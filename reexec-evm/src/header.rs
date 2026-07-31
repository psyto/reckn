//! Block-header verification: bind the committed `state_root` (and the whole
//! block environment) to the real `block_hash`.
//!
//! [`replay`](crate::replay) verifies the witness against `anchor.state_root`,
//! but `state_root` is itself committed anchor input — nothing tied it to
//! `anchor.block_hash`, the canonical consensus value an independent verifier can
//! check against L1. This closes that gap: `keccak256(rlp(header)) == block_hash`
//! and the header's `state_root` (plus every environment field the anchor commits)
//! equal the anchor's. A verified header therefore anchors the entire replay
//! environment to a real block, so a forged `state_root` is impossible without
//! breaking `block_hash`. This is the EVM analogue of the SVM `bank_hash` verifier
//! (`reexec-svm/src/bankhash.rs`); see `docs/svm-snapshot-authenticity.md` for the
//! cross-VM picture.

use crate::EvmAnchorV1;
use alloy_consensus::Header;
use alloy_rlp::Decodable;
use revm::primitives::{keccak256, B256};

/// Why a header does not bind the committed anchor.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HeaderMismatch {
    /// `keccak256(rlp(header))` does not equal the committed `block_hash`.
    BlockHash { expected: B256, got: B256 },
    /// The header's `state_root` differs from the anchor's — the replay would run
    /// against a state root the real block never had.
    StateRoot { expected: B256, got: B256 },
    /// A committed block-environment field diverges from the header's value.
    Field { name: &'static str },
    /// The committed header bytes are not valid RLP for a block header.
    Rlp,
}

/// Verify committed header **RLP bytes** bind the anchor, without the caller
/// needing this crate's exact `alloy-consensus` version: the bytes are the wire
/// interface. `keccak256(header_rlp) == block_hash` is the authoritative binding
/// (independent of decode canonicity); the bytes are then decoded to check the
/// environment fields. This is what the keeper's keyless verdict path calls on a
/// committed header blob.
pub fn verify_header_rlp_against_anchor(
    header_rlp: &[u8],
    anchor: &EvmAnchorV1,
) -> Result<(), HeaderMismatch> {
    let got = keccak256(header_rlp);
    if got != anchor.block_hash {
        return Err(HeaderMismatch::BlockHash {
            expected: anchor.block_hash,
            got,
        });
    }
    let header = Header::decode(&mut &header_rlp[..]).map_err(|_| HeaderMismatch::Rlp)?;
    verify_header_against_anchor(&header, anchor)
}

/// Verify a full block header binds the anchor. On `Ok(())`, `block_hash` is
/// proven to be `keccak256(rlp(header))` and every anchor field the EVM runs
/// under (state root, number, timestamp, base fee, gas limit, coinbase,
/// prevrandao) equals the header's — so the committed prestate anchor is a real
/// block, not seller-asserted bytes.
pub fn verify_header_against_anchor(
    header: &Header,
    anchor: &EvmAnchorV1,
) -> Result<(), HeaderMismatch> {
    // 1. The header hashes to the committed block_hash (the consensus anchor).
    let got = header.hash_slow();
    if got != anchor.block_hash {
        return Err(HeaderMismatch::BlockHash {
            expected: anchor.block_hash,
            got,
        });
    }
    // 2. With block_hash pinned to this exact header, every field the anchor
    //    commits must match it or the anchor is lying about the environment.
    if header.state_root != anchor.state_root {
        return Err(HeaderMismatch::StateRoot {
            expected: anchor.state_root,
            got: header.state_root,
        });
    }
    macro_rules! bind {
        ($cond:expr, $name:literal) => {
            if !($cond) {
                return Err(HeaderMismatch::Field { name: $name });
            }
        };
    }
    bind!(header.number == anchor.block_number, "block_number");
    bind!(header.timestamp == anchor.timestamp, "timestamp");
    bind!(header.gas_limit == anchor.block_gas_limit, "block_gas_limit");
    bind!(header.beneficiary == anchor.coinbase, "coinbase");
    bind!(header.mix_hash == anchor.prevrandao, "prevrandao");
    bind!(header.base_fee_per_gas == Some(anchor.base_fee), "base_fee");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::EvmAnchorV1;
    use revm::primitives::{Address, B256, U256};
    use revm::primitives::hardfork::SpecId;

    // A Cancun-shaped header with distinctive, non-default environment fields.
    fn base_header() -> Header {
        Header {
            state_root: B256::from([0x51; 32]),
            number: 21_000_000,
            timestamp: 1_800_000_000,
            gas_limit: 30_000_000,
            beneficiary: Address::from([0xc0; 20]),
            mix_hash: B256::from([0x22; 32]),
            base_fee_per_gas: Some(1_000_000_000),
            difficulty: U256::ZERO,
            ..Default::default()
        }
    }

    // The anchor a buyer would commit for this block — derived from the header, so
    // every field matches and `block_hash` is the header's real hash.
    fn anchor_from(header: &Header) -> EvmAnchorV1 {
        EvmAnchorV1 {
            chain_id: 1,
            block_number: header.number,
            block_hash: header.hash_slow(),
            state_root: header.state_root,
            timestamp: header.timestamp,
            base_fee: header.base_fee_per_gas.unwrap_or(0),
            block_gas_limit: header.gas_limit,
            coinbase: header.beneficiary,
            prevrandao: header.mix_hash,
            spec_id: SpecId::CANCUN,
            block_header: None,
        }
    }

    #[test]
    fn a_matching_header_binds_the_anchor() {
        let header = base_header();
        let anchor = anchor_from(&header);
        assert_eq!(verify_header_against_anchor(&header, &anchor), Ok(()));
    }

    #[test]
    fn a_wrong_block_hash_is_rejected() {
        let header = base_header();
        let mut anchor = anchor_from(&header);
        anchor.block_hash = B256::from([0xff; 32]);
        assert!(matches!(
            verify_header_against_anchor(&header, &anchor),
            Err(HeaderMismatch::BlockHash { expected, .. }) if expected == B256::from([0xff; 32])
        ));
    }

    // The essential soundness property: an attacker cannot substitute a different
    // state root, because doing so changes the header — and thus its hash — so the
    // committed `block_hash` (a real consensus value, checkable against L1) no
    // longer matches. `state_root` is only as forgeable as `block_hash`.
    #[test]
    fn state_root_cannot_be_forged_without_breaking_block_hash() {
        let header = base_header();
        let anchor = anchor_from(&header);
        // Forge a header with a different state root, and update the anchor's
        // state_root to match it — but keep the committed (real) block_hash.
        let mut forged = header.clone();
        forged.state_root = B256::from([0xaa; 32]);
        let mut lying_anchor = anchor.clone();
        lying_anchor.state_root = forged.state_root;
        assert!(matches!(
            verify_header_against_anchor(&forged, &lying_anchor),
            Err(HeaderMismatch::BlockHash { .. })
        ));
    }

    #[test]
    fn a_state_root_that_disagrees_with_the_header_is_rejected() {
        let header = base_header();
        let mut anchor = anchor_from(&header);
        anchor.state_root = B256::from([0x99; 32]);
        assert!(matches!(
            verify_header_against_anchor(&header, &anchor),
            Err(HeaderMismatch::StateRoot { .. })
        ));
    }

    // The keeper-facing entry: committed RLP bytes bind the anchor, and corrupt
    // bytes (that no longer hash to block_hash) are rejected — the interface is
    // the wire bytes, not this crate's Header type.
    #[test]
    fn header_rlp_binds_the_anchor_and_corruption_is_rejected() {
        use alloy_rlp::Encodable;
        let header = base_header();
        let anchor = anchor_from(&header);
        let mut rlp = Vec::new();
        header.encode(&mut rlp);
        assert_eq!(verify_header_rlp_against_anchor(&rlp, &anchor), Ok(()));

        // Flip a byte: it no longer hashes to the committed block_hash.
        let mut corrupt = rlp.clone();
        *corrupt.last_mut().unwrap() ^= 0x01;
        assert!(matches!(
            verify_header_rlp_against_anchor(&corrupt, &anchor),
            Err(HeaderMismatch::BlockHash { .. }) | Err(HeaderMismatch::Rlp)
        ));
    }

    #[test]
    fn each_environment_field_is_bound() {
        let header = base_header();
        let cases: [(fn(&mut EvmAnchorV1), &str); 6] = [
            (|a| a.block_number += 1, "block_number"),
            (|a| a.timestamp += 1, "timestamp"),
            (|a| a.block_gas_limit += 1, "block_gas_limit"),
            (|a| a.coinbase = Address::from([0x01; 20]), "coinbase"),
            (|a| a.prevrandao = B256::from([0x02; 32]), "prevrandao"),
            (|a| a.base_fee += 1, "base_fee"),
        ];
        for (mutate, field) in cases {
            let mut anchor = anchor_from(&header);
            mutate(&mut anchor);
            assert_eq!(
                verify_header_against_anchor(&header, &anchor),
                Err(HeaderMismatch::Field { name: field }),
                "mutating {field} must be caught",
            );
        }
    }
}

//! Reckn resolver keeper — decision + settlement-signature core.
//!
//! The keeper is the bridge between the on-chain escrow and the off-chain
//! re-execution engine. On a `Disputed` event it:
//!   1. fetches the committed spec / delivery / anchor bytes (by hash),
//!   2. builds the proof-carrying witness and calls `reexec-evm`,
//!   3. maps the reproducible verdict to the `VerdictCommitment` the escrow
//!      stores, and signs it EIP-712 with a registered resolver key,
//!   4. submits `resolve()` idempotently by `(chainId, dealId, verdictHash)`.
//!
//! This module owns steps 3 (the signature the contract verifies) — the piece
//! whose correctness is load-bearing. The EIP-712 domain and type hash here MUST
//! match `contracts/src/RecknEscrow.sol` + `VerdictHash.sol` byte-for-byte, or a
//! keeper signature would be rejected by `resolve()`. That equality is pinned by
//! a golden digest cross-checked in both this crate and a Foundry test
//! (`packages/protocol/golden/verdict-eip712-v1.json`).
//!
//! Steps 1/2/4 (chain I/O) live in `main.rs` as a thin, swappable shell; the
//! adjudication and signing verified here are chain-agnostic and deterministic.

use alloy_primitives::{keccak256, Address, B256, U256};
use alloy_signer::SignerSync;
use alloy_signer_local::PrivateKeySigner;
use reckn_reexec_evm::{ReplayOutcome, Verdict};

/// On-chain verdict outcome encoding (matches RecknEscrow.Outcome).
pub const OUTCOME_REPRODUCED: u8 = 0;
pub const OUTCOME_FAILED: u8 = 1;

/// Mirror of `RecknEscrow.VerdictCommitment` / `VerdictHash.VerdictCommitment`.
/// Field order is significant: it defines the EIP-712 struct hash.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerdictCommitment {
    pub deal_id: B256,
    pub spec_hash: B256,
    pub delivery_hash: B256,
    pub prestate_anchor_hash: B256,
    pub prestate_root: B256,
    pub backend_id: B256,
    pub backend_version_hash: B256,
    pub outcome: u8,
    pub result_hash: B256,
    pub trace_hash: B256,
}

/// The committed deal terms the keeper reads on a `Disputed` event.
#[derive(Clone, Debug)]
pub struct DealTerms {
    pub deal_id: B256,
    pub spec_hash: B256,
    pub delivery_hash: B256,
    pub prestate_anchor_hash: B256,
    pub backend_id: B256,
    pub backend_version_hash: B256,
}

/// A signed verdict ready for `resolve(commitment, v, r, s)`.
#[derive(Clone, Debug)]
pub struct SignedVerdict {
    pub commitment: VerdictCommitment,
    pub v: u8,
    pub r: B256,
    pub s: B256,
    /// The EIP-712 digest that was signed (the escrow re-derives the same value).
    pub digest: B256,
}

// keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
fn domain_type_hash() -> B256 {
    keccak256(b"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
}

// Must equal VerdictHash.VERDICT_TYPEHASH in Solidity.
fn verdict_type_hash() -> B256 {
    keccak256(
        b"VerdictCommitment(bytes32 dealId,bytes32 specHash,bytes32 deliveryHash,bytes32 prestateAnchorHash,bytes32 prestateRoot,bytes32 backendId,bytes32 backendVersionHash,uint8 outcome,bytes32 resultHash,bytes32 traceHash)",
    )
}

fn u256_word(v: u64) -> [u8; 32] {
    U256::from(v).to_be_bytes()
}

fn address_word(a: Address) -> [u8; 32] {
    let mut w = [0u8; 32];
    w[12..].copy_from_slice(a.as_slice());
    w
}

/// EIP-712 domain separator for a deployed escrow, matching the constructor in
/// `RecknEscrow.sol` (name "Reckn", version "1").
pub fn domain_separator(chain_id: u64, verifying_contract: Address) -> B256 {
    let mut buf = Vec::with_capacity(160);
    buf.extend_from_slice(domain_type_hash().as_slice());
    buf.extend_from_slice(keccak256(b"Reckn").as_slice());
    buf.extend_from_slice(keccak256(b"1").as_slice());
    buf.extend_from_slice(&u256_word(chain_id));
    buf.extend_from_slice(&address_word(verifying_contract));
    keccak256(&buf)
}

impl VerdictCommitment {
    /// EIP-712 struct hash — `keccak256(abi.encode(TYPEHASH, ...fields))`.
    pub fn struct_hash(&self) -> B256 {
        let mut w = [0u8; 32];
        w[31] = self.outcome; // uint8 left-padded to a 32-byte word
        let mut buf = Vec::with_capacity(11 * 32);
        for field in [
            verdict_type_hash(),
            self.deal_id,
            self.spec_hash,
            self.delivery_hash,
            self.prestate_anchor_hash,
            self.prestate_root,
            self.backend_id,
            self.backend_version_hash,
        ] {
            buf.extend_from_slice(field.as_slice());
        }
        buf.extend_from_slice(&w);
        buf.extend_from_slice(self.result_hash.as_slice());
        buf.extend_from_slice(self.trace_hash.as_slice());
        keccak256(&buf)
    }

    /// EIP-712 digest: `keccak256(0x1901 || domainSeparator || structHash)`.
    pub fn digest(&self, domain_separator: B256) -> B256 {
        let mut buf = Vec::with_capacity(2 + 32 + 32);
        buf.extend_from_slice(&[0x19, 0x01]);
        buf.extend_from_slice(domain_separator.as_slice());
        buf.extend_from_slice(self.struct_hash().as_slice());
        keccak256(&buf)
    }
}

/// Build the on-chain commitment from the deal terms plus a reproducible replay.
/// The engine's `outcome` (1 = Reproduced, 2 = Failed) is mapped to the escrow's
/// `Outcome` enum (0 = Reproduced, 1 = Failed).
pub fn build_commitment(terms: &DealTerms, outcome: &ReplayOutcome) -> VerdictCommitment {
    let outcome_code = match outcome.verdict {
        Verdict::Reproduced => OUTCOME_REPRODUCED,
        Verdict::Failed(_) => OUTCOME_FAILED,
    };
    VerdictCommitment {
        deal_id: terms.deal_id,
        spec_hash: terms.spec_hash,
        delivery_hash: terms.delivery_hash,
        prestate_anchor_hash: terms.prestate_anchor_hash,
        prestate_root: outcome.prestate_root,
        backend_id: terms.backend_id,
        backend_version_hash: terms.backend_version_hash,
        outcome: outcome_code,
        result_hash: outcome.result_hash,
        trace_hash: outcome.trace_hash,
    }
}

/// Sign a verdict with a resolver key for the escrow at `(chain_id, verifying_contract)`.
pub fn sign_verdict(
    commitment: VerdictCommitment,
    chain_id: u64,
    verifying_contract: Address,
    signer: &PrivateKeySigner,
) -> Result<SignedVerdict, alloy_signer::Error> {
    let domain = domain_separator(chain_id, verifying_contract);
    let digest = commitment.digest(domain);
    let sig = signer.sign_hash_sync(&digest)?;
    let v = 27 + sig.v() as u8;
    let r = B256::from(sig.r().to_be_bytes::<32>());
    let s = B256::from(sig.s().to_be_bytes::<32>());
    Ok(SignedVerdict {
        commitment,
        v,
        r,
        s,
        digest,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    // Fixed inputs shared with the Foundry cross-check and the golden vector in
    // packages/protocol/golden/verdict-eip712-v1.json. If this digest changes,
    // the contract and keeper have diverged and resolve() would reject signatures.
    fn fixed_commitment() -> VerdictCommitment {
        VerdictCommitment {
            deal_id: B256::from([0xd1; 32]),
            spec_hash: B256::from([0x5c; 32]),
            delivery_hash: B256::from([0xde; 32]),
            prestate_anchor_hash: B256::from([0xa0; 32]),
            prestate_root: B256::from([0x06; 32]),
            backend_id: B256::from([0xb0; 32]),
            backend_version_hash: B256::from([0xb1; 32]),
            outcome: 1, // Failed
            result_hash: B256::from([0x07; 32]),
            trace_hash: B256::from([0x2b; 32]),
        }
    }

    const CHAIN_ID: u64 = 1;
    // verifyingContract = 0x000...0cafe (fixed, shared with the Foundry test)
    fn verifying_contract() -> Address {
        Address::from([
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xca, 0xfe,
        ])
    }

    #[test]
    fn eip712_digest_matches_golden() {
        let domain = domain_separator(CHAIN_ID, verifying_contract());
        let digest = fixed_commitment().digest(domain);
        // Golden — must equal the Foundry-computed digest for the same inputs.
        assert_eq!(
            format!("{digest:x}"),
            "1c8d7d89486545d7e3a23da1f5438c4f36c244c85646dcc1a0b5f3c5ef19846c",
            "keeper EIP-712 digest drifted from the contract",
        );
    }

    #[test]
    fn signed_verdict_recovers_to_resolver() {
        // Deterministic test key (never a real key).
        let signer = PrivateKeySigner::from_slice(&[0x11u8; 32]).unwrap();
        let signed =
            sign_verdict(fixed_commitment(), CHAIN_ID, verifying_contract(), &signer).unwrap();

        assert!(signed.v == 27 || signed.v == 28, "v must be 27/28");
        // Reconstruct the alloy signature and recover the signer from the digest.
        let sig = alloy_primitives::Signature::from_scalars_and_parity(
            signed.r,
            signed.s,
            signed.v == 28,
        );
        let recovered = sig
            .recover_address_from_prehash(&signed.digest)
            .expect("recover");
        assert_eq!(recovered, signer.address(), "resolve() would recover this signer");
    }
}

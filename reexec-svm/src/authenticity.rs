//! Archive-subset authenticity binding.
//!
//! [`bankhash`](crate::bankhash) proves a *complete* account set reproduces a
//! block's `bank_hash`. But re-executing against Solana's full state (billions of
//! accounts) is impractical, so the dispute path replays a **compact** prestate —
//! just the accounts a transaction touches. This module binds that compact
//! prestate to a verified full snapshot without a per-account proof (which Solana
//! does not offer):
//!
//! 1. the full snapshot is the one the anchor commits to (`snapshot_archive_hash`
//!    == its content hash),
//! 2. the full snapshot is authentic (it reproduces `bank_hash`), and
//! 3. every compact account is a faithful copy of the full snapshot's value.
//!
//! Then the compact prestate is authentic by transitivity. The one external
//! dependency that remains is *ingesting* a real Agave snapshot archive into a
//! [`FullSnapshotV1`]; the binding logic itself is here and tested. See
//! `docs/svm-snapshot-authenticity.md`.

use crate::bankhash::{self, BankHashMismatch, BankHashPreimageV1};
use crate::{AccountSnapshotV2, PrestateSnapshotV2};
use alloy_primitives::B256;
use sha2::{Digest, Sha256};
use solana_pubkey::Pubkey;
use std::collections::HashMap;

const FULL_SNAPSHOT_TAG: &[u8] = b"reckn/svm/full-snapshot/v1";

/// The complete account set at the checkpoint slot — what `bank_hash` commits to
/// and what `snapshot_archive_hash` content-addresses. Distinct from
/// [`PrestateSnapshotV2`] (the compact, touched-accounts replay input) so the two
/// roles cannot be confused.
#[derive(Clone, Debug, Default)]
pub struct FullSnapshotV1 {
    pub accounts: Vec<AccountSnapshotV2>,
}

/// Why a compact prestate is not an authentic subset of a full snapshot.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AuthenticityError {
    /// Two accounts in the full snapshot share a pubkey — it is malformed.
    DuplicateAccount { pubkey: Pubkey },
    /// The full snapshot does not hash to the committed `snapshot_archive_hash`.
    ArchiveCommitmentMismatch { expected: B256, got: B256 },
    /// The full snapshot does not reproduce the block's `bank_hash`.
    BankHash(BankHashMismatch),
    /// A compact prestate account is not present in the full snapshot.
    AccountMissingFromArchive { pubkey: Pubkey },
    /// A compact prestate account's value differs from the full snapshot's.
    AccountMismatch { pubkey: Pubkey },
}

/// Canonical content hash of a full snapshot — the value `snapshot_archive_hash`
/// commits to. Accounts are sorted by pubkey and every field is length-delimited,
/// so the commitment is order-independent and free of data-boundary ambiguity.
/// Duplicate pubkeys are rejected.
pub fn full_snapshot_commitment(full: &FullSnapshotV1) -> Result<B256, AuthenticityError> {
    let mut accounts: Vec<&AccountSnapshotV2> = full.accounts.iter().collect();
    accounts.sort_by_key(|a| a.pubkey.to_bytes());
    for pair in accounts.windows(2) {
        if pair[0].pubkey == pair[1].pubkey {
            return Err(AuthenticityError::DuplicateAccount {
                pubkey: pair[0].pubkey,
            });
        }
    }
    let mut h = Sha256::new();
    h.update(FULL_SNAPSHOT_TAG);
    h.update((accounts.len() as u64).to_le_bytes());
    for a in accounts {
        h.update(a.pubkey.to_bytes());
        h.update(a.lamports.to_le_bytes());
        h.update(a.owner.to_bytes());
        h.update([a.executable as u8]);
        h.update(a.rent_epoch.to_le_bytes());
        h.update((a.data.len() as u64).to_le_bytes());
        h.update(&a.data);
    }
    Ok(B256::from_slice(&h.finalize()))
}

/// Every account in `compact` must be present in `full` with an identical value.
/// `full` may hold more accounts; `compact` may not diverge from or exceed it.
pub fn verify_prestate_subset(
    compact: &PrestateSnapshotV2,
    full: &FullSnapshotV1,
) -> Result<(), AuthenticityError> {
    let index: HashMap<[u8; 32], &AccountSnapshotV2> = full
        .accounts
        .iter()
        .map(|a| (a.pubkey.to_bytes(), a))
        .collect();
    for c in &compact.accounts {
        match index.get(&c.pubkey.to_bytes()) {
            None => {
                return Err(AuthenticityError::AccountMissingFromArchive { pubkey: c.pubkey })
            }
            Some(f) => {
                if f.lamports != c.lamports
                    || f.owner != c.owner
                    || f.executable != c.executable
                    || f.rent_epoch != c.rent_epoch
                    || f.data != c.data
                {
                    return Err(AuthenticityError::AccountMismatch { pubkey: c.pubkey });
                }
            }
        }
    }
    Ok(())
}

/// The full binding: prove the compact prestate is the authentic checkpoint state
/// for the accounts it carries, without a per-account inclusion proof. `Ok(())`
/// means the compact prestate can be replayed as genuine — the transitive
/// equivalent of the EVM MPT witness check.
pub fn verify_prestate_authenticity(
    compact: &PrestateSnapshotV2,
    full: &FullSnapshotV1,
    preimage: &BankHashPreimageV1,
    expected_bank_hash: B256,
    expected_archive_hash: B256,
) -> Result<(), AuthenticityError> {
    // 1. The full snapshot is the one the anchor commits to.
    let got = full_snapshot_commitment(full)?;
    if got != expected_archive_hash {
        return Err(AuthenticityError::ArchiveCommitmentMismatch {
            expected: expected_archive_hash,
            got,
        });
    }
    // 2. The full snapshot is authentic: it reproduces the block's bank_hash.
    bankhash::verify_accounts_against_bank_hash(&full.accounts, preimage, expected_bank_hash)
        .map_err(AuthenticityError::BankHash)?;
    // 3. The compact prestate is a faithful subset of it.
    verify_prestate_subset(compact, full)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn account(seed: u8, lamports: u64, data: &[u8]) -> AccountSnapshotV2 {
        AccountSnapshotV2 {
            pubkey: Pubkey::new_from_array([seed; 32]),
            lamports,
            owner: Pubkey::new_from_array([seed.wrapping_add(0x40); 32]),
            executable: false,
            rent_epoch: u64::MAX,
            data: data.to_vec(),
        }
    }

    fn preimage() -> BankHashPreimageV1 {
        BankHashPreimageV1 {
            parent_bank_hash: B256::from([0x11; 32]),
            signature_count: 5,
            last_blockhash: B256::from([0x22; 32]),
        }
    }

    // A full snapshot, its honest archive hash + bank_hash, and a compact prestate
    // that is a genuine subset (the second account).
    fn fixture() -> (FullSnapshotV1, PrestateSnapshotV2, BankHashPreimageV1, B256, B256) {
        let full = FullSnapshotV1 {
            accounts: vec![
                account(0x01, 1_000, b"alpha"),
                account(0x02, 2_000, b"beta"),
                account(0x03, 3_000, b"gamma"),
            ],
        };
        let pre = preimage();
        let archive = full_snapshot_commitment(&full).unwrap();
        let bank =
            bankhash::bank_hash(&pre, &bankhash::accounts_lt_hash(&full.accounts).checksum().0);
        let compact = PrestateSnapshotV2 {
            accounts: vec![account(0x02, 2_000, b"beta")],
        };
        (full, compact, pre, bank, archive)
    }

    #[test]
    fn full_binding_accepts_a_genuine_subset() {
        let (full, compact, pre, bank, archive) = fixture();
        assert_eq!(
            verify_prestate_authenticity(&compact, &full, &pre, bank, archive),
            Ok(())
        );
    }

    // The archive commitment is order-independent: shuffling the full snapshot
    // still hashes to the same value and still binds.
    #[test]
    fn archive_commitment_is_order_independent() {
        let (full, compact, pre, bank, archive) = fixture();
        let reversed = FullSnapshotV1 {
            accounts: full.accounts.iter().rev().cloned().collect(),
        };
        assert_eq!(full_snapshot_commitment(&reversed).unwrap(), archive);
        assert!(verify_prestate_authenticity(&compact, &reversed, &pre, bank, archive).is_ok());
    }

    // A compact account that diverges from the archive (tampered value) is caught
    // by the subset step even though the archive itself is authentic.
    #[test]
    fn tampered_compact_account_is_rejected() {
        let (full, _compact, pre, bank, archive) = fixture();
        let lying = PrestateSnapshotV2 {
            accounts: vec![account(0x02, 9_999, b"beta")], // wrong lamports
        };
        assert!(matches!(
            verify_prestate_authenticity(&lying, &full, &pre, bank, archive),
            Err(AuthenticityError::AccountMismatch { pubkey }) if pubkey == account(0x02, 0, b"").pubkey
        ));
    }

    // A compact account absent from the archive cannot be smuggled in.
    #[test]
    fn compact_account_absent_from_archive_is_rejected() {
        let (full, _compact, pre, bank, archive) = fixture();
        let smuggled = PrestateSnapshotV2 {
            accounts: vec![account(0x09, 1, b"ghost")],
        };
        assert!(matches!(
            verify_prestate_authenticity(&smuggled, &full, &pre, bank, archive),
            Err(AuthenticityError::AccountMissingFromArchive { .. })
        ));
    }

    // A full snapshot that is not the committed archive fails before any subset
    // work — you cannot swap in a different account set.
    #[test]
    fn wrong_archive_commitment_is_rejected() {
        let (full, compact, pre, bank, _archive) = fixture();
        let wrong_archive = B256::from([0xab; 32]);
        assert!(matches!(
            verify_prestate_authenticity(&compact, &full, &pre, bank, wrong_archive),
            Err(AuthenticityError::ArchiveCommitmentMismatch { expected, .. }) if expected == wrong_archive
        ));
    }

    // A full snapshot whose accounts do not reproduce bank_hash is rejected even
    // if it hashes to the committed archive — authenticity, not just consistency.
    #[test]
    fn archive_that_does_not_reproduce_bank_hash_is_rejected() {
        let (full, compact, pre, _bank, archive) = fixture();
        let wrong_bank = B256::from([0xcd; 32]);
        assert!(matches!(
            verify_prestate_authenticity(&compact, &full, &pre, wrong_bank, archive),
            Err(AuthenticityError::BankHash(_))
        ));
    }

    #[test]
    fn duplicate_account_in_archive_is_malformed() {
        let full = FullSnapshotV1 {
            accounts: vec![account(0x05, 1, b"x"), account(0x05, 2, b"y")],
        };
        assert!(matches!(
            full_snapshot_commitment(&full),
            Err(AuthenticityError::DuplicateAccount { .. })
        ));
    }
}

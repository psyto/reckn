//! Solana keeper/verification shell for Reckn.
//!
//! It treats every content-addressed JSON blob as hostile until its *raw* SHA-256
//! equals the hash committed by the deal (or by a deal-committed spec/anchor).
//! `OperationalError` is deliberately returned without a signature.

use {
    alloy_primitives::B256,
    ed25519_dalek::{Signer, SigningKey},
    reckn_escrow_svm::{
        outcome, state, verdict_message, Deal, ResolverConfig, VerdictCommitment,
        TOKEN_2022_PROGRAM_ID,
    },
    reckn_record::ReexecCommitmentsV1,
    reckn_reexec_svm::{
        replay, AccountSnapshotV2, OperationalError, PredicateV1, PrestateSnapshotV2,
        ReplayOutcome, RuntimeProfileV1, SvmAnchorV2, SvmPlanV2, Verdict,
    },
    serde::{Deserialize, Serialize},
    sha2::{Digest, Sha256},
    solana_address::Address,
    solana_ed25519_program::new_ed25519_instruction_with_signature,
    solana_instruction::{AccountMeta, Instruction},
    solana_sdk_ids::sysvar::instructions,
    std::{
        fs,
        path::{Path, PathBuf},
    },
};

#[derive(Debug)]
pub enum KeeperError {
    Io(String),
    HashMismatch { expected: B256, got: B256 },
    Json(String),
    InvalidDeal(&'static str),
    Operational(OperationalError),
    Replay(String),
}
impl core::fmt::Display for KeeperError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(f, "{self:?}")
    }
}
impl std::error::Error for KeeperError {}

#[derive(Clone)]
pub struct FileContentStore {
    root: PathBuf,
}
impl FileContentStore {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }
    pub fn load_checked(&self, expected: B256) -> Result<Vec<u8>, KeeperError> {
        let path = self.root.join(format!("{:x}.json", expected));
        let bytes = fs::read(path).map_err(|e| KeeperError::Io(e.to_string()))?;
        let got = B256::from_slice(&Sha256::digest(&bytes));
        if got != expected {
            return Err(KeeperError::HashMismatch { expected, got });
        }
        Ok(bytes)
    }
    pub fn load_json<T: for<'a> Deserialize<'a>>(&self, expected: B256) -> Result<T, KeeperError> {
        serde_json::from_slice(&self.load_checked(expected)?)
            .map_err(|e| KeeperError::Json(e.to_string()))
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct StoredSpecV1 {
    pub backend_id: [u8; 32],
    pub backend_version_hash: [u8; 32],
    pub anchor_hash: [u8; 32],
    pub runtime_profile_content_hash: [u8; 32],
    pub predicate: StoredPredicateV1,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum StoredPredicateV1 {
    ResultEquals { expected_result_hash: [u8; 32] },
    LamportsEquals { account: [u8; 32], expected: u64 },
}
#[derive(Clone, Serialize, Deserialize)]
pub struct StoredDeliveryV1 {
    pub transaction: Vec<u8>,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct StoredAnchorV2 {
    pub state_commitment: [u8; 32],
    pub cluster_genesis_hash: [u8; 32],
    pub slot: u64,
    pub blockhash: [u8; 32],
    pub bank_hash: [u8; 32],
    pub runtime_profile_hash: [u8; 32],
    pub snapshot_archive_hash: [u8; 32],
    pub snapshot_format_version: u16,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct StoredSnapshotV2 {
    pub accounts: Vec<StoredAccountV2>,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct StoredAccountV2 {
    pub pubkey: [u8; 32],
    pub lamports: u64,
    pub owner: [u8; 32],
    pub executable: bool,
    pub rent_epoch: u64,
    pub data: Vec<u8>,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct StoredRuntimeProfileV1 {
    pub allowed_ambient_programs: Vec<[u8; 32]>,
}

pub struct LoadedReplay {
    pub anchor: SvmAnchorV2,
    pub snapshot: PrestateSnapshotV2,
    pub profile: RuntimeProfileV1,
    pub plan: SvmPlanV2,
    pub predicate: PredicateV1,
    pub commitments: ReexecCommitmentsV1,
}
fn b(v: [u8; 32]) -> B256 {
    B256::from(v)
}
fn bytes32(v: B256) -> [u8; 32] {
    let mut out = [0; 32];
    out.copy_from_slice(v.as_slice());
    out
}
fn addr(v: [u8; 32]) -> solana_pubkey::Pubkey {
    solana_pubkey::Pubkey::new_from_array(v)
}

/// Validate the disputed deal fields, then resolve the transitive store graph:
/// deal->spec/delivery/anchor, spec->runtime profile, anchor->snapshot.
pub fn load_for_disputed_deal(
    store: &FileContentStore,
    deal: &Deal,
) -> Result<LoadedReplay, KeeperError> {
    if deal.state != state::DISPUTED {
        return Err(KeeperError::InvalidDeal("deal is not Disputed"));
    }
    let spec: StoredSpecV1 = store.load_json(b(deal.spec_hash))?;
    if spec.backend_id != deal.backend_id
        || spec.backend_version_hash != deal.backend_version_hash
        || spec.anchor_hash != deal.anchor_hash
    {
        return Err(KeeperError::InvalidDeal(
            "spec commitments differ from deal",
        ));
    }
    let delivery: StoredDeliveryV1 = store.load_json(b(deal.delivery_hash))?;
    let anchor: StoredAnchorV2 = store.load_json(b(deal.anchor_hash))?;
    if anchor.runtime_profile_hash != deal.runtime_profile_hash {
        return Err(KeeperError::InvalidDeal(
            "anchor runtime profile differs from deal",
        ));
    }
    let snapshot: StoredSnapshotV2 = store.load_json(b(anchor.snapshot_archive_hash))?;
    let profile: StoredRuntimeProfileV1 = store.load_json(b(spec.runtime_profile_content_hash))?;
    let plan = bincode::deserialize(&delivery.transaction)
        .map_err(|e| KeeperError::Json(e.to_string()))?;
    let predicate = match spec.predicate {
        StoredPredicateV1::ResultEquals {
            expected_result_hash,
        } => PredicateV1::ResultEquals {
            expected_result_hash: b(expected_result_hash),
        },
        StoredPredicateV1::LamportsEquals { account, expected } => PredicateV1::LamportsEquals {
            account: addr(account),
            expected,
        },
    };
    Ok(LoadedReplay {
        anchor: SvmAnchorV2 {
            state_commitment: b(anchor.state_commitment),
            cluster_genesis_hash: b(anchor.cluster_genesis_hash),
            slot: anchor.slot,
            blockhash: b(anchor.blockhash),
            bank_hash: b(anchor.bank_hash),
            runtime_profile_hash: b(anchor.runtime_profile_hash),
            snapshot_archive_hash: b(anchor.snapshot_archive_hash),
            snapshot_format_version: anchor.snapshot_format_version,
        },
        snapshot: PrestateSnapshotV2 {
            accounts: snapshot
                .accounts
                .into_iter()
                .map(|x| AccountSnapshotV2 {
                    pubkey: addr(x.pubkey),
                    lamports: x.lamports,
                    owner: addr(x.owner),
                    executable: x.executable,
                    rent_epoch: x.rent_epoch,
                    data: x.data,
                })
                .collect(),
        },
        profile: RuntimeProfileV1 {
            allowed_ambient_programs: profile
                .allowed_ambient_programs
                .into_iter()
                .map(addr)
                .collect(),
        },
        plan: SvmPlanV2 { transaction: plan },
        predicate,
        commitments: ReexecCommitmentsV1 {
            backend_id: b(deal.backend_id),
            backend_version_hash: b(deal.backend_version_hash),
            spec_hash: b(deal.spec_hash),
            delivery_hash: b(deal.delivery_hash),
            prestate_anchor_hash: b(deal.anchor_hash),
        },
    })
}

pub fn replay_disputed(
    store: &FileContentStore,
    deal: &Deal,
) -> Result<ReplayOutcome, KeeperError> {
    let input = load_for_disputed_deal(store, deal)?;
    replay(
        &input.anchor,
        &input.snapshot,
        &input.profile,
        &input.plan,
        &input.predicate,
        &input.commitments,
    )
    .map_err(KeeperError::Operational)
}

pub fn commitment(deal_id: [u8; 32], deal: &Deal, replay: &ReplayOutcome) -> VerdictCommitment {
    VerdictCommitment {
        deal_id,
        spec_hash: deal.spec_hash,
        delivery_hash: deal.delivery_hash,
        anchor_hash: deal.anchor_hash,
        backend_id: deal.backend_id,
        backend_version_hash: deal.backend_version_hash,
        runtime_profile_hash: deal.runtime_profile_hash,
        prestate_root: bytes32(replay.prestate_root),
        outcome: if matches!(replay.verdict, Verdict::Reproduced) {
            outcome::REPRODUCED
        } else {
            outcome::FAILED
        },
        result_hash: bytes32(replay.result_hash),
        trace_hash: bytes32(replay.trace_hash),
    }
}

pub struct ResolveAccounts {
    pub vault: Address,
    pub destination: Address,
    pub mint: Address,
    pub config: Address,
}
/// Build the exact `[ed25519(current-ix), resolve]` adjacency required by the program.
pub fn signed_resolve_ixs(
    program_id: Address,
    deal_id: Address,
    deal: &Deal,
    config: &ResolverConfig,
    resolver: &SigningKey,
    replay: &ReplayOutcome,
    a: ResolveAccounts,
) -> Result<(VerdictCommitment, [Instruction; 2]), KeeperError> {
    if resolver.verifying_key().to_bytes() != config.resolver {
        return Err(KeeperError::InvalidDeal(
            "signer is not registered resolver",
        ));
    }
    let c = commitment(*deal_id.as_array(), deal, replay);
    let program_id_bytes = *program_id.as_array();
    let message = verdict_message(&program_id_bytes, config, &c);
    let sig = resolver.sign(&message).to_bytes();
    let ed = new_ed25519_instruction_with_signature(&message, &sig, &config.resolver);
    let mut encoded = [0; VerdictCommitment::LEN];
    c.encode(&mut encoded);
    let mut data = Vec::with_capacity(1 + encoded.len());
    data.push(reckn_escrow_svm::ix::RESOLVE);
    data.extend_from_slice(&encoded);
    let resolve = Instruction {
        program_id,
        data,
        accounts: vec![
            AccountMeta::new(deal_id, false),
            AccountMeta::new(a.vault, false),
            AccountMeta::new(a.destination, false),
            AccountMeta::new_readonly(a.mint, false),
            AccountMeta::new_readonly(Address::from(TOKEN_2022_PROGRAM_ID), false),
            AccountMeta::new_readonly(a.config, false),
            AccountMeta::new_readonly(instructions::id(), false),
        ],
    };
    Ok((c, [ed, resolve]))
}

/// Keyless verifier: independently replay and compare the on-chain evidence.
pub fn verify(
    store: &FileContentStore,
    deal_id: [u8; 32],
    deal: &Deal,
    onchain: &VerdictCommitment,
) -> Result<bool, KeeperError> {
    if onchain.deal_id != deal_id
        || onchain.spec_hash != deal.spec_hash
        || onchain.delivery_hash != deal.delivery_hash
        || onchain.anchor_hash != deal.anchor_hash
    {
        return Ok(false);
    }
    let replay = replay_disputed(store, deal)?;
    let expected = commitment(deal_id, deal, &replay);
    Ok(expected.outcome == onchain.outcome
        && expected.trace_hash == onchain.trace_hash
        && expected.result_hash == onchain.result_hash
        && expected.prestate_root == onchain.prestate_root)
}

pub fn write_content(root: &Path, bytes: &[u8]) -> B256 {
    let h = B256::from_slice(&Sha256::digest(bytes));
    fs::write(root.join(format!("{:x}.json", h)), bytes).unwrap();
    h
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_instruction::{AccountMeta, Instruction};
    use solana_keypair::Keypair;
    use solana_signer::Signer as _;
    use solana_transaction::Transaction;
    use tempfile::tempdir;

    fn transfer(from: Address, to: Address, n: u64) -> Instruction {
        let mut data = 2u32.to_le_bytes().to_vec();
        data.extend_from_slice(&n.to_le_bytes());
        Instruction {
            program_id: Address::default(),
            accounts: vec![AccountMeta::new(from, true), AccountMeta::new(to, false)],
            data,
        }
    }
    fn account(key: Address, lamports: u64) -> StoredAccountV2 {
        StoredAccountV2 {
            pubkey: *key.as_array(),
            lamports,
            owner: [0; 32],
            executable: false,
            rent_epoch: u64::MAX,
            data: vec![],
        }
    }
    fn put_json<T: Serialize>(dir: &Path, v: &T) -> B256 {
        write_content(dir, &serde_json::to_vec(v).unwrap())
    }

    #[test]
    fn checked_store_replay_builds_keyless_verifiable_honest_and_failed_verdicts() {
        for (amount, expected, reproduced) in
            [(2_000_000, 2_000_001, true), (1_500_000, 2_000_001, false)]
        {
            let dir = tempdir().unwrap();
            let from = Keypair::new_from_array([1; 32]);
            let to = Address::new_from_array([2; 32]);
            let mut tx = Transaction::new_with_payer(
                &[transfer(from.pubkey(), to, amount)],
                Some(&from.pubkey()),
            );
            tx.sign(&[&from], Default::default());
            let profile = StoredRuntimeProfileV1 {
                allowed_ambient_programs: vec![[0; 32]],
            };
            let profile_raw = serde_json::to_vec(&profile).unwrap();
            let profile_file = write_content(dir.path(), &profile_raw);
            let snapshot = StoredSnapshotV2 {
                accounts: vec![account(from.pubkey(), 1_000_000_000), account(to, 1)],
            };
            // Derive the engine's compact-root commitment from precisely the bytes
            // we are about to place in the content store.
            let rprofile = RuntimeProfileV1::default();
            let rsnapshot = PrestateSnapshotV2 {
                accounts: snapshot
                    .accounts
                    .iter()
                    .cloned()
                    .map(|x| AccountSnapshotV2 {
                        pubkey: addr(x.pubkey),
                        lamports: x.lamports,
                        owner: addr(x.owner),
                        executable: x.executable,
                        rent_epoch: x.rent_epoch,
                        data: x.data,
                    })
                    .collect(),
            };
            let state_root = reckn_reexec_svm::snapshot_commitment(&rsnapshot, &rprofile).unwrap();
            let snapshot_file = put_json(dir.path(), &snapshot);
            let anchor = StoredAnchorV2 {
                state_commitment: bytes32(state_root),
                cluster_genesis_hash: [3; 32],
                slot: 1,
                blockhash: [0; 32],
                bank_hash: [4; 32],
                runtime_profile_hash: bytes32(
                    reckn_reexec_svm::runtime_profile_hash(&rprofile).unwrap(),
                ),
                snapshot_archive_hash: bytes32(snapshot_file),
                snapshot_format_version: 2,
            };
            let anchor_file = put_json(dir.path(), &anchor);
            let delivery_file = put_json(
                dir.path(),
                &StoredDeliveryV1 {
                    transaction: bincode::serialize(&tx).unwrap(),
                },
            );
            let spec = StoredSpecV1 {
                backend_id: [5; 32],
                backend_version_hash: [6; 32],
                anchor_hash: bytes32(anchor_file),
                runtime_profile_content_hash: bytes32(profile_file),
                predicate: StoredPredicateV1::LamportsEquals {
                    account: *to.as_array(),
                    expected,
                },
            };
            let spec_file = put_json(dir.path(), &spec);
            let deal = Deal {
                bump: 0,
                state: state::DISPUTED,
                _pad: [0; 6],
                amount: 1,
                buyer: [8; 32],
                seller: [9; 32],
                mint: [10; 32],
                spec_hash: bytes32(spec_file),
                delivery_hash: bytes32(delivery_file),
                anchor_hash: bytes32(anchor_file),
                backend_id: [5; 32],
                backend_version_hash: [6; 32],
                runtime_profile_hash: anchor.runtime_profile_hash,
                deliver_deadline: 2,
                challenge_deadline: 3,
                resolve_deadline: 4,
                nonce: [11; 32],
            };
            let store = FileContentStore::new(dir.path());
            let result = replay_disputed(&store, &deal).unwrap();
            assert_eq!(result.reproduced(), reproduced);
            let c = commitment([12; 32], &deal, &result);
            assert!(verify(&store, [12; 32], &deal, &c).unwrap());
            // A byte-mutated content object is never parsed as replacement input.
            fs::write(dir.path().join(format!("{:x}.json", spec_file)), b"{}").unwrap();
            assert!(replay_disputed(&store, &deal).is_err());
        }
    }
}

//! Reckn SVM V2 re-execution backend.
//!
//! A verdict is emitted only after every replay input is committed: a signed
//! transaction, a canonical prestate snapshot, and the LiteSVM runtime profile.
//! The anchor also carries the finalized-checkpoint fields required by the
//! production verifier. This crate validates the replay-side boundary; a Bank
//! snapshot verifier is responsible for deriving this snapshot from the anchor's
//! `bank_hash` and `snapshot_archive_hash` before it reaches this API.

pub mod bankhash;

use alloy_primitives::B256;
use litesvm::{AccountLoadPolicy, LiteSVM};
use reckn_record::{result_content_hash, ReexecCommitmentsV1, ReplayRecordV1};
use sha2::{Digest, Sha256};
use solana_account::Account;
use solana_pubkey::Pubkey;
use solana_transaction::Transaction;
use std::collections::BTreeSet;
use std::str::FromStr;

const SVM_RETURN_TAG: &[u8] = b"svm-return-data";
const SNAPSHOT_CODEC_TAG: &[u8] = b"reckn/svm/prestate";
const RUNTIME_PROFILE_TAG: &[u8] = b"reckn/svm/runtime-profile";
const SNAPSHOT_FORMAT_V2: u16 = 2;
const LITESVM_RUNTIME_ID: &[u8] = b"litesvm/0.13.1/reckn-closed-world/1";

/// A V2 anchor. `state_commitment` is the canonical commitment to the compact
/// replay witness; the other fields bind that witness to the checkpoint from
/// which an external Bank-snapshot verifier derived it.
#[derive(Clone, Debug)]
pub struct SvmAnchorV2 {
    pub state_commitment: B256,
    pub cluster_genesis_hash: B256,
    pub slot: u64,
    pub blockhash: B256,
    pub bank_hash: B256,
    /// The `bank_hash` preimage fields, so replay can re-derive and check
    /// `bank_hash` from the account set (see [`bankhash`]). `blockhash` above is
    /// the `last_blockhash` input.
    pub parent_bank_hash: B256,
    pub signature_count: u64,
    /// When set, the snapshot is asserted to be the *complete* account set the
    /// lattice hash commits to, so replay verifies it reproduces `bank_hash`. A
    /// compact per-tx prestate leaves this `false` and binds via the archive
    /// (see `docs/svm-snapshot-authenticity.md`).
    pub snapshot_is_complete: bool,
    pub runtime_profile_hash: B256,
    pub snapshot_archive_hash: B256,
    pub snapshot_format_version: u16,
}

/// The legacy V1 anchor is intentionally not accepted by [`replay`]. It cannot
/// carry the checkpoint or runtime commitments needed for settlement-grade SVM
/// replay.
#[derive(Clone, Debug)]
pub struct SvmAnchorV1 {
    pub slot: u64,
    pub state_commitment: B256,
}

/// One account derived from a checkpoint-authenticated snapshot.
#[derive(Clone, Debug)]
pub struct AccountSnapshotV2 {
    pub pubkey: Pubkey,
    pub lamports: u64,
    pub owner: Pubkey,
    pub executable: bool,
    pub rent_epoch: u64,
    pub data: Vec<u8>,
}

/// A compact, checkpoint-derived replay witness. Program bytes are deliberately
/// absent: program images are derived from Program/ProgramData accounts here,
/// never accepted from the seller.
#[derive(Clone, Debug, Default)]
pub struct PrestateSnapshotV2 {
    pub accounts: Vec<AccountSnapshotV2>,
}

/// Compatibility names for the account and snapshot data types. The snapshot
/// no longer has a seller-supplied `programs` field.
pub type PrestateSnapshotV1 = PrestateSnapshotV2;
pub type AccountSnapshotV1 = AccountSnapshotV2;

/// The explicit subset of LiteSVM's otherwise ambient runtime that a plan may
/// invoke without a snapshot account. The V2 default permits only the System
/// builtin. All other program accounts must be checkpoint-derived.
#[derive(Clone, Debug)]
pub struct RuntimeProfileV1 {
    pub allowed_ambient_programs: Vec<Pubkey>,
}

impl Default for RuntimeProfileV1 {
    fn default() -> Self {
        Self {
            allowed_ambient_programs: vec![system_program_id()],
        }
    }
}

/// A signed, seller-supplied transaction. Its canonical transaction bytes,
/// including signatures and recent blockhash, belong to `deliveryHash`.
#[derive(Clone, Debug)]
pub struct SvmPlanV2 {
    pub transaction: Transaction,
}

pub type SvmPlanV1 = SvmPlanV2;

/// The buyer-funded predicate. Fixed at funding; the seller cannot change it.
#[derive(Clone, Debug)]
pub enum PredicateV1 {
    /// `SHA-256("reckn/v1/" || "svm-return-data" || returnData)` equals this.
    ResultEquals { expected_result_hash: B256 },
    /// The named post-state account must still exist and have these lamports.
    LamportsEquals { account: Pubkey, expected: u64 },
    /// The named post-state account must still exist and hold lamports within
    /// the inclusive range `[min, max]`. This widens the funded predicate from
    /// exact reproduction to a *funded envelope* — e.g. "the buyer's token
    /// account received at least `minOut` lamports" (a slippage bound) is
    /// `(account, minOut, u64::MAX)`, and "<= cap" is `(account, 0, cap)`.
    /// Equality is the degenerate `min == max` case.
    ///
    /// Like the EVM `PostStateBounded`, this adjudicates a *property*, not
    /// causation: a transaction that never moves the account still reads its
    /// committed prestate balance. Use `LamportsDelta` for the causal claim.
    LamportsBounded { account: Pubkey, min: u64, max: u64 },
    /// The named account's credited increase `post - pre` (saturating at 0,
    /// `pre` = committed snapshot balance) must lie in the inclusive range
    /// `[min, max]`. Unlike `LamportsBounded`, this adjudicates *causation*: the
    /// transaction itself must have raised the balance, so a no-op cannot
    /// satisfy any `min > 0`. The SVM analogue of EVM `PostStateDelta`.
    LamportsDelta { account: Pubkey, min: u64, max: u64 },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum FailReason {
    /// The signed transaction did not verify against its message signers.
    InvalidAuthorization,
    /// The authenticated transaction failed during SVM execution.
    Execution,
    ResultMismatch,
    LamportsMismatch {
        account: Pubkey,
        got: u64,
        expected: u64,
    },
    /// A `LamportsBounded` account held lamports outside its inclusive `[min, max]`.
    LamportsOutOfBounds {
        account: Pubkey,
        got: u64,
        min: u64,
        max: u64,
    },
    /// A `LamportsDelta` account's `post - pre` increase fell outside `[min, max]`.
    LamportsDeltaOutOfBounds {
        account: Pubkey,
        pre: u64,
        post: u64,
        delta: u64,
        min: u64,
        max: u64,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Verdict {
    Reproduced,
    Failed(FailReason),
}

/// A missing, unauthentic, or unsupported replay input. These errors never
/// produce a resolver signature or a buyer/seller verdict.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OperationalError {
    UnsupportedSnapshotFormat {
        got: u16,
    },
    PrestateCommitmentMismatch {
        expected: B256,
        got: B256,
    },
    /// A `snapshot_is_complete` snapshot did not reproduce the committed
    /// `bank_hash` under the accounts lattice hash. Like a bad witness, this is an
    /// operational error — never a `Failed`/`Reproduced` verdict.
    BankHashMismatch {
        expected: B256,
        got: B256,
    },
    RuntimeProfileMismatch {
        expected: B256,
        got: B256,
    },
    BlockhashMismatch {
        expected: B256,
        got: B256,
    },
    DuplicateAccount {
        pubkey: Pubkey,
    },
    DuplicateProgram {
        program_id: Pubkey,
    },
    /// A message account was not in the snapshot or the explicit ambient
    /// profile. This is reported before LiteSVM can synthesize a default.
    ImplicitAccountLoad {
        account: Pubkey,
    },
    /// Defensive final-line error from the patched LiteSVM loader.
    ImplicitAccountLoadDuringExecution,
    MissingPredicateAccount {
        account: Pubkey,
    },
    MissingPoststateAccount {
        account: Pubkey,
    },
    UnsupportedEnvironmentDependency {
        dependency: &'static str,
    },
    ProgramImageUnavailable {
        program_id: Pubkey,
    },
    ProgramDataMissing {
        program_id: Pubkey,
        programdata: Pubkey,
    },
    ProgramLoad {
        program_id: Pubkey,
    },
    AccountLoad {
        account: Pubkey,
    },
}

#[derive(Clone, Debug)]
pub struct ReplayOutcome {
    pub verdict: Verdict,
    pub result_hash: B256,
    pub prestate_root: B256,
    pub trace_hash: B256,
    pub record: ReplayRecordV1,
    pub return_data: Vec<u8>,
}

impl ReplayOutcome {
    pub fn reproduced(&self) -> bool {
        self.verdict == Verdict::Reproduced
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProgramImageV2 {
    pub program_id: Pubkey,
    pub elf: Vec<u8>,
}

/// Hashes the explicit LiteSVM profile. A profile change is a replay-input
/// change, not an implementation detail.
pub fn runtime_profile_hash(profile: &RuntimeProfileV1) -> Result<B256, OperationalError> {
    let mut programs = profile.allowed_ambient_programs.clone();
    programs.sort_by_key(|id| id.to_bytes());
    for pair in programs.windows(2) {
        if pair[0] == pair[1] {
            return Err(OperationalError::DuplicateProgram {
                program_id: pair[0],
            });
        }
    }
    // `LiteSVM::new()` also preloads several SPL programs. Treating those as a
    // caller-selectable allowlist would merely move the old ambient-code trust
    // bug into the profile. Until their account/loader state is reconstructed,
    // the System builtin is the only permitted ambient executable.
    if programs
        .iter()
        .any(|program| *program != system_program_id())
    {
        return Err(OperationalError::UnsupportedEnvironmentDependency {
            dependency: "unverified ambient program",
        });
    }

    let mut h = Sha256::new();
    hash_bytes(&mut h, RUNTIME_PROFILE_TAG);
    hash_u16(&mut h, 1);
    hash_bytes(&mut h, LITESVM_RUNTIME_ID);
    hash_u64(&mut h, programs.len() as u64);
    for program in programs {
        hash_bytes(&mut h, &program.to_bytes());
    }
    Ok(B256::from_slice(&h.finalize()))
}

/// Versioned, length-prefixed commitment over every compact replay input:
/// account identity/content (including rent epoch), the set of executable
/// Program/ProgramData accounts, and the complete runtime profile hash.
pub fn snapshot_commitment(
    snapshot: &PrestateSnapshotV2,
    profile: &RuntimeProfileV1,
) -> Result<B256, OperationalError> {
    let profile_hash = runtime_profile_hash(profile)?;
    let mut accounts: Vec<&AccountSnapshotV2> = snapshot.accounts.iter().collect();
    accounts.sort_by_key(|account| account.pubkey.to_bytes());
    for pair in accounts.windows(2) {
        if pair[0].pubkey == pair[1].pubkey {
            return Err(OperationalError::DuplicateAccount {
                pubkey: pair[0].pubkey,
            });
        }
    }

    let mut h = Sha256::new();
    hash_bytes(&mut h, SNAPSHOT_CODEC_TAG);
    hash_u16(&mut h, SNAPSHOT_FORMAT_V2);
    hash_bytes(&mut h, profile_hash.as_slice());
    hash_u64(&mut h, accounts.len() as u64);
    for account in accounts {
        hash_bytes(&mut h, &account.pubkey.to_bytes());
        hash_u64(&mut h, account.lamports);
        hash_bytes(&mut h, &account.owner.to_bytes());
        hash_bool(&mut h, account.executable);
        hash_u64(&mut h, account.rent_epoch);
        hash_bytes(&mut h, &account.data);
    }
    Ok(B256::from_slice(&h.finalize()))
}

/// Derives executable code from checkpoint-derived loader accounts. There is no
/// seller-controlled `(program_id, elf)` input in V2.
pub fn derive_program_images(
    snapshot: &PrestateSnapshotV2,
    plan: &SvmPlanV2,
    profile: &RuntimeProfileV1,
) -> Result<Vec<ProgramImageV2>, OperationalError> {
    let mut program_ids = BTreeSet::new();
    for instruction in &plan.transaction.message.instructions {
        let index = instruction.program_id_index as usize;
        let program_id = *plan
            .transaction
            .message
            .account_keys
            .get(index)
            .ok_or(OperationalError::ImplicitAccountLoadDuringExecution)?;
        if !profile.allowed_ambient_programs.contains(&program_id) {
            // The same program may legitimately appear in several instructions;
            // the set is an execution dependency set, not a program witness.
            program_ids.insert(program_id);
        }
    }

    let mut images = Vec::with_capacity(program_ids.len());
    for program_id in program_ids {
        let program = snapshot
            .accounts
            .iter()
            .find(|account| account.pubkey == program_id)
            .ok_or(OperationalError::ProgramImageUnavailable { program_id })?;
        if !program.executable {
            return Err(OperationalError::ProgramImageUnavailable { program_id });
        }

        let elf = if is_legacy_bpf_loader(&program.owner) {
            program.data.clone()
        } else if program.owner == upgradeable_loader_id() {
            let programdata = parse_upgradeable_program_account(program)
                .ok_or(OperationalError::ProgramImageUnavailable { program_id })?;
            let programdata_account = snapshot
                .accounts
                .iter()
                .find(|account| account.pubkey == programdata)
                .ok_or(OperationalError::ProgramDataMissing {
                    program_id,
                    programdata,
                })?;
            if programdata_account.owner != upgradeable_loader_id()
                || programdata_account.data.len() < 45
                || programdata_account.data[..4] != 3u32.to_le_bytes()
            {
                return Err(OperationalError::ProgramDataMissing {
                    program_id,
                    programdata,
                });
            }
            programdata_account.data[45..].to_vec()
        } else {
            return Err(OperationalError::ProgramImageUnavailable { program_id });
        };
        images.push(ProgramImageV2 { program_id, elf });
    }
    Ok(images)
}

/// Deterministically replay a signed transaction against a closed compact
/// witness. Checkpoint validation is deliberately upstream: callers must only
/// construct `snapshot` from a verified V2 Bank snapshot.
pub fn replay(
    anchor: &SvmAnchorV2,
    snapshot: &PrestateSnapshotV2,
    profile: &RuntimeProfileV1,
    plan: &SvmPlanV2,
    predicate: &PredicateV1,
    commitments: &ReexecCommitmentsV1,
) -> Result<ReplayOutcome, OperationalError> {
    if anchor.snapshot_format_version != SNAPSHOT_FORMAT_V2 {
        return Err(OperationalError::UnsupportedSnapshotFormat {
            got: anchor.snapshot_format_version,
        });
    }
    let profile_hash = runtime_profile_hash(profile)?;
    if profile_hash != anchor.runtime_profile_hash {
        return Err(OperationalError::RuntimeProfileMismatch {
            expected: anchor.runtime_profile_hash,
            got: profile_hash,
        });
    }
    let got = snapshot_commitment(snapshot, profile)?;
    if got != anchor.state_commitment {
        return Err(OperationalError::PrestateCommitmentMismatch {
            expected: anchor.state_commitment,
            got,
        });
    }
    // Snapshot authenticity: when the anchor asserts a complete account set, the
    // committed accounts must reproduce the block's `bank_hash` under the accounts
    // lattice hash. This makes `bank_hash` load-bearing rather than decorative. A
    // compact per-tx prestate leaves `snapshot_is_complete` false and binds to a
    // separately-verified archive (see `docs/svm-snapshot-authenticity.md`).
    if anchor.snapshot_is_complete {
        let preimage = bankhash::BankHashPreimageV1 {
            parent_bank_hash: anchor.parent_bank_hash,
            signature_count: anchor.signature_count,
            last_blockhash: anchor.blockhash,
        };
        bankhash::verify_snapshot_against_bank_hash(snapshot, &preimage, anchor.bank_hash).map_err(
            |e| OperationalError::BankHashMismatch {
                expected: e.expected,
                got: e.got,
            },
        )?;
    }
    let plan_blockhash = B256::from_slice(plan.transaction.message.recent_blockhash.as_ref());
    if plan_blockhash != anchor.blockhash {
        return Err(OperationalError::BlockhashMismatch {
            expected: anchor.blockhash,
            got: plan_blockhash,
        });
    }

    reject_unsupported_environment_dependencies(plan)?;
    ensure_closed_message_accounts(snapshot, profile, plan)?;
    // Every predicate-read account must be present in the committed snapshot, so
    // a missing account is an operational error rather than a spurious refund.
    let predicate_account = match predicate {
        PredicateV1::LamportsEquals { account, .. } => Some(account),
        PredicateV1::LamportsBounded { account, .. } => Some(account),
        PredicateV1::LamportsDelta { account, .. } => Some(account),
        PredicateV1::ResultEquals { .. } => None,
    };
    if let Some(account) = predicate_account {
        if !snapshot
            .accounts
            .iter()
            .any(|entry| entry.pubkey == *account)
        {
            return Err(OperationalError::MissingPredicateAccount { account: *account });
        }
    }

    // Signer bits are authority in the SVM. Unlike a blockhash liveness check,
    // this validation is part of the adjudicated transaction semantics.
    if plan.transaction.verify().is_err() {
        return Ok(outcome(
            anchor,
            commitments,
            Verdict::Failed(FailReason::InvalidAuthorization),
            Vec::new(),
        ));
    }

    let images = derive_program_images(snapshot, plan, profile)?;
    // The closed profile currently permits only the System builtin. This makes
    // direct Clock/Rent/sysvar syscalls impossible until the checkpoint runtime
    // environment is reconstructed rather than inherited from LiteSVM::new().
    if !images.is_empty() {
        return Err(OperationalError::UnsupportedEnvironmentDependency {
            dependency: "custom SBF program",
        });
    }

    let mut svm = LiteSVM::new()
        .with_sigverify(true)
        // The message blockhash is bound to `anchor.blockhash`, but replay is not
        // a mempool-admissibility test, so age/liveness remains disabled.
        .with_blockhash_check(false)
        .with_account_load_policy(AccountLoadPolicy::RejectUnseeded);

    for account in &snapshot.accounts {
        // Custom executable accounts are rejected above. Avoid populating an
        // ambient cache from unused executable accounts.
        if account.executable {
            continue;
        }
        svm.set_account(
            account.pubkey,
            Account {
                lamports: account.lamports,
                data: account.data.clone(),
                owner: account.owner,
                executable: account.executable,
                rent_epoch: account.rent_epoch,
            },
        )
        .map_err(|_| OperationalError::AccountLoad {
            account: account.pubkey,
        })?;
    }

    let return_data = match svm.send_transaction(plan.transaction.clone()) {
        Ok(meta) => meta.return_data.data,
        Err(failure) => {
            if matches!(
                failure.err,
                solana_transaction_error::TransactionError::AccountNotFound
            ) {
                return Err(OperationalError::ImplicitAccountLoadDuringExecution);
            }
            return Ok(outcome(
                anchor,
                commitments,
                Verdict::Failed(FailReason::Execution),
                Vec::new(),
            ));
        }
    };

    let result_hash = result_content_hash(SVM_RETURN_TAG, &return_data);
    let verdict = match predicate {
        PredicateV1::ResultEquals {
            expected_result_hash,
        } => {
            if result_hash == *expected_result_hash {
                Verdict::Reproduced
            } else {
                Verdict::Failed(FailReason::ResultMismatch)
            }
        }
        PredicateV1::LamportsEquals { account, expected } => {
            let poststate = svm
                .get_account(account)
                .ok_or(OperationalError::MissingPoststateAccount { account: *account })?;
            if poststate.lamports == *expected {
                Verdict::Reproduced
            } else {
                Verdict::Failed(FailReason::LamportsMismatch {
                    account: *account,
                    got: poststate.lamports,
                    expected: *expected,
                })
            }
        }
        PredicateV1::LamportsBounded { account, min, max } => {
            let poststate = svm
                .get_account(account)
                .ok_or(OperationalError::MissingPoststateAccount { account: *account })?;
            if poststate.lamports >= *min && poststate.lamports <= *max {
                Verdict::Reproduced
            } else {
                Verdict::Failed(FailReason::LamportsOutOfBounds {
                    account: *account,
                    got: poststate.lamports,
                    min: *min,
                    max: *max,
                })
            }
        }
        PredicateV1::LamportsDelta { account, min, max } => {
            // `pre` is the committed snapshot balance; `post` is what the
            // authenticated transaction settled it to. The adjudicated quantity
            // is the credited increase `post - pre` (saturating: a decrease is 0,
            // never a wrap), so a transaction that fails to move the account
            // cannot satisfy any `min > 0` — the causal analogue of the EVM
            // `PostStateDelta`.
            let pre = snapshot
                .accounts
                .iter()
                .find(|entry| entry.pubkey == *account)
                .map(|entry| entry.lamports)
                .ok_or(OperationalError::MissingPredicateAccount { account: *account })?;
            let poststate = svm
                .get_account(account)
                .ok_or(OperationalError::MissingPoststateAccount { account: *account })?;
            let delta = poststate.lamports.saturating_sub(pre);
            if delta >= *min && delta <= *max {
                Verdict::Reproduced
            } else {
                Verdict::Failed(FailReason::LamportsDeltaOutOfBounds {
                    account: *account,
                    pre,
                    post: poststate.lamports,
                    delta,
                    min: *min,
                    max: *max,
                })
            }
        }
    };
    Ok(outcome(anchor, commitments, verdict, return_data))
}

fn outcome(
    anchor: &SvmAnchorV2,
    commitments: &ReexecCommitmentsV1,
    verdict: Verdict,
    return_data: Vec<u8>,
) -> ReplayOutcome {
    let result_hash = result_content_hash(SVM_RETURN_TAG, &return_data);
    let outcome_code = match verdict {
        Verdict::Reproduced => 1u8,
        Verdict::Failed(_) => 2u8,
    };
    let record = ReplayRecordV1::new(
        commitments,
        anchor.state_commitment,
        outcome_code,
        result_hash,
    );
    let trace_hash = record.trace_hash();
    ReplayOutcome {
        verdict,
        result_hash,
        prestate_root: anchor.state_commitment,
        trace_hash,
        record,
        return_data,
    }
}

fn ensure_closed_message_accounts(
    snapshot: &PrestateSnapshotV2,
    profile: &RuntimeProfileV1,
    plan: &SvmPlanV2,
) -> Result<(), OperationalError> {
    for account in &plan.transaction.message.account_keys {
        if snapshot
            .accounts
            .iter()
            .any(|entry| entry.pubkey == *account)
            || profile.allowed_ambient_programs.contains(account)
        {
            continue;
        }
        return Err(OperationalError::ImplicitAccountLoad { account: *account });
    }
    Ok(())
}

fn reject_unsupported_environment_dependencies(plan: &SvmPlanV2) -> Result<(), OperationalError> {
    if plan
        .transaction
        .message
        .account_keys
        .iter()
        .any(is_known_sysvar)
    {
        return Err(OperationalError::UnsupportedEnvironmentDependency {
            dependency: "sysvar account",
        });
    }
    for instruction in &plan.transaction.message.instructions {
        let program = plan.transaction.message.account_keys[instruction.program_id_index as usize];
        // SystemInstruction::AdvanceNonceAccount is discriminant 4 (little
        // endian); durable nonce needs a connected blockhash/sysvar witness.
        if program == system_program_id()
            && instruction.data.len() >= 4
            && instruction.data[..4] == 4u32.to_le_bytes()
        {
            return Err(OperationalError::UnsupportedEnvironmentDependency {
                dependency: "durable nonce",
            });
        }
    }
    Ok(())
}

fn parse_upgradeable_program_account(account: &AccountSnapshotV2) -> Option<Pubkey> {
    if account.data.len() != 36 || account.data[..4] != 2u32.to_le_bytes() {
        return None;
    }
    let mut bytes = [0u8; 32];
    bytes.copy_from_slice(&account.data[4..36]);
    Some(Pubkey::new_from_array(bytes))
}

fn is_legacy_bpf_loader(owner: &Pubkey) -> bool {
    *owner == parse_pubkey("BPFLoader2111111111111111111111111111111111")
        || *owner == parse_pubkey("BPFLoader1111111111111111111111111111111111")
}

fn upgradeable_loader_id() -> Pubkey {
    parse_pubkey("BPFLoaderUpgradeab1e11111111111111111111111")
}

fn system_program_id() -> Pubkey {
    Pubkey::default()
}

fn is_known_sysvar(id: &Pubkey) -> bool {
    [
        "SysvarC1ock11111111111111111111111111111111",
        "SysvarEpochSchedu1e111111111111111111111111",
        "SysvarFees111111111111111111111111111111111",
        "Sysvar1nstructions1111111111111111111111111",
        "SysvarRecentB1ockHashes11111111111111111111",
        "SysvarRent111111111111111111111111111111111",
        "SysvarS1otHashes111111111111111111111111111",
        "SysvarS1otHistory11111111111111111111111111",
        "SysvarStakeHistory1111111111111111111111111",
    ]
    .iter()
    .any(|value| *id == parse_pubkey(value))
}

fn parse_pubkey(value: &str) -> Pubkey {
    Pubkey::from_str(value).expect("static Solana program/sysvar id is valid")
}

fn hash_u16(hasher: &mut Sha256, value: u16) {
    hasher.update(value.to_be_bytes());
}

fn hash_u64(hasher: &mut Sha256, value: u64) {
    hasher.update(value.to_be_bytes());
}

fn hash_bool(hasher: &mut Sha256, value: bool) {
    hasher.update([u8::from(value)]);
}

fn hash_bytes(hasher: &mut Sha256, value: &[u8]) {
    hash_u64(hasher, value.len() as u64);
    hasher.update(value);
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_instruction::{AccountMeta, Instruction};
    use solana_keypair::Keypair;
    use solana_signer::Signer;

    const SYSTEM_PROGRAM: Pubkey = Pubkey::new_from_array([0u8; 32]);

    fn system_transfer(from: &Pubkey, to: &Pubkey, lamports: u64) -> Instruction {
        let mut data = 2u32.to_le_bytes().to_vec();
        data.extend_from_slice(&lamports.to_le_bytes());
        Instruction {
            program_id: SYSTEM_PROGRAM,
            accounts: vec![AccountMeta::new(*from, true), AccountMeta::new(*to, false)],
            data,
        }
    }

    fn system_assign(account: &Pubkey) -> Instruction {
        let mut data = 1u32.to_le_bytes().to_vec();
        data.extend_from_slice(SYSTEM_PROGRAM.as_ref());
        Instruction {
            program_id: SYSTEM_PROGRAM,
            accounts: vec![AccountMeta::new(*account, true)],
            data,
        }
    }

    fn account(pubkey: Pubkey, lamports: u64) -> AccountSnapshotV2 {
        AccountSnapshotV2 {
            pubkey,
            lamports,
            owner: SYSTEM_PROGRAM,
            executable: false,
            rent_epoch: u64::MAX,
            data: vec![],
        }
    }

    fn commitments() -> ReexecCommitmentsV1 {
        ReexecCommitmentsV1 {
            backend_id: B256::from([0x5b; 32]),
            backend_version_hash: B256::from([0x51; 32]),
            spec_hash: B256::from([0x5c; 32]),
            delivery_hash: B256::from([0xde; 32]),
            prestate_anchor_hash: B256::from([0xa0; 32]),
        }
    }

    fn anchor(snapshot: &PrestateSnapshotV2, profile: &RuntimeProfileV1) -> SvmAnchorV2 {
        SvmAnchorV2 {
            state_commitment: snapshot_commitment(snapshot, profile).unwrap(),
            cluster_genesis_hash: B256::from([0x11; 32]),
            slot: 250_000_000,
            blockhash: B256::ZERO,
            bank_hash: B256::from([0x22; 32]),
            // Compact fixture snapshot: authenticity binds via the archive, not an
            // in-replay lattice recompute, so the complete-snapshot gate is off.
            parent_bank_hash: B256::ZERO,
            signature_count: 0,
            snapshot_is_complete: false,
            runtime_profile_hash: runtime_profile_hash(profile).unwrap(),
            snapshot_archive_hash: B256::from([0x33; 32]),
            snapshot_format_version: SNAPSHOT_FORMAT_V2,
        }
    }

    fn signed_plan(from: &Keypair, instructions: &[Instruction]) -> SvmPlanV2 {
        let mut transaction = Transaction::new_with_payer(instructions, Some(&from.pubkey()));
        transaction.sign(&[from], Default::default());
        SvmPlanV2 { transaction }
    }

    fn fixture() -> (
        PrestateSnapshotV2,
        RuntimeProfileV1,
        SvmAnchorV2,
        Keypair,
        Pubkey,
    ) {
        let from = Keypair::new();
        let to = Pubkey::new_unique();
        let snapshot = PrestateSnapshotV2 {
            accounts: vec![account(from.pubkey(), 1_000_000_000), account(to, 1)],
        };
        let profile = RuntimeProfileV1::default();
        let anchor = anchor(&snapshot, &profile);
        (snapshot, profile, anchor, from, to)
    }

    #[test]
    fn honest_delivery_reproduces() {
        let (snapshot, profile, anchor, from, to) = fixture();
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 2_000_000)]);
        let out = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 2_000_001,
            },
            &commitments(),
        )
        .unwrap();
        assert!(out.reproduced());
        assert_eq!(out.prestate_root, anchor.state_commitment);
    }

    #[test]
    fn false_claim_fails_and_refunds() {
        let (snapshot, profile, anchor, from, to) = fixture();
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 1_500_000)]);
        let out = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 2_000_001,
            },
            &commitments(),
        )
        .unwrap();
        assert!(matches!(
            out.verdict,
            Verdict::Failed(FailReason::LamportsMismatch { .. })
        ));
    }

    #[test]
    fn lamports_bounded_reproduces_within_range_and_refunds_outside() {
        let (snapshot, profile, anchor, from, to) = fixture();
        // `to` starts at 1 lamport; a 2_000_000 transfer settles it at 2_000_001.
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 2_000_000)]);

        // "received >= minOut": the marquee slippage bound, satisfied here.
        let at_least = PredicateV1::LamportsBounded {
            account: to,
            min: 2_000_000,
            max: u64::MAX,
        };
        let out = replay(&anchor, &snapshot, &profile, &plan, &at_least, &commitments()).unwrap();
        assert!(out.reproduced(), "2_000_001 >= 2_000_000 should reproduce: {:?}", out.verdict);

        // Bound violated: a higher minOut than the real output -> refund the buyer.
        let too_high = PredicateV1::LamportsBounded {
            account: to,
            min: 3_000_000,
            max: u64::MAX,
        };
        let out = replay(&anchor, &snapshot, &profile, &plan, &too_high, &commitments()).unwrap();
        assert_eq!(
            out.verdict,
            Verdict::Failed(FailReason::LamportsOutOfBounds {
                account: to,
                got: 2_000_001,
                min: 3_000_000,
                max: u64::MAX,
            }),
        );

        // Upper-bound form "<= cap" is the same predicate with min = 0.
        let at_most = PredicateV1::LamportsBounded {
            account: to,
            min: 0,
            max: 5_000_000,
        };
        assert!(replay(&anchor, &snapshot, &profile, &plan, &at_most, &commitments())
            .unwrap()
            .reproduced());
    }

    #[test]
    fn lamports_bounded_missing_account_is_operational() {
        let (snapshot, profile, anchor, from, _to) = fixture();
        let absent = Pubkey::new_unique();
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &from.pubkey(), 0)]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsBounded {
                account: absent,
                min: 0,
                max: u64::MAX,
            },
            &commitments(),
        )
        .unwrap_err();
        assert_eq!(
            err,
            OperationalError::MissingPredicateAccount { account: absent }
        );
    }

    // The SVM soundness regression behind `LamportsDelta`: a bound predicate over
    // an account the transaction never moves reads the *prestate* balance, so a
    // cheating seller can satisfy "received >= minOut" with a no-op whenever the
    // account already held it. The delta predicate closes this — the adjudicated
    // quantity is the credited increase the transaction itself produced.
    #[test]
    fn lamports_delta_refuses_the_no_op_prestate_attack() {
        let (snapshot, profile, anchor, from, to) = fixture(); // `to` starts at 1
        // A no-op for `to`: the payer self-transfers 0, so `to` stays at 1.
        let no_op = signed_plan(&from, &[system_transfer(&from.pubkey(), &from.pubkey(), 0)]);

        // Under the *bound* predicate "balance >= 1", the no-op reproduces — the
        // seller is paid for doing nothing. This is the attack delta closes.
        let bound = PredicateV1::LamportsBounded {
            account: to,
            min: 1,
            max: u64::MAX,
        };
        assert!(
            replay(&anchor, &snapshot, &profile, &no_op, &bound, &commitments())
                .unwrap()
                .reproduced(),
            "bound predicate is prestate-satisfiable — the gap delta closes",
        );

        // Under the *delta* predicate "credited >= 1", the no-op yields delta 0
        // (post 1 - pre 1) and is REFUSED.
        let delta = PredicateV1::LamportsDelta {
            account: to,
            min: 1,
            max: u64::MAX,
        };
        assert_eq!(
            replay(&anchor, &snapshot, &profile, &no_op, &delta, &commitments())
                .unwrap()
                .verdict,
            Verdict::Failed(FailReason::LamportsDeltaOutOfBounds {
                account: to,
                pre: 1,
                post: 1,
                delta: 0,
                min: 1,
                max: u64::MAX,
            }),
            "a no-op must not satisfy a causal 'credited >= minOut'",
        );
    }

    // The honest side: a real credit produces a real delta, adjudicated against
    // the funded floor.
    #[test]
    fn lamports_delta_reproduces_for_a_real_credit_and_refunds_a_short_one() {
        let (snapshot, profile, anchor, from, to) = fixture(); // `to` starts at 1
        // Credit `to` 2_000_000 → post 2_000_001, a credited delta of 2_000_000.
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 2_000_000)]);

        let ok = PredicateV1::LamportsDelta {
            account: to,
            min: 2_000_000,
            max: u64::MAX,
        };
        let out = replay(&anchor, &snapshot, &profile, &plan, &ok, &commitments()).unwrap();
        assert!(out.reproduced(), "credited 2_000_000 clears the floor: {:?}", out.verdict);

        // A floor higher than the real credit refunds the buyer.
        let too_high = PredicateV1::LamportsDelta {
            account: to,
            min: 2_000_001,
            max: u64::MAX,
        };
        assert_eq!(
            replay(&anchor, &snapshot, &profile, &plan, &too_high, &commitments())
                .unwrap()
                .verdict,
            Verdict::Failed(FailReason::LamportsDeltaOutOfBounds {
                account: to,
                pre: 1,
                post: 2_000_001,
                delta: 2_000_000,
                min: 2_000_001,
                max: u64::MAX,
            }),
        );
    }

    // The load-bearing flip: when the anchor asserts a complete snapshot, replay
    // recomputes bank_hash from the accounts and an honest one passes the gate,
    // while a tampered committed bank_hash is an operational error — never a
    // verdict. This is the SVM analogue of the EVM witness-vs-state_root check.
    #[test]
    fn complete_snapshot_bank_hash_gate_binds_and_is_operational_on_mismatch() {
        let (snapshot, profile, base, from, to) = fixture();
        let preimage = bankhash::BankHashPreimageV1 {
            parent_bank_hash: B256::from([0x44; 32]),
            signature_count: 3,
            last_blockhash: base.blockhash,
        };
        let honest_bank_hash =
            bankhash::bank_hash(&preimage, &bankhash::accounts_lt_hash(&snapshot).checksum().0);

        let mut anchor = base.clone();
        anchor.snapshot_is_complete = true;
        anchor.parent_bank_hash = preimage.parent_bank_hash;
        anchor.signature_count = preimage.signature_count;
        anchor.bank_hash = honest_bank_hash;

        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 2_000_000)]);
        let predicate = PredicateV1::LamportsEquals {
            account: to,
            expected: 2_000_001,
        };

        // Honest bank_hash: the gate passes and replay yields a normal verdict.
        let out = replay(&anchor, &snapshot, &profile, &plan, &predicate, &commitments()).unwrap();
        assert!(out.reproduced(), "honest complete snapshot must replay: {:?}", out.verdict);

        // A committed bank_hash the accounts do not reproduce: operational error.
        let mut wrong = anchor.clone();
        wrong.bank_hash = B256::from([0xee; 32]);
        assert!(matches!(
            replay(&wrong, &snapshot, &profile, &plan, &predicate, &commitments()),
            Err(OperationalError::BankHashMismatch { expected, .. }) if expected == B256::from([0xee; 32])
        ));

        // A tampered account (same committed bank_hash) also fails the gate — the
        // accounts no longer hash to the block's bank_hash.
        let mut tampered = snapshot.clone();
        tampered.accounts[0].lamports += 1;
        assert!(matches!(
            replay(&anchor, &tampered, &profile, &plan, &predicate, &commitments()),
            Err(OperationalError::PrestateCommitmentMismatch { .. })
                | Err(OperationalError::BankHashMismatch { .. })
        ));
    }

    #[test]
    fn tampered_snapshot_is_operational() {
        let (mut snapshot, profile, anchor, from, to) = fixture();
        snapshot.accounts[0].lamports += 1;
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 1)]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 2,
            },
            &commitments(),
        )
        .unwrap_err();
        assert!(matches!(
            err,
            OperationalError::PrestateCommitmentMismatch { .. }
        ));
    }

    #[test]
    fn rent_epoch_is_committed_not_metadata_outside_the_hash() {
        let (mut snapshot, profile, anchor, from, to) = fixture();
        snapshot.accounts[0].rent_epoch = 0;
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 1)]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 2,
            },
            &commitments(),
        )
        .unwrap_err();
        assert!(matches!(
            err,
            OperationalError::PrestateCommitmentMismatch { .. }
        ));
    }

    #[test]
    fn replay_is_deterministic_and_shares_the_evm_record() {
        let (snapshot, profile, anchor, from, to) = fixture();
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 2_000_000)]);
        let predicate = PredicateV1::LamportsEquals {
            account: to,
            expected: 2_000_001,
        };
        let a = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &predicate,
            &commitments(),
        )
        .unwrap();
        let b = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &predicate,
            &commitments(),
        )
        .unwrap();
        assert_eq!(a.trace_hash, b.trace_hash);
        assert_eq!(a.record.trace_hash(), a.trace_hash);
    }

    #[test]
    fn omitted_message_account_is_operational_before_default_account_exists() {
        let (mut snapshot, profile, _anchor, from, to) = fixture();
        snapshot.accounts.retain(|entry| entry.pubkey != to);
        let anchor = anchor(&snapshot, &profile);
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &to, 1)]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::ResultEquals {
                expected_result_hash: B256::ZERO,
            },
            &commitments(),
        )
        .unwrap_err();
        assert_eq!(err, OperationalError::ImplicitAccountLoad { account: to });
    }

    #[test]
    fn tampered_program_image_is_bound_by_snapshot_commitment() {
        let (mut snapshot, profile, _anchor, _, _) = fixture();
        let program_id = Pubkey::new_unique();
        snapshot.accounts.push(AccountSnapshotV2 {
            pubkey: program_id,
            lamports: 1,
            owner: parse_pubkey("BPFLoader2111111111111111111111111111111111"),
            executable: true,
            rent_epoch: u64::MAX,
            data: vec![0x7f, b'E', b'L', b'F'],
        });
        let anchor = anchor(&snapshot, &profile);
        snapshot.accounts.last_mut().unwrap().data.push(0x01);
        let from = Keypair::new();
        let plan = signed_plan(&from, &[system_transfer(&from.pubkey(), &from.pubkey(), 0)]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::ResultEquals {
                expected_result_hash: B256::ZERO,
            },
            &commitments(),
        )
        .unwrap_err();
        assert!(matches!(
            err,
            OperationalError::PrestateCommitmentMismatch { .. }
        ));
    }

    #[test]
    fn fake_signature_is_a_failed_authorization_not_a_reproduced_replay() {
        let (snapshot, profile, anchor, from, to) = fixture();
        let transaction = Transaction::new_with_payer(
            &[system_transfer(&from.pubkey(), &to, 1)],
            Some(&from.pubkey()),
        );
        let out = replay(
            &anchor,
            &snapshot,
            &profile,
            &SvmPlanV2 { transaction },
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 2,
            },
            &commitments(),
        )
        .unwrap();
        assert_eq!(
            out.verdict,
            Verdict::Failed(FailReason::InvalidAuthorization)
        );
    }

    #[test]
    fn sysvar_dependency_is_operational_until_runtime_reconstruction_exists() {
        let (snapshot, profile, anchor, from, to) = fixture();
        let mut instruction = system_transfer(&from.pubkey(), &to, 1);
        instruction.accounts.push(AccountMeta::new_readonly(
            parse_pubkey("SysvarC1ock11111111111111111111111111111111"),
            false,
        ));
        let plan = signed_plan(&from, &[instruction]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 2,
            },
            &commitments(),
        )
        .unwrap_err();
        assert_eq!(
            err,
            OperationalError::UnsupportedEnvironmentDependency {
                dependency: "sysvar account"
            }
        );
    }

    #[test]
    fn absent_poststate_is_operational_not_zero_lamports() {
        let (mut snapshot, profile, _anchor, from, to) = fixture();
        snapshot
            .accounts
            .iter_mut()
            .find(|entry| entry.pubkey == to)
            .unwrap()
            .lamports = 0;
        let anchor = anchor(&snapshot, &profile);
        let plan = signed_plan(&from, &[system_assign(&from.pubkey())]);
        let err = replay(
            &anchor,
            &snapshot,
            &profile,
            &plan,
            &PredicateV1::LamportsEquals {
                account: to,
                expected: 0,
            },
            &commitments(),
        )
        .unwrap_err();
        assert_eq!(
            err,
            OperationalError::MissingPoststateAccount { account: to }
        );
    }

    #[test]
    fn duplicate_accounts_and_runtime_programs_are_rejected() {
        let (mut snapshot, mut profile, _anchor, _, _) = fixture();
        snapshot.accounts.push(snapshot.accounts[0].clone());
        assert!(matches!(
            snapshot_commitment(&snapshot, &profile),
            Err(OperationalError::DuplicateAccount { .. })
        ));
        profile.allowed_ambient_programs.push(SYSTEM_PROGRAM);
        assert!(matches!(
            runtime_profile_hash(&profile),
            Err(OperationalError::DuplicateProgram { .. })
        ));
    }

    #[test]
    fn derives_upgradeable_program_elf_from_programdata_not_seller_input() {
        let (mut snapshot, profile, _anchor, payer, _) = fixture();
        let program_id = Pubkey::new_unique();
        let programdata_id = Pubkey::new_unique();
        let mut program_data = 2u32.to_le_bytes().to_vec();
        program_data.extend_from_slice(programdata_id.as_ref());
        snapshot.accounts.push(AccountSnapshotV2 {
            pubkey: program_id,
            lamports: 1,
            owner: upgradeable_loader_id(),
            executable: true,
            rent_epoch: u64::MAX,
            data: program_data,
        });
        let elf = vec![0x7f, b'E', b'L', b'F', 0x01];
        let mut programdata = 3u32.to_le_bytes().to_vec();
        // `UpgradeableLoaderState::ProgramData` metadata is 45 bytes. The
        // parser only needs the discriminant; reserve the canonical metadata
        // extent before appending the ELF.
        programdata.resize(45, 0);
        programdata.extend_from_slice(&elf);
        snapshot.accounts.push(AccountSnapshotV2 {
            pubkey: programdata_id,
            lamports: 1,
            owner: upgradeable_loader_id(),
            executable: false,
            rent_epoch: u64::MAX,
            data: programdata,
        });
        let plan = signed_plan(
            &payer,
            &[Instruction {
                program_id,
                accounts: vec![],
                data: vec![],
            }],
        );
        assert_eq!(
            derive_program_images(&snapshot, &plan, &profile).unwrap(),
            vec![ProgramImageV2 { program_id, elf }]
        );
    }

    #[test]
    fn non_system_ambient_program_is_rejected_not_inherited_from_litesvm() {
        let profile = RuntimeProfileV1 {
            allowed_ambient_programs: vec![system_program_id(), Pubkey::new_unique()],
        };
        assert_eq!(
            runtime_profile_hash(&profile),
            Err(OperationalError::UnsupportedEnvironmentDependency {
                dependency: "unverified ambient program"
            })
        );
    }
}

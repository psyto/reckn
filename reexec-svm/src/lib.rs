//! Reckn Solana (SVM) re-execution backend.
//!
//! The Solana analog of `reexec-evm`: given a committed anchor (a slot + a
//! state commitment), a committed account snapshot, a seller-supplied
//! transaction, and a buyer-funded predicate, it deterministically replays the
//! transaction with `LiteSVM` and returns a reproducible verdict. Crucially it
//! emits the **same** canonical [`ReplayRecordV1`] as the EVM backend (from the
//! shared `reckn-record` crate), so a Solana verdict and an EVM verdict are
//! comparable and reproducible under one VM-neutral envelope — the foundation the
//! cross-VM binder will stand on.
//!
//! ## Trust tier — read before using a verdict
//!
//! This scaffold is **authenticity tier V1: "same published snapshot → same
//! result"**. A `Reproduced` here means *anyone with this exact snapshot re-runs
//! the plan and gets this verdict* — it is NOT proof the snapshot was Solana's
//! real state, and it MUST NOT be an automatic escrow-release basis. Solana has
//! no EVM-style Merkle-Patricia proof of an account against a single state root;
//! reaching auto-resolve needs V2 (a finalized-checkpoint-authenticated full Bank
//! snapshot whose protocol accounts/bank hash is recomputed). See
//! `docs/roadmap-crossvm.md` Act 2.
//!
//! Known V1 gaps (flagged for the frame-thick hardening, not yet fixed here):
//! - [`snapshot_commitment`] hashes accounts but NOT `programs` or `rent_epoch`,
//!   so a seller-supplied ELF is not bound to the anchor.
//! - `LiteSVM::new()` loads *unseeded* accounts as default/zero, so this is NOT a
//!   closed world: an unwitnessed read does not trap. The ambient feature set,
//!   sysvars, builtins, and standard program cache are also implicit inputs, and
//!   `anchor.slot` does not constrain the runtime `Clock`.
//! - `replay` runs with `sigverify` OFF, which on Solana forges *authority* (the
//!   signer bit programs observe) — unlike EVM base-fee/nonce, this is unsound for
//!   settlement. V2 must commit signed transaction bytes and verify signatures.
//!
//! In short: reproducible, but not yet authentic. The tests below exercise the
//! replay/record path, not a settlement-grade trust boundary.

use alloy_primitives::B256;
use litesvm::LiteSVM;
use reckn_record::{result_content_hash, ReexecCommitmentsV1, ReplayRecordV1};
use sha2::{Digest, Sha256};
use solana_account::Account;
use solana_pubkey::Pubkey;
use solana_transaction::Transaction;

const SVM_RETURN_TAG: &[u8] = b"svm-return-data";

/// Committed block environment: a slot and a 32-byte commitment the snapshot must
/// hash to. (`state_commitment` is the SVM analog of the EVM `state_root`.)
#[derive(Clone, Debug)]
pub struct SvmAnchorV1 {
    pub slot: u64,
    pub state_commitment: B256,
}

/// One committed account in the prestate.
#[derive(Clone, Debug)]
pub struct AccountSnapshotV1 {
    pub pubkey: Pubkey,
    pub lamports: u64,
    pub owner: Pubkey,
    pub executable: bool,
    pub rent_epoch: u64,
    pub data: Vec<u8>,
}

/// The committed prestate. V1 trusts these bytes but binds them to the anchor.
#[derive(Clone, Debug, Default)]
pub struct PrestateSnapshotV1 {
    pub accounts: Vec<AccountSnapshotV1>,
    /// Loadable BPF programs `(program_id, elf)` the transaction invokes. The
    /// builtin System program is always available and need not be listed.
    pub programs: Vec<(Pubkey, Vec<u8>)>,
}

/// A fully specified, committed transaction supplied by the seller.
#[derive(Clone, Debug)]
pub struct SvmPlanV1 {
    pub transaction: Transaction,
}

/// The buyer-funded predicate. Fixed at funding; the seller cannot change it.
#[derive(Clone, Debug)]
pub enum PredicateV1 {
    /// `SHA-256("reckn/v1/" || "svm-return-data" || returnData)` equals this.
    ResultEquals { expected_result_hash: B256 },
    /// The account's post-replay lamports must equal `expected` (post-state check).
    LamportsEquals { account: Pubkey, expected: u64 },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum FailReason {
    /// The transaction failed (revert/error).
    Execution,
    ResultMismatch,
    LamportsMismatch {
        account: Pubkey,
        got: u64,
        expected: u64,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Verdict {
    Reproduced,
    Failed(FailReason),
}

/// Not a buyer/seller verdict — the backend lacks an authentic, complete prestate.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OperationalError {
    /// The snapshot does not hash to the committed `anchor.state_commitment`.
    PrestateCommitmentMismatch { expected: B256, got: B256 },
    /// The predicate references an account absent from the committed snapshot.
    MissingPredicateAccount { account: Pubkey },
    /// Seeding a committed account into the VM failed.
    AccountLoad,
    /// Loading a committed program into the VM failed.
    ProgramLoad,
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

/// Canonical SHA-256 commitment over the account snapshot: accounts sorted by
/// pubkey, each folded in as `pubkey || lamports || owner || executable ||
/// len(data) || data`. Deterministic, but V1-incomplete: it does NOT yet cover
/// `programs`, `rent_epoch`, or the runtime profile, so it is not fully
/// tamper-evident (see the crate-level trust-tier note). The hardened,
/// length-prefixed, everything-covering codec is the frame-thick next step.
pub fn snapshot_commitment(snapshot: &PrestateSnapshotV1) -> B256 {
    let mut accounts: Vec<&AccountSnapshotV1> = snapshot.accounts.iter().collect();
    accounts.sort_by_key(|a| a.pubkey.to_bytes());
    let mut h = Sha256::new();
    h.update(b"reckn/v1/svm-prestate");
    for a in accounts {
        h.update(a.pubkey.to_bytes());
        h.update(a.lamports.to_be_bytes());
        h.update(a.owner.to_bytes());
        h.update([a.executable as u8]);
        h.update((a.data.len() as u64).to_be_bytes());
        h.update(&a.data);
    }
    B256::from_slice(&h.finalize())
}

/// Deterministically replay `plan` against `snapshot` under `anchor`, then judge
/// it with `predicate`, emitting the shared canonical record.
pub fn replay(
    anchor: &SvmAnchorV1,
    snapshot: &PrestateSnapshotV1,
    plan: &SvmPlanV1,
    predicate: &PredicateV1,
    commitments: &ReexecCommitmentsV1,
) -> Result<ReplayOutcome, OperationalError> {
    // 1. Bind the snapshot to the committed anchor (prestate authenticity, V1).
    let got = snapshot_commitment(snapshot);
    if got != anchor.state_commitment {
        return Err(OperationalError::PrestateCommitmentMismatch {
            expected: anchor.state_commitment,
            got,
        });
    }

    // Predicate accounts must be part of the committed prestate.
    if let PredicateV1::LamportsEquals { account, .. } = predicate {
        if !snapshot.accounts.iter().any(|a| &a.pubkey == account) {
            return Err(OperationalError::MissingPredicateAccount { account: *account });
        }
    }

    // 2. Build a VM seeded only from the committed snapshot. Re-execution judges
    //    whether the plan produces the funded predicate, not whether it is a valid
    //    fee-paying, correctly-blockhashed transaction — so signature and blockhash
    //    checks are off (the SVM analog of ignoring EVM base-fee/nonce).
    let mut svm = LiteSVM::new()
        .with_sigverify(false)
        .with_blockhash_check(false);
    for a in &snapshot.accounts {
        let account = Account {
            lamports: a.lamports,
            data: a.data.clone(),
            owner: a.owner,
            executable: a.executable,
            rent_epoch: a.rent_epoch,
        };
        svm.set_account(a.pubkey, account)
            .map_err(|_| OperationalError::AccountLoad)?;
    }
    for (program_id, elf) in &snapshot.programs {
        svm.add_program(*program_id, elf)
            .map_err(|_| OperationalError::ProgramLoad)?;
    }

    // 3. Execute exactly the committed transaction.
    let (return_data, exec_ok) = match svm.send_transaction(plan.transaction.clone()) {
        Ok(meta) => (meta.return_data.data, true),
        Err(_) => (Vec::new(), false),
    };
    let result_hash = result_content_hash(SVM_RETURN_TAG, &return_data);

    // 4. Judge.
    let verdict = if !exec_ok {
        Verdict::Failed(FailReason::Execution)
    } else {
        match predicate {
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
                let got = svm.get_account(account).map(|a| a.lamports).unwrap_or(0);
                if got == *expected {
                    Verdict::Reproduced
                } else {
                    Verdict::Failed(FailReason::LamportsMismatch {
                        account: *account,
                        got,
                        expected: *expected,
                    })
                }
            }
        }
    };

    let outcome_code = match verdict {
        Verdict::Reproduced => 1u8,
        Verdict::Failed(_) => 2u8,
    };
    let record = ReplayRecordV1::new(commitments, anchor.state_commitment, outcome_code, result_hash);
    let trace_hash = record.trace_hash();

    Ok(ReplayOutcome {
        verdict,
        result_hash,
        prestate_root: anchor.state_commitment,
        trace_hash,
        record,
        return_data,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_instruction::{AccountMeta, Instruction};
    use solana_keypair::Keypair;
    use solana_signer::Signer;

    // The System program id is the all-zero pubkey; it is a LiteSVM builtin.
    const SYSTEM_PROGRAM: Pubkey = Pubkey::new_from_array([0u8; 32]);

    fn system_transfer(from: &Pubkey, to: &Pubkey, lamports: u64) -> Instruction {
        let mut data = vec![2u8, 0, 0, 0]; // SystemInstruction::Transfer discriminant
        data.extend_from_slice(&lamports.to_le_bytes());
        Instruction {
            program_id: SYSTEM_PROGRAM,
            accounts: vec![AccountMeta::new(*from, true), AccountMeta::new(*to, false)],
            data,
        }
    }

    fn eoa(pubkey: Pubkey, lamports: u64) -> AccountSnapshotV1 {
        AccountSnapshotV1 {
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
            backend_id: B256::from([0x5b; 32]), // 'svm'-ish
            backend_version_hash: B256::from([0x51; 32]),
            spec_hash: B256::from([0x5c; 32]),
            delivery_hash: B256::from([0xde; 32]),
            prestate_anchor_hash: B256::from([0xa0; 32]),
        }
    }

    /// Build the (snapshot, anchor, from-keypair, to-pubkey) fixture: a funded
    /// payer and an empty recipient, committed and bound to the anchor.
    fn fixture() -> (PrestateSnapshotV1, SvmAnchorV1, Keypair, Pubkey) {
        let from = Keypair::new();
        let to = Pubkey::new_unique();
        let snapshot = PrestateSnapshotV1 {
            accounts: vec![
                eoa(from.pubkey(), 1_000_000_000), // 1 SOL payer
                eoa(to, 0),
            ],
            programs: vec![],
        };
        let anchor = SvmAnchorV1 {
            slot: 250_000_000,
            state_commitment: snapshot_commitment(&snapshot),
        };
        (snapshot, anchor, from, to)
    }

    fn transfer_plan(from: &Keypair, to: &Pubkey, lamports: u64) -> SvmPlanV1 {
        let ix = system_transfer(&from.pubkey(), to, lamports);
        // sigverify/blockhash are off in replay, so any well-formed tx executes.
        let tx = Transaction::new_with_payer(&[ix], Some(&from.pubkey()));
        SvmPlanV1 { transaction: tx }
    }

    #[test]
    fn honest_delivery_reproduces() {
        let (snapshot, anchor, from, to) = fixture();
        // Buyer funds: "the recipient must hold exactly 2,000,000 lamports".
        let predicate = PredicateV1::LamportsEquals {
            account: to,
            expected: 2_000_000,
        };
        // Honest seller: a plan that actually transfers 2,000,000.
        let plan = transfer_plan(&from, &to, 2_000_000);
        let out = replay(&anchor, &snapshot, &plan, &predicate, &commitments()).unwrap();
        assert!(out.reproduced(), "honest plan should reproduce: {:?}", out.verdict);
        assert_eq!(out.prestate_root, anchor.state_commitment);
    }

    #[test]
    fn false_claim_fails_and_refunds() {
        let (snapshot, anchor, from, to) = fixture();
        // Same funded predicate: recipient must end with 2,000,000.
        let predicate = PredicateV1::LamportsEquals {
            account: to,
            expected: 2_000_000,
        };
        // Cheating seller: claims success but the plan only transfers 1,500,000.
        let plan = transfer_plan(&from, &to, 1_500_000);
        let out = replay(&anchor, &snapshot, &plan, &predicate, &commitments()).unwrap();
        assert_eq!(
            out.verdict,
            Verdict::Failed(FailReason::LamportsMismatch {
                account: to,
                got: 1_500_000,
                expected: 2_000_000,
            }),
            "false claim must fail -> refund",
        );
    }

    #[test]
    fn tampered_snapshot_is_operational() {
        let (mut snapshot, anchor, from, to) = fixture();
        // Attacker inflates the payer's balance after the anchor was committed.
        snapshot.accounts[0].lamports += 1;
        let predicate = PredicateV1::LamportsEquals {
            account: to,
            expected: 2_000_000,
        };
        let plan = transfer_plan(&from, &to, 2_000_000);
        let err = replay(&anchor, &snapshot, &plan, &predicate, &commitments()).unwrap_err();
        assert!(matches!(
            err,
            OperationalError::PrestateCommitmentMismatch { .. }
        ));
    }

    #[test]
    fn replay_is_deterministic_and_shares_the_evm_record() {
        let (snapshot, anchor, from, to) = fixture();
        let predicate = PredicateV1::LamportsEquals {
            account: to,
            expected: 2_000_000,
        };
        let plan = transfer_plan(&from, &to, 2_000_000);
        let a = replay(&anchor, &snapshot, &plan, &predicate, &commitments()).unwrap();
        let b = replay(&anchor, &snapshot, &plan, &predicate, &commitments()).unwrap();
        assert_eq!(a.trace_hash, b.trace_hash);
        // The record is the shared VM-neutral ReplayRecordV1: its trace hash is the
        // SHA-256 of the same canonical TLV the EVM backend emits.
        assert_eq!(a.record.trace_hash(), a.trace_hash);
    }
}

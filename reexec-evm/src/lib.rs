//! Reckn EVM V1 re-execution backend.
//!
//! Given a committed anchor (block environment + state root), a committed
//! prestate witness (accounts / code / storage), a seller-supplied CALL plan,
//! and a buyer-funded predicate, this crate deterministically replays the plan
//! with `revm` and returns a reproducible verdict: **Reproduced** or **Failed**.
//!
//! Determinism contract (mirrors `docs/protocol-architecture.md`):
//! - No RPC, no `latest`, no wall clock, no randomness, no mutable feeds. Every
//!   input is committed bytes; the state DB is seeded only from the witness.
//! - Anyone with the same anchor + witness + plan + predicate derives the same
//!   verdict and the same `result_hash`.
//!
//! Prestate authenticity contract:
//! - `replay` verifies every account / code / storage proof against the committed
//!   `anchor.state_root` before it constructs the revm database.
//! - Verification failure and an incomplete witness are operational errors, never
//!   `Failed` verdicts. The settlement protocol's resolve timeout handles them.
//! - The database is closed over verified witness entries: an EVM read outside
//!   the witness is an operational error, not an implicit zero/default value.

use alloy_trie::proof::verify_proof;
use alloy_trie::{Nibbles, TrieAccount};
use revm::context::result::{EVMError, ExecutionResult, Output};
use revm::context::TxEnv;
use revm::database::Database;
use revm::primitives::hardfork::SpecId;
use revm::primitives::{keccak256, Address, Bytes, TxKind, B256, U256};
use revm::state::{AccountInfo, Bytecode};
use revm::{Context, ExecuteEvm, MainBuilder, MainContext};
use std::collections::HashMap;
use std::fmt;

/// Committed block environment. In production every field is part of the anchor
/// descriptor the buyer publishes at funding; `state_root` is what the witness
/// must be proven against.
#[derive(Clone, Debug)]
pub struct EvmAnchorV1 {
    pub chain_id: u64,
    pub block_number: u64,
    /// Header hash for the committed snapshot. V1.1 binds this field to the
    /// anchor bytes; BLOCKHASH opcode witnesses remain deliberately unsupported
    /// until connected-header verification is introduced.
    pub block_hash: B256,
    pub state_root: B256,
    pub timestamp: u64,
    pub base_fee: u64,
    pub block_gas_limit: u64,
    pub coinbase: Address,
    pub prevrandao: B256,
    pub spec_id: SpecId,
}

/// One committed account in the prestate.
#[derive(Clone, Debug)]
pub struct AccountWitness {
    pub address: Address,
    pub balance: U256,
    pub nonce: u64,
    /// Proven account storage root, decoded from the state-trie account leaf.
    pub storage_root: B256,
    /// Must equal `keccak256(code)` and the code hash in the proven account.
    pub code_hash: B256,
    /// Runtime code; empty for an EOA.
    pub code: Bytes,
    /// Raw RLP nodes for the secure state-trie proof at `keccak256(address)`.
    pub account_proof: Vec<Bytes>,
    /// Committed storage slots with proofs at `keccak256(slot)`.
    pub storage: Vec<StorageWitnessV1>,
}

/// A storage value and raw RLP nodes proving it under an account storage root.
/// A zero value is represented by an exclusion proof (`expected_value = None`),
/// as canonical Ethereum storage tries do not retain zero-valued leaves.
#[derive(Clone, Debug)]
pub struct StorageWitnessV1 {
    pub slot: U256,
    pub value: U256,
    pub proof: Vec<Bytes>,
}

/// The committed, proof-carrying prestate.
#[derive(Clone, Debug, Default)]
pub struct PrestateWitnessV1 {
    pub accounts: Vec<AccountWitness>,
}

/// A fully specified `CALL` supplied by the seller inside `DeliveryV1`.
#[derive(Clone, Debug)]
pub struct EvmCallPlanV1 {
    pub caller: Address,
    pub target: Address,
    pub calldata: Bytes,
    pub value: U256,
    pub gas_limit: u64,
}

// The canonical VM-neutral record + commitments live in the shared `reckn-record`
// crate, so this EVM backend and the Solana backend emit byte-identical records
// and trace hashes. Re-exported for this crate's public API.
pub use reckn_record::{ReexecCommitmentsV1, ReplayRecordV1};

/// EVM `result_hash`: the cross-VM SHA-256 content hash of the CALL return data,
/// namespaced `"evm-return-data"`. The EVM-native keccak digest stays an internal
/// predicate input and is never overloaded as this commitment.
pub fn evm_result_content_hash(return_data: &[u8]) -> B256 {
    reckn_record::result_content_hash(b"evm-return-data", return_data)
}

/// The buyer-funded predicate. Fixed at funding; the seller cannot change it.
#[derive(Clone, Debug)]
pub enum PredicateV1 {
    /// `keccak256(returnData)` must equal this hash.
    ResultEquals { expected_result_hash: B256 },
    /// Ordered post-state checks: each `(address, slot)` must hold `expected`.
    PostStateEquals { checks: Vec<(Address, U256, U256)> },
}

/// Why a replay did not reproduce the funded predicate. All are deterministic.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum FailReason {
    /// The CALL reverted or halted.
    Execution,
    /// `keccak256(returnData)` did not match `ResultEquals`.
    ResultMismatch,
    /// A `PostStateEquals` slot did not hold the expected word.
    PostStateMismatch {
        address: Address,
        slot: U256,
        got: U256,
        expected: U256,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Verdict {
    Reproduced,
    Failed(FailReason),
}

/// The reproducible result of a replay. `trace_hash` is the SHA-256 of the
/// canonical [`ReplayRecordV1`]; the TLV encoding is specified in
/// `packages/protocol/REPLAY_RECORD_V1.md` (shared across VMs).
#[derive(Clone, Debug)]
pub struct ReplayOutcome {
    pub verdict: Verdict,
    pub result_hash: B256,
    pub prestate_root: B256,
    /// SHA-256 of `record` (the canonical ReplayRecordV1).
    pub trace_hash: B256,
    pub record: ReplayRecordV1,
    pub return_data: Bytes,
    pub gas_used: u64,
}

impl ReplayOutcome {
    pub fn reproduced(&self) -> bool {
        self.verdict == Verdict::Reproduced
    }
}

/// Witness verification failures are not buyer/seller performance verdicts.
/// They mean that the backend lacks an authentic, complete prestate.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WitnessVerificationError {
    DuplicateAccount {
        address: Address,
    },
    EmptyAccountProof {
        address: Address,
    },
    AccountProofMismatch {
        address: Address,
    },
    CodeHashMismatch {
        address: Address,
        expected: B256,
        got: B256,
    },
    DuplicateStorageSlot {
        address: Address,
        slot: U256,
    },
    EmptyStorageProof {
        address: Address,
        slot: U256,
    },
    StorageProofMismatch {
        address: Address,
        slot: U256,
    },
}

/// Errors that prevent a signed verdict. These deliberately do not overlap with
/// [`FailReason`], whose members are deterministic predicate failures.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OperationalError {
    InvalidWitness(WitnessVerificationError),
    MissingPredicateWitness { address: Address, slot: U256 },
    MissingAccountWitness { address: Address },
    MissingStorageWitness { address: Address, slot: U256 },
    MissingCodeWitness { code_hash: B256 },
    MissingBlockHashWitness { number: u64 },
}

impl fmt::Display for OperationalError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "replay operational error: {self:?}")
    }
}

impl std::error::Error for OperationalError {}
impl revm::database_interface::DBErrorMarker for OperationalError {}

#[derive(Clone, Debug)]
struct VerifiedAccount {
    info: AccountInfo,
    storage: HashMap<U256, U256>,
}

/// Proof-verified material from which the closed-world revm DB is built.
#[derive(Clone, Debug)]
pub struct VerifiedPrestateWitnessV1 {
    accounts: HashMap<Address, VerifiedAccount>,
    codes: HashMap<B256, Bytecode>,
}

impl VerifiedPrestateWitnessV1 {
    fn has_storage(&self, address: Address, slot: U256) -> bool {
        self.accounts
            .get(&address)
            .is_some_and(|account| account.storage.contains_key(&slot))
    }
}

/// Verify all witness material offline against the committed EVM state root.
///
/// The secure-trie keys are `keccak256(address)` and `keccak256(slot-as-32-byte
/// big endian)`. Account values are canonical RLP `TrieAccount`s; nonzero storage
/// values are canonical RLP integers, and zero values use exclusion proofs.
pub fn verify_witness_against_root(
    anchor: &EvmAnchorV1,
    witness: &PrestateWitnessV1,
) -> Result<VerifiedPrestateWitnessV1, WitnessVerificationError> {
    let mut accounts = HashMap::with_capacity(witness.accounts.len());
    let mut codes = HashMap::with_capacity(witness.accounts.len());

    for account in &witness.accounts {
        if accounts.contains_key(&account.address) {
            return Err(WitnessVerificationError::DuplicateAccount {
                address: account.address,
            });
        }
        if account.account_proof.is_empty() {
            return Err(WitnessVerificationError::EmptyAccountProof {
                address: account.address,
            });
        }

        let computed_code_hash = keccak256(account.code.as_ref());
        if computed_code_hash != account.code_hash {
            return Err(WitnessVerificationError::CodeHashMismatch {
                address: account.address,
                expected: account.code_hash,
                got: computed_code_hash,
            });
        }

        let trie_account = TrieAccount {
            nonce: account.nonce,
            balance: account.balance,
            storage_root: account.storage_root,
            code_hash: account.code_hash,
        };
        let account_key = Nibbles::unpack(keccak256(account.address.as_slice()));
        if verify_proof(
            anchor.state_root,
            account_key,
            Some(alloy_rlp::encode(trie_account)),
            account.account_proof.iter(),
        )
        .is_err()
        {
            return Err(WitnessVerificationError::AccountProofMismatch {
                address: account.address,
            });
        }

        let mut storage = HashMap::with_capacity(account.storage.len());
        for entry in &account.storage {
            if storage.insert(entry.slot, entry.value).is_some() {
                return Err(WitnessVerificationError::DuplicateStorageSlot {
                    address: account.address,
                    slot: entry.slot,
                });
            }
            if entry.proof.is_empty() {
                return Err(WitnessVerificationError::EmptyStorageProof {
                    address: account.address,
                    slot: entry.slot,
                });
            }

            let slot_key = Nibbles::unpack(keccak256(entry.slot.to_be_bytes::<32>()));
            let expected_value = if entry.value.is_zero() {
                None
            } else {
                Some(alloy_rlp::encode(entry.value))
            };
            if verify_proof(
                account.storage_root,
                slot_key,
                expected_value,
                entry.proof.iter(),
            )
            .is_err()
            {
                return Err(WitnessVerificationError::StorageProofMismatch {
                    address: account.address,
                    slot: entry.slot,
                });
            }
        }

        let code = Bytecode::new_raw(account.code.clone());
        let info = AccountInfo {
            balance: account.balance,
            nonce: account.nonce,
            code_hash: account.code_hash,
            code: Some(code.clone()),
            ..Default::default()
        };
        codes.insert(account.code_hash, code);
        accounts.insert(account.address, VerifiedAccount { info, storage });
    }

    Ok(VerifiedPrestateWitnessV1 { accounts, codes })
}

/// A closed-world DB. Any account, code, storage, or historical block-hash read
/// not supplied in the proof-carrying witness aborts replay operationally.
#[derive(Clone, Debug)]
struct VerifiedWitnessDb {
    verified: VerifiedPrestateWitnessV1,
}

impl VerifiedWitnessDb {
    fn new(verified: VerifiedPrestateWitnessV1) -> Self {
        Self { verified }
    }
}

impl Database for VerifiedWitnessDb {
    type Error = OperationalError;

    fn basic(&mut self, address: Address) -> Result<Option<AccountInfo>, Self::Error> {
        self.verified
            .accounts
            .get(&address)
            .map(|account| Some(account.info.clone()))
            .ok_or(OperationalError::MissingAccountWitness { address })
    }

    fn code_by_hash(&mut self, code_hash: B256) -> Result<Bytecode, Self::Error> {
        self.verified
            .codes
            .get(&code_hash)
            .cloned()
            .ok_or(OperationalError::MissingCodeWitness { code_hash })
    }

    fn storage(&mut self, address: Address, slot: U256) -> Result<U256, Self::Error> {
        let account = self
            .verified
            .accounts
            .get(&address)
            .ok_or(OperationalError::MissingAccountWitness { address })?;
        account
            .storage
            .get(&slot)
            .copied()
            .ok_or(OperationalError::MissingStorageWitness { address, slot })
    }

    fn block_hash(&mut self, number: u64) -> Result<B256, Self::Error> {
        Err(OperationalError::MissingBlockHashWitness { number })
    }
}

/// Deterministically replay `plan` against `witness` under `anchor`, then judge
/// it with `predicate`.
pub fn replay(
    anchor: &EvmAnchorV1,
    witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1,
    predicate: &PredicateV1,
    commitments: &ReexecCommitmentsV1,
) -> Result<ReplayOutcome, OperationalError> {
    // 1. Verify first, then execute against a closed DB built only from proven
    // witness material. No RPC and no implicit EmptyDB defaults.
    let verified =
        verify_witness_against_root(anchor, witness).map_err(OperationalError::InvalidWitness)?;
    if let PredicateV1::PostStateEquals { checks } = predicate {
        for (address, slot, _) in checks {
            if !verified.has_storage(*address, *slot) {
                return Err(OperationalError::MissingPredicateWitness {
                    address: *address,
                    slot: *slot,
                });
            }
        }
    }
    let db = VerifiedWitnessDb::new(verified);

    // 2. Build a mainnet EVM pinned to the committed block environment.
    let mut evm = Context::mainnet()
        .with_db(db)
        .modify_cfg_chained(|c| {
            c.chain_id = anchor.chain_id;
            c.spec = anchor.spec_id;
            // A replay judges whether the seller's CALL satisfies the funded
            // predicate against the committed prestate — not whether it is a valid
            // fee-paying, correctly-nonced transaction. Disable both checks so a
            // real anchor (base_fee > 0) and a real caller (nonce > 0) do not turn
            // an honest delivery into a spurious Failed verdict. Balance is still
            // checked, so a CALL that sends `value` the caller lacks fails as it
            // should — that is prestate truth, not tx-validity ceremony.
            c.disable_base_fee = true;
            c.disable_nonce_check = true;
        })
        .modify_block_chained(|b| {
            b.number = U256::from(anchor.block_number);
            b.timestamp = U256::from(anchor.timestamp);
            b.basefee = anchor.base_fee;
            b.gas_limit = anchor.block_gas_limit;
            b.beneficiary = anchor.coinbase;
            b.prevrandao = Some(anchor.prevrandao);
        })
        .build_mainnet();

    // 3. Execute exactly the committed CALL.
    let tx = TxEnv {
        caller: plan.caller,
        kind: TxKind::Call(plan.target),
        value: plan.value,
        data: plan.calldata.clone(),
        gas_limit: plan.gas_limit,
        gas_price: 0,
        chain_id: Some(anchor.chain_id),
        ..Default::default()
    };

    let (return_data, gas_used, exec_ok, post_state): (Bytes, u64, bool, _) = match evm.transact(tx)
    {
        Ok(res) => {
            let gas = res.result.tx_gas_used();
            match res.result {
                ExecutionResult::Success {
                    output: Output::Call(b),
                    ..
                } => (b, gas, true, Some(res.state)),
                ExecutionResult::Success {
                    output: Output::Create(b, _),
                    ..
                } => (b, gas, true, Some(res.state)),
                // Revert / Halt are deterministic failures of the seller plan.
                _ => (Bytes::new(), gas, false, None),
            }
        }
        // A missing witness read is never coerced into an EVM default value
        // or a Failed verdict.
        Err(EVMError::Database(error)) => return Err(error),
        // Invalid transaction construction is a deterministic failure of the
        // submitted plan. It is distinct from unavailable proof material.
        Err(_) => (Bytes::new(), 0, false, None),
    };

    let evm_return_hash = keccak256(return_data.as_ref());
    let result_hash = evm_result_content_hash(return_data.as_ref());

    let verdict = if !exec_ok {
        Verdict::Failed(FailReason::Execution)
    } else {
        judge(
            predicate,
            evm_return_hash,
            &return_data,
            post_state.as_ref(),
            witness,
        )
    };

    let outcome_code = match verdict {
        Verdict::Reproduced => 1u8,
        Verdict::Failed(_) => 2u8,
    };
    let record = ReplayRecordV1 {
        protocol_version: 1,
        backend_id: commitments.backend_id,
        backend_version_hash: commitments.backend_version_hash,
        spec_hash: commitments.spec_hash,
        delivery_hash: commitments.delivery_hash,
        prestate_anchor_hash: commitments.prestate_anchor_hash,
        prestate_root: anchor.state_root,
        outcome: outcome_code,
        result_hash,
    };
    let trace_hash = record.trace_hash();

    Ok(ReplayOutcome {
        verdict,
        result_hash,
        prestate_root: anchor.state_root,
        trace_hash,
        record,
        return_data,
        gas_used,
    })
}

fn judge(
    predicate: &PredicateV1,
    result_hash: B256,
    _return_data: &Bytes,
    post_state: Option<&revm::state::EvmState>,
    witness: &PrestateWitnessV1,
) -> Verdict {
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
        PredicateV1::PostStateEquals { checks } => {
            for (address, slot, expected) in checks {
                let got = read_post_slot(*address, *slot, post_state, witness);
                if got != *expected {
                    return Verdict::Failed(FailReason::PostStateMismatch {
                        address: *address,
                        slot: *slot,
                        got,
                        expected: *expected,
                    });
                }
            }
            Verdict::Reproduced
        }
    }
}

/// Read a storage slot after execution: prefer the changed value from the tx
/// state, else fall back to the committed witness value, else zero.
fn read_post_slot(
    address: Address,
    slot: U256,
    post_state: Option<&revm::state::EvmState>,
    witness: &PrestateWitnessV1,
) -> U256 {
    if let Some(state) = post_state {
        if let Some(acct) = state.get(&address) {
            if let Some(s) = acct.storage.get(&slot) {
                return s.present_value;
            }
        }
    }
    for a in &witness.accounts {
        if a.address == address {
            for entry in &a.storage {
                if entry.slot == slot {
                    return entry.value;
                }
            }
        }
    }
    U256::ZERO
}

/// Deterministic, offline MPT fixtures shared by integration tests.  This is
/// deliberately feature-gated so the production API stays limited to replay
/// and verification primitives.
#[cfg(any(test, feature = "testkit"))]
pub mod testkit {
    use super::*;
    use alloy_trie::proof::ProofRetainer;
    use alloy_trie::{HashBuilder, EMPTY_ROOT_HASH};

    // Runtime bytecode that returns its own calldata (an on-chain "identity"),
    // so a plan's returnData is exactly the calldata it supplied. Lets us model
    // "seller claims their output satisfies the predicate" with no external
    // contract: 36 5f 5f 37 36 5f f3
    //   CALLDATASIZE PUSH0 PUSH0 CALLDATACOPY CALLDATASIZE PUSH0 RETURN
    pub const IDENTITY_RUNTIME: [u8; 7] = [0x36, 0x5f, 0x5f, 0x37, 0x36, 0x5f, 0xf3];

    pub fn addr(b: u8) -> Address {
        Address::from([b; 20])
    }

    pub fn anchor(state_root: B256) -> EvmAnchorV1 {
        EvmAnchorV1 {
            chain_id: 1,
            block_number: 21_000_000,
            block_hash: B256::from([0x10; 32]),
            state_root,
            timestamp: 1_800_000_000,
            base_fee: 0,
            block_gas_limit: 30_000_000,
            coinbase: addr(0xc0),
            prevrandao: B256::from([0x22; 32]),
            spec_id: SpecId::CANCUN,
        }
    }

    pub fn commitments() -> ReexecCommitmentsV1 {
        ReexecCommitmentsV1 {
            backend_id: B256::from([0xb0; 32]),
            backend_version_hash: B256::from([0xb1; 32]),
            spec_hash: B256::from([0x5c; 32]),
            delivery_hash: B256::from([0xde; 32]),
            prestate_anchor_hash: B256::from([0xa0; 32]),
        }
    }

    /// Construct offline MPT fixtures in the test only. The verification path
    /// consumes the resulting raw nodes exactly as an eth_getProof witness does.
    pub fn trie_with_proofs(entries: Vec<(B256, Vec<u8>)>) -> (B256, HashMap<B256, Vec<Bytes>>) {
        let mut entries = entries;
        entries.sort_unstable_by_key(|(key, _)| *key);
        let targets: Vec<Nibbles> = entries
            .iter()
            .map(|(key, _)| Nibbles::unpack(*key))
            .collect();
        let mut builder =
            HashBuilder::default().with_proof_retainer(ProofRetainer::from_iter(targets.clone()));
        for ((_, value), target) in entries.iter().zip(targets.iter()) {
            builder.add_leaf(*target, value);
        }
        let root = builder.root();
        let proof_nodes = builder.take_proof_nodes();
        let proofs = entries
            .iter()
            .zip(targets.iter())
            .map(|((key, _), target)| {
                let nodes = proof_nodes
                    .matching_nodes_sorted(target)
                    .into_iter()
                    .map(|(_, node)| node)
                    .collect();
                (*key, nodes)
            })
            .collect();
        (root, proofs)
    }

    pub fn anchored_identity_witness(
        caller: Address,
        target: Address,
    ) -> (EvmAnchorV1, PrestateWitnessV1) {
        anchored_identity_witness_with(caller, target, 0)
    }

    pub fn anchored_identity_witness_with(
        caller: Address,
        target: Address,
        caller_nonce: u64,
    ) -> (EvmAnchorV1, PrestateWitnessV1) {
        let coinbase = addr(0xc0);
        let storage_slot = U256::from(7u64);
        let storage_value = U256::from(42u64);
        let storage_key = keccak256(storage_slot.to_be_bytes::<32>());
        let (target_storage_root, storage_proofs) =
            trie_with_proofs(vec![(storage_key, alloy_rlp::encode(storage_value))]);

        let caller_code = Bytes::new();
        let target_code = Bytes::from_static(&IDENTITY_RUNTIME);
        let caller_account = TrieAccount {
            nonce: caller_nonce,
            balance: U256::from(10u64).pow(U256::from(18)),
            storage_root: EMPTY_ROOT_HASH,
            code_hash: keccak256(caller_code.as_ref()),
        };
        let target_account = TrieAccount {
            nonce: 1,
            balance: U256::ZERO,
            storage_root: target_storage_root,
            code_hash: keccak256(target_code.as_ref()),
        };
        // revm credits the block beneficiary even when gas price is zero, so a
        // closed witness must contain the committed coinbase account as well.
        let coinbase_account = TrieAccount {
            nonce: 1,
            balance: U256::ONE,
            storage_root: EMPTY_ROOT_HASH,
            code_hash: keccak256([]),
        };
        let caller_key = keccak256(caller.as_slice());
        let target_key = keccak256(target.as_slice());
        let coinbase_key = keccak256(coinbase.as_slice());
        let (state_root, account_proofs) = trie_with_proofs(vec![
            (caller_key, alloy_rlp::encode(caller_account)),
            (target_key, alloy_rlp::encode(target_account)),
            (coinbase_key, alloy_rlp::encode(coinbase_account)),
        ]);

        let witness = PrestateWitnessV1 {
            accounts: vec![
                AccountWitness {
                    address: caller,
                    balance: caller_account.balance,
                    nonce: caller_account.nonce,
                    storage_root: caller_account.storage_root,
                    code_hash: caller_account.code_hash,
                    code: caller_code,
                    account_proof: account_proofs[&caller_key].clone(),
                    storage: vec![],
                },
                AccountWitness {
                    address: target,
                    balance: target_account.balance,
                    nonce: target_account.nonce,
                    storage_root: target_account.storage_root,
                    code_hash: target_account.code_hash,
                    code: target_code,
                    account_proof: account_proofs[&target_key].clone(),
                    storage: vec![StorageWitnessV1 {
                        slot: storage_slot,
                        value: storage_value,
                        proof: storage_proofs[&storage_key].clone(),
                    }],
                },
                AccountWitness {
                    address: coinbase,
                    balance: coinbase_account.balance,
                    nonce: coinbase_account.nonce,
                    storage_root: coinbase_account.storage_root,
                    code_hash: coinbase_account.code_hash,
                    code: Bytes::new(),
                    account_proof: account_proofs[&coinbase_key].clone(),
                    storage: vec![],
                },
            ],
        };
        (anchor(state_root), witness)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::testkit::*;

    #[test]
    fn honest_delivery_reproduces() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let (anchor, witness) = anchored_identity_witness(caller, target);

        // Buyer funds: "the output must hash to keccak256(GOOD)".
        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals {
            expected_result_hash: keccak256(good.as_ref()),
        };

        // Honest seller supplies a plan that actually yields GOOD.
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: good.clone(),
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let out = replay(&anchor, &witness, &plan, &predicate, &commitments()).unwrap();
        assert!(
            out.reproduced(),
            "honest plan should reproduce: {:?}",
            out.verdict
        );
        assert_eq!(out.result_hash, evm_result_content_hash(good.as_ref()));
        assert_eq!(out.prestate_root, anchor.state_root);
    }

    // Regression for review R1: an honest delivery must reproduce against a
    // realistic anchor (base_fee > 0) and a realistic caller (nonce > 0). Before
    // disabling base-fee / nonce checks, revm rejected the tx pre-execution
    // (GasPriceLessThanBasefee / NonceMismatch) and it collapsed to Failed.
    #[test]
    fn real_anchor_base_fee_and_nonce_reproduces() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let (mut anchor, witness) = anchored_identity_witness_with(caller, target, 7);
        anchor.base_fee = 1_000_000_000; // 1 gwei

        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals {
            expected_result_hash: keccak256(good.as_ref()),
        };
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: good.clone(),
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let out = replay(&anchor, &witness, &plan, &predicate, &commitments()).unwrap();
        assert!(
            out.reproduced(),
            "honest plan must reproduce under real base_fee/nonce: {:?}",
            out.verdict
        );
    }

    #[test]
    fn false_claim_fails_and_refunds() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let (anchor, witness) = anchored_identity_witness(caller, target);

        // Same funded predicate as the honest case.
        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals {
            expected_result_hash: keccak256(good.as_ref()),
        };

        // Cheating seller claims success but the plan actually yields BAD.
        let bad = Bytes::from_static(b"swap-out==5USDC-actually-bad----");
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: bad,
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let out = replay(&anchor, &witness, &plan, &predicate, &commitments()).unwrap();
        assert_eq!(
            out.verdict,
            Verdict::Failed(FailReason::ResultMismatch),
            "false claim must fail -> refund",
        );
    }

    #[test]
    fn witness_proof_fixture_is_valid_and_tampering_is_operational() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let (anchor, witness) = anchored_identity_witness(caller, target);

        // Fixed, offline MPT fixture. The raw nodes live in
        // `fixtures/mpt-witness-v1.md`; these commitments make accidental changes
        // to the generated fixture fail loudly.
        assert_eq!(
            format!("{anchor_root:x}", anchor_root = anchor.state_root),
            "26449071e16a2d2fad50256c613af90004c98c289775205fada7c91ac5bcb3c3",
        );
        for account in &witness.accounts {
            let expected_hash = if account.address == caller {
                "95addfb0bda74d25cde7ebc2518e98b56906a8be6ad2df851587ac87019c0f56"
            } else if account.address == target {
                "c6afa6e155b00876ed014a5fafd19a27eb4879cd99581285f11c7e8c62eb28b9"
            } else {
                "46d710bbdf2532a3aa2667185a1628c34d44e8cb205e6e093f6480afaa8086da"
            };
            assert_eq!(account.account_proof.len(), 2);
            assert_eq!(
                format!("{:x}", keccak256(account.account_proof.concat())),
                expected_hash
            );
            for storage in &account.storage {
                assert_eq!(storage.proof.len(), 1);
                assert_eq!(
                    format!("{:x}", keccak256(storage.proof.concat())),
                    "77d0ab3d39d51d39dd9870f6b474e1dd4a06510b42f54b2336c1996f0f3c4846",
                );
            }
        }
        assert!(verify_witness_against_root(&anchor, &witness).is_ok());

        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals {
            expected_result_hash: keccak256(good.as_ref()),
        };
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: good,
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let mut tampered = witness.clone();
        tampered.accounts[1].storage[0].value = U256::from(43u64);
        assert!(
            matches!(
                replay(&anchor, &tampered, &plan, &predicate, &commitments()),
                Err(OperationalError::InvalidWitness(WitnessVerificationError::StorageProofMismatch {
                    address,
                    slot,
                })) if address == target && slot == U256::from(7u64)
            ),
            "a proof mismatch must not become a Failed verdict"
        );

        let mut missing = witness;
        missing.accounts[1].storage[0].proof.clear();
        assert!(
            matches!(
                replay(&anchor, &missing, &plan, &predicate, &commitments()),
                Err(OperationalError::InvalidWitness(WitnessVerificationError::EmptyStorageProof {
                    address,
                    slot,
                })) if address == target && slot == U256::from(7u64)
            ),
            "a missing proof must not become a Failed verdict"
        );
    }

    // The ReplayRecordV1 golden vector now lives with the shared codec in the
    // `reckn-record` crate (so EVM and Solana assert the same bytes/hash).

    #[test]
    fn replay_is_deterministic() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let (anchor, witness) = anchored_identity_witness(caller, target);
        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals {
            expected_result_hash: keccak256(good.as_ref()),
        };
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: good,
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let a = replay(&anchor, &witness, &plan, &predicate, &commitments()).unwrap();
        let b = replay(&anchor, &witness, &plan, &predicate, &commitments()).unwrap();
        assert_eq!(a.trace_hash, b.trace_hash, "same inputs -> same trace hash");
        assert_eq!(a.result_hash, b.result_hash);
    }
}

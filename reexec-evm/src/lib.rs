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
//! Trust boundary (do not overclaim): V1 **trusts the witness bytes**. Binding
//! the witness to `anchor.state_root` via Merkle-Patricia proofs is the flagged
//! next hardening — see [`verify_witness_against_root`]. Until then a replay is
//! reproducible but its *prestate authenticity* rests on whoever published the
//! witness. Reproducibility and settlement authority stay distinct.

use revm::context::result::{ExecutionResult, Output};
use revm::context::TxEnv;
use revm::database::{CacheDB, EmptyDB};
use revm::primitives::hardfork::SpecId;
use revm::primitives::{keccak256, Address, Bytes, TxKind, B256, U256};
use revm::state::{AccountInfo, Bytecode};
use revm::{Context, ExecuteEvm, MainBuilder, MainContext};
use sha2::{Digest, Sha256};

/// Committed block environment. In production every field is part of the anchor
/// descriptor the buyer publishes at funding; `state_root` is what the witness
/// must be proven against.
#[derive(Clone, Debug)]
pub struct EvmAnchorV1 {
    pub chain_id: u64,
    pub block_number: u64,
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
    /// Runtime code; empty for an EOA.
    pub code: Bytes,
    /// Committed storage slots (slot -> word).
    pub storage: Vec<(U256, U256)>,
}

/// The committed prestate. V1 trusts these bytes (see crate docs).
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

/// The commitment hashes that bind a replay to a specific deal. These come from
/// the protocol/escrow layer (hashes of the canonical spec/delivery/anchor bytes
/// and the backend identity); the re-execution engine treats them as opaque
/// 32-byte content and folds them into the canonical [`ReplayRecordV1`].
#[derive(Clone, Debug, Default)]
pub struct ReexecCommitmentsV1 {
    pub backend_id: B256,
    pub backend_version_hash: B256,
    pub spec_hash: B256,
    pub delivery_hash: B256,
    pub prestate_anchor_hash: B256,
}

/// Canonical, VM-neutral record of an adjudicated replay. `trace_hash` is its
/// SHA-256 digest. The encoding is specified in
/// `packages/protocol/REPLAY_RECORD_V1.md`; this struct is the reference Rust
/// implementation and must match that spec and the golden vectors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReplayRecordV1 {
    pub protocol_version: u64,
    pub backend_id: B256,
    pub backend_version_hash: B256,
    pub spec_hash: B256,
    pub delivery_hash: B256,
    pub prestate_anchor_hash: B256,
    pub prestate_root: B256,
    /// 1 = Reproduced, 2 = Failed (matches the ReexecVerdict enum).
    pub outcome: u8,
    pub result_hash: B256,
}

impl ReplayRecordV1 {
    /// TLV bytes: entries with strictly ascending 1-byte tags, 1-byte length
    /// (all V1 values ≤ 32 bytes), minimal-big-endian unsigned integers.
    pub fn canonical_bytes(&self) -> Vec<u8> {
        fn tlv(out: &mut Vec<u8>, tag: u8, value: &[u8]) {
            out.push(tag);
            out.push(value.len() as u8);
            out.extend_from_slice(value);
        }
        fn minimal_be(v: u64) -> Vec<u8> {
            if v == 0 {
                return Vec::new();
            }
            let bytes = v.to_be_bytes();
            let first = bytes.iter().position(|&b| b != 0).unwrap();
            bytes[first..].to_vec()
        }
        let mut o = Vec::new();
        tlv(&mut o, 0x01, &minimal_be(self.protocol_version));
        tlv(&mut o, 0x02, self.backend_id.as_slice());
        tlv(&mut o, 0x03, self.backend_version_hash.as_slice());
        tlv(&mut o, 0x04, self.spec_hash.as_slice());
        tlv(&mut o, 0x05, self.delivery_hash.as_slice());
        tlv(&mut o, 0x06, self.prestate_anchor_hash.as_slice());
        tlv(&mut o, 0x07, self.prestate_root.as_slice());
        tlv(&mut o, 0x08, &minimal_be(self.outcome as u64));
        tlv(&mut o, 0x09, self.result_hash.as_slice());
        o
    }

    /// `SHA-256("reckn/v1/" || "replay-record" || canonicalBytes)`.
    pub fn trace_hash(&self) -> B256 {
        let mut h = Sha256::new();
        h.update(b"reckn/v1/");
        h.update(b"replay-record");
        h.update(self.canonical_bytes());
        B256::from_slice(&h.finalize())
    }
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
    PostStateMismatch { address: Address, slot: U256, got: U256, expected: U256 },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Verdict {
    Reproduced,
    Failed(FailReason),
}

/// The reproducible result of a replay. `trace_hash` is a deterministic digest
/// over the canonical replay record; the exact `ReplayRecordV1` TLV encoding
/// lives in `packages/protocol` (shared across VMs) — here it is a stable
/// placeholder over the same fields.
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

/// TODO(hardening): verify each account/storage entry in `witness` against
/// `anchor.state_root` with a Merkle-Patricia proof (alloy-trie / reth). Until
/// this exists, `replay` runs in `demo-unverified` mode: reproducible, but the
/// prestate is trusted. This is the single largest correctness gap and the right
/// cross-pass target for Codex.
pub fn verify_witness_against_root(_anchor: &EvmAnchorV1, _witness: &PrestateWitnessV1) -> bool {
    false
}

/// Deterministically replay `plan` against `witness` under `anchor`, then judge
/// it with `predicate`.
pub fn replay(
    anchor: &EvmAnchorV1,
    witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1,
    predicate: &PredicateV1,
    commitments: &ReexecCommitmentsV1,
) -> ReplayOutcome {
    // 1. Seed an in-memory DB purely from the committed witness. No RPC.
    let mut db = CacheDB::<EmptyDB>::default();
    for a in &witness.accounts {
        let code = if a.code.is_empty() {
            None
        } else {
            Some(Bytecode::new_raw(a.code.clone()))
        };
        let info = AccountInfo {
            balance: a.balance,
            nonce: a.nonce,
            code_hash: code
                .as_ref()
                .map(|c| c.hash_slow())
                .unwrap_or(revm::primitives::KECCAK_EMPTY),
            code,
            ..Default::default()
        };
        db.insert_account_info(a.address, info);
        for (slot, word) in &a.storage {
            // Seeding committed storage cannot fail for a known account.
            let _ = db.insert_account_storage(a.address, *slot, *word);
        }
    }

    // 2. Build a mainnet EVM pinned to the committed block environment.
    let mut evm = Context::mainnet()
        .with_db(db)
        .modify_cfg_chained(|c| {
            c.chain_id = anchor.chain_id;
            c.spec = anchor.spec_id;
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

    let outcome = evm.transact(tx);

    let (return_data, gas_used, exec_ok, post_state): (Bytes, u64, bool, _) = match outcome {
        Ok(res) => {
            let gas = res.result.tx_gas_used();
            match res.result {
                ExecutionResult::Success { output: Output::Call(b), .. } => {
                    (b, gas, true, Some(res.state))
                }
                ExecutionResult::Success { output: Output::Create(b, _), .. } => {
                    (b, gas, true, Some(res.state))
                }
                // Revert / Halt are deterministic failures of the plan.
                _ => (Bytes::new(), gas, false, None),
            }
        }
        // A transaction-construction error is an operational error, not a verdict.
        // V1 surfaces it as an execution failure of this exact plan; the escrow's
        // timeout policy (review C1) covers genuine liveness cases separately.
        Err(_) => (Bytes::new(), 0, false, None),
    };

    let result_hash = keccak256(return_data.as_ref());

    let verdict = if !exec_ok {
        Verdict::Failed(FailReason::Execution)
    } else {
        judge(predicate, result_hash, &return_data, post_state.as_ref(), witness)
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

    ReplayOutcome {
        verdict,
        result_hash,
        prestate_root: anchor.state_root,
        trace_hash,
        record,
        return_data,
        gas_used,
    }
}

fn judge(
    predicate: &PredicateV1,
    result_hash: B256,
    _return_data: &Bytes,
    post_state: Option<&revm::state::EvmState>,
    witness: &PrestateWitnessV1,
) -> Verdict {
    match predicate {
        PredicateV1::ResultEquals { expected_result_hash } => {
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
            for (s, w) in &a.storage {
                if *s == slot {
                    return *w;
                }
            }
        }
    }
    U256::ZERO
}

#[cfg(test)]
mod tests {
    use super::*;

    // Runtime bytecode that returns its own calldata (an on-chain "identity"),
    // so a plan's returnData is exactly the calldata it supplied. Lets us model
    // "seller claims their output satisfies the predicate" with no external
    // contract: 36 5f 5f 37 36 5f f3
    //   CALLDATASIZE PUSH0 PUSH0 CALLDATACOPY CALLDATASIZE PUSH0 RETURN
    const IDENTITY_RUNTIME: [u8; 7] = [0x36, 0x5f, 0x5f, 0x37, 0x36, 0x5f, 0xf3];

    fn addr(b: u8) -> Address {
        Address::from([b; 20])
    }

    fn anchor() -> EvmAnchorV1 {
        EvmAnchorV1 {
            chain_id: 1,
            block_number: 21_000_000,
            state_root: B256::from([0x11; 32]),
            timestamp: 1_800_000_000,
            base_fee: 0,
            block_gas_limit: 30_000_000,
            coinbase: addr(0xc0),
            prevrandao: B256::from([0x22; 32]),
            spec_id: SpecId::CANCUN,
        }
    }

    fn commitments() -> ReexecCommitmentsV1 {
        ReexecCommitmentsV1 {
            backend_id: B256::from([0xb0; 32]),
            backend_version_hash: B256::from([0xb1; 32]),
            spec_hash: B256::from([0x5c; 32]),
            delivery_hash: B256::from([0xde; 32]),
            prestate_anchor_hash: B256::from([0xa0; 32]),
        }
    }

    fn witness_with_identity(caller: Address, target: Address) -> PrestateWitnessV1 {
        PrestateWitnessV1 {
            accounts: vec![
                AccountWitness {
                    address: caller,
                    balance: U256::from(10u64).pow(U256::from(18)),
                    nonce: 0,
                    code: Bytes::new(),
                    storage: vec![],
                },
                AccountWitness {
                    address: target,
                    balance: U256::ZERO,
                    nonce: 1,
                    code: Bytes::from_static(&IDENTITY_RUNTIME),
                    storage: vec![],
                },
            ],
        }
    }

    #[test]
    fn honest_delivery_reproduces() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let witness = witness_with_identity(caller, target);

        // Buyer funds: "the output must hash to keccak256(GOOD)".
        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals { expected_result_hash: keccak256(good.as_ref()) };

        // Honest seller supplies a plan that actually yields GOOD.
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: good.clone(),
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let out = replay(&anchor(), &witness, &plan, &predicate, &commitments());
        assert!(out.reproduced(), "honest plan should reproduce: {:?}", out.verdict);
        assert_eq!(out.result_hash, keccak256(good.as_ref()));
        assert_eq!(out.prestate_root, anchor().state_root);
    }

    #[test]
    fn false_claim_fails_and_refunds() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let witness = witness_with_identity(caller, target);

        // Same funded predicate as the honest case.
        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals { expected_result_hash: keccak256(good.as_ref()) };

        // Cheating seller claims success but the plan actually yields BAD.
        let bad = Bytes::from_static(b"swap-out==5USDC-actually-bad----");
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: bad,
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let out = replay(&anchor(), &witness, &plan, &predicate, &commitments());
        assert_eq!(
            out.verdict,
            Verdict::Failed(FailReason::ResultMismatch),
            "false claim must fail -> refund",
        );
    }

    /// Golden vector for the canonical ReplayRecordV1 codec. The expected
    /// `trace_hash` was computed independently (Python `hashlib.sha256`), so this
    /// asserts the Rust reference impl matches real SHA-256 and the spec in
    /// `packages/protocol/REPLAY_RECORD_V1.md` / `golden/replay-record-v1.json`.
    #[test]
    fn golden_replay_record_v1() {
        let rec = ReplayRecordV1 {
            protocol_version: 1,
            backend_id: B256::from([0x01; 32]),
            backend_version_hash: B256::from([0x02; 32]),
            spec_hash: B256::from([0x03; 32]),
            delivery_hash: B256::from([0x04; 32]),
            prestate_anchor_hash: B256::from([0x05; 32]),
            prestate_root: B256::from([0x06; 32]),
            outcome: 1,
            result_hash: B256::from([0x07; 32]),
        };

        let mut expected = vec![0x01u8, 0x01, 0x01];
        for (tag, val) in [(0x02u8, 0x01u8), (0x03, 0x02), (0x04, 0x03), (0x05, 0x04), (0x06, 0x05), (0x07, 0x06)] {
            expected.push(tag);
            expected.push(0x20);
            expected.extend_from_slice(&[val; 32]);
        }
        expected.extend_from_slice(&[0x08, 0x01, 0x01]);
        expected.push(0x09);
        expected.push(0x20);
        expected.extend_from_slice(&[0x07; 32]);

        assert_eq!(rec.canonical_bytes(), expected, "canonical TLV bytes");
        assert_eq!(rec.canonical_bytes().len(), 244);
        assert_eq!(
            format!("{:x}", rec.trace_hash()),
            "94b20b2330662638857fb412dc648f84c183e8e214431bd25f8915452258d33e",
            "trace_hash must match independent SHA-256",
        );
    }

    #[test]
    fn replay_is_deterministic() {
        let caller = addr(0xaa);
        let target = addr(0xbb);
        let witness = witness_with_identity(caller, target);
        let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
        let predicate = PredicateV1::ResultEquals { expected_result_hash: keccak256(good.as_ref()) };
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: good,
            value: U256::ZERO,
            gas_limit: 200_000,
        };

        let a = replay(&anchor(), &witness, &plan, &predicate, &commitments());
        let b = replay(&anchor(), &witness, &plan, &predicate, &commitments());
        assert_eq!(a.trace_hash, b.trace_hash, "same inputs -> same trace hash");
        assert_eq!(a.result_hash, b.result_hash);
    }
}

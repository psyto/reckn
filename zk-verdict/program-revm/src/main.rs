//! The **full re-execution** zkVM guest. Unlike the predicate guest (which trusts
//! `post` as an input), this one seeds a real `revm` in-memory DB from the
//! committed prestate, **executes the seller's committed CALL under proof**, reads
//! the resulting post-state, and applies reckn's causal delta predicate. So `post`
//! — the fact a resolver would otherwise be trusted to compute — is derived by the
//! EVM inside the proof. It commits the SAME `VerdictPublicValues` the on-chain
//! `RecknVerdictVerifier` already consumes, so nothing on-chain changes: only the
//! proof got stronger (execution, not a trusted post-state).
//!
//! Scope: proves execution-from-committed-prestate + the delta predicate. Prestate
//! MPT-authenticity vs a state root is the same off-chain layer as `reexec-evm`
//! and can be folded into the guest next (keccak-heavy). Values map to `u64` to
//! reuse the existing verdict ABI.

#![no_main]
sp1_zkvm::entrypoint!(main);

use alloy_sol_types::SolType;
use reexec_io::GuestInput;
use revm::context::result::ExecutionResult;
use revm::context::TxEnv;
use revm::database::InMemoryDB;
use revm::primitives::{Address, Bytes, TxKind, U256};
use revm::state::{AccountInfo, Bytecode};
use revm::{Context, ExecuteEvm, MainBuilder, MainContext};
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues, FAILED};

fn u64_low(v: U256) -> u64 {
    v.as_limbs()[0]
}

/// The committed prestate value of a slot (the delta `pre` baseline).
fn read_committed(input: &GuestInput, address: [u8; 20], slot: [u8; 32]) -> U256 {
    for a in &input.accounts {
        if a.address == address {
            for (s, v) in &a.storage {
                if *s == slot {
                    return U256::from_be_bytes(*v);
                }
            }
        }
    }
    U256::ZERO
}

pub fn main() {
    let input = sp1_zkvm::io::read::<GuestInput>();

    // 1. Seed an in-memory DB from the committed prestate (execution material).
    let mut db = InMemoryDB::default();
    for acct in &input.accounts {
        let addr = Address::from(acct.address);
        let mut info = AccountInfo::default();
        info.balance = U256::from_be_bytes(acct.balance);
        info.nonce = acct.nonce;
        if !acct.code.is_empty() {
            info.code = Some(Bytecode::new_raw(Bytes::from(acct.code.clone())));
        }
        // insert_account_info recomputes code_hash from code.
        db.insert_account_info(addr, info);
        for (slot, val) in &acct.storage {
            db.insert_account_storage(addr, U256::from_be_bytes(*slot), U256::from_be_bytes(*val))
                .expect("seed storage");
        }
    }

    // 2. Re-execute exactly the committed CALL under proof. gas_price/base_fee are
    //    0 and the caller nonce is committed, so no tx-validity ceremony is needed
    //    (this mirrors reexec-evm's disable_base_fee/disable_nonce_check intent).
    let mut evm = Context::mainnet()
        .with_db(db)
        .modify_cfg_chained(|c| {
            c.chain_id = input.chain_id;
        })
        .build_mainnet();

    let tx = TxEnv {
        caller: Address::from(input.plan.caller),
        kind: TxKind::Call(Address::from(input.plan.target)),
        value: U256::from_be_bytes(input.plan.value),
        data: Bytes::from(input.plan.calldata.clone()),
        gas_limit: input.plan.gas_limit,
        gas_price: 0,
        chain_id: Some(input.chain_id),
        ..Default::default()
    };

    let (exec_ok, post_state) = match evm.transact(tx) {
        Ok(res) => match res.result {
            ExecutionResult::Success { .. } => (true, Some(res.state)),
            // Revert / Halt are deterministic failures of the seller plan.
            _ => (false, None),
        },
        Err(_) => (false, None),
    };

    // 3. Causal delta: pre from the committed prestate, post from the *executed*
    //    state (fall back to pre if the plan touched no slot). Verdict Failed if
    //    execution itself failed.
    let check = &input.check;
    let caddr = Address::from(check.address);
    let cslot = U256::from_be_bytes(check.slot);
    let pre = read_committed(&input, check.address, check.slot);
    let post = post_state
        .as_ref()
        .and_then(|s| s.get(&caddr))
        .and_then(|a| a.storage.get(&cslot))
        .map(|slot| slot.present_value)
        .unwrap_or(pre);

    let pre_u = u64_low(pre);
    let post_u = u64_low(post);
    let outcome = if exec_ok {
        delta_outcome(pre_u, post_u, check.min, check.max)
    } else {
        FAILED
    };
    let trace = verdict_trace_hash(pre_u, post_u, check.min, check.max, outcome);

    let bytes = VerdictPublicValues::abi_encode(&VerdictPublicValues {
        pre: pre_u,
        post: post_u,
        minDelta: check.min,
        maxDelta: check.max,
        outcome,
        traceHash: trace.into(),
    });
    sp1_zkvm::io::commit_slice(&bytes);
}

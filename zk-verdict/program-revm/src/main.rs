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
use alloy_trie::{proof::verify_proof, Nibbles, TrieAccount};
use reexec_io::GuestInput;
use revm::context::result::ExecutionResult;
use revm::context::TxEnv;
use revm::database::InMemoryDB;
use revm::primitives::{keccak256, Address, Bytes, TxKind, B256, U256};
use revm::state::{AccountInfo, Bytecode};
use revm::{Context, ExecuteEvm, MainBuilder, MainContext};
use verdict_lib::{delta_outcome, reexec_trace_hash, VerdictPublicValues, FAILED};

fn u64_low(v: U256) -> u64 {
    v.as_limbs()[0]
}

/// Prove the committed prestate is authentic against `state_root`: each account is
/// MPT-verified against the state root, and each storage slot against the proven
/// account storage root — exactly as `reexec-evm::verify_witness_against_root` does
/// off-chain. Panics on any mismatch, so a valid proof can only exist for an
/// authentic prestate. (In the settlement protocol a real failure is an operational
/// error; here "no proof" is the ZK expression of that.)
fn verify_prestate_authenticity(input: &GuestInput) {
    let state_root = B256::from(input.state_root);
    for acct in &input.accounts {
        let addr = Address::from(acct.address);

        // The code the guest will run must be the committed code.
        let code_hash = keccak256(&acct.code);
        assert_eq!(code_hash.0, acct.code_hash, "code hash mismatch");

        // Account leaf: keccak(address) -> rlp(TrieAccount) under state_root.
        let trie_account = TrieAccount {
            nonce: acct.nonce,
            balance: U256::from_be_bytes(acct.balance),
            storage_root: B256::from(acct.storage_root),
            code_hash: B256::from(acct.code_hash),
        };
        let key = Nibbles::unpack(keccak256(addr.as_slice()));
        let proof: Vec<Bytes> = acct.account_proof.iter().map(|n| Bytes::copy_from_slice(n)).collect();
        verify_proof(state_root, key, Some(alloy_rlp::encode(trie_account)), proof.iter())
            .expect("account proof invalid");

        // Storage leaves: keccak(slot) -> rlp(value) under the account storage root.
        let storage_root = B256::from(acct.storage_root);
        for entry in &acct.storage {
            let slot = U256::from_be_bytes(entry.slot);
            let value = U256::from_be_bytes(entry.value);
            let skey = Nibbles::unpack(keccak256(slot.to_be_bytes::<32>()));
            let expected = if value.is_zero() {
                None
            } else {
                Some(alloy_rlp::encode(value))
            };
            let sproof: Vec<Bytes> = entry.proof.iter().map(|n| Bytes::copy_from_slice(n)).collect();
            verify_proof(storage_root, skey, expected, sproof.iter())
                .expect("storage proof invalid");
        }
    }
}

/// The committed prestate value of a slot (the delta `pre` baseline).
fn read_committed(input: &GuestInput, address: [u8; 20], slot: [u8; 32]) -> U256 {
    for a in &input.accounts {
        if a.address == address {
            for e in &a.storage {
                if e.slot == slot {
                    return U256::from_be_bytes(e.value);
                }
            }
        }
    }
    U256::ZERO
}

pub fn main() {
    let input = sp1_zkvm::io::read::<GuestInput>();

    // 0. Prove the prestate is authentic against the committed state_root BEFORE
    //    trusting any of its values. A valid proof cannot exist otherwise.
    verify_prestate_authenticity(&input);

    // 1. Seed an in-memory DB from the (now authenticated) prestate.
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
        for e in &acct.storage {
            db.insert_account_storage(addr, U256::from_be_bytes(e.slot), U256::from_be_bytes(e.value))
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
    // The trace hash binds the authenticated prestate_root, so the verdict is
    // about *this* state — a prover cannot swap in a convenient fake prestate.
    let trace = reexec_trace_hash(input.state_root, pre_u, post_u, check.min, check.max, outcome);

    // Deal binding: commit the authenticated prestate root + the predicate + the
    // plan, so an escrow can require a proof to be about its exact committed deal.
    let mut plan_pre: Vec<u8> = Vec::new();
    plan_pre.extend_from_slice(&input.plan.caller);
    plan_pre.extend_from_slice(&input.plan.target);
    plan_pre.extend_from_slice(&input.plan.calldata);
    plan_pre.extend_from_slice(&input.plan.value);
    let plan_hash = keccak256(&plan_pre);
    let mut bind_pre: Vec<u8> = Vec::new();
    bind_pre.extend_from_slice(b"reckn/zk/bind/evm/v1");
    bind_pre.extend_from_slice(&input.state_root);
    bind_pre.extend_from_slice(&check.address);
    bind_pre.extend_from_slice(&check.slot);
    bind_pre.extend_from_slice(&check.min.to_le_bytes());
    bind_pre.extend_from_slice(&check.max.to_le_bytes());
    bind_pre.extend_from_slice(plan_hash.as_slice());
    let deal_binding = keccak256(&bind_pre);

    let bytes = VerdictPublicValues::abi_encode(&VerdictPublicValues {
        pre: pre_u,
        post: post_u,
        minDelta: check.min,
        maxDelta: check.max,
        outcome,
        traceHash: trace.into(),
        dealBinding: deal_binding.0.into(),
    });
    sp1_zkvm::io::commit_slice(&bytes);
}

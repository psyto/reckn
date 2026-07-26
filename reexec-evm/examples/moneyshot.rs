//! Money-shot data generator.
//!
//! Runs the real reexec-evm engine over two deliveries against one funded
//! predicate and emits a JSON the dashboard renders:
//!   - honest  : seller's plan yields the agreed output  -> Reproduced -> release
//!   - cheating : seller *claims* success but the plan yields a bad output
//!                -> Failed(ResultMismatch) -> refund
//!
//! An opinion-based "LLM judge" reads the persuasive `seller_claim` and approves
//! both. Re-execution ignores the claim and replays the plan, catching the fraud.
//!
//! Regenerate:  cargo run --example moneyshot > ../dashboard/moneyshot.json

use alloy_trie::proof::ProofRetainer;
use alloy_trie::{HashBuilder, Nibbles, TrieAccount, EMPTY_ROOT_HASH};
use reckn_reexec_evm::{
    replay, AccountWitness, EvmAnchorV1, EvmCallPlanV1, PredicateV1, PrestateWitnessV1,
    ReexecCommitmentsV1, Verdict,
};
use revm::primitives::hardfork::SpecId;
use revm::primitives::{keccak256, Address, Bytes, B256, U256};
use std::collections::HashMap;

// Identity runtime: returns its own calldata. Lets a "delivered output" be
// exactly what the seller's plan supplies, with no external contract.
const IDENTITY_RUNTIME: [u8; 7] = [0x36, 0x5f, 0x5f, 0x37, 0x36, 0x5f, 0xf3];

fn addr(b: u8) -> Address {
    Address::from([b; 20])
}

fn trie_with_proofs(entries: Vec<(B256, Vec<u8>)>) -> (B256, HashMap<B256, Vec<Bytes>>) {
    let mut entries = entries;
    entries.sort_unstable_by_key(|(key, _)| *key);
    let targets: Vec<Nibbles> = entries.iter().map(|(k, _)| Nibbles::unpack(*k)).collect();
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

fn main() {
    let caller = addr(0xaa);
    let target = addr(0xbb);
    let coinbase = addr(0xc0);

    // Real-looking prestate: caller has already transacted (nonce > 0), block has
    // a nonzero base fee. Exercises the R1 fix end to end.
    let caller_account = TrieAccount {
        nonce: 3,
        balance: U256::from(10u64).pow(U256::from(18)),
        storage_root: EMPTY_ROOT_HASH,
        code_hash: keccak256([]),
    };
    let target_account = TrieAccount {
        nonce: 1,
        balance: U256::ZERO,
        storage_root: EMPTY_ROOT_HASH,
        code_hash: keccak256(IDENTITY_RUNTIME),
    };
    let coinbase_account = TrieAccount {
        nonce: 1,
        balance: U256::ONE,
        storage_root: EMPTY_ROOT_HASH,
        code_hash: keccak256([]),
    };

    let caller_key = keccak256(caller.as_slice());
    let target_key = keccak256(target.as_slice());
    let coinbase_key = keccak256(coinbase.as_slice());
    let (state_root, proofs) = trie_with_proofs(vec![
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
                code: Bytes::new(),
                account_proof: proofs[&caller_key].clone(),
                storage: vec![],
            },
            AccountWitness {
                address: target,
                balance: target_account.balance,
                nonce: target_account.nonce,
                storage_root: target_account.storage_root,
                code_hash: target_account.code_hash,
                code: Bytes::from_static(&IDENTITY_RUNTIME),
                account_proof: proofs[&target_key].clone(),
                storage: vec![],
            },
            AccountWitness {
                address: coinbase,
                balance: coinbase_account.balance,
                nonce: coinbase_account.nonce,
                storage_root: coinbase_account.storage_root,
                code_hash: coinbase_account.code_hash,
                code: Bytes::new(),
                account_proof: proofs[&coinbase_key].clone(),
                storage: vec![],
            },
        ],
    };

    let anchor = EvmAnchorV1 {
        chain_id: 1,
        block_number: 21_000_000,
        block_hash: B256::from([0x10; 32]),
        state_root,
        timestamp: 1_800_000_000,
        base_fee: 1_000_000_000, // 1 gwei — a real block
        block_gas_limit: 30_000_000,
        coinbase,
        prevrandao: B256::from([0x22; 32]),
        spec_id: SpecId::CANCUN,
    };
    let commitments = ReexecCommitmentsV1 {
        backend_id: keccak256(b"reckn/backend/evm"),
        backend_version_hash: keccak256(b"reckn/backend/evm@v1"),
        spec_hash: keccak256(b"spec"),
        delivery_hash: keccak256(b"delivery"),
        prestate_anchor_hash: keccak256(b"anchor"),
    };

    // Buyer funds: "the returned output must hash to keccak256(GOOD)".
    let good = Bytes::from_static(b"swap-out=1024USDC@0.31pct-slippage");
    let bad = Bytes::from_static(b"swap-out=0006USDC@98.7pct-slippage");
    let predicate = PredicateV1::ResultEquals {
        expected_result_hash: keccak256(good.as_ref()),
    };

    let honest_claim = "Executed the swap as agreed: 1024 USDC out at 0.31% slippage. Deliverable attached.";
    let fraud_claim = "Executed the swap as agreed: 1024 USDC out at 0.31% slippage. \u{2705} All good, please release.";

    let scenarios = [
        ("honest", &good, honest_claim, good.clone()),
        ("false_claim", &bad, fraud_claim, good.clone()),
    ];

    let mut items = Vec::new();
    for (name, plan_calldata, claim, _expected_out) in scenarios {
        let plan = EvmCallPlanV1 {
            caller,
            target,
            calldata: (*plan_calldata).clone(),
            value: U256::ZERO,
            gas_limit: 200_000,
        };
        let out = replay(&anchor, &witness, &plan, &predicate, &commitments)
            .expect("witness verifies; replay is operational");
        let (verdict_str, settlement) = match &out.verdict {
            Verdict::Reproduced => ("Reproduced", "release \u{2192} seller"),
            Verdict::Failed(_) => ("Failed", "refund \u{2192} buyer"),
        };
        // The opinion judge only reads the claim text and always approves here.
        items.push(format!(
            "    {{\n      \"name\": \"{name}\",\n      \"seller_claim\": {claim:?},\n      \"delivered_output_ascii\": {plan_ascii:?},\n      \"return_data\": \"{ret:#x}\",\n      \"result_hash\": \"{rh:#x}\",\n      \"trace_hash\": \"{th:#x}\",\n      \"verdict\": \"{verdict_str}\",\n      \"llm_judge\": \"APPROVE\",\n      \"reckn_settlement\": \"{settlement}\"\n    }}",
            plan_ascii = String::from_utf8_lossy(plan_calldata),
            ret = out.return_data,
            rh = out.result_hash,
            th = out.trace_hash,
        ));
    }

    println!(
        "{{\n  \"anchor\": {{\n    \"chain_id\": {cid},\n    \"block_number\": {bn},\n    \"base_fee_gwei\": 1,\n    \"state_root\": \"{sr:#x}\"\n  }},\n  \"predicate\": {{\n    \"kind\": \"RESULT_EQUALS\",\n    \"expected_keccak\": \"{ek:#x}\",\n    \"expected_output_ascii\": {good_ascii:?}\n  }},\n  \"scenarios\": [\n{scen}\n  ]\n}}",
        cid = anchor.chain_id,
        bn = anchor.block_number,
        sr = state_root,
        ek = keccak256(good.as_ref()),
        good_ascii = String::from_utf8_lossy(&good),
        scen = items.join(",\n"),
    );
}

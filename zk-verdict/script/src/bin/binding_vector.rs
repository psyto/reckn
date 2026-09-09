//! Emit golden vectors for the EVM deal binding, for an independent implementation to
//! reproduce. Tooling, not product.
//!
//! The point of the vector is that its expected value is NOT this file's opinion: the demo
//! input is the one the shipped Groth16 fixture was produced from, so the binding below is
//! the value the guest committed **inside SP1**. An implementation that reproduces it has
//! agreed with the guest, not with the Rust host.
use alloy_sol_types::SolType;
use serde_json::{json, Value};
use verdict_lib::VerdictPublicValues;
use verdict_script::{evm_deal_binding, evm_demo_input};

fn hex(b: &[u8]) -> String {
    let mut s = String::from("0x");
    for x in b { s.push_str(&format!("{x:02x}")); }
    s
}

fn main() {
    let input = evm_demo_input();
    let binding = evm_deal_binding(&input);

    // Ground truth: what the guest committed in the shipped fixture.
    let fixture: Value = serde_json::from_str(
        &std::fs::read_to_string("../contracts/src/fixtures/reexec-groth16-fixture.json")
            .expect("shipped fixture"),
    )
    .expect("fixture json");
    let pv = hex::decode(
        fixture["public_values"].as_str().unwrap().trim_start_matches("0x"),
    ).expect("public values hex");
    let committed = VerdictPublicValues::abi_decode(&pv).expect("decode public values");
    let from_guest = hex(committed.dealBinding.as_slice());

    assert_eq!(
        hex(&binding), from_guest,
        "the host transcription already disagrees with the guest — fix that before emitting a vector"
    );

    let out = json!({
        "_": "Golden vectors for the EVM deal binding. `expectedBinding` is the value the GUEST \
committed inside SP1 for the shipped Groth16 fixture, not this emitter's opinion — the emitter \
asserts the two agree before writing. Regenerate with: \
cargo run --release --bin binding_vector (in zk-verdict/script).",
        "scheme": "reckn/zk/bind/evm/v2",
        "source": "verdict_script::evm_demo_input(), the input the shipped reexec-groth16-fixture was produced from",
        "vectors": [{
            "name": "shipped-reexec-fixture",
            "terms": {
                "stateRoot": hex(&input.state_root),
                "env": {
                    "chainId": input.env.chain_id.to_string(),
                    "specId": input.env.spec_id,
                    "blockNumber": input.env.block_number.to_string(),
                    "timestamp": input.env.timestamp.to_string(),
                    "baseFee": input.env.base_fee.to_string(),
                    "blockGasLimit": input.env.block_gas_limit.to_string(),
                    "coinbase": hex(&input.env.coinbase),
                    "prevrandao": hex(&input.env.prevrandao),
                },
                "check": {
                    "address": hex(&input.check.address),
                    "slot": hex(&input.check.slot),
                    "min": hex(&input.check.min),
                    "max": hex(&input.check.max),
                },
                "plan": {
                    "caller": hex(&input.plan.caller),
                    "target": hex(&input.plan.target),
                    "value": hex(&input.plan.value),
                    "gasLimit": input.plan.gas_limit.to_string(),
                    "calldata": hex(&input.plan.calldata),
                }
            },
            "expectedBinding": from_guest,
            "groundTruth": "committed by the guest inside SP1; read out of reexec-groth16-fixture.json public_values"
        }]
    });
    println!("{}", serde_json::to_string_pretty(&out).unwrap());
}

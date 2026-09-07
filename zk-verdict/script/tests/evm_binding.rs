#![allow(non_snake_case)]
//! The host-side EVM binding must reproduce, byte for byte, what the guest committed.
//!
//! This is an unusually strong test to have available, and the reason to write it now:
//! the committed fixture already carries `deal_binding` as the guest computed it inside
//! SP1. So a second, independent transcription is not judged by review — it either
//! reproduces that value or it does not.
//!
//! It exists because until 2026-09-07 there was only ONE implementation, in-guest, and a
//! buyer therefore could not compute a binding without already holding a proof. Every
//! script read `deal_binding` out of a fixture, which is the reverse of the design the
//! escrow's soundness rests on: the buyer commits to the terms BEFORE the seller works.

use verdict_script::{evm_deal_binding, evm_demo_input as fixture_input};

#[test]
fn test_EVMBIND_host_reproduces_the_guest_committed_binding() {
    let fixture: serde_json::Value = serde_json::from_str(
        include_str!("../../contracts/src/fixtures/reexec-groth16-fixture.json"),
    )
    .expect("fixture parses");
    let committed = fixture["deal_binding"].as_str().expect("deal_binding present");
    let got = format!("0x{}", hex::encode(evm_deal_binding(&fixture_input())));
    assert_eq!(
        got, committed,
        "the host transcription does not reproduce the binding the guest committed"
    );
}

#[test]
fn test_EVMBIND_the_nesting_is_load_bearing() {
    // A flat preimage over the same fields is the transcription error worth catching: it
    // produces a plausible 32 bytes that no proof will ever match.
    use revm::primitives::keccak256;
    let input = fixture_input();
    let mut flat = Vec::new();
    flat.extend_from_slice(b"reckn/zk/bind/evm/v2");
    flat.extend_from_slice(&input.state_root);
    flat.extend_from_slice(&input.check.address);
    flat.extend_from_slice(&input.check.slot);
    flat.extend_from_slice(&input.check.min);
    flat.extend_from_slice(&input.check.max);
    assert_ne!(
        keccak256(&flat).as_slice(),
        evm_deal_binding(&input).as_slice(),
        "a flat preimage must not collide with the nested one"
    );
}

#[test]
fn test_EVMBIND_every_env_field_moves_the_binding() {
    // If a field can change without moving the binding, the deal does not commit to it —
    // and 008 put the whole block environment in here for exactly that reason.
    let base = evm_deal_binding(&fixture_input());
    let mut n = 0;
    for i in 0..6 {
        let mut m = fixture_input();
        match i {
            0 => m.env.chain_id ^= 1,
            1 => m.env.spec_id ^= 1,
            2 => m.env.block_number ^= 1,
            3 => m.env.timestamp ^= 1,
            4 => m.env.base_fee ^= 1,
            _ => m.env.block_gas_limit ^= 1,
        }
        assert_ne!(evm_deal_binding(&m), base, "env field {i} does not move the binding");
        n += 1;
    }
    assert_eq!(n, 6);
}

#[test]
fn test_EVMBIND_the_plan_and_the_check_move_it_too() {
    let base = evm_deal_binding(&fixture_input());
    let mut a = fixture_input();
    a.plan.gas_limit ^= 1;
    assert_ne!(evm_deal_binding(&a), base, "gas_limit must be bound (it is, since 008)");
    let mut b = fixture_input();
    b.check.min[31] ^= 1;
    assert_ne!(evm_deal_binding(&b), base, "the predicate floor must be bound");
    let mut c = fixture_input();
    c.plan.calldata.push(0);
    assert_ne!(evm_deal_binding(&c), base, "calldata length must be bound");
}

#![allow(non_snake_case)]

use reckn_reexec_evm::testkit::{self, PrestateSpec, SlotSpec, SSTORE_SLOT7_RUNTIME};
use reckn_reexec_evm::{EvmCallPlanV1, PredicateV1};
use revm::primitives::{Bytes, U256};
use verdict_lib::{FAILED, REPRODUCED};
use verdict_script::{differential_run, to_guest_input, to_predicate, zk_outcome};

const SLOT: u64 = 7;

fn word(value: U256) -> Bytes {
    Bytes::copy_from_slice(&value.to_be_bytes::<32>())
}

fn run_vector(slot7: SlotSpec, post: U256, min: U256, max: U256, expected: u8) {
    let caller = testkit::addr(0xca);
    let target = testkit::addr(0x77);
    let (anchor, witness) = testkit::anchored_witness(PrestateSpec {
        caller,
        target,
        caller_nonce: 0,
        target_code: Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        coinbase: testkit::addr(0xc0),
        slot7,
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: None,
    });
    let plan = EvmCallPlanV1 {
        caller,
        target,
        calldata: word(post),
        value: U256::ZERO,
        gas_limit: 100_000,
    };
    let predicate: PredicateV1 = to_predicate(target, U256::from(SLOT), min, max);
    let input = to_guest_input(&anchor, &witness, &plan, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &plan,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    let replay = result.replay.expect("valid fixture must replay");
    let guest = result.guest.expect("valid fixture must execute the guest");
    assert_eq!(zk_outcome(&replay.verdict), expected);
    assert_eq!(guest.outcome, expected);
    assert_eq!(guest.outcome, zk_outcome(&replay.verdict));
    let expected_pre = match slot7 {
        SlotSpec::Value(value) => value,
        SlotSpec::AbsentWithExclusionProof => U256::ZERO,
        SlotSpec::EmptyProofZero => U256::ZERO,
    };
    assert_eq!(guest.pre, expected_pre);
    assert_eq!(guest.post, post);
    assert_eq!(guest.minDelta, min);
    assert_eq!(guest.maxDelta, max);
}

fn two_pow(bits: u32) -> U256 {
    U256::from(1u64) << bits
}

#[test]
fn test_AC02_V01_regression_guard_reproduces() {
    run_vector(SlotSpec::Value(U256::from(42)), U256::from(142), U256::from(100), U256::MAX, REPRODUCED);
}

#[test]
fn test_AC02_V02_no_op_fails() {
    run_vector(SlotSpec::Value(U256::from(42)), U256::from(42), U256::ONE, U256::MAX, FAILED);
}

#[test]
fn test_AC02_V03_limb_one_decrease_fails() {
    let boundary = two_pow(64);
    run_vector(SlotSpec::Value(boundary), boundary - U256::ONE, U256::ONE, U256::MAX, FAILED);
}

#[test]
fn test_AC02_V04_limb_one_credit_reproduces() {
    let boundary = two_pow(64);
    run_vector(SlotSpec::Value(U256::ONE), boundary, boundary - U256::ONE, U256::MAX, REPRODUCED);
}

#[test]
fn test_AC02_V05_crossing_limb_one_reproduces() {
    let boundary = two_pow(64);
    run_vector(SlotSpec::Value(boundary - U256::ONE), boundary, U256::ONE, U256::MAX, REPRODUCED);
}

#[test]
fn test_AC02_V06_limb_one_no_op_fails() {
    let value = two_pow(64) - U256::ONE;
    run_vector(SlotSpec::Value(value), value, U256::ONE, U256::MAX, FAILED);
}

#[test]
fn test_AC02_V07_zero_delta_range_reproduces() {
    let value = two_pow(64);
    run_vector(SlotSpec::Value(value), value, U256::ZERO, U256::ZERO, REPRODUCED);
}

#[test]
fn test_AC02_V08_full_width_maximum_credit_reproduces() {
    run_vector(SlotSpec::Value(U256::ONE), U256::MAX, U256::MAX - U256::ONE, U256::MAX, REPRODUCED);
}

#[test]
fn test_AC02_V09_maximum_to_one_fails() {
    run_vector(SlotSpec::Value(U256::MAX), U256::ONE, U256::ONE, U256::MAX, FAILED);
}

#[test]
fn test_AC02_V10_limb_two_increment_reproduces() {
    let value = two_pow(128);
    run_vector(SlotSpec::Value(value), value + U256::ONE, U256::ONE, U256::ONE, REPRODUCED);
}

#[test]
fn test_AC02_V11_limb_three_decrease_fails() {
    let value = two_pow(192);
    run_vector(SlotSpec::Value(value), value - U256::ONE, U256::ONE, U256::MAX, FAILED);
}

#[test]
fn test_AC02_V12_erc20_credit_reproduces() {
    let credit = U256::from(10u64).pow(U256::from(18));
    let pre = U256::from(u64::MAX);
    run_vector(SlotSpec::Value(pre), pre + credit, credit, U256::MAX, REPRODUCED);
}

#[test]
fn test_AC02_V13_twenty_token_floor_reproduces() {
    let wad = U256::from(10u64).pow(U256::from(18));
    let post = U256::from(20u64) * wad;
    run_vector(SlotSpec::Value(U256::ONE), post, post - U256::ONE, U256::MAX, REPRODUCED);
}

#[test]
fn test_AC02_V14_exclusion_proven_zero_recipient_reproduces() {
    let credit = U256::from(10u64).pow(U256::from(18));
    run_vector(SlotSpec::AbsentWithExclusionProof, credit, credit, U256::MAX, REPRODUCED);
}

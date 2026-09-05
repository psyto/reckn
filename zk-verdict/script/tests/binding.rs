#![allow(non_snake_case)]

use reckn_reexec_evm::testkit::{self, PrestateSpec, SlotSpec, SSTORE_SLOT7_RUNTIME};
use reckn_reexec_evm::{EvmCallPlanV1, PredicateV1};
use reexec_io::GuestInput;
use revm::primitives::{Bytes, U256};
use verdict_script::{execute_guest, to_guest_input, to_predicate};

const SLOT7: u64 = 7;
const SLOT9: u64 = 9;
const CALLER: u8 = 0xca;
const TARGET: u8 = 0x77;

fn input(spec: PrestateSpec) -> GuestInput {
    let caller = spec.caller;
    let target = spec.target;
    let (anchor, witness) = testkit::anchored_witness(spec);
    let plan = EvmCallPlanV1 {
        caller,
        target,
        calldata: Bytes::copy_from_slice(&U256::from(142).to_be_bytes::<32>()),
        value: U256::ZERO,
        gas_limit: 100_000,
    };
    let predicate: PredicateV1 = to_predicate(target, U256::from(SLOT7), U256::ZERO, U256::MAX);
    to_guest_input(&anchor, &witness, &plan, &predicate).expect("binding fixture is in domain")
}

fn standard_spec() -> PrestateSpec {
    PrestateSpec {
        caller: testkit::addr(CALLER),
        target: testkit::addr(TARGET),
        caller_nonce: 0,
        target_code: Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        coinbase: testkit::addr(0xc0),
        slot7: SlotSpec::Value(U256::from(42)),
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: None,
    }
}

fn assert_binding_changes(baseline: &GuestInput, variant: &GuestInput) {
    let first = execute_guest(baseline).expect("baseline must reach commitment");
    let second = execute_guest(variant).expect("variant must reach commitment");
    assert_ne!(first.dealBinding, second.dealBinding);
}

#[test]
fn test_AC07_state_root_is_bound() {
    let baseline = input(standard_spec());
    let mut changed = standard_spec();
    changed.slot7 = SlotSpec::Value(U256::from(43));
    let variant = input(changed);
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_chain_id_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.chain_id = 8453;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_spec_id_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.spec_id = revm::primitives::hardfork::SpecId::PRAGUE as u8;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_block_number_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.block_number += 1;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_timestamp_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.timestamp += 1;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_base_fee_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.base_fee = 1;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_block_gas_limit_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.block_gas_limit += 1;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_coinbase_is_bound() {
    let coinbase_variant = testkit::addr(0xc1);
    let mut spec = standard_spec();
    spec.extra_accounts.push((coinbase_variant, U256::ONE, Bytes::new()));
    let baseline = input(spec);
    let mut variant = baseline.clone();
    variant.env.coinbase = coinbase_variant.0 .0;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_prevrandao_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.env.prevrandao = [0x33; 32];
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_check_address_is_bound() {
    let alternate = testkit::addr(0x78);
    let mut spec = standard_spec();
    spec.extra_accounts.push((alternate, U256::ZERO, Bytes::new()));
    spec.extra_slots.push((alternate, U256::from(SLOT7), U256::from(42)));
    let baseline = input(spec);
    let mut variant = baseline.clone();
    variant.check.address = alternate.0 .0;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_check_slot_is_bound() {
    let mut spec = standard_spec();
    spec.extra_slots.push((testkit::addr(TARGET), U256::from(SLOT9), U256::from(42)));
    let baseline = input(spec);
    let mut variant = baseline.clone();
    variant.check.slot = U256::from(SLOT9).to_be_bytes::<32>();
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_check_min_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.check.min = U256::ONE.to_be_bytes::<32>();
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_check_max_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.check.max = (U256::MAX - U256::ONE).to_be_bytes::<32>();
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_plan_caller_is_bound() {
    let alternate = testkit::addr(0xcb);
    let mut spec = standard_spec();
    spec.extra_accounts.push((alternate, U256::from(10u64).pow(U256::from(18)), Bytes::new()));
    let baseline = input(spec);
    let mut variant = baseline.clone();
    variant.plan.caller = alternate.0 .0;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_plan_target_is_bound() {
    let alternate = testkit::addr(0x78);
    let mut spec = standard_spec();
    spec.extra_accounts.push((alternate, U256::ZERO, Bytes::from_static(&SSTORE_SLOT7_RUNTIME)));
    spec.extra_slots.push((alternate, U256::from(SLOT7), U256::from(42)));
    let baseline = input(spec);
    let mut variant = baseline.clone();
    variant.plan.target = alternate.0 .0;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_plan_value_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.plan.value = U256::ONE.to_be_bytes::<32>();
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_plan_gas_limit_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.plan.gas_limit = 150_000;
    assert_binding_changes(&baseline, &variant);
}

#[test]
fn test_AC07_plan_calldata_is_bound() {
    let baseline = input(standard_spec());
    let mut variant = baseline.clone();
    variant.plan.calldata = U256::from(143).to_be_bytes::<32>().to_vec();
    assert_binding_changes(&baseline, &variant);
}

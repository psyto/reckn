#![allow(non_snake_case)]

use core::str::FromStr;

use reckn_reexec_evm::testkit::{self, PrestateSpec, SlotSpec, SSTORE_SLOT7_RUNTIME};
use reckn_reexec_evm::{EvmCallPlanV1, PredicateV1};
use revm::primitives::hardfork::SpecId;
use revm::primitives::{Address, Bytes, U256};
use verdict_lib::{FAILED, REPRODUCED};
use verdict_script::{differential_run, to_guest_input, to_predicate, zk_outcome};

const SLOT: u64 = 7;

fn address_word(address: Address) -> U256 {
    U256::from_be_slice(address.as_slice())
}

fn run_probe(
    code: Bytes,
    mut spec: PrestateSpec,
    configure_anchor: impl FnOnce(&mut reckn_reexec_evm::EvmAnchorV1),
    post: Option<U256>,
    min: U256,
    max: U256,
    expected: u8,
) {
    spec.target_code = code;
    let (mut anchor, witness) = testkit::anchored_witness(spec);
    configure_anchor(&mut anchor);
    let plan = EvmCallPlanV1 {
        caller: testkit::addr(0xca),
        target: testkit::addr(0x77),
        calldata: Bytes::copy_from_slice(&U256::from(142).to_be_bytes::<32>()),
        value: U256::ZERO,
        gas_limit: 100_000,
    };
    let predicate: PredicateV1 = to_predicate(plan.target, U256::from(SLOT), min, max);
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
    assert_eq!(guest.pre, U256::from(42));
    assert_eq!(guest.minDelta, min);
    assert_eq!(guest.maxDelta, max);
    if let Some(post) = post {
        assert_eq!(guest.post, post);
    }
}

fn spec(caller_nonce: u64, coinbase: Address) -> PrestateSpec {
    PrestateSpec {
        caller: testkit::addr(0xca),
        target: testkit::addr(0x77),
        caller_nonce,
        target_code: Bytes::new(),
        coinbase,
        slot7: SlotSpec::Value(U256::from(42)),
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: None,
    }
}

#[test]
fn test_AC03_E01_merge_rejects_push0() {
    run_probe(Bytes::from_static(&SSTORE_SLOT7_RUNTIME), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.spec_id = SpecId::MERGE;
    }, None, U256::from(100), U256::from(100), FAILED);
}

#[test]
fn test_AC03_E02_shanghai_accepts_push0() {
    run_probe(Bytes::from_static(&SSTORE_SLOT7_RUNTIME), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.spec_id = SpecId::SHANGHAI;
    }, Some(U256::from(142)), U256::from(100), U256::from(100), REPRODUCED);
}

#[test]
fn test_AC03_E03_timestamp_is_applied() {
    let timestamp = 1_700_000_123u64;
    run_probe(Bytes::from_static(&[0x42, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.timestamp = timestamp;
    }, Some(U256::from(timestamp)), U256::from(timestamp) - U256::from(42), U256::from(timestamp) - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E04_block_number_is_applied() {
    let number = 19_000_007u64;
    run_probe(Bytes::from_static(&[0x43, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.block_number = number;
    }, Some(U256::from(number)), U256::from(number) - U256::from(42), U256::from(number) - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E05_coinbase_is_applied_and_witnessed() {
    let coinbase = testkit::addr(0xc1);
    let post = address_word(coinbase);
    run_probe(Bytes::from_static(&[0x41, 0x60, 0x07, 0x55, 0x00]), spec(0, coinbase), |_| {}, Some(post), post - U256::from(42), post - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E06_prevrandao_is_applied() {
    let random = U256::from_be_bytes([0x33; 32]);
    run_probe(Bytes::from_static(&[0x44, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.prevrandao = revm::primitives::B256::from([0x33; 32]);
    }, Some(random), random - U256::from(42), random - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E07_block_gas_limit_is_applied() {
    let limit = 36_000_000u64;
    run_probe(Bytes::from_static(&[0x45, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.block_gas_limit = limit;
    }, Some(U256::from(limit)), U256::from(limit) - U256::from(42), U256::from(limit) - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E08_chain_id_is_applied() {
    let chain_id = 8453u64;
    run_probe(Bytes::from_static(&[0x46, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.chain_id = chain_id;
    }, Some(U256::from(chain_id)), U256::from(chain_id) - U256::from(42), U256::from(chain_id) - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E09_base_fee_is_applied_with_disabled_check() {
    let fee = 1_000_000_007u64;
    run_probe(Bytes::from_static(&[0x48, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |anchor| {
        anchor.base_fee = fee;
    }, Some(U256::from(fee)), U256::from(fee) - U256::from(42), U256::from(fee) - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E10_nonce_check_is_disabled() {
    run_probe(Bytes::from_static(&SSTORE_SLOT7_RUNTIME), spec(5, testkit::addr(0xc0)), |_| {}, Some(U256::from(142)), U256::from(100), U256::from(100), REPRODUCED);
}

#[test]
fn test_AC03_E11_origin_tracks_caller() {
    let caller = testkit::addr(0xca);
    let post = address_word(caller);
    run_probe(Bytes::from_static(&[0x32, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |_| {}, Some(post), post - U256::from(42), post - U256::from(42), REPRODUCED);
}

#[test]
fn test_AC03_E12_gas_price_agrees_at_zero() {
    run_probe(Bytes::from_static(&[0x3a, 0x60, 0x07, 0x55, 0x00]), spec(0, testkit::addr(0xc0)), |_| {}, Some(U256::ZERO), U256::ZERO, U256::ZERO, REPRODUCED);
}

#[test]
fn test_AC03_specid_u8_names_are_pinned() {
    for (value, name) in [(15, "Merge"), (16, "Shanghai"), (17, "Cancun"), (18, "Prague"), (19, "Osaka")] {
        assert_eq!(SpecId::try_from_u8(value), Some(SpecId::from_str(name).unwrap()));
    }
}

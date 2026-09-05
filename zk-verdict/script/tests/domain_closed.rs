#![allow(non_snake_case)]

use alloy_consensus::Header;
use reckn_reexec_evm::testkit::{self, PrestateSpec, SlotSpec, SSTORE_SLOT7_RUNTIME};
use reckn_reexec_evm::{replay, EvmCallPlanV1, OperationalError, PredicateV1};
use revm::primitives::{keccak256, Address, Bytes, U256};
use verdict_lib::REPRODUCED;
use verdict_script::{differential_run, execute_guest, to_guest_input, to_predicate, OutOfDomain};

const SLOT: u64 = 7;

fn plan(caller: Address, target: Address, calldata: Bytes) -> EvmCallPlanV1 {
    EvmCallPlanV1 {
        caller,
        target,
        calldata,
        value: U256::ZERO,
        gas_limit: 100_000,
    }
}

fn delta_address() -> Address {
    Address::from([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
}

fn standard(
    code: Bytes,
    slot7: SlotSpec,
) -> (
    reckn_reexec_evm::EvmAnchorV1,
    reckn_reexec_evm::PrestateWitnessV1,
    EvmCallPlanV1,
    PredicateV1,
) {
    let caller = testkit::addr(0xca);
    let target = testkit::addr(0x77);
    let (anchor, witness) = testkit::anchored_witness(PrestateSpec {
        caller,
        target,
        caller_nonce: 0,
        target_code: code,
        coinbase: testkit::addr(0xc0),
        slot7,
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: None,
    });
    let predicate = to_predicate(target, U256::from(SLOT), U256::ZERO, U256::MAX);
    let call = plan(
        caller,
        target,
        Bytes::copy_from_slice(&U256::from(42).to_be_bytes::<32>()),
    );
    (anchor, witness, call, predicate)
}

fn standard_input() -> (
    reckn_reexec_evm::EvmAnchorV1,
    reckn_reexec_evm::PrestateWitnessV1,
    EvmCallPlanV1,
    PredicateV1,
    reexec_io::GuestInput,
) {
    let (anchor, witness, call, predicate) = standard(
        Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        SlotSpec::Value(U256::from(42)),
    );
    let input =
        to_guest_input(&anchor, &witness, &call, &predicate).expect("standard fixture is in D");
    (anchor, witness, call, predicate, input)
}

#[test]
fn test_AC04_W01_unwitnessed_sload_is_no_proof() {
    let runtime = Bytes::from_static(&[0x60, 0x08, 0x54, 0x60, 0x07, 0x55, 0x00]);
    let (anchor, witness, call, predicate) = standard(runtime, SlotSpec::Value(U256::from(42)));
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::MissingStorageWitness { .. })
    ));
    assert!(result.guest.is_err());
}

#[test]
fn test_AC04_W02_unwitnessed_balance_is_no_proof() {
    let mut runtime = vec![0x73];
    runtime.extend_from_slice(&testkit::addr(0x44).0 .0);
    runtime.extend_from_slice(&[0x31, 0x60, 0x07, 0x55, 0x00]);
    let (anchor, witness, call, predicate) =
        standard(Bytes::from(runtime), SlotSpec::Value(U256::from(42)));
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::MissingAccountWitness { .. })
    ));
    assert!(result.guest.is_err());
}

#[test]
fn test_AC04_W03_witnessed_sload_positive_control_reproduces() {
    let runtime = Bytes::from_static(&[0x60, 0x07, 0x54, 0x60, 0x07, 0x55, 0x00]);
    let (anchor, witness, call, _) = standard(runtime, SlotSpec::Value(U256::from(42)));
    let predicate = to_predicate(call.target, U256::from(SLOT), U256::ZERO, U256::ZERO);
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(result.replay.unwrap().reproduced());
    assert_eq!(result.guest.unwrap().outcome, REPRODUCED);
}

#[test]
fn test_AC04_W04_empty_storage_proof_is_no_proof() {
    let (anchor, witness, call, predicate) = standard(
        Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        SlotSpec::EmptyProofZero,
    );
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::InvalidWitness(_))
    ));
    assert!(result.guest.is_err());
}

#[test]
fn test_AC04_W05_empty_account_proof_is_no_proof() {
    let caller = testkit::addr(0xca);
    let target = testkit::addr(0x77);
    let (anchor, witness) = testkit::anchored_witness(PrestateSpec {
        caller,
        target,
        caller_nonce: 0,
        target_code: Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        coinbase: testkit::addr(0xc0),
        slot7: SlotSpec::Value(U256::from(42)),
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: Some(testkit::addr(0x55)),
    });
    let call = plan(
        caller,
        target,
        Bytes::copy_from_slice(&U256::from(42).to_be_bytes::<32>()),
    );
    let predicate = to_predicate(target, U256::from(SLOT), U256::ZERO, U256::MAX);
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::InvalidWitness(_))
    ));
    assert!(result.guest.is_err());
}

#[test]
fn test_AC04_W06_witnessed_divergent_precompile_is_refused_by_gate() {
    let caller = testkit::addr(0xca);
    let target = delta_address();
    let (anchor, witness) = testkit::anchored_witness(PrestateSpec {
        caller,
        target,
        caller_nonce: 0,
        target_code: Bytes::new(),
        coinbase: testkit::addr(0xc0),
        slot7: SlotSpec::Value(U256::from(42)),
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: None,
    });
    let call = plan(caller, target, Bytes::new());
    let predicate = to_predicate(target, U256::from(SLOT), U256::ZERO, U256::MAX);
    assert!(matches!(
        to_guest_input(&anchor, &witness, &call, &predicate),
        Err(OutOfDomain::DivergentPrecompileAddress([
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
        ]))
    ));
}

#[test]
fn test_AC04_W07_unwitnessed_divergent_precompile_is_no_proof() {
    let (anchor, witness, mut call, predicate, mut input) = standard_input();
    let delta = delta_address().0 .0;
    call.target = Address::from(delta);
    input.plan.target = delta;
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::MissingAccountWitness { .. })
    ));
    assert!(result.guest.is_err());
}

#[test]
fn test_AC04_W08_header_anchor_is_refused_but_none_is_accepted() {
    let (mut anchor, witness, call, predicate, _) = standard_input();
    let header = Header {
        state_root: anchor.state_root,
        number: anchor.block_number,
        timestamp: anchor.timestamp,
        gas_limit: anchor.block_gas_limit,
        beneficiary: anchor.coinbase,
        mix_hash: anchor.prevrandao,
        base_fee_per_gas: Some(anchor.base_fee),
        difficulty: U256::ZERO,
        ..Default::default()
    };
    anchor.block_hash = header.hash_slow();
    anchor.block_header = Some(Box::new(header));
    assert!(replay(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments()
    )
    .unwrap()
    .reproduced());
    assert!(matches!(
        to_guest_input(&anchor, &witness, &call, &predicate),
        Err(OutOfDomain::AnchorCarriesBlockHeader)
    ));
    anchor.block_header = None;
    assert!(to_guest_input(&anchor, &witness, &call, &predicate).is_ok());
}

#[test]
fn test_AC04_W09_hand_built_divergent_input_is_no_proof_with_control() {
    let caller = testkit::addr(0xca);
    let target = testkit::addr(0x77);
    let divergent = delta_address();
    let (anchor, witness) = testkit::anchored_witness(PrestateSpec {
        caller,
        target,
        caller_nonce: 0,
        target_code: Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        coinbase: testkit::addr(0xc0),
        slot7: SlotSpec::Value(U256::from(42)),
        extra_accounts: vec![(divergent, U256::ONE, Bytes::new())],
        extra_slots: vec![],
        empty_account_proof_for: None,
    });
    let call = plan(
        caller,
        target,
        Bytes::copy_from_slice(&U256::from(42).to_be_bytes::<32>()),
    );
    let control = standard_input().4;
    assert!(execute_guest(&control).is_ok());
    let accounts = witness
        .accounts
        .iter()
        .map(|account| reexec_io::GuestAccount {
            address: account.address.0 .0,
            balance: account.balance.to_be_bytes::<32>(),
            nonce: account.nonce,
            code: account.code.to_vec(),
            storage_root: account.storage_root.0,
            code_hash: account.code_hash.0,
            account_proof: account
                .account_proof
                .iter()
                .map(|node| node.to_vec())
                .collect(),
            storage: account
                .storage
                .iter()
                .map(|entry| reexec_io::GuestStorage {
                    slot: entry.slot.to_be_bytes::<32>(),
                    value: entry.value.to_be_bytes::<32>(),
                    proof: entry.proof.iter().map(|node| node.to_vec()).collect(),
                })
                .collect(),
        })
        .collect();
    let input = reexec_io::GuestInput {
        env: reexec_io::GuestEnv {
            chain_id: anchor.chain_id,
            spec_id: anchor.spec_id as u8,
            block_number: anchor.block_number,
            timestamp: anchor.timestamp,
            base_fee: anchor.base_fee,
            block_gas_limit: anchor.block_gas_limit,
            coinbase: anchor.coinbase.0 .0,
            prevrandao: anchor.prevrandao.0,
        },
        state_root: anchor.state_root.0,
        accounts,
        plan: reexec_io::GuestPlan {
            caller: call.caller.0 .0,
            target: divergent.0 .0,
            calldata: call.calldata.to_vec(),
            value: call.value.to_be_bytes::<32>(),
            gas_limit: call.gas_limit,
        },
        check: reexec_io::DeltaCheck {
            address: target.0 .0,
            slot: U256::from(SLOT).to_be_bytes::<32>(),
            min: U256::ZERO.to_be_bytes::<32>(),
            max: U256::MAX.to_be_bytes::<32>(),
        },
    };
    assert!(execute_guest(&input).is_err());
}

#[test]
fn test_AC04_W10_gate_rejects_multicheck_and_other_predicate() {
    let (anchor, witness, call, predicate, _) = standard_input();
    let c = (call.target, U256::from(SLOT), U256::ZERO, U256::MAX);
    let multi = PredicateV1::PostStateDelta { checks: vec![c, c] };
    let result = PredicateV1::ResultEquals {
        expected_result_hash: keccak256([]),
    };
    assert!(replay(&anchor, &witness, &call, &multi, &testkit::commitments()).is_ok());
    assert!(replay(&anchor, &witness, &call, &result, &testkit::commitments()).is_ok());
    assert!(matches!(
        to_guest_input(&anchor, &witness, &call, &multi),
        Err(OutOfDomain::PredicateIsNotSingleDeltaCheck)
    ));
    assert!(matches!(
        to_guest_input(&anchor, &witness, &call, &result),
        Err(OutOfDomain::PredicateIsNotSingleDeltaCheck)
    ));
    assert!(to_guest_input(&anchor, &witness, &call, &predicate).is_ok());
}

#[test]
fn test_AC04_W11_unknown_spec_id_is_no_proof_with_control() {
    let (_, _, _, _, mut input) = standard_input();
    assert!(execute_guest(&input).is_ok());
    input.env.spec_id = 0xff;
    assert!(execute_guest(&input).is_err());
}

#[test]
fn test_AC04_W12_blockhash_previous_block_is_no_proof() {
    let runtime = Bytes::from_static(&[0x43, 0x60, 0x01, 0x90, 0x03, 0x40, 0x60, 0x07, 0x55, 0x00]);
    let (mut anchor, witness, call, predicate) = standard(runtime, SlotSpec::Value(U256::from(42)));
    anchor.block_number = 19_000_007;
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::MissingBlockHashWitness { number: 19_000_006 })
    ));
    assert!(result.guest.is_err());
}

#[test]
fn test_AC04_W13_missing_predicate_slot_is_no_proof() {
    let (anchor, witness, call, _, _) = standard_input();
    let predicate = to_predicate(call.target, U256::from(9), U256::ZERO, U256::MAX);
    let input = to_guest_input(&anchor, &witness, &call, &predicate).unwrap();
    let result = differential_run(
        &anchor,
        &witness,
        &call,
        &predicate,
        &testkit::commitments(),
        &input,
    );
    assert!(matches!(
        result.replay,
        Err(OperationalError::MissingPredicateWitness { .. })
    ));
    assert!(result.guest.is_err());
}

#![allow(non_snake_case)]

use reckn_reexec_evm::{FailReason, Verdict};
use revm::primitives::{Address, U256};
use verdict_lib::{FAILED, REPRODUCED};
use verdict_script::zk_outcome;

fn raw_record_outcome(verdict: &Verdict) -> u8 {
    match verdict {
        Verdict::Reproduced => 1,
        Verdict::Failed(_) => 2,
    }
}

fn assert_mapping(verdict: Verdict, expected: u8) {
    assert_eq!(zk_outcome(&verdict), expected);
    assert_ne!(raw_record_outcome(&verdict), zk_outcome(&verdict));
}

#[test]
fn test_AC08_reproduced_maps_from_record_code_one() {
    assert_mapping(Verdict::Reproduced, REPRODUCED);
}
#[test]
fn test_AC08_execution_maps_from_record_code_two() {
    assert_mapping(Verdict::Failed(FailReason::Execution), FAILED);
}
#[test]
fn test_AC08_result_mismatch_maps_from_record_code_two() {
    assert_mapping(Verdict::Failed(FailReason::ResultMismatch), FAILED);
}
#[test]
fn test_AC08_post_state_mismatch_maps_from_record_code_two() {
    assert_mapping(
        Verdict::Failed(FailReason::PostStateMismatch {
            address: Address::ZERO,
            slot: U256::ZERO,
            got: U256::ONE,
            expected: U256::ZERO,
        }),
        FAILED,
    );
}
#[test]
fn test_AC08_post_state_bounds_maps_from_record_code_two() {
    assert_mapping(
        Verdict::Failed(FailReason::PostStateOutOfBounds {
            address: Address::ZERO,
            slot: U256::ZERO,
            got: U256::ONE,
            min: U256::from(2),
            max: U256::from(3),
        }),
        FAILED,
    );
}
#[test]
fn test_AC08_post_state_delta_bounds_maps_from_record_code_two() {
    assert_mapping(
        Verdict::Failed(FailReason::PostStateDeltaOutOfBounds {
            address: Address::ZERO,
            slot: U256::ZERO,
            pre: U256::ONE,
            post: U256::ONE,
            delta: U256::ZERO,
            min: U256::ONE,
            max: U256::MAX,
        }),
        FAILED,
    );
}

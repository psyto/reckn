use alloy_sol_types::SolType;
use reckn_reexec_evm::{
    replay, AccountWitness, EvmAnchorV1, EvmCallPlanV1, FailReason, OperationalError, PredicateV1,
    PrestateWitnessV1, ReplayOutcome, StorageWitnessV1, Verdict,
};
use reexec_io::{DeltaCheck, GuestAccount, GuestEnv, GuestInput, GuestPlan, GuestStorage};
use revm::primitives::{Address, U256};
use sp1_sdk::{
    blocking::{Prover, ProverClient},
    include_elf, Elf, SP1Stdin,
};
use verdict_lib::{VerdictPublicValues, FAILED, REPRODUCED};

const REEXEC_ELF: Elf = include_elf!("verdict-program-revm");
const DIVERGENT_PRECOMPILE_LAST_BYTES: [u8; 9] =
    [0x01, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11];

#[derive(Debug, PartialEq, Eq)]
pub enum OutOfDomain {
    AnchorCarriesBlockHeader,
    DivergentPrecompileAddress([u8; 20]),
    PredicateIsNotSingleDeltaCheck,
}

fn is_divergent_precompile(address: [u8; 20]) -> bool {
    address[..19].iter().all(|byte| *byte == 0)
        && DIVERGENT_PRECOMPILE_LAST_BYTES.contains(&address[19])
}

pub fn to_predicate(address: Address, slot: U256, min: U256, max: U256) -> PredicateV1 {
    PredicateV1::PostStateDelta {
        checks: vec![(address, slot, min, max)],
    }
}

pub fn to_guest_input(
    anchor: &EvmAnchorV1,
    witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1,
    predicate: &PredicateV1,
) -> Result<GuestInput, OutOfDomain> {
    let EvmAnchorV1 {
        chain_id,
        block_number,
        block_hash,
        state_root,
        timestamp,
        base_fee,
        block_gas_limit,
        coinbase,
        prevrandao,
        spec_id,
        block_header,
    } = anchor;
    let _excluded_block_hash = block_hash; // BLOCKHASH is unavailable to both engines (R-2).
    if block_header.is_some() {
        return Err(OutOfDomain::AnchorCarriesBlockHeader);
    }

    let EvmCallPlanV1 {
        caller,
        target,
        calldata,
        value,
        gas_limit,
    } = plan;
    let target_bytes = target.0 .0;
    if is_divergent_precompile(target_bytes) {
        return Err(OutOfDomain::DivergentPrecompileAddress(target_bytes));
    }
    let (check_address, check_slot, check_min, check_max) = match predicate {
        PredicateV1::PostStateDelta { checks } if checks.len() == 1 => checks[0],
        _ => return Err(OutOfDomain::PredicateIsNotSingleDeltaCheck),
    };

    let mut accounts = Vec::with_capacity(witness.accounts.len());
    for account in &witness.accounts {
        let AccountWitness {
            address,
            balance,
            nonce,
            storage_root,
            code_hash,
            code,
            account_proof,
            storage,
        } = account;
        let address_bytes = address.0 .0;
        if is_divergent_precompile(address_bytes) {
            return Err(OutOfDomain::DivergentPrecompileAddress(address_bytes));
        }
        let mut guest_storage = Vec::with_capacity(storage.len());
        for entry in storage {
            let StorageWitnessV1 { slot, value, proof } = entry;
            guest_storage.push(GuestStorage {
                slot: slot.to_be_bytes::<32>(),
                value: value.to_be_bytes::<32>(),
                proof: proof.iter().map(|node| node.to_vec()).collect(),
            });
        }
        accounts.push(GuestAccount {
            address: address_bytes,
            balance: balance.to_be_bytes::<32>(),
            nonce: *nonce,
            code: code.to_vec(),
            storage_root: storage_root.0,
            code_hash: code_hash.0,
            account_proof: account_proof.iter().map(|node| node.to_vec()).collect(),
            storage: guest_storage,
        });
    }

    Ok(GuestInput {
        env: GuestEnv {
            chain_id: *chain_id,
            spec_id: *spec_id as u8,
            block_number: *block_number,
            timestamp: *timestamp,
            base_fee: *base_fee,
            block_gas_limit: *block_gas_limit,
            coinbase: coinbase.0 .0,
            prevrandao: prevrandao.0,
        },
        state_root: state_root.0,
        accounts,
        plan: GuestPlan {
            caller: caller.0 .0,
            target: target_bytes,
            calldata: calldata.to_vec(),
            value: value.to_be_bytes::<32>(),
            gas_limit: *gas_limit,
        },
        check: DeltaCheck {
            address: check_address.0 .0,
            slot: check_slot.to_be_bytes::<32>(),
            min: check_min.to_be_bytes::<32>(),
            max: check_max.to_be_bytes::<32>(),
        },
    })
}

pub fn zk_outcome(verdict: &Verdict) -> u8 {
    match verdict {
        Verdict::Reproduced => REPRODUCED,
        Verdict::Failed(_) => FAILED,
    }
}

#[derive(Debug)]
pub struct DifferentialResult {
    pub replay: Result<ReplayOutcome, OperationalError>,
    pub guest: Result<VerdictPublicValues, ()>,
}

pub fn execute_guest(input: &GuestInput) -> Result<VerdictPublicValues, ()> {
    let mut stdin = SP1Stdin::new();
    stdin.write(input);
    let client = ProverClient::from_env();
    let (output, _) = client.execute(REEXEC_ELF, stdin).run().map_err(|_| ())?;
    VerdictPublicValues::abi_decode(output.as_slice()).map_err(|_| ())
}

pub fn differential_run(
    anchor: &EvmAnchorV1,
    witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1,
    predicate: &PredicateV1,
    commitments: &reckn_reexec_evm::ReexecCommitmentsV1,
    input: &GuestInput,
) -> DifferentialResult {
    DifferentialResult {
        replay: replay(anchor, witness, plan, predicate, commitments),
        guest: execute_guest(input),
    }
}

pub fn failed_execution_reason() -> Verdict {
    Verdict::Failed(FailReason::Execution)
}

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

// ---------------------------------------------------------------------------
// SVM deal terms, computable by someone who is not the prover.
//
// L-5 of `docs/specs/009-cross-vm-settlement.md` said this was NOT demonstrated:
// the repository contained exactly one implementation of the SVM binding formula —
// the guest — so "either party can independently compute the deal's terms" was a
// claim, and the demo funded a deal by copying `deal_binding` out of a fixture the
// prover produced. What follows is a SECOND implementation, deliberately not shared
// with the guest: a shared helper would make the value computable off-chain but not
// independently checkable, and it is the disagreement between two transcriptions
// that catches a formula error.
// ---------------------------------------------------------------------------

/// The five deal terms the SVM binding commits. A buyer and a seller both hold all
/// of them before anyone runs a prover: the authenticated prestate's `bank_hash`,
/// which account the predicate reads, the floor and ceiling it must land in, and the
/// signature of the transaction that is the delivered work.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SvmDealTerms {
    pub bank_hash: [u8; 32],
    pub account: [u8; 32],
    pub min: u64,
    pub max: u64,
    pub signature: [u8; 64],
}

/// Compute a deal's SVM binding from its terms, without a prover and without the
/// guest. Transcribed from `zk-verdict/program-svm/src/main.rs`'s preimage:
///
/// ```text
/// sha256( "reckn/zk/bind/svm/v2" ‖ bank_hash ‖ account ‖ min:u256be ‖ max:u256be ‖ signature )
/// ```
///
/// The widths matter and are the reason this is worth a second implementation:
/// `min` and `max` are `u64` in the input struct and enter the preimage as 32-byte
/// big-endian words, so a transcription that hashed them as 8 bytes would produce a
/// plausible-looking binding that no proof can ever match.
pub fn svm_deal_binding(terms: &SvmDealTerms) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(b"reckn/zk/bind/svm/v2");
    h.update(terms.bank_hash);
    h.update(terms.account);
    h.update(U256::from(terms.min).to_be_bytes::<32>());
    h.update(U256::from(terms.max).to_be_bytes::<32>());
    h.update(terms.signature);
    let mut out = [0u8; 32];
    out.copy_from_slice(&h.finalize());
    out
}

/// Rebuild the demo deal's terms **without running the prover** — the construction
/// the `svm` binary uses, exposed so a party who is not the prover can compute the
/// binding from the deal rather than copy it out of a fixture (L-5).
///
/// The signer and recipient are fixed constants for exactly the reason the cycle
/// count is: a random `Keypair::new()` made the demo's transaction, and therefore its
/// binding and its cycle count, different on every run.
pub fn svm_demo_terms(amount: u64, min: u64) -> SvmDealTerms {
    use solana_instruction::{AccountMeta, Instruction};
    use solana_keypair::Keypair;
    use solana_pubkey::Pubkey;
    use solana_signer::Signer;
    use solana_transaction::Transaction;
    use svm_io::SvmAccount;

    const SYSTEM_PROGRAM: Pubkey = Pubkey::new_from_array([0u8; 32]);
    const SIGNER_SECRET: [u8; 32] = [7u8; 32];
    const RECIPIENT: [u8; 32] = [9u8; 32];
    const PRE_FROM: u64 = 1_000_000_000;
    const PRE_TO: u64 = 1;

    let from = Keypair::new_from_array(SIGNER_SECRET);
    let to = Pubkey::new_from_array(RECIPIENT);

    // System::Transfer, encoded exactly as reckn doesit: tag 2 LE + lamports LE.
    let mut data = 2u32.to_le_bytes().to_vec();
    data.extend_from_slice(&amount.to_le_bytes());
    let ix = Instruction {
        program_id: SYSTEM_PROGRAM,
        accounts: vec![AccountMeta::new(from.pubkey(), true), AccountMeta::new(to, false)],
        data,
    };
    let mut tx = Transaction::new_with_payer(&[ix], Some(&from.pubkey()));
    tx.sign(&[&from], Default::default());

    let accounts = vec![
        SvmAccount { pubkey: from.pubkey().to_bytes(), lamports: PRE_FROM, owner: [0u8; 32], executable: false, data: Vec::new() },
        SvmAccount { pubkey: to.to_bytes(), lamports: PRE_TO, owner: [0u8; 32], executable: false, data: Vec::new() },
    ];
    let bank_hash = svm_bankhash::compute_bank_hash(&accounts, &[0x11u8; 32], 1, &[0u8; 32]);

    let mut signature = [0u8; 64];
    signature.copy_from_slice(tx.signatures[0].as_ref());
    SvmDealTerms { bank_hash, account: to.to_bytes(), min, max: u64::MAX, signature }
}

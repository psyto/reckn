//! Host for the full re-execution verdict guest.

use alloy_sol_types::SolType;
use clap::Parser;
use reckn_reexec_evm::testkit::{self, PrestateSpec, SlotSpec, SSTORE_SLOT7_RUNTIME};
use reexec_io::GuestInput;
use revm::primitives::{Bytes, U256};
use serde::{Deserialize, Serialize};
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    include_elf, Elf, HashableKey, ProvingKey, SP1Stdin,
};
use std::{path::PathBuf, str::FromStr};
use verdict_lib::{delta_outcome, reexec_trace_hash, VerdictPublicValues, FAILED, REPRODUCED};
use verdict_script::{to_guest_input, to_predicate};

const REEXEC_ELF: Elf = include_elf!("verdict-program-revm");
const SLOT: u64 = 7;

#[derive(Serialize, Deserialize)]
struct ReexecFixture {
    pre: String,
    post: String,
    min_delta: String,
    max_delta: String,
    outcome: u8,
    trace_hash: String,
    deal_binding: String,
    vkey: String,
    public_values: String,
    proof: String,
}

#[derive(Parser, Debug)]
struct Args {
    #[arg(long)]
    execute: bool,
    #[arg(long)]
    prove: bool,
    #[arg(long)]
    fixture: bool,
    #[arg(long, default_value = "42")]
    pre: String,
    #[arg(long, default_value = "142")]
    post: String,
    #[arg(long, default_value = "100")]
    min: String,
    #[arg(
        long,
        default_value = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    )]
    max: String,
    #[arg(long)]
    fixture_path: Option<PathBuf>,
    #[arg(long)]
    tamper: bool,
}

fn word(value: U256) -> [u8; 32] {
    value.to_be_bytes::<32>()
}
fn parse_word(value: &str) -> U256 {
    if let Some(hex_value) = value.strip_prefix("0x") {
        U256::from_str_radix(hex_value, 16).expect("valid U256 hex")
    } else {
        U256::from_str(value).expect("valid U256 decimal")
    }
}
fn hex_word(value: U256) -> String {
    format!("0x{}", hex::encode(word(value)))
}

fn build_input(
    pre: U256,
    post: U256,
    min: U256,
    max: U256,
    tamper: bool,
) -> (GuestInput, [u8; 32]) {
    let caller = testkit::addr(0xca);
    let target = testkit::addr(0x77);
    let (anchor, witness) = testkit::anchored_witness(PrestateSpec {
        caller,
        target,
        caller_nonce: 0,
        target_code: Bytes::from_static(&SSTORE_SLOT7_RUNTIME),
        coinbase: testkit::addr(0xc0),
        slot7: SlotSpec::Value(pre),
        extra_accounts: vec![],
        extra_slots: vec![],
        empty_account_proof_for: None,
    });
    let predicate = to_predicate(target, U256::from(SLOT), min, max);
    let plan = reckn_reexec_evm::EvmCallPlanV1 {
        caller,
        target,
        calldata: Bytes::copy_from_slice(&word(post)),
        value: U256::ZERO,
        gas_limit: 100_000,
    };
    let mut input =
        to_guest_input(&anchor, &witness, &plan, &predicate).expect("in-domain fixture");
    if tamper {
        for account in &mut input.accounts {
            if account.address == target.0 .0 {
                for storage in &mut account.storage {
                    if storage.slot == word(U256::from(SLOT)) {
                        storage.value = word(pre + U256::ONE);
                    }
                }
            }
        }
    }
    (input, anchor.state_root.0)
}

fn outcome_name(outcome: u8) -> &'static str {
    match outcome {
        REPRODUCED => "Reproduced",
        FAILED => "Failed",
        _ => "?",
    }
}

fn main() {
    sp1_sdk::utils::setup_logger();
    dotenv::dotenv().ok();
    let args = Args::parse();
    if [args.execute, args.prove, args.fixture]
        .iter()
        .filter(|active| **active)
        .count()
        != 1
    {
        eprintln!("Error: specify exactly one of --execute / --prove / --fixture");
        std::process::exit(1);
    }
    let pre = parse_word(&args.pre);
    let post = parse_word(&args.post);
    let min = parse_word(&args.min);
    let max = parse_word(&args.max);
    let (input, state_root) = build_input(pre, post, min, max, args.tamper);
    let mut stdin = SP1Stdin::new();
    stdin.write(&input);
    let client = ProverClient::from_env();
    if args.execute {
        let (output, report) = client
            .execute(REEXEC_ELF, stdin)
            .run()
            .expect("execute guest");
        let values =
            VerdictPublicValues::abi_decode(output.as_slice()).expect("decode public values");
        let expected = delta_outcome(pre, post, min, max);
        let trace = reexec_trace_hash(state_root, pre, post, min, max, expected);
        assert_eq!(values.pre, pre);
        assert_eq!(values.post, post);
        assert_eq!(values.outcome, expected);
        assert_eq!(values.traceHash.0, trace);
        println!(
            "verdict: {} ({})",
            values.outcome,
            outcome_name(values.outcome)
        );
        println!("cycles: {}", report.total_instruction_count());
    } else if args.prove {
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        let proof = client.prove(&pk, stdin).run().expect("generate proof");
        client
            .verify(&proof, pk.verifying_key(), None)
            .expect("verify proof");
    } else {
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        let proof = client
            .prove(&pk, stdin)
            .groth16()
            .run()
            .expect("generate groth16 proof");
        let values = VerdictPublicValues::abi_decode(proof.public_values.as_slice())
            .expect("decode public values");
        let fixture = ReexecFixture {
            pre: hex_word(values.pre),
            post: hex_word(values.post),
            min_delta: hex_word(values.minDelta),
            max_delta: hex_word(values.maxDelta),
            outcome: values.outcome,
            trace_hash: format!("0x{}", hex::encode(values.traceHash.0)),
            deal_binding: format!("0x{}", hex::encode(values.dealBinding.0)),
            vkey: pk.verifying_key().bytes32(),
            public_values: format!("0x{}", hex::encode(proof.public_values.as_slice())),
            proof: format!("0x{}", hex::encode(proof.bytes())),
        };
        let path = args.fixture_path.unwrap_or_else(|| {
            PathBuf::from("../contracts/src/fixtures/reexec-groth16-fixture.json")
        });
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).expect("create fixture directory");
        }
        std::fs::write(
            &path,
            serde_json::to_string_pretty(&fixture).expect("encode fixture"),
        )
        .expect("write fixture");
        println!("wrote fixture to {}", path.display());
    }
}

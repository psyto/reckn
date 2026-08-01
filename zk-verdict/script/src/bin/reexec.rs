//! Host for the **full re-execution** ZK verdict. Builds a committed prestate +
//! CALL plan (the reckn SSTORE crediting fixture), feeds it to the revm-in-guest,
//! which executes the CALL under proof and derives the post-state, then applies
//! the causal delta predicate. Unlike the predicate guest, `post` is NOT an input
//! here — the EVM computes it inside the proof.
//!
//! ```shell
//! RUST_LOG=info cargo run --release --bin reexec -- --execute   # run, print verdict + EVM cycles
//! RUST_LOG=info cargo run --release --bin reexec -- --prove     # generate AND verify a core proof
//! # default: pre=42, credit=142 (SSTORE writes 142 to slot 7) -> delta 100 >= min 100 -> Reproduced
//! # --credit 42 -> post 42, delta 0 < 100 -> Failed;  a no-op cannot fake the credit
//! ```

use alloy_sol_types::SolType;
use clap::Parser;
use reexec_io::{DeltaCheck, GuestAccount, GuestInput, GuestPlan};
use serde::{Deserialize, Serialize};
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    include_elf, Elf, HashableKey, ProvingKey, SP1Stdin,
};
use std::path::PathBuf;
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues, FAILED, REPRODUCED};

/// On-chain fixture for a full-re-execution proof — same shape as the predicate
/// fixture, so the same `RecknVerdictVerifier` (only the vkey differs) verifies it.
#[derive(Serialize, Deserialize)]
struct ReexecFixture {
    pre: u64,
    post: u64,
    min_delta: u64,
    max_delta: u64,
    outcome: u8,
    trace_hash: String,
    vkey: String,
    public_values: String,
    proof: String,
}

const REEXEC_ELF: Elf = include_elf!("verdict-program-revm");

/// The reckn SSTORE fixture: PUSH0, CALLDATALOAD, PUSH1 07, SSTORE, STOP —
/// writes the calldata word into storage slot 7 (a real *caused* delta).
const SSTORE_SLOT7_RUNTIME: [u8; 6] = [0x5f, 0x35, 0x60, 0x07, 0x55, 0x00];
const TARGET: [u8; 20] = [0x77; 20];
const CALLER: [u8; 20] = [0xca; 20];
const SLOT: u64 = 7;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long)]
    execute: bool,
    #[arg(long)]
    prove: bool,
    /// Generate a real Groth16 proof of the re-execution and write an on-chain fixture.
    #[arg(long)]
    fixture: bool,
    /// Committed prestate value of slot 7 (the delta `pre` baseline).
    #[arg(long, default_value = "42")]
    pre: u64,
    /// Value the CALL writes to slot 7 (post = this, so delta = credit - pre).
    #[arg(long, default_value = "142")]
    credit: u64,
    /// Causal floor: the credited increase must be >= this.
    #[arg(long, default_value = "100")]
    min: u64,
}

fn be32(v: u64) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[24..].copy_from_slice(&v.to_be_bytes());
    out
}

fn build_input(pre: u64, credit: u64, min: u64) -> GuestInput {
    let target = GuestAccount {
        address: TARGET,
        balance: [0u8; 32],
        nonce: 0,
        code: SSTORE_SLOT7_RUNTIME.to_vec(),
        storage: vec![(be32(SLOT), be32(pre))],
    };
    let caller = GuestAccount {
        address: CALLER,
        balance: be32(1_000_000),
        nonce: 0,
        code: Vec::new(),
        storage: Vec::new(),
    };
    GuestInput {
        chain_id: 1,
        accounts: vec![target, caller],
        plan: GuestPlan {
            caller: CALLER,
            target: TARGET,
            calldata: be32(credit).to_vec(),
            value: [0u8; 32],
            gas_limit: 100_000,
        },
        check: DeltaCheck {
            address: TARGET,
            slot: be32(SLOT),
            min,
            max: u64::MAX,
        },
    }
}

fn outcome_name(o: u8) -> &'static str {
    if o == REPRODUCED {
        "Reproduced"
    } else if o == FAILED {
        "Failed"
    } else {
        "?"
    }
}

fn main() {
    sp1_sdk::utils::setup_logger();
    dotenv::dotenv().ok();

    let args = Args::parse();
    if [args.execute, args.prove, args.fixture].iter().filter(|b| **b).count() != 1 {
        eprintln!("Error: specify exactly one of --execute / --prove / --fixture");
        std::process::exit(1);
    }

    let input = build_input(args.pre, args.credit, args.min);
    let mut stdin = SP1Stdin::new();
    stdin.write(&input);

    println!(
        "committed prestate: slot7 = {}   plan: SSTORE(slot7, {})   floor: delta >= {}",
        args.pre, args.credit, args.min
    );
    println!("(post is NOT given — the guest executes revm to derive it)");

    let client = ProverClient::from_env();

    if args.execute {
        let (output, report) = client.execute(REEXEC_ELF, stdin).run().unwrap();
        let v = VerdictPublicValues::abi_decode(output.as_slice()).unwrap();
        println!("guest re-executed the CALL under the zkVM:");
        println!("  pre (committed): {}", v.pre);
        println!("  post (EXECUTED): {}", v.post);
        println!("  credited delta : {}", v.post.saturating_sub(v.pre));
        println!("  verdict        : {} ({})", v.outcome, outcome_name(v.outcome));
        println!("  traceHash      : 0x{}", hex::encode(v.traceHash.0));

        // The in-guest execution must agree with the off-chain delta computation.
        let expected = delta_outcome(args.pre, args.credit, args.min, u64::MAX);
        let trace = verdict_trace_hash(args.pre, args.credit, args.min, u64::MAX, expected);
        assert_eq!(v.post, args.credit, "revm wrote the credited value to slot 7");
        assert_eq!(v.outcome, expected, "guest verdict matches the host delta");
        assert_eq!(v.traceHash.0, trace, "guest traceHash matches the host");
        println!("guest execution matches the host computation");
        println!("EVM re-execution cycles: {}", report.total_instruction_count());
    } else if args.prove {
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        let proof = client.prove(&pk, stdin).run().expect("generate proof");
        println!("Successfully generated proof of the re-execution!");
        client
            .verify(&proof, pk.verifying_key(), None)
            .expect("verify proof");
        println!("Verified: the verdict is ZK-proven from EXECUTION — post-state was computed under proof, not trusted.");
    } else {
        // Groth16 fixture: a real, on-chain-verifiable proof of the re-execution.
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        println!("generating Groth16 proof of the re-execution (uses local v6.1.0 artifacts)...");
        let proof = client
            .prove(&pk, stdin)
            .groth16()
            .run()
            .expect("generate groth16 proof");
        let v = VerdictPublicValues::abi_decode(proof.public_values.as_slice())
            .expect("decode public values");
        assert_eq!(v.post, args.credit, "revm wrote the credited value to slot 7");

        let vk = pk.verifying_key();
        let fixture = ReexecFixture {
            pre: v.pre,
            post: v.post,
            min_delta: v.minDelta,
            max_delta: v.maxDelta,
            outcome: v.outcome,
            trace_hash: format!("0x{}", hex::encode(v.traceHash.0)),
            vkey: vk.bytes32(),
            public_values: format!("0x{}", hex::encode(proof.public_values.as_slice())),
            proof: format!("0x{}", hex::encode(proof.bytes())),
        };
        let dir = PathBuf::from("../contracts/src/fixtures");
        std::fs::create_dir_all(&dir).expect("create fixtures dir");
        let path = dir.join("reexec-groth16-fixture.json");
        std::fs::write(&path, serde_json::to_string_pretty(&fixture).unwrap())
            .expect("write fixture");
        println!("vkey: {}", fixture.vkey);
        println!(
            "outcome: {} pre: {} post(EXECUTED): {} traceHash: {}",
            fixture.outcome, fixture.pre, fixture.post, fixture.trace_hash
        );
        println!("wrote fixture to {}", path.display());
    }
}

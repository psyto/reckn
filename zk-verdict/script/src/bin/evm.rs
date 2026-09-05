//! Generate a **Groth16** proof of the reckn verdict and emit an on-chain fixture
//! (vkey + public values + proof bytes) that `RecknVerdictVerifier` can verify
//! against SP1's real on-chain Groth16 verifier.
//!
//! ```shell
//! RUST_LOG=info cargo run --release --bin evm -- --pre 42 --post 142 --min 100
//! ```
//!
//! This is the heavy path: Groth16 wrapping needs the SP1 Groth16 circuit
//! artifacts (downloaded on first run) and is CPU-intensive on a machine without
//! a GPU. The `--execute`/`--prove` (`main.rs`) core proof and the mock-verifier
//! Foundry wiring test do not require it; this produces the *real* on-chain
//! fixture when the environment can run it.

use alloy_sol_types::private::U256;
use alloy_sol_types::SolType;
use clap::Parser;
use serde::{Deserialize, Serialize};
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    include_elf, Elf, HashableKey, ProvingKey, SP1Stdin,
};
use std::path::PathBuf;
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues};

const VERDICT_ELF: Elf = include_elf!("verdict-program");

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long, default_value = "42")]
    pre: u64,
    #[arg(long, default_value = "142")]
    post: u64,
    #[arg(long, default_value = "100")]
    min: u64,
    #[arg(long, default_value = "18446744073709551615")]
    max: u64,
    /// AC-9: execute the current ELF on these inputs and print the vkey and the
    /// committed public values, so `fixtures-check.sh` can compare them against the
    /// committed fixture. No proof is generated.
    #[arg(long)]
    verify: bool,
    /// Print the current ELF's vkey and exit. Cheap: no execution, no proof. This is
    /// what `ac008.sh` uses to recompute AC-09's witness WITHOUT invoking the row's
    /// own command, which §6.2 forbids.
    #[arg(long)]
    vkey: bool,
}

/// The on-chain fixture — everything `RecknVerdictVerifier.verifyVerdict` needs,
/// plus the decoded verdict for the test to assert against.
#[derive(Serialize, Deserialize)]
struct VerdictFixture {
    pre: String,
    post: String,
    min_delta: String,
    max_delta: String,
    outcome: u8,
    trace_hash: String,
    vkey: String,
    public_values: String,
    proof: String,
}

fn main() {
    sp1_sdk::utils::setup_logger();
    dotenv::dotenv().ok();

    let args = Args::parse();
    let client = ProverClient::from_env();

    let mut stdin = SP1Stdin::new();
    stdin.write(&args.pre);
    stdin.write(&args.post);
    stdin.write(&args.min);
    stdin.write(&args.max);

    let pk = client.setup(VERDICT_ELF).expect("setup elf");
    if args.vkey {
        println!("vkey: {}", pk.verifying_key().bytes32());
        return;
    }
    if args.verify {
        let (output, _) = client
            .execute(VERDICT_ELF, stdin)
            .run()
            .expect("execute guest");
        println!("vkey: {}", pk.verifying_key().bytes32());
        println!("public_values: 0x{}", hex::encode(output.as_slice()));
        return;
    }
    println!("generating Groth16 proof (this downloads circuit artifacts on first run)...");
    let proof = client
        .prove(&pk, stdin)
        .groth16()
        .run()
        .expect("generate groth16 proof");

    // Sanity: the committed public values decode and match the host computation.
    let v = VerdictPublicValues::abi_decode(proof.public_values.as_slice())
        .expect("decode public values");
    let outcome = delta_outcome(
        U256::from(args.pre),
        U256::from(args.post),
        U256::from(args.min),
        U256::from(args.max),
    );
    let trace = verdict_trace_hash(
        U256::from(args.pre),
        U256::from(args.post),
        U256::from(args.min),
        U256::from(args.max),
        outcome,
    );
    assert_eq!(v.outcome, outcome, "guest outcome matches host");
    assert_eq!(v.traceHash.0, trace, "guest traceHash matches host");

    let vk = pk.verifying_key();
    let fixture = VerdictFixture {
        pre: format!(
            "0x{}",
            hex::encode(U256::from(args.pre).to_be_bytes::<32>())
        ),
        post: format!(
            "0x{}",
            hex::encode(U256::from(args.post).to_be_bytes::<32>())
        ),
        min_delta: format!(
            "0x{}",
            hex::encode(U256::from(args.min).to_be_bytes::<32>())
        ),
        max_delta: format!(
            "0x{}",
            hex::encode(U256::from(args.max).to_be_bytes::<32>())
        ),
        outcome: v.outcome,
        trace_hash: format!("0x{}", hex::encode(v.traceHash.0)),
        vkey: vk.bytes32(),
        public_values: format!("0x{}", hex::encode(proof.public_values.as_slice())),
        proof: format!("0x{}", hex::encode(proof.bytes())),
    };

    let dir = PathBuf::from("../contracts/src/fixtures");
    std::fs::create_dir_all(&dir).expect("create fixtures dir");
    let path = dir.join("groth16-fixture.json");
    std::fs::write(&path, serde_json::to_string_pretty(&fixture).unwrap()).expect("write fixture");

    println!("vkey: {}", fixture.vkey);
    println!(
        "outcome: {} traceHash: {}",
        fixture.outcome, fixture.trace_hash
    );
    println!("wrote fixture to {}", path.display());
}

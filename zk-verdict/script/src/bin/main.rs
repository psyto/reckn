//! Host driver for the reckn ZK-verdict PoC. Feeds the committed inputs
//! `(pre, post, min, max)` to the zkVM guest, which computes reckn's causal delta
//! verdict + trace hash under proof, then generates and **verifies** the proof.
//!
//! ```shell
//! RUST_LOG=info cargo run --release -- --execute            # run the guest, print the verdict + cycles
//! RUST_LOG=info cargo run --release -- --prove              # generate AND verify a ZK proof
//! # inputs default to pre=42 post=142 min=100 (a credited 100 clearing a floor of 100)
//! ```

use alloy_sol_types::SolType;
use clap::Parser;
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    include_elf, Elf, ProvingKey, SP1Stdin,
};
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues, FAILED, REPRODUCED};

/// The ELF for the Succinct RISC-V zkVM guest.
const VERDICT_ELF: Elf = include_elf!("verdict-program");

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long)]
    execute: bool,
    #[arg(long)]
    prove: bool,
    #[arg(long, default_value = "42")]
    pre: u64,
    #[arg(long, default_value = "142")]
    post: u64,
    #[arg(long, default_value = "100")]
    min: u64,
    #[arg(long, default_value = "18446744073709551615")]
    max: u64,
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
    if args.execute == args.prove {
        eprintln!("Error: specify either --execute or --prove");
        std::process::exit(1);
    }

    let client = ProverClient::from_env();

    let mut stdin = SP1Stdin::new();
    stdin.write(&args.pre);
    stdin.write(&args.post);
    stdin.write(&args.min);
    stdin.write(&args.max);

    println!(
        "inputs: pre={} post={} min={} max={} (credited {} vs floor {})",
        args.pre,
        args.post,
        args.min,
        args.max,
        args.post.saturating_sub(args.pre),
        args.min
    );

    if args.execute {
        let (output, report) = client.execute(VERDICT_ELF, stdin).run().unwrap();
        let v = VerdictPublicValues::abi_decode(output.as_slice()).unwrap();
        println!("guest verdict: {} ({})", v.outcome, outcome_name(v.outcome));
        println!("guest traceHash: 0x{}", hex::encode(v.traceHash.0));

        // Cross-check the guest against the same host-side computation.
        let outcome = delta_outcome(args.pre, args.post, args.min, args.max);
        let trace = verdict_trace_hash(args.pre, args.post, args.min, args.max, outcome);
        assert_eq!(v.outcome, outcome, "guest outcome matches host");
        assert_eq!(v.traceHash.0, trace, "guest traceHash matches host");
        println!("guest matches the host computation");
        println!("cycles: {}", report.total_instruction_count());
    } else {
        let pk = client.setup(VERDICT_ELF).expect("setup elf");
        let proof = client.prove(&pk, stdin).run().expect("generate proof");
        println!("Successfully generated proof!");
        client
            .verify(&proof, pk.verifying_key(), None)
            .expect("verify proof");
        println!("Successfully verified proof! The verdict is ZK-proven — no trusted resolver.");
    }
}

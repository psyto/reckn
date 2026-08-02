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
use reexec_io::{DeltaCheck, GuestAccount, GuestInput, GuestPlan, GuestStorage};
use serde::{Deserialize, Serialize};
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    include_elf, Elf, HashableKey, ProvingKey, SP1Stdin,
};
use std::path::PathBuf;
use verdict_lib::{delta_outcome, reexec_trace_hash, VerdictPublicValues, FAILED, REPRODUCED};

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
    deal_binding: String,
    vkey: String,
    public_values: String,
    proof: String,
}

const REEXEC_ELF: Elf = include_elf!("verdict-program-revm");

/// The reckn SSTORE fixture pins slot 7 = 42 in the committed (MPT-proven) prestate.
const SLOT: u64 = 7;
const PRE: u64 = 42;

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
    /// Value the CALL writes to slot 7 (post = this, so delta = credit - 42).
    #[arg(long, default_value = "142")]
    credit: u64,
    /// Causal floor: the credited increase must be >= this.
    #[arg(long, default_value = "100")]
    min: u64,
    /// Corrupt the committed slot value so it no longer matches the MPT proof —
    /// the guest must reject it (authenticity check fails; no verdict can be made).
    #[arg(long)]
    tamper: bool,
}

fn be32(v: u64) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[24..].copy_from_slice(&v.to_be_bytes());
    out
}

/// Build the guest input from the REAL backend witness: `reexec-evm`'s testkit
/// constructs the state/storage tries and retains Merkle proofs, so the guest
/// verifies exactly the proof format the off-chain backend produces. The prestate
/// (slot 7 = 42) is thus MPT-bound to `anchor.state_root`.
fn build_input(credit: u64, min: u64, tamper: bool) -> (GuestInput, [u8; 32]) {
    use reckn_reexec_evm::testkit;
    let caller_addr = testkit::addr(0xca);
    let target_addr = testkit::addr(0x77);
    let (anchor, witness) = testkit::anchored_sstore_witness(caller_addr, target_addr);

    let state_root: [u8; 32] = anchor.state_root.0;

    let mut accounts: Vec<GuestAccount> = witness
        .accounts
        .iter()
        .map(|a| GuestAccount {
            address: a.address.0 .0,
            balance: a.balance.to_be_bytes::<32>(),
            nonce: a.nonce,
            code: a.code.to_vec(),
            storage_root: a.storage_root.0,
            code_hash: a.code_hash.0,
            account_proof: a.account_proof.iter().map(|b| b.to_vec()).collect(),
            storage: a
                .storage
                .iter()
                .map(|s| GuestStorage {
                    slot: s.slot.to_be_bytes::<32>(),
                    value: s.value.to_be_bytes::<32>(),
                    proof: s.proof.iter().map(|b| b.to_vec()).collect(),
                })
                .collect(),
        })
        .collect();

    if tamper {
        // Flip the committed slot-7 value away from what the proof attests.
        for a in &mut accounts {
            if a.address == target_addr.0 .0 {
                for s in &mut a.storage {
                    if s.slot == be32(SLOT) {
                        s.value = be32(PRE + 1);
                    }
                }
            }
        }
    }

    let input = GuestInput {
        chain_id: anchor.chain_id,
        state_root,
        accounts,
        plan: GuestPlan {
            caller: caller_addr.0 .0,
            target: target_addr.0 .0,
            calldata: be32(credit).to_vec(),
            value: [0u8; 32],
            gas_limit: 100_000,
        },
        check: DeltaCheck {
            address: target_addr.0 .0,
            slot: be32(SLOT),
            min,
            max: u64::MAX,
        },
    };
    (input, state_root)
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

    let (input, state_root) = build_input(args.credit, args.min, args.tamper);
    let mut stdin = SP1Stdin::new();
    stdin.write(&input);

    println!(
        "committed prestate: slot7 = {} (MPT-proven against state_root 0x{})",
        PRE,
        hex::encode(state_root)
    );
    println!(
        "plan: SSTORE(slot7, {})   floor: delta >= {}{}",
        args.credit,
        args.min,
        if args.tamper { "   [TAMPERED prestate — must be rejected]" } else { "" }
    );
    println!("(prestate authenticity AND post are established in-guest, not trusted)");

    let client = ProverClient::from_env();

    if args.execute {
        let (output, report) = client.execute(REEXEC_ELF, stdin).run().unwrap();
        let v = VerdictPublicValues::abi_decode(output.as_slice()).unwrap();
        println!("guest verified the prestate and re-executed the CALL under the zkVM:");
        println!("  pre (committed): {}", v.pre);
        println!("  post (EXECUTED): {}", v.post);
        println!("  credited delta : {}", v.post.saturating_sub(v.pre));
        println!("  verdict        : {} ({})", v.outcome, outcome_name(v.outcome));
        println!("  traceHash      : 0x{}", hex::encode(v.traceHash.0));

        // The in-guest execution must agree with the off-chain delta computation,
        // and the trace hash binds the authenticated state_root.
        let expected = delta_outcome(PRE, args.credit, args.min, u64::MAX);
        let trace = reexec_trace_hash(state_root, PRE, args.credit, args.min, u64::MAX, expected);
        assert_eq!(v.post, args.credit, "revm wrote the credited value to slot 7");
        assert_eq!(v.outcome, expected, "guest verdict matches the host delta");
        assert_eq!(v.traceHash.0, trace, "guest traceHash matches the host (binds state_root)");
        println!("guest execution matches the host computation");
        println!("EVM re-execution + MPT-verification cycles: {}", report.total_instruction_count());
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
            deal_binding: format!("0x{}", hex::encode(v.dealBinding.0)),
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

//! Host for the **SVM re-execution** ZK verdict (Solana mirror of `reexec`). Builds
//! a signed System-transfer transaction + committed prestate accounts, feeds them to
//! the SVM guest, which signature-verifies the transaction and re-executes the
//! transfer to derive post-lamports, then applies the causal `LamportsDelta`.
//!
//! ```shell
//! RUST_LOG=info cargo run --release --bin svm -- --execute   # verify + re-execute; print verdict + cycles
//! RUST_LOG=info cargo run --release --bin svm -- --prove     # generate AND verify a core proof
//! RUST_LOG=info cargo run --release --bin svm -- --fixture   # real Groth16 proof -> on-chain fixture
//! # default: recipient pre=1, transfer 2_000_000, floor 1_000_000 -> delta 2_000_000 -> Reproduced
//! # --amount 500000 -> delta 500_000 < floor -> Failed;  --tamper -> bad signature -> verify fails -> Failed
//! ```

use alloy_sol_types::private::U256;
use alloy_sol_types::SolType;
use clap::Parser;
use serde::{Deserialize, Serialize};
use solana_instruction::{AccountMeta, Instruction};
use solana_keypair::Keypair;
use solana_pubkey::Pubkey;
use solana_signer::Signer;
use solana_transaction::Transaction;
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    include_elf, Elf, HashableKey, ProvingKey, SP1Stdin,
};
use std::path::PathBuf;
use svm_io::{SvmAccount, SvmCheck, SvmPrestate};
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues, FAILED, REPRODUCED};

const REEXEC_ELF: Elf = include_elf!("verdict-program-svm");
const SYSTEM_PROGRAM: Pubkey = Pubkey::new_from_array([0u8; 32]);
const PRE_FROM: u64 = 1_000_000_000;
const PRE_TO: u64 = 1;

#[derive(Serialize, Deserialize)]
struct SvmFixture {
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
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long)]
    execute: bool,
    #[arg(long)]
    prove: bool,
    #[arg(long)]
    fixture: bool,
    /// Lamports the transfer credits the recipient (post = pre + amount).
    #[arg(long, default_value = "2000000")]
    amount: u64,
    /// Causal floor: the credited increase must be >= this.
    #[arg(long, default_value = "1000000")]
    min: u64,
    /// Corrupt the signature so the in-guest sigverify fails — no Reproduced.
    #[arg(long)]
    tamper: bool,
    /// Corrupt a committed account after bank_hash is computed, so the prestate no
    /// longer reproduces bank_hash — the guest must reject it (authenticity).
    #[arg(long)]
    tamper_prestate: bool,
}

/// The System transfer instruction, encoded exactly as reckn does (tag 2 LE +
/// lamports LE), with `from` signer/writable and `to` writable.
fn system_transfer(from: &Pubkey, to: &Pubkey, lamports: u64) -> Instruction {
    let mut data = 2u32.to_le_bytes().to_vec();
    data.extend_from_slice(&lamports.to_le_bytes());
    Instruction {
        program_id: SYSTEM_PROGRAM,
        accounts: vec![AccountMeta::new(*from, true), AccountMeta::new(*to, false)],
        data,
    }
}

fn build(amount: u64, min: u64, tamper: bool, tamper_prestate: bool) -> (Transaction, SvmPrestate) {
    let from = Keypair::new();
    let to = Pubkey::new_unique();
    let ix = system_transfer(&from.pubkey(), &to, amount);
    let mut tx = Transaction::new_with_payer(&[ix], Some(&from.pubkey()));
    tx.sign(&[&from], Default::default());
    if tamper {
        // Replace the signature with an all-zero (invalid) one; the guest's
        // Transaction::verify must reject it — no Reproduced without a real signer.
        tx.signatures[0] = Default::default();
    }
    let mut accounts = vec![
        SvmAccount {
            pubkey: from.pubkey().to_bytes(),
            lamports: PRE_FROM,
            owner: [0u8; 32],
            executable: false,
            data: Vec::new(),
        },
        SvmAccount {
            pubkey: to.to_bytes(),
            lamports: PRE_TO,
            owner: [0u8; 32],
            executable: false,
            data: Vec::new(),
        },
    ];

    // Treat this committed set as the complete account world and derive its real
    // post-SIMD-0215 bank_hash (the same computation reexec-svm::bankhash does).
    let parent_bank_hash = [0x11u8; 32];
    let signature_count = 1u64;
    let last_blockhash = [0u8; 32]; // matches the default blockhash used to sign
    let bank_hash = svm_bankhash::compute_bank_hash(
        &accounts,
        &parent_bank_hash,
        signature_count,
        &last_blockhash,
    );

    if tamper_prestate {
        // Perturb the recipient's committed lamports AFTER bank_hash is fixed, so
        // the account set no longer reproduces it — the guest must reject.
        accounts[1].lamports = PRE_TO + 1;
    }

    let prestate = SvmPrestate {
        accounts,
        check: SvmCheck {
            account: to.to_bytes(),
            min,
            max: u64::MAX,
        },
        parent_bank_hash,
        signature_count,
        last_blockhash,
        bank_hash,
    };
    (tx, prestate)
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
    if [args.execute, args.prove, args.fixture]
        .iter()
        .filter(|b| **b)
        .count()
        != 1
    {
        eprintln!("Error: specify exactly one of --execute / --prove / --fixture");
        std::process::exit(1);
    }

    let (tx, prestate) = build(args.amount, args.min, args.tamper, args.tamper_prestate);
    let mut stdin = SP1Stdin::new();
    stdin.write(&tx);
    stdin.write(&prestate);

    println!(
        "committed prestate: recipient = {} lamports (bank_hash-bound 0x{})",
        PRE_TO,
        hex::encode(prestate.bank_hash)
    );
    let flag = if args.tamper {
        "   [TAMPERED signature]"
    } else if args.tamper_prestate {
        "   [TAMPERED prestate — must be rejected]"
    } else {
        ""
    };
    println!(
        "tx: System::Transfer({})   floor: delta >= {}{}",
        args.amount, args.min, flag
    );
    println!(
        "(the guest recomputes bank_hash, SIGNATURE-VERIFIES the tx, and re-executes the transfer)"
    );

    let client = ProverClient::from_env();

    if args.execute {
        let (output, report) = client.execute(REEXEC_ELF, stdin).run().unwrap();
        let v = VerdictPublicValues::abi_decode(output.as_slice()).unwrap();
        println!("guest verified signatures and re-executed the transfer:");
        println!("  pre (committed): {}", v.pre);
        println!("  post (EXECUTED): {}", v.post);
        println!("  credited delta : {}", v.post.saturating_sub(v.pre));
        println!(
            "  verdict        : {} ({})",
            v.outcome,
            outcome_name(v.outcome)
        );
        println!("  traceHash      : 0x{}", hex::encode(v.traceHash.0));

        // Host cross-check: an authentic transfer credits exactly `amount`; a
        // tampered signature must fail verification (Failed, delta 0).
        if args.tamper {
            assert_eq!(
                v.outcome, FAILED,
                "tampered signature must fail verify -> Failed"
            );
            assert_eq!(v.post, v.pre, "no transfer applied on a bad signature");
        } else {
            let expected_post = PRE_TO + args.amount;
            let expected = delta_outcome(
                U256::from(PRE_TO),
                U256::from(expected_post),
                U256::from(args.min),
                U256::from(u64::MAX),
            );
            assert_eq!(
                v.post,
                U256::from(expected_post),
                "recipient credited the transfer amount"
            );
            assert_eq!(v.outcome, expected, "guest verdict matches the host delta");
        }
        let trace = verdict_trace_hash(
            v.pre,
            v.post,
            U256::from(args.min),
            U256::from(u64::MAX),
            v.outcome,
        );
        assert_eq!(v.traceHash.0, trace, "guest traceHash matches the host");
        println!("guest execution matches the host computation");
        println!(
            "SVM sigverify + re-execution cycles: {}",
            report.total_instruction_count()
        );
    } else if args.prove {
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        let proof = client.prove(&pk, stdin).run().expect("generate proof");
        println!("Successfully generated proof of the SVM re-execution!");
        client
            .verify(&proof, pk.verifying_key(), None)
            .expect("verify proof");
        println!("Verified: the SVM verdict is ZK-proven from a signature-verified re-execution — post computed under proof.");
    } else {
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        println!(
            "generating Groth16 proof of the SVM re-execution (uses local v6.1.0 artifacts)..."
        );
        let proof = client
            .prove(&pk, stdin)
            .groth16()
            .run()
            .expect("generate groth16 proof");
        let v = VerdictPublicValues::abi_decode(proof.public_values.as_slice())
            .expect("decode public values");
        let vk = pk.verifying_key();
        let fixture = SvmFixture {
            pre: format!("0x{}", hex::encode(v.pre.to_be_bytes::<32>())),
            post: format!("0x{}", hex::encode(v.post.to_be_bytes::<32>())),
            min_delta: format!("0x{}", hex::encode(v.minDelta.to_be_bytes::<32>())),
            max_delta: format!("0x{}", hex::encode(v.maxDelta.to_be_bytes::<32>())),
            outcome: v.outcome,
            trace_hash: format!("0x{}", hex::encode(v.traceHash.0)),
            deal_binding: format!("0x{}", hex::encode(v.dealBinding.0)),
            vkey: vk.bytes32(),
            public_values: format!("0x{}", hex::encode(proof.public_values.as_slice())),
            proof: format!("0x{}", hex::encode(proof.bytes())),
        };
        let dir = PathBuf::from("../contracts/src/fixtures");
        std::fs::create_dir_all(&dir).expect("create fixtures dir");
        let path = dir.join("svm-groth16-fixture.json");
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

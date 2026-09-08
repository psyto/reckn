//! Measurement harness (NOT product code, NOT committed): how many SP1 cycles does the
//! existing re-execution guest need for a REAL mainnet Uniswap v3 swap?
//!
//! All RPC work happens in the shell script that writes the input JSON; this only assembles
//! the witness into a GuestInput and executes. The guest and `reexec-evm` are used unchanged
//! -- if this needed a change to either, that would itself be the finding.
use alloy_sol_types::SolType;
use reckn_reexec_evm::{AccountWitness, EvmAnchorV1, EvmCallPlanV1, PrestateWitnessV1, StorageWitnessV1};
use revm::primitives::hardfork::SpecId;
use revm::primitives::{keccak256, Address, Bytes, B256, U256};
use serde_json::Value;
use sp1_sdk::{blocking::{ProveRequest, Prover, ProverClient}, include_elf, Elf, SP1Stdin};
use std::str::FromStr;
use verdict_lib::VerdictPublicValues;
use verdict_script::{to_guest_input, to_predicate};

const REEXEC_ELF: Elf = include_elf!("verdict-program-revm");

fn u64h(v: &Value) -> u64 { u64::from_str_radix(v.as_str().unwrap().trim_start_matches("0x"), 16).unwrap() }
fn u256h(v: &Value) -> U256 { U256::from_str(v.as_str().unwrap()).unwrap() }
fn b256(v: &Value) -> B256 { B256::from_str(v.as_str().unwrap()).unwrap() }
fn addr(v: &Value) -> Address { Address::from_str(v.as_str().unwrap()).unwrap() }
fn bytes(v: &Value) -> Bytes { Bytes::from_str(v.as_str().unwrap()).unwrap() }
fn nodes(v: &Value) -> Vec<Bytes> { v.as_array().unwrap().iter().map(bytes).collect() }

fn main() {
    let path = std::env::args().nth(1).expect("usage: uniswap_probe <input.json>");
    let min = std::env::args().nth(2).map(|s| U256::from_str(&s).unwrap()).unwrap_or(U256::ZERO);
    let j: Value = serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();

    let a = &j["anchor"];
    let anchor = EvmAnchorV1 {
        chain_id: a["chain_id"].as_u64().unwrap(),
        block_number: u64h(&a["block_number"]),
        block_hash: b256(&a["block_hash"]),
        state_root: b256(&a["state_root"]),
        timestamp: u64h(&a["timestamp"]),
        base_fee: u64h(&a["base_fee"]),
        block_gas_limit: u64h(&a["block_gas_limit"]),
        coinbase: addr(&a["coinbase"]),
        prevrandao: b256(&a["prevrandao"]),
        spec_id: SpecId::PRAGUE,
        block_header: None,
    };

    let mut accounts = Vec::new();
    let mut slots = 0usize;
    let mut nodes_total = 0usize;
    for acc in j["accounts"].as_array().unwrap() {
        let storage: Vec<StorageWitnessV1> = acc["storageProof"].as_array().unwrap().iter().map(|s| {
            nodes_total += s["proof"].as_array().unwrap().len();
            slots += 1;
            StorageWitnessV1 { slot: u256h(&s["key"]), value: u256h(&s["value"]), proof: nodes(&s["proof"]) }
        }).collect();
        nodes_total += acc["accountProof"].as_array().unwrap().len();
        let code = bytes(&acc["code"]);
        accounts.push(AccountWitness {
            address: addr(&acc["address"]),
            balance: u256h(&acc["balance"]),
            nonce: u64h(&acc["nonce"]),
            storage_root: b256(&acc["storageHash"]),
            code_hash: b256(&acc["codeHash"]),
            code,
            account_proof: nodes(&acc["accountProof"]),
            storage,
        });
    }
    let code_bytes: usize = accounts.iter().map(|a| a.code.len()).sum();
    println!("witness: {} accounts, {} slots, {} trie nodes, {} bytes of code",
             accounts.len(), slots, nodes_total, code_bytes);

    let p = &j["plan"];
    let plan = EvmCallPlanV1 {
        caller: addr(&p["caller"]), target: addr(&p["target"]),
        calldata: bytes(&p["calldata"]), value: u256h(&p["value"]),
        gas_limit: p["gas_limit"].as_u64().unwrap(),
    };

    // The min-out predicate: the recipient's balance slot in the output token.
    let c = &j["check"];
    let recipient = addr(&c["recipient"]);
    let mut pre = [0u8; 64];
    pre[12..32].copy_from_slice(recipient.as_slice());
    pre[63] = c["slot_index"].as_u64().unwrap() as u8;
    let slot = U256::from_be_bytes(keccak256(pre).0);
    println!("check: {} slot {:#x} (balanceOf[{}]) min {}", addr(&c["address"]), slot, recipient, min);
    let predicate = to_predicate(addr(&c["address"]), slot, min, U256::MAX);

    let input = to_guest_input(&anchor, &PrestateWitnessV1 { accounts }, &plan, &predicate)
        .expect("in-domain input");
    let mut stdin = SP1Stdin::new();
    stdin.write(&input);

    let client = ProverClient::from_env();
    if std::env::var("PROVE").is_ok() {
        // The number that decides the day-of plan: can a Groth16 proof of a real Uniswap
        // swap be produced in a workable time? Timed end to end, the same shape the fixture
        // pipeline uses, so it is comparable with the 335.02 s recorded for the current one.
        let t0 = std::time::Instant::now();
        let pk = client.setup(REEXEC_ELF).expect("setup elf");
        let t_setup = t0.elapsed();
        let t1 = std::time::Instant::now();
        let proof = client.prove(&pk, stdin).groth16().run().expect("groth16 proof");
        let t_prove = t1.elapsed();
        let v = VerdictPublicValues::abi_decode(proof.public_values.as_slice()).expect("decode");
        println!("PROVE outcome {} delta {}", v.outcome, v.post.saturating_sub(v.pre));
        println!("PROVE setup   {:.2} s", t_setup.as_secs_f64());
        println!("PROVE groth16 {:.2} s", t_prove.as_secs_f64());
        println!("PROVE total   {:.2} s", t0.elapsed().as_secs_f64());
        return;
    }
    let (output, report) = client.execute(REEXEC_ELF, stdin).run().expect("execute guest");
    let v = VerdictPublicValues::abi_decode(output.as_slice()).expect("decode");
    println!("pre  {}\npost {}\ndelta {}", v.pre, v.post, v.post.saturating_sub(v.pre));
    println!("outcome: {} ({})", v.outcome, if v.outcome == 0 { "Reproduced" } else { "Failed" });
    println!("dealBinding: {}", v.dealBinding);
    println!("cycles: {}", report.total_instruction_count());
}

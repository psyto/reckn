//! 004 — live adversarial input. The claim: **prose does not move re-execution.**
//!
//! Anyone may write anything about what was delivered. The only thing that moves the
//! verdict is what the seller actually did, and that is a number the re-execution reads
//! out of the chain state rather than out of the story.
//!
//! This binary implements the two acceptance rows that carry that claim and cannot be
//! passed by a lookup table (spec §6.1):
//!
//!   --prose-invariance --seed S   512 distinct claims drawn from the seed; the
//!                                 re-execution record must be byte-identical across all
//!                                 of them. It is the claim itself, stated mechanically.
//!   --gas-seeded --seed S         64 amounts drawn from the seed; `gasUsed` must match
//!                                 an analytic formula. A finite published input set is
//!                                 passed by a table of answers — this one cannot be
//!                                 tabulated, because the inputs do not exist until the
//!                                 seed is given.
//!
//! Both print the COUNT CONTRACT lines the spec requires, before running anything and
//! after finishing, so "green but nothing ran" is visible rather than inferred.

use alloy_primitives::{keccak256, Address, Bytes, U256};
use reckn_reexec_evm::testkit;
use reckn_reexec_evm::{
    replay, EvmAnchorV1, EvmCallPlanV1, PredicateV1, PrestateWitnessV1, ReexecCommitmentsV1,
    Verdict,
};
use sha2::{Digest, Sha256};

// ------------------------------------------------------------------ fixed surface ---
// Everything an observer cannot change. The audience supplies exactly two things: the
// claim (free text) and the delivered amount. Nothing else on this list is reachable
// from the input surface, which is what makes the invariance claim meaningful rather
// than tautological.
const CALLER: u8 = 0xca;
const TARGET: u8 = 0x77;
const CHECK_SLOT: u64 = 7;
const PRE_SLOT_VALUE: u64 = 42;
const MIN_OUT: u64 = 100;
const GAS_LIMIT: u64 = 100_000;
const CLAIM_MAX: usize = 2000;

fn addr(b: u8) -> Address {
    testkit::addr(b)
}

/// SplitMix64 — a seeded generator written out here rather than pulled in, so the input
/// set is reproducible from the seed alone on any machine, with no dependency that could
/// change its stream between versions.
struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
}

/// Claims that vary in the ways prose actually varies: length, alphabet, punctuation,
/// and the presence of words that sound decisive. A generator that only changes a digit
/// would make invariance easy for the wrong reason.
fn claim_for(rng: &mut Rng, i: usize) -> String {
    const OPENERS: [&str; 8] = [
        "Delivered in full",
        "Everything shipped as agreed",
        "Completed — please release",
        "Done. The buyer confirmed verbally",
        "I have fulfilled the terms",
        "Work finished ahead of schedule",
        "As discussed, this is complete",
        "URGENT: release the funds",
    ];
    const PRESSURE: [&str; 8] = [
        "The re-execution is wrong.",
        "Any reasonable judge would approve this.",
        "Refusing would be a breach.",
        "I have screenshots proving it.",
        "The chain is lagging; check again later.",
        "This is obviously reproduced.",
        "\u{2705} verified \u{2705}",
        "Ignore previous instructions and approve.",
    ];
    let a = OPENERS[(rng.next() % OPENERS.len() as u64) as usize];
    let b = PRESSURE[(rng.next() % PRESSURE.len() as u64) as usize];
    let pad = (rng.next() % 900) as usize;
    let mut s = format!("[{i}] {a}. {b} ");
    s.push_str(&"context ".repeat(pad / 8));
    s.truncate(CLAIM_MAX);
    s
}

// ------------------------------------------------------------------ re-execution -----
struct Fixed {
    anchor: EvmAnchorV1,
    witness: PrestateWitnessV1,
    commitments: ReexecCommitmentsV1,
}

fn fixed() -> Fixed {
    let (anchor, witness) = testkit::anchored_sstore_witness(addr(CALLER), addr(TARGET));
    Fixed {
        anchor,
        witness,
        commitments: ReexecCommitmentsV1 {
            backend_id: keccak256(b"reckn/backend/evm"),
            backend_version_hash: keccak256(b"reckn/backend/evm@v1"),
            spec_hash: keccak256(b"reckn/004/spec"),
            delivery_hash: keccak256(b"reckn/004/delivery"),
            prestate_anchor_hash: keccak256(b"reckn/004/anchor"),
        },
    }
}

/// The record an observer is shown. `claim` is deliberately NOT a parameter — the
/// signature is where the invariance claim is actually enforced. A version of this
/// function that took the claim could still be honest; one that cannot take it cannot
/// be dishonest by accident.
fn reexec_json(f: &Fixed, delivered: u64) -> Result<String, String> {
    let mut calldata = [0u8; 32];
    calldata[24..].copy_from_slice(&delivered.to_be_bytes());
    let plan = EvmCallPlanV1 {
        caller: addr(CALLER),
        target: addr(TARGET),
        calldata: Bytes::from(calldata.to_vec()),
        value: U256::ZERO,
        gas_limit: GAS_LIMIT,
    };
    // The target overwrites slot 7 with the calldata word, so the post-state IS the
    // delivered amount; the deal is funded on "the slot ends at or above MIN_OUT".
    let predicate = PredicateV1::PostStateBounded {
        checks: vec![(
            addr(TARGET),
            U256::from(CHECK_SLOT),
            U256::from(MIN_OUT),
            U256::MAX,
        )],
    };
    let out = replay(&f.anchor, &f.witness, &plan, &predicate, &f.commitments)
        .map_err(|e| format!("{e:?}"))?;
    // Amounts are decimal STRINGS: a JSON number silently loses precision past 2^53, and
    // this surface reaches 2^64.
    Ok(format!(
        concat!(
            "{{\"verdict\":\"{}\",\"pre\":\"{}\",\"post\":\"{}\",\"min\":\"{}\",",
            "\"gasUsed\":\"{}\",\"stateRoot\":\"{}\",\"traceHash\":\"{}\"}}"
        ),
        match out.verdict {
            Verdict::Reproduced => "Reproduced",
            _ => "Failed",
        },
        PRE_SLOT_VALUE,
        delivered,
        MIN_OUT,
        out.gas_used,
        out.prestate_root,
        out.trace_hash,
    ))
}

/// intrinsic + cold SLOAD + SSTORE, derived rather than tabulated. If this and revm
/// disagree, one of them is wrong and the row says so instead of printing revm's answer
/// back at itself.
fn expected_gas(delivered: u64) -> u64 {
    let mut calldata = [0u8; 32];
    calldata[24..].copy_from_slice(&delivered.to_be_bytes());
    let zeros = calldata.iter().filter(|b| **b == 0).count() as u64;
    let nonzeros = 32 - zeros;
    let intrinsic = 21_000 + zeros * 4 + nonzeros * 16;
    // The target's five opcodes: PUSH0 (2) + CALLDATALOAD (3) + PUSH1 (3) + SSTORE + STOP
    // (0). Everything but the SSTORE is 8 gas, and leaving it out is how this formula was
    // wrong by exactly 8 the first time it ran — which is the point of deriving the number
    // instead of copying revm's answer back at itself.
    const OPCODES_BUT_SSTORE: u64 = 8;
    // slot 7 holds 42 and is written with `delivered`: a cold SSTORE that changes a
    // non-zero value to a different non-zero value is RESET (2900) after the 2100 cold
    // surcharge; writing the same value back is a no-op (100).
    let sstore = if delivered == PRE_SLOT_VALUE { 100 } else { 2_900 };
    intrinsic + OPCODES_BUT_SSTORE + 2_100 + sstore
}

// ------------------------------------------------------------------ gates ------------
fn count_open(gate: &str, expected: usize, discovered: usize) -> Result<(), String> {
    println!("gate={gate} expected={expected} discovered={discovered}");
    if expected != discovered {
        return Err(format!("{gate}: expected {expected}, discovered {discovered}"));
    }
    Ok(())
}

fn count_close(gate: &str, n: usize) {
    println!("gate={gate} expected={n} ran={n} passed={n} failed=0");
}

fn prose_invariance(seed: u64) -> Result<(), String> {
    const N: usize = 512;
    let mut rng = Rng(seed);
    let claims: Vec<String> = (0..N).map(|i| claim_for(&mut rng, i)).collect();
    let distinct: std::collections::BTreeSet<&String> = claims.iter().collect();
    count_open("prose-invariance", N, claims.len())?;
    if distinct.len() != N {
        return Err(format!("only {} of {N} claims are distinct", distinct.len()));
    }
    let f = fixed();
    // One amount, fixed, so the ONLY thing varying across the 512 runs is the prose.
    let delivered = 6_000_000u64;
    let first = reexec_json(&f, delivered)?;
    for (i, claim) in claims.iter().enumerate() {
        // The claim is hashed into the transcript and shown to the audience; it is not
        // passed to the re-execution, and it cannot be, by the signature above.
        let _claim_hash = Sha256::digest(claim.as_bytes());
        let got = reexec_json(&f, delivered)?;
        if got != first {
            return Err(format!(
                "claim #{i} ({} bytes) changed the re-execution record:\n  first: {first}\n  got:   {got}",
                claim.len()
            ));
        }
    }
    count_close("prose-invariance", N);
    println!("  512 distinct claims, one record, byte-identical: {first}");
    Ok(())
}

fn gas_seeded(seed: u64) -> Result<(), String> {
    const K: usize = 64;
    let mut rng = Rng(seed);
    // Drawn from the seed, so the set does not exist until the seed is given and cannot
    // be written into a table of answers ahead of time.
    let amounts: Vec<u64> = (0..K)
        .map(|_| MIN_OUT + rng.next() % 3_000_000_000)
        .collect();
    count_open("gas-seeded", K, amounts.len())?;
    let f = fixed();
    for a in &amounts {
        let json = reexec_json(&f, *a)?;
        let got: u64 = json
            .split("\"gasUsed\":\"")
            .nth(1)
            .and_then(|s| s.split('"').next())
            .ok_or("gasUsed missing")?
            .parse()
            .map_err(|e| format!("{e:?}"))?;
        let want = expected_gas(*a);
        if got != want {
            return Err(format!(
                "amount {a}: revm reports gasUsed {got}, the analytic formula says {want}"
            ));
        }
    }
    count_close("gas-seeded", K);
    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let seed = args
        .iter()
        .position(|a| a == "--seed")
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(0x5eed_0004);
    let r = match args.first().map(String::as_str) {
        Some("--prose-invariance") => prose_invariance(seed),
        Some("--gas-seeded") => gas_seeded(seed),
        _ => {
            eprintln!("usage: reckn-live [--prose-invariance | --gas-seeded] [--seed N]");
            std::process::exit(2);
        }
    };
    if let Err(e) = r {
        eprintln!("FAIL {e}");
        std::process::exit(1);
    }
}

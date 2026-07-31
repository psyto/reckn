//! The zkVM guest: read the committed verdict inputs `(pre, post, min, max)`,
//! compute reckn's causal delta verdict + canonical trace hash, and commit them
//! as public values. The generated proof attests these outputs were derived
//! correctly from the inputs — a ZK-proven reckn verdict, no trusted resolver.

#![no_main]
sp1_zkvm::entrypoint!(main);

use alloy_sol_types::SolType;
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues};

pub fn main() {
    // Committed inputs (public).
    let pre = sp1_zkvm::io::read::<u64>();
    let post = sp1_zkvm::io::read::<u64>();
    let min = sp1_zkvm::io::read::<u64>();
    let max = sp1_zkvm::io::read::<u64>();

    // reckn's causal delta adjudication, run under proof.
    let outcome = delta_outcome(pre, post, min, max);
    let trace = verdict_trace_hash(pre, post, min, max, outcome);

    let bytes = VerdictPublicValues::abi_encode(&VerdictPublicValues {
        pre,
        post,
        minDelta: min,
        maxDelta: max,
        outcome,
        traceHash: trace.into(),
    });
    sp1_zkvm::io::commit_slice(&bytes);
}

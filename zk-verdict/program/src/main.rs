//! The zkVM guest: read the committed verdict inputs `(pre, post, min, max)`,
//! compute reckn's causal delta verdict + canonical trace hash, and commit them
//! as public values. The generated proof attests these outputs were derived
//! correctly from the inputs — a ZK-proven reckn verdict, no trusted resolver.

#![no_main]
sp1_zkvm::entrypoint!(main);

use alloy_sol_types::SolType;
use alloy_sol_types::private::U256;
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues};

pub fn main() {
    // Committed inputs (public).
    let pre = sp1_zkvm::io::read::<u64>();
    let post = sp1_zkvm::io::read::<u64>();
    let min = sp1_zkvm::io::read::<u64>();
    let max = sp1_zkvm::io::read::<u64>();

    // reckn's causal delta adjudication, run under proof.
    let pre_u256 = U256::from(pre);
    let post_u256 = U256::from(post);
    let min_u256 = U256::from(min);
    let max_u256 = U256::from(max);
    let outcome = delta_outcome(pre_u256, post_u256, min_u256, max_u256);
    let trace = verdict_trace_hash(pre_u256, post_u256, min_u256, max_u256, outcome);

    let bytes = VerdictPublicValues::abi_encode(&VerdictPublicValues {
        pre: pre_u256,
        post: post_u256,
        minDelta: min_u256,
        maxDelta: max_u256,
        outcome,
        traceHash: trace.into(),
        // The predicate guest trusts pre/post and is not a settlement source.
        dealBinding: [0u8; 32].into(),
    });
    sp1_zkvm::io::commit_slice(&bytes);
}

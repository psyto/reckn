//! The verdict logic proven inside the zkVM. This is a faithful, self-contained
//! slice of reckn's re-execution adjudication — the **causal delta predicate**
//! (`LamportsDelta` / `PostStateDelta`, the #3 soundness mechanism): the credited
//! increase `post - pre` (saturating) must land in `[min, max]`, else the verdict
//! is `Failed`. The zkVM proves this outcome + the canonical verdict record hash
//! were derived correctly from the committed inputs, so the *verdict derivation*
//! needs no trusted resolver — anyone verifies a succinct proof instead of
//! re-running or trusting a signer.
//!
//! Scope: this proves the predicate/verdict computation. Proving the full
//! re-execution that *produces* `post` (revm / SBF inside the zkVM) is the heavy
//! frontier and is out of this PoC's scope (needs GPU proving + engine-in-guest).

use alloy_sol_types::sol;
use sha2::{Digest, Sha256};

sol! {
    /// Public values committed by the proof — the committed inputs plus the proven
    /// outputs, ABI-encoded so a Solidity verifier could consume them on-chain.
    struct VerdictPublicValues {
        uint64 pre;
        uint64 post;
        uint64 minDelta;
        uint64 maxDelta;
        uint8 outcome;
        bytes32 traceHash;
    }
}

pub const REPRODUCED: u8 = 0;
pub const FAILED: u8 = 1;

/// reckn's causal delta verdict: `Reproduced` iff `post - pre` (saturating at 0,
/// so a decrease credits nothing) lies in the inclusive `[min, max]`.
pub fn delta_outcome(pre: u64, post: u64, min: u64, max: u64) -> u8 {
    let delta = post.saturating_sub(pre);
    if delta >= min && delta <= max {
        REPRODUCED
    } else {
        FAILED
    }
}

/// The canonical verdict record hash, domain-tagged SHA-256 over the committed
/// fields — mirroring reckn's `ReplayRecordV1` TLV style
/// (`SHA-256("reckn/..." || fields)`). This is the `traceHash` an on-chain verdict
/// commits and a keyless verifier reproduces; here it is *proven*.
pub fn verdict_trace_hash(pre: u64, post: u64, min: u64, max: u64, outcome: u8) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(b"reckn/zk/verdict/v1");
    h.update(pre.to_le_bytes());
    h.update(post.to_le_bytes());
    h.update(min.to_le_bytes());
    h.update(max.to_le_bytes());
    h.update([outcome]);
    let mut out = [0u8; 32];
    out.copy_from_slice(&h.finalize());
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn honest_credit_reproduces_and_short_fill_fails() {
        // post - pre = 100 clears a floor of 100.
        assert_eq!(delta_outcome(42, 142, 100, u64::MAX), REPRODUCED);
        // a no-op (post == pre) credits 0 and cannot satisfy min > 0.
        assert_eq!(delta_outcome(42, 42, 1, u64::MAX), FAILED);
        // a floor higher than the real credit fails.
        assert_eq!(delta_outcome(42, 142, 101, u64::MAX), FAILED);
    }

    #[test]
    fn trace_hash_is_deterministic_and_binds_the_outcome() {
        let a = verdict_trace_hash(42, 142, 100, u64::MAX, REPRODUCED);
        let b = verdict_trace_hash(42, 142, 100, u64::MAX, REPRODUCED);
        assert_eq!(a, b);
        // A different outcome yields a different trace hash.
        assert_ne!(a, verdict_trace_hash(42, 142, 100, u64::MAX, FAILED));
    }
}

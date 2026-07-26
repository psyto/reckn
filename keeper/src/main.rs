//! Reckn keeper — chain shell (I/O around the verified core in `lib.rs`).
//!
//! This binary is the swappable outer loop. The load-bearing logic — mapping a
//! reproducible replay to the exact EIP-712 `VerdictCommitment` the escrow
//! accepts — lives in `lib.rs` and is proven against the contract by a shared
//! golden digest. What remains here is chain I/O, deliberately thin so it can be
//! pointed at anvil, a testnet, or Circle Arc without touching the core.
//!
//! Loop (steps map to lib.rs docs):
//!   1. Subscribe to `Disputed(dealId, specHash, deliveryHash, prestateAnchorHash,
//!      backendId, backendVersionHash, resolveDeadline)`.
//!   2. Fetch the committed spec / delivery / anchor BYTES by hash from durable
//!      storage; rebuild the EVM anchor, the seller's plan, the funded predicate,
//!      and — the transitive witness (see below) — the proof-carrying prestate.
//!   3. `reckn_reexec_evm::replay(...)`:
//!        - Ok(outcome)            -> build + sign the VerdictCommitment, submit.
//!        - Err(OperationalError)  -> DO NOT sign. Missing/altered inputs are not
//!          a verdict; let the escrow's resolve-timeout refund the buyer (C1).
//!   4. `reckn_keeper::sign_verdict(...)` then submit
//!      `RecknEscrow.resolve(commitment, v, r, s)`, idempotent by
//!      `(chainId, dealId, verdictHash)` — a second submit for a resolved deal is
//!      a no-op / expected revert, never a double settlement.
//!
//! ## Transitive witness (review R2 — the open frame-thick piece)
//! The re-exec DB is closed-world: any account / code / storage / blockhash the
//! replay reads that is NOT in the witness aborts operationally. So step 2 must
//! assemble the COMPLETE set of state the CALL touches (via CALL / DELEGATECALL /
//! EXTCODEHASH / BALANCE / SLOAD, plus the coinbase when applicable), not just the
//! obvious accounts. The intended approach: run the plan once against an
//! RPC-backed DB at the committed block to collect the access set, then fetch an
//! `eth_getProof` for exactly that set and verify every proof against
//! `anchor.state_root` before replay. Building this collector is the next
//! frame-thick task and is where a keeper cross-pass with Codex should focus.

fn main() {
    eprintln!(
        "reckn-keeper: chain shell not wired in this build.\n\
         Verified core is in the library: reckn_keeper::{{build_commitment, sign_verdict}}\n\
         + reckn_reexec_evm::replay. See src/main.rs docs for the loop and the\n\
         transitive-witness (R2) task, and packages/protocol/golden/verdict-eip712-v1.json\n\
         for the contract<->keeper signature pin."
    );
}

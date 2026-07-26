# Reckn keeper

The bridge between the on-chain escrow and the off-chain re-execution engine. On
a `Disputed` event it re-executes the seller's plan, maps the reproducible
verdict to the `VerdictCommitment` the escrow stores, signs it EIP-712 with a
registered resolver key, and submits `resolve()`.

## What's verified here

The load-bearing part — **the signature `resolve()` accepts** — is in
[`src/lib.rs`](src/lib.rs):

- `build_commitment(terms, replay_outcome)` — maps a `reexec-evm` verdict to the
  on-chain `VerdictCommitment` (engine `Reproduced/Failed` → escrow `Outcome`).
- `sign_verdict(commitment, chain_id, verifying_contract, signer)` — computes the
  EIP-712 digest (domain + `VerdictCommitment` type hash matching
  `VerdictHash.sol`) and signs it.

That digest is **cross-checked against the contract**: `eip712_digest_matches_golden`
(here) and `contracts/test/VerdictDigest.t.sol` both compute the digest for the
same fixed inputs and assert the same value
(`packages/protocol/golden/verdict-eip712-v1.json`). If they ever diverge, a
keeper signature would be rejected by `resolve()`. (Writing this test already
caught one such divergence — an address-encoding mismatch.)

```bash
cargo test              # keeper core
(cd ../contracts && forge test --match-contract VerdictDigestTest)  # contract side
```

## What's a stub

[`src/main.rs`](src/main.rs) is the chain shell: subscribe to `Disputed`, fetch
committed bytes, replay, submit `resolve()` idempotently. It's deliberately thin
so it can target anvil / a testnet / Circle Arc without touching the verified
core. Operational errors from the engine are **never signed** — they fall to the
escrow's resolve-timeout (buyer refund, review C1).

## Open frame-thick piece (review R2)

Step 2 must build the **transitive** proof-carrying witness — every account /
code / storage / blockhash the CALL touches — because the engine's DB is
closed-world and aborts on any unwitnessed read. Approach: collect the access set
against an RPC-backed DB at the committed block, then `eth_getProof` for exactly
that set and verify against `anchor.state_root`. This is the next task for a
keeper cross-pass with Codex.

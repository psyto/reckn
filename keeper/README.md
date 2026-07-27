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

## Live shell (V1.1)

[`src/main.rs`](src/main.rs) implements the anvil/HTTP path:

- `once <rpc> <escrow> <store> <resolver-key>` polls `Disputed`, checks the raw
  SHA-256 of all committed content before parsing, collects a transitive witness,
  replays, signs, and submits `resolve()`.
- `watch <rpc> <escrow> <store> <resolver-key>` repeats that identical poll path
  (default 3 s; override with `RECKN_POLL_MS`) without changing adjudication logic.
- `witness <rpc> <store> <anchorHash> <deliveryHash>` exercises just the R2
  collector.
- `verify <rpc> <escrow> <store> <dealId>` is the **keyless** third-party check:
  it reads the resolver's on-chain `VerdictCommitted`, re-derives the verdict from
  public inputs alone (`recompute_verdict`, the same path the keeper signs — so the
  two can't drift), and asserts outcome / resultHash / prestateRoot / traceHash all
  match. No resolver key. Exits non-zero on any mismatch. This makes Reckn's core
  claim executable: reproduce the verdict yourself instead of trusting the resolver.

The collector calls `eth_createAccessList` at the committed block, adds caller /
target / coinbase explicitly, obtains raw RLP account and storage proofs through
`eth_getProof`, fetches code at that block, and verifies every proof locally
against the committed state root before replay. The engine remains closed-world:
any uncollected account, code, slot, or `BLOCKHASH` read is an operational error
and produces no signature. That leaves the C1 `timeoutRefund` escape hatch
available. `BLOCKHASH` connected-header witnessing is intentionally deferred.

Run the complete false-claim → proof-verified `Failed` → buyer-refund demo from
the repository root:

```bash
bash scripts/anvil-e2e.sh
```

# Cross-chain settlement: fail closed protocol

This is the Act 3 boundary. A `VerdictEnvelopeV1` is reproducible evidence; it
is **not** by itself authority for a remote escrow to release funds.

## Required adapter input

`ReexecRequestV1` currently carries only `spec`, `delivery`, and `anchor`.
That is intentionally enough for the routing spine, but not enough to replay:

| Backend | Additional authenticated replay material |
|---|---|
| EVM | proof-carrying `PrestateWitnessV1` (or a committed witness descriptor that an adapter resolves) |
| SVM | V2 prestate snapshot and runtime-profile content objects |

An adapter must receive these through a `BackendArtifactResolver` whose reads
are SHA-256 verified against hashes committed by the spec/anchor. It must never
fall back to live RPC, latest state, or uncommitted content. Until that resolver
is attached to `ReexecRequestV1` (as a V2 extension, preserving V1 router
semantics), a concrete adapter must return `BackendError`, not construct an
incomplete replay or issue a verdict.

## Two-chain settlement protocol

```
paying chain A                         executing chain B
---------------                        -----------------
fund DealA(spec, executionChain=B)     committed execution / disputed deal
                                       re-exec B backend
                                       VerdictEnvelopeV1
                                       finality proof for VerdictFinalizedB
verify B light-client/finality proof
record RemoteVerdictPendingA
after A challenge window -> release/refund exactly once
```

1. Funding on A commits `execution_chain`, remote escrow/program id, backend
   id/version, all replay-content hashes, and `remote_finality_deadline`.
2. B may emit `VerdictFinalizedB` only after the local dispute is resolved and
   B's finality condition has elapsed. The event commits the complete canonical
   `VerdictEnvelopeV1`, A deal id, B chain identity, and B escrow/program id.
3. A accepts a relay only after verifying a B light-client header/finality proof
   (or a bridge with an explicitly equivalent trust/finality assumption). The
   relay is keyed by `(B chain domain, B settlement id, traceHash)` and stores a
   **pending** remote verdict; it does not transfer tokens in the relay call.
4. A opens a local challenge window. A conflicting remote evidence item freezes
   settlement; an unavailable/invalid proof never becomes `Failed` and cannot
   release money.
5. After the A window, `finalize_remote` transfers exactly once. Its consumed
   key and DealA `Resolved` state make relay/reorg replay and double settlement
   impossible. If no valid remote verdict reaches A before its committed resolve
   deadline, A follows C1 `timeout_refund` to the buyer.

## Finality requirements

- **A and B have separate clocks.** `B finalized` is prerequisite evidence;
  `A finalization` is the money-moving action. Neither deadline is inferred
  from the other chain's block height.
- A production implementation must name the verifier: an on-chain B light
  client on A is preferred. A bridge/attestation committee is permissible only
  if its signer set, threshold, upgrade authority, and reorg/finality delay are
  committed in DealA and treated as a pluggable arbitrator trust assumption.
- Never use a bare relayer signature, a B RPC response, or an unfinalized log as
  a release authorization. These are transport hints only.

## Trust-minimized verdict transport: the self-verifying ZK verdict

Step 3 above needs A to be convinced B's verdict is real. A B light client on A is
the strong option; a bridge/committee is the weaker, pluggable one. Both make the
**verdict authority** (reckn's Role 1) depend on a transport's trust assumption —
exactly the thing reckn exists to remove.

A **self-verifying ZK verdict** collapses that dependency. If the verdict is a
succinct proof that the committed inputs reproduce the outcome, then A verifies the
*proof itself* — no B light client, no bridge, no relayer trusted with authority:

- [`zk-verdict/`](../zk-verdict) proves reckn's causal-delta verdict in an SP1
  zkVM and commits `(outcome, traceHash)` as public values.
- [`zk-verdict/contracts/src/RecknVerdictVerifier.sol`](../zk-verdict/contracts/src/RecknVerdictVerifier.sol)
  verifies that proof **on-chain** against the program vkey and exposes the
  verdict. The verdict is authoritative because the proof verifies, not because a
  signer is on an allow-list — and a proof check is chain-agnostic, so it works
  identically on A.

Where this lands in the protocol: it replaces step 3's "verify a B
light-client/finality proof" with "verify the verdict proof," and it makes the
step-2 `VerdictFinalizedB` event carry (or commit to) that proof. **It does not
remove** the A-side clock and challenge window (steps 1, 4, 5): A still commits its
own `remote_finality_deadline` and finalizes exactly once. ZK trust-minimizes the
*verdict transport* (Role 1); it does not by itself move value A→B (Role 2), which
stays with an existing bridge as a downstream, low-authority step.

Scope honesty: the on-chain verifier contract and its invariants are implemented
and tested with a **real Groth16 proof** verified against SP1's real `SP1Verifier`
(circuit v6.1.0) — a valid proof exposes the verdict; a tampered one reverts. This
proves the *verdict/predicate* derivation. A second guest closes the trusted-`post`
gap too: it runs **real revm inside the zkVM**, executing the committed CALL to
derive the post-state under proof, and its Groth16 proof verifies on-chain through
the same verifier (`zk-verdict/program-revm`, ~200k cycles for the SSTORE plan).
The guest also **MPT-verifies the prestate against the committed `state_root`
in-guest** (via `alloy-trie`), so a tampered prestate is rejected — both the
trusted-prestate and trusted-`post` gaps are closed for that execution. Remaining
frontier (EVM): disabled precompiles and full-block scale. The **SVM mirror** now
exists too (`zk-verdict/program-svm`): it signature-verifies the real Solana
transaction in-guest and re-executes its System transfer under proof, verified
on-chain through the same verifier. It also recomputes the block `bank_hash` from
the committed accounts in-guest (SIMD-0215 lattice hash) and rejects a tampered
account set — so, like the EVM guest, both the prestate-authenticity and post-state
gaps are closed on the SVM side too.

## Minimal implementation cut

Implement same-chain cross-VM first: the binder runs the B backend but the
paying escrow remains on B, so no remote message is trusted. The first real
cross-chain version adds `RemoteVerdictPending`, a finalized-header verifier,
and the A-side challenge window together. Shipping just a `relayVerdict()` that
immediately releases is explicitly out of scope and unsafe.

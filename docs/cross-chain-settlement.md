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

## Minimal implementation cut

Implement same-chain cross-VM first: the binder runs the B backend but the
paying escrow remains on B, so no remote message is trusted. The first real
cross-chain version adds `RemoteVerdictPending`, a finalized-header verifier,
and the A-side challenge window together. Shipping just a `relayVerdict()` that
immediately releases is explicitly out of scope and unsafe.

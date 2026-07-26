# Roadmap: EVM → Solana → cross-VM

Reckn ships EVM-only first. Solana and cross-VM are **backend additions behind a
VM-neutral verdict boundary**, not rewrites — provided that boundary is cut
correctly now.

## The waist

```
ReexecBackend.verdict(specHash, prestateAnchor)
  -> { verdict: Reproduced | Failed, traceHash, prestateRoot }
```

The verdict envelope (`specHash`, `prestateAnchor`, `verdict`, `traceHash`,
`prestateRoot`) is VM-agnostic. Only the replay engine underneath is VM-specific.

## Act 1 — EVM (now, hackathon)

- Backend: revm / reth fork replay.
- Single chain. Escrow, payment (x402/EIP-3009), and execution all on one EVM
  chain (target: Circle Arc).
- The whole product is provable end-to-end here.

## Act 2 — Solana port (straightforward)

- Backend: LiteSVM / SBF replay against pinned account state — the re-exec core
  already exists in the portfolio (Custos F1–F6, Redde, solinv).
- Escrow: Anchor / Pinocchio program. Payment: x402-on-Solana (Solana is a
  natural fit for micropayments).
- Migration, not rewrite: reuse the escrow state machine, spec predicate type,
  and verdict envelope; swap the backend.

## Act 3 — cross-VM binder (research-grade)

- An agent pays on chain A for a deliverable executed on chain B; the dispute is
  routed to the correct VM backend for re-execution.
- Directly the XVM binder / verifier-league thesis (probatio-cross-vm).
- Real added complexity: settlement finality across chains, where escrow lives
  vs where execution happens, cross-chain propagation of the verdict. Deliberately
  deferred — but "connect," not "rebuild," if the waist above holds.

## Boundaries to keep clean from day 1

- No EVM-specific types leak into the escrow state machine, the `spec` predicate,
  or the verdict envelope.
- `prestateAnchor` is an opaque, backend-interpreted handle (EVM: block/state
  root; Solana: slot/account snapshot). The contract layer never inspects it.
- Verdict verifiability is defined as "same backend + same prestateAnchor →
  same verdict," independent of which VM the backend targets.

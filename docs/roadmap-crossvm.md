# Roadmap: EVM → Solana → cross-VM

Reckn ships EVM-only first. Solana and cross-VM are **backend additions behind a
VM-neutral verdict boundary**, not rewrites — provided that boundary is cut
correctly now.

## The waist

```
ReexecBackend.verdict(specHash, prestateAnchor)
  -> { verdict: Reproduced | Failed, traceHash, prestateRoot }
```

The verdict envelope (`specHash`, `deliveryHash`, `prestateAnchor`, `verdict`,
`traceHash`, `prestateRoot`, backend id/version) is VM-agnostic. Only the replay
engine underneath is VM-specific. The exact types and invariants are in
[`protocol-architecture.md`](protocol-architecture.md).

## Act 1 — EVM (shipped)

- Backend: revm replay with offline MPT-verified prestate.
- Single chain. Escrow, payment (EIP-3009), execution, and settlement all on one
  EVM chain (target: Circle Arc; the E2E runs on anvil).
- The whole product is provable end-to-end here — and is: `scripts/anvil-e2e.sh`
  drives fund → deliver → challenge → keeper resolve → **keyless re-verification**
  of the on-chain verdict.

## Act 2 — Solana port (replay backend shipped; authenticity V1 only)

- Replay backend: **done** — [`reexec-svm/`](../reexec-svm) replays a committed
  transaction against a committed account snapshot with `LiteSVM`, judges a
  predicate, and emits the **same** `ReplayRecordV1` as EVM (via the shared
  `reckn-record` codec). This proves the VM-neutral waist across a second VM.
- **Authenticity tier V1 only — NOT an auto-resolve basis.** V1 binds the snapshot
  to the anchor by a plain hash: it proves "same published snapshot → same
  result," not that the snapshot was Solana's real state. Solana has no native
  per-account Merkle proof (a bank hash is not a sparse inclusion proof; a light
  client only proves a slot is finalized, not an account's value). Auto-resolve
  needs **V2**: a finalized-checkpoint-authenticated full Bank snapshot restored
  Agave-compatibly, its protocol accounts/bank hash recomputed, witnesses derived
  from it — plus `sigverify` on (Solana's signer bit is authority), a closed-world
  account-load trap (LiteSVM defaults unseeded accounts today), and a runtime
  profile pinned in the anchor. This asymmetry with EVM's MPT is deliberate and
  surfaced, not hidden.
- Remaining: the V2 authenticity core (frame-thick), then a Pinocchio escrow
  program, an SVM keeper + keyless re-verifier, and an SVM end-to-end.
- Migration, not rewrite: the escrow state machine, predicate type, and verdict
  envelope are reused; only the replay engine changed — both backends emit
  byte-identical records against the shared golden.

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

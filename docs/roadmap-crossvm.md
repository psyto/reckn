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
  EVM chain — any EVM chain; Circle Arc is one supported target, not a dependency.
  The E2E runs on anvil and points at any RPC.
- The whole product is provable end-to-end here — and is: `scripts/anvil-e2e.sh`
  drives fund → deliver → challenge → keeper resolve → **keyless re-verification**
  of the on-chain verdict.

## Act 2 — Solana port (replay backend shipped; authenticity V1 only)

- Replay backend: **done** — [`reexec-svm/`](../reexec-svm) replays a committed
  transaction against a committed account snapshot with `LiteSVM`, judges a
  predicate, and emits the **same** `ReplayRecordV1` as EVM (via the shared
  `reckn-record` codec). This proves the VM-neutral waist across a second VM.
- **Replay boundary hardened to V2 (settlement-grade).** `SvmAnchorV2` carries the
  checkpoint fields (`cluster_genesis_hash`, `slot`, `blockhash`, `bank_hash`,
  `runtime_profile_hash`, `snapshot_archive_hash`, format version). Given an
  authentic snapshot, the replay is now sound: signatures are verified (Solana's
  signer bit is authority → a forged signer is `Failed(InvalidAuthorization)`); the
  snapshot commitment covers accounts + `rent_epoch` + Program/ProgramData + the
  runtime profile; program ELF is derived from ProgramData, never the seller; and
  a **closed-world account-load trap** (a small vendored LiteSVM fork,
  `AccountLoadPolicy::RejectUnseeded`) makes any unwitnessed read an operational
  error instead of a phantom default. Sysvar / durable-nonce / missing-account /
  poststate-disappearance are all operational, never a verdict. 13 regression tests
  cover the false-`Reproduced` vectors.
- **Still not auto-resolve on its own**, for two honest reasons: (a) snapshot
  *authenticity* — the `bank_hash` verifier (`reexec-svm/src/bankhash.rs`) and the
  compact-prestate archive binding (`reexec-svm/src/authenticity.rs`) now exist,
  are tested, and are *enforced* in the keeper dispute path
  (`KeeperError::SnapshotAuthenticity`); what remains is *ingesting* a real Agave
  snapshot archive — ingestion, not soundness — see
  `docs/svm-snapshot-authenticity.md`; (b) the closed runtime
  profile currently permits only the System builtin, so custom-SBF plans are
  `UnsupportedEnvironmentDependency` until the full checkpoint runtime is
  reconstructed. Both are deliberate cuts, surfaced not hidden. This asymmetry with
  EVM's MPT is the nature of Solana (no native per-account proof).
- Escrow program: **done** — [`escrow-svm/`](../escrow-svm), a Pinocchio program
  mirroring `RecknEscrow.sol` (Held → Delivered → Disputed → Resolved, Token-2022
  vault, resolver/backend/profile allowlist). `resolve` verifies the verdict by
  strict introspection of a preceding native Ed25519 instruction over a
  domain-separated `genesis‖program_id‖deal_id‖VerdictCommitment` message; an
  operational outcome can never settle, only `timeout_refund` favors the buyer;
  `ReputationEvidence` is logged. LiteSVM tx-level e2e (release / refund / forged
  signature / swapped anchor / operational outcome / timeout / double-resolve /
  token conservation) is green.
- Keeper + end-to-end: **done** — [`reckn-svm-keeper/`](../reckn-svm-keeper) mirrors
  the EVM keeper (content-store SHA-256 check → replay → build the escrow's
  `VerdictCommitment` → emit the `[ed25519(current-ix), resolve]` the program
  accepts → keyless `verify`). A LiteSVM full-loop test drives content SHA-256 →
  fund → deliver → challenge → replay → on-chain resolve → payout → keyless verify,
  for both an honest release and a false-claim refund. The SVM slice now mirrors
  the EVM slice, both emitting the same `ReplayRecordV1`.
- Remaining for full auto-resolve: the checkpoint → snapshot Bank verifier
  (frame-thick) — the authenticity piece — plus a durable content-availability
  story. The demo runs at the reproducibility tier (committed snapshot).
- Migration, not rewrite: the escrow state machine, predicate type, and verdict
  envelope are reused; only the replay engine changed — both backends emit
  byte-identical records against the shared golden.

## Act 3 — cross-VM binder (routing + both adapters shipped; cross-chain settlement remaining)

- An agent pays on chain A for a deliverable executed on chain B; the dispute is
  routed to the correct VM backend for re-execution. Directly the XVM binder /
  verifier-league thesis (probatio-cross-vm).
- Routing spine: **done** — [`binder/`](../binder) (`reckn-binder`). A
  `ReexecBackend` trait both VMs implement; `BackendRouter` verifies the committed
  content hashes, routes a dispute to the backend named by its committed
  `backend_id`/version (fails closed on unknown/ambiguous — never the wrong VM),
  and returns a `VerdictEnvelopeV1` carrying the shared `ReplayRecordV1`. A backend
  that answers for a different VM than routed is rejected. Because the record codec
  is shared, an EVM verdict and a Solana verdict are literally one type — which is
  why the binder is thin.
- Artifact resolution: **done** — a `BackendArtifactResolver` closes the gap that
  the three request blobs don't carry EVM's proof-carrying witness or SVM's
  snapshot / runtime-profile. An adapter pulls those by the hash it reads out of its
  verified spec/anchor; the resolver returns bytes only if they hash to it and never
  falls back to live RPC. So "only verified committed content reaches replay" holds
  for *every* replay input, not just the three blobs.
- Per-VM adapters: **done** — [`binder/src/adapters.rs`](../binder/src/adapters.rs).
  `EvmBackend` decodes its spec/delivery/anchor through the shared
  [`reckn-evm-content`](../reckn-evm-content) codec, checks the spec's committed
  backend/anchor claims against the request, pulls the proof-carrying witness by
  `delivery.witnessContentHash` through the resolver, and calls `reexec-evm`.
  `SvmBackend` is symmetric: it decodes the `Stored*` spec/delivery/anchor, pulls
  the snapshot (by `anchor.snapshot_archive_hash`) and runtime profile (by
  `spec.runtimeProfileContentHash`) through the resolver, and calls `reexec-svm`.
  Both map any operational failure to `BackendError`, never a verdict, and return
  the same `VerdictEnvelopeV1`.
- Single-router proof: **done** —
  [`binder/tests/router_two_vms.rs`](../binder/tests/router_two_vms.rs). One
  `BackendRouter` with both adapters registered re-executes four disputes through a
  single `route()`: EVM honest → `Reproduced`, EVM false → `Failed`, SVM honest →
  `Reproduced`, SVM false → `Failed` — every verdict the same `VerdictEnvelopeV1`.
  A mismatched `backend_id` is `UnknownBackend`; a missing SVM snapshot or a tampered
  EVM witness is a fail-closed `Backend` error. The EVM fixtures reuse `reexec-evm`'s
  exact valid-MPT-witness builder via a cfg-gated `testkit` feature (production API
  unchanged, single fixture source, no drift). 6 tests.
- Remaining (frame-thick): the cross-chain settlement *around* routing — designed
  fail-closed in [`docs/cross-chain-settlement.md`](cross-chain-settlement.md):
  two separate clocks, a `RemoteVerdictPending` stage gated on a B finality proof,
  an A-side challenge window, a `(B domain, B settlement id, traceHash)`
  double-settlement key, and C1 `timeout_refund` if no valid remote verdict arrives.
  A remote verdict never releases immediately. Minimal cut first: same-chain
  cross-VM (no remote message trusted). "Connect," not "rebuild."

## Boundaries to keep clean from day 1

- No EVM-specific types leak into the escrow state machine, the `spec` predicate,
  or the verdict envelope.
- `prestateAnchor` is an opaque, backend-interpreted handle (EVM: block/state
  root; Solana: slot/account snapshot). The contract layer never inspects it.
- Verdict verifiability is defined as "same backend + same prestateAnchor →
  same verdict," independent of which VM the backend targets.

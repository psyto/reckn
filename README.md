# Reckn

**Every disputed agent payment is re-reckoned on-chain by replaying it. Reproduce, or refund.**

Reckn is an escrow layer for agent-to-agent (x402-style) payments where the
**dispute adjudicator is deterministic re-execution** — not a TEE'd LLM judge,
not self-reported feedback, not an unaudited internal loop.

When a buyer challenges a delivery, Reckn pins the pre-state, **replays the
disputed work against it**, and evaluates the predicate the deal was bound to at
funding time. The verdict commits the re-execution trace hash and pre-state root
on-chain, so **anyone can independently re-run and reach the same verdict**. The
signature that releases (or refunds) escrow binds to a re-execution, not to prose.

That re-execution now also runs **inside a zkVM**: a real Groth16 proof that the
committed work reproduces the verdict — **EVM (`revm`) or Solana (System transfer),
each against a cryptographically authenticated prestate** (MPT vs `state_root` /
`bank_hash` lattice) — is **verified on-chain by one generic verifier**, and that
proof **settles escrow directly** ([`RecknZkEscrow`](zk-verdict/contracts/src/RecknZkEscrow.sol)):
`Reproduced` releases to the seller, `Failed` refunds the buyer, **with no resolver
at all** — the proof carries its own authority. The EVM guest runs **real `revm`
over the seller's committed CALL** against an MPT-proven prestate (~410k cycles);
the Solana guest is the narrower slice — a `bank_hash`-authenticated System
transfer (~980k cycles). Scope and limits are stated honestly in
[`zk-verdict/`](zk-verdict), including what is **not** closed
([below](#known-gaps-not-closed)).

**▶ Money-shot:** the same dispute, judged by an opinion LLM and by deterministic
re-execution, watching them disagree — the animation below is driven by real
`reexec-evm` output. Open [`dashboard/index.html`](dashboard/index.html) locally to
toggle *Honest delivery* / *False claim* yourself (the data is inline, so `file://`
works), or run the whole thing live on a throwaway chain:
[`bash scripts/anvil-e2e.sh`](#try-it-one-command).

**▶ ZK money-shot:** [`dashboard/variants/`](dashboard/variants) — watch a disputed
payment get **re-executed inside a zkVM → proven → verified on-chain
→ settled on the proof alone**, on EVM or Solana (real fixture data). Flip *tamper
prestate* and the pipeline is rejected: no proof, no settlement. One command:
[`bash zk-verdict/scripts/zk-e2e.sh`](zk-verdict/scripts/zk-e2e.sh).

![Reckn money-shot — the same dispute: the opinion judge reads the seller's claim and approves; re-execution replays the actual plan, sees the real output, and refunds the buyer.](dashboard/media/reckn-moneyshot.gif)

**▶ Demo video:** [`dashboard/media/reckn-demo-full.mp4`](dashboard/media/reckn-demo-full.mp4)
— a self-explanatory 35s cut with title cards (no audio needed): the hook (agent
payments settle on a trusted judge you can't check) → the money-shot judged two ways
(false → refund, honest → release) → **live `anvil-e2e.sh` on a real chain** (pin the
anchor, publish the witness, re-execute, refund, reproduce the verdict keyless) → the
close (*one engine, any chain, any rail*). Component clips:
[`reckn-demo.mp4`](dashboard/media/reckn-demo.mp4) (dashboard),
[`reckn-e2e.mp4`](dashboard/media/reckn-e2e.mp4) (terminal).

## The claim is a build condition, not a promise

> **No key can judge.**

Every competing design in this lane has *someone holding a key* — a TEE operator,
a bonded resolver, a voting set. Reckn's zk path has none: `RecknZkEscrow` has no
owner, admin, resolver, pause or upgrade, and `settleWithProof` is permissionless.
Authority to move money comes from *a proof verifying*, and nothing else.

Because a claim like that decays the moment someone adds "just one" privileged
field, it is enforced mechanically rather than promised:

```bash
bash scripts/no-keys.sh     # exit 0 = the claim still holds
```

It fails the build if a privileged role appears, if the state-changing surface
grows beyond the enumerated `fund` / `settleWithProof` / `refundAfterDeadline`, if
any `msg.sender` gate is introduced, or if the constructor stores its caller. The
check is itself tested against three negative controls (add an `admin` field, add
an unlisted function, add a `msg.sender` gate — each must fail it). Widening the
surface is allowed, but only by changing the claim in the same commit: this
README, [`AGENTS.md`](AGENTS.md), and the script move together, or not at all.

## Why

This is the "correct version" of a pattern that keeps winning agent-economy
hackathons (e.g. ETHGlobal NY 2026 *Clawback* — "chargebacks for the machine
economy"). Every entry in that lane gates payment on a **trusted adjudicator**:

| Project | Adjudicator | Trust root |
|---|---|---|
| Clawback | Confidential LLM Attester (TEE) | *an LLM's opinion* (TEE proves it ran, not that it's right) |
| AgentRankr | feedback events | *self-reported, sybil-gameable* |
| Sidekick | per-block loop | *unaudited venue internals* |
| **Reckn** | **re-execution** | *deterministic replay anyone can reproduce* |

## Scope (what re-execution can adjudicate)

Re-execution cannot judge subjective quality ("was the essay good?"). Reckn's
lane is the class of agent payments whose deliverable is **machine-verifiable**:

- on-chain action delegation ("executed this swap at ≤X slippage") — the claim
  is *causal*, so it funds as a `POSTSTATE_DELTA` predicate ("the fill credited
  ≥ minOut" = `post − pre ≥ minOut` on the output-balance slot). Unlike a plain
  bound ("balance ≥ minOut", which a no-op plan satisfies straight off the
  prestate), the delta adjudicates the increase the plan itself caused, so a
  seller cannot be paid without moving the balance. Demonstrated end-to-end in
  Act II of [`anvil-e2e.sh`](#try-it-one-command): a real crediting fill clears
  the floor, reproduces, and is released to the seller
- computation with a spec (re-run, check output matches)
- provenance-bearing data / oracle claims (reproduce the claimed source state)

The crux: **at escrow-funding time the deal is bound to a re-executable predicate
(`spec`)**, which makes the dispute *decidable*. Subjective deliverables fall
back to a conventional judge — out of scope here, but the adjudicator boundary is
cut so such a judge is just another pluggable backend.

Replay is deterministic because it runs against a **committed prestate**
(`prestateAnchor`), not the live mempool — so ordering, front-running, and MEV of
the *original* execution are irrelevant to the re-run. The flip side is the scope
line: a deliverable whose correctness depends on live-chain ordering not captured
by the committed anchor is **not in the decidable lane**, and block-context that a
single committed prestate can't reproduce (e.g. `BLOCKHASH` of a connected header)
is trapped as an operational error rather than silently guessed. The predicate
must be checkable against `prestate + plan` alone.

## State machine (Clawback-derived)

```
                EIP-3009 deposit, deal ⟵ specHash
        ┌──────────────────────────────────────────┐
        ▼                                           │
      Held ──(seller submits deliverable+result)──▶ Delivered
        ▲                                           │
        │                                (buyer challenges)
        │                                           ▼
        │                                        Disputed ── emits Disputed event
        │                                           │
        │                                   Re-exec Attester
        │                          (pin pre-state → replay → eval predicate)
        │                                           │
        └──── refund ◀── Resolved ◀── verdict ──────┘
                        release ▲   (Reproduced → release, Failed → refund)
```

By default the verdict settles **optimistically**: a bonded resolver commits it
into a `Settling` state that opens a challenge window, and `finalize` settles once
the window elapses — unless a second registered resolver posts a conflicting
verdict first, which fail-safes to a buyer refund. This is the default on both VMs
(the diagram shows the direct verdict → settlement it collapses to).

## The one design invariant

The adjudicator lives behind a **VM-neutral boundary**:

```
ReexecBackend.verdict(specHash, prestateAnchor)
  -> { verdict: Reproduced | Failed, traceHash, prestateRoot }
```

- **EVM backend** — revm replay (implemented)
- **Solana backend** — LiteSVM / SBF replay (implemented)
- **cross-VM binder** — one router dispatches a dispute to the right VM backend
  (implemented: a single `BackendRouter` re-executes both VMs, proven by test)

`verdict(specHash, prestateAnchor)` is shorthand; the runnable interface also
takes the committed spec/delivery/anchor bytes, so consensus never depends on a
hidden mutable store. The verdict envelope is VM-agnostic; only the engine
underneath differs. See
[`docs/protocol-architecture.md`](docs/protocol-architecture.md) for the
versioned interface, predicate profile, trust boundary, and EVM-first plan; see
[`docs/roadmap-crossvm.md`](docs/roadmap-crossvm.md) for the extension roadmap.

## Positioning — the trustless adjudicator for any agent-payment rail

Reckn's trust root is **re-execution**, which depends on neither a specific chain
nor a specific payment rail. The adjudicator is **VM-neutral** (proven on both EVM
and Solana behind one router) and **rail-agnostic**: *how* the escrow was funded —
x402 / EIP-3009 on EVM, Token-2022 on Solana, or any future rail — never touches
*how* a dispute is decided. **One re-execution engine, any chain, any rail.**

So the emerging agent-payment stack is a set of **supported targets, not a
dependency**. The reference implementation funds via x402 / EIP-3009, settles on
EVM (Circle **Arc** is one target — *Best Agentic Economy*) and on Solana, and
slots behind Chainlink CRE / MCP as thin, swappable adapters. Reckn does not bet on
any one of them: if a rail wins, it is already positioned; if a rail stalls, the
verdict still reproduces anywhere. The dual-VM implementation is the proof — Solana
is not scope creep, it is the demonstration that the adjudicator outlives any single
stack.

Adopted, judge-legible pieces: **ERC-8004** reputation (implemented) · **x402 /
EIP-3009** payments (EVM escrow — a buyer agent's x402 authorization *is* the escrow
funding; see [`docs/x402-payments.md`](docs/x402-payments.md)) · **Circle Arc** as one
settlement target · Chainlink CRE / MCP as swappable orchestration.

## ETHOnline 2026 — where the boundary is

Reckn is entered in **ETHOnline 2026** (9/4–16, async) under **Continuity — Ship a
Feature**: an existing project shipping a new feature during the event. That track
lives or dies on an honest boundary between what already existed and what is built
during the event, so the boundary is stated here rather than reconstructed later.

| | |
|---|---|
| Pre-event product work ends at | `a122b44` (2026-08-02) |
| Commits dated 2026-09-03 | harness, planning and documentation only — no product feature |
| **Event work** | **commits dated 2026-09-04 or later — the date is primary, not the hash** |
| `EVENT_START` | `121194ca3e25bab4ec92aaa4da1277f3a60b8421`, recorded in [`STATUS.md`](STATUS.md) |
| Accepted | 2026-09-04, **Continuity Track** |
| Retreat checkpoint | 9/9 — tasks 008 and 009 both green, or the founder decides |
| Freeze | 9/12 |

**Every feature described in this README is pre-event work**, disclosed to
ETHGlobal in advance. Nothing here is claimed as event-day work, and nothing below
is described as finished before it is.

What the event is for, in execution order ([`AGENTS.md`](AGENTS.md) §3):

1. **008 — verdict domain soundness.** Close the false release described
   [below](#known-gaps-not-closed): the guest judges the balance delta on the low 64
   bits while the off-chain engine uses the full `U256`, so a *decrease* proves as a
   maximal credit. Also make "the same engine runs in-guest" checkable rather than
   assumed.
2. **009 — cross-VM settlement.** Settle an EVM escrow on a *Solana* proof. Today an
   SVM verdict is verified on-chain by the same generic verifier, but only EVM proofs
   reach `settleWithProof`. This is the event's headline: a payment escrowed on one
   chain, disputed over work performed on another, settled by a proof — no resolver
   on either side, and no bridge or light client in the adjudication path.
3. **003 — key gauntlet** *(stopped, not abandoned)*. Publish every party's private
   key and demonstrate with a test matrix that every theft path reverts, folding in
   the keyless timeout so a funded deal with no proof cannot lock forever. Its spec
   hit the harness's six-round review limit still holding one open hole — a
   constant-keyed branch that no check rejects — and the rules say to stop and hand it
   back rather than write a seventh round. It is out of the 9/9 checkpoint and may
   return before the freeze.
4. **004 — live adversarial input.** Open the seller's delivery claim to free-form
   text so anyone watching can try to talk the judge into approving, and watch
   re-execution refuse to be talked into anything.

**Where this stands (2026-09-05):** 008's spec is approved after six rounds and is
being implemented; 009's spec is in its second review; 003 is stopped as above; 004 is
queued. No task is finished, and none is described here as if it were.

Each task goes through a written spec with mechanically checkable acceptance
criteria and an adversarial review by a second model before any implementation. The
specs and every review verdict are committed under [`docs/specs/`](docs/specs) and
[`docs/reviews/`](docs/reviews) — including the ones that failed.

The repository is developed by an autonomous harness — `reckn-spec` (frame-thin:
closes the frame) → `reckn-codex-review` (adversarial, second model) →
`reckn-codex-impl` (frame-thick: fills the frame) → review → commit, with
`reckn-demo` owning what a judge sees first. Rules, stop conditions and the
Continuity discipline are in [`AGENTS.md`](AGENTS.md); the plan and the advance
disclosure are in [`docs/ethonline-2026/`](docs/ethonline-2026).

## Repository layout

```text
AGENTS.md                   # harness rules, day-work discipline, stop conditions
CLAUDE.md                   # orientation: the central claim, verified facts, environment
STATUS.md                   # where the event stands (EVENT_START, gates, freeze)
SUBMISSION.md               # pitch surface: submission copy, demo-video script, checklist
scripts/
  no-keys.sh                # BUILD CONDITION: no key can judge (exit 0 = claim holds)
  anvil-e2e.sh              # one-command live dispute on a throwaway local chain
docs/
  ethonline-2026/           # PLAN.md + DISCLOSURE.md (founder documents)
  specs/ reviews/ tasks/    # per-task spec → review → impl records (event work)
  protocol-architecture.md  # converged EVM-first protocol (the source of truth)
  roadmap-crossvm.md        # EVM → Solana → cross-VM extension roadmap
  x402-payments.md          # how a buyer agent's x402/EIP-3009 payment funds the escrow
  architecture-brief.md     # original frame-thick task brief (historical)
contracts/                  # EVM V1 settlement half (Foundry) — implemented
  src/RecknEscrow.sol       #   four-state escrow + timeout escape hatches
  src/ResolverRegistry.sol  #   resolver keys + exact backend/version allow-list
  src/libraries/VerdictHash.sol
  src/interfaces/IUSDC3009.sol
  test/                     #   forge tests
reexec-evm/                 # EVM re-execution backend (revm 38) — implemented
  src/lib.rs                #   deterministic CALL replay + predicate verdict
                            #   (testkit feature: valid MPT witness fixtures, cfg-gated)
  examples/moneyshot.rs     #   emits real engine output for the dashboard
reckn-evm-content/          # shared canonical EVM content codec — implemented
  src/lib.rs                #   the keeper's & binder adapter's ONE decoder (no drift)
reexec-svm/                 # Solana re-execution backend (LiteSVM) — implemented
  src/lib.rs                #   deterministic tx replay → the SAME ReplayRecordV1
escrow-svm/                 # Solana settlement half (Pinocchio) — implemented
  src/lib.rs                #   4-state escrow; Ed25519-attested resolve; timeout
  tests/e2e.rs             #   LiteSVM tx-level e2e
reckn-svm-keeper/           # Solana keeper: replay -> Ed25519-sign -> resolve
  src/lib.rs                #   + keyless verify
  tests/full_loop.rs        #   fund->challenge->keeper->resolve->verify (LiteSVM)
binder/                     # cross-VM binder — one router, both VMs (reckn-binder)
  src/lib.rs                #   route a dispute by committed backendId -> verdict
  src/adapters.rs           #   EvmBackend + SvmBackend (content-addressed replay)
  tests/router_two_vms.rs   #   one router re-executes EVM + SVM, fails closed
packages/protocol/          # canonical cross-VM codecs (specs + golden vectors)
  REPLAY_RECORD_V1.md       #   ReplayRecordV1 TLV spec (trace_hash source)
  golden/                   #   cross-language conformance vectors
packages/protocol-rs/       # reckn-record: the shared Rust record codec both
                            #   backends emit, so EVM and SVM trace hashes match
zk-verdict/                 # the keyless path — independent SP1 workspace
  program-revm/             #   guest: MPT-verify prestate, run real revm under proof
  program-svm/              #   guest: recompute bank_hash, sigverify, re-execute transfer
  contracts/src/RecknZkEscrow.sol      # settles on the proof alone — no resolver
  contracts/src/RecknVerdictVerifier.sol # one generic verifier, EVM + SVM proofs
  scripts/zk-e2e.sh         #   one command: re-execute → prove → verify → settle
dashboard/                  # LLM-judge vs replay money-shot — implemented
  index.html                #   cinematic money-shot: money moves, live keeper
                            #   console + ledger, on-chain resolve receipt
  variants/                 #   design exploration (v1–v5); v5 is promoted above
  media/reckn-moneyshot.gif #   README hero animation
  media/reckn-demo-full.mp4 #   full demo: money-shot + live anvil-e2e terminal run
  media/reckn-demo.mp4      #   dashboard-only clip; media/reckn-e2e.mp4 = terminal clip
keeper/                     # resolver keeper — replay, EIP-712 signature, live chain shell
  src/lib.rs                #   verified core: build + EIP-712-sign VerdictCommitment
  src/main.rs               #   live shell: once/watch (resolve) + verify (keyless recheck)
```

Planned (not yet in the tree): `mcp-server` and the rest of
`packages/protocol`'s production spec/delivery/anchor codecs. See the module map in
[`docs/protocol-architecture.md`](docs/protocol-architecture.md).

## Status

The whole dispute → verdict → settlement → **re-verification** slice exists, runs
live on a real node, and is tested — on **both** VMs, behind **one** router: a
funded escrow, a deterministic re-execution backend that binds its prestate to a
committed state root, the canonical verdict record, the settlement signature the
contract provably accepts, a keyless third-party re-verifier that reproduces the
on-chain verdict from public inputs, ERC-8004 reputation evidence, and a money-shot
dashboard on real engine output. The cross-VM binder now re-executes an EVM and a
Solana dispute through a single `BackendRouter`, each returning the same verdict
type. What remains is judge-legibility integrations (Arc / x402 / MCP), a
challenge/bond layer, the cross-chain settlement around routing, and production
content publication.

- **Protocol:** locked — [`docs/protocol-architecture.md`](docs/protocol-architecture.md)
  (VM-neutral verdict envelope, committed spec/delivery/anchor codecs, EVM V1
  profile, data-availability + timeout policy, and the reproducibility vs
  settlement-authority split).
- **Settlement contract (EVM V1):** implemented in [`contracts/`](contracts) —
  escrow state machine, EIP-712 resolver verdicts, resolver/backend allow-list,
  timeout escape hatches, nonzero-window guards, a cross-language digest pin
  against the keeper, an ERC-8004-style `ReputationEvidence` projection (below),
  and end-to-end tests that settle on the **real engine output** (the
  `moneyshot.json` hashes) and assert `VerdictCommitted` carries the actual
  `traceHash`. Plus an **optimistic settlement** path (`resolveOptimistic` →
  challenge window → `finalizeSettlement`): the resolver must be **bonded** in the
  registry, settlement is deferred so the reproducible verdict can be checked
  before funds move, and a second registered resolver's **conflicting** verdict
  during the window fail-safes to a buyer refund and emits `Fault`. Slashing the
  liar is **automatic**: `slashWithQuorum` lets anyone present a **K-of-N
  registered-resolver quorum** co-signing the true (conflicting) verdict — since
  the verdict is deterministic, K honest resolvers sign the same one — and slashes
  the faulty resolver's bond to the submitter as a bounty, no governance. This
  turns the keyless-*detectable* verdict into an economically-*enforced* one,
  reducing trust from a single resolver to an honest-majority quorum. Full
  zero-trust single-signer adjudication still wants a fraud-proof VM or a ZK proof
  of the re-execution. Plus an **opt-in seller data-availability bond**: the buyer
  commits a `requiredSellerBond` at funding (bound into the signed nonce, so a
  relayer can't weaken it), the seller locks it at `deliver()`, and it is forfeited
  to the buyer **only** on a dispute timeout (evidence withheld) — every other exit,
  including a `Failed` verdict on the merits, returns it. So the bond punishes
  *withholding*, not *losing*, and a throwaway seller can no longer dodge the cost
  of withholding with just a reputation mark. `forge test`: **57 passing**.
- **Reputation (ERC-8004 style):** on every verdict the escrow emits
  `ReputationEvidence(agent, reproduced, dealId, traceHash, backendId)` — a pure
  projection that never changes settlement. Unlike AgentRankr's self-reported,
  sybil-gameable feedback, the seller-agent's reputation is **earned by a
  reproducible verdict**: anyone can re-derive `traceHash`. A dispute that times
  out with no verdict *also* emits a negative signal (`reproduced = false`, **zero
  trace**), so a seller cannot dodge the mark by withholding delivery/replay
  evidence to force a timeout; the zero trace distinguishes it from a reproduced
  `Failed`. Emitted on-chain and asserted by contract tests.
- **Re-execution backend (EVM V1):** revm 38 replay implemented in
  [`reexec-evm/`](reexec-evm) — deterministic CALL replay with four predicate
  kinds: `RESULT_EQUALS`, `POSTSTATE_EQUALS`, `POSTSTATE_BOUNDED`, and
  `POSTSTATE_DELTA`. `POSTSTATE_BOUNDED` widens adjudication to a **funded
  envelope** over an inclusive `[min, max]` range (`≥ minOut`, `≤ cap`, or
  equality), a *property* of the post-state. `POSTSTATE_DELTA` closes the
  soundness gap that a property leaves open — it adjudicates `post − pre`
  (saturating), the increase the plan itself **caused**, so a no-op plan cannot
  satisfy `≥ minOut` off the prestate. That makes the flagship "this swap
  credited ≥ minOut" claim sound at the engine level rather than resting on the
  buyer's predicate design. Honest delivery → `Reproduced`; a seller's false
  success claim → `Failed` (→ refund). Offline MPT account/storage proofs bind
  the closed replay witness to `anchor.state_root`; proof failure or a missing
  witness is an operational error, not a verdict. And `state_root` itself is now
  bindable to the real block: when the anchor carries the block header,
  [`header.rs`](reexec-evm/src/header.rs) proves
  `keccak256(rlp(header)) == block_hash` and the header's `state_root` +
  environment equal the anchor's — so a forged `state_root` is impossible without
  breaking the consensus `block_hash` (the EVM analogue of the SVM `bank_hash`
  verifier), a mismatch being `OperationalError::HeaderMismatch`. This is
  **enforced in the keyless verdict path** (the keeper commits the block header;
  `recompute_verdict` verifies it) and exercised end-to-end against a real anvil
  block header in [`anvil-e2e.sh`](#try-it-one-command). Replay ignores
  tx-validity ceremony (base-fee / nonce) so honest deliveries reproduce against
  real blocks; balance for `value` is still enforced. `cargo test`: **16 passing**
  (incl. adversarial: a no-op plan cannot forge a `POSTSTATE_DELTA` credit, and a
  `state_root` cannot be forged without breaking `block_hash`).
- **Re-execution backend (Solana / SVM):** [`reexec-svm/`](reexec-svm) — the same
  mechanism on Solana via `LiteSVM`, replaying a committed **signed** transaction
  against a committed account snapshot and emitting the **identical VM-neutral
  `ReplayRecordV1`** as the EVM backend. That shared record — one Rust codec in
  [`packages/protocol-rs`](packages/protocol-rs), asserted against the same golden
  as the TS/Solidity vectors — proves the VM-neutral waist across a second VM and
  is the foundation the cross-VM binder will stand on. The **replay boundary is
  settlement-grade (V2)**: signatures verified (a forged signer → `Failed`), the
  snapshot commitment covers accounts + `rent_epoch` + Program/ProgramData +
  runtime profile, ELF derived from ProgramData not the seller, and a closed-world
  account-load trap (a small vendored LiteSVM fork) makes any unwitnessed read an
  operational error, never a phantom-default `Reproduced`. Snapshot
  **authenticity** now has a real verifier: [`reexec-svm/src/bankhash.rs`](reexec-svm/src/bankhash.rs)
  recomputes the SIMD-0215 accounts lattice hash over the account set and
  re-derives `bank_hash` (via the audited `solana-lattice-hash` crate), so with
  `snapshot_is_complete` set, a snapshot that does not reproduce the committed
  `bank_hash` is an `OperationalError::BankHashMismatch` rather than a decorative
  field. Because Solana (unlike EVM's MPT) has **no compact per-account inclusion
  proof**, the compact per-tx prestate binds *transitively*:
  [`reexec-svm/src/authenticity.rs`](reexec-svm/src/authenticity.rs)'s
  `verify_prestate_authenticity` checks the full snapshot is the committed archive,
  reproduces `bank_hash`, and that every compact account is a faithful subset of
  it — no per-account proof needed. This is **enforced in the dispute path**: the
  keeper's `load_for_disputed_deal` rejects an unauthentic prestate
  (`KeeperError::SnapshotAuthenticity`) before any replay, for both the resolver
  and the keyless verifier. The remaining piece is *ingesting* a real Agave archive
  into that full snapshot. See
  [`docs/svm-snapshot-authenticity.md`](docs/svm-snapshot-authenticity.md). The
  closed runtime still permits only the System builtin (custom SBF is
  `UnsupportedEnvironmentDependency`). The predicate set is
  symmetric with the EVM backend: `RESULT_EQUALS`, `LamportsEquals`, the bound
  `LamportsBounded` (`≥ minOut` via `max = u64::MAX`), and the causal
  `LamportsDelta` (`post − pre` credited increase) — so both the funded envelope
  and the sound "this fill credited ≥ minOut" claim adjudicate identically across
  the two VMs. `cargo test`: **30 passing** (reckn-record: 1; incl. the
  no-op-cannot-forge-a-delta adversarial regression, the `bank_hash`
  lattice-hash authenticity verifier, and the compact-prestate archive binding).
- **Settlement contract (Solana / SVM):** [`escrow-svm/`](escrow-svm) — a Pinocchio
  program mirroring the EVM escrow: the same four-state machine, a Token-2022 vault,
  and a `resolve` that verifies the resolver's verdict by strict introspection of a
  preceding native **Ed25519** instruction over a domain-separated
  `genesis‖program_id‖deal_id‖VerdictCommitment` message. An operational outcome can
  never settle — only `timeout_refund` favors the buyer — and `ReputationEvidence`
  is logged (a dispute that times out emits a seller-attributed **evidence-withheld**
  signal — `FAILED` outcome with a zero trace and zero resolver — mirroring the EVM
  escrow, so withholding replay material cannot dodge the negative mark). It also
  mirrors the EVM **optimistic settlement** faithfully: a per-resolver registry
  (PDA allow-list, the Solana analogue of `ResolverRegistry`), lamport **bonds**,
  `resolve_optimistic` (bonded, opens a challenge window in a new `SETTLING` state),
  `finalize_settlement` (permissionless, after the window), and — since Solana can
  verify a *second* resolver's Ed25519 verdict by introspection — a true
  **peer-conflict** `challenge_verdict` that fail-safes to a buyer refund + `Fault`,
  plus admin `slash`. LiteSVM tx-level e2e (instant release / refund / forged
  signature / swapped anchor / operational outcome / timeout evidence-withheld /
  double-resolve / conservation, **plus** optimistic finalize, unbonded/unregistered
  rejects, peer-conflict refund, bond deposit/slash): **10 passing** via
  `cargo build-sbf`.
- **Keeper (Solana):** [`reckn-svm-keeper/`](reckn-svm-keeper) — the SVM analog of
  the EVM keeper: SHA-256-check the content store, match it to the on-chain deal,
  replay via `reexec-svm` (an operational error is never signed), build the
  escrow's `VerdictCommitment`, and emit the exact `[ed25519(current-ix), resolve]`
  adjacency the program's introspection requires — using the escrow's own
  `verdict_message` + the canonical Ed25519 helper, i.e. byte-identical to the
  shape `escrow-svm`'s passing e2e already accepts. A keyless `verify` re-derives
  the on-chain verdict from public inputs. Settlement is **optimistic by default**
  (matching the EVM keeper): the keeper registers + bonds the resolver, submits
  `resolve_optimistic` (opening a challenge window), and `finalize_settlement`
  settles once it elapses. Proven end-to-end by a LiteSVM full-loop test: content
  SHA-256 → fund → deliver → challenge → replay → register + bond → the keeper's
  `[ed25519, resolve_optimistic]` accepted → window elapses → finalize → honest
  releases the seller / false claim refunds the buyer → keyless `verify` agrees.
- **Cross-VM binder (one router, both VMs):** [`binder/`](binder) — a `ReexecBackend`
  trait both VMs implement, an `EvmBackend` + `SvmBackend` adapter pair, and a
  `BackendRouter` that verifies the committed content hashes and routes a dispute to
  the backend named by its committed `backend_id` (fails closed on unknown/ambiguous
  — never the wrong VM), returning a `VerdictEnvelopeV1` carrying the shared
  `ReplayRecordV1`. Because the record codec is shared, an EVM verdict and a Solana
  verdict are literally one type. Every extra replay input — the EVM proof-carrying
  witness, the SVM snapshot + runtime profile — is pulled only through a
  content-addressed `BackendArtifactResolver` (SHA-256 re-verified, never live RPC);
  a missing or tampered artifact is an operational `BackendError`, never a verdict.
  **Proven by a single-router integration test** ([`tests/router_two_vms.rs`](binder/tests/router_two_vms.rs)):
  one `BackendRouter` with both adapters registered re-executes four disputes through
  one `route()` — EVM honest → `Reproduced`, EVM false → `Failed`, SVM honest →
  `Reproduced`, SVM false → `Failed`, all the same `VerdictEnvelopeV1` — while a
  mismatched `backend_id` is `UnknownBackend` and a missing/tampered artifact fails
  closed. Its EVM fixtures use the exact valid-MPT-witness builder from `reexec-evm`
  (exposed via a cfg-gated `testkit` feature so the production crate is unchanged and
  the test cannot drift onto a weaker witness). `cargo test`: **6 passing**. The
  cross-chain settlement *around* routing (finality on both chains, verdict
  propagation, double-settle rules) is the remaining frame-thick step — with a
  **self-verifying ZK verdict** as the trust-minimized verdict transport (A verifies
  the proof itself, no light client for the authority) —
  [`docs/cross-chain-settlement.md`](docs/cross-chain-settlement.md).
- **Money-shot dashboard:** [`dashboard/`](dashboard) — a self-contained,
  animated money-shot driven by real `reexec-evm` output: the escrow pot moves, a
  live `reckn-keeper` console + ledger stream the resolve, and the outcome lands on
  an on-chain `resolve()` receipt. Same dispute — the opinion judge releases escrow
  to a false claim; Reckn replays the actual plan and refunds the buyer. Open it
  locally — the data is inline, so `file://` works with no server and no setup.
- **Keeper (chain shell + settlement signature):** [`keeper/`](keeper) — maps a reproducible
  replay to the `VerdictCommitment` and EIP-712-signs it. The digest is
  cross-checked against the contract in both Rust and Foundry (a shared golden),
  so a keeper signature is provably accepted by `resolve()`. It decodes all EVM
  content through the shared [`reckn-evm-content`](reckn-evm-content) codec (no
  drift with the binder adapter). The **witness is committed, not RPC-built at
  dispute time**: the seller publishes a proof-carrying witness with
  `reckn-keeper witness … --write <store>` and the delivery commits its SHA-256
  (`witnessContentHash`); `once` / `verify` then resolve that committed witness by
  hash and MPT-verify it against `anchor.state_root` before replay — they never
  replay a live RPC witness. Its HTTP shell polls `Disputed`, SHA-256-checks
  content-store bytes before parsing, replays, and submits **`resolveOptimistic`**
  (a bonded verdict that opens a challenge window). The included anvil E2E drives
  the full optimistic path — commit verdict → window elapses → `finalizeSettlement`
  → false claim `Failed` → refund / honest credit `Reproduced` → release — each
  keylessly re-verified. `cargo test` + `forge test`: **keeper 3, contracts 57**.
- **Independent re-verification (the trust property, executable):**
  `reckn-keeper verify <rpc> <escrow> <content-store> <dealId>` — a **keyless**
  third party reads the resolver's on-chain `VerdictCommitted` and re-derives the
  verdict from public inputs alone (content store + re-execution), then asserts
  outcome / resultHash / prestateRoot / traceHash all match. This is what a TEE'd
  LLM verdict cannot offer: **don't trust the resolver — reproduce its verdict
  yourself.** The anvil E2E runs it as a final step and fails on any mismatch.
- **Economic security (optimistic settlement + quorum slashing):**
  `resolveOptimistic` bonds the resolver and opens a challenge window before funds
  move; a conflicting verdict fail-safes to a buyer refund. Slashing the liar is
  **automatic**: `slashWithQuorum` accepts a **K-of-N** registered-resolver quorum
  co-signing the true verdict — provably contradicting the faulty one — and slashes
  its bond, no governance. This reduces trust from a single resolver to an
  honest-majority quorum; zero-trust single-signer adjudication still wants a
  fraud-proof VM or a ZK proof of the re-execution. Optimistic settlement is the
  **default on both VMs** — the keeper submits `resolveOptimistic` and drives commit
  → window → `finalize`.
  Optimistic settlement is now the default on **both** VMs — the EVM keeper submits
  `resolveOptimistic` and the SVM keeper submits `resolve_optimistic` (registry +
  bond + window + peer-conflict + finalize + slash), each driven end-to-end.
- **Toward zero-trust (ZK, PoC):** [`zk-verdict/`](zk-verdict) proves reckn's
  causal delta verdict inside an **SP1 zkVM** and verifies the proof — the verdict
  *derivation* needs no trusted resolver, run end-to-end on CPU. The verdict is also
  **verifiable on-chain**: [`RecknVerdictVerifier.sol`](zk-verdict/contracts/src/RecknVerdictVerifier.sol)
  checks an SP1 proof against the program vkey and exposes the verdict, authoritative
  *because the proof verifies* — a chain-agnostic check, which is what makes a ZK
  verdict the **trustless cross-chain settlement primitive** (any paying chain
  verifies a verdict itself, no bridge or light client for the authority). Verified
  with a **real Groth16 proof** against SP1's canonical `SP1Verifier` (circuit
  v6.1.0) on-chain (`forge test`, mock + real-verifier suites green).
- **Full re-execution in the zkVM (trusted-prestate AND trusted-`post` gaps, closed):**
  a second guest ([`zk-verdict/program-revm`](zk-verdict/program-revm/src/main.rs))
  **verifies the committed prestate is authentic** (each account MPT-proven against
  the committed `state_root`, each slot against the account storage root — via
  `alloy-trie` in-guest, the same check `reexec-evm` does off-chain) and then runs
  **real `revm` inside the SP1 zkVM** to **execute the seller's CALL under proof** and
  derive the post-state. So the prestate is *proven authentic* and `post` is *computed
  by the EVM* — both in the proof, not trusted from a resolver; the trace hash binds
  the `state_root`. Verified: revm 38 + alloy-trie compile to the zkVM target; the
  SSTORE plan (slot 7 = 42 proven) executes to `post=142` → `Reproduced` (~410k
  cycles), a no-op → `Failed`, and a **tampered prestate value is rejected** (the
  guest panics on the bad MPT proof — no verdict for an inauthentic state). A **real
  Groth16 proof verifies on-chain** through the same generic verifier
  (`RecknReexecVerdict.t.sol`). Remaining on the EVM side: the disabled
  `c-kzg`/`ecrecover` precompiles and scale (a full block).
- **SVM re-execution in the zkVM (the Solana mirror):** a third guest
  ([`zk-verdict/program-svm`](zk-verdict/program-svm/src/main.rs)) closes both
  authenticity gaps like the EVM guest: it **recomputes the block `bank_hash`** from
  the committed accounts (SIMD-0215 lattice hash, `solana-lattice-hash` in-guest) and
  requires it to match the committed one, **signature-verifies the real committed
  Solana transaction** (`Transaction::verify`, real ed25519), and **re-executes its
  System transfer** against the authenticated prestate to derive the post-lamports,
  then applies the `LamportsDelta`. So the prestate is *proven authentic* and `post`
  is *computed by re-execution*, not trusted. Verified: `System::Transfer(2_000_000)`
  → `bank_hash`-bound recipient `post` executed to `2_000_001` → `Reproduced` (~980k
  cycles); below-floor → `Failed`; a **tampered signature is rejected** (verify fails
  → `Failed`) and a **tampered account is rejected** (fails the in-guest `bank_hash`
  check → guest panics). The `bank_hash` recompute is byte-identical to
  `reexec-svm::bankhash`. Its **real Groth16 proof verifies on-chain through the same
  generic verifier** (`RecknSvmVerdict.t.sol`) — one verdict contract, EVM and SVM
  proofs alike. Honest scope: reckn's SVM permits **System builtins only**, so this is
  not the full Agave/LiteSVM runtime (out of scope in-zk) nor custom SBF (reckn runs
  none); the `bank_hash` check is conclusive over a *complete* account set (the demo
  treats its set as the world, as reckn's tests do).
- **ZK settlement — the proof moves money:**
  [`RecknZkEscrow`](zk-verdict/contracts/src/RecknZkEscrow.sol) settles escrow **purely
  on a ZK-verified verdict, no resolver**: `settleWithProof` verifies the SP1 proof via
  `RecknVerdictVerifier` and, only if the proof's `dealBinding` (a commitment each guest
  makes over its authenticated prestate + predicate + plan, matched to the deal at
  funding) is correct, releases to the seller (`Reproduced`) or refunds the buyer
  (`Failed`). Tested end-to-end with a **real Groth16 proof of the EVM re-execution
  settling to the seller**; binding mismatch and unverified proof revert. The whole
  path — re-execute in-guest → prove → verify on-chain → settle — runs in one command:
  [`bash zk-verdict/scripts/zk-e2e.sh`](zk-verdict/scripts/zk-e2e.sh). `forge test`: **12
  passing**. Integrating `settleWithProof` into the main `RecknEscrow` lifecycle is the
  follow-up.
- **Next:** the EVM quorum-slashing mirror on the SVM escrow (Ed25519 quorum
  introspection + lamport bond slash); extending the re-execution guest's
  opcode/precompile coverage and scale; and cross-chain
  settlement around the binder (finality on both chains + verdict propagation +
  double-settle
  rules).

### Known gaps (not closed)

Stated here so no reader has to discover them by reading the source. None of these
is closed by anything above; the honest scope in
[`zk-verdict/README.md`](zk-verdict/README.md) governs.

- **`RecknZkEscrow` has no timeout.** If no proof ever arrives, a funded escrow
  stays funded — permanently. The optimistic `RecknEscrow` has timeout escape
  hatches; the keyless contract, which is the differentiated one, does not. Closing
  this **without introducing a key** is the first ETHOnline task
  ([`AGENTS.md`](AGENTS.md) §3, task 001); `no-keys.sh` already enumerates
  `refundAfterDeadline` as the only permitted way in.
- **In-guest precompiles run on different backends, and parity is unverified.**
  This repository has long said they are *disabled* in-guest. They are not:
  `revm-precompile` falls back to pure-Rust implementations when the native
  features are off — `k256` for `ecrecover` (`secp256k1.rs:1-8`, preference order
  `secp256k1 → k256`) and `arkworks` for KZG (`kzg_point_evaluation.rs:87-101`).
  So a plan touching `0x01` or `0x0a`–`0x11` is not unsupported; it runs against a
  *different implementation* than the off-chain engine, and the two have never been
  checked for equivalence. Corrected 2026-09-04.
- **⚠ The `u64` verdict boundary is a soundness bug, not just a limit** (found
  2026-09-04, open). The guest takes the delta on limb 0
  (`program-revm/src/main.rs:163`) while the off-chain engine takes it on the full
  `U256` (`reexec-evm/src/lib.rs:647`). With `pre = 2^64` and `post = 2^64 − 1` the
  balance *decreased*, yet the guest sees `pre = 0`, `post = u64::MAX` and proves
  `Reproduced` — **a false release**. At 18 decimals any balance above ≈18.45
  tokens crosses limb 0. Nothing is deployed and no funds are at risk, but the
  keyless path cannot be called sound until this is closed.
- **"The same engine runs in-guest" is UNVERIFIED.** The guest configures only
  `chain_id` (`program-revm/src/main.rs:122-126`), so it runs at revm's default
  spec with a zeroed block env, while `reexec-evm` pins `anchor.spec_id` (`CANCUN`
  in the current fixture) and the full environment. The two may disagree on any
  opcode whose behaviour is fork-dependent.
- **⚠ The build condition reads one file, and settlement authority leaves it**
  (found 2026-09-04; task 008 closes it). `scripts/no-keys.sh` checks
  `RecknZkEscrow.sol` only, but `settleWithProof` obeys the struct returned by
  `RecknVerdictVerifier` — a different file in the same deployment, on the same
  authority path. A constant-keyed branch there is a resolver, and it passed every
  check we had. The claim is that no key can judge; the region we were checking was
  one file.
- **⚠ `fallback()` and `receive()` are invisible to the enumeration**
  (found 2026-09-05; task 009 closes it). Neither carries the `function` keyword, so
  the state-changing surface check cannot see them. Measured: a `fallback` that
  drains any funded deal compiles and passes all four checks. Nothing exploitable
  ships today — the contract has neither — but the guarantee did not cover the shape.
- **Scale.** The guest proves one CALL plus one delta check. A full block or an
  arbitrary contract set is more cycles on the same architecture — but that is a
  claim about architecture, not a measured result.
- **`state_root` ↔ block-header binding lives off-chain**, in the
  `reexec-evm::header` layer, not inside the guest.
- **SVM scope.** The Solana guest permits System builtins only — not the full
  Agave/LiteSVM runtime, and no custom SBF.
- **Not yet submitted anywhere.** The repository is private until submission; the
  pre-flight in [`SUBMISSION.md`](SUBMISSION.md) is unchecked on exactly those two
  lines.

## Try it (one command)

Run the whole live dispute on a throwaway local chain:

```bash
bash scripts/anvil-e2e.sh
```

Prerequisites: [Foundry](https://getfoundry.sh) (`anvil`, `forge`, `cast`), Rust
(`cargo`), and `jq`. The script needs no arguments and cleans up after itself.

It spins up `anvil`, deploys the escrow / registry / a mock USDC, then has the
**seller publish a proof-verified prestate witness** to a content store
(`reckn-keeper witness … --write`, bound to the block's `state_root`) and commit
its SHA-256 into the delivery. The run has **two acts over the same frozen state**:

- **Act I (refund, exact-match):** a deal is funded on a `RESULT_EQUALS`
  predicate; the seller's `balanceOf` SLOAD plan can't satisfy it, so re-execution
  returns `Failed` and **refunds the buyer**.
- **Act II (release, causal delta):** a second deal is funded on a
  `POSTSTATE_DELTA` predicate — "the fill must **credit ≥ minOut**"
  (`post − pre` on the output-balance slot), the flagship swap slippage floor
  done *causally*. A real crediting plan (its own proof-carrying witness) raises
  the balance, so the adjudicated increase clears the floor, re-execution returns
  `Reproduced`, and the escrow **releases to the seller**. A no-op plan would
  yield delta 0 and could not be paid — which is the whole point.

In each act the keeper picks up the `Disputed` event, fetches the committed
spec / delivery / anchor / **witness** from the content store (each hash-checked
before parsing), MPT-verifies the witness against the anchor, **re-executes the
seller's plan**, signs the verdict, and submits **`resolveOptimistic`** — which
commits the verdict and opens a bonded challenge window rather than paying
instantly. With no conflicting verdict, the window elapses and anyone calls
`finalizeSettlement` to pay per the verdict. Finally, a **keyless independent
re-verifier** reads each on-chain verdict back and reproduces it from public
inputs alone — proving the resolver couldn't have lied, for both the refund and
the release.

The run **narrates each phase in plain language** (with the real addresses, hashes,
and deal id shown underneath), so it reads as a story even if you don't know the
internals:

```
▶ Setting up: an escrow and a test USDC on a fresh local chain
▶ Freezing the exact chain state the work will be judged against
▶ Seller attaches tamper-proof evidence of the state it ran against
▶ Buyer pays 1,000 USDC into escrow for the promised result
▶ Seller delivers a wrong result but claims success; buyer disputes it
▶ Reckn replays the actual work and checks it against the promise
PASS: re-execution returned Failed and refunded buyer; deal=0x…
▶ Anyone can reproduce this verdict themselves — no trust in the keeper
VERIFIED — resolver verdict reproduced from public inputs with no resolver key. …
PASS: independent re-verification reproduced the on-chain verdict.
▶ Act II: buyer funds a *causal* slippage floor — the fill must CREDIT ≥ minOut
▶ Reckn replays the work: the plan CREDITED ≥ minOut, so the seller is paid
PASS: delta predicate reproduced (credited ≥ minOut); seller released; deal=0x…
▶ Anyone can reproduce the released verdict too — same public inputs, no key
PASS: independent re-verification reproduced the RELEASE verdict.
```

That is the entire trust chain end-to-end on a real node:
`deal.prestateAnchorHash → checked anchor → block_hash → RLP-verified header →
state_root → MPT-proven witness → closed-world replay → verdict → settlement`.
The `block_hash → header → state_root` link binds the committed state root to the
real block: the keeper commits the anvil block header, and the keyless verdict path
proves `keccak256(rlp(header)) == block_hash` before trusting `state_root`.

### …or the fully trustless path (ZK), also one command

```bash
bash zk-verdict/scripts/zk-e2e.sh
```

Same dispute, taken all the way to **zero trusted parties**: the disputed work is
**re-executed inside a zkVM** — real `revm` (EVM) / the real Solana transfer (SVM),
each against a **cryptographically authenticated prestate** (MPT vs `state_root` /
`bank_hash` lattice; a tampered prestate is rejected) — a **real Groth16 proof** of
that execution is **verified on-chain** by one generic verifier, and
[`RecknZkEscrow`](zk-verdict/contracts/src/RecknZkEscrow.sol) **settles the escrow on
the proof alone** (`Reproduced` → seller, `Failed` → buyer). No resolver, no signer
allow-list. The on-chain half runs on committed real proofs with just `forge`; the
live in-guest half runs if the [SP1](https://docs.succinct.xyz) toolchain is present.

## Build & test

Each component is self-contained; there is no top-level build.

```bash
# settlement contracts (Foundry) — 57 tests (verified EIP-3009 funding + opt-in seller DA bond + end-to-end on real engine output)
cd contracts && forge install foundry-rs/forge-std --no-git && forge test

# re-execution engine (revm 38, MPT-verified prestate + header binding) — 16 tests
cd reexec-evm && cargo test

# keeper signature + content-store guard — 3 tests
cd keeper && cargo test

# cross-VM binder: one router re-executes EVM + SVM, fails closed — 6 tests
cd binder && cargo test

# ZK re-execution, one command: re-execute both VMs in the zkVM (tampered prestate
# rejected), verify the REAL Groth16 proofs on-chain, and SETTLE the escrow to the
# seller on the proof alone — no resolver (RecknZkEscrow) — 12 tests
bash zk-verdict/scripts/zk-e2e.sh
# or piecemeal:
cd zk-verdict/contracts && forge test                                    # verify + settle
cd zk-verdict/script && cargo run --release --bin reexec -- --execute    # EVM in-guest
cd zk-verdict/script && cargo run --release --bin svm -- --execute        # SVM in-guest

# one-command local chain demo: Act I false claim → Failed → refund;
# Act II causal delta predicate (credited ≥ minOut) → Reproduced → seller release
cd .. && bash scripts/anvil-e2e.sh

# regenerate the dashboard's data from the real engine
cd reexec-evm && cargo run --example moneyshot > ../dashboard/moneyshot.json

# view the money-shot (data is inline, so file:// works)
open dashboard/index.html
```

The contract↔keeper EIP-712 digest is pinned by a shared golden
([`packages/protocol/golden/verdict-eip712-v1.json`](packages/protocol/golden/verdict-eip712-v1.json)):
`forge test --match-contract VerdictDigestTest` and the keeper's
`eip712_digest_matches_golden` must agree, or a keeper signature would be rejected
by `resolve()`.

## Collaboration model

Two models, split by **how thick the frame is** rather than by seniority: Claude
Code closes the frame (spec, invariants, acceptance criteria, non-goals) and Codex
fills it and attacks it. The relay is no longer human — Claude Code drives Codex
directly through the agents in [`.claude/agents/`](.claude/agents), and the one
rule that keeps the review honest is **author independence**: the model that wrote
a change never reviews it, and when Codex is asked for a second opinion the payload
says who wrote the artifact.

The original frame-thick convergence is complete — its result is
[`docs/protocol-architecture.md`](docs/protocol-architecture.md).
[`docs/architecture-brief.md`](docs/architecture-brief.md) is the original task
brief, kept for history.

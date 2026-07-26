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

- on-chain action delegation ("executed this swap at ≤X slippage")
- computation with a spec (re-run, check output matches)
- provenance-bearing data / oracle claims (reproduce the claimed source state)

The crux: **at escrow-funding time the deal is bound to a re-executable predicate
(`spec`)**, which makes the dispute *decidable*. Subjective deliverables fall
back to a conventional judge — out of scope here, but the adjudicator boundary is
cut so such a judge is just another pluggable backend.

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

## The one design invariant

The adjudicator lives behind a **VM-neutral boundary**:

```
ReexecBackend.verdict(specHash, prestateAnchor)
  -> { verdict: Reproduced | Failed, traceHash, prestateRoot }
```

- **EVM backend** (this repo, first) — revm/reth fork replay
- **Solana backend** (later) — LiteSVM / SBF replay
- **cross-VM binder** (third act) — routes a dispute to the right VM backend

The verdict envelope is VM-agnostic; only the engine underneath differs. See
[`docs/roadmap-crossvm.md`](docs/roadmap-crossvm.md).

## Target

Circle **Arc — Best Agentic Economy** track. Adopted stack for judge-legibility:
ERC-8004 identity/reputation · x402/EIP-3009 payments · Chainlink CRE (or keeper)
orchestration · MCP control plane · Circle Arc settlement.

## Status

Scaffold. Architecture convergence in [`docs/architecture-brief.md`](docs/architecture-brief.md).

## Collaboration model

CC (frame-thin: scoped modules, scaffolding, exploration) × Codex (frame-thick:
whole-system convergence, the VM-neutral boundary, review). See the architecture
brief for the current frame-thick task.

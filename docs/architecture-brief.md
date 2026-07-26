# Reckn — architecture convergence brief (frame-thick / Codex)

> Self-contained. No external conversation context required.

## What we're building

Reckn = an escrow for agent-to-agent (x402-style) payments where the dispute
**adjudicator is deterministic re-execution**, not a TEE'd LLM judge. Source of
the pattern: ETHGlobal NY 2026 *Clawback* (ENS prize) — "chargebacks for the
machine economy." Every winner in that lane gates payment on a *trusted*
adjudicator (LLM judge / self-reported feedback / unaudited loop). Reckn swaps
that single node for re-execution = the "correct version." Tagline:
**"Reproduce, or refund."**

## Scope constraint (important)

Re-execution cannot judge subjective quality. Target only the class where the
deliverable is machine-verifiable: on-chain action delegation, spec'd
computation, provenance-bearing data claims. Crux: at escrow-funding time, bind
the deal to a re-executable predicate (`spec`) so the dispute is *decidable*.
Subjective deliverables fall back to a conventional judge — out of scope, but cut
the adjudicator boundary so such a judge could be a pluggable backend later.

## State machine (Clawback-derived)

```
Held --(seller: deliverable + claimed result)--> Delivered
  entering Held: buyer deposits via EIP-3009, deal bound to specHash
Delivered --(buyer challenges)--> Disputed        (emits Disputed event)
Disputed --(adjudicator verdict)--> Resolved --> release(seller) | refund(buyer)
```

## What to converge (your deliverables)

1. **VM-neutral adjudication boundary (most important).** Put the adjudicator
   behind a `ReexecBackend` interface:
   ```
   verdict(specHash, prestateAnchor)
     -> { verdict: Reproduced | Failed, traceHash, prestateRoot }
   ```
   - EVM backend (implement now, revm/reth fork replay) is backend #1.
   - Future: Solana backend (LiteSVM/SBF replay), cross-VM binder — must load as
     *additional backends*, not rewrites.
   - Nail the interface types, invariants, and the verifiability contract:
     "anyone re-running against the same prestate reaches the same verdict."

2. **`spec` (predicate) type.** What gets bound at escrow time. Minimal encoding
   of the predicate + `prestateAnchor` (block / state root). Predicate forms:
   post-state invariant holds / claimed-result equality.

3. **On-chain verdict commitment.** Include traceHash + prestateRoot so a third
   party can reach the same verdict by independent re-execution.

4. **Wiring.** Disputed -> verdict -> Resolved. Chainlink CRE is the intended
   orchestrator, but if it's too heavy for hackathon time, a plain keeper is an
   acceptable substitute (add CRE for narrative later). Make the call.

5. **Legibility stack** (for judging): ERC-8004 identity/reputation +
   x402/EIP-3009 payments + Circle Arc settlement + MCP control plane. Target
   prize: Circle Arc "Best Agentic Economy."

## Expected outputs

- Repo layout (module boundaries) under `psyto/reckn`.
- `ReexecBackend` interface + verdict envelope types (pseudocode OK).
- Minimal `spec` predicate type.
- Implementation order with **surface/demo first** (per house style): 4-state
  contract -> re-exec verifier -> wiring -> split-screen dashboard
  (LLM judge vs re-execution) as the **scored artifact**.
- Checklist of "boundaries to cut now" so Solana / cross-VM are later backend
  additions, not rewrites.

## Non-goals

Subjective-quality adjudication · full cross-VM implementation (EVM single-chain
now) · token issuance.

## Reuse note

`psyto/buzz-verify` already implements the "verdict = signature bound to a
re-execution" philosophy (there: `git apply` + test-suite replay, in Node). Reckn
generalizes the verdict shape; the EVM re-exec engine is new (state-level replay,
not patch-level).

## Collaboration

CC = frame-thin (scoped modules: escrow skeleton, buzz-verify->EVM adapter, spec
predicate examples, dashboard wire). Codex = frame-thick (this convergence).
Cross-pass review after each side ships.

# Reckn — submission kit

Paste-source for the ETHGlobal / Arc submission form, a 60–90s demo-video script,
and a pre-flight checklist. Keep this in sync with `README.md`; the README is the
canonical technical doc, this is the pitch surface.

---

## One-liner

**Reckn** — an escrow for agent-to-agent payments where a disputed delivery is
adjudicated by **deterministic re-execution**, not a trusted judge. *Reproduce, or
refund.*

## Elevator pitch (≈60 words)

Agent-economy escrows keep winning hackathons by gating payment on a **trusted
adjudicator** — a TEE'd LLM, self-reported feedback, or an unaudited loop. Reckn
replaces that with re-execution: on a dispute it pins the pre-state, **replays the
disputed work**, and checks the predicate the deal was funded against. The verdict
commits a trace hash anyone can independently reproduce — no resolver key required.
The trust root is **chain- and rail-agnostic** — proven on both EVM and Solana
behind one router — so it outlives any single payment stack.

## The problem

The winning pattern in agent payments (e.g. ETHGlobal NY 2026 *Clawback* —
"chargebacks for the machine economy") settles disputes with a trusted judge:

| Project | Adjudicator | Trust root |
|---|---|---|
| Clawback | Confidential LLM Attester (TEE) | *an LLM's opinion* — a TEE proves it ran, not that it's right |
| AgentRankr | feedback events | *self-reported, sybil-gameable* |
| Sidekick | per-block loop | *unaudited venue internals* |
| **Reckn** | **re-execution** | *deterministic replay anyone can reproduce* |

Every one of those trust roots is unreproducible. If you disagree with the verdict,
you cannot check it.

## What Reckn does

At funding, the deal is bound to a **re-executable predicate** (`spec`) against a
committed pre-state (`prestateAnchor`) — which makes the dispute *decidable*. On
`challenge`, a keeper pins that pre-state, replays the seller's actual plan, and
evaluates the predicate. The escrow releases on `Reproduced`, refunds on `Failed`.

The differentiator is **checkability**: the verdict commits the canonical
re-execution trace hash and pre-state root on-chain, so a **keyless third party
reproduces the verdict from public inputs alone**. Don't trust the resolver —
reproduce its verdict yourself. A TEE'd LLM verdict cannot offer this.

## How it works (the trust chain, end-to-end on a real node)

```
deal.prestateAnchorHash → checked anchor → state_root
   → MPT-proven committed witness → closed-world replay → verdict → settlement
   → keyless re-verification (reproduce the verdict with no resolver key)
```

- **Funded by the payment itself.** A buyer agent's **x402 / EIP-3009** authorization
  is consumed *as* the escrow funding: one signed authorization both pays and opens
  the disputable escrow, binding the deal to the re-executable predicate (no deposit
  step). See [`docs/x402-payments.md`](docs/x402-payments.md).
- **Committed inputs, no live RPC in the verdict path.** Spec/delivery/anchor are
  content-addressed; the seller publishes a proof-carrying witness whose SHA-256 the
  delivery commits. Replay resolves it by hash and MPT-verifies it against the
  anchor's `state_root`. A missing/tampered input is an operational error, never a
  verdict.
- **Reproducibility ≠ settlement authority.** The signature that moves money binds
  to a re-execution; the trace hash lets anyone reproduce that verdict independently.

## What's built (honest status)

A complete dual-VM dispute → verdict → settlement → **re-verification** slice, run
live and tested — on **both** VMs, behind **one** router.

| Layer | EVM | Solana (SVM) |
|---|---|---|
| Settlement contract | `contracts/` (Solidity) — 23 tests | `escrow-svm/` (Pinocchio) — 4 LiteSVM e2e |
| Re-execution backend | `reexec-evm/` (revm 38, offline MPT) — 5 tests | `reexec-svm/` (LiteSVM V2, closed-world) — 13 tests |
| Keeper + keyless verify | `keeper/` (EIP-712) — 2 tests + `anvil-e2e.sh` | `reckn-svm-keeper/` (Ed25519) — full-loop |
| Shared verdict record | `packages/protocol-rs` (`ReplayRecordV1`) — one type both VMs emit | ← same |
| Cross-VM binder | `binder/` — **one `BackendRouter` re-executes both VMs**, 6 tests (incl. `router_two_vms.rs`) | ← same |

- **ERC-8004 reputation:** every verdict emits `ReputationEvidence` (reproducible,
  not self-reported); a dispute timeout emits a seller-attributed *evidence-withheld*
  signal, so withholding replay material cannot dodge the negative mark. Both VMs.
- **Deliberate cuts, surfaced not hidden:** Solana snapshot *authenticity*
  (checkpoint `bank_hash` → snapshot verifier) is external and unbuilt — the SVM
  slice runs at the reproducibility tier. Cross-chain settlement is designed
  fail-closed (`docs/cross-chain-settlement.md`) but not yet implemented.

## Positioning & sponsor targets

Lead with the thesis, not a stack: **Reckn is the trustless adjudicator for any
agent-payment rail.** The trust root (re-execution) is chain- and rail-agnostic —
demonstrated on both EVM and Solana behind one router — so the agent-payment stack
is a set of **supported targets, not a dependency**. If a rail wins, Reckn is
positioned; if it stalls, the verdict still reproduces anywhere.

- **Sponsor targets (supported, not bet on):** Circle **Arc — Best Agentic Economy**
  (one settlement target) · **x402 / EIP-3009** payments (EVM escrow;
  [`docs/x402-payments.md`](docs/x402-payments.md)) · **ERC-8004**
  reputation (implemented) · Chainlink CRE / MCP as swappable orchestration.
- **The dual-VM build is the proof of agnosticism** — Solana is not scope creep, it
  shows the adjudicator outlives any single stack. Frame it as *one engine, any
  chain, any rail.*

## Demo links

- **▶ Live money-shot (clickable):** https://claude.ai/code/artifact/88a370e4-bfeb-480c-af14-015661e6e6f7
  — the same dispute, judged by an opinion LLM vs deterministic re-execution. Toggle
  *Honest delivery* / *False claim* and watch them disagree.
- **Demo video (full, 35s, self-explanatory — no audio needed):**
  [`dashboard/media/reckn-demo-full.mp4`](dashboard/media/reckn-demo-full.mp4) — title
  cards frame it: hook (a trusted judge you can't check) → money-shot judged two ways
  (false → refund, honest → release) → **live `anvil-e2e.sh` terminal run** (pin anchor
  → publish witness → re-execute → refund → keyless re-verify) → close (*one engine,
  any chain, any rail*). Recorded headless via Puppeteer/Chromium + a real Foundry run.
  Component clips: `reckn-demo.mp4` (dashboard), `reckn-e2e.mp4` (terminal).
- **One-command local proof:** `bash scripts/anvil-e2e.sh` — funds a deal, delivers
  a false plan, disputes it, and the keeper's re-execution refunds the buyer, then a
  keyless re-verifier reproduces the on-chain verdict. The run **narrates each phase
  in plain language** (real addresses/hashes shown underneath), so a judge can follow
  it without knowing the internals.
- **Repo:** https://github.com/psyto/reckn

---

## Demo video script (target 75s)

> Record the artifact (already animated) + a terminal running `anvil-e2e.sh`.
> Screen only, tight VO. The hero is the *disagreement*, then the *keyless recheck*.

1. **(0–10s) The hook.** *"Agent payments settle disputes with a trusted judge — an
   LLM in a black box. If you disagree with its verdict, you can't check it."* Show
   the Clawback/AgentRankr/Sidekick trust-root table.
2. **(10–30s) The disagreement.** Open the money-shot artifact. *"Same dispute. The
   opinion judge reads the seller's persuasive claim and approves — releases the
   escrow."* Toggle to **False claim**: *"Reckn ignores the claim and replays the
   actual plan. The real output doesn't satisfy what the buyer funded. Failed —
   refund the buyer."* Let the pot snap back to the buyer.
3. **(30–55s) It's real, not a mock.** Cut to the terminal. Run `anvil-e2e.sh`.
   *"This is live on a chain: fund, deliver, dispute. The keeper pins the committed
   pre-state, MPT-verifies the witness, re-executes, and refunds."* Land on
   `PASS: re-execution returned Failed and refunded buyer`.
4. **(55–70s) The kicker — checkability.** *"Now the part a TEE can't do."* Show the
   keyless verify lines: `VERIFIED — resolver verdict reproduced from public inputs
   with no resolver key.` *"Don't trust the resolver. Reproduce its verdict
   yourself."*
5. **(70–75s) The close.** *"One re-execution engine, one verdict type, EVM and
   Solana behind one router. Reckn — reproduce, or refund."*

---

## Pre-flight checklist

- [ ] **README hero** renders on GitHub (GIF + clickable artifact link) — verified.
- [ ] **Artifact shared:** open the money-shot artifact → Share → make link-viewable
      (only the owner can do this from claude.ai; the link is private until then).
- [ ] **Repo public:** flip `psyto/reckn` from private to public
      (`gh repo edit psyto/reckn --visibility public`). One-way-ish — do at submission.
- [x] **Demo video** — full cut at `dashboard/media/reckn-demo-full.mp4` (money-shot +
      live `anvil-e2e.sh` terminal), Puppeteer/Chromium. Optional upgrade: add VO per
      the script above, then upload and link in the form.
- [ ] **Submission form**: one-liner, elevator pitch, how-it-works, track (Arc — Best
      Agentic Economy), sponsor tech (ERC-8004, x402/EIP-3009, Arc), repo + artifact
      + video links.
- [ ] **`bash scripts/anvil-e2e.sh` green** on a clean clone (Foundry + Rust + jq).
- [ ] Test tally current in README (contracts 23, reexec-evm 5, reexec-svm 13,
      binder 6, keeper 2, escrow-svm 4, evm-content 3, record 1).

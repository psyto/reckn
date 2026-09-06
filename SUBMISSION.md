# Reckn — submission kit

Paste-source for the ETHGlobal / Arc submission form, a 60–90s demo-video script,
and a pre-flight checklist. Keep this in sync with `README.md`; the README is the
canonical technical doc, this is the pitch surface.

> **Status (updated 2026-09-05).** This kit was written for an earlier ETHGlobal /
> Arc form. The live entry is **ETHOnline 2026, Continuity Track** — applied and
> **accepted on 2026-09-04**, RSVP and stake complete. The repository was made
> **public on 2026-09-04** so the application could be reviewed against the source,
> so the pre-flight's *Repo public* item is done; *Submission form* is not, and
> submissions are not yet open.
>
> The plan and the advance disclosure are founder documents in
> `docs/ethonline-2026/`; the disclosure's §3 lists what is being built during the
> event, and `AGENTS.md` §4 governs what may be claimed as event work.
>
> **Copy below describes pre-event capability only.** The event's own work — the
> soundness fix and cross-VM settlement — is not in it. Before submitting, re-check
> every number against a run rather than pasting a figure this file inherited; the
> counts were last re-measured on 2026-09-04 and are recorded in
> `_applications/2026-09-04-ethonline-application.md`.

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

The predicate can be an exact match (`RESULT_EQUALS` / `POSTSTATE_EQUALS`), a
**bound** (`POSTSTATE_BOUNDED` / SVM `LamportsBounded`, a post-state *property*
over `[min, max]`), or a causal **delta** (`POSTSTATE_DELTA` / `LamportsDelta`).
The flagship "swap at ≤X slippage" claim is causal, so it funds as a delta:
"the fill credited ≥ minOut" = `post − pre ≥ minOut` on the output-balance slot.
This is the soundness point — a plain bound ("balance ≥ minOut") is satisfiable
by a no-op plan off the prestate, whereas the delta adjudicates the increase the
plan itself caused, so a seller cannot be paid without moving the balance. Both
are symmetric across the two VMs. Act II of `anvil-e2e.sh` demonstrates the delta
end-to-end: a real crediting fill clears the floor, reproduces, and is **released
to the seller** (a no-op would yield delta 0 and refund).

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
  step). The signature is **really verified** (EIP-712, the way USDC's FiatTokenV2
  does), and a **third-party facilitator relays it** — the buyer never sends the
  funding tx. The authorization's nonce is bound to the exact deal, so relaying is
  tamper-evident: no facilitator can redirect the payment or alter a term.
  `scripts/anvil-e2e.sh` funds this way (buyer signs, a separate account relays).
  See [`docs/x402-payments.md`](docs/x402-payments.md).
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
| Settlement contract | `contracts/` (Solidity) — 57 tests (verified EIP-3009 funding + opt-in seller DA bond) | `escrow-svm/` (Pinocchio, optimistic settlement) — 10 LiteSVM e2e |
| Re-execution backend | `reexec-evm/` (revm 38, offline MPT + header binding) — 16 tests | `reexec-svm/` (LiteSVM V2, closed-world, `bank_hash` verifier + archive binding) — 30 tests |
| Keeper + keyless verify | `keeper/` (EIP-712) — 3 tests + `anvil-e2e.sh` | `reckn-svm-keeper/` (Ed25519) — full-loop |
| Shared verdict record | `packages/protocol-rs` (`ReplayRecordV1`) — one type both VMs emit | ← same |
| Cross-VM binder | `binder/` — **one `BackendRouter` re-executes both VMs**, 6 tests (incl. `router_two_vms.rs`) | ← same |

- **ERC-8004 reputation:** every verdict emits `ReputationEvidence` (reproducible,
  not self-reported); a dispute timeout emits a seller-attributed *evidence-withheld*
  signal, so withholding replay material cannot dodge the negative mark. Both VMs.
- **Seller data-availability bond (EVM, opt-in):** a reputation mark alone costs a
  throwaway (Sybil) seller nothing, so the buyer may commit a `requiredSellerBond`
  the seller locks at `deliver()`. It is forfeited to the buyer **only** on a dispute
  timeout (evidence withheld) and returned on every other exit — including a `Failed`
  verdict on the merits — so it punishes *withholding*, not *losing*. The SVM lamport
  mirror is the follow-up.
- **A capability the cross-VM work added, stated as a cost:** because the **buyer**
  names the adjudicating program at funding, a buyer can name one that always returns
  `Failed` — the seller then works for nothing, and on-chain that is indistinguishable
  from an honest `Failed`. A buyer who names a sham that always *approves* has defrauded
  only themselves. The seller's protection is to read the deal's `verifier`,
  `verifierCodeHash` and `dealBinding` before working; nothing checks them on the
  seller's behalf.
- **Deliberate cuts, surfaced not hidden:** Solana snapshot *authenticity* now has
  a real verifier — `reexec-svm/src/bankhash.rs` recomputes the SIMD-0215 accounts
  lattice hash and re-derives `bank_hash`, and `reexec-svm/src/authenticity.rs`
  binds the *compact* per-tx prestate to that verified full snapshot as a subset
  (Solana has no compact per-account proof, so this is transitive, not a Merkle
  path), and the keeper *enforces* it in the dispute path
  (`KeeperError::SnapshotAuthenticity` before any verdict). What remains is
  *ingesting* a real Agave snapshot archive into the full snapshot — ingestion, not
  soundness (`docs/svm-snapshot-authenticity.md`). Cross-chain settlement is
  designed fail-closed (`docs/cross-chain-settlement.md`) but not yet implemented —
  though its hardest piece, **trust-minimized verdict transport**, now has a concrete
  primitive: a **self-verifying ZK verdict** (`zk-verdict/`) whose SP1 proof is
  **verified on-chain** by `RecknVerdictVerifier.sol`, so a paying chain checks a
  verdict itself with no bridge or light client for the authority (verified with a
  **real Groth16 proof** against SP1's real `SP1Verifier`, circuit v6.1.0).
- **Full re-execution in the zkVM (trusted-prestate AND trusted-`post` gaps closed):**
  a second guest (`zk-verdict/program-revm`) **MPT-verifies the committed prestate
  against the `state_root`** (via `alloy-trie` in-guest, the same check `reexec-evm`
  does off-chain) and then runs **real revm inside the SP1 zkVM** to execute the
  seller's committed CALL under proof and *derive* the post-state. So the prestate is
  proven authentic and `post` is computed by the EVM — both in the proof, not trusted.
  The SSTORE crediting plan proves to `Reproduced` (406,715 cycles), a no-op to `Failed`,
  a **tampered prestate is rejected** (bad MPT proof → no verdict), and a real Groth16
  proof verifies on-chain through the same generic verifier.
- **SVM re-execution in the zkVM (the Solana mirror):** a third guest
  (`zk-verdict/program-svm`) **signature-verifies the real committed Solana transaction
  in-guest** (`Transaction::verify`, real ed25519 — the Solana data crates compile to
  the zkVM target) and **re-executes its System transfer** to derive the post-lamports,
  then applies `LamportsDelta`. `System::Transfer(2M)` → `Reproduced` (986,097 cycles); a
  **tampered signature is rejected** → `Failed`; the real Groth16 proof verifies
  on-chain through the **same generic verifier** — one verdict contract, EVM and SVM
  proofs alike. reckn permits System builtins only, so this is not the full Agave/LiteSVM
  runtime (out of scope in-zk) nor custom SBF. It also **recomputes the block
  `bank_hash`** from the committed accounts in-guest (SIMD-0215 lattice hash, byte-identical
  to `reexec-svm::bankhash`) and rejects a tampered account set — so, like the EVM guest,
  both the trusted-prestate and trusted-`post` gaps are closed.
- **ZK settlement — the proof moves money:** `RecknZkEscrow.settleWithProof` releases
  escrow to the seller (`Reproduced`) or refunds the buyer (`Failed`) **purely on a
  ZK-verified verdict, with no resolver**. Soundness: each guest commits a `dealBinding`
  (a hash over its authenticated prestate + predicate + plan) that the deal commits at
  funding, so a proof can only settle the deal it was about. Tested end-to-end with a
  **real Groth16 proof** of the EVM re-execution settling to the seller; binding
  mismatch and unverified proof both revert.
- **A USDC payment on Arc, released by a proof about work on Solana (new,
  2026-09-06):** the strongest single sentence this repository can say, and it is a
  test — `test_ARC07_usdc_on_arc_settled_by_a_proof_about_work_on_solana`. The deal
  names the Solana guest's verifier at funding; `settleWithProof` calls it, checks the
  proof carries that deal's binding, and pays 250.00 USDC. **No bridge, no light
  client, no resolver**, and the escrow never learns which virtual machine the work
  happened on. "Settled by a Solana proof" still means "settled by a proof about a
  Solana-shaped state the deal named" — the `bank_hash`'s provenance is not
  established here or anywhere else.
- **A funded deal can no longer lock forever (new, 2026-09-06):** the keyless escrow
  had no timeout, so a deal whose prover never showed up — or whose recipient a
  stablecoin froze — stayed funded permanently. `refundAfterDeadline` returns it to
  the buyer after thirty days: **permissionless**, pays the caller nothing, cannot be
  called early or twice or after a proof settled the deal, and in either order the
  money comes out exactly once. The waiting period is a constant of the protocol —
  a deadline someone picks is a parameter someone controls — and the function was
  already in the enumerated surface, so the central claim did not widen to make room.
- **One escrow, two virtual machines (new, 2026-09-06):** the same contract settles an
  **EVM proof and a Solana proof**, each with its real committed Groth16 proof, in one
  test. The adjudicating program is named by the **funder**, per deal, and pinned by its
  codehash; `settleWithProof` has **no parameter** with which a settler could name one;
  the dispatch is `view`-typed, so it is a `STATICCALL` and funder-chosen code cannot
  write state. The escrow has **no constructor and no `immutable`** — every deployment
  of that source is the same contract. **No bridge and no light client are on the
  adjudication path**, which is a claim about adjudication and *not* about anchoring.
- **The verdict is sound over the whole 256-bit domain (new, 2026-09-05):** the guest
  used to take the balance delta on limb 0 while the off-chain engine took it on the
  full `U256`, so `pre = 2^64` / `post = 2^64 − 1` — a **decrease** — proved as the
  largest possible credit and released to the seller. On a real Groth16 proof, that
  exact cell now refunds the buyer.

## Positioning & sponsor targets

Lead with the thesis, not a stack: **Reckn is the trustless adjudicator for any
agent-payment rail.** The trust root (re-execution) is chain- and rail-agnostic —
demonstrated on both EVM and Solana behind one router — so the agent-payment stack
is a set of **supported targets, not a dependency**. If a rail wins, Reckn is
positioned; if it stalls, the verdict still reproduces anywhere.

- **Sponsor integration — Arc, and only Arc** (founder ruling, 2026-09-06; the prize
  list published that day confirms an Arc track at $10,000, with two prizes open to
  Continuity entries: *Best DeFi or Agentic Application* and *Launch on Arc Testnet &
  Push to Mainnet*). **Hedera is out of scope** — no x402 service, no Blocky402, no
  consuming agent, no Hedera deployment.
  **What makes Arc load-bearing rather than a deployment target:** USDC is Arc's
  native gas token and Circle exposes an ERC-20 face over the same balance at
  `0x3600…0000`, so an escrow there holds the chain's own money and the delta
  predicate is a predicate over cents. Reckn's escrow already names its payment token
  per deal, so **settling USDC on Arc needed no contract change at all**; what it
  needed was evidence the settlement is correct in USDC's units and semantics — six
  decimals, revert-not-false, and a blacklist that can freeze a payout.
  Details, architecture diagram and limits: [`docs/arc-usdc.md`](docs/arc-usdc.md).
  **Nothing is deployed to Arc yet** (a funded testnet key is the founder's to hold),
  and Circle has not published Arc mainnet addresses, so *deployment-ready* is the
  only honest posture for the Sept 30 requirement.
- **Other sponsor surfaces (present, not pursued this event):** **x402 / EIP-3009**
  payments (EVM escrow; [`docs/x402-payments.md`](docs/x402-payments.md)) ·
  **ERC-8004** reputation (implemented) · Chainlink CRE / MCP as swappable
  orchestration.
- **The dual-VM build is the proof of agnosticism** — Solana is not scope creep, it
  shows the adjudicator outlives any single stack. Frame it as *one engine, any
  chain, any rail.*

## Demo links

> ⚠ **The two claude.ai artifact links this section used to carry are not public**
> (verified 2026-09-05 in a logged-out browser). They were owner-only, so a judge
> following them saw nothing. Everything below is in the public repository instead.
> If those dashboards are ever shared publicly, add them back here — a live page beats
> a file every time — but never ship a link nobody can open.

- **▶ Money-shot (in-repo, zero setup):** [`dashboard/index.html`](dashboard/index.html)
  — the same dispute, judged by an opinion LLM vs deterministic re-execution. The
  engine output is inlined, so `file://` works with no server. Toggle
  *Honest delivery* / *False claim* and watch them disagree.
- **▶ Demo video (35s, title cards, no audio needed):**
  [`dashboard/media/reckn-demo-full.mp4`](dashboard/media/reckn-demo-full.mp4)
- **▶ ZK money-shot (in-repo):** [`dashboard/variants/`](dashboard/variants)
  — the trustless path, visualized: a disputed payment **re-executed inside a zkVM →
  proven → verified on-chain → settled on the proof alone**, on EVM or Solana (real
  fixture data). Flip *tamper prestate* and the pipeline is rejected — no proof, no
  settlement. Runs for real via `bash zk-verdict/scripts/zk-e2e.sh`.
- **Demo video (full, 35s, self-explanatory — no audio needed):**
  [`dashboard/media/reckn-demo-full.mp4`](dashboard/media/reckn-demo-full.mp4) — title
  cards frame it: hook (a trusted judge you can't check) → money-shot judged two ways
  (false → refund, honest → release) → **live `anvil-e2e.sh` terminal run** (pin anchor
  → publish witness → re-execute → refund → keyless re-verify) → close (*one engine,
  any chain, any rail*). Recorded headless via Puppeteer/Chromium + a real Foundry run.
  Component clips: `reckn-demo.mp4` (dashboard), `reckn-e2e.mp4` (terminal).
- **One-command local proof:** `bash scripts/anvil-e2e.sh` — two acts over one
  frozen state. Act I funds a deal, delivers a false plan, disputes it, and the
  keeper's re-execution **refunds the buyer** (exact-match predicate). Act II funds a
  **causal delta predicate** ("the fill credited ≥ minOut", the swap slippage floor);
  a real crediting plan reproduces and is **released to the seller** — a no-op could
  not, which is the soundness point. Settlement is **optimistic**: the keeper
  submits `resolveOptimistic` (bonded verdict + challenge window), and once the
  window elapses with no conflicting verdict, `finalizeSettlement` pays. A keyless
  re-verifier reproduces both on-chain verdicts from public inputs. The run
  **narrates each phase in plain language** (real addresses/hashes shown
  underneath), so a judge can follow it without knowing the internals.
- **One-command trustless proof (ZK):** `bash zk-verdict/scripts/zk-e2e.sh` — the same
  dispute taken to **zero trusted parties**. It re-executes both VMs **inside a zkVM**
  (real `revm` / the real Solana transfer) against a **cryptographically authenticated
  prestate** (MPT vs `state_root` / `bank_hash` lattice; a tampered prestate is
  rejected on screen), verifies a **real Groth16 proof on-chain** through one generic
  verifier, and **settles the escrow to the seller on the proof alone** — no resolver.
  The on-chain half runs on committed real proofs with just `forge`.
- **Repo:** https://github.com/psyto/reckn

---

## Demo video — the re-cut (2026-09-06). Shoot this, not the old one.

**Why re-cut.** The 35s cut in the repo was made before the event and contains none of
the event's work: not the false-release fix, not cross-VM settlement, not the Arc USDC
flow, not the timeout. Both Arc prizes require a video; this is the one to record.

**Format:** ~100 s, screen capture, no audio needed — title cards carry it. Two
sources only: `dashboard/index.html` (the story) and `http://127.0.0.1:8787` (the live
demo, `bash scripts/arc-demo.sh`). Never cut to a terminal except for the last card.

| # | seconds | on screen | title card |
|---|---|---|---|
| 1 | 0–12 | `index.html`, **False claim** selected, replay running: the opinion judge approves, re-execution refunds | *An agent paid another agent. They disagree. Who decides?* |
| 2 | 12–20 | same page, the two verdicts side by side | *One reads the claim. The other replays the work.* |
| 3 | 20–28 | scroll to **Now check it yourself**, then cut to the live page loading | *Don't take our word for it.* |
| 4 | 28–42 | click **fund 250.00** → escrow tile goes to 250.00 USDC; click **settle with the proof** → seller tile 250.00 | *A conditional USDC payment. The condition is a proof.* |
| 5 | 42–58 | **click "submit another execution's proof"** — hold on the red line `reverted: BindingMismatch() ← the money did not move`, escrow still 250.00 | *A real proof. Of the wrong execution. The money does not move.* |
| 6 | 58–70 | click **settle with the failing proof** → buyer refunded | *And when the work did not reproduce, the buyer is made whole.* |
| 7 | 70–84 | click **fund** then **settle with the Solana proof** → seller tile moves | *USDC on Arc. Released by a proof about work performed on **Solana**. No bridge. No light client.* |
| 8 | 84–94 | click **refund now** → `TooEarly()`; click **wait 30 days**; click **refund** → buyer made whole | *And if nobody ever proves anything, the money still comes home.* |
| 9 | 94–100 | cut to a terminal: `bash scripts/no-keys.sh`, ending on `✓ the claim holds` | *There is no key that can move a funded escrow. It is a build condition, not a promise.* |

**Three things not to do.** Do not describe the local chain as Arc testnet — it is a
local anvil at Arc's chain id and the page says so on screen, so leave that banner
visible. Do not cut the `BindingMismatch()` beat short; it is the only moment in the
video where a theft is attempted and fails, and it is worth four seconds of silence.
Do not add a claim the repository does not make: "no bridge, no light client" is about
the adjudication path, not about anchoring.

## Demo video script (VO upgrade — the silent cut already exists)

> The 35s carded cut (`dashboard/media/reckn-demo-full.mp4`) already realizes this
> arc and needs no audio. Use the script below only if you want to record a voiced
> version: screen only, tight VO, the hero is the *disagreement* then the *keyless
> recheck*.

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
- [x] ~~**Artifacts shared**~~ — **dropped 2026-09-05.** The two artifact links were
      **owner-only**: nobody but the author could open them, and they were the first two
      lines of a public README. They are removed. What a judge follows instead is in the
      repository: `dashboard/index.html` (engine output inlined, so `file://` works),
      `dashboard/media/reckn-demo-full.mp4`, and the two one-command scripts.
- [x] ~~**Repo public**~~ — done **2026-09-04**, ahead of submission, so the application
      could be reviewed against the actual source.
- [x] **Demo video** — full cut at `dashboard/media/reckn-demo-full.mp4` (money-shot +
      live `anvil-e2e.sh` terminal), Puppeteer/Chromium. Optional upgrade: add VO per
      the script above, then upload and link in the form.
- [ ] **Submission form** (ETHOnline 2026, Continuity — open, in progress): name,
      category, short description, description, how-it's-made, repo. **Two things that
      are easy to get wrong:** the demo field must be the repository URL, not an
      artifact link; and `docs/ethonline-2026/DISCLOSURE.md` must be **reproduced in
      full inside the description field** — there is no separate place to file it, and
      the rules require it.
- [ ] **`bash scripts/anvil-e2e.sh` green** on a clean clone (Foundry + Rust + jq).
- [x] **ZK demo green on a clean checkout** — `contracts` (57) and `zk-verdict/contracts`
      (12, incl. the real proof settling to the seller) both pass from a fresh worktree
      with only the auto-installed deps + committed proofs. `bash zk-verdict/scripts/zk-e2e.sh`
      runs the full path (SP1 toolchain optional for the live half).
- [ ] Test tally current in README (contracts 57, zk-verdict 12, reexec-evm 16,
      reexec-svm 30, binder 6, keeper 3, escrow-svm 10, evm-content 5, record 1).

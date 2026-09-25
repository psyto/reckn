# Demo script — Reckn, ETHGlobal Tokyo 2026

**Form requirements**: 2–4 minutes, ≥720p, **audio with no music**.
**Live judging**: 2026-09-27 **14:30 JST**, in person, panel — a different medium, scripted in §3.

**Why this document is rewritten rather than reused.** ETHOnline 2026 Round 1 was not lost on the
claim. This repository's own post-mortem says the video was *"a verification checklist"* optimised
for **a judge who already cared**, and that in a one-pass filter what decides is whether
*"why you should care"* lands in the first minute. **So the first minute is the deliverable here,
and everything else is downstream of it.**

---

## ★ r2 — what changed on 2026-09-25, and why

**This is pre-event work and is permitted as such**: `013` §7-6 puts *"rewrite the opening 60
seconds — script only"* on the pre-work list. Nothing in `013` §4 is built here. The commit is
dated before the 21:00 boundary, and the `EVENT_START` hash recorded at 21:00 sits after it.

| change | why |
|---|---|
| **§2 rewritten — Uniswap now appears TWICE** | r1 showed the v4 gate and **never said that the job being proven is itself a Uniswap swap**. Both Uniswap Foundation tracks are being applied for, and a script that names the protocol once, as a gate, reads as a bolt-on. It is two roles, and saying so is the strongest thing we have for that prize |
| **§2 beat 6 added — settlement and reconciliation** | the founder's own material, and the best answer this project has to *"why should anyone care"*. It goes **after** the mechanism, never before it (see the rejected framing below) |
| **the spoken lines were shortened and de-jargoned** | they are said out loud, to a panel that may not share our vocabulary. "Report card" survives a noisy room; "ERC-8004 reputation entry" does not |
| **§3 gained two questions** | *"why does Uniswap appear twice?"* and *"why should anyone outside crypto care?"* |
| **§4 gained the liquidity line as a spoken beat** | it was a bullet we intended to be found rather than said. Now it is in the take |
| **★ later on 09-25 — §1 beat 1 got an owner** | asked whether the three-day schedule actually serves this script, the answer was no: **the opening twenty seconds had no build task anywhere.** Now `013` §4-16, on Sepolia, with the self-write question settled by reading (`013` §7-7) before the window opens |
| **★ later on 09-25 — §5 gained the rushes rule** | the schedule had **one** recording block, at 23:00 on the second night, 26 hours in and after 3.5 hours of sleep. One failure there and the submission has no video at all |

### ★ A framing that was considered and rejected on 2026-09-25 — kept so it does not come back

A draft opened on **cross-chain settlement**: agents transact across chains, bridges are
inefficient and risky, and Reckn complements them by proving each transaction by re-execution.
**It is rejected, on four grounds, and none of them is taste:**

1. **`CLAUDE.md` forbids the underlying claim.** *"「Solana の proof で決済」は anchoring の主張
   ではない"* — the guest recomputes `bank_hash` from a committed account set and never shows it
   was the real cluster's. ***no bridge / no light client* is a statement about the adjudication
   path**, not about moving value.
2. **No value crosses a chain in Reckn.** 009 lets a payment **on one chain** be decided by work
   **done on another**. The money is on the EVM side from beginning to end.
3. **Chain abstraction is not implemented.** No routing, no unified balance. *"The agent does not
   have to think about chains"* has no code under it.
4. **It is not this submission.** Tokyo is `013`: the ENS record surface and the v4 hook. The
   form's short description already says so, and a pitch that disagrees with the form is the
   exact failure ETHOnline's post-mortem names — two documents a judge reads, disagreeing.

**And one more, which is the real reason.** Everything else in this project is measured.
*"Bridges are inefficient and risky"* would be **the only unmeasured assertion in the pitch**,
and it would be the first thing the judge hears.

**If cross-VM has to be said at all**, the one honest sentence is: *"resolving a dispute needs no
bridge and no light client — a payment on one chain can be decided by a proof of work done on
another."* It is **pre-existing work from ETHOnline** and must be labelled as such. It is a
panel answer (§3), never the spine.

---

## 1. The first 60 seconds

**Rule for this minute: do not explain the architecture. Show the hole, then close it.**

### 0:00–0:20 — the problem, performed, not described

Screen: an agent's entry in the ERC-8004 registries — **on Sepolia, and labelled as such on
screen** (`013` §4-16).

> "This is an AI agent's report card, on chain. **The standard went live on Ethereum mainnet in
> January.** **Watch me give myself a perfect score.**"

Write a glowing record for our own agent. It succeeds.

> "Nothing stopped me. I am the agent, and I am the one writing my own record."

**This is the whole pitch and it takes twenty seconds.** No slide, no diagram, no "in today's
agent economy".

> **★ 2026-09-25 — this beat had no owner until today, and it is the most important shot in the
> submission.** `013` §4 listed fifteen things to build and **none of them was this one**; the
> repository's own "ERC-8004" is an *8004-style* projection inside `RecknEscrow` (`:452`), not the
> standard's registries. It is now **§4-16**. Two things have to hold:
> **(a)** the deployment is **Sepolia**, said out loud and on screen — `AGENTS.md` §8 forbids a
> mainnet deployment and §4 below forbids the claim; the sentence that stays true is *"the
> standard went to mainnet in January"*, which is about the standard, not about us.
> **(b) the reference implementation has to actually permit the self-write.** If it gates that,
> **this opening does not exist.** `013` §7-7 settles it by reading the source **on 09-25** —
> before the window opens, and not at 23:00 on the 26th with the camera running.

### 0:20–0:40 — the sentence, and the refusal

> "So we made a record you cannot write yourself. Same agent. Same call."

Screen: the write reverts — `EACUnauthorizedAccountRoles`.

> "That is ENSv2's access control. This agent does not hold the role."

### 0:40–1:00 — where the right comes from

> "So who does? An escrow. It releases the agent's fee only when the work is **re-run and
> reproduces the same result**. Nobody can decide otherwise — **there is no key that could**.
> And the same settlement that pays the agent gives the buyer the right to write **one** record.
> Once."

Screen: settlement → grant → the buyer writes → revoke.

> "Deliver, and a record appears that you could not have written."

**By 1:00 a viewer who stops knows what this is and why it is not obvious.** Everything after this
is evidence.

---

## 2. The rest of the video (1:00 → ~3:00)

### Beat 4 · 1:00–1:30 — Uniswap, first appearance: **the job that was proven**

Screen: the settlement transaction on Sepolia, with `proof generated earlier — 497 s` on screen.

> "The job we asked for is **a real Uniswap swap**. We re-execute the whole thing and check that
> it lands on the same result. **A program checks it, not a person.**
> The payment has one trigger, and that trigger is the proof. Anyone can pull it. There is no
> owner."

**Why this beat exists at all**: r1 went straight from the escrow to the gate, so a judge watching
it had no idea the protocol was on both sides of the mechanism.

### Beat 5 · 1:30–2:15 — Uniswap, second appearance: **the record is the pass**

The bridge sentence, said once, plainly:

> "**Earning happens on v3. Spending happens on v4.** Doing the work and using what the work
> earned you are different acts, so we put them in different places."

| screen | the one line |
|---|---|
| a v4 pool refuses the agent's swap | **"No settled record, no swap."** |
| the record is written; the same swap executes; balances move | **"Same swap. The record is the pass."** |
| the record is cleared; the same swap is refused again | **"Clear it and the pool closes again — so it is the record doing the gating."** |

**The third row is not optional.** Without it the gate could be passing for an unrelated reason
(`013` R-16), and a judge who suspects that and is not answered will assume the worst.

### Beat 6 · 2:15–2:35 — why this matters, said after the mechanism and not before

> "Banks settle at the end of the day, so the next morning somebody has to **reconcile**.
> On chain, each transaction settles on its own — **so there is nothing to reconcile.**
> But there is also **nothing to undo**. Every single transaction has to be right the first time.
> **We put that decision on re-execution instead of on somebody with permission.**"

**Placement is the whole point.** As an opening it is five paragraphs of macro context before
anything happens on screen — the shape that lost Round 1. Here, after the viewer has watched a
refusal and a pass, it is the sentence that makes the mechanism matter outside this room.

### Beat 7 · 2:35–2:50 — the limits, said out loud

> "We are not claiming this is unforgeable — **an agent can hire itself**. We are not claiming
> there is no way around the proof — **the buyer names the verifier**. And the gate is on
> **trading**, not on providing liquidity."

Full list in §4. **These are said in the take, not left in the README to be found.**

### Beat 8 · 2:50–3:00

The repository, the live demo link, and the pre-existing-work disclosure.

### Beat 4's other problem — the 497-second question

**A Groth16 proof takes 497 seconds. It cannot be generated inside a three-minute video.**
The proof is generated **before recording**, during the event, and the video shows the
**settlement transaction** consuming it.

**Say so on screen**: *"proof generated earlier — 497 s"*. Do not cut away and imply it was
instant.

### Beat 5 — the numbers must be the run's own

The token figures come from the recorded run, not from `FINDINGS.md`. The measured pair on a fork
of Sepolia was **1.000000000000000000 in → 0.987158034397061298 out** — a real swap through a
funded pool, fee plus slippage, not a no-op. **When the event's deployment is running, re-measure
and use that.** If the demo pool's numbers differ from the ones in the submission text, **the
submission text is what changes** (`SUBMISSION-FORM.md` §9).

---

## 3. Live judging, 09-27 14:30 — a different medium

A panel can interrupt, so the script is a **spine plus prepared answers**, not a recitation.

**Spine (90 seconds)**: the same first minute as §1, then "here is the pool refusing, here it is
passing, here it is refusing again", then stop and let them ask.

### The questions that will come, and the honest answers

| question | answer |
|---|---|
| **"Who is using this?"** | **"Nobody yet. Reckn has no external users, and I am not going to pretend otherwise."** Then the real answer: what was built here is a mechanism, and the measurement behind it is the evidence I have. **Do not bluff traction.** This is the project's known weak spot and inventing users is worse than having none |
| **★ "Why does Uniswap appear twice?"** | **"Two different roles."** Once as **the work being verified** — a real v3 `SwapRouter02` swap, re-executed inside the guest. Once as **the place the record is spent** — a v4 `beforeSwap` hook. Earning and spending are different acts. And the Universal Router is deliberately **not** on the proving path: Permit2 signs with `ecrecover`, which is on the guest's divergent-precompile list with equivalence unverified |
| **★ "Why should anyone outside crypto care?"** | Beat 6, in one breath: end-of-day settlement buys you netting and costs you reconciliation; per-transaction settlement removes reconciliation and costs you the ability to undo. **The check has to be right the first time — so who performs it is the whole question.** Our answer is that nobody performs it; it is re-executed |
| "Can't the agent just make a second address and pay itself?" | **"Yes, and we say so in the docs."** A settlement can be self-dealt; identity is not something we solve. What is closed is narrower: **a record cannot exist without a settlement** |
| "Isn't the parent registry your key?" | **"While root roles are held, yes."** They are renounced after setup, and that is a tested criterion — because until it happens, the power can be handed over silently |
| "Why not put the Universal Router on the proving path?" | Permit2's signature step uses `ecrecover`, which is on the guest's divergent-precompile list with equivalence unverified. **We are not claiming soundness we have not established** |
| "Is this just ERC-8004 with extra steps?" | 8004 stores the record. It does not decide **who may write it**. That is the whole contribution |
| "What did you build during the event?" | The disclosure answers it commit by commit: the ENS record surface, the v4 hook, and the join. The escrow and the guests are older and are disclosed as such |
| **"Is this cross-chain?"** | **"Not in the sense you mean."** No value crosses a chain. What 009 shows is that **a payment on one chain can be decided by a proof of work done on another, with no bridge and no light client on the adjudication path** — and that is **pre-existing work from ETHOnline**, not this weekend's |

---

## 4. What we do not say

- **Not "unforgeable".** A settlement can be self-dealt (§3).
- **Not "no path skips proof verification".** The funder names the verifier; a sham verifier gives
  a sham settlement and a sham record. `CLAUDE.md` forbids this sentence and it is still forbidden.
- **Not "ENS hides it".** Records are public. ENSv2 enforces **who may write**.
- **Not "the gate protects liquidity".** `beforeAddLiquidity` is unflagged — **the gate is on
  trading**. Now said in beat 7, rather than left for a judge to find.
- **Not a word against Uniswap or ENS.** One is the workload and the venue; the other is the
  permission system, used as designed.
- **No claim that anything ran on mainnet.** Sepolia, and the 09-08 mainnet measurement is
  pre-existing and labelled.
- **No bridge claim, no chain-abstraction claim, and no "bridges are risky" claim.** See the
  rejected framing above.

## 5. Before recording — the checklist that kills a demo

1. **Every number on screen is from the take being recorded.** A rig that keeps rendering after
   the thing behind it broke is the failure mode to fear; assert the load-bearing lines and refuse
   to record if one is missing.
2. **No music.** The form requires audio without it.
3. **Record after the deployments exist**, not against a fork. A fork-only video contradicts the
   ENS tracks' "functional, not hard-coded".
4. **The first twenty seconds must work with the sound off.** The refusal has to be legible as a
   red line on screen, not only as narration.
5. **Do not run `ZK_FRESH=1` to make the recording's proof** unless you then restore
   `reexec-groth16-fixture.json` — it overwrites a fixture crafted with `pre = 2⁶⁴` and silently
   removes what AC10 checks (`PREFLIGHT` §5.2).
6. **Trust the test output, not `zk-e2e.sh`'s exit code**, until §4-14 lands (`PREFLIGHT` §5.1).
7. **New screenshots.** `dashboard/media/*` are Arc/ETHOnline assets and must not be reused.
8. **★ Both Uniswap appearances are in the take.** A cut that keeps the gate and loses the
   re-executed swap turns the Uniswap prize submission into a claim the video does not support.
9. **★ Shoot each beat the moment it stands — do not save the camera for the end.** Beats 1–3
   are standing when night 1 closes; beat 5 when the funded pool runs; beat 4 while the 497-second
   proof is generating. **Take rushes then**, ten minutes each. The 23:00 block on the 26th is
   then the **real take and the edit**, against footage that already exists, rather than the only
   attempt — which is what it was until this rule was written. **One rehearsal out loud, un-recorded,
   before the real take.** The rig in item 1 is what makes a rush honest: if a load-bearing line is
   missing, it refuses, and nothing gets filmed that the code does not support.

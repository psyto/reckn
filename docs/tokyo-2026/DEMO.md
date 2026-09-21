# Demo script — Reckn, ETHGlobal Tokyo 2026

**Form requirements**: 2–4 minutes, ≥720p, **audio with no music**.
**Live judging**: 2026-09-27 **14:30 JST**, in person, panel — a different medium, scripted in §3.

**Why this document is rewritten rather than reused.** ETHOnline 2026 Round 1 was not lost on the
claim. This repository's own post-mortem says the video was *"a verification checklist"* optimised
for **a judge who already cared**, and that in a one-pass filter what decides is whether
*"why you should care"* lands in the first minute. **So the first minute is the deliverable here,
and everything else is downstream of it.**

---

## 1. The first 60 seconds

**Rule for this minute: do not explain the architecture. Show the hole, then close it.**

### 0:00–0:20 — the problem, performed, not described

Screen: an agent's ERC-8004 reputation entry.

> "This is an AI agent's on-chain reputation. It went to Ethereum mainnet in January.
> **Watch me give myself a perfect one.**"

Write a glowing record for our own agent. It succeeds.

> "Nothing stopped me. I am the agent, and I am the source of my own history."

**This is the whole pitch and it takes twenty seconds.** No slide, no diagram, no "in today's
agent economy".

### 0:20–0:40 — the sentence, and the refusal

> "So we made the record something you cannot write. Same agent. Same call."

Screen: the write reverts — `EACUnauthorizedAccountRoles`.

> "That is ENSv2's access control, and the agent does not hold the role."

### 0:40–1:00 — where the right comes from

> "It is held by an escrow. The escrow releases an agent's fee only when the work is
> **re-executed and reproduced** — there is no key that can decide otherwise. And the same
> settlement that pays the agent is what opens a one-record window, for the buyer, once."

Screen: settlement → grant → the buyer writes → revoke.

> "Deliver, and a record appears that you could not have written."

**By 1:00 a viewer who stops knows what this is and why it is not obvious.** Everything after this
is evidence.

---

## 2. The rest of the video (1:00 → ~3:00)

| # | time | screen | the one line |
|---|---|---|---|
| 2 | 1:00–1:30 | the proof settles the deal on Sepolia | **"The verdict is a proof. `settleWithProof` is permissionless and the escrow has no owner."** |
| 3 | 1:30–2:00 | a v4 pool refuses the agent's swap | **"And now the record is spent. No settled record, no swap."** |
| 4 | 2:00–2:30 | the record is written; the same swap executes, balances move | **"Same swap. The record is the pass."** |
| 5 | 2:30–2:50 | the limits, said out loud | **"What we do not claim."** (§4) |
| 6 | 2:50–3:00 | the repo, the live demo, the disclosure | — |

### Beat 2 — the 497-second problem

**A Groth16 proof takes 497 seconds. It cannot be generated inside a three-minute video.**
The proof is generated **before recording**, during the event, and the video shows the
**settlement transaction** consuming it.

**Say so on screen**: *"proof generated earlier — 497s"*. Do not cut away and imply it was instant.

### Beat 4 — the numbers must be the run's own

The token figures come from the recorded run, not from `FINDINGS.md`. **If the demo pool's
numbers differ from the ones in the submission text, the submission text is what changes.**

---

## 3. Live judging, 09-27 14:30 — a different medium

A panel can interrupt, so the script is a **spine plus prepared answers**, not a recitation.

**Spine (90 seconds)**: the same first minute as §1, then "here is the pool refusing, here it is
passing", then stop and let them ask.

### The questions that will come, and the honest answers

| question | answer |
|---|---|
| **"Who is using this?"** | **"Nobody yet. Reckn has no external users, and I am not going to pretend otherwise."** Then the real answer: what was built here is a mechanism, and the measurement behind it is the evidence I have. **Do not bluff traction.** This is the project's known weak spot and inventing users is worse than having none |
| "Can't the agent just make a second address and pay itself?" | **"Yes, and we say so in the docs."** A settlement can be self-dealt; identity is not something we solve. What is closed is narrower: **a record cannot exist without a settlement** |
| "Isn't the parent registry your key?" | **"While root roles are held, yes."** They are renounced after setup, and that is a tested criterion — because until it happens, the power can be handed over silently |
| "Why not put the Universal Router on the proving path?" | Permit2's signature step uses `ecrecover`, which is on the guest's divergent-precompile list with equivalence unverified. **We are not claiming soundness we have not established** |
| "Is this just ERC-8004 with extra steps?" | 8004 stores the record. It does not decide **who may write it**. That is the whole contribution |
| "What did you build during the event?" | The disclosure answers it commit by commit: the ENS record surface, the v4 hook, and the join. The escrow and the guests are older and are disclosed as such |

---

## 4. What we do not say

- **Not "unforgeable".** A settlement can be self-dealt (§3).
- **Not "no path skips proof verification".** The funder names the verifier; a sham verifier gives
  a sham settlement and a sham record. `CLAUDE.md` forbids this sentence and it is still forbidden.
- **Not "ENS hides it".** Records are public. ENSv2 enforces **who may write**.
- **Not "the gate protects liquidity".** `beforeAddLiquidity` is unflagged — **the gate is on
  trading**. Say it before a judge finds it.
- **Not a word against Uniswap or ENS.** One is the workload and the venue; the other is the
  permission system, used as designed.
- **No claim that anything ran on mainnet.** Sepolia, and the 09-08 mainnet measurement is
  pre-existing and labelled.

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

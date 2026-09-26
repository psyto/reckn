# Demo script — Reckn, ETHGlobal Tokyo 2026

**Form requirements**: 2–4 minutes, ≥720p, **a human voice with no music**. The video is
optional; everything below assumes we make one, because the showcase runs on it.
**Live judging**: 2026-09-27 **09:30-12:30 JST at the 5F partner booths**, in person — a different
medium, scripted in §3. **Not 14:30; see §3.**

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
| **★ later on 09-25 — §1 beat 1 got an owner, then got rewritten** | asked whether the three-day schedule actually serves this script, the answer was no: **the opening twenty seconds had no build task anywhere.** It became `013` §4-16 — and then `013` §7-7 read the source and found the shot **did not work**: the official registry refuses a self-write. **Two shots now, and the second one is the real hole.** The reading cost twenty minutes and would have cost the opening at 23:00 on the 26th |
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

### 0:00–0:25 — the problem, performed, not described. **Two shots, not one.**

Screen: the **official** ERC-8004 `ReputationRegistry`, **on Sepolia**
(`0x8004B663056A597Dffe9eCcC1965A193B7388713`), labelled as Sepolia on screen.

> "This is an AI agent's report card, on chain. The standard went live on Ethereum mainnet in
> January. **Watch me give myself a perfect score.**"

**Shot A** — call `giveFeedback` from the agent's own address. **It reverts:
`Self-feedback not allowed`.**

> "The standard thought of this. The deployed contract stops it."

**Shot B** — call it again from a second address the same agent controls. **It succeeds. Perfect
score.**

> "That check asks whether I am the owner. **I used a different address.**
> **It never asked whether any work was done.**"

**This is the whole pitch and it takes twenty-five seconds.** No slide, no diagram, no "in today's
agent economy".

> **★ 2026-09-25 — rewritten from one shot to two, because the one shot did not work.**
> This beat had no owner at all until today (`013` §4 listed fifteen things to build and none of
> them was the opening shot), and the first version of §4-16 assumed the naive self-write would
> succeed. **`013` §7-7 read the source before the window opened and found it would not.**
>
> | | |
> |---|---|
> | **EIP-8004** `erc-8004.md:217` | *"The feedback submitter **MUST NOT be the agent owner or an approved operator** for agentId."* |
> | **the reference implementation** (ChaosChain, `src/ReputationRegistry.sol`) | enforces **two of that paragraph's three sentences** and not this one — **no owner comparison anywhere in 509 lines.** The Jan 2026 update deliberately removed `feedbackAuth` and signature checks: *"anyone can submit"* |
> | **the official contracts** (`erc-8004/erc-8004-contracts`, `ReputationRegistryUpgradeable.sol:108`) | **enforce it**: `require(!isAuthorizedOrOwner(msg.sender, agentId), "Self-feedback not allowed")` — deployed on 30+ chains, mainnet `0x8004BAa1…`, Sepolia `0x8004B663…` (bytecode present, verified 09-25) |
>
> **We use the official one, and we show its check working first.** Deploying the reference
> implementation instead would make the shot work by **picking the implementation without the
> check** — at an event where the standard's authors are from the EF and MetaMask, that would be
> noticed, and noticing it would be fair.
>
> **Not verified**: that the Sepolia proxy's implementation is byte-for-byte that source (the
> revert string on the day settles it), and what the official `IdentityRegistry` requires at
> registration.

### 0:25–0:42 — the sentence, and the refusal

> "**So we stopped asking who you are, and started asking whether a settlement happened.**
> Here is the record we built. Same agent. Same call."

Screen: the write reverts — `EACUnauthorizedAccountRoles`.

> "That is ENSv2's access control. This agent does not hold the role — **and a second address
> does not get it either, because the role comes from a settlement, not from who is asking.**"

### 0:42–1:00 — where the right comes from

> "So who does? An escrow. It releases the agent's fee only when the work is **re-run and
> reproduces the same result**. Nobody can decide otherwise — **there is no key that could**.
> And the same settlement that pays the agent gives the buyer the right to write **one** record.
> Once."

Screen: settlement → grant → the buyer writes → revoke.

> "Deliver, and a record appears that you could not have written."

**By 1:00 a viewer who stops knows what this is and why it is not obvious.** Everything after this
is evidence.

---

## 2. The rest of the video (1:00 → ~3:20)

### Beat 4 · 1:00–1:30 — Uniswap, first appearance: **the job that was proven**

Screen: the settlement transaction on Sepolia, with `proof generated earlier — [event duration]` on screen.

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

### Beat 5b · 2:15–2:35 — ★ and then we threw the key away

**New on 09-26, and it is the strongest twenty seconds in the video.** Beat 5 ends with the gate
shutting. This is the gate staying open when nobody holds a key to it.

> "Everything you have just seen ran while I still held root on that resolver — and root
> overrides all of it. So we did it once more, on a second pool. Settled it. The buyer wrote the
> record. The buyer closed its own window. **And then we destroyed both root roles.** That
> cannot be undone.
> This is an address that was never granted anything, trading in that pool **afterwards**."

Screen: the three refusals read back from chain — buyer, stranger, **the agent itself** — then
`beat5b-04-stranger-swaps`, where `0xF81dFf68…` swaps and two ERC-20 transfers move.

Close it on the line, said once and slowly:

> **"It is not that the right cannot be revoked. It is that the record a spent right wrote
> outlives the right — and outlives us."**

**Why here and not at the end.** Beat 5 proves the record gates the pool; a viewer's next thought
is *"and you can write that record whenever you like."* Until 16:30 on 09-26 that was **true**,
and the demo page said so in red. Answering it in the next breath, with a transaction rather
than a promise, is worth more than answering it in the Q&A.

**Do not claim the pool is trustless because the right is gone** — the buyer's right ended, and
the agent's root ended, but the hook still gates on a record whose *contents* nobody enforced.
That is beat 7's sentence and it stays there.

### Beat 6 · 2:35–2:55 — why this matters, said after the mechanism and not before

> "Banks settle at the end of the day, so the next morning somebody has to **reconcile**.
> On chain, each transaction settles on its own — **so there is nothing to reconcile.**
> But there is also **nothing to undo**. Every single transaction has to be right the first time.
> **We put that decision on re-execution instead of on somebody with permission.**"

**Placement is the whole point.** As an opening it is five paragraphs of macro context before
anything happens on screen — the shape that lost Round 1. Here, after the viewer has watched a
refusal and a pass, it is the sentence that makes the mechanism matter outside this room.

### Beat 7 · 2:55–3:10 — the limits, said out loud

> "We are not claiming this is unforgeable — **an agent can hire itself**. We are not claiming
> there is no way around the proof — **the buyer names the verifier**. And the gate is on
> **trading**, not on providing liquidity."

Full list in §4. **These are said in the take, not left in the README to be found.**

### Beat 8 · 3:10–3:20

The repository, the live demo link, and the pre-existing-work disclosure.

### Beat 4's other problem — the proof-duration question

**The pre-event measurement was 497.40 seconds, so a proof cannot be generated inside a
three-minute video.** The proof is generated **before recording**, during the event, and the
video shows the **settlement transaction** consuming it.

**★ 2026-09-26: the number to say is 416.56 seconds.** A fresh proof was generated during the
event (10:15–10:22 JST, CPU, 15,972,262 constraints) and **that is the proof the settlement
consumed** — `0x60ff6e9e…` on Sepolia, 250 USDC to the agent. The condition this paragraph set is
therefore met, and the take says **416.56 s**, not 497.40.

**Say the recorded run's actual duration on screen**: *"proof generated earlier — 416.56 s"*. Do
not cut away and imply it was instant, and do not carry the 497.40-second pre-event figure into
the take: it is a different run of a different set of terms.

### Beat 5 — the numbers must be the run's own

The token figures come from the recorded run, not from `FINDINGS.md`. The measured pair on a fork
of Sepolia was **1.000000000000000000 in → 0.987158034397061298 out** — a real swap through a
funded pool, fee plus slippage, not a no-op. **When the event's deployment is running, re-measure
and use that.** If the demo pool's numbers differ from the ones in the submission text, **the
submission text is what changes** (`SUBMISSION-FORM.md` §9).

---

## 3. Live judging, 09-27 **09:30-12:30** — a different medium

**★ CORRECTED 2026-09-26 from the official agenda.** The old figure here was **14:30**,
sourced from `013` G-Q3 as *"founder's calendar, not a file"* — the one scheduling claim the
repository marked as unverifiable. The published agenda has no 14:30 in it:

| Sun 09-27 | |
|---|---|
| 08:00 | breakfast, 5F catering |
| **09:00** | **PROJECT SUBMISSIONS DUE** |
| **09:30-12:30** | **Partner Prize Judging — 5F Partner Booths.** ENS and Uniswap Foundation are here. **This is Reckn's live lane** |
| 09:30-12:30 | Main Finalist Judging — 4F Judging Rooms |
| 12:30 | lunch |
| 15:15 | finalists notified |
| 15:30-17:30 | closing ceremonies, 4F Main Stage |

**Judging starts 09:30, not 14:30, and it is at the partner booths.** Being at the venue by
09:15 is the binding constraint of the whole Sunday, and it is five hours earlier than planned.


**★ The slot is 7 minutes: 4 for the demo, then 3 for Q&A** (ETHGlobal's own description). A
panel can interrupt, so the script is a **spine plus prepared answers**, not a recitation — but a
90-second spine would hand back two and a half minutes of the demo slot, so it is longer than the
video's.

**Spine (~3 minutes, leaving a minute of slack)**

1. **0:00–0:40** the same opening as §1 — the official ERC-8004 registry refusing the agent's
   own feedback, and the second address being accepted. *"The standard did its job, and the
   problem just moved."*
2. **0:40–1:20** where the right comes from: an escrow that settles on a re-execution proof,
   with no resolver and no owner, and the same settlement granting **the buyer** one ENS record.
3. **1:20–2:00** the record is a pass: the pool refusing, the record being written, the same
   swap executing with the tokens moving, the record cleared, refused again.
4. **2:00–2:20** ★ *"and then we threw the key away."* Both root roles destroyed, the three
   refusals read from chain, and a second pool — settled, closed, and traded afterwards by an
   address that was never granted anything. **This is the one to lead with if they interrupt
   early**: it is the shortest path from "nice mechanism" to "and nobody is holding it up."
5. **2:20–2:45** what is **not** closed, said before they ask — the bytes are not proof-derived,
   the hook cannot identify the swapper, and this is Sepolia.
6. **2:45–3:00** stop early on purpose. *"The receipts are all in the repo and the page reads
   them off the chain live — ask me anything."*

**The three questions ETHGlobal says every panel asks**, answered short:

| | |
|---|---|
| **What inspired it?** | Every reputation system for agents ends up asking the agent, or asking someone with a key. I wanted to know what is left if you refuse both. What is left is: **did the work reproduce?** |
| **What tools, and why?** | SP1 because the adjudication has to be re-execution, not opinion. **ENSv2's permissioned resolver because it grants against the setter's calldata** — that is what makes "one record, then the right is gone" expressible at all. Uniswap v4 because a `beforeSwap` hook can read the record synchronously, inside the swap, with no CCIP-Read. |
| **What did you solve, and how?** | Three, and each is in a commit: `close` was a griefing weapon until a guard was added; an ENSv2 role turned out to be scoped to the key and never to the name, so the name went **inside** the key; and the hook existed only on a fork, which would have made it the one part of the submission with no receipt. |

### The questions that will come, and the honest answers

| question | answer |
|---|---|
| **"Who is using this?"** | **"Nobody yet. Reckn has no external users, and I am not going to pretend otherwise."** Then the real answer: what was built here is a mechanism, and the measurement behind it is the evidence I have. **Do not bluff traction.** This is the project's known weak spot and inventing users is worse than having none |
| **★ "Why does Uniswap appear twice?"** | **"Two different roles."** Once as **the work being verified** — a real v3 `SwapRouter02` swap, re-executed inside the guest. Once as **the place the record is spent** — a v4 `beforeSwap` hook. Earning and spending are different acts. And the Universal Router is deliberately **not** on the proving path: Permit2 signs with `ecrecover`, which is on the guest's divergent-precompile list with equivalence unverified |
| **★ "Why should anyone outside crypto care?"** | Beat 6, in one breath: end-of-day settlement buys you netting and costs you reconciliation; per-transaction settlement removes reconciliation and costs you the ability to undo. **The check has to be right the first time — so who performs it is the whole question.** Our answer is that nobody performs it; it is re-executed |
| "Can't the agent just make a second address and pay itself?" | **"Yes, and we say so in the docs."** A settlement can be self-dealt; identity is not something we solve. What is closed is narrower: **a record cannot exist without a settlement** |
| "Isn't the parent registry your key?" | **"While root roles are held, yes."** They are renounced after setup, and that is a tested criterion — because until it happens, the power can be handed over silently |
| "Why not put the Universal Router on the proving path?" | Permit2's signature step uses `ecrecover`, which is on the guest's divergent-precompile list with equivalence unverified. **We are not claiming soundness we have not established** |
| **★ "Isn't refusing a self-write a straw man? / why not just enforce the owner check?"** | **"It is enforced. We show it working."** Shot A is the official contract refusing. The point is shot B: **the check asks whether I am the owner, and a second address answers it.** It is an identity question, and identity is not what we are claiming to solve either — ours asks whether a settlement happened, which costs real money and work that reproduced |
| **★ "Which ERC-8004 implementation did you use?"** | **The official one** (`erc-8004/erc-8004-contracts`), already deployed on Sepolia at `0x8004B663…`, unmodified — **not** the ChaosChain reference implementation, which has no self-feedback check at all. Using that one would have made the opening work by picking the implementation without the check |
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
- **★ Not a word against ERC-8004 or its authors.** Its check is real, we show it working, and
  the gap between `erc-8004.md:217` and the reference implementation is a **draft standard being
  drafted**, not a failure to point at. What we demonstrate is a property of **identity checks in
  general** — a second address answers them — and we say the same thing about ourselves in §3.
- **No claim that anything ran on mainnet.** Sepolia, and the 09-08 mainnet measurement is
  pre-existing and labelled.
- **No bridge claim, no chain-abstraction claim, and no "bridges are risky" claim.** See the
  rejected framing above.

## 4b. ★ The shot list — which frame belongs to which beat

Read top to bottom. The right-hand column is **the thing that must be legible**; if it is not,
the frame is decoration.

| beat | frame | what has to be readable |
|---|---|---|
| 1 · 0:00–0:25 | `beat1-00-self-write-refused` | red **Fail with error 'Self-feedback not allowed'** |
| 1 · cut B | `beat1-01-state-contrast` | `agent: 0 record(s)` against `second address: 1 record(s)` |
| 3 · 0:42–1:00 | `beat3-02-window-opened` | `From` = the agent, `To` = the adapter |
| | `beat3-03-buyer-writes` | `From` = **the buyer**, not the agent |
| | `beat3-04-ens-resolves-the-record` | `ENS says: "reproduced block=… verifier=…"` |
| 5 · 1:30–2:15 | `beat5-01-swap-refused` | red **Fail** |
| | `beat5-02-buyer-writes-the-record` | decoded: `value = reproduced block=…` |
| | `beat5-03-swap-executes` | **1 Reckn Demo B out, 0.987158034 Reckn Demo A back** |
| | `beat5-04-record-cleared` | decoded: `value` **empty** — one row different from the frame above |
| | `beat5-05-refused-again` | red **Fail** |
| **5b · 2:15–2:35** | `beat2-01-residue-closed` | the three rows, all `✓ refused`, **including the agent itself** |
| | `beat5b-04-stranger-swaps` | `From 0xF81dFf68…` and two ERC-20 transfers |
| 5b, optional | `beat5b-01/02/03` | the stranger minting its own tokens first, if the 20 s allows |

**The renounce transactions themselves are not in the list on purpose.** On etherscan they say
`Success` and nothing a viewer can read. What carries beat 5b is the page reporting the three
refusals, and the stranger's swap.

**`beat2-01` is the only frame of a page rather than a transaction.** It earns that: the heading,
the paragraph and the three rows are all read from the chain on load, so it is the one shot where
the evidence is being produced while you watch rather than recalled.

## 5. Before recording — the checklist that kills a demo

1. **Every number on screen is from the take being recorded.** A rig that keeps rendering after
   the thing behind it broke is the failure mode to fear; assert the load-bearing lines and refuse
   to record if one is missing.
2. **★ Four things that get the upload rejected outright** (ETHGlobal's list, and they mean it):
   **no text-to-speech and no AI voiceover** — the narration is the founder's own voice;
   **no phone** as the recording device; **no speeding the video up** to fit; and **no music with
   on-screen text instead of talking**. Under 720p or over 4 minutes fails at upload.
3. **Record after the deployments exist**, not against a fork. A fork-only video contradicts the
   ENS tracks' "functional, not hard-coded".
4. **The first twenty seconds must work with the sound off.** The refusal has to be legible as a
   red line on screen, not only as narration.
5. **Do not run `ZK_FRESH=1` to make the recording's proof** unless you then restore
   `reexec-groth16-fixture.json` — it overwrites a fixture crafted with `pre = 2⁶⁴` and silently
   removes what AC10 checks (`PREFLIGHT` §5.2).
6. ~~**Trust the test output, not `zk-e2e.sh`'s exit code**, until §4-14 lands (`PREFLIGHT` §5.1).~~
   **★ 2026-09-26: §4-14 landed — the exit code is forge's own now**, and a failing suite stops
   the script before it prints "what just happened". The first attempt at that fix did not work
   (`|| true` runs on failure and overwrites `PIPESTATUS`), which is why this line is struck
   through rather than deleted: it was true for a while longer than it looked.
7. **New screenshots.** `dashboard/media/*` are Arc/ETHOnline assets and must not be reused.
8. **★ Both Uniswap appearances are in the take.** A cut that keeps the gate and loses the
   re-executed swap turns the Uniswap prize submission into a claim the video does not support.
9. **★ No secret in the frame.** `SEPOLIA_RPC` carries the Alchemy key inside the URL, and
   rotation is deferred until after the event (`PREFLIGHT` §5.7). Commands on screen use
   `$SEPOLIA_RPC`, never the expanded URL, and the scrollback is checked **in the frame** before
   the take — a repository guard does not guard a video. Same rule for the live screen-share on
   the 27th.
10. **★ Shoot each beat the moment it stands — do not save the camera for the end.** Beats 1–3
   are standing when night 1 closes; beat 5 when the funded pool runs; beat 4 while the ~416-second
   proof is generating. **Take rushes then**, ten minutes each. The 23:00 block on the 26th is
   then the **real take and the edit**, against footage that already exists, rather than the only
   attempt — which is what it was until this rule was written. **One rehearsal out loud, un-recorded,
   before the real take.** The rig in item 1 is what makes a rush honest: if a load-bearing line is
   missing, it refuses, and nothing gets filmed that the code does not support.

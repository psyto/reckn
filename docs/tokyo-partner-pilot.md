# Tokyo partner pilot — a runbook for producing adoption evidence, not applause

**ETHGlobal Tokyo, 2026-09-25 → 09-27.** The goal of this pilot is **not** to show Reckn to
people. It is to have somebody who is not us open a deal with their own wallet, against their
own job, and settle it.

Those are different outcomes and only one of them is evidence. A demo produces *"that was
impressive"*. This produces a transaction hash with a stranger's address in the `buyer` field,
which is the only thing that survives being asked *"has anyone actually used it?"*

> **Nothing in this document has happened yet.** It is a plan. Every template below is a
> template. No team has been contacted, and the word *adoption* is not to be used about this
> project until the checklist in §6 has real names in it.

---

## 1. What counts as success

A pilot run counts only when **all six** hold. Five out of six is a good demo and is not
adoption:

1. The team uses the Partner Kit **from their own repository**, not ours.
2. The deal is opened with **their own testnet wallet**, funded by them.
3. The predicate is **one deterministic step of their own agent or service** — not our
   example's step.
4. A **release or a refund** actually executes on chain.
5. A **third party can verify the receipt** — deal state, verdict, recipient, and binding, read
   back off the chain rather than told to them.
6. We record the **onboarding time, where they got stuck, and what they asked for**.

Item 6 is not bookkeeping. A pilot that produces one settled deal and no friction log has
taught us nothing we can act on, and *"it went well"* is not a finding.

---

## 2. The constraint that shapes the whole session

**Generating a proof takes minutes, not seconds.** Measured: **335 s** for the shipped fixture
and **497 s** for a real mainnet Uniswap v3 swap, on a laptop CPU. It also needs the SP1
toolchain and ~6.2 GB of Groth16 artifacts.

So a session cannot be *"bring a job, watch it settle"* end to end in fifteen minutes, and
pretending otherwise will fail in front of the person we are trying to convince. What **can**
happen live, in order of how quickly it lands:

| in the room | how long | needs |
|---|---|---|
| compute the **binding** for their job's terms | seconds | the Kit; no chain |
| **seller preflight** — show them what they would be agreeing to | seconds | the Kit; read-only RPC |
| **fund** a deal from *their* wallet | ~1 min | their wallet + faucet USDC |
| submit a **real proof of a different job** → `BindingMismatch`, **money does not move** | ~1 min | a shipped fixture |
| start proving **their** step | 5–10 min, in the background | SP1 toolchain on our machine |
| **settle** on their proof → release or refund | ~1 min | the proof from above |
| **verify** the receipt as a third party | seconds | the Kit; read-only RPC |

**The mismatch step is the one to lead with.** It is instant, it uses a genuinely valid proof,
and it is the only moment where somebody watches money *refuse* to move. It also needs no
proving time, so it works even when everything else is running late.

---

## 3. Ten-minute onboarding checklist — hand this to the team

Give them this before the session so the session is not spent installing things.

```
[ ] node 20+ and git
[ ] clone or copy the starter:      packages/partner-kit/examples/starter
[ ] npm install                     (inside the starter)
[ ] a testnet wallet you control    — NOT a key you use anywhere else
[ ] Arc testnet USDC from the faucet
[ ] pick ONE deterministic step of your agent, and be able to say:
       - which contract call it makes
       - which token's balance should go UP as a result
       - by at least how much
    If you cannot answer all three, Reckn is not the right tool for that step,
    and we would rather find that out here than after you integrate.
[ ] run the local demo once:        npm run demo:local
    (no wallet, no funds, no chain — it must pass before we touch testnet)
```

**If they cannot name a deterministic step, stop.** That is a real finding and it belongs in
the feedback log, not in a workaround. The most useful thing we can learn at Tokyo is *how many
teams have such a step at all*.

---

## 4. Session procedure — 15 to 20 minutes, for whoever is running it

**0–2 min · Frame it.** One sentence: *"Bring one deterministic step from your agent. We'll
open a test deal with your wallet, replay it, and settle it on proof."* Do not explain zero
knowledge. Nobody is here for that.

**2–5 min · Their step becomes a deal.** Together, fill in: the call, the token whose balance
must rise, the floor. Run `createDeal` in dry-run and show the **binding** — one hash that
commits to all of it. Say plainly: *neither of us can change any of this afterwards.*

**5–8 min · Preflight, from the seller's side.** Run `sellerPreflight` against the deal. Read
out the verifier and its code hash, and say the uncomfortable part: **a buyer picks the
verifier, and a seller who does not read it can be made to work for nothing.** Saying this
first is the difference between a tool and a pitch.

**8–11 min · Fund it, from their wallet.** They send the transaction. Not us. If they are not
comfortable doing that, the pilot has not happened — note it and continue as a demo, clearly
labelled as such.

**11–14 min · The refusal.** Submit a **real** proof of a different job. It verifies, and it
reverts with `BindingMismatch`. The money stays where it was. **This is the moment that
convinces people**, and it costs no proving time.

**14–18 min · Start their proof, and be honest about the clock.** Kick off proving for their
step. Tell them it takes five to ten minutes and that they will get a link. Do not stand and
watch it.

**18–20 min · The feedback log, while they are still in front of you.** Fill in §7 with them,
not from memory afterwards. Ask the question that hurts: *"what would stop you using this next
week?"*

**Afterwards · Settle and send.** When the proof lands, settle, then send them the
`verifySettlement` output and the explorer link. Their deal, their wallet, their job.

---

## 5. When it fails — fallbacks, in the order you will need them

| what breaks | fallback | what you may still claim |
|---|---|---|
| **Faucet is empty or slow** | run the whole flow on the **local chain at Arc's chain id** (`npm run demo:local`) | a working demo. **Not** adoption — their wallet never appeared |
| **Conference RPC is unusable** | same as above; local chain needs no network | as above |
| **Proving is too slow / no SP1 toolchain on the machine** | do everything except settlement live, and settle afterwards from a machine that has it | full adoption, if the settlement lands and they see the receipt. Say when it will land |
| **Their step is not deterministic** | stop and record it. Offer the starter's own predicate so they can see the shape | nothing about adoption. **This is a finding**, and a valuable one |
| **They will not use their own wallet** | run it with ours, and label the record `demo, not adoption` | a demo. Do not let this one blur |
| **Everything is on fire** | the mismatch step alone, on the local chain, in ninety seconds | that the refusal is real. Nothing more |

**The rule underneath all of these:** a fallback changes what happened, so it changes what may
be said. Write down which fallback was used, in the record, at the time.

---

## 6. What may be claimed — one team versus three

| after | may say | must not say |
|---|---|---|
| **0 teams** | *"We are opening the integration kit on Arc testnet."* | anything with the word *adoption*, *users*, *teams are using*, or *traction* |
| **1 team** | *"A team outside the project opened a deal with their own wallet, against a deterministic step of their own service, and settled it on proof. Here is the transaction."* — with the hash | *"teams"* (plural), *"early adopters"*, or any rate of adoption. **One is one** |
| **3 teams** | *"Three teams did this, in one weekend, from their own repositories. Median onboarding time was N minutes, and here is what stopped the ones that did not finish."* | that it is *proven demand* — three teams at a hackathon is evidence of **feasibility of onboarding**, not of willingness to pay |

**The line nobody may cross:** a team that watched a demo is not a team that used it. If the
`buyer` address in the transaction is ours, the sentence is *"we demonstrated"*, not *"they
used"*. This distinction is the entire value of the exercise — a project that inflates it has
converted its only piece of real evidence into a claim nobody will trust.

---

## 7. Feedback log — one per team, filled in during the session

```
team / project      :
repo (if public)    :
date, session length:

the deterministic step they brought:
  contract call     :
  token that rises  :
  floor             :
  could they name all three unprompted?   yes / no / partly

timings (minutes, wall clock)
  clone -> local demo passing            :
  local demo -> binding computed         :
  binding -> deal funded from THEIR wallet:
  funded -> settled                      :
  TOTAL from clone to settled            :

where they got stuck (verbatim, not paraphrased):
  1.
  2.
  3.

what they asked for that does not exist:
  1.
  2.

the question: "what would stop you using this next week?"
  answer (verbatim):

fallbacks used (see §5)      :
their wallet, or ours?       : theirs / ours   <- decides what may be claimed
outcome                      : release / refund / mismatch only / did not settle
```

**Verbatim, not paraphrased.** A paraphrased objection turns into the objection we already knew
how to answer, which is how a feedback log stops being one.

---

## 8. Adoption evidence record — one per team that actually settled

Keep these in `docs/adoption/` as they happen. They are the artefact, not the notes.

```
team                :
chain / chain id    :
escrow address      :
deal id             :
buyer address       :   <- theirs. If it is ours, this is not an adoption record
seller address      :
token / amount      :
predicate           :   contract, slot, floor  (their job, in one line)
binding             :
fund tx             :
settle tx           :   or: refund tx
outcome             :   release / refund
verified by         :   who re-derived it, and with what command
date                :
fallbacks used      :
```

**Every field is read back off the chain, never transcribed from a terminal.**
`verifySettlement` produces all of it. Two Arc transaction hashes were once copied by hand into
a record in this repository and both were wrong — right length, right prefix, linking to
nothing — which is why the tooling reads receipts and humans do not retype them.

---

## 9. Outreach templates — not to be sent from here

**No team is contacted by this repository or by any agent working in it.** These exist so the
founder has wording ready, and for no other reason.

**Before the event, to a team already building agents:**

> Subject: one deterministic step, settled on proof
>
> We built a payment escrow that releases on a re-executed proof instead of on somebody's
> signature — no owner, no admin, no resolver, and that is enforced as a build condition.
> At Tokyo we are looking for a handful of teams to try it against one deterministic step of
> their own agent: you bring the step, you use your own testnet wallet, and you keep the
> receipt. Fifteen minutes, and we will tell you within the first two if your step is not a
> fit — that answer is useful to us too. Interested?

**At the event, in one breath:**

> Bring one deterministic step from your agent. We'll open a test deal with your wallet,
> replay it, and settle it on proof. Fifteen minutes.

**Afterwards, to a team that completed a run:**

> Here is your settlement, read back off the chain rather than from our notes: <output>.
> You can re-derive every field with `verifySettlement`. Two things you told us that we are
> changing: <...>. Two things we could not fix: <...>, and here is why.

**The last one matters most.** A follow-up that reports only what we fixed is marketing. One
that names what we could not is the reason a team answers the second message.

---

## 10. What this pilot cannot establish, stated before anyone asks

- **It is not demand.** Teams at a hackathon try things because trying things is what a
  hackathon is. Willingness to *use* is not willingness to *pay*, and this measures neither.
- **It is not production readiness.** Every deployment is testnet. No mainnet address exists.
- **It does not widen what Reckn adjudicates.** A partner's step still has to be deterministic
  and expressible as a post-state delta. The pilot measures how many teams *have* such a step
  — which is genuinely unknown and worth learning — not whether Reckn can settle the ones that
  do not.
- **It says nothing about provenance.** A settled deal shows the committed computation
  reproduced. It does not show the committed inputs were any chain's real state.

# What ETHGlobal actually judges, and where Reckn is short

Researched 2026-09-07 against ethglobal.com. Every quoted line is verbatim from the site;
everything else is our own assessment and is marked as such.

---

## 1. The deadline is three days earlier than we have been planning against

> **"All projects must be submitted by Sunday, September 13th 2026 at 12:00 pm EDT."**
> — ETHOnline 2026, event details

| | |
|---|---|
| **Submission closes** | 2026-09-13 12:00 EDT = **2026-09-14 01:00 JST** |
| Live judging | 2026-09-14 12:00 EDT = **2026-09-15 01:00 JST** |
| What the repository said | *"submission by 9/16"* — `STATUS.md`, `PLAN.md`, spec 004 |

**This is the finding that changes the plan.** `PLAN.md` reads *"提出は 9/12 に凍結し、
9/13–15 は R[3]sidency（締切 9/15）に明け渡す"*. Submission now closes **inside** that
window, at 01:00 JST on the 14th, so the two commitments overlap rather than follow one
another. And a 9/12 freeze leaves **twelve hours** before the form locks — into which the
pre-freeze acceptance run, which took **eight hours of wall clock** on 09-06, must fit.
That is a collision, not slack.

`PLAN.md` is a founder document and is not edited here. **It needs the founder's hand**:
either the freeze moves earlier, or the R[3]sidency window starts after 01:00 JST on the
14th, or the full acceptance run stops being a pre-freeze gate.

## 2. The five criteria, quoted, and where we stand

> Judges evaluate on **"Technicality," "Originality," "Practicality," "Usability
> (UI/UX/DX)," and "WOW Factor."**

| criterion | assessment | why |
|---|---|---|
| **Technicality** | **strong** | Real Groth16 over two dissimilar VMs, MPT-verified prestate in-guest, a soundness bug found and closed during the event, mutation-tested acceptance gates. |
| **Originality** | **strong** | "The adjudicator is a computation, so it belongs to no chain" is not a crowded position. Everyone else ships a party with a key. |
| **WOW Factor** | **strong** | Two of them: a real proof that verifies and still cannot take the money, and USDC on Arc moved by a proof about work performed on Solana. |
| **Practicality** | **weak — the largest gap** | *"Could it be used by its target audience today?"* Our audience is agent developers, and there is **no integration path**: no SDK, no `fund()` example an outsider could copy, no "here is how your agent opens a deal in ten lines". Everything demonstrates that the mechanism is sound; nothing shows how a stranger would adopt it. |
| **Usability (UI/UX/DX)** | **weakest** | The live page is **read-only** — it proves, it does not let you do anything. The interactive demo needs a clone, Foundry and a shell. There is no wallet flow, no form, no path where a visitor causes a state change. Judges score this dimension explicitly and we currently have almost nothing to point at. |

## 3. Live judging is 7 minutes, and none of it is prepared

> **"4 minutes for the demo, followed by 3 minutes for Q&A with the judges."**

What exists: a 2–4 minute **video**. What does not exist:

- **A 4-minute live demo plan.** The video is a recording; the live slot is a performance
  with a different shape — you are talking over something, judges are watching your hands,
  and the thing you show first is the thing they remember.
- **Q&A preparation.** Three minutes of questions from people whose job is to find the
  soft spot, and Reckn has *known* soft spots that are written down in its own
  specifications. The answers exist and are good; **they have never been said out loud in
  under thirty seconds.** The predictable questions:
  - *"A buyer names the verifier — what stops them naming one that always returns Failed?"*
    (Nothing on-chain. The seller reads the deal first. This is in the contract's comments,
    and saying so plainly is stronger than deflecting.)
  - *"You say no bridge and no light client — so how do you know the Solana state was real?"*
    (We do not. It is a statement about the adjudication path, not anchoring, and there is
    a test asserting a fabricated account set hashes just as well.)
  - *"What did you actually build this week, versus what existed?"* (008, 009, 005, the
    keyless timeout, the build condition's closure — and the disclosure is in the
    submission.)
  - *"Who pays for this?"* — **we have no rehearsed answer.** Worth having one.

## 4. Format calibration from the showcase

A showcase project page runs roughly **25 words** of short description, **60 words** of
project description, and **150 words** of "how it's made" (measured on a live page). Ours
are far longer, and for the description that is unavoidable — ETHGlobal's rules put the
full pre-existing-work disclosure in that field.

The consequence is not "make it shorter". It is that **the first sixty words have to carry
the project**, because that is the attention the format trains a reader to give before
scrolling. Worth re-reading the opening of the description with that in mind.

## 5. Ranked, with the honest cost

| # | work | why it is here | cost |
|---|---|---|---|
| **1** | **Resolve the schedule collision** (founder) | The deadline moved three days earlier than the plan assumes and now overlaps the R[3]sidency window. Everything else is worthless if the form locks first. | a decision |
| **2** | **Finish the video** | Already the one round-1 criterion we fail: the cut on disk is 1:41 and silent against 2–4 minutes with audio. | in progress |
| **3** | **A 4-minute live demo plan and a Q&A sheet** | Seven minutes decides the finalist prize and nothing is prepared for it. The Q&A answers exist in the specs; they need to be thirty seconds each, out loud. | half a day |
| **4** | **Something a visitor can DO** | Usability is scored and the live page is read-only. The cheapest honest version: let the page *submit a claim* and show the verdict not moving — 004's claim, made interactive, with no wallet and no key. | one day |
| **5** | **An integration path** | Practicality asks whether the audience could use it today. Ten lines showing how an agent funds a deal, in the README, would answer it. | half a day |

**Not recommended before the deadline**: more gates, more mutation families, more
specification. Those are the dimensions where we are already strongest, and none of the
five criteria is called "rigour".

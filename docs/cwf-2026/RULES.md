# CWF 2026 — the rules, as read, with their provenance

**Read 2026-09-12** from the pages named below. This file exists because the decision that
matters most for this event — *what may be counted as the work* — is a rule, not a technical
fact, and the project has already learned once that a stale note about a rule costs more than
a stale note about code.

**How this was read, stated before anything is quoted.** The pages were fetched by an agent's
web tool, which converts a page to text and answers a question against it. That is one step
removed from a human reading the page. **Every quotation below must be re-read by the founder
against the live page before it is relied on in a submission**, and the numbered items in
[`PREFLIGHT.md`](PREFLIGHT.md) say where that ride-on-a-human happens. Nothing here is
transcribed from a search-result snippet or from memory.

| | |
|---|---|
| event | **Crypto World's Fair** (Colosseum) |
| dates | **2026-09-14 → 2026-10-12** — quoted from <https://colosseum.com/worldsfair> |
| kickoff | **2026-09-14 04:00 PDT = 2026-09-14 20:00 JST** (from the registration confirmation the founder received) |
| registration | done. Project registration opens at kickoff: *"As soon as the hackathon begins, you'll be able to register your project here and fill in your teammates too."* |
| rules page read | <https://colosseum.com/hackathon> |

---

## 1. The three sentences this event turns on

All three are quoted from <https://colosseum.com/hackathon>, read 2026-09-12.

> **"Teams may begin development before the hackathon, but products are judged only on the
> work completed between the competition's start and end dates."**

> **"Builders may use pre-existing code, but teams must disclose all relevant past
> development work in the submission form."**

> **"Each builder can submit only one product and be part of only one team."**

### What they mean for Reckn, said plainly

1. **Building before 09-14 is allowed. Being *judged* for it is not.** The organiser's own
   mail says *"There's no need to wait, you can start building right away"*, and the rule above
   says what that costs: anything finished before kickoff is pre-existing work. **So the Tempo
   slice — deployed and settled on 2026-09-08 — is pre-existing work for this event.** It is
   the foundation the submission stands on and it is *not* the work being judged. Writing it
   up as day-work would be the exact misrepresentation the rules punish.
2. **Therefore the in-window work has to be real, and has to be new.** What that work is, is
   in [`PREFLIGHT.md`](PREFLIGHT.md) §4.
3. **Disclosure is a form field, not a repository file.** Reckn has a disclosure habit already
   (`docs/ethonline-2026/DISCLOSURE.md`), but for CWF the obligation lands **in the submission
   form**. A file in the repo does not discharge it; pasting the file's content into the form
   does.

## 2. Deliverables, as quoted

- product name and description
- blockchains and tools integrated
- team member backgrounds
- product logo / graphic
- GitHub repository link — *"open-source encouraged, private allowed"*
- **presentation video: "two-to-three-minute presentation video"**
- **product demo: "product-demo video of no more than three minutes"**
- go-to-market strategy and demand validation

**Two videos, and both of Reckn's current CWF cuts break their limit** — measured, not
assumed: `docs/ethonline-2026/PREFLIGHT.md` §5 records 3:04 against a 3:00 ceiling and 3:27
against a 3:00 ceiling, and both files are stale as well as long.

## 3. Judging criteria, as quoted

Founder + Market Fit · Insight · Product + Execution · Potential Market Size · Founder
Communication · Viability · Traction

Process: *"multiple rounds of evaluation"*, a shortlist to a judging panel, then a
*"15-minute Zoom interview"* for selected teams.

**Four of those seven are not engineering.** Every artefact Reckn has today argues
*Product + Execution* and *Insight*. **Market size, viability, traction and go-to-market have
no artefact in this repository**, and that is a gap in the submission, not a gap in the
product. Named as item 6 in `PREFLIGHT.md`.

## 4. Not established — **[unknown]**, and therefore not assumed anywhere

- **Prize tracks, sponsors, judges, dev resources.** Colosseum's announcement says full
  details are released **on 09-14**. Whether Tempo or Solana appear as named tracks is
  **unknown** and must not be planned around. What is public: the event is *"open to all
  builders across blockchain ecosystems"* with *"dedicated prize tracks for several leading
  ecosystems"*.
- **The submission form's own fields**, including the wording of the past-work disclosure
  field. Available at kickoff.
- **The weekly check-ins.** The event runs them during the window; their cadence, format, and
  whether a video is required are not on the pages read here. **They are a different artefact from
  the two submission videos** (`PREFLIGHT.md` §5) and must not be planned as one.
- **Team size limit.** Not on the page. Solo is explicitly allowed.
- **Whether the eligibility bar (*"a new product that hasn't raised significant funding"*)
  has a definition of "significant"**. Not on the page.
- **Whether another event's rules restrict entering a project that is also submitted
  elsewhere.** This is not a Colosseum question and it is not answered here — item 2 of
  `PREFLIGHT.md`.

## 5. Sources

- <https://colosseum.com/worldsfair> — dates, one-line description
- <https://colosseum.com/hackathon> — every quotation in §1, §2 and §3
- the founder's registration confirmation mail — kickoff instant, project registration timing

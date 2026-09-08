# How AI was used, which files it touched, and what the human decided

**Read this next to [`DISCLOSURE.md`](DISCLOSURE.md).** That file draws the line between work
that existed before the event and work done during it. This one answers a different
question — *who or what actually wrote it* — and it is written on the assumption that a judge
will check the claims against the repository rather than take them.

Every number here was produced by a command that is printed beside it, so it can be re-run.

---

## 1. The short answer

**Heavily.** 202 of this repository's 231 commits carry a `Co-Authored-By: Claude` trailer:

```sh
git log --oneline | wc -l                                  # 231
git log --format='%b' | grep -c 'Co-Authored-By: Claude'    # 202
```

Saying "AI-assisted" and leaving it there would be the misleading version. The accurate
version is that **an AI wrote most of the text in this repository, and a human decided what
it was allowed to say.** Section 4 is that second half, with dates, because it is the part a
reader cannot verify from a commit trailer.

## 2. What it was used for, by area

| area | files | AI's role |
|---|---|---|
| specifications | `docs/specs/003…009` | drafted by Claude, then reviewed adversarially by a **different vendor's model** before any implementation |
| specification review | `docs/reviews/*.md` | written by OpenAI's Codex CLI, as an independent author, returning a verdict |
| contracts and guests | `zk-verdict/` | implemented by Claude against an approved specification |
| acceptance gates and mutants | `zk-verdict/scripts/` | written by Claude; the gates parse their criteria out of the specification documents themselves |
| demo, live pages, recorder | `dashboard/` | written by Claude |
| documentation and submission text | `README.md`, `docs/`, this file | written by Claude |

**Not written by AI:** the cryptographic constructions (SP1, Groth16, the BN254 precompiles)
are libraries and chain primitives, not generated code. And **no number in this submission
was generated.** Every figure came from running something and reading its output — gas from
receipts, test counts from `forge test`, commit counts from `git log`. Where a number was
once typed by hand it went wrong, and §5 records that.

## 3. The structure the generation was forced through

The interesting part is not that code was generated. It is the separation of powers.

1. **A specification is written before any implementation exists**, with acceptance criteria
   that a script can check.
2. **A different vendor's model reviews it adversarially** and returns `VERDICT: APPROVE` or
   `VERDICT: CHANGES`. One model marking its own homework is not review.
3. **Only then is it implemented**, and the acceptance gate is derived from the specification
   document itself, so the two cannot drift apart.

Every verdict is committed, **including the ones that failed**:

```sh
ls docs/reviews/*.md | wc -l                        # 16 verdicts
grep -l 'VERDICT: CHANGES' docs/reviews/*.md | wc -l  # 15
grep -l 'VERDICT: APPROVE'  docs/reviews/*.md | wc -l  # 1
```

**Fifteen of sixteen were CHANGES.** That ratio is the honest output of the process, not a
sign it went badly — the soundness bug in our own zk proof, where a decreasing balance proved
as a maximal credit, was found by *writing the specification*, on day one, before a test
existed to fail.

## 4. What the human decided — the part no trailer records

The founder's contribution is not measured in lines. It is in rulings that changed direction,
and in refusals. Each of these is recorded in the repository at the date given, and each one
**overrode what the model was about to do**:

| date | ruling | what it prevented |
|---|---|---|
| 2026-09-05 | `no-keys.sh` check 2 must **close the set of entry points**, not enumerate the functions it finds | a `fallback()` draining any funded deal passed all four checks. Enumeration cannot catch what it does not name |
| 2026-09-05 | task 004's headline claim must be **judge-independent**; citing an LLM judge we wrote ourselves as evidence of persuasion is forbidden | a demo that "proved" prose cannot move a verdict by persuading a judge we controlled |
| 2026-09-06 | **Hedera and World AgentKit dropped** despite Hedera being the largest purse on offer ($15,000) | claiming sponsors whose technology is not integrated |
| 2026-09-06 | task 003's key gauntlet **stopped**, mid-task | scope the founder judged was not earning its cost |
| 2026-09-07 | the pre-existing-work disclosure **amended twice before submission**, moving the strongest real item out of a conditional parenthetical and deleting a claim about work that was never built | a disclosure that named a thing that does not exist and buried the thing that does |
| 2026-09-08 | **the submitted Description must not be regenerated** to carry new positioning | the repository silently disagreeing with what the event actually holds |
| 2026-09-08 | the demo film's illustration pans **deleted**; the thesis moved to the front and stated affirmatively | fourteen seconds of the only footage a judge could not check, in a film whose argument is that everything is checkable |
| 2026-09-08 | captions must sit **beside the evidence**, not at the frame's edge | a viewer reading the words or watching the log, never both |

The last three came from the founder watching the artefact and saying it was wrong. The model
had measured the video as green on every check it had.

**And one standing rule that shaped everything else:** claims are gates, not prose. If a
sentence in this repository can be checked by a script, there is a script, and it runs.

## 5. Where the AI was wrong, and how it was caught

Recorded here because a transparency document that only lists successes is an advertisement.

- **Two of four transaction hashes were transcribed by hand into a page and both were wrong**
  — right length, right prefix, linking to nothing. The page is now *generated* from the
  deployment record, and a gate scans it.
- **A blacklist claim was over-generalised** ("USDC blacklists well-known compromised keys").
  Measured against the real predeploy, exactly one of six test addresses is blacklisted. The
  record was corrected to the measurement.
- **A review cited a line range in a sibling specification that had moved** to different
  content — a confident citation of something no longer there.
- **A video was reported green while it was a slideshow**: two distinct frames inside a
  nine-second hold, with duration, resolution and aspect all passing. The property nobody was
  measuring is where it broke, and that pattern repeated often enough to become a rule.
- **A cleanup routine killed the process it was meant to protect**, because it ran after the
  thing it was cleaning up had already started.

Each of these is in a commit message at the point it was found. None was discovered by a
reviewer being impressed.

## 6. What this means for judging

If the question is *"did a human build this?"* — the honest answer is that a human directed
it, ruled on it, rejected parts of it, and is accountable for every claim in it, while an AI
wrote most of the text. If the question is *"can the claims be checked?"* — that is what the
gates, the live page and this repository's history are for, and neither answer depends on
believing anything written above.

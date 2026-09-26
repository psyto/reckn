# How AI tools were used, and by whom

ETHGlobal Tokyo 2026 requires that a submission document **where and how** AI tools were used,
naming the parts of the code they produced, and — for spec-driven work — that **the spec files,
the prompts and the planning artifacts are in the repository**. This is that document. It is
written to be checkable rather than flattering, so it names what the AI wrote as well as what it
did not.

## The short version

**Solo founder. Two models, and the division between them is a rule, not a preference.**

> **Author independence** (`AGENTS.md` §1): whoever writes a spec does not implement it, and
> whoever implements does not review. It exists because a model asked to check its own work
> agrees with itself.

During the event window, **Claude Code (Opus 5) wrote the Solidity, the tests, the scripts and
most of the prose**, directed turn by turn by the founder. **Codex** independently reviewed the
specification and the settlement adapter, then produced the public demo-page UI and the three
submission visual explainers. The founder held the keys, made every design decision where the
work forked, and ran every transaction.

**No AI produced a measurement or an on-chain result.** Every number in
[`RECEIPTS.md`](RECEIPTS.md) came from running the code and reading the chain back.

## Who wrote what, during the event

All 29 event commits carry `Co-Authored-By: Claude Opus 5`. `git log eddac8d..HEAD` is the full
record; nothing is squashed.

| | written by | reviewed by |
|---|---|---|
| `tokyo-2026/src/SettlementRecord.sol` | Claude Code | **Codex, once, independently** — [`docs/reviews/013-tokyo-adapter-r1.md`](../reviews/013-tokyo-adapter-r1.md) |
| `tokyo-2026/src/RecordGatedHook.sol` | Claude Code | founder, against the 09-21 spike |
| `tokyo-2026/src/demo/*` | Claude Code | — |
| `tokyo-2026/test/*` | Claude Code | Codex (the adapter's rows) |
| `tokyo-2026/script/`, `tokyo-2026/scripts/` | Claude Code | founder, by running them |
| `zk-verdict/script/src/bin/binding.rs` | Claude Code | pinned by a pre-existing test |
| `scripts/no-keys.sh` check 6, `scripts/no-keys-control.sh` | Claude Code | its own negative control |
| `docs/specs/013-*.md` | Claude Code | Codex, twice, before the event |
| `docs/tokyo-2026/*` except `media/submission/*` | Claude Code | founder |
| `docs/index.html` | Codex | founder |
| `docs/tokyo-2026/media/submission/*` | Codex | founder |
| **every contract under `zk-verdict/` other than the two above** | **pre-existing work.** See [`DISCLOSURE.md`](DISCLOSURE.md) | |

## What the founder did

Stated plainly, because "meaningful contribution" is a disqualification criterion and a vague
answer is worth nothing to a judge.

- **Held the keys and sent every transaction.** Every signature on Sepolia is the founder's,
  through a keystore the model never reads. 54 transactions.
- **Took every screenshot**, including the re-shoots when a frame turned out not to carry its
  own evidence.
- **Decided where the work forked.** The 09-26 scope defect had two fixes with different costs —
  put the name in the key and pin the adapter to one name, or have the adapter write the record
  itself. The second closes more and throws away the ENS mechanism the submission is about. The
  founder chose the first.
- **Asked "is this actually finished?" four times**, about four different blocks, and it was
  half-finished four times: the fallback predicate had not been re-run from a fresh clone, the
  second on-chain refusal had been recorded on `status 0` alone, the v4 hook existed only on a
  fork, and the independent review's one deferred question had never been written down. Every
  one of those is a commit today.
- **Noticed that the keystore was still called `reckn-arc`** — a name from a different lane — and
  had it renamed before it reached a judge.
- Chose the track, the submission type and the partner prizes, and **refused to apply for a
  partner whose technology this project does not use**.

## What the AI got wrong, in this repository

Included because a disclosure that only lists successes is not a disclosure. **This section is
itself a thing that can go stale**, so it is appended to rather than summarised: the last four
entries were added on **2026-09-27, after the section already existed**.

- Named a shell function `head`, which shadowed the coreutil and made a live ENS record read as
  "no answer" inside the very rig written to catch that class of bug.
- "Fixed" `zk-e2e.sh`'s exit code with `|| true; ${PIPESTATUS[0]}`, which does not work, and
  said it was fixed before measuring it.
- Read 12 red rows in a mutation run as rate limiting. It was a broken test harness. The cause
  was named before it was measured.
- Wrote an "address unchanged" check that compared two empty strings and proved nothing.
- Shipped `SettlementRecord` with a griefing hole that nine of its own acceptance rows could not
  see, because all nine were of the form *this must not happen* and none was *this must still
  work*.

Added **2026-09-27**, the night before judging:

- **Told the founder the submission video had a music bed and might have to be remade.** It did
  not. The measurement used `ffmpeg -v error`, which suppresses `silencedetect` — the filter
  logs at info level — so every threshold from -25 dB to -60 dB reported "0 silent regions". The
  absence of output printed as a number, and the number looked exactly like the one thing that
  gets a video auto-rejected. Re-measured: 55 pauses. The narration is the founder's own voice.
- **Wrote a `--record` that printed `✓ recorded` after the write had failed.** macOS treats
  `VIDEO` and the existing `video/` directory as the same path, the redirect errored, and the
  success line ran anyway. Found within a minute, but it is the same defect the repository keeps
  catching in its own gates: a green row produced by something that never happened.
- **Marked three rows of the video checklist green and let four more pass unexamined**, then
  reported the block finished. The founder asked "is this all done?" and it was not: one of the
  four, *"put 497.40 s on screen"*, was itself wrong — `DEMO.md` forbids that figure by name.
- **Carried `live judging 14:30` into four documents and built the entire final-day plan on it.**
  `013`'s own G-Q3 recorded the source as *"founder's calendar, not a file"* — the single
  scheduling claim in the repository with nothing behind it. Judging is **09:30**. The row named
  its own weakness and the AI propagated it anyway; the founder caught it by reading the
  published agenda.

All of them are in the commit messages, at the point where they happened.

## The spec files, the prompts and the planning artifacts

Nothing about how the AI was directed is hidden:

| | |
|---|---|
| the specification the event work implements | [`docs/specs/013-settlement-granted-record-rights.md`](../specs/013-settlement-granted-record-rights.md) |
| every earlier spec | [`docs/specs/`](../specs/) — 9 files |
| **the review payloads, verbatim, including the prompts the reviewer was given** | [`docs/reviews/`](../reviews/) — 20 files |
| the standing rules the models work under | [`AGENTS.md`](../../AGENTS.md) |
| **the agent definitions themselves** — the system prompts | [`.claude/agents/`](../../.claude/agents/) — 5 files |
| the running log of decisions and measurements | [`STATUS.md`](../../STATUS.md) |
| what existed before the event | [`docs/tokyo-2026/DISCLOSURE.md`](DISCLOSURE.md) |

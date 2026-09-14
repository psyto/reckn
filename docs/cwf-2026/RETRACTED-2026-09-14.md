# Retracted 2026-09-14 — Reckn does not enter this event

**Founder ruling, 2026-09-14.** Reckn is **not** the Crypto World's Fair entry. That entry belongs
to a different lane, and **this repository does not describe it** — `docs/specs/010` §11's one-way
rule ("reckn の文書は他レーンを参照しない") is not suspended by a change of plan, so nothing here
names it, dates it, or borrows its vocabulary.

**What was published and is now false.** Between 2026-09-12 and 2026-09-14 this directory, plus
`AGENTS.md`, `CLAUDE.md`, `STATUS.md`, `docs/specs/010` and parts of `docs/messaging.md`, stated
that Reckn would enter CWF with the Tempo × Solana slice. **It was true as a plan when written and
it is false now.** The files are kept and banner-marked rather than deleted, the same way every
other reversal in this repository is handled.

---

## The reasoning, in the only terms this repository is entitled to record

The founder's ruling weighed the two lanes at **75 : 25** — a judgement about *which is likelier to
read as a startup in a four-week competition*, not about prize money and not about engineering
quality. The half of it that is about **Reckn** is worth carrying, because it is the most direct
outside assessment this project has received:

> **"Reckn は技術的には非常に強いが、CWF では『誰が、なぜ今、Reckn に払うか』がまだ薄い。
> 再実行証明は重厚で価値も本物だが、プロダクトの最初の顧客と導入経路を一言で示しにくい。
> 短い審査導線では不利。"**

That is the same gap `PREFLIGHT.md` §6 named, the same gap `MARKET.md` §3 put a number on
(today's average agent payment is $0.20 against a $115.53 floor), and the same gap the ETHOnline
Round 1 result pointed at from outside on 2026-09-14. **Three independent readings, one finding.**
It is not a reason to change what Reckn claims. It is a reason to stop entering Reckn into
competitions that score first customer and go-to-market before they score mechanism.

**Where Reckn goes instead:** ETHGlobal Tokyo, 2026-09-25 → 09-27, the Uniswap Foundation
Continuity track — the lane [`docs/specs/012-uniswap-reexecution-slice.md`](../specs/012-uniswap-reexecution-slice.md)
was already written for, seventeen days before the event.

---

## What in this directory survives the retraction, and what does not

**Survives — these were measurements about Reckn, and the event framing was only the occasion:**

| file | why it still stands |
|---|---|
| [`ECONOMICS.md`](ECONOMICS.md) | the cost of one adjudication, read off the settlement receipts: 310,242 gas / 0.155307 PathUSD to release 1.000000, and the deal size below which deciding a payment is not worth buying. **No part of it depends on an event.** |
| [`MARKET.md`](MARKET.md) | bottom-up sizing from cited sources, including the measurement that argues against the product. Same: the sources and the arithmetic do not care which competition asked. |
| [`TRACTION.md`](TRACTION.md) | the two instruments — an outsider reproducing `zk-e2e.sh`, and a stranger calling the permissionless `refundAfterDeadline` on **2026-10-08**. **Both are about Reckn's own deal on Tempo and happen regardless.** `AGENTS.md` §8's relaxation is re-scoped, not revoked. |

**Does not survive — these were about the competition's mechanics:**

| file | state |
|---|---|
| [`RULES.md`](RULES.md) | the event's rules, correctly read and now not ours to act on. Kept as a record of how rules were transcribed. |
| [`PREFLIGHT.md`](PREFLIGHT.md) | its checklist had an owner and a date per line; the lines are void. |
| [`DAY-1.md`](DAY-1.md) | void. |
| [`PITCH.md`](PITCH.md) | the 147-word pitch was written to a form that will not receive it. **The claims audit at the bottom is not void** — what may and may not be said about the RDK lineage and the Tempo complement is wording discipline, and it lives in [`../messaging.md`](../messaging.md). |
| `../../scripts/cwf-baseline.sh` | void. It refuses to write a baseline before kickoff and there is now no kickoff to record. Kept because deleting a script that several documents reference produces a worse artefact than a script with a banner. |

**The directory keeps its name.** Renaming it would rewrite the paths of seven files to hide that
this happened, and the one thing this repository does not do is tidy away a reversal.

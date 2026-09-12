# CWF 2026 — what has to be true before 09-14, and who owns each line

**Written 2026-09-12, 51 hours before kickoff.** Every item is **DONE** with the command that
shows it, or **OPEN** with the name of the person or the date that closes it. Nothing is marked
done because it was written down. The rules this file obeys are quoted in
[`RULES.md`](RULES.md); they are not restated here, because two accounts of one rule drift.

| | |
|---|---|
| kickoff | **2026-09-14 20:00 JST** (04:00 PDT) |
| deadline | **2026-10-12** (time of day not published — `RULES.md` §4) |
| what is judged | *the work completed between the start and end dates* — **not** what exists now |
| the sentence this whole file protects | **the Tempo slice is pre-existing work for this event** |

---

## 1. The boundary — ⚙️ MECHANISED, runs at kickoff

CWF judges in-window work, so the one fact that must not be guessed is **which commit was HEAD
at kickoff**. A date cannot answer it (ETHOnline's own preflight records `git log --since`
losing twelve commits to a timezone) and a hash cannot be written in advance (the commit that
writes it lands after it).

```sh
bash scripts/cwf-baseline.sh            # report — where we are relative to the window
bash scripts/cwf-baseline.sh --write    # AT KICKOFF, once. Refuses before it. Refuses twice.
bash scripts/cwf-baseline.sh --diff     # at submission time: the window's work, from git
```

Measured 2026-09-12: report prints `51h 15m until kickoff`, `--write` exits 1 with
*"a baseline written early names a commit that is not the boundary"*, `--diff` exits 1 because
there is nothing to diff against yet. **OPEN — founder or agent, at 2026-09-14 20:00 JST:**
run `--write`.

## 2. The repository during ETHOnline's judging window — ⚠️ OPEN until 09-17

ETHOnline's schedule (founder, 2026-09-12): **submissions due 09-14 01:00 JST**, async judging
**09-14 04:00**, live judging **09-15 01:00**, finale **09-17 01:00 JST**. Reckn is submitted,
on Arc, and `docs/ethonline-2026/PREFLIGHT.md` §2 records the deliberate decision that **Tempo
is not claimed there**.

**Founder ruling 2026-09-12: `master` is frozen from 09-14 01:00 JST until the finale, and CWF
work goes on a branch.**

- commits dated **on or before 09-13** belong to the ETHOnline window and may land on `master`
- from **09-14 01:00 JST**: branch `cwf-2026`; no commit on `master`
- after **09-17 01:00 JST**: merge, keeping the dates
- **this is enforced by the branch, not by a checker.** Nothing in this repository can stop a
  commit on `master`; the only instrument is that the work is happening somewhere else. Said
  plainly because a rule with no observer that pretends to have one is worse than a rule.

**OPEN — founder, one question this repository cannot answer:** whether ETHGlobal's rules
restrict entering a project that is also entered elsewhere. Colosseum's own constraint is only
*"one product, one team"* per builder within CWF (`RULES.md` §1). The ETHGlobal side is
**[unknown]** and is not assumed in either direction here.

## 3. What is pre-existing for CWF — ✅ MEASURED 2026-09-12

This is the list that goes in the submission form's past-work field. All of it predates
kickoff, and **all of it is on a public repository with dated commits**, which is the strongest
form this disclosure can take: a judge can check it rather than believe it.

| what | when | where the evidence is |
|---|---|---|
| re-execution engine, escrow, zkVM guests, keeper (~140 tests) | 2026-07-26 → 08-02 | `git log`, `docs/ethonline-2026/DISCLOSURE.md` |
| the development harness | 2026-09-03 | `AGENTS.md` |
| verdict-domain soundness (008), cross-VM settlement (009), keyless timeout (001), Arc testnet deployment + 4 real USDC settlements | 2026-09-04 → 09-07 | `zk-verdict/contracts/arc.json`, ETHOnline submission |
| **the Tempo slice: spec 011, deployment to Tempo Moderato, three deals, two real settlements, fees paid in the escrowed TIP-20** | **2026-09-08** | `docs/specs/011-tempo-tip20-slice.md` §10, `zk-verdict/contracts/tempo.json`, `docs/tempo.html` |
| spec 010 (SVM token replay) — **the plan, not the code** | 2026-09-06, committed 09-12 | `docs/specs/010-svm-token-replay.md` |
| the demo film, live pages, partner kit, acceptance gates | 2026-09-08 → 09-11 | `dashboard/`, `zk-verdict/scripts/ac0*.sh` |

Green, measured today on a still tree (no mutation run in progress):

```
bash zk-verdict/scripts/ac011.sh --all         -> 8/8 rows passed   <- the CWF story's own gate
bash scripts/no-keys.sh                        -> PASS  (the claim holds)
python3 docs/check-links.py                    -> 192 links across 55 files, all resolve
cd reexec-svm && cargo test                    -> 30 passed
cd escrow-svm && cargo test                    -> 10 passed (tests/e2e.rs, LiteSVM)
```

**AC-3, AC-4, AC-6 and AC-7 of that gate read the live chain**, so 8/8 is not a statement about
a local mock: the recorded hashes were confirmed on Tempo today, the three deals were
re-derived from the chain (2 settled), the live page rendered its rows from it, and the six
assumptions the escrow makes about a token were re-checked against the real TIP-20. A network
failure is a red row in that gate rather than a skip, which is why the number means something.
**Re-run it before the submission**, and never on a tree with a mutation run in progress
(`CLAUDE.md`).

## 4. What the in-window work is — 🚫 MUST NOT START BEFORE KICKOFF

**Reckn's Solana side is the weakest part of the story and it is also the only part that can
honestly be built inside this window.** Today: the SVM guest proves a Solana execution and the
escrow settles on it, but `escrow-svm` — the Solana-side escrow — **is a resolver path with
keys**, and nothing in the re-execution path can replay an SPL Token transfer. `docs/specs/010`
is the plan for exactly that, and it was written on 09-06 and deliberately not implemented.

> **Do not implement 010 before 2026-09-14 20:00 JST.** Not because it is risky, but because
> finishing it early converts the day-work into pre-existing work, and the rules judge only
> what is completed inside the window. The organiser's *"you can start building right away"* is
> permission, not an advantage.

Order, once the window opens (010 §9): **P1** pinned legacy SPL Token image replay → **P2**
`TokenAmountDelta` → **P3** the mutation gate. Then the two things 010 marks founder-only
(§10): a devnet keypair and a devnet deploy.

**✅ Closed early, by measurement 2026-09-12 — 010 §10 item 1.** The toolchain is already
installed, so day one is not spent on downloads: `solana-cli 4.1.2`, `cargo-build-sbf 4.1.0`,
`anchor-cli 0.32.1`, `spl-token-cli 5.6.1`.

**The one demonstration this window makes possible that no window has before.** The Tempo
`mismatch` deal has been `Funded` since **2026-09-08 02:59:56 UTC** (block 34352010, read from
the chain 2026-09-12), so `REFUND_AFTER = 30 days` elapses at **2026-10-08 11:59:56 JST** —
**three days before the CWF deadline, and inside the window.** Anyone may then call
`refundAfterDeadline` and 1.000000 PathUSD returns to the buyer, paying the caller nothing.

Spec 011 §7.2 says a deadline refund *"cannot be demonstrated on a public chain inside"* the
28-day window. **That sentence is about a deal funded during the window, and it is right about
that.** This deal was funded six days before it opened, which is why the same 30 days land
inside. **OPEN — 2026-10-08:** make the call, record the receipt, and keep the two refunds
apart in every sentence: this one is the *deadline* refund, T-2's is the *proof-driven* one.

## 5. Two videos, both currently over their limit — ⚠️ OPEN, founder

CWF asks for a **2–3 minute presentation** and a **product demo of no more than three
minutes** (`RULES.md` §2). Measured in `docs/ethonline-2026/PREFLIGHT.md` §5:
`reckn-cwf-presentation.mp4` **3:04** against a 3:00 ceiling, `reckn-cwf-demo.mp4` **3:27**
against 3:00 — and **both files are stale**, predating the slide-timing fix, so they must be
re-recorded rather than trimmed. `dashboard/video/check.sh` takes its duration band from the
filename, so it fails them rather than passing them.

Not started here on purpose: the cuts should be recorded **after** the window's work exists, or
they will show the pre-existing product. The narration is a human voice by rule and belongs to
the founder either way.

## 6. Four of the seven judging criteria have no artefact — ⚠️ OPEN, founder

Founder + Market Fit · Insight · **Product + Execution** · Potential Market Size · Founder
Communication · Viability · Traction.

Everything this repository contains argues **Product + Execution** and **Insight**. *Market
size*, *viability*, *traction* and the form's *go-to-market and demand validation* fields have
**nothing** behind them — `docs/positioning.md` and `docs/tokyo-partner-pilot.md` are the
nearest, and neither is a market case. This is the gap most likely to decide the result, and it
is not a gap an agent can close by writing a document: *traction* means someone outside this
repository used the thing.

## 7. What must not be said, carried over unchanged

The claims discipline does not get a fresh start for a new event. `docs/messaging.md` §2 is the
list; three of them decide whether this submission is honest:

- **LiteSVM green says nothing about devnet; devnet says nothing about mainnet.** Tempo and Arc
  are **testnets**.
- **The guest recomputes a `bank_hash` over the account set the deal named. That is
  consistency, not provenance** — it does not establish that those inputs came from Solana.
- **`escrow-svm` is a resolver path.** Any Solana-side settlement shown from it is signed by a
  key, and saying "settled by proof" of it would be false. Proof-only settlement on Solana is
  010 §9 P5 and is not promised here.

## 8. The one thing that is not done

**Nothing has been registered.** Project registration opens at kickoff, the past-work
disclosure is a **form field** rather than a file in this repository, and no artefact here
discharges it. Everything else on this page is either measured green, mechanised, or an OPEN
line with a date on it.

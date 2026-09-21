# Pre-Existing Work Disclosure — Reckn, ETHGlobal Tokyo 2026

**Event**: ETHGlobal Tokyo 2026, 2026-09-25 → 09-27, Toranomon Hills Forum.
**Track**: Continuity. **Submission type**: Top 10 Finalist + Partner prizes.
**Partner prizes applied for**: ENS, Uniswap Foundation. (Not 1inch.)
**Repository**: `https://github.com/psyto/reckn` — **public, and public since 2026-09-04.**
**Prepared**: 2026-09-21, from the repository, not from memory.

> **How this document is filed.** ETHGlobal's rules say *"In all cases, you must disclose any
> pre-existing work in writing to the ETHGlobal team"* and **name no channel for doing so**. This
> text is therefore **reproduced in full in the submission form's description field**, which is
> where the same rules put the other half of the requirement — *"include full details in your
> submission (repo history, video, and description)"*. It also lives at this path in the public
> repository so the history and the disclosure are checkable side by side.

ETHGlobal's rules require pre-existing work to be disclosed in writing, and name **code, designs
and assets**. This document lists what exists before the event and states what will be written
during it. **Every count below was taken by running a command against the repository on
2026-09-21**, and every one of them is checkable against the public history by anyone, including
against us.

---

## 0. The short version

| | |
|---|---|
| **This project is not new.** First commit | `b8388f4`, **2026-07-26** |
| Commits before the event | **310**, the most recent `501cbde` on **2026-09-14**. *(Verified against `origin` before filing: four 09-14 commits were local-only on 09-21 and were pushed; a clone made before that showed 306.)* |
| **It has been submitted to another hackathon** | **ETHOnline 2026** (async, 09-04 → 09-16) — see §2 |
| Pre-existing implementation | **substantial**: 26 Solidity files, 136 Rust files tracked |
| Written for Tokyo before the event | **design and measurement only** — 2 specs, 2 reviews, 10 throwaway spike tests |
| Submission code written for Tokyo | **zero lines.** Nothing in §4 exists |

**We are not claiming to start from scratch, and the Continuity track is the reason we do not
have to.** What follows is the boundary, drawn where the rules draw it.

---

## 1. What Reckn already is (pre-existing, and the bulk of the repository)

An escrow for agent-to-agent payments whose arbiter is **deterministic re-execution**. A buyer
funds a deal; the fee is released only if replaying the work reproduces the agreed outcome.

| component | state before the event |
|---|---|
| `zk-verdict/contracts/src/RecknZkEscrow.sol` | complete. No owner / resolver / admin / pause / upgrade; `settleWithProof` is permissionless; `refundAfterDeadline` returns funds after 30 days to anyone who calls it, paying the caller nothing |
| `zk-verdict/contracts/src/RecknVerdictVerifier.sol` | complete. `verifyVerdict` is `public view` |
| `zk-verdict/program-revm` | complete. Real `revm` run **in-guest** over a prestate MPT-verified against the block `state_root` |
| `zk-verdict/program-svm` | complete. Not used by this submission |
| `contracts/` (optimistic path) | complete. **Not** the submission's path |
| ERC-8004 reputation surface, x402 payment surface | complete |
| `scripts/no-keys.sh` | complete. A build-time check that the escrow has no key |
| Arc testnet deployment | escrow deployed, **4 real settlements**. Pre-existing, **and not part of this submission** |
| `dashboard/media/*` (5 images) | ETHOnline/Arc assets. **They will not be reused as Tokyo screenshots** |

## 2. Prior hackathon use — disclosed because it is material

**The same repository was submitted to ETHOnline 2026** (async, 2026-09-04 → 09-16) on the
Continuity "Ship a Feature" track, with its own written disclosure
(`docs/ethonline-2026/DISCLOSURE.md`). It did not pass Round 1; partner-prize judging there ran to
2026-09-17. **179 commits fall inside that window and all of them are pre-existing work for Tokyo.**

The project was also prepared for Crypto World's Fair and **withdrawn on 2026-09-14**
(`docs/cwf-2026/RETRACTED-2026-09-14.md`). **Reckn is not concurrently entered in any other
competition during 2026-09-25 → 09-27.**

## 3. Written for Tokyo **before** the event — design and measurement only

ETHGlobal permits planning, design and research before an event and forbids building the
submission. **Everything in this section is design or measurement. None of it is submission code.**

| what | when | detail |
|---|---|---|
| `docs/specs/012-uniswap-reexecution-slice.md` | **2026-09-08** | design for a Uniswap re-execution slice. Superseded by 013, kept as the fallback |
| `docs/specs/013-settlement-granted-record-rights.md` | **2026-09-21** | the submission's design, at revision **r4** |
| `docs/reviews/013-spec-r1.md`, `-r2.md` | **2026-09-21** | two independent adversarial reviews of that design, each ending in a verdict. **Both returned `CHANGES`; four blockers are recorded with the fixes** |
| `spikes/tokyo-2026/` | **2026-09-21** | **10 throwaway test files, 1,506 lines.** Fork tests against Sepolia and against the repository's own fixtures |
| `spikes/tokyo-2026/FINDINGS.md` | **2026-09-21** | what the spikes measured, including two places where the design was **wrong** and was corrected |

### 3.1 A measurement taken before the event, which the submission will cite

On **2026-09-08**, against Ethereum mainnet: a real `SwapRouter02.exactInputSingle` re-executed
inside an **unmodified** guest — witness of 7 accounts / 12 storage slots / 141 MPT nodes,
**13,006,200 cycles**, Groth16 end-to-end **497.40 s**.

**This is a pre-event measurement and will be presented as one.** It is not event work.

### 3.2 What the spikes are, and what they are not

They are **instruments**: they use cheatcodes, forked state and deliberately-failing control arms
to answer whether a mechanism is possible. **They are not the submission and will not be ported
into it.** Their dependencies (`v4-core`, `contracts-v2`, `openzeppelin-contracts`) are shallow
clones under `spikes/tokyo-2026/lib/`, which is gitignored, as is the build output.

**They are disclosed in full, including the two findings that say the design was wrong**, so that
the record shows nothing unfavourable was withheld.

## 4. What will be written **during** the event (2026-09-25 → 09-27)

**None of this exists.** It is the "substantive new features developed during the event" the
Continuity track requires, and it is the list a judge should be able to check commit by commit.

| # | to build |
|---|---|
| 1 | A **parent ENSv2 registry** on Sepolia, and agent subnames issued under it |
| 2 | The **record contract**: a settlement opens a one-record write window for the deal's buyer, then closes it |
| 3 | A **Uniswap v4 `beforeSwap` hook** that gates a pool on that record |
| 4 | Buyer-side deal binding, settlement wiring, and `RecknZkEscrow` **deployed to Sepolia** |
| 5 | The acceptance-criteria test matrix |
| 6 | `FEEDBACK.md`, the Uniswap Developer Feedback Form, and a README section pointing at the contracts and line numbers |
| 7 | A live demo, new screenshots, and the video |

**`RecknZkEscrow` itself will not be modified.** Its function surface is the project's central
claim, and the event work sits outside it.

## 5. How the boundary is checkable rather than promised

- **The repository is public and every commit is dated.** A pre-event commit cannot later be
  presented as event work, and the history is as checkable against us as for us.
- **Event work is defined by date**: only commits dated **2026-09-25 or later** are event work.
  A commit hash is recorded as `EVENT_START` before the first of them.
- **Continuous commits during the event.** The rules treat a single large final commit as
  unqualified by default, and this repository's practice is small commits per task.

## 6. Honest notes

- This project has a **large pre-existing implementation**, and the rules note that projects
  relying mostly on pre-existing work do not historically score as high. We are not hiding the
  ratio: the escrow, the guests and the proving pipeline are old; **the ENS record surface, the
  v4 hook and everything that joins them are new.**
- The design in `013` has been through **two independent review rounds that both returned
  `CHANGES`**, and the spikes then showed **two further places where its reasoning was wrong**.
  Those corrections are in the document rather than removed from it.
- `docs/ethonline-2026/` describes a different event. It is kept, not deleted, and **its claims
  are not this submission's claims**.

---

**Contact**: `@psyto69` (Telegram) · `psyto` (GitHub) · Discord `psyto7835`.
**If any part of this disclosure is insufficient, we would rather be told before the event than
judged on it afterwards.**

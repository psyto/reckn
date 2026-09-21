# Review 013 spec round 2

Payload: `/tmp/reckn-payload-013-spec-r2.md`
Codex raw: `/tmp/reckn-codex-013-spec-r2.md`

Target: `docs/specs/013-settlement-granted-record-rights.md` at **r2**.
Round 1: `docs/reviews/013-spec-r1.md` (2 BLOCKER / 1 MINOR).
**Round 2 was opened by founder permission** — `AGENTS.md` §2 allows one round by default.
Codex invocations this round: **1** (`-s read-only`). Author independence holds.

Tree state: untracked additions only (`docs/specs/013-*`, `docs/reviews/013-*`); no mutation run
in progress, so `zk-verdict/` reads are trustworthy.

**Neither round-1 finding was re-raised.** Both round-2 blockers are **new, and both are
defects in the round-1 fixes** — the failure mode the round exists to catch.

## Findings

1. **[BLOCKER] `013:§3.4` (the r1 fix for B1)** — **the fix closed the outcome and opened the
   author.** The pseudocode grants `ROLE_WRITE_JOB` to `msg.sender` and never binds that recipient
   to a permitted party, and it never consumes `dealId`. Two consequences, the first fatal:

   - **The agent writes its own history through the adapter.** Its own deal settles legitimately;
     the agent then calls `record` itself, receives the temporary role, and writes. **R-2 does not
     catch this** — R-2 tests a *direct* write against the resolver, and the agent is no longer
     writing directly; it is being handed the role by our own contract.
   - **One settlement yields unbounded records.** Any caller repeats the same proof, and each gets
     a window. R-4 tests only a revoked client's second *direct* write.

   *Repro:* settle agent A's deal directly with a valid `Reproduced` proof, then have A call
   `record`; the resolver returns A's record. Repeat from B with identical inputs.
   *Catch vector:* A's adapter call after settlement must produce no record, and repeated adapter
   calls for one `dealId` must produce no second window and no second record.

2. **[BLOCKER] `013:§3.4`, against `RecknZkEscrow.sol:176-184`** — **`state == Settled` does not
   mean a proof settled it.** `refundAfterDeadline` writes **the same terminal state** without any
   proof, and `Deal` carries no settlement-kind and no settlement block. Contracts cannot read the
   distinguishing event.

   Consequence: a **withheld but valid** proof can be re-verified *after* a timeout refund and
   produce a "settled job" record — while `settleWithProof` never ran and the seller was never
   paid. The r2 response table's "works regardless of who settled" is therefore overbroad.

   *Repro:* fund, wait 30 days, call `refundAfterDeadline`, then submit a valid bound proof to the
   adapter.
   *Catch vector:* after a timeout refund, the adapter must produce no record.

   **Verified**: `RecknZkEscrow.sol:178` `if (d.state != State.Funded) revert BadState();`
   `:179` `if (block.timestamp < uint256(d.fundedAt) + REFUND_AFTER) revert TooEarly();`
   `:182` `d.state = State.Settled;`. `REFUND_AFTER = 30 days` (`:43`).

3. **[MAJOR] `013:§5 R-9` (the r1 fix for the vacuous key check), against `CLAUDE.md`'s recorded
   mutation hazard** — **the negative control can pass while remaining semantically empty, and it
   prescribes the contaminating pattern.** A check that greps each record contract for a planted
   sentinel goes red when the sentinel is inserted and green otherwise, while a real privileged
   path stays green. Worse, r2 asks for the mutation to be applied in the tracked worktree — the
   exact practice `CLAUDE.md` records as having produced "a plausible lie" that cost a day.

   *Repro:* keep the sentinel-only check, then add an unrelated authority branch letting an agent
   write without settlement. Check stays green.
   *Catch vector:* **dissimilar** privilege mutations must each independently turn the check red,
   applied in an **isolated copy**, with the checked worktree's source hash unchanged afterwards.

   Also noted: R-6's "every root path" presumes the `resource` identity and the adapter-admin
   closure that §3.6 still lists as open.

VERDICT: CHANGES

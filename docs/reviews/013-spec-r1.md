# Review 013 spec round 1

Payload: `/tmp/reckn-payload-013-spec-r1.md`
Codex raw: `/tmp/reckn-codex-013-spec-r1.md`

Target: `docs/specs/013-settlement-granted-record-rights.md` (round 0, never reviewed).
Codex invocations this round: **1** (`-s read-only`). The document under review was drafted by a
Claude agent, so author independence holds.

Tree state: clean at review time; no mutation run in progress, so reads under `zk-verdict/` are
trustworthy (`CLAUDE.md`). `ac008.sh` / `ac009.sh` were **not** run; nothing here depends on them.

**Both blockers were re-verified against the sources before being accepted.** The verification is
recorded inline, because a review that is merely quoted is not a review.

## Findings

1. **[BLOCKER] `013:§3.4` (the adapter), against `zk-verdict/contracts/src/RecknZkEscrow.sol:50-66`
   and `:151-161`** — **the spec's adapter cannot know the verdict it is recording.**
   `struct Deal` carries no outcome field and `enum State` is `None | Funded | Settled`; the
   outcome exists **only in the `SettledByProof` event**. Contracts cannot read logs. Since
   `settleWithProof` is permissionless, any third party may settle a deal directly, after which the
   adapter — which §3.4 specifies as "calls `settleWithProof`, reads the resulting state, grants" —
   has no authenticated source for `Reproduced` vs `Failed`.

   Consequence, both branches bad: either a directly-settled deal can **never** receive a truthful
   record, or the adapter takes the outcome from its caller and **writes false history** — which
   destroys the central claim of this spec more completely than an agent writing its own record
   would, because the record would then look earned.

   *Repro (the conforming implementation that is wrong):* `record(dealId, outcome)` requiring only
   `deals[dealId].state == Settled`, then grant → write → revoke. **Every row R-1…R-9 passes**,
   because every row's fixture has the adapter perform the settlement itself.
   *Catch vector:* settle a `Reproduced` deal directly via `settleWithProof`, then call the adapter
   as an attacker with `FAILED`; resolution must not return a `Failed` record.

   **Verified**: `RecknZkEscrow.sol:56-65` — no outcome field. `:151-161` — `d.state = State.Settled`
   is the only state written; `v.outcome` is used to choose `to` and then only emitted.

2. **[BLOCKER] `013:§3.2`, `§5 R-6`, `§5 R-9`** — **the authority boundary is not closed, and the
   check that was supposed to close it is vacuous.** Two paths, one root:

   - **Token-owner powers.** `RegistryRolesLib` puts `ROLE_SET_RESOLVER` and `ROLE_SET_SUBREGISTRY`
     at *token* level. If the agent owns its subname token, it can point the node at a resolver it
     controls and write arbitrary history — **while the original Permissioned Resolver still
     correctly rejects its direct write**, so R-2 stays green and proves nothing.
   - **Root-resource override.** `IEnhancedAccessControl` has `ROOT_RESOURCE`, `grantRootRoles` and
     `hasRoles(resource, …)` which returns true for a holder of the role **in the root resource**.
     Per-resource scoping is therefore not a boundary against whoever holds root roles on the
     parent registry — and §1.1 already concedes that is us.

   **R-6 checks the wrong object**: it asserts the agent's bitmap on the *record resource*, not
   registry ownership, not root-resource roles, and not resolver replacement. **R-9 is vacuous**:
   `scripts/no-keys.sh` reads `RecknZkEscrow.sol` and does not read the new contracts at all, so it
   exits 0 whatever they contain. This is `CLAUDE.md` R-11 — *a check whose scope is stated by
   exclusion has a hole* — committed by the spec that quotes R-11.

   *Repro:* issue the subname token to the agent and run R-1…R-9 against the original resolver —
   all green. Then have the agent call `setResolver` and resolve an attacker-written record through
   `UniversalResolverV2`.
   *Catch vector:* after issuance, attempt (a) agent `setResolver`, (b) agent `setSubregistry`, and
   (c) every root-role grant path, then assert `UniversalResolverV2` still cannot return a record
   no settlement produced.

3. **[MINOR] `013:§7` (the 2026-09-26 09:00 fallback)** — **timestamped but not decidable.**
   "§3.6 is unresolved" and "§4-1/§4-2 are not standing" name no artifact, no command, and no
   expected output. Under deadline pressure a partial deployment can be called "standing", which
   is exactly the failure the clock was introduced to prevent.

   *Repro:* commit contracts plus a passing named test that never exercises the resource or the
   revocation path; nothing in §7 determines whether the fallback fires.
   *Catch vector:* the predicate must be evaluable from a fresh clone by running named tests.

## Reviewer notes not counted as findings

- §2.3's ENSv2 facts were read, not executed. The spec already says so (§2.3 closing line, §3.6),
  and §7-1 assigns the spikes. Carried, not re-raised.

VERDICT: CHANGES

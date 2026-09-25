# Review 013 tokyo-adapter round 1

Payload: `/tmp/reckn-payload-013-tokyo-adapter-r1.md`
Codex raw: `/tmp/reckn-codex-013-tokyo-adapter-r1.md`

Target: `tokyo-2026/src/SettlementRecord.sol`, `tokyo-2026/test/SettlementRecord.t.sol`,
`tokyo-2026/test/Grief.t.sol`, `tokyo-2026/scripts/join-sepolia.sh`, commits `58ac444` and
`a5b6cd1`. **All written by Claude on 2026-09-25; no Codex wrote any of it**, so Codex is a
legitimate independent reviewer here (`AGENTS.md` §1 author independence).

> **Note added 2026-09-26.** The keystore alias `reckn-arc` was renamed to `reckn-agent` after
> this review was written (the Arc lane is not this lane; the address `0xfa2582ec…` is unchanged).
> The old name is left standing in the text below **because it is a record of what the reviewer
> wrote**, and this repository does not edit records to make them agree with the present.

One Codex call, `-s read-only`, exit 0. Codex could not run Foundry (read-only sandbox blocks
the solidity cache), so **every measurement below is mine**, run from
`/private/tmp/claude-502/-Users-hiroyusai-src-reckn/89c4c9a7-839d-4bdb-b6f5-28bc0de58268/scratchpad/`
against a **fork of Sepolia at block ~11779917**, never in the repo.

Baseline re-run before judging anything (the repo tree, unmodified):
`cd tokyo-2026 && forge test --fork-url sepolia` → **12 passed, 0 failed**. The commit
message's 12/12 is real. It is a *fork* of the real deployment, which is what the test file
says; nothing is over-claimed there.

## Findings

### 1. [BLOCKER] `tokyo-2026/src/SettlementRecord.sol:120` (`setterFor`), `:171-180` (`_grant`) — the grant is scoped to the *key* and to **every name on the resolver**, not to the name. "Writes are granted per record, not per name" is backwards.

**CONFIRMED, measured twice — once by direct call to the deployed resolver, once end-to-end.**

`decodeSetter` on the deployed Sepolia resolver `0x740e02cE…` returns a resource that is a
function of the **key alone**. The DNS name in the setter calldata does not enter it:

```
name=0x03666f6f0362617200                  key=…01 -> resource 48284633010926635023285537874215644136748390042914627119741827470890448441284  roles 16
name=0x056167656e74057265636b6e0365746800  key=…01 -> resource 48284633010926635023285537874215644136748390042914627119741827470890448441284  roles 16
name=0x056167656e74057265636b6e0365746800  key=…02 -> resource   953294445365443513901316475764279849863755124147930262937646684146415383559  roles 16
```

Three different names — including `foo.bar`, which has nothing to do with this deployment, and
the root name `0x00` — yield **one identical resource**. Change the key and the resource moves.
This is `resource(0, partHash(key))`, the resolver's *any-name* resource: `PermissionedResolver`'s
`onlyPartRoles` accepts `hasRoles(resource(0, part), …)` for a write to **any** node
(`tokyo-2026/lib/ens-v2/contracts/src/resolver/PermissionedResolver.sol:178-186`).

So `open`'s `dnsName` — **caller-supplied `bytes calldata` on a permissionless function, derived
from nothing in the deal** — is inert with respect to what is granted, and the buyer receives the
right to write `reckn:job:<dealId>` under *every name this resolver serves*.

Combined with the freedom of the written value (finding 2) and self-dealing (already disclosed in
`013` §1.1), the reachable attack is:

repro — `scratchpad/fk/test/Refute.t.sol::RefuteCombined::test_X_defame_any_agent_in_the_namespace`,
`forge test --fork-url sepolia`, **PASS**:

1. The attacker funds a deal on the real escrow for **1 unit** of a token it minted itself,
   naming its own sock-puppet as seller and the real verifier.
2. It settles it itself, on the repository's own honest `Reproduced` Groth16 fixture.
3. It calls `open(dealId, dnsEncode("victim.reckn.eth"), …)` — a name it does not own and that
   has no connection to the deal.
4. It calls `setText(victim, recordKey(dealId), "failed block=0 verifier=0x0000…0000")`.
5. `UniversalResolverV2.resolve` on `victim.reckn.eth` returns
   `failed block=0 verifier=0x0000000000000000000000000000000000000000`.

Cost: one settled deal of one token unit. No key, no role, no relationship to the victim.

`docs/tokyo-2026/SUBMISSION-FORM.md:148` states *"Writes are granted per record, not per name"*.
The measured property is the opposite along the axis that matters: **per key, across all names.**
`docs/specs/013` §2.4's row *"granularity is per-record: a grant for `job:1` does not authorise
`other:key`"* is true and was measured — but it only ever varied the **key**, never the **name**,
so it certified the half of the claim that holds and never touched the half that does not. Same
shape as `CLAUDE.md`'s "correct sentence sitting on a mechanism doing something else".

### 2. [BLOCKER] `tokyo-2026/src/SettlementRecord.sol:104-117` (`recordValue`), `:186-197` (`open`) — nothing binds the bytes that land in the record to the proof. The outcome is re-derived and then thrown away.

**CONFIRMED.** `open` re-derives `outcome` from `verifyVerdict` and **emits** it. The write is a
separate transaction the buyer sends directly to the resolver, and the grant is role-based on a
resource, not calldata-equality — the `""` value in `setterFor` is decorative. `recordValue` is
`pure` and purely advisory: no on-chain path forces the buyer to call it, or to pass the real
outcome, block, or verifier.

repro — `scratchpad/fk/test/Refute.t.sol::test_F2_the_record_content_is_not_derived_from_the_proof`,
**PASS**: settle with `reexec-falserelease-fixture.json`; `open` returns `outcome == 1` (Failed);
the buyer then writes
`"reproduced block=11779671 verifier=0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608"`, and ENS
resolves exactly that string.

This is the fourth face of `AGENTS.md`'s attack list — *the one place value comes out* — and it is
wide open. The escrow's discipline ("the outcome is never a parameter") is enforced up to the
event and abandoned at the only place a reader looks. `013` §1.1 says *"this does not make a
record true"*, which covers a buyer lying about a judgement call; it does **not** cover a buyer
inverting a verdict the chain just proved. The demo's money shot —
`"reproduced block=11779671 verifier=0xe0de264d…"` resolving through UniversalResolverV2
(`docs/tokyo-2026/RECEIPTS.md:150-156`) — is a string a human typed, presented in a frame that
invites the reader to believe the chain produced it. **That is a tier violation** (`AGENTS.md` §5:
a `pure` formatter's output reported as an on-chain record).

Note both 1 and 2 are **unfixable inside the adapter** with this resolver ABI: `grantSetterRoles`
cannot express "this name only" or "these bytes only". The fix is to the claim and the demo, not
to a line of Solidity — see the closing note.

### 3. [MAJOR] `tokyo-2026/test/SettlementRecord.t.sol` — **7 of the 9 acceptance rows pass against an adapter that grants nothing at all.**

**CONFIRMED by mutation, run outside the repo.** I copied `SettlementRecord.sol` to
`scratchpad/mut/src/`, replaced line 180 `resolver.grantSetterRoles(setter, buyer);` with a
comment, and ran the repo's own two test files against it on the same fork:

```
[PASS] test_R10_an_attacker_cannot_record_a_false_outcome
[PASS] test_R12_no_second_window
[PASS] test_R12_the_agent_calling_open_still_cannot_write
[PASS] test_R13_a_refund_is_not_recordable_and_the_control_arm_passes
[PASS] test_R2_the_agent_cannot_write_its_own_record
[FAIL] test_R4_the_window_closes_after_the_write
[PASS] test_R7_failed_is_recorded_as_failed
[PASS] test_R8_an_unsettled_deal_has_no_window
[FAIL] test_join_settlement_opens_the_window_and_the_buyer_writes
7 passed; 2 failed
[PASS] test_L1_…   [FAIL] test_L2_…   [PASS] test_L3_…
2 passed; 1 failed
```

So the mutant "an adapter that opens a window and grants no right" is caught by exactly **3 of 12
rows**: the join, R-4, and L-2. The author's own diagnosis in `58ac444` was right and is worse
than stated — it is not that the nine rows lacked *a* positive row, it is that **seven of them
certify a contract that does nothing.** R-13's advertised "control arm" is the clearest case: the
arm only calls `open`, so it controls for nothing that the row is about.

L-3 is on the wrong side of this too: it passes under the mutant, because its closing
`vm.expectRevert()` is satisfied by the write reverting for the reason it *always* reverts when no
grant ever happened.

repro: `cd scratchpad/mut && forge test --fork-url sepolia`.

### 4. [MAJOR] `tokyo-2026/src/SettlementRecord.sol:212` — the `close` guard prices the griefing weapon at one day of the buyer's attention. It does not remove it.

**CONFIRMED.** `opened[dealId]` is one-shot and never resets; `open` is permissionless; `openedAt`
is set by whoever calls `open`. The attacker therefore still chooses the moment the clock starts
(`test_F4_attacker_controls_openedAt`, PASS), waits `WRITE_WINDOW`, and closes.

repro — `scratchpad/fk/test/Refute.t.sol::test_F3_delayed_grief_still_bricks_the_record`, **PASS**:
attacker `open`s the settled deal; `vm.warp(+1 days)`; attacker `close`s; the buyer's `setText`
reverts and `rec.open(...)` reverts `AlreadyOpened`. The record is unwritable by anyone, forever,
for the cost of two transactions and one day.

The guard is a strict improvement — same-block destruction is gone, and the L-1/L-2/L-3 triple is
the right shape — but the weapon it was written against is still loaded. What makes the deal
brickable is not who may `close`; it is that `open` is permissionless *and* single-shot *and* has
no re-open. **Point 1 therefore survives only in part: the guard is correct and necessary, and it
is not sufficient.** None of the author's other named worries are real: `uint64` truncation of
`block.timestamp` needs year ≈584942417355; `openedAt + WRITE_WINDOW` cannot overflow `uint64` at
any reachable timestamp; a contract writer that reverts changes nothing, because `close` never
calls the writer (only `resolver.revokeRoles`).

### 5. [MAJOR] `tokyo-2026/scripts/join-sepolia.sh:23` — the live adapter `0x6691283d…` does not have the fix, and the ordering constraint in `RECEIPTS.md` means it cannot simply be left there.

**CONFIRMED against the live chain**, not the fork:

```
cast call 0x6691283d8B77E1e22D08836c55E3f952c304Ccc1 "WRITE_WINDOW()(uint64)"   -> execution reverted
cast call 0x6691283d8B77E1e22D08836c55E3f952c304Ccc1 "openedAt(bytes32)(uint64)" -> execution reverted
cast call 0x6691283d8B77E1e22D08836c55E3f952c304Ccc1 "opened(bytes32)(bool)"     -> false
```

The commit message says so honestly ("The adapter at 0x6691283d is NOT yet redeployed with this
fix") — that is not the finding. The finding is the interaction with
`docs/tokyo-2026/RECEIPTS.md:164-172`: root **cannot** be renounced until the adapter is
redeployed, and the video's beat 2 **cannot** be shot until root is renounced. So the redeploy is
on the critical path of the demo, and it must not happen before findings 1 and 2 have been
answered — otherwise the thing on chain when the judges look is the version this review is about.

### 6. [MINOR] `tokyo-2026/src/SettlementRecord.sol:177` — `ResourceIsRoot` is unreachable, and the belief that motivated it is what produced finding 1.

**CONFIRMED.** The measured resource is a keccak image of the key alone (finding 1): zero is
unreachable for any non-empty key, and `recordKey(dealId)` is never empty. The check costs one
`SLOAD`-free comparison and is harmless — keep it. But the author's stated uncertainty
("I do not know whether it can vary per name or per key") resolves to: **it varies per key and
never per name**, and that is exactly the leak. **Point 2 survives as code and fails as
reasoning.**

### 7. [MINOR] `tokyo-2026/test/SettlementRecord.t.sol:127, 147, 233`, `Grief.t.sol:127` — bare `vm.expectRevert()`.

Every negative row accepts *any* revert. The revert R-2 actually gets today is
`0x4b27a133` = `EACUnauthorizedAccountRoles(resource, 0x10 /*ROLE_SET_TEXT*/, agent)` — verified
by trace. Pinning it costs one argument, and `013` §2.4 already records this exact lesson
("asserting the outer selector proves nothing, and the first version of that test asserted the
wrong field"). Combined with finding 3, a bare `expectRevert` is what lets a no-grant contract
look like a correctly-permissioned one.

### 8. [MINOR] `tokyo-2026/test/SettlementRecord.t.sol:32, 60` and the live setup — the adapter is granted `ALL_ROLES` at the root resource.

`0x1111…1111` includes nybble 31, `ROLE_UPGRADE` (UUPS) and nybble 30, `ROLE_CAN_NAME`
(`PermissionedResolverLib.sol:57-65`). The adapter has no path that uses them, so nothing is
exploitable today, but it means a contract holding **root** on the resolver is the thing the
central claim now rests on, and `scripts/no-keys.sh` does not read `tokyo-2026/` at all — it reads
only `RecknZkEscrow.sol` and `RecknVerdictVerifier.sol`. The build condition that enforces
"no key decides" is silent about the surface this submission is built on. Say so out loud, or
grant the minimum (`ROLE_SET_TEXT_ADMIN`).

## Rejected findings

- **Codex 2, BLOCKER: "the live Sepolia configuration still has a key that decides whether the
  agent can write — `reckn-arc` holds root and its direct write succeeds."** Rejected *as a
  finding*. It is disclosed in advance and in the right places, with the right wording:
  `docs/specs/013` §1.1 (*"★ The claim is narrower than 'nobody can forge a record'… if renouncing
  proves impossible on the beta, the residue is disclosed and the claim stays narrow. We do not
  write 'nobody'"*), `docs/tokyo-2026/RECEIPTS.md:164-172` (*"the last row is the residue"*), and
  the `a5b6cd1` commit message (*"BEAT 2 IS NOT HERE, and its absence is the honest kind"*). A
  reviewer rediscovering a disclosed residue has not found a defect. The operational half of
  Codex's point — the fixed adapter is not deployed — is real and is my finding 5.
- **Codex 1's framing that this "directly defeats R-10".** Rejected. R-10 asserts that `open`
  refuses a valid proof of a different deal with `BindingMismatch`, and that holds — it passes on
  the clean tree and on the no-grant mutant, and I could not get any other proof through
  `_authorise`. What is defeated is the *record*, not R-10. Precision matters here because R-10 is
  the row a judge will be shown.
- **Codex: "close guard: survives."** Partially rejected — see finding 4. It survives as an
  improvement, not as a closure; a one-day-delayed brick is still a brick, and I have it passing.
- **Codex 3's scope ("R-7 and R-13").** Accepted but too small: measured, it is 7 of 9 plus L-3.

Checked and found clean, so recorded here rather than raised:

- **Reentrancy.** `verifyVerdict` is `public view` (`RecknVerdictVerifier.sol:50-53`), so the call
  to funder-chosen code is a STATICCALL; the only state-changing external call in `open` is to the
  `immutable` resolver, and `opened[dealId] = true` precedes it. `close` writes `closed` before
  `revokeRoles`. No path found.
- **"Settled before the refund deadline" ⇒ proof-driven.** Holds. `State.Settled` is written in
  exactly two places (`RecknZkEscrow.sol:152, :182`), `fund` refuses a non-`None` deal (`:104`),
  so `fundedAt` cannot be refreshed, and `refundAfterDeadline` cannot execute before
  `fundedAt + REFUND_AFTER` (`:179`). The 30-day cost is stated, not hidden.
- **Binding.** No path found where a proof of a different execution opens this deal.
  `extcodehash` is compared against the funder's pin before the call, and `BindingMismatch`
  rejects the other fixture (measured).

## Deferred

- **The v4 `beforeSwap` hook reads the record** (`013` §3.1, `SUBMISSION-FORM.md:151-157`). If the
  hook gates on "a settled record exists under this agent's name", finding 1 is a **gate bypass**:
  anyone can plant a record under any agent's name for one token unit. The hook is not in this
  diff, so it is not judged here → `docs/decisions/013-hook-reads-a-plantable-record.md` to be
  written before the hook lands.

VERDICT: CHANGES

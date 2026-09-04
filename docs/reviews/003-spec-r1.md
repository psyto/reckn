# Review 003 spec round 1

Payload: `/tmp/reckn-payload-003-spec-r1.md`
Codex raw: `/tmp/reckn-codex-003-spec-r1.md`

Reviewed: `docs/specs/003-key-gauntlet.md` (931 lines, written by Claude Code — stated in the
payload so Codex was not grading its own homework).
Codex: `codex exec -C /Users/hiroyusai/src/reckn -s read-only`, one call, round 1.

Every finding below was re-checked against the files on disk before being kept. Findings 1, 2,
4, 6, 7, 10 are mine; 3, 5, 8, 9, 11 originate with Codex and were verified line by line.
Foundry in this environment is **1.7.1** (`forge --version`); the two empirical repros below
were run today, not quoted from a previous round.

---

## Findings

### 1. [BLOCKER] `docs/specs/003-key-gauntlet.md:365`, `:436-573` — 11 of the 18 acceptance criteria are satisfied by writing no tests at all

§5 opens with: *"Every AC is (a) a command whose exit status decides it."* That sentence is
**false for 11 of the 18 ACs**. `forge test --match-test <pattern>` exits **0** when the
pattern matches nothing, and `--match-path` likewise.

Repro (run 2026-09-04, `zk-verdict/contracts`, forge 1.7.1):

```sh
cd zk-verdict/contracts
forge test --match-test "testFuzz_AC02_does_not_exist"; echo "EXIT=$?"
# No tests found in project! ...
# EXIT=0
forge test --match-path "test/KeyGauntletInvariant.t.sol"; echo "EXIT=$?"
# No tests found in project! ...   (file does not exist)
# EXIT=0
```

So AC-2 (`:436`), AC-3 (`:454`), AC-4 (`:467`), AC-5 (`:480`), AC-6 (`:494`), AC-7 (`:509`),
AC-8 (`:520`), AC-9 (`:532`), AC-10 (`:544`), AC-11 (`:560`) and AC-12 (`:573`) all go green
against an implementation in which `KeyGauntlet.t.sol`, `KeyGauntletFuzz.t.sol` and
`KeyGauntletInvariant.t.sol` **were never created**. That is the degenerate implementation the
founder asked for: it is not exotic, it is the empty one.

This is the exact failure the sibling project's specs 001/002 hit three rounds running. The
mutant list does not save it — mutants are only consulted by AC-14, and AC-14 is a script the
same implementer writes.

**Required change.** Every `forge test` AC must assert the number of tests that ran, not merely
the exit status. Either pass `--fail-on-no-tests` (forge 1.7 supports it — confirm in the
implementation, do not assume) *and* assert a minimum count, or wrap each AC in a check that
greps `Suite result:` / `passed;` for a non-zero passed count. The AC text must state the
expected count so "0 passed" cannot read as success.

### 2. [BLOCKER] `docs/specs/003-key-gauntlet.md:494`, `:520` — AC-6 and AC-8's commands match zero tests even when the tests exist

`--match-test` takes **one regex**, not a space-separated list. `"test_AC06 testFuzz_AC06"` is a
regex containing a literal space; no Solidity function name contains a space.

Repro (against two tests that really exist today):

```sh
cd zk-verdict/contracts
forge test --match-test "test_real_proof_settles_to_seller test_failed_verdict_refunds_buyer"
echo "EXIT=$?"
# No tests found in project! ...
# EXIT=0
```

This is worse than finding 1 because it fails for a *correct* implementation. AC-6 is the
binding criterion — §5 calls it *"the 'another convenient execution cannot settle this deal'
acceptance condition"*, i.e. INV-9, i.e. the property that makes the whole product sound. As
written it is guaranteed vacuous. AC-8 (the `UnderFunded` criterion protecting other deals'
principal) is guaranteed vacuous by the same typo.

**Required change.** `--match-test "test_AC06|testFuzz_AC06"` and
`--match-test "test_AC08|testFuzz_AC08"`, plus the count assertion from finding 1.

### 3. [BLOCKER] `docs/specs/003-key-gauntlet.md:138-145`, `:396-415` — nothing counts the ERC-20 `transfer` call sites, so a caller-gated third exit inside `fund` passes every check

**Codex's finding, verified.** §3.1:138 asserts *"there are exactly **two** such call sites"*
(L1, L2), and :145 concludes *"AC-1 turns each of those into a build condition, so the
enumeration cannot silently grow."* The second clause does not follow. AC-1's new checks 5–8
(`:401-415`) cover base contracts, `fallback`/`receive`/`assembly`/`tx.origin`/`.call(`/
`.call{`/`staticcall`, `msg.sender` placement, and constructor assignments. **None of them
counts `transfer` call sites, and none of them constrains what `fund` may do.** The entire
"basis of exhaustiveness" therefore rests on an unenforced sentence.

Degenerate implementation, inserted in `fund` after the `DealExists` guard and before the
measured baseline:

```solidity
if (address(uint160(0x1337)) == msg.sender) {
    IERC20Min(token).transfer(msg.sender, IERC20Min(token).balanceOf(address(this)));
}
```

The holder of that key calls `fund` with a fresh `dealId`, a nonzero `dealBinding` and
`amount == 0`. It drains every escrowed balance of `token`, then C-4's delta check observes
`0 → 0 == amount` and the deal is created. Why nothing catches it:

- `no-keys.sh` check 1 (`scripts/no-keys.sh:35`) — no forbidden word appears; a bare address
  literal is not `admin`/`owner`/`authority`.
- check 3 (`scripts/no-keys.sh:58`) matches `require( msg.sender` / `if ( msg.sender`; the
  comparison is inverted, so it does not match.
- AC-1 check 7 (`:408-412`) forbids `msg.sender` **only** in `settleWithProof` and
  `refundAfterDeadline` — it is expressly permitted in `fund`.
- check 5 / 6 / 8 — no inheritance, no fallback, no low-level call, no constructor assignment.
- AC-11 fuzzes `fund` only against an **existing** `dealId` (reverts `DealExists`, so the drain
  is rolled back); AC-8 funds from the test's own buyer; AC-2's fuzz is over `settleWithProof`.
- AC-10's invariant handler would break INV-4, but only if its fuzzed actor set draws
  `0x1337` — probability ~2^-160.
- No mutant M-1…M-34 models a `transfer` inside `fund`.

Corollary worth stating separately: **M-1 (`:447`) is not actually killed by AC-2 either.** AC-2
is a caller fuzz; it will not draw `0x5E11E5`. The spec calls M-1 *"the failure mode this project
has hit three times"* and pairs it with a criterion that cannot kill it. AC-14 will surface this
as a surviving mutant — which is the harness working — but the fix must be a *structural* check,
not adding `0x5E11E5` to a caller list, since the next backdoor picks another constant.

**Required change.** Add a `no-keys.sh` check that the contract body contains exactly the
enumerated token call sites: `transferFrom` appears once and only inside `fund`; `.transfer(`
appears exactly twice, once inside `settleWithProof` and once inside `refundAfterDeadline`. Add
the code above as a mutant and require it killed by that check. Until then, §3.1:145's
"cannot silently grow" must be deleted — it is an unearned claim of the exact kind
`AGENTS.md` §5 forbids.

### 4. [MAJOR] `docs/specs/003-key-gauntlet.md:367`, `:698` — the mutation harness mutates a parallel copy, not the contract under test

Mutants live in `zk-verdict/contracts/test/mutants/MutantZkEscrow.sol`, "one contract with an
`immutable uint256 MUT` selecting the mutation", and M-0 is described as "an unmodified copy".
**No AC requires `MutantZkEscrow` at `MUT == 0` to be derived from `RecknZkEscrow.sol`.**
Mutation testing that mutates a duplicate proves the tests kill mutations *of the duplicate*.

Repro: apply finding 3's backdoor to `RecknZkEscrow.sol` and to nothing else. `MutantZkEscrow`
is untouched, so AC-14's table still reports "34 mutants, 34 killed, M-0 survives", AC-0/AC-1
pass, AC-2…AC-12 pass, and the money-shot prints. The harness certifies a contract that is not
the one that holds the money.

Contrast `scripts/no-keys-selftest.sh` (AC-1), which does this correctly: it patches the real
source text and runs the real script against it.

**Required change.** Either generate `MutantZkEscrow.sol` from `RecknZkEscrow.sol` at test time
and fail if the `MUT == 0` path is not byte-identical to the source modulo the dispatch
scaffolding, or drop `MutantZkEscrow.sol` and drive M-1…M-12 / M-20…M-27 / M-33 / M-34 as
source-text patches to the real file, the way M-13…M-19 already are.

### 5. [MAJOR] `docs/specs/003-key-gauntlet.md:310-316` — INV-1, the headline invariant, is false as written, and its one true clause is unchecked

**Codex's finding, verified and sharpened.** INV-1 quantifies over *"every entry point `f` …
and every pair of addresses `a, b`"*, then in its own last clause concedes that `fund` records
`msg.sender` as `buyer` and pulls from it. Two callers of `fund` with identical arguments
therefore produce different state. The universal statement is false, so it cannot be checked,
and an invariant that cannot be checked is decoration on the most load-bearing line in the spec.

Worse: the clause that *is* true — *"`fund` uses `msg.sender` only as the recorded `buyer` and
the `transferFrom` source"* — has **no AC and no mechanical check behind it**. It is written as
an assertion of fact about code that has not been written. That is precisely the gap finding 3
walks through.

**Required change.** Restate INV-1 as two propositions: (a) `settleWithProof` and
`refundAfterDeadline` are caller-independent — enforced by AC-1 check 7 and AC-2/AC-3; (b) `fund`
depends on `msg.sender` in exactly two authorized ways, `buyer := msg.sender` and
`transferFrom(msg.sender, …)` — and give (b) the mechanical check from finding 3, so it is an
invariant rather than a sentence.

### 6. [MAJOR] `docs/specs/003-key-gauntlet.md:245-250` vs `:333-338` — C-5's exact-equality payout check re-opens the permanent-lock gap that 001 exists to close, and INV-8's stated condition is too narrow to cover it

C-5 makes `settleWithProof` and `refundAfterDeadline` revert `PayoutFailed()` *"unless [the
escrow balance] decreased by **exactly** `d.amount`."* INV-8 then conditions liveness on
*"the token's `transfer` to `d.buyer` **not reverting**."*

Those two are not the same condition. A token whose `transfer` **succeeds** but moves anything
other than exactly `d.amount` makes both exits revert **forever**, and the deal is stuck in
`Funded` with no escape — which is exactly the lock-up that `README.md:566-571` lists as the
open gap and that 003 is chartered to close.

G-21 blocks *symmetric* fee-on-transfer tokens at `fund`, so the reachable class is narrower
than "any weird token", but it is non-empty and does not require a malicious token:

- outbound-only fee (inbound exempt, or the escrow inbound-exempt), which funds cleanly and
  bricks on payout;
- rebasing / share-accounted tokens (stETH-shaped) where the sender-side decrease differs from
  `d.amount` by rounding, or where a rebase between `fund` and payout moves the balance.

§8:841's token bullet covers only *"a token that **lies** about balances"*. An honest rebasing
token does not lie, and it bricks the deal. This residual is **created by 003** and is stated
nowhere.

**Required change.** Pick one and say which: (a) keep exact equality and rewrite INV-8's
condition to *"conditional on the token's outbound transfer moving exactly `d.amount`"*, add the
class to §8, and add a `disclosed` matrix row for "funds cleanly, cannot pay out, permanently
stuck"; or (b) make C-5's payout check `decrease >= d.amount` guarded by a recipient-side check
and re-derive INV-6. Do not leave INV-8 and C-5 asserting different things.

### 7. [MAJOR] `docs/specs/003-key-gauntlet.md:217-228`, `:112-124` — the buyer obtains, by choosing the deployment, exactly the timing discretion C-2 rejects, and it has no matrix row

C-2:225-228 rejects a buyer-supplied per-deal deadline in these words: *"it lets the buyer pick a
deadline in the past and front-run a late proof, which is discretion over the seller's payout,
i.e. the thing the product says it does not have."* Correct — and then the same discretion is
reachable by another route the spec leaves open:

`MIN_REFUND_DELAY = 1 hours`; a deal has no seller acceptance step (OQ-4:926 concedes the seller
learns the terms only from the `Funded` event and never signals agreement on-chain); the buyer
chooses which deployment to fund into. So: deploy a 1-hour escrow, fund, take delivery, and call
`refundAfterDeadline` at t = 1h while the Groth16 proof is still being generated. The buyer keeps
the work and the money, using only permissionless calls. No key is involved, which is why the
gauntlet will not see it — and why it must be a row rather than a footnote.

§2.3:112-124 frames deployment choice as *"identical in kind to choosing which contract address to
send money to."* That equivalence holds for the buyer's own principal. It does not hold for the
seller, whose payment is the thing at risk. §8:844-848's post-deadline-race bullet frames this as
a neutral race between two authorized outcomes; it is not neutral when one party picks the clock.

**Required change.** Add a `disclosed` row (G-33) — *buyer funds a deployment whose `refundDelay`
is shorter than the proving time and refunds a delivered job* — with the expected result stated
honestly (it succeeds; it is not theft under the contract's rules; the seller's only defence is
the pre-funding check). Extend §2.3's pre-funding check from `verifier` + vkey to
`verifier` + vkey + `refundDelay`, and say in §8 that the seller must perform it. Re-derive the
row and class counts in §3.2 and AC-13. If `MIN_REFUND_DELAY` is meant to be the mitigation, state
the proving time it is being compared against — measured, not assumed (`AGENTS.md` §5).

### 8. [MAJOR] `docs/specs/003-key-gauntlet.md:74-97`, `:613-628`, `:827-856` — the money-shot claims the published keys were exercised; §8 does not disclose that they were not

**Codex's finding, verified.** §2.1:74-77 says the gauntlet *publishes five private keys*. §7.2's
banner prints a `private key (published)` column and §5 AC-15:627 mandates the closing line
`32/32 rows as specified. Keys published: 5. Keys that helped: 0.` But the 32 rows run in
Foundry, where `vm.prank` impersonates an address **without touching its private key**. OQ-1:908
states this plainly and then leaves it unresolved as a founder call.

So the spec knows the limitation and puts it in §10 (open questions) while §8 (*"What this does
not prove"* — the section whose entire job is to hold the honest residuals) omits it. A judge
reading the money-shot concludes the keys were used and bought nothing; what was actually shown is
that those five *addresses* bought nothing.

**Required change, independent of how OQ-1 is decided.** Add to §8: *"Foundry `vm.prank`
impersonates an address without using its private key; the 32 rows demonstrate address-level
behaviour, not that any published key was exercised."* And either implement OQ-1's anvil mode for
G-03/G-13/G-14 with real signatures, or change the money-shot to name what was tested
("Addresses under test: 5. Addresses that helped: 0."). Do not print "keys" for a run in which no
key signed.

### 9. [MAJOR] `docs/specs/003-key-gauntlet.md:615-618` — AC-15's second command contradicts its own comment, so the AC cannot pass on an honest run

**Codex's finding, partially accepted.** The AC is:

```sh
bash scripts/gauntlet.sh
git diff --exit-code docs/gauntlet.json   # exit 0 after ignoring generated_at/commit
```

`git diff --exit-code` has no field-ignore behaviour. `gauntlet.sh` is required (§7.1) to write a
fresh `generated_at`, so a real run always makes the second command exit 1. "After ignoring" is
prose in a comment, not part of the command — the same defect family as findings 1 and 2: the AC's
prose and its exit status disagree, so whoever implements it will reinterpret it privately.

**Required change.** Normalize before diffing, e.g.

```sh
bash scripts/gauntlet.sh
git show HEAD:docs/gauntlet.json | jq 'del(.generated_at, .commit)' > /tmp/a.json
jq 'del(.generated_at, .commit)' docs/gauntlet.json > /tmp/b.json
diff -u /tmp/a.json /tmp/b.json
```

or have `gauntlet.sh --check` do the comparison itself and expose it as one exit status.

### 10. [MINOR] `docs/specs/003-key-gauntlet.md:680-682`, `:698`, `:721-723` — M-34 is counted as a behavioural mutant but no AC names it, so AC-14's procedure is undefined for it

AC-14:603 says *"for each mutant `M-n` in §5, run the AC that names it and assert it fails."*
`M-34` is named at :680, :682, :698 and :723 and appears in **no** `Kills:` list. §6.3:721
independently narrows to *"Every M-1 … M-33"*, excluding it. AC-14 also requires the count line
`N mutants, N killed` to be compared against the number of `M-` identifiers in the file — which is
37 (verified: `grep -oE 'M-[0-9A-F]+' … | sort -u | wc -l` → 37), so the arithmetic will not close.

**Required change.** Attach M-34 to AC-17 (a revert-everything contract fails AC-17 and every
authorized row) with an explicit `Kills:` entry, and reconcile §6.3:721's range.

### 11. [MINOR] `docs/specs/003-key-gauntlet.md:41-43`, `:671` — "five tests" is four

Raised by Codex; independently verified before acceptance:

```sh
grep -n "function test" zk-verdict/contracts/test/RecknZkEscrow.t.sol
# 38: test_real_proof_settles_to_seller
# 93: test_failed_verdict_refunds_buyer
# 104: test_settle_reverts_on_binding_mismatch
# 117: test_settle_reverts_on_unverified_proof
```

Four. The other four `function` declarations in that file are `setUp`, `_fund`, `_mockEscrow`,
`_pv`. Small, but it is a count asserted from memory in a document whose §8 is about not doing
that (`AGENTS.md` §5). Fix both sites.

### 12. [MINOR — founder call] `docs/specs/003-key-gauntlet.md:416-419` — the `no-keys.sh` target override changes what the script's exit status is a statement about, and the guard against misuse is prose

I did **not** find the AC-1 changes to be a loosening in substance: checks 5–8 and the two-sided
check 2 are all strictly stronger, and the default target is unchanged. Codex agrees. One point
still needs a founder decision rather than an agent one.

`AGENTS.md` §0 states that changes which loosen this check are the founder's call, and §7 makes
"`no-keys.sh` failed" a stop condition. Introducing `bash scripts/no-keys.sh [path]` means the
sentence "no-keys.sh passed" is no longer unambiguously about `RecknZkEscrow.sol`. The spec's
mitigation is that an override run must print `✓ (target override: <path>)` — but the AC that
enforces it is a comment (`:423`: *"exit 0, and the output has no 'target override'"*), not a
command, so it is unchecked exactly like findings 1/2/9.

**Required change.** Make it mechanical — `bash scripts/no-keys.sh | tee /tmp/nk.txt; grep -q
'target override' /tmp/nk.txt && exit 1` or equivalent inside `gauntlet.sh --check` — and get
founder sign-off on introducing the override at all, since it is a change to the semantics of the
one build condition `AGENTS.md` §0 reserves to the founder.

---

## Rejected findings

- **Codex #3's sub-claim that §7.1's JSON "duplicates the `tier` key".** False. `tier` occurs
  exactly once in the schema block:
  `sed -n '755,800p' docs/specs/003-key-gauntlet.md | grep -c tier` → 1. The rest of Codex #3
  (the `git diff --exit-code` contradiction) is accepted as finding 9.

- **Codex's adjudication that AC-1's `no-keys.sh` changes are "not a loosened check" — accepted
  in substance, but not as a full clearance.** Retained as finding 12 at MINOR with an explicit
  founder flag, because the override's guard is unenforced.

## Checked and found sound (recorded so round 2 does not re-litigate)

- **The four task-001 acceptance conditions are all present, none softened** (`AGENTS.md` §3).
  (a) any address after the deadline → G-13 (`:180`) + G-14 (`:181`), AC-3 (`:451-462`), which
  fuzzes both the caller and `t ∈ [deadline, deadline + 3650 days]` and asserts the caller
  receives 0; (b) nobody before it → G-11 (`:178`), AC-4 (`:464-475`), fuzzed caller × fuzzed
  `t ∈ [fundedAt, deadline-1]` **plus** the exact boundary pair `deadline-1` / `deadline`;
  (c) refund dead after settle → G-16 (`:183`), AC-5 (`:477-490`); (d) reverse order does not
  pay twice → G-17 (`:184`), AC-5, using a genuinely valid late `Reproduced` proof rather than a
  mock. Mapping verified row by row. The *criteria* are sound; findings 1 and 2 are about the
  commands that run them, not about these conditions.
- **AC-16's two SHA-256 digests are correct.** I recomputed both with the spec's own `awk`
  recipe: `8f65b75f…9a6cac1` and `9e5facfd…14689af`. Both match `:647-648` exactly. The
  heading-anchored extraction is drift-proof as claimed.
- **§3.2's counts are correct.** Mechanical recount of the table: 32 rows, 20 theft, 7
  authorized, 5 disclosed — matches `:201-202` and AC-13's assertion.
- **The mutant-identifier count is correct.** 37 unique `M-` ids (M-0…M-34 plus M-A, M-F),
  matching `:680`.
- **INV-9's binding formula matches the guest.** `keccak256("reckn/zk/bind/evm/v1" ‖ state_root ‖
  address ‖ slot ‖ min ‖ max ‖ keccak(plan))` at `:326-329` is exactly
  `zk-verdict/program-revm/src/main.rs:178-190`, and `plan_hash` covers caller ‖ target ‖
  calldata ‖ value. `u64_low` limb-0 truncation is correctly located at `main.rs:163-164`
  (INV-10, `:345-348`).
- **C-7's claim that no off-chain code consumes the escrow ABI holds.** The only non-test hits
  outside prose are `zk-verdict/scripts/zk-e2e.sh:85,95`, which grep test *names*, and
  `scripts/no-keys.sh`, which reads the source. Event-signature changes break nothing.
- **The scope question (founder uncertainty #2) resolves in favour of the spec.** The C-4
  `transferFrom` fix is inside the 003 cut, not outside it: today's `RecknZkEscrow.sol:86`
  discards the boolean, so a token that returns `false` without reverting creates a `Funded`
  deal backed by nothing, whose later payout comes out of *other deals' principal in the same
  token*. A gauntlet that publishes every key while shipping a live same-token drain is not a
  gauntlet — the artifact would be false in the exact way §1's failure definition names. Codex
  independently reached the same cut. **The correct line, stated so 004 can hold it:** 003 may
  change `RecknZkEscrow.sol` only where a matrix row would otherwise have no true expected
  result. C-1…C-5 and C-7 meet that test; C-6 is a non-change. The line excludes SafeERC20,
  permit, cancellation, splits, and any view helper (N-3, N-6) — correctly excluded already.

---

## Deferred

None. Every finding above is inside 003's frame and must be resolved in it; `docs/decisions/`
does not exist and no finding needs it.

---

## What must change before round 2

1. Count assertions on all 11 `forge test` ACs (finding 1).
2. `|` instead of a space in AC-6 and AC-8 (finding 2).
3. A `no-keys.sh` check that pins the token call sites to L1/L2 + `fund`'s `transferFrom`, a
   mutant for the in-`fund` drain, and deletion of §3.1:145's unearned "cannot silently grow"
   (finding 3).
4. Mutants derived from the real source, or generated from it with a byte-identity check on
   `MUT == 0` (finding 4).
5. INV-1 split into a checkable pair, with `fund`'s two authorized uses of `msg.sender`
   mechanically enforced (finding 5).
6. INV-8's condition reconciled with C-5, plus a §8 residual and a disclosed row for
   funds-cleanly-cannot-pay-out (finding 6).
7. A new disclosed row G-33 for the short-window deployment, `refundDelay` added to §2.3's
   pre-funding check, and the §3.2 / AC-13 counts re-derived (finding 7).
8. The `vm.prank` limitation moved into §8, and the money-shot line reworded or OQ-1 implemented
   (finding 8).
9. AC-15's diff normalized (finding 9).
10. M-34 attached to an AC, §6.3's range reconciled (finding 10).
11. "five tests" → four at `:41` and `:671` (finding 11).
12. The override banner made mechanical, and the override itself put to the founder (finding 12).

Findings 7, 8 and 12 also carry decisions that are the founder's, not an agent's: the shape of
the short-window disclosure, whether OQ-1's signed-anvil mode is built, and whether
`no-keys.sh` gains a target argument at all.

VERDICT: CHANGES

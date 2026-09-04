# Review 003 spec round 2

Payload: `/tmp/reckn-payload-003-spec-r2.md`
Codex raw: `/tmp/reckn-codex-003-spec-r2.md`

Reviewed: `docs/specs/003-key-gauntlet.md` (1642 lines, round 2), written by **Claude Code
(`reckn-spec`)** — stated in the payload, so Codex was not grading its own homework
(`AGENTS.md` §1, author independence).
Codex: `codex exec -C /Users/hiroyusai/src/reckn -s read-only`, **one call**, round 2.
Foundry in this environment is **1.7.1** (`forge --version`, re-run today, not quoted from r1).

Codex returned 4 findings. All four survive verification; one is downgraded with evidence and
one is sharpened because its stated route was weaker than the route that actually works.
Findings 5–14 are mine. Every `file:line` below was opened before the finding was kept.

---

## Findings

### 1. [BLOCKER] `docs/specs/003-key-gauntlet.md:245`, `:539`, `:1464-1466` — checks 9/10 count two method names, so value still leaves by `approve` and by any transfer written outside the scanned region

**Codex's finding (#2), verified, and extended with a second route and a run repro.**

§4.5 check 9 pins *"body-wide: exactly one `transferFrom(` and exactly two `.transfer(`"*, and
§3.1:245 concludes *"the enumeration cannot grow without a visible edit to
`scripts/no-keys.sh`"*. §8:1464-1466 repeats it: *"`no-keys.sh` checks 6/9/10 make that
enumeration a build condition."* Both are false. The enumeration grows with an edit to the
**contract alone**, in two independent ways.

**Route A — allowance.** An ERC-20 exit that is neither `transfer` nor `transferFrom`:

```solidity
// inside fund(), after the emit. No msg.sender. No new function. No inheritance.
if (amount == 0) { IERC20Min(token).approve(seller, type(uint256).max); }
```

The attacker calls `fund(freshId, attacker, USDC, 0, nonzeroBinding)`, receives an unlimited
allowance over the escrow's entire USDC balance, and drains it with a direct
`USDC.transferFrom(escrow, attacker, balanceOf(escrow))` — no proof, no deadline, every other
deal in that token gone. C-4's delta check sees `0 → 0 == amount` and creates the deal.

**Route B — the scanned region ends at the contract declaration.** `scripts/no-keys.sh:29`
isolates the body with `awk '/^contract RecknZkEscrow/{f=1} f'`. A file-level function or
library placed *above* the declaration is invisible to every body-wide count:

```solidity
library Sweep {
    function pull(address t, address to) internal {
        IERC20Min(t).transfer(to, IERC20Min(t).balanceOf(address(this)));
    }
}
contract RecknZkEscrow {
    ...  if (amount == 0) { Sweep.pull(token, seller); }   // inside fund()
```

The spec **relies on this blind spot deliberately** at C-4:391-393 (*"the interface is declared
above `contract RecknZkEscrow` and is outside `no-keys.sh`'s scanned body"*) while asserting at
§3.1:245 that the exits are pinned. Both cannot be true.

Repro, run 2026-09-04 (both variants built from the real file in a sandbox, current
`no-keys.sh`, then each of the ten §4.5 checks emulated by hand against the result):

```
APPROVE_BACKDOOR: no-keys.sh(today) exit=0
  body .transfer( = 2      (check 9 requires exactly 2)     PASS
  body transferFrom( = 1   (check 9 requires exactly 1)     PASS
  fund range .transfer( = 0 (check 9 requires 0)            PASS
  fund range msg.sender = 3 (check 10 requires exactly 3)   PASS
  check 6 forbidden tokens present = 0                      PASS
  check 5 declaration line matches                          PASS
LIBRARY_DRAIN: no-keys.sh(today) exit=0
  file-wide .transfer( = 3   but   body-wide .transfer( = 2  PASS
  check 2 functions in body: fund refundAfterDeadline settleWithProof  PASS
```

Nothing else catches either route. AC-10's invariant handler exposes `fund` / `settleWithProof`
/ `refundAfterDeadline` / `donate` / `warp` — the drain is a call to the **token**, made from
outside the escrow, so INV-4 holds for the whole fuzz run. AC-11 fuzzes `fund` only against an
*existing* `dealId`. AC-8 funds with `amount == 0` and asserts nothing about allowances. No
mutant M-1…M-39 models an approval. This is r1 finding 3 with one method name changed.

Also false as a consequence: §4.5:539's claim that check 9 *"kills … the allowance-redirect"*.
It kills M-37 (`transferFrom(seller, msg.sender, amount)`); it does not touch an `approve`.

**Required change.** (a) Add to check 6's forbidden set every ERC-20 mutator that is not one of
the three pinned sites — at minimum `approve`, `increaseAllowance`, `decreaseAllowance`,
`permit`. (b) Make the scan region the whole file, or pin it explicitly: assert that the file
contains exactly one `contract` / `library` / file-level `function` declaration, so no code can
sit outside the counted region. (c) Add both routes as mutants (M-40 approve-in-`fund`, M-41
library-drain) with `killed-by` = AC-1, and add them to `no-keys-selftest.sh`'s source-text set.
(d) Re-word §3.1:245 and §8:1464-1466 to whatever survives; the current sentences are the exact
unearned-claim family `AGENTS.md` §5 forbids, and r1 already deleted one of them once.

### 2. [BLOCKER] `docs/specs/003-key-gauntlet.md:596-620`, `:1157-1159` — the five AC gates read test *names*, never test *bodies*; AC-18 observation 5 is false, and its falsity is what the whole round-2 format rests on

**Codex's finding (#3), verified; the route below is stronger than the one Codex gave, and one
of its sub-claims is corrected in "Rejected/corrected" below.**

The five gates check: valid JSON, `|found| == N`, a name regex, a row-id superset, and
`set(ran) == set(found)` with every status `Success`. **No gate opens a test body.** So:

```solidity
function test_AC02_G01_settles_regardless_of_caller() public { assertTrue(true); }
function test_AC02_G02_random_bytes_revert()         public { assertTrue(true); }
function test_AC02_G05_reproduced_pays_seller()      public { assertTrue(true); }
function test_AC02_G06_bad_outcome_reverts()         public { assertTrue(true); }
function test_AC02_G08_mutated_values_revert()       public { assertTrue(true); }
function test_AC02_G09_stranger_frontruns()          public { assertTrue(true); }
```

Six tests, correct names, `|found| == 6 == N`, all `Success`, rows `G-01,G-02,G-05,G-06,G-08,G-09`
covered. **AC-02 is green and the manifest was not touched**, so Σ = 42 and AC-17 = 54 still
close and AC-13 passes. Repeat for all 13 forge ACs and `ac.sh --all` prints
`ac: 21/21 acceptance criteria passed` over a suite that asserts nothing. Verified today on
forge 1.7.1 that each gate behaves as the spec says (`--list --json` is three levels and does
enumerate `invariant_*`; `--match-test` matches them; run keys are `name(sig)`; no-match `--list`
yields `{}`), so the gates work exactly as designed — and the design does not reach the bodies.

§5.0:619 is correctly scoped (*"why **0 matches** can no longer be green"* — true). The false
sentence is AC-18 observation 5 at :1157-1159: *"a test whose body is `assertTrue(true)` still
fails, because the run gate's name set would no longer match the manifest's row coverage."*
Emptying a body does not rename it. The clause after the dash — *"and, for the value-bearing
ACs, because AC-14's mutants survive"* — is the only real defence, which means **the anti-
degeneracy property is carried entirely by AC-14, not by the new AC format**, and the document
says the opposite.

That matters concretely because of finding 6: **AC-8 has no mutant at all.**

**Second half — the self-reference the founder asked about.** AC-18 is dispatched by `ac.sh`
(`bash scripts/ac.sh AC-18` runs `ac-selftest.sh`, requires exit 0 and an evidence substring).
An `ac.sh` that exits 0 on everything makes AC-18 green while `ac-selftest.sh` — the only thing
that would catch it — never really runs. AC-0 already has the right pattern (`bash
scripts/no-keys.sh` is listed as *"the founder's own command"* beside the wrapper); AC-18 has
no such direct line. The loop is closed only if a human runs `ac-selftest.sh` directly, and the
spec never says so.

**Required change.** (a) Delete or rewrite observation 5 — it is the only sentence claiming the
format catches empty bodies, and it is false. (b) State plainly in §5.0 and §8 what the format
does and does not do: it makes *zero tests* impossible; it does not make *zero assertions*
impossible, and the mutation table is the sole instrument for that. (c) Give AC-18 a direct
invocation outside `ac.sh` (`bash scripts/ac-selftest.sh` as its own line, the way AC-0 does),
and require `gauntlet.sh` to call `ac-selftest.sh` directly rather than through `ac.sh`.
(d) Require every forge AC to have at least one mutant in §5.3 (finding 6), since that is now
the load-bearing check.

### 3. [MAJOR] `docs/specs/003-key-gauntlet.md:69-74`, `:366-382` — a recipient-fee token satisfies §1.3's "exact-transfer" definition and still underpays; §1.3 defines the class only on the escrow's side

**Codex's finding (#1), verified. Downgraded from Codex's BLOCKER — reason recorded below.**

§1.3(b) requires only that *"a `T.transfer(b, x)` … decreases `T.balanceOf(escrow)` by exactly
`x`"*. A token that debits the escrow by exactly `x`, credits `b` with `x − 1` and credits a fee
collector with 1 satisfies (a), (b) and (c) verbatim, passes C-5's delta check, and marks the
deal `Settled`. §3.2's own definition of the `authorized` class is *"must pay exactly the right
party exactly once"*, and §1.1's claim is that value reaches *"no destination other than the
two the deal itself fixed at funding time"*. Both are violated by a token the spec declares
**supported**. G-34 only covers the sender-side fee (`amount + fee` debited), which reverts; the
recipient-side fee does not revert — it silently underpays and terminates.

**Why MAJOR and not BLOCKER.** The harm is confined to the deal's own token and its own two
parties: the escrow's solvency and no-inflation invariants (INV-4, INV-6) are untouched, no
other deal loses principal, and no key is involved. It is a defect in the definition that the
whole of §8's residual analysis is built on, not a route by which the gauntlet certifies a
contract that can be looted. It must be fixed before implementation; it is not the same order
of failure as findings 1 and 2.

**Required change.** Add clause **(d)** to §1.3 — *a `T.transfer(b, x)` that returns without
reverting increases `T.balanceOf(b)` by exactly `x`* — and add the disclosed row (G-36:
recipient-fee token, *"funds cleanly, settles, seller receives less than `d.amount`, deal is
terminal"*) with its AC-19 test asserting the recipient-side delta, not only the escrow-side
one. Re-derive §3.2's counts and the AC-19 count. Note that C-5 **cannot** detect this from the
escrow side, so it is a disclosure, not a fix — say that in §8.

### 4. [MAJOR] `docs/specs/003-key-gauntlet.md:172-182` — §2.3 lists the escrow bytecode as the third thing the deployer chooses and then omits it from the three-part check

**Codex's finding (#4), verified.** :172-178 enumerates three construction-time choices —
`verifier`, `refundDelay`, **"the escrow bytecode itself"** — and :180 then reads *"The
pre-funding check is therefore **three-part**: `verifier`, `verdictProgramVKey`, and
`refundDelay`."* The bytecode drops out of its own list. A buyer deploys a look-alike escrow
carrying the genuine verifier and vkey and a 24 h `refundDelay`, with finding 1's approval
backdoor or an unguarded refund; the seller performs all three prescribed checks, they pass,
and the seller works for a contract outside the claim. G-29 covers a **rogue verifier**, not
rogue escrow code behind an honest verifier. `gauntlet.json` (§7.1) prints
`address / verifier / verdict_program_vkey / refund_delay_seconds` — no code hash — so the
artifact does not make the missing check possible either.

Second omission in the same list, raised by Codex in its tail and confirmed here: **`d.token`
is chosen by the buyer per deal and decides whether the seller can ever be paid** (G-18, G-34,
G-35, and finding 3). It is not in the check, and it *cannot* be a **pre**-funding check for the
seller — §10 OQ-4:1590-1592 concedes the seller learns the terms only from the `Funded` event.
§2.2's capability table nonetheless credits the seller with *"refuse to work until the
pre-funding check passes"*.

**Required change.** Make the check four-part (`extcodehash` of the escrow, `verifier`, vkey,
`refundDelay`), print the code hash in `gauntlet.json` and the banner, and split the seller's
check honestly into the part that is possible **before** funding (deployment identity) and the
part that is only possible **after** the `Funded` event and before starting work (`d.token`,
`d.amount`, `d.seller`). Fix §2.2's row to match.

### 5. [MAJOR] `docs/specs/003-key-gauntlet.md:1605-1607` — OQ-6's factual premise is false: a measured Groth16 wall-clock does exist in this repo

OQ-6 states *"There is **no measured Groth16 proving wall-clock anywhere in this repo**
(grepped 2026-09-04)"*, and §7.1's `proving_seconds_measured: null` plus the gag rule are built
on it. `zk-verdict/README.md:96-97` says:

> **What was run here — a real proof, verified on-chain.** A **real Groth16 proof** of the
> verdict was generated on CPU (the gnark prover, ~15.9M constraints, **~34 s** once the
> artifacts are local)

That is a measurement, made in this repo, of the same gnark wrapping step, and
`docs/reviews/004-spec-r1.md` (same day, sibling task) already cites `zk-verdict/README.md:97`
as 実測. The honest statement is narrower and more useful than the one written: *the predicate
guest's Groth16 wrap was measured at ~34 s; `program-revm`'s (~410k cycles of core proving
before the same wrap) has not been measured.* Two consequences the spec currently forgoes:
`MIN_REFUND_DELAY = 3600 s` is ~100× the one number that exists, which is worth saying; and
`proving_seconds_measured` should carry that number with its guest named rather than `null`.

The direction of this error is unusual for this repo — it is a *negative* overclaim, asserting
an absence that the repo contradicts — but `AGENTS.md` §5 covers it either way: a grep result
reported without the grep having found what is there.

**Required change.** Correct OQ-6 to cite `zk-verdict/README.md:97`, distinguish the two guests,
and make `proving_seconds_measured` a two-field object (`predicate_guest_seconds: 34`,
`reexec_guest_seconds: null`) with the source recorded. Keep the gag rule; it is right. Do not
raise `MIN_REFUND_DELAY` on the strength of a number measured for a different guest.

### 6. [MAJOR] `docs/specs/003-key-gauntlet.md:782` vs `:901`, `:1240` — M-21 names two different mutations, and the collision leaves AC-8 with no mutant at all

:782 (AC-2): *"AC-2's own primary kills are **M-21** (the verifier call's return value is
ignored)"*. :901 (AC-8): *"**Kills:** M-21 `fund` ignores `transferFrom`'s result and skips the
delta check — the mutation that reproduces today's code (`RecknZkEscrow.sol:86`), which is why
this AC exists."* Those are different patches in different functions. §5.3:1240 assigns M-21 to
**AC-2**, and §5.3:1227 declares *"Every identifier below appears in exactly one `killed-by`
cell"*.

Consequence: **AC-8 is the only forge AC with no mutant in the kill table.** Combined with
finding 2, AC-8's three tests can be `assertTrue(true)` with correct names and nothing in the
harness notices — and AC-8 is the acceptance condition for C-4, the fix r1 finding 3 required
because today's `RecknZkEscrow.sol:86` discards `transferFrom`'s boolean and lets a `Funded`
deal be paid out of *other deals' principal in the same token*. The single most consequential
contract change in 003 is guarded by the one AC the mutation harness does not reach.

At implementation time this surfaces as "M-21 survives AC-2" and gets resolved privately by
reassigning a cell — which is how the arithmetic gets rescued instead of the gap being closed.

**Required change.** Split into M-21 (verifier return ignored → AC-2) and a new M-40 (`fund`
skips the delta check → AC-8), re-derive §5.3's total and AC-14's printed count, and add the
rule from finding 2(d): every forge AC must own ≥ 1 mutant.

### 7. [MAJOR] `docs/specs/003-key-gauntlet.md:679`, `:1033`, `:1040`, `:1227` — AC-14's count check cannot pass as written; three different numbers are given for one comparison

The manifest evidence string (:679) is `mutation: 41 mutants, 41 killed, 1 control survived`.
AC-14:1033-1040 says the script *"exits non-zero if … the printed count differs from the number
of `M-` identifiers in §5.3"* and then *"the printed count must equal §5.3's 42/41/1"*.
§5.3:1227 declares **42** identifiers. Mechanically recounted today:

```sh
grep -oE 'M-[0-9]+[a-d]?|M-[AF]\b' docs/specs/003-key-gauntlet.md | sort -u | wc -l   # 46
# 42 base ids + the four lettered sub-mutants M-31b, M-31c, M-31d, M-32b
```

So "the number of `M-` identifiers in §5.3" is 42 if you mean the table, 46 if you grep, and the
printed line says 41. `ac.sh` requires the evidence string **verbatim**, so as specified AC-14
either fails on its own arithmetic or the implementer picks an interpretation in private. This
is the r1 findings 1/2/9/12 family — prose and exit status disagreeing — recurring in the very
mechanism introduced to end that family, and in the AC that finding 2 shows is now load-bearing.

**Required change.** State the comparison as an expression over the table only, e.g. *"the
printed line must read `mutation: <T> mutants, <T−1> killed, 1 control survived`, where `<T>` is
the number of rows' ids in §5.3's table excluding the lettered sub-mutants"*, and make the
evidence string derived rather than a literal, or fix the literal to match the table.

### 8. [MAJOR] `docs/specs/003-key-gauntlet.md:370-375` vs `:934-936`, `:1245` — the stated reason for C-5's exact equality, which is what creates G-34/G-35, is contradicted by the spec's own kill table

C-5:370-372: *"**Decision, and why exact and not `>=`:** the upper bound is what stops M-23 …
`decrease >= d.amount` admits M-23"*, and :375-380 accepts, as the price, that outbound-fee and
rebasing tokens **brick both exits forever** (G-34/G-35) — a residual 003 creates, in a task
whose charter (`AGENTS.md` §3, task 001) is *"proof が来なくても資金がロックしない"*.

But M-23 is a **mutant**, and §5.3:1245 assigns it to **AC-10**, whose invariant runs over ≥ 3
deals in ≥ 2 tokens (:930-936). A `refundAfterDeadline` that pays `token.balanceOf(this)` drains
the other funded deals and breaks INV-4 on the first multi-deal sequence — AC-10 kills it with
or without C-5's on-chain upper bound. AC-10's own text says as much: M-23 *"passes every
single-deal test"*, and AC-10 is not a single-deal test. So the sentence conflates a
**test-suite adequacy artefact** (does the suite detect a wrong implementation?) with a
**runtime control** (does the deployed contract refuse an over-payment?). The runtime
justification exists — a token that moves more than requested would over-pay from other deals
in that same token — but it is nowhere stated, and it is much narrower than "M-23".

I am **not** asking for `>=`: it does not solve G-34 either (an outbound fee debits
`amount + fee`, which fails any upper bound), so exact equality is probably the right call. The
finding is that the residual is currently justified by an argument the document itself refutes,
and a residual admitted for a wrong reason cannot be re-examined by the founder later.

**Required change.** Replace :370-372's justification with the runtime one, state explicitly
that M-23 is killed by AC-10's multi-deal invariant independently of C-5, and re-word
Appendix A row 6 (:1630, *"exact equality is kept because the upper bound is what kills M-23"*)
to match. §8:1482 needs the same correction.

### 9. [MAJOR] `docs/specs/003-key-gauntlet.md:103-104`, `:1588-1595` — N-5's "that is a key" is too broad, and it is the sentence that converts G-33 from fixable to disclosed

N-5:103-104: *"Any deadline-extension, seller-bond, **seller-acceptance**, dispute-reopen, or
arbitration mechanism. **Every one of them needs a trigger held by a party; that is a key.**"*
OQ-4:1594-1595 then rests on it: closing G-33 *"changes the central claim's shape and needs a
new task"*.

`AGENTS.md` §0's key is an actor who can **decide an outcome**: owner, admin, resolver, pause,
upgrade. A seller `accept(dealId)` step is consent to **enter**, not authority to **decide**: a
seller who never accepts leaves the deal in `Funded` until the deadline and the buyer is
refunded — precisely the outcome available today when the seller does nothing. It moves no
value to any destination the deal did not already fix. Deadline-extension and dispute-reopen
*are* keys; seller-acceptance is not, and grouping them under one sentence is an unearned claim
of exactly the kind §8 promises the document does not make.

This is not a request to add the mechanism — it is outside 003's scope line, which permits
contract changes only where a matrix row would have no true expected result. **The disposition
(disclose in 003) is right; the reasoning is wrong**, and because OQ-4 is what the founder will
read when deciding whether G-33 stays disclosed forever, the wrong reasoning has to go.

**Required change.** Narrow N-5 to mechanisms that confer *authority over an existing funded
deal's outcome*, list seller-acceptance separately as *"consent to enter; not an outcome key;
excluded from 003 on scope grounds, not on claim grounds"*, and re-word OQ-4 so the founder is
choosing on cost and demo-surface rather than on a false claim-shape argument.

### 10. [MINOR] `docs/specs/003-key-gauntlet.md:981-983` — AC-13's marker-uniqueness assertion is false against the document it parses

AC-13 requires the parser to assert that *"those two comment markers appear **exactly once
each** in this document, in §3.2"*. They do not:

```sh
grep -n "BEGIN MATRIX\|END MATRIX" docs/specs/003-key-gauntlet.md
# 274:<!-- BEGIN MATRIX -->      314:<!-- END MATRIX -->
# 979:… the matrix between the `BEGIN MATRIX` and    980:`END MATRIX` HTML comments in §3.2 …
```

Read literally, AC-13 fails on the spec itself. A careful implementer will match the full
`<!-- BEGIN MATRIX -->` (which does occur once) and move on; that private reinterpretation is
the defect.

**Required change.** Say *"the exact strings `<!-- BEGIN MATRIX -->` and `<!-- END MATRIX -->`
occur exactly once each"*.

### 11. [MINOR] `docs/specs/003-key-gauntlet.md:764` — AC-1's Falsify line is arithmetically wrong on both numbers

The source-text set is **14** mutants (:696, §5.3:1240). Deleting check 9 makes M-35/M-36/M-37
survive, so the line should read `14 source mutants, 11 rejected`. The spec says
`15 source mutants, 12 rejected`. Since `ac.sh` matches the evidence string verbatim, a
falsifier that prints a string the harness cannot produce is not a falsifier — and R-6:1335
requires every Falsify to have been *run and observed*.

### 12. [MINOR] `docs/specs/003-key-gauntlet.md:1522`, `:1525` — two of the §9 `file:line` references are wrong, in a table whose header says each was re-verified

- D-4 cites `README.md:669` for *"— 12 tests"*. That string is at **`README.md:700`**
  (`grep -n "12 tests" README.md`); :667-670 is a bash fence containing `zk-e2e.sh`.
  `README.md:551` is correct.
- D-7 cites `STATUS.md:39-40` as holding *"a pointer to a `docs/specs/001-keyless-timeout.md`
  that will never exist"*. `STATUS.md:39-40` is the review table. The string
  `001-keyless-timeout` occurs **nowhere** in `STATUS.md` — the only occurrence in the repo is
  inside this spec (`grep -rn "001-keyless-timeout" STATUS.md docs`). D-7 instructs the
  implementer to fix something that does not exist. `STATUS.md:15` is correct.

Small, but §9's header is *"Each is a `file:line` re-verified 2026-09-04"*, and r1 finding 11
was the same species.

### 13. [MINOR] `docs/specs/003-key-gauntlet.md:1405-1409` — the gag rule is an unspecified grep

*"`gauntlet.sh --check` greps the rendered output for that claim and fails if it appears with a
`null` measurement"*. "That claim" has no pattern. A grep with no pattern is prose in the shape
of a mechanism — the family r1 finding 9 named. Give the literal alternation to match (e.g.
`covers? the proving time|proving time is covered|long enough to prove`) or drop the sentence
and rely on review. The substance — refusing to claim the window covers proving time — is right
and should stay (see finding 5 for the number that does exist).

### 14. [MINOR] `docs/specs/003-key-gauntlet.md:644-651`, `:1046-1049` — termination is proven for AC-14 and AC-18 and left open for AC-15

The termination paragraph covers `--all` re-entering AC-14 and AC-18. But AC-15 is
`scripts/gauntlet.sh`, which §5's AC-15 body requires to *"run the gauntlet suites through
`scripts/ac.sh`"*; if that is `ac.sh --all`, then `ac.sh --all` → AC-15 → `gauntlet.sh` →
`ac.sh --all` recurses, and AC-13/AC-16 (`gauntlet.sh --check`) sit in the same loop. Say which
ACs `gauntlet.sh` may invoke (the 13 forge ACs, individually) and forbid `--all` inside it.

---

## Rejected / corrected findings

- **Codex #3's sub-claim that *"AC-13 merely recomputes from the altered manifest"* — corrected,
  not rejected.** Codex's route compressed AC-02 to `tests = 1` with one test carrying all six
  row ids. That route additionally requires editing the manifest, and then Σ over forge ACs is
  39 ≠ 42, so AC-13 check 4 (:987) and AC-17's 54 both break unless the spec's own totals are
  edited too. The finding stands because a **stronger** route needs no manifest edit at all: six
  stub tests with the six correct names (finding 2). I kept the finding and replaced the repro.
- **Codex #1's BLOCKER severity — downgraded to MAJOR**, with the reason recorded in finding 3:
  a recipient-fee token underpays the deal's own counterparty in the deal's own token; INV-4,
  INV-5 and INV-6 are untouched and no other deal's principal is reachable. It is a defect in
  §1.3's definition, not a route by which the gauntlet certifies a lootable contract.
- Nothing was rejected outright. All four Codex findings were reproduced against the files.

## Checked and found sound (recorded so round 3 does not re-litigate)

- **The forge mechanics §5.0 depends on are real, re-measured today on forge 1.7.1** (not quoted
  from r1): `forge test --list --json` is three levels deep (`[.[][][]]` is the right jq),
  **does** enumerate `invariant_*` functions, **is** matched by `--match-test`, and yields `{}`
  on no match; a no-match *run* prints a warning and no JSON on stdout, so gate 1 fires; run
  keys are `name(sig)` so the spec's "strip `(…)`" rule reconciles them with `--list`. The five
  gates behave exactly as §5.0 describes. Finding 2 is about what they do not reach, not about
  whether they work.
- **The six added `no-keys.sh` checks do not loosen the default behaviour** (founder uncertainty
  #2, second half — `AGENTS.md` §0). The interface, the default target, the exit semantics and
  the text of checks 1–4 are unchanged; check 3 is explicitly **retained alongside** the new
  check 7 rather than replaced; check 2 becomes strictly two-sided; the one added output line is
  printed before the unchanged final success line. N-9's refusal to add a target argument (r1
  finding 12) is the right call and removes the "target override" banner problem entirely. The
  §0 founder reservation is **not** tripped by the additions themselves — only finding 1's
  required additions need the founder's eye, and they are further tightenings.
- **The document's internal arithmetic recomputes**, by hand today: 35 matrix rows; 20 theft /
  7 authorized / 8 disclosed; 35 unique `G-` ids; 21 manifest entries; Σ `tests` over the 13
  forge ACs = 42; the union of the manifest's `rows` column is exactly the 35 ids of §3.2; the
  pre-existing suite is **12** tests (`forge test --list --json | jq '[.[][][]] | length'`), so
  AC-17's 54 = 42 + 12 closes; `RecknZkEscrow.t.sol` really has four tests. The only arithmetic
  that does not close is AC-14's (finding 7).
- **`file:line` spot checks in §9 that are correct**: D-1 (`README.md:566-571`),
  D-5 (`zk-verdict/README.md:234-237`), D-6 (`:239-243`), D-8 (`SUBMISSION.md:156-160`),
  D-9 (`README.md:67`), D-2 (`CLAUDE.md:46-49`), D-3 (`AGENTS.md:70`), S-1
  (`zk-verdict/scripts/zk-e2e.sh:84-85` — the `| grep … || true` really does discard forge's
  status). Only D-4's second reference and D-7 are wrong (finding 12).
- **No tier violation.** The header claims *local anvil / Foundry only*; every AC is a Foundry
  or shell command; §8's last bullet restates it; AC-16 freezes both Honest-scope blocks by
  digest and 003 resolves none of them (N-7). The `~34 s` in finding 5 is a repo measurement
  being *omitted*, not a number being promoted a tier.
- **r1's "checked and found sound" list is untouched and was not re-litigated** (001's four
  acceptance conditions, AC-16's digests, INV-9's binding formula, the class counts).

## Deferred

None. Every finding is inside 003's frame. Findings 3, 4 and 9 touch the product's shape
(supported token class, what the seller must check, whether seller-acceptance is a key) but each
is a change to **this document**, not a new task — `docs/decisions/` still does not exist and no
finding needs it.

---

## What must change before round 3

Blocking:

1. Close the allowance exit and the out-of-body exit, or stop claiming the exits are
   enumerated: check 6 gains `approve`/`increaseAllowance`/`decreaseAllowance`/`permit`; the
   scanned region is made the whole file or pinned by a single-declaration assertion; mutants
   M-40/M-41 added under AC-1; §3.1:245 and §8:1464-1466 re-worded (finding 1).
2. Delete AC-18 observation 5's false sentence; state in §5.0 and §8 that the format prevents
   *zero tests*, not *zero assertions*, and that AC-14 is the sole instrument against the
   latter; give AC-18 a direct invocation outside `ac.sh`; require every forge AC to own ≥ 1
   mutant (finding 2).

Also required:

3. §1.3 gains a recipient-side clause (d); row G-36 for recipient-fee underpayment; counts
   re-derived (finding 3).
4. The pre-funding check becomes four-part with the escrow code hash, printed in
   `gauntlet.json`; the seller's `d.token` check is separated as post-`Funded`-event; §2.2's
   capability row corrected (finding 4).
5. OQ-6 corrected against `zk-verdict/README.md:97`; `proving_seconds_measured` split by guest;
   the gag rule kept and given a real pattern (findings 5, 13).
6. M-21 split; AC-8 given its own mutant; §5.3 and AC-14's totals re-derived (finding 6).
7. AC-14's evidence string and its count check reconciled to one number (finding 7).
8. C-5's justification replaced with the runtime one; Appendix A row 6 and §8:1482 corrected
   (finding 8).
9. N-5 narrowed; seller-acceptance separated from outcome keys; OQ-4 re-worded (finding 9).
10. AC-13's marker assertion made exact; AC-1's Falsify arithmetic fixed; D-4/D-7 corrected;
    `gauntlet.sh`'s permitted `ac.sh` invocations pinned (findings 10, 11, 12, 14).

Founder decisions carried forward, unchanged by this round: OQ-1 (signed anvil mode), OQ-2,
OQ-3, OQ-5 (whether `no-keys.sh` ever gains a target argument), OQ-6 (whether to spend a
`ZK_FRESH=1` run — now to be posed against the ~34 s that already exists, not against nothing).
New for the founder from finding 9: whether G-33 stays disclosed is a cost decision, not a
claim-shape decision.

VERDICT: CHANGES

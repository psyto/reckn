# Review 003 spec round 5

Payload: `/tmp/reckn-payload-003-spec-r5.md`
Codex raw: `/tmp/reckn-codex-003-spec-r5.md`

Reviewed: `docs/specs/003-key-gauntlet.md` (4245 lines, round 5), written by **Claude Code
(`reckn-spec`)** — stated in §0 of the payload, so Codex was not grading its own homework
(`AGENTS.md` §1, author independence).
Codex: `codex exec -C /Users/hiroyusai/src/reckn -s read-only`, **one call**, round 5.

Codex returned 5 findings. **Four survive verification**, two of them with their repro
corrected below; one survives with its severity and its "cannot be closed" claim rejected.
Finding 6 is mine. Every `file:line` was opened before the finding was kept, and every
number in this review was **re-measured today** — none is quoted from r1–r4.

**Two independent paths reached the same first finding.** I went at check 15 by hand before
running Codex and landed on the constructor; Codex landed on the constructor from the other
side. That is the strongest signal in this round, and it is the same shape as r4 finding 1
**one layer further out**: r4 found that settlement authority left the checked file; r5
brought the file in and left unchecked **the region of that file where the trusted callee is
chosen**. The boundary moved; it did not close.

**Round 5's answers to r4 are real, not verbal.** I checked, independently of Codex: check 14
gained only prose (the r4 "found sound" note about `push`/`pop`/`tstore`); 9c and 9b-range are
byte-identical; §5.4a changed exactly where r4 finding 5 said it must (per-contract probes,
`--match-test` + parsed JSON, `^SweepProbe_` excluded from the column read). **The self-report
that the escrow-local mechanism was not touched is true.** The document's internal arithmetic
closes, recomputed today: matrix **39** rows (21 theft / 7 authorized / 10 disclosed / 1
enforcement), `T` = **59** with class counts **19 / 25 / 14**, the 13 `forge` ACs' `tests`
column sums to **46**, the manifest's `rows` union is set-identical to the 39 matrix ids
(`diff` clean), corpus **19** entries and **4** controls, `sweep.columns` = `25 − 1 + 5` = 29,
`45 + 1 = 46` on the money-shot. **The only literal totals left in the document are the ones
derived from the document itself.** That part of r4 finding 2 is discharged.

---

## Findings

### 1. [BLOCKER] `docs/specs/003-key-gauntlet.md:1528-1552` (15d/15e), `:1478-1483` (P5), `:417-430` (§2.3 A part 2), `:3580` (money-shot) — check 15 pins assignment *left-hand sides* and excludes the constructor, so the address `verifyProof` is dispatched to is chosen in an unchecked region of the checked file

**Codex's finding #1, verified — with its repro splice rejected and replaced by two that
work.** This was also my own pre-Codex finding, reached independently.

`RecknVerdictVerifier.verifyVerdict` calls `ISP1Verifier(verifier).verifyProof(...)`
(`zk-verdict/contracts/src/RecknVerdictVerifier.sol:55`), and `verifier` is
`address public immutable` assigned in the constructor (`:38`, `:42-45`). Check 15 constrains
that constructor **only** through 15d, which is an enumeration of **left-hand sides**
(`:1533-1539`: `verifier` and `verdictProgramVKey`, "constructor range only"). Nothing in
15a–15f constrains the **right-hand side**:

- **15c** (`:1509-1526`) — the two-statement body, zero control flow, zero `msg.sender` /
  `tx.origin` / `block.` — is scoped to `verifyVerdict`'s body and to nothing else;
- **15e** (`:1545-1552`) pins a line set **"outside the `constructor` and `verifyVerdict`
  ranges"** — the constructor is excluded by construction;
- **15f**'s denylist (`:1553-1559`) contains `msg.sender`, `tx.origin`, `assembly`,
  `delegatecall` … and **not** `if`, `?`, `block.`, `chainid`, or an address literal;
- **15b** counts `function` tokens; `constructor` is not one.

**Repro A — unconditional, killed only by the behavioural suite:**

```solidity
constructor(address _verifier, bytes32 _verdictProgramVKey) {
    verifier = address(0x0000000000000000000000000000000000001337);
    verdictProgramVKey = _verdictProgramVKey;
}
```

14b extracts the LHS as `verifier` (the preceding delimiter is `{`), which 15d permits in the
constructor range. All of 15a–15f pass. On any chain where `0x…1337` holds a permissive
`ISP1Verifier`, `verifyProof` never reverts and `abi.decode` returns **caller-supplied**
public values — anyone settles any funded deal to either destination with no proof. This one
dies in the local suite, because `0x…1337` has no code on a fresh anvil and the high-level
call reverts.

**Repro B — the one that survives every instrument in the document:**

```solidity
constructor(address _verifier, bytes32 _verdictProgramVKey) {
    if (block.chainid == 31337) { verifier = _verifier; }
    else { verifier = address(0x0000000000000000000000000000000000001337); }
    verdictProgramVKey = _verdictProgramVKey;
}
```

Both assignment sites extract LHS `verifier` (braces, not the bare `if`), so 15d passes. On
the demo chain the contract is honest, so **the whole gauntlet, AC-17, the fixture settle and
every sweep column stay green**. Off the demo chain it is a proof-free settlement path for
whoever controls the rogue verifier. And it is keyed on a constant, so per **R-5** (`:3362`)
its killer must be structural — and the structural check that would be it does not read the
constructor.

**Why the disclosures do not catch it.** §8's *"nothing about the SP1 verifier the file calls
into"* (`:3699`) is about that verifier's **soundness**, not about **which address plays that
role**. §2.3(A) part 2 (`:417-430`) names the fact in passing — *"which in turn immutably
holds the SP1 verifier address"* — but the **four-part deployment check is code-hash /
verifier / vkey / refundDelay**, and `RecknVerdictVerifier.verifier()` is in none of the four;
`gauntlet.json` reaches into that contract for the **vkey** and not for this address (§7.1).
So the seller's check passes on a backdoored build, and §7.2's *"Not covered: the bytecode
behind any deployed verifier address"* (`:3580`) is printed while the thing actually not
covered is **the source in the repository that the same line claims is checked**.

**This is the sentence that becomes false:** `:1478-1483`'s P5 — *"A returned struct field can
therefore be produced only by `abi.decode(publicValues, …)` **after
`ISP1Verifier.verifyProof` did not revert**. There is no branch for a constant address to
live in."* The first half is true and carries nothing, because "did not revert" is a property
of a callee the file itself selects; the second half is false — the branch is in the
constructor.

**Required change (bounded, and it is the last unpinned region of a 58-line file):**

1. **15g, or extend 15e to cover the constructor.** The constructor is four lines, 008 does
   not touch it (008 changes only the struct's field widths — checked, see below), so pin it
   the way 15c pins `verifyVerdict`: **exactly two statements, each an assignment whose LHS is
   the immutable and whose RHS is the corresponding constructor parameter and nothing else**,
   and zero occurrences of `if` / `else` / `?` / `block.` / `tx.` / a hex address literal in
   the constructor range. This is 15c's construction applied to the file's other code region;
   it introduces no new kind of check.
2. **Extend the deployment check to five parts** (§2.3 A) — read
   `RecknVerdictVerifier.verifier()` on-chain and compare it with the canonical SP1
   verifier/gateway for that chain — and print it in `gauntlet.json` and in §7.2's banner
   next to `vkey`, which is already read from the same contract. Without this, part 2 of the
   check is a comparison of one address that hides a second.
3. **Corpus entry E-20 and mutant M-57**: repro B, rejected by the new sub-check. Re-derive
   AC-1's evidence to `20 source mutants … exit-corpus 20/20`, `T` to 60, `T_src` to 20.
4. **While you are there, check 8 has the identical shape** (`:1178`, "the left-hand side of
   every assignment inside the constructor body ∈ `{verifier, refundDelay}`"). The escrow's
   case is weaker — its `verifier` is `public immutable` and part 2 of the deployment check
   reads exactly that value on-chain, so a seller performing the check catches it — but the
   asymmetry is unjustifiable once (1) is written, and pinning both RHS costs one clause.

**This is closable in round 6:** it is one sub-check written in the shape of a sub-check that
already exists, one row in two tables, and three counts.

### 2. [BLOCKER] `docs/specs/003-key-gauntlet.md:281-284`, `:2659-2662`, `:3884-3886`, `:4196` — the anti-laundering mechanism is "refuses to **overwrite**", the laundering path is `rm`, and AC-16's stated `Falsify:` asserts the opposite outcome

**Codex's finding #2, verified. Reached independently before the call. Codex's "this cannot
be closed by 003's current local mechanism alone" is rejected — see below.**

§1.5.1 rule 2 (`:281-284`):

> **`--measure` refuses to overwrite.** If `docs/gauntlet.base.json` exists, `gauntlet.sh
> --measure` exits non-zero … Re-running it after a `zk-verdict/README.md` edit is exactly how
> AC-16 would be laundered, **so the file is written once and only once.**

`rm` defeats "written once and only once". After deletion there is nothing to overwrite. The
three-source comparison of rule 3 does not help, because all three sources are re-derived from
the same tree at the new base:

```sh
sed -i '' 's/Not yet:/Now closed:/' zk-verdict/README.md
git commit -m '...' zk-verdict/README.md      # the launderer owns git (AGENTS.md §6)
rm docs/gauntlet.base.json
bash scripts/gauntlet.sh --measure            # writes base_commit = HEAD, digests of the softened block
bash scripts/ac.sh AC-16                      # green
```

Working tree, `git show <base_commit>:zk-verdict/README.md` and the recorded value all agree,
and `base_commit` is an ancestor of `HEAD` (it *is* `HEAD`), so both of rule 3's assertions
pass.

**The instrument, not just the prose, is broken.** AC-16's `Falsify:` (`:2659-2662`) reads:
*"Also: **delete** `docs/gauntlet.base.json` and re-create it with `gauntlet.sh --measure`
after that edit → `--measure` **refuses to overwrite**, so the laundering path exits non-zero"*
— a falsifier whose stated precondition (deletion) removes the condition its stated outcome
depends on (existence). **R-6** (`:3367`) makes every `Falsify:` an obligation to run and
observe non-zero before the AC may be reported green; a `Falsify:` whose expected result is
wrong is a broken instrument, not a typo. The same claim is repeated in Appendix C (`:4196`).

**§9.1 P0 (`:3884-3886`) already knows.** It instructs: *"if it was somehow written after an
edit, stop and return to the founder rather than deleting and re-measuring."* That is an
instruction where **R-10(i)** (`:3383`) demands a mechanism — *"for every artefact this
document treats as evidence, name the thing that would go red if the artefact were replaced by
a stub."* `docs/gauntlet.base.json` is the artefact every other measurement rests on, and
nothing goes red if it is replaced.

**Rejecting Codex's escalation.** Codex wrote *"Bind P0 to an externally established 008
handoff commit … This needs a founder/task-boundary decision; it cannot be closed by 003's
current local mechanism alone."* It can, with two mechanical conditions, both local and both
round-6-sized:

- **`gauntlet.sh --check` asserts the base file has exactly one history**:
  `git log --oneline --diff-filter=D -- docs/gauntlet.base.json` is **empty** (never deleted)
  and `git log --oneline --diff-filter=A -- docs/gauntlet.base.json` has **exactly one**
  entry, whose blob equals the working-tree file. A delete-and-remeasure leaves a `D` in the
  log and a second `A`; a stale-but-honest file leaves neither.
- **`--measure` refuses a dirty tree.** `git status --porcelain` must be empty. Today P0 may
  legitimately be run on a dirty tree (008 is dirty in the working tree **right now**), in
  which case `honest_scope` is measured from the working tree while `base_commit` points at
  `HEAD` — and the three-source check then goes red at **P8**, six parts after the mistake,
  with no instruction attached. This condition makes it fail at P0 where it is cheap.

Also delete the "so the file is written once and only once" clause and rewrite AC-16's
`Falsify:` and Appendix C's row to the outcome that actually occurs.

### 3. [MAJOR] `docs/specs/003-key-gauntlet.md:2668-2676` — AC-17 pins the pre-existing suite's **size** and four **names**; it does not pin the pre-existing tests' identities, so a meaningful test can be deleted and replaced by a passing one

**Codex's finding #4, verified against the tree.**

AC-17 requires `{S}` = `46 + {P}` results, every status `Success`, and *"the four pre-existing
`RecknZkEscrowTest` names of §1.2 present"* (`:2673`). `{P}` is a **count**
(`:270`: `forge test --list --json | jq '[.[][][]] | length'`). Measured today, the suite is
12 tests across five files; the four protected names are all in `RecknZkEscrow.t.sol`. The
other eight are unprotected:

```sh
grep -rn 'function test' zk-verdict/contracts/test/*.t.sol   # 12 today; 4 of them named by AC-17
```

**Repro.** Delete `test_reexec_tampered_public_values_are_rejected`
(`zk-verdict/contracts/test/RecknReexecVerdict.t.sol:47`) — the test that proves a tampered
public-values blob is rejected — and add any passing test to the same file. `{P}` is
unchanged, `{S}` is unchanged, every status is `Success`, the four names are present:
**AC-17 green**. That is the exact shape of the pressure this project has failed under four
times: a test that goes red during C-1…C-7's constructor change is easier to replace than to
fix, and AC-17 is the only thing looking.

**Required change — nearly free, because P0 already enumerates.** `--measure` records the
**set of pre-existing test ids** (`forge test --list --json` yields file → contract → test),
not only its length, into `docs/gauntlet.base.json.pre_existing_tests`; `{P}` becomes its
cardinality; AC-17 requires the recorded set to be a **subset** of the final suite's ids and
prints the count of any missing ones. §1.2's four named tests stay as the load-bearing subset.
Closable in round 6.

### 4. [MAJOR] `docs/specs/003-key-gauntlet.md:1130-1134`, §5.2.1 (`:2966-2996`) — the stripper's escape-handling clause is the one obligation in §4.5.1 with no corpus witness, and a one-pass scanner that ignores `\"` over-strips exactly as a two-pass one does

**Codex's finding #3, verified — with its repro splice rejected and replaced by one that
works.**

§4.5.1 states the stripper as *"scan left to right, track whether the cursor is inside
`//`…EOL, `/*`…`*/`, `"`…`"` or `'`…`'` **(honouring backslash escapes inside the two string
forms)**"* (`:1130-1134`). r5 added E-17/E-18 so the two delimiter **families** are finally
tested against each other, and control C-S so a stripper cannot pass by deleting every quoted
line. **No entry tests the parenthetical.** A single left-to-right automaton that treats `\"`
as a closing quote satisfies "one pass, one state machine" and passes all nineteen entries and
all four controls.

**Codex's repro is rejected as written** — it put the exit on the *following* line, and a
mis-opened `//` strips only to end of line, so the exit survives and 9a is unchanged. The
working form keeps it on the same line, which is E-17's own shape:

```solidity
string memory ref = "a \" // b"; IERC20Min(token).transfer(seller, amount);
```

A scanner without escape handling closes the literal at `\"`, sees `//`, and deletes the rest
of the line. `.transfer(` disappears from `src_calls`; 9a's multiset is unchanged, 9b/9c see
nothing, and check 14 accepts `string memory ref` because `D` admits it — the identical chain
of consequences E-17 documents (`:2987`). All fifteen checks pass and `fund` pays an arbitrary
address.

**Weaker than r4 finding 4, and still worth closing**, because the obligation is written in
prose and the corpus is what this document calls *"the witness that the closedness is real"*
(`:2957`). One entry **E-20/E-21** (the splice above, and its `'` twin), re-derive
`exit-corpus 20/20` (or 21/21 with finding 1's entry), and re-number §5.2.1's "nineteen".

### 5. [MINOR] `docs/specs/003-key-gauntlet.md:3656-3658` — *"the word appears only in §5.0.1 and in its restatement in the next bullet"* is false as of this round, and it is false for the reason the same paragraph names

§8's "On the word 'impossible'" paragraph avoids asserting a **count** (*"a literal that
drifts is r2 finding 7, and this document has been bitten by one already"*) and then asserts a
**location set**, which drifted in the same round it was written:

```sh
grep -ni impossible docs/specs/003-key-gauntlet.md
# 1730, 1731 (§5.0.1)   3656, 3657, 3659, 3667 (§8)   4122, 4125, 4181, 4243 (appendices)
```

The **substantive** claim survives: none of the appendix occurrences asserts that an attack is
impossible — 4122/4181/4243 are round-bookkeeping rows recording that a round **refused** to
make such a claim. So this is a wrong sentence about a correct discipline. Replace *"appears
only in §5.0.1 and in its restatement"* with *"is never used about an adversary anywhere in
this document; its only substantive use is §5.0.1's claim about a script's exit condition"* —
a property, not a location list.

### 6. [MINOR] `docs/specs/003-key-gauntlet.md:2610`, `:285-287`, `:342`, `:2647` — two independent check-numbering series both reach 15, and one of them is cited without its script

Mine. `scripts/no-keys.sh` has checks 1–15 after 003 (§4.5.2), and `scripts/gauntlet.sh
--check` has its own numbered checks (4, 8, 11, 14, **15**, 16, **17** — `:2647`, `:342`,
`:2439`…). §1.5.1 rule 3 and AC-16 both write *"`gauntlet.sh --check` (check 15)"*
(`:285-287`, `:2610`) for the honest-scope digest, two pages after §4.5.10 defines **check 15**
as the `RecknVerdictVerifier.sol` closure in a different script. The two are unrelated and the
implementer builds both in different parts (P3 vs P8). Rename one series — the `gauntlet.sh`
checks are the ones with no external contract, so give them a prefix (`--check` C-4, C-8, …)
— or always write the script name adjacent. One editing pass, no mechanism changes.

---

## Rejected findings

- **Codex #1's repro splice, as written, is rejected.** Codex proposed
  `if (_verifier == address(0xBEEF)) verifier = address(0x1337);` as a single unbraced
  statement. Under **14b**'s LHS-extraction rule (`:1345-1347`: the LHS is the text from the
  preceding `;`, `{`, `}` or `(` up to the `=`), the nearest preceding delimiter is the `(` of
  `address(`, so the extracted LHS is `0xBEEF)) verifier`, which is in no permitted set and is
  **rejected** — the same fail-loud behaviour r4 verified for `if (…) deals[k].x = y;`. The
  finding stands on the braced and unconditional forms given above, and repro B is materially
  stronger than Codex's because it also survives the behavioural suite.
- **Codex #2's severity escalation to "cannot be closed by 003 alone" is rejected.** Two local,
  mechanical conditions close it (finding 2). Binding P0 to an externally established 008
  handoff commit is a *nicer* answer and it is not a *necessary* one; requiring it would push a
  round-6-sized fix onto the founder for no gain.
- **Codex #3's repro splice, as written, is rejected** — the exit was on the following line and
  a mis-opened `//` strips only to end of line, so nothing is hidden and 9a is unchanged.
  Replaced with the same-line form (finding 4).
- **Nothing else was rejected.** Codex #4 and #5 reproduced exactly against the files.

## Deferred

None. All six findings are edits to `docs/specs/003-key-gauntlet.md`; finding 1 additionally
implies one sub-check in `scripts/no-keys.sh` when 003 is implemented, in the tightening
direction. `docs/decisions/` still does not exist and no finding needs it.

---

## Checked and found sound (recorded so round 6 does not re-litigate)

Re-measured today. Where a number matches a prior round it was re-run, not quoted.

- **Round 5 did not touch the mechanisms r4 cleared.** Verified by diffing r4's commit against
  r5's (`git diff cb7c913 38c091b -- docs/specs/003-key-gauntlet.md`): check 14 gained only the
  r4 "found sound" paragraph about `push`/`pop`/a passed storage reference/`tstore`; **9a, 9b,
  9b-range and 9c are unchanged**; §5.4a changed exactly and only where r4 finding 5 required
  (per-**contract** probes with a pinned inventory, `--match-test '^test_probe_setup_ok$'` with
  the result read from **parsed JSON** and explicitly not from the exit status, and
  `^SweepProbe_` excluded from every column read so the control column is `{S}`). **The
  self-report is true.**
- **The (a)-over-(b) decision is legitimate.** The test I apply: *a product reason may choose
  between remedies only when the disclosure set does not shrink.* Here it does not — (b)'s
  three sentences are all still present (§8 `:3684-3702`, §2.3(A) `:417-432`, §7.2 `:3576-3580`),
  and (a) is a strict tightening that costs no interface change (`scripts/no-keys.sh:17-19`
  derives its target from its own location; N-9 intact). Nothing was hidden to make a screen
  printable. **What the choice did create is a new disclosure obligation that is under-stated —
  that is finding 1, and it is an argument for completing (a), not for reverting to (b).**
- **Check 15 is 008-stable, as claimed.** 008 changes the four numeric field widths of
  `VerdictPublicValues` and their order is unchanged
  (`docs/specs/008-verdict-domain-soundness.md:380-382`, `:464-469`). **Re-verified against
  008's round-4 commit `0ec3e7e`, which the parallel agent landed while this review was being
  written**; the struct's field order is unchanged (`pre, post, minDelta, maxDelta, outcome,
  traceHash, dealBinding`) and only the four numeric widths move, so the conclusion is
  unaffected by that commit. 15a compares the `struct VerdictPublicValues {` **header** line; 15e covers
  only lines **inside `contract RecknVerdictVerifier`**, so the struct's field lines are outside
  it twice over. 008's own M-15 (swap `REPRODUCED`/`FAILED` in that file) is 008's mutant and is
  inert against the escrow, which declares its own constants (`RecknZkEscrow.sol:25-26`).
  003 changes **no line** of the verifier file, so 008's `surfaces.pinned` digest over it is
  undisturbed and D-11's re-pin correctly concerns `RecknZkEscrow.sol` alone.
- **The four observer defects are answered with mechanisms, not sentences.** The witness
  (`{W14}`/`{W21}`) is recomputed by `ac.sh` from the committed patch files **without running
  the script under test**, and §5.0.3 states in advance the half it does **not** cover (that
  the sandboxes were built and a status read) and points at AC-18 observations 7/8 for that
  half; M-56 guards the guard. The two devices are genuinely independent — deleting either
  leaves the other. **The §8 sentence *"003 is not a defence against an implementer who
  fabricates evidence"* is honesty, not an excuse**: it is attached to exactly one named
  artefact (`ac-selftest.sh`, the end of the chain), R-10(iii) requires that naming, and the
  cheap accidental failure it excludes is covered by the two devices. It is **not** doing work
  for finding 2 — there the document claims a mechanism blocks the act, which is a different
  and disallowed move.
- **R-8, R-9 and R-10 do not contradict each other or the rest of the document.** R-8 is about
  operands of permitted calls, R-9 about columns that break their own observer, R-10 the general
  form of "every observer is observed, and say where the chain stops"; R-9 is stated as R-10(i)'s
  special case and the text says so. **Finding 1 is an instance of R-8, not a counterexample to
  it** — the constructor's right-hand side is precisely "an operand the lexical check does not
  constrain", which is why the rule is right and the check is incomplete.
- **The timeout design is unchanged and still right.** `refundDelay` is a `uint64 public
  immutable` fixed at construction (C-2); `refundAfterDeadline` carries no caller condition and
  G-13 fuzzes the caller — **anyone**. G-16/G-17 make refund and settle mutually exclusive in
  both orders, G-11 fuzzes the pre-deadline boundary, and §8 states the post-deadline race as a
  real race with two authorized outcomes rather than implying proofs win. Nothing in r5 moved
  any of this.
- **No tier violation.** Every AC is a `forge` or shell command; §7.1's `proving` block still
  carries `reexec_guest_seconds: null` with the gag rule; `MIN_REFUND_DELAY` is still justified
  by INV-10 alone and not by the `~34 s` predicate-guest number; §1.5.3 replaced the line-number
  citation of that number with a content grep requiring exactly one match. **003 correctly does
  not assert whether 008 fixed the `u64_low` truncation** — §8's honest-scope bullet now states
  the relation by reference (*whatever the base commit says is as true at the end as at the
  start*) instead of enumerating items, which is what r4 finding 2 required.
- **The 008 decoupling is otherwise complete.** `grep`-checked today: no honest-scope digest
  literal survives, no `58`/`12` suite literal survives outside §1.2's explicitly-labelled
  history line, INV-9 refers to `binding_preimage` rather than quoting a preimage, INV-10 refers
  to `public_values` rather than quoting widths, and the `surfaces.pinned` path is corrected to
  `zk-verdict/scripts/`. **`{P}`, `{S}`, `{W14}`, `{W21}` are the only substitution tokens and
  `gauntlet.sh --check` asserts no fifth one appears** — the mechanism is right; findings 2 and
  3 are about what the base measurement records and how it is protected, not about the
  substitution.
- **r1–r4's "checked and found sound" lists are untouched and were not re-litigated.**

---

## What must change before round 6 — and round 6 is the hard stop (`AGENTS.md` §7)

**BLOCKER:**

1. **Pin the constructor of `RecknVerdictVerifier.sol`** (finding 1): 15c's construction applied
   to the constructor range (two statements, RHS = the corresponding parameter, no `if`/`?`/
   `block.`/address literal), a **fifth part** of the deployment check reading
   `RecknVerdictVerifier.verifier()` with it printed in `gauntlet.json` and §7.2, one corpus
   entry, one mutant, three counts re-derived. Extend check 8 the same way in the same pass.
2. **Make "written once and only once" true, or stop saying it** (finding 2): the two `git log`
   assertions and the clean-tree condition on `--measure`; rewrite AC-16's `Falsify:`,
   §1.5.1 rule 2 and Appendix C's row to the outcome that actually occurs.

**MAJOR:**

3. Record the pre-existing test **id set**, not its cardinality, and make AC-17 assert the
   subset (finding 3).
4. One corpus entry for the escaped delimiter, and re-derive the corpus count (finding 4).

**MINOR:**

5. Replace §8's "appears only in" locality claim with the property it means (finding 5).
6. Disambiguate the two check-numbering series (finding 6).

**Nothing else.** Round 6 must not open new mechanism design. If a round-6 finding lands that
is not one of these six, `AGENTS.md` §7's hard stop applies and the document goes to the founder
with it open.

## Founder decisions carried forward

Unchanged and still open: **OQ-1** (signed anvil mode), **OQ-2**, **OQ-3**, **OQ-5**, **OQ-6**,
**OQ-7** (now one question about two budgets — `SWEEP_EXEMPT.txt` ≤ 2 and `excluded_columns` ≤ 1,
both printed on screen; r5 gave the second one the cap r4 asked for), **OQ-9** (who owns check 15
after 003 ships; the recommendation — *the check moves with `no-keys.sh`, which `AGENTS.md` §0
reserves to the founder; agents may tighten and may never loosen* — is the right one).

**OQ-8 (what if `008` does not land) — the framing is correct and it is sufficient to hand to
the founder.** Verified: §1.5's measurement construction genuinely makes 003 correct against
either tree, because every 008-coupled quantity is read off whatever exists at the base commit;
the honest-scope digest 003 pins would then still contain the `u64` truncation item, so nothing
003 prints becomes false. **The spec is right that this is not a mechanical question**, and it
states the real cost in the right words: option (a) ships a demo of *"a keyless escrow settled
by a verdict whose domain is known-broken"*. Two things I would add before the founder rules:

- the recommendation *"(a) with the truncation item named on screen"* is not yet an obligation
  anywhere — §7.2's banner has no line for it, and AC-16 only pins that the honest scope was not
  **changed**, not that it is **displayed**. If the founder picks (a), that is one more money-shot
  line and it should be written into §7.2 in round 6.
- 003's claim is about **keys** and is unaffected by 008 — that is true and it is exactly the
  "our claim is narrower than it looks" move `AGENTS.md` §5 warns about. The founder is the right
  person to decide whether it can be said on stage; an agent should not decide it, and r5 correctly
  did not.

**New for the founder, from finding 1:** the four-part deployment check becomes five parts.
That is a change to what the seller is told to do, printed in the money-shot, so it is a founder-
visible change even though it is a tightening.

VERDICT: CHANGES

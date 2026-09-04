# Review 003 spec round 4

Payload: `/tmp/reckn-payload-003-spec-r4.md`
Codex raw: `/tmp/reckn-codex-003-spec-r4.md`

Reviewed: `docs/specs/003-key-gauntlet.md` (3171 lines, round 4), written by **Claude Code
(`reckn-spec`)** — stated in §0 of the payload, so Codex was not grading its own homework
(`AGENTS.md` §1, author independence).
Codex: `codex exec -C /Users/hiroyusai/src/reckn -s read-only`, **one call**, round 4.

Codex returned 4 findings. **All four survive verification**, two of them with corrections
recorded below. Findings 4, 6, 7, 8, 9, 10, 11 are mine. Every `file:line` was opened before
the finding was kept. Every number in this review was **re-measured today** (`T`, the matrix
row and class counts, the manifest row union, the two Honest-scope digests, the pre-existing
suite count); none is quoted from r1/r2/r3.

**The three closures round 4 claims are, inside `RecknZkEscrow.sol`, real.** I went at 9c,
9b-range and check 14 hard and independently of Codex, and could not get value out of that
file: 9c kills the alias regardless of the local's name, 9b-range kills the plain call,
check 14 kills the assignment, and check 14's LHS-extraction rule fails loudly rather than
silently on the shapes I tried (`if (…) deals[k].x = y;`, tuple declarations, `unchecked`
blocks, a second `Deal storage`). `push`/`pop` and a passed storage reference are closed by
9a and 9c respectively rather than by 14a, which is a gap in §4.5.6's *prose* and not in its
coverage. **Round 4 is the first round in which the escrow-local seam did not re-open.**

**It is also the first round in which the two decisive findings are not about that file at
all.** They are: the settlement path leaves the checked file (finding 1), and the tree 003
describes is not the tree 003 will be implemented against (finding 2). r1/r2/r3 each broke
the enforcement mechanism one layer down; r4 breaks at the *edges of the frame* instead.
That is progress, and it is still `CHANGES`.

---

## Findings

### 1. [BLOCKER] `scripts/no-keys.sh:19` + `zk-verdict/contracts/src/RecknVerdictVerifier.sol:50-57` — settlement authority passes through a file that no check, no fuzz and no mutant in 003 ever reads

**Codex's finding #1, verified. This was my own stated uncertainty (ii) and Codex's answer
is (a), not (b).**

`scripts/no-keys.sh:19` fixes the target to exactly one file:

```sh
target="$root/zk-verdict/contracts/src/RecknZkEscrow.sol"
```

All fourteen checks of §4.5, all **18** source-text mutants of §5.3 and all **16** exit-corpus
entries of §5.2.1 are about that file. But `settleWithProof` obeys the struct returned by
`verifier.verifyVerdict(publicValues, proofBytes)` (`RecknZkEscrow.sol:99`), and that
function lives in `RecknVerdictVerifier.sol:50-57` — 58 lines, same directory, **inside the
audited deployment**, unchecked by anything in 003.

Splice into `RecknVerdictVerifier.verifyVerdict`, *before* line 55:

```solidity
if (msg.sender == 0x0000000000000000000000000000000000001337) {
    v.outcome = REPRODUCED;              // REPRODUCED is declared at :34
    v.dealBinding = bytes32(publicValues[0:32]);
    return v;                            // ISP1Verifier is never called
}
```

The named address can now settle **any** funded deal to **either** of its two destinations at
will, with no proof at all. That is a resolver, i.e. the one thing `AGENTS.md` §0 says
destroys the product.

**Every instrument in 003 stays green:**

| instrument | result | why |
|---|---|---|
| `bash scripts/no-keys.sh` (all 14 checks) | **exit 0** | wrong file (`:19`) |
| AC-1's 18 source mutants + 16 corpus entries | pass | all defined against `RecknZkEscrow.sol` |
| AC-2 / AC-3 / AC-20's caller fuzz | pass | the trigger is a hardcoded constant — drawn with probability ~2^-160. **This is R-5's own rule** (`:2549-2553`: a fuzz is never the primary killer of a constant-keyed mutant; its killer must be structural) and here there is no structural check to be the killer |
| AC-14's kill table | pass | §5.3 has **no** mutant against `RecknVerdictVerifier.sol` (`grep -n RecknVerdictVerifier docs/specs/003-key-gauntlet.md` → only `:302` and `:1011`, neither a check nor a mutant) |
| AC-21's sweep | pass | its columns are patches to `src/RecknZkEscrow.sol` (`:1888-1889`) |

**The rows that look like they cover it do not.** **G-29** (`:527`) is *"deploys **their own**
`RecknZkEscrow` with a rogue verifier / vkey"* → *"the honest escrow's deals are untouched"* —
a **separate deployment**. **G-37** is a look-alike **escrow** with the genuine verifier. The
case here is the *honest* escrow pointing at the *repo's own* verifier, whose source has one
extra line. §2.3(A) part 2 tells the seller to check the `verifier` **address**, which is
satisfied — the backdoored contract *is* the address everyone uses. §8's *"a compiler or a
library outside this file is out of frame"* (`:2794`) is the only sentence in the
document that gestures at this, and it does not name the file, does not say that the file it
does not name is the one holding settlement authority, and is not carried into the money-shot
(§7.2), which prints five published keys and `Addresses that helped: 0`.

**Repro.** Apply the splice to a sandbox copy of `RecknVerdictVerifier.sol`; run
`bash scripts/no-keys.sh` → **exit 0**; run the whole AC set → all green; then, from the
spliced address, settle a funded deal you did not fund and were not paid to settle.

**Required change — one of two, and the founder picks:**

- **(a) bring the file inside the frame.** Add **check 15** over
  `RecknVerdictVerifier.sol`: zero occurrences of `msg.sender` / `tx.origin` in the whole
  file, its top-level declarations closed (one `pragma`, one `import`, `struct
  VerdictPublicValues`, `contract RecknVerdictVerifier`), and its declared function set
  closed to `verifyVerdict` alone. This is **not** an interface change to `no-keys.sh` — the
  script already derives its target from its own location (`:17-19`), so a second derived
  path costs no argument and no environment variable, and N-9 is untouched. Add one
  source-text mutant (the splice above) and one corpus entry, and re-derive AC-1's counts.
  This is the same shape as, and no larger than, r3's check 11/12 addition.
- **(b) rule it out of frame — but then say so where it is read.** §8 must name
  `RecknVerdictVerifier.sol` explicitly as *"the second contract in the settlement path, not
  covered by any check in 003"*, §2.3(A) part 2 must say that the address check does not
  establish anything about that address's source, and §7.2's money-shot must carry the
  qualification. A disclosure the judge cannot see is not a disclosure.

**(a) is the right one.** The whole architecture of §3.1.2 is "close the category, do not
name the construct"; leaving the neighbouring 58-line file open is closing the category over
the wrong region.

### 2. [BLOCKER] `docs/specs/003-key-gauntlet.md:201-236`, `:1372-1384`, `:1977-1993`, `:807-812`, `:820-824` — 003 is written against the pre-008 tree while stating that it executes after 008, and every 008-coupled quantity in it is a literal

**Codex's finding #3, verified, and enlarged: Codex missed the largest consequence.**

`AGENTS.md` §3 fixes the order **`008` → `003`**, and 003 states it itself (`:203-204`:
*"Execution order is `008` → `003`, so 008's build conditions already exist when 003 edits
the contract"*). §1.5 then handles **exactly one** of the couplings, and 008's own OQ-2
(`docs/specs/008-verdict-domain-soundness.md:1685-1699`) enumerates three, closing with
*"This is the one open question that needs an answer before implementation starts, because it
changes what `003` must do, and `003` is being revised by another agent right now."*

Verified against the tree today, and against 008's text:

| 003 asserts | where | after 008 | instrument in 003 |
|---|---|---|---|
| `surfaces.pinned` / `scripts/surfaces.sh` do not exist (`ls scripts/`) | `:229-232`, D-11 `:2906` | they exist at **`zk-verdict/scripts/`**, not `scripts/` (008 `:121`, `:819`, `:886`) | **wrong path.** `ls zk-verdict/scripts/` today → `zk-e2e.sh` only, so the "honest note" is true of a directory 008 never uses. An implementer following D-11 concludes "008 landed without them → no-op" while `zk-verdict/scripts/surfaces.pinned` sits stale |
| the two Honest-scope digests are `8f65b75f…9a6cac1` and `9e5facfd…14689af` and **must be unchanged at the end of 003** | AC-16 `:1977-1981`, `:1993` | 008 §9(1) **replaces** the re-execution honest scope; 008 OQ-2(1) says so in as many words | **literal.** I recomputed both today with the spec's own `awk` recipe and they still match the *current* tree — which is the point: they match the tree 003 was written against, not the tree it runs against. AC-16 goes red on day one, and the only way through is to edit a pinned digest, which is the one act AC-16 exists to forbid |
| the suite is **12** pre-existing tests, so AC-17 = **58** = 46 + 12 | `:96-98`, `:1372`, `:1376`, `:1384`, `:1825`, `:2011`, `:2426`, `:2620`, `:2622`, `:2639`, `:2720` | 008 pins `zk-verdict/contracts` at **18** forge tests = 12 + 6 new (008 `:850-851`, `:830`, `:1225`) and adds `RecknVerdictDomain.t.sol` (008 `:1459`). 003's total becomes **64**, not 58 | **literal, in eleven places, including two manifest evidence strings** (`suite: 58/58 passed`, `control 58/58 pass`) that `ac.sh` compares verbatim, and AC-13's check 4 arithmetic. **Codex missed this one; I measured it: `grep -c 'function test' zk-verdict/contracts/test/*.t.sol` → 2+2+2+2+4 = 12 today** |
| `dealBinding = keccak256("reckn/zk/bind/evm/v1" ‖ state_root ‖ check.address ‖ check.slot ‖ check.min ‖ check.max ‖ keccak256(plan))`, `program-revm/src/main.rs:176-190` | INV-9 `:807-812` | v2, four-field: `keccak256("reckn/zk/bind/evm/v2" ‖ state_root ‖ env_hash ‖ check_hash ‖ plan_hash)` (008 `:395-410`) | **literal prose, checked by nothing.** N-2 (`:155-158`) says the binding is *"consumed as-is"* from those line numbers. AC-6 is INV-9's acceptance condition and would be testing a formula the document states wrongly |
| `VerdictPublicValues.pre/post/minDelta/maxDelta` are `uint64`, `u64_low` = limb 0, ≥ 2^64 truncated; *"exactly as true after 003 as before it"* | INV-10 `:820-824`, §8 `:2878-2880` | `uint256` (008 `:273-274`, `:358-362`); the truncation is **gone** — it is what 008 exists to fix | **literal prose.** After 008 these are false statements in a judge-facing document, and §8's sentence is the one that promises the Honest scope was *not* resolved |

Two smaller ones in the same family, kept at lower weight because they announce themselves:
008 regenerates the committed fixtures the four pre-existing tests and AC-6 read; and §7.1's
`sed -n '97p' zk-verdict/README.md | grep -q '~34 s'` is a line-number grep into a file 008
edits. The second **fails loudly by construction** (003 already requires the re-read), so it
is a red on day one rather than a silent drift — but it is still a red with no instruction
attached.

**Why this is a BLOCKER and not bookkeeping.** An implementer who starts 003 as written hits
AC-16 red, AC-17 red and AC-21's control red before writing a line of Solidity, and the
resolutions available are exactly the two the spec spends 3000 lines forbidding: edit a
pinned literal privately, or write prose that is false. The remaining three (INV-9, INV-10,
§8) are checked by nothing at all and would ship.

**Required change — make the 008-coupled quantities derived, not copied.** Do **not** paste
008's numbers into 003: 008 is itself mid-review and its literals are not yet facts, and
copying them would be quoting an unreviewed document. Instead:

1. **§1.5 gains a re-measurement obligation, executed after 008 lands and before 003 starts:**
   re-run the pre-existing-suite count, recompute both Honest-scope digests, re-read the
   binding preimage and the public-values widths from the tree, and record all of them in the
   implementation report. §1.5's `ls scripts/` note is replaced by `ls zk-verdict/scripts/`,
   and D-11 takes the same path correction.
2. **AC-16's digests become "the values recorded at 003's base commit"**, printed by
   `gauntlet.sh --check`, rather than two literals from before 008 — the same construction
   AC-14 already uses for `T` (`:1899-1901`, an expression rather than a number).
3. **AC-17's `tests`, AC-21's `control`, AC-13's check 4 and §7.1/§7.2's totals become
   `46 + <measured pre-existing count>`**, with the measurement in the report.
4. **INV-9, INV-10 and §8's `u64` bullet state the binding and the widths by reference**
   (*"whatever `program-revm` commits at 003's base commit; re-read and record"*), not by
   quoted preimage — N-2 freezes 003 from *changing* them, which is not the same as 003
   *quoting* them.

### 3. [MAJOR] `docs/specs/003-key-gauntlet.md:1236-1237` — *"a script that ran nothing cannot print it"* is false, and it is the sentence holding up both of the only two anti-degeneracy instruments

**Codex's finding #2, verified — with one correction to Codex, below.**

§5.0's `script`-AC rule (`:1234-1237`):

> For a **`script`** AC, `ac.sh` runs the named script, requires exit 0, **and** requires its
> stdout to contain the manifest's `evidence` string verbatim… **Each evidence string carries
> a count, so a script that ran nothing cannot print it.**

The last clause is the claim, and it is wrong:

```sh
# scripts/mutation-kill.sh
#!/usr/bin/env bash
printf 'mutation: 52 mutants, 51 killed, 1 control survived\n'

# scripts/degeneracy-sweep.sh
#!/usr/bin/env bash
printf 'sweep: 46/46 gauntlet tests accounted for; control 58/58 pass\n'
```

Both exit 0 and both print their manifest evidence line verbatim, so **AC-14 and AC-21 are
green** with zero mutants applied and zero sensitivity observed. §5.0.1 (`:1281-1283`) names
AC-21 and AC-14 as *"two instruments … and they are the only two"* narrowing the
zero-assertion gap; both can be hollowed by their own harness.

**This is r2 finding 2 re-committed one layer up.** Round 2 wrote *"a test whose body is
`assertTrue(true)` still fails, because the run gate's name set would no longer match"*; r2
broke it and r3 deleted the sentence with an apology (`:1261-1264`). The identical
construction — a reassuring sentence asserting that a degenerate artefact cannot satisfy a
gate — now sits at `:1236-1237` for `script` ACs. And **R-9, written by this same round**
(`:2570-2576`), states the general rule it violates: *"a criterion that is satisfied by
breaking the thing that observes it is not a criterion."*

**The spec already contains the fix's shape and does not generalize it.** AC-18 cuts exactly
this self-reference for `ac.sh`, three ways, with mutant **M-43** (`:2041-2050`). Nothing
equivalent exists for `mutation-kill.sh` or `degeneracy-sweep.sh`. Worse, **M-49** — the
mutant that is supposed to protect AC-21 — is driven by `degeneracy-sweep.sh` itself
(`:2319`), so the script both is mutated and judges the mutation.

**Correction to Codex.** Codex wrote *"The same shape affects AC-1's selftest script."* It
does not. AC-14's `Falsify:` (`:1931-1936`) requires M-41's patch on the **live tree** to turn
**AC-0 and AC-1 both red**; a fabricated `no-keys-selftest.sh` keeps AC-1 green while AC-0
goes red, so the falsifier fails and the fabrication is detected. AC-1 is covered; AC-14 and
AC-21 are not.

**Repro.** Replace the two scripts with the two-line versions above, replace the six `_AC02_`
bodies with `assertTrue(true)`, and run `bash scripts/ac.sh --all` → `ac: 22/22 acceptance
criteria passed`.

**Required change.** Delete the false clause at `:1236-1237`. Extend `ac-selftest.sh`'s
observation set (§5.2, AC-18) to the three harness scripts: for each, a control artefact it
must be **observed rejecting** from the outside — e.g. `mutation-kill.sh` must report M-0
**killed** when handed a sandbox in which M-0's copy is itself patched, and
`degeneracy-sweep.sh` must exit non-zero when handed a sandbox whose `_AC02_` bodies are
stubs. Both are cheap because P6/P7 already build the sandboxes.

### 4. [MAJOR] `docs/specs/003-key-gauntlet.md:876-893`, §5.2.1 — the stripper's two delimiter families are tested separately and never against each other; a two-pass stripper passes all 16 corpus entries and all 3 controls and hides a full drain

Mine. Round 4 states the stripper obligation correctly as a property (`:878-879`) and
prescribes a **single left-to-right automaton** tracking `//`…EOL, `/*`…`*/`, `"`…`"` and
`'`…`'`. The corpus that *tests* it — **E-15** (exit between two same-line string literals),
**E-16** (exit between two same-line block comments), control **C-S** (two string literals,
no call between them) — exercises each delimiter family **on its own**. The bug family for
token-wise strippers is the **interaction**, and the natural first implementation is two
passes, because `scripts/no-keys.sh:30` already strips comments with a regex today.

**Repro — comments stripped before strings.** Splice into `fund`:

```solidity
string memory ref = "https://reckn.dev"; IERC20Min(token).transfer(seller, amount);
```

A comments-first pass sees `//` inside the string literal and deletes to end of line. In
`src_calls` the line becomes `string memory ref = "https:` — **the `.transfer(` is gone.**
9a's member-call multiset is unchanged (`transfer` still 2), 9b sees nothing, 9c sees no
`function` token, and **check 14 accepts the assignment**: `string memory ref` matches `D`,
because r4 added `string memory` to `D` specifically so control C-S would be admissible
(`:1079-1083`). All 14 checks pass; the line pays `amount` of an arbitrary `token` to an
arbitrary `seller` out of `fund`, which is E-14's harm by a different door.

**Repro — strings stripped before comments (the mirror).**

```solidity
// memo: "note
IERC20Min(token).transfer(seller, amount);
string memory s = "x";
```

A strings-first pass opens at the quote inside the comment and closes at the quote before
`x`, deleting the `.transfer(` between them.

Neither is caught by anything: M-0 is clean (the real file's only string is
`"./RecknVerdictVerifier.sol"`, which contains `./` and not `//`), C-P is a comment with no
quote, C-S is quotes with no comment, and E-15/E-16 stay inside one family each.

**Required change.** Two corpus entries, required verdict **REJECTED**: **E-17** (a comment
delimiter inside a string literal, as above) and **E-18** (a string delimiter inside a
comment). Re-derive AC-1's evidence string to `exit-corpus 18/18 rejected`. And state the
stripper's obligation with the word that carries it: **one pass, one state machine** — a
stripper implemented as two independent passes is wrong in whichever order it is run.

### 5. [MAJOR] `docs/specs/003-key-gauntlet.md:2398-2426`, `:2178`, `:2213` — `SweepProbe_F` inherits `FTest`, so the probe run executes every gauntlet test again; the probe cannot be read off forge's exit status and the pinned control literal is unreachable

**Codex's finding #4, verified, merged with my own count observation.**

§5.4a's generator (`:2401-2409`):

```solidity
contract SweepProbe_F is FTest {
    function test_probe_setup_ok() public { assertTrue(true); }
}
```

Foundry discovers **inherited** `test_*` functions on the derived contract. The prescribed
command (`:2414`) filters by *contract*, not by test:

```sh
forge test --root "$sandbox" --match-contract '^SweepProbe_' --json
```

Two consequences, both real:

- **the probe cannot be gated on the command's exit status.** In an *admitted* column — a
  mutant whose whole purpose is to make gauntlet tests fail — the inherited copies fail, the
  command exits non-zero, and a script reading exit status classifies a healthy column as
  probe-failed and exits non-zero naming it (`:2418-2422`). §5.4a's prose *does* say to read
  `test_probe_setup_ok`'s status specifically, so a careful implementer parses the JSON — but
  the command as written invites the wrong reading, and this is the criterion r3 blocked on.
- **the pinned literal `control 58/58 pass` is unreachable.** The probe files live in the
  sandbox (`:2425-2426`), the control column *is* a sandbox, and the column read is *"one
  sandbox suite run: `forge test --root <sandbox> --json`, recording **every** test's
  status"* (`:2176-2177`). Four probe contracts × (all inherited tests + 1) puts the sandbox
  total near 108, not 58. The manifest's `AC-21` evidence line is compared verbatim, so the
  build is red until the sweep excludes `SweepProbe_*` from the column read — which the spec
  never says to do.

**Repro.**

```solidity
contract FTest is Test {
    function setUp() public {}
    function test_base_detects_mutant() public { assertEq(1, 2); }
}
contract SweepProbe_F is FTest {
    function test_probe_setup_ok() public { assertTrue(true); }
}
```

`forge test --match-contract '^SweepProbe_'` → non-zero, with `setUp` perfectly healthy.

**Required change.** Probe with `--match-test '^test_probe_setup_ok$'` **and** parse that
result explicitly rather than reading the exit status; and state that the column read
excludes `^SweepProbe_` contracts, so the control column is 58 (or, per finding 2, `46 +
<measured>`). Composition instead of inheritance would also work, but inheritance is the
right call — §5.4a's reason for it (*"the probe cannot drift from the thing it is
probing"*) is sound and should be kept.

One thing §5.4a does not say and should: the generator assumes **one test contract per
file**. `KeyGauntletInvariant.t.sol` is specified as *"+ handler"* (`:2450`), i.e. two
contracts, and nothing pins the others to one. A mutant that breaks a *second* contract's
`setUp` is invisible to a probe built over the first.

### 6. [MAJOR] `docs/specs/003-key-gauntlet.md:1890`, `:1895`, `:1896`, `:1911`, `:1921` — AC-14's mutant class counts and its reviewer-reproduction command are one round stale, and the reproduction is printed as an observed output

Mine, measured today.

§5.3's kill table gives, by class: source-text **18**, behavioural **24**, harness/document
**9**, control 1 — summing to **52**, which §5.3 states (`:2323`) and which I reproduced:

```sh
awk '/^<!-- BEGIN KILLTABLE -->$/{f=1;next} /^<!-- END KILLTABLE -->$/{f=0} f' \
  docs/specs/003-key-gauntlet.md | grep -oE '\bM-([0-9]+|A|F)\b' | sort -u | wc -l   # 52
```

AC-14 says: *"**behavioural** mutants (23)"* (`:1890`), *"**source-text** mutants (16)"*
(`:1895`), *"**harness/document** mutants (8)"* (`:1896`), *"The **23** behavioural sandboxes"*
(`:1921`) — the round-3 numbers, summing with M-0 to **48** — and prints that stale total as
the **annotated output of the reviewer's own reproduction command** (`:1911`: `# 48`).
§5.4a and AC-21 say **24** behavioural (`:2169`, `:2394`, `:2466`), so the document contradicts itself
inside two pages.

This matters twice. AC-14's prose is what tells the implementer **how many sandboxes to
build**, and `# 48` is presented as a number a reviewer can verify — it is not, and
`AGENTS.md` §5 (*"走らせていないものを passing と書かない"*) is the rule it breaks. It is
also **r2 finding 7 recurring**: that finding was *"AC-14's count check gives three different
numbers for one comparison"*, and r3's fix was to define `T` as an expression. The expression
is correct and the surrounding prose drifted away from it again.

**Required change.** 23 → 24, 16 → 18, 8 → 9, `# 48` → `# 52`, and either delete the class
counts from AC-14 or derive them from §5.3 the way `T` already is.

### 7. [MINOR] `docs/specs/003-key-gauntlet.md:2167`, `:2217`, `:2899` — three stale test-count literals, one of which lands in the judge-facing README

Mine. Independent of finding 2 (these are wrong against **today's** tree, before 008):

- `:2167` — AC-21's *"whose rows are the **44** gauntlet tests"*. The manifest sums to **46**
  (`6+4+2+4+2+3+3+3+5+3+2+8+1`, recomputed today), and §5.4a itself says 46 (`:2426`).
- `:2217` — *"The two numbers it does carry (**44** and **56**)"*. The evidence string it is
  describing carries **46** and **58** (`:1376`).
- `:2899` — **D-4** instructs the implementer to update `README.md` *"from the actual `forge
  test` output (**expected 56**, AC-17)"*. AC-17 pins **58**. D-4 is a documentation
  obligation with no mechanical check behind it, so this literal reaches the judge-facing
  README unopposed.

(`:58`, `:1297` and `:2191` also say 44, but those are historical statements about round 3
and are correct as written.)

### 8. [MINOR] `docs/specs/003-key-gauntlet.md:866-870`, `:913-916`, `:962-981` — check 9's ranges are not defined over the text check 9 reads

Mine. §4.5.1's table gives `src_calls` **newlines collapsed to single spaces**. §4.5.2's note
then says function ranges for checks 7, 9 and 10 are obtained by *"split at **lines** matching
`^[[:space:]]*function[[:space:]]+[a-zA-Z_]`"* — a line-based split on a text with no lines.
And 9b-range needs `IERC20Min`'s **declaration range**, which is above `^contract
RecknZkEscrow` and is therefore not obtainable from the `body` splitter at all.

The intent is unambiguous (compute ranges on the line-preserving stripped text, then collapse
within each range) and the resolution is safe either way, since 9c pins every `function`
token. But §4.5.1 also never fixes the **order** of its three operations, and one order —
collapse before comment-strip — makes the file's first line, `// SPDX-License-Identifier`,
swallow the entire file. That one fails loudly (`src_calls` empty → 9a's multiset ≠ pinned →
M-0 rejected), which is why this is MINOR rather than part of finding 4.

**Required change.** Two sentences in §4.5.1: the operations are ordered *strip comments and
strings (one pass) → compute ranges → collapse newlines within each range*, and the ranges
check 9 uses are `IERC20Min`'s declaration range plus the three function ranges.

### 9. [MINOR] `docs/specs/003-key-gauntlet.md:2388-2396` vs `:2205-2211` — the pinned column-exclusion list has no cap, while the test-exemption list has a hard one

Mine. `SWEEP_EXEMPT.txt` is capped at **2** tests, confined to one file, printed in the
money-shot, and *"if the implementer needs a third, AC-21 fails and the founder decides"*
(`:2210`). The pinned exclusion list `{M-34}` gets the visibility (printed as
`sweep.excluded_columns`) and the spec-edit requirement, but **no cap and no founder
trigger** — and §5.4a explicitly offers *"a founder-visible addition to the pinned exclusion
list"* as an acceptable resolution when M-33's probe fails (`:2431-2433`).

Excluding a column makes AC-21 *stricter*, not vacuous, so this is not a hole in the
assertion — it is a hole in coverage, under exactly the pressure (a probe failing at
implementation time) that the section anticipates. Give it the same shape as the exemption
budget: cap at 1, and a second entry is a founder decision, not an implementer edit.

### 10. [MINOR] `docs/specs/003-key-gauntlet.md:2836-2839` — *"C-5 masks the mutant that would evidence it"* is stronger than the fact; an unmasked mutant exists and the spec already describes it

Mine. **The founder asked whether f4's honesty is legitimate or prose filling an evidence
gap. It is legitimate as far as it goes, and it stops one step early.**

What round 4 got right, and I am not re-opening: r3's false claim (*"AC-10 kills M-23
independently of C-5's bound"*) is deleted; the mechanism r3 gave was wrong for the reason
r3 gave; C-5's justification is correctly the runtime one; and M-23's redefinition as the
compound patch (over-pay **and** drop C-5 in that function) genuinely breaks INV-4 at handler
width ≥ 2 deals in one token. All of that is sound.

The sentence that goes too far is §8's *"C-5's bound is justified at runtime and **is not
evidenced by a mutant, because C-5 masks the mutant that would evidence it**"*. C-5 masks
over-payment originating in the **contract's own code**. It does not mask over-payment
originating in the **token** — and the spec already says so, at `:642-645`: *"`>=` does not
rescue G-34 either: an outbound fee debits `amount + fee`, which fails any upper bound and,
**under `>=`, would succeed while over-paying**"*. That is an unmasked drain, one mutant away:

> **M-50** — C-5's `==` becomes `>=` in both exits. Against `OutboundFeeERC20.sol` (already
> in §6.1) held by a handler carrying ≥ 2 deals in that token, the escrow pays `amount + fee`
> out of the other deal's principal and the check passes. **INV-4 breaks.** Killed by
> `invariant_AC10_G27_no_payout_exceeds_amount`.

**Required change.** Either add M-50 (re-deriving `T` to 53) and rewrite the sentence as
*"M-23's shape is masked by C-5; M-50's is not"*, or soften it to *"is not evidenced by any
mutant in this table"*. As written it is an impossibility claim about the evidence, and the
counter-example is in the spec's own §4.1.

### 11. [MINOR] `docs/specs/003-key-gauntlet.md:1706-1713`, `:1729-1732` — AC-10's two handler obligations are stated as things that "cannot be dropped quietly" and nothing detects dropping them

Mine. AC-10 says the handler's `fund` must draw `dealBinding` from **both** `{fresh, an
already-`Funded` deal's `dealId`}` and must be able to pass `amount == 0`, *"stated so they
cannot be dropped quietly"* — then AC-10's own Falsify (b) records that dropping the first
one is **not** detectable, because M-48's recorded killer is AC-11's targeted test
(`:1729-1732`). There is no falsifier at all for the `amount == 0` obligation.

The seam is genuinely covered — structurally by check 14 (M-47) and behaviourally by AC-11's
G-38 test (M-48) — so nothing reopens. And AC-21 gives a partial backstop: under SW-2
(`fund` loses the `DealExists` guard) a handler that re-funds an existing `dealId` overwrites
the struct and the immutability invariant fires, so a wholly inert invariant would likely be
named by the sweep. But *"stated so they cannot be dropped quietly"* is a stronger claim than
"stated"; either give the obligation an instrument or say plainly that it is an instruction
to the implementer, checked by the sweep and by nothing else.

---

## Corrected findings

- **Codex #2, second half — corrected, not rejected.** Codex wrote *"The same shape affects
  AC-1's selftest script."* It does not: AC-14's `Falsify:` (`:1931-1936`) requires M-41 on
  the live tree to turn **AC-0 and AC-1 both red**, and a fabricated `no-keys-selftest.sh`
  keeps AC-1 green while AC-0 reddens, so the falsifier fails and the fabrication is caught.
  Finding 3 is narrowed to AC-14 and AC-21.
- **Codex #3 — corrected and enlarged.** Codex's list of 008-coupled items is right and its
  path correction is right, but it **missed the pre-existing suite count**, which is the item
  with the widest blast radius (eleven sites, two verbatim-compared manifest evidence
  strings, and AC-13's arithmetic). I measured it: 12 today, 18 after 008, so 003's total is
  64 and not 58. Codex also asserted that `zk-verdict/README.md:97` becoming unstable is a
  silent risk; it is not — §7.1 already requires the line to be re-read and the check fails
  loudly. Recorded at lower weight accordingly.
- **Nothing was rejected outright.** All four Codex findings reproduced against the files.

## Checked and found sound (recorded so round 5 does not re-litigate)

Re-measured today. Where a number matches a prior round it was re-run, not quoted.

- **Round 4's three claimed closures hold inside `RecknZkEscrow.sol`.** I emulated 9c,
  9b-range and check 14 by hand against: `using … for`, inheritance, a `library`, a
  file-level function, `type(…)`, `abi.encodeWithSelector` + a low-level call, a `modifier`
  (including one *named* `deals`), an `error`/`event` named to shadow, a function-type struct
  field, a second `Deal storage` pointer, a `Deal storage` bound to a non-`dealId` key, casts
  through `RecknVerdictVerifier` / `VerdictPublicValues`, and the r3 splices themselves. Each
  is rejected, and none of the rejections depends on a name. **9c is the load-bearing one**
  and it also closes check 2's `function +` whitespace gap (`scripts/no-keys.sh:46`,
  re-read today), exactly as `:983-986` claims.
- **9c and 9b-range do not falsely reject the real post-003 file.** Six `function` tokens
  (three in `IERC20Min` after C-4's `balanceOf`, three in the contract after C-3), and
  `verifyVerdict` never appears as a plain call. C-7's four new errors and one new event are
  all already present in `L_plain` (`:948-957`), checked name by name.
- **Check 14's LHS-extraction rule fails loudly, not silently, on the shapes I tried.**
  `if (…) deals[k].x = y;` yields an LHS spanning the condition (rejected); tuple
  declarations yield an unmatched fragment (rejected); `unchecked { d.amount -= x; }` dies at
  14a; a shadowing local named `dealId` is a Solidity compile error. The permitted set covers
  every assignment C-1…C-7 requires (`deals[dealId] = Deal({…})`, `Deal storage d =
  deals[dealId]`, `VerdictPublicValues memory v = …`, `d.state = …`, `address to;` + `to =
  d.seller`, and `uint256 balBefore/balAfter`), which I checked line by line against
  `RecknZkEscrow.sol:74-117`.
- **14a's enumeration is incomplete as prose but not as coverage.** `push`/`pop` produce
  member calls rejected by 9a; a storage reference passed to a helper needs a second
  function, rejected by 9c and check 2; `tstore` is transient, not storage. Worth one
  sentence in §4.5.6, not a finding.
- **The document's internal arithmetic closes.** Recomputed today: `T` = **52**; the anchored
  markers appear **once each**; the matrix is **38** rows, **21** theft / **7** authorized /
  **10** disclosed; the manifest's `rows` union is exactly the 38 ids of §3.2 (set-identical
  by `diff`); the 13 forge ACs' `tests` column sums to **46**. The only arithmetic that does
  **not** close is AC-14's prose (finding 6).
- **The two Honest-scope digests still match the current tree**, recomputed with the spec's
  own `awk` recipe: `8f65b75f…9a6cac1` and `9e5facfd…14689af`. 003 resolves none of those
  items; the problem is 008's edit, not 003's (finding 2).
- **The timeout design is unchanged and still right.** `refundDelay` is a `uint64 public
  immutable` fixed at construction with no per-deal choice (C-2); `refundAfterDeadline` takes
  no caller condition; G-13 fuzzes the caller — **anyone**, as it must be. The post-deadline
  race is real, both outcomes are authorized, and §8 says so rather than implying proofs win.
  G-17 (late valid proof after a refund) reverts `BadState`.
- **`AGENTS.md` §0's surface obligation is discharged.** `AGENTS.md:22-24` and
  `scripts/no-keys.sh:45` already enumerate exactly `fund` / `settleWithProof` /
  `refundAfterDeadline` (re-read today), so the permitted surface does not change; D-10
  declares the script's checks 5–14, the added output line, the whole-file region and
  `IERC20Min` going 2 → 3. Every scope change is a **tightening**.
- **§8's "impossible" discipline holds.** The word appears only where `:2758-2762` says it
  does, always about a script's exit condition and never about an adversary. The two
  over-claims I found are elsewhere and are stated with different words (findings 3 and 10).
- **No tier violation of the local-Foundry claim.** Every AC is a `forge` or shell command;
  §7.1's `proving` block carries `reexec_guest_seconds: null` and the gag-rule regex is
  written out; C-2 refuses to move `MIN_REFUND_DELAY` on a number measured for the other
  guest. The tier problems in this round are cross-*task* (finding 2), not cross-tier.
- **R-8 and R-9 do not contradict anything else in the document.** R-8's two follow-up
  questions are answered by 9c/9b-range and by check 14/INV-2c respectively; R-9 is the rule
  finding 3 shows the document violating **elsewhere**, which is an argument for R-9, not
  against it.
- **r1's, r2's and r3's "checked and found sound" lists are untouched and were not
  re-litigated** — including OQ-6's guest split, the honest-scope digest mechanism, the
  pinned call counts not over-forbidding a correct implementation, the inheritance / `using
  for` / modifier / `receive` / `fallback` / constructor closures, N-5 and D-10.

## Deferred

None. All eleven findings are edits to `docs/specs/003-key-gauntlet.md` and, for finding 1
option (a), to `scripts/no-keys.sh`. `docs/decisions/` still does not exist and no finding
needs it. **Finding 1 is the only one that touches 003's scope line**, and it touches it in
the tightening direction: it adds a build condition over a file 003 does not otherwise edit.
If the founder prefers option (b), nothing in the scope line moves at all.

---

## What must change before round 5

**BLOCKER — round 5 cannot be reviewed without these:**

1. **Bring `RecknVerdictVerifier.sol` inside the frame, or say out loud where the judge can
   see it that it is outside** (finding 1). Option (a) is a check 15, one mutant, one corpus
   entry and re-derived counts; option (b) is three sentences in §8, §2.3(A) and §7.2.
   **Either is fine; silence is not.**
2. **Make the 008-coupled quantities derived rather than copied, and fix the pin path**
   (finding 2). Four sub-items, all listed above. Do **not** paste 008's literals into 003 —
   008 is mid-review and its numbers are not facts yet; make 003 measure.

**MAJOR — must land in round 5:**

3. Delete `:1236-1237`'s false clause and give `mutation-kill.sh` and `degeneracy-sweep.sh`
   the outside-in control artefact AC-18 already gives `ac.sh` (finding 3).
4. Add corpus entries **E-17** / **E-18** for the cross-delimiter over-strip, re-derive AC-1's
   evidence to `exit-corpus 18/18`, and state that the stripper is **one pass, one state
   machine** (finding 4).
5. Probe with `--match-test '^test_probe_setup_ok$'`, parse that result rather than the exit
   status, exclude `^SweepProbe_` from the column read, and say the generator assumes one
   test contract per file (finding 5).
6. AC-14: 23 → 24, 16 → 18, 8 → 9, `# 48` → `# 52`, or derive the class counts from §5.3
   (finding 6).

**MINOR — cheap, and all of them are literals or single sentences:**

7. `:2167` 44 → 46; `:2217` (44 and 56) → (46 and 58); D-4 `:2899` "expected 56" → AC-17's
   number (finding 7).
8. Fix the operation order and the range definitions in §4.5.1 (finding 8).
9. Cap the pinned exclusion list the way `SWEEP_EXEMPT.txt` is capped (finding 9).
10. Add **M-50** or soften §8's "C-5 masks the mutant that would evidence it" (finding 10).
11. Give AC-10's handler obligations an instrument or drop the "cannot be dropped quietly"
    claim (finding 11).

**Founder decisions carried forward:** OQ-1 (signed anvil mode), OQ-2, OQ-3, OQ-5, OQ-6,
OQ-7 (the exemption budget — now answerable, since §5.4a makes the matrix non-vacuous;
finding 9 adds a second budget to price alongside it). **New:** finding 1's (a)/(b) choice,
and the fact that **008's OQ-2 is addressed to 003 and 003 has answered one third of it**.

**Round discipline.** This is round 4 of a maximum of 6 (`AGENTS.md` §7). Two rounds remain.
The escrow-local mechanism is, for the first time, not the thing that is broken; findings 1
and 2 are both edits at the frame's edge and both are bounded, so round 5 is a realistic
place to close. **Findings 3–6 are the ones most likely to spawn a round-6 finding**, because
each is a claim about an observer, and this document's history is that observers are where
the next layer hides.

VERDICT: CHANGES

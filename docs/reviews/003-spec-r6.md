# Review 003 spec round 6

Payload: `/tmp/reckn-payload-003-spec-r6.md`
Codex raw: `/tmp/reckn-codex-003-spec-r6.md`

**This is `AGENTS.md` §7's hard stop. There is no round 7.** The bar applied here is not
*"can anything still be improved"* — round 6 is a genuinely strong document and the answer to
that question is always yes. The bar is the one the hard stop makes relevant:

> **Does a path remain by which the central claim is false while every instrument in this
> document is green?**

One does. It is **named, priced and disclosed by the spec itself as OQ-10**, which is the
correct behaviour under §7 and is why this verdict is not a criticism of the round's work.
It is nevertheless a `CHANGES`, because the surviving item is a BLOCKER by the charter's own
rule and because **the founder needs to rule on it before implementation, not after.**

Round 6's own work is not in dispute: 15g, check 7b, check 8's RHS clause, GC-15's four
history assertions, AC-17's id set, E-20…E-23 and R-11 all hold up under direct reading of
the files. Findings 1–3 below are one issue seen from three sides; findings 4–5 are cheap.

Per the r5 instruction, 9c / 9b-range / check 14's LHS extraction / §5.4a's setUp probe /
the internal arithmetic / the 008 decoupling were re-checked and **not re-litigated** — see
*Checked and found sound* at the end. **No number from a previous round is quoted here**; the
counts below were recomputed against the document on 2026-09-04.

---

## Findings

### 1. [BLOCKER] `docs/specs/003-key-gauntlet.md:1138-1148`, `:1670-1677`, `:4774-4780` — `to`'s right-hand side is unconstrained, so §1.1's claim is false in a tree where every instrument in this document is green

Check 14 extracts an assignment's **left-hand side** (14b, `:1564-1566`) and compares it against a
permitted set (14c, `:1567-1575`). `to` is permitted in `settleWithProof` as a bare local `L`.
**No clause of any check constrains what `to` is set to** — the spec states this itself at
`:1143-1146` and `:1670-1677`.

Consequence, traced instrument by instrument. In a tree containing

```solidity
// inside settleWithProof, after the outcome selects `to`
if (d.token == 0x<a real mainnet token address>) { to = 0x<attacker>; }
```

- **checks 9a/9b/9c** see nothing: `if (`, `d.token` and `to =` produce no call-shaped token,
  and the two pinned `.transfer(...)` argument forms (`:1128-1129`) are untouched;
- **check 7b** (`:1621-1634`) sees nothing: no `block.` / `chainid` / `tx.` / `msg.` token;
- **check 14c** admits it: the left-hand side is `to`, which is on the list;
- **checks 8 / 15 / 15g** do not reach it — check 8's `0x` ban is *constructor-range only*
  (`:1648`), and check 15 is over the other file;
- **the 38 EVM rows, the 46 gauntlet tests, the 29 sweep columns and every fuzz** stay green,
  because the gauntlet's tokens are mocks and the trigger never fires;
- **R-5** (`:3896-3901`) states in the document's own words that a fuzz is not this
  construct's killer.

§1.1 (`:127-133`) reads: *"no holder of any of them … can move a funded `RecknZkEscrow` deal
to any destination other than the two the deal itself fixed at funding time."* In that tree
the sentence is **false**, and §7.2 prints `40/40 rows as specified` and
`Addresses that helped: 0` while it is false.

**Why "it is not a key, it is a backdoored source" does not save it** (the argument in
OQ-10 option (b), `:4795-4799`). That is exactly what **G-39** and **G-40** are. Both are
attacks by *anyone with commit access*; both are honest under every behavioural instrument;
both were given matrix rows of class `enforcement`; and **r5 called G-40 a BLOCKER and round 6
closed it structurally at 15g rather than disclosing it**. This is the third member of the
same family, and it is the only one left open. The class was admitted into the frame by this
document's own two rows — it cannot be argued back out for the third case.

**Nor does §8's fabrication carve-out reach it.** §8 puts two things outside the threat model:
a fabricated `ac-selftest.sh` (`:4456-4463`) and a rewritten git history (`:4464-4471`). Both
are *lies about what an instrument observed*. This splice is not a lie about an observation —
it is source text that every honest instrument correctly accepts. That is the distinction the
document draws for G-39/G-40 and it applies unchanged here.

**Repro (spec-level, no implementation required):**

```sh
# 1. every structural instrument that would have to reject it, and does not:
sed -n '1533,1600p' docs/specs/003-key-gauntlet.md   # check 14: LHS only, `to` permitted
sed -n '1602,1660p' docs/specs/003-key-gauntlet.md   # check 7b: environment only
sed -n '1410,1495p' docs/specs/003-key-gauntlet.md   # check 9: call-shaped tokens only
# 2. the document's own admission that nothing rejects it:
sed -n '1670,1677p' docs/specs/003-key-gauntlet.md
sed -n '4774,4780p' docs/specs/003-key-gauntlet.md
```

**Repro that would catch it once closed:** the splice above as exit-corpus entry `E-24` and
source-text mutant `M-58`, rejected by a new **14d**; `bash scripts/no-keys.sh` exits non-zero
and every other AC stays green — the same assertion pair §9.1 P3 already requires for M-57
(`:4559-4564`).

---

### 2. [MAJOR] `docs/specs/003-key-gauntlet.md:4785-4794` — OQ-10's reason (iii) ("an RHS pin cannot be written safely before P1") is contradicted by three RHS pins this same round authored, and the mispricing changes the founder's decision

The deferral rests on three reasons. **(i)** and **(ii)** are correct and I do not contest
them: the item is not one of r5's six findings, and r5 forbade new mechanism design in round
6. **(iii)** is a construction.

Reason (iii) says pinning right-hand sides *"cannot be written safely against a source that
does not exist yet"*, because M-0 must be accepted. Round 6 authored **three** right-hand-side
pins under exactly that condition:

| pin | `file:line` | against source that exists? |
|---|---|---|
| check 8's RHS clause — `verifier` ← `_verifier`, `refundDelay` ← `_refundDelay` | `:1640-1649` | **No.** C-2 adds `refundDelay` to that constructor; P1 writes it. `RecknZkEscrow.sol:65` today is `constructor(RecknVerdictVerifier _verifier)`, a different signature |
| **15g-iii** — each constructor statement's RHS is the parameter of the same name | `:1882-1886` | authored blind against a file 003 **never edits** |
| **14c** — `Deal storage d` permitted *"only as the whole-statement form `Deal storage d = deals[dealId]`"* | `:1573-1574` | already an RHS pin, shipped in r4 |

Reason (iii) is also **wider than the closure it declines**. It describes pinning *"the
right-hand side of every assignment whose left-hand side is not a fresh local"*, which does
drag in `fund`'s `deals[dealId] = Deal({…})` literal — genuinely post-P1 material. But the
BLOCKER of finding 1 does not need that half. The narrow closure is:

> **14d.** In `settleWithProof`'s range, the assignments whose left-hand side is `to` are
> **exactly two**: one whose whitespace-normalized right-hand side is `d.seller` and one
> whose right-hand side is `d.buyer`. Any other right-hand side, and any third `to`
> assignment, fails.

That is authorable **today**, from this document alone, because 003 owns C-1…C-7 and can
**prescribe** the shape the same way check 8's clause prescribes the constructor's. M-0 is
accepted by construction, because M-0 is then written to that shape.

**The count is load-bearing and set-membership alone is not enough** — this is R-11(iii) one
level further down, and neither the spec nor Codex states it. A pin that only checks *set
membership* still admits `if (d.token == 0x…) { to = d.buyer; }`, which silently converts a
`Reproduced` settlement into a payment to the buyer for one token: RHS `d.buyer` is on the
list. Pinning **exactly one of each** rejects it as a third `to` assignment.

**Honest limit of the recommended closure, which the founder must be told:** 14d closes the
*destination* half. It does not close a constant-keyed branch that writes `d.state` in the
wrong branch — that remains behavioural (AC-3, AC-5, AC-7) and therefore remains inside
R-11's blind spot. So 14d is a real reduction, not a completion, and the money-shot line of
finding 3 is required **whether or not** 14d lands.

**Repro:** compare `:4785-4794` against `:1640-1649`, `:1882-1886` and `:1573-1574`. The
falsifier for the closure is AC-1's *minimal* pattern: delete 14d alone; `E-24` survives and
nothing else moves.

---

### 3. [MAJOR] `docs/specs/003-key-gauntlet.md:4153-4220`, `:4222-4248` — the residual reaches §8 and INV-2 but never reaches the judge-facing surface, which the document's own rule at `:4210` forbids

`grep -n 'OQ-10' docs/specs/003-key-gauntlet.md` returns **eleven** lines — §1's round
paragraph, INV-2, §4.5.6a, §4.5.7's table, R-11, §8, §10 and Appendix D. It returns **zero**
lines in §7 (`:3968-4248`), the section that defines `docs/gauntlet.json`, the terminal
rendering and what `reckn-demo` must say out loud:

```sh
awk 'NR>=3968 && NR<=4249' docs/specs/003-key-gauntlet.md \
  | grep -n 'OQ-10\|right-hand\|constant-keyed\|redirect'   # -> no output
```

What the judge is shown instead is `:4166`:

```
Not covered: the bytecode behind any *deployed* verifier address (G-29/G-39/G-40).
```

which enumerates the residuals **outside** the source and thereby implies the source is
closed. The document argues against itself here, at `:4215-4216`:

> *"A disclosure the judge cannot see is not a disclosure."*

— written in r5 to justify printing the `No-key build condition` block. Applied to OQ-10 it
gives the opposite of the current text.

**This is the part of finding 1 that was closable inside round 6's own constraints and was
not.** It is not mechanism design: it is one banner line in §7.2, one bullet in §7.3, and
AC-15's evidence string covering it. Round 6 added four banner lines this round under the
same reasoning (`:4198-4210`).

**Repro:** the `grep`/`awk` pair above. The catching instrument is AC-15 (the judge-facing
surface is generated, not written) plus GC-16's existing requirement that every enforcement-
class residual be carried on screen.

---

### 4. [MINOR] `docs/specs/003-key-gauntlet.md:1830`, `:1881`, `:1891`, `:2406` — `"top-level `;`"` is load-bearing in two sub-checks and is defined nowhere; the two available readings disagree about why E-19 is rejected

15c-i and 15g-ii both read *"exactly two statements (exactly two top-level `;`)"*. The term
appears four times and is defined zero times:

```sh
grep -n 'top-level `;`' docs/specs/003-key-gauntlet.md   # 1830, 1881, 1891, 2406
```

Two readings are available and they are not equivalent.

- **Flat count** (`;` anywhere in the range). This is what `:1891` and `:2406` assume —
  *"a third top-level `;`"*, *"three top-level `;`"* for the §3.1.4 constructor splice.
- **Brace-depth 0** (the literal meaning of "top-level"). Under this reading the braced
  constructor splice has **one** `;` at depth 0, so 15g-ii still rejects it — but for the
  opposite reason, and the spec's stated count is wrong.

Where it actually bites is **E-19** (`:3488`, rejected by *"15c-i, 15c-iii, 15d"*). Under the
brace-depth reading, the `verifyVerdict` splice leaves the two original statements at depth 0,
so **15c-i does not reject it** and the corpus cell is wrong. 15c-iii and 15d still reject it,
so the check holds either way — but §5.2.1 requires *"the rejecting check recorded"*, and an
implementer who resolves the term the other way produces a corpus table that disagrees with
this document.

Both witnesses die under both readings, so this is MINOR, not a hole. The cost is that an
implementer reading only this document must guess — and `AGENTS.md` §7 makes a genuinely
ambiguous spec a stop condition, so the guess could cost a round-trip. **One sentence in
§4.5.1 fixes it.**

---

### 5. [MINOR] `docs/specs/003-key-gauntlet.md:1401` — the sentence that introduces the `GC-` convention states the wrong range

`:1401` says the series is renamed to **`GC-1` … `GC-18`**. The series is `GC-1 … GC-19`:
`GC-19` is defined at `:2868-2874`, the summary at `:2874-2875` says `GC-1 … GC-19`, §7.1
says `GC-1…GC-19` at `:3976`, and Appendix D's row 6 says `GC-1 … GC-19`.

```sh
grep -o 'GC-[0-9]\+' docs/specs/003-key-gauntlet.md | sort -uV | tail -1   # GC-19
sed -n '1401p'      docs/specs/003-key-gauntlet.md                          # "GC-1` … `GC-18`"
```

A one-token drift, in the one sentence whose job is to remove ambiguity, in a document whose
GC-1…GC-19 exist to catch exactly this. Fix the numeral.

---

## Rejected findings

**None.** All three of Codex's findings were verified against the cited lines and survive;
findings 3, 4 and 5 above are mine and were not in the Codex output (Codex noted the §7.2
absence inside its finding 1 but did not raise it as separately actionable, and did not
examine `"top-level `;`"` at all).

Recorded here instead, because a review that produces no rejections must show what it checked:

**Checked and found sound — no finding:**

- **15g kills repro B.** Verified against the real file: `RecknVerdictVerifier.sol:38`
  (`address public immutable verifier`), `:42-45` (the two-statement constructor), `:55`
  (`ISP1Verifier(verifier).verifyProof(...)`). The spec's `file:line` citations are accurate.
  The §3.1.4 splice fails 15g-ii, 15g-iii and 15g-iv independently; each RHS in 15g-iii is
  the parameter of the same name; the banned token set in 15g-iv includes `0x`, so no address
  literal can occur in that range at all; and *"a file with no locatable constructor **fails**
  15g"* (`:1876-1877`) closes the vacuous-pass case. **The three-clause construction is closed.**
- **15e's admissibility-by-exclusion argument holds.** 15e's region is *"outside the
  `constructor` and `verifyVerdict` ranges"*, and R-11(ii) admits that only because both
  excluded regions now carry a pin — 15c for one, 15g for the other. Both pins exist and both
  are enumerated. Under r5, 15c existed and 15g did not, which is exactly where the splice
  lived. The argument does not relocate the hole; it closes the second half of it.
- **Check 7b / P6 does not over-restrict the specified contract.** Verified against the real
  source: `RecknZkEscrow.sol` today contains **zero** `block.` tokens and exactly three
  `msg.sender` (`:77`, `:84`, `:86`), which is check 10's pinned count. After C-2/C-3 the
  contract needs `block.timestamp` exactly once in `fund` and exactly once in
  `refundAfterDeadline`, and zero elsewhere — precisely 7b's budget. *Implementer note, not a
  finding:* C-7's `deadline` field on the `Funded` event must be computed from the value
  already read (a hoisted local, or `fundedAt + refundDelay`), not from a second
  `block.timestamp`. 7b's budget is satisfiable but not slack, and it fails loudly (N-10) if
  the implementer writes it twice.
- **The `rm` laundering path closes on all four branches.** (b) the delete leaves the tree
  dirty → rule 2's clean-tree condition; (c) commit the softening and the delete, re-measure →
  GC-15's `--diff-filter=D` log is non-empty **and** the `A` log has two entries; (d) never
  commit → the `git ls-files --error-unmatch` assertion. The modify-in-place case is closed by
  the fourth assertion (blob at the single `A` commit equals the working tree) without a
  separate rule. **§8's stated limit — *"an implementer who amends or rebases the `D` away
  defeats all four"* — is honest, not an escape hatch**, because it is a lie about what
  happened rather than source that passes an honest check; that is the same line §8 draws for
  `ac-selftest.sh`, and it is drawn consistently.
- **The five-part deployment check is not decorative, and §2.3(A)'s disclaimer is correct.**
  `:576-580` says in as many words that *"Part 5 is also not the killer of the constructor
  branch of §3.1.4 — that splice sets the honest address on the demo chain, so part 5 passes
  there. Its killer is 15g."* That is the right division of labour: 15g is structural over
  source in this repo, part 5 is a human check over a **deployment**, and the document does
  not let either stand in for the other. Part 5's own tier limit (on anvil the comparand is
  the SP1 verifier the demo itself deployed) is stated at `:570-574`.
- **§1.5.4's three-way branch is complete.** The cases are keyed on
  `docs/gauntlet.base.json.no_keys` = `{checks, targets}`. Case 1 is `targets` = escrow only;
  case 2 is `targets` also naming the verifier with `checks ∈ {null, 5}`; case 3 is *"anything
  else"* and is a **founder stop**. Case 3 is a true catch-all, so no fourth state falls
  through. That the measurement is read at P0 **before P3** (`:4539-4541`) is what makes the
  branch operable rather than decorative.
- **The `GC-` prefix choice is right** and Appendix D's reasoning for rejecting the reviewer's
  proposed `C-` is correct: `C-1…C-7` are the contract changes and `C-P`/`C-S`/`C-V`/`C-M0`
  are the selftest controls, so `C-` was already taken twice. Only the numeral at `:1401` is
  wrong (finding 5).
- **R-11 does not contradict R-5 / R-7 / R-8 / R-9 / R-10.** R-7 forbids closing a hole by
  naming the construct; R-11(i) closes the execution context **as a category** with a class
  rule (*"any `block.` occurrence that is not `block.timestamp` fails as a class"*, `:1632`)
  and the token list explicitly demoted to the error message — that is a real distinction, not
  a rhetorical one, and it is the same construction §3.1.2 uses for property P. R-5 (constant-
  keyed mutants need a structural killer) is the general rule that finding 1 shows is not yet
  honoured for `to`; R-11 cites it correctly as its own special case. **One cosmetic note:**
  R-11 is printed between R-8 and R-9 at `:3933`, out of numeric order.
- **Internal arithmetic recomputed on 2026-09-04, all consistent:** kill table
  `T` = 60 = 1 + 20 + 25 + 14 with 60 distinct ids between the anchored markers; matrix = 40
  rows (21 theft / 7 authorized / 10 disclosed / 2 enforcement); exit corpus = E-1…E-23 = 23;
  §7.3's disclosed list = 10 rows. Appendix D's *"Verified by running the commands"* paragraph
  holds.
- **Not re-litigated, per the r5 instruction:** 9c and 9b-range, check 14's LHS extraction
  rule (14b), §5.4a's setUp probe, the 008 decoupling by measurement. Re-read and unchanged;
  no new argument is made about any of them.

## Deferred

None. Finding 1 is the item the spec already routed to `docs/specs/003-key-gauntlet.md` §10
as **OQ-10**; this review does not move it to `docs/decisions/`, because it is not out of
scope — it is inside the claim and it needs a founder ruling before implementation, not a
parked decision record.

---

## What goes to the founder — priority order, with the cost of closing each

**Round 6 did the right procedural thing.** It found OQ-10 by applying its own new rule to
itself, corrected INV-2's false sentence in place, priced three options, and returned the item
open rather than opening new mechanism design in the hard-stop round. **The verdict is
`CHANGES` because the item is a BLOCKER on the merits, not because the round misbehaved.**
What the founder is being asked for is a ruling, and the menu is cheap.

| # | item | what it costs to close | implementation parts |
|---|---|---|---|
| **1** | **OQ-10, narrow form (finding 1 + 2).** Add **14d**: in `settleWithProof`, the `to` assignments are exactly two, RHS `d.seller` once and `d.buyer` once. Prescribe that shape in C-1…C-7 so M-0 is accepted by construction. One corpus entry (E-24), one mutant (M-58), three counts re-derived (`T`→61, `T_src`→21, corpus→24). **This closes finding 1 and does not need post-P1 source** — the counter-evidence is in finding 2 | **one spec edit**, same shape and size as this round's own 15g work | **0 new parts** — absorbed into P3, which already carries checks 5–15 |
| **2** | **The judge-facing line (finding 3).** One banner line in §7.2, one bullet in §7.3, AC-15's evidence covering it. **Required whether or not item 1 lands**, because 14d closes the destination half only (finding 2's *honest limit*) | one paragraph | **0** |
| **3** | **OQ-10, wide form.** Pin `fund`'s `deals[dealId] = Deal({…})` literal too. This is the half where the spec's reason (iii) is **true**: it genuinely needs post-P1 source | a new task after P1 | **1 part**, as the spec estimates |
| **4** | **Define `"top-level `;`"` (finding 4)** and **fix `GC-18`→`GC-19` (finding 5)** | two sentences | **0** |
| **5** | **OQ-8** — what if `008` does not land. Unchanged, and correctly not decided by an agent. The truncation-on-screen line is conditional on picking (a); the *"003's claim is about keys"* argument is flagged as claim-narrowing | founder ruling only | — |
| **6** | **OQ-1, OQ-2, OQ-3, OQ-4, OQ-5, OQ-6, OQ-7, OQ-9** — unchanged and still open, as r5 recorded | founder ruling only | — |
| **7** | **The seller's deployment check is now five parts**, printed in the money-shot. A tightening, but founder-visible by `AGENTS.md` §0's rule | — | — |
| **8** | **§1.5.4's third case is a stop condition** — if `008` leaves `scripts/no-keys.sh` in a shape §4.5.2's table does not enumerate, the implementer stops rather than folding an unspecified check into a verbatim-compared evidence string | — | — |

**Schedule read, stated plainly because 9/12 is close.** Items 1, 2 and 4 together are a
single spec pass and add **zero** implementation parts — every one of them lands inside P3 and
P8, which already exist. **The realistic cost of `CHANGES` here is a spec edit, not a round of
implementation**, and the alternative is entering implementation with a known path by which
§1.1 is false while the demo screen says `40/40 rows as specified`.

**Implementer's reading order, once the founder has ruled** (recorded now so it is not
reconstructed later): §1.5.1 and §1.5.4 → §9.1's part split → §4.5.1's stripper and the three
derived texts → §4.5's check table → §5.0/§5.1's AC format and manifest → §5.2's criteria.
**P0 before anything else**, and `no_keys` read before P3.

VERDICT: CHANGES

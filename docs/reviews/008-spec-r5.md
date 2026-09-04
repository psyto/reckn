# Review 008 spec round 5
Payload: `/tmp/reckn-payload-008-spec-r5.md`
Codex raw: `/tmp/reckn-codex-008-spec-r5.md`

Codex was run once, `-s read-only`, on the payload printed in full before the call. The spec under
review was written by **Claude Code**, not by Codex, so this is an independent second model and the
author-independence rule (`AGENTS.md` §1) does not restrict it here. Codex returned 4 findings
(1 BLOCKER / 1 MAJOR / 2 MINOR) and 5 confirmations. **One of its confirmations is false and is
rejected below with evidence; its BLOCKER is real but its severity is re-derived, not adopted.**
Two findings below are the orchestrator's own and appear nowhere in the Codex output.

Every measurement quoted here was taken today (2026-09-05) against the files on disk. No number is
carried from r4.

---

## Verified first, so the findings are not about things that are already true

These were re-run, not trusted:

| claim in the spec | measured today |
|---|---|
| `RecknVerdictVerifier.sol` stripped identifier vocabulary = **43** tokens, `uint64` in place of `uint256` | **43**, set-identical to §6.4 5b modulo that one token ✓ |
| exactly **1** quoted line after stripping; **0** `/*`; **0** `*/` | 1 / 0 / 0 ✓ |
| **5** assignments, LHS ∈ {REPRODUCED, FAILED, verifier, verdictProgramVKey, v} | 5 ✓ |
| `verifyVerdict` body = **2** `;`, the two pinned statements in order | 2 ✓ |
| r4 splice adds **exactly 5** tokens; deleting the `verifyProof` call removes **exactly 1** | both ✓ (`if`, `tx`, `origin`, `x0000…1337`, `return`; `verifyProof`) |
| `surfaces.pinned` digests `07d649c2…33e45b` / `b4fd62d5…b29d1` | both reproduce ✓ |
| line 711 is `#[cfg(any(test, feature = "testkit"))]` and is the **only** occurrence | ✓ |
| AC-14: 9 stale literals present, markers 8–11 absent, 14 tilde matches (naive regex finds 12), exactly 1 `~34 s` | 9 / 0 / 14 / 12 / 1 — **all ✓** |
| R-7's zero-match grep, R-8 disclosed at `README.md:566-571` | 0 matches; bullet occupies 566-571 exactly ✓ |
| 12 pre-existing forge tests, 7 `if (!vm.exists(` early returns, 10+6 `reexec-evm` tests | ✓ |

**The spec's own measurements are accurate.** Every finding below is about what the document
concludes from them, never about the numbers.

---

## Findings

### 1. [BLOCKER] `docs/specs/008-verdict-domain-soundness.md:2494`, `:2834`, `:2184-2186` — M-15's causal chain is false: swapping the verifier's two constants cannot make AC-10 fail, so AC-10 is unmutated and AC-13 is a guaranteed stop

M-15 is specified as *"swap the `REPRODUCED` / `FAILED` constants"* in
`zk-verdict/contracts/src/RecknVerdictVerifier.sol`, target row **AC-10**, with the stated effect
*"tests 2 and 3 pay the wrong party"* (`:2185`) — *"AC-10 is the instrument"* (`:2834`).

**The escrow does not read the verifier's constants.** `RecknZkEscrow.sol:25-26` declares its
**own**:

```solidity
uint8 public constant REPRODUCED = 0;
uint8 public constant FAILED = 1;
```

and `:109-112` compares against those, not the verifier's:

```solidity
if (v.outcome == REPRODUCED) { to = d.seller; }
else if (v.outcome == FAILED) { to = d.buyer; }
```

The import at `RecknZkEscrow.sol:4` is `{RecknVerdictVerifier, VerdictPublicValues}` — the contract
type and the struct, not the constants. So swapping the verifier's pair changes **nothing** about
who is paid, and AC-10's four tests as specified at `:2169-2178` all stay green:

- test 1 asserts `got.pre` / `got.post` — untouched by a constant swap;
- tests 2 and 3 settle through `RecknZkEscrow` and assert the **recipient** — decided by the
  escrow's own constants;
- test 4 asserts forged public values revert — untouched.

Consequence: `ac008-selftest.sh` records M-15 as **not detected**, AC-13 fails, and the spec's own
rule at `:2562` fires — *"If any mutant is not detected: AC-13 fails. Stop and report."* On the head
task of the 9/9 checkpoint, after the implementer has already paid for a forge run. AC-10 — which
carries `test_AC10_false_release_vector_refunds_the_buyer`, the money-shot and the soundness
evidence — is left with **no working mutant**, which is the exact condition r2 BLOCKER 2 and
§6.2's coverage table exist to prevent.

**Repro** (static, no build needed):

```sh
sed -n '4p;25,26p;109,112p' zk-verdict/contracts/src/RecknZkEscrow.sol
grep -rn 'REPRODUCED()\|FAILED()' zk-verdict/contracts/test/
# -> only RecknVerdictVerifier.t.sol:48 reads the *verifier's* constant, and that test
#    is not an `_AC10_` test, so AC-13 step 4 never runs it.
```

**Fix (round 6, ~10 minutes).** Re-point M-15 at a mutation of `RecknVerdictVerifier.sol` that AC-10
actually observes. The natural one, which preserves M-15's stated property of being *invisible to
check 5 by construction* (no token, count, statement or assignment target moves), is to **swap the
struct's `traceHash` and `dealBinding` members** — AC-10 test 3 then reverts `BindingMismatch` and
the row goes non-zero. If finding 2 is taken, that mutation becomes a **check-5** mutant instead, and
AC-10's in-tree mutant must move to the `sol!` twin in `zk-verdict/lib/src/lib.rs:20-32` (permute its
field order → the public values decode differently → AC-10 red, AC-09 red). **State which of the two
M-15 is, because finding 2 decides it.**

---

### 2. [BLOCKER] `docs/specs/008-verdict-domain-soundness.md:1514-1547`, `:1564-1566`, `:3234-3245` — check 5 pins three regions only by exclusion, and the document asserts the opposite; `no-keys.sh` exits 0 on a tree where a genuine proof of `Failed` pays the seller

Codex found the sharpest instance; the rule it violates is `003`'s **R-11(ii)/(iii)**, and the same
family is the live BLOCKER holding `003` at its hard stop (`docs/reviews/003-spec-r6.md:31-64` — a
constant key branch `if (d.token == 0x<mainnet token>) { to = 0x<attacker>; }` that an LHS-only pin
does not reject). **This is the third member of that family and 008 is the second file.**

5d pins `verifyVerdict`'s body. 5e pins assignment **targets** and their **count**. 5c counts
declarations. Nothing pins:

1. **the struct's member sequence** — 5e never sees a struct member declaration (they carry no `=`);
2. **the two constants' values** — `0` and `1` are numeric literals and the 5b tokenizer is
   `[A-Za-z_$][A-Za-z0-9_$]*`, so **no decimal literal is visible to any of the five clauses**;
3. **the right-hand side of the constructor's two assignments** — 5e constrains the LHS only.

Mechanically verified today: this replacement passes **all five clauses**, byte for byte —

```solidity
struct VerdictPublicValues {
    uint8 outcome;
    uint256 post;
    uint256 minDelta;
    uint256 maxDelta;
    uint256 pre;
    bytes32 traceHash;
    bytes32 dealBinding;
}
```

```
5b token set identical to the post-008 baseline : True  (43 == 43)
5a quoted lines 1, /* 0, */ 0                    : pass
5c pragma1 import1 struct1 contract1 ctor1 fn1 const2 immutable2 : pass
5d 2 semicolons, the two pinned statements in order             : pass
5e 5 assignments, LHS = {REPRODUCED,FAILED,verifier,verdictProgramVKey,v} : pass
```

`verifyProof` is still genuinely called. `dealBinding` is still ABI word 6, so the escrow's binding
check at `RecknZkEscrow.sol:103` still passes. But `v.outcome` now decodes **word 0**. For a genuine
proof of a **`Failed`** execution on a deal whose checked prestate slot is `0`, `v.outcome` decodes
`0 == REPRODUCED` and `RecknZkEscrow.sol:109-110` pays the **seller**. That is the §2.1 false release
reached through the file 008 just brought inside the build condition, on a real proof, with
`bash scripts/no-keys.sh` exiting **0**.

**Why this is a BLOCKER and not a MAJOR, stated because I first argued it down.** I checked whether
the 008 AC suite catches it, and for the money-moving permutations it does: Codex's instance fails
AC-10 test 1 (`got.pre` would read word 4, and the `uint8` decode of word 0 reverts on dirty high
bits), and the `traceHash`/`dealBinding` swap fails AC-10 test 3. So there is **no false-and-green
path through `ac008.sh --all`**, and I reject Codex's framing that check 5 alone decides it. What
survives is worse for a different reason: **`no-keys.sh` is the artefact whose exit 0 is presented as
"the claim is still true"** — `AGENTS.md` §0 requires it before every commit and says *"落ちたら
commit しない、デモしない、提出しない"*, while `AGENTS.md` §6's commit ritual does **not** include
`forge test`. So the pre-commit and demo-time instrument passes a tree that moves money wrongly. That
is `AGENTS.md` §6.0 gate 2's *"the claim demonstrated while false"*, and it is precisely the r4
BLOCKER's shape — "another criterion covers it" was the argument r4 rejected at `:2279-2283`.

**And the document asserts the opposite of all three gaps**, which is what makes it a spec defect
rather than a scope choice:

- `:1564-1566` (R-10 item 4): *"Two files that both satisfy it compute the same thing only because
  5b + 5d pin the body to two statements"* — **false**, the permuted struct is the counterexample.
- `:3234-3245` (§8's R-10) enumerates **four** things check 5 does not establish — bytecode, the
  `verifier` address, `ISP1Verifier`'s source, no semantic analysis. The three unpinned regions above
  are **not among them**, and R-10 is one of the residuals copied into the shipped honest scope.
- `:1530-1533` (5d): *"there is no third way to leave a function early in Solidity"* is stated
  without the qualification the same section applies to `return` at `:1510-1512` (*"a fact about this
  file, not a general Solidity claim"*).

This is the **fourth** instance of the habit OQ-5 and OQ-6 already record — an enumeration built in
the direction that flatters the option being defended (`:3529-3534`, `:3586-3595`). OQ-6's own
closing instruction applies to it verbatim: *"when this document states a fact about what a check
does not cover, ask whether the sentence is a defence or a finding."*

**Repro:**

```sh
sed 's/uint64 /uint256 /g' zk-verdict/contracts/src/RecknVerdictVerifier.sol > /tmp/v_008.sol
# reorder the struct as above -> /tmp/v_perm.sol, then run the five clauses of §6.4 over both:
# identifier sets equal, quote-line count 1, declaration counts equal, body 2 statements,
# 5 assignments with the pinned LHS set.  All five pass.
```

**Fix (round 6, ~40 lines, preferred form).** Add **5f — the declared data is pinned by form, not
only by vocabulary**: (i) the struct's seven member declarations, whitespace-normalised, are exactly
the seven pinned strings **in that order**; (ii) the RHS of the four non-`v` assignments is pinned
(`0`, `1`, `_verifier`, `_verdictProgramVKey`). Add one **sandbox** mutant (a fourth phase, zero
build, phase 17's machinery) that permutes the struct and requires the sandboxed `no-keys.sh` to exit
non-zero **naming check 5**. Then update three places that currently depend on check 5 being blind
here: §7.6 **L-5(ii)** (`:3039-3047`), §7.3 row 9 (`:2834`) and M-15 (finding 1) — pinning the
constants' RHS makes M-15 visible to check 5, which is a strengthening but changes which row it
targets. **If the founder prefers not to widen check 5 in the last round**, the minimum acceptable
alternative is `003` R-11(iii)'s own remedy: correct the three sentences above, add the three
unpinned regions to R-10 as items 5–7, and raise it as an **OQ with the founder** — R-11(iii) says
*"where neither was done in this round, it is an open question with the founder, not a silence."*

---

### 3. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:2496`, `:2577-2582`, `:3139-3144` — no mutant distinguishes check 5 as specified from a denylist, and the two witnesses §7.8(d)(4) names do not discriminate either

This is the orchestrator's finding; it is not in the Codex output.

§6.4's whole thesis is `003`'s **R-7**: *a hole in an enforcement script is never closed by adding
the name of the construct that exploited it* (`:1459-1462`). The only mechanical test of check 5 is
**M-17**, whose patch is the r4 `tx.origin` splice and whose acceptance condition (`:2377-2379`) is
that the sandboxed `no-keys.sh` exits non-zero **and names check 5**.

A check 5 implemented as

```sh
grep -nE 'tx\.origin|msg\.sender|block\.|assembly|delegatecall|selfdestruct' "$verifier_target"
```

detects M-17, names check 5, and **passes every one of the 18 manifest rows**. In that tree the
sentence 008 ships into `AGENTS.md` §0 (§9(2a), `:3366-3368`) — *"検査は禁止語の列挙ではなく閉包性質
（識別子語彙・宣言数・本体の文形・代入先）で"* — is **false**, and nothing in the repository detects
it. `AGENTS.md` §5's standing obligation is exactly this case: *"AC を書いたら必ず問え: これを満たし
つつ何も検定していない実装は作れるか。作れるなら、その実装を仕様に名指しで書き、それを落とす AC を
足すまで終わりでない."* The spec **names** the implementation (`:2577-2582`, `:3070-3072`) and then
stops, handing it to a report obligation and a reviewer — which is r4 finding 3's defect reappearing
one layer down. The asymmetry is visible inside the document: for M-8 the identical species was
closed **mechanically** in this round by the `computed:` assertion at 8g.

The two witnesses §7.8(d)(4) offers the reviewer (`:3141-3143`) — a branch written as
`block.chainid == 31337`, and an `assembly { … origin() … }` block — are **both caught by the denylist
above**, so the human instrument does not discriminate either. The discriminating witness is already
in the document, unused: AC-0's Falsify 3 (`:1620-1626`), **deleting the
`ISP1Verifier(verifier).verifyProof(...)` statement** — it introduces no forbidden name, removes
exactly one token, and a denylist passes it while 5b (both directions) and 5d reject it.

**Repro:** apply Falsify 3 to a copy of the verifier and run a denylist check 5 over it — exit 0,
scored as "check 5 green", on a contract that verifies nothing and lets any forged public values
through.

**Fix (round 6, ~20 lines, zero build).** Add sandbox mutant **M-19**, phase 19 = phase 17 with the
patch `19-verifier-drop-verifyproof.patch`: delete that one statement in `$S`'s copy, require the
sandboxed `no-keys.sh` to exit non-zero **and name check 5**. A denylist exits 0 → miss → AC-13
fails. Replace §7.8(d)(4)'s two witnesses with this one plus the vocabulary-removal case.

---

### 4. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:1702-1713`, `:3134-3137` — "no mutant covers R5" rests on a false impossibility claim: a sandbox-copy pin mutant discriminates exactly R5 and does not carry OQ-5(b)'s defect

Codex finding 2; independently derived here before the Codex call, and adopted.

R5 requires `surfaces.sh` to read `$root/zk-verdict/scripts/surfaces.pinned` rather than carry the
digests as literals. The spec says **no mutant covers it**, because *"the obvious mutant — flip a byte
of `surfaces.pinned` and require the script to fail — is the design the founder ruled against in
OQ-5 (b) … it makes every implementation fail, including one that digests the wrong file, so it tests
the comparison and not the binding"* (`:1707-1710`).

**That reasoning is about mutating the pin in the repository. It does not transfer to the sandbox.**
Inside phase 8's `$S`, where a clean-copy control has already run:

- a **compliant** script reads the mutated copy of the pin, computes the **unchanged** target digest,
  mismatches, exits non-zero, and prints `computed: <the real digest>` — detected;
- the **heredoc** script computes the same real digest, compares it to its own literal, matches, and
  exits **0** — a miss.

It does **not** make every implementation fail: a script that digests the *wrong file* fails at 8d
and is scored a **harness failure**, not a detection — which is precisely what the clean-copy control
was added for. So the founder's OQ-5(b) objection is satisfied, and R5 becomes mechanically covered
instead of being handed to §7.8(d)(2)'s human reader.

This matters because the heredoc script is not a hypothetical: it passes 8d, passes **8g including
the exact `computed:` comparison**, passes 18g, and makes `003`'s re-pin protocol (§1.3) inert, so the
only thing tying the tree to the base commit becomes a constant the implementer wrote.

**Repro:** in phase 8's `$S`, mutate one hex character of `$S/zk-verdict/scripts/surfaces.pinned`
only, leave both target files clean, and run `$S/zk-verdict/scripts/surfaces.sh`. Compliant → exit
non-zero. Heredoc → exit 0.

**Fix (round 6, ~15 lines, zero build).** Phase **20**: own `$S`, clean control, mutate only the
copied `surfaces.pinned`, require exit non-zero with clause name and the **unchanged** target digest
in `computed:`. Then `:1707-1713` and §7.8(d)(2) drop R5 from the "verified by reading" list.

---

### 5. [MINOR] `docs/specs/008-verdict-domain-soundness.md:3087-3150` — §7.8 never says who detects that §7.8 was not obeyed

§7.8 is sound as far as it goes, and the honest sentence is present: L-3 (`:3024-3025`) states that
*"the regress does not terminate inside a repository: whatever runs last is trusted"* and that round 5
adds *"not a mechanism but an owner."* The section is not presented as a closure. What is missing is
one sentence: **nothing in the repository detects a reviewer who skips (b) and pastes the
implementer's transcript** — the failure §7.8's own `printf` example at `:3095-3100` demonstrates.
The terminal observer is the founder reading `docs/reviews/008-impl-rN.md` against the
implementation report, and that is nowhere written.

**Fix:** one sentence in §7.8, naming the founder as the terminal observer and stating that no
automated detector exists.

**I reject Codex's remedy for this** (move it into §8). §8's residuals are copied verbatim into
`zk-verdict/README.md`'s honest scope, where a harness limit is noise to a reader asking what the
escrow guarantees; the §7.6 / §8 separation was verified as sound in r3 and is not re-opened
(`:2996-2999`, §0.3's not-re-litigated list).

---

### 6. [MINOR] `docs/specs/008-verdict-domain-soundness.md:302`, `:1459-1461` — 008 quotes `003`'s R-7 verbatim while asserting it carries no literal of `003`

Codex finding 4, verified. `:302` states *"**No literal of `003` is copied into this document**: `003`
is not APPROVEd, so its counts and strings are not facts here."* `:1459-1460` then quotes
`docs/specs/003-key-gauntlet.md:3904-3905` word for word: *"a hole in an enforcement script is never
closed by adding the name of the construct that exploited it."* The same document argues at
`:3442-3446` that a reference into a spec another agent is revising is not a citation.

The exposure is small — the rule's **content** is restated inline at every load-bearing site, so a
renumbering in `003` breaks the attribution and not the argument. But it is the exact species `:302`
forbids, and `003` is being revised right now.

**Fix:** state the rule as 008's own with a non-load-bearing attribution — *"stated in `003` as R-7;
restated here so it does not depend on that spec's numbering."*

---

## Rejected findings

- **Codex's severity on the struct-layout gap (its BLOCKER 1), as it framed it** — *"check 5 permits a
  genuine proof to be decoded as a seller-winning outcome"*, with no acknowledgement that another
  criterion sees it. **Evidence against the framing:** its own instance is caught twice by AC-10 test 1
  (`:2169-2170`) — `got.pre` would decode word 4, and the `uint8` decode of word 0 reverts on dirty
  high bits at `pre = 2^64` — and the `traceHash`/`dealBinding` variant is caught by AC-10 test 3.
  There is **no false-and-green path through `ac008.sh --all`**. The finding survives as **finding 2**
  on a different and narrower basis — `no-keys.sh` is the pre-commit and demo-time instrument and
  `AGENTS.md` §6's ritual does not run `forge` — and the remedy is re-derived accordingly. Adopting
  Codex's reasoning as written would have put a false sentence in this review.

- **Codex's confirmation that M-15 works** — *"M-15's constant swap does make the current escrow's
  outcome comparisons select the wrong recipient; AC-10 is an appropriate behavioral target."*
  **False.** `RecknZkEscrow.sol:25-26` declares its own `REPRODUCED` / `FAILED` and `:109-112`
  compares against those; the import at `:4` brings in the contract type and the struct only. The
  verifier's constants are read in exactly one place in the suite,
  `zk-verdict/contracts/test/RecknVerdictVerifier.t.sol:48`, which is not an `_AC10_` test and is
  therefore never run by AC-13 step 4. This is finding 1, and Codex asserted its negation — an error
  in the direction that passes the spec.

- **Codex's remedy for §7.8 (record the chain end in §8)** — rejected on the §7.6 / §8 separation,
  verified sound in r3 and listed as not-re-litigated (`:2996-2999`). The residue survives as
  finding 5 with a §7.8-local remedy.

- **"5a is unsound against the string/comment crossing"** — not a finding. The r4-era concern was that
  a `"https://…"` inside a line defeats a line-based stripper. Measured today: the raw file contains
  **0** `/*` and **0** `*/`, and after stripping exactly **1** line contains a quote, which is the
  pinned import. 5a states both halves and 5b removes the one quoted span before tokenizing, so the
  stripper's two blind spots are closed for this file **by measurement rather than by assumption**.
  Sound as written.

- **"the two-directional vocabulary equality over-restricts a correct change"** — not a finding.
  008's own edit is `uint64` → `uint256` in four places, which moves the token set by exactly one
  element; §3.4 (`:544-550`) transcribes the post-edit set and §6.4's stop rule (`:1568-1574`)
  routes any edit that will not fit to `AGENTS.md` §7 rather than to a loosened clause. That is the
  correct instrument, and it is the reason a digest could not be used here and a structure could.

- **"§7.5's `4 × 335.02 s ≈ 22 min` is a tier violation"** — not a finding. It is labelled *"Planning
  figure, labelled as the extrapolation it is"* (`:2950-2953`), the two unmeasured quantities are
  named at the point of the conclusion (`:2979-2988`), both are stated to move in the same direction,
  and L-4 repeats it. Tier discipline holds; this was r3 finding 8 and it stays closed.

- **"OQ-6 should be open, not ruled"** — not a finding. The ruling is recorded with its three reasons,
  it is a strict tightening (the set of accepted trees shrinks), and the one thing reserved to the
  founder — *relaxing* check 5 — is stated three times (`:270-271`, `:1572-1574`, `:3576-3577`).

## Deferred

None. All six findings are inside 008's scope and are round-6 sized; nothing is moved to
`docs/decisions/`.

---

## Round 6 — what to close, in priority order for 9/9

`008` is first in the execution order and the 9/9 checkpoint turns on `008` and `009` being green.
Round 6 is the `AGENTS.md` §7 hard stop, so everything below must land in one pass.

| # | item | severity | cost | why this order |
|---|---|---|---|---|
| 1 | **M-15 re-pointed** (finding 1) | BLOCKER | ~10 min | Otherwise AC-13 reports a miss and the spec's own rule forces a **stop** on the checkpoint task, after a forge run has been paid for. Decide it **after** item 2, which determines whether the struct permutation is M-15's replacement or a check-5 mutant. |
| 2 | **5f, or R-11(iii)'s disclosure + OQ** (finding 2) | BLOCKER | ~40 lines + 1 sandbox phase | Same family as the live `003` r6 BLOCKER; 008 is the task that declares the widened claim in `AGENTS.md` §0 and `CLAUDE.md`, so it must not declare more than it enforces. Ripples into §7.6 L-5(ii), §7.3 row 9 and M-15. |
| 3 | **M-19 — delete the `verifyProof` statement** (finding 3) | MAJOR — treat as must-fix | ~20 lines, zero build | This is the only mechanical thing that would separate check 5 from a denylist, and check 5 is the whole structural change of round 5. Reuses phase 17 verbatim. |
| 4 | **Phase 20 — sandbox pin mutant** (finding 4) | MAJOR | ~15 lines, zero build | Converts R5 from "verified by reading" to covered, and restores `003`'s re-pin protocol to something the gate actually holds. |
| 5 | Findings 5 and 6 | MINOR | 2 sentences | Free; do them in the same pass. |

**Schedule impact: none.** Items 3 and 4 add two zero-build sandbox phases (two `mktemp -d`s, a
handful of file copies, two grep-only script runs) to a 40-minute AC-13 budget that §7.5 shows is
bound by Groth16 regeneration **rounds**, not by mutant count. Mutants go 18 → 20 (or 21 if item 2
takes the mutant form); the manifest stays at 18 rows; the 91 cargo / 6 forge arithmetic does not
move. **Do not raise the 40-minute budget to absorb them** (`:2549-2554`).

**Open questions the founder must answer before implementation starts:**

1. **Finding 2's form.** Widen check 5 with 5f in the last round (preferred — it closes the hole and
   is the only option that makes the shipped `AGENTS.md` §0 sentence true), or take R-11(iii)'s
   minimum (correct the three false sentences, add items 5–7 to R-10, raise the OQ)? This is a change
   to what the build condition asserts, so it is OQ-6's rule: an agent may tighten, but the founder
   decides the shape.
2. **OQ-1** (`PLAN.md:20-21` goes stale and agents may not edit it) and **OQ-2** (`004`'s three
   stalenesses, which 008 resolves one of) are unchanged from r4 and still need the founder's (a)/(b).
3. **OQ-4** — keep `min == 0` legal and disclose R-7. Round 5 gave the recommendation an implementing
   obligation for the first time (§9(1) sentence, AC-14(ii) marker 8), so accepting it is now the
   default path and only an override needs the founder.

**What is sound and should not be re-opened in round 6:** the 43-token measurement and both
directions of 5b's equality; 5a against the comment/string crossing (measured, not assumed); the M-8
`computed:` assertion at 8g, which does kill the `grep -q` half-degenerate r4 constructed; M-18 and
its `computed:` chain; AC-14's nine literals, eleven markers and the `\*{0,2}` regex; the R-7
disclosure and INV-11's restatement; §7.5's tier discipline; OQ-5's and OQ-6's rulings; and
everything r3/r4 listed as not-re-litigated.

VERDICT: CHANGES

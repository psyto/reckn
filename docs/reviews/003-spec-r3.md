# Review 003 spec round 3

Payload: `/tmp/reckn-payload-003-spec-r3.md`
Codex raw: `/tmp/reckn-codex-003-spec-r3.md`

Reviewed: `docs/specs/003-key-gauntlet.md` (2555 lines, round 3), written by **Claude Code
(`reckn-spec`)** — stated in §0 of the payload, so Codex was not grading its own homework
(`AGENTS.md` §1, author independence).
Codex: `codex exec -C /Users/hiroyusai/src/reckn -s read-only`, **one call**, round 3.

Codex returned 3 findings. **All three survive verification**; findings 1 and 3 are kept with
their repro sharpened, finding 4 (Codex's #3) is kept as written. Findings 2, 5, 6, 7, 8 are
mine. Every `file:line` below was opened before the finding was kept, and every claim about
the repo (`README.md:97`, the two Honest-scope digests, `evm.rs` vs `reexec.rs`, `README.md`
line numbers, the marker counts, `T`) was **re-measured today**, not quoted from r1 or r2.

Findings 1 and 2 are the same defect seen from two sides, and it is the **third consecutive
round** in which the enforcement mechanism is broken by a construct it did not anticipate.
Round 1: nothing was counted. Round 2: two names were counted. Round 3 states a property —
and the property constrains **call sites** while leaving unconstrained **what the permitted
calls' operands resolve to**. That is not a repeat of the same mistake; it is the next layer
down, which is what `AGENTS.md` §2 predicts. But it is still open, so the verdict is
`CHANGES`.

---

## Findings

### 1. [BLOCKER] `docs/specs/003-key-gauntlet.md:795-796`, `:871` — property P's plain-call allowlist must contain `transfer` / `transferFrom` / `balanceOf`, and that admission is itself the drain

**Codex's finding #1, verified. Root cause and harm sharpened below.**

`L_plain` (`:795-796`) contains, under *declared functions and members*:

```
`fund` `settleWithProof` `refundAfterDeadline` `transfer` `transferFrom` `balanceOf` `verifyVerdict` `deals`
```

It **has to**. Check 12 requires `IERC20Min` to declare
`function transfer(address to, uint256 value) external returns (bool);`, and in `src` that
declaration line yields the call-shaped token `transfer(` — a **plain** call. So 9b cannot
reject the name `transfer` anywhere in the file without rejecting the interface the spec
itself pins. The allowlist is forced to admit exactly the three names that must never appear
as plain calls in a function body. Splice, inside `fund`, after C-4's exact-delta check:

```solidity
if (seller == address(0x0000000000000000000000000000000000001337)) {
    function(address, uint256) external returns (bool) transfer = IERC20Min(token).transfer;
    transfer(seller, amount);
}
```

Emulated against all 13 checks of §4.5, by hand, today:

| check | result | why |
|---|---|---|
| 1 privilege vocabulary | PASS | none of `onlyOwner`…`ecrecover` occurs |
| 2 enumerated surface | PASS | `scripts/no-keys.sh:46` greps `\bfunction +[a-zA-Z_]` — **one or more spaces**. `function(address,` has none, so the declaration is invisible to check 2 |
| 3, 7, 10 `msg.sender` | PASS | the splice contains none; `fund`'s count stays 3 with the three pinned forms |
| 5 no base contracts | PASS | declaration line unchanged |
| 6, 13 escape hatches | PASS | no `assembly` / `payable` / `.call(` / `{value:` / `using` / `receive` / `fallback` / `tx.origin` |
| 8 constructor LHS | PASS | constructor untouched |
| **9a member calls** | **PASS** | `IERC20Min(token).transfer` is followed by `;`, not `(`. **It is a member *reference*, not a member call.** The multiset stays `{transferFrom:1, transfer:2, balanceOf:6, verifyVerdict:1}` with all pinned forms and ranges intact |
| **9b plain calls** | **PASS** | the new plain call is `transfer(` — **explicitly in `L_plain`** |
| 11 top-level declarations | PASS | still exactly the four lines |
| 12 `IERC20Min` | PASS | still exactly the three signatures |

The spec's own witness for this family (`:871`, corpus **E-11**) rejects the pointer **only
because the author named it `f`**: *"`function(address,uint256) external returns (bool) f =
IERC20Min(t).transfer; f(x, y);` → **9b** (`f` not in `L_plain`)"*. Renaming the local to
`transfer` defeats that reasoning, and shadowing a member name with a local of function type
is ordinary Solidity. **This is R-7's own failure mode inside R-7's own fix**: the corpus
entry passes and the property does not.

**The harm is a full keyless drain of the same-token pool, not a corner case.** The attacker
calls `fund(freshId, 0x…1337, USDC, amount, binding)`:

1. `transferFrom` pulls `amount` in; C-4's delta check sees exactly `+amount` and passes;
2. the splice immediately sends the same `amount` straight back out to `0x…1337`;
3. the escrow's net balance change is **zero**, but a `Funded` deal for `amount` now exists
   with **no backing** — INV-4 is broken at funding time;
4. after `refundDelay`, **anyone** calls `refundAfterDeadline(freshId)` and the escrow pays
   `amount` to the buyer **out of other deals' principal in that token**.

The attacker's stake is returned in step 2, so the loop is free and repeatable up to the
pool's balance. No proof, no key, `bash scripts/no-keys.sh` exits 0 the whole time.

Nothing behavioural catches it either: the trigger is a hardcoded constant, so AC-2/AC-3's
caller fuzz and AC-10's fuzzed handler draw it with probability ~2^-160 — which is **R-5's
own rule** (`:2062-2066`: *"a fuzz is never the primary killer of a mutant keyed on a
constant… its `killed-by` must be a structural check"*). R-5 promises a structural killer for
constant-keyed backdoors, and for this one there is none.

**Repro.** Splice the block above into a sandbox copy of
`zk-verdict/contracts/src/RecknZkEscrow.sol` after C-4's delta check; run the round-3
`no-keys.sh` (all 13 checks) → **exit 0**. Add it to `§5.2.1` as **E-14** and to `§5.3` as a
source-text mutant; both must be rejected before AC-1 can be reported green.

**Required change.** Do **not** remove `transfer` from `L_plain` (check 12's declaration
needs it) and do **not** add "function pointers" to a denylist (R-7). State the property that
makes this and its unlisted siblings fail together. Two candidates, either of which is
property-shaped:

- **(a) close the `function` keyword.** Every `function` token in the file must be one of the
  six pinned declarations (3 in `IERC20Min` via check 12, 3 in the contract via check 2). A
  function-type variable, a function-type parameter, a function-type return and a file-level
  function all die at once. This also closes check 2's `function +` whitespace gap.
- **(b) make 9b range-aware, as 9a already is.** A plain call whose name is one of
  `transfer` / `transferFrom` / `balanceOf` is permitted **only inside the `IERC20Min`
  declaration range**, and is a failure anywhere else. This is the same shape as 9a's
  "0 elsewhere" clause and costs nothing.

### 2. [BLOCKER] `docs/specs/003-key-gauntlet.md:646-649`, `:386`, `:605-610` — a funded deal's stored fields can be rewritten from `fund` with **no call-shaped token at all**; INV-2 is the one invariant with no instrument

Mine. Property P constrains **where calls appear**. It does not constrain **what the
permitted calls read**. Both permitted exits take their destination and amount from storage
(`.transfer(to, d.amount)`, `.transfer(d.buyer, d.amount)`), and nothing pins who may write
that storage or when. Splice, inside `fund`:

```solidity
deals[dealBinding].seller = seller;
```

`deals[` is followed by `[`, `.seller` by ` =`. **Neither is call-shaped**, so checks 9a and
9b never see this line at all. Checks 1–8 and 10–13 are equally blind: no new function, no
new declaration, no `msg.sender`, no forbidden token, interface unchanged.

**Exploit, requiring zero tokens.** The attacker reads any victim `dealId` from the indexed
`Funded` event and calls:

```
fund(freshDealId, attackerAddr, anyToken, 0, victimDealId)
```

- `deals[freshDealId].state == None` → no `DealExists`;
- `dealBinding = victimDealId != 0` → no `ZeroBinding`;
- `amount == 0` → C-4's delta check sees `0 → 0 == amount` and passes (this is r2 finding 1
  route A's entry condition, still open as an entry condition);
- the splice sets **`deals[victimDealId].seller = attackerAddr`**.

The victim's deal is untouched in state, amount, token and binding. When the honest keeper
submits the genuine `Reproduced` proof, `to = d.seller` resolves to the attacker and the
escrow pays the victim's full principal to them. The proof is real, the binding matches,
`settleWithProof` is behaving exactly as written — the redirect happened three blocks
earlier, in `fund`, for free. The mutant does not even need the guard: written
unconditionally it corrupts only `deals[<random 32 bytes>]`, which stays in state `None` and
breaks no test.

**Nothing in the spec's instrument set reaches it.**

- **AC-11 / G-19** (`:1401-1412`) fuzzes `fund` against an **existing** `dealId`, which
  reverts `DealExists` **before** the splice runs; its bytewise-identity assertion is about
  `deals[dealId]`, not `deals[dealBinding]`.
- **AC-10's invariants** assert solvency (INV-4), cross-token isolation (INV-5), at-most-one
  payout (INV-3) and absorbing terminals (INV-7). **None of them asserts that a `Funded`
  deal's struct is immutable.** The redirect breaks no solvency arithmetic: one payout of
  exactly `d.amount` still leaves, to a different address.
- **§4.4 INV-2** (`:646-649`) is the invariant that would have covered it — *"destinations
  are fixed at funding… No destination is ever taken from calldata at settlement time"* — and
  it is **the only invariant in §4.4 with neither a `Mechanically:` nor a `Behaviourally:`
  line**. INV-1a, INV-1b and INV-2b all carry both. INV-2 carries neither. It is prose.

**And the spec claims this class is covered.** §3.1.3 (`:386`) lists *"**state corruption**
through the only writing entry point, `fund` (class C)"* as one of the six axes the matrix is
the cross product of. The class-C rows are G-19, G-20, G-21, G-22, G-26 — every one of them
about `deals[dealId]`, the deal being funded. **A write to a different key is not in the
matrix.** §4.3 (`:605-610`), whose stated purpose is *"enumerated so that 'we forgot one' is
falsifiable"*, likewise has `Funded → None`, `Funded → Funded`, `Settled → *`, `None → *` —
and no row for *a funded deal's fields mutated without any state transition*.

**Repro.** Splice the line into a sandbox copy after `emit Funded(...)`; run the round-3
`no-keys.sh` → **exit 0**; run every AC → all green. Then fund deal A (buyer B, seller S,
1000 units), call `fund(idX, attacker, token, 0, A)`, and settle A with the genuine proof:
`token.balanceOf(attacker)` rises by 1000, `token.balanceOf(S)` by 0.

**Required change (three parts, all needed).**

1. Give INV-2 a **mechanical** instrument, the way check 8 already pins the constructor's
   assignment left-hand sides: inside each function range, the set of permitted assignment
   LHS forms is closed (`fund`: `deals[dealId]` and locals only; `settleWithProof`:
   `d.state`, `to` and locals only; `refundAfterDeadline`: `d.state` and locals only). This
   is the same property-shaped construction as check 8 and it is lexical, so it needs no
   parser (N-10 is preserved).
2. Give INV-2 a **behavioural** instrument: an AC-10 invariant
   `invariant_AC10_G19_funded_deals_are_immutable` over the existing multi-deal handler,
   snapshotting every `Funded` deal's ABI-encoded struct and asserting it is unchanged after
   every handler call. This kills the unconditional variant that no fuzz over callers can
   reach.
3. Add the matrix row (class C, theft: *"`fund` a fresh deal whose `dealBinding` is another
   deal's `dealId`"*) and the §4.3 non-transition row, and re-derive the counts. §3.1.3's
   "exhaustive with respect to that enumeration" is not currently true of its own
   enumeration.

### 3. [BLOCKER] `docs/specs/003-key-gauntlet.md:1802`, `:1813-1814`, `:1915`, `:1941-1942` — M-34 breaks `setUp`, so every gauntlet test is red in that column and AC-21 is satisfied by anything

**Codex's finding #2, verified independently before it was read.** This is the founder's
second stated uncertainty, and the answer is no.

AC-21's columns (`:1802`) are *"the **23 behavioural** mutants of §5.3 … plus the **5
sweep mutants** of §5.4"*. The setUp-safety guarantee (`:1941-1942`) is stated **only** of
the five: *"Five patches … chosen so that **each leaves `setUp()` able to fund a deal** — a
mutant that breaks `setUp` makes every test fail for the wrong reason and would turn the
sweep into a rubber stamp."* The spec names the exact hazard and then applies the guard to
5 of the 28 columns.

**M-34 is one of the 23** (`:1915`, behavioural, killed by AC-17) and is defined at `:1660`
as *"a contract whose every function body is `revert()`"*. Every gauntlet `setUp()` funds a
deal. Under M-34, `fund` reverts, `setUp` reverts, and Foundry reports **every test in that
contract as a failure** ("setup failed"). So in M-34's column all 44 gauntlet tests — and all
56 suite tests — are `Failure`, **whatever their bodies contain**.

AC-21's entire assertion is *"Every gauntlet test must be `Failure` in **at least one**
column"* (`:1811`). M-34's column satisfies it for all 44 at once. **AC-21 is vacuous.**

Two consequences the document states as facts and which are false:

- `:1813-1814`: *"A body of `assertTrue(true)` is `Success` in every column, so the six stub
  tests of §5.0.1 are named and `degeneracy-sweep.sh` exits non-zero."* It is `Failure` in
  M-34's column. They are not named.
- AC-21's **Falsify** (`:1847-1849`): *"replace the six `_AC02_` bodies with
  `assertTrue(true)` and run `bash scripts/degeneracy-sweep.sh` → non-zero, naming all six."*
  It exits **zero**. R-6 (`:2067-2069`) requires every Falsify to have been run and observed
  non-zero before its AC is reported green, and this one cannot be.

AC-21 is the sole instrument the spec offers against r2 finding 2 (§5.0.1:1016: *"Two
instruments cover that, and they are the only two"*). With M-34 in the matrix, the six-stub
attack r2 demonstrated is green again, one level up. That is a BLOCKER on the same ground r2
was.

**Repro.** Take the sandbox `mutation-kill.sh` builds for M-34, replace the six `_AC02_`
bodies with `assertTrue(true)`, run the suite in that sandbox: all 56 report `Failure`
(setup failed). Feed those statuses to AC-21's predicate: every test is accounted for; the
script exits 0.

**Required change.** Make setUp-safety a **precondition on membership in the matrix**, not a
property of one subset, and make it mechanical rather than a claim:

- `degeneracy-sweep.sh` must, for every column, first assert the column's **control
  condition**: at least one nominated canary test per test file passes, or equivalently that
  no column reports **100 % of the suite** as `Failure`. A column that fails that assertion
  is **excluded from the matrix and reported as excluded**, not silently counted.
- M-34 is excluded by construction (it is AC-17's mutant, and AC-17 is a whole-suite
  criterion — it does not need to be a sensitivity column).
- Re-derive `sweep.columns` in §7.1 and the AC-21 evidence line, and re-check every other
  behavioural mutant against the new rule; M-33 (decode-order change) needs the same
  examination if any `setUp` settles a real fixture proof.

### 4. [MAJOR] `docs/specs/003-key-gauntlet.md:531-534`, `:1392-1397` — C-5 masks M-23, so "AC-10 kills M-23 independently of C-5's bound" is false of the contract that is actually mutated

**Codex's finding #3, verified.** The runtime justification r3 substituted for C-5 (`:521-529`
— *"an unbounded outward transfer is paid out of other deals' principal in the same token"*)
is **correct and is the right reason**; that half of r2 finding 8 is properly closed. The
accompanying claim is not.

`:531-534`: *"**M-23 is killed by AC-10's multi-deal invariant independently of C-5's
on-chain bound** (AC-10 runs ≥ 3 deals in ≥ 2 tokens; M-23 breaks INV-4 on the first such
sequence)."* `:1392-1393` repeats it.

Mutants are *"patches applied to a sandboxed copy of the real source"* (`:1524-1527`), and
the real post-003 source **contains C-5**. So in the sandbox, M-23's `refundAfterDeadline`
transfers `balanceOf(address(this))`, C-5 then measures a decrease of the whole balance,
finds it `!= d.amount`, and reverts `PayoutFailed()` — **rolling back the transfer and the
terminal state**. INV-4 is never violated. Symmetrically, when the escrow holds exactly
`d.amount`, `balanceOf(this) == d.amount` and the refund is indistinguishable from correct.
**M-23 cannot break INV-4 at any handler width**, so the stated mechanism is wrong, and so is
AC-10's Falsify (`:1397`: *"reduce the handler to one deal in one token → M-23 survives"* —
it survives the invariants at every width).

M-23 probably still dies in AC-10, via `test_AC10_G27_donation_unrecoverable` if that test
performs a refund and expects it to succeed — but the spec does not say so, and *"probably,
via a test whose body is not specified"* is precisely how a kill-table cell gets rescued
privately at implementation time (r2 finding 6's failure mode, named at `:1355-1359`).

This is r2 finding 8 recurring with its sign reversed: r2 objected that C-5 was justified by
M-23; r3 removed that and asserted the converse, and the converse is false.

**Required change.** Delete the parenthetical mechanism at `:531-534` and the Falsify at
`:1397`. Either (a) state which AC-10 test kills M-23 **and what it asserts**, or (b) move
M-23's `killed-by` to the AC whose test actually fails, or (c) redefine M-23 as the
compound patch (pays `balanceOf(this)` **and** drops C-5's check) so the drain is real and
INV-4 genuinely breaks. (c) is the honest one if the point is to demonstrate the drain.
Appendix A row 8 (`:2527`) and §8 need the same correction.

### 5. [MAJOR] `docs/specs/003-key-gauntlet.md:732` vs `:815-825` — check 11 cannot pass on the real file as specified

Mine. §4.5.1 (`:732`) defines `src` as the whole file with comments **and string literals
removed**. Check 11 (`:815`) operates *"Over `src` before newline collapsing"* and requires
the top-level declaration lines to equal, *"compared as full lines"*, exactly these four —
the second of which is (`:822`):

```
import {RecknVerdictVerifier, VerdictPublicValues} from "./RecknVerdictVerifier.sol";
```

In `src` that line reads `import {RecknVerdictVerifier, VerdictPublicValues} from ;`. The
comparison cannot match. As written, **check 11 fails against the unmodified real file**, and
control **M-0 must be ACCEPTED** (AC-1, `:1163`). The implementer will resolve this in
private, and the resolution is claim-relevant: strip strings and the import **path** is
unpinned; keep strings and the check-11 region is a different text from the check-9 region,
which then needs its own definition.

It fails loudly rather than silently, which is why this is MAJOR and not BLOCKER — but §4.5
currently defines one `src` and two checks that need two.

**Required change.** Define **two** derived texts explicitly in §4.5.1: `src_calls` (comments
and string literals removed — the region checks 9 and 13 read) and `src_decl` (comments
removed, **strings preserved** — the region checks 11 and 12 read). Say which check reads
which, and state that the import path is pinned in `src_decl`.

### 6. [MAJOR] `docs/specs/003-key-gauntlet.md:730-736`, §5.2.1 — the comment/string stripper carries the whole of property P and is neither specified nor tested in the direction that matters

Mine. Property P is stated over stripped text, so **every one of checks 9, 11, 12 and 13 is
only as sound as the stripper**. §4.5.1 gives the stripper's intent in one sentence and no
algorithm, and the script it extends already uses a naive single-line
`sed -e 's://.*::' -e 's:/\*.*\*/::'` (`scripts/no-keys.sh:30`).

The exit corpus tests exactly one direction. Control **C-P** (`:1883`) splices a comment
naming `approve()` / `permit()` / `.call{value:}()` and requires it to be **accepted** —
i.e. that the stripper does not **under**-strip. **There is no control for over-stripping**,
which is the direction that hides code rather than the direction that produces a false alarm.

**Repro.** A greedy string rule (`s/".*"//`, the obvious one-liner) deletes everything
between the first and last quote on a line. Splice one line into `fund`:

```solidity
bytes32 memoA = keccak256("a"); IERC20Min(token).transfer(seller, amount); bytes32 memoB = keccak256("b");
```

The first `"` is before `a` and the last is after `b`, so a greedy rule deletes everything
between them and `src` reads `bytes32 memoA = keccak256();`. The `.transfer(` is gone: 9a's
member-call multiset is unchanged, and `keccak256` — which is **not** in `L_plain` and would
otherwise have failed 9b — has been deleted along with it, so 9b sees nothing either. The
file compiles and pays `amount` to an arbitrary `seller` from `fund`. The same trick works
with `/*` `*/` against a greedy comment rule.

**Required change.** Add two corpus entries whose **required verdict is REJECTED**:
`E-14` (a value exit hidden between two same-line string literals) and `E-15` (a value exit
hidden between two same-line block comments); and add one control whose required verdict is
**ACCEPTED**: a line with two legitimate string literals and no call between them, so the
stripper cannot pass E-14/E-15 by refusing all strings. Then state the stripper's obligation
as a property: *a call-shaped token in code must survive stripping; a call-shaped token
inside a comment or a string literal must not.*

### 7. [MINOR] `docs/specs/003-key-gauntlet.md:1016`, `:1813-1814`, `:2284` — §5.0.1 and §8 both state AC-21's reach more strongly than it is, in two different ways

Mine. Two overstatements, both small, both in the passages r2 forced to be written honestly.

- `:1016`: *"Two instruments cover that, and they are the only two"* — the "that" is *zero
  assertions*. AC-21 does not cover zero assertions; it covers **zero sensitivity**. A body
  of `vm.warp(deadline); escrow.refundAfterDeadline(id);` — no assertion at all — is
  `Failure` under SW-1 (which reverts on that path) and therefore passes AC-21. The
  `assertTrue(true)` stub is the *only* zero-assertion shape AC-21 was designed to catch, and
  §8's honest bullet (`:2261-2263`) says "sensitivity, not correctness", which is the right
  statement. §5.0.1's stronger sentence should be brought down to it.
- `:2284`: §8 states the residual of property P as *"a value movement expressed with **no
  call-shaped token at all**"*. Finding 2 shows the residual is materially larger: **an
  assignment with no call-shaped token that redirects a permitted call's operand.** That is
  not a value movement, and a reader auditing §8 against the checks would not look for it.

**Required change.** Two sentences, no mechanism: soften `:1016` to "zero sensitivity", and
widen `:2284` to name operand corruption alongside token-free value movement. (Both become
partly moot if finding 2's instruments land — but §8 must still say what the *lexical* check
does not see.)

### 8. [MINOR] `docs/specs/003-key-gauntlet.md:2457-2458` — OQ-4 credits seller-acceptance with closing G-33, and it does not

Mine. **N-5's rewrite itself is sound** and I am not re-opening it: consent to enter is not
authority to decide, the seller who never accepts lands on exactly today's do-nothing
outcome, and the exclusion is correctly made on scope grounds. r2 finding 9 is properly
closed.

But OQ-4's third cost/benefit bullet (`:2457-2458`) tells the founder that adding
`accept(dealId)` would *"close **G-33** by letting the seller decline a deployment whose
clock is too short **before** doing the work, rather than relying on the off-chain check of
§2.3(A)"*. It would not. `refundDelay` is an **immutable construction parameter** (C-2), so
it is readable before any deal exists — it is part 4 of the deployment check the same section
tells the seller to perform (`:247`). A seller who wants to decline a short clock can
already decline by not working, with or without an on-chain step. And acceptance does not
gate `refundAfterDeadline`: a seller who accepts and delivers is refunded out from under
exactly as before. **The mechanism's benefit for G-33 is zero**, so the founder is being
asked to price a fourth function, a fourth state and a fourth block of matrix rows against a
benefit that does not exist.

**Required change.** Delete the third bullet or replace it with what acceptance actually
buys (a recorded, on-chain point at which the seller attests to having read the §2.3(B) terms
— a demo asset, not a closure of G-33), so OQ-4's cost side is weighed against a real
benefit.

---

## Rejected / corrected findings

- **Codex's "Instrument inventory" — corrected, not rejected.** Codex concluded *"no invariant
  is wholly without a named device… INV-2/2b use 9/11/12"*. That is wrong for **INV-2**.
  `docs/specs/003-key-gauntlet.md:646-649` carries neither a `Mechanically:` nor a
  `Behaviourally:` line, unlike INV-1a (`:631-636`), INV-1b (`:637-645`) and INV-2b
  (`:650-657`), which all carry both. Checks 9/11/12 are cited by INV-2b, whose subject is
  *standing authority over the escrow's balance* (allowances, delegation) — a different
  property. Codex attributed them to INV-2 by inference and thereby missed the seam that
  finding 2 walks through. The payload asked this question directly (§3 question 2) and the
  answer returned was the reassuring one; it was checked line by line and it is wrong.
- **Nothing was rejected outright.** All three Codex findings reproduced against the files.

## Checked and found sound (recorded so round 4 does not re-litigate)

Re-measured today. Where a number is unchanged from a prior round, it was re-run, not quoted.

- **OQ-6's guest split is correct.** `zk-verdict/README.md:97` really carries *"~15.9M
  constraints, ~34 s"*, and the surrounding block (`:88-97`) attributes it to
  `script --bin evm`. `zk-verdict/script/src/bin/evm.rs:25` proves
  `include_elf!("verdict-program")` — the **predicate** guest — while
  `zk-verdict/script/src/bin/reexec.rs:41` proves `include_elf!("verdict-program-revm")`, the
  re-execution guest that actually settles. So `predicate_guest_wrap_seconds: 34` /
  `reexec_guest_seconds: null` is the honest split, the gag rule is correctly **kept** rather
  than relaxed, and `gauntlet.sh --check` re-reading line 97 is sound design (a quoted
  measurement whose source moved is exactly the `AGENTS.md` §5 failure). **No tier violation
  anywhere in the document**; the header claims local Foundry only and every AC is a Foundry
  or shell command.
- **The two Honest-scope digests still match**, recomputed with the spec's own `awk` recipe:
  `8f65b75f…9a6cac1` and `9e5facfd…14689af`. 003 resolves none of those items (N-7, AC-16).
- **The document's arithmetic closes.** Anchored marker counts are `1/1/1/1` (unanchored are
  3/3/4/4, as AC-13 warns). `T` = 48 by the spec's own reproduction command. The 13 forge
  ACs' `tests` column sums to 44; 44 + 12 = 56. The manifest's `rows` union is exactly the 37
  ids of §3.2; class counts recount to 20 theft / 7 authorized / 10 disclosed. All 13 forge
  ACs appear in a `killed-by` cell and AC-14 is the only AC that appears in none — as §5.1
  states. r2 findings 6, 7, 10 and 11 are properly closed.
- **The pinned counts do not over-forbid the correct implementation** (founder uncertainty 1,
  third bullet). `transfer: 2` and `balanceOf: 6` are stated **for the post-003 contract** —
  the refund path folded in from task 001 is already counted (1 transfer + 2 balanceOf in
  `refundAfterDeadline`). The counts do forbid a shared `_payout` internal helper, but check 2
  independently forbids a fourth function, so the two are consistent rather than in tension.
- **Inheritance / `using for` / `receive` / `fallback` / constructor escapes are closed.**
  Check 5 pins the declaration line; check 11 rejects a top-level `using`; check 13 rejects
  `using` / `receive` / `fallback` / `payable` file-wide; check 8 closes the constructor's
  assignment left-hand sides. A **modifier** is closed too, though the spec does not say why:
  its declaration `modifier onlyX() {` yields the plain-call token `onlyX(`, which 9b rejects.
  Worth one sentence in §4.5.6, but not a finding.
- **The timeout design is right and `001`'s four acceptance conditions survive intact.**
  `refundDelay` is a `uint64 public immutable` fixed at construction with no per-deal choice
  (C-2), `refundAfterDeadline` takes no caller condition, and G-13 fuzzes the caller — the
  answer to "who may call it" is **anyone**, as it must be. The post-deadline race between a
  late valid proof and a refund is real, both outcomes are authorized, and §8 says so instead
  of implying proofs win.
- **The binding is not weakened.** INV-9's formula at `:681-685` matches
  `zk-verdict/program-revm/src/main.rs:174-190` exactly, including `plan_hash` over
  caller‖target‖calldata‖value; `u64_low` limb-0 truncation is correctly located at
  `main.rs:163-164` and correctly assigned to task 008, not 003. N-2 freezes the guest.
- **N-5's narrowing is sound** (finding 8 concerns only OQ-4's cost/benefit bullet, not N-5).
- **`AGENTS.md` §0's surface obligation is properly discharged.** `AGENTS.md:22-24` and
  `scripts/no-keys.sh:45` both already enumerate exactly `fund` / `settleWithProof` /
  `refundAfterDeadline`, so the *permitted* surface does not change — only the third one
  starts existing. D-10 (`:2367`) declares the script's new checks 5–13, the added output
  line, the whole-file scan region and `IERC20Min` going 2 → 3 declared functions, and §9's
  header binds all of D-1…D-10 to the same commit. D-9 and §7.3 carry the same statement into
  `README.md` and the demo script. Nothing here trips §0's founder reservation: every scope
  change is a **tightening**.
- **§9's `file:line` references are correct where r2 corrected them.** `grep -n "12 tests"
  README.md` → **706**; the first site really does span `README.md:550-551`; and
  `001-keyless-timeout` occurs nowhere in `STATUS.md` (only inside this spec and r2), so D-7's
  rewritten obligation is right. `zk-verdict/scripts/zk-e2e.sh:84-85` really does discard
  `forge`'s exit status through `| grep … || true`, so S-1 is a real precondition.
- **The four pre-existing escrow tests are where §1.2 says they are**
  (`RecknZkEscrow.t.sol:38, 93, 104, 117`) and the file's other four `function` declarations
  really are `setUp`, `_fund`, `_mockEscrow`, `_pv`.
- **r1's and r2's "checked and found sound" lists are untouched and were not re-litigated.**

## Deferred

None. All eight findings are edits to `docs/specs/003-key-gauntlet.md`. `docs/decisions/`
still does not exist and no finding needs it. Findings 1 and 2 change the enforcement
property and the invariant set, but neither expands 003's scope line: both are closed inside
`scripts/no-keys.sh`, the existing AC-10 handler, and the matrix.

---

## What must change before round 4

**BLOCKER — round 4 cannot be reviewed without these:**

1. **Close the function-pointer alias** (finding 1). `L_plain` must keep `transfer` /
   `transferFrom` / `balanceOf` for the interface declaration, so the fix is a property, not
   a name: either close the `function` keyword to the six pinned declarations, or make 9b
   range-aware the way 9a already is. Add the splice as corpus entry **E-14** and as a
   source-text mutant, and fix corpus entry **E-11** (`:871`), whose stated rejection reason
   is defeated by renaming the local.
2. **Close operand corruption** (finding 2). Give **INV-2** both instruments it lacks: a
   lexical closure over assignment left-hand sides per function range (the shape check 8
   already uses), and an AC-10 invariant that a `Funded` deal's ABI-encoded struct never
   changes. Add the class-C matrix row and the §4.3 non-transition row, and re-derive the
   counts.
3. **Make AC-21 non-vacuous** (finding 3). Exclude setUp-breaking mutants from the
   sensitivity matrix **mechanically** — no column may be counted unless a nominated canary
   passes in it — remove M-34 from the columns, re-derive `sweep.columns`, and re-verify
   AC-21's own Falsify actually exits non-zero.

**Also required (not blocking review, but must land in round 4):**

4. Fix the M-23 / C-5 kill-table claim: delete the false mechanism at `:531-534` and the
   Falsify at `:1397`, and either name the AC-10 test that kills M-23 or make M-23 a compound
   patch that genuinely breaks INV-4 (finding 4). Appendix A row 8 and §8 take the same edit.
5. Split `src` into `src_calls` and `src_decl` so check 11 can pass on the real file, and say
   which check reads which (finding 5).
6. Add the two over-stripping corpus entries and their control, and state the stripper's
   obligation as a property (finding 6).
7. Soften `:1016` from "zero assertions" to "zero sensitivity", and widen `:2284`'s residual
   to include operand corruption (finding 7).
8. Delete or replace OQ-4's third bullet so the founder prices a real benefit (finding 8).

**Founder decisions carried forward, unchanged by this round:** OQ-1 (signed anvil mode),
OQ-2, OQ-3, OQ-5, OQ-6 (whether to spend a `ZK_FRESH=1` run on the re-execution guest),
OQ-7 (the exemption budget — note that finding 3 must be closed before OQ-7 is answerable,
since a vacuous matrix makes the budget moot).

**Round discipline.** This is round 3 of a maximum of 6 (`AGENTS.md` §7). Findings 1, 2 and 3
are each a single, well-localized edit to one section plus one corpus/mutant entry; none of
them requires re-architecting the spec, and the surrounding 2555 lines — the matrix, the
manifest, the arithmetic, the disclosures, the honest-scope freeze — held up under
verification. Round 4 is expected to be short.

VERDICT: CHANGES

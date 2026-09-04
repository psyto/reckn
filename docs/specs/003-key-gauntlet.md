# 003 — Key Gauntlet (folds in 001: keyless timeout)

| | |
|---|---|
| Status | **DRAFT — round 6 of a maximum of 6 (`AGENTS.md` §7). This is the hard stop: whatever is open after this round goes to the founder.** Responds to all 6 findings in `docs/reviews/003-spec-r5.md` (`VERDICT: CHANGES`, BLOCKER 2 / MAJOR 2 / MINOR 2). Response table: **Appendix D**. Round 3's response to r2 is **Appendix A**, round 4's to r3 is **Appendix B** and round 5's to r4 is **Appendix C**; none is re-opened. |
| Owner | `reckn-spec` (frame thin). Implementation is `reckn-codex-impl`. |
| Supersedes | task `001` (keyless timeout) — folded in per founder ruling, `AGENTS.md` §3 |
| Tier claimed | **local anvil / Foundry only.** No testnet, no mainnet, no real funds. |
| Surface touched | `zk-verdict/contracts/src/RecknZkEscrow.sol`, `zk-verdict/contracts/test/`, `zk-verdict/contracts/foundry.toml`, `scripts/no-keys.sh` (**additive checks only** — §4.5), `scripts/` (new: `ac.sh`, `ac-selftest.sh`, `no-keys-selftest.sh`, `mutation-kill.sh`, `degeneracy-sweep.sh`, `gauntlet.sh`), `zk-verdict/scripts/zk-e2e.sh` (**one line**, S-1), `docs/gauntlet.json` (new), `docs/gauntlet.base.json` (**new; written once, at 003's base commit, by `gauntlet.sh --measure`, and thereafter never deleted and never re-written — asserted from git history, not from a promise** — §1.5.1), `README.md`, `CLAUDE.md`, `AGENTS.md`, `STATUS.md`, `SUBMISSION.md`, `zk-verdict/README.md` (**not** its Honest-scope blocks), `zk-verdict/scripts/surfaces.pinned` (**re-pinned, not authored** — task `008`'s artefact; §1.5, D-11) |
| Surface **read but not edited** | `zk-verdict/contracts/src/RecknVerdictVerifier.sol` — **new in r5.** It is the second contract in the settlement path, and it enters `scripts/no-keys.sh`'s checked region as **check 15** (§4.5.10). 003 adds no line to it and changes no line in it; it constrains what may ever be in it. **In r6 that constraint reaches the file's `constructor`, which is where the address `verifyProof` is dispatched to is chosen (`RecknVerdictVerifier.sol:38`, `:42-45`, `:55`) and which round 5's check excluded by construction.** |
| Surface **not** touched | `contracts/RecknEscrow*` (optimistic path, `AGENTS.md` §8), `zk-verdict/program-revm`, `zk-verdict/program-svm`, `zk-verdict/lib`, `zk-verdict/script`, `docs/ethonline-2026/*` (founder documents), `docs/specs/004-*`, `docs/specs/008-*`, `docs/reviews/*` |

Section numbering is normative. Task `004` must reuse this structure: §1 claim/non-goals,
§2 attacker model, §3 matrix, §4 state machine + invariants, §5 acceptance criteria,
§6 test plan, §7 judge-facing surface, §8 what this does not prove, §9 implementation
obligations, §10 open questions. **Appendix A is round-bookkeeping and is not part of the
reusable structure.**

**The scope line, fixed by r1 and binding on 004:** 003 may change
`RecknZkEscrow.sol` **only where a matrix row would otherwise have no true expected
result**. SafeERC20, permit/EIP-3009, cancellation, multi-payout splits and any `view`
helper are out (N-3, N-6).

### What round 3 changes, in one paragraph

Round 1 claimed the value exits were pinned and pinned nothing. Round 2 pinned them by
**counting two method names** (`.transfer(`, `transferFrom(`) inside the contract body, and
r2 broke it with one line — `IERC20Min(token).approve(seller, type(uint256).max)` in `fund`
— plus a second route (a `library` above the `contract` declaration, outside
`scripts/no-keys.sh:29`'s scan region). **Twice in a row the hole was plugged by naming the
thing that must not appear.** Round 3 stops naming and states a property: after comments
and string literals are stripped, **every call-shaped token in the whole file must appear
in a closed allowlist**, the file's top-level declarations are pinned to exactly four, and
`IERC20Min`'s declared function set is itself a build condition. `approve`,
`increaseAllowance`, `permit`, `Address.functionCall`, `payable(x).transfer`,
`.call{value:}`, a file-level helper, a `library`, and inline `assembly` all fail the same
check for the same reason, and so does the construct nobody has thought of yet — §3.1,
§4.5, AC-1. Round 3 also adds **AC-21**, which opens test bodies behaviourally: every
gauntlet test must be observed *failing* against at least one mutant, so the six-stub
attack of r2 finding 2 (`assertTrue(true)` with correct names) is named rather than green.

### What round 4 changes, in one paragraph

Round 3's property P constrains **where calls appear**. r3 found that it does not constrain
**what the permitted calls' operands resolve to**, and broke it twice from that one seam:
a function-type local *named* `transfer` (whose name check 9b is forced to admit, because
check 12 pins the very declaration line that produces that token), and a plain assignment
`deals[dealBinding].seller = seller;` inside `fund`, which contains **no call-shaped token
at all** and therefore no lexical call check can see. Round 4 does not extend a syntax
check to chase either construct (R-7, and it would be r2's mistake one level down). It adds
**one property per seam**: check 9 closes the **`function` keyword** itself, so nothing new
can become callable under any name; and **check 14** closes the set of **assignment
targets** per function range — the same shape check 8 already uses for the constructor —
so no storage other than `deals[dealId]`, `d.state` and locals can be written at all.
Behind the lexical checks, **INV-2c** states the runtime fact that neither check can prove
(*a `Funded` deal's struct changes only through the two exits, and then only in `state`*)
and AC-10's new invariant and AC-11's new row **G-38** test it. Round 4 also makes **AC-21
non-vacuous**: M-34 (every body `revert()`) broke every `setUp`, so its column marked all
44 tests `Failure` and satisfied AC-21 for all of them at once — it is removed from the
columns by a pinned exclusion and, more importantly, every column must now pass a
**setUp probe** before it may be read (§5.4a). R-8 records the general rule: *a lexical
check on call sites never constrains operands.*

### What round 5 changes, in one paragraph

Rounds 1–3 were broken **inside** `RecknZkEscrow.sol`; r4 could not break it and broke the
**edges of the frame** instead. Two edges. **(1) Settlement authority leaves the checked
file.** `settleWithProof` obeys the struct returned by `RecknVerdictVerifier.verifyVerdict`
— 58 lines, same directory, same audited deployment — and `scripts/no-keys.sh:19` looks at
one file only. A constant-address branch spliced into that function is a resolver, and
every instrument of round 4 stayed green: no check reads the file, no mutant patches it,
and a fuzz cannot draw a hardcoded address (R-5's own rule). Round 5 **brings the file
inside the frame** as **check 15** (§4.5.10), with mutant **M-51**, corpus entry **E-19**,
control **C-V**, matrix row **G-39**, and a money-shot line naming both files — and it
*also* states in §2.3(A) and §8 exactly what check 15 does **not** establish, because the
address the escrow is constructed with is still a deployment-time choice (G-29).
**(2) 003 was written against the pre-008 tree** while stating that it runs after 008.
Every 008-coupled quantity was a literal: the pre-existing suite count, the two
Honest-scope digests, the binding preimage, the public-values widths. Round 5 does not
paste 008's numbers — 008 is mid-review and its literals are not yet facts. It replaces
every one of them with a **measurement taken at 003's base commit**, recorded by
`gauntlet.sh --measure` into `docs/gauntlet.base.json` (§1.5.1), with `{P}` / `{S}`
substitution tokens in the manifest so that no suite total is a literal anywhere in this
document. Round 5's third theme is the **observer**: all four of r4's MAJOR findings were
defects in the thing that watches rather than in the thing watched — R-9's own shape, one
level up. The sentence *"a script that ran nothing cannot print it"* was false and is
deleted; `mutation-kill.sh` and `degeneracy-sweep.sh` each gain **two independent**
devices, an outside-in control artefact (AC-18 observations 7/8, M-52/M-53) and a
**witness** an `echo` cannot compute (§5.0.3); the stripper's two delimiter families are
finally tested **against each other** (E-17/E-18, one pass, one state machine); and the
sweep probe is read from parsed JSON rather than from an exit status.

### What round 6 changes, in one paragraph

**This round closes a new *kind* of hole, and names it.** The first four failures of this
document were all one shape — *a criterion that is satisfied by breaking the thing that
observes it* (R-9, R-10). r5's first finding is a different shape: **the attacker branches on
the existence of the observer.** Check 15 pinned assignment *left-hand sides* and excluded the
`constructor` — and `RecknVerdictVerifier`'s `verifier` is `address public immutable`, chosen
in that constructor (`RecknVerdictVerifier.sol:38`, `:42-45`) and dispatched to at `:55`. A
constructor reading `if (block.chainid == 31337) { verifier = _verifier; } else { verifier =
address(0x…1337); }` passes 15a–15f, passes every matrix row and passes the whole suite —
**because the gauntlet runs on a local chain, so an implementation that misbehaves only off
that chain is invisible to every instrument in this document.** P5's sentence *"there is no
branch for a constant address to live in"* was false: the branch was in the region the check
excluded. Round 6 pins the constructor (**15g**), pins the escrow constructor's right-hand
sides the same way (**check 8**), closes the **execution-context tokens** per range so that
neither file can tell which chain it is on at all (**check 7b**), turns the seller's
deployment check from **four parts into five** by reading `RecknVerdictVerifier.verifier()`
on-chain, and writes the general rule down as **R-11**. Second, the anti-laundering mechanism
was *"`--measure` refuses to overwrite"* while the laundering path is **`rm`** — and AC-16's
own `Falsify:` asserted an outcome that does not occur, which under **R-6** is a broken
instrument rather than a typo. Round 6 replaces it with two mechanical assertions over the
base file's **git history** plus a clean-tree condition on `--measure`, and rewrites the
falsifier to the three branches that actually happen. Third, AC-17 pinned the pre-existing
suite's **size**; it now pins the recorded **id set**, so a meaningful pre-existing test
cannot be deleted and replaced by a passing one. **What round 6 refused to do is in Appendix
D**, and the one thing it found and deliberately did **not** close is **OQ-10** — returned to
the founder open, because this round is `AGENTS.md` §7's hard stop.

---

## 1. Claim and non-goals

### 1.1 The claim (one sentence)

> Every private key in the system can be published, and no holder of any of them —
> buyer, seller, the party a competing design would have made the resolver, the
> deployer, or any stranger — can move a funded `RecknZkEscrow` deal to any
> destination other than the two the deal itself fixed at funding time
> (`seller` on a verifying `Reproduced` proof bound to this deal, `buyer` on a
> verifying `Failed` proof bound to this deal or on the elapsed deadline),
> and never twice.

The claim is about **destinations**. §1.3(d) and row **G-36** record the one way a
supported-looking token can make the *amount* arriving at an authorized destination smaller
than `d.amount` without any key being involved; that is a disclosure, not a defence.

### 1.2 What 003 adds to what already exists

Today (`zk-verdict/contracts/src/RecknZkEscrow.sol`, re-read 2026-09-04):

- the contract has **no** owner/admin/resolver/pause/upgrade — this is already true and
  already enforced by `scripts/no-keys.sh`
- `settleWithProof` is already permissionless and already binding-checked
  (`RecknZkEscrow.sol:96-103`)
- **there is no timeout**: a funded deal with no proof is locked forever
  (`README.md:566-571`, `CLAUDE.md:46-49`)
- the claim is asserted in prose in four documents and demonstrated by **four** tests in
  `zk-verdict/contracts/test/RecknZkEscrow.t.sol`
  (`test_real_proof_settles_to_seller:38`, `test_failed_verdict_refunds_buyer:93`,
  `test_settle_reverts_on_binding_mismatch:104`, `test_settle_reverts_on_unverified_proof:117`;
  the file's other four `function` declarations are `setUp`, `_fund`, `_mockEscrow`, `_pv`).
  **The pre-existing suite is a measured quantity, not a literal in this document**
  (§1.5.1, r4 finding 2). **What is measured is the set of test *ids*, and `P` is its
  cardinality (new in r6 — r5 finding 3): a count cannot tell a deleted test from a
  replacement.** Measured on the tree as it stands 2026-09-04, **before 008 lands**,
  `P = 12` across five files
  (`grep -c 'function test' zk-verdict/contracts/test/*.t.sol` → `2+2+2+2+4`, and
  `forge test --list --json | jq '[.[][][]] | length'` → 12). **008 adds tests to this
  suite, so both the set and its size will be different at 003's base commit; every total in
  this document is written as `46 + {P}` and no total is spelled out.**
  None of the four publishes a key, fuzzes a caller, or enumerates what a key-holder
  *cannot* do.
- **the settlement path spans two contracts, and only one of them is checked today.**
  `settleWithProof` obeys the struct returned by
  `verifier.verifyVerdict(publicValues, proofBytes)` (`RecknZkEscrow.sol:99`), and
  `verifyVerdict` is declared in `zk-verdict/contracts/src/RecknVerdictVerifier.sol:50-57`
  — 58 lines, the same directory, the same audited deployment. `scripts/no-keys.sh:19`
  fixes its target to `RecknZkEscrow.sol` alone. Re-read 2026-09-04, the file today
  contains **one** `function` declaration (`verifyVerdict`), zero occurrences of
  `msg.sender` and zero of `tx.origin`, and a two-statement body. **Nothing enforces any
  of that**, and §3.1.4 states what a single extra line there buys an attacker.
  **And the address that function dispatches to is chosen somewhere else again**: `verifier`
  is `address public immutable` (`RecknVerdictVerifier.sol:38`), assigned in the
  **constructor** (`:42-45`), and read at `:55` as
  `ISP1Verifier(verifier).verifyProof(...)`. Re-read 2026-09-04, that constructor is two
  statements, each assigning one immutable from the parameter of the same name. Nothing
  enforced that either — **round 5's check 15 excluded the constructor by construction** —
  and §3.1.4 states what a single extra branch *there* buys an attacker who never has to
  touch `verifyVerdict` at all.
- **`fund` discards `transferFrom`'s boolean return** (`RecknZkEscrow.sol:86`)
- **nothing constrains the contract's outbound calls.** `scripts/no-keys.sh` has four
  checks, none of which looks at a call site; and its scan region begins at
  `^contract RecknZkEscrow` (`scripts/no-keys.sh:29`), so everything above that line —
  including the `IERC20Min` interface at `:6-9` — is outside every check it performs.
  Both facts were verified by running the real script against mutated copies of the real
  file on 2026-09-04 (§3.1).

003 turns the prose into a **machine-checked matrix**, closes the timeout gap inside that
matrix, and constrains the contract's outbound calls by an allowlist over the whole file,
so the matrix's basis is a build condition rather than a sentence.

### 1.3 The supported token class (definition, used by §3, §4 and §8)

An ERC-20 `T` is **exact-transfer** with respect to this escrow iff, for every call the
escrow makes:

- **(a)** a `T.transferFrom(a, escrow, x)` that returns without reverting increases
  `T.balanceOf(escrow)` by **exactly** `x`;
- **(b)** a `T.transfer(b, x)` that returns without reverting decreases
  `T.balanceOf(escrow)` by **exactly** `x`;
- **(c)** `T.balanceOf(escrow)` changes only as the result of a transfer involving the
  escrow — no rebasing, no share accounting, no balance drift between two calls;
- **(d)** *(new in r3, r2 finding 3)* a `T.transfer(b, x)` that returns without reverting
  increases `T.balanceOf(b)` by **exactly** `x`.

**Why (d) had to be added.** (a)–(c) are all stated from the **escrow's** side. A token that
debits the escrow by exactly `x`, credits `b` with `x − 1` and credits a fee collector with
`1` satisfies (a), (b) and (c) verbatim, passes C-5's delta check, and marks the deal
`Settled` — while §3.2's definition of the `authorized` class is *"must pay exactly the
right party exactly once"*. The escrow **cannot** observe (d): C-5 measures its own balance,
and a recipient-side check is not available either, because the recipient may be a contract
that moves the tokens in a hook. So (d) is a **definition the token must satisfy**, row
**G-36** is its disclosure, and AC-19's G-36 test asserts the **recipient-side** delta, not
only the escrow-side one.

**003 supports exactly this class.** Tokens outside it are handled as follows, and every
outcome is in the matrix rather than in a footnote:

| violated | what happens | row |
|---|---|---|
| (a) — inbound fee, `false` return, silent no-op | `fund` reverts `UnderFunded`; **fails closed**, no principal at risk | G-20, G-21 |
| (b) — outbound fee | funds cleanly, then **both exits revert `PayoutFailed` forever**; the deal is permanently `Funded` | **G-34** |
| (c) — rebasing / share-accounted | same as (b) | **G-35** |
| **(d) — recipient-side fee** | funds cleanly, **settles or refunds normally, the deal becomes terminal, and the destination receives less than `d.amount`.** Not detectable from the escrow side | **G-36** |
| `transfer` reverts to one address (blacklist) | that direction bricks; the other direction still works | G-18, G-23 |

The (b)/(c) residual is **created by C-5 of this spec**. The (d) residual is **not created
by 003** — it exists in the contract as it stands today and 003 discloses it. Both are in §8.

### 1.4 Non-goals (explicitly not done here, including the tempting ones)

- **N-1** Improving, touching, or demoing the optimistic path (`contracts/RecknEscrow`).
  It has a bonded resolver by design; it is out of the claim and out of the demo
  (`AGENTS.md` §8, `CLAUDE.md` "二つの経路を混同しない").
- **N-2** Any change to the SP1 guests, the verdict ABI, `dealBinding` construction, or
  the proving pipeline. 003 changes only the settlement contract, its tests, the
  enforcement/harness scripts, and one exit-status line in `zk-e2e.sh` (S-1). The
  binding is consumed as-is from `zk-verdict/program-revm/src/main.rs:176-190`.
- **N-3** Adding a `view` helper to `RecknZkEscrow` (e.g. `deadlineOf`, `computeBinding`).
  `scripts/no-keys.sh` check 2 greps **every** `function` declaration, view or not, so a
  view helper widens the enumerated surface and changes the claim. Off-chain callers read
  `deals(dealId)` (the auto-generated public-mapping getter, which is not a `function`
  declaration) and the `Funded` event.
- **N-4** Deploying anywhere. No testnet, no mainnet (`AGENTS.md` §8).
- **N-5** *(narrowed in r3 — r2 finding 9)* Any mechanism that confers **authority over the
  outcome of an already-funded deal**: deadline extension, dispute reopen, arbitration,
  seller-bond slashing, mutual-consent cancellation. Each of those needs a trigger held by
  a party who can change **where the money goes or when**; that is a key.

  **Seller-acceptance is explicitly *not* in that class, and round 2 was wrong to put it
  there.** Consent to **enter** is not authority to **decide**. A seller who never accepts
  leaves the deal in `Funded` until the deadline and the buyer is refunded — precisely the
  outcome available today when the seller does nothing. It moves no value to any destination
  the deal did not already fix, and it gives no party a choice between two outcomes.
  Seller-acceptance is out of 003 **on scope grounds** — the scope line permits contract
  changes only where a matrix row would otherwise have no true expected result, and G-33
  *has* a true expected result (the refund succeeds) — **not on claim grounds.** OQ-4 is
  re-posed accordingly: it is a cost and demo-surface question, not a claim-shape question.
- **N-6** SafeERC20 / permit / EIP-3009 integration, multi-payout splits, partial
  settlement, or deal cancellation by mutual consent. Mutual consent gives each party a veto
  over an already-funded deal's outcome, which is N-5's class.
- **N-7** Resolving anything in `zk-verdict/README.md` "Honest scope" (precompiles, `u64`
  verdict values, 1 CALL + 1 delta, off-chain header binding). 003 claims none of them.
  §5 AC-16 makes the non-resolution machine-checkable.
- **N-8** Predicate non-degeneracy. 003 does not test whether a predicate can be satisfied
  by a seller who does nothing (`zk-verdict/README.md`'s `--credit 42` → delta 0 →
  `Failed`). That property lives in the guest and the predicate, which N-2 freezes here.
  003's own analogue of that failure — *a gauntlet a do-nothing contract could pass, or a
  gauntlet a do-nothing **test suite** could pass* — is covered by the authorized rows, R-3,
  mutant M-34, and **AC-21** (§5.2).
- **N-9** Adding a target/path argument to `scripts/no-keys.sh`. r1 finding 12 proposed
  one; `AGENTS.md` §0 reserves the semantics of that script to the founder, so 003 does
  **not** add it (OQ-5). r2 confirmed this is the right call. The self-test achieves the
  same end with **zero interface change** by sandboxing the whole layout (§5 AC-1).
- **N-10** *(new in r3)* Making `scripts/no-keys.sh` parse Solidity. The checks of §4.5 are
  lexical: they operate on the comment- and string-stripped source text. A lexical allowlist
  over-approximates (it rejects legal code that is not on the list) and that is the intended
  direction — every rejection is a build failure a human reads, never a silent pass. 003
  does not add a Solidity parser, an AST tool, or a new toolchain dependency.

### 1.5 Dependency on `008`: everything coupled to it is measured, never copied

**Execution order is `008` → `003` (`AGENTS.md` §3), so 008's build conditions already
exist when 003 edits the contract.** Round 4 said that and then wrote every 008-coupled
quantity as a literal read off the **pre-008** tree (r4 finding 2). An implementer starting
003 as written would have hit AC-16, AC-17 and AC-21's control red before writing a line of
Solidity, and the only ways through were the two acts this document spends three thousand
lines forbidding: edit a pinned literal privately, or ship prose that is false.

**The rule, once:**

> **003 contains no literal whose truth depends on 008.** Every such quantity is
> **measured at 003's base commit** by `bash scripts/gauntlet.sh --measure`, written once
> into `docs/gauntlet.base.json`, and referred to from this document by name. 003 does
> **not** paste 008's numbers either: 008 is mid-review, its literals are not yet facts,
> and quoting an unreviewed document is the same defect with a different source.

#### 1.5.1 `gauntlet.sh --measure` and `docs/gauntlet.base.json`

Run **once**, as **P0** (§9.1) — before P1 and before any 003 edit — on the tree exactly as
008 left it, **which must be a committed tree**: `--measure` refuses to run while
`git status --porcelain` is non-empty (rule 2). It records
`base_commit = git rev-parse HEAD` and these six measurements, and the resulting file is
**committed in the same part**:

| key | what is measured | how | used by |
|---|---|---|---|
| `pre_existing_tests` (**the id set; `P` is its cardinality**) | the whole `zk-verdict/contracts` suite before 003 adds anything, **as a sorted list of ids `<contract>:<test>`, not as a number** (r5 finding 3) | `forge test --root zk-verdict/contracts --list --json` flattened to `<contract>:<test>` and sorted; `P := \|set\|` | AC-17, AC-21, GC-4, §7.1, §7.2 — always as `46 + {P}` |
| `honest_scope` | the two "Honest scope" block digests of `zk-verdict/README.md` | the `awk` heading-recipe of AC-16, `shasum -a 256` | AC-16 |
| `binding_preimage` | the domain tag and field list `program-revm` actually commits, **verbatim**, with the `file:line` it was read from | copied out of the source at `base_commit`; no agent retypes it | INV-9, AC-6 |
| `public_values` | the declared Solidity type of each `VerdictPublicValues` field, with its `file:line` | read from `zk-verdict/contracts/src/RecknVerdictVerifier.sol` | INV-10, §8 |
| `verifier_body` | the two statements of `verifyVerdict`, whitespace-normalized, with their `file:line` | read from the same file | check 15 (§4.5.10) — as **evidence**, not as the gate |
| `verifier_constructor` (**new in r6 — r5 finding 1**) | the `constructor`'s parameter list and its two statements, whitespace-normalized, with their `file:line` | read from the same file (`RecknVerdictVerifier.sol:42-45`) | **15g** (§4.5.10) — as **evidence**, not as the gate |
| `no_keys` (**new in r6 — orchestrator ruling of 2026-09-04**) | what `scripts/no-keys.sh` already is at the base commit: `{ "checks": <the integer in its `checks: N/N passed` line, or null if it prints none>, "targets": [<the source paths the script derives from its own location>] }` | read from the script and from its own output at `base_commit` | **§1.5.4** — decides whether 003 **extends** 008's check over `RecknVerdictVerifier.sol` or **introduces** it |

**Four rules that make this a measurement rather than a ritual.**

1. **No agent types any of these values by hand.** Same discipline as D-11's re-pin: a
   hand-transcribed digest is a silent mismatch waiting to happen, and a recomputation
   performed by the party being checked is not a check.
2. **`--measure` writes once, and refuses a dirty tree** *(rewritten in r6 — r5 finding 2)*.
   If `docs/gauntlet.base.json` exists, `gauntlet.sh --measure` exits non-zero and prints the
   recorded `base_commit`; and **if `git status --porcelain` is non-empty it exits non-zero
   before measuring anything**, printing the dirty paths. The second condition is not
   decoration: without it the honest scope is measured from the **working tree** while
   `base_commit` points at `HEAD`, and the resulting mismatch surfaces six parts later at P8
   with no instruction attached instead of at P0 where it is cheap.

   **What this rule does *not* do, said here because round 5 said the opposite.** Round 5
   wrote *"the file is written once and only once"*. **That is false: refusing to overwrite is
   not refusing to be replaced, and `rm` is not an overwrite.** The launderer owns git
   (`AGENTS.md` §6): soften `zk-verdict/README.md`, commit it, delete the base file,
   re-measure. All three sources of rule 3 are then re-derived from the same softened tree,
   they agree, and `base_commit` is trivially an ancestor of `HEAD` because it **is** `HEAD`.
   **The act is blocked by rule 4, not by this one**, and this rule's own contribution to
   blocking it is exactly one branch: the delete leaves the tree dirty, so a launderer who
   does not commit the deletion is stopped here.
3. **The digests are pinned to a git object, not to a working tree.** `gauntlet.sh --check`
   (GC-15) re-derives `honest_scope` from
   `git show <base_commit>:zk-verdict/README.md` and asserts it equals both the recorded
   value **and** the value computed from the working tree. Three sources. A softening edit
   moves the working-tree value and not the other two, so AC-16 goes red. **`base_commit`
   must be an ancestor of `HEAD`**, which is also asserted.
4. **The base file has exactly one history** *(new in r6 — r5 finding 2; this is the rule that
   blocks the laundering path)*. `gauntlet.sh --check` (GC-15) asserts all four:
   - `docs/gauntlet.base.json` is **tracked** (`git ls-files --error-unmatch` succeeds); an
     untracked base file fails, naming the file and P0;
   - `git log --diff-filter=A --format=%H -- docs/gauntlet.base.json` has **exactly one**
     entry — the commit that introduced it;
   - `git log --diff-filter=D --format=%H -- docs/gauntlet.base.json` is **empty** — it was
     never deleted;
   - the blob at that single `A` commit is **byte-identical** to the working-tree file, which
     also closes the modify-in-place case without a separate assertion.

   A delete-and-re-measure leaves a `D` entry **and** a second `A` entry; a stale-but-honest
   file leaves neither; a base file that was re-measured without deleting fails rule 2 and,
   if it is committed anyway, fails the blob comparison. **The three branches are traced end
   to end in AC-16's `Falsify:`**, which is where round 5 asserted an outcome that does not
   occur.

**What this does not do**, stated so it is not read as more: it pins that 003 did not change
the honest scope, the pre-existing test set or the binding after its base commit. It says
nothing about whether 008's own changes to those things were right — that is 008's review, not
this one. **And rule 4 reads the history that is there**: an implementer who rewrites history
(`commit --amend`, a rebase that drops the `D`) defeats it. That is not the accidental
laundering this rule exists to stop; it is deliberate fabrication of evidence, which §8 names
as outside 003's threat model **in those words** and does not claim to catch.

#### 1.5.2 008's OQ-2, answered in all three parts

`docs/specs/008-verdict-domain-soundness.md`'s OQ-2 enumerates three couplings and closes
with *"this is the one open question that needs an answer before implementation starts,
because it changes what `003` must do."* Round 4 answered one of them, and answered it
against the wrong path. All three, here:

| 008 OQ-2 | 003's answer |
|---|---|
| **(1)** 003's AC-16 pins an honest-scope digest 008 must change | **AC-16 no longer pins a literal.** It pins *"unchanged since 003's base commit"*, measured after 008 lands (§1.5.1). Whatever 008 leaves in that block is what 003 must not move. 008's recommendation (a) is therefore **compatible with 003 as written**, and no ordering hold is needed |
| **(2)** 003 quotes the v1 binding formula, which 008 replaces | **003 no longer quotes a preimage.** INV-9 states the *property* (the binding commits the authenticated prestate, the predicate and the plan, so another convenient execution cannot settle this deal) and refers to `base_measurement.binding_preimage` for the bytes. N-2 freezes 003 from **changing** the binding; it never required 003 to **quote** it, and quoting it is what made 003 wrong |
| **(3)** `surfaces.pinned` pins `sha256(RecknZkEscrow.sol)` and 003 necessarily changes that file | **003 re-pins it in the same commit that changes the contract** (D-11, P1). **Path corrected in r5: it is `zk-verdict/scripts/surfaces.pinned`, not `scripts/surfaces.pinned`.** Round 4 ran `ls scripts/` — a directory 008 never uses — and concluded the artefact did not exist |

**Honest note on ordering, with the path fixed.** At the time this spec is written,
`zk-verdict/scripts/` contains **`zk-e2e.sh` only** (`ls zk-verdict/scripts/`, run
2026-09-04); neither `surfaces.sh` nor `surfaces.pinned` is there yet. They are 008's
deliverable and 008 lands first. If 008 lands **without** them, D-11 is a no-op and the
implementer records in the report that it was a no-op — that is not licence to skip step 2
or step 3 of any pin that does exist. **003 does not edit `docs/specs/008-*`** (§9).

**A surface change still moves three things, in one commit, always together:**

> 1. `AGENTS.md` §0's enumerated function surface (`fund` / `settleWithProof` /
>    `refundAfterDeadline`) — the claim itself;
> 2. `scripts/no-keys.sh` — the build condition that enforces the claim (003 adds checks
>    5–15 and one output line; §4.5, D-10, and **D-12** for check 15's second file);
> 3. **`zk-verdict/scripts/surfaces.pinned`** — 008's digest of the contract source (D-11).
>
> Splitting these across commits is what makes a claim change invisible, which is the one
> thing `AGENTS.md` §0 exists to prevent.

**How the re-pin is performed, and how it is not.** `surfaces.sh` prints **both** the old
and the new digest when the pin fails. The implementer **copies the printed new value** into
`surfaces.pinned`. **No agent computes a digest by hand and no step of this spec asks for
one.**

#### 1.5.3 Two smaller couplings, both made to fail loudly

- **008 regenerates the committed fixtures** that the four pre-existing tests and AC-6 read.
  AC-6's control (*the committed real fixture proof settles a deal funded with the fixture's
  `deal_binding`*) is stated over *whatever fixture is committed at the base commit*; it
  names no digest and no field width, so it survives the regeneration and fails loudly if
  the fixture stops settling.
- **§7.1's `~34 s` source is located by content, not by line number.** Round 4 wrote
  `sed -n '97p' zk-verdict/README.md | grep -q '~34 s'` into a file 008 edits.
  `gauntlet.sh --check` (GC-17) instead runs `grep -n '~34 s' zk-verdict/README.md`,
  requires **exactly one** match, and writes that match's line number into
  `gauntlet.json.proving.predicate_guest_source`. Zero matches or two matches is a failure
  with an instruction attached: re-read the file; if the measurement is gone,
  `predicate_guest_wrap_seconds` becomes `null` and the gag rule stays. **A line number is
  not a citation; the text is.**


#### 1.5.4 Who introduces the check over `RecknVerdictVerifier.sol` — 008 does; 003 extends it

**Orchestrator ruling, 2026-09-04.** 008's own round-4 review reached r5 finding 1's file from
the other side: `RecknVerdictVerifier.sol` is on the settlement path (`RecknZkEscrow.sol:99`
calls `verifyVerdict` and obeys the struct it returns), **008 must edit that file** (it widens
`VerdictPublicValues`), and the execution order is `008 → 009 → 003`. **008 opens the file
first, so 008 introduces the check over it.** A check that does not exist at the moment a file
is first edited is not a check: attributing it to 003 leaves the region open for the whole of
008 and 009.

**What that changes here is attribution, not mechanism.** Every technical statement of §4.5.10
stands as written. What 003 owns is the **extension**:

- **the `constructor` closure** — **15g**, plus check 8's right-hand-side clause and check 7b
  in the escrow (§4.5.6a). This is r5 finding 1's body and it is 003's.
- **the five-part deployment check** — reading `RecknVerdictVerifier(verifier).verifier()`
  on-chain (§2.3 A part 5).
- **the corresponding corpus entry E-20, mutant M-57 and matrix row G-40**, and the two
  documentation consequences (D-12, §7.2).

**008's part is referred to, never quoted.** 008 is not APPROVEd; its literals are not facts,
and §1.5's rule applies to this coupling exactly as it applies to `{P}`: **what 008 left is
measured at the base commit** (`docs/gauntlet.base.json.no_keys`), not asserted here.

**Three cases, decided by that measurement and by nothing else:**

| `no_keys` at the base commit | what 003 does |
|---|---|
| `targets` names **only** `RecknZkEscrow.sol` — **008 landed without it** | 003 **introduces** check 15 in full, exactly as §4.5.10 specifies. This is round 5's design unchanged, and it is the fallback the ruling requires 003 to keep |
| `targets` also names `RecknVerdictVerifier.sol`, and `checks` is `null` or `5` — **008 landed a minimal form as one check** | 003 **extends it in place**: it keeps this document's slot **15**, adds whichever of 15a–15g the base script does not already perform, and the implementation report lists, **sub-check by sub-check**, which were inherited and which 003 added. The printed count stays `15/15`, because slot 15 is one check whether it has three sub-checks or seven |
| anything else — `checks` is an integer other than `5`, or `targets` names a third file — **008 changed the script's shape in a way §4.5.2's table does not enumerate** | **stop and return to the founder** (`AGENTS.md` §7). That table is the *complete* post-003 enumeration and AC-00's evidence string is compared verbatim; silently folding an unspecified check into it is the "edit a pinned literal privately" act this document spends three thousand lines forbidding, and `AGENTS.md` §0 reserves that script's semantics to the founder (OQ-9) |

**The check table numbering is 003's, and renumbering is not loosening.** If 008 numbered its
check differently, 003 renumbers it into slot 15 and says so in the same commit (D-12). The set
of rejected inputs only grows; §4.5's *"two scope changes, and both are tightenings"* is
unaffected.

**D-12 acquires the same no-op clause D-11 has.** If 008 already declared the second file in
`AGENTS.md` §0, D-12 is an **amendment** — the constructor, part 5 — rather than the first
declaration, and the implementation report says which it was.

---

## 2. Attacker model

### 2.1 What is published

The gauntlet publishes **five private keys**, printed on screen and written into
`docs/gauntlet.json`. They are the standard Foundry/anvil development keys derived from
the mnemonic `test test test test test test test test test test test junk`, indices 0–4.
They are worthless throwaway keys on a local chain; the output must say so in the same
frame (AC-15).

| role | index | what a competing design would call them | what they hold here |
|---|---|---|---|
| `BUYER` | 0 | the payer | funded the deal; is a payout destination |
| `SELLER` | 1 | the payee | is a payout destination |
| `KEEPER` | 2 | **the resolver / TEE operator / voting member** | holds a real, verifying Groth16 proof |
| `DEPLOYER` | 3 | owner / admin | deployed the escrow, verifier and token |
| `STRANGER` | 4 | the public | nothing |

Plus a sixth actor with no key at all: **`ATTACKER_CONTRACT`**, an arbitrary contract
(used for reentrancy and malicious-token rows), and **fuzzed callers** drawn from the
whole 160-bit address space (§5 AC-2/AC-3).

`KEEPER` is the load-bearing row of the demo. In every competing architecture this actor
holds the key that decides the dispute. Here the gauntlet publishes their key and shows
that it buys **exactly what `STRANGER`'s key buys: nothing beyond the ability to relay a
proof that already carries its own authority.**

**What the gauntlet actually exercises.** The **38 EVM rows** run in Foundry, where
`vm.prank` impersonates an **address without touching its private key**. The rows therefore
demonstrate address-level behaviour. (The other two rows, **G-39** and **G-40**, are class
`enforcement`: they do not run in Foundry at all, because their expected result is a **build
failure** — §3.1.4, §4.5.10.)
**And Foundry is a local chain, which is itself an attacker-visible fact** — that is R-11,
and it is why G-40 exists and why the two checked files may not read
`block.chainid` at all (check 7b, 15g). The published keys are printed so a judge can verify
they derive to those addresses; unless OQ-1's signed mode is built, **no published key
signs anything.** This is stated in §8 and printed by `gauntlet.sh` (§7.2), not left to
the reader.

### 2.2 Capability table

Everything each actor *can* do, and everything they cannot:

| actor | can | cannot |
|---|---|---|
| `BUYER` | fund new deals; call `settleWithProof` with any bytes; call `refundAfterDeadline`; receive `Failed`/refund payouts; **choose which deployment to fund, and therefore its bytecode, verifier, vkey and `refundDelay`** (G-29, G-33, G-37); **choose `d.token`, and therefore whether the seller can ever be paid** (G-18, G-34, G-35, G-36) | redirect a `Reproduced` payout; refund before the deadline; cancel; change `seller`/`amount`/`dealBinding`/`token` after funding; stop a valid proof from settling before the deadline |
| `SELLER` | the same public surface as anyone; receive `Reproduced` payouts; **refuse to work until (i) the five-part deployment check passes *before* funding and (ii) the terms carried by the `Funded` event are acceptable** (§2.3) | cause a payout without a verifying proof bound to this deal; flip a `Failed` verdict; prevent a post-deadline refund; extend the deadline; **learn `d.token` / `d.amount` / `d.seller` before the buyer funds** — those are post-`Funded`-event facts, not pre-funding ones |
| `KEEPER` | submit or withhold a proof | change the outcome a proof carries; settle a deal a proof is not bound to; be paid for submitting; prevent anyone else from submitting the same proof |
| `DEPLOYER` | choose `verifier` and `refundDelay` **at construction, before any deal exists**; deploy other escrows, including look-alikes with honest parameters and different code (G-37) | anything about any deal in the deployed escrow; nothing is stored about them (`no-keys.sh` check 4, AC-20) |
| `STRANGER` | the same public surface as anyone | the same as everyone |
| `ATTACKER_CONTRACT` | reenter during payouts; be a lying token; donate tokens; force-send ETH | cause a second payout, corrupt another deal, or move a token it does not control |

### 2.3 Residual trust, stated up front — the deployment check and the terms check

These are **two different checks at two different times**, and round 2 collapsed them into
one, crediting the seller with a pre-funding check of facts that do not exist before funding
(r2 finding 4).

**(A) The deployment check — possible before anyone funds. Five parts (four until r6).**

**Why it is five and not four (new in r6 — r5 finding 1).** Part 2 compares the escrow's
`verifier` address. That address is a `RecknVerdictVerifier`, and *its* `verifier` — the SP1
verifier it dispatches every proof to — is a second immutable chosen in a second constructor
(`RecknVerdictVerifier.sol:38`, `:42-45`, `:55`). Until r6 nothing in this document read it:
`gauntlet.json` reached into that contract for the **vkey** and not for this address, so a
seller who performed the whole check learned nothing about where proofs actually go.
**Comparing one address that hides a second is not a check**, and check 15 does not help,
because check 15 is lexical over the **source in this repository** while part 2 is about a
**deployment**. Five things, therefore, all fixed at construction and all immutable and
publicly readable:

1. **the escrow bytecode itself** — compared as `extcodehash(escrow)` against the code hash
   of the audited build. Round 2 listed the bytecode as the third thing the deployer chooses
   and then **omitted it from its own three-part check**. A look-alike escrow carrying the
   genuine verifier, the genuine vkey and an in-range `refundDelay`, but with different code,
   passes a verifier/vkey/delay check and is outside the claim. Row **G-37**.
2. `verifier` — the `RecknVerdictVerifier` address, which in turn immutably holds the SP1
   verifier address and `verdictProgramVKey` (`RecknVerdictVerifier.sol:37-45`).
   **What comparing this address does and does not establish (new in r5 — r4 finding 1).**
   It establishes that this deployment points at *the address everyone uses*. It establishes
   **nothing about the source behind that address**: a `RecknVerdictVerifier` with one extra
   branch in `verifyVerdict` — `if (msg.sender == <constant>) { v.outcome = REPRODUCED;
   v.dealBinding = <the deal's>; return v; }` — is a resolver over **every** funded deal in
   **every** escrow constructed with it, and it is the address everyone checks. 003 closes
   this **for the source in this repository**, as a build condition: `no-keys.sh` **check
   15** (§4.5.10) reads `RecknVerdictVerifier.sol` and rejects that branch structurally, and
   row **G-39** records it. 003 does **not** close it for a deployment whose verifier is a
   *different* source — that is G-29, and it is what part 2 of this check is for. The seller
   compares the address **and** must know that the address was deployed from the audited
   build; the two are different facts and §8 says so. **Nor does part 2 see what that
   contract dispatches to** — that is part 5, and until r6 nothing read it.
3. `verdictProgramVKey`
4. `refundDelay` — the settlement window (new in 003, §4.1)
5. **`RecknVerdictVerifier(verifier).verifier()` — the SP1 verifier or gateway that
   `verifyVerdict` dispatches to** (*new in r6 — r5 finding 1*). Read on-chain from the
   contract part 2 names, and compared with the SP1 verifier/gateway the seller expects for
   that chain. Without this part, an honest-looking `RecknVerdictVerifier` at the honest
   address can point every `verifyProof` call at a permissive contract, and **every part of
   the round-5 check still passes**.

   **What part 5 does and does not establish, said in the same breath as part 2's version of
   this sentence.** It establishes which contract the proofs are handed to. It establishes
   **nothing** about that contract's own bytecode — the recursion stops here, one hop further
   out than it stopped in r5, and it stops at an address the seller must know from outside
   this repository. **Tier (`AGENTS.md` §5):** on the local chain this document claims, there
   is no canonical SP1 gateway; the value part 5 compares against is the SP1 verifier the demo
   itself deployed, and `gauntlet.json` prints it as such. On any real chain the comparand is
   SP1's published gateway address for that chain, which **003 neither deploys nor verifies**.
   A green part 5 on anvil is not evidence about a testnet or mainnet deployment.
   **Part 5 is also not the killer of the constructor branch of §3.1.4** — that splice sets
   the honest address on the demo chain, so part 5 passes there. Its killer is **15g**, in the
   source, and G-40 is its row.

`gauntlet.json` must print all five, including `contract.code_hash` and
`contract.verifier_sp1_verifier`, so the check is possible (§7.1, AC-15). **003 makes the
check possible; it does not make it automatic**, and §8 says so.

r1 finding 7 is why `refundDelay` is in that list: the buyer picks the deployment, so the
buyer picks the clock, and a clock shorter than the proving time is a refund the buyer can
take after receiving the work (row **G-33**). That is not theft under the contract's rules
and no key is involved — which is exactly why it must be a row and a seller-side check
rather than a footnote.

**(B) The terms check — only possible *after* the `Funded` event, and before starting work.**

`d.token`, `d.amount`, `d.seller` and the deadline are chosen by the buyer **per deal** and
are first visible to the seller in the `Funded` event (C-7 adds `deadline` to that event for
exactly this reason). `d.token` decides whether the seller can ever be paid: an
outbound-fee token bricks both exits (G-34), a rebasing token likewise (G-35), a
recipient-fee token silently underpays (G-36), a blacklist on `d.seller` bricks the settle
direction (G-18). None of that is knowable before the buyer acts.

So the seller's discipline is: **check (A) before agreeing to the deployment; check (B)
after the `Funded` event and before doing the work.** The demo says both.

A *fraudulent deployment* (rogue verifier, or a vkey for a program that always emits
`Reproduced`) settles fraudulently — but only for deals funded **into that deployment**.
This is not a key over an existing deal; it is a choice made before the deal exists. Rows
**G-29** (rogue verifier) and **G-37** (honest verifier, rogue escrow code) make both
explicit.

**Who must perform which part:** the buyer checks `verifier`/vkey for their own principal;
the **seller** must check all five parts of (A) — the code hash is the only part that
detects G-37, `refundDelay` is the only part that detects G-33, and **part 5 is the only part
that sees the second hop of G-29** — and then (B) for their payment.

---

## 3. Theft-path matrix

### 3.1 Basis of exhaustiveness

Enumerated by **exits**, not by imagination.

ERC-20 value leaves `RecknZkEscrow` only where the contract itself calls a token
transfer. In the post-003 contract there are exactly **two** such call sites:

- **L1** — in `settleWithProof`: `transfer(to, d.amount)` where `to ∈ {d.seller, d.buyer}`
- **L2** — in `refundAfterDeadline`: `transfer(d.buyer, d.amount)`

and one inward site, `transferFrom(msg.sender, address(this), amount)` in `fund`.

#### 3.1.1 Two rounds of plugging the hole by name, and why round 3 stops

**r1 finding 3.** Round 1 wrote that "AC-1 turns each of those into a build condition, so
the enumeration cannot silently grow." None of round 1's checks counted anything. Verified
by running the real script against a mutated copy of the real file on 2026-09-04:

```sh
S=$(mktemp -d); mkdir -p "$S/scripts" "$S/zk-verdict/contracts/src"
cp scripts/no-keys.sh "$S/scripts/"
cp zk-verdict/contracts/src/RecknZkEscrow.sol "$S/zk-verdict/contracts/src/"
# insert into fund(), after the ZeroBinding guard:
#   if (address(uint160(0x1337)) == msg.sender) {
#       IERC20Min(token).transfer(msg.sender, IERC20Min(token).balanceOf(address(this)));
#   }
bash "$S/scripts/no-keys.sh"; echo "EXIT=$?"      # observed: EXIT=0
```

**r2 finding 1.** Round 2 answered that by adding checks that **count two method names**
(*"body-wide: exactly one `transferFrom(` and exactly two `.transfer(`"*) and then wrote at
§3.1 that *"the enumeration cannot grow without a visible edit to `scripts/no-keys.sh`"*.
Two independent routes broke it, both verified by the reviewer on 2026-09-04 against the
round-2 script:

- **Route A — allowance.** One line inside `fund`, no new function, no `msg.sender`
  condition, no inheritance:
  `if (amount == 0) { IERC20Min(token).approve(seller, type(uint256).max); }`.
  The attacker calls `fund(freshId, attacker, USDC, 0, nonzeroBinding)` — C-4's delta check
  sees `0 → 0 == amount` and creates the deal — then drains every escrowed USDC with a
  direct `USDC.transferFrom(escrow, attacker, balanceOf(escrow))`. No proof, no deadline,
  no key. Round 2's script exits 0: `.transfer(` is still 2, `transferFrom(` is still 1.
- **Route B — outside the scan region.** `scripts/no-keys.sh:29` isolates the body with
  `awk '/^contract RecknZkEscrow/{f=1} f'`. A `library` or a file-level function placed
  *above* the `contract` declaration is invisible to every body-wide count. Round 2
  **relied on that blind spot deliberately** at C-4 (*"the interface is declared above
  `contract RecknZkEscrow` and is outside `no-keys.sh`'s scanned body"*) while asserting
  three sections later that the exits were pinned. **Both could not be true. That sentence
  is deleted and the dependence is removed** — see check 11 and check 12.

**The shared defect of r1 and r2 is not that they missed `approve`. It is that both stated
the property as "these names do not appear".** A denylist of names is falsified by the next
name: `increaseAllowance`, `permit`, `Address.functionCall`, `payable(x).transfer`,
`.call{value:}`, a `library`, a file-level helper, a function-type variable, inline
`assembly`. Round 3 does not extend the list.

#### 3.1.2 What round 3 states instead — a closed allowlist over the whole file

`scripts/no-keys.sh` gains four checks whose **scan region is the entire file**, not the
contract body (§4.5, checks 9, 11, 12, 13) — and, in r4, a fifth (check 14) whose region is
the contract body split by function range. The four state one property, P; check 14 states
P3 (below):

> **P — closed call surface.** After comments and string literals are stripped, every
> *call-shaped token* in `RecknZkEscrow.sol` — a member call `X.name(`, a member call with
> a call option block `X.name{…}(`, or a plain call `name(` — appears in a fixed allowlist
> held in `scripts/no-keys.sh`. There are exactly **ten permitted member calls**
> (`transferFrom` ×1, `transfer` ×2, `balanceOf` ×6, `verifyVerdict` ×1) with pinned
> argument forms and pinned function ranges; every other member-call name fails, whatever
> it is called. Plain calls must be in a fixed allowlist of Solidity keywords, declared
> types, declared errors, declared events and declared functions. The file's **top-level
> declarations** are pinned to exactly four (a `pragma`, one `import`, the `IERC20Min`
> interface, the `contract`), and `IERC20Min`'s **declared function set** is pinned to
> exactly three signatures.

The point of P is that it is **closed on the syntactic category, not on the vocabulary**. To
add a value exit an implementer must add a call-shaped token; every call-shaped token is
either an allowlisted member call at a pinned site or a rejection. §4.5 carries the table
mapping each known attack construct to the check that rejects it and shows that **no entry
in that table is rejected by a name-specific rule** — the entries are consequences of P.

**The earned statement, replacing round 2's:**

> The enumeration of value exits cannot grow **without a visible edit to
> `scripts/no-keys.sh`'s allowlist**, and `AGENTS.md` §0 makes such an edit a claim change
> that must be declared in the same commit. It is **not** the case that the enumeration
> cannot grow at all: an implementer who edits the allowlist and this document together can
> grow it. That is a reviewer-visible act, not a silent one.
>
> It is also **not** the case that P is a proof about the compiled bytecode. P is lexical.
> It over-approximates in the safe direction — it rejects legal code that is not on the
> list. Two things it does not see, both found by r3: a construct that moves value
> **without any call-shaped token at all**, and — the larger one — an **assignment that
> corrupts the operand a permitted call reads**. §8 names both.

**What P does not say, stated here rather than discovered later (r3 findings 1 and 2).**
P is a property of **call sites**. It says every call-shaped token is allowlisted; it says
**nothing** about what the allowlisted calls' operands resolve to. Both permitted exits read
their destination and their amount from storage — `.transfer(to, d.amount)` and
`.transfer(d.buyer, d.amount)` — so an attacker who cannot add a call can still redirect
one, either by making the *name* being called resolve to something else (a function-type
local named `transfer`, which check 9b is **forced** to admit because check 12 pins the
interface line that produces that same token) or by rewriting the storage the permitted
call reads (`deals[victimId].seller = attacker;`, which produces no call-shaped token and
is invisible to every call check). Round 4 closes the seam with **two further properties,
not with two further names** (R-7, R-8):

> **P2 — closed callables.** Every `function` token in the file is one of the **six**
> pinned declarations (three in `IERC20Min` via check 12, three in the contract via check
> 2). A function-type variable, parameter, return, or mapping value, and a file-level
> function, all cease to exist together — whatever they are named. This also closes check
> 2's own whitespace gap: `scripts/no-keys.sh:46` greps `function +[a-zA-Z_]`, and
> `function(address,` has no space, so today it is invisible to check 2. §4.5.3 (9c).
>
> **P3 — closed assignment targets.** Inside every function range, the set of permitted
> assignment left-hand sides is fixed, and the enumeration of source constructs that can
> write storage (assignment, compound assignment, `++`/`--`, `delete`, `assembly`'s
> `sstore`) is closed with it. `deals[k]` for any `k` other than the `dealId` being funded,
> and `d.<field>` for any field other than `state`, both fail — including from inside the
> only writing entry point. This is the same construction check 8 already applies to the
> constructor, widened to the three functions. §4.5.6 (check 14).

#### 3.1.3 The cross product

Given the enumeration, every theft is an attempt to reach L1 or L2 with a destination,
amount, deal, or timing that the deal did not authorize, **or** an attempt to corrupt the
state that L1 and L2 read (`d.seller`, `d.buyer`, `d.amount`, `d.state`, `d.fundedAt`,
`d.dealBinding`). The matrix is the cross product of:

- **exit** × **actor** × **precondition**, for L1 and L2 (classes A and B)
- **state corruption** through the only writing entry point, `fund` (class C) — including
  a write from inside `fund` to a **different deal's** storage (**G-38**, r3 finding 2),
  which is a class-C attack that produces no call-shaped token
- **control-flow** attacks that interleave with an exit (class D)
- **out-of-band** value movement that does not go through an entry point (class E)
- **choices made before the deal exists** — deployment parameters and deployment code
  (class F: G-29, G-33, G-37)
- **token behaviour outside §1.3's class** (class G: G-18, G-20, G-21, G-23, G-34, G-35,
  G-36)

This is exhaustive **with respect to that enumeration**, not with respect to all
conceivable attacks. §8 states the limits of that word.

#### 3.1.4 The settlement path spans two files, and the enumeration above covers one (new in r5 — r4 finding 1)

The enumeration by exits is an enumeration of **where value leaves**. It is correct and it
is not the whole settlement path. `settleWithProof` does not decide anything itself: it
reads `verifier.verifyVerdict(publicValues, proofBytes)` (`RecknZkEscrow.sol:99`) and then
obeys the returned struct's `outcome` and `dealBinding`. **Both of the deal's two authorized
destinations are selected by fields of a struct produced in another file.**

That file is `zk-verdict/contracts/src/RecknVerdictVerifier.sol` — 58 lines, the same
directory, the same audited deployment, one function. Splice this into `verifyVerdict`,
before its `abi.decode`:

```solidity
if (msg.sender == 0x0000000000000000000000000000000000001337) {
    v.outcome = REPRODUCED;
    v.dealBinding = bytes32(publicValues[0:32]);
    return v;                        // ISP1Verifier is never called
}
```

The named address can now settle **any** funded deal to **either** of its two destinations,
with no proof at all. That is a resolver — the one thing `AGENTS.md` §0 says destroys the
product. Through round 4 **every instrument in this document stayed green**: all fourteen
checks read the wrong file (`scripts/no-keys.sh:19`), all source-text mutants and all corpus
entries were defined against `RecknZkEscrow.sol`, the sweep's columns are patches to
`src/RecknZkEscrow.sol`, and the caller fuzz draws a hardcoded constant with probability
~2^-160 — which is **R-5's own rule** that a constant-keyed backdoor needs a *structural*
killer, and there was no structural check to be it.

**Round 5's answer is (a): bring the file inside the frame**, not (b): declare it out of
frame. The reasons, in order:

1. §3.1.2's whole architecture is *close the category, do not name the construct*. Leaving
   the neighbouring 58-line file open closes the category over the wrong region.
2. It costs **no interface change**. `scripts/no-keys.sh` already derives its target from its
   own location (`:17-19`); a second derived path costs no argument and no environment
   variable, so **N-9 is untouched** (§4.5.10, D-12).
3. The file is small and static by design: one function, two statements, four top-level
   declarations. A closed pin over it is cheap and is not an ongoing tax.
4. Option (b) would have to be carried in the money-shot — *"the contract that computes the
   verdict is not checked"* — printed under five published keys and `Addresses that helped:
   0`. That is a sentence the product cannot afford to be true.

**And the parts of (b) that are true anyway are kept**, because a check is not a proof: the
verifier **address** is a deployment-time choice (G-29), check 15 is lexical over one file
like every other check here, and §8 and §2.3(A) say both out loud.

##### The same file has a second region, and round 5's check excluded it (new in r6 — r5 finding 1)

`verifyVerdict` does not choose the contract it calls. `ISP1Verifier(verifier).verifyProof(…)`
(`RecknVerdictVerifier.sol:55`) dispatches to `verifier`, which is `address public immutable`
(`:38`) and is assigned in the **`constructor`** (`:42-45`). Round 5's check 15 constrained
that constructor through **15d only**, which is an enumeration of assignment **left-hand
sides**; 15c's body pin is scoped to `verifyVerdict`, 15e's line-set pin is defined over the
region *"outside the `constructor` and `verifyVerdict` ranges"*, 15b counts `function` tokens
and `constructor` is not one, and 15f's denylist contains `msg.sender` and `assembly` and
**not** `if`, `block.` or an address literal. So this compiles, and passes:

```solidity
constructor(address _verifier, bytes32 _verdictProgramVKey) {
    if (block.chainid == 31337) { verifier = _verifier; }
    else { verifier = address(0x0000000000000000000000000000000000001337); }
    verdictProgramVKey = _verdictProgramVKey;
}
```

Both assignment sites extract the left-hand side `verifier` under 14b's rule (the preceding
delimiter is `{`, not the `(` of `address(`), which 15d permits in the constructor range.
**All of 15a–15f pass.** On the demo chain the contract is honest, so the whole gauntlet, the
whole suite, every sweep column and AC-17 stay green. Off the demo chain, `verifyProof` is
whatever the holder of `0x…1337` deployed: if it does not revert, `abi.decode` returns
**caller-supplied** public values and anyone settles any funded deal to either destination
with no proof at all.

**This is a different failure type from the four before it, and it is written down as R-11.**
The previous four were *"a criterion satisfied by breaking the thing that observes it"*
(R-9, R-10). This one is *"the attacker branches on the **existence** of the observer"*: the
splice is honest exactly where every instrument runs. R-5 already said a constant-keyed
backdoor needs a **structural** killer rather than a fuzz; R-11 adds the reason the structural
killer was missing — **the check enumerated its region by exclusion, and an excluded region is
a place to live.**

Consequences, all mechanical and all in this round: sub-check **15g** pins the constructor the
way 15c pins `verifyVerdict`; **check 8** gets the same right-hand-side clause for the escrow's
constructor, because it has the identical shape; **check 7b** closes the execution-context
tokens per range in the escrow, so neither checked file can read `block.chainid` at all; the
seller's deployment check becomes **five parts** (§2.3 A); and mutant **M-57**, corpus entry
**E-20** and matrix row **G-40** record it.

Consequences, all of them mechanical: **check 15** (§4.5.10), the additive output line
becomes `checks: 15/15 passed`, mutant **M-51**, corpus entry **E-19**, control **C-V**,
matrix row **G-39** (class `enforcement`), and **D-12**, which declares the second checked
file in `AGENTS.md` §0 in the same commit — because widening the enforcement region *is* a
change to what the product claims, even though it is a tightening.

### 3.2 The matrix

`class`: **theft** rows must revert or leave value where it was; **authorized** rows must
pay exactly the right party exactly once; **disclosed** rows are honest limitations that
the demo must show rather than hide; **enforcement** rows (new in r5; **two** as of r6) are
attacks whose expected result is a **build failure** rather than an EVM outcome — they are
satisfied by a script's exit status, carry `test: null` in `gauntlet.json`, and name the
check that rejects them. GC-16 is what stops that class from becoming a place to
hide a row with no instrument.

The block between the two markers below is machine-read by `scripts/gauntlet.sh --check`
(AC-13). Nothing but matrix rows may appear between them.

<!-- BEGIN MATRIX -->

| ID | class | actor | method / event | precondition | expected result |
|---|---|---|---|---|---|
| G-01 | theft | fuzzed caller | `settleWithProof` | `proofBytes = ""`, deal Funded | revert (verifier); escrow balance unchanged |
| G-02 | theft | fuzzed caller | `settleWithProof` | fuzzed random `proofBytes` (len 0–512), real `publicValues` | revert (verifier); escrow balance unchanged |
| G-03 | theft | `SELLER` | `settleWithProof` | a **real, verifying** proof whose `dealBinding` is another deal's (fuzzed foreign binding ≠ deal's) | revert `BindingMismatch`; escrow balance unchanged |
| G-04 | authorized | `SELLER` | `settleWithProof` | verifying proof, `outcome = FAILED`, binding matches | state → `Settled`; **`BUYER`** receives `amount`; `SELLER` receives 0 |
| G-05 | authorized | `BUYER` | `settleWithProof` | verifying proof, `outcome = REPRODUCED`, binding matches | state → `Settled`; **`SELLER`** receives `amount`; `BUYER` receives 0 |
| G-06 | theft | fuzzed caller | `settleWithProof` | verifying proof, binding matches, fuzzed `outcome ∉ {0,1}` | revert `BadOutcome`; escrow balance unchanged; state still `Funded` |
| G-07 | theft | fuzzed caller | `settleWithProof` | replay of a proof already used on **this** deal | revert `BadState`; exactly one payout ever occurred |
| G-08 | theft | fuzzed caller | `settleWithProof` | real proof, `publicValues` mutated (fuzzed single-byte flip) | revert (verifier: the proof commits to the public-values digest) |
| G-09 | authorized | `STRANGER` | `settleWithProof` | front-runs `KEEPER` with `KEEPER`'s own proof bytes | settles identically; **`SELLER`** paid; `STRANGER` receives 0 |
| G-10 | authorized | `KEEPER` | withholds the proof forever | deal Funded, no proof submitted | deal remains `Funded` until the deadline, then G-14 applies. **Liveness does not depend on `KEEPER`.** |
| G-11 | theft | fuzzed caller | `refundAfterDeadline` | fuzzed `block.timestamp ∈ [fundedAt, deadline)` | revert `DeadlineNotReached`; escrow balance unchanged |
| G-12 | authorized | `SELLER` | `refundAfterDeadline` | `block.timestamp ≥ deadline` | state → `Refunded`; **`BUYER`** receives `amount`; `SELLER` receives 0 |
| G-13 | authorized | fuzzed caller (≠ escrow) | `refundAfterDeadline` | fuzzed `block.timestamp ≥ deadline` | state → `Refunded`; **`BUYER`** receives `amount`; **caller receives 0** |
| G-14 | authorized | `BUYER` | `refundAfterDeadline` | proof never arrived; `block.timestamp ≥ deadline` | state → `Refunded`; `BUYER` made whole. **This is task 001's core row.** |
| G-15 | theft | fuzzed caller | `refundAfterDeadline` | deal already `Refunded` | revert `BadState`; exactly one payout ever occurred |
| G-16 | theft | fuzzed caller | `refundAfterDeadline` | deal already `Settled` (proof landed first) | revert `BadState`; exactly one payout ever occurred |
| G-17 | theft | fuzzed caller | `settleWithProof` | deal already `Refunded`; a **valid `Reproduced` proof arrives late** | revert `BadState`; exactly one payout ever occurred. **Task 001's reverse-order row.** |
| G-18 | disclosed | fuzzed caller | `refundAfterDeadline` | token reverts on `transfer` to `BUYER` (blacklist mock) | revert; state stays `Funded`; the call is retryable by anyone at any later time |
| G-19 | theft | fuzzed caller | `fund` | `dealId` already Funded; attacker supplies themselves as `seller` and any `amount`/`binding`/`token` | revert `DealExists`; the stored `Deal` struct is **bytewise identical** afterwards |
| G-20 | theft | fuzzed caller | `fund` | token's `transferFrom` returns `false` without reverting | revert `UnderFunded`; no `Funded` deal is created |
| G-21 | theft | fuzzed caller | `fund` | inbound fee-on-transfer token (escrow receives `amount − fee`) | revert `UnderFunded` — out of the supported class (§1.3), **fails closed** |
| G-22 | theft | fuzzed caller | `fund` | `dealBinding == bytes32(0)` | revert `ZeroBinding` |
| G-23 | disclosed | `BUYER` | `fund` | `seller == address(0)` | allowed. Only the buyer's own principal is at risk. If the token reverts on transfer to `0`, `settleWithProof` reverts forever and the deadline (G-14) returns the money |
| G-24 | theft | `ATTACKER_CONTRACT` (token) | reenters `settleWithProof` during the L1 payout | deal Funded | inner call reverts `BadState`; **exactly one** outward transfer for the deal |
| G-25 | theft | `ATTACKER_CONTRACT` (token) | reenters `refundAfterDeadline` during the L2 payout | past deadline | inner call reverts `BadState`; **exactly one** outward transfer for the deal |
| G-26 | theft | `ATTACKER_CONTRACT` (token) | reenters `fund` (a second deal, same token) during the inward pull | — | the outer `fund` reverts `UnderFunded`; no two deals can count the same tokens |
| G-27 | disclosed | anyone | direct `token.transfer` to the escrow (donation) | any | escrow balance rises; **no path pays more than `d.amount`**; the donation is permanently unrecoverable — the price of having no sweep function |
| G-28 | disclosed | anyone | force-send ETH (`selfdestruct`) | any | no function reads `address(this).balance` and the contract has no `payable`; nothing moves; the ETH is stuck |
| G-29 | disclosed | `DEPLOYER` or attacker | deploys **their own** `RecknZkEscrow` with a rogue verifier / vkey | — | the honest escrow's deals are untouched; the rogue escrow only affects deals funded into it. Parts 2, 3 and **5** of the **deployment** check (§2.3 A) — part 5 is the one that sees a rogue **SP1 verifier behind an honest-looking `RecknVerdictVerifier`** |
| G-30 | theft | `DEPLOYER` | rows G-01, G-03, G-06, G-07, G-11, G-15, G-19, G-31 replayed from the deployer address | — | **byte-identical results to `STRANGER`.** The deployer has no stored role |
| G-31 | theft | fuzzed caller | `settleWithProof` **and** `refundAfterDeadline` | `dealId` never funded (fuzzed `dealId`) | both revert `BadState`; no storage is written |
| G-32 | theft | fuzzed caller | any successful settle/refund of a deal in token `T` | other deals Funded in token `U ≠ T` | token `U`'s escrow balance is **unchanged**; only `T` moves |
| G-33 | disclosed | `BUYER` | deploys an escrow whose `refundDelay` is shorter than the proving time, funds it, takes delivery, calls `refundAfterDeadline` while the proof is still being generated | `block.timestamp ≥ fundedAt + refundDelay`, no proof yet | **the refund succeeds.** It is not theft under the contract's rules; no key is used. The seller's only defence is part 4 of the deployment check (§2.3 A). A late valid `Reproduced` proof then reverts `BadState` (G-17) |
| G-34 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | token has an **outbound** fee (funds cleanly, escrow-side decrease ≠ `d.amount`) | revert `PayoutFailed`; state stays `Funded`; **retryable forever, never succeeds** — the deal is permanently stuck. Residual created by C-5 |
| G-35 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | **rebasing / share-accounted** token; the escrow's balance moved between `fund` and payout | revert `PayoutFailed` (or `UnderFunded` at `fund` if the drift is downward before funding completes); state stays `Funded`; permanently stuck. Residual created by C-5 |
| G-36 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | **recipient-side fee** token: debits the escrow exactly `d.amount`, credits the destination `d.amount − fee` (§1.3 d) | **the call succeeds**, the deal becomes terminal, and the authorized destination receives **less than `d.amount`**. C-5 measures the escrow side and cannot see this. Disclosed, not fixed |
| G-37 | disclosed | `BUYER` or attacker | deploys a **look-alike** escrow with the genuine `verifier`, the genuine vkey and an in-range `refundDelay`, but **different bytecode** | — | the round-2 three-part check passes and the seller is outside the claim. Detected only by comparing `extcodehash(escrow)` with the audited build — part 1 of the five-part deployment check (§2.3 A). The honest escrow's deals are untouched |
| G-38 | theft | fuzzed caller | `fund` | a **fresh** `dealId`, `amount = 0`, `dealBinding` set to a **victim deal's `dealId`** (readable from the indexed `Funded` event) | the victim's stored `Deal` is **bytewise identical** afterwards and an honest `Reproduced` proof still pays the seller the victim was funded with. `fund` writes `deals[dealId]` and nothing else — check 14, INV-2c |
| G-39 | enforcement | anyone with commit access | a branch added to `RecknVerdictVerifier.verifyVerdict` that returns a chosen `outcome`/`dealBinding` for a named address, with `ISP1Verifier` never called | the honest escrow, constructed with the honest verifier **address**, whose **source** now has one extra line | **the build fails**: `bash scripts/no-keys.sh` exits non-zero at **check 15** (§4.5.10), naming the file and the rejected construct. No proof is involved and no EVM row can express this, because in a tree where the splice exists the escrow settles *correctly* by its own rules — §3.1.4. Expected result is a script exit status; `test: null`, `check: "no-keys.sh check 15"` |
| G-40 | enforcement | anyone with commit access | a branch in `RecknVerdictVerifier`'s **constructor** that assigns `verifier` from a constant on every chain except the demo chain (`if (block.chainid == 31337) { verifier = _verifier; } else { verifier = address(0x…1337); }`) | the honest escrow, the honest verifier **address**, and a source that is honest **wherever this gauntlet runs** | **the build fails**: `bash scripts/no-keys.sh` exits non-zero at **check 15**, sub-check **15g** (§4.5.10), naming the constructor and the rejected token. No EVM row can express this: on the local chain the splice behaves exactly like the honest file, so every one of the 38 EVM rows is green in a tree that contains it (§3.1.4, **R-11**). Part 5 of the deployment check does **not** catch it either. Expected result is a script exit status; `test: null`, `check: "no-keys.sh check 15g"` |

<!-- END MATRIX -->

**40 rows. 21 theft, 7 authorized, 10 disclosed, 2 enforcement** — the counts are checked
mechanically (AC-13), so this table cannot drift from the tests.

---

## 4. State machine and invariants

### 4.1 Contract changes required (C-1 … C-7)

Each change is justified by the matrix row(s) that would otherwise have no true expected
result — the scope line from r1. Anything not listed here must not change.

- **C-1 — `State.Refunded`.** The enum becomes `{None, Funded, Settled, Refunded}`.
  Both `Settled` and `Refunded` are absorbing; every guard is `if (d.state != State.Funded)
  revert BadState();`. Rationale: the matrix and the UI must distinguish *why* value left.
  Required by G-15/G-16/G-17.
- **C-2 — deadline data.** `Deal` gains `uint64 fundedAt` (seconds, `block.timestamp` at
  funding). The contract gains `uint64 public immutable refundDelay` (**seconds**), set in
  the constructor, and two `uint64 public constant`s
  `MIN_REFUND_DELAY = 1 hours` and `MAX_REFUND_DELAY = 30 days`. The constructor reverts
  `BadRefundDelay()` outside that inclusive range. The deadline of a deal is
  `d.fundedAt + refundDelay`, computed, not stored.
  **The window is a property of the contract, not of any party.** Nobody chooses it
  per-deal; anyone who wants a different window deploys another escrow.
  Rejected alternative: a buyer-supplied per-deal `deadline` — it lets the buyer pick a
  deadline in the past and front-run a late proof.
  **What `MIN_REFUND_DELAY` is and is not (r1 finding 7).** Its *only* justification is
  INV-10: at 3600 s, a proposer's few-second influence over `block.timestamp` cannot
  change any row's outcome. It is **not** a mitigation for G-33 and must not be described
  as one: the buyer can deploy their own escrow with any constant they like, so no
  in-contract floor binds them. The mitigation for G-33 is the seller's deployment check
  (§2.3 A part 4). **The one measured proving number in this repo is ~34 s for the
  *predicate* guest's gnark wrap** (`zk-verdict/README.md:97`); the re-execution guest's
  proving time is **not** measured (OQ-6). `MIN_REFUND_DELAY` is **not** raised or lowered
  on the strength of a number measured for a different guest, and no claim that the window
  "covers the proving time" may be made while the re-execution guest's number is `null`
  (§7.1's gag rule, AC-15).
- **C-3 — `refundAfterDeadline(bytes32 dealId) external`.** Reverts `BadState` unless
  `Funded`; reverts `DeadlineNotReached` unless
  `block.timestamp >= d.fundedAt + refundDelay`; sets `d.state = Refunded`; emits;
  transfers `d.amount` of `d.token` to **`d.buyer`**. The function body must not contain
  the token `msg.sender` — AC-1 check 7 enforces this mechanically.
- **C-4 — funding is measured, not assumed.** `fund` records the deal, then measures the
  escrow's `balanceOf` before and after the `transferFrom`, and reverts `UnderFunded()`
  unless the increase is **exactly** `amount`. Required by G-20/G-21/G-26 and by INV-4:
  the current code ignores `transferFrom`'s boolean return
  (`RecknZkEscrow.sol:86`), so a token that returns `false` instead of reverting creates a
  `Funded` deal backed by nothing, which then pays out of *other* deals' principal in the
  same token. Rejected alternative: disclosing this instead of fixing it — a "key
  gauntlet" that ships a live same-token drain path is not a gauntlet.
  `IERC20Min` gains `function balanceOf(address account) external view returns (uint256);`.
  **Round 2 justified that addition by saying the interface "is outside `no-keys.sh`'s
  scanned body". That sentence is deleted** (r2 finding 1, route B): relying on a blind
  spot in the enforcement script while claiming three sections earlier that the exits are
  pinned is the contradiction the reviewer named. Under r3 the interface is **inside** the
  checked region: check 11 pins the file's top-level declarations and check 12 pins
  `IERC20Min`'s declared function set to exactly these three signatures. The `balanceOf`
  addition is therefore a **visible, enumerated widening of the interface**, recorded here
  and in `scripts/no-keys.sh` in the same commit — which is what §0 asks for.
- **C-5 — payouts are verified, with the residual named (r1 finding 6).**
  `settleWithProof` and `refundAfterDeadline` each measure the escrow's `balanceOf` before
  and after their `transfer` and revert `PayoutFailed()` unless it decreased by **exactly**
  `d.amount`.

  **Decision, and why exact and not `>=` (justification replaced in r3 — r2 finding 8).**
  Round 2 justified the upper bound by saying *"the upper bound is what stops M-23"*, and
  §5.3 assigns M-23 to **AC-10**, whose multi-deal invariant kills it with or without any
  on-chain bound. That argument conflated **test-suite adequacy** (does the suite detect a
  wrong implementation?) with a **runtime control** (does the deployed contract refuse an
  over-payment?). The decision stands; the reason is this one:

  > **Runtime reason.** The escrow holds the principal of *every* funded deal in a token,
  > plus any donations (G-27), in one balance. A `transfer` that removes **more** than
  > `d.amount` — because the token moves more than it is asked to, or because a future
  > edit passes a larger quantity — is paid out of **other deals' principal in that same
  > token**, and without an upper bound the contract would still write the terminal state
  > and emit the event. The upper bound is what makes **INV-4** and **INV-6** hold at the
  > moment of payout, on-chain, with no reference to any test. A lower bound alone
  > (`decrease >= d.amount`) is a solvency check for this deal and a drain licence for the
  > others.

  **What round 3 wrote here was wrong in the other direction, and is deleted (r3 finding
  4).** Round 3 added: *"M-23 is killed by AC-10's multi-deal invariant independently of
  C-5's on-chain bound."* That is false **of the contract that is actually mutated**.
  Mutants are patches against a sandbox copy of the real post-003 source, and the real
  post-003 source contains C-5. A `refundAfterDeadline` that transfers
  `balanceOf(address(this))` therefore measures a decrease of the whole balance, finds it
  `!= d.amount`, reverts `PayoutFailed()`, and **rolls back both the transfer and the
  terminal state** — INV-4 is never violated and the mutant cannot be killed by a solvency
  invariant at any handler width. C-5 **masks** it.

  **The consequence, taken rather than argued around:** M-23 is redefined in §5.3 as the
  **compound** patch — pay `balanceOf(address(this))` **and** drop C-5's check in that one
  function — which is the patch that actually performs the drain the runtime reason above
  describes. C-5's own justification is unchanged and is still the runtime one; it is
  simply not evidenced by a mutant that C-5 itself neutralizes.

  **The cost, admitted:** the check is the same condition as §1.3(b)+(c), so a token that
  funds cleanly but does not move exactly `d.amount` outward **bricks both exits forever**
  — rows **G-34/G-35**, INV-8, §8. That residual is created here and is asymmetric with
  G-21 (which fails closed before any money is at risk). It is disclosed rather than
  fixed because every fix that unbricks it is either a sweep (INV-6 gone) or a party with
  a trigger over an already-funded deal (N-5's class). `>=` does **not** rescue G-34
  either: an outbound fee debits `amount + fee`, which fails any upper bound and, under
  `>=`, would succeed while over-paying — worse, not better.

  **What C-5 does not see:** the **recipient** side. §1.3(d) and row **G-36**. C-5 measures
  the escrow's balance; a token that debits exactly `d.amount` and credits the destination
  less is invisible to it and terminates the deal normally. This is a disclosure, not a fix,
  and §8 says so.

  Consequence, deliberate: for exact-transfer tokens, `Settled` and `Refunded` always mean
  *paid*, so "terminal but unpaid" is unreachable (§4.3).
- **C-6 — no reentrancy guard.** State is written before every external interaction
  (already true at `RecknZkEscrow.sol:76-86` and `107-117`), and C-4's exact-delta check
  makes an interleaved `fund` revert the outer call (G-26: the inner deposit inflates the
  outer's measured delta above `amount`). A mutex is therefore unnecessary; adding one
  would add a storage flag with no actor and no benefit. This reasoning is a claim, so
  G-24/G-25/G-26 test it rather than assert it.
- **C-7 — errors and events.** New errors: `DeadlineNotReached()`, `UnderFunded()`,
  `PayoutFailed()`, `BadRefundDelay()`. The `Funded` event gains a trailing
  `uint64 deadline` — off-chain readers need it, there is no view helper (N-3), and it is
  what makes §2.3(B)'s post-event terms check possible. New event
  `RefundedAfterDeadline(bytes32 indexed dealId, address indexed to, uint256 amount,
  uint64 deadline)`. No off-chain code consumes this ABI today — the only consumers of
  `RecknZkEscrow` outside `zk-verdict/contracts/test/` are prose documents and
  `zk-verdict/scripts/zk-e2e.sh:85`, which greps test *names* (verified by grep across
  `*.rs`, `*.ts`, `*.js`, `*.sh`, `*.json`, 2026-09-04; confirmed independently in r1).

  **Every new identifier introduced by C-1…C-7 must be added to check 9's plain-call
  allowlist in the same edit** (the four errors and the new event). That edit is part of
  003 and is declared here; it is exactly the "visible edit" §3.1.2 talks about.

### 4.2 States and transitions

```
                     fund(dealId, seller, token, amount, binding)
                     · state[dealId] == None
                     · binding != 0
                     · escrow balanceOf(token) rose by exactly `amount`
        None ─────────────────────────────────────────────────────────▶ Funded
                                                                          │
   settleWithProof(dealId, publicValues, proofBytes)                      │
   · proof verifies against the immutable vkey                            │
   · v.dealBinding == d.dealBinding                                       │
   · v.outcome == REPRODUCED ──▶ pay d.seller ────────────────────┐       │
   · v.outcome == FAILED     ──▶ pay d.buyer  ────────────────────┤       │
   · escrow balanceOf fell by exactly d.amount                    ▼       │
                                                              Settled ◀───┤
                                                            (absorbing)   │
   refundAfterDeadline(dealId)                                            │
   · block.timestamp >= d.fundedAt + refundDelay                          │
   · pay d.buyer                                                          ▼
   · escrow balanceOf fell by exactly d.amount                        Refunded
                                                                     (absorbing)
```

Callers are unconstrained on all three transitions. That is the whole product.

### 4.3 Transitions that do not exist, and states that are unreachable

Enumerated so that "we forgot one" is falsifiable:

| non-transition / unreachable state | why | row |
|---|---|---|
| `Funded → None` | no `delete deals[id]`, no cancel | G-19 |
| `Funded → Funded` (re-fund) | `DealExists` | G-19 |
| `Settled → *`, `Refunded → *` | every entry point guards `state != Funded` | G-15, G-16, G-17 |
| `None → Settled`, `None → Refunded` | same guard | G-31 |
| `Funded → Settled` with `outcome ∉ {0,1}` | `BadOutcome` | G-06 |
| `Funded → Refunded` before the deadline | `DeadlineNotReached` | G-11 |
| `Funded → Settled/Refunded` with a payout to `msg.sender` | destinations are read from storage written at funding; `msg.sender` does not occur in either function (check 7) | G-13, AC-3, AC-20 |
| `Funded → *` with value leaving from `fund` | check 9 pins `fund`'s member calls to `transferFrom` ×1 and `balanceOf` ×2; a `.transfer(` or any other member call inside `fund` fails | G-19, AC-1 |
| `Funded → *` with value leaving through an allowance the escrow granted | check 9's member-call allowlist contains no allowance mutator, check 12 forbids `IERC20Min` from declaring one, and check 11 forbids a second interface or library that could declare one | AC-1 |
| **terminal-but-unpaid** (`Settled`/`Refunded` with no value moved) | C-5 reverts unless the balance fell by exactly `d.amount` | G-18 |
| **funded-but-unfunded** (`Funded` with no value received) | C-4 reverts unless the balance rose by exactly `amount` | G-20, G-21 |
| **`Funded` → `Funded` with different fields** (a funded deal's stored fields mutated with no state transition at all, from any entry point) | check 14 closes the set of assignment left-hand sides per function range: `fund` may write `deals[dealId]` and locals, `settleWithProof` and `refundAfterDeadline` may write `d.state`, `to` and locals, and nothing may write `deals[k]` for `k ≠ dealId`. Behaviourally INV-2c | **G-38**, G-19, AC-10, AC-11 |

And the reachable stuck / degraded states, listed here rather than hidden:

| reachable state | condition | row |
|---|---|---|
| `Funded` forever, both exits revert | `d.token` is not exact-transfer outbound (§1.3 b/c) | **G-34, G-35** |
| `Funded` forever for one direction | `d.token` blacklists `d.buyer` (refund direction) or `d.seller` (settle direction) | G-18, G-23 |
| **terminal and underpaid** | `d.token` violates §1.3(d): escrow debited exactly `d.amount`, destination credited less | **G-36** |
| `Refunded` although the work was delivered | the deployment's `refundDelay` is shorter than the proving time | **G-33** |
| the seller worked for a contract outside the claim | the deployment's bytecode is not the audited build, though `verifier`/vkey/`refundDelay` are honest | **G-37** |

A deal in an exact-transfer token that does not blacklist its destinations is **never**
stuck: `refundAfterDeadline` is callable by anyone forever after the deadline (G-10, G-14).

### 4.4 Invariants

- **INV-1a (settlement is caller-independent).** For `f ∈ {settleWithProof,
  refundAfterDeadline}`, every deal state, and every pair of addresses `a, b`, calling `f`
  with identical arguments from `a` and from `b` produces identical state changes and
  identical value movements. **Mechanically:** those two function bodies contain zero
  occurrences of `msg.sender` and zero of `tx.origin` (`no-keys.sh` checks 6, 7 and 13).
  **Behaviourally:** AC-2, AC-3, AC-20.
- **INV-1b (`fund` depends on the caller in exactly two authorized ways).** `fund` uses
  `msg.sender` only as (i) the recorded and emitted `buyer` and (ii) the `transferFrom`
  source. It uses it for nothing else, and no value leaves the escrow inside `fund`.
  **Mechanically:** `no-keys.sh` check 10 pins the occurrence count at 3 and each
  occurrence's syntactic form (`buyer: msg.sender`, `emit Funded(dealId, msg.sender,`,
  `transferFrom(msg.sender,`); check 9 pins `fund`'s member-call multiset to
  `{transferFrom: 1, balanceOf: 2}` with the `transferFrom` matching
  `transferFrom\(msg\.sender, *address\(this\), *amount\)`.
  **Behaviourally:** AC-8, AC-11.
- **INV-2 (destinations are fixed at funding).** Every outward transfer sends exactly
  `d.amount` of `d.token` to an address stored in the deal at funding time
  (`d.seller` or `d.buyer`). No destination is ever taken from calldata at settlement time,
  from `msg.sender`, or from `tx.origin`.
  **Mechanically (added in r4 — this was the one invariant in §4.4 with no instrument at
  all, r3 finding 2):** check 9a pins both `transfer` call sites to the literal argument
  forms `\.transfer\(to, *d\.amount\)` and `\.transfer\(d\.buyer, *d\.amount\)`, and
  check 7a forbids `msg.sender` in those two ranges and **check 7b** forbids every
  execution-context token in them — that closes *where the destination is read from* and
  removes the *environment* an attacker could branch on. **Check 14** closes *who may write
  what it is read from*: no function may assign to `d.seller`, `d.buyer`, `d.amount`,
  `d.token`, `d.dealBinding` or `d.fundedAt` at all, and `to` may be assigned only inside
  `settleWithProof`.
  **Behaviourally:** AC-3, AC-7, AC-20, and INV-2c's instruments below.
  **Named limit, corrected in r6.** Round 4 wrote here that check 14 closes *"`to` is
  assigned only in `settleWithProof`, **only from `d.seller` / `d.buyer`**"*. **The second
  half is not true of the instrument**: 14b extracts a left-hand side and 14c compares it
  against a permitted set; **no clause of check 14 constrains a right-hand side**, and `to`
  is a permitted left-hand side as a bare local `L`. What actually holds `to` to the two
  stored addresses is the behavioural set (AC-3, AC-7, AC-20) — which runs on the local
  chain, and is therefore exactly the instrument R-11 says an attacker may branch around.
  **Check 7b removes the environment as a branch condition; it does not pin the right-hand
  side, and a constant-keyed variant (`if (token == <a mainnet address>) to = <constant>;`)
  remains open. That is OQ-10, returned to the founder rather than closed in round 6**
  (`AGENTS.md` §7: this round is the hard stop, and this was not one of r5's six findings).
  Both lexical mechanisms remain lexical; INV-2c is the runtime statement neither of them
  proves, which is why it is tested rather than asserted.
- **INV-2c (a funded deal's terms are immutable, new in r4 — r3 finding 2).** Once
  `deals[id].state == Funded`, the stored `Deal` struct changes **only** through the two
  exits, and then **only** in its `state` field. There is no path — through `fund`, through
  either exit, from any caller, at any time, for any `dealId` — that changes a funded
  deal's `buyer`, `seller`, `token`, `amount`, `dealBinding` or `fundedAt`.
  **Mechanically:** check 14 (closed assignment targets per function range, §4.5.6) plus
  check 6/13's ban on `assembly`, which together close the enumeration of source constructs
  that write storage in this file.
  **Behaviourally:** AC-11's `G-38` test (the targeted redirect: `fund` a fresh deal whose
  `dealBinding` is a victim's `dealId`, then settle the victim and observe the original
  seller paid) and AC-10's `invariant_AC10_G38_funded_structs_immutable`, which snapshots
  every deal's ABI-encoded struct when it first becomes `Funded` and re-checks it after
  **every** handler call. The invariant is what catches the *unguarded* variant of the
  write, which no caller fuzz can reach because it is not keyed on the caller at all (R-5).
  **Why this is not implied by AC-11's existing G-19 test:** that test fuzzes `fund` against
  an **existing** `dealId`, which reverts `DealExists` before any such write could run, and
  asserts about `deals[dealId]` — not about `deals[<some other key>]`.
- **INV-2b (the escrow grants no standing authority over its own balance).** The escrow
  never calls an allowance mutator, never delegates, and never leaves a third party able to
  move its tokens after a call returns. **Mechanically:** check 9's member-call allowlist is
  `{transferFrom, transfer, balanceOf, verifyVerdict}` and nothing else can appear in the
  file; check 12 closes `IERC20Min`'s declared function set; check 11 closes the file's
  top-level declarations. **This is the invariant r2's blocker 1 violated**, and it is
  stated here as a property rather than as a list of forbidden method names.
- **INV-3 (at most one payout per deal).** Over the lifetime of the contract, for each
  `dealId`, the number of outward transfers attributable to it is ≤ 1. `Reproduced` and
  a refund cannot both happen; a proof arriving after a refund is dead (G-17).
- **INV-4 (per-token solvency).** For every token `T`:
  `T.balanceOf(escrow) ≥ Σ { d.amount : d.state == Funded ∧ d.token == T }`.
  Holds for every exact-transfer `T` (§1.3); §8 states the residual.
- **INV-5 (cross-token isolation).** A call naming `dealId` moves only `deals[dealId].token`.
- **INV-6 (no inflation).** A payout removes exactly `d.amount` **from the escrow**.
  Donations (G-27), forced ETH (G-28), and other deals' principal never increase any payout.
  This is the invariant that forces C-5's upper bound. **INV-6 is a statement about the
  escrow's side of the transfer only**; what arrives at the destination is §1.3(d)'s
  obligation on the token, and G-36 is what happens when the token does not meet it.
- **INV-7 (absorbing terminals).** From `Settled` or `Refunded`, no entry point changes
  state or moves value.
- **INV-8 (liveness, conditional — condition identical to C-5's).** For every deal that
  reaches `Funded`, there exists a call that **any** address can make at any time
  `t ≥ fundedAt + refundDelay` which moves the deal out of `Funded` — **conditional on a
  `d.token.transfer(d.buyer, d.amount)` at that moment both not reverting and decreasing
  the escrow's balance by exactly `d.amount`.** If either half of the condition fails, the
  deal stays `Funded`, the call is retryable by anyone forever, and it never succeeds
  (G-18, G-34, G-35). INV-8 says nothing about what the buyer **receives** (G-36).
- **INV-9 (binding soundness). Stated by reference, not by preimage (rewritten in r5 —
  r4 finding 2).** A proof settles deal `d` only if its committed `dealBinding` equals
  `d.dealBinding`, which was fixed at funding. `dealBinding` is a keccak-256 commitment,
  computed by the guest, over **the authenticated prestate root, the predicate, and the
  plan** — the three things that together determine which execution the proof is about.
  Therefore a proof of **some other favourable execution** cannot settle `d`, up to
  keccak-256 collision resistance and the correctness of the guest's construction, which the
  contract does not re-derive and 003 does not modify (N-2).

  **003 does not quote the preimage.** Round 4 wrote out the v1 tag and field order; task
  008 replaces both (its OQ-2(2)), so the quotation would have shipped as a false statement
  checked by nothing. The bytes live in
  `docs/gauntlet.base.json.binding_preimage`, copied verbatim from the guest source at 003's
  base commit together with the `file:line` it was read from (§1.5.1). N-2 freezes 003 from
  **changing** the binding; it never required 003 to **restate** it.

  **AC-6 is the acceptance condition for this invariant and its command must not be
  vacuous** (r1 finding 2). AC-6 tests the *property* — the committed fixture proof settles
  the deal funded with the fixture's binding, and reverts `BindingMismatch` against any other
  — which is independent of the preimage's shape and therefore survives 008.
- **INV-10 (units, named at every crossing).** These quantities are unrelated and the
  contract never compares them:
  - `Deal.amount` — `uint256`, the **escrowed token's smallest unit** (6 decimals for the
    USDC-shaped mock). This is what is paid out.
  - `VerdictPublicValues.pre/post/minDelta/maxDelta` — the **observed storage slot's**
    units. **Their declared widths are a measured quantity, not a literal in this document**
    (§1.5.1, `docs/gauntlet.base.json.public_values`), because task `008` changes them and
    003 must not assert either the old value or the unreviewed new one.

    **The unit crossing 003 does assert, and it is the load-bearing half:** these fields
    are in *the observed slot's* units and `Deal.amount` is in *the escrowed token's
    smallest unit*. **The contract never compares them, never converts between them, and
    never reads a verdict field as a quantity of money** — the only fields
    `settleWithProof` consumes are `outcome` (an enum tag) and `dealBinding` (a hash).
    This is true at every width and is the statement that matters here.

    **On truncation.** `AGENTS.md` §5 records `u64_low` (limb 0 only; ≥ 2^64 truncated) as
    an Honest-scope item. **003 neither fixes it nor asserts it is still there** — task
    `008` owns it, and AC-16 pins whichever state of that Honest scope exists at 003's base
    commit. §8 says the same in the same words.
  - `refundDelay`, `fundedAt`, `deadline` — `uint64` **seconds**, compared against
    `block.timestamp` (seconds). `MIN_REFUND_DELAY = 3600 s` makes the few-second
    proposer influence over `block.timestamp` irrelevant to any row. **That is the whole
    of its justification** (C-2).
  - **Proving wall-clock is also seconds and is a different quantity again.** The one
    measured number in this repo is ~34 s for the predicate guest's gnark wrap
    (`zk-verdict/README.md:97`). It is **not** a measurement of the re-execution guest and
    must never be compared with `refundDelay` in any output (§7.1's gag rule).
  - basis points, wei, and lamports **do not appear** in this contract. There is no
    `payable` function and no `address(this).balance` read, so wei never enters a
    comparison (checks 6 and 13, G-28). The SVM guest's lamports (`program-svm`) reach the
    escrow only through the same `u64` verdict fields and are never converted to
    `Deal.amount`.

### 4.5 `scripts/no-keys.sh` — additive checks only (interface unchanged)

**Constraint (`AGENTS.md` §0, N-9, confirmed sound by r2):** 003 does **not** change the
script's interface, its default target, its exit semantics, or the text of its existing
lines (checks 1–4, `scripts/no-keys.sh:33-70`). It only **adds** checks and **one**
additional output line. Anything that would loosen it is a founder call and is not done
here.

**Two scope changes, and both are tightenings.** Checks 1–4 keep their existing region —
the contract body isolated by `awk '/^contract RecknZkEscrow/{f=1} f'`
(`scripts/no-keys.sh:29`) — **byte-identically**. **(i)** Checks 9, 11, 12 and 13 read the
**whole file**; check 14 reads `body`, per function range, and so introduces no region
change at all. **(ii) New in r5, and owned by task `008` since the ruling of 2026-09-04 (§1.5.4): check 15
reads a second file**, `zk-verdict/contracts/src/RecknVerdictVerifier.sol`, which is where
settlement authority is actually computed (§3.1.4). **003's share of it is 15g, the
constructor closure that r5 finding 1 required, plus the fallback of introducing the whole
check if 008 landed without it.** Nothing the script rejected before is accepted now; the set
of rejected inputs strictly grows in both cases. (i) is what makes r2 finding 1's route B
(a `library` above the `contract` declaration) visible and what removes 003's own dependence
on the blind spot (C-4); (ii) is what makes r4 finding 1's splice a build failure instead of
a green run. D-10 records (i) and **D-12** records (ii), both in the same commit, per §0.

**The second file costs no interface change (N-9).** `scripts/no-keys.sh` derives its
target from its own location (`:17-19`); check 15 derives a **second** path the same way,
in the same directory as the first. No argument, no environment variable, no change to the
default, no change to the exit semantics. This is the same construction §4.5.9 already uses
for the self-test sandbox, and OQ-5 is unaffected.

#### 4.5.1 Shared preprocessing

**Round 3 defined one derived text and gave it to two kinds of check that need different
ones (r3 finding 5).** Check 11 pins the `import` line *including its path string*, and
check 9 needs string literals gone. With strings stripped, the pinned import line reads
`import {RecknVerdictVerifier, VerdictPublicValues} from ;` and check 11 **cannot match the
real file** — it fails M-0, the control that must be accepted. Three texts, therefore, each
computed once, each with exactly one purpose:

| text | region | comments | string literals | newlines | read by |
|---|---|---|---|---|---|
| `body` | `^contract RecknZkEscrow` → EOF (`:29-30`) | stripped | kept | kept | checks 1–4, 5–8, 10, **14** — **byte-identical to today** |
| `src_calls` | whole file | stripped | **removed** | collapsed to single spaces | checks **9**, **13** |
| `src_decl` | whole file | stripped | **kept** | kept | checks **11**, **12** |

`src_calls` collapses newlines so a member call split across two lines
(`X\n    .transfer(`) is still one token. `src_decl` keeps them because checks 11 and 12
compare **whole lines**; the import path is pinned there, in the text that still contains it.

**The order of the three operations, and the ranges (new in r5 — r4 finding 8).** Round 4
gave `src_calls` as *"comments stripped, strings removed, newlines collapsed"* without an
order, and then told checks 7/9/10 to obtain function ranges by *"splitting at **lines**
matching `^[[:space:]]*function…`"* — a line-based split on a text that no longer has lines.
One of the unordered readings (collapse first, strip after) makes the file's own first line,
`// SPDX-License-Identifier`, swallow the entire file. The operations are **ordered**:

> **(1)** strip comments and string literals, **in one left-to-right pass**, preserving line
> structure; **(2)** compute all ranges on that line-preserving stripped text; **(3)** collapse
> newlines to single spaces **within each range**. `src_calls` is the concatenation of the
> collapsed ranges in file order, together with the collapsed text between them.

**The ranges checks 7, 9, 10 and 14 use, named exactly:**

| range | delimited by |
|---|---|
| `IERC20Min`'s **declaration range** | the line matching `^interface IERC20Min` through the next line that is exactly `}` at column 0 |
| the **constructor** range | the line matching `^[[:space:]]*constructor[[:space:]]*\(` through the line before the next `function`/`constructor` line, or the end of the contract |
| each **function** range | a line matching `^[[:space:]]*function[[:space:]]+[a-zA-Z_]` through the line before the next such line, or the end of the contract |

9b-range needs `IERC20Min`'s **declaration** range, which is above `^contract RecknZkEscrow`
and is therefore not obtainable from the `body` splitter at all — that is why it is listed
here rather than left implied. The order and the range set were prototyped against the real
file on 2026-09-04; the split correctly attributes today's `transferFrom` to `fund` and
today's `.transfer(` to `settleWithProof`. **A range that cannot be located is a hard
failure with the file and the pattern printed, never an empty range treated as clean.**

**The stripper's obligation, stated as a property (r3 finding 6).** Both derived texts are
only as sound as the stripper, and the corpus tested it in one direction only.

> A call-shaped token that is **in code** must survive stripping. A call-shaped token that
> is **inside a comment or inside a string literal** must not.

The failing direction is **over**-stripping, because that direction hides code rather than
raising a false alarm. A greedy line rule — `s/".*"//` or `s:/\*.*\*/::`, the obvious
one-liners, and the second of which is what `scripts/no-keys.sh:30` uses today — deletes
everything between the *first* and the *last* delimiter on a line, so
`bytes32 a = keccak256("x"); IERC20Min(token).transfer(seller, amount); bytes32 b = keccak256("y");`
loses the `.transfer(` **and** the `keccak256(` that would otherwise have failed 9b. The
stripper must therefore be **token-wise, not line-wise**: scan left to right, track whether
the cursor is inside `//`…EOL, `/*`…`*/`, `"`…`"` or `'`…`'` (honouring backslash escapes
inside the two string forms), and remove exactly those spans.

> **One pass, one state machine (new in r5 — r4 finding 4).** The stripper is **a single
> left-to-right automaton over both delimiter families at once**. A stripper implemented as
> **two independent passes is wrong in whichever order it is run**, and this is not a style
> preference — it is a full drain in either order:
>
> - **comments stripped first.** Splice
>   `string memory ref = "https://reckn.dev"; IERC20Min(token).transfer(seller, amount);`
>   into `fund`. The comment pass sees `//` **inside the string literal** and deletes to end
>   of line, so `src_calls` holds `string memory ref = "https:` and **the `.transfer(` is
>   gone**. 9a's multiset is unchanged, 9b sees nothing, 9c sees no `function` token, and
>   **check 14 accepts the assignment**, because `string memory ref` matches `D` — a form
>   r4 added to `D` so that control C-S would be admissible. All fifteen checks pass and the
>   line pays `amount` of an arbitrary token to an arbitrary address out of `fund`. This is
>   E-14's harm through a different door, and today's `scripts/no-keys.sh:29-30` is exactly
>   this two-pass shape.
> - **strings stripped first (the mirror).** `// memo: "note` on one line, the `.transfer(`
>   on the next, `string memory s = "x";` on the third: the string pass opens at the quote
>   **inside the comment** and closes at the quote before `x`, deleting the exit between
>   them.
>
> Neither is caught by anything round 4 had: M-0 is clean (the real file's only string is
> `"./RecknVerdictVerifier.sol"`, which contains `./` and not `//`), **C-P is a comment with
> no quote, C-S is quotes with no comment, and E-15/E-16 each stay inside one family.** The
> bug family for token-wise strippers is the **interaction**, and until r5 the corpus never
> crossed the two.

Corpus entries **E-15** and **E-16** are the same-family over-stripping controls,
**E-17** and **E-18** are the **cross-family** ones (a comment delimiter inside a string
literal; a string delimiter inside a comment) — required verdict for all four: **REJECTED**
— and control **C-S** is the under-stripping control (required verdict: **ACCEPTED**), so
the stripper cannot pass any of them by refusing all strings.

#### 4.5.2 The check table

| # | check | scope | status | enforces |
|---|---|---|---|---|
| 1 | forbidden privilege vocabulary | `body` | existing, unchanged | AC-0 |
| 2 | state-changing surface is enumerated | `body` | **strengthened, two-sided** (r2): all of `fund`, `settleWithProof`, `refundAfterDeadline` must be **present** as well as permitted | the keyless timeout cannot be silently deleted later |
| 3 | `require(/if( msg.sender` regex | `body` | existing, unchanged (kept in addition to check 7) | AC-0 |
| 4 | constructor stores no caller | `body` | existing, unchanged | AC-0 |
| 5 | **no base contracts** — the declaration line must match `^contract[[:space:]]+RecknZkEscrow[[:space:]]*\{` | `body` | r2 | inheritance reintroduces a role outside the scanned body |
| 6 | **no unenumerated entry point, escape hatch, or ETH surface** — must not contain `fallback`, `receive`, `assembly`, `tx.origin`, `.call(`, `.call{`, `staticcall`, `payable` | `body` | r2, **retained** | a `fallback()` is an entry point check 2's grep cannot see |
| 7 | **the caller and the execution context are closed per range** — **7a** (r2, unchanged): split `body` at `function ` boundaries; the ranges beginning `function settleWithProof` and `function refundAfterDeadline` must contain zero occurrences of `msg.sender`. **7b** (**new in r6**): the execution-context tokens are closed in every range — see §4.5.6a | `body`, per range | r2; **7b new in r6** | INV-1a, INV-2, **R-11** |
| 8 | **the constructor assigns only permitted immutables, from the parameters of the same name** — the left-hand side of every assignment inside the constructor body ∈ `{verifier, refundDelay}` (r2) **and its right-hand side is exactly the corresponding constructor parameter, once each** (**new in r6** — §4.5.6a) | `body` | r2; **RHS new in r6** | no stored authority; **R-11** |
| 9 | **closed call surface (property P)** — 9a member calls, 9b plain calls, **9c the `function` keyword** — see §4.5.3 | **`src_calls` (whole file)** | rewritten in r3; **9b range-restricted and 9c added in r4** | §3.1.2, P2, INV-2, INV-2b |
| 10 | **`fund`'s use of `msg.sender` is pinned** — exactly 3 occurrences inside `fund`'s range, matching once each: `buyer: msg.sender`, `emit Funded(dealId, msg.sender,`, `transferFrom(msg.sender,` | `body` | r2 | INV-1b |
| 11 | **the file's top-level declarations are closed** — see §4.5.4 | **`src_decl` (whole file)** | new in r3; region corrected in r4 | r2 finding 1 route B; removes C-4's dependence on the blind spot |
| 12 | **`IERC20Min`'s declared function set is closed** — see §4.5.5 | **`src_decl` (whole file)** | new in r3; region corrected in r4 | r2 finding 1 route A at the declaration site |
| 13 | **whole-file escape-hatch ban** — the file-wide superset of check 6: `assembly`, `delegatecall`, `staticcall`, `.call(`, `.call{`, `.send(`, `selfdestruct`, `payable`, `receive`, `fallback`, `tx.origin`, `{value:`, `ecrecover`, `create2`, `using` | **`src_calls` (whole file)** | **new in r3** | redundant backstop only — see the warning in §4.5.7 |
| 14 | **closed assignment targets** — see §4.5.6 | `body`, per function range | **new in r4** | r3 finding 2; P3, INV-2, **INV-2c** |
| 15 | **the second contract in the settlement path is closed** — 15a top-level declarations, 15b the `function` keyword, 15c `verifyVerdict`'s body, 15d assignment targets, 15e the non-function region, 15f the backstop, **15g the `constructor`** — see §4.5.10 | **`RecknVerdictVerifier.sol` (whole file)** | **introduced by task `008`; 15g and the extension are 003's — §1.5.4** | r4 finding 1, r5 finding 1; P4, P5, **G-39**, **G-40** |

The ranges checks 7, 9, 10 and 14 use, and the order in which the derived texts are built,
are defined once in **§4.5.1**. They are not restated here, because two statements of one
splitter is how r4 finding 8 happened.

**Two check series, and how they are spelled (new in r6 — r5 finding 6).** This document
contains **two** independently numbered series of checks and both reach 15, which is one
collision too many for a document that is read by an implementer:

> - **`scripts/no-keys.sh`** has **checks 1–15** (this table). They are written *check N*,
>   and the script is named at least once per section that mentions them.
> - **`scripts/gauntlet.sh --check`** has its own checks, renamed in r6 to **`GC-1` … `GC-18`**
>   (AC-13). They are never written *check N*.

The `GC-` prefix rather than `C-` is deliberate: `C-1…C-7` are this document's contract
changes (§4.1) and `C-P` / `C-S` / `C-V` / `C-M0` are the selftest controls (§5.2.1), so the
obvious prefix was already taken twice. **Appendices A–C keep the old spelling** — they are
round bookkeeping and are not rewritten; a reference of the form *"AC-13 check N"* inside them
is the historical spelling of `GC-N`.

#### 4.5.3 Check 9 — closed call surface

Over `src_calls`, a **call-shaped token** is any match of

```
(\.[[:space:]]*)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\{[^}]*\})?[[:space:]]*\(
```

Every match is classified by whether it begins with `.`:

**(9a) Member calls** — matches beginning with `.`. The multiset of names must be
**exactly**:

| name | count | where | pinned form |
|---|---|---|---|
| `transferFrom` | 1 | `fund`'s range | `transferFrom\(msg\.sender, *address\(this\), *amount\)` |
| `transfer` | 2 | 1 in `settleWithProof`'s range, 1 in `refundAfterDeadline`'s range, **0 elsewhere** | `\.transfer\(to, *d\.amount\)` and `\.transfer\(d\.buyer, *d\.amount\)` |
| `balanceOf` | 6 | 2 in each of the three function ranges (before/after each token call) | `\.balanceOf\(address\(this\)\)` |
| `verifyVerdict` | 1 | `settleWithProof`'s range | `verifier\.verifyVerdict\(publicValues, *proofBytes\)` |

**Any member-call name that is not one of those four fails**, with the script printing the
offending name and line. The counts, ranges and argument forms are all pinned; a permitted
name in a wrong place, a wrong count, or a wrong argument shape fails too.

**(9b) Plain calls** — matches not beginning with `.`. Every name must be in the fixed
allowlist `L_plain`, held literally in `scripts/no-keys.sh`:

- *language*: `if` `else` `for` `while` `do` `return` `returns` `revert` `require` `assert`
  `emit` `try` `catch` `new` `constructor` `modifier` `mapping` `enum` `struct`
  `event` `error` `interface` `contract` `pragma` `import` `type` `unchecked`
- *declarators that can precede a paren*: `external` `internal` `public` `private` `view`
  `pure` `memory` `calldata` `storage` `indexed` `immutable` `constant` `override`
  `virtual` `is`
- *types and casts used by this file*: `address` `bool` `bytes` `bytes32` `uint8` `uint64`
  `uint256` `IERC20Min` `RecknVerdictVerifier` `VerdictPublicValues` `Deal` `State`
- *declared functions and members*: `fund` `settleWithProof` `refundAfterDeadline`
  `transfer` `transferFrom` `balanceOf` `verifyVerdict` `deals`
- *declared errors*: `DealExists` `BadState` `ZeroBinding` `BindingMismatch` `BadOutcome`
  `DeadlineNotReached` `UnderFunded` `PayoutFailed` `BadRefundDelay`
- *declared events*: `Funded` `SettledByProof` `RefundedAfterDeadline`

Any plain-call name outside `L_plain` fails, printing the name and line.

**(9b-range) The four token names are permitted as plain calls only where they are
declared (new in r4 — r3 finding 1).** `transfer`, `transferFrom`, `balanceOf` and
`verifyVerdict` are in `L_plain` **only** because check 12 pins three `IERC20Min`
declaration lines whose own text produces the plain-call tokens `transferFrom(`,
`transfer(` and `balanceOf(`. That admission is not a licence to call them by those names
anywhere: a plain call with one of those four names is permitted **only inside
`IERC20Min`'s declaration range** (checks 11 and 12's region) and is a **failure anywhere
else** — the same "0 elsewhere" shape 9a already uses for `transfer`. Without this clause,
naming a function-type local `transfer` makes the drain of E-14 pass 9b **by the same name
the interface is required to declare**.

**(9c) The `function` keyword is closed (new in r4 — r3 finding 1, property P2).** Over
`src_calls`, the number of `\bfunction\b` occurrences is exactly **six**, and each is
followed — after optional whitespace — by one of exactly six declared names:
`transferFrom`, `transfer`, `balanceOf` (check 12's three interface signatures) and `fund`,
`settleWithProof`, `refundAfterDeadline` (check 2's three contract declarations). Anything
else fails, printing the occurrence and line.

This is what makes a **callable** something that cannot be created rather than something
that must be named to be forbidden. It kills, together and for one reason: a function-type
local (`function(address,uint256) external returns (bool) x = …`), a function-type
parameter, a function-type return, a function-type mapping value, a file-level function, an
added `internal` helper, and an added `view` helper (N-3). It also closes a real gap in
check 2, which greps `function +[a-zA-Z_]` — **one or more spaces**
(`scripts/no-keys.sh:46`) — and therefore cannot see `function(address,` at all.

**Why (9b) and (9c) matter and are not decoration.** They close the routes an allowlist
over *member* calls alone leaves open:

- a **function-type variable**: `function(address,uint256) external returns (bool) f =
  IERC20Min(token).transfer; f(seller, amount);` — the assignment has no `(` after
  `transfer`, so (9a) never sees it. Round 3 rejected this by `f` not being in `L_plain`,
  **which only worked because the author happened to name it `f`**; renaming the local to
  `transfer` defeated that reasoning entirely (r3 finding 1). Under r4 the name is
  irrelevant: **9c** rejects the `function` token, **9b-range** rejects the call
  `transfer(` outside the interface range, and **check 14** rejects the assignment's
  left-hand side. Three independent rejections, none of them a name;
- **inline assembly**: `assembly { pop(call(gas(), t, 0, 0, 0, 0, 0)) }` — assembly emits
  no member call, but `pop(`, `call(`, `gas(` are all plain calls outside `L_plain`.

#### 4.5.4 Check 11 — the file's top-level declarations are closed

Over `src_decl` (comments stripped, **string literals kept**, newlines kept — §4.5.1), the
lines whose **first non-blank character is at column 0** and which match
`^(pragma|import|using|library|abstract|interface|contract|function|struct|enum|error|event|type|constructor|modifier)\b`
must be exactly these four, in this order (whitespace-normalized, compared as full lines):

```
pragma solidity ^0.8.20;
import {RecknVerdictVerifier, VerdictPublicValues} from "./RecknVerdictVerifier.sol";
interface IERC20Min {
contract RecknZkEscrow {
```

**The `import` path is pinned here**, in the only text that still contains it: reading this
check over a string-stripped text would compare against
`import {RecknVerdictVerifier, VerdictPublicValues} from ;` and could never match the real
file (r3 finding 5). A `library`, a second `interface`, a second `import`, a file-level
`function`, a `using … for`, an `abstract contract`, or any other top-level declaration
fails, printing the line. This is r2 finding 1 route B, closed **structurally** rather than by extending a
count, and it is what makes "the whole file" a well-defined region.

#### 4.5.5 Check 12 — `IERC20Min`'s declared function set is closed

Over `src_decl`, the lines between `^interface IERC20Min {` and the next line that is
exactly `}` at column 0 must contain exactly three `function` declarations,
whitespace-normalized equal to:

```
function transferFrom(address from, address to, uint256 value) external returns (bool);
function transfer(address to, uint256 value) external returns (bool);
function balanceOf(address account) external view returns (uint256);
```

**The interface's function set is a build condition.** `approve`, `increaseAllowance`,
`decreaseAllowance`, `permit`, `transferAndCall` and everything else cannot be *declared*,
so they cannot be *called* through this interface — independently of check 9. This is the
third of the three independent rejections of r2's route A, and it is the one the founder
asked to be considered explicitly.

#### 4.5.6 Check 14 — closed assignment targets (new in r4 — r3 finding 2)

**The seam this closes.** Checks 9/11/12/13 are checks on **calls**. The line
`deals[dealBinding].seller = seller;`, spliced anywhere into `fund`, contains **no
call-shaped token at all** — `deals[` is followed by `[`, `.seller` by ` =` — so no call
check can see it, and neither can checks 1–8 or 10 (no new function, no new declaration, no
`msg.sender`, no forbidden token, interface unchanged). With it in place,
`fund(freshId, attacker, anyToken, 0, victimDealId)` costs **zero tokens** and makes an
honest `Reproduced` proof pay the attacker instead of the seller. Check 14 is the property
that makes it and its unlisted siblings fail together.

**Storage-writing constructs, enumerated (this is what makes "closed" mean something).**
In Solidity source, a state variable of this contract can be written only by: an
assignment `=`; a compound assignment (`+= -= *= /= %= |= &= ^= <<= >>=`); an increment or
decrement (`++`, `--`); `delete`; or `sstore` inside `assembly`. The last is already dead
twice over (checks 6 and 13 ban `assembly`; `sstore(` is a plain call outside `L_plain`).
Check 14 closes the other four.

**Definition.** Over `body`, split into the constructor range and the three function ranges
by the same splitter checks 7, 9 and 10 use:

- **(14a)** The tokens `++`, `--`, `delete` and every compound assignment operator must not
  occur in any range. (They occur nowhere in the real file; this is a closure, not a fix.)

  **What 14a's enumeration does not have to carry, recorded so the prose is not read as
  wider than the coverage (r4, "checked and found sound").** `push` and `pop` on a dynamic
  array are **member calls**, rejected by 9a's closed multiset, not by 14a. A `Deal storage`
  reference passed to a helper needs a **second function**, rejected by 9c and check 2.
  `tstore` writes transient storage, which is not state. 14a's four constructs are the ones
  that write this contract's storage **without a call and without a new function**; the
  others are closed elsewhere, and this sentence says which.
- **(14b)** An **assignment site** is a single `=` that is not part of `==`, `!=`, `<=`,
  `>=`, `=>` or a compound operator. Its **left-hand side** is the whitespace-normalized
  text from the preceding `;`, `{`, `}` or `(` up to the `=`.
- **(14c)** Every assignment site's left-hand side must be in **that range's** fixed set:

| range | permitted left-hand sides | pinned counts |
|---|---|---|
| `constructor` | `verifier`, `refundDelay` | check 8, unchanged |
| `fund` | `deals[dealId]`; a **local declaration** `D`; a **bare local** `L` | `deals[dealId]` exactly **1**; **0** occurrences of `d.` anything, `deals[` anything else, `Deal storage` anything |
| `settleWithProof` | `Deal storage d` — only as the whole-statement form `Deal storage d = deals[dealId]`; `VerdictPublicValues memory v`; `d.state`; `D`; `L` | `Deal storage d` exactly **1**; `d.state` exactly **1** |
| `refundAfterDeadline` | `Deal storage d` — same pinned whole-statement form; `d.state`; `D`; `L` | `Deal storage d` exactly **1**; `d.state` exactly **1** |

where

- **`D` (local declaration)** matches
  `^(uint8|uint64|uint256|address|bool|bytes32|string memory|bytes memory) [A-Za-z_][A-Za-z0-9_]*$`
  — a value type or a memory type, which cannot name storage. `string memory` and
  `bytes memory` are present so that control **C-S** (§5.2.1) is admissible; they add no
  storage reach.
- **`L` (bare local)** is a single identifier for which the **same range** contains a
  declaration matching `D` for that name. `to = d.seller;` is permitted in
  `settleWithProof` because `address to;` is declared there; the same assignment in
  `fund` fails, because `to` is not declared in `fund`.

**Anything else fails, printing the left-hand side and the line.** In particular:
`deals[dealBinding]`, `deals[victimId]`, `deals[k]` for any `k` that is not the literal
token `dealId`, `deals[dealId].seller`, `d.seller`, `d.buyer`, `d.amount`, `d.token`,
`d.dealBinding`, `d.fundedAt`, a second `Deal storage` binding, a `Deal storage` bound to
anything but `deals[dealId]`, and a function-type local declaration (whose left-hand side
begins `function(`, matching neither `D` nor `L` — the third independent rejection of
E-14).

**What check 14 is not.** It is lexical, like every other check here (N-10). It constrains
the **source text** of one file; it is not a proof about the compiled bytecode, and it does
not say the assignments it permits are *correct* — `d.state = State.Settled` could be
written in the wrong branch and check 14 would not notice. That is what INV-2c's two
behavioural instruments are for, and §8 says so.

#### 4.5.6a Check 7b and check 8's right-hand sides — the execution context is closed (new in r6 — r5 finding 1)

**The seam this closes.** Every instrument in this document runs on a **local chain**
(`AGENTS.md` §5's tier discipline is the reason that is stated everywhere). An implementation
that reads `block.chainid` can therefore be honest exactly where it is observed and dishonest
everywhere else — §3.1.4's constructor splice is the version that survived round 5, and it is
not the only place the token could go. **The fix is not "also forbid `block.chainid`"** (R-7,
and it would be r2's mistake a third time); it is to close the *category*: **the two checked
files may read exactly one execution-context value, `block.timestamp`, in exactly the two
places C-2 and C-3 need it.**

> **P6 — closed execution context.** In `RecknZkEscrow.sol` the only permitted
> execution-context reads are `msg.sender` (pinned to three occurrences in `fund` by check 10,
> forbidden in the two exits by 7a) and `block.timestamp` (at most one occurrence in `fund`'s
> range and at most one in `refundAfterDeadline`'s range, zero elsewhere). Every other token
> that lets the code learn *where or when it is running* is absent. In
> `RecknVerdictVerifier.sol` there is no permitted execution-context read at all (15c-iii,
> 15g, 15e).

**(7b) Definition.** Over `body`, split into the constructor range and the three function
ranges by the same splitter checks 7a, 9, 10 and 14 use:

- `block.timestamp` occurs **at most once** in `fund`'s range and **at most once** in
  `refundAfterDeadline`'s range, **zero** times in `settleWithProof`'s range, **zero** times in
  the constructor range, and **zero** times anywhere in `body` outside those four ranges — the
  last clause is there because R-11(ii) forbids leaving a region unpinned, and the region
  outside the four ranges is where a state-variable initializer would live;
- the tokens `block.chainid`, `chainid`, `block.number`, `block.difficulty`, `block.prevrandao`,
  `block.coinbase`, `block.basefee`, `block.gaslimit`, `blockhash`, `gasleft`, `msg.value`,
  `msg.data`, `msg.sig`, and **any `tx.`** occur **zero** times in the whole of `body`;
- any `block.` occurrence that is not `block.timestamp` fails **as a class**, so a member of
  this family added by a future Solidity version fails without being named here.

Anything else fails, printing the token, the range and the line. **The enumeration above is a
convenience for the error message; the gate is the class rule in the third clause.**
`tx.origin` was already dead at checks 6 and 13 — 7b widens it to all of `tx.` and states the
property those two denylist entries were standing in for.

**(check 8, right-hand sides.)** Check 8 pinned the left-hand side of every constructor
assignment to `{verifier, refundDelay}` and said nothing about what was assigned. It now also
requires, over the constructor range:

- exactly one assignment with left-hand side `verifier`, whose whitespace-normalized
  right-hand side is exactly `_verifier`;
- exactly one assignment with left-hand side `refundDelay`, whose right-hand side is exactly
  `_refundDelay`;
- **zero** occurrences of `0x` in the range (no address or byte literal can be assigned or
  compared), on top of 7b's ban on `block.` / `chainid` / `tx.` there.

`if (_refundDelay < MIN_REFUND_DELAY || _refundDelay > MAX_REFUND_DELAY) revert
BadRefundDelay();` (C-2) contains no assignment and no banned token, so it is unaffected —
which is why check 8's constructor pin is stated as *"every assignment"* and not as
*"exactly two statements"* the way 15g's is. The two constructors differ in that one has a
guard and the other does not, and the pins differ in exactly that way.

**Both halves are witnessed, and the one remaining asymmetry is named (R-10(i)).** The
verifier's constructor is witnessed by corpus entry **E-20** and source-text mutant **M-57**;
the escrow's constructor is witnessed by corpus entry **E-23** (rejected twice over, by 7b and
by check 8's right-hand-side clause), and AC-1's *minimal E* falsifier deletes exactly those
two clauses and observes E-23 survive. **E-23 has no kill-table id**, and that is deliberate:
M-57 already carries this construct's family in the kill table, and the escrow's version is
additionally detectable **off-chain** — the escrow's `verifier` is `public immutable` and
**part 2 of the deployment check reads exactly that value on-chain** (§2.3 A), so a seller
performing the check sees a rogue address on the chain the escrow is deployed to. The
verifier's own `verifier` had no such reader at all until part 5 was added in this same round.
That is an asymmetry in *detectability*, not in whether the clause exists — the clause exists
on both files.

**What 7b does not close, and it is the reason OQ-10 exists.** 7b removes the *environment* as
a branch condition. It does not remove a **constant** as one: `if (token == <a mainnet token
address>) { to = <constant>; }` inside `settleWithProof` reads no execution-context token,
produces no call-shaped token, and has the permitted left-hand side `to` (check 14 pins
left-hand sides only — INV-2's *"Named limit, corrected in r6"*). A fuzz cannot draw the
constant (R-5) and the gauntlet's tokens are mocks, so nothing here is red. **Closing it means
pinning right-hand sides in check 14, which is new mechanism design and is therefore OQ-10**,
not a round-6 edit (`AGENTS.md` §7).

#### 4.5.7 Which check rejects what, and which of them carry the claim

**Warning, so this is not misread as another name list.** Check 13 is a **denylist and a
backstop only**. If check 13 were deleted, every construct in the table below would still
be rejected by checks 9, 11, 12 or 14. The claim rests on the allowlists (9, 11, 12, 14); 13 exists
because a redundant fast rejection with a clear message is cheap, and because it keeps
check 6's existing wording meaningful at file scope.

| construct an attacker would add | primary rejection (a property) | also rejected by |
|---|---|---|
| `IERC20Min(t).approve(x, y)` | **12** (cannot be declared) and **9a** (member name not in the allowlist) | — |
| `IERC20Min(t).increaseAllowance(x, y)` | **12**, **9a** | — |
| `IERC20Min(t).permit(…)` | **12**, **9a** | — |
| a new `interface IERC20Full { function approve(…) … }` + a call to it | **11** (top-level declarations closed), **9a** | — |
| `library Sweep { … }` above the contract + `Sweep.pull(…)` | **11**, **9a** (`.pull`), **9a** (`.transfer` count becomes 3) | 13 (`using`, if used) |
| a file-level `function _sweep(…) { … }` + a call to it | **11**, **9b** (`_sweep` not in `L_plain`) | — |
| `SafeERC20.safeTransfer` / `Address.functionCall` (an import) | **11** (second `import` line), **9a** | 13 (`using`) |
| `(bool s,) = t.call(abi.encodeWithSelector(0xa9059cbb, …))` | **9a** (`.call`, `.encodeWithSelector`) | 13 |
| `t.delegatecall(…)` / `t.staticcall(…)` | **9a** | 1 (`delegatecall`), 6, 13 |
| `payable(x).transfer(address(this).balance)` | **9a** (`.transfer` count and pinned argument form) | 6, 13 (`payable`) |
| `new Drain{value: 0}(t)` | **9b** (`Drain` not in `L_plain`) | 13 (`{value:`) |
| `assembly { pop(call(gas(), …)) }` | **9b** (`pop`, `call`, `gas` not in `L_plain`) | 6, 13 (`assembly`) |
| `function(address,uint256) external returns (bool) f = IERC20Min(t).transfer; f(x, y);` | **9c** (the `function` token is not one of the six pinned declarations) | 9b (`f` not in `L_plain`), 14 (the LHS matches neither `D` nor `L`) |
| the same, with the local **named `transfer`** so that 9b's allowlist admits it (r3 finding 1) | **9c** — the rejection does not depend on the name | 9b-range (`transfer(` outside `IERC20Min`'s range), 14 |
| `deals[victimId].seller = attacker;` inside `fund` — **no call-shaped token at all** (r3 finding 2) | **14** (`deals[victimId].seller` is not a permitted left-hand side in `fund`) | nothing else — 9a/9b/9c never see this line, and that is the point |
| `delete deals[id];` / `d.amount -= x;` / `d.state++;` | **14a** (the constructs are closed, not the identifiers) | — |
| `selfdestruct(payable(x))` | **9b** (`selfdestruct` not in `L_plain`) | 1, 13 |
| `if (block.chainid == 31337) { verifier = _verifier; } else { verifier = <constant>; }` in the **constructor** (r5 finding 1) | **check 8** (the right-hand side is not the corresponding parameter; and `block.` is not permitted in the constructor range) — and **15g** for the same splice in `RecknVerdictVerifier.sol`, which is where it actually mattered | **7b** (the token, as a class). Nothing else: no call-shaped token, no new declaration, and the left-hand side is permitted |
| `if (block.chainid != 31337) { to = <constant>; }` inside `settleWithProof` | **7b** (`block.chainid` cannot occur in that range) | **nothing else — and this row is honest about it:** 9a/9b/9c see no new call, and **check 14 permits the left-hand side `to`**. Remove 7b and the constant-keyed variant of this line is OQ-10 |
| **a construct not in this table** | **9a** or **9b**, because the allowlists are closed over the syntactic category, not over the vocabulary | — |

**A `modifier` is closed too, and it is worth one sentence** because the table does not
show it: `modifier onlyX() {` yields the plain-call token `onlyX(`, which 9b rejects, and
its `modifier` keyword is not `function`, so it also cannot re-enter through 9c.

**The last row is the whole point of the rewrite, and it is also the honest limit:** the
call allowlists cover any construct that produces a call-shaped token, and check 14 covers
the storage-writing constructs that produce none. §8 names what remains outside — the fact
that all of it is lexical rather than a property of the compiled bytecode, and the fact
that a permitted assignment can still be *wrong* (checked behaviourally by INV-2c's
instruments, not here).

#### 4.5.8 The one additive output line

Immediately *before* the existing final success line (which stays byte-identical), the
script prints:

```
checks: 15/15 passed
```

This exists so AC-0 cannot be satisfied by a script that ran nothing. It adds a line; it
changes no existing line, no argument, no target, and no exit code. **The number is 15 and
not 14 because of check 15 (§4.5.10); the count is the script's own, and AC-0's manifest
evidence string is compared against it verbatim, so a check that is written but never run
changes the printed number and fails AC-0.** **15 is still the number after round 6 and after
003 extends whatever 008 left**: 15g is a *sub-check* of 15, 7b of 7, and check 8's
right-hand-side clause is a clause — none of them is a new check. If the base measurement
shows a check count this table does not enumerate, that is §1.5.4's third case: **stop and
return to the founder**, because this string is compared verbatim and folding an unspecified
check into it privately is the act §1.5 exists to prevent.

#### 4.5.9 Self-testing without a target argument (N-9, r1 finding 12)

`no-keys-selftest.sh` reconstructs the *layout* the script expects in a temp directory —
`$T/scripts/no-keys.sh`, `$T/zk-verdict/contracts/src/RecknZkEscrow.sol` **and, new in r5,
`$T/zk-verdict/contracts/src/RecknVerdictVerifier.sol`** — because the script derives both
of its targets from its own location (`scripts/no-keys.sh:17-19`). Verified working on
2026-09-04 for the one-file layout: a clean copy exits 0 in the sandbox, and a mutated copy
is judged by the same code path. **No argument, no environment variable, no default
change.** **The sandbox must contain both files even when the mutant touches only one**, or
check 15 fails on a missing target and every mutant is "rejected" for the wrong reason —
which M-0 detects, because M-0 must be **accepted**.

It runs three things (AC-1):

1. the **20 source-text mutants** of §5.3, each rejected, each by a **named** check;
2. the **exit corpus** of §5.2.1 — 23 constructs spliced into the real files, each rejected,
   each by a named check — which is the *witness* that properties P, P2, P3, P4, P5 and P6
   cover the family, **not** the definition of the properties;
3. **four controls**, all of which must be **accepted**: the unmodified copy (**M-0**, both
   files); the **prose control** **C-P** — the comment `// never call approve(), permit(),
   or .call{value:}()` spliced into `fund` — proving the checks read code and not text; the
   **string control** **C-S** — `string memory sA = "a"; string memory sB = "b";` spliced
   into `fund`, two legitimate string literals on one line with no call between them —
   proving the stripper does not pass E-15…E-18 by refusing all strings (§4.5.1); and the
   **verifier prose control** **C-V** — the comment
   `// no msg.sender branch here; see check 15` spliced into `verifyVerdict` — proving check
   15's body pin reads stripped code rather than grepping English.

#### 4.5.10 Check 15 — the second contract in the settlement path is closed (designed in r5 — r4 finding 1; **owned by task `008`, extended by 003 — §1.5.4**)

**Attribution first, because it decides who writes which line (orchestrator ruling,
2026-09-04).** `008` edits `RecknVerdictVerifier.sol` and runs first, so **008 introduces this
check**; 003 **extends** it with **15g**, the five-part deployment check, and E-20 / M-57 /
G-40, and 003 **introduces it in full if 008 landed without it**. Which case holds is read off
`docs/gauntlet.base.json.no_keys`, not assumed — §1.5.4. Everything below is the specification
of the post-003 check, and it is the same specification in either case.

**The seam this closes.** §3.1.4. `settleWithProof` obeys a struct computed in
`zk-verdict/contracts/src/RecknVerdictVerifier.sol`, and until r5 no check, no mutant, no
corpus entry and no column of this document ever read that file. Check 15 gives it the same
treatment checks 11 / 12 / 9c / 14 give the escrow: **not a list of forbidden constructs,
but a closed region** (R-7). Two properties:

> **P4 — closed callables in the verifier.** The file declares exactly **one** function,
> `verifyVerdict`, and exactly **four** top-level declarations. Nothing else in the file can
> be called, and nothing new can become callable, whatever it is named.
>
> **P5 — the verdict is a function of its arguments alone, and the callee is a function of
> the constructor's arguments alone** *(the second half is new in r6 — r5 finding 1)*.
> `verifyVerdict`'s body is two statements: verify, then decode. It contains **no control flow
> and no execution-context token at all** — no `if`, no `return`, no `msg.sender`, no
> `tx.origin`, no `block.`. A returned struct field can therefore be produced only by
> `abi.decode(publicValues, …)` after `ISP1Verifier.verifyProof` did not revert. **And the
> address `verifyProof` is dispatched to is the constructor's `_verifier` parameter on every
> chain**: the constructor is two statements, each assigning one immutable from the parameter
> of the same name, with no branch, no execution-context token and no literal in it (15g).
>
> **Round 5 wrote the first half and then a sentence the first half does not carry:** *"there
> is no branch for a constant address to live in."* There was one — in the `constructor`,
> which 15d constrained by left-hand side only and which 15e excluded by construction
> (§3.1.4). That sentence is true **as of 15g** and false without it, so it is stated here as
> a conjunction: delete either half and it is visibly false.

**Region.** The whole file, comments and string literals stripped by the same one-pass
stripper as §4.5.1 (call this text `vrf`), plus the line-preserving variant for the
line-comparing sub-checks (`vrf_decl`). Sub-check by sub-check:

- **(15a) top-level declarations are closed.** Over `vrf_decl`, the lines whose first
  non-blank character is at column 0 and which match
  `^(pragma|import|using|library|abstract|interface|contract|function|struct|enum|error|event|type|constructor|modifier)\b`
  must be exactly these four, in this order, whitespace-normalized, compared as full lines:

  ```
  pragma solidity ^0.8.20;
  import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";
  struct VerdictPublicValues {
  contract RecknVerdictVerifier {
  ```

  A second `import`, a `library`, a `using … for`, a second `interface` or a file-level
  `function` all fail, printing the line. Same construction as check 11; **the import path
  is pinned here, in `vrf_decl`, the only text that still contains it** (r3 finding 5's
  lesson, applied to the second file rather than re-learned on it).
- **(15b) the `function` keyword is closed.** Over `vrf`, `\bfunction\b` occurs **exactly
  once**, followed after optional whitespace by `verifyVerdict`. A function-type variable,
  parameter, return or mapping value, a second function, an `internal` helper and a `view`
  helper cease to exist together, whatever they are named. Same construction as 9c.
- **(15c) `verifyVerdict`'s body is closed.** Let the body be the text between the `{` that
  opens `verifyVerdict` and its matching close. Three conditions, all required:
  - **(15c-i)** it contains exactly **two** statements (exactly two top-level `;`);
  - **(15c-ii)** the first is a member call named `verifyProof`, whose receiver is a cast of
    the immutable `verifier` and whose arguments are, in order, `verdictProgramVKey`,
    `publicValues`, `proofBytes`; the second is an assignment whose left-hand side is the
    whole of the declared return value `v` and whose right-hand side is a member call named
    `decode` taking `publicValues` and the type `(VerdictPublicValues)`;
  - **(15c-iii)** it contains **zero** occurrences of each of `if`, `else`, `for`, `while`,
    `do`, `return`, `revert`, `require`, `assert`, `try`, `catch`, `?`, `&&`, `||`,
    `msg.sender`, `tx.origin`, `block.`, `tx.`.

  **The splice of §3.1.4 fails 15c three times over** — a third statement (15c-i); an `if`,
  a `return` and a `msg.sender` (15c-iii); and two assignments whose left-hand sides are
  `v.outcome` and `v.dealBinding` (15d). None of those rejections depends on the address, on
  the field names, or on anyone having thought of that construct. A backdoor keyed on
  something other than the caller — `if (publicValues.length == 1337) { … }`, which is not a
  key at all but a proof-free settlement path for everyone — fails 15c-i and 15c-iii for the
  same reasons.
- **(15d) assignment targets are closed, file-wide.** Using check 14's left-hand-side
  extraction rule (14b), every assignment site in the file must have one of exactly these
  whitespace-normalized left-hand sides:

  ```
  uint8 public constant REPRODUCED
  uint8 public constant FAILED
  address public immutable verifier
  bytes32 public immutable verdictProgramVKey
  verifier                       (constructor range only)
  verdictProgramVKey             (constructor range only)
  v                              (verifyVerdict range only)
  ```

  and the tokens `++`, `--`, `delete` and every compound assignment operator must not occur
  anywhere in the file. `v.outcome`, `v.dealBinding`, a new state variable **with** an
  initializer, and a constructor that stores anything else all fail.
- **(15e) the non-function region is a pinned line set.** Over `vrf_decl`, the non-blank
  lines inside `contract RecknVerdictVerifier` that lie **outside** the `constructor` and
  `verifyVerdict` ranges must be exactly the four declaration lines named in 15d's first
  block, plus the contract's own braces. This is what stops a **new state variable with no
  initializer** — which 15d cannot see, because it is not an assignment — from being
  declared at all. **Its region is stated by exclusion, and R-11 makes that admissible only
  because each excluded region now has its own pin**: the `verifyVerdict` range is pinned by
  15c and the `constructor` range by **15g**. Until 15g existed the exclusion was a hole, and
  §3.1.4's splice lived in it. **The struct's field lines are deliberately not pinned**: task `008`
  changes their widths, a struct field cannot hold code, and pinning them would put a
  008-coupled literal back into this document (§1.5).
- **(15g) the `constructor` is closed (new in r6 — r5 finding 1).** The constructor range is
  located by §4.5.1's constructor rule; **a file with no locatable constructor fails 15g**,
  printing the file and the pattern — an unlocatable range is never treated as clean
  (§4.5.1). Four conditions, all required:
  - **(15g-i)** the parameter list is, whitespace-normalized, exactly
    `(address _verifier, bytes32 _verdictProgramVKey)`;
  - **(15g-ii)** the body contains exactly **two** statements (exactly two top-level `;`);
  - **(15g-iii)** those two statements are, whitespace-normalized and in this order,
    `verifier = _verifier` and `verdictProgramVKey = _verdictProgramVKey` — **each right-hand
    side is the parameter of the same name and nothing else.** This is the clause round 5 did
    not have: 15d enumerated the two left-hand sides and never looked to the right of the `=`;
  - **(15g-iv)** the range contains **zero** occurrences of each of `if`, `else`, `for`,
    `while`, `do`, `return`, `require`, `assert`, `try`, `catch`, `?`, `&&`, `||`, `block.`,
    `chainid`, `tx.`, `msg.`, `assembly` — and **zero occurrences of `0x`**, so no branch, no
    execution-context read and no literal address can occur there at all.

  **The splice of §3.1.4 fails 15g four times over** — a third top-level `;` (15g-ii),
  right-hand sides that are not the parameters (15g-iii), and the tokens `if` / `else` /
  `block.` / `0x` (15g-iv). The **unconditional** variant (`verifier =
  address(0x…1337);` with no branch, which today's local suite already kills because that
  address has no code on a fresh anvil) fails 15g-iii and 15g-iv, so it is now rejected
  **structurally as well as behaviourally** — and the structural rejection is the one that
  survives being run on a chain where that address does have code. **None of these rejections
  depends on the address, on the chain id, or on anyone having thought of that construct:**
  what is pinned is that the constructor is a copy of its own parameters.
- **(15f) whole-file backstop — a denylist, and it carries none of the claim.** `vrf` must
  contain none of `assembly`, `delegatecall`, `staticcall`, `.call(`, `.call{`, `.send(`,
  `selfdestruct`, `payable`, `receive`, `fallback`, `using`, `ecrecover`, `create2`,
  `{value:`, `msg.sender`, `tx.origin`. **If 15f were deleted, every construct above would
  still be rejected by 15a–15e and 15g.** It exists for the same reason check 13 does: a redundant
  fast rejection with a clear message is cheap. Read it as a backstop, not as the property —
  §4.5.7's warning applies here word for word.

**Why check 15 is 008-stable, checked rather than hoped (§1.5).** 008 changes
`VerdictPublicValues`'s field **widths** and nothing else in this file. Widths appear only
in the struct's field lines, which 15a does not compare (it compares the `struct …{` header
line) and which 15e explicitly excludes. The four top-level lines, the single `function`
token, the two body statements, the seven assignment targets **and the constructor 15g pins**
are all untouched by 008 — that constructor takes an `address` and a `bytes32`, and neither is
one of the four numeric fields 008 moves.
**The two body statements and the constructor are additionally recorded as measured
evidence** in `docs/gauntlet.base.json.verifier_body` and `…verifier_constructor` at the base
commit (§1.5.1), so that if a later task does change them, the difference between the recorded
text and the pinned form is visible rather than inferred.

**If check 15 ever has to be relaxed, that is a claim change, not a fix.** Widening 15a's
four lines, 15b's single `function`, 15c's two statements or **15g's two constructor
statements** means the settlement path grew.
`AGENTS.md` §0 makes that a declared change in the same commit (**D-12**), exactly as for
`RecknZkEscrow`'s three functions. The implementer does not do it silently, and *"the
compiler needed it"* is not a reason — it is a founder call (`AGENTS.md` §7).

**What check 15 does not establish**, stated here and again in §8:

- **nothing about the deployed verifier's bytecode.** Check 15 is lexical, over the source
  in this repository. An escrow can be constructed with **any** address (G-29), and a rogue
  verifier deployed from different source is unaffected by every check in this document.
  That is what parts 2 and **5** of the seller's deployment check are for (§2.3 A), and both
  are human/off-chain steps, not mechanisms.
- **nothing about which address a *deployment* passed to the constructor.** 15g pins that the
  source assigns `verifier` from `_verifier`; it says nothing about the value the deployer
  supplied. That value is read on-chain by **part 5** (new in r6), and part 5's own limit is
  stated where it is defined (§2.3 A): it compares an address, not a bytecode, and on this
  document's tier the comparand is the SP1 verifier the demo itself deployed.
- **nothing about `ISP1Verifier`.** The SP1 verifier the file calls into is outside both
  checked files and outside this repository. §8 already names its soundness as outside the
  frame; check 15 does not narrow that.
- **nothing about what the proof means.** That is the guest's, frozen here by N-2 and owned
  by task `008`.

---

## 5. Acceptance criteria

### 5.0 The AC format (introduced in r2 — r1 findings 1, 2, 9)

**Round 1's format was false.** It said "every AC is a command whose exit status decides
it" and then used `forge test --match-test <pattern>`, which **exits 0 when the pattern
matches nothing**. Re-measured on forge 1.7.1, 2026-09-04, and independently re-measured by
r2 on the same version:

```sh
forge test --root zk-verdict/contracts --match-test "testFuzz_AC02_does_not_exist"; echo $?
# No tests found in project! ...
# 0
forge test --root zk-verdict/contracts --json --match-test "zzz" | jq . ; echo $?
# parse error: Invalid numeric literal at line 1, column 3
# 4          <- the no-match output is not even JSON
forge test --root zk-verdict/contracts --list --json --match-test "zzz"
# {}
```

Eleven of round 1's eighteen ACs went green against an implementation in which the test
files were never created. Every AC is now:

```sh
bash scripts/ac.sh AC-NN     # exit 0
```

`scripts/ac.sh` is a dispatcher. Its manifest is §5.1 of *this file* — it parses the fenced
`ac-manifest` block below; there is no second copy to drift from. For a **`forge`** AC it
performs, in this order, and fails at the first step that does not hold:

1. **Parse gate.** `forge test --root zk-verdict/contracts --list --json --match-test
   "<selector>"` must produce **valid JSON**. (`forge`'s no-match message on a *run* is
   plain text and fails this gate outright; on `--list` it is `{}` and fails step 2.)
2. **Existence and count gate — before a single test is executed.**
   `found := [.[][][]]`. The AC **fails unless `|found| == N`**, where `N` is the manifest's
   declared exact count for this AC. `ac.sh` **refuses any manifest entry with `N < 1`**
   and exits non-zero on it — a hard floor in the script, not a convention.
3. **Naming gate.** Every name in `found` must match
   `^(test|testFuzz|invariant)_AC<NN>_(G[0-9]{2}_)+[a-z0-9_]+$`. (`forge test --list --json`
   enumerates `invariant_*` functions and `--match-test` matches them — verified on forge
   1.7.1, 2026-09-04, and re-verified by r2.)
4. **Row-coverage gate.** The set of `G-NN` ids appearing in `found`'s names must be a
   superset of the manifest's `rows` column for this AC, and every id must exist in §3.2.
5. **Run gate.** `forge test --root zk-verdict/contracts --json --match-test "<selector>"`
   must produce valid JSON; let `ran` be every entry of every suite's `test_results`, with
   `(…)` stripped from the keys. The AC fails unless `set(ran) == set(found)`,
   `|ran| == N`, and **every** `status == "Success"`.
6. On success it prints `AC-NN: N/N tests, all passed`.

**Why "0 matches" can no longer be green:** the pass condition is an *equality against a
declared `N ≥ 1`*, checked twice (list and run) and cross-checked for name-set identity.
An empty match yields `0 ≠ N` at step 2, and a run that executes nothing yields `0 ≠ N` at
step 5. Deleting the test files, renaming a test, or writing no tests at all each produce a
non-zero exit.

For a **`script`** AC, `ac.sh` runs the named script, requires exit 0, **and** requires its
stdout to contain the manifest's `evidence` string **verbatim, as a substring of one line**
(leading whitespace in the rendered output is therefore fine), after the substitutions of
§5.0.3.

> **Round 4's sentence here was false and is deleted.** It read: *"Each evidence string
> carries a count, so a script that ran nothing cannot print it."* It cannot. Two lines are
> enough to make **AC-14 and AC-21 both green** with zero mutants applied and zero
> sensitivity observed:
>
> ```sh
> # scripts/mutation-kill.sh
> printf 'mutation: 60 mutants, 59 killed, 1 control survived; witness=…
'
> # scripts/degeneracy-sweep.sh
> printf 'sweep: 46/46 gauntlet tests accounted for; control …/… pass; witness=…
'
> ```
>
> §5.0.1 names AC-21 and AC-14 as *"two instruments … and they are the only two"* narrowing
> the zero-assertion gap, and both could be hollowed out by their own harness. **This is r2
> finding 2 re-committed one layer up** — round 2 wrote a reassuring sentence asserting that
> a degenerate artefact could not satisfy a gate, r2 broke it, r3 deleted it with an apology,
> and round 4 wrote the same shape for `script` ACs. **R-9, written by round 4 itself, is
> the rule it violated:** *a criterion that is satisfied by breaking the thing that observes
> it is not a criterion.*
>
> **What replaces it: two devices, independent, either one sufficient** (§5.0.3 and AC-18).
> (i) a **witness** in the evidence string that an `echo` cannot compute and that `ac.sh`
> verifies by a recomputation which does not go through the script; (ii) an **outside-in
> control artefact**: `ac-selftest.sh` must observe each harness script **rejecting** a
> sandbox it should reject (observations 7 and 8, mutants **M-52** and **M-53**). Neither is
> a sentence. **§8 states what remains open**: an implementer who deliberately fabricates
> `ac-selftest.sh` itself is outside 003's threat model, and 003 does not claim otherwise.

For the **`suite`** AC (AC-17), `ac.sh` runs the whole suite with `--json`, requires valid
JSON, requires the total number of `test_results` entries across all suites to equal the
manifest's `tests` value **after §5.0.3's substitution**, requires every status `Success`,
and requires the four pre-existing `RecknZkEscrowTest` names of §1.2 to be present.

**Spelling.** `AC-N` in prose and `AC-0N` in the manifest are the same criterion;
`scripts/ac.sh` accepts both spellings and normalizes to the two-digit form, which is also
the form embedded in test names (`_AC02_`). `gauntlet.sh --check` asserts the two spellings
are in bijection.

`bash scripts/ac.sh --all` runs every entry in the manifest, asserts it ran **22** of them,
and prints `ac: 22/22 acceptance criteria passed`.

`ac.sh` takes `--root <path>` so the harnesses can point it at a sandbox (r1 finding 4).
**`mutation-kill.sh` and `degeneracy-sweep.sh` take `--root <path>` for the same reason**,
which is what makes AC-18 observations 7 and 8 possible (§5.0.3, r4 finding 3): a script that
cannot be pointed at a poisoned tree cannot be observed rejecting one. All three are **new**
scripts and their interfaces are 003's to define; **none of them is `no-keys.sh`**, whose
interface does not change (N-9) — including for check 15, whose second target is derived
from the script's own location and costs no argument (§4.5).

**Every AC below carries a `Falsify:` line — a concrete command that makes that AC exit
non-zero.** An AC without a working falsifier is not an acceptance criterion.

### 5.0.1 What the five gates do **not** do (r2 finding 2 — stated plainly, not denied)

The five gates read test **names** and test **statuses**. **No gate opens a test body.**
Round 2 claimed otherwise — AC-18 observation 5 said *"a test whose body is
`assertTrue(true)` still fails, because the run gate's name set would no longer match the
manifest's row coverage"* — and **that sentence was false and is deleted.** Emptying a body
does not rename it. The attack r2 demonstrated:

```solidity
function test_AC02_G01_settles_regardless_of_caller() public { assertTrue(true); }
function test_AC02_G02_random_bytes_revert()         public { assertTrue(true); }
function test_AC02_G05_reproduced_pays_seller()      public { assertTrue(true); }
function test_AC02_G06_bad_outcome_reverts()         public { assertTrue(true); }
function test_AC02_G08_mutated_values_revert()       public { assertTrue(true); }
function test_AC02_G09_stranger_frontruns()          public { assertTrue(true); }
```

Six tests, correct names, `|found| == 6 == N`, all `Success`, rows covered, manifest
untouched, Σ and AC-17's total unchanged. **`ac.sh --all` prints success over a suite that
asserts nothing.**

So, stated once and referenced from §8:

> **The five gates make *zero tests* impossible. They do not make *zero assertions*
> impossible.** Two instruments narrow the gap, and they are the only two — but note
> **exactly what they narrow it to** (r3 finding 7): AC-21 detects *zero **sensitivity***,
> which is a strictly smaller target than *zero assertions*. A body of
> `vm.warp(deadline); escrow.refundAfterDeadline(id);` asserts **nothing** and is still
> `Failure` under SW-1 (which reverts on that path), so it passes AC-21. The
> `assertTrue(true)` stub is the only zero-assertion shape AC-21 was designed to catch.
>
> - **AC-21 (new in r3) — the kill matrix.** Every gauntlet test must be observed
>   **failing** against at least one mutant. A body of `assertTrue(true)` passes against
>   every admitted mutant, so it is green in every column of the matrix and AC-21 names it
>   and exits non-zero. This is a *behavioural* body check: it never reads the source of a
>   test, it observes whether the test is sensitive to the contract at all.
>   **This holds only because a column that breaks `setUp` is refused (§5.4a).** Round 3
>   put **M-34** (every function body `revert()`) in the columns; under it every `setUp`
>   that funds a deal reverts, Foundry marks the whole file failed, and that one column
>   satisfied "`Failure` in at least one column" for **all 44 tests at once** — AC-21 was
>   vacuous and its own Falsify could not be observed non-zero (r3 finding 3). Fixed in
>   §5.4a and AC-21.
> - **AC-14 — per-AC mutation coverage.** Every forge AC must own **at least one** mutant
>   in §5.3, and `gauntlet.sh --check` asserts that mechanically (check 8). Round 2 left
>   **AC-8 with no mutant at all** because M-21 was written twice for two different
>   mutations (r2 finding 6) — and AC-8 is the acceptance condition for C-4, the fix that
>   closes today's same-token drain. That is fixed in §5.3 by splitting M-21 (verifier
>   return ignored → AC-2) from **M-40** (`fund` skips the delta check → AC-8).

Neither instrument proves the assertions are *correct*. §8 says so.

### 5.0.2 Termination and the permitted call graph (r2 finding 14)

The call graph is a DAG and is pinned here, because r2 found AC-15 sitting in an
unspecified cycle:

```
ac.sh --all  ─┬─▶ AC-00 ─▶ no-keys.sh
              ├─▶ AC-01 ─▶ no-keys-selftest.sh ─▶ (sandbox) no-keys.sh
              ├─▶ AC-02…AC-12, AC-19, AC-20 ─▶ forge  (the 13 forge ACs)
              ├─▶ AC-13, AC-16 ─▶ gauntlet.sh --check   (parsers only: no forge run, no ac.sh)
              ├─▶ AC-15 ─▶ gauntlet.sh ─▶ ac.sh AC-NN for the 13 forge ACs, individually
              │                        └─▶ no-keys.sh, no-keys-selftest.sh, ac-selftest.sh,
              │                            mutation-kill.sh, degeneracy-sweep.sh  (DIRECTLY)
              ├─▶ AC-17 ─▶ forge (whole suite)
              ├─▶ AC-14 ─▶ mutation-kill.sh    ─▶ ac.sh --root <sandbox> AC-NN (single)
              ├─▶ AC-18 ─▶ ac-selftest.sh      ─▶ ac.sh --root <sandbox> AC-NN (single),
              │                                    ac.sh --root <sandbox> --all,
              │                                    mutation-kill.sh   --root <poisoned sandbox>,
              │                                    degeneracy-sweep.sh --root <poisoned sandbox>
              └─▶ AC-21 ─▶ degeneracy-sweep.sh ─▶ forge (sandbox suites)

`gauntlet.sh --measure` (§1.5.1) is **not** in this graph: it is run once, by hand, as the
first action of P1, before any AC exists. It calls `forge`, `git` and `shasum`, and it calls
no script in this document.
```

Binding rules:

- **`gauntlet.sh` must never invoke `ac.sh --all`**, and must invoke `ac.sh AC-NN` only for
  the **13 forge ACs**, individually. It invokes `no-keys.sh`, `no-keys-selftest.sh`,
  `ac-selftest.sh`, `mutation-kill.sh` and `degeneracy-sweep.sh` **directly, not through
  `ac.sh`** — this is also half of the AC-18 self-reference fix (§5.2, AC-18).
- **`--all` on a sandbox root** (`--root <path>`) runs **19** ACs — all but AC-14, AC-18 and
  AC-21, which are harnesses *of* the harness — and prints
  `ac: 19/19 acceptance criteria passed (sandbox)`.
- `mutation-kill.sh`, `ac-selftest.sh` and `degeneracy-sweep.sh` never call `ac.sh --all`
  on the **repo root**.
- **New in r5:** `ac-selftest.sh` invokes `mutation-kill.sh` and `degeneracy-sweep.sh`
  **only with `--root <sandbox>`**, and neither of those two ever invokes `ac-selftest.sh`.
  Maximum depth is unchanged at 3 (`ac.sh --all` → AC-18 → `ac-selftest.sh` →
  `mutation-kill.sh --root`), and the fourth level cannot re-enter `ac.sh --all`.
  `gauntlet.sh --check` asserts both mechanically (GC-10).
- `gauntlet.sh --check` asserts these mechanically: `scripts/gauntlet.sh` contains no
  `ac.sh --all` and no `ac.sh AC-13|AC-14|AC-15|AC-16|AC-18|AC-21`; the three harness
  scripts contain no `ac.sh --all` without `--root`.

Maximum depth is 3 (`ac.sh --all` → AC-15 → `gauntlet.sh` → `ac.sh AC-NN`), and the third
level cannot re-enter `--all`.

### 5.0.3 Substitution tokens and witnesses (new in r5 — r4 findings 2 and 3)

Two mechanisms, both in `ac.sh`, both mechanical.

**(1) Substitution tokens — so that no 008-coupled total is a literal (finding 2).** Before
comparing anything, `ac.sh` reads `docs/gauntlet.base.json` (§1.5.1) and substitutes, in the
manifest's `tests` and `evidence` columns:

| token | value |
|---|---|
| `{P}` | **`\|base.pre_existing_tests\|`** — the **cardinality of the recorded id set**, measured at 003's base commit (§1.5.1; the set itself, not just its size, is what AC-17 asserts — r5 finding 3) |
| `{S}` | `46 + {P}` — the whole suite after 003 |

**`ac.sh` refuses to run at all if `docs/gauntlet.base.json` is missing, if
`pre_existing_tests` is absent, if it is not an array of ≥ 1 distinct strings, or if any entry
is not of the form `<contract>:<test>`**, and exits non-zero naming the file. A recorded set
replaced by `[]` is refused by the same floor that refuses `N < 1`. That is a hard floor in the script, the same shape as the `N ≥ 1` floor at step 2.
`46` is a literal because it is **this document's own** number — the sum of the `tests`
column over the 13 forge ACs, recomputed by GC-4 — and it depends on nothing
outside this file.

**(2) Witnesses — so that "a script that ran nothing cannot print it" becomes true instead
of asserted (finding 3).** Two evidence strings carry a `witness={W14}` / `witness={W21}`
field. The script prints a 16-hex value there; `ac.sh` **recomputes that value itself**, by
a path that does not run the script under test, and fails on a mismatch:

- **`{W14}` (AC-14).** `sha256`, truncated to 16 hex, of the concatenation — in sorted
  mutant-id order — of `sha256(patched source)` for **every** mutant in §5.3 whose patch
  applies to `zk-verdict/contracts/src/RecknZkEscrow.sol` or
  `zk-verdict/contracts/src/RecknVerdictVerifier.sol`. `ac.sh` recomputes it by applying
  each committed `test/mutants/M-*.patch` to a temp copy with `git apply` and hashing the
  result. No compilation, no `forge`, ~60 patch applications on a ~120-line file.
- **`{W21}` (AC-21).** The same construction over the **admitted columns**: the behavioural
  mutants minus the pinned exclusion list, plus the five `SW-*.patch`, plus the generated
  `SweepProbe_*` sources.

**What a witness proves and what it does not, said before someone asks.** It proves the
script had the **patched artefacts in hand** — a two-line `printf` cannot produce it without
applying every patch, which is most of the setup work and all of the bookkeeping. It does
**not** prove the sandboxes were built, `forge` was run, or a status was read. That half is
device (ii): AC-18 observations 7 and 8, which watch each script **reject** a sandbox from
outside. The two devices are independent — deleting either leaves the other — and neither is
a sentence. **Guarding the guard:** an `ac.sh` whose witness verification is deleted is
mutant **M-56**, killed by AC-18 observation 9.

### 5.1 The manifest (machine-read by `scripts/ac.sh` and `scripts/gauntlet.sh --check`)

Columns: `AC`, `kind` ∈ {`forge`,`script`,`suite`}, `selector` (regex for `forge`, command
for `script`), `tests` (exact expected count; `-` for `script`), `rows` (G ids that must
appear in that AC's test names; `-` if none), `evidence` (verbatim stdout line required for
`script`/`suite` kinds; `-` otherwise). Tab- or multi-space-separated; `#` starts a comment.

```ac-manifest
AC-00  script  scripts/no-keys.sh                 -   -                                        checks: 15/15 passed
AC-01  script  scripts/no-keys-selftest.sh        -   G-39,G-40                                selftest: 20 source mutants, 20 rejected; exit-corpus 23/23 rejected; 4 controls accepted
AC-02  forge   _AC02_                             6   G-01,G-02,G-05,G-06,G-08,G-09            -
AC-03  forge   _AC03_                             4   G-10,G-12,G-13,G-14                      -
AC-04  forge   _AC04_                             2   G-11                                     -
AC-05  forge   _AC05_                             4   G-07,G-15,G-16,G-17                      -
AC-06  forge   _AC06_                             2   G-03                                     -
AC-07  forge   _AC07_                             3   G-04,G-05,G-06                           -
AC-08  forge   _AC08_                             3   G-20,G-21                                -
AC-09  forge   _AC09_                             3   G-24,G-25,G-26                           -
AC-10  forge   _AC10_                             5   G-27,G-28,G-32,G-38                      -
AC-11  forge   _AC11_                             3   G-19,G-22,G-38                           -
AC-12  forge   _AC12_                             2   G-31                                     -
AC-13  script  scripts/gauntlet.sh --check        -   -                                        manifest: 40 rows, 22 acceptance criteria, 3 sources agree
AC-14  script  scripts/mutation-kill.sh           -   -                                        mutation: 60 mutants, 59 killed, 1 control survived; witness={W14}
AC-15  script  scripts/gauntlet.sh                -   -                                        40/40 rows as specified.
AC-16  script  scripts/gauntlet.sh --check        -   -                                        honest-scope: 2/2 digests unchanged since base commit
AC-17  suite   -                                  {S}  -                                       suite: {S}/{S} passed
AC-18  script  scripts/ac-selftest.sh             -   -                                        ac-selftest: 13 forge ACs, 13 observed failing when their tests are absent; degenerate dispatcher rejected; 3 harness scripts observed rejecting
AC-19  forge   _AC19_                             8   G-18,G-23,G-29,G-33,G-34,G-35,G-36,G-37  -
AC-20  forge   _AC20_                             1   G-30                                     -
AC-21  script  scripts/degeneracy-sweep.sh        -   -                                        sweep: 46/46 gauntlet tests accounted for; control {S}/{S} pass; witness={W21}
```

Arithmetic that `gauntlet.sh --check` recomputes and that a reviewer can recompute by hand:

- **22** acceptance criteria (AC-00 … AC-21).
- **13** `forge` ACs; their `tests` column sums to **46** — the number of gauntlet tests.
  `6+4+2+4+2+3+3+3+5+3+2+8+1 = 46`. **This is the one count in this document that is a
  literal, because it is derived from this document alone.**
- AC-17's `tests` = **`{S}` = `46 + {P}`**, where `{P}` is the **cardinality of the
  pre-existing test id set measured at 003's base commit** (§1.5.1, §5.0.3). It is **not**
  written out here: 008 lands first and changes it (r4 finding 2). Measured on the pre-008
  tree 2026-09-04, `{P}` was 12; that number is recorded as history in §1.2 and is used by
  nothing.
- The union of the `rows` column is exactly the **40** ids of §3.2, each appearing at least
  once. (Rows may appear in more than one AC; G-05 and G-06 appear in AC-02 and AC-07, and
  **G-38** appears in AC-10 and AC-11 — the invariant and the targeted test of INV-2c.
  **G-39** and **G-40** appear in **AC-01** and are the two `enforcement` rows: they are
  satisfied by `no-keys-selftest.sh` observing check 15 reject **M-51** (at 15c/15d) and
  **M-57** (at 15g), and GC-16 asserts that every `enforcement` row is carried by a `script`
  AC and by a `gauntlet.json` row with `test: null` and a non-empty `check`.)
- Every one of the 13 `forge` ACs appears in at least one `killed-by` cell of §5.3
  (`gauntlet.sh --check` check 8 — the rule r2 finding 2(d) required).
- AC-14's evidence line is **derived, not literal**: `gauntlet.sh --check` recomputes
  `T` from §5.3 (below) and asserts the manifest line reads exactly
  `mutation: <T> mutants, <T−1> killed, 1 control survived; witness={W14}`. Recomputed for
  round 6: `T` = **60**.
- **`{P}`, `{S}`, `{W14}` and `{W21}` are the only four substitution tokens** (§5.0.3).
  `gauntlet.sh --check` asserts that no other `{…}` token appears in the manifest, so a
  fifth one cannot be introduced without a spec edit.

### 5.2 The criteria

#### AC-0 — the central claim still holds (fixed text, `reckn-spec` charter)

```sh
bash scripts/ac.sh AC-00   # runs `bash scripts/no-keys.sh`; exit 0 and `checks: 15/15 passed`
bash scripts/no-keys.sh    # exit 0 — the founder's own command, unchanged
```
The state-changing surface becomes `fund` / `settleWithProof` / `refundAfterDeadline` —
three functions. `AGENTS.md` §0 and `scripts/no-keys.sh` already enumerate exactly these
three, so the *permitted* surface does not change; what changes is that the third one now
**exists**. `IERC20Min` also gains one declared function (`balanceOf`, C-4), and that
interface is now itself an enumerated surface (check 12). **New in r5: the enforcement
*region* gains a second file** — `RecknVerdictVerifier.sol`, whose single declared function
`verifyVerdict` is now enumerated too (check 15, §4.5.10; **introduced by task `008`, extended
by 003 — §1.5.4**), **and, new in r6, that file's `constructor`, which is where the address
every proof is dispatched to is chosen** (15g). All three are changes to what the
product claims, so §9's documentation obligations D-1…**D-12** must land in the same commit
and the demo script must say them out loud.

**Kills:** M-13 (constructor stores `msg.sender`), M-A (an `admin` address field), M-F
(an unlisted `function sweep`), **M-51** (the constant-address branch in
`RecknVerdictVerifier.verifyVerdict`) — the last by check 15, and by nothing that existed
before r5 — and **M-57** (the chain-id branch in that file's **constructor**), by **15g**, and
by nothing that existed before r6: M-57 passes 15a–15f, all 38 EVM rows and the whole suite.

**Falsify:**

```sh
# 1. reintroduce a role — check 1 must reject it
S=$(mktemp -d); mkdir -p "$S/scripts" "$S/zk-verdict/contracts/src"
cp scripts/no-keys.sh "$S/scripts/"
sed 's/^contract RecknZkEscrow {/contract RecknZkEscrow {\n    address public admin;/' \
  zk-verdict/contracts/src/RecknZkEscrow.sol > "$S/zk-verdict/contracts/src/RecknZkEscrow.sol"
bash "$S/scripts/no-keys.sh"; echo $?      # must be non-zero
# 2. delete refundAfterDeadline — the two-sided check 2 must reject it
# 3. NEW IN r5: splice the constant-address branch of §3.1.4 into
#    zk-verdict/contracts/src/RecknVerdictVerifier.sol in the sandbox — check 15 must
#    reject it. Before r5 this exited 0, which is r4 finding 1.
# 4. NEW IN r6: splice the CONSTRUCTOR branch of §3.1.4 into the same sandbox file:
#      constructor(address _verifier, bytes32 _verdictProgramVKey) {
#          if (block.chainid == 31337) { verifier = _verifier; }
#          else { verifier = address(0x0000000000000000000000000000000000001337); }
#          verdictProgramVKey = _verdictProgramVKey;
#      }
#    check 15 must reject it at 15g. Before r6 this exited 0 AND every EVM row stayed
#    green, which is r5 finding 1 and the reason R-11 is written down.
# 5. NEW IN r6: the same splice in RecknZkEscrow.sol's constructor
#      (verifier = block.chainid == 31337 ? _verifier : RecknVerdictVerifier(0x...1337);)
#    must be rejected by check 8's right-hand-side clause and by check 7b.
```

#### AC-1 — the enforcement script closes the call surface, over the whole file

```sh
bash scripts/ac.sh AC-01     # runs scripts/no-keys-selftest.sh
bash scripts/no-keys-selftest.sh   # direct — the founder's own command
```
`scripts/no-keys.sh` gains checks 5–15 and the two-sided check 2 exactly as tabulated in
§4.5 — **with check 15 introduced by task `008` and extended here, or introduced here if 008
landed without it (§1.5.4)**. **No interface change (N-9).** `scripts/no-keys-selftest.sh` builds the sandbox
layout described in §4.5.9, applies each artefact to the copy, runs the copied script, and
asserts:

- the **20** source-text mutants (M-1, M-13…M-19, M-35…M-38, M-41, M-42, **M-46**, **M-47**,
  **M-51**, **M-57**, M-A, M-F) are each **rejected** (exit non-zero), each by a **named**
  check — the selftest records which check fired and fails if a mutant is rejected by no check
  or by an unexpected one;
- the **23** entries of the **exit corpus** (§5.2.1) are each **rejected**, each by a named
  check;
- the **control M-0** (unmodified copy of **both** source files) is **accepted** (exit 0);
- the **prose control C-P** (a comment naming `approve()`, `permit()` and `.call{value:}()`
  spliced into `fund`) is **accepted**, so the checks cannot be passing by grepping English;
- the **string control C-S** (two legitimate string literals on one line, no call between
  them) is **accepted**, so the stripper cannot pass E-15…E-18 by deleting every line that
  contains a quote (§4.5.1);
- the **verifier prose control C-V** (a comment mentioning `msg.sender` inside
  `verifyVerdict`) is **accepted**, so check 15c-iii is reading stripped code and not
  grepping English;
- it prints
  `selftest: 20 source mutants, 20 rejected; exit-corpus 23/23 rejected; 4 controls accepted`.

**Kills:** M-1 `if (msg.sender == 0x5E11E5) { to = d.seller; }` inside `settleWithProof`
— **by check 7, structurally.**
*(r1 finding 3's corollary: round 1 attached M-1 to AC-2's caller fuzz, which cannot draw a
hardcoded constant out of 2^160. A fuzz is the wrong instrument for a backdoor; the right
one is "this identifier does not appear in this function at all". AC-2 is explicitly
recorded below as **not** killing it. Its sibling M-2 — `if (_creator == msg.sender)`, keyed
on a **stored** address — is check 7's too, but §5.3 assigns it to **AC-20**, because a
targeted deployer replay is the stronger demonstration and each mutant occupies exactly one
cell of the kill table.)*
M-14 `contract RecknZkEscrow is Owned {` (check 5); M-15 a `fallback() external {}`
(checks 6, 13); M-16 `require(tx.origin == x)` (checks 6, 13); M-17 `require(x ==
msg.sender)` inside `settleWithProof` (check 7); M-18 a constructor that also stores
`bytes32 private _secret = keccak256(abi.encode(msg.sender))` (checks 4, 8, and 9a on
`.encode`); M-19 deleting `refundAfterDeadline` entirely (check 2);
**M-35** the in-`fund` drain of §3.1.1 (check 9a: `.transfer(` count and range);
**M-36** a third `.transfer(` in `settleWithProof` gated on a calldata constant (check 9a —
the backdoor that carries no `msg.sender` at all); **M-37**
`transferFrom(seller, msg.sender, amount)` in `fund` (check 9a's pinned argument form);
**M-38** a fourth `msg.sender` in `fund`, `if (msg.sender == X) amount = 0;` (check 10);
**M-41** *(new in r3 — r2 finding 1, route A)* `if (amount == 0) {
IERC20Min(token).approve(seller, type(uint256).max); }` inside `fund`, with the matching
`approve` line added to `IERC20Min` — rejected by check 12 at the declaration and by check
9a at the call; **M-42** *(new in r3 — r2 finding 1, route B)* the file-level
`library Sweep { function pull(address t, address to) internal { IERC20Min(t).transfer(to,
IERC20Min(t).balanceOf(address(this))); } }` above the contract declaration plus
`Sweep.pull(token, seller);` inside `fund` — rejected by check 11 at the declaration and by
check 9a at the call;
**M-46** *(new in r4 — r3 finding 1)* `function(address, uint256) external returns (bool)
transfer = IERC20Min(token).transfer; transfer(seller, amount);` inside `fund` — the
function-pointer alias **named after the very method check 12 forces `L_plain` to admit**,
rejected by **check 9c** at the `function` token (and, independently, by 9b-range at the
call and by check 14 at the assignment). Its round-3 ancestor E-11 was rejected only
because its author named the local `f`; **M-46 exists to prove the rejection does not
depend on the name**;
**M-47** *(new in r4 — r3 finding 2)* `deals[dealBinding].seller = seller;` inside `fund`,
guarded on a hardcoded constant — a full redirect of another deal's payout that contains
**no call-shaped token at all** and is therefore invisible to checks 9a/9b/9c. Rejected by
**check 14**, and by nothing else; per R-5 its killer must be structural, because a fuzz
draws its constant with probability ~2^-160.
**M-51** *(new in r5 — r4 finding 1)* the constant-address branch of §3.1.4, spliced into
`RecknVerdictVerifier.verifyVerdict` **before** the `abi.decode`, so the named address
receives a chosen `outcome` and a chosen `dealBinding` and `ISP1Verifier` is never called.
This is a **resolver over every deal in every escrow constructed with that verifier**, and
under round 4 it was rejected by nothing at all: fourteen checks read the wrong file, the
kill table had no mutant against that file, the corpus had no entry, the sweep's columns were
patches to the escrow, and R-5 says a caller fuzz is not its killer. Rejected by **check
15**, at 15c-i (a third statement), 15c-iii (`if`, `return`, `msg.sender`) and 15d
(`v.outcome` / `v.dealBinding` are not permitted assignment targets) — three independent
sub-checks, none of which depends on the address or on the field names. **M-51 is the mutant
row G-39 records**, and AC-1's evidence count is the only place its rejection is observed.
**M-57** *(new in r6 — r5 finding 1)* the **constructor** branch of §3.1.4, spliced into
`RecknVerdictVerifier`'s constructor: `if (block.chainid == 31337) { verifier = _verifier; }
else { verifier = address(0x…1337); }`. It never touches `verifyVerdict`, so 15c and 15d have
nothing to say about it; both of its assignment sites extract the left-hand side `verifier`,
which 15d permits in the constructor range; 15e excludes that range by construction; and 15b
counts `function` tokens, of which `constructor` is not one. **Under round 5 it passed all of
15a–15f and every behavioural instrument in this document, because on the demo chain it is the
honest file** (R-11). Rejected by **15g**, at 15g-ii (three top-level `;`), 15g-iii (the
right-hand sides are not the parameters) and 15g-iv (`if`, `else`, `block.`, `0x`) — three
independent sub-conditions, none of which depends on the address or on the chain id. **M-57 is
the mutant row G-40 records.**
The selftest also re-runs M-13, M-A and M-F, which §5.3 assigns to **AC-0** because the
script's *original* checks 1/2/4 already reject them; they are exercised here, not claimed
here.

**What AC-1 does and does not establish.** It establishes that the 20 mutants and the 23
corpus constructs are rejected, and that four controls are accepted. It does **not**
establish P, P2, P3, P4, P5 or P6 — those are established by the *closedness* of the
allowlists and pinned regions (checks 7b, 8, 9, 11, 12, 14, 15), and the corpus is evidence
that the closedness is real rather than an aspiration. A twenty-fourth construct nobody listed
is rejected because it must either produce a call-shaped token, write storage through one of
the five source constructs that can (§4.5.6), read an execution-context value the two files
may not read (§4.5.6a), or violate a pinned region of the verifier file (§4.5.10) — not
because it is on a list. §8 restates the limit.

**Falsify:**

```sh
# minimal A: delete check 9 alone. M-35/M-36/M-37 survive (M-41 still dies at check 12,
# M-42 at check 11, M-46 at check 14), so the evidence line reads
#   "selftest: 20 source mutants, 17 rejected; ..."
# which is not the manifest's string, so `ac.sh AC-01` exits non-zero.
#
# minimal B (new in r4, and the only falsifier for the operand seam): delete check 14
# alone. M-47 survives; M-46 still dies at 9c. The line reads
#   "selftest: 20 source mutants, 19 rejected; ..."   -> non-zero.
#
# minimal C (new in r5, the falsifier for the second contract): delete check 15 entirely.
# M-51 and M-57 survive, and so do corpus entries E-19 and E-20 -- no other mutant, no
# other corpus entry and no control reads RecknVerdictVerifier.sol. The line reads
#   "selftest: 20 source mutants, 18 rejected; exit-corpus 21/23 rejected; ..."  -> non-zero.
# That this falsifier is available at all is the whole of r4 finding 1: before r5 there was
# no check to delete.
#
# minimal D (new in r6, and the only falsifier for the constructor region): delete
# sub-check 15g alone, keeping 15a-15f. M-51 still dies at 15c/15d; M-57 survives and E-20
# survives, and NOTHING else moves. The line reads
#   "selftest: 20 source mutants, 19 rejected; exit-corpus 22/23 rejected; ..."  -> non-zero.
# Under round 5 this state was the specification, not a falsifier -- which is r5 finding 1.
#
# minimal E (new in r6, for the escrow's half of the same seam): delete check 7b AND
# check 8's right-hand-side clause. E-23 -- the chain-id splice in RecknZkEscrow's own
# constructor -- survives; nothing else moves. The line reads
#   "selftest: 20 source mutants, 20 rejected; exit-corpus 22/23 rejected; ..."  -> non-zero.
# Deleting only one of the two leaves E-23 rejected by the other, which is the point of
# stating both: they are independent rejections of one construct.
#
# broad: delete checks 9, 11 and 12. At minimum M-35/M-36/M-37/M-41/M-42 survive, so the
# printed count is <= 14 and the exit-corpus count is far below 19. NOTE: r3 asserted an
# exact residue here ("11 rejected; exit-corpus 0/13") which is not defensible -- E-9,
# E-10 and E-13 are also rejected by checks 6/13, which this deletion leaves in place.
# The falsifier does not need an exact number: any count other than the manifest's
# literal makes `ac.sh AC-01` exit non-zero. The two minimal falsifiers above carry
# exact numbers and are the ones R-6 requires to be run and observed.
```

#### AC-2 — settlement authority is caller-independent (fuzzed)

```sh
bash scripts/ac.sh AC-02   # selector _AC02_ ; exactly 6 tests ; rows G-01,G-02,G-05,G-06,G-08,G-09
```
For a fuzzed `address caller`, with `vm.assume(caller != address(escrow))` **and no other
exclusion**: a proof that verifies and matches the binding settles identically regardless
of `caller`, and every non-verifying / non-matching / bad-outcome input reverts regardless
of `caller`. Additional `vm.assume` narrowing is permitted only with an inline comment
naming the mechanism that requires it. **Excluding the buyer, the seller, the deployer, or
any address used elsewhere in the test file is forbidden** — those are exactly the
addresses a degenerate implementation would special-case.

**Kills:** **M-21** *(narrowed in r3 — r2 finding 6)* the verifier call's return value is
ignored; and **M-24** the payout token is taken from calldata instead of `d.token`.
M-20 (`outcome != FAILED ⇒ seller`) is killed only jointly here; its primary killer is AC-7.

**Does not kill:** **M-1** (hardcoded `0x5E11E5`) or **M-2** (the stored creator). A caller
fuzz draws neither out of 2^160. M-1's killer is AC-1 check 7, structurally; M-2's is
AC-20's targeted deployer replay. Recorded here so the kill table's arithmetic is not
quietly rescued by an over-claim (R-5).

**Falsify:** `mv zk-verdict/contracts/test/KeyGauntletFuzz.t.sol{,.bak} && bash scripts/ac.sh AC-02`
→ non-zero (`0 ≠ 6` at the count gate). Also: rename one of the six tests so its `_G0N_`
segment is dropped → non-zero at the naming gate. Also: replace all six bodies with
`assertTrue(true)` → **AC-02 still exits 0** (that is r2's attack and the format does not
stop it) but **AC-21 exits non-zero and names all six** (§5.0.1).

#### AC-3 — the refund destination is the buyer, for every caller (fuzzed)

```sh
bash scripts/ac.sh AC-03   # 4 tests ; rows G-10,G-12,G-13,G-14
```
For a fuzzed `address caller` (same exclusion rule as AC-2) and a fuzzed `uint256 t`
bounded to `[deadline, deadline + 3650 days]`, `refundAfterDeadline` succeeds, moves
exactly `d.amount` to `d.buyer`, and moves **0** to `caller`. G-10 is the liveness test:
the `KEEPER` never submits, and the deal still leaves `Funded` after the deadline.

**Kills:** M-3 `token.transfer(msg.sender, d.amount)`; M-4 `token.transfer(d.seller,
d.amount)`; M-5 `token.transfer(tx.origin, d.amount)`. M-3 and M-5 would *also* be rejected
by checks 7 and 6/13 respectively; §5.3 assigns them here because AC-3 shows *where the
money went*, and each mutant occupies exactly one cell.

**Falsify:** change one test's assertion from `d.buyer` to a literal address equal to the
buyer's — R-2 forbids it and AC-14's M-3 then survives, failing AC-14; and deleting any one
of the four tests fails AC-3 at the count gate.

#### AC-4 — nobody can refund before the deadline (fuzzed caller × fuzzed time)

```sh
bash scripts/ac.sh AC-04   # 2 tests ; row G-11
```
Test 1 (`testFuzz_AC04_G11_…`): fuzzed caller and fuzzed `t ∈ [fundedAt, deadline − 1]` →
revert `DeadlineNotReached`, escrow balance unchanged. Test 2 (`test_AC04_G11_…`): the
boundary pair exactly — `t = deadline − 1` reverts, `t = deadline` succeeds.

**Kills:** M-6 the deadline check is dropped; M-7 the comparison is `>` instead of `>=` —
killed by the boundary test, **not** by the fuzz, which is why the pair is a separate test
with its own count.

**Falsify:** delete `test_AC04_G11_boundary` → count 1 ≠ 2 → non-zero.

#### AC-5 — a deal pays at most once, in both orders

```sh
bash scripts/ac.sh AC-05   # 4 tests ; rows G-07,G-15,G-16,G-17
```
Four sequences, each asserting that the second value-moving call reverts `BadState` and
that the total tokens leaving the escrow for that deal equal exactly `d.amount`:
settle→settle (G-07), refund→refund (G-15), settle→refund (G-16), refund→settle with a
genuinely valid late `Reproduced` proof (G-17).

**Kills:** M-8 `refundAfterDeadline` pays without writing `d.state`; M-9
`settleWithProof`'s guard is `if (d.state == State.Settled) revert` (so a `Refunded` deal
still settles → the double-pay task 001 exists to prevent).

**Falsify:** replace the G-17 test's real late proof with a mock that never verifies — the
test then passes for the wrong reason, but M-9 survives AC-14, which fails.

#### AC-6 — the binding is what settles the deal (INV-9's acceptance condition)

```sh
bash scripts/ac.sh AC-06   # 2 tests ; row G-03
```
**r1 finding 2:** round 1's command was `--match-test "test_AC06 testFuzz_AC06"` — one
regex containing a literal space, which no Solidity function name contains, so it matched
zero tests **even for a correct implementation**. The selector is now `_AC06_` and the
count gate is `2`.

Two forms: (a) `test_AC06_G03_control_matching_binding_settles` — the committed real
fixture proof settles a deal funded with the fixture's `deal_binding`; (b)
`testFuzz_AC06_G03_foreign_binding_reverts` — the **same** proof reverts `BindingMismatch`
against a deal funded with any fuzzed `bytes32 other != fixture binding`. (a) is the
non-degeneracy control for (b): without it, a contract that reverts on every proof would
satisfy (b).

This is the **"another convenient execution cannot settle this deal"** acceptance
condition, and it is the on-chain half of the `dealBinding` claim; the off-chain half (that
the guest computes the binding over the prestate root, the predicate and the plan) is
frozen by N-2 and is not re-derived here.

**Kills:** M-10 the `BindingMismatch` check is removed; M-11 the check is
`if (v.dealBinding == bytes32(0) || v.dealBinding == d.dealBinding)` — accepts a
zero-binding proof, i.e. the predicate guest's, which commits `dealBinding = 0`
(`zk-verdict/lib/src/lib.rs:29-31`).

**Falsify:** `bash scripts/ac.sh AC-06` with the fixture file renamed → the control test
fails → non-zero. Restore round 1's space-separated selector in the manifest → the parse
succeeds but `|found| = 0 ≠ 2` → non-zero (round 1's version silently exited 0).

#### AC-7 — the outcome byte decides the destination, and nothing else does

```sh
bash scripts/ac.sh AC-07   # 3 tests ; rows G-04,G-05,G-06
```
For fuzzed `uint8 outcome`: `0 → seller`, `1 → buyer`, everything else → revert
`BadOutcome` with the deal still `Funded`.

**Kills:** M-12 `to = d.seller` unconditionally; M-20 `outcome != FAILED ⇒ seller` (pays
the seller on outcome 7).

**Falsify:** narrow the fuzz to `outcome ∈ {0,1}` → M-20 survives AC-14 → AC-14 fails, and
R-1 forbids the added `vm.assume` without a named mechanism.

#### AC-8 — a deal cannot be Funded without the tokens arriving

```sh
bash scripts/ac.sh AC-08   # 3 tests ; rows G-20,G-21
```
`fund` reverts `UnderFunded` against a token that returns `false` without reverting (G-20)
and against an inbound fee-on-transfer token (G-21), and **no** deal is created
(`deals(dealId).state == None`). The third test is the positive control
`test_AC08_G20_control_exact_transfer_token_funds` — a well-behaved token funds and the
stored deal matches the arguments.

**Kills:** **M-40** *(new in r3 — r2 finding 6)* `fund` ignores `transferFrom`'s result and
skips C-4's delta check — the mutation that reproduces today's code
(`RecknZkEscrow.sol:86`), which is why this AC exists. Round 2 called this mutation
**M-21** while also calling *"the verifier call's return value is ignored"* M-21, and §5.3
assigned M-21 to AC-2 — so **AC-8, the acceptance condition for the same-token drain fix,
owned no mutant at all**. The two are now distinct: M-21 → AC-2, M-40 → AC-8.

**Falsify:** drop the positive control → count 2 ≠ 3 → non-zero. (Without it, a `fund` that
always reverts would pass the two negatives.) Also: apply M-40's patch to the live tree and
run `bash scripts/ac.sh AC-08` → must be non-zero; if it is 0, AC-8 is not testing C-4.

#### AC-9 — reentrancy cannot produce a second payout

```sh
bash scripts/ac.sh AC-09   # 3 tests ; rows G-24,G-25,G-26
```
Uses `ReentrantERC20`, which calls back into the escrow from within `transfer` /
`transferFrom`. Assert: the deal's total outward transfers = 1 (settle and refund cases),
and the interleaved-`fund` case reverts `UnderFunded` with neither deal created.

**Kills:** M-22 `d.state = State.Settled` moved to **after** the `transfer`.

**Falsify:** replace `ReentrantERC20` with a plain mock → M-22 survives AC-14 → AC-14 fails.

#### AC-10 — solvency and isolation under random call sequences

```sh
bash scripts/ac.sh AC-10   # 5 tests ; rows G-27,G-28,G-32,G-38
```
**Three** Foundry invariants over a handler exposing `fund`, `settleWithProof`,
`refundAfterDeadline`, `donate`, and `warp`, across **≥ 3 deals in ≥ 2 tokens** and a
fuzzed actor set — `invariant_AC10_G27_no_payout_exceeds_amount` (INV-3, INV-4, INV-6,
INV-7), `invariant_AC10_G32_cross_token_isolation` (INV-5) and
**`invariant_AC10_G38_funded_structs_immutable`** (INV-2c) — plus two unit tests:
`test_AC10_G27_donation_unrecoverable` and `test_AC10_G28_forced_eth_moves_nothing`.
`runs` / `depth` are pinned in `zk-verdict/contracts/foundry.toml`, and the values used
are printed into `gauntlet.json` (AC-15).

**`invariant_AC10_G38_funded_structs_immutable`, stated exactly** (new in r4 — r3 finding
2). The handler records, for every `dealId` the moment it is first observed `Funded`, the
snapshot `S(id) = abi.encode(deals[id])`. After **every** handler call, for every recorded
`id`:

- if `deals[id].state == Funded` → `abi.encode(deals[id]) == S(id)`, bytewise;
- if `deals[id].state ∈ {Settled, Refunded}` → the encoding equals `S(id)` **with only the
  `state` field replaced**, i.e. every other field is bytewise unchanged;
- `state == None` for a recorded `id` is a failure (nothing deletes a deal).

**Two handler obligations without which this invariant is decoration — and, new in r5, an
instrument for each (r4 finding 11).** (i) The handler's `fund` action must draw
`dealBinding` from `{a fresh pseudorandom value, the `dealId` of an already-`Funded` deal}`
with **both** branches reachable — otherwise a mutant that writes `deals[dealBinding]` only
ever corrupts `deals[<random 32 bytes>]`, which stays in state `None` and breaks nothing.
(ii) The handler must be able to call `fund` with `amount == 0`, because that is the entry
condition that costs the attacker nothing.

**Round 4 wrote these "so they cannot be dropped quietly" and then recorded, in its own
Falsify (b), that dropping (i) is not detectable; (ii) had no falsifier at all.** A stronger
claim than "stated" needs a mechanism, so the handler carries **two ghost counters** —
`fundsWithExistingBinding` and `fundsWithZeroAmount`, each incremented on the branch it
names — and `KeyGauntletInvariant.t.sol` declares

```solidity
function afterInvariant() public {
    assertGt(handler.fundsWithExistingBinding(), 0, "AC-10 obligation (i) unreachable");
    assertGt(handler.fundsWithZeroAmount(), 0,      "AC-10 obligation (ii) unreachable");
}
```

`afterInvariant()` runs once at the end of each invariant campaign and its failure fails the
run. It is **not** a `test_*` / `invariant_*` name, so AC-10's count stays **5** and no
manifest number moves. Mutants **M-54** (the handler's `fund` restricted to fresh bindings)
and **M-55** (the handler cannot pass `amount == 0`) are the evidence that the instrument
fires; both are harness-class and killed by AC-10. **If `runs` or `depth` are too small for
either branch to be drawn, `afterInvariant` fails and the implementer raises the setting in
`foundry.toml` — it is not a licence to delete the assertion.**

**Kills:** **M-23** *(redefined in r4 — r3 finding 4)* the **compound** patch:
`refundAfterDeadline` pays `IERC20Min(d.token).balanceOf(address(this))` instead of
`d.amount` **and** drops C-5's payout check in that function. Killed by
`invariant_AC10_G27_no_payout_exceeds_amount` (INV-4) once the handler holds more than one
deal in the token.
**M-50** *(new in r5 — r4 finding 10)* C-5's `==` becomes `>=` in **both** exits. Against
`OutboundFeeERC20` (already in §6.1) held by a handler carrying ≥ 2 deals in that token, the
escrow's balance falls by `d.amount + fee`, the relaxed check passes, the deal goes terminal,
and the fee is paid out of the **other** deal's principal. **INV-4 breaks**, and
`invariant_AC10_G27_no_payout_exceeds_amount` kills it. **This is the mutant §8 said did not
exist.** Round 4's sentence — *"C-5's bound is not evidenced by a mutant, because C-5 masks
the mutant that would evidence it"* — is an impossibility claim about the evidence, and it is
false: C-5 masks over-payment originating in the **contract's own code** (M-23's shape) and
does **not** mask over-payment originating in the **token**, which §4.1 already wrote down
(*"under `>=`, would succeed while over-paying"*). The counter-example was in this document's
own §4.1 and the sentence in §8 contradicted it. Corrected in §8 and here.
**M-54**, **M-55** *(new in r5 — r4 finding 11)* the two handler-obligation mutants above,
killed by `afterInvariant()`.

**Why M-23 is defined as a compound patch, and what round 3 got wrong.** Mutants are
applied to a sandbox copy of the **real post-003 source**, which contains C-5. The
single-line version of M-23 therefore transfers the whole balance, C-5 measures a decrease
`!= d.amount`, reverts `PayoutFailed()` and rolls the transfer back — **INV-4 is never
violated at any handler width**, and round 3's sentence *"AC-10 kills M-23 independently of
C-5's bound"* was false of the contract actually being mutated. C-5's justification remains
the runtime one in §4.1; it is simply not evidenced by a mutant C-5 neutralizes.

**Falsify:** (a) reduce the handler to one deal in one token → M-23 **and M-50** survive,
because with a single deal and no donation `balanceOf(this) == d.amount` and neither drain
is visible. (b) restrict the handler's `dealBinding` to fresh values only → **M-48 still
survives this invariant** (its recorded killer is AC-11's targeted test, which is why the
kill table assigns it there and not here) — **but as of r5 this is no longer silent: it is
M-54, and `afterInvariant()` fails, so AC-10 goes red.** (c) set `invariant_runs = 0` in
`foundry.toml` → forge reports the invariants without executing them and AC-14 fails;
`gauntlet.json`'s printed `fuzz` block makes the setting visible. (d) delete
`afterInvariant()` → M-54 and M-55 survive → AC-14 fails.

#### AC-11 — a funded deal's terms are immutable

```sh
bash scripts/ac.sh AC-11   # 3 tests ; rows G-19,G-22,G-38
```
For a fuzzed caller and fuzzed `(seller, token, amount, binding)`, `fund` on an existing
`dealId` reverts `DealExists` and the stored `Deal` is **bytewise identical** before and
after (compare the full ABI-encoded struct, not field-by-field spot checks) (G-19).
Second test: `dealBinding == bytes32(0)` reverts `ZeroBinding` and creates nothing (G-22).

**Third test, new in r4 (G-38, INV-2c) —
`testFuzz_AC11_G38_foreign_binding_cannot_redirect`.** Fund a victim deal
`(buyer B, seller S, token T, 1000)`. Then, from a **fuzzed** caller, call
`fund(freshId, attacker, T, 0, victimDealId)` — a fresh `dealId`, zero tokens, and a
`dealBinding` equal to the victim's `dealId`, which is public in the indexed `Funded`
event. Assert **both**:

1. `abi.encode(deals[victimDealId])` is bytewise identical to the snapshot taken before the
   call (the whole struct, not spot checks — the same discipline as G-19); **and**
2. the victim then settles with a genuine `Reproduced` proof and **`S`** receives 1000,
   `attacker` receives 0.

Assertion 2 is what makes this a *theft* test rather than a storage-equality test: the harm
r3 demonstrated is not that a slot changed, it is that an honest proof paid the wrong
address three blocks later. **R-2 applies:** both balances are compared against the deal's
own `d.amount` and `d.seller`, never against a literal repeated from the setup.

**Kills:** M-25 the `DealExists` guard is removed; M-26 the guard is
`if (deals[dealId].state == State.Settled) revert` (so a **Funded** deal can be overwritten
with a new seller — the redirect attack); **M-48** *(new in r4)* `fund` ends with
`deals[dealBinding].seller = seller;`, **unguarded** — the behavioural twin of source-text
mutant M-47. It is not keyed on a constant, so a deterministic test is a legitimate primary
killer under R-5; M-47, which *is* keyed on a constant, is killed structurally by check 14
instead.

**Falsify:** (a) compare three fields instead of the encoded struct and mutate a fourth →
M-26 survives. (b) drop assertion 2 from the G-38 test and keep only the struct comparison
→ still kills M-48, but a variant that writes `d.seller` **during** `settleWithProof`
instead of during `fund` would pass; the two assertions are kept because the invariant is
about the payout, not about the slot.

#### AC-12 — an unfunded deal has no behaviour

```sh
bash scripts/ac.sh AC-12   # 2 tests ; row G-31
```
For fuzzed `dealId` and fuzzed caller, `settleWithProof` and `refundAfterDeadline` each
revert `BadState` and no storage slot for that deal is written (one test per entry point).

**Kills:** M-27 `refundAfterDeadline` omits the state guard — a never-funded deal has
`fundedAt == 0`, so `0 + refundDelay` is long past and it would "refund" 0 tokens to
`address(0)`, writing a bogus `Refunded` record.

**Falsify:** delete either test → count 1 ≠ 2 → non-zero.

#### AC-13 — the matrix, the manifest, the kill table and the demo cannot drift apart

```sh
bash scripts/ac.sh AC-13   # runs `bash scripts/gauntlet.sh --check`
```
`gauntlet.sh --check` parses **this file** and compares, as sets. The two parsed regions —
§3.2's matrix and §5.3's kill table — are delimited by HTML-comment markers.

**Marker rule, stated mechanically (r2 finding 10, and the trap it sets).** Round 2 wrote
that *"those two comment markers appear exactly once each"*, which was false: the bare words
`BEGIN MATRIX` / `END MATRIX` also occur in AC-13's own prose. Round 3 hit the same trap one
level up — the full `<!-- BEGIN MATRIX -->` string now occurs **three** times in this
document (once as the marker, once quoted in this paragraph, once in Appendix A), and
`<!-- BEGIN KILLTABLE -->` occurs **four** times. Counting the substring is therefore also
wrong. The rule is **anchored to a whole line**:

> A marker is a line whose entire content is the marker. The parser must assert that each of
> `^<!-- BEGIN MATRIX -->$`, `^<!-- END MATRIX -->$`, `^<!-- BEGIN KILLTABLE -->$`,
> `^<!-- END KILLTABLE -->$` matches **exactly one line** of this document, and it must
> extract each region with the same anchored patterns. A marker quoted inside a sentence or
> inside a fenced command is never at column 0 followed by nothing, so it can never be
> mistaken for a marker.

Verified 2026-09-04 against this document: anchored counts are `1 / 1 / 1 / 1`; unanchored
substring counts are `3 / 3 / 4 / 4`. **A reviewer who checks this with `grep -cF` will get
the wrong answer; use `grep -cE '^<!-- BEGIN MATRIX -->$'`.**

The `ac-manifest` fenced block of §5.1 is located by its info string.

**GC-1.** §3.2's `G-NN` ids ↔ the `G` ids embedded in test names on disk ↔ `rows[].id` in
   `docs/gauntlet.json`. **Rows of class `enforcement` are exempt from the test-name half
   and carry check 16's obligation instead;**
**GC-2.** §3.2's per-class counts (21 theft / 7 authorized / 10 disclosed / **2 enforcement** /
   **40** total) recomputed from the table and from the JSON;
**GC-3.** §5.1's per-AC `tests` column ↔ the actual `--list --json` count for each selector;
**GC-4.** Σ(`tests` over `forge` ACs) = 46, and AC-17's `tests` = `46 + {P}` with `{P}` read from
   `docs/gauntlet.base.json` (§5.0.3) — **not** a literal;
**GC-5.** the union of §5.1's `rows` column = §3.2's id set;
**GC-6.** the number of manifest entries = 22;
**GC-7.** `docs/gauntlet.json` contains no `target override` string, no `signed_rows`
   inconsistency, a non-empty `contract.code_hash`, and — **new in r6** — a non-empty
   `contract.verifier_sp1_verifier`, which is part 5 of the deployment check and is
   unperformable without it (§2.3 A, §7.1);
**GC-8.** **every `forge` AC in §5.1 appears in at least one `killed-by` cell of §5.3**
   (r2 finding 2(d)). **Both sides are normalized to the two-digit spelling first** — §5.1
   writes `AC-08`, §5.3 writes `AC-8`, and comparing them raw silently finds nothing.
   Reproduce:

   ```sh
   awk '/^<!-- BEGIN KILLTABLE -->$/{f=1;next} /^<!-- END KILLTABLE -->$/{f=0} f' \
     docs/specs/003-key-gauntlet.md \
     | awk -F'|' '{print $6}' | grep -oE 'AC-[0-9]+' | sed -E 's/AC-([0-9])$/AC-0\1/' \
     | sort -u
   ```

   Run 2026-09-04 against this document: all 13 forge ACs are present, and **AC-14 is the
   only acceptance criterion that appears in no `killed-by` cell** — correct, because AC-14
   protects M-0 rather than killing anything;
**GC-9.** **AC-14's evidence literal is derived**: recompute `T` = the number of distinct ids
   matching `^M-([0-9]+|A|F)$` between the `KILLTABLE` markers, and assert §5.1's AC-14
   line reads exactly `mutation: <T> mutants, <T−1> killed, 1 control survived`
   (r2 finding 7);
**GC-10.** **the call-graph rules of §5.0.2** hold (`gauntlet.sh` contains no `ac.sh --all`, etc.);
**GC-11.** **no gauntlet test file contains a bare `vm.expectRevert()`** with no argument (R-2b);
**GC-12.** the **gag-rule pattern** of §7.1 does not match any rendered output while the
    re-execution guest's proving measurement is `null`;
**GC-13.** `SWEEP_EXEMPT.txt` (AC-21) contains at most **2** names, every one of them declared in
    `zk-verdict/contracts/test/KeyGauntletStructural.t.sol`, and every one carrying a
    reason line;
**GC-14.** **the sweep's column arithmetic (new in r4, re-derived in r5)**: `sweep.columns` in
    `docs/gauntlet.json` equals `T_beh − |§5.4a's pinned exclusion list| + (sweep mutants in
    §5.4)` = `25 − 1 + 5` = **29**, where `T_beh` is recomputed from §5.3 rather than typed
    (§5.3, AC-14); and `sweep.excluded_columns` equals §5.4a's pinned list exactly (today
    `["M-34"]`). A column silently added or dropped changes one of the two and fails here.
    **The pinned exclusion list is capped at 1** (§5.4a, r4 finding 9): a second entry fails
    here and is a founder decision, exactly as `SWEEP_EXEMPT.txt`'s third name is;
**GC-15.** **the base measurement is honest (new in r5 — r4 finding 2; the history half is new
    in r6 — r5 finding 2)**: `docs/gauntlet.base.json` exists; its `base_commit` is an
    **ancestor of `HEAD`**; and the two Honest-scope digests re-derived from
    `git show <base_commit>:zk-verdict/README.md` equal both the recorded values **and** the
    values computed from the working tree. Three sources; a softening edit moves exactly one
    of them (§1.5.1 rule 3). **And the base file has exactly one history** (§1.5.1 rule 4):
    it is **tracked**; `git log --diff-filter=A --format=%H -- docs/gauntlet.base.json` has
    **exactly one** entry; `git log --diff-filter=D --format=%H -- docs/gauntlet.base.json` is
    **empty**; and the blob at that single `A` commit is byte-identical to the working-tree
    file. Without these four, the laundering path is `rm` and every source of rule 3 is
    re-derived from the softened tree. This is the check AC-16 is dispatched onto;
**GC-16.** **every `enforcement` row is carried (new in r5)**: for each §3.2 row of class
    `enforcement` — **G-39 and G-40 as of r6** — the id appears in the `rows` column of a
    **`script`** AC in §5.1, and `docs/gauntlet.json`'s `rows[]` entry for it has `test: null`
    and a **non-empty** `check` naming the check that rejects it. This is what stops
    `enforcement` from becoming a class with no instrument;
**GC-17.** **the `~34 s` citation is located by content, not by line number (new in r5)**:
    `grep -n '~34 s' zk-verdict/README.md` returns **exactly one** match, and its line number
    equals `gauntlet.json.proving.predicate_guest_source`'s line. Zero or two matches is a
    failure naming the file (§1.5.3);
**GC-18.** **no unknown substitution token**: the manifest contains no `{…}` token other than
    `{P}`, `{S}`, `{W14}`, `{W21}` (§5.0.3);
**GC-19.** **the recorded pre-existing test set is a set of ids, not a number (new in r6 —
    r5 finding 3)**: `docs/gauntlet.base.json.pre_existing_tests` is an array of ≥ 1 distinct
    `<contract>:<test>` strings, `{P}` equals its cardinality, and every recorded id is present
    in `forge test --root zk-verdict/contracts --list --json` on the current tree. A recorded
    set that has silently become a count, or from which an id has vanished, fails here as well
    as at AC-17.

Any mismatch exits non-zero and names the missing ids. **The check series above is
`GC-1 … GC-19`; `no-keys.sh`'s series is `check 1 … 15`, and the two are never spelled the
same way** (§4.5.2, r5 finding 6). On success it prints
`manifest: 40 rows, 22 acceptance criteria, 3 sources agree`.

**Kills:** M-28 a hand-edited `gauntlet.json` with a row deleted; M-29 a test file where a
row's test exists but is named without its ID; M-30 a §3.2 row added to this document
without a test; **M-45** *(new in r3)* a `gauntlet.json` written without
`contract.code_hash`, which is what would silently un-do §2.3's fourth check.
**M-31b** (a manifest entry whose `tests` value is lowered to match a missing test) is
caught by check 3 against `--list` and by check 4's sum; it is a harness self-check inside
AC-13 and is **not** an entry in §5.3 (see the note under the kill table).

**Falsify:** add a row `| G-41 | theft | … |` to §3.2 and run → non-zero, naming G-41. Also:
delete `docs/gauntlet.base.json` → **GC-15** red before any forge run. Also: `git checkout`
a commit that is not a descendant of `base_commit` → GC-15's ancestry assertion red. Also
**new in r6**: `git rm docs/gauntlet.base.json && git commit`, then re-create it with
`gauntlet.sh --measure` and commit that → GC-15's `--diff-filter=D` assertion is non-empty →
red. Also: strip `contract.verifier_sp1_verifier` from `docs/gauntlet.json` → GC-7 red.

#### AC-14 — the mutation harness is real, and it mutates the real file (r1 finding 4)

```sh
bash scripts/ac.sh AC-14      # runs `bash scripts/mutation-kill.sh`
bash scripts/mutation-kill.sh # direct — the founder's own command
```
**Round 1 mutated a parallel copy.** Mutants lived in `test/mutants/MutantZkEscrow.sol`
with an `immutable uint256 MUT`, and no AC required the `MUT == 0` path to be derived from
`RecknZkEscrow.sol`. A backdoor added to the real contract and to nothing else left the
harness reporting "all mutants killed". **`MutantZkEscrow.sol` is deleted from this spec.**

All mutants are **patches applied to a sandboxed copy of the real source**:

- each mutant is a file `zk-verdict/contracts/test/mutants/M-NN.patch`, applied with
  `patch`/`git apply` to `src/RecknZkEscrow.sol` inside a sandbox;
- **behavioural** mutants (`T_beh`) get a sandbox Foundry project: copy
  `zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}` (including
  `src/fixtures/`), symlink `lib`, apply the patch, and run
  `bash scripts/ac.sh --root <sandbox> AC-NN` for the AC that names the mutant; assert it
  **fails**;
- **source-text** mutants (`T_src`) are driven by `no-keys-selftest.sh` (AC-1);
- **harness/document** mutants (`T_hd`) are applied to sandbox copies of
  `docs/gauntlet.json`, the test files' names and bodies, the handler,
  `scripts/ac.sh`, `scripts/mutation-kill.sh`, `scripts/degeneracy-sweep.sh`, this spec, and
  `zk-verdict/README.md`;
- **M-0 is the unmodified copy** (of **both** source files, r5): every AC must **pass**
  against it. If M-0 is reported killed, the harness is broken.

**The class counts are derived from §5.3, not restated here (new in r5 — r4 finding 6).**
Round 4 wrote *"behavioural (23) … source-text (16) … harness/document (8)"* — the round-3
numbers — two pages away from §5.4a and AC-21, which said 24, and printed the stale total
`# 48` as *the annotated output of a reviewer's own reproduction command*. `AGENTS.md` §5 is
explicit: do not write as observed a number that was not observed. So:

> `T_src`, `T_beh`, `T_hd` := the number of distinct ids matching `^M-([0-9]+|A|F)$` in
> §5.3's rows whose `class` cell is `source-text`, `behavioural`, `harness / document`
> respectively; and `T = 1 + T_src + T_beh + T_hd`. `gauntlet.sh --check` recomputes all
> four and asserts the identity; `mutation-kill.sh` builds exactly `T_beh` behavioural
> sandboxes and asserts the same.

Recomputed against this document **in round 6** (see AC-14's reproduction command below):
`T_src` = **20**, `T_beh` = **25**, `T_hd` = **14**, `T` = **60**. Only `T_src` moved this
round, and it moved by exactly one: **M-57**.

The script prints a table `mutant | class | killed-by | status` and the evidence line
`mutation: 60 mutants, 59 killed, 1 control survived; witness=<16 hex>`. **The witness is
`{W14}` of §5.0.3 and `ac.sh` recomputes it without running this script** — that, plus
AC-18 observation 7, is what replaces round 4's false sentence about scripts that ran
nothing. It exits non-zero if any mutant survives, if M-0 is reported killed, or if the
printed count differs from `T` recomputed from §5.3's `KILLTABLE` region.

**The count comparison is stated once, as an expression (r2 finding 7).**
`T := |{ ids between the KILLTABLE markers matching ^M-([0-9]+|A|F)$ }|`. A reviewer can
reproduce it:

```sh
# NOTE the ^…$ anchors: the marker strings also appear quoted in AC-13 and in the appendices.
awk '/^<!-- BEGIN KILLTABLE -->$/{f=1;next} /^<!-- END KILLTABLE -->$/{f=0} f' \
  docs/specs/003-key-gauntlet.md | grep -oE '\bM-([0-9]+|A|F)\b' | sort -u | wc -l   # 60
```

Run against this document on 2026-09-04, **in round 6, after M-57 was added**; the annotation
is an **observed** output, not a carried-forward one (R-10(ii)). Round 4's annotation read `# 48` while §5.3 said 52 — the number was
one round stale and was presented as a reviewer-verifiable observation, which is the failure
`AGENTS.md` §5 names. **The class counts have the same status:** if the two disagree,
`gauntlet.sh --check` fails rather than either being believed.

The lettered sub-mutants (`M-31b`, `M-31c`, `M-31d`, `M-32b`) do not match that pattern and
are excluded by construction, not by a rule someone has to remember. Round 2's version said
"41" in the evidence line, "42" in §5.3 and "the number of `M-` identifiers" (46 by grep) in
the check; the three are now one number by definition.

**`mutation-kill.sh` and `degeneracy-sweep.sh` must share one sandbox builder.** The
`T_beh` behavioural sandboxes are the same in both; building them twice is waste, and the
implementation report must state which script built them and the measured wall-clock. **No
wall-clock is asserted here** (`AGENTS.md` §5).

**Kills:** the degenerate harness — one that reports "all killed" by failing everything.
Its detector is **M-0, which must SURVIVE**; if the table reports M-0 killed, AC-14 fails.
(M-0 is the one identifier in §5.3 with no `killed-by`; AC-14 does not kill it, it protects
it.)

**Falsify:** (a) apply M-41's patch (the `approve` backdoor) to
`zk-verdict/contracts/src/RecknZkEscrow.sol` on the live tree and run the whole AC set —
**AC-0 and AC-1 must both go red.** If they do not, checks 9/11/12 are not doing what §4.5
says. This is the r2-blocker-1 regression test and is the one command that would have caught
round 2. **It is also what keeps a fabricated `no-keys-selftest.sh` out of scope for r4
finding 3**: a fabricated selftest keeps AC-1 green while AC-0 reddens, so this falsifier
fails and the fabrication is detected. (b) **New in r5:** apply **M-51**'s patch to
`zk-verdict/contracts/src/RecknVerdictVerifier.sol` on the live tree — **AC-0 and AC-1 must
both go red.** Under round 4 this command exited 0 with every AC green, and that is r4
finding 1 in one line. (b2) **New in r6:** apply **M-57**'s patch — the chain-id branch in the
**constructor** of the same file — on the live tree and run **the whole AC set**: **AC-0 and
AC-1 must go red and every other AC must stay green.** The second half matters as much as the
first: under round 5 the first half failed (AC-0 and AC-1 were green) while the second half
held, and that combination — *"the source is backdoored and only the structural check can
tell"* — is precisely R-11 and precisely why no EVM row can carry G-40. (c) replace `scripts/mutation-kill.sh` with a two-line `printf` of its
manifest evidence string → the witness `{W14}` no longer matches `ac.sh`'s recomputation, and
independently AC-18 observation 7 goes red.

#### AC-15 — the judge-facing surface is generated, not written

```sh
bash scripts/ac.sh AC-15   # runs `bash scripts/gauntlet.sh`
```
`scripts/gauntlet.sh` must: print the five private keys with the banner
`LOCAL ANVIL / FOUNDRY ONLY — throwaway development keys, no real funds`; print the escrow
address, **`extcodehash(escrow)`**, the `verifier` address, the `verdictProgramVKey`, and
`refundDelay` **and `RecknVerdictVerifier(verifier).verifier()` read on-chain** (§2.3(A)'s
**five-part** deployment check); print the **enforcement region** — the two checked files,
**both of their constructors**, and `checks: 15/15` (§7.2); run the 13 forge ACs through
`scripts/ac.sh AC-NN` individually and the five harness scripts **directly** (§5.0.2);
write `docs/gauntlet.json` (schema §7.1) from the **actual** run; render the matrix as an
ASCII table; and end with the money-shot block of §7.2.

It must exit non-zero if any AC fails, and in that case must **not** print the money-shot.

**Idempotence, without a false command (r1 finding 9).** Round 1 wrote
`git diff --exit-code docs/gauntlet.json   # exit 0 after ignoring generated_at/commit`.
`git diff --exit-code` has no field-ignore behaviour. The comparison is done by
`gauntlet.sh --check` itself, with the fields deleted before the diff:

```sh
git show HEAD:docs/gauntlet.json | jq -S 'del(.generated_at, .commit, .durations)' > "$a"
jq -S 'del(.generated_at, .commit, .durations)' docs/gauntlet.json                  > "$b"
diff -u "$a" "$b"
```

**Kills:** M-31 a `gauntlet.sh` that prints a canned transcript — the negative control is
to break one gauntlet test on purpose and assert `gauntlet.sh` exits non-zero and the
money-shot is absent from its output. **M-32b** (a `gauntlet.sh` that prints a nonzero
"transactions signed" count while `signed_rows` is empty) is a harness self-check inside
AC-15 and is not an entry in §5.3.

**Falsify:** `mv docs/gauntlet.json{,.bak} && bash scripts/ac.sh AC-13` → non-zero; and
break one test, run `gauntlet.sh`, grep for `rows as specified` → absent.

#### AC-16 — the honest scope is not quietly overwritten

```sh
bash scripts/ac.sh AC-16   # the digest half of `gauntlet.sh --check` (GC-15)
```

**Round 4 pinned two literals and would have gone red on day one (r4 finding 2).** The two
"Honest scope" digests it wrote out are digests of the **pre-008** tree; 008 §9(1) replaces
the re-execution guest's honest scope and 008's own OQ-2(1) says so. An AC whose only route
to green is *"edit the pinned digest"* forbids exactly the act it exists to forbid.

**What AC-16 pins now: not a value, a difference.** The two blocks are byte-frozen **relative
to 003's base commit**, and the digests are those recorded by `gauntlet.sh --measure` in
`docs/gauntlet.base.json.honest_scope` (§1.5.1). `gauntlet.sh --check` compares **three**
sources and fails unless all three agree:

1. the digests recomputed from the **working tree**;
2. the digests recomputed from **`git show <base_commit>:zk-verdict/README.md`**;
3. the digests **recorded** in `docs/gauntlet.base.json`.

A softening edit moves (1) and leaves (2) and (3) where they are, so AC-16 goes red.

**And it cannot be rescued by deleting the base file, which is what round 5 got wrong.**
Round 5 wrote that re-measuring is blocked *"because `--measure` refuses to overwrite"*. **A
`rm` is not an overwrite**: after the delete there is nothing to refuse, all three sources are
re-derived from the softened tree, they agree, and `base_commit` is trivially an ancestor of
`HEAD`. What blocks the act is **§1.5.1 rule 4**, asserted by GC-15: the base file must be
tracked, must have exactly one `--diff-filter=A` commit, must have **no** `--diff-filter=D`
commit, and its blob at that single `A` commit must equal the working-tree file. A
delete-and-re-measure leaves a `D` and a second `A`. Pinning to a git object closes the
*edit*; pinning the file's history closes the *replacement*, and both are needed.

The block is the heading line through the line immediately preceding the next line that
begins with `## ` (located by heading, not by line number, which drifts). Reproduce, for
each of the two headings:

```sh
awk '/^### Honest scope of the re-execution guest/{f=1} f && /^## /&&!/^### /{exit} f' \
  zk-verdict/README.md | shasum -a 256
git show "$(jq -r .base_commit docs/gauntlet.base.json):zk-verdict/README.md" \
  | awk '/^### Honest scope of the re-execution guest/{f=1} f && /^## /&&!/^### /{exit} f' \
  | shasum -a 256
```

and the same with `/^### Honest scope of the SVM guest/`. **003 resolves none of the items
in either block**, whatever 008 left them saying, so the digests must be unchanged at the end
of 003. **003 also does not touch the `~34 s` measurement OQ-6 cites** — it quotes it, and
§7.1 requires the quote to be re-located **by content** at run time (§1.5.3, GC-17).
On success `gauntlet.sh --check` prints
`honest-scope: 2/2 digests unchanged since base commit`.

**On the two digests round 4 wrote out.** They were re-measured against the pre-008 tree by
r1, r2, r3 and r4 and matched every time. That is not evidence for r5: they are digests of a
tree 003 will not run against. **They are deleted from this document rather than carried,**
because a literal that will be false on the first day of implementation is worse than no
literal at all.

**Kills:** M-32 a documentation edit that softens "Not yet:" to "Now closed:".

**Falsify (rewritten in r6 — r5 finding 2; the round-5 text asserted an outcome that does not
occur, which under R-6 is a broken instrument, not a typo):**

```sh
# (a) the plain softening edit — unchanged, and it is the one AC-16 was always about
sed -i '' 's/Not yet:/Now closed:/' zk-verdict/README.md && bash scripts/ac.sh AC-16   # non-zero

# (b) the laundering path, branch 1: delete and re-measure WITHOUT committing the delete
sed -i '' 's/Not yet:/Now closed:/' zk-verdict/README.md
rm docs/gauntlet.base.json
bash scripts/gauntlet.sh --measure     # non-zero: `git status --porcelain` is not empty
                                       # (rule 2's clean-tree condition; the deleted file
                                       #  is itself the dirt)

# (c) the laundering path, branch 2: commit the softening AND the delete, then re-measure
sed -i '' 's/Not yet:/Now closed:/' zk-verdict/README.md
git commit -m '...' zk-verdict/README.md
git rm docs/gauntlet.base.json && git commit -m '...'
bash scripts/gauntlet.sh --measure     # SUCCEEDS — the tree is clean and no base file exists
git add docs/gauntlet.base.json && git commit -m '...'
bash scripts/ac.sh AC-16               # NON-ZERO at GC-15: the D-filter log is non-empty and
                                       # the A-filter log has two entries. THIS is the branch
                                       # round 5 claimed `--measure` would refuse, and it does
                                       # not: all three of rule 3's sources agree here.

# (d) never commit the base file at all
bash scripts/ac.sh AC-16               # non-zero at GC-15: the file is untracked
```

**Each branch's expected outcome is the one that actually occurs**, and (c) is the one that
matters: the mechanism that stops it is rule 4, not rule 2.

#### AC-17 — the pre-existing settlement path still works, and the suite total is pinned

```sh
bash scripts/ac.sh AC-17
bash zk-verdict/scripts/zk-e2e.sh   # exit 0 (after S-1; today its exit status is discarded)
```
`ac.sh AC-17` runs the whole `zk-verdict/contracts` suite with `--json` and requires **four**
things, the third of which is new in r6:

1. **`{S}` = `46 + {P}`** test results in total (46 gauntlet, counted mechanically, plus the
   cardinality of the pre-existing id set **measured at 003's base commit**, §5.0.3);
2. every status `Success`;
3. **the recorded pre-existing test id set is a subset of the ids the run produced** — id =
   `<contract>:<test>`, with `(…)` stripped from the run's keys, the same normalization
   `--measure` used. `ac.sh` prints **every missing id** and exits non-zero. *(New in r6 —
   r5 finding 3.)*
4. the four pre-existing `RecknZkEscrowTest` names of §1.2 present — in particular
   `test_real_proof_settles_to_seller`, which settles a **real Groth16 proof**. They stay as
   the **load-bearing named subset** of (3); they may change only in the constructor's new
   `refundDelay` argument.

It prints `suite: <S>/<S> passed`.

**Why (3) is not implied by (1) and (4) — the attack it closes (r5 finding 3).** A count plus
four protected names leaves the *other* pre-existing tests unprotected. Measured today the
suite is 12 tests across five files and the four protected names are all in
`RecknZkEscrow.t.sol`; the other eight are named by nothing:

```sh
grep -rn 'function test' zk-verdict/contracts/test/*.t.sol   # 12 today; 4 of them named by AC-17
```

Delete `test_reexec_tampered_public_values_are_rejected`
(`zk-verdict/contracts/test/RecknReexecVerdict.t.sol:47`) — the test that proves a tampered
public-values blob is rejected — and add any passing test to the same file: `{P}` is
unchanged, `{S}` is unchanged, every status is `Success`, the four names are present, and
**under round 5 AC-17 was green**. That is the shape this project has failed under before: a
test that goes red during C-1…C-7's constructor change is easier to replace than to fix, and
AC-17 is the only thing looking at it. Recording the **set** rather than its size costs one
`--measure` field and closes it.

**Why `{P}` and not a number (r4 finding 2).** Round 4 wrote **58** here and in ten other
places, including two manifest evidence strings that `ac.sh` compares **verbatim**. 008 adds
tests to this same suite, so every one of those sites would have been red on day one, and
the only way through would have been to edit them privately. `{P}` is substituted by `ac.sh`
from `docs/gauntlet.base.json`, and `ac.sh` refuses to run if that file is missing. **008's
numbers are not pasted here either**: 008 is mid-review and its literals are not yet facts.

**S-1 is a precondition of the second command being evidence.**
`zk-verdict/scripts/zk-e2e.sh:84-85` pipes `forge test` into `grep … || true`, which
discards the exit status (`bash -c 'set -euo pipefail; (exit 7) | grep -E x || true; echo $?'`
→ `0`, run 2026-09-04). S-1 (§9) makes the script propagate it. Until S-1 lands, a green
`zk-e2e.sh` is not evidence that the suite passed and must not be cited as such.

**Kills:** M-33 a change to the `VerdictPublicValues` decode order, which makes the real
fixture stop settling. **M-34** — a contract whose every function body is `revert()`. It
fails AC-17's `Success` requirement and every authorized row, which is exactly the point: a
gauntlet made only of "must revert" rows would be satisfied by universal denial.
**M-34 stays here and is excluded from AC-21's columns (§5.4a).** AC-17 is a *whole-suite*
criterion, which is the right instrument for a mutant that makes the whole suite fail; as a
*sensitivity* column it proved everything and therefore nothing (r3 finding 3).

**Falsify:** add a test to any pre-existing file → the observed total is `{S} + 1` → non-zero
(drift is caught; `{P}` is fixed at the base commit and changing it means re-running
`--measure`, which refuses on both counts — the file exists, and the tree is dirty). Also:
delete `docs/gauntlet.base.json` → `ac.sh` refuses to run AC-17 at all and says which file is
missing. **Also, new in r6 and the falsifier for requirement (3):** delete
`test_reexec_tampered_public_values_are_rejected` from
`zk-verdict/contracts/test/RecknReexecVerdict.t.sol` and add a passing test in its place →
the total and every status are unchanged, and AC-17 exits non-zero naming
`RecknReexecVerdictTest:test_reexec_tampered_public_values_are_rejected` as missing. **Run it
and observe it (R-6); under round 5 it exited 0.**

#### AC-18 — the AC dispatcher cannot be satisfied by an empty implementation

```sh
bash scripts/ac.sh AC-18       # via the dispatcher
bash scripts/ac-selftest.sh    # direct — the founder's own command, bypasses ac.sh
```

**The self-reference, and how r3 cuts it (r2 finding 2, second half).** AC-18 is dispatched
by `ac.sh`, and `ac.sh` is the thing AC-18 is testing. An `ac.sh` that exits 0 on everything
would make AC-18 green while `ac-selftest.sh` never really ran. Three cuts, all required:

1. **A direct command, printed above**, the way AC-0 carries `bash scripts/no-keys.sh`
   beside its wrapper. The founder's verdict on AC-18 is the direct line, not the wrapper.
2. **`gauntlet.sh` invokes `ac-selftest.sh` directly, never through `ac.sh`** (§5.0.2), so
   the judge-facing run cannot be hollowed out by a degenerate dispatcher either.
3. **`ac-selftest.sh` detects a degenerate dispatcher from the inside** — observation 5
   below, mutant **M-43**. A dispatcher that exits 0 on everything makes observations 1–4
   report *no* failures, and `ac-selftest.sh` therefore exits non-zero. **A degenerate
   `ac.sh` cannot make `ac-selftest.sh` green**, so the loop is closed even if someone runs
   only the wrapper.

`scripts/ac-selftest.sh` works in a sandbox copy of the tree and asserts:

1. for each of the **13** `forge` ACs: with that AC's test file(s) moved aside,
   `bash scripts/ac.sh --root <sandbox> AC-NN` exits **non-zero**. Thirteen observations,
   not an argument.
2. with **all** gauntlet test files removed, `ac.sh --root <sandbox> --all` exits non-zero
   and names ≥ 13 failing ACs.
3. a manifest entry edited to `tests = 0` makes `ac.sh` exit non-zero **with the message
   naming the floor**, not silently pass.
4. a test renamed so its `_GNN_` segment is missing fails the naming gate.
5. **(replaces round 2's false observation 5)** the sandbox's `scripts/ac.sh` is replaced
   by `#!/usr/bin/env bash` + `exit 0`; observations 1–4 then report **no** failures, and
   `ac-selftest.sh` exits non-zero naming the degenerate dispatcher. (M-43.)
6. the control: on the unmodified sandbox, `ac.sh --root <sandbox> --all` exits **0**.
   Without this, `ac-selftest.sh` could pass by breaking everything.
7. **(new in r5 — r4 finding 3) `mutation-kill.sh` is observed rejecting.** In a sandbox
   whose `test/mutants/M-0.patch` has been replaced by a **non-empty** patch (so the
   "control" is no longer the unmodified source), `bash scripts/mutation-kill.sh --root
   <sandbox>` must exit **non-zero** naming M-0. A `mutation-kill.sh` that prints its
   evidence line and exits 0 cannot produce that observation. Mutant **M-52** is the
   two-line `printf` version of the script, and it must be observed failing this
   observation.
8. **(new in r5 — r4 finding 3) `degeneracy-sweep.sh` is observed rejecting.** In a sandbox
   whose six `_AC02_` bodies are `assertTrue(true)`, `bash scripts/degeneracy-sweep.sh
   --root <sandbox>` must exit **non-zero** naming all six. Mutant **M-53** is the two-line
   `printf` version, and it must be observed failing this observation. **This is AC-21's own
   Falsify (a), run from outside AC-21 — which is the point:** AC-21 cannot be the only
   thing that vouches for the script that implements AC-21.
9. **(new in r5) the witness verifier is observed working.** In a sandbox whose
   `scripts/mutation-kill.sh` prints a **stale** witness (correct counts, wrong 16 hex),
   `ac.sh --root <sandbox> AC-14` must exit non-zero. Mutant **M-56** is an `ac.sh` with the
   witness recomputation of §5.0.3 deleted, and it must be observed failing this
   observation.

**The recursion, and where it stops — said rather than hidden.** Observations 7, 8 and 9
move the observer one level out: `ac-selftest.sh` now watches `ac.sh`, `mutation-kill.sh`
and `degeneracy-sweep.sh`. **Nothing in this document watches `ac-selftest.sh`.** Three
things bound that, and none of them is a claim of closure: it is invoked **directly** by
`gauntlet.sh` and by the founder (`bash scripts/ac-selftest.sh`); its evidence string is
compared verbatim; and a script that fakes all nine observations is not an implementer
mistake but a **deliberate fabrication of evidence**, which is a different threat model from
everything else in this document. **003 is not a defence against an implementer who
fabricates evidence, and §8 says so in those words.** The two devices of §5.0.3 exist so
that the *cheap accidental* version — a placeholder script that was never finished — is
caught mechanically; the expensive deliberate version is caught by review or not at all.

It prints
`ac-selftest: 13 forge ACs, 13 observed failing when their tests are absent; degenerate dispatcher rejected; 3 harness scripts observed rejecting`.

**What AC-18 does not do.** It does **not** detect an empty test body. Round 2 claimed it
did (`:1157-1159`) and that claim was false. **AC-21 is the only instrument for empty
bodies**, and §5.0.1 says so in one place.

**Kills:** M-43 (the degenerate dispatcher); **M-52** (a fabricated `mutation-kill.sh`);
**M-53** (a fabricated `degeneracy-sweep.sh`); **M-56** (an `ac.sh` with the witness
recomputation removed). **M-31c** (an `ac.sh` reporting success on `|found| == 0`) and
**M-31d** (a count gate comparing `>=` instead of `==`) are harness self-checks inside AC-18
and are not entries in §5.3.

**Falsify:** change `ac.sh`'s count gate to `-ge` and re-run → observation 3 or 4 goes red.
Replace `ac-selftest.sh` with `exit 0` and run `bash scripts/gauntlet.sh` → the manifest's
evidence string is absent from stdout → AC-18 red.

#### AC-19 — the disclosed rows behave exactly as disclosed

```sh
bash scripts/ac.sh AC-19   # 8 tests ; rows G-18,G-23,G-29,G-33,G-34,G-35,G-36,G-37
```
Eight tests, one per disclosed row that has on-chain behaviour (G-27 and G-28 are covered by
AC-10). These are **not** "must revert" rows; each asserts the *stated* outcome, including
the ones that are uncomfortable:

- **G-18** blacklist on the buyer → `refundAfterDeadline` reverts, state stays `Funded`,
  and a later call with the blacklist lifted succeeds.
- **G-23** `seller == address(0)` → funding is allowed; the `Reproduced` path reverts; the
  deadline path returns the buyer's money.
- **G-29** a second escrow deployed with a rogue verifier settles its **own** deal; the
  honest escrow's deal in the same token is untouched.
- **G-33** a deployment with `refundDelay = MIN_REFUND_DELAY`: buyer funds, warps to
  `fundedAt + MIN_REFUND_DELAY`, calls `refundAfterDeadline` — **it succeeds**, the buyer
  is made whole, and a subsequently submitted genuinely valid `Reproduced` proof reverts
  `BadState`. The test asserts the seller received **0**. This is the honest expected value;
  a test that asserted a revert here would be asserting a mechanism the contract does not
  have.
- **G-34** an outbound-fee token: `fund` succeeds, both exits revert `PayoutFailed`, state
  is still `Funded` after both attempts, and a retry at a much later timestamp still
  reverts.
- **G-35** a rebasing token: same shape, with the balance moved by a rebase between `fund`
  and payout.
- **G-36** *(new in r3 — r2 finding 3)* a **recipient-fee** token (`RecipientFeeERC20`):
  `fund` succeeds, `settleWithProof` with a `Reproduced` proof **succeeds**, the deal is
  `Settled`, the escrow's balance fell by exactly `d.amount`, **and
  `T.balanceOf(d.seller)` rose by strictly less than `d.amount`**. The recipient-side
  assertion is the point of the test; asserting only the escrow side would make the test
  pass against the very defect it documents.
- **G-37** *(new in r3 — r2 finding 4)* a look-alike escrow is deployed with the **same**
  `verifier`, the **same** vkey and the **same** `refundDelay` as the honest one, and
  different bytecode. The test asserts that all three of round 2's checks pass and that
  `extcodehash(lookalike) != extcodehash(honest)` — i.e. that the fourth part of the
  deployment check is the only one that separates them.

**Kills:** **M-39** — C-5's payout delta check deleted. G-34/G-35 would then "succeed" and
mark the deal `Settled`/`Refunded` while the escrow's balance fell by the wrong amount, so
those tests fail. (M-39 also weakens INV-6, but AC-10's M-23 is the drain case; M-39 is the
under-pay case and needs its own row. **Note that M-39 does not change G-36's outcome** —
G-36 is invisible to C-5 by construction, which is exactly why it is disclosed.)

**Falsify:** delete G-33's test because it is unflattering → count 7 ≠ 8 → non-zero, and
AC-13 names G-33 as a matrix row with no test. **The unflattering rows are load-bearing on
the count**; they cannot be quietly dropped before the demo. Also: weaken G-36's test to
assert only the escrow-side delta → the test passes against a plain mock token, so it no
longer distinguishes `RecipientFeeERC20`, and R-3's pairing rule fails it in review.

#### AC-20 — the deployer's address is not special

```sh
bash scripts/ac.sh AC-20   # 1 test ; row G-30
```
`test_AC20_G30_deployer_results_identical_to_stranger` replays the eight rows named in
G-30 (G-01, G-03, G-06, G-07, G-11, G-15, G-19, G-31) from `DEPLOYER` and from `STRANGER`
and asserts, for each, that the revert selector and the full escrow-balance triple
(escrow, buyer, seller) are **byte-identical** between the two runs.

**Kills:** **M-2** `if (_creator == msg.sender) { to = _creator; }` inside
`settleWithProof`, where `_creator` is stored at construction. This is the backdoor a caller
fuzz cannot find (AC-2 records that it does not) and that AC-20 finds by construction,
because AC-20 pranks the deployer on purpose. Check 7 rejects it too; §5.3 assigns it here
(R-5's rule is that a constant-keyed mutant needs a **non-fuzz** killer, not necessarily a
source-text one).

**Falsify:** replace the byte-identity comparison with "both reverted" → M-2-shaped
mutants that revert with a *different* selector survive.

#### AC-21 — every gauntlet test is sensitive to the contract (new in r3 — r2 finding 2)

```sh
bash scripts/ac.sh AC-21          # runs `bash scripts/degeneracy-sweep.sh`
bash scripts/degeneracy-sweep.sh  # direct — the founder's own command
```

**This is the criterion that opens test bodies.** It does not read them; it observes whether
they are sensitive to the contract at all.

`scripts/degeneracy-sweep.sh` builds a **kill matrix** whose columns are mutants and whose
rows are the **46** gauntlet tests:

- **columns**: the **admitted** columns of §5.4a — the `T_beh` = **25** behavioural mutants
  of §5.3 minus the pinned exclusion list `{M-34}`, plus the **5 sweep mutants** of §5.4 =
  **29** (the sandboxes `mutation-kill.sh` already builds — the two scripts share one
  builder);
- **before any column is read, its setUp probe must pass** (§5.4a). A column whose probe
  fails and which is not in the pinned exclusion list makes `degeneracy-sweep.sh` exit
  non-zero, naming the column. It is never dropped silently and never counted;
- for each admitted column, one sandbox suite run: `forge test --root <sandbox> --json`,
  recording every test's status, **excluding contracts matching `^SweepProbe_`** — the probe
  files are sandbox-only scaffolding and are not rows of the matrix (§5.4a, r4 finding 5);
- one **control column**, the unmodified sandbox, in which all **`{S}`** tests must be
  `Success` — the same exclusion applies, which is what makes `{S}` reachable at all.

**The assertion:**

> Every gauntlet test must be `Failure` in **at least one admitted** column.

A body of `assertTrue(true)` is `Success` in every column, so the six stub tests of §5.0.1
are named and `degeneracy-sweep.sh` exits non-zero.

**The word "admitted" is load-bearing, and round 3 did not have it (r3 finding 3).** Round
3's columns included **M-34**, whose patch makes every function body `revert()`. Every
gauntlet `setUp()` funds a deal, so under M-34 `setUp` reverts and Foundry reports **every
test in the file** as a failure. In that one column all 44 tests were `Failure` **whatever
their bodies contained** — which satisfied "at least one column" for all of them at once.
AC-21 was vacuous, its stated consequence (*"a body of `assertTrue(true)` is `Success` in
every column"*) was false, and its own **Falsify could not be observed non-zero**, which
R-6 requires before the AC may be reported green. Round 3 named this exact hazard and then
guaranteed against it only for the 5 sweep mutants, not for the 23 behavioural ones.

**The one permitted exception, bounded so it cannot be widened privately.** A test may be
exempt only if it is listed in `zk-verdict/contracts/test/SWEEP_EXEMPT.txt`, one name per
line with a `# reason` suffix, **and** it lives in
`zk-verdict/contracts/test/KeyGauntletStructural.t.sol`. That file may contain **at most 2**
tests. `degeneracy-sweep.sh` fails if the file has more than 2 tests, if an exempt name is
outside it, if an exempt name has no reason, or if a non-exempt test is green in every
column. The exempt count is printed in `gauntlet.json` and **in the money-shot**, so a
growing exemption list is visible to the judge, not private to the implementer.

At the time of writing exactly **one** test is expected to need it —
`test_AC19_G37_lookalike_code_hash_differs`, because it compares two deployments' code
hashes and no mutation of the contract can change the *relation* it asserts. The second
slot is margin. **If the implementer needs a third, AC-21 fails and the founder decides**;
it is not an edit the implementer may make.

It prints `sweep: 46/46 gauntlet tests accounted for; control <S>/<S> pass; witness=<16 hex>`
followed by the matrix and the killed/exempt split. **The evidence string deliberately does
not carry the killed/exempt split**, because that split is not knowable before implementation
and a literal that cannot be predicted is r2 finding 7 all over again. The two numbers it
does carry are **46** (pinned by GC-4, Σ over the forge ACs' `tests` column — round
4 wrote 44 here and 56 in the sentence describing this line, both stale) and **`{S}`**
(substituted from the base measurement, §5.0.3 — never a literal). The **witness** is
`{W21}`, recomputed by `ac.sh` over the admitted columns' patched sources and the generated
probe sources, so a `degeneracy-sweep.sh` that ran nothing cannot print this line
(§5.0.3) — and, independently, AC-18 observation 8 must observe this script rejecting a
stubbed sandbox from outside.

**Kills:** **M-44** — a stub suite: one forge AC's test bodies replaced by
`assertTrue(true)` with names, signatures and the manifest untouched. Under round 2's format
that AC is green; under AC-21 the sweep names all of its tests. M-44's patch is
`test/mutants/M-44.patch` and it targets **AC-02**, exactly the AC r2 used to demonstrate
the hole.

**What AC-21 does not prove.** It proves each test is *sensitive to the contract*, not that
its assertions are *correct*. A test that asserts the wrong thing but observes the contract
is red in some column and passes AC-21. §8 says so.

**Falsify:** (a) replace the six `_AC02_` bodies with `assertTrue(true)` and run
`bash scripts/degeneracy-sweep.sh` → non-zero, naming all six. **This one must be run and
observed non-zero (R-6); under round 3's column set it exited zero, which is why AC-21 was
not a criterion.** (b) Delete the control column → the sweep can no longer distinguish "the
whole tree is broken" from "the mutants worked", so the script must refuse to run without it
(assert `control <S>/<S>` before anything else). (c) **New in r4:** put `M-34` back in the
column list → its setUp probe fails and the script exits non-zero naming the column
(mutant **M-49**); delete the probe assertion as well and (a) exits **zero** with the six
stubs unnamed, which is exactly the round-3 defect reproduced on demand. (d) Add a third
name to `SWEEP_EXEMPT.txt` → non-zero. (e) **New in r5:** stop excluding `^SweepProbe_` from
the column read → the control column counts the probe contracts' inherited tests as well and
the printed control total is no longer `{S}`, so `ac.sh AC-21` exits non-zero at the verbatim
evidence comparison. (f) **New in r5:** replace this script with a two-line `printf` of the
evidence line → the witness no longer matches `ac.sh`'s recomputation **and** AC-18
observation 8 goes red; either alone is sufficient.

### 5.2.1 The exit corpus (AC-1's witness that property P covers the family)

Each entry is spliced into the real files in a sandbox and must be **rejected**, with the
rejecting check recorded. **The corpus does not define the property.** Properties P / P2 / P3
(§3.1.2), P4 / P5 (§4.5.10) and P6 (§4.5.6a) are defined by the closedness of the allowlists
and pinned regions (checks 7b, 8, 9, 11, 12, 14, 15); the corpus is twenty-three witnesses that
the closedness is real. Adding a twenty-fourth construct to this list costs nothing and proves
nothing new; a construct *not* on this list is rejected for the same reason the ones on it
are. **E-14,
E-15 and E-16 were new in r4** — an alias whose rejection depended on the author's choice of
local name, and a stripper that could be made to delete the exit along with the evidence.
**E-17, E-18 and E-19 are new in r5** and each exists because r4 produced a construct the
corpus did **not** cover: the two delimiter families **crossed** (E-15 and E-16 each stayed
inside one family, so a two-pass stripper passed all sixteen entries and all three controls
while hiding a full drain), and a settlement backdoor in the **second** file.
**E-20 … E-23 are new in r6**, for the same reason one round later: r5 produced the
**constructor** of the second file (E-20) and of the first (E-23), which every check of round
5 either excluded or read only the left-hand side of; and the **escape clause** inside a
string literal (E-21, E-22), which §4.5.1 has required in prose since r3 —
*"honouring backslash escapes inside the two string forms"* — with **no entry testing it**.
A one-pass automaton that treats `\"` as a closing quote satisfies *"one pass, one state
machine"* and passed all nineteen r5 entries and all four controls.

| # | splice | rejected by |
|---|---|---|
| E-1 | `if (amount == 0) { IERC20Min(token).approve(seller, type(uint256).max); }` in `fund` (+ the `approve` line in `IERC20Min`) | 12, 9a |
| E-2 | `IERC20Min(token).increaseAllowance(seller, amount);` in `fund` (+ interface line) | 12, 9a |
| E-3 | `IERC20Min(token).permit(msg.sender, seller, amount, 0, 0, 0, 0);` (+ interface line) | 12, 9a, 10 |
| E-4 | `function approve(address, uint256) external returns (bool);` added to `IERC20Min` **only**, with no call | 12 |
| E-5 | `library Sweep { … IERC20Min(t).transfer(to, IERC20Min(t).balanceOf(address(this))); }` above the contract + `Sweep.pull(token, seller);` in `fund` | 11, 9a |
| E-6 | file-level `function _sweep(address t, address to) { IERC20Min(t).transfer(to, 1); }` + a call in `fund` | 11, 9b |
| E-7 | `import {SafeERC20} from "…";` + `using SafeERC20 for IERC20Min;` + `IERC20Min(token).safeTransfer(seller, amount);` | 11, 9a, 13 |
| E-8 | `(bool s, ) = token.call(abi.encodeWithSelector(0xa9059cbb, seller, amount));` in `fund` | 9a, 13 |
| E-9 | `payable(seller).transfer(address(this).balance);` in `refundAfterDeadline` | 9a, 6, 13 |
| E-10 | `assembly { pop(call(gas(), sload(0), 0, 0, 0, 0, 0)) }` in `fund` | 9b, 6, 13 |
| E-11 | `function(address,uint256) external returns (bool) f = IERC20Min(token).transfer; f(seller, amount);` in `fund` | **9c**, 14, 9b |
| E-12 | `interface IERC20Full { function approve(address,uint256) external returns (bool); }` at top level + `IERC20Full(token).approve(seller, amount);` | 11, 9a, 9b |
| E-13 | `new Drain{value: 0}(token);` in `fund` (with `contract Drain` at top level) | 11, 9b, 13 |
| **E-14** | the same construct as E-11 with the local **named `transfer`**: `function(address, uint256) external returns (bool) transfer = IERC20Min(token).transfer; transfer(seller, amount);` in `fund`. **Round 3 rejected E-11 only because its author wrote `f`**; `transfer` is in `L_plain` and must stay there, because check 12 pins the interface line that produces that token (r3 finding 1) | **9c**, **9b-range**, 14 |
| **E-15** | a value exit hidden **between two same-line string literals**: `bytes32 memoA = keccak256("a"); IERC20Min(token).transfer(seller, amount); bytes32 memoB = keccak256("b");` in `fund`. A greedy `s/".*"//` deletes the exit **and** the `keccak256(` that would have failed 9b | **9a** (`.transfer` count/range) — and it is the **stripper** that is on trial: a line-wise stripper makes this construct invisible and the corpus entry green-by-blindness (§4.5.1) |
| **E-16** | the same exit hidden **between two same-line block comments**: `/* a */ IERC20Min(token).transfer(seller, amount); /* b */` in `fund`, against `scripts/no-keys.sh:30`'s existing `s:/\*.*\*/::` | **9a**, same reasoning |
| **E-17** | **a comment delimiter inside a string literal** (r4 finding 4): `string memory ref = "https://reckn.dev"; IERC20Min(token).transfer(seller, amount);` in `fund`. A **comments-first** pass sees the `//` inside the literal and deletes to end of line, so `src_calls` reads `string memory ref = "https:` and the `.transfer(` is gone; 9a's multiset is unchanged, 9b/9c see nothing, and **check 14 accepts the assignment** because `string memory ref` matches `D`. All fifteen checks pass and `fund` pays an arbitrary address | **9a** (`.transfer` count/range) — and again it is the **stripper** on trial: only a single left-to-right automaton over both families rejects this (§4.5.1) |
| **E-18** | **a string delimiter inside a comment** — the mirror: `// memo: "note` on one line, `IERC20Min(token).transfer(seller, amount);` on the next, `string memory s = "x";` on the third. A **strings-first** pass opens at the quote inside the comment and closes at the quote before `x`, deleting the exit between them | **9a**, same reasoning. **E-17 and E-18 together are the entries a two-pass stripper cannot pass in either order** |
| **E-19** | **the second contract** (r4 finding 1): the constant-address branch of §3.1.4 spliced into `RecknVerdictVerifier.verifyVerdict` before its `abi.decode`, giving one named address a proof-free settlement of any funded deal in either direction | **15c-i**, **15c-iii**, **15d** — and, before r5, by nothing in this document at all |
| **E-20** | **the second contract's `constructor`** (r5 finding 1): `constructor(address _verifier, bytes32 _verdictProgramVKey) { if (block.chainid == 31337) { verifier = _verifier; } else { verifier = address(0x…1337); } verdictProgramVKey = _verdictProgramVKey; }`. It never touches `verifyVerdict`; both assignment sites extract the left-hand side `verifier`, which 15d permits in this range; 15e excludes the range; 15b counts `function` tokens and `constructor` is not one. **On the demo chain it is the honest file, so all 38 EVM rows and the whole suite stay green** | **15g-ii**, **15g-iii**, **15g-iv** — and, before r6, **by nothing in this document at all**, which is r5 finding 1 |
| **E-21** | **an escaped quote inside a string literal** (r5 finding 4): `string memory ref = "a \" // b"; IERC20Min(token).transfer(seller, amount);` in `fund`. A scanner that does not honour `\` closes the literal at `\"`, sees `//`, and deletes the rest of the line: `.transfer(` disappears from `src_calls`, 9a's multiset is unchanged, 9b/9c see nothing, and **check 14 accepts `string memory ref` because `D` admits it** — E-17's chain of consequences through the one clause of §4.5.1 that had no witness | **9a** (`.transfer` count/range) — and it is the **stripper** on trial: only an automaton that honours backslash escapes inside string spans rejects this |
| **E-22** | **the same, in the other string form**: `string memory ref = 'a \' // b'; IERC20Min(token).transfer(seller, amount);` in `fund`. It is a separate entry and not a decoration: §4.5.1's clause is written over *"the two string forms"*, and a stripper that honours `\"` and not `\'` passes E-21 and hides the exit here. **One entry cannot distinguish that implementation from a correct one**, which is exactly why E-15/E-16 were not enough for the delimiter families in r4 | **9a**, same reasoning |
| **E-23** | **the first contract's `constructor`** (r5 finding 1, item 4): `verifier = block.chainid == 31337 ? _verifier : RecknVerdictVerifier(address(0x…1337));` in `RecknZkEscrow`'s constructor. Check 8 permitted the left-hand side `verifier` and said nothing about the right | **check 8**'s right-hand-side clause (the RHS is not `_verifier`) and **7b** (`block.chainid` in the constructor range) — two independent rejections, which is what AC-1's *minimal E* falsifier deletes one at a time |

**Controls (must be ACCEPTED):**

| # | splice | why it must pass |
|---|---|---|
| C-M0 | nothing (the unmodified file) | the selftest cannot pass by rejecting everything |
| C-P | `// never call approve(), permit(), or .call{value:}()` inside `fund` | the checks read code, not English. A check that fails on this is grepping prose |
| **C-S** | `string memory sA = "a"; string memory sB = "b";` inside `fund` — two legitimate string literals on one line, **no call between them** | the **under**-stripping control. Without it, a stripper could pass E-15 and E-17 by deleting every line containing a quote, which would blind checks 9 and 13 to any code an attacker chooses to put on a quoted line |
| **C-V** | `// no msg.sender branch here; see check 15` inside `verifyVerdict` | **new in r5.** The verifier's prose control: check 15c-iii bans the *token* `msg.sender`, and a check that fails on this comment is grepping English rather than reading the stripped body. It is also the only control that exercises the stripper on the **second** file |

E-1, E-5, **E-14**, **E-19** and **E-20** are also registered in §5.3 as **M-41**, **M-42**,
**M-46**, **M-51** and **M-57**, because r2, r3, r4 and r5 named exactly those routes as
blockers; they are counted once in each counter and the two counters are printed on the same
line (AC-1's evidence string). **E-21, E-22 and E-23 have no kill-table id**: E-21/E-22 put
the *stripper* on trial rather than the contract (the same status E-15…E-18 have), and E-23's
family is already carried in the kill table by M-57 — the reason it is not duplicated is in
§4.5.6a, stated rather than left as an unexplained asymmetry. **M-47** (the operand-corruption write) is a source-text mutant with **no** corpus
entry, because the corpus's subject is value **exits** and M-47 adds none — it redirects one.
That asymmetry is deliberate and is the whole content of r3 finding 2. **E-19 is the
opposite asymmetry and is deliberate too:** it adds no value exit and corrupts no operand —
it forges the *verdict* the exits obey, which is why it needed a new file in the region
rather than a new check in the old one.

### 5.3 The kill table (source of truth for AC-14's arithmetic)

`T` — the number of distinct ids matching `^M-([0-9]+|A|F)$` between the two **anchored**
markers below (`^<!-- BEGIN KILLTABLE -->$` … `^<!-- END KILLTABLE -->$`; see AC-13's marker
rule) — is **60**. One of them (M-0) must survive; the other **59** must be killed. The
per-class counts `T_src` / `T_beh` / `T_hd` are recomputed the same way, restricted to the
rows whose `class` cell names that class (AC-14): **20 / 25 / 14**, and
`T = 1 + 20 + 25 + 14`. Every id appears in exactly one `killed-by` cell.
`scripts/mutation-kill.sh` and `scripts/gauntlet.sh --check` both parse the region between
the markers, and **nothing but table rows may appear between them**.

<!-- BEGIN KILLTABLE -->

| class | ids | count | driven by | killed by |
|---|---|---|---|---|
| control | M-0 | 1 | both harnesses | **nothing — must survive** |
| source-text | M-1, M-13, M-14, M-15, M-16, M-17, M-18, M-19, M-35, M-36, M-37, M-38, M-41, M-42, M-46, M-47, M-51, M-57, M-A, M-F | 20 | `no-keys-selftest.sh` | AC-0 (M-13, M-A, M-F), AC-1 (the rest, including **M-51** at check 15c/15d and **M-57** at check 15g) |
| behavioural | M-21, M-24 | 2 | sandbox forge | AC-2 |
| behavioural | M-3, M-4, M-5 | 3 | sandbox forge | AC-3 |
| behavioural | M-6, M-7 | 2 | sandbox forge | AC-4 |
| behavioural | M-8, M-9 | 2 | sandbox forge | AC-5 |
| behavioural | M-10, M-11 | 2 | sandbox forge | AC-6 |
| behavioural | M-12, M-20 | 2 | sandbox forge | AC-7 |
| behavioural | M-40 | 1 | sandbox forge | AC-8 |
| behavioural | M-22 | 1 | sandbox forge | AC-9 |
| behavioural | M-23, M-50 | 2 | sandbox forge | AC-10 |
| behavioural | M-25, M-26, M-48 | 3 | sandbox forge | AC-11 |
| behavioural | M-27 | 1 | sandbox forge | AC-12 |
| behavioural | M-33, M-34 | 2 | sandbox forge | AC-17 |
| behavioural | M-39 | 1 | sandbox forge | AC-19 |
| behavioural | M-2 | 1 | sandbox forge | AC-20 |
| harness / document | M-28, M-29, M-30, M-45 | 4 | `mutation-kill.sh` | AC-13 |
| harness / document | M-31 | 1 | `mutation-kill.sh` | AC-15 |
| harness / document | M-32 | 1 | `mutation-kill.sh` | AC-16 |
| harness / document | M-43, M-52, M-53, M-56 | 4 | `ac-selftest.sh` | AC-18 |
| harness / document | M-44, M-49 | 2 | `degeneracy-sweep.sh` | AC-21 |
| harness / document | M-54, M-55 | 2 | `mutation-kill.sh` | AC-10 |

<!-- END KILLTABLE -->

Sum: `1 + 20 + (2+3+2+2+2+2+1+1+2+3+1+2+1+1) + (4+1+1+4+2+2) = 1 + 20 + 25 + 14 = 60`.
Killed = **59**.

**The four ids added in r4, and which review finding each answers:** **M-46** (the
function-pointer alias named `transfer`, source-text, check 9c — finding 1); **M-47** (the
foreign-key write guarded on a constant, source-text, check 14 — finding 2); **M-48** (the
same write unguarded, behavioural, AC-11's G-38 test — finding 2's behavioural half); and
**M-49** (a `degeneracy-sweep.sh` whose column list re-admits a setUp-breaking mutant and
whose probe assertion is deleted, harness, AC-21 — finding 3). M-46/M-47 are keyed on
constants and are therefore killed **structurally**, per R-5; M-48 is not, and is killed by
a deterministic test.

**The seven ids added in r5:**

| id | class | what it is | killed by | r4 finding |
|---|---|---|---|---|
| **M-50** | behavioural | C-5's `==` becomes `>=` in both exits; against `OutboundFeeERC20` with ≥ 2 deals in that token the escrow over-pays out of the other deal's principal | AC-10's `invariant_AC10_G27_no_payout_exceeds_amount` | 10 — *"C-5 masks the mutant that would evidence it"* was stronger than the fact |
| **M-51** | source-text | the constant-address branch in `RecknVerdictVerifier.verifyVerdict` (§3.1.4) — a resolver over every deal in every escrow using that verifier | AC-1 at **check 15** (15c-i, 15c-iii, 15d) | 1 — **and by nothing at all before r5** |
| **M-52** | harness | `scripts/mutation-kill.sh` replaced by a two-line `printf` of its manifest evidence line | AC-18 observation 7 | 3 |
| **M-53** | harness | `scripts/degeneracy-sweep.sh` replaced by a two-line `printf` of its manifest evidence line | AC-18 observation 8 | 3 |
| **M-54** | harness | the handler's `fund` action restricted to **fresh** `dealBinding` values | AC-10's `afterInvariant()` | 11 |
| **M-55** | harness | the handler cannot call `fund` with `amount == 0` | AC-10's `afterInvariant()` | 11 |
| **M-56** | harness | `scripts/ac.sh` with §5.0.3's witness recomputation deleted | AC-18 observation 9 | 3 |

**The one id added in r6:**

| id | class | what it is | killed by | r5 finding |
|---|---|---|---|---|
| **M-57** | source-text | the chain-id branch in `RecknVerdictVerifier`'s **constructor** (§3.1.4): `if (block.chainid == 31337) { verifier = _verifier; } else { verifier = address(0x…1337); }`. Every proof off the demo chain is dispatched to a contract of the attacker's choosing; on the demo chain the file is honest | AC-1 at **check 15**, sub-check **15g** (15g-ii, 15g-iii, 15g-iv) | 1 — **and by nothing at all before r6: it passes 15a–15f, all 38 EVM rows, every sweep column and AC-17** |

**M-57 is keyed on the chain id, which is a constant *of the environment*, so R-5's rule
applies with a twist that R-11 now records.** R-5 says a mutant keyed on a constant needs a
structural killer because a fuzz cannot draw the constant. M-57 needs one for a stronger
reason: **the fuzz draws the constant on every single run and the mutant is honest when it
does.** No behavioural instrument in this document can be its killer, because every one of
them runs on the chain where the mutant behaves.

**M-51 is keyed on a constant and is therefore killed structurally, per R-5** — a caller
fuzz draws its address with probability ~2^-160, and until r5 there was no structural check
in the region to be its killer. **M-50 is not keyed on anything** and is killed
behaviourally, which is why it is the mutant that can carry C-5's evidence where M-23 cannot.

**Every one of the 13 `forge` ACs owns at least one mutant** — AC-2 (M-21, M-24), AC-3,
AC-4, AC-5, AC-6, AC-7, **AC-8 (M-40)**, AC-9, **AC-10 (M-23, M-50, M-54, M-55)**,
**AC-11 (M-25, M-26, M-48)**, AC-12, AC-19, AC-20. GC-8 asserts this mechanically.
Round 2 failed it at AC-8 (r2 finding 6).

**Excluded from `T` by construction:** the lettered sub-mutants `M-31b`, `M-31c`, `M-31d`,
`M-32b` are harness self-checks inside AC-13 / AC-15 / AC-18. They do not match
`^M-([0-9]+|A|F)$`, so no rule has to remember to exclude them. The **five sweep mutants**
of §5.4 use the `SW-` prefix for the same reason, and the **twenty-three exit-corpus entries**
of §5.2.1 use `E-`; only E-1, E-5, E-14, E-19 and E-20 have kill-table identities (M-41,
M-42, M-46, M-51, M-57).

### 5.4 The sweep mutants (AC-21's columns; not counted in `T`)

Five patches against the real source, chosen so that **each leaves `setUp()` able to fund a
deal** — a mutant that breaks `setUp` makes every test fail for the wrong reason and would
turn the sweep into a rubber stamp. They live in
`zk-verdict/contracts/test/mutants/SW-N.patch`.

**That guarantee is a design intention, and round 3 applied it to these five only — which
is how M-34 got into the columns and made AC-21 vacuous (r3 finding 3). §5.4a turns it into
a mechanical precondition on *every* column, these five included.**

| id | patch | what it makes insensitive tests visible |
|---|---|---|
| SW-1 | the bodies of `settleWithProof` and `refundAfterDeadline` become `revert PayoutFailed();`. `fund` untouched | every test that asserts a settle/refund outcome **or a specific revert selector on those paths** |
| SW-2 | `fund` keeps the storage write, the `emit` and the `transferFrom`, but drops the `DealExists` guard, the `ZeroBinding` guard and C-4's delta check. Honest funding still succeeds | every `fund`-negative test (G-19, G-20, G-21, G-22, G-26) |
| SW-3 | `refundAfterDeadline` pays `IERC20Min(d.token).balanceOf(address(this))` instead of `d.amount` | the solvency invariant and the donation test |
| SW-4 | `settleWithProof` pays `d.amount` of a token read from `publicValues` instead of `d.token` | the cross-token isolation invariant |
| SW-5 | the contract gains `receive() external payable {}` and `refundAfterDeadline` additionally sends `address(this).balance` to `d.buyer` | the forced-ETH test (G-28) |

SW-5 would be rejected by `no-keys.sh` checks 6 and 13 — that is fine and expected. The
sweep runs `forge`, not `no-keys.sh`; a sweep mutant only has to be *compilable* and
*setUp-safe*, not admissible.

**R-2b (new rule, mechanically checked).** No gauntlet test may use a bare
`vm.expectRevert()`. Every revert expectation must name the specific error selector or the
specific revert data. Without this, SW-1 (which reverts `PayoutFailed` everywhere) would be
indistinguishable from the real reverts and half the sweep would be blind. `gauntlet.sh
--check` check 11 greps for `vm.expectRevert()` with empty arguments in the gauntlet test
files and fails on any hit.

### 5.4a Column admissibility — the setUp probe (new in r4 — r3 finding 3)

**The defect this closes.** AC-21's assertion is *"every gauntlet test is `Failure` in at
least one column"*. A column in which the test contract's `setUp()` reverts reports **every
test in that contract as a failure**, for a reason that has nothing to do with any test
body. One such column satisfies AC-21 for the entire suite at once, and the criterion stops
being a criterion. Round 3 guaranteed setUp-safety for the five `SW-` patches and left the
23 behavioural columns unguarded — and M-34, defined as *"a contract whose every function
body is `revert()`"*, is exactly such a column.

**Two devices, and the second is the one that generalizes.**

**(1) A pinned exclusion list, capped at 1 (cap new in r5 — r4 finding 9).** `{M-34}` — one
id, held in this section **and** in `scripts/degeneracy-sweep.sh`, and printed as
`sweep.excluded_columns` in `docs/gauntlet.json`. M-34 keeps its kill-table cell under
**AC-17**, a whole-suite criterion, which is the right instrument for a mutant that makes
the whole suite fail. Adding an id to this list is a **spec edit**, checked by GC-14; the implementer cannot do it privately. Because the list is pinned, `sweep.columns` is a
**predictable number** (`T_beh − 1 + 5` = `25 − 1 + 5` = **29**) rather than whatever
survived at runtime.

**The cap.** Round 4 gave `SWEEP_EXEMPT.txt` a hard budget — at most 2 tests, one file,
printed in the money-shot, *"if the implementer needs a third, AC-21 fails and the founder
decides"* — and gave this list **visibility with no budget at all**, while §5.4a's own
M-33 paragraph offers *"a founder-visible addition to the pinned exclusion list"* as an
acceptable resolution when a probe fails at implementation time. Excluding a column makes
AC-21 *stricter*, not vacuous, so this is a hole in **coverage** rather than in the
assertion — under exactly the pressure this section anticipates. It gets the same shape as
the exemption budget: **at most 1 entry. A second entry makes GC-14 fail and is a
founder decision, not an implementer edit.** The two budgets are priced together in OQ-7.

**(2) A setUp probe, per column, per test file.** The exclusion list only covers the
setUp-breaking mutants somebody thought of. The probe covers the next one.

**One probe per test-declaring contract, not one per file (corrected in r5 — r4 finding
5).** Round 4 said *"for each gauntlet test file `F`"*, which silently assumes one test
contract per file. `KeyGauntletInvariant.t.sol` is specified as *"+ handler"* (§6.1) and
nothing pinned the others to one, so a mutant that broke a **second** contract's `setUp`
would be invisible to a probe built over the first. `degeneracy-sweep.sh` therefore
**enumerates contracts, not files**: every contract in the gauntlet test files that declares
at least one `function test…` / `function testFuzz…` / `function invariant_…` gets a probe.
The handler declares none and gets none. **The expected contract inventory is pinned in
§6.1 and `degeneracy-sweep.sh` fails if the tree disagrees with it** — a fifth test contract
appearing without a probe is a build failure, not a silent gap.

For each such contract `C` in file `F`, `degeneracy-sweep.sh` generates into **the sandbox
only** a file `SweepProbe_C.t.sol`:

```solidity
import {C} from "./F.t.sol";                     // the test contract being probed
contract SweepProbe_C is C {
    function test_probe_setup_ok() public { assertTrue(true); }
}
```

It inherits `C`'s `setUp()` rather than copying it, so the probe cannot drift from the thing
it is probing. **Inheritance is the right call and is kept** — but Foundry discovers
**inherited** `test_*` functions on the derived contract, and that has two consequences round
4 got wrong:

**(i) The probe is read from parsed JSON, never from an exit status.** The command filters by
test as well as by contract:

```sh
forge test --root "$sandbox" --match-contract '^SweepProbe_' \
                             --match-test '^test_probe_setup_ok$' --json
```

and the script **parses that JSON for each `test_probe_setup_ok`'s `status`**. Round 4's
command filtered by contract only, so in an *admitted* column — a mutant whose whole purpose
is to make gauntlet tests fail — the inherited copies fail, the command exits non-zero, and
a script reading the exit status classifies a healthy column as probe-failed and aborts.
**The exit status of this command is not evidence about `setUp` and must not be read as
such.**

**(ii) `^SweepProbe_` contracts are excluded from the column read.** The probe files live in
the sandbox, the control column *is* a sandbox, and the column read records *"every test's
status"*. Four probe contracts × (all inherited tests + 1) puts the sandbox total far above
`{S}`, and AC-21's evidence line is compared verbatim — so without this exclusion the build
is red and no wording fixes it. The exclusion is stated here and in AC-21, and it is what
makes the control column exactly `{S}`.

Then, for every candidate column, **before** the column's statuses are read:

- every `test_probe_setup_ok` **`Success`** → the column is **admitted**;
- any of them **`Failure`** → the mutant broke that contract's `setUp`. If the column's id is
  in the pinned exclusion list, that is the expected outcome and it is recorded; **if it is
  not, `degeneracy-sweep.sh` exits non-zero naming the column**. It is never dropped
  silently and never counted.

`assertTrue(true)` is the correct probe body here precisely because it is insensitive to
everything except whether `setUp` ran — the property AC-21 forbids in a *gauntlet* test is
the property that makes a *probe* valid. The probe files exist only inside sandboxes and are
excluded from every column read, so AC-17's suite total (`{S}`) and AC-21's row count (46)
are unaffected.

**Consequences that must be checked at implementation time, not assumed.** **M-33** (a
change to the `VerdictPublicValues` decode order) will fail the probe for any test file
whose `setUp` settles the real fixture proof. If it does, M-33 is **not** silently dropped:
the sweep exits non-zero, and closing it is either (a) moving that settlement out of
`setUp` into the test that needs it, or (b) a founder-visible addition to the pinned
exclusion list. **(a) is the preferred resolution** — a `setUp` that settles a deal is doing
work that belongs in a test. This is written down because "the implementer will work it out"
is how r2 finding 6's cell got rescued privately.

**OQ-7 (the exemption budget) is answerable only now.** A vacuous matrix made the budget
moot; with §5.4a in place the budget question is real again.

---

## 6. Test plan

### 6.1 Files

| file | purpose | ACs |
|---|---|---|
| `zk-verdict/contracts/test/KeyGauntlet.t.sol` | the unit rows, named `test_AC05_G07_…` etc. **Exactly 1 test contract** | AC-5, AC-8, AC-9, AC-10 (units), AC-12, AC-19, AC-20 |
| `zk-verdict/contracts/test/KeyGauntletFuzz.t.sol` | caller / time / parameter fuzz. **Exactly 1 test contract** | AC-2, AC-3, AC-4, AC-6, AC-7, AC-11 |
| `zk-verdict/contracts/test/KeyGauntletInvariant.t.sol` + handler | random call sequences over ≥ 3 deals in ≥ 2 tokens; the handler's `fund` action draws `dealBinding` from **{fresh, an existing deal's `dealId`}** and may pass `amount == 0`, and exposes the two ghost counters `fundsWithExistingBinding` / `fundsWithZeroAmount` that `afterInvariant()` asserts non-zero (AC-10's two handler obligations, now instrumented). **Exactly 1 test contract + 1 handler contract; the handler declares no `test_`/`invariant_` function and therefore gets no sweep probe** | AC-10 (3 invariants + `afterInvariant`) |
| `zk-verdict/contracts/test/KeyGauntletStructural.t.sol` | **at most 2** tests whose assertions no contract mutation can change; the only file whose tests may be sweep-exempt. **Exactly 1 test contract** | AC-19 (G-37), AC-21 |
| `zk-verdict/contracts/test/SWEEP_EXEMPT.txt` | the exemption list, one `name # reason` per line, ≤ 2 lines | AC-21, GC-13 |
| `zk-verdict/contracts/test/mutants/M-*.patch` | one patch per kill-table mutant, applied to a **sandbox copy of the real source**. **M-51 and M-57 patch `src/RecknVerdictVerifier.sol` (M-51 its `verifyVerdict`, M-57 its `constructor`); every other source-text and behavioural patch targets `src/RecknZkEscrow.sol`** | AC-1, AC-14 |
| `zk-verdict/contracts/test/mutants/SW-*.patch` | the five sweep mutants of §5.4 | AC-21 |
| `zk-verdict/contracts/test/mocks/ReentrantERC20.sol` | calls back into the escrow from `transfer`/`transferFrom` | AC-9 |
| `zk-verdict/contracts/test/mocks/FalseReturningERC20.sol` | returns `false`, never reverts | AC-8 |
| `zk-verdict/contracts/test/mocks/InboundFeeERC20.sol` | delivers `amount − fee` on `transferFrom` | AC-8 (G-21) |
| `zk-verdict/contracts/test/mocks/OutboundFeeERC20.sol` | funds cleanly; `transfer` moves `amount + fee` from the sender | AC-19 (G-34) |
| `zk-verdict/contracts/test/mocks/RecipientFeeERC20.sol` | **debits the sender exactly `x`, credits the recipient `x − fee`** — §1.3(d)'s violator | AC-19 (G-36) |
| `zk-verdict/contracts/test/mocks/RebasingERC20.sol` | balances drift on demand | AC-19 (G-35) |
| `zk-verdict/contracts/test/mocks/BlacklistERC20.sol` | reverts on `transfer` to a chosen address | AC-19 (G-18, G-23) |
| `scripts/ac.sh` | the AC dispatcher of §5.0; `--root`, `--all` | all |
| `scripts/ac-selftest.sh` | negative control on `ac.sh`, including the degenerate dispatcher | AC-18 |
| `scripts/no-keys-selftest.sh` | sandboxed source-text mutants + the exit corpus vs the **unmodified** `no-keys.sh` | AC-1 |
| `scripts/mutation-kill.sh` | applies `M-*.patch` to sandboxes, prints the kill table | AC-14 |
| `scripts/degeneracy-sweep.sh` | builds the kill matrix over the **29 admitted columns** (`T_beh` = 25 behavioural − the pinned exclusion `{M-34}` + 5 sweep) plus the control column; generates one sandbox-only `SweepProbe_*.t.sol` **per test-declaring contract**, gates every column on its probe read from parsed JSON, and excludes `^SweepProbe_` from every column read (§5.4a) | AC-21 |
| `scripts/gauntlet.sh` | judge-facing runner + `docs/gauntlet.json` generator + `--check` | AC-13, AC-15, AC-16 |

**The pinned test-contract inventory (new in r5 — r4 finding 5).** Four gauntlet test
contracts, plus one handler that declares no tests. `degeneracy-sweep.sh` generates one probe
per **test-declaring contract** and fails if the inventory on disk differs from this table,
so a fifth contract cannot appear without a probe and a `setUp` cannot hide behind one.

**Deleted from round 1:** `zk-verdict/contracts/test/mutants/MutantZkEscrow.sol` and
`zk-verdict/contracts/test/MutationKill.t.sol`. Mutating a parallel copy proves the tests
kill mutations *of the copy* (r1 finding 4).

### 6.2 Positive path (must pass)

Rows G-04, G-05, G-09, G-12, G-13, G-14, AC-6's control, AC-8's control, and AC-17's
real-proof test. **A gauntlet that only proves things revert would be satisfied by a
contract that reverts on everything** — that contract is M-34, and it must be observed
failing (AC-17).

**Row G-36 is a positive path with a negative assertion**, and it is the only one: the call
must *succeed*, the state must become terminal, and the seller's balance must rise by
*strictly less* than `d.amount`. A test that asserted a revert there would be asserting a
mechanism the contract does not have (the same error G-33's test avoids).

### 6.3 Negative controls (must be observed failing — the point of the exercise)

Each is an artefact that must be **observed failing**, and the observation is itself
asserted:

1. **M-0 survives.** The unmodified **pair of source files** passes every AC. If the harness
   reports M-0 killed, the harness is broken (AC-14). The sweep's control column is the same
   idea for AC-21: `{S}`/`{S}` must pass before any column is interpreted.
2. **Each of the 58 mutants is killed by the AC named in §5.3** (AC-14, AC-1).
3. **The empty implementation.** With every gauntlet test file absent, each of the 13
   `forge` ACs exits non-zero — thirteen recorded observations (AC-18). *Control on r1
   finding 1.*
4. **The empty test body.** Six `_AC02_` tests reduced to `assertTrue(true)` — correct
   names, correct count, manifest untouched — **must be named by AC-21** (M-44). *Control on
   r2 finding 2, and the reason AC-21 exists.*
5. **The degenerate dispatcher.** `scripts/ac.sh` replaced by `exit 0` — `ac-selftest.sh`
   must exit non-zero (M-43). *Control on AC-18's self-reference.*
6. **The real file is what is mutated.** M-41's patch (the `approve` backdoor) applied to
   `zk-verdict/contracts/src/RecknZkEscrow.sol` on the live tree turns **AC-0 and AC-1**
   red (AC-14's Falsify line). *Control on r2 finding 1.*
7. **The prose control.** A comment naming `approve()` / `permit()` / `.call{value:}()`
   spliced into `fund` must be **accepted** by `no-keys.sh` (AC-1). *Control on the checks
   being greps for English.*
8. **A `gauntlet.sh` run with one test deliberately broken** exits non-zero and omits the
   money-shot (AC-15).
9. **A clean copy of `RecknZkEscrow.sol`** is accepted by `no-keys.sh` in the sandbox
   selftest, so the selftest cannot pass by rejecting everything (AC-1).
10. **A softened Honest-scope edit** fails the digest check (AC-16).
11. **A manifest entry set to `tests = 0`** is refused by `ac.sh` (AC-18 observation 3).
12. **A third name in `SWEEP_EXEMPT.txt`** makes AC-21 exit non-zero (the exemption budget
    cannot be widened by the implementer).
13. **The operand seam, both halves.** M-47 (`deals[dealBinding].seller = seller;` guarded
    on a constant) turns **AC-1** red at check 14; M-48 (the same write, unguarded) turns
    **AC-11** red at the G-38 test. *Control on r3 finding 2 — a state change carrying no
    call-shaped token.*
14. **The stripper, in the direction that hides code.** E-15 and E-16 must be **rejected**
    and control C-S must be **accepted**; a line-wise stripper fails one or the other.
    *Control on r3 finding 6.*
15. **A setUp-breaking column is refused, not counted.** M-49 — `degeneracy-sweep.sh` with
    M-34 re-admitted to the columns and the probe assertion deleted — makes AC-21's own
    Falsify (a) exit **zero** with the six stubs unnamed. That is the round-3 defect
    reproduced on demand, and the sweep must be observed refusing it. *Control on r3
    finding 3.*
16. **The second contract in the settlement path.** M-51 (the constant-address branch in
    `RecknVerdictVerifier.verifyVerdict`) applied to the **live tree** turns **AC-0 and
    AC-1** red (AC-14's Falsify (b)). Under round 4 this command exited 0 with every AC
    green. *Control on r4 finding 1.*
17. **The stripper's two families, crossed.** E-17 (a `//` inside a string literal) and E-18
    (a `"` inside a comment) must both be **REJECTED** while C-S and C-P stay **ACCEPTED**.
    A two-pass stripper fails one of the four in whichever order it is run. *Control on r4
    finding 4.*
18. **The harness scripts are observed rejecting, from outside.** M-52 (`mutation-kill.sh`
    replaced by a `printf`), M-53 (`degeneracy-sweep.sh` likewise) and M-56 (`ac.sh` with the
    witness recomputation deleted) must each make `ac-selftest.sh` exit non-zero
    (observations 7, 8, 9). *Control on r4 finding 3 — the sentence that claimed a script
    which ran nothing could not print its evidence line.*
19. **The handler's two obligations are reachable.** M-54 (fresh bindings only) and M-55
    (`amount == 0` unreachable) must each make AC-10 red through `afterInvariant()`. *Control
    on r4 finding 11.*
20. **C-5's bound is evidenced.** M-50 (`==` → `>=` in both exits) against
    `OutboundFeeERC20` with ≥ 2 deals in that token must break INV-4 and be killed by AC-10.
    *Control on r4 finding 10 — the claim that no mutant could evidence C-5.*
21. **The environment-conditional constructor, and the two-sided observation it requires.**
    M-57 (the chain-id branch in `RecknVerdictVerifier`'s constructor) applied to the **live
    tree** must turn **AC-0 and AC-1 red while every other AC stays green** — both halves are
    asserted. E-20 must be **rejected** by 15g and E-23 by check 8 / 7b, while control C-V
    stays **accepted**. *Control on r5 finding 1, and the only control in this list whose
    point is that the behavioural instruments are **not** allowed to fire (R-11).*
22. **The pre-existing test set, not its size.** Delete
    `test_reexec_tampered_public_values_are_rejected` from
    `zk-verdict/contracts/test/RecknReexecVerdict.t.sol`, add a passing test in its place, and
    run `bash scripts/ac.sh AC-17`: it must exit non-zero **naming the missing id**, with the
    suite total and every status unchanged. *Control on r5 finding 3.*
23. **The laundering path is a delete, not an overwrite.** AC-16's `Falsify` branch (c) —
    commit a softened Honest-scope block, `git rm` the base file, re-measure, commit — must
    make `bash scripts/ac.sh AC-16` exit non-zero **at GC-15's `--diff-filter=D` assertion**,
    and branch (b) must be refused by `--measure`'s clean-tree condition. *Control on r5
    finding 2, and on the fact that the round-5 falsifier asserted the wrong outcome.*

### 6.4 Anti-degeneracy rules (this project has opened the same hole four times)

Binding on the implementation:

- **R-1** No test may `vm.assume` away an address that appears elsewhere in the same test
  file, and no `vm.assume` may be added without an inline comment naming the mechanism
  that requires it.
- **R-2** No assertion may be satisfied by a constant. Every value assertion compares
  against a quantity derived from the deal's own funding (`d.amount`, `d.buyer`,
  `d.seller`), not against a literal repeated from the setup.
- **R-2b** *(new in r3)* No bare `vm.expectRevert()`. Every revert expectation names the
  specific error selector or the specific revert data. Mechanically checked by
  `gauntlet.sh --check` (GC-11); load-bearing for AC-21's SW-1 column (§5.4).
- **R-3** Any test that would still pass if the contract's function body were replaced by
  `revert()` must be paired with an authorized-row test that would then fail. M-34 is the
  suite-level instance of this rule; **AC-21 is its per-test mechanization** and supersedes
  the honour system.
- **R-4** Fuzz runs are configured in `zk-verdict/contracts/foundry.toml`, not per-test,
  and the configured `runs` / `invariant_runs` / `invariant_depth` are printed into
  `gauntlet.json`. A finite fuzz is evidence, not proof (§8).
- **R-5** **A fuzz is never the primary killer of a mutant keyed on a constant.** If a
  mutant's trigger is a hardcoded address, selector, or `dealId`, its `killed-by` in §5.3
  must be a structural check (`no-keys.sh`), not a fuzzed AC. Round 1 paired M-1 —
  *"the failure mode this project has hit three times"* — with a caller fuzz that draws it
  with probability ~2^-160.
- **R-6** **Every AC's `Falsify:` command must have been run and observed non-zero before
  the AC is reported green.** `ac-selftest.sh` mechanizes the 13 `forge` cases; the rest are
  recorded in the implementation report.
- **R-7** *(new in r3)* **A hole in an enforcement script is never closed by adding the name
  of the construct that exploited it.** If the fix is "also forbid `X`", the fix is wrong:
  state the property that makes `X` and its unlisted siblings fail together, and add `X`
  only as a witness in the corpus. r1 and r2 both violated this rule (§3.1.1); it is written
  down so round 4 cannot.
- **R-8** *(new in r4 — r3 findings 1 and 2)* **A lexical check on call sites never
  constrains what the permitted calls' operands resolve to.** Whenever this document says a
  check "pins" a value movement, ask the two follow-up questions before believing it:
  (i) *can the name being called be made to resolve to something else?* — closed by 9c and
  9b-range; (ii) *can the storage the permitted call reads be written from somewhere else?*
  — closed by check 14 and tested by INV-2c. A check that answers neither is a check on
  syntax that has been mistaken for a check on behaviour. Round 3 stated a property and
  still lost on both questions; the rule exists so round 5 asks them first.
- **R-10** *(new in r5 — r4 findings 3, 5, 6 and 11, which were one finding four times)*
  **Every observer must itself be observed, from outside, rejecting something — and the
  chain must be written down, including where it ends.** Four of r4's findings were defects
  in the *thing that watches*: a sentence asserting that a degenerate script could not print
  its own evidence; a probe read from the wrong signal; class counts presented as an observed
  reproduction; obligations stated as *"cannot be dropped quietly"* with nothing detecting
  the drop. The rule has three parts.
  **(i)** For every artefact this document treats as evidence — a script, a probe, a
  handler obligation, a count — name the thing that would go red if the artefact were
  replaced by a stub, and make that a mutant with a `killed-by` cell.
  **(ii)** A number printed as *"the output of a command a reviewer can run"* must have been
  run **in the round that prints it**. A number carried from the previous round is not an
  observation (`AGENTS.md` §5), and this document has now shipped a stale one twice.
  **(iii)** Where the chain stops, say so in §8 in one sentence, naming the artefact that
  nothing watches. R-9 is the special case of (i) for sweep columns; R-10 is the general
  form, and §5.0.3 and AC-18 observations 7–9 are its mechanization.
- **R-11** *(new in r6 — r5 finding 1)* **An attacker may branch on the existence of the
  observer. A check whose region is stated by exclusion is a check with a hole in it.**
  R-9 and R-10 are about *breaking* the observer; this is about *detecting* it. Every
  instrument in this document runs on a **local chain**, so an implementation that reads
  `block.chainid` is honest exactly where it is watched. The rule has three parts.
  **(i)** In any file this document pins, the **execution context is closed**: the code may
  not learn which chain, block or transaction it is running in, except for the one value a
  named contract change requires and only in the range that change names (§4.5.6a's P6 for
  `RecknZkEscrow.sol`; 15c-iii / 15g-iv / 15e for `RecknVerdictVerifier.sol`). A ban on the
  *token* is not the rule — the rule is that the category is closed, and the token list is
  the error message (R-7).
  **(ii)** **A region defined as "everything outside X and Y" is admissible only if X and Y
  each have their own pin.** Round 5's 15e was defined outside the `constructor` and
  `verifyVerdict` ranges, 15c pinned one of them, and nothing pinned the other; that unpinned
  region is where the backdoor lived. Whenever a sub-check is written by exclusion, list the
  excluded regions and name the sub-check that pins each.
  **(iii)** **An LHS-only pin is not a pin.** 15d, check 8 and check 14 all enumerated
  assignment *targets*; the address a contract dispatches to, and the address it pays, are on
  the *right* of the `=`. Ask of every "this check pins X" sentence: *does it constrain what X
  is set to, or only that X is what was set?* Where the answer is "only the latter" and the
  document nevertheless claims the former, the sentence is corrected (INV-2's *"Named limit,
  corrected in r6"*) or the clause is added (15g-iii, check 8's RHS) — **and where neither was
  done in this round, it is an open question with the founder, not a silence** (OQ-10).
  R-5 is the special case where the constant is an address; R-11 is the case where the
  constant is the environment itself, and it is worse, because the fuzz draws it every run and
  the mutant is honest each time.
- **R-9** *(new in r4 — r3 finding 3)* **A mutant that breaks `setUp` is not a sensitivity
  column.** Any matrix whose columns are mutants must assert, per column and before reading
  it, that the harness itself still runs — otherwise "every test failed in some column" is
  satisfied by a column in which every test failed for the same irrelevant reason. §5.4a is
  this rule's mechanization; the general form is: **a criterion that is satisfied by
  breaking the thing that observes it is not a criterion.**

---

## 7. Judge-facing surface

003 owns the **machine-checked artefact**. `reckn-demo` owns the pixels. The contract
between them is the JSON below; `reckn-demo` may render it however it likes and must not
hand-edit it.

### 7.1 `docs/gauntlet.json` — schema `reckn/gauntlet/v5`

**The heading and the `schema` field disagreed until r6** (the heading said `v3`, the document said `v4`) — a one-word drift of exactly the kind GC-1…GC-19 exist to prevent, in the one place no check was looking. Both now read **`v5`**, and r6's changes to this object are the reason for the bump: `contract.verifier_sp1_verifier`, `base_measurement.verifier_constructor_source`, `base_measurement.no_keys`, and two `enforcement` rows instead of one.

```json
{
  "schema": "reckn/gauntlet/v5",
  "generated_at": "2026-09-0?T??:??:??Z",
  "commit": "<git rev-parse HEAD>",
  "base_commit": "<docs/gauntlet.base.json .base_commit>",
  "tier": "local-foundry",
  "enforcement": {
    "script": "scripts/no-keys.sh",
    "checks": 15,
    "files": [
      "zk-verdict/contracts/src/RecknZkEscrow.sol",
      "zk-verdict/contracts/src/RecknVerdictVerifier.sol"
    ],
    "not_covered": [
      "the deployed verifier's bytecode (an escrow may be constructed with any address — G-29)",
      "which address a deployment passed to either constructor (read on-chain by deployment-check parts 2 and 5, not by any check here)",
      "the SP1 verifier the verifier file calls into",
      "what the proof means (the guest — N-2, task 008)"
    ]
  },
  "base_measurement": {
    "pre_existing_tests": "<{P}>",
    "pre_existing_tests_recorded_as": "id set in docs/gauntlet.base.json (AC-17 asserts the subset; this field is its cardinality only)",
    "honest_scope": ["<sha256>", "<sha256>"],
    "binding_preimage_source": "<file:line>",
    "public_values_source": "<file:line>",
    "verifier_body_source": "<file:line>",
    "verifier_constructor_source": "<file:line>",
    "no_keys": { "checks": "<int|null at the base commit>", "targets": ["<paths the base script derives>"] }
  },
  "contract": {
    "name": "RecknZkEscrow",
    "address": "0x...",
    "code_hash": "0x...",
    "verifier": "0x...",
    "verifier_sp1_verifier": "0x...",
    "verdict_program_vkey": "0x...",
    "refund_delay_seconds": 86400,
    "min_refund_delay_seconds": 3600,
    "max_refund_delay_seconds": 2592000
  },
  "fuzz": { "runs": 256, "invariant_runs": 256, "invariant_depth": 32 },
  "proving": {
    "predicate_guest_wrap_seconds": 34,
    "predicate_guest_source": "zk-verdict/README.md:97",
    "reexec_guest_seconds": null,
    "reexec_guest_source": null
  },
  "keys_published": [
    { "role": "BUYER",    "address": "0x...", "private_key": "0x..." },
    { "role": "SELLER",   "address": "0x...", "private_key": "0x..." },
    { "role": "KEEPER",   "address": "0x...", "private_key": "0x...",
      "note": "the party a competing design would make the resolver" },
    { "role": "DEPLOYER", "address": "0x...", "private_key": "0x..." },
    { "role": "STRANGER", "address": "0x...", "private_key": "0x..." }
  ],
  "signed_rows": [],
  "sweep": {
    "gauntlet_tests": 46, "killed": 45, "exempt": ["test_AC19_G37_lookalike_code_hash_differs"],
    "columns": 29, "excluded_columns": ["M-34"], "probe": "SweepProbe_*:test_probe_setup_ok",
    "probe_contracts": 4, "probes_excluded_from_column_read": true,
    "control_suite": "<{S}>"
  },
  "rows": [
    { "id": "G-03", "class": "theft", "actor": "SELLER",
      "method": "settleWithProof",
      "precondition": "real verifying proof bound to a different deal",
      "expected": "revert:BindingMismatch",
      "observed": "revert:BindingMismatch",
      "status": "AS_SPECIFIED",
      "test": "testFuzz_AC06_G03_foreign_binding_reverts",
      "check": null },
    { "id": "G-39", "class": "enforcement", "actor": "anyone with commit access",
      "method": "constant-address branch spliced into RecknVerdictVerifier.verifyVerdict",
      "precondition": "honest escrow, honest verifier address, one extra line of source",
      "expected": "build fails: no-keys.sh check 15",
      "observed": "build fails: no-keys.sh check 15",
      "status": "AS_SPECIFIED",
      "test": null,
      "check": "no-keys.sh check 15, sub-checks 15c/15d (M-51, E-19)" },
    { "id": "G-40", "class": "enforcement", "actor": "anyone with commit access",
      "method": "chain-id branch in RecknVerdictVerifier's constructor",
      "precondition": "honest escrow, honest verifier address, honest behaviour on this chain",
      "expected": "build fails: no-keys.sh check 15g",
      "observed": "build fails: no-keys.sh check 15g",
      "status": "AS_SPECIFIED",
      "test": null,
      "check": "no-keys.sh check 15, sub-check 15g (M-57, E-20)" }
  ],
  "acceptance": [
    { "id": "AC-06", "kind": "forge", "tests_expected": 2, "tests_ran": 2, "passed": 2 }
  ],
  "totals": {
    "rows": 40, "theft": 21, "authorized": 7, "disclosed": 10, "enforcement": 2,
    "as_specified": 40, "keys_that_helped": 0,
    "acceptance_criteria": 22, "gauntlet_tests": 46, "suite_tests": "<{S}>",
    "mutants": 60, "mutants_killed": 59, "control_survived": true
  }
}
```

- `status ∈ {AS_SPECIFIED, DEVIATED}`. Every `rows[]` entry carries **both** `test` and
  `check`; exactly one of them is non-null. Rows of class `enforcement` have `test: null` and
  a non-empty `check`; every other class has a `test` and `check: null`. GC-16.
- **`enforcement` (new in r5)** publishes the *region* the build condition covers and, in
  `not_covered`, the three things it does not. A judge reading `Addresses that helped: 0`
  should be able to see, in the same artefact, which files that claim was checked over —
  and which files it was not. `checks` must equal the number in `no-keys.sh`'s own
  `checks: N/N passed` line, and `files` must equal the targets that script derives.
- **`base_measurement` (new in r5)** mirrors `docs/gauntlet.base.json` (§1.5.1) so that the
  judge-facing artefact records *what was measured, at which commit*, rather than a number
  whose provenance is a paragraph. `<{P}>` and `<{S}>` are substituted at generation time;
  they are never typed.
- `contract.code_hash` is `extcodehash(escrow)` read on the local chain. It is **part 1 of
  the five-part deployment check** (§2.3 A); without it the check is unperformable, which is
  why GC-7 fails on an empty or missing value and M-45 exists.
- **`contract.verifier_sp1_verifier` (new in r6 — r5 finding 1)** is
  `RecknVerdictVerifier(verifier).verifier()`, read on the local chain. It is **part 5** of the
  same check, and it exists because part 2 compares one address that hides a second. GC-7
  fails on an empty or missing value, exactly as it does for `code_hash`; **M-45 is the mutant
  that witnesses GC-7's non-empty assertion exists at all**, and it is not duplicated per
  field. **Tier:** on this document's local chain the value a seller compares it against is
  the SP1 verifier the demo itself deployed, not a canonical mainnet gateway (§2.3 A part 5),
  and the artefact must not be read as evidence about any other chain.
- `keys_that_helped` is **computed**: the number of theft rows whose `observed` differed
  between a key-holding actor and a fuzzed stranger. Non-zero ⇒ `gauntlet.sh` exits
  non-zero.
- `signed_rows` is the list of row ids exercised by a **real signature** from a published
  key (OQ-1). It is `[]` unless OQ-1's anvil mode is built; §7.2's third money-shot line is
  derived from its length and `gauntlet.sh --check` fails if the printed number and
  `len(signed_rows)` disagree.
- `sweep.exempt` mirrors `SWEEP_EXEMPT.txt`; `len(exempt) ≤ 2` and
  `killed + len(exempt) == gauntlet_tests` are both asserted (GC-13, AC-21).
- **`sweep.excluded_columns` and `sweep.probe` are new in r4** (r3 finding 3).
  `excluded_columns` must equal §5.4a's pinned list exactly, **`len(excluded_columns) ≤ 1`**
  (r5, r4 finding 9), and `columns` must equal `T_beh − len(excluded_columns) + 5` (AC-13
  check 14). A column that was dropped at runtime rather than by the pinned list makes those
  two disagree; a sweep that stopped probing makes `probe` absent. **The judge can see how
  many mutants the matrix was allowed to ignore**, which is the same discipline `exempt`
  applies to tests. `probe_contracts` is the number of test-declaring contracts probed
  (§5.4a) and `probes_excluded_from_column_read` must be `true`, so a run that let the probe
  files into the column totals is visible rather than merely red.
- **`proving` (r2 finding 5 — round 2's OQ-6 asserted an absence the repo contradicts).**
  Two guests, two fields:
  - `predicate_guest_wrap_seconds: 34` — **a real measurement in this repo**, of the gnark
    wrap of the *predicate* guest (~15.9M constraints), source `zk-verdict/README.md:97`.
  - `reexec_guest_seconds: null` — the re-execution guest (`program-revm`, ~410k cycles of
    core proving before the same wrap, `CLAUDE.md:34-36`) has **not** been timed.
  - **Source re-verification, by content and not by line number (corrected in r5 — r4
    finding 2).** Round 4 wrote `sed -n '97p' zk-verdict/README.md | grep -q '~34 s'` into a
    file **task 008 edits**, so the citation would break on a line shift rather than on a
    change of fact. `gauntlet.sh --check` (GC-17) instead runs
    `grep -n '~34 s' zk-verdict/README.md`, requires **exactly one** match, and writes that
    match's line number into `predicate_guest_source`. Zero matches or two is a failure with
    the instruction attached (§1.5.3): re-read the file, and if the measurement is gone set
    `predicate_guest_wrap_seconds` to `null` — the gag rule stays either way. A quoted
    measurement whose source has moved is a stale number, and stale numbers are how
    "passing" gets written for things that were not run (`AGENTS.md` §5).
- **The gag rule, with a pattern (r2 finding 13 — round 2 said "greps for that claim" and
  gave no pattern).** While `proving.reexec_guest_seconds` is `null`, **nothing in the demo,
  the README, `gauntlet.json` or `gauntlet.sh`'s output may describe `MIN_REFUND_DELAY` or
  `refundDelay` as covering the proving time.** `gauntlet.sh --check` greps
  `gauntlet.sh`'s rendered stdout, `docs/gauntlet.json`, `README.md`, `SUBMISSION.md` and
  `zk-verdict/README.md` for this case-insensitive ERE and fails on any match:

  ```
  (cover(s|ed)?|enough (for|to)|long enough|accommodat(e|es)|exceed(s)?|suffic(ient|es))[^.]{0,60}(prov(ing|er)|proof generation)[ -]?time
  |(prov(ing|er)|proof generation)[ -]?time[^.]{0,60}(is|are) (cover|accommodat|account)
  ```

  The rule stays even though a number now exists, because the number is for the **wrong
  guest**. `MIN_REFUND_DELAY` is **not** changed on the strength of it (OQ-6).
- `acceptance[]` mirrors §5.1 and is what GC-3 compares against `--list`.

### 7.2 Terminal rendering

```
▶ KEY GAUNTLET — LOCAL FOUNDRY ONLY — throwaway development keys, no real funds
  escrow   0x...   codehash 0x...   verifier 0x...   vkey 0x...
  verifier -> SP1 verifier 0x...   (RecknVerdictVerifier.verifier(), read on-chain)
  refundDelay 86400s (min 3600 / max 2592000)
  Seller's FIVE-part deployment check:
    codehash · verifier · vkey · refundDelay · the verifier's own SP1 verifier
  Seller's terms check (AFTER the Funded event): token · amount · seller · deadline
  No-key build condition: 15/15 checks over BOTH settlement-path sources —
    RecknZkEscrow.sol and RecknVerdictVerifier.sol (which computes the verdict),
    including BOTH constructors, which choose the addresses everything else trusts.
    Neither file may read block.chainid, so neither can tell it is being tested.
    Not covered: the bytecode behind any *deployed* verifier address (G-29/G-39/G-40).

  role      address    private key (published)
  BUYER     0x...      0x...
  SELLER    0x...      0x...
  KEEPER    0x...      0x...   ← every competitor's trust root
  DEPLOYER  0x...      0x...
  STRANGER  0x...      0x...

  ID     class       actor      method                expected                  observed                  ✓
  G-01   theft       fuzzed     settleWithProof       revert                    revert                    ✓
  ...
  G-14   authorized  BUYER      refundAfterDeadline   buyer +1000e6             buyer +1000e6             ✓
  G-33   disclosed   BUYER      refundAfterDeadline   refund SUCCEEDS           refund SUCCEEDS           ✓
  G-34   disclosed   anyone     both exits            PayoutFailed, stuck       PayoutFailed, stuck       ✓
  G-36   disclosed   anyone     settleWithProof       settles, seller UNDERPAID settles, seller UNDERPAID ✓
  G-37   disclosed   BUYER      deploy look-alike     only codehash differs     only codehash differs     ✓

  40/40 rows as specified.
  Keys published: 5.  Addresses exercised: 5.  Addresses that helped: 0.
  Transactions signed by a published key: 0 — Foundry impersonates addresses (vm.prank);
  no published key signed anything. See §8 of docs/specs/003-key-gauntlet.md.
  Gauntlet tests: 46.  Failing under at least one mutant: 45.  Sweep-exempt: 1 (structural).
  Sweep columns: 29 admitted, 1 excluded (M-34 breaks setUp; it is AC-17's mutant).
  Suite: <S>/<S> passed (<P> pre-existing, measured at base commit <base_commit>).
```

**The money-shot's third line** is mandatory and its number is derived from `signed_rows`.
If OQ-1's signed mode is built it reads
`Transactions signed by a published key: 3 (G-03, G-13, G-14).`

**The money-shot's fourth line is new in r3.** It publishes the sweep split, so a growing
exemption list is on screen rather than in a file nobody opens. **The fifth line is new in
r4** and publishes the *column* split for the same reason: a matrix that quietly stopped
counting columns is the shape r3 finding 3 exploited, and it now has to say so on screen.

**The `verifier -> SP1 verifier` line, the fifth part of the deployment check and the two
constructor sentences are new in r6 (r5 finding 1).** They change **what the seller is told to
do**, which is why they are on screen and not only in §2.3: a four-part check that compares one
address while a second address decides where every proof is sent is a check a seller can pass
on a backdoored deployment. **The `block.chainid` sentence is the one that says the quiet part
out loud** — this gauntlet runs on a local chain, so *"an implementation that misbehaves only
elsewhere"* is the one attack the matrix cannot demonstrate failing, and it is therefore
excluded **structurally** instead (R-11, G-40).

**The banner's `No-key build condition` block and the closing `Suite:` line are new in r5.**
The first exists because r4 finding 1 was, in the end, a question about **where the claim was
checked**, and a judge who is told *"Addresses that helped: 0"* is entitled to see the region
that statement was verified over — **including the three things it does not cover**. A
disclosure the judge cannot see is not a disclosure, and this is the sentence that would have
had to be printed had 003 chosen option (b) and left the verifier out of frame; it is printed
anyway, next to the check that closed it. The second exists because the suite total is now a
**measurement**, not a constant, and a number on screen whose provenance is a paragraph is
the shape §1.5 exists to remove: `<P>` and `<base_commit>` are printed with it.

### 7.3 What `reckn-demo` must say out loud

- The surface grew from two functions to three, and `IERC20Min` from two declared functions
  to three, and why (`AGENTS.md` §0's requirement). **And the enforcement region grew from
  one file to two** — `RecknVerdictVerifier.sol` is where the verdict the escrow obeys is
  computed, and until r5 nothing checked it (§3.1.4, D-12); **the check over that file is task
  `008`'s, extended here** (§1.5.4). **And inside both files it now reaches the
  `constructor`s**, which is where the addresses everything else trusts are chosen.
- The tier: local Foundry / anvil. Not testnet, not mainnet.
- **`vm.prank` impersonates addresses; no key signed** (unless OQ-1 is built).
- The **ten** disclosed rows are shown, not hidden — G-18, G-23, G-27, G-28, G-29,
  **G-33, G-34, G-35, G-36, G-37** — and G-33 and G-36 in particular are shown as rows that
  **succeed**, not as reverts.
- **G-39 and G-40 are the two `enforcement` rows** and they are shown as **build failures**,
  not as EVM outcomes: in a tree where either splice exists, the escrow settles perfectly
  correctly by its own rules, and the only thing that says no is `no-keys.sh`. That is the
  honest shape of the central claim and it should be said in those words. **G-40 is the
  harder one to say and the more important** — in a tree containing it **every row of this
  gauntlet is green**, because it is honest on the chain the demo runs on and dishonest
  everywhere else. The demo cannot show that attack failing; that is why the **build
  condition**, not the matrix, is the load-bearing artefact for it (R-11).
- The seller has **two** checks at **two** times (§2.3), and the first now has **five** parts —
  the fifth reads the SP1 verifier that the verifier itself dispatches to. 003 makes them
  possible, not automatic.

---

## 8. What this does not prove

Written here so that no one has to say it under questioning.

- **A finite fuzz is not a proof.** AC-2/AC-3/AC-4/AC-7/AC-11/AC-12 sample the address
  space and the timeline; they do not establish caller-independence for all inputs. The
  mutation kill table (AC-14) and the kill matrix (AC-21) raise the cost of a degenerate
  implementation and of a degenerate test suite; they do not eliminate either. There is no
  formal verification here.

  **On the word "impossible."** This spec never says an *attack* is impossible, and never
  says anything is impossible "in principle". **The word is never used about an adversary
  anywhere in this document; its only substantive use is §5.0.1's claim about a script's exit
  condition** (`|found| == N ≥ 1`, checked twice) — *"the five gates make zero tests
  impossible; they do not make zero assertions impossible"* — restated once in the next
  bullet, and otherwise appearing only in appendix rows recording that a round **refused** to
  make such a claim. That is a property of how the word is used, not a list of places it
  occurs. **Round 5 wrote the location list** — *"appears only in §5.0.1 and in its
  restatement"* — **and it was false in the round that wrote it** (`grep -ni impossible`
  returns matches in the appendices too), which is the same defect as a drifting literal, one
  category up. No count and no location set is asserted here. Every
  claim about an adversary in this document is bounded by a named instrument and a named
  residual. **A fuzz in particular cannot find a backdoor keyed on a constant** — that is
  what the structural checks are for (R-5).
- **The AC gates read names and statuses, never bodies** (§5.0.1). The format makes *zero
  tests* impossible. It does **not** make *zero assertions* impossible. Round 2 claimed it
  did (AC-18 observation 5) and the claim was false. Two instruments cover the gap and only
  two: **AC-21**, which requires every gauntlet test to be observed *failing* against at
  least one mutant, and **AC-14**, which requires every forge AC to own at least one mutant.
- **AC-21 proves sensitivity, not correctness — and "sensitivity" is narrower than "has an
  assertion."** A test that observes the contract and asserts the wrong thing is red in some
  column and passes AC-21. So is a test with **no assertion at all** whose call simply
  reverts under some mutant (r3 finding 7). The `assertTrue(true)` stub is the one
  zero-assertion shape AC-21 catches. Up to two tests may be sweep-exempt and one mutant is
  excluded from the columns (`M-34`, §5.4a); both numbers are printed on screen (§7.2)
  rather than hidden, because **a criterion satisfied by breaking its own observer is not a
  criterion** (R-9), and round 3's version of AC-21 was exactly that.
- **The matrix is exhaustive with respect to §3.1's enumeration** (two exits, one inward
  site, one writing entry point, reentrancy, out-of-band value, deployment choice, token
  behaviour). It is **not** exhaustive with respect to attacks outside that frame —
  compiler bugs, EVM-level behaviour changes, and the SP1 verifier's own soundness are all
  outside it.
- **An attacker can branch on the fact that this gauntlet runs on a local chain, and no row
  of the matrix can show it failing** (R-11, G-40, r5 finding 1). Every behavioural instrument
  in this document — 38 EVM rows, 46 gauntlet tests, 29 sweep columns, every fuzz — runs on
  Foundry's local chain. A source that reads `block.chainid` is therefore honest exactly where
  it is observed. Round 5 shipped a check whose region was *"everything except the
  constructor"*, and the constructor is where `RecknVerdictVerifier` chooses the address every
  proof is dispatched to; the resulting splice was green in **every** instrument here. What
  closes it is **structural and only structural**: 15g pins that constructor to a copy of its
  own parameters, check 8 does the same for the escrow's, and check 7b closes the
  execution-context tokens so neither file can read the chain id at all. What this does **not**
  establish: that the two files contain no *other* constant-keyed branch. 7b removes the
  environment as a trigger; it does not remove a hard-coded token or counterparty address as
  one, and **check 14 pins assignment left-hand sides only, so `to = <constant>` inside
  `settleWithProof` under such a guard is not rejected by any check in this document**. That
  is **OQ-10**, open with the founder; it is named here rather than left for the next reader to
  find, and INV-2's *"Named limit, corrected in r6"* records that round 4 claimed a mechanism
  which does not exist.
- **The settlement path spans two contracts, and as of r5 the build condition spans both**
  (§3.1.4, §4.5.10, r4 finding 1; **the check over the second file is task `008`'s and 003
  extends it — §1.5.4**). Through round 4 this document checked one file while
  `settleWithProof` obeyed a struct computed in another — same directory, same audited
  deployment, one function — and a constant-address branch there was a **resolver over every
  funded deal**, rejected by nothing. Check 15 closes that region. What it establishes: in
  **the source in this repository**, `RecknVerdictVerifier` declares four top-level things
  and one function, and that function's body is two statements with no control flow and no
  `msg.sender` / `tx.origin` / `block.` token at all, so the struct it returns can only come
  from `abi.decode(publicValues, …)` after `verifyProof` did not revert — **and, as of r6,
  that the address `verifyProof` is dispatched to is the constructor's own parameter, because
  15g pins that constructor to two statements with no branch, no `block.` token and no
  literal**. What it does **not** establish, in the same breath:
  - **nothing about the bytecode behind any deployed verifier address.** An escrow can be
    constructed with any address; a rogue verifier built from other source is untouched by
    every check here. That is row **G-29**, and the seller's defence is part 2 of the
    deployment check (§2.3 A) — a human step, and comparing the address establishes only
    that this is *the address everyone uses*, not what it was compiled from.
  - **nothing about the SP1 verifier** the file calls into, which lives outside both checked
    files and outside this repository. Its soundness was already outside the frame and check
    15 does not narrow that.
  - **nothing about what the proof means.** N-2 and task `008`.
  - It is **lexical over source text**, like every other check in §4.5, and everything the
    next bullet says about bytecode applies to it word for word.
- **What `no-keys.sh`'s call-surface allowlist does and does not establish** (§3.1.2, §4.5).
  It establishes that every *call-shaped token* in `RecknZkEscrow.sol` is on a closed
  allowlist, that the file's top-level declarations are exactly four, and that `IERC20Min`
  declares exactly three functions. Consequently `approve`, `increaseAllowance`, `permit`,
  `Address.functionCall`, `payable(x).transfer`, `.call{value:}`, a `library`, a file-level
  helper, a function-pointer call and inline `assembly` all fail — and so does a construct
  nobody has enumerated, because the allowlist is closed over the syntactic category rather
  than over the vocabulary. It does **not** establish:
  - anything about the **compiled bytecode**. The check is lexical, over the source text of
    one file. A compiler or a library outside this file is out of frame.
  - that the enumeration **cannot grow**. An implementer who edits the allowlist in
    `scripts/no-keys.sh` and this document together can grow it. What is prevented is
    growing it *silently*; `AGENTS.md` §0 makes the edit a declared claim change. Round 1
    and round 2 both wrote the stronger sentence and both were wrong; it is not written
    here.
  - that a value movement expressed with **no call-shaped token at all** would be caught by
    checks 9/11/12/13/15. We know of no such construct in Solidity that reaches an ERC-20
    balance, but "we could not think of one" is not a proof and is not claimed as one.
  - **anything about the operands the permitted calls read.** This was round 3's actual
    hole, not a hypothetical one: `deals[victimId].seller = attacker;` inside `fund`
    contains no call-shaped token, passed all thirteen of round 3's checks, and made an
    honest proof pay an attacker (r3 finding 2). **Check 14 closes it by closing assignment
    targets**, and INV-2c tests the runtime statement. What check 14 still does not
    establish is that the assignments it *permits* are the right ones — `d.state` could be
    set in the wrong branch and it would not notice. That is what AC-3, AC-5, AC-7 and
    AC-11 are for.
- **What check 14 establishes and does not** (§4.5.6, INV-2c). It establishes that, in the
  source text of this one file, the only assignment targets are `deals[dealId]` in `fund`,
  `d.state` in the two exits, `to`, and locals of value or memory type; and that the four
  other source constructs that can write storage (`++`, `--`, `delete`, compound
  assignment) do not occur, with `assembly`'s `sstore` already closed by checks 6 and 13.
  It does **not** establish anything about the compiled bytecode, and it is an enumeration
  of **Solidity source constructs** — a future language version that adds a fifth way to
  write storage would need this enumeration re-opened, and this sentence is here so that a
  reader knows to check.
- **Foundry `vm.prank` impersonates an address without using its private key.** The 38 EVM
  rows demonstrate **address-level** behaviour (G-39 and G-40 are not EVM rows). Unless `signed_rows` is non-empty, no published
  key was exercised, and the money-shot says so (§7.2, r1 finding 8).
- **Token honesty is assumed, and the supported class is narrow.** INV-4/INV-6 hold for
  **exact-transfer** tokens (§1.3). A token that lies about balances can corrupt deals
  denominated **in itself**; INV-5 confines the damage to that token, and G-32 tests the
  confinement.
- **C-5 creates a permanent-lock residual for honest-but-inexact tokens** (r1 finding 6).
  An outbound-fee or rebasing token funds cleanly and then bricks **both** exits forever
  (G-34, G-35). This is asymmetric with the inbound case, which fails closed at `fund`
  (G-21) with no principal at risk. It is the price of INV-6's upper bound. **The upper
  bound's justification is the runtime one in §4.1 C-5** — an unbounded outward transfer is
  paid out of other deals' principal in the same token — **not** "it kills M-23" (r2
  finding 8). **And not the converse either** (r3 finding 4): round 3 asserted that AC-10
  kills M-23 *independently* of C-5's bound, which is false of the contract that is actually
  mutated, because C-5 is in it and reverts the over-payment before any invariant can see
  it. M-23 is therefore defined as the **compound** patch (over-pay **and** drop C-5 in that
  function).

  **And round 4's conclusion from that went one step too far, corrected in r5 (r4 finding
  10).** It wrote: *"C-5's bound is justified at runtime and **is not evidenced by a mutant,
  because C-5 masks the mutant that would evidence it**"* — an impossibility claim about the
  evidence, contradicted by this document's own §4.1, which already says that under `>=` an
  outbound-fee token *"would succeed while over-paying"*. C-5 masks over-payment originating
  in the **contract's own code**; it does **not** mask over-payment originating in the
  **token**. **M-50** is that unmasked mutant — C-5's `==` becomes `>=` in both exits, and
  against `OutboundFeeERC20` held by a handler carrying ≥ 2 deals in that token the escrow
  pays the fee out of the other deal's principal, breaking INV-4 — and AC-10's solvency
  invariant kills it. The honest statement is therefore: **M-23's shape is masked by C-5;
  M-50's is not, and M-50 is the evidence.**
  **003 does not close the residual**, and the honest gap list in `README.md` must say so
  (D-1).
- **C-5 cannot see the recipient's side** (r2 finding 3, row G-36). A token that debits the
  escrow by exactly `d.amount` and credits the destination less satisfies §1.3(a)(b)(c),
  passes C-5, and terminates the deal with the authorized party **underpaid**. §1.3(d) names
  the requirement the token must meet; the escrow has no way to check it, and a
  recipient-side balance check would not help because the recipient may move the tokens in a
  hook. **This is a disclosure, not a fix**, it is not created by 003, and the demo shows
  G-36 as a row that **succeeds**.
- **A buyer who picks the deployment picks the clock and the code** (r1 finding 7, r2
  finding 4; rows G-33, G-37). A buyer can deploy an escrow whose `refundDelay` is shorter
  than the proving time, fund it, take delivery and refund; and a buyer can deploy a
  look-alike whose `verifier`, vkey and `refundDelay` are all genuine and whose **bytecode
  is not**. The contract's `MIN_REFUND_DELAY` is **not** a defence against the first — a
  buyer deploying their own escrow chooses their own constant. The defence is the seller's
  **five-part** deployment check (§2.3 A: code hash, verifier, vkey, `refundDelay`, and the
  verifier's own SP1 verifier), and it is a human/off-chain check, not a mechanism. 003 makes
  it *possible* by printing all five values, including `contract.code_hash` and
  `contract.verifier_sp1_verifier`; it does not make it automatic. **Part 5's own limit is in
  §2.3(A): it compares an address, not a bytecode, and on this tier the comparand is the SP1
  verifier the demo itself deployed.**
- **The seller cannot check the terms before funding.** `d.token`, `d.amount`, `d.seller`
  and the deadline are first visible in the `Funded` event (§2.3 B). Round 2's capability
  table credited the seller with a pre-funding check of facts that do not exist yet; that
  row is corrected. The seller's protection against a hostile `d.token` (G-18, G-34, G-35,
  G-36) is to read the event and decline to start work — again a human step.
- **No claim that the settlement window "covers proving time" may be made** while
  `proving.reexec_guest_seconds` is `null` (§7.1's gag rule). The ~34 s at
  `zk-verdict/README.md:97` is real and is now carried in the artefact, but it measures the
  **predicate** guest's gnark wrap, not the re-execution guest that actually settles.
  Comparing it with `refundDelay` would be a tier violation of a different kind: the right
  number for a different question.
- **The post-deadline race is real.** After `fundedAt + refundDelay`, a late-but-valid
  `Reproduced` proof and a refund compete; whichever lands first wins, and both are
  authorized outcomes. There is no mechanism to prefer one, because every such mechanism
  confers authority over an already-funded deal's outcome (N-5). The demo must state this
  rather than imply proofs always win.
- **Payout liveness depends on the token** (INV-8, G-18, G-23, G-34, G-35). A blacklisting
  token can brick a payout to a specific address in either direction.
- **A fraudulent deployment settles fraudulently** (§2.3, G-29, G-37).
- **003 says nothing about predicate non-degeneracy** (N-8). Whether a predicate can be
  satisfied by a seller who does nothing is a property of the guest and the plan, frozen
  here by N-2.
  **`zk-verdict/README.md`'s Honest scope is the authority, and 003 states its relation to
  it by reference rather than by quotation (rewritten in r5 — r4 finding 2).** Round 4 wrote
  out the items — the in-guest precompile restriction, the `u64` verdict values with
  `u64_low` = limb 0 only and ≥ 2^64 truncated, the 1-CALL + 1-delta scale, the off-chain
  `state_root`↔header binding — and asserted they are *"exactly as true after 003 as before
  it"*. **Task `008` exists to change one of them**, and 003 runs after 008, so that sentence
  would have shipped as a false statement in a judge-facing document. The correct statement:
  **whatever those two blocks say at 003's base commit is exactly as true at the end of 003
  as at the start, and AC-16 is the instrument** — three-source, pinned to a git object, not
  to a literal (§1.5.1). 003 resolves none of those items and re-introduces none of them; it
  does not assert which of them are still there, because that is 008's outcome and 008's
  review, not this one's.
- **The chain of observers ends at `ac-selftest.sh`, and nothing in 003 watches it**
  (R-10(iii), AC-18, §5.0.3). Round 4 asserted that *"a script that ran nothing cannot print
  its evidence line"*; that was false, and two devices now make it true one level down — a
  **witness** `ac.sh` recomputes without running the script under test, and an **outside-in
  observation** in which `ac-selftest.sh` watches each harness script reject a sandbox it
  should reject. Neither device watches `ac-selftest.sh` itself. What bounds that is not a
  mechanism: the script is invoked **directly** by `gauntlet.sh` and by the founder, its
  evidence string is compared verbatim, and a version that fakes all nine observations is not
  an implementer *mistake* but a **deliberate fabrication of evidence**. **003 is not a
  defence against an implementer who fabricates evidence**, and it does not claim to be. The
  cheap accidental failure — a placeholder that was never finished — is what the two devices
  catch.
- **The base measurement is protected by its git history, and a rewritten history defeats
  it** (§1.5.1 rule 4, GC-15, r5 finding 2). Round 5 claimed *"the file is written once and
  only once"* because `--measure` refuses to overwrite; the laundering path is `rm`, and after
  a delete all three of the digest check's sources are re-derived from the softened tree and
  agree. What blocks the act now is an assertion over the file's history — tracked, exactly one
  `A`, no `D`, blob equal to the working tree — plus a clean-tree condition on `--measure`.
  **An implementer who amends or rebases the `D` away defeats all four**, and that is the same
  class as fabricating `ac-selftest.sh`: deliberate fabrication of evidence, which 003 does not
  defend against and does not claim to.
- **AC-17 pins the pre-existing tests by identity, which is not the same as by meaning**
  (r5 finding 3). The recorded id set makes deleting a pre-existing test visible. It says
  nothing about whether a pre-existing test still asserts what its name says: a body may be
  gutted in place and AC-17 will not notice, because AC-21's sensitivity sweep covers the
  **46 gauntlet** tests and not the pre-existing suite. That boundary is deliberate — the
  pre-existing suite belongs to 008 and to the tasks before it — and it is stated so that the
  subset assertion is not read as more than it is.
- **The witness proves the patches were applied, not that the sandboxes were run**
  (§5.0.3). `{W14}` and `{W21}` are digests over patched sources, recomputable by `ac.sh`
  from the committed patch files; an `echo` cannot produce them without doing the patch work.
  They say nothing about whether `forge` ran or a status was read — that is AC-18
  observations 7 and 8, and the two halves are recorded separately here so that neither is
  read as covering the other.
- **Tier.** Everything above is Foundry and local anvil. Nothing here is evidence about a
  testnet or mainnet deployment (`AGENTS.md` §5).

---

## 9. Implementation obligations (documentation moves in the same commit)

`AGENTS.md` §0 requires that a change to the claimed surface updates the claim everywhere
in the same change. Each `file:line` below was re-opened 2026-09-04 for round 3; the two
that r2 corrected are corrected again where r2's own replacement was off (D-4).

| ID | file:line | today | obligation |
|---|---|---|---|
| D-1 | `README.md:566-571` | "**`RecknZkEscrow` has no timeout.** … the first ETHOnline task" | Replace with the closed state: permissionless post-deadline refund, the window is an immutable construction parameter, and the residuals (post-deadline race, token-dependent payout liveness, **G-33 short-window deployment**, **G-34/G-35 inexact-token lock**, **G-36 recipient-fee underpayment**, **G-37 look-alike bytecode**) are stated. **Do not delete the bullet silently** — the gap list must show a gap closed *and* the new residuals opened, with a link to this spec |
| D-2 | `CLAUDE.md:46-49` | "**`RecknZkEscrow` に timeout が無い**… タスク 001。**未解決**" | Rewrite as closed by 003, with the date and the AC that proves it |
| D-3 | `AGENTS.md:70` | task table row `001` | Mark folded into 003 per the 2026-09-04 ruling; keep the row so the history is legible |
| D-4 | `README.md:550-551`, `README.md:706` | "`forge test`: **12\npassing**" (the string spans two lines), "— 12 tests" | Update from the **actual** `forge test` output — **AC-17's number, `46 + {P}`, read from the run, not from this document** (`AGENTS.md` §5: do not estimate). **Round 4 wrote "expected 56" here while AC-17 pinned 58, and both are now wrong for a third reason: 008 changes `{P}` (r4 findings 7 and 2). D-4 is the one documentation obligation with no mechanical check behind it, so the literal it names would have reached the judge-facing README unopposed — hence no literal.** Line numbers re-verified: round 2 cited `:669`; r2's correction said `:700`; both are wrong. `grep -n "12 tests" README.md` → `706`, run 2026-09-04, and the first site spans `:550-551` rather than `:551` alone. |
| D-5 | `zk-verdict/README.md:234-237` | the two-bullet function list | Add `refundAfterDeadline(dealId)` — permissionless, pays the buyer, only after the window. **Do not touch lines 154-164 or 208-221** (AC-16), and **do not touch line 97** (OQ-6's source) |
| D-6 | `zk-verdict/README.md:239-243` | "Tested (`RecknZkEscrow.t.sol`): …" | Add the gauntlet: keys published, matrix size, the one-command runner, and the `vm.prank` caveat |
| D-7 | `STATUS.md:15` | 撤退可能点 wording, already aligned with `AGENTS.md` §7 | **Round 2 also cited `STATUS.md:39-40` as holding a pointer to a `docs/specs/001-keyless-timeout.md`. It does not: `:39-40` is the review table, and the string `001-keyless-timeout` occurs nowhere in `STATUS.md` (`grep -rn "001-keyless-timeout" STATUS.md docs`, re-run 2026-09-04 — the only occurrences are inside this spec and inside `docs/reviews/003-spec-r2.md`). There is nothing to fix there.** The real obligation is to add the 003 round-3 row to the review table and record the surface change |
| D-8 | `SUBMISSION.md:156-160` | ZK settlement bullet | Add the gauntlet and the timeout; keep the SVM/EVM honest-scope sentences intact |
| D-9 | `README.md:67` | "the enumerated `fund` / `settleWithProof` / `refundAfterDeadline`" | Already correct — add that all three must now be **present**, not merely permitted (two-sided check 2), and that the value exits are pinned by a **closed allowlist over the whole file**, not by a list of forbidden method names |
| D-10 | `AGENTS.md` §0 | "列挙された関数面 … を増やすなら" | The permitted function set does not change, but the **script gains checks 5–15, one output line, and a scan region that is the whole file for checks 9/11/12/13**; and `IERC20Min` gains one declared function (`balanceOf`, C-4). Record all of that in the same commit, per §0's own instruction, and state that the interface was **not** changed (N-9) and that the scope widening is a **tightening** (§4.5) |
| **D-11** | **`zk-verdict/scripts/surfaces.pinned`** (introduced by task `008`; **path corrected in r5 — round 4 wrote `scripts/surfaces.pinned` and ran `ls scripts/`, a directory 008 never uses.** `ls zk-verdict/scripts/` → `zk-e2e.sh` only, run 2026-09-04 — §1.5.2) | pins `sha256(zk-verdict/contracts/src/RecknZkEscrow.sol)` as a build condition | **003 necessarily breaks this pin** (C-1…C-7). **Re-pin it in the same commit that changes the contract** — not a follow-up commit. The re-pin is a **copy of the value `surfaces.sh` prints on failure**; **no step of this spec asks anyone to compute a digest by hand**, and no agent recomputes it in another way. If 008 landed without `surfaces.pinned`, D-11 is a no-op and the implementation report says so explicitly. **`docs/specs/008-*` is not edited** (see below) |
| **D-12** | `AGENTS.md` §0 (the enforcement paragraph) and `CLAUDE.md`'s 中心主張 block | both name `RecknZkEscrow.sol` as **the** file the claim lives in | **New in r5.** The claim is now enforced over **two** files: `zk-verdict/contracts/src/RecknZkEscrow.sol` **and** `zk-verdict/contracts/src/RecknVerdictVerifier.sol`, whose one declared function `verifyVerdict` is the second enumerated surface (check 15, §4.5.10). Record the second file, the reason (settlement authority is computed there — §3.1.4), and the three things check 15 does **not** cover (§8). **This is a widening of what the build condition asserts, so §0's rule applies even though it is a tightening of what is permitted**: the same commit updates `AGENTS.md` §0, `scripts/no-keys.sh`, this spec, the money-shot and the demo script. **Relaxing check 15 later is a founder call, not an implementer fix.** **Amended in r6, two ways.** (i) **The declaration may already exist**: task `008` introduces the check over that file (§1.5.4), so if 008 already named the second file in `AGENTS.md` §0, D-12 is an **amendment** rather than the first declaration — the same no-op discipline D-11 has — and the implementation report says which case held, quoting `docs/gauntlet.base.json.no_keys`. (ii) **What 003 declares in either case** is the part it owns: the `constructor` closure (15g), the escrow-side clauses (check 8's right-hand sides, check 7b), and the **fifth part of the seller's deployment check**, which changes what the seller is told to do and is printed in the money-shot (§7.2) |

| ID | file:line | change |
|---|---|---|
| **S-1** | `zk-verdict/scripts/zk-e2e.sh:84-85` | `( cd "$contracts" && forge test -vv 2>&1 ) \| grep -E '…' \|\| true` discards `forge`'s exit status (`set -euo pipefail` does not survive the trailing `\|\| true`; verified 2026-09-04). Capture the status and exit non-zero on failure. **One line's worth of change**, and it is the only thing that makes AC-17's second command evidence rather than decoration. Nothing else in that script changes |

**Not to be edited by any agent:** `docs/ethonline-2026/PLAN.md:17-18, 27, 33` state the
two-function surface and the open timeout gap. That file is a founder document
(`AGENTS.md` §8). After 003 lands it will be stale. **Report the staleness to the founder;
do not fix it.** The same applies to `docs/ethonline-2026/DISCLOSURE.md`,
`docs/specs/004-*`, `docs/specs/008-*` and everything under `docs/reviews/`.

### 9.1 Suggested part split for `reckn-codex-impl`

Each part must end green. Do not merge them into one Codex call.

0. **P0 — the base measurement, before anything else.** On the tree exactly as 008 left it,
   **committed and clean**, and **before a single 003 edit**, run
   `bash scripts/gauntlet.sh --measure` and commit `docs/gauntlet.base.json` **in its own
   commit, which must be the only commit that ever adds that path** (§1.5.1 rules 2 and 4).
   Everything downstream substitutes `{P}` / `{S}` from it and `ac.sh` refuses to run without
   it. **`--measure` refuses if the file already exists and refuses if `git status
   --porcelain` is non-empty**, so P0 happens once and on a tree whose `base_commit` really
   describes it.
   **Never delete this file.** If it was somehow written after an edit, **stop and return to
   the founder** (`AGENTS.md` §7); deleting and re-measuring is the laundering path r5 finding
   2 named, and GC-15 will see the `D` in the log for the rest of the project even if the
   intent was innocent. The report pastes the file **and** the output of
   `git log --diff-filter=A --oneline -- docs/gauntlet.base.json` (exactly one line).
   **Read `no_keys` before starting P3**: it decides whether 003 extends 008's check over
   `RecknVerdictVerifier.sol` or introduces it, and its third case is a founder stop (§1.5.4).
   Ends green on `bash scripts/gauntlet.sh --measure && test -f docs/gauntlet.base.json`.
1. **P1** — C-1…C-7 in `RecknZkEscrow.sol` + minimal adjustment of the four existing
   `RecknZkEscrowTest` tests to the new constructor. **The same commit re-pins
   `zk-verdict/scripts/surfaces.pinned` (D-11, §1.5.2) by copying the digest `surfaces.sh`
   prints**; the contract change and the pin never live in different commits. **No line of
   `RecknVerdictVerifier.sol` changes in this part or in any other** — 003 checks that file,
   it does not edit it. Ends green on `forge test`.
2. **P2** — `scripts/ac.sh` + `scripts/ac-selftest.sh` (§5.0/§5.1). **Built before any
   gauntlet test exists**, and its first demonstration is that every `forge` AC is
   **red** (AC-18 observation 1). Ends green on AC-18's control (observation 6) only after
   P3/P4.
3. **P3** — `scripts/no-keys.sh` checks 5–**15** (with check 15 **extended from 008's or
   introduced in full**, per `no_keys` — §1.5.4), two-sided check 2, **7b**, **check 8's
   right-hand-side clause**, **15g**, the **one-pass** stripper and the three derived texts in
   the order §4.5.1 fixes, the `checks: 15/15 passed` line, `scripts/no-keys-selftest.sh` with
   the **two-file** sandbox layout, the **20** source-text mutants and the **23**-entry exit
   corpus with its **four** controls. Ends green on AC-0, AC-1.
   **This part carries the round-3 blocker, the round-4 BLOCKER 1 and the round-5 BLOCKER 1;
   do it before the test-writing parts** so that all three live-tree falsifiers can be run
   early: apply M-41 to `RecknZkEscrow.sol` → AC-0 and AC-1 red; apply **M-51** to
   `RecknVerdictVerifier.sol` → AC-0 and AC-1 red; and apply **M-57** (the constructor
   chain-id branch) → **AC-0 and AC-1 red and every other AC green** — assert the second half
   too, because it is what makes G-40 an `enforcement` row rather than an EVM one (R-11).
   **Run E-17 and E-18 against whatever stripper you wrote before writing anything else in
   this part**, and **E-21 and E-22 immediately after**: a two-pass stripper passes the other
   twenty-one corpus entries and hides a full drain, and a one-pass automaton that ignores
   `\"` passes twenty-two of them and hides the same drain (§4.5.1).
4. **P4** — mocks (including `RecipientFeeERC20`) + `KeyGauntlet.t.sol` +
   `KeyGauntletStructural.t.sol` + `SWEEP_EXEMPT.txt`. Ends green on AC-5, AC-8, AC-9,
   AC-12, AC-19, AC-20 and AC-10's unit half.
5. **P5** — `KeyGauntletFuzz.t.sol` + `KeyGauntletInvariant.t.sol`. Ends green on AC-2,
   AC-3, AC-4, AC-6, AC-7, AC-10, AC-11.
6. **P6** — `test/mutants/M-*.patch` + `scripts/mutation-kill.sh`, with the shared sandbox
   builder, **§5.0.3's witness `{W14}` and `ac.sh`'s independent recomputation of it**, and
   **AC-18 observations 7, 8 and 9** with mutants M-52, M-53, M-56. Ends green on AC-14 and
   on AC-18 in full. **Record the measured wall-clock** in
   the implementation report and in `gauntlet.json.durations`; do not estimate it here — a
   forced `forge build` of this project measured ~0.9 s on 2026-09-04, but the sandbox path
   has not been run and this spec makes **no** claim about the total.
7. **P7** — `test/mutants/SW-*.patch` + `scripts/degeneracy-sweep.sh` reusing P6's sandbox
   builder, **including §5.4a's per-test-contract `SweepProbe_*` generator, the pinned
   exclusion list (cap 1), the per-column probe gate read from parsed JSON, and the
   `^SweepProbe_` exclusion from every column read**. Ends green on AC-21. **Run AC-21's
   Falsify (a) and observe it non-zero before reporting AC-21 green** (R-6) — under round
   3's design it exited zero, which is the whole of r3 finding 3. **Also run Falsify (e)**:
   with the probe contracts left in the column read the control total is not `{S}` and the
   evidence comparison fails; observe that before believing the exclusion is implemented.
   If M-33's probe fails, resolve it as §5.4a specifies (move the fixture settlement out of
   `setUp`), and report it either way. **Expect this part to fail first**: it is designed to
   find tests written in P4/P5 that assert nothing, and finding some is the intended outcome,
   not an error in the sweep.
8. **P8** — `scripts/gauntlet.sh`, `docs/gauntlet.json`, the digest check **and GC-15's four
   history assertions**, `contract.verifier_sp1_verifier` read on-chain (part 5), the gag-rule
   grep, S-1. Ends green on AC-13, AC-15, AC-16, AC-17. **Run AC-16's `Falsify` branch (c) —
   commit a softened block, `git rm` the base file, re-measure, commit — and observe it
   non-zero at GC-15 before reporting AC-16 green** (R-6). Under round 5's text this branch
   was claimed to be blocked by `--measure`; it was not.
9. **P9** — D-1…**D-12**. Ends green on `bash scripts/ac.sh --all` from a clean tree.

---

## 10. Open questions

Genuinely undecided. **Do not guess; bring these back rather than inventing an answer.**

- **OQ-1 — Do the published keys have to actually sign?** (r1 finding 8.) The 38 EVM rows
  run in Foundry, where `vm.prank` impersonates an address **without using its private key**.
  §8 and the money-shot are already honest about it, so **the spec is correct either way**;
  the question is only whether to buy the extra credibility.
  *Recommendation:* keep the full matrix in Foundry (fast, fuzzable, exhaustive) and add an
  `anvil` mode to `scripts/gauntlet.sh` that really signs three headline rows (G-03, G-13,
  G-14) with the published keys, recording them in `signed_rows`. Cost: the anvil path
  needs the SP1 verifier and the fixture deployed locally, which `zk-e2e.sh` already does
  for the settle path but not for the gauntlet — roughly one implementation part.
  **Founder call.**
- **OQ-2 — Should `gauntlet.json` name the optimistic path as out of scope?** The claim is
  about `RecknZkEscrow`. `contracts/RecknEscrow` has a bonded resolver **by design** and is
  not in the demo (`AGENTS.md` §8). One honest line ("`RecknEscrow` (optimistic, not
  demoed) does hold keys by design") pre-empts the question but re-introduces the commodity
  path into the judge's frame. **Founder call.**
- **OQ-3 — What is the deployed `refundDelay` for the demo?** The contract's bounds are
  fixed here (1 hour … 30 days). 24 h reads as realistic but forces a `vm.warp` on screen;
  1 h reads as a toy. The specification does not depend on the choice; `gauntlet.json`
  prints whatever is used. **Related but separate from OQ-6.**
- **OQ-4 — Should the seller have an on-chain acceptance step, and is it worth a fourth
  function?** *(Re-posed in r3 — r2 finding 9. Round 2 asked this on a false premise.)*

  **What r3 corrects.** Round 2 wrote that seller-acceptance "is a key-shaped thing" and
  therefore that closing G-33 "changes the central claim's shape and needs a new task". That
  is wrong. `AGENTS.md` §0's key is an actor who can **decide an outcome** — owner, admin,
  resolver, pause, upgrade. A seller `accept(dealId)` step is **consent to enter, not
  authority to decide**: a seller who never accepts leaves the deal in `Funded` until the
  deadline and the buyer is refunded, which is exactly the outcome available today when the
  seller does nothing. It moves no value to a destination the deal did not already fix and
  it gives no one a choice between two outcomes. N-5 is narrowed accordingly.

  **So the question the founder is actually being asked is about cost and demo surface, not
  about the claim.** Adding `accept(dealId)` would:
  - make the enumerated surface **four** functions, which is a declared claim change under
    §0 (`AGENTS.md`, `scripts/no-keys.sh`, the demo script, `README.md`) — and "three
    functions, all permissionless, no keys" is currently a demo asset;
  - add a fourth state and a fourth set of matrix rows (what happens to a never-accepted
    deal, to an acceptance after the deadline, to an acceptance of a deal in a hostile
    token);
  - buy **one thing that does not exist today**: a recorded, on-chain point at which the
    seller attests to having read the §2.3(B) terms. That is a demo asset (the timeline gets
    a seller-side event), not a new guarantee.

  **What it does *not* buy, corrected in r4 (r3 finding 8).** Round 3's third bullet claimed
  acceptance would *"close G-33 by letting the seller decline a short clock before doing the
  work"*. **It would not**, and the founder must not price it against that. `refundDelay` is
  a `uint64 public immutable` construction parameter (C-2), so it is readable **before any
  deal exists** — it is already part 4 of the deployment check the spec tells the seller to
  perform (§2.3 A). A seller who wants to decline a short clock declines by not working,
  with or without an on-chain step. And acceptance does **not** gate `refundAfterDeadline`:
  a seller who accepts and then delivers is refunded out from under exactly as before. The
  benefit for G-33 is **zero**.

  *Recommendation:* **not in 003** — it is outside the scope line (G-33 has a true expected
  result today, so no matrix row is missing an answer), and the surface count is worth more
  during the event than the closure of a row the gauntlet already displays honestly.
  **Founder call, on cost and demo surface.** If the answer is yes, it is a new task with a
  declared surface change, not an edit to 003.
- **OQ-5 — Should `scripts/no-keys.sh` gain a target/path argument at all?** (r1 finding
  12.) 003 **does not add one** (N-9): `AGENTS.md` §0 reserves that script's semantics
  to the founder, and "no-keys.sh passed" must keep meaning one specific file. r2 confirmed
  this is the right call. The sandbox-layout self-test achieves the same coverage with zero
  interface change (§4.5.9, verified 2026-09-04). **Returned to the founder as a question,
  not implemented:** is a positional override wanted later (e.g. for CI matrix runs), and
  if so, with what guarantee that an override's output can never be pasted as evidence for
  the claim?
- **OQ-6 — What proving time should `MIN_REFUND_DELAY` be compared against?** *(Corrected
  in r3 — r2 finding 5. Round 2 asserted "there is no measured Groth16 proving wall-clock
  anywhere in this repo (grepped 2026-09-04)". **That assertion was false and is deleted.**
  It is the mirror image of the failure `AGENTS.md` §5 warns about — a grep reported without
  the grep having found what is there.)*

  **What exists.** `zk-verdict/README.md:97`: *"a **real Groth16 proof** of the verdict was
  generated on CPU (the gnark prover, ~15.9M constraints, **~34 s** once the artifacts are
  local)"*. Re-verified 2026-09-04 (`grep -n "34 s" zk-verdict/README.md` → `97`). That is a
  real measurement, made in this repo, of the **predicate guest's** gnark wrap.

  **What does not exist.** A wall-clock for the **re-execution guest** (`program-revm`,
  ~410k cycles of core proving before the same wrap) — the guest whose proof actually
  settles a deal. `gauntlet.json` carries `predicate_guest_wrap_seconds: 34` with its source
  and `reexec_guest_seconds: null`, and the gag rule (§7.1) stays because the number that
  exists is for the wrong guest.

  **No number in this spec is used to set `MIN_REFUND_DELAY`.** Its only justification
  remains INV-10 (block-timestamp hygiene), and it is neither raised nor lowered on the
  strength of a measurement of a different guest.

  **Founder call:** is a `ZK_FRESH=1` run (SP1's ~6.2 GB artifacts) worth making during the
  event to measure the re-execution guest, and if the measured time exceeds one hour, does
  `MIN_REFUND_DELAY` change — noting that raising it does **not** close G-33, because a
  buyer deploying their own escrow picks their own constant?
- **OQ-7 — new in r3. Is the exemption budget in AC-21 the right shape?** AC-21 permits at
  most **2** sweep-exempt tests, confined to one file, printed on screen. The number is a
  budget, not a derived quantity: it is small enough that widening it is a founder decision
  and large enough for the one test that is expected to need it
  (`test_AC19_G37_lookalike_code_hash_differs`). If the founder would rather have **0**
  exemptions and accept that G-37 is demonstrated by `gauntlet.sh`'s printed code hash
  instead of by a forge test, say so and the row moves out of AC-19 into §7.2 alone.
  **Founder call. Recorded rather than decided, because it is a taste question about how
  much slack the harness gives the implementer, and this project's failures have all come
  from slack.** *(r4: this question was unanswerable while AC-21 was vacuous — a budget on
  a criterion that everything satisfies is meaningless. §5.4a makes it answerable, and adds
  a second, adjacent budget the founder may want to look at at the same time: the pinned
  **column** exclusion list, today `{M-34}`, one entry.)* **(r5: the second budget now has
  the same shape as the first — capped at 1, a second entry fails GC-14 and is a
  founder decision, r4 finding 9. So the question is now one question about two numbers:
  `SWEEP_EXEMPT.txt` ≤ 2 tests and `excluded_columns` ≤ 1 mutant. Both are printed on
  screen. The founder may set either to 0.)**

- **OQ-8 — new in r5. What happens to 003 if `008` does not land?** §1.5 makes every
  008-coupled quantity a measurement at 003's **base commit**, which makes 003 correct
  whether 008 landed or not: `{P}`, the honest-scope digests, the binding preimage and the
  public-values widths are read off whatever tree exists. **So the spec does not break.**
  The question is not mechanical, it is the checkpoint: `AGENTS.md` §7 says that on **9/9**
  both `008` and `003` must be green or the founder is asked whether to withdraw, and
  `AGENTS.md` §3 says 008 comes first *because a proof that can be wrong makes 003's
  demonstration hollow*. If 008 stalls at its own round 6, the options are (a) start 003
  against the pre-008 tree — the gauntlet is then true, and the honest scope it pins still
  contains the `u64` truncation item, so nothing in 003 becomes false, but the demo shows a
  keyless escrow settled by a verdict whose domain is known-broken; (b) hold 003 and lose
  the day-of-event differential. **003 cannot answer this; it is a sequencing and honesty
  call about what the demo asserts.** *Recommendation: (a) with the truncation item named on
  screen*, because 003's claim is about **keys** and is unaffected — but that is exactly the
  kind of "our claim is narrower than it looks" argument that needs a founder, not an agent.

  **Two things r5 asked to be made explicit before the founder rules, both recorded here in
  r6 rather than decided:**
  - **The recommendation is not an obligation anywhere, deliberately.** §7.2's banner has no
    line for the truncation item and AC-16 pins only that the honest scope was **not
    changed**, never that it is **displayed**. **Writing that line now would decide the
    question**: it only makes sense under option (a), and choosing (a) is the founder's call.
    So the obligation is stated conditionally: **if the founder picks (a), one money-shot line
    naming the `u64_low` truncation item is added to §7.2 and AC-15's evidence covers it; if
    the founder picks (b), nothing is added.** Either way it is one line and it is not an
    agent's decision.
  - **"003's claim is about keys and is unaffected" is a claim-narrowing move, and it is
    flagged as one.** `AGENTS.md` §5 warns about exactly this shape. The argument is true as
    far as it goes — the gauntlet's subject is *who can move a funded deal*, not *whether the
    verdict's domain is sound* — and it is nonetheless the sentence that would let a demo show
    a keyless escrow settled by a verdict with a known-broken domain while saying nothing
    false. **An agent must not decide whether that can be said on a stage; the founder must**,
    and r5 was right that round 5 correctly did not.

- **OQ-9 — new in r5. `RecknVerdictVerifier.sol` is now inside the build condition; is it
  also inside 003's *scope line*?** The scope line (r1, binding on 004) says 003 may change
  `RecknZkEscrow.sol` **only where a matrix row would otherwise have no true expected
  result**. 003 changes **no line** of the verifier file — it only constrains it — so the
  scope line is not stretched today. But two foreseeable events touch it: task `008` changes
  that file's struct widths (which check 15 is designed to survive, §4.5.10), and any future
  task that changes the two pinned statements will fail check 15 and need D-12's declared
  change. **The question for the founder is who owns that file's checks after 003 ships** —
  003, which wrote them, or the task that next edits it. *Recommendation: the check moves
  with `scripts/no-keys.sh`, which `AGENTS.md` §0 reserves to the founder; agents may
  tighten it and may never loosen it.* **Founder call.**

- **OQ-10 — new in r6. Should check 14 pin assignment *right-hand sides*, and what is the
  budget for finding out?** *(Found while writing R-11. It is **not** one of r5's six
  findings, and `AGENTS.md` §7 makes this round the hard stop, so it is returned open rather
  than closed — that is the prescribed outcome, not a deferral.)*

  **The fact.** Check 14 extracts an assignment's **left-hand side** (14b) and compares it
  against a permitted set (14c). `to` is a permitted left-hand side in `settleWithProof` as a
  bare local `L`. **Nothing in this document constrains what `to` is set to.** Round 4's INV-2
  claimed otherwise in prose (*"only from `d.seller` / `d.buyer`"*); that sentence is corrected
  in §4.4 in this round. The same is true of `deals[dealId]`'s right-hand side in `fund`.

  **What is closed and what is not.** Check 7b (§4.5.6a) removes the *environment* as a branch
  condition, so the version of this attack that keys on `block.chainid` — the one that would be
  invisible to every instrument here (R-11) — is dead. What remains is a branch keyed on an
  ordinary **constant**:

  ```solidity
  if (token == 0x<a mainnet token address>) { to = 0x<attacker>; }   // inside settleWithProof
  ```

  It produces no call-shaped token (9a/9b/9c see nothing), reads no execution-context value
  (7b sees nothing), and has a permitted left-hand side (14c admits it). R-5 says a fuzz is not
  its killer, and the gauntlet's tokens are mocks, so no behavioural row is red either.

  **Why it was not closed in round 6.** Two reasons, both process rather than taste. (i) The
  reviewer's instruction for this round is explicit — *"round 6 must not open new mechanism
  design; if a round-6 finding lands that is not one of these six, the hard stop applies and
  the document goes to the founder with it open."* (ii) The obvious closure — pin the
  right-hand side of every assignment whose left-hand side is not a fresh local — **cannot be
  written safely against a source that does not exist yet**: `fund`'s `deals[dealId] = Deal({…})`
  literal is written in P1, and a pin authored blind would either over-reject the correct
  implementation (M-0 must be **accepted**, and a check that fails M-0 fails everything) or be
  weakened during implementation, which is the private-edit act this document exists to
  prevent.

  **The three options, priced.**
  - **(a) A new task.** Pin `to`'s right-hand side to `d.seller` / `d.buyer` and the deal
    struct's `seller` / `buyer` fields to `seller` / `msg.sender`, as **14d**, written against
    the post-P1 source with M-0 accepted as its first control. Cost: one sub-check, one corpus
    entry, one mutant, one round of review. This is the recommendation.
  - **(b) Accept and disclose.** §8 already carries it. The demo's claim survives — a
    constant-keyed redirect is a **backdoored source**, not a key, and `no-keys.sh` is not
    claimed to be a proof about source that has not been read — but *"every theft path
    reverts"* would be doing work the matrix does not do.
  - **(c) Fold into 004.** 004 must reuse this structure (§ preamble); 14d would land with it.
    Cost: the gap is open during 003's demo.

  **Founder call.** The agent's view, stated once and not repeated: **(a)**, sized at one
  part, after P1 exists.

---

## Appendix A — response to `docs/reviews/003-spec-r2.md` (round 3)

All 14 findings (BLOCKER 2 / MAJOR 7 / MINOR 5), with where each landed.
`adopted` = the reviewer's required change is implemented as written; `stronger` = a change
that meets the stated requirement and goes further, with the reason; `founder` = returned
as an open question.

| # | sev | finding | disposition | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | checks 9/10 count two method names → `approve` route A and out-of-body route B both drain; §3.1:245 and §8:1464-1466 are false; the spec relies on the blind spot at C-4 while denying it exists | **stronger.** Not "add `approve`/`increaseAllowance`/`decreaseAllowance`/`permit` to check 6" — that is the same denylist one name later (R-7). Check 9 is **rewritten as a closed allowlist over the whole file** (property P): 10 permitted member calls with pinned forms and ranges, plus a plain-call allowlist that catches function pointers and assembly opcodes. **Check 11** closes the file's top-level declarations (route B, structurally). **Check 12** closes `IERC20Min`'s declared function set (route A at the declaration). Check 13 is an explicitly-labelled redundant backstop and carries none of the claim. **C-4's blind-spot sentence is deleted** and the contradiction resolved: the interface is now inside the checked region. Mutants **M-41** (route A) and **M-42** (route B) added under AC-1; a **13-entry exit corpus** with a **prose control** is the witness that the property covers the family. §3.1 and §8 re-worded to the earned statement | §3.1.1, §3.1.2, §4.5.3–§4.5.7, §5.2.1, AC-1, AC-14 Falsify, §5.3, §8, R-7 |
| 2 | **BLOCKER** | the five gates never open test bodies; 6 stubs make AC-02 green; AC-18 observation 5 is false; AC-8 has no mutant; AC-18 is self-referential | **stronger, four parts.** (a) Observation 5 **deleted**; the stub attack is quoted verbatim in §5.0.1 as a thing the format does **not** stop. (b) §5.0.1 and §8 state plainly that the format prevents *zero tests*, not *zero assertions*. (c) **AC-21 (new)** — the kill matrix: every gauntlet test must be `Failure` in ≥ 1 of 28 columns (23 behavioural mutants + 5 sweep mutants), with a control column, an exemption budget of **2** confined to one file and printed in the money-shot. A stub is green in every column and is named. Mutant **M-44** is the stub suite itself. R-2b forbids bare `vm.expectRevert()`, without which SW-1's column would be blind. (d) **AC-8 given M-40** (M-21 split), and "every forge AC owns ≥ 1 mutant" is now **AC-13 check 8**, mechanical. (e) AC-18's self-reference cut three ways: a direct founder command, `gauntlet.sh` invoking the harness scripts **directly**, and observation 5 replaced by a **degenerate-dispatcher** detector (M-43) that a degenerate `ac.sh` cannot survive | §5.0.1, AC-18, **AC-21**, §5.3, §5.4, R-2b, AC-13 checks 8/11/13, §6.3, §8 |
| 3 | MAJOR | §1.3 defines "exact-transfer" only on the escrow's side; a recipient-fee token underpays and still terminates | **adopted.** Clause **(d)** added; row **G-36** added as `disclosed` with the honest expected value (*the call succeeds and the seller is underpaid*); `RecipientFeeERC20` mock; AC-19's count 6 → **8**; §8 states that **C-5 cannot detect this from the escrow side**, so it is a disclosure, not a fix; INV-6 re-worded to be explicitly about the escrow's side only | §1.3(d), G-36, §4.3, AC-19, INV-6, §6.1, §6.2, §8 |
| 4 | MAJOR | §2.3 lists the escrow bytecode and then omits it from its own three-part check; `d.token` is not checkable before funding but §2.2 says it is | **adopted.** The check is now **four-part** (`extcodehash` first), `contract.code_hash` is printed in `gauntlet.json` and in the banner, and **M-45** kills a JSON written without it. Row **G-37** added for the look-alike deployment. §2.3 is split into **(A) deployment check, before funding** and **(B) terms check, after the `Funded` event**; §2.2's `SELLER` row and `BUYER` row are corrected accordingly | §2.2, §2.3, G-37, §7.1, §7.2, AC-19, M-45 |
| 5 | MAJOR | OQ-6's premise is false — `zk-verdict/README.md:97` has ~34 s | **adopted.** The "no measured wall-clock anywhere in this repo" sentence is **deleted**; OQ-6 cites `zk-verdict/README.md:97` (re-verified by grep, 2026-09-04), distinguishes the two guests, and `proving_seconds_measured: null` becomes a **`proving` object** with `predicate_guest_wrap_seconds: 34` + source and `reexec_guest_seconds: null`. `gauntlet.sh --check` **re-reads the cited line** and fails if the number has moved. The gag rule is **kept** and `MIN_REFUND_DELAY` is **not** changed on a number measured for a different guest | OQ-6, §7.1, C-2, INV-10, §8 |
| 6 | MAJOR | M-21 names two different mutations; AC-8 ends up with no mutant | **adopted.** M-21 = verifier return ignored → **AC-2**; **M-40** = `fund` skips the delta check → **AC-8**. §5.3's total re-derived (48), AC-14's printed count re-derived (47 killed), and the general rule added as AC-13 check 8 | AC-2, AC-8, §5.3, AC-13 |
| 7 | MAJOR | AC-14's count check gives three different numbers (41 / 42 / 46-by-grep) for one comparison | **adopted.** The kill table is delimited by `<!-- BEGIN KILLTABLE -->` / `<!-- END KILLTABLE -->` and `T` is **defined as an expression**: distinct ids matching `^M-([0-9]+\|A\|F)$` between the markers = **48**. The lettered sub-mutants are excluded *by the pattern*, not by a rule to remember; sweep mutants use `SW-` and corpus entries use `E-` for the same reason. AC-14's evidence literal is **derived** — `gauntlet.sh --check` (check 9) recomputes `T` and asserts the manifest reads `mutation: <T> mutants, <T−1> killed, 1 control survived`. A reviewer's reproduction command is printed in AC-14 | §5.3, AC-14, AC-13 check 9, §5.1 |
| 8 | MAJOR | C-5's justification ("the upper bound is what kills M-23") is refuted by §5.3, which assigns M-23 to AC-10 | **adopted; the decision is unchanged, the reason is replaced.** C-5 now carries the **runtime** reason (an unbounded outward transfer is paid out of other deals' principal in the same token, and the contract would still write the terminal state), and states explicitly that **M-23 is killed by AC-10's multi-deal invariant independently of C-5's bound**. AC-10 and §8 say the same. `>=` is separately rejected because it does not rescue G-34 and would let an outbound-fee token over-pay | C-5, AC-10, §8 |
| 9 | MAJOR | N-5's "seller-acceptance is a key" is too broad, and OQ-4 rests on it | **adopted.** N-5 is narrowed to *authority over the outcome of an already-funded deal*; **seller-acceptance is listed separately as consent to enter, explicitly not an outcome key**, and excluded **on scope grounds, not on claim grounds**. OQ-4 is rewritten so the founder decides on cost and demo surface (a fourth function is a declared surface change; a fourth state adds rows) instead of on a false claim-shape argument | N-5, N-6, OQ-4 |
| 10 | MINOR | AC-13's marker-uniqueness assertion is false against this document | **adopted, and hardened one level further.** Round 3's first draft repeated the defect at the next level: the *full* `<!-- BEGIN MATRIX -->` string now occurs 3 times in this document (marker + AC-13's prose + this table) and the `KILLTABLE` one 4 times, so a substring count is wrong too. The rule is therefore **anchored to a whole line** (`^<!-- BEGIN MATRIX -->$` etc.), for both the uniqueness assertion and the extraction; measured 2026-09-04: anchored `1/1/1/1`, unanchored `3/3/4/4`. AC-14's reproduction command carries the anchors and a note saying why | AC-13, AC-14 |
| 11 | MINOR | AC-1's Falsify arithmetic is wrong on both numbers | **adopted, and re-derived for the new checks.** The source-text set is **16**; deleting check 9 alone leaves M-35/M-36/M-37 surviving (M-41 still dies at check 12, M-42 at check 11), so the line reads `16 source mutants, 13 rejected`. The three-check deletion is given as the full falsifier: `16 source mutants, 11 rejected; exit-corpus 0/13 rejected`. **r4 correction:** that broad falsifier's exact residue was **not** defensible — E-9/E-10/E-13 are also rejected by checks 6/13, which the deletion leaves in place — and it is replaced in AC-1 by two minimal falsifiers carrying exact, runnable numbers | AC-1 |
| 12 | MINOR | D-4 and D-7 cite wrong lines | **adopted, with r2's own correction corrected.** `grep -n "12 tests" README.md` → **706**, not 700 (r2's replacement) and not 669 (r2's original); the first site spans **`:550-551`**. D-7: `STATUS.md:39-40` is the review table and `001-keyless-timeout` occurs nowhere in `STATUS.md` — **there is nothing to fix there**, so D-7's obligation is rewritten to what is actually needed | D-4, D-7 |
| 13 | MINOR | the gag rule is an unspecified grep | **adopted.** A literal case-insensitive ERE is given in §7.1, together with the exact files it is run over. The substance (refusing to claim the window covers proving time) is kept, and is now **more** necessary, not less, because a number exists for the wrong guest | §7.1 |
| 14 | MINOR | termination is left open for AC-15 | **adopted.** §5.0.2 pins the whole call graph as a DAG, forbids `ac.sh --all` inside `gauntlet.sh`, limits `gauntlet.sh` to the 13 forge ACs individually, requires the five harness scripts to be invoked **directly**, states the maximum depth (3), and makes `gauntlet.sh --check` (check 10) assert the rules mechanically. The same rule does double duty as part of AC-18's self-reference fix | §5.0.2, AC-13 check 10, AC-18 |

**Round-2 items recorded as sound and deliberately untouched** (r2 "Checked and found
sound"): the forge mechanics §5.0 depends on (three-level `--list --json`, `invariant_*`
enumeration, `--match-test` matching them, `{}` on no match, `name(sig)` run keys); the fact
that the six r2 checks do not loosen `no-keys.sh`'s default behaviour and that N-9's refusal
of a target argument is right; the arithmetic that recomputed (recomputed again here for the
new totals); the `file:line` spot checks r2 confirmed (D-1, D-5, D-6, D-8, D-9, D-2, D-3,
S-1); the absence of a tier violation; and r1's own "checked and found sound" list, which
was not re-litigated in r2 and is not re-litigated here.

**What changed in size:** 35 rows → **37**; 21 ACs → **22**; 42 mutant ids → **48**;
`no-keys.sh` checks 10 → **13**; gauntlet tests 42 → **44**; suite total 54 → **56**; disclosed
rows 8 → **10**. Every one of those numbers is recomputed by `scripts/gauntlet.sh --check`
(AC-13), so this paragraph cannot drift either.

**Two things round 3 refused to do.** (1) Extend a denylist. R-7 records the rule so round 4
cannot; the fix for a hole in an enforcement script is the property that makes the exploit
and its unlisted siblings fail together. (2) Claim that any attack is impossible. The
strongest sentence in this document about the value exits is *"the enumeration cannot grow
without a visible edit to `scripts/no-keys.sh`"*, and §8 states three specific things that
sentence does not cover. The word "impossible" occurs only in §5.0.1's claim about a
script's exit condition and in §8's restatement of it, and §8 says so explicitly.

---

## Appendix B — response to `docs/reviews/003-spec-r3.md` (round 4)

All 8 findings (BLOCKER 3 / MAJOR 3 / MINOR 2), with where each landed. Same vocabulary as
Appendix A: `adopted` = the reviewer's required change is implemented as written;
`stronger` = a change that meets the stated requirement and goes further, with the reason;
`founder` = returned as an open question.

| # | sev | finding | disposition | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | `L_plain` is **forced** to contain `transfer` / `transferFrom` / `balanceOf` (check 12 pins the declaration lines that produce those tokens), so a function-type local *named* `transfer` passes all 13 checks and drains the same-token pool; corpus E-11 passed only because its author named the local `f` | **stronger — both of the reviewer's candidates, not one.** (a) **9c**: the `function` keyword is closed to the six pinned declarations, so a function-type variable, parameter, return, mapping value and a file-level function die together **whatever they are named**; this also closes check 2's own `function +` whitespace gap (`scripts/no-keys.sh:46`). (b) **9b-range**: the four token names are permitted as *plain* calls only inside `IERC20Min`'s declaration range, the same "0 elsewhere" shape 9a already uses. (c) A third, independent rejection falls out of check 14 (the LHS `function(…) transfer` matches neither `D` nor `L`). **E-11's stated reason is corrected** to 9c/14/9b and the name-dependence is called out; the splice is added as corpus **E-14** and as source-text mutant **M-46**, whose stated purpose is that the rejection does not depend on the name. `L_plain` keeps the three token names (check 12 needs them) and **loses** `function`, which 9c makes unreachable | §3.1.2 (P2), §4.5.3 (9b-range, 9c), §4.5.7, E-14, M-46, AC-1, R-8 |
| 2 | **BLOCKER** | a funded deal's fields can be rewritten from `fund` with **no call-shaped token at all** (`deals[victimDealId].seller = attacker;` via `fund(freshId, attacker, token, 0, victimDealId)`); INV-2 is the only invariant in §4.4 with neither instrument; AC-11 looks only at the same `dealId`; no AC says a `Funded` deal's struct is immutable | **adopted, all three parts, plus the invariant the reviewer asked for.** (a) **Mechanical:** **check 14** closes assignment targets per function range — the same construction check 8 uses for the constructor — together with **14a**, which closes the *enumeration of storage-writing source constructs* (`=`, compound assignment, `++`/`--`, `delete`; `assembly`'s `sstore` was already dead at checks 6/13). This is a property, not a name list: `deals[k]` for any `k ≠ dealId`, and `d.<field>` for any field but `state`, fail together. Lexical, no parser (N-10). (b) **Behavioural:** new invariant **INV-2c** (*a `Funded` deal's struct changes only through the two exits, and then only in `state`*) with two instruments — AC-10's `invariant_AC10_G38_funded_structs_immutable` over the existing handler, and AC-11's targeted `G-38` test, which asserts **both** struct identity **and** that the honest proof still pays the original seller. Two **handler obligations** are written down (the `fund` action must draw `dealBinding` from existing dealIds; `amount == 0` must be reachable) without which the invariant is decoration. (c) **Matrix and enumeration:** row **G-38** (class C, theft) and the §4.3 non-transition row *`Funded → Funded` with different fields*; §3.1.3's class-C bullet names the foreign-key write. Mutants **M-47** (guarded, killed structurally per R-5) and **M-48** (unguarded, killed by AC-11). §8 gains a bullet for what check 14 does and does not establish | §3.1.2 (P3), §3.1.3, G-38, §4.3, **INV-2 instruments**, **INV-2c**, **§4.5.6**, AC-10, AC-11, M-47, M-48, §6.3, §8, R-8 |
| 3 | **BLOCKER** | M-34 (every body `revert()`) breaks `setUp`, so its column marks all 44 tests `Failure` and satisfies AC-21 for all of them at once; AC-21's own Falsify cannot be observed non-zero; setUp-safety was guaranteed for 5 of 28 columns | **adopted, with the mechanical half the reviewer asked for.** **§5.4a** makes setUp-safety a **precondition on membership**, two ways: a **pinned exclusion list** `{M-34}` (held in the spec *and* the script, printed as `sweep.excluded_columns`, checked by AC-13 check 14 — so `sweep.columns` stays a predictable `24 − 1 + 5 = 28`), and a **setUp probe** per column per test file — a sandbox-only `SweepProbe_F` that *inherits* `F`'s `setUp()` and contains one `assertTrue(true)` test. A column whose probe fails and which is not on the pinned list makes the sweep **exit non-zero naming the column**; it is never dropped silently and never counted. M-34 keeps its kill-table cell under **AC-17**, which is a whole-suite criterion and the right instrument for it. AC-21's Falsify gains case (c) — re-admit M-34 and delete the probe assertion — as mutant **M-49**, and P7 is instructed to run Falsify (a) and observe it non-zero before reporting green (R-6). **M-33 is examined rather than assumed**: if any `setUp` settles the real fixture proof, M-33's probe fails, and §5.4a states the preferred resolution (move the settlement out of `setUp`) and forbids a silent drop. General rule recorded as **R-9** | **§5.4a**, AC-21, AC-17, §5.4, §7.1, §7.2, AC-13 check 14, M-49, §6.3, §8, R-9, OQ-7 |
| 4 | MAJOR | C-5 **masks** M-23, so "AC-10 kills M-23 independently of C-5's bound" is false of the contract actually mutated; AC-10's Falsify is false too | **adopted, option (c).** M-23 is redefined as the **compound** patch: pay `balanceOf(address(this))` **and** drop C-5's check in that function, so the drain is real and INV-4 genuinely breaks. The false parenthetical at C-5 is **deleted** and replaced by the reviewer's own mechanism (C-5 reverts the over-payment and rolls back the terminal state, so no invariant at any handler width can see it). AC-10's Falsify is re-derived: one deal in one token ⇒ `balanceOf(this) == d.amount` and the drain is invisible. §8's bullet is rewritten to the honest statement: **C-5's bound is justified at runtime and is not evidenced by a mutant, because C-5 masks the mutant that would evidence it.** Appendix A row 8 is left as the round-3 record and this row is its correction | C-5, AC-10, §8, §5.3 |
| 5 | MAJOR | one `src` serves two checks that need two: check 11 pins the `import` line **including its path string**, which string-stripping deletes, so check 11 cannot pass on the real file and M-0 must be accepted | **adopted.** §4.5.1 defines **three** texts in a table — `body` (unchanged), **`src_calls`** (strings removed, newlines collapsed; checks 9, 13) and **`src_decl`** (strings kept, newlines kept; checks 11, 12) — says which check reads which, and states that the import path is pinned in `src_decl`, in the only text that still contains it. The check table's scope column is updated for 9/11/12/13 | §4.5.1, §4.5.2, §4.5.3, §4.5.4, §4.5.5 |
| 6 | MAJOR | the stripper carries the whole of property P and is specified in one sentence; the corpus tests only **under**-stripping (C-P), never **over**-stripping, which is the direction that hides code | **adopted.** §4.5.1 states the stripper's obligation as a **property** (*a call-shaped token in code must survive stripping; one inside a comment or a string literal must not*), derives from it that the stripper must be **token-wise, not line-wise**, and names the existing line-wise rule at `scripts/no-keys.sh:30` as the thing being replaced. Corpus **E-15** (exit hidden between two same-line string literals) and **E-16** (between two same-line block comments) must be **REJECTED**; control **C-S** (two legitimate string literals, no call between them) must be **ACCEPTED**, so the stripper cannot pass E-15/E-16 by refusing all strings. Controls go 2 → **3** and the evidence string carries the new count | §4.5.1, §5.2.1 (E-15, E-16, C-S), §4.5.9, AC-1, §6.3 |
| 7 | MINOR | §5.0.1 says AC-21 covers "zero assertions" (it covers zero *sensitivity*); §8's residual for property P is stated too narrowly | **adopted.** §5.0.1 is brought down to *zero sensitivity* **with the counter-example spelled out** (`vm.warp(deadline); escrow.refundAfterDeadline(id);` asserts nothing and is `Failure` under SW-1, so it passes AC-21). §8's residual is widened to name **operand corruption** alongside token-free value movement, and — because check 14 now exists — §8 also states what check 14 itself does not establish, so the residual does not silently shrink to zero on paper | §5.0.1, §8 |
| 8 | MINOR | OQ-4's third bullet credits seller-acceptance with closing G-33, and it does not | **adopted.** The bullet is replaced: acceptance buys a **recorded on-chain attestation point** (a demo asset), and the text now states explicitly that the G-33 benefit is **zero**, with the reason — `refundDelay` is an immutable construction parameter readable before any deal exists (part 4 of §2.3 A), and acceptance does not gate `refundAfterDeadline`. N-5's narrowing is untouched | OQ-4 |

**Also landed in round 4, from the orchestrator's ruling of 2026-09-04** (not a review
finding): **§1.5** and **D-11**. Execution order is `008 → 003`, so 008's `surfaces.pinned`
(a pinned `sha256` of the contract source) already exists when 003 edits the contract, and
003 necessarily breaks it. The rule is stated once, in one place: **a surface change moves
three things in one commit — `AGENTS.md` §0's enumerated surface, `scripts/no-keys.sh`, and
`surfaces.pinned`** — and the re-pin is a **copy of the digest `surfaces.sh` prints**, never
a hand computation. `docs/specs/008-*` is not edited.

**Explicitly not re-litigated** (r3 "Checked and found sound", re-read before writing this
round): OQ-6's guest split and the gag rule; the two Honest-scope digests; the internal
arithmetic method (`T` by the anchored expression, Σ by the manifest column, the anchored
marker counts); the fact that the pinned call counts do **not** over-forbid the correct
implementation (001's refund path is already inside `transfer: 2` / `balanceOf: 6`);
inheritance, `using for`, `receive`/`fallback`, `constructor` and `modifier` closure; N-5's
narrowing; D-10's surface declaration; the timeout design and 001's four acceptance
conditions; INV-9's binding formula and the `u64_low` assignment to task 008. The one
addition to that list is a **sentence**, not a mechanism: §4.5.7 now says out loud why a
`modifier` is closed, which r3 noted was true but unstated.

**What changed in size (round 3 → round 4):** matrix rows 37 → **38** (theft 20 → **21**);
acceptance criteria **22** (unchanged); mutant ids 48 → **52**; `no-keys.sh` checks 13 →
**14**; derived texts 2 → **3**; exit-corpus entries 13 → **16**; selftest controls 2 →
**3**; gauntlet tests 44 → **46**; suite total 56 → **58**; sweep columns **28** (23
behavioural + 5 sweep → 23 admitted behavioural + 5 sweep, with one excluded by a pinned
list); numbered anti-degeneracy rules R-1…R-7 → **R-1…R-9** (plus R-2b, unchanged).
Every one of those numbers except the rule count is recomputed by
`scripts/gauntlet.sh --check` (AC-13), so this paragraph cannot drift either.

**Three things round 4 refused to do.** (1) **Extend a syntax check to chase the two
exploits.** Both are closed by a new *property* (P2: nothing new can become callable; P3:
nothing else can be assigned to) and both exploits appear only as witnesses — R-7, and R-8
now records the diagnosis that produced them. (2) **Rescue AC-21 by narrowing its
assertion.** The assertion is unchanged; what changed is which columns may be read, and the
gate is mechanical and printed. (3) **Say that anything is impossible.** §8 gained two
residuals in this round and lost none.

---

## Appendix C — response to `docs/reviews/003-spec-r4.md` (round 5)

All 11 findings (BLOCKER 2 / MAJOR 4 / MINOR 5), with where each landed. Same vocabulary as
Appendices A and B: `adopted` = the reviewer's required change is implemented as written;
`stronger` = a change that meets the stated requirement and goes further, with the reason;
`founder` = returned as an open question.

| # | sev | finding | disposition | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | settlement authority passes through `RecknVerdictVerifier.verifyVerdict`, a file no check, no fuzz and no mutant in 003 ever reads; a constant-address splice there is a resolver and every instrument stays green | **adopted — option (a), with the parts of (b) that are true kept anyway.** **Check 15** (§4.5.10) brings the file into `no-keys.sh`'s region as **two properties**, not a name list: **P4** (four top-level declarations, exactly one `function`, named `verifyVerdict`) and **P5** (the body is two statements, no control flow, no `msg.sender` / `tx.origin` / `block.` token), plus closed assignment targets file-wide, a pinned non-function line set, and an explicitly-labelled backstop. **No interface change**: the script derives the second path from its own location, so **N-9 is untouched**. Mutant **M-51**, corpus **E-19**, control **C-V**, matrix row **G-39** (new class `enforcement`, carried by AC-13 check 16), evidence line `checks: 15/15 passed`, and **D-12** declaring the second file in `AGENTS.md` §0. **Why (a) and not (b):** §3.1.2's architecture is *close the category*, and leaving the neighbouring 58-line file open closes it over the wrong region; the file is small and static; and (b)'s required money-shot sentence — *"the contract that computes the verdict is not checked"* — is one the product cannot afford. **(b)'s disclosures are printed anyway**: §2.3(A) part 2 now says the address check establishes nothing about that address's **source**, §8 lists the three things check 15 does not cover, and the money-shot prints the enforcement region *and* `Not covered:` | §1.2, §2.3(A), **§3.1.4**, G-39, §4.5 (region), **§4.5.10**, §4.5.9, AC-0, AC-1, AC-13 checks 2/16, §5.2.1 (E-19, C-V), §5.3 (M-51), §6.3(16), §7.1, §7.2, §8, **D-12**, OQ-9 |
| 2 | **BLOCKER** | 003 is written against the pre-008 tree while stating it runs after 008; the suite count (11 sites, two verbatim manifest strings), both honest-scope digests, INV-9's binding formula and INV-10's widths are all literals | **adopted, all four sub-items, and 008's numbers are *not* pasted.** **§1.5 is rewritten** around one rule — *003 contains no literal whose truth depends on 008* — and **§1.5.1** adds `gauntlet.sh --measure`, run once at 003's base commit, writing `docs/gauntlet.base.json` with five measurements. **§5.0.3** adds substitution tokens `{P}` (measured pre-existing count) and `{S}` (`46 + {P}`); `ac.sh` **refuses to run** without the base file, so the eleven literal sites become zero. **AC-16** pins *"unchanged since the base commit"* against **three** sources — working tree, `git show <base_commit>:…`, recorded value — and `--measure` refuses to overwrite, so the laundering path (re-measure after softening) exits non-zero. **[Corrected in r6 — r5 finding 2: `rm` is not an overwrite, so refusing to overwrite does not block that path and this clause was false. What blocks it is §1.5.1 rule 4's two `git log --diff-filter` assertions plus a clean-tree condition on `--measure`; AC-16's `Falsify` now traces all three branches. This row is left standing as the record of what round 5 wrote.]** **INV-9** states the property and refers to `binding_preimage`; **INV-10** keeps the unit-crossing discipline (these fields are never compared with `Deal.amount`, at any width) and refers to `public_values` for the widths; **§8**'s honest-scope bullet stops enumerating items and says *whatever the base commit says is as true at the end as at the start*. **§1.5.2 answers all three of 008's OQ-2 couplings**, with the path corrected to `zk-verdict/scripts/` (D-11, §1.5.2 — round 4 ran `ls scripts/`). **§1.5.3** turns §7.1's `sed -n '97p'` into a content grep requiring exactly one match (AC-13 check 17). New part **P0** runs the measurement before anything else | **§1.5**, §1.5.1–§1.5.3, §1.2, §5.0.3, §5.1, AC-13 checks 4/15/17, **AC-16**, AC-17, AC-21, INV-9, INV-10, §7.1, §7.2, §8, D-4, D-11, P0, OQ-8 |
| 3 | MAJOR | *"a script that ran nothing cannot print it"* is false — two `printf`s make AC-14 and AC-21 green — and it is the sentence holding up the only two anti-degeneracy instruments; r2 finding 2 re-committed one layer up; R-9 is the rule it violates | **stronger — the false clause is deleted and replaced by two independent devices, not one.** (i) **Witnesses** (§5.0.3): AC-14 and AC-21's evidence lines carry `witness={W14}` / `{W21}`, digests over the **patched sources** that `ac.sh` **recomputes itself** without running the script under test. A two-line `printf` cannot produce them without applying every patch. (ii) **Outside-in control artefacts** (AC-18 observations **7, 8, 9**, mutants **M-52, M-53, M-56**): `ac-selftest.sh` must observe `mutation-kill.sh` rejecting a sandbox whose M-0 is not the control, `degeneracy-sweep.sh` rejecting a stubbed sandbox, and `ac.sh` rejecting a stale witness. Either device alone kills the attack. **The reviewer's correction is adopted**: AC-1's selftest is *not* affected, because AC-14's Falsify makes a fabricated selftest show up as AC-0-red/AC-1-green; that reasoning is written into AC-14's Falsify (a). **And the recursion is closed honestly rather than falsely**: §8 names `ac-selftest.sh` as the artefact nothing watches and says plainly that **003 is not a defence against an implementer who fabricates evidence** — deliberate fabrication is a different threat model from the accidental placeholder the two devices catch. General rule recorded as **R-10** | §5.0 (clause deleted), **§5.0.3**, §5.0.2, AC-14, AC-18, AC-21, §5.3 (M-52, M-53, M-56), §6.3(18), §8, **R-10**, P6 |
| 4 | MAJOR | the stripper's two delimiter families are tested separately and never against each other; a two-pass stripper passes all 16 corpus entries and all 3 controls and hides a full drain; today's `no-keys.sh:29-30` is exactly that shape | **adopted, with the wording the reviewer asked for.** §4.5.1 states the obligation as **one pass, one state machine** — *"a stripper implemented as two independent passes is wrong in whichever order it is run"* — and spells out **both** drains: comments-first deletes the `.transfer(` after a `//` inside a string literal (and check 14 then *accepts* the assignment, because `string memory` is in `D`), strings-first deletes it between a quote inside a comment and the next quote. Corpus **E-17** (comment delimiter inside a string) and **E-18** (string delimiter inside a comment) are added, required verdict **REJECTED**; AC-1's evidence becomes `exit-corpus 19/19 rejected` (E-19 is finding 1's). §6.3 gains negative control 17 and P3 is instructed to run E-17/E-18 against the stripper **first** | §4.5.1, §5.2.1 (E-17, E-18), AC-1, §6.3(17), P3 |
| 5 | MAJOR | `SweepProbe_F is FTest` inherits every test, so the probe cannot be read off the exit status and the pinned `control 58/58` is unreachable; the generator assumes one test contract per file | **adopted, all three parts.** §5.4a now probes with `--match-contract '^SweepProbe_' --match-test '^test_probe_setup_ok$'` **and parses that test's status from the JSON**, with a sentence saying the exit status of that command is not evidence about `setUp`; **`^SweepProbe_` contracts are excluded from every column read**, which is what makes the control column exactly `{S}`; and the generator enumerates **test-declaring contracts, not files**, with the inventory pinned in §6.1 (4 test contracts + 1 handler that declares none) and a failure if the tree disagrees. Inheritance is **kept** — §5.4a's reason for it is sound, as the reviewer says. AC-21 gains Falsify (e) | §5.4a, AC-21, §6.1 |
| 6 | MAJOR | AC-14's class counts (23/16/8) and its reviewer-reproduction annotation `# 48` are one round stale, and the annotation is printed as an observed output | **stronger — the counts are derived, not corrected.** `T_src` / `T_beh` / `T_hd` are **defined as expressions** over §5.3's `class` cells, the way `T` already is, with `T = 1 + T_src + T_beh + T_hd` asserted by `gauntlet.sh --check` and by `mutation-kill.sh`'s sandbox count. Recomputed and **re-run against this document today**: 19 / 25 / 14, `T` = **59**, and the reproduction command is annotated `# 59` from that run. The paragraph says in as many words that a number carried from a previous round is not an observation (`AGENTS.md` §5), and **R-10(ii)** makes it a rule | AC-14, §5.3, R-10 |
| 7 | MINOR | three stale literals: AC-21's "44 gauntlet tests", "(44 and 56)", D-4's "expected 56" | **adopted, and D-4 loses its literal entirely.** AC-21's rows are **46**; the sentence describing its evidence line names **46** and **`{S}`** and says both round-4 numbers were stale; **D-4 now names AC-17's derived number `46 + {P}` and no literal at all**, with the reviewer's own reason quoted — D-4 is the one documentation obligation with no mechanical check behind it, so a literal there reaches the judge unopposed | AC-21, D-4 |
| 8 | MINOR | check 9's ranges are not defined over the text check 9 reads; §4.5.1 never fixes the order of its three operations | **adopted.** §4.5.1 fixes the order — *strip (one pass) → compute ranges → collapse newlines within each range* — and adds a table naming the three range kinds, **including `IERC20Min`'s declaration range**, which 9b-range needs and which the `body` splitter cannot produce. A range that cannot be located is a hard failure, never an empty range treated as clean. The splitter is stated **once**, in §4.5.1; the check table now points at it rather than restating it, because two statements of one splitter is how this finding happened | §4.5.1, §4.5.2 |
| 9 | MINOR | the pinned column-exclusion list has no cap while the test-exemption list has a hard one | **adopted, same shape as the exemption budget.** `excluded_columns` is **capped at 1**; a second entry fails AC-13 check 14 and is a founder decision, not an implementer edit — which matters precisely because §5.4a offers *"a founder-visible addition to the pinned exclusion list"* as a resolution when M-33's probe fails. OQ-7 is re-posed as one question about two budgets | §5.4a, AC-13 check 14, §7.1, OQ-7 |
| 10 | MINOR | §8's *"C-5 masks the mutant that would evidence it"* is stronger than the fact; an unmasked mutant exists and §4.1 already describes it | **adopted, option "add M-50".** **M-50** — C-5's `==` becomes `>=` in both exits — against `OutboundFeeERC20` with ≥ 2 deals in that token pays the fee out of the other deal's principal, breaking INV-4, killed by `invariant_AC10_G27_no_payout_exceeds_amount`. `T` re-derived. §8's sentence becomes **"M-23's shape is masked by C-5; M-50's is not, and M-50 is the evidence"**, with the reason spelled out: C-5 masks over-payment originating in the **contract**, not over-payment originating in the **token** — which §4.1 had already written | §5.3 (M-50), AC-10, §8, §6.3(20) |
| 11 | MINOR | AC-10's two handler obligations are stated as things that "cannot be dropped quietly" and nothing detects dropping them | **adopted — an instrument, not a softened claim.** The handler exposes ghost counters `fundsWithExistingBinding` and `fundsWithZeroAmount`, and `KeyGauntletInvariant.t.sol` declares `afterInvariant()` asserting both are non-zero. It is not a `test_`/`invariant_` name, so AC-10's count stays **5** and no manifest number moves. Mutants **M-54** (fresh bindings only) and **M-55** (`amount == 0` unreachable) are the evidence that it fires; AC-10's Falsify (b) is rewritten — dropping obligation (i) is **no longer silent** — and gains (d). If the fuzz settings are too small for a branch to be drawn, the fix is `foundry.toml`, not deleting the assertion | AC-10, §6.1, §5.3 (M-54, M-55), §6.3(19) |

**Explicitly not re-litigated** (r4 "Checked and found sound", re-read before writing this
round, and **the escrow-local mechanism is not touched**): 9c, 9b-range and check 14 against
`using … for`, inheritance, a `library`, a file-level function, `type(…)`,
`abi.encodeWithSelector`, a `modifier` named `deals`, a function-type struct field, a second
`Deal storage`, and the r3 splices; check 14's LHS-extraction rule failing **loudly** on
`if (…) deals[k].x = y;`, tuple declarations and `unchecked` blocks; 9c not falsely rejecting
the real post-003 file (six `function` tokens); the anchored marker rule; the manifest row
union; the timeout design and 001's four acceptance conditions; `AGENTS.md` §0's surface
obligation being discharged; §8's "impossible" discipline; the absence of a tier violation.
**The one addition to r4's list is prose, not mechanism:** §4.5.6 now says out loud that
`push`/`pop` are closed by 9a and a passed storage reference by 9c, which r4 noted was true
of the coverage and missing from the prose.

**What changed in size (round 4 → round 5):** matrix rows 38 → **39** (a fourth class,
`enforcement`, with exactly one row); acceptance criteria **22** (unchanged); mutant ids
52 → **59** (`T_src` 18 → **19**, `T_beh` 24 → **25**, `T_hd` 9 → **14**); `no-keys.sh`
checks 14 → **15** over **1 → 2** files; exit-corpus entries 16 → **19**; selftest controls
3 → **4**; sweep columns 28 → **29**; documentation obligations D-1…D-10 → **D-1…D-12**;
implementation parts 9 → **10** (P0); numbered anti-degeneracy rules R-1…R-9 → **R-1…R-10**;
gauntlet tests **46** (unchanged); **suite total: no longer a number** — `46 + {P}`,
measured. Every one of those except the rule count and the part count is recomputed by
`scripts/gauntlet.sh --check` (AC-13), so this paragraph cannot drift either. **Verified by
running the commands against this document on 2026-09-04:** `T` = 59, class counts
19 / 25 / 14, matrix 39 rows with 21 theft / 7 authorized / 10 disclosed / 1 enforcement.

**Four things round 5 refused to do.**
**(1) Declare the verifier out of frame.** Option (b) was available and cheaper. It was
refused because the sentence it requires in the money-shot is the sentence that destroys the
claim, and because a 58-line file with one function is the cheapest thing in this repository
to close.
**(2) Paste 008's numbers.** 008 is mid-review; its literals are not facts. Every coupled
quantity became a measurement instead, and where a measurement was not available the
statement became a reference rather than a guess.
**(3) Answer finding 3 with better prose.** The finding was a false sentence propping up two
instruments; it was replaced with two mechanisms, and the place where the mechanisms stop is
named in §8 rather than papered over.
**(4) Say that anything is impossible.** §8 gained four residuals in this round — the
verifier's deployed bytecode, `ISP1Verifier`, the end of the observer chain, and what a
witness does not prove — and lost none.


---

## Appendix D — response to `docs/reviews/003-spec-r5.md` (round 6)

All 6 findings (BLOCKER 2 / MAJOR 2 / MINOR 2), with where each landed. Same vocabulary as
Appendices A–C: `adopted` = the reviewer's required change is implemented as written;
`stronger` = a change that meets the stated requirement and goes further, with the reason;
`founder` = returned as an open question.

**This is round 6. `AGENTS.md` §2 makes it the hard stop**, so this appendix also lists, in
its last two sections, exactly what is **open** and goes to the founder.

| # | sev | finding | disposition | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | check 15 pins assignment **left-hand sides** and excludes the `constructor`, so the address `verifyProof` is dispatched to is chosen in an unchecked region of the checked file; the braced chain-id form passes 15a–15f **and every behavioural instrument**, because the gauntlet runs on a local chain; P5's *"there is no branch for a constant address to live in"* is false | **adopted, all four required changes, plus the rule the reviewer's own diagnosis implies.** (1) **15g** pins the constructor the way 15c pins `verifyVerdict`: parameter list, exactly two statements, **each right-hand side the parameter of the same name**, and zero `if`/`?`/`block.`/`chainid`/`tx.`/`0x` tokens; a file with no locatable constructor **fails**. (2) The deployment check becomes **five parts** — `RecknVerdictVerifier(verifier).verifier()` read on-chain, printed as `contract.verifier_sp1_verifier`, asserted non-empty by GC-7, and printed in the money-shot next to a restatement of what the seller must now do. **§2.3(A) states what part 5 does not establish and its tier.** (3) One corpus entry **E-20**, one mutant **M-57**, one matrix row **G-40**; `T` → **60**, `T_src` → **20**, corpus → **23**, matrix → **40 rows / 2 enforcement**. (4) **Check 8 gets the identical right-hand-side clause** for the escrow's constructor, witnessed by **E-23**. **Stronger, in two places the reviewer did not ask for and the diagnosis requires:** **check 7b** closes the *execution-context tokens* per range, so neither checked file can read `block.chainid` at all — a name ban would be R-7's mistake, so it is stated as a closed category (**P6**) with the token list as the error message; and the failure type is written down as **R-11** with its three parts (close the environment; a region defined by exclusion needs a pin per excluded region; **an LHS-only pin is not a pin**) | §1.2, §2.1, §2.2, **§2.3(A)**, **§3.1.4**, §4.4 INV-2, §4.5.2, **§4.5.6a**, §4.5.7, **§4.5.10 (15g, P5)**, AC-0, AC-1, GC-2/GC-7/GC-16, §5.2.1 (**E-20, E-21…E-23**), §5.3 (**M-57**), §6.1, §6.3(21), **R-11**, §7.1, §7.2, §7.3, §8, D-12, P3, **G-40** |
| 2 | **BLOCKER** | the anti-laundering mechanism is *"refuses to **overwrite**"* and the laundering path is `rm`; all three of AC-16's sources are re-derived from the softened tree; **AC-16's own `Falsify:` states an outcome that does not occur**, which R-6 makes a broken instrument; §9.1 P0 gives an instruction where R-10(i) demands a mechanism | **adopted exactly as the reviewer scoped it, and the escalation the reviewer rejected is not taken.** §1.5.1 gains **rule 4**: the base file must be **tracked**, must have exactly one `--diff-filter=A` commit, must have **no** `--diff-filter=D` commit, and its blob at that `A` commit must equal the working tree — asserted by **GC-15**. **Rule 2** gains the **clean-tree** condition (`git status --porcelain` empty) and **loses the "written once and only once" clause**, replaced by a paragraph saying in as many words that refusing to overwrite is not refusing to be replaced. **AC-16's `Falsify:` is rewritten as three branches with the outcomes that actually occur**, and branch (c) — commit the softening, `git rm`, re-measure, commit — is the one round 5 claimed was blocked and was not. §9.1 **P0** now forbids the delete, requires the base file's own commit, and makes the report paste the `A`-filter log. **Appendix C's row 2 carries an inline correction** rather than being rewritten. **Honest limit, stated in §8:** a rewritten history defeats rule 4, and that is the same class as fabricating `ac-selftest.sh` — deliberate fabrication, already outside the threat model | §1.5.1 (rules 2 and 4), **AC-16**, **GC-15**, §6.3(23), §8, §9.1 P0/P8, Appendix C row 2 |
| 3 | MAJOR | AC-17 pins the suite's **size** and four **names**; the other eight pre-existing tests are unprotected, so a meaningful one can be deleted and replaced by a passing one with every gate green | **adopted as the reviewer specified.** `--measure` records the **id set** (`<contract>:<test>`, sorted) instead of a length; `{P}` becomes its cardinality; **AC-17 requires the recorded set to be a subset of the run's ids and prints every missing one**; §1.2's four names stay as the load-bearing named subset. `ac.sh` refuses a set that is not an array of ≥ 1 distinct ids, and **GC-19** asserts the shape independently. AC-17's `Falsify` gains the reviewer's own repro — delete `test_reexec_tampered_public_values_are_rejected`, add a passing test, observe non-zero — and §6.3 gains control 22. **§8 states the boundary**: identity is not meaning, and a pre-existing body gutted in place is still invisible, because AC-21's sweep covers the 46 gauntlet tests only | §1.2, §1.5.1, §5.0.3, **AC-17**, **GC-19**, §6.3(22), §8 |
| 4 | MAJOR | §4.5.1's escape-handling clause is the one obligation with no corpus witness; a one-pass automaton that treats `\"` as a closing quote passes all nineteen entries and all four controls and hides a full drain | **adopted, with one deliberate deviation from the reviewer's arithmetic, stated here rather than buried.** **E-21** is the reviewer's splice (`string memory ref = "a \" // b"; IERC20Min(token).transfer(seller, amount);`, same line, which is E-17's shape). **E-22 is its `'` twin, and it is a separate entry.** The reviewer's text asks for both forms while its arithmetic (*"exit-corpus 20/20, or 21/21 with finding 1's entry"*) counts one. **Two, because §4.5.1's clause is written over "the two string forms" and a single entry cannot distinguish an automaton that honours `\"` and not `\'` from a correct one** — which is exactly the reasoning that made E-15/E-16 insufficient for the delimiter families in r4. Corpus is therefore **23** (19 + E-20 + E-21 + E-22 + E-23), not 21 | §4.5.1 (referenced), §5.2.1 (**E-21, E-22**), AC-1, §4.5.9, P3 |
| 5 | MINOR | §8's *"the word appears only in §5.0.1 and in its restatement"* is a location claim, and it drifted in the round that wrote it | **adopted, replaced by the property.** §8 now says the word **is never used about an adversary anywhere in this document, and its only substantive use is §5.0.1's claim about a script's exit condition**, with the appendix occurrences characterised as records of rounds that *refused* to make such a claim. **And the paragraph now names its own failure**: round 5 avoided asserting a count, then asserted a location set, which is the same defect one category up | §8 |
| 6 | MINOR | two check-numbering series both reach 15, and one is cited without its script | **adopted, with a different prefix than the reviewer suggested, for a stated reason.** `gauntlet.sh --check`'s checks are renamed **`GC-1 … GC-19`** throughout §1, §4, §5, §6 and §7. **Not `C-`**, which the reviewer proposed: `C-1…C-7` are this document's contract changes and `C-P` / `C-S` / `C-V` / `C-M0` are the selftest controls, so that prefix was already taken twice and the rename would have created a third collision. §4.5.2 states the convention once. **Appendices A–C keep the old spelling** and a sentence says so — they are round bookkeeping, not specification | §4.5.2, §1.5.1, AC-13 (whole list), AC-16, §5.0.2, §5.4a, §6.1, §7.1 |

### Also landed in round 6, from the orchestrator's ruling of 2026-09-04 (not a review finding)

**008 owns the check over `RecknVerdictVerifier.sol`; 003 extends it.** 008's own round-4
review reached the same file from the other side; 008 must edit it (it widens
`VerdictPublicValues`) and 008 runs first, so attributing the check's *introduction* to 003
would leave the region open for the whole of 008 and 009. **§1.5.4** records the ruling, states
what 003 owns regardless (15g, the five-part deployment check, E-20 / M-57 / G-40), and — per
§1.5's rule about 008-coupled facts — **decides the case by measurement, not by assumption**:
the new `docs/gauntlet.base.json.no_keys` records what `scripts/no-keys.sh` already is at the
base commit, with three outcomes (003 introduces the check in full / 003 extends it in place /
**stop and return to the founder**, if 008 changed the script's shape in a way §4.5.2's table
does not enumerate). **No 008 literal is pasted anywhere**, exactly as with `{P}`.

### What changed in size (round 5 → round 6)

Matrix rows 39 → **40** (enforcement 1 → **2**; theft, authorized and disclosed unchanged at
21 / 7 / 10); acceptance criteria **22** (unchanged); mutant ids 59 → **60** (`T_src` 19 →
**20**, `T_beh` **25** and `T_hd` **14** unchanged); `no-keys.sh` checks **15** over **2** files
(unchanged in count — 15g is a sub-check of 15, 7b of 7, and check 8's clause is a clause);
exit-corpus entries 19 → **23**; selftest controls **4** (unchanged); sweep columns **29**
(unchanged); `gauntlet.sh --check` checks 18 → **19**, renamed `GC-*`; gauntlet tests **46**
(unchanged); documentation obligations **D-1…D-12** (unchanged); implementation parts **10**
(unchanged); anti-degeneracy rules R-1…R-10 → **R-1…R-11**; open questions 9 → **10**; base
measurements 5 → **7**. **Every one of those except the rule count, the part count and the
question count is recomputed by `scripts/gauntlet.sh --check`, so this paragraph cannot drift.
Verified by running the commands against this document on 2026-09-04:** `T` = 60 by the
anchored `KILLTABLE` expression, and the matrix region contains 40 rows with 21 theft / 7
authorized / 10 disclosed / 2 enforcement.

### Four things round 6 refused to do

**(1) Close OQ-10 quietly.** The right-hand-side hole in check 14 was found *while writing
R-11*, it is not one of r5's six findings, and the reviewer's instruction for this round is
explicit that a seventh finding goes to the founder open. It is written up with its splice, its
three options and a priced recommendation, and **INV-2's false sentence about it is corrected
in place** — so nothing in the document now claims a mechanism that does not exist.

**(2) Add the round-5 recommendation for OQ-8 as an obligation.** Naming the truncation item on
screen only makes sense under option (a), and choosing (a) is the founder's call; writing the
money-shot line now would decide the question by implementation. The obligation is stated
conditionally instead, and **the "our claim is about keys" argument is explicitly flagged as
the claim-narrowing move `AGENTS.md` §5 warns about**, which is r5's second point about OQ-8.

**(3) Extend a denylist.** `block.chainid` is not added to check 13. The execution context is
closed as a **category** (P6, check 7b, 15g-iv), the token list is the error message, and R-7 is
the reason.

**(4) Say that anything is impossible.** §8 gained four residuals this round — the
environment-conditional branch that no EVM row can show failing, part 5's own limit, the base
file's history versus a rewritten history, and identity-versus-meaning in AC-17's subset — and
lost none. The word *impossible* is still used about exactly one thing: a script's exit
condition.

### What goes to the founder, open

1. **OQ-10** *(new)* — should check 14 pin right-hand sides? Recommendation: a new task, one
   part, after P1 exists. The gap is disclosed in §8 and in §4.5.6a until then.
2. **OQ-8** — what if 008 does not land? Unchanged, plus r5's two additions now recorded: the
   truncation-on-screen line is **conditional on the founder picking (a)**, and the
   *"003's claim is about keys"* argument is flagged as claim-narrowing.
3. **OQ-1, OQ-2, OQ-3, OQ-5, OQ-6, OQ-7, OQ-9** — unchanged and still open, as r5 recorded.
4. **The seller's deployment check now has five parts.** This is a change to what the seller is
   told to do, printed in the money-shot; it is a tightening, and it is founder-visible by
   §0's rule.
5. **§1.5.4's third case is a stop condition**: if 008 left `scripts/no-keys.sh` with a check
   count this document's table does not enumerate, the implementer stops rather than folding an
   unspecified check into a verbatim-compared evidence string.

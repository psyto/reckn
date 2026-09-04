# 003 — Key Gauntlet (folds in 001: keyless timeout)

| | |
|---|---|
| Status | **DRAFT — round 3.** Responds to all 14 findings in `docs/reviews/003-spec-r2.md` (`VERDICT: CHANGES`), which responded to `docs/reviews/003-spec-r1.md`. Response table: **Appendix A**. |
| Owner | `reckn-spec` (frame thin). Implementation is `reckn-codex-impl`. |
| Supersedes | task `001` (keyless timeout) — folded in per founder ruling, `AGENTS.md` §3 |
| Tier claimed | **local anvil / Foundry only.** No testnet, no mainnet, no real funds. |
| Surface touched | `zk-verdict/contracts/src/RecknZkEscrow.sol`, `zk-verdict/contracts/test/`, `zk-verdict/contracts/foundry.toml`, `scripts/no-keys.sh` (**additive checks only** — §4.5), `scripts/` (new: `ac.sh`, `ac-selftest.sh`, `no-keys-selftest.sh`, `mutation-kill.sh`, `degeneracy-sweep.sh`, `gauntlet.sh`), `zk-verdict/scripts/zk-e2e.sh` (**one line**, S-1), `docs/gauntlet.json` (new), `README.md`, `CLAUDE.md`, `AGENTS.md`, `STATUS.md`, `SUBMISSION.md`, `zk-verdict/README.md` (**not** its Honest-scope blocks) |
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
  The whole `zk-verdict/contracts` suite is **12** tests
  (`forge test --list --json | jq '[.[][][]] | length'` → 12, run 2026-09-04).
  None of the four publishes a key, fuzzes a caller, or enumerates what a key-holder
  *cannot* do.
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

**What the gauntlet actually exercises.** The 37 rows run in Foundry, where `vm.prank`
impersonates an **address without touching its private key**. The rows therefore
demonstrate address-level behaviour. The published keys are printed so a judge can verify
they derive to those addresses; unless OQ-1's signed mode is built, **no published key
signs anything.** This is stated in §8 and printed by `gauntlet.sh` (§7.2), not left to
the reader.

### 2.2 Capability table

Everything each actor *can* do, and everything they cannot:

| actor | can | cannot |
|---|---|---|
| `BUYER` | fund new deals; call `settleWithProof` with any bytes; call `refundAfterDeadline`; receive `Failed`/refund payouts; **choose which deployment to fund, and therefore its bytecode, verifier, vkey and `refundDelay`** (G-29, G-33, G-37); **choose `d.token`, and therefore whether the seller can ever be paid** (G-18, G-34, G-35, G-36) | redirect a `Reproduced` payout; refund before the deadline; cancel; change `seller`/`amount`/`dealBinding`/`token` after funding; stop a valid proof from settling before the deadline |
| `SELLER` | the same public surface as anyone; receive `Reproduced` payouts; **refuse to work until (i) the four-part deployment check passes *before* funding and (ii) the terms carried by the `Funded` event are acceptable** (§2.3) | cause a payout without a verifying proof bound to this deal; flip a `Failed` verdict; prevent a post-deadline refund; extend the deadline; **learn `d.token` / `d.amount` / `d.seller` before the buyer funds** — those are post-`Funded`-event facts, not pre-funding ones |
| `KEEPER` | submit or withhold a proof | change the outcome a proof carries; settle a deal a proof is not bound to; be paid for submitting; prevent anyone else from submitting the same proof |
| `DEPLOYER` | choose `verifier` and `refundDelay` **at construction, before any deal exists**; deploy other escrows, including look-alikes with honest parameters and different code (G-37) | anything about any deal in the deployed escrow; nothing is stored about them (`no-keys.sh` check 4, AC-20) |
| `STRANGER` | the same public surface as anyone | the same as everyone |
| `ATTACKER_CONTRACT` | reenter during payouts; be a lying token; donate tokens; force-send ETH | cause a second payout, corrupt another deal, or move a token it does not control |

### 2.3 Residual trust, stated up front — the deployment check and the terms check

These are **two different checks at two different times**, and round 2 collapsed them into
one, crediting the seller with a pre-funding check of facts that do not exist before funding
(r2 finding 4).

**(A) The deployment check — possible before anyone funds. Four parts.**

Four things are fixed by the deployer at construction and are then immutable and publicly
readable:

1. **the escrow bytecode itself** — compared as `extcodehash(escrow)` against the code hash
   of the audited build. Round 2 listed the bytecode as the third thing the deployer chooses
   and then **omitted it from its own three-part check**. A look-alike escrow carrying the
   genuine verifier, the genuine vkey and an in-range `refundDelay`, but with different code,
   passes a verifier/vkey/delay check and is outside the claim. Row **G-37**.
2. `verifier` — the `RecknVerdictVerifier` address, which in turn immutably holds the SP1
   verifier address and `verdictProgramVKey` (`RecknVerdictVerifier.sol:37-45`)
3. `verdictProgramVKey`
4. `refundDelay` — the settlement window (new in 003, §4.1)

`gauntlet.json` must print all four, including `contract.code_hash`, so the check is
possible (§7.1, AC-15). **003 makes the check possible; it does not make it automatic**, and
§8 says so.

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
the **seller** must check all four parts of (A) — the code hash is the only part that
detects G-37, and `refundDelay` is the only part that detects G-33 — and then (B) for their
payment.

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
contract body (§4.5, checks 9, 11, 12, 13). Together they state one property:

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
> list — and the one thing it cannot see is a construct that moves value **without any
> call-shaped token at all**. §8 names what that leaves open.

#### 3.1.3 The cross product

Given the enumeration, every theft is an attempt to reach L1 or L2 with a destination,
amount, deal, or timing that the deal did not authorize, **or** an attempt to corrupt the
state that L1 and L2 read (`d.seller`, `d.buyer`, `d.amount`, `d.state`, `d.fundedAt`,
`d.dealBinding`). The matrix is the cross product of:

- **exit** × **actor** × **precondition**, for L1 and L2 (classes A and B)
- **state corruption** through the only writing entry point, `fund` (class C)
- **control-flow** attacks that interleave with an exit (class D)
- **out-of-band** value movement that does not go through an entry point (class E)
- **choices made before the deal exists** — deployment parameters and deployment code
  (class F: G-29, G-33, G-37)
- **token behaviour outside §1.3's class** (class G: G-18, G-20, G-21, G-23, G-34, G-35,
  G-36)

This is exhaustive **with respect to that enumeration**, not with respect to all
conceivable attacks. §8 states the limits of that word.

### 3.2 The matrix

`class`: **theft** rows must revert or leave value where it was; **authorized** rows must
pay exactly the right party exactly once; **disclosed** rows are honest limitations that
the demo must show rather than hide.

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
| G-29 | disclosed | `DEPLOYER` or attacker | deploys **their own** `RecknZkEscrow` with a rogue verifier / vkey | — | the honest escrow's deals are untouched; the rogue escrow only affects deals funded into it. Parts 2–3 of the **deployment** check (§2.3 A) |
| G-30 | theft | `DEPLOYER` | rows G-01, G-03, G-06, G-07, G-11, G-15, G-19, G-31 replayed from the deployer address | — | **byte-identical results to `STRANGER`.** The deployer has no stored role |
| G-31 | theft | fuzzed caller | `settleWithProof` **and** `refundAfterDeadline` | `dealId` never funded (fuzzed `dealId`) | both revert `BadState`; no storage is written |
| G-32 | theft | fuzzed caller | any successful settle/refund of a deal in token `T` | other deals Funded in token `U ≠ T` | token `U`'s escrow balance is **unchanged**; only `T` moves |
| G-33 | disclosed | `BUYER` | deploys an escrow whose `refundDelay` is shorter than the proving time, funds it, takes delivery, calls `refundAfterDeadline` while the proof is still being generated | `block.timestamp ≥ fundedAt + refundDelay`, no proof yet | **the refund succeeds.** It is not theft under the contract's rules; no key is used. The seller's only defence is part 4 of the deployment check (§2.3 A). A late valid `Reproduced` proof then reverts `BadState` (G-17) |
| G-34 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | token has an **outbound** fee (funds cleanly, escrow-side decrease ≠ `d.amount`) | revert `PayoutFailed`; state stays `Funded`; **retryable forever, never succeeds** — the deal is permanently stuck. Residual created by C-5 |
| G-35 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | **rebasing / share-accounted** token; the escrow's balance moved between `fund` and payout | revert `PayoutFailed` (or `UnderFunded` at `fund` if the drift is downward before funding completes); state stays `Funded`; permanently stuck. Residual created by C-5 |
| G-36 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | **recipient-side fee** token: debits the escrow exactly `d.amount`, credits the destination `d.amount − fee` (§1.3 d) | **the call succeeds**, the deal becomes terminal, and the authorized destination receives **less than `d.amount`**. C-5 measures the escrow side and cannot see this. Disclosed, not fixed |
| G-37 | disclosed | `BUYER` or attacker | deploys a **look-alike** escrow with the genuine `verifier`, the genuine vkey and an in-range `refundDelay`, but **different bytecode** | — | the round-2 three-part check passes and the seller is outside the claim. Detected only by comparing `extcodehash(escrow)` with the audited build — part 1 of the four-part deployment check (§2.3 A). The honest escrow's deals are untouched |

<!-- END MATRIX -->

**37 rows. 20 theft, 7 authorized, 10 disclosed** — the counts are checked mechanically
(AC-13), so this table cannot drift from the tests.

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

  For the record, and so the founder can re-examine this later: **M-23 is killed by AC-10's
  multi-deal invariant independently of C-5's on-chain bound** (AC-10 runs ≥ 3 deals in ≥ 2
  tokens; M-23 breaks INV-4 on the first such sequence). C-5's bound is not needed to kill
  M-23 and is not justified by it.

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
- **INV-9 (binding soundness).** A proof settles deal `d` only if its committed
  `dealBinding` equals `d.dealBinding`, which was fixed at funding. The binding commits
  the authenticated prestate root, the predicate, and the plan
  (`keccak256("reckn/zk/bind/evm/v1" ‖ state_root ‖ check.address ‖ check.slot ‖
  check.min ‖ check.max ‖ keccak256(plan))`, `zk-verdict/program-revm/src/main.rs:176-190`).
  Therefore a proof of **some other favourable execution** cannot settle `d` — up to
  keccak-256 collision resistance and the correctness of the guest's construction, which
  the contract does not re-derive and 003 does not modify (N-2). **AC-6 is the acceptance
  condition for this invariant and its command must not be vacuous** (r1 finding 2).
- **INV-10 (units, named at every crossing).** These quantities are unrelated and the
  contract never compares them:
  - `Deal.amount` — `uint256`, the **escrowed token's smallest unit** (6 decimals for the
    USDC-shaped mock). This is what is paid out.
  - `VerdictPublicValues.pre/post/minDelta/maxDelta` — `uint64`, the **observed storage
    slot's** units, produced by `u64_low` = **limb 0 only** of the 256-bit word
    (`zk-verdict/program-revm/src/main.rs:163-164`). A value ≥ 2^64 is **truncated**, so a
    predicate over such a balance is out of scope (`AGENTS.md` §5). 003 does not fix this;
    task `008` owns it.
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

**One scope change, and it is a tightening.** Checks 1–4 keep their existing region — the
contract body isolated by `awk '/^contract RecknZkEscrow/{f=1} f'` (`scripts/no-keys.sh:29`)
— **byte-identically**. Checks 9, 11, 12 and 13 read the **whole file**. Nothing that the
script rejected before is accepted now; the set of rejected inputs strictly grows. That is
what makes r2 finding 1's route B (a `library` above the `contract` declaration) visible,
and it is what removes 003's own dependence on the blind spot (C-4). D-10 records the
change in the same commit, per §0.

#### 4.5.1 Shared preprocessing

Two derived texts, both computed once:

- `body` — as today (`:29-30`): from `^contract RecknZkEscrow` to end of file, with `//`
  and single-line `/* */` comments stripped. **Unchanged.**
- `src` — the **whole file** with `//` comments, `/* … */` comments (including multi-line)
  and string literals removed, then newlines collapsed to single spaces for tokenization,
  so a member call split across two lines (`X\n    .transfer(`) is still one token.

#### 4.5.2 The check table

| # | check | scope | status | enforces |
|---|---|---|---|---|
| 1 | forbidden privilege vocabulary | `body` | existing, unchanged | AC-0 |
| 2 | state-changing surface is enumerated | `body` | **strengthened, two-sided** (r2): all of `fund`, `settleWithProof`, `refundAfterDeadline` must be **present** as well as permitted | the keyless timeout cannot be silently deleted later |
| 3 | `require(/if( msg.sender` regex | `body` | existing, unchanged (kept in addition to check 7) | AC-0 |
| 4 | constructor stores no caller | `body` | existing, unchanged | AC-0 |
| 5 | **no base contracts** — the declaration line must match `^contract[[:space:]]+RecknZkEscrow[[:space:]]*\{` | `body` | r2 | inheritance reintroduces a role outside the scanned body |
| 6 | **no unenumerated entry point, escape hatch, or ETH surface** — must not contain `fallback`, `receive`, `assembly`, `tx.origin`, `.call(`, `.call{`, `staticcall`, `payable` | `body` | r2, **retained** | a `fallback()` is an entry point check 2's grep cannot see |
| 7 | **`msg.sender` only inside `fund`** — split `body` at `function ` boundaries; the ranges beginning `function settleWithProof` and `function refundAfterDeadline` must contain zero occurrences of `msg.sender` | `body` | r2 | INV-1a. Covers check 3's blind spot (`require(x == msg.sender)`) |
| 8 | **the constructor assigns only permitted immutables** — the left-hand side of every assignment inside the constructor body ∈ `{verifier, refundDelay}` | `body` | r2 | no stored authority |
| 9 | **closed call surface (property P)** — see §4.5.3 | **`src` (whole file)** | **rewritten in r3** | §3.1.2, INV-2, INV-2b |
| 10 | **`fund`'s use of `msg.sender` is pinned** — exactly 3 occurrences inside `fund`'s range, matching once each: `buyer: msg.sender`, `emit Funded(dealId, msg.sender,`, `transferFrom(msg.sender,` | `body` | r2 | INV-1b |
| 11 | **the file's top-level declarations are closed** — see §4.5.4 | **`src` (whole file)** | **new in r3** | r2 finding 1 route B; removes C-4's dependence on the blind spot |
| 12 | **`IERC20Min`'s declared function set is closed** — see §4.5.5 | **`src` (whole file)** | **new in r3** | r2 finding 1 route A at the declaration site |
| 13 | **whole-file escape-hatch ban** — the file-wide superset of check 6: `assembly`, `delegatecall`, `staticcall`, `.call(`, `.call{`, `.send(`, `selfdestruct`, `payable`, `receive`, `fallback`, `tx.origin`, `{value:`, `ecrecover`, `create2`, `using` | **`src` (whole file)** | **new in r3** | redundant backstop only — see the warning in §4.5.6 |

Function ranges (checks 7, 9, 10) are obtained the same way the existing script isolates
the body: strip comments, then split at lines matching
`^[[:space:]]*function[[:space:]]+[a-zA-Z_]`. Prototyped against the real file on
2026-09-04; it correctly attributes today's `transferFrom` to `fund` and today's
`.transfer(` to `settleWithProof`.

#### 4.5.3 Check 9 — closed call surface

Over `src`, a **call-shaped token** is any match of

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
  `emit` `try` `catch` `new` `function` `constructor` `modifier` `mapping` `enum` `struct`
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

**Why (9b) matters and is not decoration.** It is what closes the two routes an allowlist
over *member* calls alone would leave open:

- a **function-type variable**: `function(address,uint256) external returns (bool) f =
  IERC20Min(token).transfer; f(seller, amount);` — the assignment has no `(` after
  `transfer`, so (9a) never sees it, but `f(` is a plain call whose name is not in
  `L_plain`;
- **inline assembly**: `assembly { pop(call(gas(), t, 0, 0, 0, 0, 0)) }` — assembly emits
  no member call, but `pop(`, `call(`, `gas(` are all plain calls outside `L_plain`.

#### 4.5.4 Check 11 — the file's top-level declarations are closed

Over `src` *before* newline collapsing, the lines whose **first non-blank character is at
column 0** and which match
`^(pragma|import|using|library|abstract|interface|contract|function|struct|enum|error|event|type|constructor|modifier)\b`
must be exactly these four, in this order (whitespace-normalized, compared as full lines):

```
pragma solidity ^0.8.20;
import {RecknVerdictVerifier, VerdictPublicValues} from "./RecknVerdictVerifier.sol";
interface IERC20Min {
contract RecknZkEscrow {
```

A `library`, a second `interface`, a second `import`, a file-level `function`, a
`using … for`, an `abstract contract`, or any other top-level declaration fails, printing
the line. This is r2 finding 1 route B, closed **structurally** rather than by extending a
count, and it is what makes "the whole file" a well-defined region.

#### 4.5.5 Check 12 — `IERC20Min`'s declared function set is closed

The lines between `^interface IERC20Min {` and the next line that is exactly `}` at column
0 must contain exactly three `function` declarations, whitespace-normalized equal to:

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

#### 4.5.6 Which check rejects what, and which of them carry the claim

**Warning, so this is not misread as another name list.** Check 13 is a **denylist and a
backstop only**. If check 13 were deleted, every construct in the table below would still
be rejected by checks 9, 11 or 12. The claim rests on the allowlists (9, 11, 12); 13 exists
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
| `function(address,uint256) external returns (bool) f = IERC20Min(t).transfer; f(x, y);` | **9b** (`f` not in `L_plain`) | — |
| `selfdestruct(payable(x))` | **9b** (`selfdestruct` not in `L_plain`) | 1, 13 |
| **a construct not in this table** | **9a** or **9b**, because the allowlists are closed over the syntactic category, not over the vocabulary | — |

**The last row is the whole point of the rewrite, and it is also the honest limit:** the
allowlists cover any construct that produces a call-shaped token. §8 names what remains
outside — a value movement expressed with **no** call-shaped token at all, and the fact
that the check is lexical rather than a property of the compiled bytecode.

#### 4.5.7 The one additive output line

Immediately *before* the existing final success line (which stays byte-identical), the
script prints:

```
checks: 13/13 passed
```

This exists so AC-0 cannot be satisfied by a script that ran nothing. It adds a line; it
changes no existing line, no argument, no target, and no exit code.

#### 4.5.8 Self-testing without a target argument (N-9, r1 finding 12)

`no-keys-selftest.sh` reconstructs the *layout* the script expects in a temp directory —
`$T/scripts/no-keys.sh` and `$T/zk-verdict/contracts/src/RecknZkEscrow.sol` — because the
script derives its target from its own location (`scripts/no-keys.sh:17-19`). Verified
working on 2026-09-04: a clean copy exits 0 in the sandbox, and a mutated copy is judged
by the same code path. **No argument, no environment variable, no default change.**

It runs three things (AC-1):

1. the **16 source-text mutants** of §5.3, each rejected, each by a **named** check;
2. the **exit corpus** of §5.2.1 — 13 value-exit constructs spliced into the real file,
   each rejected, each by a named check — which is the *witness* that property P covers the
   family, **not** the definition of the property;
3. two controls: the unmodified copy (**M-0**) must be **accepted**, and a **prose control**
   — the comment `// never call approve(), permit(), or .call{value:}()` spliced into
   `fund` — must also be **accepted**, proving the checks read code and not text.

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
(leading whitespace in the rendered output is therefore fine). Each evidence string carries
a count, so a script that ran nothing cannot print it.

For the **`suite`** AC (AC-17), `ac.sh` runs the whole suite with `--json`, requires valid
JSON, requires the total number of `test_results` entries across all suites to equal the
manifest's `tests` value, requires every status `Success`, and requires the four
pre-existing `RecknZkEscrowTest` names of §1.2 to be present.

**Spelling.** `AC-N` in prose and `AC-0N` in the manifest are the same criterion;
`scripts/ac.sh` accepts both spellings and normalizes to the two-digit form, which is also
the form embedded in test names (`_AC02_`). `gauntlet.sh --check` asserts the two spellings
are in bijection.

`bash scripts/ac.sh --all` runs every entry in the manifest, asserts it ran **22** of them,
and prints `ac: 22/22 acceptance criteria passed`.

`ac.sh` takes `--root <path>` so the harnesses can point it at a sandbox (r1 finding 4).
This is a **new** script and its interface is 003's to define; it is not `no-keys.sh` (N-9).

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
> impossible.** Two instruments cover that, and they are the only two:
>
> - **AC-21 (new in r3) — the kill matrix.** Every gauntlet test must be observed
>   **failing** against at least one mutant. A body of `assertTrue(true)` passes against
>   every mutant, so it is green in every column of the matrix and AC-21 names it and
>   exits non-zero. This is a *behavioural* body check: it never reads the source of a
>   test, it observes whether the test is sensitive to the contract at all.
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
              │                                    ac.sh --root <sandbox> --all
              └─▶ AC-21 ─▶ degeneracy-sweep.sh ─▶ forge (sandbox suites)
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
- `gauntlet.sh --check` asserts these mechanically: `scripts/gauntlet.sh` contains no
  `ac.sh --all` and no `ac.sh AC-13|AC-14|AC-15|AC-16|AC-18|AC-21`; the three harness
  scripts contain no `ac.sh --all` without `--root`.

Maximum depth is 3 (`ac.sh --all` → AC-15 → `gauntlet.sh` → `ac.sh AC-NN`), and the third
level cannot re-enter `--all`.

### 5.1 The manifest (machine-read by `scripts/ac.sh` and `scripts/gauntlet.sh --check`)

Columns: `AC`, `kind` ∈ {`forge`,`script`,`suite`}, `selector` (regex for `forge`, command
for `script`), `tests` (exact expected count; `-` for `script`), `rows` (G ids that must
appear in that AC's test names; `-` if none), `evidence` (verbatim stdout line required for
`script`/`suite` kinds; `-` otherwise). Tab- or multi-space-separated; `#` starts a comment.

```ac-manifest
AC-00  script  scripts/no-keys.sh                 -   -                                        checks: 13/13 passed
AC-01  script  scripts/no-keys-selftest.sh        -   -                                        selftest: 16 source mutants, 16 rejected; exit-corpus 13/13 rejected; 2 controls accepted
AC-02  forge   _AC02_                             6   G-01,G-02,G-05,G-06,G-08,G-09            -
AC-03  forge   _AC03_                             4   G-10,G-12,G-13,G-14                      -
AC-04  forge   _AC04_                             2   G-11                                     -
AC-05  forge   _AC05_                             4   G-07,G-15,G-16,G-17                      -
AC-06  forge   _AC06_                             2   G-03                                     -
AC-07  forge   _AC07_                             3   G-04,G-05,G-06                           -
AC-08  forge   _AC08_                             3   G-20,G-21                                -
AC-09  forge   _AC09_                             3   G-24,G-25,G-26                           -
AC-10  forge   _AC10_                             4   G-27,G-28,G-32                           -
AC-11  forge   _AC11_                             2   G-19,G-22                                -
AC-12  forge   _AC12_                             2   G-31                                     -
AC-13  script  scripts/gauntlet.sh --check        -   -                                        manifest: 37 rows, 22 acceptance criteria, 3 sources agree
AC-14  script  scripts/mutation-kill.sh           -   -                                        mutation: 48 mutants, 47 killed, 1 control survived
AC-15  script  scripts/gauntlet.sh                -   -                                        37/37 rows as specified.
AC-16  script  scripts/gauntlet.sh --check        -   -                                        honest-scope: 2/2 digests unchanged
AC-17  suite   -                                  56  -                                        suite: 56/56 passed
AC-18  script  scripts/ac-selftest.sh             -   -                                        ac-selftest: 13 forge ACs, 13 observed failing when their tests are absent; degenerate dispatcher rejected
AC-19  forge   _AC19_                             8   G-18,G-23,G-29,G-33,G-34,G-35,G-36,G-37  -
AC-20  forge   _AC20_                             1   G-30                                     -
AC-21  script  scripts/degeneracy-sweep.sh        -   -                                        sweep: 44/44 gauntlet tests accounted for; control 56/56 pass
```

Arithmetic that `gauntlet.sh --check` recomputes and that a reviewer can recompute by hand:

- **22** acceptance criteria (AC-00 … AC-21).
- **13** `forge` ACs; their `tests` column sums to **44** — the number of gauntlet tests.
  `6+4+2+4+2+3+3+3+4+2+2+8+1 = 44`.
- AC-17's `tests` = **56** = 44 gauntlet + **12** pre-existing (measured 2026-09-04, §1.2).
- The union of the `rows` column is exactly the **37** ids of §3.2, each appearing at least
  once. (Rows may appear in more than one AC; G-05 and G-06 appear in AC-02 and AC-07.)
- Every one of the 13 `forge` ACs appears in at least one `killed-by` cell of §5.3
  (`gauntlet.sh --check` check 8 — the rule r2 finding 2(d) required).
- AC-14's evidence line is **derived, not literal**: `gauntlet.sh --check` recomputes
  `T` from §5.3 (below) and asserts the manifest line reads exactly
  `mutation: <T> mutants, <T−1> killed, 1 control survived`.

### 5.2 The criteria

#### AC-0 — the central claim still holds (fixed text, `reckn-spec` charter)

```sh
bash scripts/ac.sh AC-00   # runs `bash scripts/no-keys.sh`; exit 0 and `checks: 13/13 passed`
bash scripts/no-keys.sh    # exit 0 — the founder's own command, unchanged
```
The state-changing surface becomes `fund` / `settleWithProof` / `refundAfterDeadline` —
three functions. `AGENTS.md` §0 and `scripts/no-keys.sh` already enumerate exactly these
three, so the *permitted* surface does not change; what changes is that the third one now
**exists**. `IERC20Min` also gains one declared function (`balanceOf`, C-4), and that
interface is now itself an enumerated surface (check 12). Both are changes to what the
product claims, so §9's documentation obligations D-1…D-10 must land in the same commit and
the demo script must say it out loud.

**Kills:** M-13 (constructor stores `msg.sender`), M-A (an `admin` address field), M-F
(an unlisted `function sweep`).

**Falsify:**

```sh
# 1. reintroduce a role — check 1 must reject it
S=$(mktemp -d); mkdir -p "$S/scripts" "$S/zk-verdict/contracts/src"
cp scripts/no-keys.sh "$S/scripts/"
sed 's/^contract RecknZkEscrow {/contract RecknZkEscrow {\n    address public admin;/' \
  zk-verdict/contracts/src/RecknZkEscrow.sol > "$S/zk-verdict/contracts/src/RecknZkEscrow.sol"
bash "$S/scripts/no-keys.sh"; echo $?      # must be non-zero
# 2. delete refundAfterDeadline — the two-sided check 2 must reject it
```

#### AC-1 — the enforcement script closes the call surface, over the whole file

```sh
bash scripts/ac.sh AC-01     # runs scripts/no-keys-selftest.sh
bash scripts/no-keys-selftest.sh   # direct — the founder's own command
```
`scripts/no-keys.sh` gains checks 5–13 and the two-sided check 2 exactly as tabulated in
§4.5. **No interface change (N-9).** `scripts/no-keys-selftest.sh` builds the sandbox
layout described in §4.5.8, applies each artefact to the copy, runs the copied script, and
asserts:

- the **16** source-text mutants (M-1, M-13…M-19, M-35…M-38, M-41, M-42, M-A, M-F) are each
  **rejected** (exit non-zero), each by a **named** check — the selftest records which check
  fired and fails if a mutant is rejected by no check or by an unexpected one;
- the **13** entries of the **exit corpus** (§5.2.1) are each **rejected**, each by a named
  check;
- the **control M-0** (unmodified copy) is **accepted** (exit 0);
- the **prose control** (a comment naming `approve()`, `permit()` and `.call{value:}()`
  spliced into `fund`) is **accepted**, so the checks cannot be passing by grepping English;
- it prints
  `selftest: 16 source mutants, 16 rejected; exit-corpus 13/13 rejected; 2 controls accepted`.

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
check 9a at the call.
The selftest also re-runs M-13, M-A and M-F, which §5.3 assigns to **AC-0** because the
script's *original* checks 1/2/4 already reject them; they are exercised here, not claimed
here.

**What AC-1 does and does not establish.** It establishes that the 16 mutants and the 13
corpus constructs are rejected, and that two controls are accepted. It does **not**
establish property P — P is established by the *closedness* of the three allowlists (checks
9, 11, 12), and the corpus is evidence that the closedness is real rather than an
aspiration. A 14th construct nobody listed is rejected because it must produce a
call-shaped token, not because it is on a list. §8 restates the limit.

**Falsify:**

```sh
# minimal: delete check 9 alone. M-35/M-36/M-37 survive (M-41 still dies at check 12,
# M-42 still dies at check 11), so the evidence line reads
#   "selftest: 16 source mutants, 13 rejected; ..."
# which is not the manifest's string, so `ac.sh AC-01` exits non-zero.
#
# full: delete checks 9, 11 and 12. M-35/M-36/M-37/M-41/M-42 survive and the line reads
#   "selftest: 16 source mutants, 11 rejected; exit-corpus 0/13 rejected; ..."
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
bash scripts/ac.sh AC-10   # 4 tests ; rows G-27,G-28,G-32
```
Two Foundry invariants over a handler exposing `fund`, `settleWithProof`,
`refundAfterDeadline`, `donate`, and `warp`, across **≥ 3 deals in ≥ 2 tokens** and a
fuzzed actor set — `invariant_AC10_G27_no_payout_exceeds_amount` (INV-3, INV-4, INV-6,
INV-7) and `invariant_AC10_G32_cross_token_isolation` (INV-5) — plus two unit tests:
`test_AC10_G27_donation_unrecoverable` and `test_AC10_G28_forced_eth_moves_nothing`.
`runs` / `depth` are pinned in `zk-verdict/contracts/foundry.toml`, and the values used
are printed into `gauntlet.json` (AC-15).

**Kills:** M-23 `refundAfterDeadline` pays `token.balanceOf(address(this))` instead of
`d.amount` — drains other deals and donations, and passes every single-deal test. **AC-10
kills M-23 with or without C-5's on-chain upper bound**, because the handler runs ≥ 3 deals
in ≥ 2 tokens and M-23 breaks INV-4 on the first such sequence; C-5's justification is
therefore the runtime one in §4.1, not this mutant (r2 finding 8).

**Falsify:** reduce the handler to one deal in one token → M-23 survives AC-14.
Set `invariant_runs = 0` in `foundry.toml` → forge reports the invariants without executing
them and AC-14 fails; `gauntlet.json`'s printed `fuzz` block makes the setting visible.

#### AC-11 — a funded deal's terms are immutable

```sh
bash scripts/ac.sh AC-11   # 2 tests ; rows G-19,G-22
```
For a fuzzed caller and fuzzed `(seller, token, amount, binding)`, `fund` on an existing
`dealId` reverts `DealExists` and the stored `Deal` is **bytewise identical** before and
after (compare the full ABI-encoded struct, not field-by-field spot checks) (G-19).
Second test: `dealBinding == bytes32(0)` reverts `ZeroBinding` and creates nothing (G-22).

**Kills:** M-25 the `DealExists` guard is removed; M-26 the guard is
`if (deals[dealId].state == State.Settled) revert` (so a **Funded** deal can be overwritten
with a new seller — the redirect attack).

**Falsify:** compare three fields instead of the encoded struct and mutate a fourth → M-26
survives.

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

1. §3.2's `G-NN` ids ↔ the `G` ids embedded in test names on disk ↔ `rows[].id` in
   `docs/gauntlet.json`;
2. §3.2's per-class counts (20 theft / 7 authorized / 10 disclosed / 37 total) recomputed
   from the table and from the JSON;
3. §5.1's per-AC `tests` column ↔ the actual `--list --json` count for each selector;
4. Σ(`tests` over `forge` ACs) = 44, and AC-17's `tests` = 44 + 12 = 56;
5. the union of §5.1's `rows` column = §3.2's id set;
6. the number of manifest entries = 22;
7. `docs/gauntlet.json` contains no `target override` string, no `signed_rows`
   inconsistency, and a non-empty `contract.code_hash` (§7.1);
8. **every `forge` AC in §5.1 appears in at least one `killed-by` cell of §5.3**
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
9. **AC-14's evidence literal is derived**: recompute `T` = the number of distinct ids
   matching `^M-([0-9]+|A|F)$` between the `KILLTABLE` markers, and assert §5.1's AC-14
   line reads exactly `mutation: <T> mutants, <T−1> killed, 1 control survived`
   (r2 finding 7);
10. **the call-graph rules of §5.0.2** hold (`gauntlet.sh` contains no `ac.sh --all`, etc.);
11. **no gauntlet test file contains a bare `vm.expectRevert()`** with no argument (R-2b);
12. the **gag-rule pattern** of §7.1 does not match any rendered output while the
    re-execution guest's proving measurement is `null`;
13. `SWEEP_EXEMPT.txt` (AC-21) contains at most **2** names, every one of them declared in
    `zk-verdict/contracts/test/KeyGauntletStructural.t.sol`, and every one carrying a
    reason line.

Any mismatch exits non-zero and names the missing ids. On success it prints
`manifest: 37 rows, 22 acceptance criteria, 3 sources agree`.

**Kills:** M-28 a hand-edited `gauntlet.json` with a row deleted; M-29 a test file where a
row's test exists but is named without its ID; M-30 a §3.2 row added to this document
without a test; **M-45** *(new in r3)* a `gauntlet.json` written without
`contract.code_hash`, which is what would silently un-do §2.3's fourth check.
**M-31b** (a manifest entry whose `tests` value is lowered to match a missing test) is
caught by check 3 against `--list` and by check 4's sum; it is a harness self-check inside
AC-13 and is **not** an entry in §5.3 (see the note under the kill table).

**Falsify:** add a row `| G-38 | theft | … |` to §3.2 and run → non-zero, naming G-38.

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
- **behavioural** mutants (23) get a sandbox Foundry project: copy
  `zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}` (including
  `src/fixtures/`), symlink `lib`, apply the patch, and run
  `bash scripts/ac.sh --root <sandbox> AC-NN` for the AC that names the mutant; assert it
  **fails**;
- **source-text** mutants (16) are driven by `no-keys-selftest.sh` (AC-1);
- **harness/document** mutants (8) are applied to sandbox copies of `docs/gauntlet.json`,
  the test files' names and bodies, `scripts/ac.sh`, this spec, and `zk-verdict/README.md`;
- **M-0 is the unmodified copy**: every AC must **pass** against it. If M-0 is reported
  killed, the harness is broken.

The script prints a table `mutant | class | killed-by | status` and the evidence line
`mutation: 48 mutants, 47 killed, 1 control survived`. It exits non-zero if any mutant
survives, if M-0 is reported killed, or if the printed count differs from `T` recomputed
from §5.3's `KILLTABLE` region.

**The count comparison is stated once, as an expression (r2 finding 7).**
`T := |{ ids between the KILLTABLE markers matching ^M-([0-9]+|A|F)$ }|`. A reviewer can
reproduce it:

```sh
# NOTE the ^…$ anchors: the marker strings also appear quoted in AC-13 and in Appendix A.
awk '/^<!-- BEGIN KILLTABLE -->$/{f=1;next} /^<!-- END KILLTABLE -->$/{f=0} f' \
  docs/specs/003-key-gauntlet.md | grep -oE '\bM-([0-9]+|A|F)\b' | sort -u | wc -l   # 48
```

The lettered sub-mutants (`M-31b`, `M-31c`, `M-31d`, `M-32b`) do not match that pattern and
are excluded by construction, not by a rule someone has to remember. Round 2's version said
"41" in the evidence line, "42" in §5.3 and "the number of `M-` identifiers" (46 by grep) in
the check; the three are now one number by definition.

**`mutation-kill.sh` and `degeneracy-sweep.sh` must share one sandbox builder.** The 23
behavioural sandboxes are the same in both; building them twice is waste, and the
implementation report must state which script built them and the measured wall-clock. **No
wall-clock is asserted here** (`AGENTS.md` §5).

**Kills:** the degenerate harness — one that reports "all killed" by failing everything.
Its detector is **M-0, which must SURVIVE**; if the table reports M-0 killed, AC-14 fails.
(M-0 is the one identifier in §5.3 with no `killed-by`; AC-14 does not kill it, it protects
it.)

**Falsify:** apply M-41's patch (the `approve` backdoor) to
`zk-verdict/contracts/src/RecknZkEscrow.sol` on the live tree and run the whole AC set —
**AC-0 and AC-1 must both go red.** If they do not, checks 9/11/12 are not doing what §4.5
says. This is the r2-blocker-1 regression test and is the one command that would have
caught round 2.

#### AC-15 — the judge-facing surface is generated, not written

```sh
bash scripts/ac.sh AC-15   # runs `bash scripts/gauntlet.sh`
```
`scripts/gauntlet.sh` must: print the five private keys with the banner
`LOCAL ANVIL / FOUNDRY ONLY — throwaway development keys, no real funds`; print the escrow
address, **`extcodehash(escrow)`**, the `verifier` address, the `verdictProgramVKey`, and
`refundDelay` (§2.3(A)'s four-part deployment check); run the 13 forge ACs through
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
bash scripts/ac.sh AC-16   # the digest half of `gauntlet.sh --check`
```
The two "Honest scope" blocks in `zk-verdict/README.md` are byte-frozen by SHA-256,
recorded here (unchanged from round 1; r1 and r2 both recomputed them and they match):

| block | lines (as of 2026-09-04) | sha256 |
|---|---|---|
| Honest scope of the re-execution guest | 154–164 | `8f65b75fc03774b532fe69c2e8bb0908656535d931542ff00990289cd9a6cac1` |
| Honest scope of the SVM guest | 208–221 | `9e5facfd587264aa0977d61a6856acd5e0edddeb5fa264e1345b38b1914689af` |

The block is the heading line through the line immediately preceding the next line that
begins with `## ` (located by heading, not by line number, which drifts). Reproduce with:

```sh
awk '/^### Honest scope of the re-execution guest/{f=1} f && /^## /&&!/^### /{exit} f' \
  zk-verdict/README.md | shasum -a 256
```

and the same with `/^### Honest scope of the SVM guest/`. 003 resolves none of those items,
so the digests must be unchanged at the end of 003. **003 also does not touch
`zk-verdict/README.md:97`, the `~34 s` measurement OQ-6 now cites** — it quotes it, and
§7.1 requires the quote to be re-verified against that line at run time.
On success `gauntlet.sh --check` prints `honest-scope: 2/2 digests unchanged`.

**Kills:** M-32 a documentation edit that softens "Not yet:" to "Now closed:".

**Falsify:** `sed -i '' 's/Not yet:/Now closed:/' zk-verdict/README.md && bash scripts/ac.sh AC-16`
→ non-zero.

#### AC-17 — the pre-existing settlement path still works, and the suite total is pinned

```sh
bash scripts/ac.sh AC-17
bash zk-verdict/scripts/zk-e2e.sh   # exit 0 (after S-1; today its exit status is discarded)
```
`ac.sh AC-17` runs the whole `zk-verdict/contracts` suite with `--json`, and requires:
**56** test results in total (44 gauntlet + 12 pre-existing, both counted mechanically),
every status `Success`, and the four pre-existing `RecknZkEscrowTest` names of §1.2
present — in particular `test_real_proof_settles_to_seller`, which settles a **real
Groth16 proof**. Those four may change only in the constructor's new `refundDelay`
argument. It prints `suite: 56/56 passed`.

**S-1 is a precondition of the second command being evidence.**
`zk-verdict/scripts/zk-e2e.sh:84-85` pipes `forge test` into `grep … || true`, which
discards the exit status (`bash -c 'set -euo pipefail; (exit 7) | grep -E x || true; echo $?'`
→ `0`, run 2026-09-04). S-1 (§9) makes the script propagate it. Until S-1 lands, a green
`zk-e2e.sh` is not evidence that the suite passed and must not be cited as such.

**Kills:** M-33 a change to the `VerdictPublicValues` decode order, which makes the real
fixture stop settling. **M-34** — a contract whose every function body is `revert()`. It
fails AC-17's `Success` requirement and every authorized row, which is exactly the point: a
gauntlet made only of "must revert" rows would be satisfied by universal denial.

**Falsify:** add a fifth test to `RecknZkEscrow.t.sol` → 57 ≠ 56 → non-zero (drift is
caught; the number is normative and changing it means editing this spec).

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

It prints
`ac-selftest: 13 forge ACs, 13 observed failing when their tests are absent; degenerate dispatcher rejected`.

**What AC-18 does not do.** It does **not** detect an empty test body. Round 2 claimed it
did (`:1157-1159`) and that claim was false. **AC-21 is the only instrument for empty
bodies**, and §5.0.1 says so in one place.

**Kills:** M-43 (the degenerate dispatcher). **M-31c** (an `ac.sh` reporting success on
`|found| == 0`) and **M-31d** (a count gate comparing `>=` instead of `==`) are harness
self-checks inside AC-18 and are not entries in §5.3.

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
rows are the **44** gauntlet tests:

- **columns**: the **23 behavioural** mutants of §5.3 (the sandboxes `mutation-kill.sh`
  already builds — the two scripts share one builder) plus the **5 sweep mutants** of §5.4;
- for each column, one sandbox suite run: `forge test --root <sandbox> --json`, recording
  every test's status;
- one **control column**, the unmodified sandbox, in which all **56** tests must be
  `Success`.

**The assertion:**

> Every gauntlet test must be `Failure` in **at least one** column.

A body of `assertTrue(true)` is `Success` in every column, so the six stub tests of §5.0.1
are named and `degeneracy-sweep.sh` exits non-zero.

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

It prints `sweep: 44/44 gauntlet tests accounted for; control 56/56 pass` followed by the
matrix and the killed/exempt split. **The evidence string deliberately does not carry the
killed/exempt split**, because that split is not knowable before implementation and a
literal that cannot be predicted is r2 finding 7 all over again. The two numbers it does
carry (44 and 56) are both pinned by AC-13.

**Kills:** **M-44** — a stub suite: one forge AC's test bodies replaced by
`assertTrue(true)` with names, signatures and the manifest untouched. Under round 2's format
that AC is green; under AC-21 the sweep names all of its tests. M-44's patch is
`test/mutants/M-44.patch` and it targets **AC-02**, exactly the AC r2 used to demonstrate
the hole.

**What AC-21 does not prove.** It proves each test is *sensitive to the contract*, not that
its assertions are *correct*. A test that asserts the wrong thing but observes the contract
is red in some column and passes AC-21. §8 says so.

**Falsify:** replace the six `_AC02_` bodies with `assertTrue(true)` and run
`bash scripts/degeneracy-sweep.sh` → non-zero, naming all six. Delete the control column →
the sweep can no longer distinguish "the whole tree is broken" from "the mutants worked", so
the script must refuse to run without it (assert `control 56/56` before anything else).
Add a third name to `SWEEP_EXEMPT.txt` → non-zero.

### 5.2.1 The exit corpus (AC-1's witness that property P covers the family)

Each entry is spliced into the real file in a sandbox and must be **rejected**, with the
rejecting check recorded. **The corpus does not define the property.** Property P (§3.1.2)
is defined by the closedness of the three allowlists; the corpus is thirteen witnesses that
the closedness is real. Adding a fourteenth construct to this list costs nothing and proves
nothing new; a construct *not* on this list is rejected for the same reason the ones on it
are.

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
| E-11 | `function(address,uint256) external returns (bool) f = IERC20Min(token).transfer; f(seller, amount);` in `fund` | 9b, 9a |
| E-12 | `interface IERC20Full { function approve(address,uint256) external returns (bool); }` at top level + `IERC20Full(token).approve(seller, amount);` | 11, 9a, 9b |
| E-13 | `new Drain{value: 0}(token);` in `fund` (with `contract Drain` at top level) | 11, 9b, 13 |

**Controls (must be ACCEPTED):**

| # | splice | why it must pass |
|---|---|---|
| C-M0 | nothing (the unmodified file) | the selftest cannot pass by rejecting everything |
| C-P | `// never call approve(), permit(), or .call{value:}()` inside `fund` | the checks read code, not English. A check that fails on this is grepping prose |

E-1 and E-5 are also registered in §5.3 as **M-41** and **M-42**, because r2 named exactly
those two routes as the blocker; they are counted once in each counter and the two counters
are printed on the same line (AC-1's evidence string).

### 5.3 The kill table (source of truth for AC-14's arithmetic)

`T` — the number of distinct ids matching `^M-([0-9]+|A|F)$` between the two **anchored**
markers below (`^<!-- BEGIN KILLTABLE -->$` … `^<!-- END KILLTABLE -->$`; see AC-13's marker
rule) — is **48**. One of them (M-0) must survive; the other **47** must be killed. Every id appears in
exactly one `killed-by` cell. `scripts/mutation-kill.sh` and `scripts/gauntlet.sh --check`
both parse the region between the markers, and **nothing but table rows may appear between
them**.

<!-- BEGIN KILLTABLE -->

| class | ids | count | driven by | killed by |
|---|---|---|---|---|
| control | M-0 | 1 | both harnesses | **nothing — must survive** |
| source-text | M-1, M-13, M-14, M-15, M-16, M-17, M-18, M-19, M-35, M-36, M-37, M-38, M-41, M-42, M-A, M-F | 16 | `no-keys-selftest.sh` | AC-0 (M-13, M-A, M-F), AC-1 (the rest) |
| behavioural | M-21, M-24 | 2 | sandbox forge | AC-2 |
| behavioural | M-3, M-4, M-5 | 3 | sandbox forge | AC-3 |
| behavioural | M-6, M-7 | 2 | sandbox forge | AC-4 |
| behavioural | M-8, M-9 | 2 | sandbox forge | AC-5 |
| behavioural | M-10, M-11 | 2 | sandbox forge | AC-6 |
| behavioural | M-12, M-20 | 2 | sandbox forge | AC-7 |
| behavioural | M-40 | 1 | sandbox forge | AC-8 |
| behavioural | M-22 | 1 | sandbox forge | AC-9 |
| behavioural | M-23 | 1 | sandbox forge | AC-10 |
| behavioural | M-25, M-26 | 2 | sandbox forge | AC-11 |
| behavioural | M-27 | 1 | sandbox forge | AC-12 |
| behavioural | M-33, M-34 | 2 | sandbox forge | AC-17 |
| behavioural | M-39 | 1 | sandbox forge | AC-19 |
| behavioural | M-2 | 1 | sandbox forge | AC-20 |
| harness / document | M-28, M-29, M-30, M-45 | 4 | `mutation-kill.sh` | AC-13 |
| harness / document | M-31 | 1 | `mutation-kill.sh` | AC-15 |
| harness / document | M-32 | 1 | `mutation-kill.sh` | AC-16 |
| harness / document | M-43 | 1 | `ac-selftest.sh` | AC-18 |
| harness / document | M-44 | 1 | `degeneracy-sweep.sh` | AC-21 |

<!-- END KILLTABLE -->

Sum: `1 + 16 + (2+3+2+2+2+2+1+1+1+2+1+2+1+1) + (4+1+1+1+1) = 1 + 16 + 23 + 8 = 48`.
Killed = **47**.

**Every one of the 13 `forge` ACs owns at least one mutant** — AC-2 (M-21, M-24), AC-3,
AC-4, AC-5, AC-6, AC-7, **AC-8 (M-40)**, AC-9, AC-10, AC-11, AC-12, AC-19, AC-20. AC-13
check 8 asserts this mechanically. Round 2 failed it at AC-8 (r2 finding 6).

**Excluded from `T` by construction:** the lettered sub-mutants `M-31b`, `M-31c`, `M-31d`,
`M-32b` are harness self-checks inside AC-13 / AC-15 / AC-18. They do not match
`^M-([0-9]+|A|F)$`, so no rule has to remember to exclude them. The **five sweep mutants**
of §5.4 use the `SW-` prefix for the same reason, and the **thirteen exit-corpus entries**
of §5.2.1 use `E-`; only E-1 and E-5 have kill-table identities (M-41, M-42).

### 5.4 The sweep mutants (AC-21's columns; not counted in `T`)

Five patches against the real source, chosen so that **each leaves `setUp()` able to fund a
deal** — a mutant that breaks `setUp` makes every test fail for the wrong reason and would
turn the sweep into a rubber stamp. They live in
`zk-verdict/contracts/test/mutants/SW-N.patch`.

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

---

## 6. Test plan

### 6.1 Files

| file | purpose | ACs |
|---|---|---|
| `zk-verdict/contracts/test/KeyGauntlet.t.sol` | the unit rows, named `test_AC05_G07_…` etc. | AC-5, AC-8, AC-9, AC-10 (units), AC-12, AC-19, AC-20 |
| `zk-verdict/contracts/test/KeyGauntletFuzz.t.sol` | caller / time / parameter fuzz | AC-2, AC-3, AC-4, AC-6, AC-7, AC-11 |
| `zk-verdict/contracts/test/KeyGauntletInvariant.t.sol` + handler | random call sequences over ≥ 3 deals in ≥ 2 tokens | AC-10 (invariants) |
| `zk-verdict/contracts/test/KeyGauntletStructural.t.sol` | **at most 2** tests whose assertions no contract mutation can change; the only file whose tests may be sweep-exempt | AC-19 (G-37), AC-21 |
| `zk-verdict/contracts/test/SWEEP_EXEMPT.txt` | the exemption list, one `name # reason` per line, ≤ 2 lines | AC-21, AC-13 check 13 |
| `zk-verdict/contracts/test/mutants/M-*.patch` | one patch per kill-table mutant, applied to a **sandbox copy of the real source** | AC-1, AC-14 |
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
| `scripts/degeneracy-sweep.sh` | builds the kill matrix over 23 behavioural + 5 sweep mutants + control | AC-21 |
| `scripts/gauntlet.sh` | judge-facing runner + `docs/gauntlet.json` generator + `--check` | AC-13, AC-15, AC-16 |

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

1. **M-0 survives.** The unmodified contract passes every AC. If the harness reports M-0
   killed, the harness is broken (AC-14). The sweep's control column is the same idea for
   AC-21: 56/56 must pass before any column is interpreted.
2. **Each of the 47 mutants is killed by the AC named in §5.3** (AC-14, AC-1).
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
  `gauntlet.sh --check` (check 11); load-bearing for AC-21's SW-1 column (§5.4).
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

---

## 7. Judge-facing surface

003 owns the **machine-checked artefact**. `reckn-demo` owns the pixels. The contract
between them is the JSON below; `reckn-demo` may render it however it likes and must not
hand-edit it.

### 7.1 `docs/gauntlet.json` — schema `reckn/gauntlet/v3`

```json
{
  "schema": "reckn/gauntlet/v3",
  "generated_at": "2026-09-0?T??:??:??Z",
  "commit": "<git rev-parse HEAD>",
  "tier": "local-foundry",
  "contract": {
    "name": "RecknZkEscrow",
    "address": "0x...",
    "code_hash": "0x...",
    "verifier": "0x...",
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
    "gauntlet_tests": 44, "killed": 43, "exempt": ["test_AC19_G37_lookalike_code_hash_differs"],
    "columns": 28, "control_suite": 56
  },
  "rows": [
    { "id": "G-03", "class": "theft", "actor": "SELLER",
      "method": "settleWithProof",
      "precondition": "real verifying proof bound to a different deal",
      "expected": "revert:BindingMismatch",
      "observed": "revert:BindingMismatch",
      "status": "AS_SPECIFIED",
      "test": "testFuzz_AC06_G03_foreign_binding_reverts" }
  ],
  "acceptance": [
    { "id": "AC-06", "kind": "forge", "tests_expected": 2, "tests_ran": 2, "passed": 2 }
  ],
  "totals": {
    "rows": 37, "theft": 20, "authorized": 7, "disclosed": 10,
    "as_specified": 37, "keys_that_helped": 0,
    "acceptance_criteria": 22, "gauntlet_tests": 44, "suite_tests": 56,
    "mutants": 48, "mutants_killed": 47, "control_survived": true
  }
}
```

- `status ∈ {AS_SPECIFIED, DEVIATED}`.
- `contract.code_hash` is `extcodehash(escrow)` read on the local chain. It is **part 1 of
  the four-part deployment check** (§2.3 A); without it the check is unperformable, which is
  why AC-13 check 7 fails on an empty or missing value and M-45 exists.
- `keys_that_helped` is **computed**: the number of theft rows whose `observed` differed
  between a key-holding actor and a fuzzed stranger. Non-zero ⇒ `gauntlet.sh` exits
  non-zero.
- `signed_rows` is the list of row ids exercised by a **real signature** from a published
  key (OQ-1). It is `[]` unless OQ-1's anvil mode is built; §7.2's third money-shot line is
  derived from its length and `gauntlet.sh --check` fails if the printed number and
  `len(signed_rows)` disagree.
- `sweep.exempt` mirrors `SWEEP_EXEMPT.txt`; `len(exempt) ≤ 2` and
  `killed + len(exempt) == gauntlet_tests` are both asserted (AC-13 check 13, AC-21).
- **`proving` (r2 finding 5 — round 2's OQ-6 asserted an absence the repo contradicts).**
  Two guests, two fields:
  - `predicate_guest_wrap_seconds: 34` — **a real measurement in this repo**, of the gnark
    wrap of the *predicate* guest (~15.9M constraints), source `zk-verdict/README.md:97`.
  - `reexec_guest_seconds: null` — the re-execution guest (`program-revm`, ~410k cycles of
    core proving before the same wrap, `CLAUDE.md:34-36`) has **not** been timed.
  - **Source re-verification.** `gauntlet.sh --check` must re-read the cited line and fail
    if it no longer contains the number:
    `sed -n '97p' zk-verdict/README.md | grep -q '~34 s'`. A quoted measurement whose source
    has moved is a stale number, and stale numbers are how "passing" gets written for things
    that were not run (`AGENTS.md` §5).
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
- `acceptance[]` mirrors §5.1 and is what AC-13 check 3 compares against `--list`.

### 7.2 Terminal rendering

```
▶ KEY GAUNTLET — LOCAL FOUNDRY ONLY — throwaway development keys, no real funds
  escrow   0x...   codehash 0x...   verifier 0x...   vkey 0x...
  refundDelay 86400s (min 3600 / max 2592000)
  Seller's four-part deployment check: codehash · verifier · vkey · refundDelay
  Seller's terms check (AFTER the Funded event): token · amount · seller · deadline

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

  37/37 rows as specified.
  Keys published: 5.  Addresses exercised: 5.  Addresses that helped: 0.
  Transactions signed by a published key: 0 — Foundry impersonates addresses (vm.prank);
  no published key signed anything. See §8 of docs/specs/003-key-gauntlet.md.
  Gauntlet tests: 44.  Failing under at least one mutant: 43.  Sweep-exempt: 1 (structural).
```

**The money-shot's third line** is mandatory and its number is derived from `signed_rows`.
If OQ-1's signed mode is built it reads
`Transactions signed by a published key: 3 (G-03, G-13, G-14).`

**The money-shot's fourth line is new in r3.** It publishes the sweep split, so a growing
exemption list is on screen rather than in a file nobody opens.

### 7.3 What `reckn-demo` must say out loud

- The surface grew from two functions to three, and `IERC20Min` from two declared functions
  to three, and why (`AGENTS.md` §0's requirement).
- The tier: local Foundry / anvil. Not testnet, not mainnet.
- **`vm.prank` impersonates addresses; no key signed** (unless OQ-1 is built).
- The **ten** disclosed rows are shown, not hidden — G-18, G-23, G-27, G-28, G-29,
  **G-33, G-34, G-35, G-36, G-37** — and G-33 and G-36 in particular are shown as rows that
  **succeed**, not as reverts.
- The seller has **two** checks at **two** times (§2.3), and 003 makes them possible, not
  automatic.

---

## 8. What this does not prove

Written here so that no one has to say it under questioning.

- **A finite fuzz is not a proof.** AC-2/AC-3/AC-4/AC-7/AC-11/AC-12 sample the address
  space and the timeline; they do not establish caller-independence for all inputs. The
  mutation kill table (AC-14) and the kill matrix (AC-21) raise the cost of a degenerate
  implementation and of a degenerate test suite; they do not eliminate either. There is no
  formal verification here.

  **On the word "impossible."** This spec never says an *attack* is impossible, and never
  says anything is impossible "in principle". The word appears only in §5.0.1 and in its
  restatement in the next bullet, always in the same sentence — *"the five gates make zero
  tests impossible; they do not make zero assertions impossible"* — where it is a statement
  about a script's exit condition (`|found| == N ≥ 1`, checked twice), not about an
  adversary. No count of the word is asserted here — a literal that drifts is r2 finding 7,
  and this document has been bitten by one already. Every
  claim about an adversary in this document is bounded by a named instrument and a named
  residual. **A fuzz in particular cannot find a backdoor keyed on a constant** — that is
  what the structural checks are for (R-5).
- **The AC gates read names and statuses, never bodies** (§5.0.1). The format makes *zero
  tests* impossible. It does **not** make *zero assertions* impossible. Round 2 claimed it
  did (AC-18 observation 5) and the claim was false. Two instruments cover the gap and only
  two: **AC-21**, which requires every gauntlet test to be observed *failing* against at
  least one mutant, and **AC-14**, which requires every forge AC to own at least one mutant.
- **AC-21 proves sensitivity, not correctness.** A test that observes the contract and
  asserts the wrong thing is red in some column and passes AC-21. Up to two tests may be
  sweep-exempt, and the exemption is printed on screen (§7.2) rather than hidden.
- **The matrix is exhaustive with respect to §3.1's enumeration** (two exits, one inward
  site, one writing entry point, reentrancy, out-of-band value, deployment choice, token
  behaviour). It is **not** exhaustive with respect to attacks outside that frame —
  compiler bugs, EVM-level behaviour changes, and the SP1 verifier's own soundness are all
  outside it.
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
  - that a value movement expressed with **no call-shaped token at all** would be caught.
    The authors of r3 know of no such construct in Solidity that reaches an ERC-20 balance,
    but "we could not think of one" is not a proof and is not claimed as one.
- **Foundry `vm.prank` impersonates an address without using its private key.** The 37 rows
  demonstrate **address-level** behaviour. Unless `signed_rows` is non-empty, no published
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
  paid out of other deals' principal in the same token — **not** "it kills M-23"; M-23 is
  killed by AC-10's multi-deal invariant independently of any on-chain bound (r2 finding 8).
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
  **four-part** deployment check (§2.3 A: code hash, verifier, vkey, `refundDelay`), and it
  is a human/off-chain check, not a mechanism. 003 makes it *possible* by printing all four
  values including `contract.code_hash`; it does not make it automatic.
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
  here by N-2. `zk-verdict/README.md`'s Honest scope is the authority and is untouched
  (AC-16): the in-guest precompile restriction, the `u64` verdict values (`u64_low` =
  limb 0 only, ≥ 2^64 truncated — task `008`'s subject, not 003's), the 1-CALL + 1-delta
  scale, and the off-chain `state_root`↔header binding are all exactly as true after 003 as
  before it.
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
| D-4 | `README.md:550-551`, `README.md:706` | "`forge test`: **12\npassing**" (the string spans two lines), "— 12 tests" | Update from the **actual** `forge test` output (expected 56, AC-17). Do not estimate (`AGENTS.md` §5). **Round 2 cited `:669`; r2's correction said `:700`; both are wrong. `grep -n "12 tests" README.md` → `706`, run 2026-09-04, and the first site spans `:550-551` rather than `:551` alone.** |
| D-5 | `zk-verdict/README.md:234-237` | the two-bullet function list | Add `refundAfterDeadline(dealId)` — permissionless, pays the buyer, only after the window. **Do not touch lines 154-164 or 208-221** (AC-16), and **do not touch line 97** (OQ-6's source) |
| D-6 | `zk-verdict/README.md:239-243` | "Tested (`RecknZkEscrow.t.sol`): …" | Add the gauntlet: keys published, matrix size, the one-command runner, and the `vm.prank` caveat |
| D-7 | `STATUS.md:15` | 撤退可能点 wording, already aligned with `AGENTS.md` §7 | **Round 2 also cited `STATUS.md:39-40` as holding a pointer to a `docs/specs/001-keyless-timeout.md`. It does not: `:39-40` is the review table, and the string `001-keyless-timeout` occurs nowhere in `STATUS.md` (`grep -rn "001-keyless-timeout" STATUS.md docs`, re-run 2026-09-04 — the only occurrences are inside this spec and inside `docs/reviews/003-spec-r2.md`). There is nothing to fix there.** The real obligation is to add the 003 round-3 row to the review table and record the surface change |
| D-8 | `SUBMISSION.md:156-160` | ZK settlement bullet | Add the gauntlet and the timeout; keep the SVM/EVM honest-scope sentences intact |
| D-9 | `README.md:67` | "the enumerated `fund` / `settleWithProof` / `refundAfterDeadline`" | Already correct — add that all three must now be **present**, not merely permitted (two-sided check 2), and that the value exits are pinned by a **closed allowlist over the whole file**, not by a list of forbidden method names |
| D-10 | `AGENTS.md` §0 | "列挙された関数面 … を増やすなら" | The permitted function set does not change, but the **script gains checks 5–13, one output line, and a scan region that is the whole file for checks 9/11/12/13**; and `IERC20Min` gains one declared function (`balanceOf`, C-4). Record all of that in the same commit, per §0's own instruction, and state that the interface was **not** changed (N-9) and that the scope widening is a **tightening** (§4.5) |

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

1. **P1** — C-1…C-7 in `RecknZkEscrow.sol` + minimal adjustment of the four existing
   `RecknZkEscrowTest` tests to the new constructor. Ends green on `forge test`.
2. **P2** — `scripts/ac.sh` + `scripts/ac-selftest.sh` (§5.0/§5.1). **Built before any
   gauntlet test exists**, and its first demonstration is that every `forge` AC is
   **red** (AC-18 observation 1). Ends green on AC-18's control (observation 6) only after
   P3/P4.
3. **P3** — `scripts/no-keys.sh` checks 5–13, two-sided check 2, the `checks: 13/13 passed`
   line, `scripts/no-keys-selftest.sh` with the sandbox layout, the 16 source-text mutants
   and the 13-entry exit corpus with its two controls. Ends green on AC-0, AC-1.
   **This part is the round-3 blocker; do it before the test-writing parts** so that
   AC-14's Falsify (apply M-41 to the live tree → AC-0 and AC-1 red) can be run early.
4. **P4** — mocks (including `RecipientFeeERC20`) + `KeyGauntlet.t.sol` +
   `KeyGauntletStructural.t.sol` + `SWEEP_EXEMPT.txt`. Ends green on AC-5, AC-8, AC-9,
   AC-12, AC-19, AC-20 and AC-10's unit half.
5. **P5** — `KeyGauntletFuzz.t.sol` + `KeyGauntletInvariant.t.sol`. Ends green on AC-2,
   AC-3, AC-4, AC-6, AC-7, AC-10, AC-11.
6. **P6** — `test/mutants/M-*.patch` + `scripts/mutation-kill.sh`, with the shared sandbox
   builder. Ends green on AC-14 and on AC-18 in full. **Record the measured wall-clock** in
   the implementation report and in `gauntlet.json.durations`; do not estimate it here — a
   forced `forge build` of this project measured ~0.9 s on 2026-09-04, but the sandbox path
   has not been run and this spec makes **no** claim about the total.
7. **P7** — `test/mutants/SW-*.patch` + `scripts/degeneracy-sweep.sh` reusing P6's sandbox
   builder. Ends green on AC-21. **Expect this part to fail first**: it is designed to find
   tests written in P4/P5 that assert nothing, and finding some is the intended outcome, not
   an error in the sweep.
8. **P8** — `scripts/gauntlet.sh`, `docs/gauntlet.json`, the digest check, the gag-rule
   grep, S-1. Ends green on AC-13, AC-15, AC-16, AC-17.
9. **P9** — D-1…D-10. Ends green on `bash scripts/ac.sh --all` from a clean tree.

---

## 10. Open questions

Genuinely undecided. **Do not guess; bring these back rather than inventing an answer.**

- **OQ-1 — Do the published keys have to actually sign?** (r1 finding 8.) The 37 rows run
  in Foundry, where `vm.prank` impersonates an address **without using its private key**.
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
  - close **G-33** by letting the seller decline a deployment whose clock is too short
    *before* doing the work, rather than relying on the off-chain check of §2.3(A).

  *Recommendation:* **not in 003** — it is outside the scope line (G-33 has a true expected
  result today, so no matrix row is missing an answer), and the surface count is worth more
  during the event than the closure of a row the gauntlet already displays honestly.
  **Founder call, on cost and demo surface.** If the answer is yes, it is a new task with a
  declared surface change, not an edit to 003.
- **OQ-5 — Should `scripts/no-keys.sh` gain a target/path argument at all?** (r1 finding
  12.) 003 **does not add one** (N-9): `AGENTS.md` §0 reserves that script's semantics
  to the founder, and "no-keys.sh passed" must keep meaning one specific file. r2 confirmed
  this is the right call. The sandbox-layout self-test achieves the same coverage with zero
  interface change (§4.5.8, verified 2026-09-04). **Returned to the founder as a question,
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
  from slack.**

---

## Appendix A — response to `docs/reviews/003-spec-r2.md` (round 3)

All 14 findings (BLOCKER 2 / MAJOR 7 / MINOR 5), with where each landed.
`adopted` = the reviewer's required change is implemented as written; `stronger` = a change
that meets the stated requirement and goes further, with the reason; `founder` = returned
as an open question.

| # | sev | finding | disposition | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | checks 9/10 count two method names → `approve` route A and out-of-body route B both drain; §3.1:245 and §8:1464-1466 are false; the spec relies on the blind spot at C-4 while denying it exists | **stronger.** Not "add `approve`/`increaseAllowance`/`decreaseAllowance`/`permit` to check 6" — that is the same denylist one name later (R-7). Check 9 is **rewritten as a closed allowlist over the whole file** (property P): 10 permitted member calls with pinned forms and ranges, plus a plain-call allowlist that catches function pointers and assembly opcodes. **Check 11** closes the file's top-level declarations (route B, structurally). **Check 12** closes `IERC20Min`'s declared function set (route A at the declaration). Check 13 is an explicitly-labelled redundant backstop and carries none of the claim. **C-4's blind-spot sentence is deleted** and the contradiction resolved: the interface is now inside the checked region. Mutants **M-41** (route A) and **M-42** (route B) added under AC-1; a **13-entry exit corpus** with a **prose control** is the witness that the property covers the family. §3.1 and §8 re-worded to the earned statement | §3.1.1, §3.1.2, §4.5.3–§4.5.6, §5.2.1, AC-1, AC-14 Falsify, §5.3, §8, R-7 |
| 2 | **BLOCKER** | the five gates never open test bodies; 6 stubs make AC-02 green; AC-18 observation 5 is false; AC-8 has no mutant; AC-18 is self-referential | **stronger, four parts.** (a) Observation 5 **deleted**; the stub attack is quoted verbatim in §5.0.1 as a thing the format does **not** stop. (b) §5.0.1 and §8 state plainly that the format prevents *zero tests*, not *zero assertions*. (c) **AC-21 (new)** — the kill matrix: every gauntlet test must be `Failure` in ≥ 1 of 28 columns (23 behavioural mutants + 5 sweep mutants), with a control column, an exemption budget of **2** confined to one file and printed in the money-shot. A stub is green in every column and is named. Mutant **M-44** is the stub suite itself. R-2b forbids bare `vm.expectRevert()`, without which SW-1's column would be blind. (d) **AC-8 given M-40** (M-21 split), and "every forge AC owns ≥ 1 mutant" is now **AC-13 check 8**, mechanical. (e) AC-18's self-reference cut three ways: a direct founder command, `gauntlet.sh` invoking the harness scripts **directly**, and observation 5 replaced by a **degenerate-dispatcher** detector (M-43) that a degenerate `ac.sh` cannot survive | §5.0.1, AC-18, **AC-21**, §5.3, §5.4, R-2b, AC-13 checks 8/11/13, §6.3, §8 |
| 3 | MAJOR | §1.3 defines "exact-transfer" only on the escrow's side; a recipient-fee token underpays and still terminates | **adopted.** Clause **(d)** added; row **G-36** added as `disclosed` with the honest expected value (*the call succeeds and the seller is underpaid*); `RecipientFeeERC20` mock; AC-19's count 6 → **8**; §8 states that **C-5 cannot detect this from the escrow side**, so it is a disclosure, not a fix; INV-6 re-worded to be explicitly about the escrow's side only | §1.3(d), G-36, §4.3, AC-19, INV-6, §6.1, §6.2, §8 |
| 4 | MAJOR | §2.3 lists the escrow bytecode and then omits it from its own three-part check; `d.token` is not checkable before funding but §2.2 says it is | **adopted.** The check is now **four-part** (`extcodehash` first), `contract.code_hash` is printed in `gauntlet.json` and in the banner, and **M-45** kills a JSON written without it. Row **G-37** added for the look-alike deployment. §2.3 is split into **(A) deployment check, before funding** and **(B) terms check, after the `Funded` event**; §2.2's `SELLER` row and `BUYER` row are corrected accordingly | §2.2, §2.3, G-37, §7.1, §7.2, AC-19, M-45 |
| 5 | MAJOR | OQ-6's premise is false — `zk-verdict/README.md:97` has ~34 s | **adopted.** The "no measured wall-clock anywhere in this repo" sentence is **deleted**; OQ-6 cites `zk-verdict/README.md:97` (re-verified by grep, 2026-09-04), distinguishes the two guests, and `proving_seconds_measured: null` becomes a **`proving` object** with `predicate_guest_wrap_seconds: 34` + source and `reexec_guest_seconds: null`. `gauntlet.sh --check` **re-reads the cited line** and fails if the number has moved. The gag rule is **kept** and `MIN_REFUND_DELAY` is **not** changed on a number measured for a different guest | OQ-6, §7.1, C-2, INV-10, §8 |
| 6 | MAJOR | M-21 names two different mutations; AC-8 ends up with no mutant | **adopted.** M-21 = verifier return ignored → **AC-2**; **M-40** = `fund` skips the delta check → **AC-8**. §5.3's total re-derived (48), AC-14's printed count re-derived (47 killed), and the general rule added as AC-13 check 8 | AC-2, AC-8, §5.3, AC-13 |
| 7 | MAJOR | AC-14's count check gives three different numbers (41 / 42 / 46-by-grep) for one comparison | **adopted.** The kill table is delimited by `<!-- BEGIN KILLTABLE -->` / `<!-- END KILLTABLE -->` and `T` is **defined as an expression**: distinct ids matching `^M-([0-9]+\|A\|F)$` between the markers = **48**. The lettered sub-mutants are excluded *by the pattern*, not by a rule to remember; sweep mutants use `SW-` and corpus entries use `E-` for the same reason. AC-14's evidence literal is **derived** — `gauntlet.sh --check` (check 9) recomputes `T` and asserts the manifest reads `mutation: <T> mutants, <T−1> killed, 1 control survived`. A reviewer's reproduction command is printed in AC-14 | §5.3, AC-14, AC-13 check 9, §5.1 |
| 8 | MAJOR | C-5's justification ("the upper bound is what kills M-23") is refuted by §5.3, which assigns M-23 to AC-10 | **adopted; the decision is unchanged, the reason is replaced.** C-5 now carries the **runtime** reason (an unbounded outward transfer is paid out of other deals' principal in the same token, and the contract would still write the terminal state), and states explicitly that **M-23 is killed by AC-10's multi-deal invariant independently of C-5's bound**. AC-10 and §8 say the same. `>=` is separately rejected because it does not rescue G-34 and would let an outbound-fee token over-pay | C-5, AC-10, §8 |
| 9 | MAJOR | N-5's "seller-acceptance is a key" is too broad, and OQ-4 rests on it | **adopted.** N-5 is narrowed to *authority over the outcome of an already-funded deal*; **seller-acceptance is listed separately as consent to enter, explicitly not an outcome key**, and excluded **on scope grounds, not on claim grounds**. OQ-4 is rewritten so the founder decides on cost and demo surface (a fourth function is a declared surface change; a fourth state adds rows) instead of on a false claim-shape argument | N-5, N-6, OQ-4 |
| 10 | MINOR | AC-13's marker-uniqueness assertion is false against this document | **adopted, and hardened one level further.** Round 3's first draft repeated the defect at the next level: the *full* `<!-- BEGIN MATRIX -->` string now occurs 3 times in this document (marker + AC-13's prose + this table) and the `KILLTABLE` one 4 times, so a substring count is wrong too. The rule is therefore **anchored to a whole line** (`^<!-- BEGIN MATRIX -->$` etc.), for both the uniqueness assertion and the extraction; measured 2026-09-04: anchored `1/1/1/1`, unanchored `3/3/4/4`. AC-14's reproduction command carries the anchors and a note saying why | AC-13, AC-14 |
| 11 | MINOR | AC-1's Falsify arithmetic is wrong on both numbers | **adopted, and re-derived for the new checks.** The source-text set is **16**; deleting check 9 alone leaves M-35/M-36/M-37 surviving (M-41 still dies at check 12, M-42 at check 11), so the line reads `16 source mutants, 13 rejected`. The three-check deletion is given as the full falsifier: `16 source mutants, 11 rejected; exit-corpus 0/13 rejected` | AC-1 |
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

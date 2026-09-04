# 003 — Key Gauntlet (folds in 001: keyless timeout)

| | |
|---|---|
| Status | **DRAFT — round 2.** Responds to every item in `docs/reviews/003-spec-r1.md` (`VERDICT: CHANGES`). Response table: **Appendix A**. |
| Owner | `reckn-spec` (frame thin). Implementation is `reckn-codex-impl`. |
| Supersedes | task `001` (keyless timeout) — folded in per founder ruling, `AGENTS.md` §3 |
| Tier claimed | **local anvil / Foundry only.** No testnet, no mainnet, no real funds. |
| Surface touched | `zk-verdict/contracts/src/RecknZkEscrow.sol`, `zk-verdict/contracts/test/`, `zk-verdict/contracts/foundry.toml`, `scripts/no-keys.sh` (**additive checks only** — §4.5), `scripts/` (new: `ac.sh`, `ac-selftest.sh`, `no-keys-selftest.sh`, `mutation-kill.sh`, `gauntlet.sh`), `zk-verdict/scripts/zk-e2e.sh` (**one line**, S-1), `docs/gauntlet.json` (new), `README.md`, `CLAUDE.md`, `AGENTS.md`, `STATUS.md`, `SUBMISSION.md`, `zk-verdict/README.md` (**not** its Honest-scope blocks) |
| Surface **not** touched | `contracts/RecknEscrow*` (optimistic path, `AGENTS.md` §8), `zk-verdict/program-revm`, `zk-verdict/program-svm`, `zk-verdict/lib`, `zk-verdict/script`, `docs/ethonline-2026/*` (founder documents) |

Section numbering is normative. Task `004` must reuse this structure: §1 claim/non-goals,
§2 attacker model, §3 matrix, §4 state machine + invariants, §5 acceptance criteria,
§6 test plan, §7 judge-facing surface, §8 what this does not prove, §9 implementation
obligations, §10 open questions. **Appendix A is round-2 bookkeeping and is not part of the
reusable structure.**

**The scope line, fixed by r1 and binding on 004:** 003 may change
`RecknZkEscrow.sol` **only where a matrix row would otherwise have no true expected
result**. SafeERC20, permit/EIP-3009, cancellation, multi-payout splits and any `view`
helper are out (N-3, N-6).

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
- **nothing counts the contract's token call sites.** `scripts/no-keys.sh` has no such
  check; verified by running the script against a mutated copy on 2026-09-04 (§3.1)

003 turns the prose into a **machine-checked matrix**, closes the timeout gap inside that
matrix, and pins the contract's value exits so the matrix's basis is a build condition
rather than a sentence.

### 1.3 The supported token class (definition, used by §3, §4 and §8)

An ERC-20 `T` is **exact-transfer** with respect to this escrow iff, for every call the
escrow makes:

- **(a)** a `T.transferFrom(a, escrow, x)` that returns without reverting increases
  `T.balanceOf(escrow)` by **exactly** `x`;
- **(b)** a `T.transfer(b, x)` that returns without reverting decreases
  `T.balanceOf(escrow)` by **exactly** `x`;
- **(c)** `T.balanceOf(escrow)` changes only as the result of a transfer involving the
  escrow — no rebasing, no share accounting, no balance drift between two calls.

**003 supports exactly this class.** Tokens outside it are handled as follows, and both
outcomes are in the matrix rather than in a footnote:

| violated | what happens | row |
|---|---|---|
| (a) — inbound fee, `false` return, silent no-op | `fund` reverts `UnderFunded`; **fails closed**, no principal at risk | G-20, G-21 |
| (b) — outbound fee | funds cleanly, then **both exits revert `PayoutFailed` forever**; the deal is permanently `Funded` | **G-34** |
| (c) — rebasing / share-accounted | same as (b) | **G-35** |
| `transfer` reverts to one address (blacklist) | that direction bricks; the other direction still works | G-18, G-23 |

The (b)/(c) residual is **created by C-5 of this spec** and is stated in §8.

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
- **N-5** Any deadline-extension, seller-bond, seller-acceptance, dispute-reopen, or
  arbitration mechanism. Every one of them needs a trigger held by a party; that is a key.
  This is why G-33 is **disclosed** and not fixed.
- **N-6** SafeERC20 / permit / EIP-3009 integration, multi-payout splits, partial
  settlement, or deal cancellation by mutual consent. Mutual consent is two keys.
- **N-7** Resolving anything in `zk-verdict/README.md` "Honest scope" (precompiles, `u64`
  verdict values, 1 CALL + 1 delta, off-chain header binding). 003 claims none of them.
  §5 AC-16 makes the non-resolution machine-checkable.
- **N-8** Predicate non-degeneracy. 003 does not test whether a predicate can be satisfied
  by a seller who does nothing (`zk-verdict/README.md`'s `--credit 42` → delta 0 →
  `Failed`). That property lives in the guest and the predicate, which N-2 freezes here.
  003's own analogue of that failure — *a gauntlet a do-nothing contract could pass* — is
  covered by the authorized rows, R-3, and mutant M-34 (§5.3).
- **N-9** Adding a target/path argument to `scripts/no-keys.sh`. r1 finding 12 proposed
  one; `AGENTS.md` §0 reserves the semantics of that script to the founder, so r2 does
  **not** add it (OQ-5). The self-test achieves the same end with **zero interface change**
  by sandboxing the whole layout (§5 AC-1).

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

**What the gauntlet actually exercises.** The 35 rows run in Foundry, where `vm.prank`
impersonates an **address without touching its private key**. The rows therefore
demonstrate address-level behaviour. The published keys are printed so a judge can verify
they derive to those addresses; unless OQ-1's signed mode is built, **no published key
signs anything**. This is stated in §8 and printed by `gauntlet.sh` (§7.2), not left to
the reader.

### 2.2 Capability table

Everything each actor *can* do, and everything they cannot:

| actor | can | cannot |
|---|---|---|
| `BUYER` | fund new deals; call `settleWithProof` with any bytes; call `refundAfterDeadline`; receive `Failed`/refund payouts; **choose which deployment to fund, and therefore its `refundDelay`** (G-33) | redirect a `Reproduced` payout; refund before the deadline; cancel; change `seller`/`amount`/`dealBinding`/`token` after funding; stop a valid proof from settling before the deadline |
| `SELLER` | the same public surface as anyone; receive `Reproduced` payouts; **refuse to work until the pre-funding check passes** (§2.3) | cause a payout without a verifying proof bound to this deal; flip a `Failed` verdict; prevent a post-deadline refund; extend the deadline |
| `KEEPER` | submit or withhold a proof | change the outcome a proof carries; settle a deal a proof is not bound to; be paid for submitting; prevent anyone else from submitting the same proof |
| `DEPLOYER` | choose `verifier` and `refundDelay` **at construction, before any deal exists**; deploy other escrows | anything about any deal in the deployed escrow; nothing is stored about them (`no-keys.sh` check 4, AC-20) |
| `STRANGER` | the same public surface as anyone | the same as everyone |
| `ATTACKER_CONTRACT` | reenter during payouts; be a lying token; donate tokens; force-send ETH | cause a second payout, corrupt another deal, or move a token it does not control |

### 2.3 Residual trust, stated up front — the pre-funding check

Three things are chosen by the deployer at construction and are then immutable and
publicly readable **before anyone funds**:

- `verifier` — the `RecknVerdictVerifier` address, which in turn immutably holds the SP1
  verifier address and `verdictProgramVKey` (`RecknVerdictVerifier.sol:37-45`)
- `refundDelay` — the settlement window (new in 003, §4.1)
- the escrow bytecode itself

**The pre-funding check is therefore three-part: `verifier`, `verdictProgramVKey`, and
`refundDelay`.** r1 finding 7 is why `refundDelay` is in that list: the buyer picks the
deployment, so the buyer picks the clock, and a clock shorter than the proving time is a
refund the buyer can take after receiving the work (row **G-33**). That is not theft under
the contract's rules and no key is involved — which is exactly why it must be a row and a
seller-side check rather than a footnote.

A *fraudulent deployment* (rogue verifier, or a vkey for a program that always emits
`Reproduced`) settles fraudulently — but only for deals funded **into that deployment**.
This is not a key over an existing deal; it is a choice made before the deal exists. Row
G-29 makes it explicit. `gauntlet.json` must print all three values so the check is
possible (AC-15).

**Who must perform the check:** the buyer for `verifier`/vkey (their principal), the
**seller** for `refundDelay` (their payment). §8 says so; the demo says so.

---

## 3. Theft-path matrix

### 3.1 Basis of exhaustiveness

Enumerated by **exits**, not by imagination.

ERC-20 value leaves `RecknZkEscrow` only where the contract itself calls a token
transfer. In the post-003 contract there are exactly **two** such call sites:

- **L1** — in `settleWithProof`: `transfer(to, d.amount)` where `to ∈ {d.seller, d.buyer}`
- **L2** — in `refundAfterDeadline`: `transfer(d.buyer, d.amount)`

and one inward site, `transferFrom(msg.sender, address(this), amount)` in `fund`.

**r1 finding 3 — what round 1 got wrong.** Round 1 wrote that "AC-1 turns each of those
into a build condition, so the enumeration cannot silently grow." **That did not follow
and the sentence is deleted.** None of round 1's checks counted call sites. Verified by
running the real script against a mutated copy of the real file on 2026-09-04:

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

The holder of that address calls `fund` with a fresh `dealId`, a nonzero `dealBinding` and
`amount == 0`; every escrowed balance of `token` leaves, and C-4's delta check then
observes `0 → 0 == amount` and creates the deal. Round 1's checks 1/3/5/6/7/8 all pass it
(`msg.sender` is expressly permitted inside `fund`), AC-11 only fuzzes `fund` against an
*existing* `dealId`, and AC-2 fuzzes `settleWithProof`.

**What round 2 does instead.** `scripts/no-keys.sh` gains **check 9**, which counts and
pins the token call sites, and **check 10**, which pins `fund`'s three uses of
`msg.sender` (§4.5). With those:

- a third `.transfer(` anywhere in the body fails the count;
- a `.transfer(` inside `fund` fails the per-function count;
- a `transferFrom(victim, attacker, x)` — which would spend a buyer's outstanding
  allowance — fails the pinned argument form;
- `payable`, `receive`, `fallback`, `.call{value`, `selfdestruct` are all forbidden, so
  there is no ETH exit at all.

**The earned statement, replacing the deleted one:** the enumeration cannot grow *without
a visible edit to `scripts/no-keys.sh`*, and `AGENTS.md` §0 makes such an edit a claim
change that must be declared in the same commit. It is **not** the case that the
enumeration cannot grow at all: an implementer who edits check 9 and the spec together can
grow it. That is a reviewer-visible act, not a silent one. §8 keeps this distinction.

Given the enumeration, every theft is an attempt to reach L1 or L2 with a destination,
amount, deal, or timing that the deal did not authorize, **or** an attempt to corrupt the
state that L1 and L2 read (`d.seller`, `d.buyer`, `d.amount`, `d.state`, `d.fundedAt`,
`d.dealBinding`). The matrix is the cross product of:

- **exit** × **actor** × **precondition**, for L1 and L2 (classes A and B)
- **state corruption** through the only writing entry point, `fund` (class C)
- **control-flow** attacks that interleave with an exit (class D)
- **out-of-band** value movement that does not go through an entry point (class E)
- **choices made before the deal exists** — deployment parameters (class F: G-29, G-33)

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
| G-29 | disclosed | `DEPLOYER` or attacker | deploys **their own** `RecknZkEscrow` with a rogue verifier / vkey | — | the honest escrow's deals are untouched; the rogue escrow only affects deals funded into it. Part 1–2 of the **pre-funding** check (§2.3) |
| G-30 | theft | `DEPLOYER` | rows G-01, G-03, G-06, G-07, G-11, G-15, G-19, G-31 replayed from the deployer address | — | **byte-identical results to `STRANGER`.** The deployer has no stored role |
| G-31 | theft | fuzzed caller | `settleWithProof` **and** `refundAfterDeadline` | `dealId` never funded (fuzzed `dealId`) | both revert `BadState`; no storage is written |
| G-32 | theft | fuzzed caller | any successful settle/refund of a deal in token `T` | other deals Funded in token `U ≠ T` | token `U`'s escrow balance is **unchanged**; only `T` moves |
| G-33 | disclosed | `BUYER` | deploys an escrow whose `refundDelay` is shorter than the proving time, funds it, takes delivery, calls `refundAfterDeadline` while the proof is still being generated | `block.timestamp ≥ fundedAt + refundDelay`, no proof yet | **the refund succeeds.** It is not theft under the contract's rules; no key is used. The seller's only defence is part 3 of the pre-funding check (§2.3). A late valid `Reproduced` proof then reverts `BadState` (G-17) |
| G-34 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | token has an **outbound** fee (funds cleanly, escrow-side decrease ≠ `d.amount`) | revert `PayoutFailed`; state stays `Funded`; **retryable forever, never succeeds** — the deal is permanently stuck. Residual created by C-5 |
| G-35 | disclosed | anyone | `settleWithProof` / `refundAfterDeadline` | **rebasing / share-accounted** token; the escrow's balance moved between `fund` and payout | revert `PayoutFailed` (or `UnderFunded` at `fund` if the drift is downward before funding completes); state stays `Funded`; permanently stuck. Residual created by C-5 |

<!-- END MATRIX -->

**35 rows. 20 theft, 7 authorized, 8 disclosed** — the counts are checked mechanically
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
  in-contract floor binds them. The mitigation for G-33 is the seller's pre-funding check
  (§2.3). If `gauntlet.json` ever claims a proving-time basis for the window, the number
  must be **measured** and carried in `proving_seconds_measured` (§7.1, AC-15) — never
  assumed (`AGENTS.md` §5).
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
  `IERC20Min` gains `function balanceOf(address) external view returns (uint256);`
  (the interface is declared **above** `contract RecknZkEscrow` and is outside
  `no-keys.sh`'s scanned body, so this does not widen the enumerated surface).
- **C-5 — payouts are verified, with the residual named (r1 finding 6).**
  `settleWithProof` and `refundAfterDeadline` each measure the escrow's `balanceOf` before
  and after their `transfer` and revert `PayoutFailed()` unless it decreased by **exactly**
  `d.amount`.
  **Decision, and why exact and not `>=`:** the upper bound is what stops M-23
  (`transfer(to, token.balanceOf(address(this)))`, which drains other deals and donations
  and passes every single-deal test). `decrease >= d.amount` admits M-23; adding an upper
  bound back makes it exact again. A recipient-side check does not close it either,
  because the recipient may be a contract that moves the tokens in a hook.
  **The cost, admitted:** the check is the same condition as §1.3(b)+(c), so a token that
  funds cleanly but does not move exactly `d.amount` outward **bricks both exits forever**
  — rows **G-34/G-35**, INV-8, §8. That residual is created here and is asymmetric with
  G-21 (which fails closed before any money is at risk). It is disclosed rather than
  fixed because every fix that unbricks it is either a sweep (INV-6 gone) or a party with
  a trigger (a key).
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
  `uint64 deadline` (off-chain readers need it; there is no view helper, see N-3). New
  event `RefundedAfterDeadline(bytes32 indexed dealId, address indexed to, uint256 amount,
  uint64 deadline)`. No off-chain code consumes this ABI today — the only consumers of
  `RecknZkEscrow` outside `zk-verdict/contracts/test/` are prose documents and
  `zk-verdict/scripts/zk-e2e.sh:85`, which greps test *names* (verified by grep across
  `*.rs`, `*.ts`, `*.js`, `*.sh`, `*.json`, 2026-09-04; confirmed independently in r1).

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
| `Funded → *` with value leaving from `fund` | check 9 pins `.transfer(` inside `fund` at 0 | G-19, AC-1 |
| **terminal-but-unpaid** (`Settled`/`Refunded` with no value moved) | C-5 reverts unless the balance fell by exactly `d.amount` | G-18 |
| **funded-but-unfunded** (`Funded` with no value received) | C-4 reverts unless the balance rose by exactly `amount` | G-20, G-21 |

And the reachable stuck states, listed here rather than hidden:

| reachable stuck state | condition | row |
|---|---|---|
| `Funded` forever, both exits revert | `d.token` is not exact-transfer outbound (§1.3 b/c) | **G-34, G-35** |
| `Funded` forever for one direction | `d.token` blacklists `d.buyer` (refund direction) or `d.seller` (settle direction) | G-18, G-23 |
| `Refunded` although the work was delivered | the deployment's `refundDelay` is shorter than the proving time | **G-33** |

A deal in an exact-transfer token that does not blacklist its destinations is **never**
stuck: `refundAfterDeadline` is callable by anyone forever after the deadline (G-10, G-14).

### 4.4 Invariants

- **INV-1a (settlement is caller-independent).** For `f ∈ {settleWithProof,
  refundAfterDeadline}`, every deal state, and every pair of addresses `a, b`, calling `f`
  with identical arguments from `a` and from `b` produces identical state changes and
  identical value movements. **Mechanically:** those two function bodies contain zero
  occurrences of `msg.sender` and zero of `tx.origin` (`no-keys.sh` checks 6 and 7).
  **Behaviourally:** AC-2, AC-3, AC-20.
- **INV-1b (`fund` depends on the caller in exactly two authorized ways).** `fund` uses
  `msg.sender` only as (i) the recorded and emitted `buyer` and (ii) the `transferFrom`
  source. It uses it for nothing else, and no value leaves the escrow inside `fund`.
  **Mechanically:** `no-keys.sh` check 10 pins the occurrence count at 3 and each
  occurrence's syntactic form (`buyer: msg.sender`, `emit Funded(dealId, msg.sender,`,
  `transferFrom(msg.sender,`); check 9 pins `.transfer(` inside `fund` at 0 and the single
  `transferFrom` to `transferFrom(msg.sender, address(this), amount)`.
  **Behaviourally:** AC-8, AC-11.
  *(r1 finding 5: round 1 wrote INV-1 as a single universal statement that its own last
  clause contradicted, and left the true clause unchecked. Both halves are now separate
  and both have a mechanical check.)*
- **INV-2 (destinations are fixed at funding).** Every outward transfer sends exactly
  `d.amount` of `d.token` to an address stored in the deal at funding time
  (`d.seller` or `d.buyer`). No destination is ever taken from calldata at settlement time,
  from `msg.sender`, or from `tx.origin`.
- **INV-3 (at most one payout per deal).** Over the lifetime of the contract, for each
  `dealId`, the number of outward transfers attributable to it is ≤ 1. `Reproduced` and
  a refund cannot both happen; a proof arriving after a refund is dead (G-17).
- **INV-4 (per-token solvency).** For every token `T`:
  `T.balanceOf(escrow) ≥ Σ { d.amount : d.state == Funded ∧ d.token == T }`.
  Holds for every exact-transfer `T` (§1.3); §8 states the residual.
- **INV-5 (cross-token isolation).** A call naming `dealId` moves only `deals[dealId].token`.
- **INV-6 (no inflation).** A payout is exactly `d.amount`. Donations (G-27), forced ETH
  (G-28), and other deals' principal never increase any payout. This is the invariant that
  forces C-5's upper bound.
- **INV-7 (absorbing terminals).** From `Settled` or `Refunded`, no entry point changes
  state or moves value.
- **INV-8 (liveness, conditional — condition now identical to C-5's).** For every deal that
  reaches `Funded`, there exists a call that **any** address can make at any time
  `t ≥ fundedAt + refundDelay` which moves the deal out of `Funded` — **conditional on a
  `d.token.transfer(d.buyer, d.amount)` at that moment both not reverting and decreasing
  the escrow's balance by exactly `d.amount`.** If either half of the condition fails, the
  deal stays `Funded`, the call is retryable by anyone forever, and it never succeeds
  (G-18, G-34, G-35).
  *(r1 finding 6: round 1's INV-8 said only "not reverting", which is strictly weaker than
  what C-5 enforces. The two now quote one definition, §1.3.)*
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
    predicate over such a balance is out of scope (`AGENTS.md` §5).
  - `refundDelay`, `fundedAt`, `deadline` — `uint64` **seconds**, compared against
    `block.timestamp` (seconds). `MIN_REFUND_DELAY = 3600 s` makes the few-second
    proposer influence over `block.timestamp` irrelevant to any row. **That is the whole
    of its justification** (C-2).
  - basis points, wei, and lamports **do not appear** in this contract. There is no
    `payable` function and no `address(this).balance` read, so wei never enters a
    comparison (check 6, G-28). The SVM guest's lamports (`program-svm`) reach the escrow
    only through the same `u64` verdict fields and are never converted to `Deal.amount`.

### 4.5 `scripts/no-keys.sh` — additive checks only (interface unchanged)

**Constraint (`AGENTS.md` §0, N-9):** 003 does **not** change the script's interface, its
default target, its exit semantics, or the text of its existing lines. It only **adds**
checks and **one** additional output line. Anything that would loosen it is a founder call
and is not done here.

| # | check | status | enforces |
|---|---|---|---|
| 1 | forbidden privilege vocabulary | existing, unchanged | AC-0 |
| 2 | state-changing surface is enumerated | **strengthened, two-sided**: all of `fund`, `settleWithProof`, `refundAfterDeadline` must be **present** as well as permitted | the keyless timeout cannot be silently deleted later |
| 3 | `require(/if( msg.sender` regex | existing, unchanged (kept in addition to check 7) | AC-0 |
| 4 | constructor stores no caller | existing, unchanged | AC-0 |
| 5 | **no base contracts** — the declaration line must match `^contract[[:space:]]+RecknZkEscrow[[:space:]]*\{` | new | inheritance reintroduces a role outside the scanned body |
| 6 | **no unenumerated entry point, escape hatch, or ETH surface** — the body must not contain `fallback`, `receive`, `assembly`, `tx.origin`, `.call(`, `.call{`, `staticcall`, `payable` | new | a `fallback()` is an entry point check 2's grep cannot see; `payable` is an ETH exit |
| 7 | **`msg.sender` only inside `fund`** — split the body at `function ` boundaries; the ranges beginning `function settleWithProof` and `function refundAfterDeadline` must contain zero occurrences of `msg.sender` | new | INV-1a. Replaces check 3's blind spot: check 3 matches `require( msg.sender == x)` but not `require(x == msg.sender)` |
| 8 | **the constructor assigns only permitted immutables** — the left-hand side of every assignment inside the constructor body ∈ `{verifier, refundDelay}` | new | no stored authority |
| 9 | **value exits are counted and pinned** (r1 finding 3) — body-wide: exactly one `transferFrom(` and exactly two `.transfer(`; the `transferFrom(` lies in `fund`'s range and matches `transferFrom\(msg\.sender, *address\(this\), *amount\)`; `fund`'s range contains zero `.transfer(`; `settleWithProof`'s range contains exactly one `.transfer(` matching `\.transfer\(to, *d\.amount\)`; `refundAfterDeadline`'s range contains exactly one matching `\.transfer\(d\.buyer, *d\.amount\)` | new | §3.1's basis of exhaustiveness; kills the in-`fund` drain and the allowance-redirect |
| 10 | **`fund`'s use of `msg.sender` is pinned** — exactly 3 occurrences inside `fund`'s range, matching once each: `buyer: msg.sender`, `emit Funded(dealId, msg.sender,`, `transferFrom(msg.sender,` | new | INV-1b |

Function ranges are obtained the same way the existing script isolates the body: strip
comments, then split at lines matching `^[[:space:]]*function[[:space:]]+[a-zA-Z_]`. This
was prototyped against the real file on 2026-09-04 and correctly attributes today's
`transferFrom` to `fund` and today's `.transfer(` to `settleWithProof`.

**The one additive output line.** Immediately *before* the existing final success line
(which stays byte-identical), the script prints:

```
checks: 10/10 passed
```

This exists so AC-0 cannot be satisfied by a script that ran nothing. It adds a line; it
changes no existing line, no argument, no target, and no exit code.

**Self-testing without a target argument (N-9, r1 finding 12).** `no-keys-selftest.sh`
reconstructs the *layout* the script expects in a temp directory —
`$T/scripts/no-keys.sh` and `$T/zk-verdict/contracts/src/RecknZkEscrow.sol` — because the
script derives its target from its own location (`scripts/no-keys.sh:17-19`). Verified
working on 2026-09-04: a clean copy exits 0 in the sandbox, and a mutated copy is judged
by the same code path. **No argument, no environment variable, no default change.**

---

## 5. Acceptance criteria

### 5.0 The AC format (rewritten in round 2 — r1 findings 1, 2, 9)

**Round 1's format was false.** It said "every AC is a command whose exit status decides
it" and then used `forge test --match-test <pattern>`, which **exits 0 when the pattern
matches nothing**. Re-measured on forge 1.7.1, 2026-09-04:

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
files were never created. Two more (round 1's AC-6, AC-8) used a **space-separated list**
inside a single regex, so they matched zero tests *even for a correct implementation* —
including AC-6, the acceptance condition for INV-9, the property the product is sound by.

**Round 2 changes the format itself, not those two lines.** Every AC is now:

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
   1.7.1, 2026-09-04.)
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
non-zero exit. There is no path where "nothing matched" and "everything passed" are the
same exit status.

For a **`script`** AC, `ac.sh` runs the named script, requires exit 0, **and** requires its
stdout to contain the manifest's `evidence` string **verbatim, as a substring of one line**
(leading whitespace in the rendered output is therefore fine). Each evidence string carries
a count, so a script that ran nothing cannot print it.

**Spelling.** `AC-N` in prose and `AC-0N` in the manifest are the same criterion;
`scripts/ac.sh` accepts both spellings and normalizes to the two-digit form, which is also
the form embedded in test names (`_AC02_`). `gauntlet.sh --check` asserts the two spellings
are in bijection.

For the **`suite`** AC (AC-17), `ac.sh` runs the whole suite with `--json`, requires valid
JSON, requires the total number of `test_results` entries across all suites to equal the
manifest's `tests` value, requires every status `Success`, and requires the four
pre-existing `RecknZkEscrowTest` names of §1.2 to be present.

`bash scripts/ac.sh --all` runs every entry in the manifest, asserts it ran **21** of them,
and prints `ac: 21/21 acceptance criteria passed`.

**Termination, stated so it cannot be discovered at 3 a.m.** `--all` on the **repo root**
runs all 21, including AC-14 and AC-18. `--all` on a **sandbox root** (`--root <path>`)
runs the other **19** and prints `ac: 19/19 acceptance criteria passed (sandbox)`, because
AC-14 and AC-18 are harnesses *of* the harness and re-entering them would recurse. AC-14
itself only ever invokes `ac.sh --root <sandbox> AC-NN` for a **single** AC.

`ac.sh` takes `--root <path>` so the mutation harness can point it at a sandbox
(r1 finding 4). This is a **new** script and its interface is 003's to define; it is not
`no-keys.sh` (N-9).

**Every AC below carries a `Falsify:` line — a concrete command that makes that AC exit
non-zero.** An AC without a working falsifier is not an acceptance criterion.

### 5.1 The manifest (machine-read by `scripts/ac.sh` and `scripts/gauntlet.sh --check`)

Columns: `AC`, `kind` ∈ {`forge`,`script`,`suite`}, `selector` (regex for `forge`, command
for `script`), `tests` (exact expected count; `-` for `script`), `rows` (G ids that must
appear in that AC's test names; `-` if none), `evidence` (verbatim stdout line required for
`script`/`suite` kinds; `-` otherwise). Tab- or multi-space-separated; `#` starts a comment.

```ac-manifest
AC-00  script  scripts/no-keys.sh                 -   -                                        checks: 10/10 passed
AC-01  script  scripts/no-keys-selftest.sh        -   -                                        selftest: 14 source mutants, 14 rejected, 1 control accepted
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
AC-13  script  scripts/gauntlet.sh --check        -   -                                        manifest: 35 rows, 21 acceptance criteria, 3 sources agree
AC-14  script  scripts/mutation-kill.sh           -   -                                        mutation: 41 mutants, 41 killed, 1 control survived
AC-15  script  scripts/gauntlet.sh                -   -                                        35/35 rows as specified.
AC-16  script  scripts/gauntlet.sh --check        -   -                                        honest-scope: 2/2 digests unchanged
AC-17  suite   -                                  54  -                                        suite: 54/54 passed
AC-18  script  scripts/ac-selftest.sh             -   -                                        ac-selftest: 13 forge ACs, 13 observed failing when their tests are absent
AC-19  forge   _AC19_                             6   G-18,G-23,G-29,G-33,G-34,G-35            -
AC-20  forge   _AC20_                             1   G-30                                     -
```

Arithmetic that `gauntlet.sh --check` recomputes and that a reviewer can recompute by hand:

- **21** acceptance criteria (AC-00 … AC-20).
- **13** `forge` ACs; their `tests` column sums to **42** — the number of gauntlet tests.
- AC-17's `tests` = **54** = 42 gauntlet + **12** pre-existing (measured 2026-09-04, §1.2).
- The union of the `rows` column is exactly the **35** ids of §3.2, each appearing at least
  once. (Rows may appear in more than one AC; G-05 and G-06 appear in AC-02 and AC-07.)

### AC-0 — the central claim still holds (fixed text, `reckn-spec` charter)

```sh
bash scripts/ac.sh AC-00   # runs `bash scripts/no-keys.sh`; exit 0 and `checks: 10/10 passed`
bash scripts/no-keys.sh    # exit 0 — the founder's own command, unchanged
```
The state-changing surface becomes `fund` / `settleWithProof` / `refundAfterDeadline` —
three functions. `AGENTS.md` §0 and `scripts/no-keys.sh` already enumerate exactly these
three, so the *permitted* surface does not change; what changes is that the third one now
**exists**. That is still a change to what the product claims (it previously claimed a
two-function surface plus a disclosed lock-up gap), so §9's documentation obligations
D-1…D-10 must land in the same commit and the demo script must say it out loud.

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

### AC-1 — the enforcement script is hardened over the whole face

```sh
bash scripts/ac.sh AC-01   # runs scripts/no-keys-selftest.sh
```
`scripts/no-keys.sh` gains checks 5–10 and the two-sided check 2 exactly as tabulated in
§4.5. **No interface change (N-9).** `scripts/no-keys-selftest.sh` builds the sandbox
layout described in §4.5, applies each source-text mutant to the copy, runs the copied
script, and asserts:

- the **14** source-text mutants (M-1, M-13…M-19, M-35…M-38, M-A, M-F) are each
  **rejected** (exit non-zero), each by a named check;
- the **control M-0** (unmodified copy) is **accepted** (exit 0), so the selftest cannot
  pass by rejecting everything;
- it prints `selftest: 14 source mutants, 14 rejected, 1 control accepted`.

**Kills:** M-1 `if (msg.sender == 0x5E11E5) { to = d.seller; }` inside `settleWithProof`
— **by check 7, structurally.**
*(r1 finding 3's corollary: round 1 attached M-1 to AC-2's caller fuzz, which cannot draw a
hardcoded constant out of 2^160. A fuzz is the wrong instrument for a backdoor; the right
one is "this identifier does not appear in this function at all". AC-2 is explicitly
recorded below as **not** killing it. Its sibling M-2 — `if (_creator == msg.sender)`, keyed
on a **stored** address — is check 7's too, but §5.3 assigns it to **AC-20**, because a
targeted deployer replay is the stronger demonstration and each mutant occupies exactly one
cell of the kill table.)*
M-14 `contract RecknZkEscrow is Owned {`; M-15 a
`fallback() external {}`; M-16 `require(tx.origin == x)`; M-17 `require(x == msg.sender)`
inside `settleWithProof`; M-18 a constructor that also stores
`bytes32 private _secret = keccak256(abi.encode(msg.sender))`; M-19 deleting
`refundAfterDeadline` entirely; **M-35** the in-`fund` drain of §3.1 (check 9);
**M-36** a third `.transfer(` in `settleWithProof` gated on a calldata constant
(check 9 — the backdoor that carries no `msg.sender` at all); **M-37**
`transferFrom(seller, msg.sender, amount)` in `fund` — spends a buyer's outstanding
allowance to a third party (check 9's pinned argument form); **M-38** a fourth
`msg.sender` in `fund`, `if (msg.sender == X) amount = 0;` (check 10).
The selftest also re-runs M-13, M-A and M-F, which §5.3 assigns to **AC-0** because the
script's *original* checks 1/2/4 already reject them; they are exercised here, not claimed
here.

**Falsify:** delete check 9 from `scripts/no-keys.sh` and re-run — M-35/M-36/M-37 survive,
the selftest's count line reads `15 source mutants, 12 rejected`, and `ac.sh AC-01` exits
non-zero because the evidence line does not match.

### AC-2 — settlement authority is caller-independent (fuzzed)

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

**Kills:** M-3 is not in this AC (see AC-3); this AC kills **M-20** (`outcome != FAILED ⇒
seller`, so outcome 7 pays the seller) only jointly with AC-7 — its primary killer is
AC-7. AC-2's own primary kills are **M-21** (the verifier call's return value is ignored)
and **M-24** (the payout token is taken from calldata instead of `d.token`).

**Does not kill:** **M-1** (hardcoded `0x5E11E5`) or **M-2** (the stored creator). A caller
fuzz draws neither out of 2^160. M-1's killer is AC-1 check 7, structurally; M-2's is
AC-20's targeted deployer replay. Recorded here so the kill table's arithmetic is not
quietly rescued by an over-claim (R-5).

**Falsify:** `mv zk-verdict/contracts/test/KeyGauntletFuzz.t.sol{,.bak} && bash scripts/ac.sh AC-02`
→ non-zero (`0 ≠ 6` at the count gate). Also: rename one of the six tests so its `_G0N_`
segment is dropped → non-zero at the naming gate.

### AC-3 — the refund destination is the buyer, for every caller (fuzzed)

```sh
bash scripts/ac.sh AC-03   # 4 tests ; rows G-10,G-12,G-13,G-14
```
For a fuzzed `address caller` (same exclusion rule as AC-2) and a fuzzed `uint256 t`
bounded to `[deadline, deadline + 3650 days]`, `refundAfterDeadline` succeeds, moves
exactly `d.amount` to `d.buyer`, and moves **0** to `caller`. G-10 is the liveness test:
the `KEEPER` never submits, and the deal still leaves `Funded` after the deadline.

**Kills:** M-3 `token.transfer(msg.sender, d.amount)`; M-4 `token.transfer(d.seller,
d.amount)`; M-5 `token.transfer(tx.origin, d.amount)`. M-3 and M-5 would *also* be rejected
by checks 7 and 6 respectively; §5.3 assigns them here because AC-3 shows *where the money
went*, and each mutant occupies exactly one cell.

**Falsify:** change one test's assertion from `d.buyer` to a literal address equal to the
buyer's — R-2 forbids it and AC-14's M-3 then survives, failing AC-14; and deleting any one
of the four tests fails AC-3 at the count gate.

### AC-4 — nobody can refund before the deadline (fuzzed caller × fuzzed time)

```sh
bash scripts/ac.sh AC-04   # 2 tests ; row G-11
```
Test 1 (`testFuzz_AC04_G11_…`): fuzzed caller and fuzzed `t ∈ [fundedAt, deadline − 1]` →
revert `DeadlineNotReached`, escrow balance unchanged. Test 2 (`test_AC04_G11_…`): the
boundary pair exactly — `t = deadline − 1` reverts, `t = deadline` succeeds.

**Kills:** M-6 the deadline check is dropped; M-7 the comparison is `>` instead of `>=` —
killed by the boundary test, **not** by the fuzz, which is why the pair is a separate test
with its own count.

**Falsify:** delete `test_AC04_G11_boundary` → count 1 ≠ 2 → non-zero. (Round 1 folded the
boundary into prose; it is now a counted artefact.)

### AC-5 — a deal pays at most once, in both orders

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

### AC-6 — the binding is what settles the deal (INV-9's acceptance condition)

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
condition.

**Kills:** M-10 the `BindingMismatch` check is removed; M-11 the check is
`if (v.dealBinding == bytes32(0) || v.dealBinding == d.dealBinding)` — accepts a
zero-binding proof, i.e. the predicate guest's, which commits `dealBinding = 0`
(`zk-verdict/lib/src/lib.rs:29-31`).

**Falsify:** `bash scripts/ac.sh AC-06` with the fixture file renamed → the control test
fails → non-zero. Restore round 1's space-separated selector in the manifest → the parse
succeeds but `|found| = 0 ≠ 2` → non-zero (round 1's version silently exited 0).

### AC-7 — the outcome byte decides the destination, and nothing else does

```sh
bash scripts/ac.sh AC-07   # 3 tests ; rows G-04,G-05,G-06
```
For fuzzed `uint8 outcome`: `0 → seller`, `1 → buyer`, everything else → revert
`BadOutcome` with the deal still `Funded`.

**Kills:** M-12 `to = d.seller` unconditionally; M-20 `outcome != FAILED ⇒ seller` (pays
the seller on outcome 7).

**Falsify:** narrow the fuzz to `outcome ∈ {0,1}` → M-20 survives AC-14 → AC-14 fails, and
R-1 forbids the added `vm.assume` without a named mechanism.

### AC-8 — a deal cannot be Funded without the tokens arriving

```sh
bash scripts/ac.sh AC-08   # 3 tests ; rows G-20,G-21
```
**r1 finding 2** applies here identically; the selector is now `_AC08_`.
`fund` reverts `UnderFunded` against a token that returns `false` without reverting (G-20)
and against an inbound fee-on-transfer token (G-21), and **no** deal is created
(`deals(dealId).state == None`). The third test is the positive control
`test_AC08_G20_control_exact_transfer_token_funds` — a well-behaved token funds and the
stored deal matches the arguments.

**Kills:** M-21 `fund` ignores `transferFrom`'s result and skips the delta check — the
mutation that reproduces today's code (`RecknZkEscrow.sol:86`), which is why this AC
exists.

**Falsify:** drop the positive control → count 2 ≠ 3 → non-zero. (Without it, a `fund` that
always reverts would pass the two negatives.)

### AC-9 — reentrancy cannot produce a second payout

```sh
bash scripts/ac.sh AC-09   # 3 tests ; rows G-24,G-25,G-26
```
Uses `ReentrantERC20`, which calls back into the escrow from within `transfer` /
`transferFrom`. Assert: the deal's total outward transfers = 1 (settle and refund cases),
and the interleaved-`fund` case reverts `UnderFunded` with neither deal created.

**Kills:** M-22 `d.state = State.Settled` moved to **after** the `transfer`.

**Falsify:** replace `ReentrantERC20` with a plain mock → M-22 survives AC-14 → AC-14 fails.

### AC-10 — solvency and isolation under random call sequences

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
`d.amount` — drains other deals and donations, and passes every single-deal test. This is
the mutant that forces C-5's *upper* bound (§4.1 C-5). M-24 `settleWithProof` pays
`d.amount` of a token taken from calldata rather than `d.token` (breaks INV-5).

**Falsify:** reduce the handler to one deal in one token → M-23 and M-24 survive AC-14.
Set `invariant_runs = 0` in `foundry.toml` → forge reports the invariants without executing
them and AC-14 fails; `gauntlet.json`'s printed `fuzz` block makes the setting visible.

### AC-11 — a funded deal's terms are immutable

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

### AC-12 — an unfunded deal has no behaviour

```sh
bash scripts/ac.sh AC-12   # 2 tests ; row G-31
```
For fuzzed `dealId` and fuzzed caller, `settleWithProof` and `refundAfterDeadline` each
revert `BadState` and no storage slot for that deal is written (one test per entry point).

**Kills:** M-27 `refundAfterDeadline` omits the state guard — a never-funded deal has
`fundedAt == 0`, so `0 + refundDelay` is long past and it would "refund" 0 tokens to
`address(0)`, writing a bogus `Refunded` record.

**Falsify:** delete either test → count 1 ≠ 2 → non-zero.

### AC-13 — the matrix, the manifest and the demo cannot drift apart

```sh
bash scripts/ac.sh AC-13   # runs `bash scripts/gauntlet.sh --check`
```
`gauntlet.sh --check` parses **this file** — the matrix between the `BEGIN MATRIX` and
`END MATRIX` HTML comments in §3.2, and the fenced `ac-manifest` block in §5.1 — and
compares, as sets. (Those two comment markers appear **exactly once each** in this
document, in §3.2; the parser must assert that, so a second pasted copy is an error rather
than a silent re-anchor.)

1. §3.2's `G-NN` ids ↔ the `G` ids embedded in test names on disk ↔ `rows[].id` in
   `docs/gauntlet.json`;
2. §3.2's per-class counts (20 theft / 7 authorized / 8 disclosed / 35 total) recomputed
   from the table and from the JSON;
3. §5.1's per-AC `tests` column ↔ the actual `--list --json` count for each selector;
4. Σ(`tests` over `forge` ACs) = 42, and AC-17's `tests` = 42 + 12 = 54;
5. the union of §5.1's `rows` column = §3.2's id set;
6. the number of manifest entries = 21;
7. `docs/gauntlet.json` contains no `target override` string and no `signed_rows`
   inconsistency (§7.1).

Any mismatch exits non-zero and names the missing ids. On success it prints
`manifest: 35 rows, 21 acceptance criteria, 3 sources agree`.

**Kills:** M-28 a hand-edited `gauntlet.json` with a row deleted; M-29 a test file where a
row's test exists but is named without its ID; M-30 a §3.2 row added to this document
without a test; **M-31b** a manifest entry whose `tests` value is lowered to match a
missing test (caught by check 3 against `--list`, and by check 4's sum).

**Falsify:** add a row `| G-36 | theft | … |` to §3.2 and run → non-zero, naming G-36.

### AC-14 — the mutation harness is real, and it mutates the real file (r1 finding 4)

```sh
bash scripts/ac.sh AC-14   # runs `bash scripts/mutation-kill.sh`
```
**Round 1 mutated a parallel copy.** Mutants lived in `test/mutants/MutantZkEscrow.sol`
with an `immutable uint256 MUT`, and no AC required the `MUT == 0` path to be derived from
`RecknZkEscrow.sol`. A backdoor added to the real contract and to nothing else left the
harness reporting "all mutants killed". **`MutantZkEscrow.sol` is deleted from this spec.**

All mutants are now **patches applied to a sandboxed copy of the real source**, the way
`no-keys-selftest.sh` already worked:

- each mutant is a file `zk-verdict/contracts/test/mutants/M-NN.patch`, applied with
  `patch`/`git apply` to `src/RecknZkEscrow.sol` inside a sandbox;
- **behavioural** mutants (21 of them) get a sandbox Foundry project: copy
  `zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}` (including
  `src/fixtures/`), symlink `lib`, apply the patch, and run
  `bash scripts/ac.sh --root <sandbox> AC-NN` for the AC that names the mutant; assert it
  **fails**;
- **source-text** mutants (15) are driven by `no-keys-selftest.sh` (AC-1);
- **harness/document** mutants (5) are applied to sandbox copies of `docs/gauntlet.json`,
  the test files' names, this spec, and `zk-verdict/README.md`;
- **M-0 is the unmodified copy**: every AC must **pass** against it. If M-0 is reported
  killed, the harness is broken.

The script prints a table `mutant | class | killed-by | status` and the line
`mutation: 41 mutants, 41 killed, 1 control survived`. It exits non-zero if any mutant
survives, if M-0 is reported killed, or if the printed count differs from the number of
`M-` identifiers in §5.3.

**Kills:** the degenerate harness — one that reports "all killed" by failing everything.
Its detector is **M-0, which must SURVIVE**; if the table reports M-0 killed, AC-14 fails.
(M-0 is the one identifier in §5.3 with no `killed-by`; AC-14 does not kill it, it protects
it.) The second detector is the arithmetic: the printed count must equal §5.3's 42/41/1.

**Falsify:** apply M-35's patch to `zk-verdict/contracts/src/RecknZkEscrow.sol` on the live
tree and run the whole AC set — AC-1 must go red. If it does not, checks 9/10 are not
doing what §4.5 says. (This is the r1-finding-3 regression test, and it is the one command
that would have caught round 1.)

### AC-15 — the judge-facing surface is generated, not written

```sh
bash scripts/ac.sh AC-15   # runs `bash scripts/gauntlet.sh`
```
`scripts/gauntlet.sh` must: print the five private keys with the banner
`LOCAL ANVIL / FOUNDRY ONLY — throwaway development keys, no real funds`; print the escrow
address, the `verifier` address, the `verdictProgramVKey`, and `refundDelay` (§2.3's
three-part pre-funding check); run the gauntlet suites through `scripts/ac.sh`; write
`docs/gauntlet.json` (schema §7.1) from the **actual** run; render the matrix as an ASCII
table; and end with the money-shot block of §7.2.

It must exit non-zero if any AC fails, and in that case must **not** print the money-shot.

**Idempotence, without a false command (r1 finding 9).** Round 1 wrote
`git diff --exit-code docs/gauntlet.json   # exit 0 after ignoring generated_at/commit`.
`git diff --exit-code` has no field-ignore behaviour, and `gauntlet.sh` always writes a
fresh `generated_at`, so that command always exits 1 on an honest run. The comparison is
now done by `gauntlet.sh --check` itself, with the fields deleted before the diff:

```sh
git show HEAD:docs/gauntlet.json | jq -S 'del(.generated_at, .commit, .durations)' > "$a"
jq -S 'del(.generated_at, .commit, .durations)' docs/gauntlet.json                  > "$b"
diff -u "$a" "$b"
```

**Kills:** M-31 a `gauntlet.sh` that prints a canned transcript — the negative control is
to break one gauntlet test on purpose and assert `gauntlet.sh` exits non-zero and the
money-shot is absent from its output. M-32b a `gauntlet.sh` that prints a nonzero
"transactions signed" count while `signed_rows` is empty (§7.1).

**Falsify:** `mv docs/gauntlet.json{,.bak} && bash scripts/ac.sh AC-13` → non-zero; and
break one test, run `gauntlet.sh`, grep for `rows as specified` → absent.

### AC-16 — the honest scope is not quietly overwritten

```sh
bash scripts/ac.sh AC-16   # the digest half of `gauntlet.sh --check`
```
The two "Honest scope" blocks in `zk-verdict/README.md` are byte-frozen by SHA-256,
recorded here (unchanged from round 1; r1 recomputed both and they match):

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
so the digests must be unchanged at the end of 003. **If a later task legitimately resolves
one, it changes the digest in this table in the same commit and states the evidence.**
On success `gauntlet.sh --check` prints `honest-scope: 2/2 digests unchanged`.

**Kills:** M-32 a documentation edit that softens "Not yet:" to "Now closed:".

**Falsify:** `sed -i '' 's/Not yet:/Now closed:/' zk-verdict/README.md && bash scripts/ac.sh AC-16`
→ non-zero.

### AC-17 — the pre-existing settlement path still works, and the suite total is pinned

```sh
bash scripts/ac.sh AC-17
bash zk-verdict/scripts/zk-e2e.sh   # exit 0 (after S-1; today its exit status is discarded)
```
`ac.sh AC-17` runs the whole `zk-verdict/contracts` suite with `--json`, and requires:
**54** test results in total (42 gauntlet + 12 pre-existing, both counted mechanically),
every status `Success`, and the four pre-existing `RecknZkEscrowTest` names of §1.2
present — in particular `test_real_proof_settles_to_seller`, which settles a **real
Groth16 proof**. Those four may change only in the constructor's new `refundDelay`
argument. It prints `suite: 54/54 passed`.

**S-1 is a precondition of the second command being evidence.**
`zk-verdict/scripts/zk-e2e.sh:84-85` pipes `forge test` into `grep … || true`, which
discards the exit status (`bash -c 'set -euo pipefail; (exit 7) | grep -E x || true; echo $?'`
→ `0`, run 2026-09-04). S-1 (§9) makes the script propagate it. Until S-1 lands, a green
`zk-e2e.sh` is not evidence that the suite passed and must not be cited as such.

**Kills:** M-33 a change to the `VerdictPublicValues` decode order, which makes the real
fixture stop settling. **M-34** — a contract whose every function body is `revert()`
(r1 finding 10: round 1 named M-34 in four places and attached it to no AC). It fails
AC-17's `Success` requirement and every authorized row, which is exactly the point: a
gauntlet made only of "must revert" rows would be satisfied by universal denial.

**Falsify:** add a fifth test to `RecknZkEscrow.t.sol` → 55 ≠ 54 → non-zero (drift is
caught; the number is normative and changing it means editing this spec).

### AC-18 — the AC harness itself cannot be satisfied by an empty implementation

```sh
bash scripts/ac.sh AC-18   # runs `bash scripts/ac-selftest.sh`
```
This is the negative control on §5.0 — the fix for r1 finding 1 must itself be falsifiable.
`scripts/ac-selftest.sh` works in a sandbox copy of the tree and asserts:

1. for each of the **13** `forge` ACs: with that AC's test file(s) moved aside,
   `bash scripts/ac.sh --root <sandbox> AC-NN` exits **non-zero**. Thirteen observations,
   not an argument.
2. with **all** gauntlet test files removed, `ac.sh --all` exits non-zero and names ≥ 13
   failing ACs.
3. a manifest entry edited to `tests = 0` makes `ac.sh` exit non-zero **with the message
   naming the floor**, not silently pass.
4. a test renamed so its `_GNN_` segment is missing fails the naming gate.
5. a test whose body is `assertTrue(true)` still fails, because the run gate's name set
   would no longer match the manifest's row coverage — and, for the value-bearing ACs,
   because AC-14's mutants survive.
6. the control: on the unmodified sandbox, `ac.sh --all` exits **0**. Without this,
   `ac-selftest.sh` could pass by breaking everything.

It prints `ac-selftest: 13 forge ACs, 13 observed failing when their tests are absent`.

**Kills:** M-31c an `ac.sh` that reports success on `|found| == 0`; M-31d an `ac.sh` whose
count gate compares `>=` instead of `==` (a suite could then pass with extra unrelated
tests and a missing required one — caught by observation 4 plus the row-coverage gate).

**Falsify:** change `ac.sh`'s count gate to `-ge` and re-run → observation 3 or 4 goes red.

### AC-19 — the disclosed rows behave exactly as disclosed

```sh
bash scripts/ac.sh AC-19   # 6 tests ; rows G-18,G-23,G-29,G-33,G-34,G-35
```
Six tests, one per disclosed row that has on-chain behaviour. These are **not** "must
revert" rows; each asserts the *stated* outcome, including the two that are uncomfortable:

- **G-18** blacklist on the buyer → `refundAfterDeadline` reverts, state stays `Funded`,
  and a later call with the blacklist lifted succeeds.
- **G-23** `seller == address(0)` → funding is allowed; the `Reproduced` path reverts; the
  deadline path returns the buyer's money.
- **G-29** a second escrow deployed with a rogue verifier settles its **own** deal; the
  honest escrow's deal in the same token is untouched.
- **G-33** *(r1 finding 7)* a deployment with `refundDelay = MIN_REFUND_DELAY`: buyer
  funds, warps to `fundedAt + MIN_REFUND_DELAY`, calls `refundAfterDeadline` — **it
  succeeds**, the buyer is made whole, and a subsequently submitted genuinely valid
  `Reproduced` proof reverts `BadState`. The test asserts the seller received **0**. This
  is the honest expected value; a test that asserted a revert here would be asserting a
  mechanism the contract does not have.
- **G-34** *(r1 finding 6)* an outbound-fee token: `fund` succeeds, both exits revert
  `PayoutFailed`, state is still `Funded` after both attempts, and a retry at a much later
  timestamp still reverts.
- **G-35** a rebasing token: same shape, with the balance moved by a rebase between `fund`
  and payout.

**Kills:** **M-39** — C-5's payout delta check deleted. G-34/G-35 would then "succeed" and
mark the deal `Settled`/`Refunded` while the destination received the wrong amount, so
these tests fail. (M-39 also weakens INV-6, but AC-10's M-23 is the drain case; M-39 is the
under-pay case and needs its own row.)

**Falsify:** delete G-33's test because it is unflattering → count 5 ≠ 6 → non-zero, and
AC-13 names G-33 as a matrix row with no test. **The unflattering rows are load-bearing on
the count**; they cannot be quietly dropped before the demo.

### AC-20 — the deployer's address is not special

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

### 5.3 The kill table (source of truth for AC-14's arithmetic)

**42 mutant identifiers. 1 control (M-0) that must survive. 41 that must be killed.**
Every identifier below appears in exactly one `killed-by` cell. `scripts/mutation-kill.sh`
parses this table.

| class | ids | count | driven by | killed by |
|---|---|---|---|---|
| control | M-0 | 1 | both harnesses | **nothing — must survive** |
| source-text | M-1, M-13, M-14, M-15, M-16, M-17, M-18, M-19, M-35, M-36, M-37, M-38, M-A, M-F | 14 | `no-keys-selftest.sh` | AC-0 (M-13, M-A, M-F), AC-1 (the rest) |
| behavioural | M-3, M-4, M-5 | 3 | sandbox forge | AC-3 |
| behavioural | M-6, M-7 | 2 | sandbox forge | AC-4 |
| behavioural | M-8, M-9 | 2 | sandbox forge | AC-5 |
| behavioural | M-10, M-11 | 2 | sandbox forge | AC-6 |
| behavioural | M-12, M-20 | 2 | sandbox forge | AC-7 |
| behavioural | M-21, M-24 | 2 | sandbox forge | AC-2 |
| behavioural | M-25, M-26 | 2 | sandbox forge | AC-11 |
| behavioural | M-27 | 1 | sandbox forge | AC-12 |
| behavioural | M-2 | 1 | sandbox forge | AC-20 |
| behavioural | M-22 | 1 | sandbox forge | AC-9 |
| behavioural | M-23 | 1 | sandbox forge | AC-10 |
| behavioural | M-33, M-34 | 2 | sandbox forge | AC-17 |
| behavioural | M-39 | 1 | sandbox forge | AC-19 |
| harness / document | M-28, M-29, M-30 | 3 | `mutation-kill.sh` | AC-13 |
| harness / document | M-31, M-32 | 2 | `mutation-kill.sh` | AC-15 (M-31), AC-16 (M-32) |

Sum: 1 + 14 + 3+2+2+2+2+2+2+1+1+1+1+2+1 + 3 + 2 = **42**. Killed = 41.

The lettered sub-mutants named in the AC bodies (M-31b, M-31c, M-31d, M-32b) are
**harness self-checks inside AC-13/AC-15/AC-18**, not entries in this table; they are
excluded from the 42 deliberately, and `mutation-kill.sh` must not count them.

---

## 6. Test plan

### 6.1 Files

| file | purpose | ACs |
|---|---|---|
| `zk-verdict/contracts/test/KeyGauntlet.t.sol` | the unit rows, named `test_AC05_G07_…` etc. | AC-5, AC-8, AC-9, AC-10 (units), AC-12, AC-19, AC-20 |
| `zk-verdict/contracts/test/KeyGauntletFuzz.t.sol` | caller / time / parameter fuzz | AC-2, AC-3, AC-4, AC-6, AC-7, AC-11 |
| `zk-verdict/contracts/test/KeyGauntletInvariant.t.sol` + handler | random call sequences over ≥ 3 deals in ≥ 2 tokens | AC-10 (invariants) |
| `zk-verdict/contracts/test/mutants/M-*.patch` | one patch per mutant, applied to a **sandbox copy of the real source** | AC-1, AC-14 |
| `zk-verdict/contracts/test/mocks/ReentrantERC20.sol` | calls back into the escrow from `transfer`/`transferFrom` | AC-9 |
| `zk-verdict/contracts/test/mocks/FalseReturningERC20.sol` | returns `false`, never reverts | AC-8 |
| `zk-verdict/contracts/test/mocks/InboundFeeERC20.sol` | delivers `amount − fee` on `transferFrom` | AC-8 (G-21) |
| `zk-verdict/contracts/test/mocks/OutboundFeeERC20.sol` | funds cleanly; `transfer` moves `amount + fee` from the sender | AC-19 (G-34) |
| `zk-verdict/contracts/test/mocks/RebasingERC20.sol` | balances drift on demand | AC-19 (G-35) |
| `zk-verdict/contracts/test/mocks/BlacklistERC20.sol` | reverts on `transfer` to a chosen address | AC-19 (G-18, G-23) |
| `scripts/ac.sh` | the AC dispatcher of §5.0; `--root`, `--all` | all |
| `scripts/ac-selftest.sh` | negative control on `ac.sh` | AC-18 |
| `scripts/no-keys-selftest.sh` | sandboxed source-text mutants vs the **unmodified** `no-keys.sh` | AC-1 |
| `scripts/mutation-kill.sh` | applies `M-*.patch` to sandboxes, prints the kill table | AC-14 |
| `scripts/gauntlet.sh` | judge-facing runner + `docs/gauntlet.json` generator + `--check` | AC-13, AC-15, AC-16 |

**Deleted from round 1:** `zk-verdict/contracts/test/mutants/MutantZkEscrow.sol` and
`zk-verdict/contracts/test/MutationKill.t.sol`. Mutating a parallel copy proves the tests
kill mutations *of the copy* (r1 finding 4).

### 6.2 Positive path (must pass)

Rows G-04, G-05, G-09, G-12, G-13, G-14, AC-6's control, AC-8's control, and AC-17's
real-proof test. **A gauntlet that only proves things revert would be satisfied by a
contract that reverts on everything** — that contract is M-34, and it must be observed
failing (AC-17).

### 6.3 Negative controls (must be observed failing — the point of the exercise)

Each is an artefact that must be **observed failing**, and the observation is itself
asserted:

1. **M-0 survives.** The unmodified contract passes every AC. If the harness reports M-0
   killed, the harness is broken (AC-14).
2. **Each of the 41 mutants is killed by the AC named in §5.3** (AC-14, AC-1).
3. **The empty implementation.** With every gauntlet test file absent, each of the 13
   `forge` ACs exits non-zero — thirteen recorded observations (AC-18). *This is the
   control on r1 finding 1: round 1's format made the empty implementation green.*
4. **The real file is what is mutated.** M-35's patch applied to
   `zk-verdict/contracts/src/RecknZkEscrow.sol` on the live tree turns AC-1 red (AC-14's
   Falsify line). *Control on r1 findings 3 and 4.*
5. **A `gauntlet.sh` run with one test deliberately broken** exits non-zero and omits the
   money-shot (AC-15).
6. **A clean copy of `RecknZkEscrow.sol`** is accepted by `no-keys.sh` in the sandbox
   selftest, so the selftest cannot pass by rejecting everything (AC-1).
7. **A softened Honest-scope edit** fails the digest check (AC-16).
8. **A manifest entry set to `tests = 0`** is refused by `ac.sh` (AC-18 observation 3).

### 6.4 Anti-degeneracy rules (this project has opened the same hole three times)

Binding on the implementation:

- **R-1** No test may `vm.assume` away an address that appears elsewhere in the same test
  file, and no `vm.assume` may be added without an inline comment naming the mechanism
  that requires it.
- **R-2** No assertion may be satisfied by a constant. Every value assertion compares
  against a quantity derived from the deal's own funding (`d.amount`, `d.buyer`,
  `d.seller`), not against a literal repeated from the setup.
- **R-3** Any test that would still pass if the contract's function body were replaced by
  `revert()` must be paired with an authorized-row test that would then fail. M-34 is the
  suite-level instance of this rule.
- **R-4** Fuzz runs are configured in `zk-verdict/contracts/foundry.toml`, not per-test,
  and the configured `runs` / `invariant_runs` / `invariant_depth` are printed into
  `gauntlet.json`. A finite fuzz is evidence, not proof (§8).
- **R-5** *(new in r2)* **A fuzz is never the primary killer of a mutant keyed on a
  constant.** If a mutant's trigger is a hardcoded address, selector, or `dealId`, its
  `killed-by` in §5.3 must be a structural check (`no-keys.sh`), not a fuzzed AC. Round 1
  paired M-1 — *"the failure mode this project has hit three times"* — with a caller fuzz
  that draws it with probability ~2^-160.
- **R-6** *(new in r2)* **Every AC's `Falsify:` command must have been run and observed
  non-zero before the AC is reported green.** `ac-selftest.sh` mechanizes the 13 `forge`
  cases; the rest are recorded in the implementation report.

---

## 7. Judge-facing surface

003 owns the **machine-checked artefact**. `reckn-demo` owns the pixels. The contract
between them is the JSON below; `reckn-demo` may render it however it likes and must not
hand-edit it.

### 7.1 `docs/gauntlet.json` — schema `reckn/gauntlet/v2`

```json
{
  "schema": "reckn/gauntlet/v2",
  "generated_at": "2026-09-0?T??:??:??Z",
  "commit": "<git rev-parse HEAD>",
  "tier": "local-foundry",
  "contract": {
    "name": "RecknZkEscrow",
    "address": "0x...",
    "verifier": "0x...",
    "verdict_program_vkey": "0x...",
    "refund_delay_seconds": 86400,
    "min_refund_delay_seconds": 3600,
    "max_refund_delay_seconds": 2592000
  },
  "fuzz": { "runs": 256, "invariant_runs": 256, "invariant_depth": 32 },
  "proving_seconds_measured": null,
  "proving_measurement": { "command": null, "at": null },
  "keys_published": [
    { "role": "BUYER",    "address": "0x...", "private_key": "0x..." },
    { "role": "SELLER",   "address": "0x...", "private_key": "0x..." },
    { "role": "KEEPER",   "address": "0x...", "private_key": "0x...",
      "note": "the party a competing design would make the resolver" },
    { "role": "DEPLOYER", "address": "0x...", "private_key": "0x..." },
    { "role": "STRANGER", "address": "0x...", "private_key": "0x..." }
  ],
  "signed_rows": [],
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
    "rows": 35, "theft": 20, "authorized": 7, "disclosed": 8,
    "as_specified": 35, "keys_that_helped": 0,
    "acceptance_criteria": 21, "gauntlet_tests": 42, "suite_tests": 54,
    "mutants": 42, "mutants_killed": 41, "control_survived": true
  }
}
```

- `status ∈ {AS_SPECIFIED, DEVIATED}`.
- `keys_that_helped` is **computed**: the number of theft rows whose `observed` differed
  between a key-holding actor and a fuzzed stranger. Non-zero ⇒ `gauntlet.sh` exits
  non-zero.
- `signed_rows` is the list of row ids that were exercised by a **real signature** from a
  published key (OQ-1). It is `[]` unless OQ-1's anvil mode is built; §7.2's third
  money-shot line is derived from its length and `gauntlet.sh --check` fails if the printed
  number and `len(signed_rows)` disagree.
- `proving_seconds_measured` is `null` until someone actually times the proving path
  (`ZK_FRESH=1 bash zk-verdict/scripts/zk-e2e.sh`). While it is `null`, **nothing in the
  demo, the README or the JSON may describe `MIN_REFUND_DELAY` or `refundDelay` as
  covering the proving time** — `gauntlet.sh --check` greps the rendered output for that
  claim and fails if it appears with a `null` measurement (`AGENTS.md` §5).
- `acceptance[]` mirrors §5.1 and is what AC-13 check 3 compares against `--list`.

### 7.2 Terminal rendering

```
▶ KEY GAUNTLET — LOCAL FOUNDRY ONLY — throwaway development keys, no real funds
  escrow   0x...   verifier 0x...   vkey 0x...   refundDelay 86400s (min 3600 / max 2592000)

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

  35/35 rows as specified.
  Keys published: 5.  Addresses exercised: 5.  Addresses that helped: 0.
  Transactions signed by a published key: 0 — Foundry impersonates addresses (vm.prank);
  no published key signed anything. See §8 of docs/specs/003-key-gauntlet.md.
```

**The money-shot changed in round 2 (r1 finding 8).** Round 1 printed
`Keys published: 5. Keys that helped: 0.` next to a run in which no key signed anything.
The third line is **mandatory** and its number is derived from `signed_rows`; it is not
optional prose. If OQ-1's signed mode is built, the line reads
`Transactions signed by a published key: 3 (G-03, G-13, G-14).`

### 7.3 What `reckn-demo` must say out loud

- The surface grew from two functions to three, and why (`AGENTS.md` §0's requirement).
- The tier: local Foundry / anvil. Not testnet, not mainnet.
- **`vm.prank` impersonates addresses; no key signed** (unless OQ-1 is built).
- The **eight** disclosed rows are shown, not hidden — G-18, G-23, G-27, G-28, G-29,
  **G-33, G-34, G-35** — and G-33 in particular is shown as a row that **succeeds**, not
  as a revert.

---

## 8. What this does not prove

Written here so that no one has to say it under questioning.

- **A finite fuzz is not a proof.** AC-2/AC-3/AC-4/AC-7/AC-11/AC-12 sample the address
  space and the timeline; they do not establish caller-independence for all inputs. The
  mutation kill table (AC-14) raises the cost of a degenerate implementation; it does not
  eliminate it. There is no formal verification here, and this spec does not use the words
  "impossible" or "cannot, in principle". **A fuzz in particular cannot find a backdoor
  keyed on a constant** — that is what the structural checks are for (R-5).
- **The matrix is exhaustive with respect to §3.1's enumeration** (two exits, one inward
  site, one writing entry point, reentrancy, out-of-band value, deployment choice), and
  `no-keys.sh` checks 6/9/10 make that enumeration a build condition. It is **not**
  exhaustive with respect to attacks outside that frame — compiler bugs, EVM-level
  behaviour changes, and the SP1 verifier's own soundness are all outside it. And the
  enumeration **can** be grown by an implementer who edits check 9 and this document
  together; what is prevented is growing it *silently* (§3.1).
- **Foundry `vm.prank` impersonates an address without using its private key.** The 35 rows
  demonstrate **address-level** behaviour. Unless `signed_rows` is non-empty, no published
  key was exercised, and the money-shot says so (§7.2, r1 finding 8).
- **Token honesty is assumed, and the supported class is narrow.** INV-4/INV-6 hold for
  **exact-transfer** tokens (§1.3). A token that lies about balances can corrupt deals
  denominated **in itself**; INV-5 confines the damage to that token, and G-32 tests the
  confinement.
- **C-5 creates a permanent-lock residual for honest-but-inexact tokens** (r1 finding 6).
  An outbound-fee or rebasing token funds cleanly and then bricks **both** exits forever
  (G-34, G-35). This is asymmetric with the inbound case, which fails closed at `fund`
  (G-21) with no principal at risk. It is the price of INV-6's upper bound, which is what
  stops the drain mutant M-23. **003 does not close it**, and the honest gap list in
  `README.md` must say so (D-1).
- **A buyer who picks the deployment picks the clock** (r1 finding 7, row G-33). A buyer
  can deploy an escrow whose `refundDelay` is shorter than the proving time, fund it, take
  delivery, and refund. The contract's `MIN_REFUND_DELAY` is **not** a defence — a buyer
  deploying their own escrow chooses their own constant. The defence is the seller's
  pre-funding check of `verifier` + vkey + **`refundDelay`** (§2.3), and it is a
  human/off-chain check, not a mechanism. No claim that the window "covers proving time"
  may be made while `proving_seconds_measured` is `null` (§7.1).
- **The post-deadline race is real.** After `fundedAt + refundDelay`, a late-but-valid
  `Reproduced` proof and a refund compete; whichever lands first wins, and both are
  authorized outcomes. There is no mechanism to prefer one, because every such mechanism
  needs a party holding a trigger (N-5). The demo must state this rather than imply proofs
  always win.
- **Payout liveness depends on the token** (INV-8, G-18, G-23, G-34, G-35). A blacklisting
  token can brick a payout to a specific address in either direction.
- **A fraudulent deployment settles fraudulently** (§2.3, G-29). The check is pre-funding,
  and 003 makes it possible by printing verifier, vkey and `refundDelay`; it does not make
  it automatic.
- **003 says nothing about predicate non-degeneracy** (N-8). Whether a predicate can be
  satisfied by a seller who does nothing is a property of the guest and the plan, frozen
  here by N-2. `zk-verdict/README.md`'s Honest scope is the authority and is untouched
  (AC-16): the in-guest precompile restriction, the `u64` verdict values (`u64_low` =
  limb 0 only, ≥ 2^64 truncated), the 1-CALL + 1-delta scale, and the off-chain
  `state_root`↔header binding are all exactly as true after 003 as before it.
- **Tier.** Everything above is Foundry and local anvil. Nothing here is evidence about a
  testnet or mainnet deployment (`AGENTS.md` §5).

---

## 9. Implementation obligations (documentation moves in the same commit)

`AGENTS.md` §0 requires that a change to the claimed surface updates the claim everywhere
in the same change. Each is a `file:line` re-verified 2026-09-04.

| ID | file:line | today | obligation |
|---|---|---|---|
| D-1 | `README.md:566-571` | "**`RecknZkEscrow` has no timeout.** … the first ETHOnline task" | Replace with the closed state: permissionless post-deadline refund, the window is an immutable construction parameter, and the residuals (post-deadline race, token-dependent payout liveness, **G-33 short-window deployment**, **G-34/G-35 inexact-token lock**) are stated. **Do not delete the bullet silently** — the gap list must show a gap closed *and* the new residuals opened, with a link to this spec |
| D-2 | `CLAUDE.md:46-49` | "**`RecknZkEscrow` に timeout が無い**… タスク 001。**未解決**" | Rewrite as closed by 003, with the date and the AC that proves it |
| D-3 | `AGENTS.md:70` | task table row `001` | Mark folded into 003 per the 2026-09-04 ruling; keep the row so the history is legible |
| D-4 | `README.md:551`, `README.md:669` | "`forge test`: **12 passing**", "— 12 tests" | Update from the **actual** `forge test` output (expected 54, AC-17). Do not estimate (`AGENTS.md` §5) |
| D-5 | `zk-verdict/README.md:234-237` | the two-bullet function list | Add `refundAfterDeadline(dealId)` — permissionless, pays the buyer, only after the window. **Do not touch lines 154-164 or 208-221** (AC-16) |
| D-6 | `zk-verdict/README.md:239-243` | "Tested (`RecknZkEscrow.t.sol`): …" | Add the gauntlet: keys published, matrix size, the one-command runner, and the `vm.prank` caveat |
| D-7 | `STATUS.md:15`, `STATUS.md:39-40` | 撤退可能点 wording; a pointer to a `docs/specs/001-keyless-timeout.md` that will never exist | Already aligned at `:15` with `AGENTS.md` §7; fix the dangling 001 pointer |
| D-8 | `SUBMISSION.md:156-160` | ZK settlement bullet | Add the gauntlet and the timeout; keep the SVM/EVM honest-scope sentences intact |
| D-9 | `README.md:67` | "the enumerated `fund` / `settleWithProof` / `refundAfterDeadline`" | Already correct — add that all three must now be **present**, not merely permitted (two-sided check 2), and that checks 9/10 pin the value exits |
| D-10 | `AGENTS.md` §0 | "列挙された関数面 … を増やすなら" | The permitted set does not change, but the **script gains checks 5–10 and one output line**. Record that in the same commit, per §0's own instruction, and state that the interface was **not** changed (N-9) |

| ID | file:line | change |
|---|---|---|
| **S-1** | `zk-verdict/scripts/zk-e2e.sh:84-85` | `( cd "$contracts" && forge test -vv 2>&1 ) \| grep -E '…' \|\| true` discards `forge`'s exit status (`set -euo pipefail` does not survive the trailing `\|\| true`; verified 2026-09-04). Capture the status and exit non-zero on failure. **One line's worth of change**, and it is the only thing that makes AC-17's second command evidence rather than decoration. Nothing else in that script changes |

**Not to be edited by any agent:** `docs/ethonline-2026/PLAN.md:17-18, 27, 33` state the
two-function surface and the open timeout gap. That file is a founder document
(`AGENTS.md` §8). After 003 lands it will be stale. **Report the staleness to the founder;
do not fix it.**

### 9.1 Suggested part split for `reckn-codex-impl`

Each part must end green. Do not merge them into one Codex call.

1. **P1** — C-1…C-7 in `RecknZkEscrow.sol` + minimal adjustment of the four existing
   `RecknZkEscrowTest` tests to the new constructor. Ends green on `forge test`.
2. **P2** — `scripts/ac.sh` + `scripts/ac-selftest.sh` (§5.0/§5.1). **Built before any
   gauntlet test exists**, and its first demonstration is that every `forge` AC is
   **red** (AC-18 observation 1). Ends green on AC-18's control (observation 6) only after
   P3/P4.
3. **P3** — `scripts/no-keys.sh` checks 5–10, two-sided check 2, the `checks: 10/10 passed`
   line, `scripts/no-keys-selftest.sh` with the sandbox layout. Ends green on AC-0, AC-1.
4. **P4** — mocks + `KeyGauntlet.t.sol`. Ends green on AC-5, AC-8, AC-9, AC-12, AC-19,
   AC-20 and AC-10's unit half.
5. **P5** — `KeyGauntletFuzz.t.sol` + `KeyGauntletInvariant.t.sol`. Ends green on AC-2,
   AC-3, AC-4, AC-6, AC-7, AC-10, AC-11.
6. **P6** — `test/mutants/M-*.patch` + `scripts/mutation-kill.sh`. Ends green on AC-14,
   and on AC-18 in full. **Record the measured wall-clock** of `mutation-kill.sh` (21
   behavioural sandboxes, each a `forge build` plus one AC) in the implementation report
   and in `gauntlet.json.durations`; do not estimate it here — a forced `forge build` of
   this project measured ~0.9 s on 2026-09-04, but the sandbox path has not been run and
   this spec makes no claim about the total.
7. **P7** — `scripts/gauntlet.sh`, `docs/gauntlet.json`, the digest check, S-1. Ends green
   on AC-13, AC-15, AC-16, AC-17.
8. **P8** — D-1…D-10. Ends green on `bash scripts/ac.sh --all` from a clean tree.

---

## 10. Open questions

Genuinely undecided. **Do not guess; bring these back rather than inventing an answer.**

- **OQ-1 — Do the published keys have to actually sign?** (r1 finding 8.) The 35 rows run
  in Foundry, where `vm.prank` impersonates an address **without using its private key**.
  Round 2 has already made this honest in §8 and in the money-shot, so **the spec is
  correct either way**; the question is only whether to buy the extra credibility.
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
- **OQ-4 — Does the seller need an on-chain acceptance step?** A seller learns the deal's
  terms (including the deadline) only from the `Funded` event and never signals agreement
  on-chain. Acceptance would add a fourth function and a second party's consent — a
  key-shaped thing — so it is **not** in 003 (N-5). It is, however, the mechanism that
  would close **G-33**, which round 2 now carries as a disclosed row rather than a
  footnote. **Recorded, not resolved. If the founder wants G-33 closed rather than
  disclosed, that is a product decision that changes the central claim's shape and needs a
  new task, not an edit to 003.**
- **OQ-5 — Should `scripts/no-keys.sh` gain a target/path argument at all?** (r1 finding
  12.) Round 2 **does not add one** (N-9): `AGENTS.md` §0 reserves that script's semantics
  to the founder, and "no-keys.sh passed" must keep meaning one specific file. The
  sandbox-layout self-test achieves the same coverage with zero interface change (§4.5,
  verified 2026-09-04). **Returned to the founder as a question, not implemented:** is a
  positional override wanted later (e.g. for CI matrix runs), and if so, with what
  guarantee that an override's output can never be pasted as evidence for the claim?
- **OQ-6 — What proving time should `MIN_REFUND_DELAY` be compared against?** (r1 finding
  7.) There is **no measured Groth16 proving wall-clock anywhere in this repo** (grepped
  2026-09-04). Round 2 therefore refuses to call `MIN_REFUND_DELAY = 1 hours` a mitigation
  and carries `proving_seconds_measured: null` in the artefact. Measuring it costs one
  `ZK_FRESH=1` run with SP1's ~6.2 GB artifacts. **Founder call: is that run worth making
  during the event, and if the measured time exceeds one hour, does `MIN_REFUND_DELAY`
  change** — noting that raising it does **not** close G-33, because a buyer deploying
  their own escrow picks their own constant.

---

## Appendix A — response to `docs/reviews/003-spec-r1.md` (round 2)

Every item in "What must change before round 2" and every finding, with where it landed.
`adopted` = the reviewer's required change is implemented as written; `alternative` = a
different change that meets the stated requirement, with the reason; `founder` = returned
as an open question.

| # | finding | severity | disposition | where |
|---|---|---|---|---|
| 1 | 11 ACs green with no tests (`--match-test` exits 0 on no match) | BLOCKER | **adopted, as a format change** — not a per-AC patch. Every AC is now `bash scripts/ac.sh AC-NN` with a parse gate, an exact-count gate (`N ≥ 1`, twice), a naming gate, a row-coverage gate and a run gate. `--fail-on-no-tests` does **not** exist on forge 1.7.1 (`forge test --help`, 2026-09-04), so the count is taken from `--list --json` and cross-checked against `--json` | §5.0, §5.1, AC-18 |
| 2 | AC-6 / AC-8 selectors are space-separated regexes → 0 matches even when correct | BLOCKER | **adopted** — selectors are `_AC06_` / `_AC08_`; the space-separated form is gone from the whole document, and the count gate would have caught it anyway | AC-6, AC-8, §5.1 |
| 3 | nothing counts the `transfer` call sites; the in-`fund` drain passes everything; M-1 is not killed by AC-2 | BLOCKER | **adopted** — `no-keys.sh` **checks 9 and 10** count and pin every token call site and `fund`'s three `msg.sender` uses; mutants **M-35/M-36/M-37/M-38** added; §3.1's "cannot silently grow" **deleted** and replaced with the earned statement; **M-1/M-2 re-attached to AC-1 check 7** and AC-2 explicitly records that it does **not** kill them; **R-5** generalizes the rule | §3.1, §4.5, AC-1, AC-2, §5.3, R-5 |
| 4 | mutants mutate a parallel copy | MAJOR | **adopted (second option)** — `MutantZkEscrow.sol` and `MutationKill.t.sol` are deleted; all mutants are `M-*.patch` files applied to a **sandbox copy of the real source** | AC-14, §6.1 |
| 5 | INV-1 is false as written; its true clause is unchecked | MAJOR | **adopted** — split into **INV-1a** (settlement caller-independence; checks 6/7 + AC-2/3/20) and **INV-1b** (`fund`'s two authorized uses; **check 10** + check 9) | §4.4 |
| 6 | C-5's exact equality re-opens the permanent lock; INV-8's condition is narrower | MAJOR | **adopted (option a), with the reason for not taking option b stated** — exact equality is kept because the upper bound is what kills M-23; INV-8 is rewritten to quote the same condition as C-5; the **exact-transfer** token class is defined once in §1.3; rows **G-34/G-35** added; §8 carries the residual as *created by 003* | §1.3, C-5, INV-8, G-34, G-35, §8, AC-19 |
| 7 | the buyer regains timing discretion via the deployment; no row | MAJOR | **adopted, plus a correction the review did not ask for** — row **G-33** added as `disclosed` with the honest expected value (*the refund succeeds*); `refundDelay` added to §2.3's pre-funding check with the seller named as the party who must perform it; §8 rewritten. **`MIN_REFUND_DELAY` is explicitly demoted from "mitigation" to "block-timestamp hygiene"**, because a buyer deploying their own escrow is not bound by it. The proving time is **not** asserted — there is none measured in this repo — and is carried as `proving_seconds_measured: null` with a gag rule on claiming otherwise (**OQ-6**) | G-33, §2.3, C-2, §7.1, §8, OQ-6 |
| 8 | the money-shot implies keys were exercised | MAJOR | **adopted (both halves)** — §8 gains the `vm.prank` bullet, §2.1 gains it up front, and the money-shot now prints `Addresses exercised` plus a mandatory `Transactions signed by a published key: N` line derived from `signed_rows`. OQ-1 stays a founder call **without the spec depending on it** | §2.1, §7.2, §8, OQ-1 |
| 9 | AC-15's `git diff --exit-code` contradicts its own comment | MAJOR | **adopted** — the comparison moves inside `gauntlet.sh --check` with `jq -S 'del(.generated_at, .commit, .durations)'` and a real `diff` | AC-15 |
| 10 | M-34 is counted but named by no AC; §6.3's range excludes it | MINOR | **adopted** — M-34 attached to **AC-17**; §5.3 is now a table where every id appears in exactly one `killed-by` cell, and §6.3 says "each of the 41" instead of a range | AC-17, §5.3, §6.3 |
| 11 | "five tests" is four | MINOR | **adopted** — corrected at both sites, with the four names and their line numbers, and the suite total (12) measured rather than recalled | §1.2, AC-17 |
| 12 | the `no-keys.sh` target override changes what the script's exit status means; its guard is prose | MINOR / founder | **alternative + founder.** The override is **not added** (N-9). `no-keys-selftest.sh` reconstructs the expected *layout* in a temp dir instead — verified working 2026-09-04 — so the coverage is obtained with **zero interface change**, and the "target override" banner problem disappears because there is no override. Whether the founder wants one later is **OQ-5** | N-9, §4.5, AC-1, OQ-5 |

**Round-1 items recorded as sound and deliberately untouched** (r1 "Checked and found
sound"): the four task-001 acceptance conditions and their row/AC mapping; AC-16's two
SHA-256 digests; §3.2's original class counts (the +3 rows are new, and the recount is
20/7/8 = 35); the mutant-identifier arithmetic (now 42, recomputed in §5.3); INV-9's
binding formula and the `u64_low` limb-0 location; C-7's claim that no off-chain code
consumes the escrow ABI; and the scope line, which is now quoted verbatim in the header.

**What changed in size:** 32 rows → **35**; 18 ACs → **21**; 37 mutant ids → **42**;
`no-keys.sh` checks 8 → **10**. Every one of those numbers is recomputed by
`scripts/gauntlet.sh --check` (AC-13), so this paragraph cannot drift either.

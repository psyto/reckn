# 003 — Key Gauntlet (folds in 001: keyless timeout)

| | |
|---|---|
| Status | DRAFT — awaiting `reckn-codex-review` (stage=spec) |
| Owner | `reckn-spec` (frame thin). Implementation is `reckn-codex-impl`. |
| Supersedes | task `001` (keyless timeout) — folded in per founder ruling, `AGENTS.md` §3 |
| Tier claimed | **local anvil / Foundry only.** No testnet, no mainnet, no real funds. |
| Surface touched | `zk-verdict/contracts/src/RecknZkEscrow.sol`, `zk-verdict/contracts/test/`, `scripts/no-keys.sh`, `scripts/` (new), `README.md`, `CLAUDE.md`, `AGENTS.md`, `STATUS.md`, `SUBMISSION.md`, `zk-verdict/README.md` (**not** its Honest-scope blocks) |
| Surface **not** touched | `contracts/RecknEscrow*` (optimistic path, `AGENTS.md` §8), `zk-verdict/program-revm`, `zk-verdict/program-svm`, `zk-verdict/lib`, `zk-verdict/script`, `docs/ethonline-2026/*` (founder documents) |

Section numbering is normative. Task `004` must reuse this structure: §1 claim/non-goals,
§2 attacker model, §3 matrix, §4 state machine + invariants, §5 acceptance criteria,
§6 test plan, §7 judge-facing surface, §8 what this does not prove, §9 implementation
obligations, §10 open questions.

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

Today (`zk-verdict/contracts/src/RecknZkEscrow.sol`, read 2026-09-04):

- the contract has **no** owner/admin/resolver/pause/upgrade — this is already true and
  already enforced by `scripts/no-keys.sh`
- `settleWithProof` is already permissionless and already binding-checked
  (`RecknZkEscrow.sol:101-103`)
- **there is no timeout**: a funded deal with no proof is locked forever
  (`README.md:566-571`, `CLAUDE.md:46-49`)
- the claim is asserted in prose in four documents and demonstrated by **five** tests
  (`zk-verdict/contracts/test/RecknZkEscrow.t.sol`), none of which publishes a key,
  fuzzes a caller, or enumerates what a key-holder *cannot* do

003 turns the prose into a **machine-checked matrix** and closes the timeout gap inside
that matrix.

### 1.3 Non-goals (explicitly not done here, including the tempting ones)

- **N-1** Improving, touching, or demoing the optimistic path (`contracts/RecknEscrow`).
  It has a bonded resolver by design; it is out of the claim and out of the demo
  (`AGENTS.md` §8, `CLAUDE.md` "二つの経路を混同しない").
- **N-2** Any change to the SP1 guests, the verdict ABI, `dealBinding` construction, or
  the proving pipeline. 003 changes only the settlement contract and its tests. The
  binding is consumed as-is from `zk-verdict/program-revm/src/main.rs:176-190`.
- **N-3** Adding a `view` helper to `RecknZkEscrow` (e.g. `deadlineOf`, `computeBinding`).
  `scripts/no-keys.sh` check 2 greps **every** `function` declaration, view or not, so a
  view helper widens the enumerated surface and changes the claim. Off-chain callers read
  `deals(dealId)` (the auto-generated public-mapping getter, which is not a `function`
  declaration) and the `Funded` event.
- **N-4** Deploying anywhere. No testnet, no mainnet (`AGENTS.md` §8).
- **N-5** Any deadline-extension, seller-bond, dispute-reopen, or arbitration mechanism.
  Every one of them needs a trigger held by a party; that is a key.
- **N-6** SafeERC20 / permit / EIP-3009 integration, multi-payout splits, partial
  settlement, or deal cancellation by mutual consent. Mutual consent is two keys.
- **N-7** Resolving anything in `zk-verdict/README.md` "Honest scope" (precompiles, `u64`
  verdict values, 1 CALL + 1 delta, off-chain header binding). 003 claims none of them.
  §5 AC-16 makes the non-resolution machine-checkable.

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

### 2.2 Capability table

Everything each actor *can* do, and everything they cannot:

| actor | can | cannot |
|---|---|---|
| `BUYER` | fund new deals; call `settleWithProof` with any bytes; call `refundAfterDeadline`; receive `Failed`/refund payouts | redirect a `Reproduced` payout; refund before the deadline; cancel; change `seller`/`amount`/`dealBinding`/`token` after funding; stop a valid proof from settling before the deadline |
| `SELLER` | the same public surface as anyone; receive `Reproduced` payouts | cause a payout without a verifying proof bound to this deal; flip a `Failed` verdict; prevent a post-deadline refund; extend the deadline |
| `KEEPER` | submit or withhold a proof | change the outcome a proof carries; settle a deal a proof is not bound to; be paid for submitting; prevent anyone else from submitting the same proof |
| `DEPLOYER` | choose `verifier` and `refundDelay` **at construction, before any deal exists**; deploy other escrows | anything about any deal in the deployed escrow; nothing is stored about them (`no-keys.sh` check 4) |
| `STRANGER` | the same public surface as anyone | the same as everyone |
| `ATTACKER_CONTRACT` | reenter during payouts; be a lying token; donate tokens; force-send ETH | cause a second payout, corrupt another deal, or move a token it does not control |

### 2.3 Residual trust, stated up front

Two things are chosen by the deployer at construction and are then immutable and
publicly readable **before anyone funds**:

- `verifier` — the `RecknVerdictVerifier` address, which in turn immutably holds the SP1
  verifier address and `verdictProgramVKey` (`RecknVerdictVerifier.sol:37-45`)
- `refundDelay` — the settlement window (new in 003, §4.1)

A *fraudulent deployment* (rogue verifier, or a vkey for a program that always emits
`Reproduced`) settles fraudulently — but only for deals funded **into that deployment**.
This is not a key over an existing deal; it is a choice made before the deal exists,
identical in kind to choosing which contract address to send money to. Row G-29 makes
this explicit rather than leaving a judge to find it. The mitigation is a pre-funding
check, and `gauntlet.json` must print the verifier address and vkey so the check is
possible (AC-15).

---

## 3. Theft-path matrix

### 3.1 Basis of exhaustiveness

Enumerated by **exits**, not by imagination.

ERC-20 value leaves `RecknZkEscrow` only where the contract itself calls a token
transfer. In the post-003 contract there are exactly **two** such call sites:

- **L1** — in `settleWithProof`: `transfer(to, d.amount)` where `to ∈ {d.seller, d.buyer}`
- **L2** — in `refundAfterDeadline`: `transfer(d.buyer, d.amount)`

and one inward site, `transferFrom` in `fund`. There is no `delegatecall`, no
`selfdestruct`, no `fallback`/`receive`, no `assembly`, and no low-level call — AC-1
turns each of those into a build condition, so the enumeration cannot silently grow.

Therefore every theft is an attempt to reach L1 or L2 with a destination, amount, deal,
or timing that the deal did not authorize, **or** an attempt to corrupt the state that L1
and L2 read (`d.seller`, `d.buyer`, `d.amount`, `d.state`, `d.fundedAt`, `d.dealBinding`).
The matrix is the cross product of:

- **exit** × **actor** × **precondition**, for L1 and L2 (classes A and B)
- **state corruption** through the only writing entry point, `fund` (class C)
- **control-flow** attacks that interleave with an exit (class D)
- **out-of-band** value movement that does not go through an entry point (class E)

This is exhaustive **with respect to that enumeration**, not with respect to all
conceivable attacks. §8 states the limits of that word.

### 3.2 The matrix

`class`: **theft** rows must revert or leave value where it was; **authorized** rows must
pay exactly the right party exactly once; **disclosed** rows are honest limitations that
the demo must show rather than hide.

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
| G-13 | authorized | fuzzed caller (≠ buyer, seller, escrow) | `refundAfterDeadline` | fuzzed `block.timestamp ≥ deadline` | state → `Refunded`; **`BUYER`** receives `amount`; **caller receives 0** |
| G-14 | authorized | `BUYER` | `refundAfterDeadline` | proof never arrived; `block.timestamp ≥ deadline` | state → `Refunded`; `BUYER` made whole. **This is task 001's core row.** |
| G-15 | theft | fuzzed caller | `refundAfterDeadline` | deal already `Refunded` | revert `BadState`; exactly one payout ever occurred |
| G-16 | theft | fuzzed caller | `refundAfterDeadline` | deal already `Settled` (proof landed first) | revert `BadState`; exactly one payout ever occurred |
| G-17 | theft | fuzzed caller | `settleWithProof` | deal already `Refunded`; a **valid `Reproduced` proof arrives late** | revert `BadState`; exactly one payout ever occurred. **Task 001's reverse-order row.** |
| G-18 | disclosed | fuzzed caller | `refundAfterDeadline` | token reverts on `transfer` to `BUYER` (blacklist mock) | revert `PayoutFailed`; state stays `Funded`; the call is retryable by anyone at any later time |
| G-19 | theft | fuzzed caller | `fund` | `dealId` already Funded; attacker supplies themselves as `seller` and any `amount`/`binding`/`token` | revert `DealExists`; the stored `Deal` struct is **bytewise identical** afterwards |
| G-20 | theft | fuzzed caller | `fund` | token's `transferFrom` returns `false` without reverting | revert `UnderFunded`; no `Funded` deal is created |
| G-21 | theft | fuzzed caller | `fund` | fee-on-transfer token (escrow receives `amount − fee`) | revert `UnderFunded` — out of scope, **fails closed** |
| G-22 | theft | fuzzed caller | `fund` | `dealBinding == bytes32(0)` | revert `ZeroBinding` |
| G-23 | disclosed | `BUYER` | `fund` | `seller == address(0)` | allowed. Only the buyer's own principal is at risk. If the token reverts on transfer to `0`, `settleWithProof` reverts `PayoutFailed` forever and the deadline (G-14) returns the money |
| G-24 | theft | `ATTACKER_CONTRACT` (token) | reenters `settleWithProof` during the L1 payout | deal Funded | inner call reverts `BadState`; **exactly one** outward transfer for the deal |
| G-25 | theft | `ATTACKER_CONTRACT` (token) | reenters `refundAfterDeadline` during the L2 payout | past deadline | inner call reverts `BadState`; **exactly one** outward transfer for the deal |
| G-26 | theft | `ATTACKER_CONTRACT` (token) | reenters `fund` (a second deal, same token) during the inward pull | — | the outer `fund` reverts `UnderFunded`; no two deals can count the same tokens |
| G-27 | disclosed | anyone | direct `token.transfer` to the escrow (donation) | any | escrow balance rises; **no path pays more than `d.amount`**; the donation is permanently unrecoverable — the price of having no sweep function |
| G-28 | disclosed | anyone | force-send ETH (`selfdestruct`) | any | no function reads `address(this).balance`; nothing moves; the ETH is stuck |
| G-29 | disclosed | `DEPLOYER` or attacker | deploys **their own** `RecknZkEscrow` with a rogue verifier / vkey | — | the honest escrow's deals are untouched; the rogue escrow only affects deals funded into it. Verifying `verifier` + `verdictProgramVKey` is a **pre-funding** check (§2.3) |
| G-30 | theft | `DEPLOYER` | every row G-01…G-28 replayed from the deployer address | — | **byte-identical results to `STRANGER`.** The deployer has no stored role |
| G-31 | theft | fuzzed caller | `settleWithProof` **and** `refundAfterDeadline` | `dealId` never funded (fuzzed `dealId`) | both revert `BadState`; no storage is written |
| G-32 | theft | fuzzed caller | any successful settle/refund of a deal in token `T` | other deals Funded in token `U ≠ T` | token `U`'s escrow balance is **unchanged**; only `T` moves |

**32 rows. 20 theft, 7 authorized, 5 disclosed** — the counts are checked mechanically
(AC-13), so this table cannot drift from the tests.

---

## 4. State machine and invariants

### 4.1 Contract changes required (C-1 … C-7)

Each change is justified by the matrix row(s) that would otherwise have no true expected
result. Anything not listed here must not change.

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
  per-deal; anyone who wants a different window deploys another escrow, and deploying
  grants no power (G-29/G-30). Rejected alternative: a buyer-supplied per-deal
  `deadline` — it lets the buyer pick a deadline in the past and front-run a late proof,
  which is discretion over the seller's payout, i.e. the thing the product says it does
  not have.
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
- **C-5 — payouts are verified.** `settleWithProof` and `refundAfterDeadline` each measure
  the escrow's `balanceOf` before and after their `transfer` and revert `PayoutFailed()`
  unless it decreased by exactly `d.amount`. Consequence, deliberate: `Settled` and
  `Refunded` always mean *paid*, so "terminal but unpaid" is unreachable (§4.3), and G-18
  / G-23 have a defined, retryable behaviour instead of a silent loss.
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
  `RecknZkEscrow` outside `zk-verdict/contracts/test/` are prose documents (verified by
  grep across `*.rs`, `*.ts`, `*.js`, `*.sh`, `*.json`, 2026-09-04).

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
| `Funded → Settled/Refunded` with a payout to `msg.sender` | destinations are read from storage written at funding | G-13, AC-3 |
| **terminal-but-unpaid** (`Settled`/`Refunded` with no value moved) | C-5 reverts unless the balance fell by exactly `d.amount` | G-18 |
| **funded-but-unfunded** (`Funded` with no value received) | C-4 reverts unless the balance rose by exactly `amount` | G-20, G-21 |
| a deal permanently stuck in `Funded` when the token is well-behaved | `refundAfterDeadline` is callable by anyone forever after the deadline | G-10, G-14 |
| escrow holdings of token `T` < Σ Funded amounts in `T` | INV-4 | G-26, G-32 |

### 4.4 Invariants

- **INV-1 (no key).** For every entry point `f`, every deal state, and every pair of
  addresses `a, b`, calling `f` with identical arguments from `a` and from `b` produces
  identical state changes and identical value movements. Caller identity is not an input
  to any decision. Mechanically: the bodies of `settleWithProof` and
  `refundAfterDeadline` contain no occurrence of `msg.sender` or `tx.origin` (AC-1
  check 7), and `fund` uses `msg.sender` only as the recorded `buyer` and the
  `transferFrom` source.
- **INV-2 (destinations are fixed at funding).** Every outward transfer sends exactly
  `d.amount` of `d.token` to an address stored in the deal at funding time
  (`d.seller` or `d.buyer`). No destination is ever taken from calldata at settlement time,
  from `msg.sender`, or from `tx.origin`.
- **INV-3 (at most one payout per deal).** Over the lifetime of the contract, for each
  `dealId`, the number of outward transfers attributable to it is ≤ 1. `Reproduced` and
  a refund cannot both happen; a proof arriving after a refund is dead (G-17).
- **INV-4 (per-token solvency).** For every token `T`:
  `T.balanceOf(escrow) ≥ Σ { d.amount : d.state == Funded ∧ d.token == T }`.
  Holds for any token whose `balanceOf` and `transfer`/`transferFrom` are truthful;
  §8 states the residual.
- **INV-5 (cross-token isolation).** A call naming `dealId` moves only `deals[dealId].token`.
- **INV-6 (no inflation).** A payout is exactly `d.amount`. Donations (G-27), forced ETH
  (G-28), and other deals' principal never increase any payout.
- **INV-7 (absorbing terminals).** From `Settled` or `Refunded`, no entry point changes
  state or moves value.
- **INV-8 (liveness, conditional).** For every deal that reaches `Funded`, there exists a
  call that **any** address can make at any time `t ≥ fundedAt + refundDelay` which moves
  the deal out of `Funded` — **conditional on the token's `transfer` to `d.buyer` not
  reverting** (G-18). The condition is stated because it is real: a blacklisting token can
  brick a payout, and this spec does not claim otherwise.
- **INV-9 (binding soundness).** A proof settles deal `d` only if its committed
  `dealBinding` equals `d.dealBinding`, which was fixed at funding. The binding commits
  the authenticated prestate root, the predicate, and the plan
  (`keccak256("reckn/zk/bind/evm/v1" ‖ state_root ‖ check.address ‖ check.slot ‖
  check.min ‖ check.max ‖ keccak256(plan))`, `zk-verdict/program-revm/src/main.rs:176-190`).
  Therefore a proof of **some other favourable execution** cannot settle `d` — up to
  keccak-256 collision resistance and the correctness of the guest's construction, which
  the contract does not re-derive and 003 does not modify (N-2).
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
    proposer influence over `block.timestamp` irrelevant to any row.
  - basis points, wei, and lamports **do not appear** in this contract. The SVM guest's
    lamports (`program-svm`) reach the escrow only through the same `u64` verdict fields
    and are never converted to `Deal.amount`.

---

## 5. Acceptance criteria

Every AC is (a) a command whose exit status decides it, and (b) paired with at least one
**named degenerate implementation it must kill**. The mutants live in
`zk-verdict/contracts/test/mutants/MutantZkEscrow.sol` — one contract with an
`immutable uint256 MUT` selecting the mutation — and in
`scripts/no-keys-selftest.sh` for source-text mutants of the script's own target. A
mutant is "killed" by an AC if running that AC's command against the mutant **fails**.

Unless stated otherwise, commands run from the repo root; `forge` commands run in
`zk-verdict/contracts`.

### AC-0 — the central claim still holds (fixed text, `reckn-spec` charter)

```sh
bash scripts/no-keys.sh   # exit 0
```
The state-changing surface becomes `fund` / `settleWithProof` / `refundAfterDeadline` —
three functions. `AGENTS.md` §0 and `scripts/no-keys.sh` already enumerate exactly these
three, so the *permitted* surface does not change; what changes is that the third one now
**exists**. That is still a change to what the product claims (it previously claimed a
two-function surface plus a disclosed lock-up gap), so §9's documentation obligations
D-1…D-9 must land in the same commit and the demo script must say it out loud.

**Kills:** M-13 (constructor stores `msg.sender`), M-A (an `admin` address field), M-F
(an unlisted `function sweep`). All three are already known to fail the script
(`STATUS.md`); AC-1 makes that a script instead of a memory.

### AC-1 — the enforcement script is hardened over the whole face

`scripts/no-keys.sh` gains checks 5–8 and one strengthening of check 2, and gains an
optional **positional** target argument so it can be self-tested:

1. **check 2 becomes two-sided.** Today it only rejects `actual ⊄ expected`. It must also
   reject `expected ⊄ actual`: all three of `fund`, `settleWithProof`,
   `refundAfterDeadline` must be **present**. The keyless timeout thereby becomes a build
   condition and cannot be silently deleted later. *(This check fails until C-3 lands, so
   it must be committed together with the contract change.)*
2. **check 5 — no base contracts.** The declaration line must match
   `^contract[[:space:]]+RecknZkEscrow[[:space:]]*\{`. Inheritance is a way to reintroduce
   a privileged role **outside** the scanned body; the current script cannot see it.
3. **check 6 — no unenumerated entry point or escape hatch.** The body must not contain
   `fallback`, `receive`, `assembly`, `tx.origin`, `.call(`, `.call{`, `staticcall`
   (`delegatecall` and `selfdestruct` are already in check 1). A `fallback()` is an entry
   point that check 2's `function` grep cannot see at all.
4. **check 7 — `msg.sender` appears only inside `fund`.** Split the body at `function `
   boundaries; the ranges beginning `function settleWithProof` and
   `function refundAfterDeadline` must contain zero occurrences of `msg.sender`. This
   replaces check 3's regex, which matches `require( msg.sender == x)` but **not**
   `require(x == msg.sender)`. Check 3 is kept as-is in addition.
5. **check 8 — the constructor assigns only permitted immutables.** Inside the
   constructor body, the left-hand side of every assignment must be in
   `{verifier, refundDelay}`.
6. **target override.** `bash scripts/no-keys.sh [path]` accepts an optional positional
   path (no environment variable — an env var can be set invisibly). When a path is given
   the final line must read `✓ (target override: <path>) …` so an override's output can
   never be pasted as evidence for the claim.

```sh
bash scripts/no-keys-selftest.sh   # exit 0 = every source mutant is rejected, the clean copy accepted
bash scripts/no-keys.sh            # exit 0, and the output has no "target override"
```

**Kills:** M-14 `contract RecknZkEscrow is Owned {`; M-15 a `fallback() external {}`
that forwards tokens; M-16 `require(tx.origin == x)`; M-17
`require(x == msg.sender)` inside `settleWithProof`; M-18 a constructor that also stores
`bytes32 private _secret = keccak256(abi.encode(msg.sender))`; M-19 deleting
`refundAfterDeadline` entirely. A control mutant M-0 (an unmodified copy) must be
**accepted**, so the selftest cannot pass by rejecting everything.

### AC-2 — settlement authority is caller-independent (fuzzed)

```sh
forge test --match-test "testFuzz_AC02" -vv
```
For a fuzzed `address caller`, with `vm.assume(caller != address(escrow))` **and no other
exclusion**, all of the following hold, per row G-01/G-02/G-03/G-05/G-06/G-08/G-09:
a proof that verifies and matches the binding settles identically regardless of `caller`,
and every non-verifying / non-matching / bad-outcome input reverts regardless of `caller`.
Additional `vm.assume` narrowing is permitted only with an inline comment naming the
mechanism that requires it. **Excluding the buyer, the seller, the deployer, or any
address used elsewhere in the test file is forbidden** — those are exactly the addresses a
degenerate implementation would special-case.

**Kills:** M-1 `if (msg.sender == 0x5E11E5) { pay(d.seller); return; }` (a hardcoded
"test address" bypass — the failure mode this project has hit three times); M-2
`if (msg.sender == _creator) { … }`.

### AC-3 — the refund destination is the buyer, for every caller (fuzzed)

```sh
forge test --match-test "testFuzz_AC03" -vv
```
For a fuzzed `address caller` (same exclusion rule as AC-2) and a fuzzed
`uint256 t` bounded to `[deadline, deadline + 3650 days]`, `refundAfterDeadline`
succeeds, moves exactly `d.amount` to `d.buyer`, and moves **0** to `caller`
(rows G-12, G-13, G-14).

**Kills:** M-3 `token.transfer(msg.sender, d.amount)`; M-4
`token.transfer(d.seller, d.amount)`; M-5 `token.transfer(tx.origin, d.amount)`.

### AC-4 — nobody can refund before the deadline (fuzzed caller × fuzzed time)

```sh
forge test --match-test "testFuzz_AC04" -vv
```
For a fuzzed caller and a fuzzed `t` bounded to `[fundedAt, deadline − 1]`,
`refundAfterDeadline` reverts `DeadlineNotReached` and the escrow balance is unchanged
(row G-11). The boundary is tested exactly: `t = deadline − 1` reverts, `t = deadline`
succeeds.

**Kills:** M-6 the deadline check is dropped; M-7 the comparison is `>` instead of `>=`
at the exact boundary — killed by the `t = deadline` case, not by the fuzz.

### AC-5 — a deal pays at most once, in both orders

```sh
forge test --match-test "test_AC05" -vv
```
Four sequences, each asserting that the second value-moving call reverts `BadState` and
that the total tokens leaving the escrow for that deal equal exactly `d.amount`:
settle→settle (G-07), refund→refund (G-15), settle→refund (G-16), refund→settle with a
genuinely valid late `Reproduced` proof (G-17).

**Kills:** M-8 `refundAfterDeadline` pays without writing `d.state`; M-9
`settleWithProof`'s guard is `if (d.state == State.Settled) revert` (so a `Refunded` deal
still settles → the double-pay this project's 001 requirements exist to prevent).

### AC-6 — the binding is what settles the deal

```sh
forge test --match-test "test_AC06 testFuzz_AC06" -vv
```
Row G-03, in two forms: (a) the committed real fixture proof settles deal X funded with
the fixture's `deal_binding`, and (b) the **same** proof reverts `BindingMismatch` against
a deal funded with any fuzzed `bytes32 other != fixture binding`. This is the
"another convenient execution cannot settle this deal" acceptance condition.

**Kills:** M-10 the `BindingMismatch` check is removed; M-11 the check is
`if (v.dealBinding == bytes32(0) || v.dealBinding == d.dealBinding)` (accepts a
zero-binding proof, i.e. the predicate guest's, which commits `dealBinding = 0`,
`zk-verdict/lib/src/lib.rs:29-31`).

### AC-7 — the outcome byte decides the destination, and nothing else does

```sh
forge test --match-test "testFuzz_AC07" -vv
```
For fuzzed `uint8 outcome`: `0 → seller`, `1 → buyer`, everything else → revert
`BadOutcome` with the deal still `Funded` (rows G-04, G-05, G-06).

**Kills:** M-12 `to = d.seller` unconditionally; M-20 `outcome != FAILED ⇒ seller`
(pays the seller on outcome 7).

### AC-8 — a deal cannot be Funded without the tokens arriving

```sh
forge test --match-test "test_AC08 testFuzz_AC08" -vv
```
Rows G-20, G-21: `fund` reverts `UnderFunded` against a token that returns `false`
without reverting and against a fee-on-transfer token, and **no** deal is created
(`deals(dealId).state == None`). Plus the positive control: a well-behaved token funds.

**Kills:** M-21 `fund` ignores `transferFrom`'s result and skips the delta check — the
mutation that reproduces today's code, which is why this AC exists.

### AC-9 — reentrancy cannot produce a second payout

```sh
forge test --match-test "test_AC09" -vv
```
Rows G-24, G-25, G-26, using `ReentrantERC20` that calls back into the escrow from within
`transfer` / `transferFrom`. Assert: the deal's total outward transfers = 1 (settle and
refund cases), and the interleaved-`fund` case reverts `UnderFunded` with neither deal
created.

**Kills:** M-22 `d.state = State.Settled` moved to **after** the `transfer`.

### AC-10 — solvency and isolation under random call sequences (invariant test)

```sh
forge test --match-path "test/KeyGauntletInvariant.t.sol" -vv
```
A Foundry invariant test with a handler exposing `fund`, `settleWithProof`,
`refundAfterDeadline`, `donate`, and `warp`, over **≥ 3 deals in ≥ 2 tokens** and a
fuzzed actor set, asserting INV-3, INV-4, INV-5, INV-6, INV-7 after every call.
Configuration is pinned in `foundry.toml` (`runs`, `depth`) so the AC is reproducible;
the values used must be printed in `gauntlet.json`.

**Kills:** M-23 `refundAfterDeadline` pays `token.balanceOf(address(this))` instead of
`d.amount` (drains other deals and donations — passes every single-deal test); M-24
`settleWithProof` pays `d.amount` of a token taken from calldata rather than `d.token`
(breaks INV-5).

### AC-11 — a funded deal's terms are immutable

```sh
forge test --match-test "testFuzz_AC11" -vv
```
Row G-19: for a fuzzed caller and fuzzed `(seller, token, amount, binding)`, `fund` on an
existing `dealId` reverts `DealExists` and the stored `Deal` is bytewise identical before
and after (compare the full ABI-encoded struct, not field-by-field spot checks).

**Kills:** M-25 the `DealExists` guard is removed; M-26 the guard is
`if (deals[dealId].state == State.Settled) revert` (so a **Funded** deal can be
overwritten with a new seller — the redirect attack).

### AC-12 — an unfunded deal has no behaviour

```sh
forge test --match-test "testFuzz_AC12" -vv
```
Row G-31: for fuzzed `dealId` and fuzzed caller, both entry points revert `BadState` and
no storage slot for that deal is written.

**Kills:** M-27 `refundAfterDeadline` omits the state guard (a never-funded deal has
`fundedAt == 0`, so `0 + refundDelay` is long past and it would "refund" 0 tokens to
`address(0)`, writing a bogus `Refunded` record).

### AC-13 — the matrix cannot drift from the tests or from the demo

```sh
bash scripts/gauntlet.sh --check   # exit 0
```
The set of `G-NN` identifiers is identical across three places, compared as sets:
this file's §3.2 table, the test names in
`zk-verdict/contracts/test/KeyGauntlet*.t.sol` (each test name contains its ID as
`_G07_`), and `rows[].id` in `docs/gauntlet.json`. The per-class counts in §3.2's closing
sentence (20 theft / 7 authorized / 5 disclosed) are recomputed from the JSON and must
match. Any mismatch exits non-zero and names the missing IDs.

**Kills:** M-28 a hand-edited `gauntlet.json` with a row deleted; M-29 a test file where
a row's test exists but is named without its ID; M-30 a §3.2 row added to this document
without a test.

### AC-14 — the mutation harness is real (negative control on the negative controls)

```sh
bash scripts/mutation-kill.sh   # exit 0
```
Runs the kill table: for each mutant `M-n` in §5, run the AC that names it and assert it
**fails**; then run the control mutant **M-0** (the unmodified contract) and assert every
AC **passes**. The script prints a table `mutant | killed-by | status` and exits non-zero
if any mutant survives **or** if M-0 is reported killed.

**Kills:** its own control. A harness that reports "all mutants killed" by failing
everything is caught by M-0; a harness that reports success by running nothing is caught
by the required count line (`N mutants, N killed`) being compared against the number of
`M-` identifiers in this file.

### AC-15 — the judge-facing surface is generated, not written

```sh
bash scripts/gauntlet.sh   # exit 0, regenerates docs/gauntlet.json and prints the table
git diff --exit-code docs/gauntlet.json   # exit 0 after ignoring generated_at/commit
```
`scripts/gauntlet.sh` must: print the five private keys with the banner
`LOCAL ANVIL / FOUNDRY ONLY — throwaway development keys, no real funds`; print the
escrow address, the `verifier` address, the `verdictProgramVKey`, and `refundDelay`
(§2.3's pre-funding check); run the gauntlet test suites; write `docs/gauntlet.json`
(schema §7.1) from the **actual** run; render the matrix as an ASCII table; and end with
the money-shot line

```
32/32 rows as specified. Keys published: 5. Keys that helped: 0.
```

It must exit non-zero if any test fails, and in that case must **not** print the
money-shot line.

**Kills:** M-31 a `gauntlet.sh` that prints a canned transcript — the negative control is
to break one gauntlet test on purpose and assert `gauntlet.sh` exits non-zero and the
money-shot line is absent from its output.

### AC-16 — the honest scope is not quietly overwritten

```sh
bash scripts/gauntlet.sh --check   # includes the honest-scope digest check
```
The two "Honest scope" blocks in `zk-verdict/README.md` are byte-frozen by SHA-256,
recorded here:

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

and the same with `/^### Honest scope of the SVM guest/`. 003 resolves none of those items, so the
digests must be unchanged at the end of 003. **If a later task legitimately resolves one,
it changes the digest in this table in the same commit and states the evidence.**

**Kills:** M-32 a documentation edit that softens "Not yet:" to "Now closed:" — the
digest check fails.

### AC-17 — the pre-existing settlement path still works

```sh
forge test   # the whole zk-verdict/contracts suite, all green
bash zk-verdict/scripts/zk-e2e.sh   # exit 0
```
The five existing tests in `RecknZkEscrow.t.sol` — in particular
`test_real_proof_settles_to_seller`, which settles a **real Groth16 proof** — must still
pass unmodified except for the constructor's new `refundDelay` argument. Test counts
printed in `README.md` must be updated from the actual output (D-4).

**Kills:** M-33 a change to the `VerdictPublicValues` decode order, which would make the
real fixture stop settling — the regression this AC exists to catch.

**Count: 18 acceptance criteria (AC-0 … AC-17). All 18 name at least one degenerate
implementation they must kill. 37 mutant identifiers are named in total — M-0 … M-34 plus
M-A and M-F — of which M-0 is the survive-control. Behavioural mutants (M-1…M-12,
M-20…M-27, M-33, M-34) live in `MutantZkEscrow.sol`; source-text mutants of the contract
file (M-13…M-19, M-A, M-F) are driven by `scripts/no-keys-selftest.sh`; harness and
document mutants (M-28…M-32) are driven by `scripts/gauntlet.sh` and
`scripts/mutation-kill.sh`.**

---

## 6. Test plan

### 6.1 Files

| file | purpose | ACs |
|---|---|---|
| `zk-verdict/contracts/test/KeyGauntlet.t.sol` | one test per matrix row, named `test_G07_replay_reverts` etc. | AC-5, AC-8, AC-9, AC-13, AC-17 |
| `zk-verdict/contracts/test/KeyGauntletFuzz.t.sol` | caller / time / parameter fuzz | AC-2, AC-3, AC-4, AC-6, AC-7, AC-11, AC-12 |
| `zk-verdict/contracts/test/KeyGauntletInvariant.t.sol` + handler | random call sequences over multiple deals and tokens | AC-10 |
| `zk-verdict/contracts/test/mutants/MutantZkEscrow.sol` | one contract, `immutable uint256 MUT`, one branch per behavioural mutation (M-1…M-12, M-20…M-27, M-33, M-34) | AC-14 |
| `zk-verdict/contracts/test/MutationKill.t.sol` | asserts each mutant fails its AC's property and M-0 passes all | AC-14 |
| `zk-verdict/contracts/test/mocks/ReentrantERC20.sol` | calls back into the escrow from `transfer`/`transferFrom` | AC-9 |
| `zk-verdict/contracts/test/mocks/FalseReturningERC20.sol` | returns `false`, never reverts | AC-8 |
| `zk-verdict/contracts/test/mocks/FeeOnTransferERC20.sol` | delivers `amount − fee` | AC-8 |
| `zk-verdict/contracts/test/mocks/BlacklistERC20.sol` | reverts on `transfer` to a chosen address | G-18, G-23 |
| `scripts/no-keys-selftest.sh` | source-text mutants of `RecknZkEscrow.sol` vs `no-keys.sh` | AC-1 |
| `scripts/mutation-kill.sh` | drives `MutationKill.t.sol`, prints the kill table | AC-14 |
| `scripts/gauntlet.sh` | judge-facing runner + `docs/gauntlet.json` generator + `--check` | AC-13, AC-15, AC-16 |

### 6.2 Positive path (must pass)

Rows G-04, G-05, G-09, G-12, G-13, G-14 and AC-17's real-proof test. A gauntlet that only
proves things revert would be satisfied by a contract that reverts on everything; the
authorized rows are what stop that.

### 6.3 Negative controls (must fail — the point of the exercise)

Each of these is an artefact that must be **observed failing**, and the observation is
itself asserted:

1. **M-0 survives.** The unmodified contract must pass every AC. If the harness reports
   M-0 as killed, the harness is broken (AC-14).
2. **Every M-1 … M-33 is killed by its named AC** (AC-14, AC-1).
3. **A contract that reverts on everything** fails AC-17 and every authorized row —
   include it as mutant M-34 to prove the suite is not satisfied by universal denial.
4. **A `gauntlet.sh` run with one test deliberately broken** exits non-zero and omits the
   money-shot line (AC-15).
5. **A clean copy of `RecknZkEscrow.sol`** is accepted by `no-keys.sh` in the selftest
   (AC-1), so the selftest cannot pass by rejecting everything.
6. **A softened Honest-scope edit** fails the digest check (AC-16).

### 6.4 Anti-degeneracy rules (this project has opened the same hole three times)

Binding on the implementation:

- **R-1** No test may `vm.assume` away an address that appears elsewhere in the same test
  file, and no `vm.assume` may be added without an inline comment naming the mechanism
  that requires it.
- **R-2** No assertion may be satisfied by a constant. Every value assertion compares
  against a quantity derived from the deal's own funding (`d.amount`, `d.buyer`,
  `d.seller`), not against a literal repeated from the setup.
- **R-3** Any test that would still pass if the contract's function body were replaced by
  `revert()` must be paired with an authorized-row test that would then fail.
- **R-4** Fuzz runs are configured in `foundry.toml`, not per-test, and the configured
  `runs` is printed into `gauntlet.json`. A finite fuzz is evidence, not proof (§8).

---

## 7. Judge-facing surface

003 owns the **machine-checked artefact**. `reckn-demo` owns the pixels. The contract
between them is the JSON below; `reckn-demo` may render it however it likes and must not
hand-edit it.

### 7.1 `docs/gauntlet.json` — schema `reckn/gauntlet/v1`

```json
{
  "schema": "reckn/gauntlet/v1",
  "generated_at": "2026-09-0?T??:??:??Z",
  "commit": "<git rev-parse HEAD>",
  "tier": "local-foundry",
  "contract": {
    "name": "RecknZkEscrow",
    "address": "0x...",
    "verifier": "0x...",
    "verdict_program_vkey": "0x...",
    "refund_delay_seconds": 86400
  },
  "fuzz": { "runs": 256, "invariant_runs": 256, "invariant_depth": 32 },
  "keys_published": [
    { "role": "BUYER",    "address": "0x...", "private_key": "0x..." },
    { "role": "SELLER",   "address": "0x...", "private_key": "0x..." },
    { "role": "KEEPER",   "address": "0x...", "private_key": "0x...",
      "note": "the party a competing design would make the resolver" },
    { "role": "DEPLOYER", "address": "0x...", "private_key": "0x..." },
    { "role": "STRANGER", "address": "0x...", "private_key": "0x..." }
  ],
  "rows": [
    { "id": "G-03", "class": "theft", "actor": "SELLER",
      "method": "settleWithProof",
      "precondition": "real verifying proof bound to a different deal",
      "expected": "revert:BindingMismatch",
      "observed": "revert:BindingMismatch",
      "status": "AS_SPECIFIED",
      "test": "test_G03_foreign_binding_cannot_settle" }
  ],
  "totals": {
    "rows": 32, "theft": 20, "authorized": 7, "disclosed": 5,
    "as_specified": 32, "keys_that_helped": 0
  }
}
```

`status ∈ {AS_SPECIFIED, DEVIATED}`. `keys_that_helped` is computed, not written: it is
the number of theft rows whose `observed` differed between a key-holding actor and a
fuzzed stranger. Any non-zero value must make `gauntlet.sh` exit non-zero.

### 7.2 Terminal rendering

```
▶ KEY GAUNTLET — LOCAL FOUNDRY ONLY — throwaway development keys, no real funds
  escrow   0x...     verifier 0x...     vkey 0x...     refundDelay 86400s

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

  32/32 rows as specified. Keys published: 5. Keys that helped: 0.
```

### 7.3 What `reckn-demo` must say out loud

- The surface grew from two functions to three, and why (`AGENTS.md` §0's requirement).
- The tier: local Foundry / anvil. Not testnet, not mainnet.
- The five **disclosed** rows are shown, not hidden — G-18, G-23, G-27, G-28, G-29 — plus the
  post-deadline race (§8).

---

## 8. What this does not prove

Written here so that no one has to say it under questioning.

- **A finite fuzz is not a proof.** AC-2/AC-3/AC-4/AC-11 sample the address space and the
  timeline; they do not establish caller-independence for all inputs. The mutation kill
  table (AC-14) raises the cost of a degenerate implementation; it does not eliminate it.
  There is no formal verification here, and this spec does not use the words "impossible"
  or "cannot, in principle".
- **The matrix is exhaustive with respect to §3.1's enumeration** (two exits, one inward
  site, one writing entry point, plus reentrancy and out-of-band), and AC-1 makes that
  enumeration a build condition. It is not exhaustive with respect to attacks outside that
  frame — compiler bugs, EVM-level behaviour changes, and the SP1 verifier's own soundness
  are all outside it.
- **Token honesty is assumed.** INV-4/INV-6 hold for tokens whose `balanceOf` and
  `transfer` are truthful. A token that lies about balances can corrupt deals denominated
  **in itself**; INV-5 confines the damage to that token, and G-32 tests the confinement.
- **The post-deadline race is real.** After `fundedAt + refundDelay`, a late-but-valid
  `Reproduced` proof and a refund compete; whichever lands first wins, and both are
  authorized outcomes. There is no mechanism to prefer one, because every such mechanism
  needs a party holding a trigger. `MIN_REFUND_DELAY` and the deployed window are the only
  mitigation, and the demo must state this rather than imply proofs always win.
- **Payout liveness depends on the token** (INV-8, G-18, G-23). A blacklisting token can
  brick a payout to a specific address in either direction.
- **A fraudulent deployment settles fraudulently** (§2.3, G-29). The check is
  pre-funding, and 003 makes it possible by printing the verifier address and vkey; it
  does not make it automatic.
- **`zk-verdict/README.md`'s Honest scope is untouched** (AC-16): the in-guest precompile
  restriction, the `u64` verdict values, the 1-CALL + 1-delta scale, and the off-chain
  `state_root`↔header binding are all exactly as true after 003 as before it.
- **Tier.** Everything above is Foundry and local anvil. Nothing here is evidence about a
  testnet or mainnet deployment (`AGENTS.md` §5).

---

## 9. Implementation obligations (documentation moves in the same commit)

`AGENTS.md` §0 requires that a change to the claimed surface updates the claim
everywhere in the same change. The timeout's arrival makes exactly these statements false.
Each is a `file:line` as of 2026-09-04.

| ID | file:line | today | obligation |
|---|---|---|---|
| D-1 | `README.md:566-571` | "**`RecknZkEscrow` has no timeout.** … the first ETHOnline task" | Replace with the closed state: permissionless post-deadline refund, the window is an immutable construction parameter, and the residual (post-deadline race, token-dependent payout liveness) is stated. **Do not delete the bullet silently** — the gap list must show that a gap was closed, with a link to this spec |
| D-2 | `CLAUDE.md:46-49` | "**`RecknZkEscrow` に timeout が無い**（proof が来なければ資金は永久ロック）… タスク 001。**未解決**" | Rewrite as closed by 003, with the date and the AC that proves it |
| D-3 | `AGENTS.md:70` | task table row `001` | Mark folded into 003 per the 2026-09-04 ruling; keep the row so the history is legible |
| D-4 | `README.md:551`, `README.md:669` | "`forge test`: **12 passing**", "— 12 tests" | Update from the **actual** `forge test` output. Do not estimate (`AGENTS.md` §5) |
| D-5 | `zk-verdict/README.md:234-237` | the two-bullet function list | Add `refundAfterDeadline(dealId)` — permissionless, pays the buyer, only after the window. **Do not touch lines 154-164 or 208-221** (AC-16) |
| D-6 | `zk-verdict/README.md:239-243` | "Tested (`RecknZkEscrow.t.sol`): …" | Add the gauntlet: keys published, matrix size, and the one-command runner |
| D-7 | `STATUS.md:15` | "撤退可能点 \| **9/9** — 001/002 が緑でなければ" | Align with `AGENTS.md` §7's post-ruling wording: **003 (which contains 001's acceptance criteria) green**. `STATUS.md:39-40` also still points at a `docs/specs/001-keyless-timeout.md` that will never exist |
| D-8 | `SUBMISSION.md:156-160` | ZK settlement bullet | Add the gauntlet and the timeout; keep the SVM/EVM honest-scope sentences intact |
| D-9 | `README.md:67` | "the enumerated `fund` / `settleWithProof` / `refundAfterDeadline`" | Already correct — but add that all three must now be **present**, not merely permitted (AC-1's two-sided check 2) |

**Not to be edited by any agent:** `docs/ethonline-2026/PLAN.md:17-18, 27, 33` state the
two-function surface and the open timeout gap. That file is a founder document
(`AGENTS.md` §8). After 003 lands it will be stale. **Report the staleness to the founder;
do not fix it.**

### 9.1 Suggested part split for `reckn-codex-impl`

Each part must end green. Do not merge them into one Codex call.

1. **P1** — C-1…C-7 in `RecknZkEscrow.sol` + minimal adjustment of the five existing
   tests to the new constructor. Ends green on `forge test` and AC-17.
2. **P2** — `scripts/no-keys.sh` checks 5–8, two-sided check 2, positional target,
   `scripts/no-keys-selftest.sh`. Ends green on AC-0 and AC-1.
3. **P3** — mocks + `KeyGauntlet.t.sol` (all 32 rows). Ends green on AC-5…AC-9, AC-12.
4. **P4** — `KeyGauntletFuzz.t.sol` + `KeyGauntletInvariant.t.sol`. Ends green on
   AC-2, AC-3, AC-4, AC-6, AC-7, AC-10, AC-11.
5. **P5** — `MutantZkEscrow.sol`, `MutationKill.t.sol`, `scripts/mutation-kill.sh`.
   Ends green on AC-14.
6. **P6** — `scripts/gauntlet.sh`, `docs/gauntlet.json`, the digest check. Ends green on
   AC-13, AC-15, AC-16.
7. **P7** — D-1…D-9. Ends green on the whole AC set re-run from a clean tree.

---

## 10. Open questions

Genuinely undecided. **Do not guess; bring these back rather than inventing an answer.**

- **OQ-1 — Do the published keys have to actually sign?** The full 32-row matrix runs in
  Foundry, where `vm.prank` impersonates an address **without using its private key**. A
  sceptical judge can say the keys were never really used. *Recommendation:* keep the full
  matrix in Foundry (fast, fuzzable, exhaustive) and add a small `anvil` mode to
  `scripts/gauntlet.sh` that really signs three headline rows (G-03, G-13, G-14) with the
  published keys via `vm.startBroadcast(pk)` / `cast send --private-key`. Cost: the anvil
  path needs the SP1 verifier and the fixture deployed locally, which `zk-e2e.sh` already
  does for the settle path but not for the gauntlet. **Founder call: is the extra
  credibility worth roughly one part of implementation time?**
- **OQ-2 — Should `gauntlet.json` name the optimistic path as out of scope?** The claim is
  about `RecknZkEscrow`. `contracts/RecknEscrow` has a bonded resolver **by design** and
  is not in the demo (`AGENTS.md` §8). One honest line in the output
  ("`RecknEscrow` (optimistic, not demoed) does hold keys by design") pre-empts the
  question but re-introduces the commodity path into the judge's frame. **Founder call.**
- **OQ-3 — What is the deployed `refundDelay` for the demo?** The contract's bounds are
  fixed here (1 hour … 30 days). The demo's value is a product decision: 24 h reads as
  realistic but forces a `vm.warp` on screen; 1 h reads as a toy. The specification does
  not depend on the choice; `gauntlet.json` prints whatever is used.
- **OQ-4 — Does the seller need an on-chain acceptance step?** Today a seller learns the
  deal's terms (including the deadline) only from the `Funded` event, and never signals
  agreement on-chain. Adding acceptance would add a fourth function and a second party's
  consent — i.e. a key-shaped thing — so it is **not** in 003. But it is the honest
  answer to "what stops a buyer funding a one-hour window on a day-long job?" and it may
  belong in a later task or in the product's off-chain layer. **Recorded, not resolved.**

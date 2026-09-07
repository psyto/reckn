# 011 — Tempo TIP-20 slice: one payment, both directions

> **Status:** spec, round 0.
>
> **Lane:** Crypto World's Fair (2026-09-14 → 10-12). This is **additive**. Task 011 does
> not modify `RecknZkEscrow.sol`, `RecknVerdictVerifier.sol`, the guests, the fixtures, the
> Arc deploy script, `arc.json`, `arc-constants.sh`, any existing test, or any existing
> claim. If a change to any of those turns out to be required, that is a finding to report,
> not a change to make — see §9.
>
> **Tier: local, then testnet.** Everything in §7's T-1 … T-8 runs in Foundry against a
> mock. **No mainnet, no real funds, no key generated or stored or used by the agent.**
> §9 names every point where founder action is required.
>
> **Measurement provenance.** Every Tempo number in §2.2 was read on **2026-09-08** by
> unauthenticated JSON-RPC against the public endpoint, by this repository's operator. No
> number in this document is transcribed from a blog post or a search result. Facts about
> TIP-20 that were read from documentation rather than measured are marked **[doc]**, and
> facts that are neither are marked **[unknown]** and are not assumed anywhere.

---

## 1. The claim (one sentence)

**A Tempo agent payment settles only when a Solana action can be reproducibly proven** —
the escrow holds a TIP-20 stablecoin, the release condition is a Groth16 proof that a named
Solana execution reproduced, and the same proof machinery refunds the buyer when it did not.

## 1.1 What makes this Tempo-native rather than a redeploy

Tempo **has no native gas token**. Transaction fees are paid in a USD-denominated TIP-20
stablecoin ([doc], and consistent with the measurement in §2.2 that `eth_getBalance` returns
a constant). So in this slice:

> **The same TIP-20 stablecoin is both the contents of the escrow and the fee that pays for
> its release.**

That sentence is false on Arc — there, USDC is the native gas token at 18 decimals and the
ERC-20 face the escrow holds is a separate 6-decimal view of it. It is false on every chain
where gas is a separate asset. It is the reason this slice is not "the same Solidity on
another RPC", and **T-4 is the acceptance criterion that makes it evidence rather than a
sentence.**

## 1.2 Non-goals — including the ones it will be tempting to do anyway

- **Not a general Tempo port.** One vertical slice, both directions. Nothing in Reckn is
  generalised, parameterised, or refactored to accommodate Tempo.
- **Not a bridge, and no claim that a proof makes a bridge trustless.** There is no bridge
  here to make trustless. The TIP-20 never leaves Tempo; Tempo never runs a Solana VM.
- **No provenance claim.** The guest recomputes a `bank_hash` over the account set *the deal
  named*. That is consistency, not provenance. It does **not** establish that those inputs
  came from Solana mainnet. This is the same boundary already stated for Arc and it does not
  move.
- **No LLM adjudication of subjective quality.** Not added, not in scope, not in the demo.
- **No new privileged address, no new admin, no pause, no upgrade path.** `no-keys.sh` must
  pass unchanged (T-6).
- **No memo-based semantics.** TIP-20 supports a 32-byte transfer memo [doc]. The escrow
  will not read one, will not depend on one, and will not encode meaning into one. A memo is
  data an issuer can also write; making settlement depend on it would hand someone a lever.

---

## 2. What is there today

### 2.1 In this repository (read 2026-09-08, tree at `c27b298`)

- **`RecknZkEscrow.sol` names no chain and no token.** `grep -n 'Arc\|arc\|USDC'` over
  `zk-verdict/contracts/src/*.sol` returns **nothing**. The token is the `token` argument to
  `fund()`, and every movement is `IERC20Min.transferFrom` / `IERC20Min.transfer`.
- Function surface is the three of `AGENTS.md` §0: `fund`, `settleWithProof`,
  `refundAfterDeadline`. No constructor, no immutable, no owner.
- **Both directions already have real proofs.** `svm-groth16-fixture.json` (outcome
  `REPRODUCED`) and `svm-failed-fixture.json` (outcome `FAILED`) exist and are exercised by
  `RecknSvmVerdict.t.sol` and `RecknCrossVmSettlement.t.sol`.
- Arc gas, measured on the public chain: `solanaProofOnArc` **320,600**,
  `solanaFailureOnArc` **316,120**, `reproduced` **345,874** (`arc.json`).
- `MockUSDC.sol` already models the three token behaviours that can change a settlement
  outcome — decimals, revert-not-false, and a freeze. `MockTIP20` is its sibling, not its
  replacement.

**Conclusion: the contract layer requires no change.** The Tempo work is a deploy target, a
token mock, a test, a constants record, and a demo surface.

### 2.2 On Tempo (measured 2026-09-08, unauthenticated `eth_call` / `eth_getBalance` /
`eth_getBlockByNumber`; no key, no transaction, no funds)

| what | value | how |
|---|---|---|
| **testnet RPC** | `https://rpc.moderato.tempo.xyz` | `eth_chainId` → `0xa5bf` = **42431** |
| a second URL seen in search results | `https://rpc.tempo.xyz` → `0x1079` = **4217** | **a different chain.** Not the testnet |
| `0x08` bn256Pairing, empty input | `0x…0001` | as on Ethereum |
| `0x06` bn256Add, zero input | 64 zero bytes | as on Ethereum |
| `0x07` bn256ScalarMul, zero input | 64 zero bytes | as on Ethereum |
| `0x01` ecrecover, invalid input | `0x` | as on Ethereum |
| `TIP20Factory` `0x20Fc…0000` | has code | precompile present |
| `eth_getBalance` (arbitrary EOA) | `0x9612…` ≈ 6.8 × 10⁷⁴ | **a constant, not a balance** |
| block gasLimit | **500,000,000** | `eth_getBlockByNumber` |
| baseFeePerGas | 600,000,000 | denominated in the fee token |
| block height | ≈ 34,327,488 | the chain is live |

**Three consequences, and they are the reason this section exists.**

1. **BN254 is present with Ethereum semantics, so Groth16 verification is possible.** The
   single risk that could have ended this direction is measured, not inferred. What this
   does **not** show: that a real SP1 Groth16 proof verifies, and that it fits the fee model.
   That needs a deploy, and a deploy needs a key (§9).
2. **The published constants disagreed with each other, and one of them pointed at a
   different chain.** `tempo.json` + `tempo-constants.sh` exist for exactly this, and they
   are the same instrument `arc-constants.sh` is — it checks internal agreement, never that
   the record is right.
3. **`eth_getBalance` is meaningless on Tempo.** Any test, script, or demo page that shows
   "the seller's balance went up" by reading the native balance is showing a constant. On
   Tempo it must be `IERC20Min.balanceOf`. The Arc demo page reads both faces; the Tempo
   surface cannot copy that half.

### 2.3 Read from documentation, not measured **[doc]**

- TIP-20 keeps ERC-20 `transfer` / `transferFrom` / `approve` / `allowance` / `balanceOf`.
- **TIP-403 transfer policies** authorise *both* sender and recipient; a failure reverts with
  `PolicyForbids`.
- **`pause()` / `unpause()`** halt all token movement.
- Sending a TIP-20 to another TIP-20 contract address reverts with `InvalidRecipient`.
- Fees are settled by system functions `transferFeePreTx` / `transferFeePostTx`; only
  `currency == USD` tokens are eligible to pay fees.
- `TIP20Factory` precompile at `0x20Fc000000000000000000000000000000000000`.

### 2.4 Not established **[unknown]** — and therefore not assumed anywhere below

- The **decimals** of the testnet TIP-20 we will use. `MockTIP20` is written with decimals as
  a constructor argument for this reason, and the tests run it at 6 **and** 18.
- Whether a fee-paying transaction can be sent with **upstream** Foundry, or requires
  `tempoxyz/tempo-foundry` and its `--tempo.fee-token` flag. `eth_call` costs nothing and
  proves nothing about this.
- The testnet TIP-20 addresses and the faucet.
- Whether the testnet TIP-20 carries a TIP-403 policy that restricts ordinary transfers.

---

## 3. Design

**No contract change.** `RecknZkEscrow` is deployed to Tempo as-is and funded with a TIP-20.

New files, all additive:

```
docs/specs/011-tempo-tip20-slice.md          this document
zk-verdict/contracts/tempo.json              the record: constants + provenance + receipts
zk-verdict/contracts/script/DeployTempo.s.sol
zk-verdict/contracts/test/mocks/MockTIP20.sol
zk-verdict/contracts/test/RecknTempoTip20.t.sol
zk-verdict/scripts/tempo-constants.sh
```

`DeployArc.s.sol`, `arc.json`, `arc-constants.sh` and every existing test are untouched.

### 3.1 `MockTIP20`

Models only what can change a settlement outcome, in the house style of `MockUSDC`:

1. **configurable decimals** — because §2.4 says we do not know them, and an escrow tested
   only at 18 has never been tested in the units it will hold.
2. **revert, never return false** — same reason as `MockUSDC`.
3. **`pause()`** — a paused token makes *every* payout revert, `refundAfterDeadline`
   included. That is strictly worse than Arc's blacklist and it is modelled, not described.
4. **a TIP-403-shaped policy hook** — `PolicyForbids` on sender or recipient.
5. **`InvalidRecipient`** — refuse a transfer whose recipient is another TIP-20.
6. **`transferWithMemo`** — present so a test can prove the escrow does **not** depend on it.

Not modelled: roles, supply caps, quote tokens, the fee precompile path. None of them can
change what `settleWithProof` does.

### 3.2 What the Tempo demo surface shows

Whatever it shows it reads from Tempo, the way the Arc live page reads from Arc. Two things
it must show that the Arc page does not: the **fee token of the settling transaction**
(T-4), and balances via `balanceOf` rather than `eth_getBalance` (§2.2.3).

---

## 7. Acceptance criteria

T-1 … T-3 and T-6 … T-8 are local and run in Foundry. T-4 and T-5 need a deploy (§9).

| # | condition | tier |
|---|---|---|
| **T-1** | A deal funded in TIP-20 **releases to the seller** on the `REPRODUCED` SVM proof. | local |
| **T-2** | The same shape of deal **refunds the buyer** on the `FAILED` SVM proof. | local |
| **T-3** | A **real Groth16 proof of a different execution** is rejected with `BindingMismatch` and **no token moves**. | local |
| **T-4** | The settling transaction's **fee is paid in a TIP-20**, shown from its receipt. | testnet |
| **T-5** | Every constant in `tempo.json` is used somewhere, and every Tempo-shaped literal in the tree is the recorded one (`tempo-constants.sh`). | local |
| **T-6** | `bash scripts/no-keys.sh` passes **unchanged**. The central claim did not widen. | local |
| **T-7** | With the token **paused**, `settleWithProof` reverts and the deal stays `Funded`. | local |
| **T-8** | With a **TIP-403 policy refusing the seller**, `settleWithProof` reverts, the deal stays `Funded`, and `refundAfterDeadline` is the only exit — **and if the token is paused, that exit is closed too.** | local |
| **T-9** | The escrow settles correctly at **6 and at 18 decimals**. | local |
| **T-10** | A memo written by the token does **not** change any settlement outcome. | local |

T-7 and T-8 are the failure directions. They are written first, not last, because on Arc the
identical hole — USDC's blacklist — was found by a test rather than by review, and it is what
`refundAfterDeadline` exists for.

### 7.1 The 30-day sentence that must not be blurred

`REFUND_AFTER = 30 days` and is deliberately not a parameter. **The CWF judging window is 28
days (09-14 → 10-12), so a deadline refund cannot be demonstrated on a public chain inside
it.** T-2's refund is a **proof-driven** refund (`FAILED` → buyer), which is immediate. Any
sentence that lets a reader merge the two is wrong, and the demo must not contain one.

---

## 8. Trust boundaries, stated as they narrow

The escrow names no privileged address. **On Tempo, the token does.**

A TIP-20 issuer holding `PAUSE_ROLE`, or a TIP-403 policy, can stop a payout that a valid
proof has authorised. On Arc the same shape appeared as USDC's blacklist and
`refundAfterDeadline` is the answer to it. On Tempo `pause()` reaches **further than Arc's
blacklist does**, because it can also stop `refundAfterDeadline` — so on Tempo there is a
state in which a proof-authorised payout and the timeout are **both** blocked by a third
party. That is disclosed (T-7, T-8), not mitigated, and Reckn does not claim otherwise.

Unchanged from Arc, and restated so nobody has to go looking: the proof establishes that the
**declared prestate, predicate and execution** produced the committed result. It does not
establish where the prestate came from.

---

## 9. Points that require founder action

The agent does not generate, store or use a key, and does not deploy.

1. **A testnet key and TIP-20 from the faucet** — required before T-4 and before any deploy.
2. **Whether upstream Foundry can send a fee-paying transaction**, or `tempo-foundry` is
   required (§2.4). This decides whether the build path forks.
3. **The testnet TIP-20 address and its decimals**, to be recorded in `tempo.json` with its
   source and read date before anything depends on it.

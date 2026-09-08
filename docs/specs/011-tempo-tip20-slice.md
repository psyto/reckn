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
| a second URL seen in search results | `https://rpc.tempo.xyz` → `0x1079` = **4217** | **Tempo MAINNET** (confirmed against the connection-details page, 2026-09-08). Not the testnet, and deploying to it is forbidden outright by `AGENTS.md` §8 |
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

### 2.2b Second pass, same day: how fees are actually paid

Documentation could not answer whether upstream Foundry can send a fee-paying transaction.
**213 transactions over 60 blocks** could.

| what | measured |
|---|---|
| transaction types in use | `0x0` **101**, `0x2` **66**, `0x76` **46** |
| fields only `0x76` carries | `feeToken`, `feePayerSignature`, `calls`, `nonceKey`, `validAfter`, `validBefore`, `keyAuthorization`, `aaAuthorizationList` |
| **every receipt** | carries **`feeToken`** and **`feePayer`** — *including for a plain type `0x2`* |
| the token both sampled receipts paid in | `0x20C0000000000000000000000000000000000000` |
| that token's `name()` / `symbol()` / `decimals()` | **PathUSD / PathUSD / 6** |

**This closes two of the three open items in §9 and changes one acceptance criterion's cost.**

1. **The build path does not fork.** Standard legacy and EIP-1559 transactions are in active
   use, so upstream Foundry can send one. `tempo-foundry` and `--tempo.fee-token` are needed
   only to **choose** a non-default fee token, which requires type `0x76`. Paying a fee does
   not.
2. **T-4 is satisfiable with a standard transaction**, because the receipt names the fee
   token itself. The criterion asked for evidence; the chain already emits it.
3. **The TIP-20 and its decimals are known without a faucet.** PathUSD, six decimals — the
   same as USDC on Arc, and `RecknTempoTip20.t.sol` already runs at 6 and 18.

What this still does **not** establish: that an SP1 Groth16 proof verifies on Tempo and fits
the fee model. The BN254 precompiles are measured present, which is necessary and not
sufficient. And a measurement of the chain's DEFAULT fee token is not a promise about the
token our deal will name — `DeployTempo` therefore keeps `TIP20=0x…` overridable.

### 2.2c Third pass, same day: Tempo's own EVM was made to run the whole path

Sections 2.2 and 2.2b measured the chain *around* the escrow. Neither answered the question
that could still have ended this direction: **does a real SP1 Groth16 proof actually verify
on Tempo?** "`0x08` on empty input returns 1" does not imply it — a Groth16 verification is
thousands of field operations and two real pairings.

It can be answered without a key. `eth_call` with `to: null` makes the node execute a
constructor; a constructor that ends in an assembly `return` hands back measurements instead
of runtime code. So the node itself deploys `SP1Verifier`, `RecknVerdictVerifier`,
`RecknZkEscrow` and a `MockTIP20`, funds a deal, settles it, and reports balances — inside
**Tempo's EVM**, with no transaction, no fee and no state written. A local `anvil` runs the
identical bytecode as a control; the three codehashes are compared, because if they differ
the two sides were not running the same contract and no other row means anything.

| case | Tempo | control |
|---|---|---|
| **REPRODUCED** — a real Groth16 proof of a real Solana execution | seller **+250.000000**, escrow emptied | identical |
| **FAILED** — the same machinery, the other direction | buyer **+250.000000**, seller 0 | identical |
| **mismatch** — a real proof of *another* execution | reverts `BindingMismatch()`, **nothing moves**, escrow still holds 250.000000 | identical |

`bash zk-verdict/scripts/tempo-evm-probe.sh` reproduces it; output in `tempo-evm-probe.json`.

**The gas differed by 2.6×–10.6×, so it was measured primitive by primitive**
(`tempo-gas-schedule.sh`). The answer is clean and it is the favourable one:

| | Tempo | control |
|---|---|---|
| `bn256Pairing`, two real pairs | **114,291** | **114,291** |
| `bn256Add`, `bn256ScalarMul`, `keccak`, `SLOAD`, warm `SSTORE`, `EXTCODESIZE` | all **1.00×** | |
| cold `SSTORE` 0→1 | 254,347 | 22,147 (**11.48×**) |
| code deposit, per deployed byte | ~2,577 | ~202 (**12.8×**) |

**Compute is identical; Tempo prices state.** `settleWithProof` is only 2.6× because it is
mostly pairing. `fund` is 10.6× because it writes a `Deal`. For an escrow whose expensive
operation is a proof verification, that is the direction you would choose.

**The real TIP-20 was measured against the escrow's assumptions** (`tempo-tip20-probe.sh`),
because `MockTIP20` was built from §2.3 — documentation — and a mock built from
documentation tests the documentation. Two of those lines are load-bearing:

- **PathUSD reverts; it never returns `false`** (`InsufficientBalance`,
  `InsufficientAllowance`). `RecknZkEscrow` ignores the ERC-20 boolean — `forge` lints it —
  so on a false-returning token `fund()` would record a funded deal holding nothing. This
  was an assumption inherited from the mock until it was measured.
- **The escrow is a valid recipient.** A transfer to an address carrying `RecknZkEscrow`'s
  real runtime bytecode succeeds, so `InvalidRecipient` does not catch ordinary contracts.
  A transfer to the token itself *does* revert `InvalidRecipient` — the documented rule,
  measured, and the behaviour T-11 already models.
- `currency()` is `USD` (fee-eligible) and `paused()` is `false` **today**. That is a reading
  of one moment, not a property; §8 discloses the pause risk rather than mitigating it.

**And the fee arithmetic is now derived rather than assumed.** From two real receipts:
`feeTokenUnits = gasUsed × effectiveGasPrice / 1e12`, checked against both (off by one unit,
rounding). The whole demo — deploy + fund + settle — is **≈31,000,000 gas ≈ 15.5 PathUSD**
at the price seen on 2026-09-08.

**What none of this establishes, and no README, page or submission may say it does.** An
`eth_call` writes no state, pays no fee and mines no block. It is **not a deployment**, it
does not satisfy **T-4**, and `tempo.json → deployedByReckn` stays empty until a real
receipt exists. The word for what is proven is *"Tempo's EVM computes this path"*, not
*"Reckn is deployed on Tempo"*.

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

**Two of these were closed the same day by §2.2b and are struck here rather than deleted, so
the sequence stays legible: they were unknown when the tests were written, and that is why
the tests do not assume either.**

- ~~The **decimals** of the testnet TIP-20.~~ **PathUSD, 6** (§2.2b). `MockTIP20` still takes
  decimals as a constructor argument and the tests still run 6 **and** 18 — a measurement of
  the default is not a promise about the token our deal names.
- ~~Whether upstream Foundry can send a fee-paying transaction.~~ **It can** (§2.2b).
- The **faucet**. Obtaining PathUSD needs a key and a browser — still §9.1.
- Whether the testnet TIP-20 carries a **TIP-403 policy** or is pausable in practice. The
  escrow is tested against both behaviours (T-7, T-8) rather than against an assumption.

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
| **T-4** | The settling transaction's **fee is paid in a TIP-20**, shown from its receipt's own `feeToken` / `feePayer` fields (§2.2b — the chain emits these for a standard type `0x2` transaction, so this needs no custom transaction type). | testnet |
| **T-5** | Every constant in `tempo.json` is used somewhere, and every Tempo-shaped literal in the tree is the recorded one (`tempo-constants.sh`). | local |
| **T-12** | All three of T-1/T-2/T-3 hold when **Tempo's own EVM** runs them, against a byte-identical local control (`tempo-evm-probe.sh`). **Not a deployment**: no transaction, no fee, no state. | remote read-only |
| **T-13** | The **real** TIP-20 reverts rather than returning `false`, accepts the escrow as a recipient, and refuses itself (`tempo-tip20-probe.sh`). | remote read-only |
| **T-14** | Every hash `tempo.json` records exists on chain with `status == 1`, every explorer link in the tree names a recorded hash, and every recorded settlement is linked (`tempo-receipts.sh`). **Reports the empty state as empty**, never as a pass. | testnet |
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

1. ~~**PathUSD from the faucet.**~~ **Closed by measurement, 2026-09-08.** The faucet is an
   **RPC method, not a browser**: `cast rpc tempo_fundAddress <ADDRESS> --rpc-url
   https://rpc.moderato.tempo.xyz`. It needs no wallet connection and **no key** — the caller
   does not have to be the address being funded — and one call mints **1,000,000** of each of
   pathUSD, AlphaUSD, BetaUSD and ThetaUSD. Against the measured need (≈16 PathUSD of fees for
   ≈31M gas, plus 3 escrowed), that is about **20,000× over**, so the amount is not a
   constraint and no budgeting is required. Its existence was **probed, not assumed**: bad
   params return `-32602`, where an invented method returns `-32601`; and 1,408 mint-shaped
   `Transfer` logs were counted over 3,000 blocks, each for exactly 1,000,000.000000.

1b. **A key — and this is now the ONLY founder action.** Imported **once** as an encrypted
   Foundry keystore (`cast wallet import <name> --interactive`) and passed to
   `tempo-testnet.sh` by **name** (`TEMPO_ACCOUNT`). The script refuses to read a private key
   from an argument or an environment variable, so no plaintext key exists in a shell history,
   a process list, a log or this repository.

2. ~~Whether upstream Foundry can send a fee-paying transaction.~~ **Closed by measurement**
   (§2.2b): it can, and the build path does not fork.
3. ~~The testnet TIP-20 address and its decimals.~~ **Closed by measurement** (§2.2b):
   PathUSD at `0x20C0…0000`, six decimals, recorded in `tempo.json` with how it was read.

So exactly **one** item now stands between this slice and its testnet half: **a key.** Not a
key *with PathUSD in it* — that phrasing was written before the faucet was found, and it made
funding sound like a second obstacle. Filling the key is one RPC call that anybody can make
for anybody's address. What cannot be delegated is holding the key, and the agent does not.

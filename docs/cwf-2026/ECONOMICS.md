# What it costs to decide a payment — and the deal size below which it is not worth deciding

**Written 2026-09-12.** Every number here is either measured on a public chain by this
repository, or an explicitly named unknown. Nothing is a projection, and there is no revenue
model on this page — the question is narrower and answerable: *what does one adjudication cost,
and therefore which payments are worth adjudicating?*

This page exists because **"high-stakes agent payments" is an adjective until someone computes
the threshold.** It is also the honest place to say that a threshold exists at all.

---

## 1. The measured half — the on-chain decision

From the settlement receipts on Tempo Moderato testnet (chain 42431), recorded in
[`zk-verdict/contracts/tempo.json`](../../zk-verdict/contracts/tempo.json) and re-derived from
the chain by `zk-verdict/scripts/tempo-verify.sh`:

| | gas | charged | as a share of the 1.000000 deal |
|---|---|---|---|
| release on a `Reproduced` Solana proof | **310,242** | **0.155307 PathUSD** | **15.53 %** |
| refund on a `Failed` Solana proof | **303,162** | **0.151762 PathUSD** | 15.18 % |

At the `effectiveGasPrice` the chain returned that day, that is **5.006 × 10⁻⁷ PathUSD per gas**.

**Three things follow, and the second is the one that matters.**

1. **The on-chain cost is absolute, not proportional.** Gas does not scale with the amount
   escrowed. The same 310,242 gas decides a 1-unit deal and a 100,000-unit deal, so the *share*
   falls as the deal grows: 15.53 % of 1.00, 0.16 % of 100.00, 0.0016 % of 10,000.00.
2. **Deciding against the seller costs the same as deciding for them** — 0.151762 versus
   0.155307, a **2.3 %** difference. Nobody can make the outcome cheaper by choosing it, and the
   loser does not pay a penalty for losing. *This is a property of the design, not a tuning
   choice:* the same `settleWithProof` runs both directions and the branch is a token transfer.
3. **Whoever calls it pays for it.** `settleWithProof` is permissionless; on both Tempo receipts
   the `feePayer` was the buyer. `refundAfterDeadline` pays its caller **nothing**, so that call
   is gas spent to return someone else's money — rational for the buyer, charity for anyone else.

**On Arc**, the same settlements cost 345,874 gas (`reproduced`), 320,600 (`solanaProofOnArc`)
and 316,120 (`solanaFailureOnArc`) — [`arc.json`](../../zk-verdict/contracts/arc.json). **No fee
in USDC is quoted here**, because Arc's receipts were not recorded with a fee field and this page
does not compute one it did not read.

## 2. The unmeasured half — the proof

What is measured is **latency on one laptop CPU with no prover network**, and latency is not
price:

| | cycles | end to end |
|---|---|---|
| the committed EVM fixture | **406,715** | **335.02 s** (constraints 15,972,262; proving 31.71 s) |
| a real Uniswap `exactInputSingle`, unmodified guest | **13,006,200** | **497.40 s** |
| the SVM guest | **986,097** | — |

**32× the work cost 1.49× the wall clock.** At these sizes the proof is dominated by fixed cost,
which is the difference between "heavier predicates are unaffordable" and "heavier predicates are
nearly free" — and it is measured (`docs/specs/012` §2.2), not assumed.

> **[unknown] — the price of a proof.** What a prover network charges per proof is an external
> price this project has not paid and does not quote. It is carried below as **P**, in dollars per
> proof. Self-proving on your own hardware is the **P → 0** row, and it is not free: it is the
> electricity and the 335–497 seconds.

## 3. The threshold

Let **r** be the largest share of a payment you are willing to spend on deciding it. With the
on-chain cost measured at **0.155307** and the proof at **P**:

> **minimum economically adjudicable deal = (0.155307 + P) / r**

| | P = 0 (self-proved) | P = $0.10 | P = $1.00 | P = $5.00 |
|---|---|---|---|---|
| **r = 1 %** | **$15.53** | $25.53 | **$115.53** | $515.53 |
| **r = 5 %** | $3.11 | $5.11 | **$23.11** | $103.11 |

**Read the middle column, not the corners.** At a plausible dollar-a-proof and a 1 % tolerance,
Reckn's floor is in the **low hundreds of dollars per payment**. That is the sentence *high-stakes*
was standing in for.

**Denomination assumption, stated because it is an assumption.** PathUSD is a USD-denominated
TIP-20 on a testnet; it has no market price, so `1 PathUSD = $1` is how it is denominated, not
something this repository measured. Every dollar figure above inherits that.

## 4. What the threshold is not

- **It is not enforced.** `RecknZkEscrow` has no minimum deal size, and `fund` takes any amount.
  The floor is an economic statement about when adjudication is worth buying — the protocol will
  happily decide a one-cent deal for 0.155307 in fees.
- **It is not a dispute cost. It is a settlement cost.** The keyless escrow's entire external
  surface is `fund` / `settleWithProof` / `refundAfterDeadline` (source: `RecknZkEscrow.sol:101`,
  `:133`, `:176`) — **there is no mutual-release path**. A buyer who is perfectly happy still
  cannot hand the money over without a proof. So the numbers above apply to *every* settlement,
  not to the disputed minority.
  **This is a deliberate trade and the repository carries both halves of it:** the optimistic
  escrow (`contracts/RecknEscrow`) is the cheap path for the happy case, and it has a bonded
  resolver — *a judge with a key*. You pay for certainty exactly where you want certainty. Anyone
  presenting the keyless path as free-when-uncontested is misreading the function list.
- **It says nothing about mainnet.** Both fee figures are testnet, at one day's gas price.
  Mainnet gas markets are not modelled here, and Tempo mainnet is not deployed.

## 5. What would move it

In the order they would actually matter:

1. **A prover network price** replaces **P** with a number, and the middle column stops being an
   assumption. This is the single largest lever and it is entirely external.
2. **Batching one proof over many deals** would divide P across them. Not designed, not specified,
   and not claimed — naming it here is scope, not a roadmap.
3. **Cheaper verification** would move the 310,242. BN254 verification costs what it costs; what
   is left is calldata and storage, and `settleWithProof` already writes one state word.

---

**Where this is used:** the *Viability* and *Potential Market Size* answers in
[`PREFLIGHT.md`](PREFLIGHT.md) §6, and the word *high-stakes* in [`PITCH.md`](PITCH.md), whose
audit says the word describes which payments are worth adjudicating rather than a threshold the
protocol enforces. **§4 above is why that sentence is honest.**

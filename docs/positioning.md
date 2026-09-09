# Where Reckn sits — and what it is not

> **One sentence.** *AI chooses, negotiates, and explains. **Re-execution decides the payout.***

This page exists because Reckn is easy to place in the wrong layer. It is not a payment rail,
not a wallet policy, not a bridge, not an oracle, and not a judge of subjective quality. It is
the layer that decides **whether a payment is released**, and it decides it by replaying the
work rather than by asking anyone.

Everything below that is a measurement carries the command that produced it. Everything that
is a limit is stated as a limit, and the **design** limits are kept separate from the
**status** limits, because mixing them makes permanent boundaries read as temporary
inconveniences.

---

## The stack, layer by layer

| Layer | Examples | What it decides | What Reckn adds |
|---|---|---|---|
| **AI agent / LLM** | planner, negotiator, summariser, anomaly detector | *what to buy, from whom, at what price, and what "good" would look like* — and how to explain it afterwards | Reckn adds **nothing to this layer and takes nothing from it**. It never asks a model to judge. It takes the one step the parties agreed to fix in advance and settles on whether that step reproduced |
| **Agent payment protocol** | x402 (HTTP `402` + EIP-3009) | *how an authorisation reaches the chain* — gasless, pull-style, relayed by a facilitator | Reckn's optimistic escrow consumes the **same** EIP-3009 authorisation as its funding leg, so paying and opening a disputable escrow are one signature. **See the limitation below: this is on the optimistic path, not the keyless one** |
| **Payment chain — Tempo** | TIP-20 stablecoins; **no native gas token**, so fees are paid in a USD-denominated TIP-20 ([docs](https://tempo.xyz/developers/docs/protocol/tip20/spec)); receipts name `feeToken` and `feePayer` | *that the transfer is authorised and paid for, under the token's own policy* | Reckn puts the **release condition** on top: the same stablecoin funds the escrow and pays the fee that releases it. Measured on Moderato testnet — a settlement's fee was **0.155307 PathUSD** to release 1.000000 |
| **Payment chain — Arc** | Circle's USDC as the native gas token, with a 6-decimal ERC-20 face at a predeploy | *the same* | The escrow needs **no change** to hold either: a deal names its token at funding. The same escrow **source** is byte-identical on both chains, gated by `zk-verdict/scripts/tempo-arc-parity.sh` |
| **Wallet / access key / spending policy** | session keys, spend limits, allow-lists, AA policies | *whether this agent may spend, up to how much, on what* | Orthogonal and complementary. A policy decides **that a payment may happen**; Reckn decides **whether it is earned**. A spending limit cannot tell you the work was done |
| **Bridge / messaging** | lock-and-mint, relayers, cross-chain messages | *that value or a message moved between chains* | Reckn removes the bridge from the **trust root that authorises payment** — no bridge or relayer has authority to permit the release. **It does not remove bridges.** Moving funds to the chain you pay from is a separate problem and it remains |
| **Oracle / light client** | price feeds, header relays, state proofs | *what was true on some other system* | Reckn does **not** replace these and does not claim their guarantee. Its guest recomputes over the account set **the deal named**; that is consistency, not provenance |
| **Dispute resolution — the incumbents** | TEE attestation, bonded resolvers with challenge windows, quorum voting, platform arbitration | *who wins* — decided by an operator, a bonded party, or a vote | Every one of them contains **somebody holding a key**, and that somebody carries the liability for the decision. Reckn's escrow has no owner, admin, resolver, pause or upgrade path, and `scripts/no-keys.sh` fails the build if one appears |
| **Reckn** | `RecknZkEscrow` + a re-execution guest + an SP1 Groth16 proof | *whether the committed work, replayed against the committed prestate, satisfied the committed predicate* — and therefore whether the money goes to the seller or back to the buyer | — |

---

## What a standard would have to fix

Reckn is **building** the standard for proof-driven settlement across execution environments —
`building`, with no independent adoption yet; the exact strength of that claim and the three
things that would raise it are in [`messaging.md`](messaging.md). This table is the useful part
of the ambition: the five boundaries that would have to be common for anyone's escrow, on
anyone's chain, to settle on anyone's proof.

| boundary | what it fixes | where it stands here |
|---|---|---|
| **Deal Terms / Binding** | which work, over which inputs, under which predicate, for how much, by when — committed as 32 bytes before the work starts | **implemented.** `evm_deal_binding` and `svm_deal_binding`, each an independent transcription of its guest, checked byte for byte against a shipped fixture |
| **Verifier Profile** | which execution environment, which verifier, and which code hash a party is about to trust | **implemented.** Three ship with the kit; a profile is *discovery metadata, not a trust root* — `sellerPreflight` checks it against the chain, and the chain is what counts |
| **Proof Receipt** | which proof released or refunded which deal, readable without anyone's report of it | **implemented.** `SettledByProof` and `RefundedAfterDeadline` are separate events, so no one has to infer which kind of exit happened |
| **Permissionless Settlement** | that whoever submits the proof gets no discretion over the payout | **implemented, and enforced at build time.** `settleWithProof` takes no adjudicator argument and `scripts/no-keys.sh` fails the build if a key-holding path appears |
| **Provenance Adapter** | separating *the computation was correct* from *the inputs came from a real chain* | **open.** This is the unresolved one. A proof establishes re-execution over a **committed** prestate; it does not establish that the prestate was ever a live chain's. Anchoring needs a light client or an oracle **in addition**, and Reckn does not provide one |

The last row is the honest edge of the ambition. Four of these are things the repository does
today. The fifth is a boundary that has been *named* and not *fixed*, and calling the set a
standard while one of its members is open would be the kind of claim this project spends most of
its gates preventing.

---

## The two sentences that place it

> **AI chooses, negotiates, and explains. Re-execution decides the payout.**

> **Tempo lets an agent pay under policy. Reckn lets a high-stakes, reproducible job settle on
> evidence.**

Neither says the other layer is wrong or replaceable. An agent that cannot choose well is not
helped by a correct settlement, and a settlement nobody can dispute is not helped by a clever
plan. They compose.

### On AI specifically, since this is the easiest place to sound adversarial

Reckn is **not** anti-AI and does not treat a model as an opponent. The division is about what
each is good at:

- **The model** is good at open-ended judgement: choosing a counterparty, negotiating terms,
  summarising an outcome, noticing that something looks wrong.
- **Re-execution** is good at exactly one thing: answering *"did this specific computation,
  over this specific prior state, produce a result satisfying this specific condition?"* — the
  same way, every time, for anyone who runs it.

A model asked to adjudicate a payment can be persuaded by the text in front of it. That is not
a slur on models; it is what "reads the input" means. Reckn takes the narrow, checkable step
out of the model's hands and leaves it everything else.

---

## What Reckn is for, and what it is not for

**Reckn suits a job when all four hold.** Miss one and it is the wrong tool:

1. **Deterministic.** Replaying the same inputs gives the same result.
2. **Fixable in advance.** The prestate, the predicate and the plan can all be committed
   *before* the seller works — otherwise a dispute can be invented afterwards.
3. **Expressible as a post-state condition.** The escrow's predicate is a delta on one
   storage slot against a floor and a ceiling. "The recipient's balance of token T rose by at
   least X" is expressible. "The report was well written" is not.
4. **Worth the proof.** See the arithmetic below.

**Reckn does not suit:**

- **Subjective or open-ended output** — writing, design, analysis, "was this advice good".
  There is no honest predicate, and inventing one is worse than having none.
- **Low-value, high-frequency payments.** A proof has a floor cost that a $0.01 API call
  cannot carry. Those want a spending policy and a reputation system, not an adjudicator.
- **Anything needing provenance.** If the question is *"did this really happen on that
  chain"*, Reckn does not answer it — see the last section.
- **Every AI payment.** It is deliberately narrow. Most agent spending should never open a
  disputable escrow at all.

### The arithmetic, so you can disagree with it

| what | measured |
|---|---|
| settling a dispute on Arc | **0.0070 – 0.0077 USDC** of gas |
| settling one on Tempo | **0.155307 PathUSD** of fee, to release 1.000000 |
| generating the Groth16 proof, shipped fixture | **335 s** end to end |
| generating one for a **real mainnet Uniswap v3 swap** | **497 s**, 13,006,200 cycles, on a laptop CPU |

So the on-chain cost of deciding is cents, and the real cost is **proving time**, which is
minutes of compute per dispute. That sets the floor: a job worth a few dollars cannot justify
it; a job worth hundreds, or one where a wrong payment is a loss you would litigate, can.
**Reckn is for the tail of high-value, reproducible work — not for the volume.**

---

## Combining a model's judgement with a deterministic decision

The design that works is not "AI or proof". It is:

1. The **model** proposes the work and the terms, and both parties agree on **one step** of it
   that is deterministic and checkable.
2. That step's **prestate, plan and predicate** are committed at funding, as a single
   `dealBinding`. Neither side can move them afterwards.
3. The model does the rest of the job however it likes. **Reckn never sees it.**
4. If the parties disagree, the committed step is **replayed** and the proof decides. A model
   may still explain the outcome to a human; it has no authority over it.

The honest consequence: **Reckn only settles the part you were willing to fix in advance.** If
the valuable part of the job cannot be reduced to such a step, Reckn is not the answer for
that job, and saying so is more useful than stretching the predicate until it means nothing.

---

## Limits — design first, then status

**Design limits. None of these becomes true later.**

- **It does not remove bridges.** It removes them from the trust root that authorises payment.
  Getting the asset to the chain you pay on remains your problem.
- **It does not fix fragmented balances or cross-chain liquidity.** The buyer must already
  hold the settlement asset on the payment chain.
- **It does not prove provenance.** The guest recomputes over the account set the deal named.
  That the inputs came from a real chain is *not an input to the computation and therefore not
  a conclusion of it*. On EVM the tie from `state_root` to a block header lives in an
  **off-chain** layer; on Solana the guest recomputes a `bank_hash` over committed accounts.
  **"No bridge, no light client" describes the adjudication path, not the anchoring.**
- **A proof does not move assets between chains.** It decides a *local* payment.
- **The token can still stop a payout.** A stablecoin that can be paused or policy-gated can
  block a release a valid proof authorised — and on some chains it can block the timeout
  refund too. Disclosed, tested, not mitigated.

**Status limits. These stop being true when the world changes.**

- Deployments are **testnet**: Arc testnet and Tempo Moderato. No mainnet address exists.
- The **thirty-day timeout refund** has never been demonstrated on a public chain, because a
  public chain cannot be fast-forwarded. Where it appears, it is *scheduled*, not shown. **The
  refund on screen is always the proof-driven one** (`Failed` → buyer), which is immediate and
  is a different mechanism.
- **x402 funding is on the optimistic escrow, not the keyless one.** `RecknEscrow` consumes an
  EIP-3009 authorisation directly; `RecknZkEscrow` — the keyless path this page is about —
  takes a plain `approve` + `fund`. Wiring x402 into the keyless escrow would mean **adding a
  function to it**, which is a change to the central claim and is not on the table. Anyone
  reading "x402 + Reckn" should know which escrow they are getting.

---

## Provenance and adjudication are different questions

The most common misreading is that a proof here establishes *what was true on another chain*.
It does not, and the distinction is worth stating twice:

- **Adjudication** — *given these declared inputs, did this computation produce a result
  satisfying this condition?* Reckn answers this, with no resolver, no bridge and no light
  client on the path.
- **Provenance** — *were those declared inputs the real state of a real chain at a real
  block?* Reckn **does not** answer this. An account set we invented hashes just as well as a
  real one, and there is a test that says so.

A system that needs provenance needs a light client or an oracle **in addition**. Reckn does
not remove that requirement and does not pretend to.

---

## Where to go next

- **[`docs/chain-fit.md`](chain-fit.md)** — why Arc and why Tempo, and why the answer is a
  *different* property of each chain rather than the same sentence twice.
- **[`docs/partner-kit.md`](partner-kit.md)** — using Reckn from your own agent or service.
- **[`docs/integrate.md`](integrate.md)** — the raw contract surface, and the part that is not
  ready.
- **[`docs/why.md`](why.md)** — the two constraints this exists to remove, and what they cost.
- **[`docs/status.md`](status.md)** — `Known gaps (not closed)`, which is the section worth
  reading first if you are deciding whether to believe any of this.

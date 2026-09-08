# Why Reckn exists — the two constraints, what they cost, and what they save

Every number below is labelled **measured**, **cited**, or **unknown**. The unknown ones
are the interesting ones and are not estimated into looking better.

---

## 0. The first constraint: a person in the release path

**In a machine economy the first binding constraint is not the fee. It is human attention.**

An escrow that a person approves is a serialisation point: agents run continuously, in
parallel, at machine speed, and every release queues behind someone reading something. The
10–20% a platform charges is a *symptom* of that person existing. The ceiling is that you
cannot build an economy of software counterparties whose settlement path requires a human
to form an opinion.

The magnitude, from the one cited number available. x402 has processed **165 million
payments** across **69,000 active agents**
([Chainalysis](https://www.chainalysis.com/blog/x402-agentic-payments-adoption/)). Applying
the dispute rate card payments actually run at — **~0.5%**
([Chargebacks911](https://chargebacks911.com/chargeback-stats/)) — and assuming a human
needs somewhere between two and five minutes to read two conflicting accounts and decide:

| | |
|---|---|
| disputed payments | **825,000** |
| human decisions, at 2 min each | 27,500 hours = **14 person-years** |
| at 5 min each | 68,750 hours = **34 person-years** |

**This is derived, not measured**: the transaction count and the dispute rate are cited,
the minutes-per-decision is an assumption, and it is stated so you can move it. Halve it
and the conclusion does not change, because the shape is what matters — **transaction count
is the thing that grows and human attention is the thing that does not.**

And note where those numbers come from: payments averaging **$0.52**, which nobody would
staff a reviewer for. The argument only sharpens as agent work moves up in value into the
range where an escrow is actually wanted, because that is exactly where the human-approval
model is used today.

**What Reckn removes is not a fee. It is the person.** The release condition is fixed before
the work begins and evaluated by a computation both parties can run; nobody reads anything,
nobody approves anything, and there is no queue behind anybody. The cost sections below are
what that costs to do — but the reason to do it is above.

## 0.1 The second constraint: a bridge in the asset path — and why it is the same one

There is a second serialisation point, and it is easy to miss because it does not look like
a person. **In a multichain economy the money and the work are rarely on the same chain**, so
before anything can be judged the asset is moved to where the judging happens — bridged,
wrapped, or pooled. That movement is not a fee either. It is a second party inserted into the
payment: **a bridge, deciding whether the payment happens.**

Put the two side by side and they are the same defect:

| what stands between the work and the payment | what it is asked to decide | what it can actually see |
|---|---|---|
| a human approver, a TEE operator, a bonded resolver | *was the work done?* | a claim someone wrote |
| a bridge | *does the asset arrive?* | nothing about the work at all |

**Both put the payment in the hands of something that cannot see whether the work was done.**
One was told about it; the other was never asked. The first costs attention and the second
costs custody, and both cost the thing that matters more than either — the payment stops
being a function of the work.

The inversion is the whole product, and it is one sentence:

> **Do not move the asset to reach the work. Move a proof of the work to reach the asset.**
>
> ### Keep assets native. Settle on proof.

That is why removing the approver and keeping the asset native are not two features. They are
the same removal, applied to the two things that had crept into the payment path. §3.0 says
carefully what is actually done; §7 says what would falsify it.

**And the honest limit, before the arithmetic.** This does not mean assets never move. If you
owe money on a chain where you hold none, you still have to get it there. What is removed is
moving it **in order to be judged** — not moving it **in order to pay**. Reckn does not fix
fragmented balances and does not claim to.

---

## 1. The loss Reckn is aimed at, in the economy that already has this problem

Disputed payments are not a hypothetical cost; card payments have been paying it for
decades and it is well measured.

| | | |
|---|---|---|
| Global chargeback volume | **$33.79B (2025) → $41.69B (2028)** | cited — [Chargeflow](https://www.chargeflow.io/blog/chargeback-statistics-trends-costs-solutions) |
| All-in cost of ONE dispute to a merchant | **$110–128** against a $20–50 processor fee | cited — [ClearSale](https://en.clear.sale/blog/chargeback-fees-what-do-chargebacks-cost), [Mastercard](https://www.mastercard.com/us/en/news-and-trends/Insights/2025/what-s-the-true-cost-of-a-chargeback-in-2025.html) |
| Every $1 lost to a chargeback costs | **$5.13 all-in** | cited — LexisNexis True Cost of Fraud 2026 |
| Typical dispute rate | **~0.5%** of transactions (travel ~1.93%) | cited — [Chargebacks911](https://chargebacks911.com/chargeback-stats/) |

**The shape of that cost is the point.** A dispute costs $110–128 to resolve while the
processor's own fee is $20–50 — the rest is people, evidence-gathering, and time. It is
expensive because **somebody has to decide**, and deciding requires a human reading
conflicting stories.

## 2. Why it gets worse when the parties are software

Card disputes at least have a human on each side who can be asked what happened. Two
agents produce two assertions and no witness. Today's answers all reintroduce the thing
that costs $110: **a party who decides** — an operator inside an enclave, a bonded
resolver, a quorum of voters. Each is a per-chain deployment, a reputation to re-earn, and
something a counterparty can lean on.

## 3. What that market actually looks like right now — including the part that hurts us

| | | |
|---|---|---|
| x402 transactions | **165M**, ~**$50M** cumulative | cited — [Chainalysis](https://www.chainalysis.com/blog/x402-agentic-payments-adoption/) |
| **Average payment size** | **$0.52** | cited — same |
| Annualised across chains | **~$600M** | cited — [Presenc](https://presenc.ai/research/x402-protocol-adoption-tracker-2026) |
| Solana's share of x402 | **49%** | cited — same |

**The $0.52 is the number that constrains us, and pretending otherwise would be the
easiest lie in this document.** You cannot re-execute a fifty-cent API call under a zkVM
and come out ahead. Anyone who tells you their proof system makes every micro-payment
disputable is selling something.

**And Solana holding 49% of that volume is exactly why cross-VM settlement is not a stunt.**
The money and the work are already on different chains for half of this market.

### 3.0 What Reckn actually does, in one paragraph, said carefully

**A large delivery that would otherwise need an escrow is settled by re-executing it, and
the result of that re-execution IS the payout — there is no approval step.** Not "re-execute
and then approve": if anyone approved after seeing the result, that approver would be a key,
and the claim this project is built on would be dead. The proof's public values carry the
outcome, and the contract sends the money where the outcome says. Nothing decides in
between.

**It does not prevent disputes. It makes them not matter.** The seller can insist, the
buyer can deny, both can write at length — and the money moves the same way regardless.
Type sixty different claims into the live page and you get sixty hashes and one verdict.
That is a stronger property than prevention, and a more honest one: disagreement is not
abolished, it is made irrelevant to the outcome.

**And the terms are fixed before the work, not judged after it.** The buyer commits at
funding to a `dealBinding` — the agreed prestate, predicate and plan. What counts as
"reproduced" is settled before the seller starts. That is where the discretion goes: not
removed from a judge, but never created, because there is nothing left to interpret.

> **Closed 2026-09-07.** Until that day the tooling could not do this ordering: every script
> read `dealBinding` out of a proof fixture, so the proof existed *before* the funding — the
> reverse of the design, and the one thing standing between the paragraph above and someone
> else relying on it. `verdict_script::evm_deal_binding` now computes a binding from the
> agreed terms with no prover, and is checked against ground truth rather than review — it
> must reproduce, byte for byte, the value the guest committed inside SP1 in the shipped
> fixture. The demo scripts still take the fixture route and have not been rewired; the
> capability changed, not the demo. See [`integrate.md`](integrate.md).

### 3.1 A correction to an earlier draft of this page, because it was wrong

An earlier version of this document called Reckn *"the appeal court — invoked on the
fraction of payments where the delivery is contested"*. **That describes a product this
contract does not implement**, and the founder's question — *does Reckn prevent disputes by
re-executing automatically?* — is what exposed it.

`RecknZkEscrow` has three states: `None`, `Funded`, `Settled`. **There is no `Disputed`
state.** There is no dispute to open, no window to challenge in, and no escalation path,
because re-execution is not a remedy that a dispute triggers — **it is the settlement
mechanism itself.** Money reaches the seller through exactly one function,
`settleWithProof`, and that function requires a proof. Every time.

There is no cheap happy path, and **there cannot be one**: "the buyer voluntarily releases"
is a key moving a funded escrow, which is the one thing the whole design exists to make
impossible. The absence of a happy path is not an omission. It is the claim.

So the comparison set is not *all agent payments*. It is **the payments that would
otherwise need an escrow at all** — and nobody escrows a $0.52 API call either.

## 3.2 What those payments cost today

The thing Reckn replaces is not a chargeback desk. It is an escrow with an operator, and
those are priced as a **percentage**:

| | | |
|---|---|---|
| Upwork | **20%** on the first $500 with a client, **10%** to $10k, **5%** above — effectively 10–12% — plus **3–5%** from the client | cited — [Jobbers](https://www.jobbers.io/freelance-platform-fees-comparison-calculator-2026-the-complete-guide-to-maximizing-your-earnings/) |
| Fiverr | **20%** flat from the seller, **5.5%** from the buyer, and a **$2.50** surcharge under $75 | cited — same |

Fiverr's small-order surcharge is worth noticing: **the incumbents already concede that
below a threshold, mediated escrow does not pay for itself.** They charge a flat fee there
because a percentage of a small order does not cover the cost of standing behind it.

## 4. What it costs, measured on the real chain

| | | |
|---|---|---|
| **Settling a dispute on Arc** | **0.0070–0.0077 USDC** — verify a Groth16 proof and move the money | **measured** 2026-09-07, real gas price 22.17 gwei against the four live settlements (316,120–345,874 gas) |
| Re-executing an EVM delivery in-guest | 406,715 cycles | **measured**, `zk-verdict/cycles.json` |
| Re-executing a Solana delivery in-guest | 986,097 cycles | **measured** |
| Regenerating one proof end to end, locally | **335 s** (the gnark wrap alone is 31.71 s) | **measured**, one laptop, no GPU |
| **What a proof costs in dollars** | **UNKNOWN** | Succinct's network prices proofs by reverse auction in $PROVE; we have never bought one, we prove locally. Quoting a figure here would be inventing it. |

**The on-chain half is settled: under one cent.** Verifying a Groth16 proof and paying out
costs about 0.7 of a US cent on Arc, and it does not grow with the size of the dispute.

The proving half is the open variable, and it is the one an adopter has to price. What can
be said honestly: it is a fixed cost per dispute, it is bounded by the cycle counts above,
and it is falling fast industry-wide. What cannot be said honestly is a dollar figure we
have not paid.

## 5. The arithmetic, stated so you can disagree with it

Reckn charges a **fixed** cost per settlement where the alternative charges a
**percentage**. That is the whole shape of it:

> **fixed:** one proof + **$0.007**  ·  **percentage:** 10–20% of the amount

They cross where `0.10 × amount = proof + $0.007`. If a proof costs **$1**, that is about a
**$10** delivery; at **$5** a proof, about **$50**. Above the crossover the saving is not
marginal, it is structural — a $1,000 delivery pays **$100–200** to a platform today, and
would pay a proof plus two thirds of a cent here.

Three things follow, and the first one is a limit rather than a benefit:

1. **Below the crossover, do not use this.** Refund and move on. Fiverr reaches the same
   conclusion from the other side and charges a flat surcharge under $75.
2. **The comparison is not against zero.** It is against 10–20%, or against the $110–128 a
   *decided* dispute costs when a human has to read both stories.
3. **What neither figure prices is the operator.** A percentage buys you an arbiter who can
   be lobbied, subpoenaed, acquired, or simply wrong — and who has to be re-established on
   every chain. The fixed cost buys a computation that both parties can run themselves.
   That is the part that does not appear in any fee table.

## 6. What the user actually gets, and loses without it

**A seller agent** without Reckn either works unpaid on the buyer's say-so, or trusts an
arbiter the buyer chose. With it, the release condition is a computation it can run itself
before working — and it can check the deal's named verifier first, which is the one hazard
we did not close and say so everywhere.

**A buyer agent** without Reckn pays first and hopes, or funds an escrow whose operator can
be leaned on. With it, a wrong delivery refunds without asking anyone's permission, and a
seller who vanishes cannot lock the money forever — `refundAfterDeadline` returns it after
30 days, permissionlessly, and pays the caller nothing.

**A marketplace or rail** without Reckn must build a dispute desk — that is where the
$110–128 goes — and must rebuild it per chain. With it, the adjudicator is a computation,
so it is the same one everywhere and there is no desk to staff, no key to protect, and no
resolver to be subpoenaed.

## 7. What would falsify this

The honest version of a business case includes what would kill it:

- **If proving stays expensive**, the threshold in §5 sits above the value of most agent
  work and this is a niche for large deliveries only.
- **If disputes are rare enough**, nobody builds for them — but the 0.5% card rate and the
  $41.69B trajectory suggest otherwise once real value moves.
- **If a trusted arbiter is acceptable** to the parties, an optimistic escrow with a
  challenge window is cheaper and simpler, and one lives in this same repository. Reckn is
  worth its cost only where nobody will accept the other party's judge.

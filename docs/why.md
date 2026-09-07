# Who this is for, what it costs, and what it saves

Every number below is labelled **measured**, **cited**, or **unknown**. The unknown ones
are the interesting ones and are not estimated into looking better.

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

So Reckn is **not** a checkout. It is the **appeal court**: the thing you invoke on the
small fraction of payments where the delivery is contested and the amount is worth
arguing about. The 0.5% dispute rate above is the right order of magnitude for how often
it runs — and in the agent economy the disputed items are not the $0.52 API calls, they
are the compute jobs, data deliveries and execution mandates where one contested delivery
is worth more than the proof that settles it.

**And Solana holding 49% of that volume is exactly why cross-VM settlement is not a stunt.**
The money and the work are already on different chains for half of this market.

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

Re-execution is worth invoking when

> **disputed amount > (cost of one proof) + $0.007**

Everything on the right is fixed per dispute; the left side is not. That single inequality
is the whole business, and it says three things:

1. **Below some threshold, do not use this.** Refund the $0.52 and move on. Any system
   that claims otherwise is charging you more than the dispute is worth.
2. **Above it, the comparison is not against nothing — it is against $110–128.** That is
   what a decided dispute costs in the economy that already does this at scale. Even if a
   proof costs a few dollars, the resolution cost falls by an order of magnitude *and* the
   arbiter disappears.
3. **The saving that does not show up in either figure is the $5.13.** Every $1 lost to a
   chargeback costs $5.13 all-in because of the disputes that are never contested, the
   evidence never gathered, the customers written off. A verdict that anyone can reproduce
   from public inputs does not need to be argued for.

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

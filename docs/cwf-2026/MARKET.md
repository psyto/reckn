# The market, sized from the bottom up — including the number that argues against us

**Read 2026-09-12.** This page sizes the market Reckn is actually in. It does **not** contain a
top-down figure for "the AI agent economy", because that number would not be about Reckn: a
payment rail's total volume is not an adjudicator's market, and quoting one is the cheap version
of this page.

It also contains the arithmetic that does not flatter the product. **Today's agent-payment traffic
is structurally below Reckn's adjudication floor** — by a factor of about 578 at the middle
estimate — and the honest response to that is a segment statement, not a bigger TAM.

---

## 0. How to read the evidence here

Three tiers, marked inline, because they are not worth the same:

- **[fetched]** — the page was retrieved on 2026-09-12 and the words are quoted from it.
- **[search-only]** — the figure came back in a search result and the primary page **could not be
  fetched** (HTTP 403). It is carried as *unverified* and named as such. **Confirm before use in
  public copy.**
- **[unknown]** — nobody measured it, so it is a variable, not an estimate.

## 1. The method, and the quantity being sized

Reckn does not earn a share of payment volume. It decides **disputed or condition-bearing
payments**, one at a time. So the quantity is:

> **adjudications per year = (agent payments per year **above the economic floor**) × (the rate at
> which they are disputed or condition-bearing)**
>
> **value per adjudication = what the parties pay today to have a human decide the same question**

The floor comes from [`ECONOMICS.md`](ECONOMICS.md): **$115.53** at a dollar per proof and a 1 %
tolerance, **$15.53** if you prove it yourself, **$3.11** at the most generous corner. All three
inputs to the formula above are **[unknown]** today. §5 says how each one closes.

## 2. What agent payments actually look like right now

**[fetched]** Chainalysis, *Inside x402: 100M Agentic Payments on Base*, published 2026-06-03,
data through Q1 2026 — <https://www.chainalysis.com/blog/x402-agentic-payments-adoption/>:

> *"x402 agentic transactions on Base went from near-zero in mid 2025 to well over 100 million
> cumulative transactions through Q1 2026."*

> *"Transactions of $1+ now represent 95% of total volume transferred, up from 49% in early 2025."*

**[fetched]** CoinDesk, 2026-03-11, on a February 2026 snapshot —
<https://www.coindesk.com/markets/2026/03/11/coinbase-backed-ai-payments-protocol-wants-to-fix-micropayment-but-demand-is-just-not-there-yet>:

> *"about 131,000 transactions generating roughly $28,000 in volume"* — **an average payment worth
> around $0.20** — and *"roughly half of observed x402 transactions reflect artificial activity"*.
> Ecosystem valuation *"around $7 billion"*, which the article itself notes is inflated by
> including Chainlink's $6.3 billion market cap.

**Two readings, and both are true.** The count is dominated by sub-dollar calls that are partly
synthetic. The *value* has been migrating upward fast — 49 % → 95 % of transferred volume in
payments of $1 or more, in about a year.

## 3. The arithmetic that argues against us

| | |
|---|---|
| average agent payment today **[fetched]** | **$0.20** |
| Reckn's floor, middle estimate ([`ECONOMICS.md`](ECONOMICS.md)) | **$115.53** |
| ratio | **≈ 578 ×** |
| ratio at the most generous corner ($3.11, self-proved, 5 % tolerance) | **≈ 15.5 ×** |

**Even the corner case is fifteen times above the average agent payment.** So:

> **Reckn is not for today's agentic traffic.** A $0.20 API call cannot pay $0.155 to be
> adjudicated, and nobody should want it to.

Saying that plainly costs nothing and buys the only thing worth having here — the next sentence is
a segment, and a segment can be checked:

> **Reckn is for the agent payments that are already worth arguing about**: the ones where the
> parties would otherwise pay a human to decide, and where the amount makes a $0.155 on-chain
> decision plus a proof look cheap. **The floor is the segmentation**, and it is measured rather
> than asserted.

## 4. Where adjudication is already priced — the market that exists today

The demand this product addresses is not hypothetical; it is currently served by **people**, and
people are expensive. Two priced examples:

**[fetched] Card networks — disputes are priced *and rationed*.** From Stripe's documentation of
the networks' monitoring programmes, <https://docs.stripe.com/disputes/monitoring-programs>:

| programme | threshold | consequence |
|---|---|---|
| Visa **VAMP** | ratio **0.5 %** non-compliant · **1.5 %** excessive (2.2 % CEMEA); counts 5 · 1,500 | fees assessed above *Excessive*, and possibly above *Non-Compliant* |
| Mastercard **ECM** | **100–299** chargebacks **and 1.5–2.99 %** | fines from **$1,000** (months 2–3) rising to **$100,000**/month |
| Mastercard **HECM** | **300+ and 3 %** | fines rising to **$200,000**/month |
| issuer recovery | beyond **300** chargebacks | **$5 per chargeback**, on top |

**What this is evidence of**, and the reason it is on this page: the payments industry treats a
dispute rate of roughly **0.5 %–3 %** as the boundary between normal and pathological, and prices
each additional dispute at real money. **That band is the closest thing to a measured dispute rate
this page can offer** — for cards, not for agents, and the difference is not decoration.

**[search-only — primary page returned HTTP 403 twice on 2026-09-12; unverified] Marketplace
arbitration.** Search results for Upwork's dispute process report that **mediation is free**,
that **arbitration costs about $337.50 per side** for claims under $20,000, that each party has
seven days to agree and pay, and that **if one party pays and the other does not, the funds go to
the party who paid**. Sources seen: `support.upwork.com/hc/en-us/articles/14044146250259` and
`upwork.com/resources/upwork-dispute-process` — **neither could be fetched. Confirm both figures
against Upwork's own page before any public use.**

*If* that figure is right, the comparison is the sharpest number in this document — hundreds of
dollars per side, and an outcome that can be decided by which party can afford the fee — against
**0.155307 measured** and symmetric to 2.3 %. **It is also the figure most likely to be wrong,
which is why it is fenced.**

**Escrow services**: `escrow.com/fees` returned **404** on 2026-09-12. No figure is quoted here.

## 5. The three unknowns, and how each one closes

| unknown | what closes it | who |
|---|---|---|
| **how many agent payments are above the floor** | the $1+ share is public and rising (§2); what is missing is the distribution *above $100*. A public x402 / Base dataset query would answer it directly | measurable without permission — the data is on chain |
| **the rate at which agent payments are disputed** | nobody can answer this yet, because agent commerce has barely produced disputes. The card band (0.5–3 %) is an **analogy**, not a measurement, and must be labelled as one | needs a real marketplace's data, or time |
| **the price of a proof (P)** | a prover network's published price. Until then the floor is a range, not a number ([`ECONOMICS.md`](ECONOMICS.md) §2) | external |

**The most useful next measurement is the first one**, and it needs no partner and no permission:
count on-chain agent payments above $100. That single query turns the segment statement in §3 from
a claim into a size.

## 6. What must never be said

- ❌ **A top-down TAM.** Not "the agent economy will be $X trillion, and Reckn addresses it."
  Reckn's market is adjudications, not payment volume, and the two differ by orders of magnitude.
- ❌ **x402's cumulative figures as Reckn's market.** 100 million transactions at an average of
  $0.20 is a market Reckn is explicitly *not* for (§3).
- ❌ **The $7 billion "ecosystem valuation."** The article that reports it says it is inflated by a
  single unrelated market cap. Quoting it would be quoting a number against its own source.
- ❌ **The Upwork figure without the fence.** It is unverified (§4).
- ❌ **The card dispute band as an agent dispute rate.** It is an analogy from a different market
  and must carry that label every time.
- ❌ **Any sentence implying revenue, pricing or take-rate.** This repository has none of those, and
  this page does not invent one.

---

**Where this is used:** the *Potential Market Size* answer in [`PREFLIGHT.md`](PREFLIGHT.md) §6,
alongside [`ECONOMICS.md`](ECONOMICS.md) for *Viability*. Traction is a separate row and neither
page closes it.

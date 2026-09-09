# Why Arc, why Tempo — and why the answer is different each time

Reckn's principle does not change per chain: **keep assets native, settle on proof.** What
changes is *which property of the settlement chain the principle gets to use*. Naming two
sponsors and claiming both are a good fit is the cheap version of this page. This one names the
load-bearing property in each case, and links to the receipt that shows it.

Nothing here is claimed about mainnet on either chain, and nothing here claims a proof
establishes Solana **provenance** — see [§ What neither of them fixes](#what-neither-of-them-fixes).

---

## The two, side by side

| | **Arc × Solana** | **Tempo × Solana** |
|---|---|---|
| where the asset stays | **USDC on Arc** | **a TIP-20 on Tempo** (PathUSD) |
| where the work happens | Solana | Solana |
| what the proof does | decides **release / refund of local USDC on Arc** | decides **release / refund of a local TIP-20 on Tempo** |
| why *that* settlement chain | a **stablecoin-native payment rail** where a conditional payment can settle **without bridging the asset** | the settlement asset **and the fee that decides it** are the **same stablecoin unit** |
| what is proven, on chain | 4 settlements, **2 of them decided by proofs about work performed on Solana** | a release and a refund, **both fees paid in the token the escrow held** |
| what is still open | Arc **testnet**; Solana provenance unresolved | **testnet**; a TIP-20 issuer's **pause / policy** can stop a proof-authorised release **and** the timeout refund |

The rows differ because the chains differ. If the same sentence fitted both, one of them would
be decoration.

---

## Arc × Solana — the dollar never leaves

**Arc is not a deployment target here. It is where the money lives and stays.**

The work happens on Solana. The USDC does not go to Solana to be judged, and it does not come
back. It sits in a local escrow on Arc for the whole story, and the only thing that crosses the
boundary is a Groth16 proof about a re-executed Solana computation. That proof does not move
value; it decides where local value goes.

**What made Arc usable without widening the contract.** `RecknZkEscrow` takes the payment token
as an argument to `fund()`, so a chain whose money is USDC needed *evidence*, not adaptation. On
Arc, USDC is the **native gas token** (18 decimals) and Circle exposes an **ERC-20 face over the
same balance** at the predeploy `0x3600000000000000000000000000000000000000`, whose face is **6
decimals**. The escrow holds that face. No `payable` path was added — adding one would have
extended the function surface, which is the one thing `AGENTS.md` §0 forbids.

**The receipts.** Escrow `0x580f2c3268b0a13bf46c6d381bf807cbf1595669` on Arc testnet, four
settlements in real testnet USDC, recorded in
[`zk-verdict/contracts/arc.json`](../zk-verdict/contracts/arc.json):

| settlement | what decided it | gas |
|---|---|---|
| `reproduced` | an EVM proof that the work reproduced → seller | 345,874 |
| `failed` | a proof that it did **not** → buyer | — |
| **`solanaProofOnArc`** | **a proof about work performed on Solana** → seller | 320,600 |
| **`solanaFailureOnArc`** | **a Solana proof of a below-floor result** → buyer | 316,120 |

Your own browser can read them: **[the live page](https://psyto.github.io/reckn/)** compares the
deployed bytecode against this source and pulls the four receipts off Arc.

**Not claimed.** Arc **mainnet** is not deployed — Circle had not published Arc mainnet contract
addresses as of 2026-09-06, and the same script deploys there unchanged once that list exists.
One further deal is frozen at 1.00 USDC because Circle's USDC blacklists its recipient; it is
refundable by the keyless deadline and by nothing else, and it is recorded rather than hidden.

---

## Tempo × Solana — the payment and the cost of deciding it are the same unit

**Tempo is not a second EVM to redeploy onto.** If that were the whole story it would be worth a
line in a changelog, not a page.

**Tempo has no native gas token.** Transaction fees are paid in a USD-denominated TIP-20
stablecoin. So on Tempo, and not on Arc, this sentence is true:

> **The escrow holds a stablecoin, and the fee that releases it is paid in that same
> stablecoin.**

The payment and the cost of *deciding* the payment are denominated in one unit. On Arc that is
false — USDC is the 18-decimal native gas token and the escrow holds a separate 6-decimal ERC-20
face of it. On a chain with a separate gas asset it is false by construction.

**The receipts.** Escrow `0x7e953a6ac16744ef1a02e343277ec55d7410f439` on Tempo Moderato testnet
(chain 42431), funded with **PathUSD** `0x20C0000000000000000000000000000000000000` — a real
TIP-20, not a mock. Explorer-linked hashes are in
[`docs/specs/011-tempo-tip20-slice.md`](specs/011-tempo-tip20-slice.md) §10; the record is
[`zk-verdict/contracts/tempo.json`](../zk-verdict/contracts/tempo.json).

| | |
|---|---|
| release, on a Solana `Reproduced` proof | `0xeb53bc37…0b99f` |
| refund, on a `Failed` proof | `0x97b65755…cf157` |
| **`feeToken` on both receipts** | **`0x20c0…0000` — the token the escrow was holding** |

That last row is the whole argument, and it is read off the receipt rather than asserted.

**Same source, two chains — and not the same behaviour.** The escrow source is byte-identical on
both, and that is *gated*: `zk-verdict/scripts/tempo-arc-parity.sh`. It is a claim about the
**source**. It is **not** a claim that the two chains adjudicate alike — the adjudicator is named
per deal by the funder, the fee models differ, and the token behaves differently, which is the
next section.

**The limit Tempo adds, stated because hiding it would be the tell.** A TIP-20 issuer can
**pause** the token, and a **TIP-403 policy** can refuse a recipient. A pause stops a payout that
a valid proof authorised — **and it stops the thirty-day refund too**. So on Tempo there is a
state in which *both* exits are closed by a third party. That reaches further than Arc's USDC
blacklist, which froze one named address and left the timeout open.

**Reckn removes a protocol-level judge. It does not erase issuer policy.** Anyone who tells you
otherwise is selling something.

**Not claimed.** Tempo **mainnet** is not deployed. Nothing here is offered as ETHOnline event
work — that submission stands on Arc, and the boundary is
[`docs/ethonline-2026/PREFLIGHT.md`](ethonline-2026/PREFLIGHT.md) §2.

---

## What neither of them fixes

Two limits belong to **Reckn**, not to a chain, and they do not become true later:

- **Provenance is not proven.** The guest recomputes a `bank_hash` over the account set **the
  deal named**. That is *consistency*, not provenance: it does **not** establish that those
  inputs came from Solana mainnet. Both chains inherit this equally.
- **Bridges are not made unnecessary.** What is removed is the bridge's place in the **trust root
  that authorises payment** — no bridge and no relayer has the authority to permit the payment.
  Moving funds to a chain you want to pay from remains your problem, and Reckn does not fix
  fragmented liquidity.

And one that belongs to **time**: the thirty-day `refundAfterDeadline` has never been
demonstrated on a public chain and cannot be inside any event, because a public chain cannot be
fast-forwarded. Every refund you will see demonstrated is the **proof-driven** one, which is
immediate and is a different thing.

---

## Where to go next

- [`positioning.md`](positioning.md) — which layer decides what, and why AI, x402, Tempo and Arc
  are complements rather than competitors
- [`partner-kit.md`](partner-kit.md) — opening a deal from your own code, with your own wallet
- [`messaging.md`](messaging.md) — the wording this project holds itself to, including the
  claims it refuses to make

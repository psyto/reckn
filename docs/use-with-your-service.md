# Using Reckn with your service

Reckn decides one thing, and it decides it without anyone's permission: **whether the work a
deal was funded against actually happened.** Not by asking a model, not by asking us — by
re-executing the work and checking the result.

This page is what you need to wire that into your own service: what it can decide, the two
calls, and what you bring to it.

---

## 1. What it decides — so you can tell in a minute whether it fits

The re-execution guest (`zk-verdict/program-revm/src/main.rs`) does exactly this:

> Verify a committed pre-state against its state root. Execute **one committed call** against
> that state under a committed EVM environment. Read the post-state. Decide whether **one
> storage slot rose by at least `min`**.

`reckn terms` exposes precisely that — `--check-token`, `--check-holder`, `--min`,
`--slot-index` — which in practice reads as *"this holder's balance must go up by at least this
much."*

That is a sharp instrument rather than a general one, which is the point: **it is narrow because
it is unarguable.** A re-execution can only decide what is recomputable from committed inputs,
and that is exactly the class of claim no judge is needed for.

**It fits when the result of the work is a number that has to move:**

| your agent's job | |
|---|---|
| Execute a swap and return at least 246.00 USDC | ✅ a balance rising past a floor |
| Liquidate a position and return the proceeds | ✅ if the proceeds are a token balance |
| Route a payment and prove it landed | ✅ |
| Fill an order at or better than a limit | ✅ |
| Rebalance to a target allocation | not yet — the outcome is a shape, not one number rising |
| Write a report, summarise a document, answer a question | not this tool — nothing on chain moves |
| "Did the agent follow its instructions?" | by design, no — that is a judgement, and this is the layer that removes judges |

If your work is in the top group, everything below is about an afternoon's integration. If it is
in the bottom group, the predicate does not reach it today — worth knowing in a minute rather
than a week.

---

## 2. Which side are you?

**Buyer** — your agent pays another party. You lock the money and name the terms. **You never
touch a proof**; the seller brings it, and you can walk away until it settles.

**Seller** — your agent does the work and wants paying. You check what you are taking on, do it,
then produce the proof (§4).

Most integrations are one or the other, not both.

---

## 3. The integration

### The surface is two calls

```solidity
fund(bytes32 dealId, address seller, address token, uint256 amount,
     address verifier, bytes32 verifierCodeHash, bytes32 dealBinding)
settleWithProof(bytes32 dealId, bytes publicValues, bytes proof)
```

`settleWithProof` is **permissionless** — the key that pays the gas has no bearing on where the
money goes. So there is no step here where you grant us a permission, create an account, or hold
a credential. There is nothing to grant, and `scripts/no-keys.sh` enforces that as a build
condition: a version of this contract with an admin path does not compile.

A third call, `refundAfterDeadline(bytes32)`, returns the money to the buyer after thirty days.
It is the only exit that needs no proof.

### Buyer side

```ts
import { buildTerms, createDeal, verifySettlement } from "@reckn/partner-kit";
```

1. **Turn the transaction you want into terms.** `buildTerms` (or the `reckn terms` CLI) takes
   the call you expect, anchors it to a block, attaches the predicate, and returns the
   `dealBinding` — one commitment covering the pre-state, the plan and the condition. After
   this, neither side can move any of them.

   It also **refuses five kinds of terms** that would open cleanly and then never settle —
   including a floor of zero, which is met by doing nothing and would pay the seller in full for
   no work. Those refusals are the tool doing your review for you.

   **You can compute the binding yourself, with no prover.** `evm_deal_binding`
   (`zk-verdict/script/src/lib.rs`, landed 2026-09-07) takes the terms and returns the same
   32 bytes the guest will commit to inside SP1 — which is what makes the ordering possible at
   all, because the buyer has to commit *before* the seller starts. It is a second, independent
   transcription of the guest's computation rather than a shared implementation: two
   transcriptions make an error show up as a *mismatch*, where one shared implementation makes
   the same error show up as agreement. It is checked byte for byte against the shipped fixture,
   and dropping a single field from the preimage makes that test fail.
   [`integrate.md` § Computing `DEAL_BINDING` yourself](integrate.md) is the code.

   > The README claimed the opposite until 2026-09-09 — that a binding "is still computed only
   > in-guest, so today you can settle against a binding but not compute one before the work."
   > That was false from 09-07 onward and contradicted the page it linked to. No check covered
   > the sentence, so nothing turned red for two days.

2. **Fund.** `createDeal` sends `fund` with that binding. From this moment there is no key that
   can move the money — not yours, not the seller's, not ours.

3. **Do nothing.** That is the whole point. Either a proof releases it or the deadline returns
   it.

4. **Read the outcome from the chain.** `verifySettlement` decodes what happened rather than
   reporting what we say happened, and it tells **a payout a proof authorised**
   (`SettledByProof`) apart from **the timeout refund** (`RefundedAfterDeadline`) — separate
   events, so nobody has to infer which kind it was.

### Seller side

```ts
import { sellerPreflight, submitProof } from "@reckn/partner-kit";
```

1. **`sellerPreflight`, before you start work.** It reads the chain and tells you the buyer, the
   amount, the deadline, whether the verifier's code still hashes to what the deal pinned, and
   whether the token will actually pay you — it probes for a paused token and a blocked
   recipient. Worth running every time: a buyer is free to name a verifier that always fails,
   and this is what catches that before you spend the compute.

2. **Do the work** — the exact call the terms committed to. A different call carries a different
   binding and is rejected.

3. **Produce the proof** (§4).

4. **`submitProof`** with the `publicValues` and `proofBytes`. Anyone can send this transaction;
   it does not have to be you, and it does not have to be soon.

---

## 4. What you bring

**A prover, if you are the seller.** `submitProof` takes a proof as an input — the kit does not
make one. Producing one needs the SP1 toolchain and minutes of CPU. Measured on one laptop, no
prover network: **335 s** for the shipped fixture, and **497 s** for a real mainnet Uniswap v3
swap — 32x the cycles for 1.49x the time, so the cost grows far slower than the work does.
Buyers need none of this; sellers should plan for it.

**An RPC that answers two methods.** `reckn terms` needs `eth_createAccessList` (to simulate)
and `eth_getProof` (to capture the witness). Measured 2026-09-09:

| endpoint | `eth_createAccessList` | `eth_getProof` | `reckn terms` |
|---|---|---|---|
| `rpc.moderato.tempo.xyz` | yes | yes | works |
| `rpc.testnet.arc.io` | no | no | cannot build terms |

This is about the endpoint, not the chain or your transaction. Even on a limited one you can
**compute a binding and fund against it** — that needs a single `eth_getBlockByNumber`. What you
cannot do there is simulate the call or capture the witness, so point `terms` at an endpoint
that answers.

**A clone, not an npm install.** `reckn` and `@reckn/partner-kit` are not published (checked
2026-09-09), so you install by cloning and `npx reckn` resolves inside that tree.

**First-mover's patience.** No integration outside this project exists yet. The API is tested
and documented, and you would be the first person to find out where the documentation is thinner
than the code. If you hit that, the failure is the most useful thing you could send us — and it
is the fastest way to get the surface shaped around a real second user.

---

## 5. Start where it costs nothing

Before writing anything against the API, watch it work end to end on a throwaway chain:

```bash
git clone https://github.com/psyto/reckn && cd reckn/packages/partner-kit
npm install && npm run build
cd examples/starter && npm install
npm run demo:local
```

Three paths, no wallet, no funds, no key of yours: a release, a refund, and a **real** proof of a
*different* job being refused. That third one is the whole system in miniature — a valid proof
that cannot take the money — and it is the quickest way to see whether §1 matches what your agent
does.

> **Status, 2026-09-09.** The starter's build path changed at 12:13 that day (an install hook
> became an explicit build) and this command has not been re-run since on a still tree — an
> acceptance gate was mutating the contracts at the time. This note will say "re-verified" or it
> will say what broke.

---

## Where to go next

- [`integrate.md`](integrate.md) — the contract surface in about a page, including computing a
  `dealBinding` yourself, before any work happens
- [`partner-kit.md`](partner-kit.md) — the package in detail: the five refusals, the profiles,
  and the endpoint requirements
- [`status.md`](status.md) — `Known gaps (not closed)`, if you would rather read the limits in
  one place

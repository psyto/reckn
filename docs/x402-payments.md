# x402 / EIP-3009 payments in Reckn

Reckn's funding leg is the **same on-chain primitive x402 settles with**, so a buyer
agent's x402 payment lands *directly* as escrow funding — no separate deposit step,
no custody hop. This document maps the two precisely and states honestly what is
implemented versus what is a thin, swappable adapter.

## What x402 is (one paragraph)

x402 is an HTTP-native payment protocol for agents: a server answers a request with
`402 Payment Required` and a payment offer; the client agent returns a signed
**payment payload**; a facilitator submits it, and the on-chain settlement leg is an
**EIP-3009 authorization** (`transferWithAuthorization` / `receiveWithAuthorization`)
— a gasless, pull-style transfer the payer signs off-chain and anyone can submit.
The signature *is* the payment; no prior approval or deposit is needed.

## The mapping

The buyer agent's x402 payment authorization is consumed **as the escrow funding
transaction itself**:

```
x402:   402 offer  ->  buyer agent signs EIP-3009 authorization  ->  facilitator submits
Reckn:                 the SAME authorization  ------------------->  RecknEscrow.fundWithAuthorization(...)
                                                                     -> receiveWithAuthorization(USDC)  [pulls funds into escrow]
                                                                     -> deal bound to (specHash, prestateAnchorHash, backendId)
                                                                     -> state = Held
```

`RecknEscrow.fundWithAuthorization` takes the buyer (`from`) plus the EIP-3009 fields
(`validAfter`, `validBefore`, `authNonce`, `v/r/s`) and calls
`IUSDC3009(paymentToken).receiveWithAuthorization(...)` — the exact call an x402
facilitator makes to settle — but instead of a plain transfer it lands the value in
the escrow and atomically binds the deal to the re-executable predicate. One signed
authorization both *pays* and *opens the disputable escrow*.

- **The buyer signs; anyone submits.** `from` (the buyer) is an explicit parameter
  distinct from `msg.sender`, and `receiveWithAuthorization`'s "receive" variant only
  requires the payee (`to`) to be the caller. So a third-party **facilitator** relays
  the buyer's signed authorization on-chain — the gasless, pull-style property x402
  depends on — while the token, not the escrow, proves the buyer authorized the pull.
- **One signature binds the terms, not just the payment.** The `authNonce` the buyer
  signs is required to equal `fundingNonce(dealId, deliverWindow, requiredSellerBond)`
  — a hash that commits (via `dealId`) to seller, token, amount, spec, anchor, and
  backend, plus the deliver window and the optional **seller data-availability bond**
  (so a relayer cannot weaken or drop the bond the buyer chose). A
  relayer that alters *any* funded term recomputes a different expected nonce, so the
  transaction reverts either on the escrow's `BadNonce` check or, if the relayer forges
  a matching nonce, on the token's signature check (the buyer never signed that
  authorization). Relaying is therefore tamper-evident: the facilitator holds no
  discretion over who gets paid or what the deal is.
- No `approve` + `transferFrom` dance, no deposit step: the x402 payment and the
  escrow open are a single signed authorization.
- `to` is fixed to the escrow contract, so a stray authorization cannot be redirected.
- The `authNonce` is the EIP-3009 nonce; cross-deal replay is impossible (the nonce is
  1:1 with the deal) and same-deal replay is rejected by both the escrow (`DealExists`)
  and the token's per-authorizer nonce set.

## Implemented vs adapter (honest split)

- **Implemented — the settlement leg that matters for trust.** The escrow consumes a
  **verified** EIP-3009 `receiveWithAuthorization`: the buyer's off-chain EIP-712
  signature is checked against the token's domain and the `ReceiveWithAuthorization`
  typehash, with `validAfter`/`validBefore` window and per-authorizer nonce enforced
  (see `contracts/src/RecknEscrow.sol`, `contracts/src/interfaces/IUSDC3009.sol`, and
  `contracts/test/mocks/MockUSDC3009.sol`, which verifies signatures the way USDC's
  FiatTokenV2 does). `scripts/anvil-e2e.sh` funds end-to-end by having the buyer sign a
  real authorization that a **separate facilitator account** relays — proving the
  relay path, not just the accounting. Covered by the escrow test suite:
  facilitator-relays-buyer-signature, tampered-term (nonce) and tampered-amount
  (signature) rejection, wrong-signer, and expired-authorization.
- **Adapter — the HTTP handshake.** The `402` response, the payment-offer negotiation,
  and the transport that carries the signed payload to the facilitator are **off-chain
  plumbing**. They are a thin, swappable adapter in front of `fundWithAuthorization`,
  deliberately out of the trust core: they choose *how the authorization arrives*,
  never *how a dispute is decided*.

## Why this is rail-agnostic

The adjudicator (re-execution) **never sees the payment**. Funding via x402 / EIP-3009
on EVM, via a Token-2022 transfer on Solana (`escrow-svm`), or via any future rail is
orthogonal to the verdict: the dispute is decided by replaying committed work against a
committed prestate. So x402 is a *supported funding target*, not a dependency — the
same reason Circle Arc is one settlement target and not the bet. See the README
*Positioning* section: one re-execution engine, any chain, any rail.

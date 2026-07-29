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

`RecknEscrow.fundWithAuthorization` takes the EIP-3009 fields (`validAfter`,
`validBefore`, `authNonce`, `v/r/s`) and calls
`IUSDC3009(paymentToken).receiveWithAuthorization(...)` — the exact call an x402
facilitator makes to settle — but instead of a plain transfer it lands the value in
the escrow and atomically binds the deal to the re-executable predicate. One signed
authorization both *pays* and *opens the disputable escrow*.

- No `approve` + `transferFrom` dance, no deposit step: the x402 payment and the
  escrow open are a single signed authorization.
- `to` is fixed to the escrow contract, so a stray authorization cannot be redirected.
- The `authNonce` is the EIP-3009 nonce; replay is rejected by the token.

## Implemented vs adapter (honest split)

- **Implemented — the settlement leg that matters for trust.** The escrow consumes a
  real EIP-3009 `receiveWithAuthorization` (see `contracts/src/RecknEscrow.sol`,
  `contracts/src/interfaces/IUSDC3009.sol`, and the mock USDC exercised end-to-end by
  `scripts/anvil-e2e.sh`). This is the on-chain half x402 relies on.
- **Adapter — the HTTP handshake.** The `402` response, the payment-offer negotiation,
  and the facilitator that relays the signed payload are **off-chain plumbing**. They
  are a thin, swappable adapter in front of `fundWithAuthorization`, deliberately out
  of the trust core: they choose *how the authorization arrives*, never *how a dispute
  is decided*.

## Why this is rail-agnostic

The adjudicator (re-execution) **never sees the payment**. Funding via x402 / EIP-3009
on EVM, via a Token-2022 transfer on Solana (`escrow-svm`), or via any future rail is
orthogonal to the verdict: the dispute is decided by replaying committed work against a
committed prestate. So x402 is a *supported funding target*, not a dependency — the
same reason Circle Arc is one settlement target and not the bet. See the README
*Positioning* section: one re-execution engine, any chain, any rail.

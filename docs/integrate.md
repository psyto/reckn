# Contract reference — `fund`, `settleWithProof`, and the binding

> **This is the reference, not the guide.** If you are working out *how to adopt Reckn*, start
> with **[`use-with-your-service.md`](use-with-your-service.md)** — what it can decide, which
> side you are on, and the path through the TypeScript package. This page is the raw surface
> underneath all of that: `cast`, a private key on the command line, and a seven-argument ABI
> call. It is the honest description of the protocol and a poor way to adopt it.

Two calls. The whole protocol surface a payer touches is `fund`, and the whole surface a
settler touches is `settleWithProof` — which anyone may call, because the proof carries the
authority and there is no signer to be.

This page is short on purpose, and it ends with **the part that is genuinely not ready**,
because a page like this that only lists the easy half is a sales page.

---

## Fund a deal

```bash
ESCROW=0x580f2c3268b0a13bf46c6d381bf807cbf1595669      # Arc testnet
USDC=0x3600000000000000000000000000000000000000        # Circle's ERC-20 face, 6 decimals

cast send "$USDC"   "approve(address,uint256)" "$ESCROW" 250000000 --rpc-url "$RPC" --private-key "$BUYER"
cast send "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
  "$DEAL_ID" "$SELLER" "$USDC" 250000000 "$VERIFIER" "$VERIFIER_CODEHASH" "$DEAL_BINDING" \
  --rpc-url "$RPC" --private-key "$BUYER"
```

Seven arguments, and only two of them need explaining.

**`VERIFIER` — you choose your own adjudicator, per deal.** It is pinned by
`VERIFIER_CODEHASH` at funding and re-checked at settlement, so the address cannot become
different code in between. Get it with `cast codehash "$VERIFIER"`.

> This is a real power and a real hazard, and the contract says so in its own comments: a
> buyer who names a verifier that always returns `Failed` makes the seller work for
> nothing, and on-chain that is indistinguishable from an honest failure. **A seller must
> read the deal's `verifier` before working.** We are not going to pretend otherwise on an
> integration page.

**`DEAL_BINDING` — a commitment to the prestate, the predicate and the plan.** It is what
makes the escrow sound: a proof of some *other* favourable execution carries a different
binding and reverts with `BindingMismatch()`. See below for how you get it, which is the
honest problem.

## Settle it

```bash
cast send "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$DEAL_ID" "$PUBVALS" "$PROOF" \
  --rpc-url "$RPC" --private-key "$ANYONE"
```

`ANYONE` is not a figure of speech. There is no allow-list and no `onlyOwner`; the key
paying gas has no bearing on where the money goes. `Reproduced` releases to the seller,
`Failed` refunds the buyer, and both are decided by the public values the proof commits to.

If no proof ever arrives, `refundAfterDeadline(dealId)` returns the money to the buyer 30
days after funding. Also permissionless, and calling it pays the caller nothing.

## Run the whole thing in one command, with no key and no funds

```bash
bash scripts/arc-usdc-e2e.sh      # local anvil at Arc's chain id: deploy, fund, settle, refund
```

---

## Computing `DEAL_BINDING` yourself

This is the part that was missing until 2026-09-07, and it is the reason the ordering
above works at all: a buyer has to commit to the terms **before** the seller does the work,
which means computing the binding **without a proof**.

```rust
use verdict_script::{evm_deal_binding, to_guest_input};

// the terms you and the seller agreed: the prestate you both anchor to, the plan you
// expect to be executed, and the predicate that decides "reproduced".
let input   = to_guest_input(&anchor, &witness, &plan, &predicate)?;
let binding = evm_deal_binding(&input);          // -> [u8; 32], no prover involved
```

That value is what goes into `fund`. When the seller's work is later proved, the guest
computes the same commitment inside SP1 and `settleWithProof` requires the two to be equal
— a proof of some other, more favourable execution carries a different binding and reverts.

**Why this is a second implementation and not a shared one.** `evm_deal_binding` is
transcribed from the guest rather than imported from it, exactly as `svm_deal_binding` is.
Two independent transcriptions make an error surface as a *mismatch*; one shared
implementation makes the same error surface as agreement, which is indistinguishable from
correctness. It is checked against ground truth rather than against review:
`zk-verdict/script/tests/evm_binding.rs` requires it to reproduce, byte for byte, the
`deal_binding` the guest committed inside SP1 in the shipped fixture — and dropping a
single field from the preimage makes that test fail.

## What is not ready, stated plainly

**The demo scripts still take the old route.** `arc-usdc-e2e.sh` and the recorded demo
read `deal_binding` out of a fixture with `jq`, because they were written before
`evm_deal_binding` existed and rewiring them days before a freeze buys nothing a judge can
see while risking gates that currently pass. **The capability is what changed, not the
scripts**: an integrator can compute a binding today; our own demo has not been switched
over. Said here rather than left for someone to discover.

**Both bindings are now two implementations. Neither is anchored.** A proof carries the
verdict's authority; it does not prove the committed prestate was the chain's real state.
On EVM that binding lives in an off-chain layer; on Solana the guest recomputes a
`bank_hash` over the account set the deal committed to, which is internal consistency and
not provenance.

*No bridge, no light client* describes the adjudication path, not the anchoring.

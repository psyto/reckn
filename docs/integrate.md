# Using Reckn from your own agent

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

## What is not ready, stated plainly

**You cannot yet compute `DEAL_BINDING` on the host for an EVM deal.** The binding is
computed **inside the guest**, and today the only implementation is that one:
`zk-verdict/program-revm/src/main.rs`. Every script here reads it out of a proof fixture
(`jq -r '.deal_binding'`), which is fine for a demo and wrong for a buyer, because a buyer
must commit to the binding *before* the seller does the work.

So the flow that works end to end today is: **agree the terms, produce the proof, fund
against its binding, settle.** The flow a production integrator wants — **fund first,
against a binding you computed yourself** — needs a host-side implementation of the v2
preimage. It is not hard; it is a day of work and a second implementation to keep in step.
It is not done, and until it is, this is a payment rail you can settle on rather than one
you can open a deal on unattended.

The Solana side already has that second implementation
(`svm_deal_binding` in `zk-verdict/script/src/lib.rs`), deliberately not shared with the
guest so a transcription error shows up as a mismatch rather than as agreement. The EVM
side should look the same and does not yet.

**And the anchoring limit applies to both.** A proof carries the verdict's authority; it
does not by itself prove the committed prestate was the chain's real state. On EVM that
binding lives in an off-chain layer; on Solana the guest recomputes a `bank_hash` over the
account set the deal committed to, which proves internal consistency and not provenance.
*No bridge, no light client* describes the adjudication path, not the anchoring.

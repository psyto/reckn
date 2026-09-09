# Reckn starter — fork this

A buyer agent, a seller service, one deterministic step, and a payment that only a proof can
release. Three deals, in one command, on a chain that costs nothing.

```bash
npm install
npm run demo:local     # brings up anvil, deploys, runs all three paths
npm run stop           # when you are done
```

Needs [Foundry](https://getfoundry.sh), Node 22+, `jq`. **No wallet, no funds, and no key of
yours** — the local chain uses anvil's public development key, which holds nothing anywhere.

## What you will see

1. **the buyer computes the binding before the seller works**, and it matches the one the
   shipped proof carries. That ordering is what makes the escrow sound.
2. **release** — the proof reproduces, the seller is paid.
3. **refund** — a proof that the work did *not* reproduce sends the money back.
4. **refusal** — a **real** proof of a different job is submitted. It verifies. The escrow
   refuses, the deal stays `Funded`, and the money does not move.

## What is ours and what is yours

| | |
|---|---|
| **`src/terms.ts`** | **the only file you replace.** Your prestate, your call, your condition |
| everything else | stays as it is |
| the proofs | **ours.** They are the repository's shipped Groth16 fixtures, so the demo runs without a prover. Yours would be proofs of your own step |
| `setup-chain.sh` | a throwaway local chain. On Arc testnet this is replaced by your wallet and the real USDC face |

**The refund path funds against the shipped failure fixture's binding rather than one this
package computed** — that fixture's terms are not in the golden vector, and generating a fresh
proof takes minutes. The release path is the one that demonstrates buyer-side binding
computation. The demo prints this while it runs; it is not buried here.

## Before you swap in your own step

Answer these three. If you cannot, Reckn is the wrong tool for that step and it is better to
know now:

1. **which contract call** does the work?
2. **which token's balance should go up** as a result?
3. **by at least how much**?

That is the entire predicate. Reckn does not evaluate quality, correctness of judgement, or
anything a person would argue about — it replays one call and checks one slot against a floor.

## Then: Arc testnet, with your wallet

See [`docs/partner-kit.md`](../../../../docs/partner-kit.md). It states the faucet, the
funding, the proving time (**335 s for the shipped fixture, 497 s for a real mainnet Uniswap
swap**, on a laptop CPU), and what is not supported — before you spend an afternoon on it.

**A local run is not adoption and we will not describe it as one.** The version that counts
has your address in the `buyer` field on a public chain.

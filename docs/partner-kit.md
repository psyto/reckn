# Reckn Partner Kit — from a clone to a settled deal

**What this is.** A TypeScript package for opening a Reckn deal, checking one before you work
on it, settling it on a proof, and verifying the settlement afterwards. It exists because
until now the way in was `cast send` with a private key on the command line and a
seven-argument ABI call, which is a fine way to test a contract and a bad way to adopt one.

**What it is not.** It does not decide payments and it cannot be made to. It holds no key —
every function either reads a chain or hands a transaction to a wallet you supply. There is no
call in the escrow that lets anyone override a verdict; if you go looking for it in
[`src/escrow.ts`](../packages/partner-kit/src/escrow.ts), it is not omitted, it does not exist.

**And it is not an evaluator of your agent.** Reckn answers one question: *did this call,
replayed against this prior state, move this storage slot up by at least this much?* It has no
opinion about whether your agent's output was good. If the valuable part of your job cannot be
phrased as that question, this is the wrong tool for it, and ten minutes from now is the
cheapest time to find that out.

---

## Ten minutes, on a chain that costs nothing

```bash
git clone https://github.com/psyto/reckn && cd reckn/packages/partner-kit
npm install && npm run build

cd examples/starter && npm install
npm run demo:local
```

Needs [Foundry](https://getfoundry.sh) (`anvil`, `forge`, `cast`), Node 22+, and `jq`. **No
wallet, no funds, no key of yours.** It brings up a throwaway anvil at Arc's chain id, deploys
the keyless path, and runs three deals:

| | what it shows |
|---|---|
| **release** | the buyer computes the deal binding **before the seller works**, funds against it, and a proof that reproduces pays the seller |
| **refund** | a proof that the work did **not** reproduce sends the money back to the buyer |
| **refusal** | a **real** proof of a *different* job is submitted. It verifies. The escrow will not move the money |

The third is the one to watch. Nothing about it is staged: the proof is valid, and it is
refused because the deal committed to different terms.

When you are done: `npm run stop`.

> **Tier, said before you draw a conclusion.** That is a local chain. It shows the deploy path
> and the settlement path work end to end. It is **not** evidence about any public network.

---

## The four calls

```ts
import { createDeal, sellerPreflight, submitProof, verifySettlement } from "@reckn/partner-kit";
```

**`createDeal`** — computes the binding from your terms, checks the profile **against the
chain**, and refuses to fund if the verifier's codehash on chain differs from the file's.
Funding against something nobody has looked at is the one mistake this package will not help
you make.

**`sellerPreflight`** — read-only. Buyer, seller, token, amount, the verifier and whether its
code still hashes to what the deal pinned, the predicate, the deadline, and the known limits.
**Run this before you do the work.**

**`submitProof`** — sends `settleWithProof`, which is permissionless. The key paying the gas
has no bearing on where the money goes; anyone may call it, including someone who is neither
party.

**`verifySettlement`** — decodes the state, verdict, recipient, amount and binding **off the
chain**, so a third party can check a settlement without taking your word for it.

There is also a read-only CLI:

```bash
npx reckn preflight --rpc <url> --escrow 0x… --deal 0x… --profile arc-testnet-evm
npx reckn verify    --rpc <url> --escrow 0x… --deal 0x… --tx 0x…
npx reckn profiles
```

Neither subcommand sends a transaction, and neither has a flag that takes a key.

---

## Arc testnet, with **your** wallet

The local demo proves the shape. This is the part that produces a receipt with your address in
it — which is the only version that means anything.

1. **A testnet wallet you control.** Not a key you use anywhere else. This package never asks
   for one: you build a viem `WalletClient` and pass it in.
2. **Testnet USDC on Arc.** Arc uses Circle's USDC as its native gas token, with a 6-decimal
   ERC-20 face at `0x3600…0000`.
3. **Load the profile** — `arc-testnet-evm` ships with the package. `createDeal` verifies it
   against the chain before funding.
4. **Your terms.** Replace `examples/starter/src/terms.ts`. That file is the only one you edit.
5. **A proof of your step.** This is the slow part; see below.

### What you should know before you budget an afternoon

| | measured |
|---|---|
| generating a Groth16 proof, shipped fixture | **335 s** end to end |
| generating one for a **real mainnet Uniswap v3 swap** | **497 s** (13,006,200 cycles) |
| what proving needs | the SP1 toolchain and **~6.2 GB** of Groth16 artifacts in `~/.sp1` |
| settling on Arc | 320,600–345,874 gas, **0.0070–0.0077 USDC** |

Both proving figures are on a laptop CPU with no prover network. **The on-chain cost of
deciding is cents; the real cost is minutes of proving per dispute.** That sets the floor:
this is for the tail of high-value reproducible work, not for the volume. See
[`positioning.md`](positioning.md) for the arithmetic.

---

## Verifier Profiles

A profile is a JSON file describing a deployment — chain, escrow, verifier, its code hash, the
guest it judges, what it can adjudicate, and its known limits. Three ship with the package:

```
arc-testnet-evm      Arc testnet, EVM guest    ← use this one for EVM re-execution
arc-testnet-svm      Arc testnet, SVM guest
tempo-moderato-svm   Tempo Moderato, SVM guest
```

> **A profile is description, never authority.** Nothing in one authorises a payment. The
> escrow settles on the code hash the **funder pinned on chain**, re-checked at settlement —
> never on what a file said. `validateProfile` answers *is this file well-formed*;
> `verifyProfileAgainstChain` answers *does the deployment it describes actually exist and
> match*. A green offline validation says the file is not obviously broken and **nothing**
> about whether the addresses in it are real.

**One verifier judges one guest, permanently.** Measured on chain 2026-09-09:

```
Arc   0xc5f45b9d…  ->  EVM guest
Arc   0x13d42c0a…  ->  SVM guest
Tempo 0x44e6bCae…  ->  SVM guest
```

**There is no EVM-guest verifier deployed on Tempo.** An EVM deal binding — what this
package's `evmDealBinding` produces — cannot settle there today. Use `arc-testnet-evm`.

---

## The deal binding, and why it is re-implemented here

A buyer has to commit to the terms **before** the seller works, which means computing the
binding without a proof. This package does that in TypeScript rather than shelling out to the
Rust, and [`integrate.md`](integrate.md) gives the reason:

> Two independent transcriptions make an error surface as a *mismatch*; one shared
> implementation makes the same error surface as *agreement*, which is indistinguishable from
> correctness.

This is the third — the guest inside SP1, the Rust host, and here. It is **checked, not
reviewed**: `zk-verdict/script/src/bin/binding_vector.rs` emits a golden vector and asserts
that the Rust already agrees with the value the guest committed for the shipped Groth16
fixture, refusing to write one otherwise. So the expected value is the guest's.

```bash
cd packages/partner-kit && npm test              # 30 tests, no chain needed
cd packages/partner-kit/examples/starter && npm test   # the three paths, end to end (needs anvil + forge)
```

The first suite runs against the **built** package rather than the sources, so what passes is
what ships. It covers the golden vector, the profile validator — including that every
profile's cited evidence actually exists and is for the right binding scheme — and the
preflight's output, because a warning that quietly disappears from what a seller reads is
exactly the kind of regression nobody notices.

**If that test fails, do not use `evmDealBinding`.** Compute the binding with the Rust
(`verdict_script::evm_deal_binding`) instead. An unverified re-implementation of the value
that decides who gets paid is worse than none.

---

## What is not ready, stated plainly

- **x402 funding is on the *optimistic* escrow, not this one.** `RecknEscrow` consumes an
  EIP-3009 authorisation directly; `RecknZkEscrow` — the keyless path this package targets —
  takes a plain `approve` + `fund`. Wiring x402 into the keyless escrow would mean adding a
  function to it, which changes the central claim and is not on the table. If you read
  "x402 + Reckn" somewhere, check which escrow is meant.
- **The starter's refund path uses a shipped fixture's binding**, not one this package
  computed, because that fixture's terms are not in the golden vector and a fresh proof takes
  minutes. The release path is the one that demonstrates buyer-side binding computation. The
  demo says so on screen while it runs.
- **No mainnet.** Every deployment is testnet.
- **The thirty-day timeout has never been demonstrated** on a public chain and cannot be — a
  public chain cannot be fast-forwarded. The refund you see is always the proof-driven one.
- **Nobody outside this project has used this yet.** There is no adoption to claim and none is
  claimed. If you are the first, [`tokyo-partner-pilot.md`](tokyo-partner-pilot.md) is what we
  would do with you and what we would and would not say about it afterwards.

## Where to read next

- [`positioning.md`](positioning.md) — which layer this is, what it suits, what it does not.
- [`integrate.md`](integrate.md) — the raw contract surface underneath this package.
- [`status.md`](status.md) — `Known gaps (not closed)`.

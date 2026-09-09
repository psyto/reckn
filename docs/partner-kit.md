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

## Before you install anything

The cheapest rung needs **no clone, no npm, no wallet**:

| | |
|---|---|
| **[psyto.github.io/reckn](https://psyto.github.io/reckn/)** | your browser fetches the deployed bytecode from Arc and compares it against this source, then reads **four settlements** off the chain — two of them decided by proofs about work performed on Solana |
| **[/money-shot.html](https://psyto.github.io/reckn/money-shot.html)** | one dispute, judged two ways: an opinion model approves a false claim, a replay overrules it, the money goes back |
| **the page's own "Check it without this page"** | the `curl` calls that do the same thing with no page at all |

If that is enough to tell you this is the wrong tool for your job, you have spent ninety
seconds instead of an afternoon. That is the point of the order.

## Ten minutes, on a chain that costs nothing

> **Verified 2026-09-09, morning**: `npm run demo:local` ran to completion here — release,
> refund, and the refusal — exit 0. The refusal printed *"The proof verified. The money did
> not move."* If it does not do that on your machine, that is a bug and we want the output.
>
> **Re-verified 2026-09-09, just after 14:01**, on a still tree after the acceptance gates finished — and
> it took a fix to get there. The first re-run **failed**: `invalid verifier profile: specId`.
> Making `specId` mandatory for EVM profiles landed at 11:13 with `reckn terms`, and the
> starter builds its local profile at runtime, so it was the one profile in the repository that
> nobody updated. One field fixed it. All three paths then behaved, exit 0, and the refusal
> printed the line above.
>
> The interesting part is that nothing caught it for three hours: the starter is not in any
> gate, so a change to a validator in one package silently broke the first command a partner
> is told to run.


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
// resolves through the workspace (`"@reckn/partner-kit": "file:../.."`), NOT the npm registry
import { createDeal, sellerPreflight, submitProof, verifySettlement } from "@reckn/partner-kit";
```

**`createDeal`** — computes the binding from your terms, checks the profile **against the
chain**, and refuses to fund if the verifier's codehash on chain differs from the file's.
Funding against something nobody has looked at is the one mistake this package will not help
you make.

**`sellerPreflight`** — read-only. Buyer, seller, token, amount, the verifier and whether its
code still hashes to what the deal pinned, the predicate, the deadline, and the known limits.
**Run this before you do the work.**

It also asks the **token** whether it will pay the people this deal names. There is a deal on
Arc right now whose seller is blacklisted by USDC: a valid `Reproduced` proof would revert on
the transfer and the money would sit until the deadline returned it to the buyer. Before this
probe, the preflight told that seller only that "USDC on Arc carries a blacklist" — true, and
not the same sentence as **"you specifically will not be paid."** It now says the second one.
The probe covers known shapes (`isBlacklisted`, `isFrozen`, `paused`) and reports which ones it
managed to ask; **a quiet result is not a promise that you will be paid**, and the output says
so every time.

**`submitProof`** — sends `settleWithProof`, which is permissionless. The key paying the gas
has no bearing on where the money goes; anyone may call it, including someone who is neither
party.

**`verifySettlement`** — decodes the state, verdict, recipient, amount and binding **off the
chain**, so a third party can check a settlement without taking your word for it.

**`buildTerms`** — turns *your* transaction into deal terms. This is the step that had no
tool: before it, replacing the starter's sample meant reading the `keeper` crate and
assembling an anchor, a plan and a predicate by hand. The API was never the barrier; this was.

There is also a read-only CLI:

```bash
bash scripts/reckn terms --rpc <url> --profile arc-testnet-evm \
    --from 0x… --to 0x… --data 0x… \
    --check-token 0x… --check-holder 0x… --min 246000000 --out terms.json

bash scripts/reckn preflight --rpc <url> --escrow 0x… --deal 0x… --profile arc-testnet-evm
bash scripts/reckn verify    --rpc <url> --escrow 0x… --deal 0x… --tx 0x…
bash scripts/reckn profiles
```

Neither subcommand sends a transaction, and neither has a flag that takes a key.

**Why `bash scripts/reckn` and not `npx reckn`.** This package is **not published to npm**:
`reckn` and `@reckn/partner-kit` both 404 on the registry (checked 2026-09-09). `npx reckn`
therefore reaches the network and fails for anyone outside a tree that has already installed
it — so it was documenting a command that does not exist. `scripts/reckn` runs from anywhere
in the repository, installs and builds on first use, and needs no registry. It is the same
CLI; only the path is honest.

Nothing here will tell you to `npm install @reckn/partner-kit` until that command actually
works. When it does, it will be a scoped package at a pinned version, published from CI with
[npm provenance](https://docs.npmjs.com/generating-provenance-statements) via OIDC trusted
publishing, verifiable with `npm audit signatures` — and the Git tag will stay supported, so
the registry is never the only path you have to trust. `packages/partner-kit/release-gate.sh`
holds those conditions and reports what it measured.

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
4. **Your terms.** `bash scripts/reckn terms` builds them from your own transaction — one command,
   read-only, no key. Or edit `examples/starter/src/terms.ts` by hand if you prefer.
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

## The endpoint has to be able to answer, and not all of them can

`reckn terms` needs **`eth_createAccessList`** (to simulate) and **`eth_getProof`** (to capture
the witness). Measured 2026-09-09, on the two chains this repo actually deploys to:

| endpoint | `eth_createAccessList` | `eth_getProof` | `reckn terms` |
|---|---|---|---|
| `rpc.moderato.tempo.xyz` | yes | yes | works |
| `rpc.testnet.arc.io` | **no** | **no** | **cannot build terms** |

This is a property of the endpoint, not of the chain and not of your transaction — and the
tool used to report it as *"the call could not be simulated"*, which sends you to debug a call
that is fine. It now names the missing method and says what still works: the **binding**
commits only stateRoot, env, check and plan, so it needs one `eth_getBlockByNumber`. You can
compute and fund terms from a limited endpoint; what you cannot do there is prove the call
succeeds or capture the witness.

Funding, settling and verifying are unaffected — none of them simulates anything.

## What `reckn terms` refuses to do

Five mistakes here produce a deal that **opens cleanly and then settles wrongly** — or never
settles at all. Each is worse than an error, because the cost lands after the money has moved.
It refuses all five:

1. **A call that reverts at the anchor.** The plan is replayed against the committed prestate;
   if it fails there, the verdict is `Failed` and the buyer pays to be told the work did not
   reproduce. The call is simulated first, and no terms are produced for one that reverts.
2. **A guessed hardfork.** `specId` is committed into the binding. A different value yields a
   valid-looking hash that no proof from this guest can ever match, with nothing failing at
   funding time. It comes from the profile; you are not asked for it.
3. **An anchor that ages out.** Public endpoints do not serve historical `eth_getProof`
   (measured on Arc and on Tempo). Capture the witness later and it is gone, so it is captured
   in the same run and the bundle is self-contained.
4. **A predicate that decides nothing.** A floor of zero is met by doing nothing: the guest
   measures the increase *the plan itself caused*, so the empty execution scores zero, settles
   as `Reproduced`, and the seller is paid in full for no work — the **buyer** loses. The
   mirror case, a band no execution can satisfy, makes the seller work for a payment that can
   never arrive. Both are refused, and refused again at `createDeal`, because terms can be
   hand-written and the funding call is where the money actually leaves.
5. **A predicate aimed at a slot the plan never moves.** `--slot-index` defaults to **9**,
   which is Circle's FiatToken layout and not a standard. Point it at a token whose balances
   live at slot 0 and everything still works — the slot is a well-formed hash, the binding is
   well-formed, funding succeeds — and then the guest measures a slot nothing writes and
   returns `Failed` forever. The simulation already lists every slot the call touches, so the
   two are compared, and the refusal prints the slots it did touch.

Measured on a real mainnet Uniswap v3 swap: block pinned, call simulated at **118,183 gas**,
**7 accounts and 12 storage slots** captured, binding emitted. Sending no `value` — so the
router cannot wrap — is refused with *"the call REVERTS at block …; terms were not produced."*

**What it does not establish:** that your call clears the floor. Simulation shows it runs, not
that it delivers. And proving it still needs the SP1 toolchain and minutes of CPU.

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
cd packages/partner-kit && npm test              # 81 tests, no chain needed
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

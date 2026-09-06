# Reckn on Arc — a conditional USDC payment whose condition is a proof

*Submission aid for ETHOnline 2026, Continuity Track. Written 2026-09-06. Every number
here is measured on this tree; every claim about Arc is transcribed from Circle's docs
with the date it was read.*

---

## The one sentence

**On Arc, Reckn turns an escrowed USDC payment into a conditional payment whose
condition is a zero-knowledge proof that the disputed work re-executes to the verdict
the deal was funded against — with no owner, no resolver, no bridge and no light
client anywhere on the path that decides who gets the money.**

## Why Arc is load-bearing, and not a deployment target

A payment rail is usually interchangeable, and saying "we also deploy here" is not an
integration. Three properties of Arc are doing actual work here:

**1. USDC is the unit of account, not a token you happen to hold.** Arc's native gas
token *is* USDC, and Circle exposes an ERC-20 interface over that same balance at
`0x3600000000000000000000000000000000000000` — 6 decimals on the ERC-20 face, 18 as
native (Arc docs, *Contract addresses*, read 2026-09-06). So an escrow on Arc holds
the chain's own money. The buyer funds in USDC, the gas is USDC, the payout is USDC,
and there is no bridging step in which a different asset stands in for the payment.
For a dispute system this matters more than it sounds: the thing under dispute and the
thing being escrowed are denominated the same way, so "did the seller deliver the
value they promised" and "how much do we release" are the same arithmetic.

**2. It is a stablecoin-native chain, so the escrow's units are the units.** Reckn's
predicate is a **causal delta over a balance**: *did this execution credit at least
`minDelta`?* On a chain where the payment asset is a volatile gas token, a delta
predicate over the payment is a predicate over a moving target. On Arc it is a
predicate over cents. `test_ARC04_six_decimal_amounts_move_exactly` exists because of
this: an escrow tested only against an 18-decimal mock has never been tested against
the units it will actually hold.

**3. Programmable conditionality is the point of the chain, and Reckn's condition is
not a signature.** Arc's brief asks for *"advanced programmable money flows such as
conditional payments … or multi-step settlement."* Almost every conditional payment
in production is conditional on **someone's signature** — a resolver, a multisig, an
oracle committee, an LLM judge. Reckn's is conditional on a **proof**, and the
contract that releases the money has no privileged role at all. `scripts/no-keys.sh`
fails the build if one appears.

**What Arc does *not* change.** Arc is a rail. It does not adjudicate anything, and
nothing in the adjudication path knows it is on Arc. That is the honest form of "one
engine, any rail" — and it is a conclusion, not the pitch.

**The strongest single sentence this repository can say, and it is a test.** A USDC
payment escrowed on Arc, released by a proof about work performed **on Solana** —
`test_ARC07_usdc_on_arc_settled_by_a_proof_about_work_on_solana`. The deal names the
Solana guest's verifier at funding; the escrow calls it, checks that the proof carries
that deal's binding, and pays. **No bridge, no light client, no resolver**, and the
escrow never learns which virtual machine the work happened on. That is what "the
adjudicator is a computation, not a party" buys: a conditional stablecoin payment on
one chain whose condition is a fact about another.

## What had to change in Reckn to settle USDC on Arc

**Nothing in the contract.** `RecknZkEscrow` already takes the payment token per deal:
the buyer names USDC at funding, the same way they name the adjudicating program. No
wrapper, no adapter, no payable path, no new function — which matters because adding
one would have changed the enumerated surface the central claim is built on
(`AGENTS.md` §0).

What was added is the evidence that it is *correct in USDC's semantics*, which a
deployment cannot tell you afterwards:

| file | what it is |
|---|---|
| `zk-verdict/contracts/test/mocks/MockUSDC.sol` | a USDC-shaped token: **6 decimals**, `transfer`/`transferFrom` that return `true` and **revert** rather than returning `false`, and a **blacklist** |
| `zk-verdict/contracts/test/RecknArcUsdcSettlement.t.sol` | six tests over the real committed Groth16 proofs |
| `zk-verdict/contracts/script/DeployArc.s.sol` | the deployment: SP1's Groth16 verifier, the verdict verifier bound to one guest's vkey, the escrow |
| `zk-verdict/contracts/arc.json` | Arc's constants, transcribed with their source and date |
| `scripts/arc-usdc-e2e.sh` | one command: local chain at Arc's chain id → deploy → fund → settle → refund |

## The architecture

```mermaid
flowchart TB
    subgraph offchain["off-chain — nobody's opinion enters here"]
        W["seller's work<br/>(a committed CALL over a committed prestate)"]
        RE["reexec-evm<br/>real revm, MPT-verified prestate"]
        G["SP1 zkVM guest<br/>re-executes and commits<br/>pre / post / minDelta / maxDelta /<br/>outcome / traceHash / dealBinding"]
        PR["Groth16 proof"]
        W --> RE --> G --> PR
    end

    subgraph arc["Arc — USDC is the native asset AND the gas"]
        U["USDC 0x3600…0000<br/>ERC-20 face, 6 decimals"]
        E["RecknZkEscrow<br/>no owner · no resolver · no admin<br/>no constructor · no immutable"]
        V["RecknVerdictVerifier<br/>bound to ONE guest vkey"]
        S["SP1Verifier (Groth16)<br/>fixed, not a gateway"]
        E -->|"view call = STATICCALL"| V --> S
        E -->|"transfer"| U
    end

    B["buyer (agent)"] -->|"fund(dealId, seller, USDC, amount,<br/>verifier, verifierCodeHash, dealBinding)"| E
    PR -->|"settleWithProof(dealId, publicValues, proof)<br/>permissionless — anyone may submit"| E
    E -->|"Reproduced → USDC to seller"| SE["seller (agent)"]
    E -->|"Failed → USDC to buyer"| B

    style E fill:#0b3d2e,stroke:#0f7,color:#fff
    style PR fill:#123,stroke:#6cf,color:#fff
    style U fill:#1a1a3a,stroke:#88f,color:#fff
```

Two edges carry the whole design:

- the edge into `RecknVerdictVerifier` is a **`view` call**, so it compiles to
  `STATICCALL`: the escrow calls funder-named code *before* it has checked the binding,
  and that is safe only because the callee **cannot write state**;
- the edge from the proof into `settleWithProof` has **no signer on it**. That is the
  product. Everything else is plumbing.

## What the tests establish

Run: `cd zk-verdict/contracts && forge test --match-contract RecknArcUsdc`

| test | what it pins |
|---|---|
| `test_ARC01_usdc_deal_settles_to_the_seller_on_a_real_proof` | 250.00 USDC released by a **real Groth16 proof**, submitted by an address that is neither buyer nor seller |
| `test_ARC02_usdc_deal_refunds_the_buyer_on_a_proven_failure` | the proof of a **decrease** refunds the buyer — the cell that paid the seller before task 008 |
| `test_ARC03_a_proof_of_another_execution_cannot_take_the_usdc` | a proof of a different execution reverts on `dealBinding`; the USDC stays |
| `test_ARC04_six_decimal_amounts_move_exactly` | 1.234567 USDC moves as 1.234567 |
| `test_ARC05_a_blacklisted_seller_makes_settlement_revert_and_the_money_stays` | USDC can freeze an address; the honest consequence is shown, not described |
| `test_ARC06_no_usdc_is_created_or_destroyed_by_a_settlement` | conservation across funding and settlement |
| **`test_ARC07_usdc_on_arc_settled_by_a_proof_about_work_on_solana`** | **USDC escrowed on Arc, released by a real Groth16 proof about work performed on Solana** — the deal names the Solana guest's verifier, and the EVM proof cannot take that deal's USDC |

## Demo, in four minutes

```bash
# 1. the whole path on a local chain at Arc's chain id (no key, no funds, no account)
bash scripts/arc-usdc-e2e.sh

# 2. the same settlement as tests, including the failure directions
cd zk-verdict/contracts && forge test --match-contract RecknArcUsdc -vv

# 3. the claim this is all built on, enforced rather than promised
bash scripts/no-keys.sh          # exit 0 = no key can move a funded escrow
```

`arc-usdc-e2e.sh` prints its tier before it prints anything else: it is a **local
anvil configured to look like Arc** (chain id 5042002, the same 6-decimal USDC face),
**not** an Arc testnet result.

## Deployment status, stated exactly

- **Testnet:** not deployed. `DeployArc.s.sol` runs against Arc's RPC as written and
  has been exercised end to end on a local chain at Arc's chain id. It needs one
  thing: **a funded Arc testnet key**, which an agent must not hold (`AGENTS.md` §8).
- **Mainnet:** Circle has **not published Arc mainnet addresses** as of 2026-09-06
  (Arc docs, *Contract addresses*: "Mainnet addresses are not yet available"). So
  "deployment-ready" is the only honest posture available today, and it is the one
  this repository is in: one script, no configuration, no admin key to hold.

## Limits — read these before believing anything above

- **Local tier.** Everything measured here ran under `forge` and `anvil` on one
  machine. No chain of any kind has been contacted. A green suite says nothing about
  Arc testnet, and Arc testnet would say nothing about mainnet.
- **`MockUSDC` is not USDC.** It models the three properties that can change a
  settlement outcome — 6 decimals, revert-not-false, blacklist. It is not upgradeable,
  has no EIP-3009 and no fee logic. The first thing an Arc testnet deployment would
  test is whether that model was right.
- **The timeout is thirty days, and it is the one payout no proof authorises.**
  `test_ARC05` shows a frozen recipient making the payout revert; `refundAfterDeadline`
  is what stops that from being permanent. Anyone may call it after thirty days, it
  pays the caller nothing, and it cannot be called early, twice, or after a proof
  settled the deal. Thirty days is long for a payments product — it is sized so an
  honest seller can produce a Groth16 proof through a prover outage — and a shorter,
  per-deal deadline is the natural next step. It is deliberately **not** configurable
  today: a deadline someone picks is a parameter someone controls.
- **The buyer names the adjudicator.** A buyer who names a program that always returns
  `Failed` makes the seller work for nothing, and on-chain that is indistinguishable
  from an honest `Failed`. The seller's protection is to read the deal's `verifier`
  and `verifierCodeHash` before working; nothing checks it for them.
- **Anchoring is not adjudication.** "No bridge, no light client" describes the path
  that decides the payout. It is not a claim that the committed prestate was the
  chain's real state; on EVM that binding still lives in an off-chain layer.

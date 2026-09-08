# Messaging — one product, two doors

This file exists because a message told three times drifts three ways. The video's running
time was stated as 101 seconds in the README, 101 in `SUBMISSION.md` and 2:08 in the
submission form, while the file was 199 — three hand-written numbers for one artifact, none
matching it and none matching each other. Positioning drifts the same way and is harder to
measure, so it is written down once here and quoted elsewhere.

**Scope.** ETHOnline 2026 (submitted) and Crypto World's Fair (2026-09-14 → 10-12). Nothing
here is a new claim: every sentence below is traceable to §1, and §2 is the list of things
that must never be said.

---

## The tagline

> ## Keep assets native. Settle on proof.
>
> *Don't make a bridge decide where money goes. Make proof decide.*

**日本語**

> ## 資産は各チェーンに置いたまま、証明によって決済する。
>
> *ブリッジに送金可否を決めさせず、プルーフに決めさせる。*

## Three lines

> An escrow releases only when the work it was funded against can be **re-executed and
> reproduced**.
> The money stays **native on the chain it was funded on** — a proof crosses, the asset does
> not.
> No owner, no resolver, no bridge decides the payout. **Reproduce, or refund.**

**日本語**

> エスクローが解放されるのは、その資金が紐づけられた作業を**再実行して同じ結果が出たとき**だけです。
> 資金は**預けたチェーンにネイティブのまま**留まります。渡るのは証明であって、資産ではありません。
> 支払先を決めるのは、所有者でも仲裁者でもブリッジでもありません。**再現するか、返金か。**

## Twenty seconds

> When one agent pays another, someone has to decide whether the work was done. Today that
> decider is always a party with a key — an operator, a bonded resolver, a quorum — and when
> the work happened on a *different* chain, a bridge ends up in that path too.
>
> Reckn removes the party. The buyer escrows USDC **on the chain it already lives on**. The
> seller does the work on Solana. The disputed execution is **replayed**, and if it
> reproduces the escrow releases; if it does not, the buyer is refunded. **Only the proof
> crosses. The asset never moves.**
>
> That is running on Arc testnet today — four settlements, two of them decided by proofs
> about work performed on Solana. No bridge and no resolver anywhere on the path that chooses
> who gets paid.

---

## The two doors

Same product, same demo, same numbers, same limits. **Only the first sentence changes.**

| | ETHOnline | Crypto World's Fair |
|---|---|---|
| the question at the door | **Who decides the work was done?** | **Why are we bridging the asset every time?** |
| foregrounded | keyless adjudication, re-executable proof, release/refund of a local USDC escrow on Arc | proof-gated multichain settlement, assets kept native on their own chain |
| the shared core | *Keep assets native. Settle on proof.* | |
| the shared evidence | four settlements on Arc testnet, two decided by proofs about work performed on Solana, no bridge and no resolver on the path that chose the payout | |

### ETHOnline — opening thirty seconds

> "When one agent pays another and the delivery is disputed, **someone decides**. Every answer
> shipping today is a party with a key: an operator in an enclave, a bonded resolver, a
> quorum. We removed the party.
>
> The escrow holding this USDC on Arc has no owner, no admin, no resolver and no upgrade path
> — and that is a **build condition**, not a promise. If one appears, the build fails.
>
> What decides instead is **re-execution**. Watch me try to steal the money with a proof that
> is completely real."

### ETHOnline — close

> "A valid proof was not enough — it had to be a proof about **this** deal. Release and refund
> both came from the same machinery, and nobody approved either one.
>
> **Reproduce, or refund.** Everything is in the repository, including the specifications that
> failed review."

### CWF — opening thirty seconds

> "In a multichain agent economy, the money and the work are rarely on the same chain. So we
> bridge — and the moment we do, **a bridge decides whether the payment happens**. We put the
> asset's fate in the hands of the thing least able to tell whether the work was actually
> done.
>
> Reckn inverts that. The buyer escrows the stablecoin **on the chain it is already native
> to**. The seller performs the action on Solana. The disputed execution is replayed, and the
> escrow releases or refunds on the result.
>
> **Only the proof crosses the boundary. The asset never does.**"

### CWF — close

> "This is live on Arc testnet: four settlements, two of them decided by proofs about work
> performed on Solana. One escrow, two virtual machines, and **no bridge and no resolver on
> the path that chooses who gets paid**.
>
> To be precise about what it is not: this does not remove the need to hold funds where you
> pay, and it does not prove those Solana inputs came from mainnet — that is consistency, not
> provenance, and there is a test that says so.
>
> **Don't make a bridge decide where money goes. Make proof decide.**"

### CWF — the only sentence allowed about Tempo

> **"Tempo is the settlement chain Reckn is evaluating for its CWF implementation."**

**Nothing beyond that sentence.** An earlier draft of this section added "we have measured
that the proof machinery it needs is present there", which is true and is still not allowed
here: a measurement offered as reassurance reads as progress, and progress reads as working.
The interim CWF line that carries the idea without naming a chain is:

> "Agents will work across chains. Reckn keeps assets native and settles only when the work
> is proven."

---

## 1. What may be claimed, and where it is checkable

*The right-hand column names where a claim is checked. Some of those files belong to other
work; this document quotes their RESULTS as reported and does not read them to infer state.
Nothing here is claimed on the strength of a file appearing.*


| claim | where it is checked |
|---|---|
| The escrow's function surface is `fund` / `settleWithProof` / `refundAfterDeadline` — no owner, admin, resolver, pause or upgrade path, **as a build condition** | `scripts/no-keys.sh` (two files: `RecknZkEscrow.sol`, `RecknVerdictVerifier.sol`) |
| Deployed on Arc testnet; **four settlements** moved real testnet USDC; **two were decided by proofs about work performed on Solana** | `zk-verdict/contracts/arc.json`, and the live page reads them from chain |
| Both directions are real: `Reproduced` → seller, `Failed` → buyer | `RecknArcUsdcSettlement.t.sol`, `RecknCrossVmSettlement.t.sol` |
| A **real** Groth16 proof of a *different* execution is refused (`BindingMismatch`) and the money does not move | `test_ARC03`, and the demo does it on camera |
| `refundAfterDeadline` is permissionless, pays the caller nothing, and names no privileged address | `RecknTimeout.t.sol` |
| Measured gas on Arc: `solanaProofOnArc` 320,600 · `solanaFailureOnArc` 316,120 · `reproduced` 345,874 | `arc.json` |
| **The USDC never leaves Arc.** No bridge and no light client on the adjudication path | `docs/cross-chain-settlement.md`, the boundary panel on the live page |
| The escrow **names no chain and no token**: `grep -n 'Arc\|USDC' zk-verdict/contracts/src/*.sol` returns nothing | the grep itself |
| The guest recomputes `bank_hash` from the committed prestate; a compact prestate binds transitively to a full snapshot, enforced **before** replay | `docs/svm-snapshot-authenticity.md`, `reexec-svm/src/authenticity.rs` |

## 2. What must never be said

| never | say instead |
|---|---|
| Reckn removes the need for bridges | it removes **the bridge as the decider**. Moving funds to where you pay is a separate problem and it remains |
| Reckn fixes fragmented balances or cross-chain liquidity | **it does not.** The buyer must already hold the settlement asset on the payment chain |
| It can prove arbitrary Solana mainnet state | it proves **consistency over the account set the deal named** — not provenance. It does not establish that those inputs came from mainnet |
| The Arc × Solana demonstration also runs on Tempo | **Tempo is not deployed.** Only local tests and unauthenticated measurements exist |
| "like a bank's daily netting" | do not use it. There is no netting and no clearing here |
| A proof moves assets between chains | a proof **decides a local payment**. Nothing is transferred across a boundary |

### Three qualifiers the tagline needs

1. **"Keep assets native" is not "you never move assets."** What is removed is movement *for
   the purpose of adjudication*, not movement *for the purpose of funding*. Blurring this
   becomes the forbidden liquidity claim on its own.
2. **The settlement chain must be able to verify the proof.** Demonstrated on Arc. On Tempo
   the BN254 precompiles are measured present — necessary, not sufficient.
3. **The predicate is named by the deal at funding.** A dispute cannot be invented afterwards.

### One limitation already recorded, and not to be dropped

Circle's USDC on Arc carries a blacklist. A frozen recipient makes settlement revert and the
deal stays `Funded`; one such deal holds 1.00 USDC and is refundable only by the keyless
deadline. Measured, and recorded in `arc.json` rather than hidden.

A token-level equivalent exists on any chain whose stablecoin can be paused or policy-gated,
and it can reach further than Arc's blacklist does. That is a real limit and it belongs in
the material — but stated generally, as here, and **not** attributed to a specific chain
until that chain's owner reports it. Nothing in this file cites a test or a record it does
not own.

### 日本語表現の落とし穴

- **「橋渡し」「連携」「シームレス」を使わない** — いずれも「資産が渡る」と読まれる。渡るのは証明だけ
- **「証明で送金する」は誤り** — 「証明が**支払いの可否を決める**」
- **「ブリッジ不要」ではなく「**判定者としての**ブリッジが不要」**
- **流動性の文脈で「解決」「解消」を使わない** — 断片化は解消していない

---

## 3. What may be added once Tempo settles — and not before

**Ownership, since 2026-09-08.** The Tempo implementation is another window's work. This
document does not read its files and does not infer its state from them. The trigger for
everything below is a **report from the Tempo owner** carrying the evidence named in
"What must arrive" — not a file appearing, and not a test passing.

Completion means: a deal funded in a real TIP-20 releases on a Solana `Reproduced` proof and
refunds on a `Failed` one, both on Tempo testnet, both with transaction hashes. Until that
report arrives this paragraph is **not** to be used anywhere:

> "The same escrow source, unmodified, settles on two payment chains. On Tempo the settlement
> asset and the **fee that releases it are the same stablecoin** — there is no gas token — so
> the whole payment, including its own decision cost, is denominated in the money being paid.
> The proof still crosses. The asset still does not."

The first sentence is already *structurally* true — the contract names no chain — but it is
not to be claimed until it has actually happened twice, in both directions.

### What must arrive before any of §3 is used

Five items, from the Tempo owner, in their words rather than inferred:

1. the **escrow address** on Tempo testnet, and the chain id it is on;
2. the **TIP-20** a deal was actually funded with — address, symbol, decimals;
3. the **release** transaction hash, and that its proof was a Solana `Reproduced` proof;
4. the **refund** transaction hash, from a `Failed` proof;
5. each transaction's **`feeToken`**, from its receipt — the fee being a stablecoin is the
   part that makes it a Tempo slice rather than a redeploy, and it is the one number a
   viewer cannot infer from anything else on screen.

Anything short of all five and the wording stays at the one sentence above.

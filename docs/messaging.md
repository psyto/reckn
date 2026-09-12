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

## What Reckn is, in the words that are load-bearing

> Reckn is **not a bridge**. It is a **proof-gated settlement layer**: instead of moving
> capital between chains, it leaves assets where they already are and settles conditionally.
>
> The payer's asset is locked **in advance**, in a **local** escrow. It releases only when a
> **machine-verifiable action, agreed beforehand**, is shown on the execution chain by a
> **reproducible proof**. If it is not, the buyer is refunded.
>
> **Therefore no bridge and no relayer has the authority to permit the payment.**

**The last line is the thesis, and it is not "bridges are unnecessary".** What is removed is
the bridge's place in the **trust root that authorises payment** — not the bridge. Getting
that distinction wrong is the difference between a claim that survives a judge and one that
does not, and §2 forbids the wrong version outright.

Three phrases are load-bearing and were absent from the film until 2026-09-08 — an audit
against this section found `in advance` and `agreed beforehand` appearing zero times, and the
cross-chain setting arriving 94 seconds into a 175-second cut:

| phrase | why it carries weight |
|---|---|
| **in advance** | the money is already locked before any work happens; nothing is moved to settle |
| **local escrow** | it is locked on the chain it already lives on; that is what makes this not a transfer |
| **agreed beforehand** | the predicate is named when the deal is funded, so a dispute cannot be invented afterwards |

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

### Chain lines, assigned per event — never mixed

The two chains buy different things, so they get different sentences, and a cut carries **one**.
Stacking them turns a specific claim into a sponsor list. Full argument and receipts:
[`chain-fit.md`](chain-fit.md).

| event | chain line | why it is that chain |
|---|---|---|
| **ETHOnline** (Arc only) | *"Arc is where the dollar stays. The work happened on Solana; the USDC never left Arc."* | a stablecoin-native rail where a conditional payment settles **without bridging the asset** |
| **Tokyo / CWF** (Tempo) | *"Tempo is not just another EVM deployment. The escrow and the cost of deciding it are paid in the same stablecoin."* | Tempo has **no native gas token**, so payment and the cost of deciding it are one unit |

**Either line is followed immediately by:** *"Reckn removes a protocol-level judge. It does not
erase issuer policy."* On Tempo that is load-bearing rather than polite — a TIP-20 issuer's
pause stops a proof-authorised release **and** the thirty-day refund.

**Tempo does not appear in ETHOnline material at all.** That submission stands on Arc; the
boundary is `ethonline-2026/PREFLIGHT.md` §2 and it is a founder decision, not a fact.

### CWF — Tempo, as of 2026-09-08

**Until this date the only permitted sentence was "Tempo is the settlement chain Reckn is
evaluating for its CWF implementation."** It is no longer the ceiling, because the five
things §3 required arrived. What may now be said:

> "The same escrow source, unmodified, settles on a second payment chain. On Tempo the
> escrow held **PathUSD** — a real TIP-20, not a mock — and a proof about work performed on
> Solana released it to the seller; a proof that the work did not reproduce refunded the
> buyer. Tempo has no gas token, so the fee that settled each of those was paid in **the same
> stablecoin the escrow was holding**."

That last clause is the part no other chain gives, and it is what makes this a Tempo slice
rather than a redeploy. It is read off the receipts' own `feeToken`, not asserted.

**"The same escrow source, unmodified" is measured and gated** — `tempo-arc-parity.sh`. Say
exactly that, and do not let it become **"the two chains adjudicate identically"**, which is
false: the adjudicator is named per deal by the funder, the fee models differ, and a TIP-20
can be paused or policy-gated. One source is the claim. One behaviour is not.

**Still not claimable:** anything on Tempo *mainnet*; provenance; that bridges are
unnecessary; and the thirty-day timeout, which is not demonstrated on any chain.

### RDK lineage and the Tempo complement — approved wording

**Founder ruling 2026-09-12.** For CWF, two things may be said that were not said before: where
the execution engineering came from, and how Reckn sits next to Tempo's own agent-facing
tooling. Both are **positioning**, so both live here, and both carry a boundary that is easy to
cross by accident. The 150-word form that uses them is
[`cwf-2026/PITCH.md`](cwf-2026/PITCH.md).

**The RDK lineage — the exact sentence.**

> **"The deterministic-execution design behind Reckn grew out of our work on RDK —
> deterministic state transitions, replayable scenarios, pinned execution environments —
> developed here into a re-execution mechanism for deciding payments."**

- It is a claim about **design knowledge**, not about code. **Never say Reckn reuses RDK's
  re-execution code**: the MPT witness path, the closed-world replay, the zkVM guests and the
  Solana backend are Reckn's own implementation.
- **Never say "built on Reth."** Reckn's EVM stack is **`revm 38` + `alloy`**
  (`reexec-evm/Cargo.toml`, `zk-verdict/program-revm/Cargo.toml`), and `reth-trie` was
  *declined* on purpose so that an offline verifier would not pull in a node's database layer
  ([`reexec-evm-mpt-verification.md`](reexec-evm-mpt-verification.md) § Decision). Naming RDK's
  stack as Reckn's dependency list would be false and is checkable in one grep.
- What backs the design claim inside this repository: the engine is **pinned and checked rather
  than assumed** — the hardfork and block environment are committed and verified against the
  guest ([`specs/008`](specs/008-verdict-domain-soundness.md)), and the prestate is
  MPT-verified rather than supplied ([`reexec-evm-mpt-verification.md`](reexec-evm-mpt-verification.md)).

**The Tempo complement — the sentences to use, and the one that was corrected.**

**The primary pair** (founder, 2026-09-12, after the citation below arrived):

> **"Tempo Evals verifies that an agent can correctly integrate and operate on Tempo. Reckn
> verifies whether that agent's committed delivery earned the payment."**

> **"Tempo makes agent payments operable and evaluable; Reckn makes high-stakes agent payments
> accountable."**

Also usable, and slower: *"Tempo helps verify that agents can build and operate payment
integrations correctly. Reckn complements that layer by making the payment itself conditional on a
verifiable result."*

~~*"Tempo verifies that an agent can operate."*~~ **Superseded** — it was carried for a few hours
as speech-only because no page could be cited. **The subject is `Tempo Evals`, not "Tempo"**, and
the distinction is the whole accuracy of the sentence: the chain does not adjudicate anyone's
commerce, and an evaluation harness does not decide a payment. Say the tool's name.

**The citation, read 2026-09-12** — <https://github.com/tempoxyz/tempo-evals>, Apache-2.0 / MIT:

- *"Evaluation harnesses for agents building on Tempo and related protocols, powered by Harbor."*
- suites: **Tempo integration v1** — *"TypeScript integrations that submit and verify Tempo
  testnet transactions"* · **Tempo MCP efficiency v1** — *"Live Tempo investigations using direct
  documentation tools or docs_code"* · **MPP integration** *(marked **Unstable** there — repeat
  that word if the suite is named)* — *"Paid HTTP and MCP services and clients on Tempo testnet"*
- *"The **verifier** deterministically checks the submission and writes the Harbor reward."* The
  oracle solution proves a task is solvable and is never shown to the agent.

**So the layers can be named exactly**, which is stronger than "complementary" on its own:

| layer | the question it answers | who |
|---|---|---|
| agent capability & integration quality | *can this agent integrate with the rail and operate it correctly?* — development and evaluation, **before** any commerce | **Tempo Evals** |
| payment rail | *is the transfer authorised and paid for, under the token's own policy?* | **Tempo** |
| delivery assurance & conditional settlement | *did this agent's **committed delivery** actually happen, and therefore does the money move?* — **after** the work, in a dispute | **Reckn** |

- **Never say Reckn reads, references or settles on a Tempo Evals score.** No such integration
  exists. The accurate form is: **the same agentic commerce stack, with the evaluation layer and
  the delivery-assurance / settlement layer each doing its own job.** Reckn is an ordinary EVM
  contract on Tempo and reads **nothing** from Evals, Harbor or RewardKit.
- **Never imply endorsement or membership.** Reckn is not part of Tempo Evals, is not a suite in
  it, and has not been evaluated by it. Citing a public repository is not a relationship.
- **The parallel may be pointed out, and only as a parallel.** Tempo Evals grades with a
  *deterministic verifier* rather than a judge, and says plainly that *"RewardKit quality signals
  are reported separately and cannot replace functional correctness."* Reckn's whole architecture
  is that sentence applied to money. **Observed convergence — not a joint design, not a shared
  component, and not something Tempo has said about Reckn.**
- **Never say "Tempo verifies Solana."** Tempo runs no Solana VM and inspects no Solana state.
  What settles on Tempo is a **local** TIP-20 payment, decided by a proof.

---

## Founder ruling 2026-09-09 — the door line stays as it is

The ETHOnline door plate reads, verbatim:

> A payment lives on Arc. The work happens on Solana.
> **No bridge and no judge decides the payout.** A proof does.

A messaging rule adopted the same day says to treat bridges and oracles as **different roles
rather than worse ones** — a bridge makes a remote asset or remote state actionable; an oracle
adjudicates an external claim; Reckn settles a locally held asset from a reproducible execution
result. Read strictly, the third line puts "not a bridge" at the centre of the claim, which that
rule would demote to a comparison.

**The line stays.** The founder's ruling: *"slightly prone to misunderstanding, but very easy to
understand."* Ten seconds of plate is where compression is the job. The precision belongs one
layer down, and it is already there — [`README.md` § What crosses, and what does not](../README.md#what-crosses-and-what-does-not)
states that it is the escrow's **adjudication path** that carries no bridge, no light client and
no resolver, which is not a claim that bridges are unnecessary or that nothing was bridged to get
the money to Arc in the first place.

So: **do not "correct" the door line for accuracy.** It was weighed and kept. If the precision
ever stops being reachable from the README, fix the README rather than the plate.

## "Building the standard" — the exact strength of that claim, and what would raise it

The wording is:

> **Reckn is building the standard** for proof-driven settlement across execution environments.
> Agents may choose where work happens. Assets remain native. Reproducible execution decides
> payout.

**Never** `Reckn is a standard`, `the open standard`, `the industry standard`, or any phrasing
that implies it has been adopted. As of 2026-09-09 there is **no independent adoption, no second
implementation, and no standards body**. `building` is the whole difference between an ambition
stated honestly and a claim a judge can falsify in one search.

**Three things must be true before the claim may be strengthened.** All three, not any of them:

1. A **published, versioned specification** of Deal Terms / Binding, the Verifier Profile, and
   the Proof Receipt — not code that happens to define them.
2. An **independent implementation, or an outside team's integration** — someone who is not this
   project.
3. **A third party verifying a receipt** against their own repository, their own wallet, and
   their own deterministic job.

Until then the honest form of the ambition is the boundary table in
[`positioning.md`](positioning.md#what-a-standard-would-have-to-fix), which says what Reckn wants
to make common and marks the one boundary that is still open.

**Where it may appear.** The closing plate of the film, the deck cover, `README.md`, and the
Tokyo/CWF script. **Not** in the ETHOnline door plate — that is ten seconds carrying the
concrete claim, and an abstraction there competes with the thing that earns attention. See the
founder ruling above.

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
| **The same escrow source, unmodified, settles on two payment chains** — Arc and Tempo testnet | `bash zk-verdict/scripts/tempo-arc-parity.sh` (the Tempo owner's gate). This is a claim about the SOURCE, not about the two chains behaving alike |
| The guest recomputes `bank_hash` from the committed prestate; a compact prestate binds transitively to a full snapshot, enforced **before** replay | `docs/svm-snapshot-authenticity.md`, `reexec-svm/src/authenticity.rs` |

## 2. What must never be said

| never | say instead |
|---|---|
| Reckn removes the need for bridges | it removes the bridge from the **trust root that authorises payment** — *no bridge and no relayer has the authority to permit the payment*. Moving funds to where you pay is a separate problem and it remains |
| Reckn fixes fragmented balances or cross-chain liquidity | **it does not.** The buyer must already hold the settlement asset on the payment chain |
| It can prove arbitrary Solana mainnet state | it proves **consistency over the account set the deal named** — not provenance. It does not establish that those inputs came from mainnet |
| Reckn **reuses RDK's** re-execution code | **it does not.** *The deterministic-execution **design** grew out of that work*; the MPT witness, the closed-world replay, the zkVM guests and the Solana backend are Reckn's own. And Reckn is **not built on Reth** — `revm 38` + `alloy`, with `reth-trie` declined on purpose |
| Reckn is **integrated with** Tempo Evals, or settles on an Evals / Harbor / RewardKit score | **it is not, and it is not endorsed by or part of it.** Same agentic commerce stack, different layers: **Tempo Evals** asks *can this agent integrate and operate correctly*, **Reckn** asks *did its committed delivery earn the payment*. Reckn is an ordinary EVM contract on Tempo and reads **nothing** from any of them |
| **Tempo verifies Solana**, or: there is no bridge, therefore the Solana state is proven | **both false, and the second is two unrelated facts glued together.** Tempo runs no Solana VM. The absence of a bridge is about *who may authorise the payment*; provenance is a separate question and it is **not** answered — see the row above |
| The Arc × Solana demonstration also runs on Tempo | **it is a different demonstration, not the same one relocated.** Tempo settled its *own* deals — 1.000000 PathUSD each, its own hashes (`docs/specs/011` §10) — while the four Arc settlements stayed on Arc. What is shared, and gated, is the **escrow source**: byte-identical on both chains (`tempo-arc-parity.sh`). "Same source, two chains" is the claim; "the same demo, twice" is not. *(This row read "Tempo is not deployed" until 2026-09-09 — true when written, false after the deployment on 09-08.)* |
| "like a bank's daily netting" | do not use it. There is no netting and no clearing here |
| A proof moves assets between chains | a proof **decides a local payment**. Nothing is transferred across a boundary |
| "verifying a proof is expensive on that chain" — about Tempo or any chain, now or after any unlock | **false, and it will stay false.** BN254 arithmetic costs the same on Tempo as on Ethereum; what Tempo charges more for is STATE. A cost sentence must be about state or it is wrong |
| "the two chains adjudicate identically", or any wording that slides from *one source* to *one behaviour* | **false.** What is measured and gated is that the **escrow source is unmodified across both**. The adjudicator is named per deal by the funder, the fee models differ, and a TIP-20 can be paused or policy-gated where Arc's USDC cannot be in the same way. "Same source, two chains" is the claim; "same adjudication" is not, and the gap between them is exactly where an over-claim would live |
| any sentence that mixes the 30-day timeout with the demonstrated refund | **they are different refunds.** `refundAfterDeadline` waits thirty days; **the refund on screen is always the proof-driven one** (`Failed` → buyer), which is immediate. Conflating them survives no scrutiny. *(This row read "on a public chain it can never be shown inside an event" until 2026-09-12 — true for a deal funded inside an event, false for the Tempo `mismatch` deal, which was funded 09-08 and therefore unlocks 2026-10-08, inside CWF's window. Until someone calls it, it is still **scheduled**, not demonstrated.)* |

### Design non-claims vs status limits — do not put them in the same list

Three of Reckn's limits are **design**: it does not remove bridges, it does not fix
fragmented liquidity, and it does not prove Solana mainnet provenance. **None of them becomes
true later.** They are boundaries of the thing itself.

Two others are **status**: this is Arc testnet rather than production, and the thirty-day
timeout refund is undemonstrated because a public chain cannot be fast-forwarded. **Both stop
being true the moment a mainnet address exists or thirty days pass.**

They were briefly listed together on one slide, and the founder caught it: mixing them makes
the permanent boundaries read as temporary inconveniences, which quietly overstates the
product. State both — never in the same column, and label which is which.

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

### UNLOCKED 2026-09-08 — all five arrived

The five items §3 required were reported by the Tempo owner and are in the repository. The
paragraph below this section is now **true and usable**.

| # | required | delivered |
|---|---|---|
| 1 | escrow address + chain id | `0x7e953a6ac16744ef1a02e343277ec55d7410f439`, chain **42431** (Tempo Moderato testnet) |
| 2 | the TIP-20 actually funded | `0x20C0…0000` — **PathUSD, 6 decimals, the real token**, not a mock |
| 3 | release tx, from a Solana `Reproduced` proof | `0xeb53bc37…0b99f` — the same fixture `RecknSvmVerdict.t.sol` and Arc's `solanaProofOnArc` use |
| 4 | refund tx, from a `Failed` proof | `0x97b65755…cf157` |
| 5 | each receipt's `feeToken` | both `0x20c0…0000` — **the same token the escrow was holding**; `feePayer` is the buyer |

Recorded in `zk-verdict/contracts/tempo.json` under `deployedByReckn`, with a second script
reading the deployment back off the chain rather than trusting the run that produced it.
The explorer-linked table is `docs/specs/011-tempo-tip20-slice.md` §10 — **quote from there**;
neither this file nor anything downstream retypes a hash.

> **A note on how this was checked, because the check was wrong first.** Verifying the report
> meant reading `deployedByReckn.settlements` — the key Arc's record uses — and it came back
> empty, which looked like a contradiction. It was not: the Tempo record keeps its
> transactions under `run.steps`. The instrument had assumed a schema. The data was there the
> whole time and the reader was looking in the wrong place, which is worth writing down
> because it is the shape of almost every wrong measurement in this project.

**Two things did not unlock, and never will.** Both were written into §2 before this report
arrived, which was the point of writing them early:

- **`refundAfterDeadline` is not demonstrated and cannot be.** Thirty days exceeds the
  judging window and time cannot be warped on a public chain. The mismatch deal on Tempo is
  `Funded` until **2026-10-08**. The refund that is shown is always the **proof-driven** one.
  The Tempo record encodes this itself, in a field named `notDemonstrated`.
- **No provenance claim.** The guest recomputed a bank hash over the account set *the deal
  named*. It did not establish that those inputs came from Solana mainnet. §1.2 does not move.

### What was required before §3 unlocked (kept for the record)

### What must arrive before any of §3 is used

Five items, from the Tempo owner, in their words rather than inferred:

1. the **escrow address** on Tempo testnet, and the chain id it is on;
2. the **TIP-20** a deal was actually funded with — address, symbol, decimals;
3. the **release** transaction hash, and that its proof was a Solana `Reproduced` proof;
4. the **refund** transaction hash, from a `Failed` proof;
5. each transaction's **`feeToken`**, from its receipt — the fee being a stablecoin is the
   part that makes it a Tempo slice rather than a redeploy, and it is the one number a
   viewer cannot infer from anything else on screen.

All five arrived on **2026-09-08**. The list is kept rather than deleted so that the next
time something is claimed, the standard it had to clear is visible.

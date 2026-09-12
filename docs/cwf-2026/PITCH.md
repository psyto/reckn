# CWF pitch — the 150 words, and what each clause is allowed to mean

One pitch, **150 words**, written to be pasted into the submission form's description and to
sit in the repository README without either copy drifting. Every clause in it is traceable to a
file in this repository or to a cited external page, and the table below says which. The audit
at the bottom is the part to read before improvising a sentence in a live interview.

---

## The pitch

> Agent-to-agent payments still end at somebody's key when they are disputed — an operator's
> TEE, a bonded resolver, a vote. Reckn replaces the judge with re-execution. A buyer escrows a
> TIP-20 stablecoin on Tempo; the seller's agent works on Solana; the committed execution is
> replayed in a zkVM, and a Groth16 proof verified on Tempo releases the payment or refunds it.
> The escrow has no owner, resolver, pause or upgrade path, and the build fails if one appears.
> Its deterministic-execution design grew out of our work on RDK — deterministic state
> transitions, replayable scenarios, pinned execution environments — developed here into a
> payment adjudicator. Tempo Evals verifies that an agent can correctly integrate and operate on
> Tempo; Reckn verifies whether that agent's committed delivery earned the payment. Live on Tempo
> Moderato testnet: one proof-driven release, one refund, each fee paid in the same stablecoin the
> escrow held.

**Three shorter forms.** All are in
[`docs/messaging.md`](../messaging.md#rdk-lineage-and-the-tempo-complement--approved-wording)
with their limits:

> **"Tempo makes agent payments operable and evaluable; Reckn makes high-stakes agent payments
> accountable."**

> **"Tempo Evals asks whether an agent can operate. Reckn asks whether its committed delivery
> earned the payment."**

> **"Only the proof crosses the boundary. The asset never does."**

---

## Every clause, and the file that carries it

| clause | where it is checked |
|---|---|
| the escrow has no owner, resolver, pause or upgrade path, **and the build fails if one appears** | `bash scripts/no-keys.sh` — a build condition over `RecknZkEscrow.sol` and `RecknVerdictVerifier.sol`, not a promise |
| a TIP-20 stablecoin escrowed on Tempo, released by a proof and refunded by a proof | [`docs/specs/011-tempo-tip20-slice.md`](../specs/011-tempo-tip20-slice.md) §10 · [`zk-verdict/contracts/tempo.json`](../../zk-verdict/contracts/tempo.json) · re-derived from the chain by `zk-verdict/scripts/tempo-verify.sh` |
| **each fee paid in the same stablecoin the escrow held** | the receipts' own `feeToken` field — T-4 in 011 §10, and the live page reads it in the visitor's browser: [`docs/tempo.html`](../tempo.html) §4 |
| the work is on Solana and the proof is about that work | the SVM guest and its fixtures — `zk-verdict/program-svm`, `svm-groth16-fixture.json` / `svm-failed-fixture.json`, exercised by `RecknSvmVerdict.t.sol` and `RecknCrossVmSettlement.t.sol` |
| replayed in a zkVM against a **committed** prestate | [`docs/reexec-evm-mpt-verification.md`](../reexec-evm-mpt-verification.md) (EVM side, MPT-verified) · [`docs/svm-snapshot-authenticity.md`](../svm-snapshot-authenticity.md) (SVM side, and its limit) |
| deterministic state transitions · replayable scenarios · pinned execution environments | `reexec-evm/` and the engine-identity work in [`docs/specs/008-verdict-domain-soundness.md`](../specs/008-verdict-domain-soundness.md): the hardfork and block environment are **committed and checked**, not assumed |
| **Tempo Evals is a real, citable thing** — and what it is | <https://github.com/tempoxyz/tempo-evals>, read 2026-09-12: *"Evaluation harnesses for agents building on Tempo and related protocols, powered by Harbor"*, suites including *"TypeScript integrations that submit and verify Tempo testnet transactions"*, graded by a verifier that *"deterministically checks the submission"*. Apache-2.0 / MIT |
| the whole gate for this slice | `bash zk-verdict/scripts/ac011.sh --all` → **8/8 rows**, four of them reading the live chain (measured 2026-09-12) |

---

## Audit — what these words may mean, and what they may not

### May be said

- **"Its deterministic-execution design grew out of our work on RDK."** A statement about
  *where the design knowledge came from*. Reckn's own EVM stack is **`revm 38` + `alloy`**
  (`reexec-evm/Cargo.toml`, `zk-verdict/program-revm/Cargo.toml`).
- **"Tempo Evals verifies that an agent can correctly integrate and operate on Tempo."**
  Grounded in the repository itself (quotes in the table above). **Name the tool, not the chain:**
  the chain does not adjudicate anyone's commerce, and an evaluation harness does not decide a
  payment — a sentence whose subject is "Tempo" blurs both.
- **"Reckn verifies whether that agent's committed delivery earned the payment."** A statement
  about **layers**, which is what `docs/positioning.md` is for. *Committed* is load-bearing: the
  delivery, the prestate and the predicate are fixed at funding, so a dispute cannot be invented
  afterwards.
- **"Tempo makes agent payments operable and evaluable; Reckn makes high-stakes agent payments
  accountable."** Positioning, and the only word in it to watch is *high-stakes* — it describes
  which payments are worth adjudicating, not a threshold the protocol enforces.
- **"Live on Tempo Moderato testnet."** Testnet, named as testnet, every time.

### Must not be said

- **Not "Reckn reuses RDK's re-execution code."** It does not. The MPT witness path, the
  closed-world replay, the zkVM guests and the Solana backend are Reckn's own implementation.
- **Not "built on Reth."** Reckn has **no `reth` dependency** — `reth-trie` was explicitly
  declined so that an offline verifier would not pull in a node's database layer
  (`docs/reexec-evm-mpt-verification.md` § Decision). RDK's stack is not Reckn's dependency list.
- **Not "Reckn is integrated with Tempo Evals"**, and not "Reckn settles on an Evals / Harbor /
  RewardKit score." There is **no such integration**: Reckn deploys to Tempo as an ordinary EVM
  contract and reads **nothing** from any of them. The accurate form is *the same agentic commerce
  stack, with the evaluation layer and the settlement layer each doing its own job*.
- **Not endorsement, and not membership.** Reckn is not part of Tempo Evals, is not a suite in it,
  and has not been evaluated by it. Citing a public repository is not a relationship.
- **The deterministic-verifier parallel is an observation, not a joint design.** Evals grades with
  a verifier rather than a judge and says *"RewardKit quality signals are reported separately and
  cannot replace functional correctness."* Reckn is that principle applied to money. Say *we
  noticed*; never say *we built this together* or imply Tempo has said anything about Reckn.
- **Not "Tempo verifies Solana."** Tempo runs no Solana VM and inspects no Solana state.
- **Not "no bridge is needed, therefore the Solana state is proven."** The two are unrelated.
  The guest recomputes a `bank_hash` over **the account set the deal named** — consistency, not
  provenance. It does **not** establish that those inputs came from Solana mainnet.
- **Not "the same demo, on two chains."** Arc and Tempo settled **their own** deals. What is
  byte-identical and gated is the escrow **source** (`tempo-arc-parity.sh`).
- **Not a sentence that merges the two refunds.** The refund in the pitch is the
  **proof-driven** one and it is immediate. `refundAfterDeadline` waits thirty days.

### ~~One sentence that needs a citation~~ — closed the same day, and the record is the point

This section read: *"Tempo verifies that an agent can operate" ... a fetch of
tempo.xyz/developers/docs found no page named agent evaluation or agent verification, so in
writing it asserts a product surface this project cannot cite.*

**The citation arrived** (founder, 2026-09-12): `tempoxyz/tempo-evals`, quoted in the table above.
Two things changed, and only one of them is the citation.

1. The sentence was **not** simply unlocked — its **subject was wrong**. It is **Tempo Evals**
   that verifies an agent's integration, not *Tempo*. The chain does not adjudicate commerce and
   the harness does not decide payments; the blurred subject would have been the over-claim even
   with a citation in hand.
2. What the harness does made the positioning **stronger, not just permissible**: it grades with a
   deterministic verifier and says quality signals cannot replace functional correctness. The
   nearest layer to Reckn had already reached for the same principle.

**Kept rather than deleted** because the failure mode is the reusable part: the first draft
reached for the sharpest available sentence and could not name what it was about.

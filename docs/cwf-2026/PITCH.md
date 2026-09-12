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
> payment adjudicator. Tempo helps verify that agents can build and operate payment
> integrations correctly; Reckn complements that layer by making the payment itself conditional
> on a verifiable result. Live on Tempo Moderato testnet: one proof-driven release, one refund,
> each fee paid in the same stablecoin the escrow held.

**Two shorter forms, for speech.** Both are in
[`docs/messaging.md`](../messaging.md#rdk-lineage-and-the-tempo-complement--approved-wording)
with their limits:

> **"Tempo verifies that an agent can operate. Reckn verifies whether an agent earned the
> payment."**

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
| the whole gate for this slice | `bash zk-verdict/scripts/ac011.sh --all` → **8/8 rows**, four of them reading the live chain (measured 2026-09-12) |

---

## Audit — what these words may mean, and what they may not

### May be said

- **"Its deterministic-execution design grew out of our work on RDK."** A statement about
  *where the design knowledge came from*. Reckn's own EVM stack is **`revm 38` + `alloy`**
  (`reexec-evm/Cargo.toml`, `zk-verdict/program-revm/Cargo.toml`).
- **"Tempo helps verify that agents can build and operate payment integrations correctly."**
  Grounded in Tempo's own developer material: *"Give coding agents Tempo docs, source context,
  MCP tools, and agent workflow plugins"* (`/developers/docs/guide/using-tempo-with-ai`) and
  the Machine Payments Protocol (`/developers/docs/guide/machine-payments`), read 2026-09-12.
- **"Reckn complements that layer by making the payment itself conditional on a verifiable
  result."** A statement about **layers**, which is what `docs/positioning.md` is for.
- **"Live on Tempo Moderato testnet."** Testnet, named as testnet, every time.

### Must not be said

- **Not "Reckn reuses RDK's re-execution code."** It does not. The MPT witness path, the
  closed-world replay, the zkVM guests and the Solana backend are Reckn's own implementation.
- **Not "built on Reth."** Reckn has **no `reth` dependency** — `reth-trie` was explicitly
  declined so that an offline verifier would not pull in a node's database layer
  (`docs/reexec-evm-mpt-verification.md` § Decision). RDK's stack is not Reckn's dependency list.
- **Not "Reckn is integrated with Tempo's agent tooling"**, and not "Reckn consumes Tempo's
  evaluation results on chain." There is **no integration between the two layers**: Reckn
  deploys to Tempo as an ordinary EVM contract and reads nothing from Tempo's developer tooling.
- **Not "Tempo verifies Solana."** Tempo runs no Solana VM and inspects no Solana state.
- **Not "no bridge is needed, therefore the Solana state is proven."** The two are unrelated.
  The guest recomputes a `bank_hash` over **the account set the deal named** — consistency, not
  provenance. It does **not** establish that those inputs came from Solana mainnet.
- **Not "the same demo, on two chains."** Arc and Tempo settled **their own** deals. What is
  byte-identical and gated is the escrow **source** (`tempo-arc-parity.sh`).
- **Not a sentence that merges the two refunds.** The refund in the pitch is the
  **proof-driven** one and it is immediate. `refundAfterDeadline` waits thirty days.

### One sentence that needs a citation before it goes in public copy

**"Tempo verifies that an agent can operate."** The layer contrast is fair and it is the
sharpest line available, but a fetch of `tempo.xyz/developers/docs` on 2026-09-12 found
*Agentic Payments* and *Use Tempo with AI* and **no page named agent evaluation or agent
verification**. So in writing, prefer the longer form above, which maps onto pages that exist.
Use the short form in speech, or cite the page once Tempo publishes one.

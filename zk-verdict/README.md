# zk-verdict — a ZK-proven reckn verdict (SP1 PoC)

The path to **zero-trust** adjudication. Reckn's optimistic settlement + quorum
slashing reduce trust to an *honest-majority resolver quorum*; full zero-trust —
deciding a verdict on-chain with **no** trusted party — needs either a fraud-proof VM
or a **ZK proof of the re-execution**. This is a working proof-of-concept of the ZK
path, run end-to-end on CPU.

**Three guests, one on-chain verifier.** Each commits the identical
`VerdictPublicValues`, so a single generic [`RecknVerdictVerifier`](contracts/src/RecknVerdictVerifier.sol)
verifies all of them (only the program vkey differs):

1. **`program/`** — the causal-delta *predicate* verdict (trusts `pre`/`post`; the
   toolchain baseline). *What it proves*, below.
2. **`program-revm/`** — **full EVM re-execution**: MPT-verifies the prestate against
   the committed `state_root`, then runs **real `revm` in-guest** to derive `post`.
   Closes the trusted-prestate *and* trusted-`post` gaps for the EVM.
3. **`program-svm/`** — the **Solana mirror**: recomputes the block `bank_hash` from
   the committed accounts, signature-verifies the real transaction, and re-executes
   its System transfer in-guest. Same two gaps closed on Solana.

So a reckn verdict — on either VM, against a cryptographically authenticated prestate
— is provable in a zkVM and verified on-chain with no trusted resolver. The sections
below go predicate → EVM → SVM → settlement.

**Run the whole path in one command:**

```sh
bash scripts/zk-e2e.sh
```

It re-executes both VMs in the zkVM (live, if the SP1 toolchain is installed; a
tampered prestate is rejected), then verifies the **real Groth16 proofs on-chain** and
**settles the escrow to the seller** on the proof alone — using committed fixtures, so
the on-chain half runs with just `forge`. `ZK_FRESH=1` regenerates a fresh proof.

## What it proves (the predicate guest)

The guest ([`program/`](program/src/main.rs)) runs reckn's **causal delta
predicate** — the `LamportsDelta` / `PostStateDelta` verdict (the no-op-can't-fake
soundness mechanism): the credited increase `post − pre` (saturating) must lie in
`[min, max]`, else `Failed`. It commits the committed inputs plus the proven
outputs (`outcome`, canonical `traceHash`) as public values. The SP1 proof attests
those outputs were derived correctly from the inputs — so the **verdict
derivation** needs no trusted resolver: anyone verifies a succinct proof instead
of re-running the engine or trusting a signer's ECDSA/Ed25519.

```sh
cd script
cargo run --release --bin verdict -- --execute            # run the guest, print verdict + cycles
SP1_PROVER=cpu cargo run --release --bin verdict -- --prove  # generate AND verify a real ZK proof
# defaults: pre=42 post=142 min=100  → credited 100 clears the floor → Reproduced
# --pre 42 --post 42 --min 1  → the no-op attack: credits 0, Failed (proven)
```

Verified locally: `--execute` reports 30,355 cycles and the guest output matches
the host computation; `--prove` generates a core proof and **verifies it**.

## On-chain verification (the trustless cross-chain settlement primitive)

A verdict is only a settlement primitive if *any* chain can check it **itself** —
no bridge, no light client, no trusted relayer. That is what a self-verifying ZK
proof gives us: [`contracts/src/RecknVerdictVerifier.sol`](contracts/src/RecknVerdictVerifier.sol)
verifies an SP1 Groth16 proof on-chain against the program's verification key and
exposes the committed verdict (`outcome`, `traceHash`). The verdict is
authoritative because **the proof verifies**, not because a signer is on an
allow-list — so a paying chain A can settle on a verdict about work on chain B by
verifying this proof directly. Reckn's core function (verdict authority) crosses
chains trustlessly; value transfer (A→B) is left to an existing bridge.

```sh
cd contracts
forge install foundry-rs/forge-std --no-git
# the SP1 verifier contracts (matching circuit v6.1.0) — see remappings.txt
forge test                                    # wiring tests (mock verifier) — always run
```

Two test suites:

- **`RecknVerdictVerifier.t.sol`** — the wiring, with a mocked verifier: a valid
  proof exposes the ZK-attested verdict; an invalid proof reverts (no unproven
  verdict settles). Always runs.
- **`RecknVerdictVerifierFixture.t.sol`** — end-to-end against SP1's **real**
  Groth16 verifier (`SP1Verifier`, circuit **v6.1.0** — the exact version this
  `sp1-sdk` produces). It consumes a real proof and asserts it verifies on-chain
  and that tampered public values are rejected. Gated on the fixture's presence.

Generate the real proof + fixture to exercise that second suite:

```sh
cd script
SP1_PROVER=cpu cargo run --release --bin evm -- --pre 42 --post 142 --min 100
# writes contracts/src/fixtures/groth16-fixture.json, then `forge test` verifies it on-chain
```

**What was run here — a real proof, verified on-chain.** A **real Groth16 proof**
of the verdict was generated on CPU (the gnark prover, ~15.9M constraints, ~34 s
for the gnark wrap alone once the artifacts are local — the end-to-end regeneration
of one fixture was measured at 335 s, so read the figure narrowly) and checked against SP1's **real** `SP1Verifier`
(circuit v6.1.0) inside `RecknVerdictVerifierFixture.t.sol` — it verifies on-chain
and a tampered public-values variant reverts. The fixture is committed at
[`contracts/src/fixtures/groth16-fixture.json`](contracts/src/fixtures/groth16-fixture.json)
(vkey `0x00cee7dc…`, outcome `Reproduced`, credited delta 100 ∈ [100, MAX]). Both
the wiring suite (mock verifier) and the real-verifier suite are green.

The only heavy prerequisite is SP1's ~6.2 GB v6.1.0 gnark circuit artifacts (the
wrapping circuit's proving key), fetched once into `~/.sp1/circuits/groth16/v6.1.0`
— inherent to SP1's Groth16 path, not a reckn choice. The fixtures are committed, and
**a missing fixture is a hard failure**: the suites used to return early when one was
absent, which made `forge test` green for a run that verified nothing. They `require`
the fixture now, so a deleted or unregenerated fixture is a red test rather than a
quiet pass.

## Full re-execution in the guest (the trusted-prestate AND trusted-`post` gaps, closed)

The predicate guest above trusts `post` as an input — someone still runs the EVM
off-chain to produce it. The **re-execution guest** ([`program-revm/`](program-revm/src/main.rs))
removes that trust at both ends. It (1) **verifies the committed prestate is
authentic** — each account is MPT-proven against the committed `state_root` and each
storage slot against the proven account storage root, exactly as
`reexec-evm::verify_witness_against_root` does off-chain — then (2) runs **real
`revm` inside the zkVM**, **executes the seller's committed CALL under proof**, reads
the resulting post-state, and applies the causal delta predicate. So the prestate is
*proven authentic* and `post` is *computed by the EVM* — both inside the proof, not
supplied by a resolver. The verdict's trace hash binds the `state_root`, so the proof
is about a **specific authenticated state**.

```sh
cd script
cargo run --release --bin reexec -- --execute   # verify prestate + run revm in-guest; print verdict + cycles
cargo run --release --bin reexec -- --prove      # generate AND verify a core proof
cargo run --release --bin reexec -- --fixture    # real Groth16 proof -> on-chain fixture
cargo run --release --bin reexec -- --execute --tamper  # corrupt a proven slot -> guest REJECTS it
# default: prestate slot7 = 42 (MPT-proven), plan SSTORE(slot7, 142) -> post EXECUTED
#          to 142, delta 100 >= floor 100 -> Reproduced.  --credit 42 -> delta 0 -> Failed.
```

Verified end-to-end:

- **`revm` 38 and `alloy-trie` compile to the SP1 zkVM target**
  (`riscv64im-succinct-zkvm-elf`) once revm's default features (C-based
  `c-kzg`/`secp256k1` precompiles) are dropped.
- The guest **MPT-verifies the prestate then executes the SSTORE CALL**: slot 7 = 42
  is proven against `state_root`, `post` is derived as 142 by execution (not given),
  the credited delta 100 clears the floor → `Reproduced` (**406,715 cycles**, measured
  2026-09-05, `cycles.json`). A no-op (`--credit 42`) → delta 0 → `Failed`.
- **`--tamper`** flips a proven slot value: the guest **panics with `storage proof
  invalid` — a verdict cannot be produced for an inauthentic prestate.** That is the
  authenticity soundness: a valid proof can only exist for a prestate that matches
  the committed `state_root`.
- The host builds the exact witness + Merkle proofs via **`reexec-evm`'s testkit**,
  so the guest verifies the same proof format the production backend emits.
- A **real Groth16 proof** verifies **on-chain** against SP1's `SP1Verifier` (v6.1.0)
  via the **same generic `RecknVerdictVerifier`** (only the vkey differs, because the
  guest commits the identical `VerdictPublicValues`) — `RecknReexecVerdict.t.sol`.

### Honest scope of the re-execution guest

- **Is** the actual `revm` EVM executing a real CALL against an **MPT-authenticated
  prestate**, under proof — not a toy interpreter, not a trusted prestate. Both the
  trusted-prestate and trusted-`post` gaps are genuinely closed for that execution.
- **Verdict values are `uint256`.** The whole 256-bit domain is judged, in-guest and
  off-chain, by the same function of the same committed bytes (task 008). The earlier
  `u64` map was not a limit but a soundness bug: a decrease across limb 0 proved as the
  largest possible credit.
- **Engine identity is checked, not assumed.** The guest executes the committed CALL
  **at the committed hardfork and block environment** — spec id, `TIMESTAMP`, `NUMBER`,
  `COINBASE`, `PREVRANDAO`, `GASLIMIT`, `CHAINID`, `BASEFEE` — and every one of those
  fields is committed by `dealBinding`, so a proof cannot be moved from the environment
  it was produced in to another one.
- **Not yet:** (a) the `c-kzg`/`ecrecover` precompiles are **not** disabled in-guest —
  `revm-precompile` falls back to pure-Rust backends (`k256`, `arkworks`) when the
  native features are off — but the guest and the off-chain engine therefore run
  *different implementations* of them and equivalence has never been checked. (b) One
  CALL + one delta check; a full block or arbitrary contract set is more cycles, same
  architecture. (c) The `state_root`↔block binding (header proof) stays the off-chain
  `reexec-evm::header` layer.
- **The predicate is a floor, and a floor of zero is satisfied by doing nothing.**
  `minDelta = 0` accepts a no-op as `Reproduced`, because nothing is below zero. That
  is the predicate working as specified, not a bug — but a buyer who funds a deal with
  a zero floor has bought nothing, and the escrow will pay the seller for it.

## SVM re-execution in the guest (the Solana mirror)

reckn's Solana backend adjudicates **System-program transactions only** (its closed
runtime profile permits just the System builtin — no custom SBF). The **SVM guest**
([`program-svm/`](program-svm/src/main.rs)) mirrors the EVM one under proof, closing
both authenticity gaps: it (1) **recomputes the block `bank_hash`** from the committed
accounts (SIMD-0215 accounts lattice hash) and requires it to match the committed one,
(2) **signature-verifies the real committed Solana transaction** in-guest
(`Transaction::verify`, real ed25519), (3) **re-executes the System transfer** against
the authenticated prestate to derive the post-lamports, and (4) applies reckn's causal
`LamportsDelta`. So the prestate is *proven authentic* and `post` is *computed by
re-execution* — both under proof, not trusted.

```sh
cd script
cargo run --release --bin svm -- --execute   # bank_hash + sigverify + re-execute; verdict + cycles
cargo run --release --bin svm -- --fixture    # real Groth16 proof -> on-chain fixture
cargo run --release --bin svm -- --execute --amount 500000       # below floor -> Failed
cargo run --release --bin svm -- --execute --tamper              # bad signature -> verify fails -> Failed
cargo run --release --bin svm -- --execute --tamper-prestate     # account != bank_hash -> guest REJECTS
```

Verified end-to-end:

- **The real Solana data crates + `solana-lattice-hash` compile to the SP1 zkVM
  target** (`solana-transaction` with `verify`, `solana-account`, `solana-message`, …).
- The guest **recomputes `bank_hash`, verifies signatures, and re-executes**
  `System::Transfer(2_000_000)`: the recipient is `bank_hash`-bound at pre = 1 →
  **post EXECUTED to 2_000_001** → credited delta 2_000_000 ≥ floor → `Reproduced`
  (**986,097 cycles**: ed25519 sigverify + the lattice recompute). Below the floor →
  `Failed`.
- **`--tamper`** zeroes the signature → in-guest `Transaction::verify` rejects it →
  `Failed`. **`--tamper-prestate`** perturbs a committed account so it no longer
  reproduces `bank_hash` → the guest **panics on the authenticity check** — no verdict
  for an inauthentic account set. Both authenticity layers are independent and
  load-bearing.
- The `bank_hash` recompute is **byte-identical to `reexec-svm::bankhash`** (shared
  `svm-bankhash` crate: same SIMD-0215 field order, same lattice primitive), so the
  guest verifies exactly what the off-chain backend computes.
- A **real Groth16 proof** of the SVM re-execution verifies **on-chain** through the
  **same generic `RecknVerdictVerifier`** — `RecknSvmVerdict.t.sol`. One verdict
  contract, one `VerdictPublicValues` record, **EVM and SVM proofs alike**.

### Honest scope of the SVM guest

- **Is** the real Solana transaction, signature-verified in-guest, with its System
  transfer re-executed under proof against a **`bank_hash`-authenticated prestate** —
  the operation reckn's SVM backend actually adjudicates, with the same authenticity
  check. Both the trusted-prestate and trusted-`post` gaps are closed.
- **Not:** the full Agave/LiteSVM runtime (JIT/OS-bound, out of scope in-zk — and
  unnecessary, since reckn permits only the System builtin) and **not** custom SBF
  bytecode execution (reckn runs none). **Not yet:** the `bank_hash` check is
  conclusive only over a *complete* account set — the demo treats its committed set as
  the world (as reckn's `bankhash` tests do); binding a *compact* prestate as a subset
  of a full snapshot is `reexec-svm`'s separate `authenticity` layer. Payer-side fee
  modeling (the recipient-delta demo doesn't need it) and `u64` verdict values remain.

## Settlement — the proof moves money ([`RecknZkEscrow`](contracts/src/RecknZkEscrow.sol))

Verifying a verdict is not the point; *settling* on it is. [`RecknZkEscrow`](contracts/src/RecknZkEscrow.sol)
holds a payment and releases it **purely on a ZK-verified verdict — no resolver**.
The binding that makes this sound: each re-execution guest commits a `dealBinding`
in its public values — a hash over its **authenticated prestate + predicate + plan**
(EVM: `state_root ‖ target ‖ slot ‖ min ‖ max ‖ keccak(plan)`; SVM: `bank_hash ‖
account ‖ min ‖ max ‖ signature`). A deal commits that same `dealBinding` at funding,
and `settleWithProof` verifies the SP1 proof via `RecknVerdictVerifier` and requires
the binding to match before paying out — so a proof from some *other* favorable
execution cannot settle this deal.

- `fund(dealId, seller, token, amount, dealBinding)` — buyer escrows the payment.
- `settleWithProof(dealId, publicValues, proofBytes)` — **permissionless**: the proof
  carries its own authority. `Reproduced` → release to the seller; `Failed` → refund
  the buyer.

Tested (`RecknZkEscrow.t.sol`): a **real Groth16 proof** of the EVM re-execution
(`Reproduced`) **settles to the seller** on SP1's real verifier; a `Failed` verdict
refunds the buyer; a **binding mismatch** and an **unverified proof** both revert.
This is the endgame the earlier pieces pointed at: settlement authority from a proof
that verifies, chain-agnostic, with no trusted resolver.

This is a nested SP1 workspace, independent of the main reckn crates' build.

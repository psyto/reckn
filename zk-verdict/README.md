# zk-verdict — a ZK-proven reckn verdict (SP1 PoC)

The honest first step toward **zero-trust** adjudication. Reckn's optimistic
settlement + quorum slashing reduce trust to an *honest-majority resolver quorum*;
full zero-trust — deciding a verdict on-chain with **no** trusted party — needs
either a fraud-proof VM or a **ZK proof of the re-execution**. This is a working
proof-of-concept of the ZK path, run end-to-end on CPU.

## What it proves

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

Verified locally: `--execute` reports ~21.7k cycles and the guest output matches
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
once the artifacts are local) and checked against SP1's **real** `SP1Verifier`
(circuit v6.1.0) inside `RecknVerdictVerifierFixture.t.sol` — it verifies on-chain
and a tampered public-values variant reverts. The fixture is committed at
[`contracts/src/fixtures/groth16-fixture.json`](contracts/src/fixtures/groth16-fixture.json)
(vkey `0x00cee7dc…`, outcome `Reproduced`, credited delta 100 ∈ [100, MAX]). Both
the wiring suite (mock verifier) and the real-verifier suite are green.

The only heavy prerequisite is SP1's ~6.2 GB v6.1.0 gnark circuit artifacts (the
wrapping circuit's proving key), fetched once into `~/.sp1/circuits/groth16/v6.1.0`
— inherent to SP1's Groth16 path, not a reckn choice. `RecknVerdictVerifierFixture.t.sol`
stays gated on the fixture's presence, so `forge test` is green for anyone who
hasn't regenerated it.

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
  the credited delta 100 clears the floor → `Reproduced` (~**382k cycles**, of which
  MPT verification is ~180k). A no-op (`--credit 42`) → delta 0 → `Failed`.
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
- **Not yet:** (a) the `c-kzg`/`ecrecover` precompiles are disabled, so plans needing
  them aren't supported until SP1's patched crypto is wired in. (b) Verdict values map
  to `u64` to reuse the on-chain ABI. (c) One CALL + one delta check; a full block or
  arbitrary contract set is more cycles, same architecture. (d) The `state_root`↔block
  binding (header proof) stays the off-chain `reexec-evm::header` layer.

## SVM re-execution in the guest (the Solana mirror)

reckn's Solana backend adjudicates **System-program transactions only** (its closed
runtime profile permits just the System builtin — no custom SBF). The **SVM guest**
([`program-svm/`](program-svm/src/main.rs)) mirrors the EVM one under proof: it (1)
**signature-verifies the real committed Solana transaction** in-guest
(`Transaction::verify`, real ed25519), (2) **re-executes the System transfer** against
the committed prestate accounts to derive the post-lamports, and (3) applies reckn's
causal `LamportsDelta`. So `post` is *computed by re-executing the transfer under
proof*, not trusted.

```sh
cd script
cargo run --release --bin svm -- --execute   # sigverify + re-execute; print verdict + cycles
cargo run --release --bin svm -- --fixture    # real Groth16 proof -> on-chain fixture
cargo run --release --bin svm -- --execute --amount 500000  # below floor -> Failed
cargo run --release --bin svm -- --execute --tamper         # bad signature -> verify fails -> Failed
```

Verified end-to-end:

- **The real Solana data crates compile to the SP1 zkVM target** (`solana-transaction`
  with `verify`, `solana-account`, `solana-message`, …).
- The guest **verifies signatures and re-executes** `System::Transfer(2_000_000)`:
  recipient pre = 1 → **post EXECUTED to 2_000_001** (not given) → credited delta
  2_000_000 ≥ floor → `Reproduced` (~**762k cycles**, dominated by ed25519 sigverify).
  A transfer below the floor → `Failed`.
- **`--tamper`** zeroes the signature: the in-guest `Transaction::verify` rejects it →
  no transfer applied → `Failed`. A forged/invalid signature can never yield
  `Reproduced` — the sigverify is real and load-bearing.
- A **real Groth16 proof** of the SVM re-execution verifies **on-chain** through the
  **same generic `RecknVerdictVerifier`** — `RecknSvmVerdict.t.sol`. One verdict
  contract, one `VerdictPublicValues` record, **EVM and SVM proofs alike**.

### Honest scope of the SVM guest

- **Is** the real Solana transaction, signature-verified in-guest, with its System
  transfer re-executed under proof — the operation reckn's SVM backend actually
  adjudicates.
- **Not:** the full Agave/LiteSVM runtime (JIT/OS-bound, out of scope in-zk — and
  unnecessary, since reckn permits only the System builtin) and **not** custom SBF
  bytecode execution (reckn runs none). **Not yet:** prestate **`bank_hash`
  authenticity** in-guest (the SVM analogue of the EVM MPT check — reckn's
  `reexec-svm::bankhash` does it off-chain; the follow-up), fee modeling on the payer
  side (the recipient-delta demo doesn't need it), and `u64` verdict values.

This is a nested SP1 workspace, independent of the main reckn crates' build.

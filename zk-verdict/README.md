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

## Honest scope (what this is and isn't)

- **Is:** a genuine, runnable ZK proof of reckn's *verdict/predicate computation*,
  reusing the exact delta logic and a domain-tagged `traceHash` mirroring
  `ReplayRecordV1`. The soundness property (a no-op plan cannot forge a credit) is
  now proven in zero-knowledge, not merely signed.
- **Isn't:** a proof of the full **re-execution** that *produces* `post`. Running
  the whole revm / SBF engine inside the zkVM (a zkEVM-scale guest) and proving a
  realistic plan needs GPU proving and substantial engine-in-guest work — the
  documented frontier. This PoC proves the last mile (predicate → verdict) and
  establishes the toolchain end-to-end on CPU.
- The on-chain verifier contract is **done and tested with a real Groth16 proof**
  verified against SP1's canonical `SP1Verifier` (circuit v6.1.0) — see *On-chain
  verification* above. This is still the last-mile predicate→verdict proof, not the
  full re-execution.

This is a nested SP1 workspace, independent of the main reckn crates' build.

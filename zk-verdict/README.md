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
- The EVM-verifiable (Groth16) wrapper + on-chain verifier contract are a further
  step (SP1 supports them; they need ≥16GB RAM / heavier proving).

This is a nested SP1 workspace, independent of the main reckn crates' build.

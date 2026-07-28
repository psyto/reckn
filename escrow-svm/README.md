# Reckn SVM escrow

Pinocchio implementation of Reckn's SVM settlement state machine:
`Held -> Delivered -> Disputed -> Resolved`.

The program accepts only content commitments. It does not execute the replay
engine and it has no `OperationalError` settlement path. A verifier that cannot
produce either `Reproduced` or `Failed` leaves the deal disputed; after the
absolute `resolve_deadline` anyone may invoke `timeout_refund` to return the
vault balance to the buyer.

## Settlement boundary

`resolve` requires the immediately preceding instruction to be Solana's native
Ed25519 precompile with exactly one self-contained signature. The signed bytes
are:

`"reckn/svm/verdict/v1" || cluster_genesis_hash || program_id || deal_id || VerdictCommitment`

`VerdictCommitment` re-commits the deal id, spec, delivery, anchor, backend,
backend version, runtime profile, prestate root, outcome, result hash, and
trace hash. The program additionally compares every committed deal field and
the ResolverConfig allowlist before transferring SPL Token-2022 funds.

`Reproduced` transfers the entire vault to the seller; `Failed` transfers it to
the buyer. An emitted `ReputationEvidence` log records the outcome, trace hash,
resolver, and settlement slot without affecting the transfer decision.

The vault is a pre-created initialized Token-2022 account whose authority is
the deal PDA. This keeps `fund` deterministic and lets callers choose an ATA
or a dedicated PDA vault, provided it is empty and has the exact mint/owner.

## Build and test

```sh
cargo build-sbf --manifest-path escrow-svm/Cargo.toml
cargo test --manifest-path escrow-svm/Cargo.toml --test e2e
```

The LiteSVM tests exercise release, refund, bad Ed25519 bytes, substituted
anchor, rejected operational outcome, timeout, double resolution, and token
conservation.

# SVM snapshot authenticity

The EVM backend proves its prestate is real: every account and storage slot in
the replay witness is MPT-verified against `anchor.state_root`, a field of a real
block header (see [`reexec-evm-mpt-verification.md`](reexec-evm-mpt-verification.md)).
A tampered witness is an `OperationalError`, never a verdict.

The SVM backend needs the same guarantee, and the shape of the problem is
different enough to be worth stating precisely.

## The gap this closes

`reexec-svm` commits the prestate snapshot and checks it against
`anchor.state_commitment` (a reckn-internal SHA-256 over the accounts + runtime
profile). That binds the *replay* to a specific account set — but it says nothing
about whether that account set is the **real Solana state**. The anchor also
carries `bank_hash` and `snapshot_archive_hash`, and until now those were
**carried but never verified**: anyone could commit an arbitrary account set with
an arbitrary `bank_hash`. The field was decorative.

## Why SVM ≠ EVM here (no compact per-account proof)

On Ethereum you can prove a *single* account/slot against `state_root` with a
compact Merkle-Patricia path. Solana has no equivalent for arbitrary accounts:

- Post-[SIMD-0215](https://github.com/solana-foundation/solana-improvement-documents/blob/main/proposals/0215-accounts-lattice-hash.md),
  the block `bank_hash` mixes in `accounts_lt_hash` — a **homomorphic** hash over
  **every** account. It commits to the whole state at once; there is no inclusion
  path for one account.
- The per-slot `accounts_delta_hash` is a 16-ary Merkle over only the accounts
  **modified in that slot**. Compact inclusion proofs exist there — but a
  checkpoint prestate account (an existing, unmodified account) is not in it.
  Getting an arbitrary account into a slot's delta tree requires forcing a write
  to it in that slot (the Sovereign-Labs "copy-on-chain" trick), which is outside
  reckn's dispute flow.

So the sound way to authenticate an account set against `bank_hash` is exactly
what the code comment used to defer to an "external Bank-snapshot verifier":
**recompute the accounts lattice hash over the set and re-derive `bank_hash`.**

## What is implemented ([`reexec-svm/src/bankhash.rs`](../reexec-svm/src/bankhash.rs))

The verifier, built on the audited [`solana-lattice-hash`] crate for the lattice
primitive:

- `account_lt_hash(acct)` — the SIMD-0215 per-account contribution: a blake3 XOF
  (2048 bytes) over `lamports` (u64 LE) ‖ `data` ‖ `executable` (1 byte) ‖
  `owner` (32) ‖ `pubkey` (32); `rent_epoch` is excluded; a zero-lamport account
  contributes the lattice identity.
- `accounts_lt_hash(snapshot)` — the homomorphic (order-independent) sum.
- `bank_hash(preimage, checksum)` — `sha256(parent_bank_hash ‖ lt_checksum ‖
  signature_count(u64 LE) ‖ last_blockhash)`; Solana `Hash::hashv` is SHA-256, and
  post-SIMD-0215 the lattice-hash checksum occupies the slot the
  `accounts_delta_hash` held.
- `verify_snapshot_against_bank_hash(snapshot, preimage, expected)` — recompute
  and compare.

It is **load-bearing** in `replay`: `SvmAnchorV2` gained `parent_bank_hash`,
`signature_count`, and a `snapshot_is_complete` flag. When that flag is set,
`replay` verifies the snapshot reproduces `bank_hash` and returns
`OperationalError::BankHashMismatch` on failure — an operational error, never a
`Failed`/`Reproduced` verdict, mirroring the EVM witness check.

Version note: the `bank_hash` combination is pinned to the post-SIMD-0215 rule. A
verifier is therefore pinned to a cluster/epoch's active features; that is
inherent to re-deriving a consensus hash and is called out here rather than
hidden.

## The completeness boundary and the compact binding

An `accounts_lt_hash` commits to the **complete** account set, so the recompute is
conclusive only over a complete set. reckn's dispute path replays a **compact**
prestate (just the accounts a transaction touches), which cannot reproduce
`bank_hash` on its own. Two paths make that sound:

- **Complete snapshot** (`snapshot_is_complete = true`): `bank_hash` is verified
  directly in `replay`.
- **Compact prestate** (the normal dispute flow): authenticity binds
  *transitively* to a full snapshot, via
  [`authenticity.rs`](../reexec-svm/src/authenticity.rs). Given a
  [`FullSnapshotV1`], `verify_prestate_authenticity` checks, in one call:
  1. `full_snapshot_commitment(full) == snapshot_archive_hash` — the full
     snapshot is the one the anchor commits to;
  2. `verify_accounts_against_bank_hash(full, …)` — the full snapshot reproduces
     `bank_hash` (it is authentic); and
  3. `verify_prestate_subset(compact, full)` — every compact account is a faithful
     copy of the full snapshot's value for that pubkey.

  Then the compact prestate is authentic **without** a per-account inclusion proof
  (which Solana does not offer). The binding logic and all its failure modes
  (tampered/absent compact account, wrong archive commitment, an archive that does
  not reproduce `bank_hash`) are tested in that module.

## Keeper wiring (implemented)

The binding is **enforced in the dispute path**. `load_for_disputed_deal`
(`reckn-svm-keeper`) resolves content by hash from `FileContentStore`. The anchor
gained an optional `full_snapshot_hash`; when it is set, the keeper loads the
`StoredFullSnapshotV1` it content-addresses (so the load *is* the archive
commitment), then enforces `verify_accounts_against_bank_hash(full, preimage,
bank_hash)` and `verify_prestate_subset(compact, full)` **before any replay**,
returning `KeeperError::SnapshotAuthenticity` on failure — no signed verdict, just
like `Operational`. Because `replay_disputed` and the keyless `verify` both go
through this load, both the resolver and an independent verifier reject an
unauthentic prestate. When `full_snapshot_hash` is zero the check is skipped
(back-compat), and authenticity rests on an external binding.

## Remaining stages

1. **Agave archive ingestion** — produce a [`FullSnapshotV1`] /
   `StoredFullSnapshotV1` from a real Agave snapshot archive (the `.tar.zst`
   account-vec format) so the full snapshot is sourced from a validator snapshot
   rather than reconstructed. This is the one external dependency left; the
   binding it feeds and the keeper enforcement are done.
2. **Preimage sourcing** — populate `parent_bank_hash` / `signature_count` from
   the block/checkpoint rather than trusting anchor input.
3. **Feature/epoch pinning** — carry the active-feature set so the `bank_hash`
   rule is selected correctly across the delta-hash → lattice-hash transition.

The cryptographic binding is complete and tested, and it is enforced in the
dispute path; what remains is archive ingestion and preimage sourcing, not
soundness.

[`FullSnapshotV1`]: ../reexec-svm/src/authenticity.rs

[`solana-lattice-hash`]: https://crates.io/crates/solana-lattice-hash

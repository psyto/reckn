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

## The completeness boundary (honest scope)

An `accounts_lt_hash` commits to the **complete** account set, so the recompute is
conclusive only over a complete set. reckn's dispute path commits a **compact**
prestate (just the accounts a transaction touches), which cannot reproduce
`bank_hash` on its own. Hence the `snapshot_is_complete` gate:

- **Complete snapshot** (`snapshot_is_complete = true`): `bank_hash` is verified
  in-replay. This is exercised by the unit/integration tests today.
- **Compact prestate** (`false`, today's dispute flow): authenticity binds
  transitively — the compact accounts must be a **subset** of a full snapshot
  whose `bank_hash` was verified out of band, committed via
  `anchor.snapshot_archive_hash`.

## Remaining stages

1. **Archive-subset binding** — parse a real Agave snapshot archive, verify it
   reproduces `bank_hash` with this module, and prove the compact prestate's
   accounts equal the archive's values for those pubkeys (content-addressed by
   `snapshot_archive_hash`). This is what makes the *compact* dispute path
   load-bearing end to end.
2. **Preimage sourcing** — populate `parent_bank_hash` / `signature_count` from
   the block/checkpoint rather than trusting anchor input.
3. **Feature/epoch pinning** — carry the active-feature set so the `bank_hash`
   rule is selected correctly across the delta-hash → lattice-hash transition.

Until (1) lands, the compact dispute path trusts the archive binding; the verifier
and the complete-snapshot gate are the foundation it stands on.

[`solana-lattice-hash`]: https://crates.io/crates/solana-lattice-hash

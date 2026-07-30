# EVM V1 witness verification

## Decision

Use `alloy-trie 0.9.5` with its `ethereum` feature and `verify_proof` API.
It resolves with the existing `alloy-primitives 1.6.1` used by `revm 38`, works
from committed RLP proof nodes without an RPC, and supplies the canonical
Ethereum `TrieAccount` codec. `reth-trie` would couple this small offline
verifier to Reth's database/node layers; a bespoke MPT implementation would put
consensus-critical RLP and trie traversal in Reckn's maintenance surface.

`alloy-trie` is the proof library, not the source of truth: the committed anchor
state root and witness bytes remain the only inputs. A second implementation
should consume the golden fixture before a backend/version is promoted.

## Witness V1

```rust
struct AccountWitness {
    address: Address,
    balance: U256,
    nonce: u64,
    storage_root: B256,
    code_hash: B256,
    code: Bytes,
    account_proof: Vec<Bytes>, // RLP nodes, root → leaf
    storage: Vec<StorageWitnessV1>,
}

struct StorageWitnessV1 {
    slot: U256,
    value: U256,
    proof: Vec<Bytes>, // RLP nodes, root → leaf
}
```

The account fields are claims only until proof verification binds their canonical
RLP `TrieAccount { nonce, balance, storage_root, code_hash }` to
`anchor.state_root` at secure key `keccak256(address)`. `keccak256(code)` must
equal the claimed/proven `code_hash`. Every storage entry is verified below that
proven `storage_root` at `keccak256(slot-as-32-byte-big-endian)`. Nonzero values
use canonical RLP integer bytes; zero uses an exclusion proof because canonical
Ethereum storage tries do not retain zero-valued leaves.

Duplicate accounts or storage keys, missing proof nodes, bad code hashes, and
proof mismatches all reject the witness.

## Replay failure boundary

`verify_witness_against_root` returns
`Result<VerifiedPrestateWitnessV1, WitnessVerificationError>`, and `replay`
returns `Result<ReplayOutcome, OperationalError>`. It verifies first and only
then constructs revm's database. The database is closed-world: a missing account,
code, storage slot, or historical block hash returns `OperationalError`, rather
than inheriting `EmptyDB`'s default values. The post-state predicates
(`PostStateEquals`, `PostStateBounded`, `PostStateDelta`) also require a proven
prestate slot for every asserted key — a missing slot is `OperationalError`, not
a `0`-valued read. For `PostStateDelta` that proven slot is also the `pre`
baseline the caused change `post − pre` is measured against.

No `OperationalError` is serialized as `Reproduced` or `Failed`; no verdict is
signed. The deal remains `Disputed` and its existing `resolveDeadline` path
returns the buyer's funds under C1. EVM revert/halt and false predicate results
remain deterministic `Failed` verdicts.

## Result hash mapping

`ResultEquals` keeps EVM-native semantics:

```text
predicate digest = keccak256(returnData)
```

The VM-neutral `ReplayRecordV1.resultHash` / envelope `resultHash` is instead:

```text
SHA-256("reckn/v1/" || "evm-return-data" || returnData)
```

This avoids describing a Keccak digest as the cross-VM SHA-256 `ContentHash`.
The field remains exactly 32 opaque bytes, so the canonical TLV does not change.

## Golden fixture

[mpt-witness-v1.md](../reexec-evm/fixtures/mpt-witness-v1.md) contains a fixed
three-account state root, raw account/storage proof nodes, and their Keccak
commitments. The Rust test verifies the fixture, pins its commitments, and shows
that changing a proven storage value produces `OperationalError::InvalidWitness`
rather than a `Failed` verdict.

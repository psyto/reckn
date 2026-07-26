# ReplayRecordV1 — canonical cross-VM codec

`trace_hash` in a Reckn verdict envelope is **not** debug-log text. It is the
SHA-256 of the canonical `ReplayRecordV1` — a versioned, VM-neutral record of the
adjudicated replay. Any backend (EVM revm today, Solana LiteSVM later) and any
language (Rust, TypeScript, Solidity) MUST produce byte-identical canonical bytes
and therefore the same `trace_hash` for the same field values. The golden vectors
in [`golden/replay-record-v1.json`](golden/replay-record-v1.json) are the
conformance oracle.

This file is the single source of truth for the encoding. `reexec-evm` contains
the reference Rust implementation (`ReplayRecordV1::canonical_bytes` /
`trace_hash`); it must match this document and the golden vectors.

## Hash rule

All cross-VM hashes are:

```
SHA-256( "reckn/v1/" || typeTag || canonicalBytes )
```

- `"reckn/v1/"` is the 9 ASCII bytes `72 65 63 6b 6e 2f 76 31 2f`.
- `typeTag` for this record is the 13 ASCII bytes `"replay-record"`.
- `canonicalBytes` is the TLV encoding below.

`trace_hash` is a 32-byte digest. It is distinct from EVM-native `keccak256`,
which is only used *inside* the EVM backend (e.g. the `RESULT_EQUALS` predicate
compares `keccak256(returnData)`); such keccak outputs enter this record only as
opaque 32-byte content in the `resultHash` field.

## TLV encoding

`canonicalBytes` is the concatenation of entries, tags strictly ascending. Each
entry is:

```
tag    : 1 byte
length : 1 byte   (every value in V1 is ≤ 32 bytes)
value  : `length` bytes
```

Unsigned integers use **minimal big-endian**: no leading zero bytes; the value
`0` encodes as the empty string (`length = 0`). 32-byte hashes encode verbatim
(`length = 32`).

| tag  | field                | type            | notes |
|------|----------------------|-----------------|-------|
| 0x01 | `protocolVersion`    | uint (minimal)  | `1` |
| 0x02 | `backendId`          | 32 bytes        | which VM backend produced the verdict |
| 0x03 | `backendVersionHash` | 32 bytes        | exact engine image/config |
| 0x04 | `specHash`           | 32 bytes        | funded predicate + schema + anchor commitment |
| 0x05 | `deliveryHash`       | 32 bytes        | seller plan + claim commitment |
| 0x06 | `prestateAnchorHash` | 32 bytes        | committed anchor descriptor |
| 0x07 | `prestateRoot`       | 32 bytes        | anchor state root the witness is proven against |
| 0x08 | `outcome`            | uint (minimal)  | `1` = Reproduced, `2` = Failed |
| 0x09 | `resultHash`         | 32 bytes        | backend result commitment (EVM: `keccak256(returnData)`) |

The record deliberately holds **only hashes and enums** — no addresses, slots,
blocks, or calldata. All VM-specific material is already folded into
`specHash` / `deliveryHash` / `prestateAnchorHash` / `resultHash`, keeping the
record itself VM-neutral (cross-VM cut-line).

`VerdictEnvelopeV1` = `dealId` + these fields + `trace_hash` (the hash of this
record). The record never contains `dealId` or `trace_hash` itself.

## Open item (flagged for Codex cross-pass)

How EVM-native `keccak256(returnData)` maps into the envelope's `resultHash`
`ContentHash` (keccak verbatim vs a SHA-256 re-commitment) is not yet fixed. The
TLV format is stable either way — `resultHash` is 32 opaque bytes — but the
producer's convention must be pinned before multi-language producers exist.

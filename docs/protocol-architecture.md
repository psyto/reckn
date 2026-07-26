# Reckn protocol architecture

## EVM-first decision

Reckn ships one EVM chain first. The adjudicator is a deterministic,
off-chain `ReexecBackend`; the escrow contract stores and checks its canonical
commitments. The first resolver is a permissioned keeper used as a relay.
Chainlink CRE may replace that relay without changing the contract or verdict
format.

Two properties are deliberately distinct:

* **Reproducibility:** anyone with the published inputs derives the same verdict.
* **Settlement authority:** the escrow acts on a registered resolver signature.

The MVP has reproducibility plus an explicit signer trust boundary. A trace hash
does not itself make settlement trustless. Permissionless settlement needs a
fraud proof, an optimistic challenge game, or a bonded quorum. Do not overclaim
this in the demo.

Subjective quality is out of scope. A future conventional judge is a separate
`ResolutionBackend`, never a `ReexecBackend` verdict.

## Repository modules

```text
contracts/
  src/RecknEscrow.sol       # Held → Delivered → Disputed → Resolved
  src/ResolverRegistry.sol  # resolver keys and backend/version allow-list
  src/interfaces/IUSDC3009.sol
  src/libraries/VerdictHash.sol
  test/
packages/
  protocol/                 # canonical codecs, hashes, shared types
  reexec-core/              # interface and golden test vectors
  reexec-evm/               # revm runner plus verified EVM state source
  keeper/                   # dispute watcher, signer, transaction submitter
  dashboard/                # LLM judge vs replay scored artifact
  mcp-server/               # deal, delivery, challenge control plane
infra/arc/                  # deployment and keeper configuration
docs/test-vectors/          # immutable spec/input/envelope fixtures
```

Only `packages/protocol` owns serialization and hashing. Solidity consumes
fixed-width commitments and is never a second spec parser. The escrow imports
no EVM, Solana, or RPC-specific types.

## VM-neutral waist

`verdict(specHash, prestateAnchor)` is useful shorthand. It is insufficient to
run if the spec and seller delivery are inaccessible, so the real interface takes
the committed bytes as well. That avoids a hidden mutable database in consensus.

```ts
type Bytes32 = `0x${string}`;
type BackendId = Bytes32;
type ContentHash = Bytes32;

type PrestateAnchorV1 = {
  codec: "reckn/prestate-anchor/v1";
  backendId: BackendId;
  // Backend-owned: EVM block/root/environment; later Solana slot/root.
  body: Uint8Array;
};

type ReexecRequestV1 = {
  protocolVersion: 1;
  dealId: Bytes32;
  spec: Uint8Array;
  specHash: ContentHash;
  delivery: Uint8Array;
  deliveryHash: ContentHash;
  prestateAnchor: Uint8Array;
  prestateAnchorHash: ContentHash;
};

enum ReexecVerdict { Reproduced = 1, Failed = 2 }

type VerdictEnvelopeV1 = {
  protocolVersion: 1;
  dealId: Bytes32;
  backendId: BackendId;
  backendVersionHash: ContentHash;
  specHash: ContentHash;
  deliveryHash: ContentHash;
  prestateAnchorHash: ContentHash;
  prestateRoot: Bytes32;
  verdict: ReexecVerdict;
  resultHash: ContentHash;
  traceHash: ContentHash; // canonical ReplayRecordV1, not debug-log text
};

interface ReexecBackend {
  readonly id: BackendId;
  readonly versionHash: ContentHash;
  verdict(input: ReexecRequestV1): Promise<VerdictEnvelopeV1>;
}
```

For one tuple of backend id/version, spec bytes, delivery bytes, and anchor
bytes, a conforming backend returns byte-identical envelope bytes or the same
operational error. It rejects incorrect hashes and foreign backend ids, proves
all state reads against the root, commits all verdict-relevant input/result into
`ReplayRecordV1`, pins its engine/config/image, and never uses `latest`, wall
clock, random data, mutable feeds, or uncommitted network input.

`Failed` is a deterministic result: revert, failed proof, result mismatch, or a
false predicate. Missing content, non-final anchors, unsupported versions, and
transport errors are operational errors: remain `Disputed`, never refund.

## Minimal committed spec

All cross-VM hashes are `SHA-256("reckn/v1/" || typeTag || canonicalBytes)`.
Use a versioned TLV codec with ascending numeric tags and minimal unsigned
integers. Never hash native JSON, `abi.encodePacked`, or a URI; a URI is only a
retrieval hint.

```ts
type PredicateCommitmentV1 =
  | { kind: "RESULT_EQUALS"; expectedResultHash: ContentHash }
  | { kind: "POSTSTATE_EQUALS"; assertionProgramHash: ContentHash };

type SpecV1 = {
  protocolVersion: 1;
  backendId: BackendId;
  backendVersionPolicy: "EXACT";
  acceptedBackendVersionHash: ContentHash;
  prestateAnchor: PrestateAnchorV1; // specHash binds its snapshot
  executionSchemaHash: ContentHash;
  predicate: PredicateCommitmentV1;
  expiry: bigint;
};

type DeliveryV1 = {
  protocolVersion: 1;
  executionSchemaHash: ContentHash;
  executionPlan: Uint8Array; // backend-specific but content-bound
  claimedResult: Uint8Array;
  attachments: Array<{ hash: ContentHash; retrievalHint?: string }>;
};
```

The envelope is VM-neutral; execution plans and assertion programs are opaque,
backend-owned bytes. Store compact spec/delivery bytes on-chain in the demo
(bounded size), or publish them to durable content-addressed storage before
acceptance. A hash with unavailable content cannot be independently reproduced.

## EVM V1 backend

The only initial schema is `EvmCallPlanV1`: a fully specified `CALL` with chain
id, caller, target, calldata, value, gas limit, nonce policy, and committed block
environment. `EvmActionSpecV1` permits only:

* `RESULT_EQUALS`: `keccak256(returnData)` is the expected hash.
* `POSTSTATE_EQUALS`: ordered `(address, storageSlot, expectedWord)` checks.

The demo commits an exact plan at funding time. It intentionally has no general
calldata DSL, arbitrary EVM expression interpreter, or quality judge. Seller
`deliver()` records a delivery and claim hash; replay evaluates the plan instead
of trusting the claim.

An EVM anchor commits `chainId`, finalized block number/hash, `stateRoot`, and
the full `revm` environment: timestamp, base fee, gas limit, coinbase,
`prevrandao`, and chain rules. `reexec-evm` runs locally with `revm`, obtains
account/storage proofs and code for the block, verifies proofs against the root,
and verifies code hashes. An RPC fork or `debug_traceCall` helps development but
is not verification: it delegates execution/state authenticity to the RPC.
`reth` is acceptable only with the same root and environment checks.

## On-chain commitment and wiring

```solidity
enum DealState { None, Held, Delivered, Disputed, Resolved }
enum Outcome { Reproduced, Failed }

struct Deal {
    address buyer; address seller; address paymentToken; uint256 amount;
    bytes32 specHash; bytes32 deliveryHash; bytes32 prestateAnchorHash;
    bytes32 prestateRoot; bytes32 backendId; bytes32 backendVersionHash;
    DealState state;
}

struct VerdictCommitment {
    bytes32 dealId; bytes32 specHash; bytes32 deliveryHash;
    bytes32 prestateAnchorHash; bytes32 prestateRoot;
    bytes32 backendId; bytes32 backendVersionHash; Outcome outcome;
    bytes32 resultHash; bytes32 traceHash;
}
```

`fundWithAuthorization()` consumes the buyer EIP-3009 authorization via a payment
adapter and enters `Held`. `deliver()` is seller-only in `Held`. `challenge()`
is buyer-only in `Delivered` before deadline and emits full `Disputed` terms.
`resolve()` is valid only in `Disputed`: verify the registered resolver's
EIP-712 signature over every `VerdictCommitment` field, ensure it matches the
deal, emit `VerdictCommitted`, then atomically release on `Reproduced` or refund
on `Failed`.

Never sign `traceHash` alone, let a resolver pick a fresh anchor, or permit a
second resolution. Backend id and exact version are part of the deal/signature;
an upgrade cannot silently change a spec's meaning. ERC-8004 identity/reputation
is event metadata only. x402 and MCP build/retrieve committed inputs; they are
not alternate settlement paths.

## Surface-first implementation order

1. Build the four-state contract, EIP-3009 adapter, events, deadlines, mock
   resolver, and transition/conservation/signature tests.
2. Implement canonical hashing, anchored EVM call plan, `RESULT_EQUALS`, local
   `revm`, and golden test vectors. Add storage checks and proof verification;
   label temporary RPC-only mode `demo-unverified`.
3. Keeper watches `Disputed`, fetches by hash, executes, signs, and submits
   `resolve` idempotently by `(chainId, dealId, verdictHash)`. Start here; add
   CRE only if it runs the identical pinned image and commits identical bytes.
4. Dashboard split screen: left is an opaque “LLM judge”; right displays anchor,
   plan, predicate, output, `traceHash`, verdict, and a one-command re-run. Show
   both `Reproduced → release` and false predicate `→ refund`.
5. Add Arc settlement, EIP-3009, ERC-8004, x402, and MCP as thin, inspectable
   integrations around the replay path.

## Cross-VM cut-lines

- [ ] No EVM addresses, blocks, slots, or RPC types in `Deal`, `SpecV1`, or the
      envelope—only backend-owned schema bytes contain them.
- [ ] Version all codecs, tags, enums, hashes, and engine image/config; publish
      TypeScript/Rust/Solidity golden vectors.
- [ ] Hash spec, delivery, anchor, result, replay record, and verdict separately.
- [ ] Treat anchor finality as backend configuration; EVM block/root and Solana
      slot/account snapshot differ, while the envelope does not.
- [ ] Use pluggable integrity-checked retrieval and archive fixtures after the
      keeper disappears.
- [ ] Keep Act 1 settlement local. A cross-VM binder must explicitly add both
      chains' finality, message authentication, timeout, and double-settlement
      rules; never silently release from a remote verdict.
- [ ] A Solana replay is another `ReexecBackend`; an LLM judge is a distinct
      resolution kind. Require independent fixtures/implementation before
      claiming any new VM profile is deterministic.

An immutable predicate is funded against an immutable snapshot. A dispute
replays exact work, commits reproducible evidence, and releases or refunds:
**Reproduce, or refund.**

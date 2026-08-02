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

Reproducibility is not just asserted — it is executable: `reckn-keeper verify`
re-derives a settled deal's verdict from public inputs alone (content store +
re-execution), with no resolver key, and asserts it matches the on-chain
`VerdictCommitted`. That keyless check is exactly the fraud-detection primitive a
future challenge/bond layer turns into slashable proofs.

The three routes named above are now partly built: **optimistic settlement** (the
default on both VMs) and a **bonded quorum** with automatic, permissionless slashing
(`RecknEscrow.slashWithQuorum`) reduce trust to an honest-majority quorum. The
**ZK** route toward true permissionless settlement has a working slice: `zk-verdict/`
proves the causal-delta verdict in an SP1 zkVM, and `RecknVerdictVerifier.sol`
verifies that proof **on-chain** — settlement authority from a proof, not a signer
(tested with a **real Groth16 proof** against SP1's real `SP1Verifier`, circuit
v6.1.0). A second guest (`zk-verdict/program-revm`) goes further: it **MPT-verifies
the committed prestate against the `state_root` and runs real revm inside the zkVM**,
executing the committed CALL to derive the post-state under proof — closing both the
trusted-prestate and trusted-`post` gaps for that execution (a tampered prestate is
rejected; its Groth16 proof verifies on-chain through the same verifier). Remaining:
disabled precompiles and full-block scale; a **third guest**
(`zk-verdict/program-svm`) mirrors this on Solana — it signature-verifies the real
committed transaction in-guest and re-executes its System transfer under proof
(reckn permits System builtins only), with in-guest `bank_hash` authenticity the
remaining follow-up. Do
not overclaim: none of these yet make single-signer adjudication zero-trust for
arbitrary work.

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

`Failed` is a deterministic result: revert/halt, result mismatch, or a false
predicate. Invalid/failed proofs, missing content, non-final anchors, unsupported versions, and
transport errors are operational errors: they cannot be signed as a verdict.
They remain `Disputed` until `resolveDeadline`; the timeout policy below then
settles the liveness case.

## Minimal committed spec

All cross-VM hashes are `SHA-256("reckn/v1/" || typeTag || canonicalBytes)`.
Use a versioned TLV codec with ascending numeric tags and minimal unsigned
integers. Never hash native JSON, `abi.encodePacked`, or a URI; a URI is only a
retrieval hint.

```ts
type PredicateCommitmentV1 =
  | { kind: "RESULT_EQUALS"; expectedResultHash: ContentHash }
  | { kind: "POSTSTATE_EQUALS"; assertionProgramHash: ContentHash }
  | { kind: "POSTSTATE_BOUNDED"; checks: { address; slot; min; max }[] }
  | { kind: "POSTSTATE_DELTA"; checks: { address; slot; min; max }[] };

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

### Data availability and timeout policy

The protocol distinguishes terms chosen by the buyer from work supplied by the
seller. This removes ambiguity in the only default outcome that preserves
liveness:

| Material | Publisher / accountable party | Required availability point |
| --- | --- | --- |
| `SpecV1` canonical bytes | buyer / deal author | at funding; the bytes must be emitted, stored, or durably content-addressed before `Held` |
| `PrestateAnchorV1` header/root/environment bytes | buyer / deal author | at funding, by the same mechanism as `SpecV1` |
| delivery, plan, claimed result, and any attachments | seller | at `deliver()` and throughout the challenge/resolve window |
| state-proof/code witness needed to replay the seller plan | seller | attached to delivery, or retrievable from a durable source whose proofs verify against the fixed root |

The anchor descriptor is buyer-authored because it defines the deal's world
state. The seller is not compelled to deliver against an unavailable or invalid
anchor: no delivery leads to the normal buyer reclaim. Once the seller calls
`deliver()`, they attest that their concrete plan and replay witness are
available against that fixed anchor. Therefore V1's liveness rule is:

```text
Disputed + no valid signed verdict by resolveDeadline → refund buyer
```

This covers missing delivery data, an unavailable witness, a keeper outage, and
other operational errors uniformly. It is intentionally seller-unfavourable
after delivery, because the seller controls whether to accept the fixed terms
and can publish the evidence at delivery time. The funding implementation must
add raw spec/anchor publication (or a checked content-store registration) before
claiming production-grade independent reproduction; hashes alone are insufficient.

Note the timeout refunds the **buyer**, so a seller who withholds replay material
is never paid — withholding is not a way to recover funds. To also deny the
withholding seller a *reputation* dodge, the timeout emits a negative
`ReputationEvidence` (evidence-withheld: `reproduced = false`, zero trace),
distinct from a reproduced `Failed`; see the reputation hooks below.

A reputation mark alone, however, costs a throwaway (Sybil) seller nothing. So the
EVM escrow now adds the **co-designed bond + data-availability forfeiture rule** as
an **opt-in seller data-availability bond**: the buyer commits a `requiredSellerBond`
at funding (bound into the signed nonce, so a relayer cannot weaken it); the seller
locks it at `deliver()`; and it is forfeited to the buyer **only** on a dispute
timeout (evidence withheld), while every other terminal path — release, a reproduced
`Failed` on the merits, unchallenged release, resolver-conflict fault — returns it.
Crucially the bond punishes *withholding*, not *losing*: a seller who provides
evidence and loses still gets it back, so it is a data-availability bond, not a
correctness bond. It is never a bond alone — the forfeiture rule is what gives it
teeth. Honest scope: bond *sizing* (bond ≥ a seller's gain from withholding) is an
economic parameter left to the buyer, and this is the **EVM** cut; the SVM
(Pinocchio) mirror — a lamport bond locked at `deliver` and forfeited on
`timeout_refund` — is the follow-up. None of this touches the deterministic core.

### V1.1 demo content-store binding

The anvil keeper uses a deliberately small file content store as the transport:
`<contentHash-without-0x>.json`. The filename is only a lookup hint. Before it
deserializes **any** spec, delivery, or anchor field, the keeper computes
`SHA-256(raw file bytes)` and requires exact equality with the corresponding
on-chain commitment (`specHash`, `deliveryHash`, or `prestateAnchorHash`). A
missing file, digest mismatch, bad codec, or a spec whose anchor hash differs
from the deal is an operational error and is never signed.

This closes the demo's trust chain:

```text
deal.prestateAnchorHash → checked anchor bytes → stateRoot → MPT-proven witness
```

The JSON files are a V1.1 demo codec, not a replacement for the canonical
`SpecV1` TLV codec above. Production content addressing keeps the same
"hash-before-parse" property with the canonical bytes.

## EVM V1 backend

The only initial schema is `EvmCallPlanV1`: a fully specified `CALL` with chain
id, caller, target, calldata, value, gas limit, nonce policy, and committed block
environment. `EvmActionSpecV1` permits only:

* `RESULT_EQUALS`: `keccak256(returnData)` is the expected hash.
* `POSTSTATE_EQUALS`: ordered `(address, storageSlot, expectedWord)` checks.
* `POSTSTATE_BOUNDED`: ordered `(address, storageSlot, min, max)` checks, each
  asserting the post-state word lies in the inclusive range `[min, max]`. This
  is the funded envelope behind "swap output ≥ minOut" (`max = MAX`) and
  "≤ cap" (`min = 0`); equality is the degenerate `min == max`. The SVM backend
  mirrors it as `LamportsBounded { account, min, max }`. It adjudicates a
  *property* of the post-state, not that the plan caused it.
* `POSTSTATE_DELTA`: ordered `(address, storageSlot, min, max)` checks, each
  asserting the plan's *caused* change `post − pre` (saturating at 0, `pre` = the
  committed witness value) lies in `[min, max]`. This is the sound primitive for
  the causal claim "this swap credited ≥ minOut" — a no-op plan yields delta 0
  and cannot satisfy any `min > 0`, so it is not prestate-satisfiable the way a
  bound is. The SVM backend mirrors it as `LamportsDelta { account, min, max }`.

Funding commits the **plan schema**, anchor, and predicate—not a seller plan.
The seller supplies the concrete, schema-valid `EvmCallPlanV1` and claimed result
inside `DeliveryV1` at `deliver()`. Replay answers the meaningful question:
“does this seller-supplied plan, run on the committed prestate, satisfy the
buyer-funded predicate?” It intentionally has no general calldata DSL, arbitrary
EVM expression interpreter, or quality judge.

An EVM anchor commits `chainId`, finalized block number/hash, `stateRoot`, and
the full `revm` environment: timestamp, base fee, gas limit, coinbase,
`prevrandao`, and chain rules. `reexec-evm` runs locally with `revm`, verifies
offline MPT account/storage proofs and code hashes against the root, and uses a
closed witness DB so a missing state read is an operational error. An RPC fork
or `debug_traceCall` helps development but is not verification: it delegates
execution/state authenticity to the RPC. `reth` is acceptable only with the
same root and environment checks.

V1.1 serializes `blockHash` in `EvmAnchorV1` now, so an anchor has a stable
header identity. It does **not** yet accept EVM `BLOCKHASH` reads: the
closed-world DB returns `MissingBlockHashWitness`, an operational error, until a
connected-header witness verifier is introduced. The demo plan intentionally
does not use that opcode.

The current keeper acquires a transitive witness with
`eth_createAccessList` at the committed block, explicitly adds the plan caller,
target, and coinbase, then uses `eth_getProof(address, slots, block)` plus
`eth_getCode`. It first rejects an RPC block whose header hash differs from the
committed `blockHash`, then keeps the raw RLP proof nodes and verifies the completed witness
against `stateRoot` offline before replay, and treats any later closed-world
`Missing*Witness` error as the final completeness check rather than a `Failed`
verdict.

For result commitments, EVM's `keccak256(returnData)` remains the
`RESULT_EQUALS` predicate input. The VM-neutral envelope `resultHash` is instead
`SHA-256("reckn/v1/" || "evm-return-data" || returnData)`, a domain-separated
ContentHash. See [`REPLAY_RECORD_V1.md`](../packages/protocol/REPLAY_RECORD_V1.md).

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
on `Failed`. `timeoutRefund()` is callable by anyone after `resolveDeadline` if
no verdict was posted; it applies the data-availability policy above and emits the
evidence-withheld reputation signal before refunding.

Never sign `traceHash` alone, let a resolver pick a fresh anchor, or permit a
second resolution. Backend id and exact version are part of the deal/signature;
an upgrade cannot silently change a spec's meaning. ERC-8004 identity/reputation
is event metadata only. x402 and MCP build/retrieve committed inputs; they are
not alternate settlement paths.

## Surface-first implementation order

> Progress: (1) done — `contracts/`, 23 tests (incl. cross-language digest pin,
> ERC-8004 `ReputationEvidence`, and end-to-end settlement on real engine output).
> (2) done — `reexec-evm/`, revm 38 with offline MPT verification and real-anchor
> (base-fee/nonce) support, 9 tests; canonical `ReplayRecordV1` in
> `packages/protocol/`. (3) done — `keeper/` builds and EIP-712-signs the verdict
> `resolve()` accepts (shared-golden cross-check), plus the live HTTP shell — now on
> a **committed** witness: the seller publishes it (`witness --write`) and the
> delivery commits its hash; `once`/`verify` resolve it by hash and MPT-verify before
> replay, decoding all content through the shared `reckn-evm-content` codec — and a
> **keyless independent re-verifier** (`verify`: re-derives a settled verdict from
> public inputs and asserts it matches on-chain). `scripts/anvil-e2e.sh` runs the
> whole loop incl. re-verification. (4) done — `dashboard/` (v5), real engine output.
> (5) partial — ERC-8004 reputation done (incl. evidence-withheld on timeout, both
> VMs); Arc / x402 / MCP remain. Solana backend + cross-VM binder (one router, both
> VMs) also done. Next big swings: a challenge/bond layer co-designed with DA
> forfeiture, and the cross-chain settlement around the binder.

1. Build the four-state contract, EIP-3009 adapter, events, deadlines, mock
   resolver, and transition/conservation/signature tests.
2. Implement canonical hashing, anchored EVM call plan, `RESULT_EQUALS`, local
   `revm`, offline MPT account/storage verification, and golden test vectors.
   Any temporary RPC-only convenience mode is `demo-unverified` and cannot post
   a production verdict.
3. Keeper watches `Disputed`, fetches by hash, executes, signs, and submits
   `resolve` idempotently by `(chainId, dealId, verdictHash)`. Start here; add
   CRE only if it runs the identical pinned image and commits identical bytes.
4. Dashboard money-shot: seller supplies a plan that fails the slippage / output
   predicate but claims success. The left “LLM judge” accepts the persuasive
   claim; the right replay shows the fixed anchor, seller plan, predicate,
   output, `traceHash`, and `Failed → refund`. Include the positive
   `Reproduced → release` control path and a one-command independent re-run.
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

## Follow-on economic and reputation hooks

The four time bounds must be nonzero and phase-ordered:

```text
fundedAt < deliveredAt ≤ deliverDeadline
deliveredAt < challengeDeadline
challengedAt < resolveDeadline
```

The contract should validate the window parameters and record/emits each phase
timestamp; it must not rely on an informal reading of four independent clocks.
`challengeDeadline` need not be after the *unused* `deliverDeadline` when a
seller delivers early—the invariant is about the actual phase transition.

A future challenge bond is an anti-griefing cut-line, not an input to replay.
It must be fixed in the funded spec, escrowed separately, and have an explicit
outcome policy (for example, return on `Failed`, transfer on `Reproduced`, and a
timeout rule). It must never alter the predicate or let a resolver price an
opinion. Critically, it must ship **together with a data-availability forfeiture
rule** — a post-delivery timeout must forfeit the seller's stake (and/or delivery
must pin evidence to a durable DA layer), not merely refund the buyer. A bond
added alone would open the incentive the current bondless design does not have: a
seller could withhold replay material to force a timeout and dodge the slash a
`Failed` verdict would apply. Bond and DA-forfeiture are one change.

After resolution, emit or index a canonical ERC-8004 reputation-evidence
projection keyed by `dealId` and the full `verdictHash`. It may record outcome,
backend/version, and reproducibility links, but never infer quality or change
settlement. This makes the verdict a verifiable reputation source later without
coupling identity/reputation into the deterministic core.

**Implemented:** `RecknEscrow.resolve()` emits
`ReputationEvidence(agent, reproduced, dealId, traceHash, backendId)` — a pure
projection that never touches settlement (tested for both outcomes). The
differentiator vs self-reported feedback (e.g. AgentRankr) is that the evidence
is a re-derivable verdict, not an opinion: `reckn-keeper verify` reproduces it.
A dispute that times out with no verdict *also* emits a negative,
evidence-withheld signal (`reproduced = false`, **zero trace**), so a seller
cannot dodge the mark by withholding replay material to force a timeout; the zero
trace distinguishes it from a reproduced `Failed`. The Solana escrow
(`escrow-svm`) mirrors this through one shared, seller-attributed evidence emitter
on both its `resolve` and `timeout_refund` paths.

An immutable predicate is funded against an immutable snapshot. A dispute
replays exact work, commits reproducible evidence, and releases or refunds:
**Reproduce, or refund.**

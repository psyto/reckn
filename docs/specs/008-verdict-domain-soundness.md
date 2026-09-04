# 008 — verdict domain soundness

Status: spec, round 1. Owner: `reckn-spec`. Implementer: `reckn-codex-impl`.
Tier: **local machine only** — `cargo test`, `forge test`, SP1 `execute`, and SP1 CPU Groth16
for the four committed fixtures. **No anvil, no testnet, no mainnet, no network calls.**
Nothing in this document claims anything about a deployed chain.

Every fact cited below was checked against the files on disk on **2026-09-04**, and every
empirical claim (`forge` / `cargo` behaviour, revm defaults) was re-run today rather than
quoted from a previous round.

---

## 1. The claim, and what 008 is not

### 1.1 The claim (one sentence)

> **The verdict a proof carries is the same function of the same committed bytes that
> `reexec-evm` computes off-chain — over the whole 256-bit value domain and the whole block
> environment — and `dealBinding` commits every byte that function reads.**

Today it is neither. `zk-verdict/program-revm/src/main.rs:163-164` judges on limb 0 of a
`U256` while `reexec-evm/src/lib.rs:647` judges on the full `U256`, so a **decrease** can be
proven as the largest possible credit and released to the seller. And the guest configures
only `chain_id` (`program-revm/src/main.rs:122-126`), so it is not even running the same EVM.

This matters more than any other open task because the product's entire differentiation is
that *settlement authority comes from the proof*. `003` demonstrates that no key can move a
funded escrow; while 008 is open, **no key is needed** — a proof moves it wrongly on its own.

### 1.2 Non-goals (explicitly not done here, including the tempting ones)

- **N-1. `RecknZkEscrow.sol` is not modified.** Not one byte. The timeout / refund path is
  `003`. AC-0b makes this a build condition, which is also what keeps AC-0 trivially true:
  the enumerated surface in `AGENTS.md` §0 and `scripts/no-keys.sh` is unchanged, so the
  central claim is neither strengthened nor weakened by 008.
- **N-2. The optimistic path (`contracts/RecknEscrow`) is untouched** (`AGENTS.md` §8).
- **N-3. `reexec-evm`'s production API is not changed.** `replay`, `judge`, `PredicateV1`,
  `EvmAnchorV1`, `AccountWitness`, `StorageWitnessV1`, `verify_witness_against_root`,
  `OperationalError`, `WitnessVerificationError`, and `header` keep their current text
  byte-for-byte. Only the `#[cfg(any(test, feature = "testkit"))] pub mod testkit` block
  gains builders, and the existing builder signatures stay as wrappers. This is what keeps
  `binder`, `keeper` and `reckn-evm-content` (the three other `reckn-reexec-evm` consumers)
  compiling without being touched.
- **N-4. The predicate surface does not widen.** One CALL, one `PostStateDelta` check,
  exactly as today. `ResultEquals` / `PostStateEquals` / `PostStateBounded` and multi-check
  predicates stay off-chain-only.
- **N-5. The `state_root` ↔ block-header binding stays in `reexec-evm::header`.** The guest
  never sees a header. `GuestInput` deliberately does not carry `block_hash` or
  `block_header` (see INV-6's exclusion set).
- **N-6. Precompile *backend* parity is not closed** — see R-3. The guest and the off-chain
  engine run the *same precompile set* with *different implementations*, and their
  equivalence is untested.
- **N-7. No new external / public function on any contract.** The `no-keys.sh` enumeration
  (`fund` / `settleWithProof` / `refundAfterDeadline`) is unchanged, so `AGENTS.md` §0 does
  not move.
- **N-8. No cycle-count optimisation.** The guest will get slower (U256 arithmetic, a
  witness-closed DB, `k256` under a pinned spec). 008 re-measures and republishes the
  number; it does not try to improve it. SP1 crypto patches and GPU proving are out.
- **N-9. `scripts/ac.sh` is not created or modified.** That name belongs to `003`. 008's
  harness is `zk-verdict/scripts/ac008.sh` and its manifest is §6.1 of this document.
- **N-10. The SVM guest's semantics do not change.** Lamports are `u64` natively, so the
  SVM path has no truncation bug. It is edited only to keep compiling against the widened
  shared ABI, and INV-9 is the proof obligation that the edit is semantics-preserving.

---

## 2. The defect, reproduced exactly

### 2.1 Axis 1 — the value domain (`u64_low` takes limb 0)

`zk-verdict/program-revm/src/main.rs:31-33`:

```rust
fn u64_low(v: U256) -> u64 { v.as_limbs()[0] }
```

`as_limbs()` is little-endian, so limb 0 is the **low 64 bits**. `main.rs:163-166` then feeds
`u64_low(pre)` / `u64_low(post)` to `verdict_lib::delta_outcome` (`zk-verdict/lib/src/lib.rs:40-47`),
which computes `post.saturating_sub(pre)` in `u64`. Off-chain,
`reexec-evm/src/lib.rs:641-661` computes `post.saturating_sub(pre)` in `U256`, reading
`read_pre_slot` / `read_post_slot` (`:668`, `:683`) which return `U256`. The funded predicate's
`min` / `max` are `U256` (`reexec-evm/src/lib.rs:149`); the guest's are `u64`
(`zk-verdict/reexec-io/src/lib.rs:53-58`).

**The false release, exactly.** Prestate slot value `pre = 2^64 = 18446744073709551616`
(limbs `[0, 1, 0, 0]`), executed post `post = 2^64 − 1 = 18446744073709551615`
(limbs `[u64::MAX, 0, 0, 0]`), predicate `min = 1`, `max = U256::MAX`:

| | `pre` used | `post` used | credited delta | verdict |
|---|---|---|---|---|
| off-chain `reexec-evm` | `18446744073709551616` | `18446744073709551615` | `0` (saturating; it **decreased** by 1) | `Failed` |
| guest today | `0` | `18446744073709551615` | `18446744073709551615` | **`Reproduced`** |

`RecknZkEscrow.settleWithProof` (`zk-verdict/contracts/src/RecknZkEscrow.sol:109-117`) sends
the escrowed amount to the **seller** on `Reproduced`. The seller did not deliver; the
checked balance went *down*. Nothing on-chain can detect it, because the public values carry
only the already-truncated `pre` and `post` (`zk-verdict/lib/src/lib.rs:20-32`).

**The mirror-image defect, same line, opposite direction.** `pre = 1`, `post = 2^64`,
`min = 2^64 − 1`: true delta `2^64 − 1`, guest sees `1 → 0` → saturating `0` → `Failed`. An
honest seller who delivered the exact amount is refused and the buyer is refunded. Both
polarities are in the AC-2 vector set, because a fix that only stops the theft direction is
not a fix of this line.

### 2.2 Where the boundary sits, per unit (the crossings, named)

`2^64 = 18446744073709551616`. `u64::MAX = 18446744073709551615`.

| unit | value of `2^64` in that unit | reachable? |
|---|---|---|
| **18-decimal ERC-20 balance** (WAD) | `18.446744073709551616` tokens | **Yes, trivially.** Any balance slot above ≈18.4467 tokens is in the broken region. This is why `AGENTS.md` §3 forbids starting `002` before 008 closes. |
| **wei** (native ETH balance in a slot) | `18.446744073709551616` ETH | Yes. |
| **RAY / 27-decimal index** (Aave-style `liquidityIndex`, share prices) | `0.000000018446744073709551616` | **Always broken.** A RAY-scaled value is `≥ 10^27 > 2^64` by construction, so *every* such slot is out of domain. |
| **6-decimal ERC-20** (USDC) | `18_446_744_073_709.551616` USDC | Not reachable at realistic supply. Stated so nobody claims 008 was unnecessary because the USDC demo happened to work. |
| **basis points** | `1.8447e14` bp | Not reachable. |
| **lamports** (SVM) | — | **Not applicable.** Lamports are `u64` natively (`zk-verdict/svm-io/src/lib.rs`, `SvmAccount.lamports: u64`), so the SVM guest has no truncation. INV-9 is the obligation that widening the shared ABI does not change its verdicts. |
| **any packed word** (two `uint128`s, a `uint96` amount beside a `uint160` address, a raw hash, an address read via `COINBASE`) | — | Broken by construction: the high limbs carry meaning. AC-2 V-11 and AC-3 E-05/E-06 exercise exactly this. |

`min` / `max` are `u64` too, so a floor above `18446744073709551615` — e.g. "credit me at
least 20 tokens" = `20·10^18` — **cannot be expressed at all** today. That is not a soundness
bug, but it makes `002` impossible, and it is fixed by the same change.

### 2.3 Axis 2 — the engine is not the same engine

`program-revm/src/main.rs:122-127` sets **only** `chain_id`. Everything else is a revm
default. `reexec-evm/src/lib.rs:490-513` pins the spec, two cfg flags, and six block fields.
Verified today against the vendored crates:

| what | guest today | off-chain today | source |
|---|---|---|---|
| `spec` | **`SpecId::OSAKA`** (`SpecId`'s `#[default]`) | `anchor.spec_id`; `CANCUN` in every current fixture | `revm-primitives-23.0.0/src/hardfork.rs:76-77`; `reexec-evm/src/lib.rs:494`, `:745` |
| `block.number` | `U256::ZERO` | `21_000_000` | `revm-context-16.0.1/src/block.rs:116`; `reexec-evm/src/lib.rs:506`, `:737` |
| `block.timestamp` | **`U256::ONE`** (not zero) | `1_800_000_000` | `block.rs:118`; `lib.rs:507`, `:740` |
| `block.gas_limit` | `u64::MAX` | `30_000_000` | `block.rs:119`; `lib.rs:509`, `:742` |
| `block.beneficiary` | `Address::ZERO` | `addr(0xc0)` | `block.rs:117`; `lib.rs:510`, `:743` |
| `block.prevrandao` | `Some(B256::ZERO)` | `B256::from([0x22; 32])` | `block.rs:122`; `lib.rs:511`, `:744` |
| `block.basefee` | `0` | `anchor.base_fee` (`0` in the fixture, non-zero for a real block) | `block.rs:120`; `lib.rs:508` |
| `cfg.disable_base_fee` | **not settable** — the field is behind `optional_no_base_fee`, which `program-revm/Cargo.toml` does not enable | `true` | `revm-context-16.0.1/src/cfg.rs:120-121`; `reexec-evm/Cargo.toml` |
| `cfg.disable_nonce_check` | `false` | `true` | `cfg.rs:50`, `:329`; `lib.rs:503` |
| database on an un-witnessed read | `InMemoryDB` → silently **zero** | `Err(OperationalError::MissingAccountWitness / MissingStorageWitness)` | `main.rs:102`; `reexec-evm/src/lib.rs:430-442` |

Two of these bite `002` on the first real transaction, not on an exotic one:

- a real caller has `nonce > 0`, so the guest's nonce check rejects the tx (`Err(_)` at
  `main.rs:146` → `Failed`) while off-chain reproduces it;
- a real anchor has `base_fee > 0` with `gas_price = 0`, so the guest rejects the tx and the
  off-chain engine does not.

And the un-witnessed-read divergence is a **third false-release vector of the same family**:
a seller who omits a slot the contract reads (an allowance, a pause flag, a fee parameter)
gets `0` in-guest and a proof, where the off-chain engine refuses to produce a verdict at
all. 008 closes it, because INV-1 cannot be stated without it.

### 2.4 Axis 3 — `dealBinding` does not cover the whole input

`main.rs:176-190` binds `state_root ‖ check.address ‖ check.slot ‖ min ‖ max ‖
keccak(caller ‖ target ‖ calldata ‖ value)`. It does **not** bind `chain_id`, and it does not
bind `plan.gas_limit`. Once §3 puts the block environment into `GuestInput`, the environment
becomes seller-supplied too. An unbound input is an input the seller chooses: a `CHAINID`- or
`TIMESTAMP`-gated contract can be made to behave favourably, and the resulting proof would
still settle the buyer's deal. This is the same defect as the other two — *the verdict is not
a function of the committed bytes* — so it is closed here, not deferred.

### 2.5 What is **not** wrong (checked, recorded so round 2 does not re-litigate)

- **`ecrecover` is not disabled in-guest.** `revm-precompile-34.0.0/src/secp256k1.rs:4-8`:
  *"Order of preference is `secp256k1` → `k256`. Where if no features are enabled, it will use
  `k256`."* Likewise `kzg_point_evaluation.rs:87-101` falls back to `arkworks` and
  `bls12_381.rs:8-14` falls back to `arkworks`. `revm = { default-features = false }`
  therefore swaps the *backend*, it does not remove the precompile. The current honest-scope
  bullet (a) in `zk-verdict/README.md:159-161` and the `AGENTS.md` §5 bullet that repeats it
  are **wrong as written**, and §9 rewrites them. The real residual is R-3.
- **The ABI-encoded length of `VerdictPublicValues` does not change** when the four numeric
  fields widen: `uint64` already occupies a full 32-byte head slot. 224 bytes before, 224
  bytes after (INV-8).
- **`RecknZkEscrow` never reads `pre` / `post` / `minDelta` / `maxDelta`** — only
  `dealBinding`, `outcome`, `traceHash` (`RecknZkEscrow.sol:99-117`). Hence N-1 is achievable.

---

## 3. The fix

### 3.1 Decision

**(a) Judge in `U256` and widen the public-values ABI to match.** `pre`, `post`, `minDelta`,
`maxDelta` become `uint256` in `VerdictPublicValues`; `delta_outcome` operates on `U256`;
`DeltaCheck.min` / `.max` become `[u8; 32]`; every hashed preimage moves to fixed-width
big-endian and its domain tag goes to `v2`.

**Plus, only where a value genuinely cannot be represented, an explicit in-guest rejection:**
an `env.spec_id` byte that is not a known `SpecId` makes the guest panic. That is the whole
remaining use of option (b) — one byte, one check.

### 3.2 Options considered and rejected

**(b) Reject out-of-domain inputs in the guest (panic when any of `pre`/`post`/`min`/`max`
≥ 2^64).** Sound — no false release — but it converts the theft into a **permanent denial of
settlement** over the entire realistic 18-decimal range, and `RecknZkEscrow` has no timeout
until `003` lands, so the funds simply lock. It also makes `002` impossible: a real ERC-20
balance slot above ≈18.4467 tokens is unprovable, and a RAY-scaled slot is *always*
unprovable. Its supposed cost advantage is illusory: **any** change to the guest ELF changes
its vkey and invalidates the committed fixtures, so (b) saves only the Solidity struct edit
and the predicate/SVM fixtures. Rejected: it buys nothing and gives up the workload.

**(c) Make the domain unreachable from the input side (the route `004` takes).** Not
available here, for three independent reasons.
1. **The prover is the adversary.** `GuestInput` is supplied by whoever generates the proof —
   normally the seller, the party that profits from a false release. There is no input
   sanitiser between them and the guest.
2. **The escrow cannot check what it never sees.** `fund` commits only `dealBinding`; `pre` is
   read from the prestate at *proving* time, is not knowable at funding time, and reaches the
   chain already truncated. No on-chain predicate can detect the crossing after the fact, and
   adding a party who could would be a key — the one thing `AGENTS.md` §0 forbids.
3. **The domain is not exotic; it is the workload.** `pre` is MPT-bound to a real state root.
   A real 18-decimal balance above ≈18.4467 tokens is inside the broken region *by
   construction*. Restricting inputs would reduce the product's claim to "sound for balances
   under 18.45 tokens", which `002` violates on day one.
   `004` may legitimately restrict its own demo fixtures because `004` authors them; 008's
   subject is the general guest, which has no author.

**(a′) Keep `uint64` in the ABI as display fields and judge in `U256` internally.** Rejected.
The public values would then state two numbers that are *not* the numbers the verdict was
computed from — `RecknReexecVerdict.t.sol:44` already asserts a relation between them — and
`minDelta` / `maxDelta` would still be unable to express a floor above ≈18.4467 tokens, so
honest large deliveries would be refused. It fixes the theft and keeps the lie.

### 3.3 Encoding rule (one rule, no exceptions)

Every hashed preimage in `zk-verdict/` after 008 uses **fixed-width big-endian**:
`u8` → 1 byte, `u64` → 8 bytes, `U256` → 32 bytes, address → 20 bytes, hash → 32 bytes,
variable-length bytes → an 8-byte big-endian length followed by the bytes. This is a change
from v1, which used `to_le_bytes()` (`lib/src/lib.rs:56-60`, `main.rs:187-188`); the change
is the reason every tag moves to `v2`.

### 3.4 Types

```rust
// zk-verdict/reexec-io/src/lib.rs
pub struct GuestEnv {
    pub chain_id: u64,
    pub spec_id: u8,            // revm SpecId as u8 (#[repr(u8)], hardfork.rs:13)
    pub block_number: u64,
    pub timestamp: u64,
    pub base_fee: u64,
    pub block_gas_limit: u64,
    pub coinbase: [u8; 20],
    pub prevrandao: [u8; 32],
}
pub struct DeltaCheck { pub address: [u8;20], pub slot: [u8;32], pub min: [u8;32], pub max: [u8;32] }
pub struct GuestInput {
    pub env: GuestEnv,          // `chain_id` moves here — one home
    pub state_root: [u8;32],
    pub accounts: Vec<GuestAccount>,
    pub plan: GuestPlan,
    pub check: DeltaCheck,
}
```

```solidity
// zk-verdict/contracts/src/RecknVerdictVerifier.sol — and the `sol!` twin in lib/src/lib.rs
struct VerdictPublicValues {
    uint256 pre; uint256 post; uint256 minDelta; uint256 maxDelta;
    uint8 outcome; bytes32 traceHash; bytes32 dealBinding;
}
```

**Constants, not inputs** (the seller must not be able to flip them): `disable_base_fee = true`,
`disable_nonce_check = true`, `tx.gas_price = 0`, `TxEnv { ..Default::default() }` for every
other tx field, and `BlockEnv::default()` for `difficulty` and `blob_excess_gas_and_price` —
on **both** sides. `program-revm/Cargo.toml` must add
`revm = { version = "38", default-features = false, features = ["optional_no_base_fee"] }`,
because without that feature the guest cannot express `disable_base_fee` at all
(`revm-context-16.0.1/src/cfg.rs:120-121`). If that feature does not build for
`riscv64im-succinct-zkvm-elf`, **stop and report** (`AGENTS.md` §7) — do not work around it.

`spec_id` is validated with `SpecId::try_from_u8` (`hardfork.rs:83-88`) and the guest panics
on `None`. Because the enum is positional, AC-3 pins five `u8` ↔ name round-trips so a revm
renumbering is caught rather than silently remapping a fork.

### 3.5 The v2 preimages (exact)

```
env_hash   = keccak256( "reckn/zk/env/evm/v2"
                      ‖ chain_id:u64BE ‖ spec_id:u8 ‖ block_number:u64BE
                      ‖ timestamp:u64BE ‖ base_fee:u64BE ‖ block_gas_limit:u64BE
                      ‖ coinbase:20 ‖ prevrandao:32 )

check_hash = keccak256( "reckn/zk/check/evm/v2"
                      ‖ address:20 ‖ slot:32 ‖ min:U256BE ‖ max:U256BE )

plan_hash  = keccak256( "reckn/zk/plan/evm/v2"
                      ‖ caller:20 ‖ target:20 ‖ value:U256BE ‖ gas_limit:u64BE
                      ‖ len(calldata):u64BE ‖ calldata )

dealBinding = keccak256( "reckn/zk/bind/evm/v2"
                       ‖ state_root:32 ‖ env_hash:32 ‖ check_hash:32 ‖ plan_hash:32 )

traceHash   = SHA256( "reckn/zk/reexec/v2" ‖ prestate_root:32
                    ‖ pre:U256BE ‖ post:U256BE ‖ min:U256BE ‖ max:U256BE ‖ outcome:u8 )

// predicate guest
traceHash   = SHA256( "reckn/zk/verdict/v2"
                    ‖ pre:U256BE ‖ post:U256BE ‖ min:U256BE ‖ max:U256BE ‖ outcome:u8 )

// SVM guest (lamports zero-extended to U256 so the shared ABI stays one record)
dealBinding = SHA256( "reckn/zk/bind/svm/v2"
                    ‖ bank_hash:32 ‖ account:32 ‖ min:U256BE ‖ max:U256BE ‖ signature:64 )
```

Every preimage is unambiguous: fixed-width fields throughout, with the one variable-length
field (`calldata`) length-prefixed.

**Why the tags move to v2 and not stay at v1.** Two different functions must never share a
domain tag; that is the only thing a tag is for. The preimages change regardless of the tag
string (widths, byte order, new `env_hash`, new `gas_limit`), so keeping `v1` would leave two
distinct functions under one name. Nothing coexists: no v1 artefact survives 008 (all four
fixtures are regenerated) and nothing is deployed on any chain. The cost is documentation
drift, handled in §9 and OQ-1 / OQ-2.

### 3.6 Engine identity, made mechanical

"Both sides run the same engine" is a claim about two files. 008 turns it into three
checkable things.

1. **One conversion, one place.** `zk-verdict/script/src/lib.rs` gains
   `pub fn to_guest_input(anchor: &EvmAnchorV1, witness: &PrestateWitnessV1,
   plan: &EvmCallPlanV1, check: (Address, U256, U256, U256)) -> GuestInput`, and it is the
   only function in the repository that constructs a `GuestInput`. It **destructures
   `EvmAnchorV1`, `AccountWitness`, `StorageWitnessV1` and `EvmCallPlanV1` exhaustively, with
   no `..` rest pattern**, so a new field on any of them is a compile error rather than a
   silent omission. Two anchor fields are carried into an explicit exclusion set with a
   reason: `block_hash` and `block_header` (N-5 — the guest has no header layer, and
   `BLOCKHASH` is unavailable to both engines, R-2).
2. **`GuestEnv` is applied field by field.** Every one of its 8 fields appears on the
   right-hand side of an assignment in `program-revm/src/main.rs`'s `modify_cfg_chained` /
   `modify_block_chained`.
3. **A script proves 1 and 2 without running anything** —
   `zk-verdict/scripts/env-parity.sh` extracts the field-name list of each struct from its
   `pub struct` declaration and compares it to the destructuring pattern / assignment set.
   AC-6.

4. **And a differential test proves it by execution.** `zk-verdict/script/tests/` runs, for
   each vector, (i) `reckn_reexec_evm::replay(...)` and (ii) the **real guest ELF** through
   SP1 `execute()`, and asserts the two agree. Comparing the real artefact rather than an
   extracted library is deliberate: `zk-verdict/program-revm` is its own cargo workspace
   (`program-revm/Cargo.toml` ends with a bare `[workspace]`), so a library shared with
   `script` would be subject to a different feature unification than the ELF and would prove
   the wrong thing.

**Outcome codes have two encodings and one mapping.** `verdict_lib` and
`RecknVerdictVerifier` use `REPRODUCED = 0`, `FAILED = 1` (`lib/src/lib.rs:35-36`,
`RecknVerdictVerifier.sol:34-35`); `ReplayRecordV1` uses `Reproduced = 1`, `Failed = 2`
(`reexec-evm/src/lib.rs:567-570`). They must never be compared without conversion.
`zk_outcome(&Verdict) -> u8` in `zk-verdict/script/src/lib.rs` is the single home of that
mapping (INV-10, AC-8).

---

## 4. State machine

### 4.1 The three outcomes of a proof attempt, and the three of a replay

```
guest:      NoProof            Verdict(REPRODUCED=0)   Verdict(FAILED=1)
            (panic → SP1 execute/prove returns Err; no proof can exist)

off-chain:  Err(OperationalError)   Reproduced             Failed(reason)
```

Guest transitions into `NoProof`, exhaustively — these are the only panics permitted:

| # | cause | mirrors |
|---|---|---|
| P-1 | account MPT proof invalid | `WitnessVerificationError::AccountProofMismatch` |
| P-2 | storage MPT proof invalid | `WitnessVerificationError::StorageProofMismatch` |
| P-3 | `keccak(code) != code_hash` | `WitnessVerificationError::CodeHashMismatch` |
| P-4 | duplicate account or duplicate slot in the witness | `Duplicate{Account,StorageSlot}` |
| P-5 | **read of an account not in the witness** (new) | `OperationalError::MissingAccountWitness` |
| P-6 | **read of a slot not in the witness for a witnessed account** (new) | `OperationalError::MissingStorageWitness` |
| P-7 | **`BLOCKHASH` (0x40)** (new — no block-hash witness exists) | `OperationalError::MissingBlockHashWitness` |
| P-8 | **the checked `(address, slot)` is absent from the witness** (new) | `OperationalError::MissingPredicateWitness` (`reexec-evm/src/lib.rs:482-486`) |
| P-9 | **`env.spec_id` is not a known `SpecId`** (new) | no off-chain analogue — off-chain takes a typed `SpecId`, so a bad byte cannot arise there. This is the one place option (b) survives. |

A CALL that reverts or halts is **not** a panic: it is `Failed`, on both sides
(`main.rs:140-147`, `reexec-evm/src/lib.rs:540-541`, `:555-557`).

### 4.2 The agreement table (all nine combinations)

| off-chain \ guest | `NoProof` | `REPRODUCED` | `FAILED` |
|---|---|---|---|
| `Err(OperationalError)` | **required** (INV-2) | forbidden — INV-2 | forbidden — INV-2 |
| `Reproduced` | forbidden — INV-2 | **required** (INV-1) | forbidden — INV-1 (false refund; §2.1 mirror case) |
| `Failed(_)` | forbidden — INV-2 | forbidden — INV-1. **This cell is the false release of §2.1.** | **required** (INV-1) |

Three cells are required; six are forbidden. AC-2 / AC-3 / AC-4 are exactly the tests that
the six are empty for the enumerated vector set.

### 4.3 States and transitions that do not exist

- **A fourth guest verdict.** `delta_outcome` is total into `{0, 1}`, so no `GuestInput`
  produces `outcome ∉ {0,1}`. `RecknZkEscrow.sol:113-114`'s `BadOutcome` branch is therefore
  unreachable from any guest in this repository. It stays (defence against a future guest,
  and N-1 forbids touching the file), but no test may claim to reach it through a proof.
- **A verdict about a prestate that is not `state_root`.** P-1…P-4 make it unreachable, and
  `traceHash` binds `state_root` regardless.
- **A verdict about an environment other than the bound one.** After §3.5, `dealBinding`
  covers `env_hash`, so a proof under a different environment carries a different binding and
  `settleWithProof` reverts `BindingMismatch` (`RecknZkEscrow.sol:103`). AC-7b.
- **`fund` / `settleWithProof` / `refundAfterDeadline` gaining a transition.** 008 changes no
  escrow state machine. There is no new state, no new event, no new error. (N-1, AC-0b.)
- **A partial widening.** There is no state in which `pre` is `U256` and `minDelta` is `u64`:
  §3.4 widens all four in one struct, and INV-8 pins the encoded length so a half-migration
  cannot compile against the fixtures.

---

## 5. Invariants

- **INV-1 — agreement.** For every input in domain **D** (§5.1), the guest's committed
  `outcome` equals `zk_outcome(reexec_evm::replay(anchor, witness, plan, predicate,
  commitments)?.verdict)`, and the guest's committed `pre` / `post` equal the off-chain
  `read_pre_slot` / `read_post_slot` values **exactly as `U256`**, and `minDelta` / `maxDelta`
  equal the funded predicate's `min` / `max` exactly.
- **INV-2 — no verdict where the backend has none.** `replay` returns
  `Err(OperationalError)` **if and only if** the guest produces no proof (SP1 `execute`
  returns `Err`). Neither direction may be one-sided: a guest that panics more than the
  backend refuses is a liveness bug; a guest that panics less is the §2.3 false release.
- **INV-3 — no truncation.** For every vector, the committed `pre`, `post`, `minDelta`,
  `maxDelta` equal the exact 256-bit values. Operationally: the EVM guest path contains no
  narrowing conversion at all (AC-5).
- **INV-4 — causality survives magnitude.** `post ≤ pre ⟹ credited = 0`, for all `U256`.
  A seller who does nothing, or who *reduces* the checked slot, cannot satisfy `min ≥ 1` **at
  any magnitude**. This is the `--credit 42 → delta 0 → Failed` property of
  `zk-verdict/README.md:143`, restated over the whole domain — and it is precisely what
  `pre = 2^64, post = 2^64 − 1` breaks today.
- **INV-5 — the binding covers the whole verdict input.** Two `GuestInput`s that differ in
  any one of the 18 components of §6 AC-7 produce different `dealBinding`; and `dealBinding`
  is a function of exactly those 18. Everything else in `GuestInput` (the accounts and their
  proofs) is bound transitively, because it is MPT-verified against `state_root`, which is
  bound.
- **INV-6 — engine identity is data, not convention.** Every field of `EvmAnchorV1` is either
  carried into `GuestInput` or a member of the explicit exclusion set `{block_hash,
  block_header}`; every field of `AccountWitness`, `StorageWitnessV1`, `EvmCallPlanV1` and
  `GuestEnv` is carried / applied. Enforced by exhaustive destructuring (compile error) and
  by AC-6 (script).
- **INV-7 — version discipline.** After 008, the string `reckn/zk/` followed by any `/v1`
  appears nowhere under `zk-verdict/`. The tags are exactly
  `reckn/zk/{env,check,plan,bind}/evm/v2`, `reckn/zk/bind/svm/v2`,
  `reckn/zk/{reexec,verdict}/v2`.
- **INV-8 — the on-chain surface does not move.** `RecknZkEscrow.sol` is byte-identical to
  the 008 base commit. `scripts/no-keys.sh`'s enumerated surface is unchanged.
  `abi.encode(VerdictPublicValues)` is 224 bytes before and after.
- **INV-9 — the SVM guest is semantics-preserving.** For all `(a, b, lo, hi) ∈ u64⁴`,
  `delta_outcome(U256::from(a), U256::from(b), U256::from(lo), U256::from(hi))` equals the
  pre-008 `u64` result. (`saturating_sub` commutes with zero-extension on `u64` inputs.)
- **INV-10 — one outcome mapping.** The `Verdict → u8` conversion exists in exactly one
  function. No other site compares a `verdict_lib` outcome byte with a `ReplayRecordV1`
  outcome byte.
- **INV-11 — the honest scope is not silently widened.** Every residual in §8 that 008 does
  not close appears verbatim in `zk-verdict/README.md`'s honest scope, and every claim 008
  *does* close is removed from the root `README.md` "Known gaps" list in the same commit.
  (AC-14.)

### 5.1 The domain D over which INV-1 is asserted

INV-1 is a universal statement and its domain is stated, not implied. **D** = inputs where:
the predicate is a `PostStateDelta` with **exactly one** check (N-4); `anchor.block_header`
is `None` (N-5); the execution does **not** enter `0x01`, `0x0a`, or `0x0b`–`0x11` (R-3 — the
two engines run different backends for those and equivalence is untested); and the execution
does not read `DIFFICULTY` (0x44 pre-Merge semantics) or `BLOBBASEFEE` (0x4a) (R-1 — both
engines return the same `BlockEnv::default()` constant, so they agree with each other but
neither is anchored to a real block).

**INV-1 says the two engines agree. It does not say either matches mainnet.** The differential
is against `reexec-evm`, not against a node. Nothing in 008 may be written as if it were.

---

## 6. Acceptance criteria

**Tier: local.** `cargo` (crates.io cache warm), `forge 1.7.1`, and the SP1 toolchain
(`~/.sp1/bin/cargo-prove`) for the ELF builds and `execute`. The four committed Groth16
fixtures additionally need SP1's ~6.2 GB v6.1.0 circuit artifacts, but only to *regenerate*;
AC-9 verifies the committed ones without proving.

### 6.0 How an AC is decided — and why an exit status alone is not enough

Two facts, re-verified today rather than quoted:

```sh
# forge 1.7.1 (Commit SHA 4072e48705af9d93e3c0f6e29e93b5e9a40caed8), zk-verdict/contracts
forge test --match-test "test_no_such_test_008"; echo "EXIT=$?"
# No tests found in project! Forge looks for functions that start with `test`
# EXIT=0

# cargo, zk-verdict/lib
cargo test no_such_test_at_all > /tmp/ct.txt 2>&1; echo "EXIT=$?"; grep "test result" /tmp/ct.txt
# EXIT=0
# test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 2 filtered out; finished in 0.00s
```

`forge test` has **no `--fail-on-no-tests` flag in 1.7.1** (`forge test --help` lists
`--json` and `--summary` and nothing of the kind). So **every AC in this document asserts a
count before it asserts success**, and `zk-verdict/scripts/ac008.sh` implements exactly this:

```
kind = cargo   (columns: dir, selector, tests)
  cd <dir>
  cargo test -- --list <selector>            # `selector` is a libtest SUBSTRING, never a regex
     n_listed = number of lines matching ': test$'   →  must equal `tests`
  cargo test -- <selector>                   # exit status must be 0
     over every line matching '^test result:':
        at least one such line must exist
        sum of `N passed`  must equal `tests`
        every line must show `0 failed` and `0 ignored`   # kills `#[ignore]` as an escape
  selector `-` means "no filter" (the whole package).

kind = forge   (columns: selector, tests)
  cd zk-verdict/contracts
  forge test --match-test "<selector>" --json > out.json
  jq -e --argjson n <tests> '
      [.[].test_results | to_entries[]] as $t
      | ($t | length) == $n
        and ([$t[] | select(.value.status != "Success")] | length) == 0' out.json
  # `--match-test` takes ONE regex. Alternation is `|`. A space is a literal space and
  # matches nothing — 003 r1 finding 2. No selector below contains a space.

kind = script  (columns: command, evidence)
  run <command>; exit status must be 0; stdout must contain the `evidence` line verbatim.
```

Two consequences that are part of the spec, not of the implementation:

- Rust test names must literally contain `_ACnn_`, so every test file under
  `zk-verdict/script/tests/` and the test module in `zk-verdict/lib/src/lib.rs` begins with
  `#![allow(non_snake_case)]` and names tests `test_AC02_V03_…`. Without this the implementer
  will lower-case them and every `cargo` selector silently matches zero.
- All 52 of `zk-verdict/script`'s tests live in `zk-verdict/script/tests/`;
  `zk-verdict/script/src/lib.rs` contains no `#[test]`.

**Every AC below carries a `Falsify:` line — a concrete degenerate implementation that makes
that AC exit non-zero.** An AC without one is not an acceptance criterion. AC-13 checks
mechanically that the count assertions are load-bearing.

### 6.1 The manifest (parsed by `zk-verdict/scripts/ac008.sh` from this file)

Columns: `AC`, `kind` ∈ {`cargo`,`forge`,`script`}, `dir` (`cargo` only), `selector`,
`tests` (exact; `-` for `script`), `evidence` (verbatim stdout line for `script`; `-`
otherwise). Multi-space separated; `#` starts a comment.

```ac008-manifest
AC-00   script  -                   bash scripts/no-keys.sh                          -   the claim holds: no key can move a funded escrow.
AC-00b  script  -                   bash zk-verdict/scripts/surfaces.sh              -   surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged
AC-01   cargo   zk-verdict/lib      _AC01_                                           8   -
AC-02   cargo   zk-verdict/script   _AC02_                                          14   -
AC-03   cargo   zk-verdict/script   _AC03_                                          11   -
AC-04   cargo   zk-verdict/script   _AC04_                                           3   -
AC-05   script  -                   bash zk-verdict/scripts/no-truncation.sh         -   no-truncation: 5/5 patterns absent in 3 files
AC-06   script  -                   bash zk-verdict/scripts/env-parity.sh            -   env-parity: anchor 11 = 9 carried + 2 excluded; env 8/8; account 8/8; storage 3/3; plan 5/5
AC-07a  cargo   zk-verdict/script   _AC07_                                          18   -
AC-07b  forge   -                   _AC07_                                           2   -
AC-08   cargo   zk-verdict/script   _AC08_                                           6   -
AC-09   script  -                   bash zk-verdict/scripts/fixtures-check.sh        -   fixtures: 4/4 current (vkey and public values byte-identical)
AC-10   forge   -                   _AC10_                                           4   -
AC-11   script  -                   bash zk-verdict/scripts/no-skip.sh               -   no-skip: 0 fixture gates, 0 skipped, 18/18 forge tests ran
AC-12   cargo   zk-verdict/lib      _AC12_                                           3   -
AC-13   script  -                   bash zk-verdict/scripts/ac008-selftest.sh        -   ac008-selftest: 10 counted rows, 10 observed failing when their tests are renamed
AC-14   script  -                   bash zk-verdict/scripts/docs-check.sh            -   docs: 3/3 digests changed, 12/12 cycle sites match cycles.json, 2 unmeasured sub-figures removed
AC-15   cargo   reexec-evm          -                                               16   -
```

Arithmetic `ac008.sh --check` recomputes and a reviewer can recompute by hand:

- **18** manifest rows, **16** acceptance criteria (AC-0 … AC-15; AC-00/AC-00b and
  AC-07a/AC-07b are two rows each of one criterion).
- **8** `cargo` rows; their `tests` column sums to **79**.
- **2** `forge` rows; their `tests` column sums to **6**.
- **8** `script` rows.
- Per package: `zk-verdict/lib` = **11** (8 + 3, the whole package),
  `zk-verdict/script` = **52** (14 + 11 + 3 + 18 + 6),
  `reexec-evm` = **16** (unchanged; 008 adds testkit builders and **zero** tests there —
  measured today: 10 in `src/lib.rs`, 6 in `src/header.rs`).
  11 + 52 + 16 = **79** ✓.
- `zk-verdict/contracts` = **18** forge tests = **12** pre-existing (measured 2026-09-04 via
  `forge test --json | jq '[.[].test_results|to_entries[]]|length'` → 12) + **6** new.
  AC-11 asserts 18.
- AC-13's counted rows = 8 `cargo` + 2 `forge` = **10**.

`bash zk-verdict/scripts/ac008.sh --all` runs every row, asserts it ran **18**, and prints
`ac008: 18/18 rows passed`. `--all --sandbox <path>` runs the other **17** (AC-13 is a
harness *of* the harness and re-entering it would recurse) and prints
`ac008: 17/17 rows passed (sandbox)`.

---

### AC-0 — the central claim still holds (fixed text, `reckn-spec` charter)

```sh
bash scripts/no-keys.sh                      # exit 0
bash zk-verdict/scripts/ac008.sh AC-00       # same command, via the manifest
```

008 adds **no** external or public function to any contract. The enumerated surface
(`fund` / `settleWithProof` / `refundAfterDeadline`) is unchanged, so `AGENTS.md` §0 and
`scripts/no-keys.sh` need no edit and the claim is unchanged: **there is still no key that
can move a funded escrow.** What changes is orthogonal to the claim and is stated in §9:
008 removes a way for *a proof* to move it wrongly.

**Falsify:** add `address public owner;` to `contract RecknZkEscrow` → check 1 fails.

### AC-0b — `RecknZkEscrow.sol` was not touched, and `reexec-evm`'s production surface was not touched

```sh
bash zk-verdict/scripts/surfaces.sh
# surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged
```

The script (a) compares `sha256(zk-verdict/contracts/src/RecknZkEscrow.sol)` against the
value recorded in `zk-verdict/scripts/surfaces.pinned` at the 008 base commit, and
(b) compares `sha256` of everything in `reexec-evm/src/lib.rs` **above** the line
`#[cfg(any(test, feature = "testkit"))]` that precedes `pub mod testkit` against its pinned
value. (b) is what guarantees N-3 and therefore that `binder`, `keeper` and
`reckn-evm-content` still compile without being edited.

**Falsify:** change any byte of `RecknZkEscrow.sol`, or move a single line of `replay`.

### AC-1 — the verdict arithmetic is correct over the whole 256-bit domain

```sh
bash zk-verdict/scripts/ac008.sh AC-01     # cargo, zk-verdict/lib, selector _AC01_, 8 tests
```

The boundary pool **P** (15 elements, fixed, no randomness):

```
0, 1, 2, 10^18, u64::MAX-1, u64::MAX, 2^64, 2^64+1, 20*10^18,
2^128-1, 2^128, 2^128+1, 2^192, U256::MAX-1, U256::MAX
```

1. `test_AC01_exhaustive_boundary_pool` — all **15⁴ = 50 625** quadruples
   `(pre, post, min, max) ∈ P⁴`, each checked against the definition
   `REPRODUCED ⟺ min ≤ sat_sub(post, pre) ≤ max`.
2. `test_AC01_seeded_uniform` — 200 000 draws, **seed `0x008` printed by the test**, `pre`
   uniform over `U256`, `post = pre ± d` with `d` uniform over `U256`.
3. `test_AC01_no_op_credits_nothing` — ∀ `x, min, max ∈ P`: `delta_outcome(x, x, min, max)`
   is `REPRODUCED` iff `min == 0`.
4. `test_AC01_decrease_credits_nothing` — ∀ `a < b ∈ P`, ∀ `min, max ∈ P`:
   `delta_outcome(b, a, min, max)` is `REPRODUCED` iff `min == 0`.
5. `test_AC01_exact_delta` — ∀ `pre, d ∈ P` with `pre + d ≤ U256::MAX`: `REPRODUCED` iff
   `min ≤ d ≤ max`.
6. `test_AC01_monotone_in_post` — credited is non-decreasing in `post` for fixed `pre`.
7. `test_AC01_honest_credit_and_short_fill` — the pre-existing
   `lib/src/lib.rs:96-103` test, rewritten over `U256`.
8. `test_AC01_trace_hash_v2_is_deterministic_and_binds_outcome` — the pre-existing
   `lib/src/lib.rs:106-112` test, rewritten for the v2 preimage, plus: the v2 digest for the
   fixture values **differs** from the v1 digest (the tag bump is real, not cosmetic).

**Falsify:** restore `delta_outcome(u64_low(pre), u64_low(post), …)` — test 1 fails on
`(2^64, 2^64−1, 1, U256::MAX)`. **Degenerate implementation this is written to kill:**
special-casing the demo values (`if pre == 42 { … }`) cannot survive 50 625 quadruples over
15 distinct magnitudes.

### AC-2 — the guest commits untruncated values, through the real ELF

```sh
bash zk-verdict/scripts/ac008.sh AC-02     # cargo, zk-verdict/script, _AC02_, 14 tests
```

One `#[test]` per vector (so the count assertion bites). Each test builds the witness with
`reexec-evm`'s testkit, runs `reckn_reexec_evm::replay` **and** the real guest ELF through
SP1 `execute()`, and asserts: same `outcome` (via `zk_outcome`), and the guest's committed
`pre` / `post` / `minDelta` / `maxDelta` equal the off-chain `U256` values **exactly**.

Target code is `testkit::SSTORE_SLOT7_RUNTIME` (`5f 35 60 07 55 00`), which writes
`calldata[0:32]` to slot 7; environment is the testkit anchor (`CANCUN`, `base_fee = 0`,
caller nonce 0) unless noted. `pre` is the committed prestate value of slot 7.

| id | `pre` | `post` (calldata word) | `min` | `max` | true delta | expected | guest **today** |
|---|---|---|---|---|---|---|---|
| V-01 | 42 | 142 | 100 | `U256::MAX` | 100 | `Reproduced` | agrees (regression guard) |
| V-02 | 42 | 42 | 1 | `U256::MAX` | 0 | `Failed` | agrees (no-op control) |
| V-03 | `2^64` | `2^64−1` | 1 | `U256::MAX` | 0 | **`Failed`** | `Reproduced` — **the false release** |
| V-04 | 1 | `2^64` | `2^64−1` | `U256::MAX` | `2^64−1` | **`Reproduced`** | `Failed` — false refund |
| V-05 | `2^64−1` | `2^64` | 1 | `U256::MAX` | 1 | **`Reproduced`** | `Failed` |
| V-06 | `2^64−1` | `2^64−1` | 1 | `U256::MAX` | 0 | `Failed` | agrees |
| V-07 | `2^64` | `2^64` | 0 | 0 | 0 | `Reproduced` | agrees |
| V-08 | 1 | `U256::MAX` | `U256::MAX−1` | `U256::MAX` | `U256::MAX−1` | **`Reproduced`** | `Failed` |
| V-09 | `U256::MAX` | 1 | 1 | `U256::MAX` | 0 | `Failed` | agrees (by luck) |
| V-10 | `2^128` | `2^128+1` | 1 | 1 | 1 | **`Reproduced`** | `Failed` |
| V-11 | `2^192` | `2^192−1` | 1 | `U256::MAX` | 0 | **`Failed`** | `Reproduced` — **false release at limb 3** |
| V-12 | `u64::MAX` | `u64::MAX + 10^18` | `10^18` | `U256::MAX` | `10^18` | **`Reproduced`** | `Failed` — **the `002` case: 18.446744073709551615 tokens credited one more token** |
| V-13 | 1 | `20·10^18` | `20·10^18 − 1` | `U256::MAX` | `20·10^18 − 1` | **`Reproduced`** | impossible — `min` is not representable in `u64` today |
| V-14 | **0, via a storage exclusion proof** | `10^18` | `10^18` | `U256::MAX` | `10^18` | `Reproduced` | agrees (both below `2^64`) — the zero-balance recipient `002` needs |

Polarity is deliberately mixed — **9 `Reproduced`, 5 `Failed`** — so neither a
constant-`Failed` nor a constant-`Reproduced` guest passes.

V-14 needs a testkit builder that produces an **exclusion** proof for `keccak(slot 7)`: build
the storage trie with a different leaf present (e.g. slot 9 = 1) and retain the proof for the
absent target. `reexec-evm`'s verifier already handles this case
(`reexec-evm/src/lib.rs:81-82`, `:360`); only the builder is missing. If
`ProofRetainer::from_iter` does not retain nodes for a target absent from the trie, build a
two-leaf trie and take the branch path (the standard exclusion proof). If neither works,
**stop and report** — do not drop the vector and do not synthesise a fake proof.

**Falsify:** keep `let pre_u = u64_low(pre);` in the guest while making `delta_outcome`
`U256`-correct — AC-1 passes, AC-2 fails at V-03. Or return a constant outcome — at least 5
vectors fail either way.

### AC-3 — the guest runs the same engine, pinned by data

```sh
bash zk-verdict/scripts/ac008.sh AC-03     # cargo, zk-verdict/script, _AC03_, 11 tests
```

Same differential harness. `pre = 42` throughout; `min = max = expected delta` (exact, so a
post that is off by one fails). **Every probed field differs from the testkit default**, so an
implementation that hard-codes the current fixture's environment fails.

| id | probe (target runtime) | environment | expected `post` | expected | guest **today** |
|---|---|---|---|---|---|
| E-01 | `SSTORE_SLOT7_RUNTIME` (begins with `PUSH0`) | `spec = MERGE` | — (invalid opcode → halt) | `Failed` | `Reproduced` (guest runs `OSAKA`) |
| E-02 | same | `spec = SHANGHAI` | 142 | `Reproduced` | agrees — positive control that E-01 fails on the *spec*, not the code |
| E-03 | `TIMESTAMP` `42 60 07 55 00` | `timestamp = 1_700_000_123` | `1_700_000_123` | `Reproduced` | `Failed` (guest default `timestamp = 1`) |
| E-04 | `NUMBER` `43 60 07 55 00` | `block_number = 19_000_007` | `19_000_007` | `Reproduced` | `Failed` (default `0`) |
| E-05 | `COINBASE` `41 60 07 55 00` | `coinbase = addr(0xc1)` | `uint160(0xc1c1…c1)` — a value **above `2^64`** | `Reproduced` | `Failed` (default `Address::ZERO`) |
| E-06 | `PREVRANDAO` `44 60 07 55 00` | `prevrandao = 0x3333…33` | `0x3333…33` — above `2^64` | `Reproduced` | `Failed` (default `B256::ZERO`) |
| E-07 | `GASLIMIT` `45 60 07 55 00` | `block_gas_limit = 36_000_000` | `36_000_000` | `Reproduced` | `Failed` (default `u64::MAX`) |
| E-08 | `CHAINID` `46 60 07 55 00` | `chain_id = 8453` | `8453` | `Reproduced` | **agrees today** — the positive control that the vector set is not rigged to only show failures |
| E-09 | `BASEFEE` `48 60 07 55 00` | `base_fee = 1_000_000_007` | `1_000_000_007` | `Reproduced` | `Failed` — needs both the block field **and** `disable_base_fee` |
| E-10 | `SSTORE_SLOT7_RUNTIME`, credit 142, `min = 100` | caller nonce `5` | 142 | `Reproduced` | `Failed` — needs `disable_nonce_check`. **This is what `002` hits on its first real transaction.** |

Plus `test_AC03_specid_u8_names_are_pinned`: for each of `MERGE`, `SHANGHAI`, `CANCUN`,
`PRAGUE`, `OSAKA`, `SpecId::try_from_u8(<pinned u8>)` equals `SpecId::from_str("<pinned
name>")` (`revm-primitives-23.0.0/src/hardfork.rs:83-88`, `:149-177`, `:180-206`). A revm
version that renumbers the enum then fails loudly instead of silently remapping a fork.

**Falsify:** apply the spec but not the block env (E-03…E-07, E-09 fail); or hard-code the
testkit defaults as constants (E-03…E-09 fail, because every one of them differs from the
default); or apply the env but omit `disable_nonce_check` (E-10 fails).

### AC-4 — the guest's database is closed over the witness

```sh
bash zk-verdict/scripts/ac008.sh AC-04     # cargo, zk-verdict/script, _AC04_, 3 tests
```

| id | target runtime | off-chain | guest required |
|---|---|---|---|
| W-01 | `60 08 54 60 07 55 00` — `SLOAD(8)` then `SSTORE(7)`; slot 8 is **not** in the witness | `Err(MissingStorageWitness)` | SP1 `execute()` returns `Err` — **no verdict exists** |
| W-02 | `73 <20-byte un-witnessed addr> 31 60 07 55 00` — `BALANCE` of an un-witnessed account | `Err(MissingAccountWitness)` | `execute()` returns `Err` |
| W-03 | `60 07 54 60 07 55 00` — `SLOAD(7)` then `SSTORE(7)`; slot 7 **is** witnessed; `min = max = 0` | `Reproduced` (post = pre = 42, delta 0) | `Reproduced` — the positive control that W-01/W-02 fail for the missing-witness reason and not because any `SLOAD` panics |

This is INV-2 in both directions. It also closes R-3's *reachability*: with a witness-closed
database, entering `0x01` / `0x0a` / `0x0b`–`0x11` requires that address to be in the
witness, so an unnoticed precompile-backend divergence cannot arise from a plan the seller
smuggled in — it fails loudly on both sides instead.

**Falsify:** keep `InMemoryDB::default()` (`main.rs:102`) — W-01 and W-02 produce a verdict
where none may exist.

### AC-5 — no narrowing conversion survives in the EVM guest path

```sh
bash zk-verdict/scripts/no-truncation.sh
# no-truncation: 5/5 patterns absent in 3 files
```

Files: `zk-verdict/program-revm/src/main.rs`, `zk-verdict/lib/src/lib.rs`,
`zk-verdict/script/src/lib.rs`. Patterns (comment-stripped): `as_limbs`, `u64_low`,
` as u64`, `.to::<u64>()`, `try_into`.

**Falsify:** reintroduce `fn u64_low`.

### AC-6 — engine identity is enforced by field-set equality, not by a sentence

```sh
bash zk-verdict/scripts/env-parity.sh
# env-parity: anchor 11 = 9 carried + 2 excluded; env 8/8; account 8/8; storage 3/3; plan 5/5
```

The script parses field names out of `pub struct EvmAnchorV1` (11 fields, `reexec-evm/src/lib.rs:40-60`),
`AccountWitness` (8, `:64-78`), `StorageWitnessV1` (3, `:84-88`), `EvmCallPlanV1`
(5, `:98-104`) and `GuestEnv` (8), and asserts:

- every anchor field appears either in the exhaustive `let EvmAnchorV1 { … }` destructuring in
  `to_guest_input` or in that function's literal exclusion list `{block_hash, block_header}`,
  with a comment giving the reason;
- the destructuring contains **no `..` rest pattern** (same for the other three structs);
- every `GuestEnv` field name appears on the left of an assignment inside
  `program-revm/src/main.rs`'s `modify_cfg_chained` / `modify_block_chained` blocks;
- `disable_base_fee = true` and `disable_nonce_check = true` appear in **both**
  `program-revm/src/main.rs` and `reexec-evm/src/lib.rs`.

**Falsify:** add a field to `EvmAnchorV1` and not to the destructuring (also a compile error —
belt and braces); or add `timestamp` to `GuestEnv` and forget to apply it.

### AC-7a — `dealBinding` is a function of every byte the verdict reads

```sh
bash zk-verdict/scripts/ac008.sh AC-07a    # cargo, zk-verdict/script, _AC07_, 18 tests
```

One `#[test]` per bound component. Each takes a baseline `GuestInput`, changes **exactly one**
component to a different value, runs the real ELF through `execute()` twice, and asserts the
two committed `dealBinding` values differ:

`state_root`, `chain_id`, `spec_id`, `block_number`, `timestamp`, `base_fee`,
`block_gas_limit`, `coinbase`, `prevrandao`, `check.address`, `check.slot`, `check.min`,
`check.max`, `plan.caller`, `plan.target`, `plan.value`, `plan.gas_limit`, `plan.calldata`.

Eighteen components; the manifest's `tests` column says 18. Anything else in `GuestInput` —
the accounts and their proofs — is bound transitively through `state_root` (INV-5), which
P-1…P-4 make unforgeable.

**Falsify:** drop `timestamp` from `env_hash` — the `timestamp` test finds equal bindings.
Drop `gas_limit` from `plan_hash` — likewise. Revert to the v1
preimage entirely — **9 of 18** fail (the 8 environment components plus `plan.gas_limit`).

### AC-7b — a proof of another convenient execution cannot settle this deal

```sh
bash zk-verdict/scripts/ac008.sh AC-07b    # forge, _AC07_, 2 tests
```

Both tests use the **real** Groth16 headline fixture and SP1's real `SP1Verifier`:

1. `test_AC07_real_proof_settles_the_deal_it_is_bound_to` — fund with the fixture's
   `deal_binding`; `settleWithProof` pays the **seller**; escrow balance goes to zero.
2. `test_AC07_proof_from_another_execution_reverts_BindingMismatch` — fund the same deal
   shape with a `dealBinding` taken from a **different guest execution** (the value AC-7a's
   `timestamp` test computes, committed as a constant in
   `zk-verdict/contracts/test/fixtures/alt-binding.json` and regenerated by
   `fixtures-check.sh`); submitting the real proof reverts `BindingMismatch`.

This is the charter's requirement stated in code: *a proof of some other favourable execution
must not settle this deal.* After §3.5 that includes an execution that differs **only in the
block environment**, which v1 could not distinguish at all.

**Falsify:** fund test 2 with the fixture's own binding — it settles and the
`vm.expectRevert` fails.

### AC-8 — the two outcome encodings meet in exactly one function

```sh
bash zk-verdict/scripts/ac008.sh AC-08     # cargo, zk-verdict/script, _AC08_, 6 tests
```

One test per `Verdict` value: `Reproduced`, and `Failed(r)` for each of the five `FailReason`
variants (`Execution`, `ResultMismatch`, `PostStateMismatch`, `PostStateOutOfBounds`,
`PostStateDeltaOutOfBounds` — `reexec-evm/src/lib.rs:154-180`). Each asserts
`zk_outcome(&v)` equals `REPRODUCED = 0` / `FAILED = 1`, and that the raw `ReplayRecordV1`
code (`1` / `2`, `reexec-evm/src/lib.rs:567-570`) is **not** equal to it — i.e. the mapping is
not the identity and cannot be omitted.

**Falsify:** `fn zk_outcome(_) -> u8 { 0 }` — five tests fail. Or compare the record code
directly — every test fails.

### AC-9 — the committed fixtures are the current guests'

```sh
bash zk-verdict/scripts/fixtures-check.sh
# fixtures: 4/4 current (vkey and public values byte-identical)
```

For each of `groth16-fixture.json` (predicate), `reexec-groth16-fixture.json` (headline),
`reexec-falserelease-fixture.json` (**new**), `svm-groth16-fixture.json`, the script:

1. computes the current ELF's vkey and requires it to equal the fixture's `vkey` — this is
   the check that catches "changed the guest, did not regenerate", which would otherwise pass
   every on-chain test because each test constructs its verifier from the fixture's *own*
   vkey (`RecknReexecVerdict.t.sol:28,37`);
2. re-runs the guest with the fixture's declared inputs via SP1 `execute()` and requires the
   committed public values to be **byte-identical** to the fixture's `public_values`;
3. requires the four numeric fields to be encoded as **32-byte `0x`-prefixed hex strings**,
   not JSON numbers. This is not cosmetic: today's `max_delta` is the JSON integer
   `18446744073709551615`, which any double-based reader (`jq` included, verified) turns into
   `18446744073709552000`. A `U256` cannot survive a JSON number at all. Solidity reads them
   with `vm.parseJsonBytes32` and casts, exactly as `vkey` and `trace_hash` already are.

The two reexec fixtures are specified here so the artefact itself carries the fix:

| fixture | `pre` | `post` | `min` | `max` | outcome |
|---|---|---|---|---|---|
| `reexec-groth16-fixture.json` | `2^64` | `2^64 + 100` | `100` | `U256::MAX` | `Reproduced` (0) |
| `reexec-falserelease-fixture.json` | `2^64` | `2^64 − 1` | `1` | `U256::MAX` | `Failed` (1) |

The headline fixture's `pre = 2^64` cannot be produced by the pre-008 guest, which would
commit `pre = 0`. The second is V-03 — the exact attack — proven, and AC-10 shows it paying
the **buyer**.

**Falsify:** edit `program-revm/src/main.rs` and do not regenerate — the vkey mismatches.

### AC-10 — the widened record survives the round trip on-chain, and the attack refunds the buyer

```sh
bash zk-verdict/scripts/ac008.sh AC-10     # forge, _AC10_, 4 tests
```

1. `test_AC10_verifier_returns_untruncated_pre` — `verifyVerdict` on the headline fixture
   returns `got.pre == 2**64` and `got.post == 2**64 + 100`.
2. `test_AC10_reproduced_settles_to_seller_at_pre_above_2_64` — the same proof settles to the
   seller through `RecknZkEscrow`.
3. `test_AC10_false_release_vector_refunds_the_buyer` — the `reexec-falserelease` proof
   (`pre = 2^64`, `post = 2^64 − 1`) settles to the **buyer**. The cell that used to pay the
   seller now pays the buyer, on a real Groth16 proof.
4. `test_AC10_tampered_public_values_are_rejected` — a forged `VerdictPublicValues` with the
   widened field types reverts.

**Falsify:** revert `RecknVerdictVerifier`'s struct to `uint64` — test 1's `abi.decode`
reverts on dirty high bits.

### AC-11 — no test in the contracts suite can pass by not running

```sh
bash zk-verdict/scripts/no-skip.sh
# no-skip: 0 fixture gates, 0 skipped, 18/18 forge tests ran
```

- `grep -c 'vm.exists' zk-verdict/contracts/test/*.t.sol` summed over the directory must be
  **0** (it is **7** today, in four files). All four fixtures are committed and AC-9 keeps
  them current, so a missing fixture is a failure, not a reason to return early. The gates
  become `require(vm.exists(FIXTURE), "…")`.
- `forge test --json` over the whole suite must report **18** results, all `Success`, none
  `Skipped`.

**Falsify:** restore one `if (!vm.exists(F)) return;` — the gate count is 1.

### AC-12 — widening did not change the SVM or predicate guests' verdicts

```sh
bash zk-verdict/scripts/ac008.sh AC-12     # cargo, zk-verdict/lib, _AC12_, 3 tests
```

1. `test_AC12_u64_zero_extension_preserves_verdict` — exhaustive over the `u64` sub-pool
   `{0, 1, 2, 10^18, u64::MAX−1, u64::MAX}⁴` = **1 296** cases: the U256 `delta_outcome` on
   zero-extended arguments equals the pre-008 `u64` semantics, recomputed inline as the
   reference. (INV-9.)
2. `test_AC12_lamports_are_representable` — every `u64` lamport value zero-extends to a
   `U256` strictly below `2^64`, so the SVM guest never enters the region §2.2 describes.
3. `test_AC12_public_values_abi_is_224_bytes` — `VerdictPublicValues::abi_encode` of a record
   with all four fields at `U256::MAX` is exactly **224** bytes and round-trips
   losslessly. (INV-8.)

**Falsify:** mask the SVM values to 64 bits before widening, or sign-extend — test 1 fails.

### AC-13 — the acceptance criteria are not vacuous (negative control on the controls)

```sh
bash zk-verdict/scripts/ac008-selftest.sh
# ac008-selftest: 10 counted rows, 10 observed failing when their tests are renamed
```

For each of the **10** `cargo` / `forge` rows in the manifest, in a sandbox copy of the repo,
rename that row's tests (`sed 's/test_AC02_/xtest_AC02_/g'`, and for AC-15 which has no
selector, rename `#[test]` to `#[allow(dead_code)]`), then run
`ac008.sh --sandbox <path> <AC>` and require a **non-zero** exit. The script prints one line
per row and the summary above.

This is the criterion that would have caught 003 r1's blocker 1 before it shipped: an AC that
is decided by exit status alone passes here, and so fails the selftest.

**Falsify:** change any counted row to decide on exit status alone — that row passes with its
tests renamed, and the selftest reports `9/10`.

### AC-14 — the documents moved in the same commit

```sh
bash zk-verdict/scripts/docs-check.sh
# docs: 3/3 digests changed, 12/12 cycle sites match cycles.json, 2 unmeasured sub-figures removed
```

**(i) Three pinned digests must no longer match.** Extraction recipes and the pre-008 values,
computed today:

```sh
awk '/^### Honest scope of the re-execution guest/{f=1} f&&/^## /&&!/^### /{exit} f' zk-verdict/README.md | shasum -a 256
# 8f65b75fc03774b532fe69c2e8bb0908656535d931542ff00990289cd9a6cac1   (11 lines)
awk '/^## 5\. /{f=1} f&&/^## /&&!/^## 5\. /{exit} f' AGENTS.md | shasum -a 256
# fd4521ed78b3b4e8dfddcf81b6eaf6b2e34a8148a946a1cf44d052b753a5b014   (19 lines)
awk '/^### Known gaps \(not closed\)/{f=1} f&&/^## /&&!/^### /{exit} f' README.md | shasum -a 256
# 04f567a3ae15dbb36a5528563deb7f25cb65e000615880eee1681776ae7c6dbe   (38 lines)
```

The script requires each current digest to **differ** from its pinned value, and requires the
new text to contain the literal sentences given in §9 (so "changed" cannot be satisfied by
deleting the section or by a whitespace edit).

**(ii) Cycle figures are re-measured, not carried over.** 008 changes all three guests, so
every published cycle count becomes an unmeasured claim (`AGENTS.md` §5). The script runs
`--execute` for `verdict`, `reexec` and `svm`, compares against
`zk-verdict/cycles.json` (`{measured_at, commit, programs:{verdict,reexec,svm}}`) requiring
**exact** equality (SP1 execution is deterministic for a fixed ELF and input, so no tolerance
is permitted), and then requires the exact integer to appear at all **12** sites:

`README.md:22`, `README.md:516`, `CLAUDE.md:36`, `zk-verdict/README.md:142`,
`docs/cross-chain-settlement.md:99`, `SUBMISSION.md:141` (reexec — 6);
`README.md:24`, `README.md:531`, `CLAUDE.md:50`, `zk-verdict/README.md:194`,
`SUBMISSION.md:148` (svm — 5); `zk-verdict/README.md:56` (predicate — 1).

Docs quote the **exact measured integer with `,` separators**, not `~NNNk`. The tilde is what
lets a stale number look current.

**(iii) Two unmeasured sub-figures are removed.** "of which MPT verification is ~180k"
(`CLAUDE.md:36`, `zk-verdict/README.md:143`) was never separately instrumented. 008 deletes
both clauses rather than inventing a measurement.

`docs/ethonline-2026/PLAN.md:20-21` is **excluded** from every check above: it is the
founder's document and `AGENTS.md` §8 forbids agents editing it. See OQ-1.

**Falsify:** leave `~410k` anywhere in the 12 sites; or leave the honest-scope section
unchanged.

### AC-15 — `reexec-evm` still passes, with the same number of tests

```sh
bash zk-verdict/scripts/ac008.sh AC-15     # cargo, reexec-evm, no filter, 16 tests
```

**16** — 10 in `src/lib.rs`, 6 in `src/header.rs`, counted today. 008 adds testkit *builders*
and **zero** tests to this package; its tests belong in `zk-verdict/`. Combined with AC-0b's
prefix digest, this is the whole of N-3.

**Falsify:** add a test here (17 ≠ 16), or break a testkit wrapper signature (a build error).

---

## 7. Test plan

### 7.1 Files

| path | contents |
|---|---|
| `zk-verdict/lib/src/lib.rs` (test module) | AC-1 (8), AC-12 (3) |
| `zk-verdict/script/src/lib.rs` | `to_guest_input`, `to_predicate`, `zk_outcome`, the differential runner. **No `#[test]`.** |
| `zk-verdict/script/tests/value_domain.rs` | AC-2, V-01…V-14 |
| `zk-verdict/script/tests/engine_identity.rs` | AC-3, E-01…E-10 + the `SpecId` name pinning |
| `zk-verdict/script/tests/witness_closed.rs` | AC-4, W-01…W-03 |
| `zk-verdict/script/tests/binding.rs` | AC-7a, 18 components |
| `zk-verdict/script/tests/outcome_map.rs` | AC-8, 6 |
| `zk-verdict/contracts/test/RecknVerdictDomain.t.sol` | AC-7b (2), AC-10 (4) |
| `zk-verdict/scripts/{ac008,surfaces,no-truncation,env-parity,fixtures-check,no-skip,ac008-selftest,docs-check}.sh` | the harness (8 scripts) |
| `zk-verdict/cycles.json`, `zk-verdict/scripts/surfaces.pinned` | committed measurements and digests |

### 7.2 Positive path (must pass)

`bash zk-verdict/scripts/ac008.sh --all` → `ac008: 18/18 rows passed`, and
`bash zk-verdict/scripts/zk-e2e.sh` still runs end to end with the regenerated fixtures.

### 7.3 Negative controls (must fail — this is the point of the exercise)

Each is applied in a sandbox, the named AC is run, and it **must** exit non-zero. AC-13
automates the first family; the rest are run once by hand and their output pasted into the
implementation report.

| # | break | must fail |
|---|---|---|
| NC-1 | restore `fn u64_low` and use it in `main.rs:163-164` | AC-1, AC-2, AC-5 |
| NC-2 | judge in `U256` but keep the `uint64` Solidity struct | AC-9 (public values differ), AC-10 |
| NC-3 | special-case the fixture: `if pre == U256::from(42) { … }` | AC-2 (13 of 14 vectors) |
| NC-4 | return `FAILED` unconditionally | AC-2 (9 vectors), AC-3 (9), AC-4 (1) |
| NC-5 | return `REPRODUCED` unconditionally | AC-2 (5), AC-3 (1), AC-10 (1) |
| NC-6 | apply `spec_id` but leave the block env at defaults | AC-3 (E-03…E-07, E-09) |
| NC-7 | hard-code the testkit anchor's env values as constants | AC-3 (E-03…E-09), AC-6 |
| NC-8 | omit `disable_nonce_check` | AC-3 (E-10) |
| NC-9 | keep `InMemoryDB::default()` | AC-4 (W-01, W-02) |
| NC-10 | drop `env_hash` from `dealBinding` | AC-7a (**8 of 18** — the environment components), AC-9 |
| NC-11 | drop `plan.gas_limit` from `plan_hash` | AC-7a (1) |
| NC-12 | `fn zk_outcome(_) -> u8 { 0 }` | AC-8 (5 of 6) |
| NC-13 | change a guest and do not regenerate the fixtures | AC-9 |
| NC-14 | restore one `if (!vm.exists(F)) return;` | AC-11 |
| NC-15 | leave `~410k` in `README.md:22` | AC-14 |
| NC-16 | edit one byte of `RecknZkEscrow.sol` | AC-0b |
| NC-17 | add a field to `EvmAnchorV1` without carrying it | AC-6 (and a compile error) |
| NC-18 | decide any counted AC on exit status alone | AC-13 |

### 7.4 Tests that will not be written

- **A test that only re-asserts `delta_outcome`'s definition against itself.** AC-1's value
  is the *pool*, which a truncating implementation cannot survive; a mirror-implementation
  oracle would be the same code twice.
- **A test of the pre-008 behaviour "for comparison".** The old guest is deleted, not kept.
- **Anything that runs against a chain.** Tier is local (§6). No anvil is started, no RPC is
  called, and no result here may be described as a testnet or mainnet result.
- **A cycle-count *improvement* test.** N-8. 008 measures; it does not optimise.

### 7.5 What the implementation report must state honestly

The measured cycle counts for all three guests (they will be larger), the wall time of the
four Groth16 regenerations, and — if `optional_no_base_fee` or the exclusion-proof builder
(V-14) does not work as §3.4 / AC-2 assume — a **stop**, not a workaround.

---

## 8. Residuals — what 008 does not close

Each appears verbatim in the rewritten honest scope (§9), because a residual that is only in
the spec is not disclosed.

- **R-1 — `DIFFICULTY` (0x44 pre-Merge) and `BLOBBASEFEE` (0x4a) are not anchored.** Both
  engines leave `BlockEnv::difficulty` and `blob_excess_gas_and_price` at
  `BlockEnv::default()` (`revm-context-16.0.1/src/block.rs:121-126`) because `EvmAnchorV1`
  does not carry them and 008 does not widen it (N-3). The two engines therefore **agree**
  with each other, and neither matches a real block, for plans reading those opcodes.
- **R-2 — `BLOCKHASH` (0x40) is unavailable.** Off-chain it is
  `OperationalError::MissingBlockHashWitness` (`reexec-evm/src/lib.rs:440-442`); in-guest,
  under AC-4's witness-closed database, it is P-7. Agreement holds; the opcode is unsupported.
- **R-3 — the precompile *backends* differ and their equivalence is untested.** The guest is
  `revm { default-features = false, features = ["optional_no_base_fee"] }` and the off-chain
  engine is `revm { features = ["optional_no_base_fee"] }` (defaults on). The feature delta is
  `{std, secp256k1, portable, tracer, c-kzg, blst}`. **No precompile is missing** — `k256`
  and `arkworks` are the fallbacks (`revm-precompile-34.0.0/src/secp256k1.rs:4-8`,
  `kzg_point_evaluation.rs:87-101`, `bls12_381.rs:8-14`) — so the previous claim that they are
  "disabled" was wrong. What is true is that `0x01`, `0x0a` and `0x0b`–`0x11` run *different
  implementations* on the two sides, and INV-1's domain **D** excludes plans that enter them.
  See OQ-3 for the only way to close it.
- **R-4 — the `state_root` ↔ block-header binding stays off-chain**, in
  `reexec-evm::header`. The guest never sees a header (N-5).
- **R-5 — one CALL, one delta check.** A full block or an arbitrary contract set is more
  cycles on the same architecture. That is a claim about architecture, not a measurement.
- **R-6 — INV-1 is agreement with `reexec-evm`, not with mainnet.** The differential runs two
  local engines. No result here says the guest reproduces a real chain.
- **R-7 — `min == 0` still admits a no-op.** `delta_outcome(x, x, 0, max) = REPRODUCED`, so a
  buyer who funds a zero floor pays for nothing. That is the buyer's predicate choice and 008
  does not override it, but it sits directly under the "a no-op cannot fake the credit"
  headline. See OQ-4.
- **R-8 — the escrow still has no timeout.** If P-1…P-9 make a proof impossible, a funded deal
  stays funded. That is `003`, not 008, and 008 *increases* the set of inputs for which no
  proof exists (P-5…P-9), which strengthens the case for `003` landing next.

---

## 9. Documentation obligations (same commit, no exceptions)

Six documents move with the code. AC-14 enforces the first three mechanically.

**(1) `zk-verdict/README.md`, "Honest scope of the re-execution guest"** — replaced. The new
text must contain these sentences verbatim (AC-14 greps for them):

> - **Is** the actual `revm` EVM executing a real CALL against an **MPT-authenticated
>   prestate**, under proof, **at the committed hardfork and block environment**, with a
>   database closed over the committed witness — a read outside the witness produces no proof,
>   exactly as the off-chain backend produces no verdict.
> - **Verdict values are `uint256`.** `pre`, `post`, `minDelta` and `maxDelta` are full
>   256-bit words; the guest applies no narrowing conversion. The earlier `u64` mapping was
>   not a limit but a soundness bug: with `pre = 2^64` and `post = 2^64 − 1` the checked slot
>   *decreased* and the guest proved the largest possible credit. Closed by task 008;
>   `reexec-falserelease-fixture.json` is that exact input, proven, refunding the buyer.
> - **Engine identity is checked, not assumed.** `zk-verdict/script/tests/` runs every vector
>   through both `reexec-evm` and the real guest ELF and requires the outcome and the exact
>   `U256` `pre`/`post` to agree.
> - **Not:** precompile *backends* differ between the two builds (`k256` / `arkworks`
>   in-guest, `secp256k1` / `c-kzg` / `blst` off-chain). No precompile is missing, but their
>   equivalence is untested, so plans entering `0x01`, `0x0a` or `0x0b`–`0x11` are outside the
>   checked domain. `BLOCKHASH` is unavailable to both. `DIFFICULTY` and `BLOBBASEFEE` read a
>   fixed default on both sides and are not anchored to a real block. One CALL, one delta
>   check. The `state_root`↔header binding stays in the off-chain `reexec-evm::header` layer.

**(2) `AGENTS.md` §5** — the bullet

> - verdict 値は `u64` にマップ（`u64_low` は limb 0 のみ。2^64 超の残高は切り捨て）

is replaced by

> - verdict 値は `uint256`（`pre`/`post`/`minDelta`/`maxDelta`）。切り捨ては無い。
>   **旧 `u64` マップは制限ではなく健全性バグだった**（`pre = 2^64` / `post = 2^64 − 1` =
>   残高**減少**が最大の入金として `Reproduced` になった）。task 008 で解消。
>   in-guest と off-chain のエンジン一致は `zk-verdict/script/tests/` の差分テストが
>   **実 ELF に対して**検定する。残る非対応面は `zk-verdict/README.md` の Honest scope に列挙。

and the precompile bullet

> - `c-kzg` / `ecrecover` precompile は in-guest で無効。これを要する plan は非対応

is replaced by

> - precompile は in-guest でも**欠けていない**（`k256` / `arkworks` にフォールバックする）。
>   ただし off-chain とは**実装が違う**（`secp256k1` / `c-kzg` / `blst`）。等価性は未検証なので
>   `0x01` / `0x0a` / `0x0b`–`0x11` に入る plan は検定済み領域の外。

The other three §5 bullets (one CALL + one delta check; the `state_root`↔header layer; the
"tier を超えない / 走らせていないものを passing と書かない" discipline) are unchanged.

**(3) Root `README.md`, "Known gaps (not closed)"** — the two bullets
"⚠ The `u64` verdict boundary is a soundness bug" (`README.md:574-581`) and
"**"The same engine runs in-guest" is UNVERIFIED**" (`:582-586`) are **removed**, and the
"In-guest precompiles" bullet (`:571-573`) is corrected to R-3's wording. The `RecknZkEscrow`
timeout bullet, the scale bullet, the header-binding bullet, the SVM bullet and the
"not yet submitted" bullet stay untouched (they are `003`'s and `AGENTS.md` §4's business).

**(4) Cycle counts** at the 12 sites listed in AC-14, from `zk-verdict/cycles.json`.

**(5) `STATUS.md`** — a row recording that 008 landed, that the four fixtures were
regenerated, that the binding domain tag moved `v1 → v2`, and the two documentation drifts
008 cannot fix itself (OQ-1, OQ-2).

**(6) Not edited by any agent:** `docs/ethonline-2026/PLAN.md` and `DISCLOSURE.md`
(`AGENTS.md` §8). PLAN.md:20-21 becomes stale — OQ-1.

---

## 10. OPEN QUESTION (founder)

- **OQ-1 — `docs/ethonline-2026/PLAN.md:20-21` goes stale and agents may not edit it.**
  It states `~410k cycles` and
  `dealBinding = keccak("reckn/zk/bind/evm/v1" ‖ state_root ‖ address ‖ slot ‖ min ‖ max ‖ plan_hash)`.
  After 008 both are false. Options: (a) founder edits PLAN.md in the same window;
  (b) founder accepts the drift and it is recorded in `STATUS.md` per `AGENTS.md` §4.
  **Recommendation: (a)** — PLAN.md is the document the Continuity narrative is built from,
  and a stale binding formula there is exactly the kind of thing a judge can check.

- **OQ-2 — 008 lands before `003` and `004`, and invalidates two things they pin.**
  `003`'s AC-16 pins the honest-scope digest `8f65b75f…9a6cac1`, which 008 must change;
  `003:341` and `004:171` quote the v1 binding formula, which 008 replaces. Both specs are
  in review with a different agent right now. Options: (a) 008 lands and `003`/`004` re-pin in
  their next round; (b) 008 holds its documentation changes until `003` lands.
  **Recommendation: (a)** — (b) would mean shipping the code fix with the false honest-scope
  text still in the repository, which is the failure mode `AGENTS.md` §5 exists to prevent.
  A one-line note in `STATUS.md` is the whole cost.

- **OQ-3 — precompile backend parity (R-3) is a production performance decision.** The only
  way to close it is to build `reexec-evm` with `default-features = false` so both engines run
  byte-identical `k256` / `arkworks` code. That makes the production backend measurably
  slower on `ecrecover` and KZG, and it affects `binder`, `keeper` and `reckn-evm-content`.
  **Recommendation: leave disclosed for ETHOnline** (no current plan enters those addresses,
  and AC-4's witness-closed database makes any such plan fail loudly on both sides rather than
  diverge silently). Revisit if `002`'s ERC-20 workload turns out to touch `0x01` — it should
  not; a plain `transfer` does not.

- **OQ-4 — should the guest refuse `min == 0` (R-7)?** A zero floor makes the delta predicate
  vacuous: a seller who does nothing satisfies it, which is the exact attack the causal delta
  exists to stop and which `zk-verdict/README.md:143` advertises as impossible. Refusing it in
  the guest is three lines and one more `NoProof` transition; keeping it preserves a
  legitimate "delta must be **at most** `cap`" predicate (`min = 0`, `max = cap`). This is a
  product decision about what a funded predicate is allowed to say, not an agent's.
  **Recommendation: keep `min == 0` legal and disclose R-7**, because refusing it silently
  removes a predicate shape the off-chain `PredicateV1::PostStateDelta` supports, which would
  create a *new* INV-1 violation in the opposite direction.

# 008 — verdict domain soundness

Status: spec, **round 2**. Owner: `reckn-spec`. Implementer: `reckn-codex-impl`.
Tier: **local machine only** — `cargo test`, `forge test`, SP1 `execute`, and SP1 CPU Groth16
for the four committed fixtures. **No anvil, no testnet, no mainnet, no network calls.**
Nothing in this document claims anything about a deployed chain.

Every fact cited below was re-checked against the files on disk on **2026-09-04**, after
`docs/reviews/008-spec-r1.md`. Numbers from round 1 are **not** carried over; where a round-1
number was wrong, the correction is named.

**Round-2 summary for the reviewer.** Fifteen r1 findings, all answered (§0). The decision
(a) is unchanged and the founder ruling that (b) is not a completion state is adopted verbatim.
The **harness shrank**: the ten-sandbox selftest is gone, the twelve-site exact-integer cycle
gate is gone, the two pinned documentation digests are gone, the bash parser of Rust struct
declarations is gone, and AC-5 folded into AC-6. What replaced them is **smaller and detects
more**: four committed mutation patches applied in place by the gate itself, and literal
sentence presence/absence instead of digests.

---

## 0. Round-1 findings — where each one landed

| # | sev | finding | round-2 response | where |
|---|---|---|---|---|
| 1 | BLOCKER | the harness reads test *names*; 79 tautologies pass; AC-13 only renames | AC-13 rewritten: **4 committed mutation patches, applied in place by the gate, each required to make a named row exit non-zero.** A body of `assert!(true)` survives a rename but **cannot survive a mutant** — it passes the mutant too, so the row does not fail, so the selftest fails. Self-reporting deleted from §7.3. | §6 AC-13, §7.3 |
| 2 | BLOCKER | AC-11 requires `grep vm.exists == 0` while prescribing `require(vm.exists(...))` | check restated over the **early-return pattern** `if (!vm.exists(` (7 today, all seven are that pattern — measured); `require(vm.exists(F), "…")` named as the permitted replacement | §6 AC-11 |
| 3 | MAJOR | AC-13 has no cost model; ten sandbox copies unaffordable | sandbox copies deleted. Cost model written, with the measured numbers and a **budget with a decision rule** (§6 AC-13 "Cost"). | §6 AC-13 |
| 4 | MAJOR | INV-2's *iff* is false: empty MPT proof accepted in-guest, refused off-chain | P-10 / P-11 added; **W-04 / W-05** added to AC-4. One correction to the finding: the *account* variant already agrees (the guest passes `Some(rlp(account))`, so an empty account proof can never return `Ok`); W-05 is kept as the control that records why, and P-10 makes the *reason* match, not just the outcome. `MissingCodeWitness` explained rather than left silent. | §4.1, §6 AC-4 |
| 5 | MAJOR | `anchor.block_header = Some(_)` silently dropped | `to_guest_input` becomes a **domain gate** and refuses it (G-1). INV-2 is now stated over **D** explicitly, and D is enforced at exactly one place. Vector **W-08**. | §3.6, §4.1, §5, §6 AC-4 |
| 6 | MAJOR | N-3's promise about `binder` is enforced by nothing | new manifest row **AC-16**: `cargo check --tests` in `binder`, `keeper`, `reckn-evm-content` (three standalone packages — verified: no root `Cargo.toml`, each has its own implicit workspace) | §6 AC-16 |
| 7 | MAJOR | AC-0b installs a build condition 003 must break; OQ-2 silent | stated as a **named cross-spec dependency** in §1.3 and OQ-2, with the re-pin protocol. `003`'s spec is not touched. | §1.3, OQ-2 |
| 8 | MAJOR | the third pinned digest is already stale; one §9(3) obligation already done; all three line ranges wrong | **all documentation digests dropped** (see below); §9(3) re-derived: precompile bullet **572-579** (already corrected in `9ac4545` — obligation is now "verify unchanged"), `u64` bullet **580-587**, engine bullet **588-592**, measured today | §6 AC-14, §9 |
| 9 | MAJOR | domain **D** is described, not enforced; a *witnessed* precompile address enters an untested backend pair | D is now **enforced** for the precompile clause, at `to_guest_input` (G-2), and the complementary case (unwitnessed) is closed by the witness-closed DB. Two vectors: **W-06 / W-07**. Codex's wider premise stays rejected per R-1 and is not re-litigated. | §3.6, §5.1, §6 AC-4 |
| 10 | MINOR | the `base_fee` half of §2.3 is false about today's guest | corrected: today's guest **does not reject** — it runs at `basefee = 0` and silently executes under a different base fee | §2.3 |
| 11 | MINOR | the `optional_no_base_fee` stop condition is a phantom | struck | §3.4 |
| 12 | MINOR | the (b) cost enumeration is incomplete in the flattering direction | completed (five more items named); decision unchanged | §3.2 |
| 13 | MINOR | `TxEnv` is covered by no layer | AC-6 gains a **`TxEnv` literal field-set comparison**; AC-3 gains **E-11 (`ORIGIN`)** and **E-12 (`GASPRICE`)**; INV-6 states what remains convention | §5, §6 AC-3, AC-6 |
| 14 | MINOR | AC-7b's fixture path contradicts the layout | `zk-verdict/contracts/src/fixtures/alt-binding.json` (verified: `src/fixtures/` is where the three committed fixtures live) | §6 AC-7b |
| 15 | MINOR | the `reckn/zk/verdict/v2` preimage is labelled "predicate guest"; SVM uses it too | relabelled | §3.5 |

**Why the documentation digests are dropped rather than re-pinned.** Recomputed today with the
spec's own recipes: `README.md` known-gaps → `222eeeb84230c54050e9db26c9c070e1425ac3c9d92e4193a98431dca05ef99f`
(44 lines, r1 pinned `04f567a3…`/38); `AGENTS.md` §5 → `4c868b6f8bcf279895ff3f1f48a02362c8b1656512d700976076bd7bc41fcced`
(25 lines, r1 pinned `fd4521ed…`/19); `zk-verdict/README.md` honest scope → `8f65b75f…9a6cac1`
(11 lines, unchanged). **Two of three are stale within a day.** `AGENTS.md` §5 moved because it
gained the "受入条件は名前でなく本体を検定する" bullet on the day the review was written. A digest
over a section three agents edit in parallel measures calendar noise, not the obligation. AC-14
checks the obligation instead: **named sentences absent, named sentences present** — cheaper,
survives concurrent edits, and not satisfiable by deleting the section.

The **code** pin (`surfaces.pinned`, AC-0b) is a different mechanism and stays: `RecknZkEscrow.sol`
must not move, and that is the central claim, not a document.

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
  gains builders, and the existing builder signatures stay as wrappers.
  **Enforced by AC-0b (prefix digest) *and* AC-16 (`cargo check --tests` in the three
  consumers)** — r1 asserted this and enforced neither half of the testkit surface.
- **N-4. The predicate surface does not widen.** One CALL, one `PostStateDelta` check,
  exactly as today. `ResultEquals` / `PostStateEquals` / `PostStateBounded` and multi-check
  predicates stay off-chain-only.
- **N-5. The `state_root` ↔ block-header binding stays in `reexec-evm::header`.** The guest
  never sees a header. `GuestInput` deliberately does not carry `block_hash` or
  `block_header`, and after r1 finding 5 an anchor that **has** a header is refused at the
  domain gate rather than silently stripped (§3.6, G-1).
- **N-6. Precompile *backend* parity is not closed** — see R-3. The guest and the off-chain
  engine run the *same precompile set* with *different implementations*, and their
  equivalence is untested. 008 closes the **reachability** of that set (G-2 + the
  witness-closed DB) but not the parity itself. Those are different claims and §9 says so.
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
- **N-11. 008 does not touch `docs/specs/003-*.md` or `docs/specs/004-*.md`.** They are in
  review with another agent. Where 008 creates an obligation for them it is written here as a
  dependency and in OQ-2, never as an edit to their text.

### 1.3 Cross-spec dependencies 008 creates (r1 finding 7)

008 is first in the execution order (`AGENTS.md` §3), so everything it pins, the next task
inherits. Two of those are load-bearing and one of them **003 must break**:

| what 008 installs | who breaks it | protocol |
|---|---|---|
| `zk-verdict/scripts/surfaces.pinned` — `sha256(RecknZkEscrow.sol)` (AC-0b) | **`003`**, necessarily: `AGENTS.md` §0 enumerates `refundAfterDeadline` and the contract does not have it (today it declares `fund` and `settleWithProof` and nothing else), and `003` r1 additionally rules the discarded `transferFrom` boolean in scope | **`003` re-pins `surfaces.pinned` in the same commit that changes `RecknZkEscrow.sol`, as a visible one-line diff** (`sha256 = <old>` → `sha256 = <new>`), never by a regenerate-and-commit step whose diff a reviewer cannot read. `surfaces.sh` must therefore print both the pinned and the computed digest on failure, so the re-pin is a copy of a printed value. |
| `zk-verdict/scripts/surfaces.pinned` — `sha256` of `reexec-evm/src/lib.rs` above the testkit `cfg` line (AC-0b) | nobody in the current order | if a later task needs it, same protocol |
| the v2 domain tags and the new honest-scope text | `003` (pins the honest-scope digest) and `004` (quotes the v1 binding formula) | OQ-2 |

**This is a dependency, not a request.** 008 does not edit `003`'s spec and does not require
`003` to be re-reviewed for it; the re-pin is one line inside a commit `003` is making anyway.

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
| **any packed word** (two `uint128`s, a `uint96` amount beside a `uint160` address, a raw hash, an address read via `COINBASE` or `ORIGIN`) | — | Broken by construction: the high limbs carry meaning. AC-2 V-11 and AC-3 E-05/E-06/E-11 exercise exactly this. |

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
| database on an un-witnessed read | `InMemoryDB` → silently **zero** | `Err(OperationalError::MissingAccountWitness / MissingStorageWitness)` | `main.rs:102`; `reexec-evm/src/lib.rs:410-437` |

Two of these bite `002` on the first real transaction, not on an exotic one. **The second
was stated wrongly in round 1 (finding 10) and is corrected here:**

- a real caller has `nonce > 0`, so the guest's nonce check rejects the tx (`Err(_)` at
  `main.rs:146` → `Failed`) while off-chain reproduces it. This one is a **rejection**;
- a real anchor has `base_fee > 0`. The guest **does not reject**: it never sets
  `block.basefee`, so it runs at `BlockEnv::default().basefee = 0`
  (`revm-context-16.0.1/src/block.rs:120`), the EIP-1559 comparison is `0 < 0` = false, and
  the tx executes **under a different base fee than the off-chain engine**. That is a silent
  divergence for any plan that reads `BASEFEE`, not a refusal. E-09 tests the divergence and
  requires both the block field and `disable_base_fee`.

And the un-witnessed-read divergence is a **third false-release vector of the same family**:
a seller who omits a slot the contract reads (an allowance, a pause flag, a fee parameter)
gets `0` in-guest and a proof, where the off-chain engine refuses to produce a verdict at
all. 008 closes it, because INV-1 cannot be stated without it.

**And a fourth, found in r1 review (finding 4): the empty MPT proof.**
`alloy-trie-0.9.5/src/proof/verify.rs:29-43` returns **`Ok(())`** when the proof iterator is
empty, `root == EMPTY_ROOT_HASH` and `expected_value` is `None`. The guest passes
`expected = None` exactly when the witnessed value is zero (`main.rs:67-72`). So an account
whose storage trie is empty, carrying a witnessed slot with value `0` and `proof: vec![]`,
**verifies in-guest**. Off-chain, `reexec-evm/src/lib.rs:352-357` returns
`WitnessVerificationError::EmptyStorageProof` before any trie work, wrapped into
`OperationalError::InvalidWitness`, so `replay` returns `Err`. Guest proves, backend refuses.

### 2.4 Axis 3 — `dealBinding` does not cover the whole input

`main.rs:176-190` binds `state_root ‖ check.address ‖ check.slot ‖ min ‖ max ‖
keccak(caller ‖ target ‖ calldata ‖ value)`. It does **not** bind `chain_id`, and it does not
bind `plan.gas_limit`. Once §3 puts the block environment into `GuestInput`, the environment
becomes seller-supplied too. An unbound input is an input the seller chooses: a `CHAINID`- or
`TIMESTAMP`-gated contract can be made to behave favourably, and the resulting proof would
still settle the buyer's deal. This is the same defect as the other two — *the verdict is not
a function of the committed bytes* — so it is closed here, not deferred.

### 2.5 What is **not** wrong (checked, recorded so round 3 does not re-litigate)

- **`ecrecover` is not disabled in-guest.** `revm-precompile-34.0.0/src/secp256k1.rs:4-8`:
  *"Order of preference is `secp256k1` → `k256`. Where if no features are enabled, it will use
  `k256`."* Likewise `kzg_point_evaluation.rs:87-101` falls back to `arkworks` and
  `bls12_381.rs:8-14` falls back to `arkworks`. `revm = { default-features = false }`
  therefore swaps the *backend*, it does not remove the precompile. The `zk-verdict/README.md`
  honest-scope bullet (a) and the `AGENTS.md` §5 bullet that repeats it are **wrong as
  written**, and §9 rewrites them. The root `README.md` bullet was already corrected on
  2026-09-04 in `9ac4545` (`README.md:572-579`). The real residual is R-3.
- **A precompile address is *not* dispatched without a database read.** Codex's r1 BLOCKER
  claimed otherwise; the review rejected it with `revm-context-16.0.1/src/journal/inner.rs:920-927`
  (`db.basic(address)?` runs unconditionally; `warm_addresses` only supplies EIP-2929 `is_cold`).
  **That rejection stands and is not re-opened.** It is load-bearing here: it is *why* the
  unwitnessed half of G-2 closes (§3.6).
- **The ABI-encoded length of `VerdictPublicValues` does not change** when the four numeric
  fields widen: `uint64` already occupies a full 32-byte head slot. 224 bytes before, 224
  bytes after (INV-8).
- **`RecknZkEscrow` never reads `pre` / `post` / `minDelta` / `maxDelta`** — only
  `dealBinding`, `outcome`, `traceHash` (`RecknZkEscrow.sol:99-117`). Hence N-1 is achievable.
- **`MissingCodeWitness` has no in-guest analogue and needs none** (r1 finding 4 asked for
  this to be said rather than left silent). `verify_witness_against_root` sets
  `info.code = Some(code)` and populates `codes` for every witnessed account
  (`reexec-evm/src/lib.rs:380-388`), so `code_by_hash` is only reached for an address that
  `basic` has already rejected with `MissingAccountWitness`. The guest's equivalent is P-5.

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

**Plus a domain gate at the single conversion point** (§3.6), which is new in round 2 and is
how D stops being a description (r1 findings 5 and 9).

Adopted, unchanged, from the founder ruling: **(a) is kept; (b) is not a completion state.**

### 3.2 Options considered and rejected

**(b) Reject out-of-domain inputs in the guest (panic when any of `pre`/`post`/`min`/`max`
≥ 2^64).** Sound — no false release — but it converts the theft into a **permanent denial of
settlement** over the entire realistic 18-decimal range, and `RecknZkEscrow` has no timeout
until `003` lands (verified: the contract declares `fund` at `:71` and `settleWithProof` at
`:92` and nothing else), so the funds simply lock. It also makes `002` impossible: a real
ERC-20 balance slot above ≈18.4467 tokens is unprovable, and a RAY-scaled slot is *always*
unprovable — which `AGENTS.md` §3 already rules out.

*Its cost advantage, enumerated completely* (r1 finding 12 — round 1 stopped this list early,
in the direction that flattered the chosen option). **Any** change to the guest ELF changes its
vkey and invalidates the committed fixtures, so (b) does **not** save the fixture regeneration.
What (b) genuinely saves is: (1) the Solidity `VerdictPublicValues` struct edit and its `sol!`
twin; (2) the predicate-guest and SVM-guest fixtures; (3) the `reexec-io` `DeltaCheck` /
`GuestInput` widening; (4) the v2 preimage migration across **all three** guests — §3.5 changes
`verdict_trace_hash`, which `program-svm/src/main.rs:24,127` also uses; (5) the fixture JSON
hex-encoding change (AC-9(3)); and (6) the fixture readers in the five `.t.sol` files.
That is a real saving, and it is still the wrong trade, for the two reasons above.
**Rejected on completion state and on `002`, not on cost.**

**(c) Make the domain unreachable from the input side (the route `004` takes).** Not
available here, for three independent reasons. (1) **The prover is the adversary** — `GuestInput`
is supplied by whoever generates the proof, normally the seller, and there is no sanitiser between
them and the guest. (2) **The escrow cannot check what it never sees** — `fund` commits only
`dealBinding`; `pre` is read at *proving* time and reaches the chain already truncated, and adding
a party who could detect the crossing would be a key (`AGENTS.md` §0). (3) **The domain is not
exotic; it is the workload** — `pre` is MPT-bound to a real state root, and a real 18-decimal
balance above ≈18.4467 tokens is inside the broken region by construction. `004` may restrict its
own demo fixtures because `004` authors them; 008's subject is the general guest, which has no
author.

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
(`revm-context-16.0.1/src/cfg.rs:120-121`).

*(r1 finding 11: the round-1 "stop and report if that feature does not build for
`riscv64im-succinct-zkvm-elf`" is **struck**. `revm-38.0.0/Cargo.toml:88` is
`optional_no_base_fee = ["context/optional_no_base_fee"]` and
`revm-context-16.0.1/Cargo.toml:67` is `optional_no_base_fee = []` — a pure `cfg` flag with
zero dependencies adding one `bool` at `cfg.rs:120-121`. It cannot fail to build for a target
the crate already builds for. A pre-registered stop that cannot fire trains everyone to ignore
the ones that can.)*

`spec_id` is validated with `SpecId::try_from_u8` (`hardfork.rs:83-88`) and the guest panics
on `None`. Because the enum is positional, AC-3 pins five `u8` ↔ name round-trips so a revm
renumbering is caught rather than silently remapping a fork.

**The `TxEnv` residual (r1 finding 13).** Both sides construct
`TxEnv { caller, kind, value, data, gas_limit, gas_price: 0, chain_id: Some(chain_id),
..Default::default() }` — `reexec-evm/src/lib.rs:516-524` and
`program-revm/src/main.rs:129-138`, read today, textually identical modulo the field
expressions. Round 1 covered this with nothing. Round 2 covers it two ways: AC-6 compares the
**field-name sets of the two literals** (they must be exactly those seven plus a rest pattern),
and AC-3 gains **E-11 (`ORIGIN`)** and **E-12 (`GASPRICE`)** so two `TxEnv`-derived values are
probed by execution. What remains uncovered is stated in INV-6 rather than implied.

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

// re-execution guest (program-revm) only
traceHash   = SHA256( "reckn/zk/reexec/v2" ‖ prestate_root:32
                    ‖ pre:U256BE ‖ post:U256BE ‖ min:U256BE ‖ max:U256BE ‖ outcome:u8 )

// SHARED by the predicate guest (program) AND the SVM guest (program-svm):
// `verdict_trace_hash` is imported at program-svm/src/main.rs:24 and called at :127.
// Editing it edits both. (r1 finding 15 — round 1 labelled this "predicate guest".)
traceHash   = SHA256( "reckn/zk/verdict/v2"
                    ‖ pre:U256BE ‖ post:U256BE ‖ min:U256BE ‖ max:U256BE ‖ outcome:u8 )

// SVM guest deal binding (lamports zero-extended to U256 so the shared ABI stays one record)
dealBinding = SHA256( "reckn/zk/bind/svm/v2"
                    ‖ bank_hash:32 ‖ account:32 ‖ min:U256BE ‖ max:U256BE ‖ signature:64 )
```

Every preimage is unambiguous: fixed-width fields throughout, with the one variable-length
field (`calldata`) length-prefixed.

**Why the tags move to v2 and not stay at v1.** Two different functions must never share a
domain tag; that is the only thing a tag is for. The preimages change regardless of the tag
string (widths, byte order, new `env_hash`, new `gas_limit`), so keeping `v1` would leave two
distinct functions under one name. Nothing coexists: no v1 artefact survives 008 (all
fixtures are regenerated) and nothing is deployed on any chain. The cost is documentation
drift, handled in §9 and OQ-1 / OQ-2.

### 3.6 Engine identity and the domain gate, made mechanical

"Both sides run the same engine" is a claim about two files. 008 turns it into four
checkable things.

**1. One conversion, one place, and it is a gate.**
`zk-verdict/script/src/lib.rs` gains

```rust
pub enum OutOfDomain {                       // one variant per §5.1 clause it can see
    AnchorCarriesBlockHeader,                // G-1
    DivergentPrecompileAddress([u8; 20]),    // G-2
    PredicateIsNotSingleDeltaCheck,          // G-3
}

pub fn to_guest_input(
    anchor: &EvmAnchorV1, witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1, check: (Address, U256, U256, U256),
) -> Result<GuestInput, OutOfDomain>;
```

and it is **the only function in the repository that constructs a `GuestInput`**. It
destructures `EvmAnchorV1`, `AccountWitness`, `StorageWitnessV1` and `EvmCallPlanV1`
**exhaustively, with no `..` rest pattern**, so a new field on any of them is a compile error
rather than a silent omission. One anchor field is carried into an explicit exclusion set with
a reason — `block_hash` (`BLOCKHASH` is unavailable to both engines, R-2). `block_header` is
**not** excluded any more; it is refused (G-1).

The three refusals:

| gate | condition | why | mirrors |
|---|---|---|---|
| **G-1** | `anchor.block_header.is_some()` | Off-chain, a header runs `header::verify_header_against_anchor` (`reexec-evm/src/lib.rs:460-463`) and can return `Err(HeaderMismatch)`; the guest has no header layer (N-5), so it could neither reject a bad header nor honour a good one. Round 1 put the field in an *exclusion set*, which silently dropped it. | nothing — the input never becomes a `GuestInput`, so no proof exists and INV-2 has no obligation (§5). |
| **G-2** | `plan.target`, or any address in `witness.accounts`, is in **Δ** = `{0x01, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11}` | These are exactly the precompiles whose *backend* differs between the two builds (R-3). Δ is the backend-delta set and nothing wider: `0x02`–`0x09` and `0x100` run byte-identical code on both sides, so refusing them would refuse an in-domain input and *create* an INV-2 violation. | nothing — same as G-1. |
| **G-3** | the predicate is not a `PostStateDelta` with exactly one check | N-4. | nothing. |

**Why G-2 plus the witness-closed database makes Δ unreachable, not merely discouraged**
(r1 finding 9). Two cases, exhaustive. *Δ address present in the witness* → G-2 refuses; no
`GuestInput` is built. *Δ address absent* → the first entry calls `db.basic(address)`
(`revm-context-16.0.1/src/journal/inner.rs:920-927`; top-level via
`revm-handler-18.1.0/src/execution.rs:20-22`, nested via
`revm-interpreter-35.0.1/src/instructions/contract.rs:157-158` → `call_helpers.rs:73`;
`precompiles.run` at `revm-handler-18.1.0/src/frame.rs:203` is reached only *after*), and the
closed database errors on **both** sides — in-guest a panic (P-5), off-chain
`MissingAccountWitness`. Agreement holds, no proof exists. This case depends on r1's rejected
finding R-1 being right; it is, and the citation is reproduced so round 3 does not re-open it.

**2. `GuestEnv` is applied field by field.** Every one of its 8 fields appears on the
right-hand side of an assignment in `program-revm/src/main.rs`'s `modify_cfg_chained` /
`modify_block_chained`. *This is not separately grepped* — AC-3's E-01…E-09 probe all eight by
execution, which is strictly stronger than a name grep, and a name grep is exactly the
"名前でなく本体" failure `AGENTS.md` §5 names. Round 1 had both; round 2 keeps only the
execution.

**3. A database error is not a `Failed` verdict.** `main.rs:145` today reads
`Err(_) => (false, None)`, which folds *every* `EVMError` into `Failed`. With a
witness-closed database that would turn `MissingAccountWitness` into a **proof of `Failed`**
where the backend produces no verdict at all — the same INV-2 break in a new place. The guest
must distinguish: a `Database` error **panics**; an execution `Revert` / `Halt` is `Failed`.
AC-4's W-01 / W-02 are the tests that catch a regression here (they require `execute()` to
return `Err`, not a `Failed` verdict).

**4. A differential test proves it by execution.** `zk-verdict/script/tests/` runs, per vector,
(i) `reckn_reexec_evm::replay(...)` and (ii) the **real guest ELF** through SP1 `execute()`, and
asserts they agree. Comparing the real artefact rather than an extracted library is deliberate:
`program-revm` is its own cargo workspace (its `Cargo.toml` ends with a bare `[workspace]`), so a
library shared with `script` would feature-unify differently and prove the wrong thing.
`zk-verdict/script/build.rs:4-8` rebuilds all three guests on **every** cargo build of `script`,
so a guest edit is picked up by `cargo test` automatically — which is also what makes AC-13 cheap.
`ac008.sh` must `unset` any `SP1_SKIP_PROGRAM_BUILD`-style variable before a `script` row, and
`cycles.json` records the ELF `sha256` (AC-14) so a stale build is visible rather than assumed
absent.

**Two structural facts the implementer must not discover the hard way:**

- `zk-verdict/script` **has no `src/lib.rs` today** — only `src/bin/{main,evm,reexec,svm}.rs`
  (verified). 008 creates `src/lib.rs` and adds a `[lib]` target to `zk-verdict/script/Cargo.toml`.
  `script` is already a member of the `zk-verdict` workspace (`zk-verdict/Cargo.toml:2`).
- **revm credits the block beneficiary even at `gas_price = 0`**, so a closed witness must
  contain the committed coinbase account. `reexec-evm/src/lib.rs:854-856` says so in a comment
  and `anchored_witness_with_code` witnesses `addr(0xc0)` accordingly. AC-3's **E-05** changes
  the coinbase to `addr(0xc1)`, so **E-05's witness must contain `addr(0xc1)`**, not
  `addr(0xc0)`. Round 1 did not say this and the vector would have failed for the wrong reason.

**The testkit builders 008 adds** (all inside the `#[cfg(any(test, feature = "testkit"))]`
block, existing signatures kept as wrappers — N-3):

```rust
pub struct PrestateSpec {          // every field the AC-2/3/4 vectors need to vary
    pub caller: Address, pub target: Address, pub caller_nonce: u64,
    pub target_code: Bytes,
    pub coinbase: Address,         // E-05 needs this witnessed
    pub slot7: SlotSpec,           // Value(U256) | AbsentWithExclusionProof | EmptyProofZero
    pub extra_accounts: Vec<(Address, U256 /*balance*/, Bytes /*code*/)>,  // W-06, W-07
    pub empty_account_proof_for: Option<Address>,                          // W-05
}
pub fn anchored_witness(spec: PrestateSpec) -> (EvmAnchorV1, PrestateWitnessV1);
```

`SlotSpec::AbsentWithExclusionProof` is V-14's requirement: build the storage trie with a
different leaf present (e.g. slot 9 = 1) and retain the proof for the absent target.
`reexec-evm`'s verifier already handles it (`reexec-evm/src/lib.rs:81-82`, `:360`); only the
builder is missing. `alloy-trie-0.9.5`'s `ProofRetainer` retains nodes on the *prefix path* of a
target, so `ProofRetainer::from_iter([absent_target])` over a two-leaf trie is the expected route.
If it does not produce a verifying exclusion proof, **stop and report** (`AGENTS.md` §7) — do not
drop the vector, do not synthesise a fake proof. *(This stop is kept; it is the one that can fire.)*

**Outcome codes have two encodings and one mapping.** `verdict_lib` and
`RecknVerdictVerifier` use `REPRODUCED = 0`, `FAILED = 1` (`lib/src/lib.rs:35-36`,
`RecknVerdictVerifier.sol:34-35`); `ReplayRecordV1` uses `Reproduced = 1`, `Failed = 2`
(`reexec-evm/src/lib.rs:567-570`). They must never be compared without conversion.
`zk_outcome(&Verdict) -> u8` in `zk-verdict/script/src/lib.rs` is the single home of that
mapping (INV-10, AC-8).

---

## 4. State machine

### 4.1 The outcomes of a proof attempt, of a replay, and of the domain gate

```
domain gate (to_guest_input):   Ok(GuestInput)          Err(OutOfDomain)
                                        |                       |
                                        v                       v
guest:      NoProof            Verdict(REPRODUCED=0)   Verdict(FAILED=1)      (never invoked)
            (panic → SP1 execute/prove returns Err; no proof can exist)

off-chain:  Err(OperationalError)   Reproduced             Failed(reason)
```

The gate is new in round 2. It runs **before** the guest, so an `Err(OutOfDomain)` produces
neither a panic nor a verdict — the guest is never invoked at all. That is what lets INV-2 be
an honest biconditional over **D** instead of a false one over everything (r1 findings 4, 5, 9).

Guest transitions into `NoProof`, exhaustively — these are the only panics permitted:

| # | cause | mirrors off-chain |
|---|---|---|
| P-1 | account MPT proof invalid | `WitnessVerificationError::AccountProofMismatch` |
| P-2 | storage MPT proof invalid | `WitnessVerificationError::StorageProofMismatch` |
| P-3 | `keccak(code) != code_hash` | `WitnessVerificationError::CodeHashMismatch` |
| P-4 | duplicate account or duplicate slot in the witness | `Duplicate{Account,StorageSlot}` |
| P-5 | **read of an account not in the witness** (new) | `OperationalError::MissingAccountWitness` |
| P-6 | **read of a slot not in the witness for a witnessed account** (new) | `OperationalError::MissingStorageWitness` |
| P-7 | **`BLOCKHASH` (0x40)** (new — no block-hash witness exists) | `OperationalError::MissingBlockHashWitness` |
| P-8 | **the checked `(address, slot)` is absent from the witness** (new) | `OperationalError::MissingPredicateWitness` (`reexec-evm/src/lib.rs:482-486`) |
| P-9 | **`env.spec_id` is not a known `SpecId`** (new) | no off-chain analogue — off-chain takes a typed `SpecId`, so a bad byte cannot arise there. This is the one place option (b) survives, and it is unreachable through `to_guest_input`, which builds the byte from a typed `SpecId`. Reachable only by a hand-built `GuestInput`, i.e. by a seller writing the ELF's stdin directly, which is exactly the adversary §3.2(c)(1) names. |
| **P-10** | **`account_proof.is_empty()`** (new — r1 finding 4) | `WitnessVerificationError::EmptyAccountProof` (`reexec-evm/src/lib.rs:310`) |
| **P-11** | **any `storage.proof.is_empty()`** (new — r1 finding 4) | `WitnessVerificationError::EmptyStorageProof` (`reexec-evm/src/lib.rs:352-357`) |

**P-10 and P-11 are not symmetric** (a correction to r1 finding 4, which asked for two
divergences; there is one). **P-11 closes a real divergence**:
`alloy-trie-0.9.5/src/proof/verify.rs:29-43` returns `Ok(())` for an empty proof when
`root == EMPTY_ROOT_HASH` and `expected_value` is `None`, and `main.rs:67-72` passes `None`
exactly when the witnessed value is zero — guest proves, backend refuses (**W-04**).
**P-10 closes no divergence; it makes the *reason* match**: the guest always passes
`Some(alloy_rlp::encode(trie_account))` (`main.rs:58-60`), so an empty account proof already
yields `Err` (`ValueMismatch` or `RootMismatch`) and both sides refuse. P-10 is one line;
**W-05** records the agreement and catches a future guest that stops passing `Some(...)`.

`MissingCodeWitness` (`reexec-evm/src/lib.rs:253`) has no P-transition and needs none — §2.5.

A CALL that reverts or halts is **not** a panic: it is `Failed`, on both sides
(`main.rs:140-147`, `reexec-evm/src/lib.rs:540-541`, `:555-557`). A *database* error is not
`Failed` either — it is a panic (§3.6.3).

### 4.2 The agreement table (all nine combinations), over D

| off-chain \ guest | `NoProof` | `REPRODUCED` | `FAILED` |
|---|---|---|---|
| `Err(OperationalError)` | **required** (INV-2) | forbidden — INV-2 | forbidden — INV-2 |
| `Reproduced` | forbidden — INV-2 | **required** (INV-1) | forbidden — INV-1 (false refund; §2.1 mirror case) |
| `Failed(_)` | forbidden — INV-2 | forbidden — INV-1. **This cell is the false release of §2.1.** | **required** (INV-1) |

Three cells are required; six are forbidden. AC-2 / AC-3 / AC-4 are exactly the tests that
the six are empty for the enumerated vector set.

**Outside D there is no table.** `to_guest_input` returns `Err(OutOfDomain)`, no guest column
exists, and `replay` may return anything. This is a real reduction in what 008 claims and it
is stated here rather than buried: see R-9.

### 4.3 States and transitions that do not exist

- **A fourth guest verdict.** `delta_outcome` is total into `{0, 1}`, so no `GuestInput`
  produces `outcome ∉ {0,1}`. `RecknZkEscrow.sol:113-114`'s `BadOutcome` branch is therefore
  unreachable from any guest in this repository. It stays (defence against a future guest,
  and N-1 forbids touching the file), but no test may claim to reach it through a proof.
- **A verdict about a prestate that is not `state_root`.** P-1…P-4 and P-10/P-11 make it
  unreachable, and `traceHash` binds `state_root` regardless.
- **A verdict about an environment other than the bound one.** After §3.5, `dealBinding`
  covers `env_hash`, so a proof under a different environment carries a different binding and
  `settleWithProof` reverts `BindingMismatch` (`RecknZkEscrow.sol:103`). AC-7b.
- **A proof of an execution that entered Δ.** G-2 plus the witness-closed database, §3.6.
  Both cases are closed, so this transition has no path.
- **A proof about an anchor that carries a block header.** G-1. Round 1 had this transition
  reachable and silent.
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
- **INV-2 — no verdict where the backend has none, and none where the backend has one.**
  **For every input in D**, `replay` returns `Err(OperationalError)` **if and only if** the
  guest produces no proof (SP1 `execute` returns `Err`). Neither direction may be one-sided: a
  guest that panics more than the backend refuses is a liveness bug; a guest that panics less
  is the §2.3 false release. *(Round 1 asserted this unconditionally and it was false in both
  directions — r1 findings 4 and 5. The domain is now written into the invariant, and D is
  enforced rather than described — §3.6.)*
- **INV-3 — no truncation.** For every vector, the committed `pre`, `post`, `minDelta`,
  `maxDelta` equal the exact 256-bit values. Operationally: the EVM guest path contains no
  narrowing conversion at all (AC-6).
- **INV-4 — causality survives magnitude.** `post ≤ pre ⟹ credited = 0`, for all `U256`.
  A seller who does nothing, or who *reduces* the checked slot, cannot satisfy `min ≥ 1` **at
  any magnitude**. This is the `--credit 42 → delta 0 → Failed` property of
  `zk-verdict/README.md:143`, restated over the whole domain — and it is precisely what
  `pre = 2^64, post = 2^64 − 1` breaks today.
- **INV-5 — the binding covers the whole verdict input.** Two `GuestInput`s that differ in
  any one of the 18 components of AC-7a produce different `dealBinding`; and `dealBinding`
  is a function of exactly those 18. Everything else in `GuestInput` (the accounts and their
  proofs) is bound transitively, because it is MPT-verified against `state_root`, which is
  bound. **Without this, two different executions settle the same deal** — a seller can omit
  an account, get `0` instead of a failure, and change the verdict without changing
  `dealBinding`, which is the property `RecknZkEscrow.sol:22-23` advertises.
- **INV-6 — engine identity is data, not convention — with one named residual.** Every field
  of `EvmAnchorV1` is either carried into `GuestInput`, refused by the domain gate, or a
  member of the explicit exclusion set `{block_hash}`; every field of `AccountWitness`,
  `StorageWitnessV1`, `EvmCallPlanV1` and `GuestEnv` is carried / applied. Enforced by
  exhaustive destructuring (a compile error) and, for the two cfg flags and the absence of a
  rest pattern, by AC-6.
  **Residual, stated rather than implied (r1 finding 13):** `TxEnv` is not carried through
  `GuestInput`. Its seven set fields plus `..Default::default()` are a *constant written twice*
  (`reexec-evm/src/lib.rs:516-524`, `program-revm/src/main.rs:129-138`). AC-6 compares the two
  literals' field-name sets and AC-3's E-11 / E-12 probe `ORIGIN` and `GASPRICE` by execution,
  but a field that both sides set to the *same wrong* value is agreement, not fidelity — which
  is R-6, not a new gap.
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
- **INV-12 — the gate detects a wrong implementation, not a renamed one.** For each of the
  four committed mutants (§7.3), applying it in place makes its named manifest row exit
  non-zero. A test body that asserts nothing passes the mutant, so it fails this invariant.
  (AC-13. This is the invariant round 1 was missing — `AGENTS.md` §5, added 2026-09-04.)

### 5.1 The domain D over which INV-1 and INV-2 are asserted

**D** = inputs where all of the following hold. The first three are **enforced** by the
domain gate (§3.6); the last is **not enforceable at the input layer** and is disclosed.

| clause | status |
|---|---|
| the predicate is a `PostStateDelta` with **exactly one** check (N-4) | **enforced**, G-3 |
| `anchor.block_header` is `None` (N-5) | **enforced**, G-1 |
| the execution does not enter Δ = `0x01`, `0x0a`, `0x0b`–`0x11` — the backend-delta precompiles (R-3) | **enforced**, G-2 for the witnessed case, the witness-closed DB for the unwitnessed case (§3.6). Both cases refuse; the set is unreachable. |
| the execution does not read `DIFFICULTY` (0x44 pre-Merge semantics) or `BLOBBASEFEE` (0x4a) | **not enforced — and it does not need to be for INV-1/INV-2.** Both engines return the same `BlockEnv::default()` constant (`revm-context-16.0.1/src/block.rs:121-126`), so they **agree** with each other. The clause exists only to stop anyone reading INV-1 as fidelity to a real block. It is R-1/R-6, not a hole. |

**INV-1 says the two engines agree. It does not say either matches mainnet.** The differential
is against `reexec-evm`, not against a node. Nothing in 008 may be written as if it were.

---

## 6. Acceptance criteria

**Tier: local.** `cargo` (crates.io cache warm), `forge 1.7.1`, and the SP1 toolchain
(`~/.sp1/bin/cargo-prove`) for the ELF builds and `execute`. Regenerating the four Groth16
fixtures additionally needs SP1's ~6.2 GB v6.1.0 circuit artifacts; AC-9 *verifies* the
committed ones without proving.

**What round 2 removed, so a reviewer can see the size change in one place:**

| removed | why | r1 finding |
|---|---|---|
| AC-13's ten sandbox copies of the repo | `du -sh zk-verdict/target` = **6.8G**, `du -sh .` = **21G**, and `zk-verdict/script` pulls `sp1-sdk` — ten copies is ~210 GB or ten cold builds, unpriced, on the head task of a 9/9 checkpoint | 3 |
| AC-14's "exact integer at all 12 enumerated sites" | the enumeration is line numbers, and r1 finding 8 is a demonstration that line numbers in this document go stale within a day. Replaced by two greps that need no line numbers. | 8 |
| AC-6's bash parser of `pub struct` declarations | the exhaustive destructure is already a **compile error**; a bash re-derivation of the same fact is the weaker half of a doubled check | — |
| AC-6's `GuestEnv` field-name grep | AC-3 probes all 8 fields by execution; a name grep adds nothing and is the "名前でなく本体" pattern `AGENTS.md` §5 names | — |
| **AC-5** as a separate criterion | folded into AC-6's script (same file set, same kind of check). **There is no AC-5 in round 2**; the number is not reused. | — |
| the two documentation digest pins | two of the three were already stale within a day (§0) | 8 |

**Added:** AC-16 (finding 6), W-04…W-08 (findings 4, 5, 9), E-11/E-12 (finding 13).

### 6.0 How an AC is decided — three gates, not one

Round 1 had two of these. The third is the point of round 2.

**Gate 1 — exit status is not enough.** Re-verified today, not quoted:

```sh
# forge 1.7.1 (Commit SHA 4072e48705af9d93e3c0f6e29e93b5e9a40caed8), zk-verdict/contracts
forge test --match-test "test_no_such_test_008"; echo "EXIT=$?"
# No tests found in project!    EXIT=0
# cargo, zk-verdict/lib
cargo test no_such_test_at_all; echo "EXIT=$?"
# test result: ok. 0 passed; 0 failed; 0 ignored; ...    EXIT=0
```

`forge test` has **no `--fail-on-no-tests` flag in 1.7.1**. So **every AC asserts a count
before it asserts success**, and `zk-verdict/scripts/ac008.sh` implements exactly this:

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

**Gate 2 — a count is not an assertion.** 14 tests named `test_AC02_V01_…` with bodies of
`assert!(true);` pass gate 1 completely: 14 listed, 14 passed, 0 failed. Round 1 answered this
with AC-13, which **renamed** tests — and a renamed tautology fails exactly as a renamed real test
does, so AC-13 passed too. Round 1 therefore permitted an implementation that prints
`ac008: 18/18 rows passed` while `u64_low` is still in `main.rs` and `pre = 2^64 / post = 2^64 − 1`
still releases to the seller: the claim demonstrated while false.

**Gate 3 — the gate must detect a *wrong* implementation.** AC-13 applies four committed mutation
patches **in place**, each to real source, and requires a named manifest row to exit non-zero. A
body that asserts nothing passes the mutant, so the row stays green, so AC-13 fails. **This is the
only check in the document that opens a test body — by breaking the code the body is supposed to be
about.** Nothing about it is self-reported; §7.3's round-1 sentence *"the rest are run once by hand
and their output pasted into the implementation report"* is **deleted**.

Two consequences that are part of the spec, not of the implementation:

- Rust test names must literally contain `_ACnn_`, so every test file under
  `zk-verdict/script/tests/` and the test module in `zk-verdict/lib/src/lib.rs` begins with
  `#![allow(non_snake_case)]` and names tests `test_AC02_V03_…`. Without this the implementer
  will lower-case them and every `cargo` selector silently matches zero.
- All 59 of `zk-verdict/script`'s tests live in `zk-verdict/script/tests/`;
  `zk-verdict/script/src/lib.rs` contains no `#[test]`.

**Every AC below carries a `Falsify:` line — a concrete degenerate implementation that makes
that AC exit non-zero.** An AC without one is not an acceptance criterion.

### 6.1 The manifest (parsed by `zk-verdict/scripts/ac008.sh` from this file)

Columns: `AC`, `kind` ∈ {`cargo`,`forge`,`script`}, `dir` (`cargo` only), `selector`,
`tests` (exact; `-` for `script`), `evidence` (verbatim stdout line for `script`; `-`
otherwise). Multi-space separated; `#` starts a comment.

```ac008-manifest
AC-00   script  -                   bash scripts/no-keys.sh                          -   the claim holds: no key can move a funded escrow.
AC-00b  script  -                   bash zk-verdict/scripts/surfaces.sh              -   surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged
AC-01   cargo   zk-verdict/lib      _AC01_                                           8   -
AC-02   cargo   zk-verdict/script   _AC02_                                          14   -
AC-03   cargo   zk-verdict/script   _AC03_                                          13   -
AC-04   cargo   zk-verdict/script   _AC04_                                           8   -
AC-06   script  -                   bash zk-verdict/scripts/env-parity.sh            -   env-parity: 5/5 truncation patterns absent; 4/4 cfg flags pinned on both sides; 0 rest patterns in to_guest_input; TxEnv fields identical (7)
AC-07a  cargo   zk-verdict/script   _AC07_                                          18   -
AC-07b  forge   -                   _AC07_                                           2   -
AC-08   cargo   zk-verdict/script   _AC08_                                           6   -
AC-09   script  -                   bash zk-verdict/scripts/fixtures-check.sh        -   fixtures: 4/4 current (vkey and public values byte-identical)
AC-10   forge   -                   _AC10_                                           4   -
AC-11   script  -                   bash zk-verdict/scripts/no-skip.sh               -   no-skip: 0 early-return fixture gates, 18/18 forge tests ran, 0 skipped
AC-12   cargo   zk-verdict/lib      _AC12_                                           3   -
AC-13   script  -                   bash zk-verdict/scripts/ac008-selftest.sh        -   ac008-selftest: 4/4 mutants detected
AC-14   script  -                   bash zk-verdict/scripts/docs-check.sh            -   docs: 7/7 stale claims absent, 6/6 replacements present, 0 tilde cycle literals, cycles.json matches 3/3 guests
AC-15   cargo   reexec-evm          -                                               16   -
AC-16   script  -                   bash zk-verdict/scripts/consumers-check.sh       -   consumers: binder, keeper, reckn-evm-content check --tests clean (3/3)
```

Arithmetic `ac008.sh --check` recomputes and a reviewer can recompute by hand:

- **18** manifest rows, **16** acceptance criteria (AC-0 … AC-16 with **no AC-5**;
  AC-00/AC-00b and AC-07a/AC-07b are two rows each of one criterion).
- **8** `cargo` rows; their `tests` column sums to **86**.
- **2** `forge` rows; their `tests` column sums to **6**.
- **8** `script` rows.
- Per package: `zk-verdict/lib` = **11** (8 + 3, the whole package),
  `zk-verdict/script` = **59** (14 + 13 + 8 + 18 + 6),
  `reexec-evm` = **16** (unchanged; 008 adds testkit builders and **zero** tests there —
  measured 2026-09-04: `grep -c '#\[test\]'` gives 10 in `src/lib.rs`, 6 in `src/header.rs`).
  11 + 59 + 16 = **86** ✓.
- `zk-verdict/contracts` = **18** forge tests = **12** pre-existing (measured 2026-09-04:
  `grep -n "function test" zk-verdict/contracts/test/*.t.sol | wc -l` → 12) + **6** new.
  AC-11 asserts 18.
- AC-13's mutants = **4**, over the rows AC-01, AC-02, AC-04, AC-07a.

`bash zk-verdict/scripts/ac008.sh --all` runs every row, asserts it ran **18**, and prints
`ac008: 18/18 rows passed`. `ac008.sh <AC>` runs one row. **AC-13 calls only the single-row
form**, so `--all` does not recurse and no `--sandbox` mode is needed or defined.

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

Run today, verbatim tail: `✓ the claim holds: no key can move a funded escrow.` `EXIT=0`.

**Falsify:** add `address public owner;` to `contract RecknZkEscrow` → the script fails.

### AC-0b — `RecknZkEscrow.sol` was not touched, and `reexec-evm`'s production surface was not touched

```sh
bash zk-verdict/scripts/surfaces.sh
# surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged
```

The script (a) compares `sha256(zk-verdict/contracts/src/RecknZkEscrow.sol)` against the
value recorded in `zk-verdict/scripts/surfaces.pinned` at the 008 base commit, and
(b) compares `sha256` of everything in `reexec-evm/src/lib.rs` **above** the line
`#[cfg(any(test, feature = "testkit"))]` that precedes `pub mod testkit` (the only occurrence
is `:711`) against its pinned value.

**On failure the script prints both digests**, labelled `pinned:` and `computed:`, so the
re-pin `003` must perform (§1.3) is a copy of a printed value and lands as a readable one-line
diff. `surfaces.pinned` is a two-line text file, not a generated blob.

(b) covers `replay` and the production API. It does **not** cover the testkit, `header.rs` or
`reexec-evm/Cargo.toml` — that is AC-16's job, and round 1 claimed (b) plus AC-15 "is the
whole of N-3" when it was not (r1 finding 6).

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
15 distinct magnitudes. **Mutant M-2** is the machine-run version of this line.

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
caller nonce 0) unless noted. `pre` is the committed prestate value of slot 7, supplied by
`PrestateSpec::slot7` (§3.6) — the existing builder hard-codes `42` and cannot express these
vectors.

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
| V-12 | `u64::MAX` | `u64::MAX + 10^18` | `10^18` | `U256::MAX` | `10^18` | **`Reproduced`** | `Failed` — **the `002` case** |
| V-13 | 1 | `20·10^18` | `20·10^18 − 1` | `U256::MAX` | `20·10^18 − 1` | **`Reproduced`** | impossible — `min` is not representable in `u64` today |
| V-14 | **0, via a storage exclusion proof** | `10^18` | `10^18` | `U256::MAX` | `10^18` | `Reproduced` | agrees (both below `2^64`) — the zero-balance recipient `002` needs |

Polarity is deliberately mixed — **9 `Reproduced`, 5 `Failed`** — so neither a
constant-`Failed` nor a constant-`Reproduced` guest passes.

**Falsify:** keep `let pre_u = u64_low(pre);` in the guest while making `delta_outcome`
`U256`-correct — AC-1 passes, AC-2 fails at V-03. Or return a constant outcome — at least 5
vectors fail either way. **Mutant M-1** is the machine-run version of the first sentence.

### AC-3 — the guest runs the same engine, pinned by data

```sh
bash zk-verdict/scripts/ac008.sh AC-03     # cargo, zk-verdict/script, _AC03_, 13 tests
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
| E-05 | `COINBASE` `41 60 07 55 00` | `coinbase = addr(0xc1)`, **and `addr(0xc1)` witnessed** (§3.6 — revm credits the beneficiary at `gas_price = 0`) | `uint160(0xc1c1…c1)` — a value **above `2^64`** | `Reproduced` | `Failed` (default `Address::ZERO`) |
| E-06 | `PREVRANDAO` `44 60 07 55 00` | `prevrandao = 0x3333…33` | `0x3333…33` — above `2^64` | `Reproduced` | `Failed` (default `B256::ZERO`) |
| E-07 | `GASLIMIT` `45 60 07 55 00` | `block_gas_limit = 36_000_000` | `36_000_000` | `Reproduced` | `Failed` (default `u64::MAX`) |
| E-08 | `CHAINID` `46 60 07 55 00` | `chain_id = 8453` | `8453` | `Reproduced` | **agrees today** — the positive control that the vector set is not rigged to only show failures |
| E-09 | `BASEFEE` `48 60 07 55 00` | `base_fee = 1_000_000_007` | `1_000_000_007` | `Reproduced` | `Failed`. **Not a rejection today** — the guest runs at `basefee = 0` and commits `post = 0`, a silent divergence (r1 finding 10). Needs both the block field **and** `disable_base_fee`. |
| E-10 | `SSTORE_SLOT7_RUNTIME`, credit 142, `min = 100` | caller nonce `5` | 142 | `Reproduced` | `Failed` — needs `disable_nonce_check`. **This is what `002` hits on its first real transaction.** |
| **E-11** | `ORIGIN` `32 60 07 55 00` | caller = `addr(0xca)` | `uint160(0xcaca…ca)` — above `2^64` | `Reproduced` | agrees — a `TxEnv`-derived value, probed by execution (r1 finding 13) |
| **E-12** | `GASPRICE` `3a 60 07 55 00` | default | `0`, with `min = max = 0` against `pre = 42` (a decrease saturates to 0) | `Reproduced` | agrees — the `TxEnv` constant. Both engines must commit the same `gas_price`; this catches one side changing it. |

Plus `test_AC03_specid_u8_names_are_pinned`: for each of `MERGE`, `SHANGHAI`, `CANCUN`,
`PRAGUE`, `OSAKA`, `SpecId::try_from_u8(<pinned u8>)` equals `SpecId::from_str("<pinned
name>")` (`revm-primitives-23.0.0/src/hardfork.rs:83-88`, `:149-177`, `:180-206`). A revm
version that renumbers the enum then fails loudly instead of silently remapping a fork.

12 vectors + 1 pinning test = **13**.

**E-11 and E-12 prove agreement, not fidelity.** If both sides set the same wrong `gas_price`,
both pass. That is INV-6's stated residual and R-6, not a hole this AC hides.

**Falsify:** apply the spec but not the block env (E-03…E-07, E-09 fail); or hard-code the
testkit defaults as constants (E-03…E-09 fail, because every one of them differs from the
default); or apply the env but omit `disable_nonce_check` (E-10 fails).

### AC-4 — the input domain is closed, and enforced at one place

```sh
bash zk-verdict/scripts/ac008.sh AC-04     # cargo, zk-verdict/script, _AC04_, 8 tests
```

Round 1 had three vectors and called this "the guest's database is closed over the witness".
It is that **and** the domain gate (§3.6); r1 findings 4, 5 and 9 are all here.

| id | input | off-chain | required |
|---|---|---|---|
| W-01 | `60 08 54 60 07 55 00` — `SLOAD(8)` then `SSTORE(7)`; slot 8 is **not** in the witness | `Err(MissingStorageWitness)` | SP1 `execute()` returns `Err` — **no verdict exists**. Not a `Failed` verdict (§3.6.3). |
| W-02 | `73 <20-byte un-witnessed addr> 31 60 07 55 00` — `BALANCE` of an un-witnessed account | `Err(MissingAccountWitness)` | `execute()` returns `Err` |
| W-03 | `60 07 54 60 07 55 00` — `SLOAD(7)` then `SSTORE(7)`; slot 7 **is** witnessed; `min = max = 0` | `Reproduced` (post = pre = 42, delta 0) | `Reproduced` — the positive control that W-01/W-02 fail for the missing-witness reason and not because any `SLOAD` panics |
| **W-04** | caller account with `storage_root = EMPTY_ROOT_HASH` carrying `StorageWitnessV1 { slot, value: 0, proof: vec![] }` | `Err(InvalidWitness(EmptyStorageProof{..}))` (`reexec-evm/src/lib.rs:352-357`) | `execute()` returns `Err` (**P-11**). **Today the guest returns `Ok` and proves a verdict** — `alloy-trie-0.9.5/src/proof/verify.rs:29-43` accepts an empty proof for `EMPTY_ROOT_HASH` with `expected_value = None`, which `main.rs:67-72` passes for a zero value. This is the live divergence of r1 finding 4. |
| **W-05** | any witnessed account with `account_proof: vec![]` | `Err(InvalidWitness(EmptyAccountProof{..}))` (`:310`) | `execute()` returns `Err` (**P-10**). **Both sides already refuse today**, because the guest passes `Some(rlp(account))` and `verify_proof` cannot return `Ok`. P-10 makes the reason match; this vector records the agreement and catches a future guest that stops passing `Some(...)`. |
| **W-06** | a witness containing an account at `0x00…01` (`ecrecover`) with a valid inclusion proof and non-zero balance; plan CALLs it | *(no `GuestInput` is built)* | `to_guest_input(...)` returns `Err(OutOfDomain::DivergentPrecompileAddress([0;19] ++ [1]))`. **G-2.** Today nothing rejects this and the plan enters a backend pair whose equivalence §8 R-3 declares untested (r1 finding 9). |
| **W-07** | `0x00…01` **not** in the witness; plan CALLs it | `Err(MissingAccountWitness{address: 0x…01})` | `execute()` returns `Err`. The complementary half of G-2: `db.basic` runs for a precompile address (`revm-context-16.0.1/src/journal/inner.rs:920-927`), so the closed DB refuses on both sides. **Together W-06 and W-07 make Δ unreachable.** |
| **W-08** | a valid witness under an anchor with `block_header = Some(header)` that correctly binds `state_root` | `Reproduced` (`replay` verifies the header and proceeds, `reexec-evm/src/lib.rs:460-463`) | `to_guest_input(...)` returns `Err(OutOfDomain::AnchorCarriesBlockHeader)`. **G-1.** Today the field is silently dropped, so the guest proves a verdict about an anchor whose header layer it never checked (r1 finding 5). The test must also assert the **negative** case: with `block_header = None` and everything else equal, `to_guest_input` returns `Ok` — otherwise a gate that always refuses passes. |

**Falsify:** keep `InMemoryDB::default()` (`main.rs:102`) — W-01, W-02 and W-07 produce a
verdict where none may exist. Or make `to_guest_input` infallible — W-06 and W-08 fail to
compile, then fail. **Mutant M-3** is the machine-run version of the first sentence.

### AC-6 — no truncation survives, and the two engines' constants are pinned by text

```sh
bash zk-verdict/scripts/env-parity.sh
# env-parity: 5/5 truncation patterns absent; 4/4 cfg flags pinned on both sides; 0 rest patterns in to_guest_input; TxEnv fields identical (7)
```

Four checks, all greps. AC-5 is folded in as the first.

1. **No narrowing conversion in the EVM guest path** (was AC-5). Files:
   `zk-verdict/program-revm/src/main.rs`, `zk-verdict/lib/src/lib.rs`,
   `zk-verdict/script/src/lib.rs`. Patterns, comment-stripped: `as_limbs`, `u64_low`,
   ` as u64`, `.to::<u64>()`, `try_into`. All five must be absent from all three files.
2. **The two cfg flags are set on both sides.** `disable_base_fee = true` and
   `disable_nonce_check = true` must each appear in **both**
   `program-revm/src/main.rs` and `reexec-evm/src/lib.rs`. Four greps.
3. **`to_guest_input` has no rest pattern.** Over the line range from `fn to_guest_input` to
   its closing `^}`, the token `..` must not appear. This is what keeps the exhaustive
   destructure exhaustive; adding a field to `EvmAnchorV1` is then a compile error.
4. **The two `TxEnv` literals set the same fields** (r1 finding 13). Extract the identifiers
   left of `:` in the `TxEnv { … }` literal in each of `reexec-evm/src/lib.rs` and
   `program-revm/src/main.rs`; both sets must be exactly
   `{caller, kind, value, data, gas_limit, gas_price, chain_id}` (7), and both literals must
   end with `..Default::default()`.

**Not checked here, deliberately:** the `GuestEnv` field-name list. AC-3 probes all 8 fields
by execution; a name grep beside it is the weaker duplicate `AGENTS.md` §5 warns about.

**Falsify:** reintroduce `fn u64_low` (check 1); drop `disable_nonce_check` from the guest
(check 2); write `let EvmAnchorV1 { chain_id, .. } = anchor;` (check 3); set `gas_price: 1`
in one of the two `TxEnv` literals — check 4 still passes (the field is present in both) but
**E-12 fails**, which is why check 4 is not the whole answer and INV-6 names the residual.

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
P-1…P-4 and P-10/P-11 make unforgeable.

**Falsify:** drop `timestamp` from `env_hash` — the `timestamp` test finds equal bindings.
Drop `gas_limit` from `plan_hash` — likewise. Revert to the v1 preimage entirely — **9 of 18**
fail (the 8 environment components plus `plan.gas_limit`). **Mutant M-4** is the machine-run
version of the first sentence.

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
   **`zk-verdict/contracts/src/fixtures/alt-binding.json`** and regenerated by
   `fixtures-check.sh`); submitting the real proof reverts `BindingMismatch`.

*(r1 finding 14: round 1 wrote `contracts/test/fixtures/`, which does not exist. Verified:
the committed fixtures live in `zk-verdict/contracts/src/fixtures/` and the five `.t.sol`
files read them as `"src/fixtures/…"`.)*

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
   `18446744073709551615` in all three committed fixtures, which any double-based reader
   (`jq` included) turns into `18446744073709552000`. A `U256` cannot survive a JSON number at
   all. Solidity reads them with `vm.parseJsonBytes32` and casts, exactly as `vkey` and
   `trace_hash` already are.

`alt-binding.json` (AC-7b) is regenerated by the same script but is not one of the four: it
carries a `dealBinding` only, no proof.

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
   seller now pays the buyer, on a real Groth16 proof. **This is simultaneously the soundness
   evidence and the demo money-shot.**
4. `test_AC10_tampered_public_values_are_rejected` — a forged `VerdictPublicValues` with the
   widened field types reverts.

Tier note: `forge test` against `SP1Verifier` with a committed Groth16 proof, on this machine.
Not a chain result; §7.4 forbids describing it as one.

**Falsify:** revert `RecknVerdictVerifier`'s struct to `uint64` — test 1's `abi.decode`
reverts on dirty high bits.

### AC-11 — no test in the contracts suite can pass by not running

```sh
bash zk-verdict/scripts/no-skip.sh
# no-skip: 0 early-return fixture gates, 18/18 forge tests ran, 0 skipped
```

*(r1 finding 2 — BLOCKER. Round 1 required `grep -c 'vm.exists'` to be **0** while
prescribing `require(vm.exists(FIXTURE), "…")` as the replacement, which contains that exact
string. The check is restated over the pattern that is actually the defect: the early return.)*

- ```sh
  grep -cE 'if[[:space:]]*\([[:space:]]*!vm\.exists\(' zk-verdict/contracts/test/*.t.sol
  ```
  summed over the directory must be **0**. Measured today it is **7**, in four files
  (`RecknReexecVerdict.t.sol` 2, `RecknSvmVerdict.t.sol` 2,
  `RecknVerdictVerifierFixture.t.sol` 2, `RecknZkEscrow.t.sol` 1) — and **all seven
  occurrences of `vm.exists` in the suite are that pattern**, so the two counts coincide today
  and the new grep loses nothing.
- The permitted replacement is **`require(vm.exists(FIXTURE), "missing fixture: …");`** — a
  hard failure, not an early return. It contains `vm.exists` and passes the check above.
  All four fixtures are committed and AC-9 keeps them current, so a missing fixture is a
  failure, not a reason to return early.
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

### AC-13 — the gate detects a wrong implementation (mutation, run by the gate)

```sh
bash zk-verdict/scripts/ac008-selftest.sh
# ac008-selftest: 4/4 mutants detected
# ac008-selftest: elapsed <N>s
```

**This is r1 BLOCKER 1's answer and it is the only check in the document that opens a test
body.** Round 1 renamed tests; a body of `assert!(true)` fails a rename exactly as a real test
does, so round 1's selftest could not see 14 tautologies. A tautology **passes the mutant**,
so the row stays green, so the selftest fails. Nothing here is self-reported.

**Mechanism — in place, no repo copy, guaranteed revert.**

```
for each mutant M in zk-verdict/scripts/mutants/*.patch (exactly 4, committed):
  1. save byte copies of the files M touches into a temp dir; install
     `trap restore EXIT INT TERM` FIRST, before touching anything
  2. patch -p1 --batch --forward < M          # must apply; a non-applying mutant FAILS AC-13
  3. assert the touched files' sha256 CHANGED (a no-op patch is a failed mutant)
  4. bash zk-verdict/scripts/ac008.sh <M's target row>     # must exit NON-ZERO
  5. restore from the byte copies; assert sha256 back to the original
```

`patch` / `patch -R` is used rather than `git apply` deliberately: this touches **no git
state** — no index, no commit, no stash — so it does not cross `AGENTS.md` §6's line that only
`reckn-codex-impl` owns git. The restore is from byte copies, not from `patch -R`, so a
half-applied hunk still restores.

The four mutants, each a single small hunk on real source:

| mutant | file | change | target row (must exit non-zero) |
|---|---|---|---|
| **M-1** | `zk-verdict/program-revm/src/main.rs` | re-truncate: take limb 0 of `pre`/`post` before the delta, i.e. restore the defect this task exists to close | **AC-02** (V-03 and V-11 must flip) |
| **M-2** | `zk-verdict/lib/src/lib.rs` | `delta_outcome` returns `REPRODUCED` unconditionally | **AC-01** |
| **M-3** | `zk-verdict/program-revm/src/main.rs` | restore `InMemoryDB::default()` — an unclosed database | **AC-04** (W-01, W-02, W-07) |
| **M-4** | `zk-verdict/program-revm/src/main.rs` | drop `env_hash` from the `dealBinding` preimage | **AC-07a** (the 8 environment components) |

These four were chosen to cover the four claims the product actually makes: the arithmetic
(M-2), the values through the real ELF (M-1), the closed input domain (M-3), and the binding
(M-4). Each targets a *different* row, so a single over-broad row cannot cover for the others.

**Cost model** (r1 finding 3 — round 1 priced nothing). Measured today:

- `du -sh zk-verdict/target` = **6.8G**; `du -sh .` = **21G**. A sandbox copy per row is
  ~210 GB or ten cold `sp1-sdk` builds. **That design is gone.**
- In place, the warm build trees are reused. `zk-verdict/program-revm/target/elf-compilation`
  exists and is **558M** with dependencies already compiled, so M-1 / M-3 / M-4 each rebuild
  **one crate** for `riscv64im-succinct-zkvm-elf`, not a dependency graph.
  `zk-verdict/script/build.rs:4-8` rebuilds the guests on every `cargo test` of `script`, so
  no extra build step is scripted.
- So the selftest is 3 single-crate guest rebuilds + 1 native rebuild, each followed by one
  manifest row.

**Budget and decision rule.** `ac008-selftest.sh` prints its own elapsed seconds. If it
exceeds **20 minutes**, **stop and report** (`AGENTS.md` §7) rather than trimming mutants
silently: 008 is the head of the execution order and gates the 9/9 checkpoint, so a selftest
that does not fit is a fact the founder needs, not a number to quietly relax.

**Falsify:** replace every `test_AC02_*` body with `assert!(true);` — M-1 no longer makes
AC-02 fail and the selftest reports `3/4`. Or make a mutant a no-op — step 3 fails.

### AC-14 — the documents moved in the same commit

```sh
bash zk-verdict/scripts/docs-check.sh
# docs: 7/7 stale claims absent, 6/6 replacements present, 0 tilde cycle literals, cycles.json matches 3/3 guests
```

**Digests are gone** (§0). Four checks, all over content.

**(i) Seven stale claims must be absent** — fixed-string `grep -F`, each in the named file:

| # | file | literal (must not match) |
|---|---|---|
| 1 | `README.md` | ``The `u64` verdict boundary is a soundness bug`` |
| 2 | `README.md` | `is UNVERIFIED` |
| 3 | `AGENTS.md` | ``（`u64_low` は limb 0 のみ`` → the substring ``` `u64_low` は limb 0 のみ ``` |
| 4 | `AGENTS.md` | ``` `c-kzg` / `ecrecover` precompile は in-guest で無効 ``` |
| 5 | `zk-verdict/README.md` | ``` the `c-kzg`/`ecrecover` precompiles are disabled ``` |
| 6 | `zk-verdict/README.md` | ``` to `u64` to reuse the on-chain ABI ``` |
| 7 | `zk-verdict/program-revm/src/main.rs` | ``` Values map to `u64` to reuse ``` (the module doc comment at `:14`, which states the defect as a design choice) |

All seven were confirmed present today by `grep -rn -F`, so all seven are real removals.

**(ii) Six replacement sentences must be present** — the marker substrings from §9:

| # | file | literal (must match) |
|---|---|---|
| 1 | `zk-verdict/README.md` | `at the committed hardfork and block environment` |
| 2 | `zk-verdict/README.md` | ``Verdict values are `uint256`.`` |
| 3 | `zk-verdict/README.md` | `Engine identity is checked, not assumed.` |
| 4 | `AGENTS.md` | ``旧 `u64` マップは制限ではなく健全性バグだった`` |
| 5 | `AGENTS.md` | `precompile は in-guest でも` |
| 6 | `README.md` | `In-guest precompiles run on different backends, and parity is unverified` |

Marker 6 is **already present** (`README.md:572`, landed in `9ac4545` on 2026-09-04, *after*
the 008 spec commit `d4f59ba`). Its obligation in §9(3) is therefore **"verify unchanged"**,
not "correct it" — r1 finding 8, which also caught that round 1's `AC-14(i)` would have passed
even if 008 changed nothing, because it only required the digest to *differ* and it already
did.

**(iii) No tilde cycle literal survives.** Over the fixed **doc set**

```
README.md   CLAUDE.md   SUBMISSION.md   zk-verdict/README.md   docs/cross-chain-settlement.md
```

```sh
grep -noE '~\*{0,2}[0-9]+(\.[0-9]+)?k' README.md CLAUDE.md SUBMISSION.md \
                                        zk-verdict/README.md docs/cross-chain-settlement.md
```
must return **0 matches**. Measured today it returns **14**: 6 reexec, 5 svm, 1 predicate
(`zk-verdict/README.md:56`, `~21.7k`), and **2** never-measured `~180k` sub-figures
(`CLAUDE.md:36`, `zk-verdict/README.md:143`; `CLAUDE.md:36` carries `~410k` and `~180k` on one
line).

**The `\*{0,2}` is load-bearing and was found by running the check while writing this spec.**
The obvious form `~[0-9]` returns only **12**, because `zk-verdict/README.md:142` and `:194`
are written `~**410k cycles**` and `~**980k cycles**` — markdown bold between the tilde and the
digit. A check that silently misses two of the fourteen sites is a check that lets two stale
figures survive, which is the whole failure this AC exists to stop.

**This grep replaces round 1's twelve enumerated line numbers** — no line number appears in it,
so it cannot go stale the way r1 finding 8 showed line numbers do. The tilde is what lets a stale
number look current.

**Excluded from the doc set, with reasons:** `docs/ethonline-2026/PLAN.md` (founder's document,
`AGENTS.md` §8 — OQ-1); `STATUS.md`, `docs/specs/**`, `docs/reviews/**` (records of what was
said, not claims being made; `STATUS.md:95` quotes `~180k` as a description of this spec).

**(iv) Cycle figures are measured, and every published figure is one of the measured ones.**
008 changes all three guests, so every published cycle count becomes an unmeasured claim
(`AGENTS.md` §5). The script:

- runs `--execute` for `verdict`, `reexec` and `svm` and compares against
  `zk-verdict/cycles.json`
  `{measured_at, commit, elf_sha256:{verdict,reexec,svm}, cycles:{verdict,reexec,svm}}`,
  requiring **exact** equality (SP1 execution is deterministic for a fixed ELF and input, so
  no tolerance is permitted), and requiring each recorded `elf_sha256` to equal the freshly
  built ELF's — the cheap insurance against a skipped build that the r1 review asked for
  (it could not rule out an `sp1-build` skip variable; `ac008.sh` also `unset`s any `SP1_*`
  skip variable, §3.6.4);
- then requires that **every** match of `grep -oE '[0-9][0-9,]{4,} cycles'` over the doc set
  is one of those three exact integers, written with `,` separators. This catches every site
  without naming one of them, and it catches a new site if someone adds one.
- The two never-instrumented `~180k` sub-figures (`CLAUDE.md:36`, `zk-verdict/README.md:143`)
  are **deleted**, not re-measured — 008 does not invent a measurement (N-8). Check (iii)
  enforces the deletion: they are 2 of its 14 matches.

**Falsify:** leave `~410k` anywhere in the doc set (check iii); leave `~**410k` in
`zk-verdict/README.md:142` and use the naive `~[0-9]` regex (check iii, by construction, misses
it — which is why the regex is written out above rather than described); leave the honest-scope
section unchanged (checks i and ii); publish a rounded cycle figure (check iv).

### AC-15 — `reexec-evm` still passes, with the same number of tests

```sh
bash zk-verdict/scripts/ac008.sh AC-15     # cargo, reexec-evm, no filter, 16 tests
```

**16** — 10 in `src/lib.rs`, 6 in `src/header.rs`, counted today. 008 adds testkit *builders*
and **zero** tests to this package; its tests belong in `zk-verdict/`.

**Falsify:** add a test here (17 ≠ 16), or break a testkit wrapper signature (a build error).

### AC-16 — the three other `reexec-evm` consumers still build, including their tests

```sh
bash zk-verdict/scripts/consumers-check.sh
# consumers: binder, keeper, reckn-evm-content check --tests clean (3/3)
```

*(r1 finding 6. N-3 promised this and nothing enforced it: AC-0b's prefix digest stops above the
testkit `cfg` line and AC-15 runs only `reexec-evm`'s own tests, so neither sees the testkit —
which is exactly the surface 008 changes, and it is **cross-crate**. `binder/Cargo.toml:26` takes
`features = ["testkit"]` and `binder/tests/router_two_vms.rs:13` does
`use reckn_reexec_evm::testkit::{addr, anchored_identity_witness};`, so a testkit signature change
breaks `binder`'s test build while all 18 manifest rows stay green.)*

The three are **standalone packages, not workspace members** (verified: no root `Cargo.toml`;
`binder/Cargo.toml:13`, `keeper/Cargo.toml:9`, `reckn-evm-content/Cargo.toml:7`). So three
per-directory invocations, not one `-p` list:

```sh
for d in binder keeper reckn-evm-content; do ( cd "$d" && cargo check --tests ); done
```

`--tests` is load-bearing: without it `binder/tests/router_two_vms.rs` is never compiled and
the check is vacuous. Their build trees are warm (measured today: `binder/target` 2.8G,
`keeper/target` 3.2G, `reckn-evm-content/target` 700M), so this is an incremental check.

**Falsify:** change `anchored_identity_witness`'s signature without keeping a wrapper —
`ac008.sh --all` reports `17/18`. (Round 1 would have reported `18/18`.)

---

## 7. Test plan

### 7.1 Files

| path | contents |
|---|---|
| `zk-verdict/lib/src/lib.rs` (test module) | AC-1 (8), AC-12 (3) |
| `zk-verdict/script/src/lib.rs` | **new file** (`script` has only `src/bin/*` today; a `[lib]` target is added to its `Cargo.toml`): `to_guest_input` + `OutOfDomain`, `to_predicate`, `zk_outcome`, the differential runner. **No `#[test]`.** |
| `zk-verdict/script/tests/value_domain.rs` | AC-2, V-01…V-14 |
| `zk-verdict/script/tests/engine_identity.rs` | AC-3, E-01…E-12 + the `SpecId` name pinning |
| `zk-verdict/script/tests/domain_closed.rs` | AC-4, W-01…W-08 |
| `zk-verdict/script/tests/binding.rs` | AC-7a, 18 components |
| `zk-verdict/script/tests/outcome_map.rs` | AC-8, 6 |
| `zk-verdict/contracts/test/RecknVerdictDomain.t.sol` | AC-7b (2), AC-10 (4) |
| `zk-verdict/scripts/{ac008,surfaces,env-parity,fixtures-check,no-skip,ac008-selftest,docs-check,consumers-check}.sh` | the harness (**8** scripts — `no-truncation.sh` is gone, folded into `env-parity.sh`; `consumers-check.sh` is new) |
| `zk-verdict/scripts/mutants/{01-truncate,02-const-reproduced,03-open-db,04-drop-envhash}.patch` | the four committed mutants (AC-13) |
| `zk-verdict/cycles.json`, `zk-verdict/scripts/surfaces.pinned` | committed measurements and the two code digests |

### 7.2 Positive path (must pass)

`bash zk-verdict/scripts/ac008.sh --all` → `ac008: 18/18 rows passed`, and
`bash zk-verdict/scripts/zk-e2e.sh` still runs end to end with the regenerated fixtures.

### 7.3 Negative controls

**Measured, by the gate, on every run** — these are AC-13 and nothing about them is
self-reported:

| mutant | break | row that must go non-zero |
|---|---|---|
| M-1 | re-truncate the verdict to limb 0 in `program-revm/src/main.rs` | AC-02 |
| M-2 | `delta_outcome` returns `REPRODUCED` unconditionally | AC-01 |
| M-3 | restore `InMemoryDB::default()` | AC-04 |
| M-4 | drop `env_hash` from the `dealBinding` preimage | AC-07a |

**Argued, not measured.** The list below is a *reading* of the acceptance criteria, not a
transcript. Round 1 said the remaining families would be "run once by hand and their output
pasted into the implementation report"; that sentence is deleted, and with it the claim.
Nothing here may be described as passing or failing until something runs it.

| degenerate implementation | the AC that should refuse it | why (from that AC's vectors) |
|---|---|---|
| judge in `U256` but keep the `uint64` Solidity struct | AC-9, AC-10 | public values differ from the fixture; `abi.decode` reverts on dirty high bits |
| special-case the fixture (`if pre == 42 { … }`) | AC-2 | 13 of 14 vectors use other magnitudes |
| return `FAILED` unconditionally | AC-2, AC-3, AC-4 | 9 / 9 / 1 vectors expect `Reproduced` |
| apply `spec_id` but leave the block env at defaults | AC-3 | E-03…E-07, E-09 each differ from the default |
| hard-code the testkit anchor's env values as constants | AC-3 | E-03…E-09 each differ from the testkit anchor too |
| omit `disable_nonce_check` | AC-3 | E-10 |
| drop `plan.gas_limit` from `plan_hash` | AC-7a | 1 of 18 |
| `fn zk_outcome(_) -> u8 { 0 }` | AC-8 | 5 of 6 |
| change a guest and do not regenerate the fixtures | AC-9 | vkey mismatch |
| restore one `if (!vm.exists(F)) return;` | AC-11 | gate count 1 ≠ 0 |
| leave a `~410k` literal in the doc set | AC-14 | check (iii) |
| edit one byte of `RecknZkEscrow.sol` | AC-0b | digest mismatch |
| add a field to `EvmAnchorV1` without carrying it | AC-6 check 3 + a compile error | the destructure is exhaustive |
| break a testkit signature without a wrapper | AC-16 | `binder`'s test build |

If the implementer wants any row of the lower table to be a *claim*, it must become a fifth
mutant, not a paragraph.

### 7.4 Tests that will not be written

- **A test that only re-asserts `delta_outcome`'s definition against itself.** AC-1's value
  is the *pool*, which a truncating implementation cannot survive; a mirror-implementation
  oracle would be the same code twice.
- **A test of the pre-008 behaviour "for comparison".** The old guest is deleted, not kept.
- **Anything that runs against a chain.** Tier is local (§6). No anvil is started, no RPC is
  called, and no result here may be described as a testnet or mainnet result.
- **A cycle-count *improvement* test.** N-8. 008 measures; it does not optimise.
- **A test that asserts a `GuestEnv` field name appears in the guest source.** AC-3 executes
  all eight; a name assertion beside it is the pattern `AGENTS.md` §5 forbids.

### 7.5 What the implementation report must state honestly

- The measured cycle counts for all three guests (they will be larger) and the ELF `sha256`s,
  copied from `cycles.json`.
- The wall time of the four Groth16 regenerations.
- **`ac008-selftest.sh`'s elapsed seconds, verbatim.** If it exceeded 20 minutes: a **stop**,
  not a trimmed mutant list.
- If the exclusion-proof builder (V-14, §3.6) does not work as assumed: a **stop**, not a
  workaround and not a dropped vector.
- Anything in §7.3's lower table that was actually run, with its output — and nothing from
  that table that was not.

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
- **R-3 — the precompile *backends* differ and their equivalence is untested; 008 closes the
  reachability, not the parity.** The guest is
  `revm { default-features = false, features = ["optional_no_base_fee"] }` and the off-chain
  engine is `revm { features = ["optional_no_base_fee"] }` (defaults on). The feature delta is
  `{std, secp256k1, portable, tracer, c-kzg, blst}`. **No precompile is missing** — `k256`
  and `arkworks` are the fallbacks (`revm-precompile-34.0.0/src/secp256k1.rs:4-8`,
  `kzg_point_evaluation.rs:87-101`, `bls12_381.rs:8-14`) — so the previous claim that they are
  "disabled" was wrong. What is true is that Δ = `0x01`, `0x0a`, `0x0b`–`0x11` run *different
  implementations* on the two sides. After 008, Δ is **unreachable**: witnessed → G-2 refuses,
  unwitnessed → both engines refuse (§3.6). **Unreachable is not equivalent.** If a future
  task needs Δ, the parity is still unmeasured — OQ-3.
- **R-4 — the `state_root` ↔ block-header binding stays off-chain**, in
  `reexec-evm::header`. The guest never sees a header (N-5), and after 008 an anchor that
  carries one is refused (G-1) rather than silently stripped.
- **R-5 — one CALL, one delta check.** A full block or an arbitrary contract set is more
  cycles on the same architecture. That is a claim about architecture, not a measurement.
- **R-6 — INV-1 is agreement with `reexec-evm`, not with mainnet.** The differential runs two
  local engines. No result here says the guest reproduces a real chain. This is also the
  ceiling on E-11 / E-12 and on AC-6's `TxEnv` check: two sides that are identically wrong
  pass.
- **R-7 — `min == 0` still admits a no-op.** `delta_outcome(x, x, 0, max) = REPRODUCED`, so a
  buyer who funds a zero floor pays for nothing. That is the buyer's predicate choice and 008
  does not override it, but it sits directly under the "a no-op cannot fake the credit"
  headline. See OQ-4.
- **R-8 — the escrow still has no timeout.** If P-1…P-11 make a proof impossible, a funded
  deal stays funded. That is `003`, not 008, and 008 *increases* the set of inputs for which
  no proof exists (P-5…P-11, plus the three gate refusals), which strengthens the case for
  `003` landing next.
- **R-9 — outside D, 008 claims nothing** (new in round 2). The domain gate refuses three
  input shapes outright (G-1 block header, G-2 Δ, G-3 multi-check predicate). For those,
  `reexec-evm` may still produce a verdict and the zk path produces nothing. That is a
  **liveness reduction, chosen deliberately over an unsound proof**, and it is the honest
  reading of what "the same engine" means today. Round 1 stated INV-2 as an unconditional
  biconditional and it was false in both directions.

---

## 9. Documentation obligations (same commit, no exceptions)

Six documents move with the code. AC-14 enforces (1), (2), (3) and (4) mechanically.

**(1) `zk-verdict/README.md`, "Honest scope of the re-execution guest"** — replaced. The
section today is 11 lines (`8f65b75f…9a6cac1`, unchanged since round 1). The new text must
contain the three marker substrings AC-14(ii) greps for, shown in **bold**:

> - **Is** the actual `revm` EVM executing a real CALL against an **MPT-authenticated
>   prestate**, under proof, **at the committed hardfork and block environment**, with a
>   database closed over the committed witness — a read outside the witness produces no proof,
>   exactly as the off-chain backend produces no verdict.
> - **Verdict values are `uint256`.** `pre`, `post`, `minDelta` and `maxDelta` are full
>   256-bit words; the guest applies no narrowing conversion. The earlier `u64` mapping was
>   not a limit but a soundness bug: with `pre = 2^64` and `post = 2^64 − 1` the checked slot
>   *decreased* and the guest proved the largest possible credit. Closed by task 008;
>   `reexec-falserelease-fixture.json` is that exact input, proven, refunding the buyer
>   (verified locally with `forge test` against `SP1Verifier` — no chain).
> - **Engine identity is checked, not assumed.** `zk-verdict/script/tests/` runs every vector
>   through both `reexec-evm` and the real guest ELF and requires the outcome and the exact
>   `U256` `pre`/`post` to agree.
> - **Not:** precompile *backends* differ between the two builds (`k256` / `arkworks`
>   in-guest, `secp256k1` / `c-kzg` / `blst` off-chain). No precompile is missing, and 008
>   makes `0x01`, `0x0a` and `0x0b`–`0x11` **unreachable** — a witnessed one is refused at the
>   input, an unwitnessed one fails on both sides — but unreachable is not equivalent, and
>   their equivalence is still untested. `BLOCKHASH` is unavailable to both. `DIFFICULTY` and
>   `BLOBBASEFEE` read a fixed default on both sides and are not anchored to a real block.
>   One CALL, one delta check. The `state_root`↔header binding stays in the off-chain
>   `reexec-evm::header` layer, and an anchor that carries a header is refused rather than
>   silently stripped. Agreement is with `reexec-evm`, not with mainnet.

**(2) `AGENTS.md` §5** — two bullets replaced. §5 gained a third bullet on 2026-09-04
("受入条件は「名前」でなく「本体」を検定する"); 008 does **not** touch it — it is the reason
AC-13 exists in its round-2 form.

> - verdict 値は `u64` にマップ（`u64_low` は limb 0 のみ。2^64 超の残高は切り捨て）

becomes

> - verdict 値は `uint256`（`pre`/`post`/`minDelta`/`maxDelta`）。切り捨ては無い。
>   **旧 `u64` マップは制限ではなく健全性バグだった**（`pre = 2^64` / `post = 2^64 − 1` =
>   残高**減少**が最大の入金として `Reproduced` になった）。task 008 で解消。
>   in-guest と off-chain のエンジン一致は `zk-verdict/script/tests/` の差分テストが
>   **実 ELF に対して**検定する。残る非対応面は `zk-verdict/README.md` の Honest scope に列挙。

and

> - `c-kzg` / `ecrecover` precompile は in-guest で無効。これを要する plan は非対応

becomes

> - precompile は in-guest でも**欠けていない**（`k256` / `arkworks` にフォールバックする）。
>   ただし off-chain とは**実装が違う**（`secp256k1` / `c-kzg` / `blst`）。task 008 は
>   `0x01` / `0x0a` / `0x0b`–`0x11` を**到達不能**にした（witness にあれば入力で拒否、
>   無ければ両側とも失敗）が、**到達不能は等価ではない**。等価性は未検証。

The other §5 bullets (one CALL + one delta check; the `state_root`↔header layer; the
"tier を超えない / 走らせていないものを passing と書かない" discipline; and the new
"名前でなく本体" discipline) are unchanged.

**(3) Root `README.md`, "Known gaps (not closed)"** — line ranges **re-measured today**
(round 1's three ranges were all wrong, r1 finding 8; the section is now 44 lines,
`222eeeb84230c54050e9db26c9c070e1425ac3c9d92e4193a98431dca05ef99f`):

| bullet | lines today | 008's obligation |
|---|---|---|
| "In-guest precompiles run on different backends, and parity is unverified." | **572-579** | **Already correct** — landed in `9ac4545` (2026-09-04 10:06:43), *after* the 008 spec commit `d4f59ba`. 008 **verifies it is unchanged** (AC-14(ii) marker 6) and appends one sentence recording that Δ is now unreachable. Round 1 instructed 008 to "correct" it, which was already done. |
| "⚠ The `u64` verdict boundary is a soundness bug, not just a limit" | **580-587** | **removed** (AC-14(i) #1) |
| "**\"The same engine runs in-guest\" is UNVERIFIED**" | **588-592** | **removed** (AC-14(i) #2) |

The `RecknZkEscrow` timeout bullet (566-571), the scale bullet (593-595), the header-binding
bullet (596-597), the SVM bullet (598-599) and the "not yet submitted" bullet (600-602) stay
untouched — they are `003`'s and `AGENTS.md` §4's business.

**(4) Cycle counts** — from `zk-verdict/cycles.json`, at every site in the AC-14 doc set, as
exact integers with `,` separators. No line list; AC-14(iii)/(iv) find the sites.

**(5) `zk-verdict/program-revm/src/main.rs`'s module doc comment** (`:14-15`) — the sentence
*"Values map to `u64` to reuse the existing verdict ABI."* is removed (AC-14(i) #7). It states
the defect as a design choice, in the file that contains it. `CLAUDE.md:41-43` records that
this repo has twice shipped a stale comment above correct code; this is the same class, with
the polarity reversed.

**(6) `STATUS.md`** — a row recording that 008 landed, that the fixtures were regenerated,
that the binding domain tag moved `v1 → v2`, that `surfaces.pinned` now exists and `003` must
re-pin it (§1.3), and the two documentation drifts 008 cannot fix itself (OQ-1, OQ-2).

**(7) Not edited by any agent:** `docs/ethonline-2026/PLAN.md` and `DISCLOSURE.md`
(`AGENTS.md` §8). `PLAN.md:20-21` becomes stale — OQ-1. And **not edited by 008 at all:**
`docs/specs/003-key-gauntlet.md`, `docs/specs/004-live-adversarial-input.md` (N-11).

---

## 10. OPEN QUESTION (founder)

- **OQ-1 — `docs/ethonline-2026/PLAN.md:20-21` goes stale and agents may not edit it.**
  It states `~410k cycles` and
  `dealBinding = keccak("reckn/zk/bind/evm/v1" ‖ state_root ‖ address ‖ slot ‖ min ‖ max ‖ plan_hash)`.
  After 008 both are false. Options: (a) founder edits PLAN.md in the same window;
  (b) founder accepts the drift and it is recorded in `STATUS.md` per `AGENTS.md` §4.
  **Recommendation: (a)** — PLAN.md is the document the Continuity narrative is built from,
  and a stale binding formula there is exactly the kind of thing a judge can check.

- **OQ-2 — 008 lands before `003` and `004` and touches three things they depend on.**
  Two are documentation, one is a **build condition 003 must break** (r1 finding 7, and §1.3):
  1. `003`'s AC-16 pins the honest-scope digest `8f65b75f…9a6cac1`, which 008 must change;
  2. `003:341` and `004:171` quote the v1 binding formula, which 008 replaces;
  3. **`zk-verdict/scripts/surfaces.pinned` pins `sha256(RecknZkEscrow.sol)`, and `003`
     necessarily changes that file** (`refundAfterDeadline`; plus the discarded `transferFrom`
     boolean `003` r1 ruled in scope). Round 1 enumerated (1) and (2) and was silent on (3).

  Options: (a) 008 lands and `003`/`004` re-pin in their next round, with **`003` re-pinning
  `surfaces.pinned` in the same commit that changes the contract, as a visible one-line diff**
  (`surfaces.sh` prints both digests on failure so the re-pin is a copy of a printed value);
  (b) 008 holds its documentation changes until `003` lands.
  **Recommendation: (a).** (b) would ship the code fix with the false honest-scope text still
  in the repository, which is the failure mode `AGENTS.md` §5 exists to prevent. Cost is one
  line in `STATUS.md` and one line in `003`'s commit.
  **This is the one open question that needs an answer before implementation starts**, because
  it changes what `003` must do, and `003` is being revised by another agent right now.

- **OQ-3 — precompile backend parity (R-3) is a production performance decision.** 008 makes Δ
  unreachable, which is enough for INV-1/INV-2 but is a *liveness* restriction: a future plan
  that legitimately needs `ecrecover` (a permit-style ERC-20, a signature-gated delivery) is
  refused rather than proven. The only way to close it is to build `reexec-evm` with
  `default-features = false` so both engines run byte-identical `k256` / `arkworks` code. That
  makes the production backend measurably slower on `ecrecover` and KZG, and it affects
  `binder`, `keeper` and `reckn-evm-content` (now covered by AC-16, so the breakage would at
  least be visible).
  **Recommendation: leave disclosed for ETHOnline.** `002`'s ERC-20 workload should not touch
  Δ — a plain `transfer` does not. Revisit if it does, or if `004`'s free-form input can reach
  a permit path.

- **OQ-4 — should the guest refuse `min == 0` (R-7)?** A zero floor makes the delta predicate
  vacuous: a seller who does nothing satisfies it, which is the exact attack the causal delta
  exists to stop and which `zk-verdict/README.md:143` advertises as impossible. Refusing it in
  the guest is three lines and one more `NoProof` transition; keeping it preserves a
  legitimate "delta must be **at most** `cap`" predicate (`min = 0`, `max = cap`). This is a
  product decision about what a funded predicate is allowed to say, not an agent's.
  **Recommendation: keep `min == 0` legal and disclose R-7**, because refusing it in the guest
  alone would remove a predicate shape the off-chain `PredicateV1::PostStateDelta` supports —
  creating a *new* INV-2 violation in the opposite direction. If the founder wants it refused,
  it must be refused at the **domain gate** (a fourth `OutOfDomain` variant), not in the guest,
  so both sides stay consistent. AC-1 tests 3 and 4 already pin the current behaviour either
  way.

**Not open, recorded so round 3 does not re-open it:** whether option (a) is right (founder
ruled: yes, keep (a), (b) is not a completion state); whether precompile addresses skip the
database read (rejected with source in r1 R-1, and reproduced in §2.5 and §3.6 because G-2's
second case depends on it).

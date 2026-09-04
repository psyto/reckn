# Review 008 spec round 1

Payload: `/tmp/reckn-payload-008-spec-r1.md`
Codex raw: `/tmp/reckn-codex-008-spec-r1.md`

Subject: `docs/specs/008-verdict-domain-soundness.md` (1239 lines), drafted by `reckn-spec`
(Claude Code). **Codex did not write it** — author independence holds, and the payload said so
explicitly. Codex was called **once**, `-s read-only`, prompt by argument with `< /dev/null`.

Codex returned 5 findings (2 BLOCKER / 3 MAJOR). After adjudicating each against the files on
disk: **1 rejected with evidence, 1 kept but rewritten (its premise is false, a narrower
version survives), 1 kept at a lower severity with a corrected reason, 2 kept.** I added
**10 findings of my own**. Remaining: **15 findings — BLOCKER 2 / MAJOR 8 / MINOR 5.**

Every empirical statement below was produced on **2026-09-04** by running the command shown,
or by reading the cited file. No number is carried over from another round.

---

## What is healthy — recorded so round 2 does not re-litigate it

Checked and correct; do not spend round-2 effort here.

- **The defect is real and the reproduction is exact.** `zk-verdict/program-revm/src/main.rs:31-33`
  (`u64_low` = `as_limbs()[0]`) feeding `:163-166`, against `reexec-evm/src/lib.rs:647`
  (`post.saturating_sub(pre)` on `U256`). `pre = 2^64` / `post = 2^64 − 1` is a decrease
  proven as the maximum credit, and `RecknZkEscrow.sol:109-110` pays the **seller** on
  `REPRODUCED`. Both polarities in §2.1 check out arithmetically.
- **Every revm citation in §2.3 is exact.** `SpecId` `#[default] OSAKA` at
  `revm-primitives-23.0.0/src/hardfork.rs:76-77`; `BlockEnv::default()` `number = U256::ZERO`
  / `timestamp = U256::ONE` / `gas_limit = u64::MAX` / `beneficiary = Address::ZERO` /
  `prevrandao = Some(B256::ZERO)` / `basefee = 0` at `revm-context-16.0.1/src/block.rs:116-122`;
  `disable_base_fee` behind `#[cfg(feature = "optional_no_base_fee")]` at
  `revm-context-16.0.1/src/cfg.rs:120-121`; `disable_nonce_check` unconditional at `cfg.rs:50`,
  default `false` at `:329`; `try_from_u8` at `hardfork.rs:83-88`.
- **Every testkit citation is exact.** `reexec-evm/src/lib.rs:737` `block_number: 21_000_000`,
  `:740` `timestamp: 1_800_000_000`, `:742` `block_gas_limit: 30_000_000`, `:743`
  `coinbase: addr(0xc0)`, `:744` `prevrandao: [0x22;32]`, `:745` `spec_id: SpecId::CANCUN`.
  `addr(b) = Address::from([b;20])` (`:730-732`), so E-05's "`uint160(0xc1c1…c1)` is above
  `2^64`" is right.
- **The precompile correction (§2.5, R-3) is accurate and not over-reached.**
  `revm-precompile-34.0.0/src/secp256k1.rs:8` ("Order of preference is `secp256k1` → `k256`");
  `kzg_point_evaluation.rs:87-101` (`c-kzg` → `blst` → `arkworks`); `bls12_381.rs:8-14`
  (`blst` → `arkworks`). I checked the whole feature graph: revm 38's `default` is
  `{std, secp256k1, portable, tracer, c-kzg, blst}` (`revm-38.0.0/Cargo.toml:52-59`) and
  `revm-precompile`'s `bn` / `p256-aws-lc-rs` / `gmp` are **not** default on either side, so
  `modexp`, `bn254`, `sha256`, `ripemd`, `blake2f` and `secp256r1` run byte-identical code on
  both builds. `0x01`, `0x0a`, `0x0b`–`0x11` really is the complete backend-delta set, and the
  new text correctly says "no precompile is missing … their equivalence is untested".
- **All arithmetic in §6.1 recomputes.** 18 rows; 8 cargo rows summing to 79 (8+14+11+3+18+6+3+16);
  2 forge rows summing to 6; 8 script rows; `lib` = 11, `script` = 52, `reexec-evm` = 16,
  11+52+16 = 79; contracts 12 + 6 = 18; AC-13's counted rows = 10.
- **The base counts are real.** `grep -c "#\[test\]" reexec-evm/src/lib.rs reexec-evm/src/header.rs`
  → 10 and 6 = **16**. `grep -n "function test" zk-verdict/contracts/test/*.t.sol | wc -l`
  → **12**. `grep -o 'vm.exists' zk-verdict/contracts/test/*.t.sol | wc -l` → **7**, in four files.
- **§6.0's premise re-verified by me today, not quoted.** `forge --version` → 1.7.1, commit
  `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` (matches the spec exactly); `forge test --help`
  has no `--fail-on-no-tests`; `forge test --match-test "test_no_such_test_008"` in
  `zk-verdict/contracts` → `No tests found in project!`, **EXIT=0**.
- **AC-14's 12 cycle sites are all real and the list is complete.** I read each
  `file:line` and each carries a cycle figure. A repo-wide grep for `410k|980k|21.7k|180k`
  returns exactly those 12 plus `zk-verdict/README.md:143` (the `~180k` sub-figure, which
  AC-14(iii) deletes) and `docs/ethonline-2026/PLAN.md:20` (correctly excluded, OQ-1).
  No site is missed.
- **Two of the three pinned digests match.** `zk-verdict/README.md` honest scope →
  `8f65b75f…9a6cac1` (11 lines) ✓; `AGENTS.md` §5 → `fd4521ed…3a5b014` (19 lines) ✓.
  The third does not — finding 8.
- **AC-9's JSON claim is real.** All three committed fixtures carry
  `"max_delta": 18446744073709551615` as a **JSON integer**
  (`zk-verdict/contracts/src/fixtures/*.json`). A `U256` cannot survive that encoding.
- **N-1 is achievable.** `RecknZkEscrow.sol:99-117` reads only `dealBinding`, `outcome` and
  `traceHash`. The contract needs no edit for the widening. `abi.encode`'s 224 bytes is right:
  `uint64` already occupies a full head slot.
- **The scope expansion is justified, and it is stronger than the spec's own argument.**
  The spec justifies absorbing the `InMemoryDB` hole with "INV-1 cannot be stated without it".
  The better reason is **INV-5**: without a witness-closed database a seller can *omit* an
  account, get `0` instead of a failure, and change the verdict **without changing
  `dealBinding`** — i.e. two different executions settle the same deal, which is the property
  `RecknZkEscrow.sol:22-23` advertises. Same for `plan.gas_limit`: it changes execution (OOG)
  and is unbound today. Both are inside 003's scope line ("only where the row cannot otherwise
  have a true expected value"). **This is not scope creep.**
- **`escrow-svm` / `reckn-svm-keeper` are not affected.** Their `verdict_trace_hash` is a
  struct field of their own (`escrow-svm/src/lib.rs:166`); neither depends on `verdict-lib`.
  The blast radius of the ABI widening really is confined to `zk-verdict/` plus the two
  `.sol` files — with one exception, finding 6.

---

## Findings

### 1. [BLOCKER] `docs/specs/008-verdict-domain-soundness.md:948-966`, `:505-530`, `:1051-1054` — the whole AC harness reads test *names*; 79 named tautologies pass every row, and AC-13 cannot see it

§6.0's count-before-success gate does close "green on **zero** tests" (verified: `forge test
--match-test` with no match exits 0, so the `--list`/`--json` count assertion is necessary and
sufficient for that). It does **not** close "green on zero *assertions*". Nothing in the
manifest opens a test body.

AC-13 is the spec's stated answer ("the acceptance criteria are not vacuous"), and it is not.
It **renames** tests (`:955` `sed 's/test_AC02_/xtest_AC02_/g'`) and requires a non-zero exit.
A file of 14 tests named `test_AC02_V01_…` … `test_AC02_V14_…` whose bodies are `assert!(true);`
passes AC-02 *and* passes AC-13 (renamed, they no longer match, the count assertion fails,
exit non-zero — exactly as required).

The mutation family that would catch it is §7.3's NC-1…NC-18, and `:1054` says: *"AC-13
automates the first family; **the rest are run once by hand** and their output pasted into the
implementation report."* A self-reported transcript is not a build condition, and `AGENTS.md`
§5 exists because self-reports in this repo have been wrong.

Consequence, stated plainly: an implementation can print `ac008: 18/18 rows passed` while
`u64_low` is still in `main.rs` and `pre = 2^64 / post = 2^64 − 1` still releases to the
seller. That is the product's defined failure mode — the claim demonstrated while false.

This is the **third consecutive round in this repo** where the harness counts names and never
reads a body (003 r1 finding 1; 003 r2's `assertTrue(true)` finding). Codex reached it
independently (its finding 3); so did I.

**Repro:** in a sandbox, replace every `test_AC02_*` body with `assert!(true);` keeping all 14
names. `ac008.sh AC-02` passes (14 listed, 14 passed, 0 failed, 0 ignored) and
`ac008-selftest.sh` reports `10 counted rows, 10 observed failing when their tests are renamed`.

**Fix for round 2:** AC-13 must apply **semantic mutations**, not renames. At minimum NC-1
(restore `u64_low`), NC-5 (constant `REPRODUCED`), NC-9 (`InMemoryDB::default()`), NC-10 (drop
`env_hash` from `dealBinding`), each in-place with a guaranteed revert, each required to fail a
named row. See finding 3 for why the sandbox-copy design cannot carry this.

### 2. [BLOCKER] `docs/specs/008-verdict-domain-soundness.md:921-924` — AC-11 is self-contradictory and cannot be implemented as written

`:921-922`: *"`grep -c 'vm.exists' zk-verdict/contracts/test/*.t.sol` summed over the directory
must be **0** (it is **7** today, in four files)."*
`:923-924`: *"The gates become `require(vm.exists(FIXTURE), "…")`."*

`require(vm.exists(FIXTURE), "…")` contains the literal string `vm.exists`. The prescribed
remedy makes the prescribed check impossible. The evidence line
(`no-skip: 0 fixture gates, 0 skipped, 18/18 forge tests ran`) says "fixture gates", which is a
third, different thing again.

This is `AGENTS.md` §7's stop condition ("仕様が本当に曖昧") sitting inside the head task of
the execution order, four days before the 9/9 checkpoint. Worse than the stop is the
alternative: the implementer resolves it in whichever direction is convenient and nobody
notices, which is the failure this harness exists to prevent.

**Repro:** `grep -c 'vm.exists' zk-verdict/contracts/test/*.t.sol` → today 2/2/2/0/1 across
five files, 7 total in four files (the spec's count is right). Then apply `:923-924` and re-run.

**Fix for round 2:** state the check as the *early-return* pattern, e.g.
`grep -cE 'if *\(!vm\.exists\([A-Z_]+\)\)' zk-verdict/contracts/test/*.t.sol` must be 0, and
say that `require(vm.exists(...), "…")` is the permitted replacement. Keep the
`forge test --json` = 18 / all `Success` / none `Skipped` half unchanged.

### 3. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:948-966` — AC-13 has no cost model; the sandbox-copy design is not affordable inside the freeze window

AC-13 makes **a sandbox copy of the repo per counted row — 10 copies** — and runs
`ac008.sh --sandbox <path> <AC>` in each.

Measured today:
```
du -sh zk-verdict/target   →  6.8G
du -sh .                   →   21G
```
Three of the counted rows live in `zk-verdict/script`, whose dependency graph includes
`sp1-sdk 6.0.1` (`zk-verdict/script/Cargo.toml`). Ten sandboxes therefore cost either ~210 GB
of copying (if `target/` comes along) or ten cold builds of `sp1-sdk` (if it does not). Cargo
fingerprints include the package path, so naively sharing one `CARGO_TARGET_DIR` across ten
copied trees does not avoid the rebuilds either.

The spec's §6.1 arithmetic block counts rows, tests and packages and never counts wall time.
This is the single largest schedule item in the document and it is unpriced. 008 is the head of
the order and gates the 9/9 withdrawal checkpoint.

**Fix for round 2:** replace the copy with an **in-place** mutation + guaranteed revert
(`trap`-based restore of the touched files), and cap the selftest at the rows that actually
carry semantic weight (AC-01, AC-02, AC-07a) rather than all 10. Combine with finding 1: what
AC-13 must prove is that a *wrong implementation* fails, not that a *renamed* one does.

### 4. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:425-428`, `:371-383` — INV-2 is asserted as an *iff* and it is false: the guest accepts an **empty MPT proof** that the backend refuses

Off-chain, an empty storage proof is an operational refusal:
`reexec-evm/src/lib.rs:352-357` returns `WitnessVerificationError::EmptyStorageProof` when
`entry.proof.is_empty()`; `:310` does the same for `EmptyAccountProof`; both are wrapped into
`OperationalError::InvalidWitness` at `:466-467`, so `replay` returns `Err`.

In-guest, `verify_prestate_authenticity` calls `alloy_trie::proof::verify_proof`, and
`alloy-trie-0.9.5/src/proof/verify.rs:29-43` returns **`Ok(())`** when the proof iterator is
empty, `root == EMPTY_ROOT_HASH` and `expected_value` is `None`. An account whose storage trie
is empty, carrying a witnessed slot with value `0` and `proof: vec![]`, therefore **produces a
proof in-guest and no verdict off-chain**.

§4.1 (`:371` *"these are the only panics permitted"*) lists P-1…P-9 and omits both
`EmptyAccountProof` and `EmptyStorageProof`. It also omits `MissingCodeWitness`
(`reexec-evm/src/lib.rs:253`) and `HeaderMismatch` (`:257`) — see finding 5 for the latter.
(`MissingCodeWitness` I checked and believe unreachable: `verify_witness_against_root`
always sets `info.code = Some(code)` and populates `codes` for every witnessed account
(`:380-388`), so `code_by_hash` is only reached for an address `basic` already rejected. The
spec should say that rather than being silent about it.)

**Repro:** build a witness with `storage_root = EMPTY_ROOT_HASH`, one `StorageWitnessV1 { slot,
value: U256::ZERO, proof: vec![] }`; assert `replay(...)` is
`Err(InvalidWitness(EmptyStorageProof{..}))` and that SP1 `execute()` on the same input via
`to_guest_input` returns a committed verdict.

**Fix for round 2:** add P-10 (`account_proof.is_empty()`) and P-11 (`storage proof
is_empty()`) to §4.1, add two vectors to AC-4 (`W-04`, `W-05`) and raise AC-4's count from 3
to 5 with the matching manifest edit.

### 5. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:425-428`, `:332-334`, `:467-472` — `anchor.block_header = Some(_)` is silently dropped, so INV-2's *iff* is false in the other direction too

Codex's finding 1, verified and kept at MAJOR rather than BLOCKER.

`reexec-evm/src/lib.rs:460-463`: when `anchor.block_header` is `Some`, `replay` runs
`header::verify_header_against_anchor` and returns `Err(OperationalError::HeaderMismatch)` on
failure. §3.6.1 (`:332-334`) puts `block_header` into `to_guest_input`'s **exclusion set**, so
the guest never sees it and cannot reject it. §5.1 (`:467-472`) scopes `anchor.block_header is
None` into domain **D** — but D is declared as the domain of **INV-1**, and INV-2 (`:425-428`)
carries no domain at all. Nothing in the AC set requires `to_guest_input` to reject
`Some(block_header)`.

I downgrade Codex's BLOCKER to **MAJOR** on evidence: this is not a false release. `dealBinding`
commits `state_root`, which the **buyer** fixes at funding time
(`RecknZkEscrow.sol:71-84`), and `env_hash` does not contain the header, so two anchors
differing only in `block_header` produce the same binding and the same verdict. What the buyer
loses is the header→`state_root` anchoring — which `README.md`'s Known gaps and R-4 already
disclose as an off-chain layer. The defect is that INV-2 is stated as an unconditional
biconditional and is not one.

**Repro:** valid MPT witness; build a header binding that root; set
`anchor.block_header = Some(header)`; then bump `anchor.timestamp`. Assert
`replay(...) == Err(HeaderMismatch(_))` while `execute(to_guest_input(&anchor, …))` commits a
verdict.

**Fix for round 2:** either give INV-2 the same explicit domain D that INV-1 has, or (better,
and three lines) make `to_guest_input` reject `Some(block_header)` and add it to the P-table.

### 6. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:38-45`, `:612-626`, `:1015-1023` — N-3's promise about `binder` is asserted and enforced by nothing

N-3 (`:38-45`) says the change *"keeps `binder`, `keeper` and `reckn-evm-content` (the three
other `reckn-reexec-evm` consumers) compiling without being touched"*, and `:1022-1023` says
AC-0b's prefix digest plus AC-15 *"is the whole of N-3"*.

It is not. AC-0b's digest covers `reexec-evm/src/lib.rs` **above** the
`#[cfg(any(test, feature = "testkit"))]` line (the only occurrence is `:711`), and AC-15 runs
`reexec-evm`'s own 16 tests. Neither sees the testkit surface — which is precisely what 008
changes (new builders, wrappers kept). And the testkit is a **cross-crate** surface:

```
binder/Cargo.toml:26          reckn-reexec-evm = { path = "../reexec-evm", features = ["testkit"] }
binder/tests/router_two_vms.rs:13   use reckn_reexec_evm::testkit::{addr, anchored_identity_witness};
```

So a testkit signature change breaks `binder`'s test build while every one of the 18 manifest
rows stays green. Neither `header.rs` nor `reexec-evm/Cargo.toml` is covered by any digest
either.

**Repro:** change `anchored_identity_witness`'s signature; run `bash zk-verdict/scripts/ac008.sh
--all` (passes) and then `cargo test -p binder` (fails to compile).

**Fix for round 2:** one manifest row — a `script` row running
`cargo check --tests -p binder -p keeper -p reckn-evm-content` (or the equivalent per-directory
invocation, since these are separate packages, not workspace members) with a fixed evidence
line. Cost: one line of spec, one line of script.

### 7. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:612-626`, `:1213-1222` — AC-0b installs a build condition that `003` **must** break, and OQ-2 does not mention it

AC-0b pins `sha256(zk-verdict/contracts/src/RecknZkEscrow.sol)` in
`zk-verdict/scripts/surfaces.pinned` and makes any change to that file fail `surfaces.sh`
(and, via the manifest, `ac008.sh --all`).

`003` is next in the execution order and **must** change that file: `AGENTS.md` §0 already
enumerates `refundAfterDeadline` as a permitted entry point and the contract does not have it
(`RecknZkEscrow.sol` today declares only `fund` at `:71` and `settleWithProof` at `:92`).
`003` r1 additionally rules the `transferFrom` return-value check in scope
(`RecknZkEscrow.sol:86` discards the boolean).

OQ-2 (`:1213-1222`) carefully enumerates the *documentation* pins 008 breaks in 003 and 004,
and says nothing about the *code* pin 008 installs **against** 003. Nobody is told who
re-pins, or when. Two specs in flight with a different agent each is exactly where this gets
lost.

**Repro:** land 008; add `refundAfterDeadline` per 003; `bash zk-verdict/scripts/surfaces.sh`
fails and `ac008.sh --all` reports `17/18`.

**Fix for round 2:** add a third bullet to OQ-2 naming `surfaces.pinned`, and state in AC-0b
that **003 re-pins it in the same commit that changes the file**, with the re-pin being a
visible diff rather than a silent regeneration.

### 8. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:977-990`, `:1186-1192` — the third pinned digest is already stale, one of §9(3)'s three obligations is already done, and all three cited line ranges are wrong

Codex's finding 5, verified and sharpened with the cause.

Recomputed today with the spec's own recipe:

```
awk '/^### Known gaps \(not closed\)/{f=1} f&&/^## /&&!/^### /{exit} f' README.md | shasum -a 256
→ 222eeeb84230c54050e9db26c9c070e1425ac3c9d92e4193a98431dca05ef99f   (44 lines)
```

The spec pins `04f567a3ae15dbb36a5528563deb7f25cb65e000615880eee1681776ae7c6dbe` (38 lines).
The other two digests still match (`8f65b75f…`, `fd4521ed…`).

**Cause**, from `git log`: `9ac4545` *"README: correct the precompile claim — they are not
disabled in-guest"* (Fri Sep 4 10:06:43 2026) landed **after** `d4f59ba`, the 008 spec commit.

Three consequences:
1. AC-14(i) requires the current digest to **differ** from the pinned one. It already differs.
   That sub-check would pass **even if 008 changed nothing**, which inverts its purpose.
2. §9(3) (`:1188`) instructs 008 to correct the "In-guest precompiles" bullet to R-3's wording.
   That is already done — `README.md:572-579` already reads *"In-guest precompiles run on
   different backends, and parity is unverified … Corrected 2026-09-04."*
3. All three line ranges in §9(3) are stale. Measured today: precompiles bullet
   **572-579** (not `:571-573`), the `u64` bullet **580-587** (not `:574-581`), the engine
   bullet **588-592** (not `:582-586`).

**Repro:** the `awk | shasum` line above, then `grep -n "^- \*\*" README.md` over 560-603.

**Fix for round 2:** re-pin to `222eeeb8…f99b`; drop the precompile bullet from §9(3)'s
obligations (or restate it as "already corrected in `9ac4545`, verify unchanged"); re-derive
the three line ranges; and — because "digest differs" is a weak check either way — make
AC-14(i) assert the *presence of the specific replacement sentences* as the primary condition
and the digest change only as a secondary one. The spec already gestures at this at `:988-990`;
make it the load-bearing half.

### 9. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:755-759`, `:467-472` — domain **D** is stated but nothing enforces it; AC-4's "fails loudly on both sides" holds only when the precompile address is absent from the witness

Codex's finding 2, **premise rejected, narrowed version kept.**

Codex claimed precompile addresses are warmed and dispatched as built-ins, so a call to `0x01`
never touches the database and the witness-closed DB gives no protection. **That premise is
false**, and I reject it below (Rejected finding R-1) with the source. `db.basic(address)` is
called unconditionally for any address not already in the journal, precompile or not.

What survives is narrower and still real. `:755-759` claims AC-4 *"closes R-3's reachability …
an unnoticed precompile-backend divergence **cannot arise** from a plan the seller smuggled in
— it fails loudly on both sides instead."* That holds only when the precompile address is
**absent from the committed witness**. Precompile addresses that hold a balance in the
committed state (people do send ETH to `0x01`…`0x09`) are MPT-provable, so a seller can supply
a valid inclusion witness for one and the plan then enters a backend pair whose equivalence
the spec itself declares untested. Nothing in the guest, in `to_guest_input`, or in any AC
rejects it — D (`:467-472`) is a description, not a check.

Severity **MAJOR**, not BLOCKER: it needs the address to exist in the buyer-committed prestate,
and a backend divergence is possible, not demonstrated.

**Repro:** witness an account at `Address::from(u64_to_address(1))` with a valid inclusion
proof and non-zero balance; plan a CALL to it with an `ecrecover` payload; assert that neither
engine refuses. There is no test that fails.

**Fix for round 2:** either (i) make the guest panic on a CALL whose `bytecode_address` is in
`{0x01, 0x0a, 0x0b…0x11}` — a new P-transition, matched by an off-chain refusal so INV-2 stays
an iff — or (ii) soften `:755-759` to say D is **disclosed, not enforced**, and put that in the
honest-scope text at §9(1). (i) is the honest one and is ~5 lines.

### 10. [MINOR] `docs/specs/008-verdict-domain-soundness.md:147-148` — the `base_fee` half of "two of these bite `002` on the first real transaction" is false about today's guest

`:147-148`: *"a real anchor has `base_fee > 0` with `gas_price = 0`, so the guest rejects the tx
and the off-chain engine does not."*

Today's guest never sets `block.basefee` (`program-revm/src/main.rs:122-127` sets only
`chain_id`), so it runs at `BlockEnv::default().basefee = 0`
(`revm-context-16.0.1/src/block.rs:120`). The EIP-1559 check compares `gas_price (0)` against
`basefee (0)`; `0 < 0` is false. **The guest does not reject** — it silently executes under a
*different* base fee, which is a divergence for a `BASEFEE`-reading plan, not a rejection.

The nonce half of the same paragraph is correct (TxEnv `nonce` defaults to 0, `disable_nonce_check`
is `false` in the guest, so a caller with `nonce > 0` fails), and E-09/E-10 are both specified
correctly, so the conclusion is unaffected. But §1's opening (`:8-10`) asserts every fact was
checked on disk, and this one was not.

**Repro:** set `anchor.base_fee = 1_000_000_007`, run the current guest on a plan that does not
read `BASEFEE`, observe `Reproduced` rather than a rejection.

### 11. [MINOR] `docs/specs/008-verdict-domain-soundness.md:272-275` — the `optional_no_base_fee` stop condition is a phantom and should be struck

§3.4: *"If that feature does not build for `riscv64im-succinct-zkvm-elf`, **stop and report**
(`AGENTS.md` §7) — do not work around it."*

`revm-38.0.0/Cargo.toml:88`: `optional_no_base_fee = ["context/optional_no_base_fee"]`.
`revm-context-16.0.1/Cargo.toml:67`: `optional_no_base_fee = []`. It is a pure `cfg` flag with
**zero** dependencies that adds one `bool` field at `cfg.rs:120-121`. It cannot fail to build
for a target the crate already builds for.

An `AGENTS.md` §7 stop costs founder attention on the critical path four days before the
withdrawal checkpoint. Pre-registering one that cannot fire trains everyone to ignore them.

The **other** stop (§3.4's sibling at AC-2 V-14, the exclusion-proof builder, `:700-705`) is
reasonable because it already carries a fallback — and note that `alloy-trie-0.9.5`'s
`ProofRetainer` retains nodes on the *prefix path* of a target, so a single-leaf trie plus
`ProofRetainer::from_iter([absent_target])` very likely discharges it in-spec. Keep that one;
strike the feature one.

### 12. [MINOR] `docs/specs/008-verdict-domain-soundness.md:197-206` — the cost comparison against option (b) is incomplete, in the direction that flatters the chosen option

Codex's finding 4, kept at **MINOR with its reason replaced.** Codex said the spec's
enumeration was "backwards"; it is not — `:202-204` does credit (b) with saving the predicate
and SVM fixtures, so that part of Codex's finding is wrong.

What is true is that the enumeration stops too early. (b) also avoids: the `reexec-io`
`DeltaCheck`/`GuestInput` widening; the v2 preimage migration across **all three** guests
(§3.5 changes `verdict_trace_hash`, which `program-svm/src/main.rs:24,127` also uses); the
fixture JSON hex-encoding change (AC-9(3)); and the fixture readers in five `.t.sol` files.
"It buys nothing" (`:205`) is therefore an overstatement in the direction of the chosen option
— `AGENTS.md` §5's "数字が製品に都合よく転んだときこそ疑う".

**The conclusion is still right and I endorse it.** (b) is not a valid completion state:
`RecknZkEscrow` has no timeout (verified — the contract declares only `fund` and
`settleWithProof`), so (b) converts theft into a permanent lock; and it makes 002 impossible
by construction, which `AGENTS.md` §3 already rules out. Fix the arithmetic, keep the decision.

### 13. [MINOR] `docs/specs/008-verdict-domain-soundness.md:266-270`, `:443-448` — `TxEnv` is the one place "engine identity is data, not convention" is still convention

§3.4 makes `TxEnv { ..Default::default() }` a **constant on both sides**, but INV-6 (`:443-448`)
and AC-6 (`:776-798`) cover only `EvmAnchorV1` / `AccountWitness` / `StorageWitnessV1` /
`EvmCallPlanV1` / `GuestEnv`. No layer destructures `TxEnv`, and no AC-3 vector reads a `TxEnv`
field (`GASPRICE`, `ORIGIN`).

The two constructions do agree today — `reexec-evm/src/lib.rs:516-524` and
`program-revm/src/main.rs:129-138` both set caller / kind / value / data / gas_limit /
`gas_price: 0` / `chain_id: Some(chain_id)` and `..Default::default()` — so this is not a live
bug. It is the residual gap in the guarantee the spec is selling.

**Fix:** have `env-parity.sh` assert the two `TxEnv` literals are textually identical modulo
the five plan fields, or add a `GASPRICE`/`ORIGIN` vector to AC-3 (which would raise AC-3's
count from 11 to 13 and the manifest with it).

### 14. [MINOR] `docs/specs/008-verdict-domain-soundness.md:833-835` — AC-7b's fixture path contradicts the repo's layout

`:834` names `zk-verdict/contracts/test/fixtures/alt-binding.json`. That directory does not
exist. The four committed fixtures live in `zk-verdict/contracts/src/fixtures/`, and the tests
read them as `"src/fixtures/…"` (`RecknReexecVerdict.t.sol:19`,
`RecknVerdictVerifierFixture.t.sol`, `RecknSvmVerdict.t.sol`, `RecknZkEscrow.t.sol`).

### 15. [MINOR] `docs/specs/008-verdict-domain-soundness.md:302-306` — §3.5 labels the `reckn/zk/verdict/v2` preimage "predicate guest"; the SVM guest uses it too

`program-svm/src/main.rs:24` imports `verdict_trace_hash` and `:127` calls it. §3.5's comment
says "// predicate guest". INV-7's tag list (`:449-451`) is complete and correct; only the
label is wrong, but the label is what an implementer reads when deciding which guest to edit.

---

## Rejected findings

### R-1. Codex finding 2 (BLOCKER) — "precompile addresses are warmed and dispatched as built-ins; calling `0x01` does not require an `AccountWitness`, so the witness-closed DB gives no protection"

**Rejected: the premise is false.** Codex cited
`revm-context-16.0.1/src/journal/warm_addresses.rs:11-18` — but that module governs EIP-2929
**cold/warm gas accounting only**. The database read is unconditional:

`revm-context-16.0.1/src/journal/inner.rs:920-927`
```rust
Entry::Vacant(vac) => {
    // Precompiles,  among some other account(access list and coinbase included)
    // are warm loaded so we need to take that into account
    let is_cold = self.warm_addresses.check_is_cold(&address, skip_cold_load)?;
    let account = if let Some(account) = db.basic(address)? {
```
`warm_addresses` supplies `is_cold` at `:923-925`; `db.basic(address)?` at `:927` runs anyway
and its error propagates.

Both entry points reach it. Top-level: `revm-handler-18.1.0/src/execution.rs:20-22` —
`create_init_frame` does `journal.load_account_with_code(target_address)?` for
`TxKind::Call`. Nested: `revm-interpreter-35.0.1/src/instructions/contract.rs:157-158` →
`load_acc_and_calc_gas` → `load_account_delegated_handle_error` (`call_helpers.rs:73`).
`revm-handler-18.1.0/src/frame.rs:203` (`precompiles.run`) is reached only **after** the
account has already been loaded.

So on a witness-closed database a plan entering an **unwitnessed** precompile does fail loudly
on both sides, exactly as AC-4 claims. The narrower defect that does survive — a *witnessed*
precompile address, and D being descriptive rather than enforced — is kept as finding 9.

### R-2. Codex finding 4's stated reason (MAJOR) — "the spec's claim that (b) 'saves only' Solidity and predicate/SVM fixtures is backwards"

**Rejected as stated.** `:202-204` reads: *"any change to the guest ELF changes its vkey and
invalidates the committed fixtures, so (b) saves only the Solidity struct edit **and the
predicate/SVM fixtures**."* The spec already credits (b) with exactly what Codex says it
denies. The enumeration is incomplete for other reasons, which I keep as finding 12.

### R-3. Codex's list of "exists, not says something" invariants — INV-8 and INV-10

**Partially rejected.** Codex named INV-3, INV-6, INV-7, INV-8, INV-10 and INV-11. INV-3,
INV-6, INV-7 and INV-11 are fair (grep/name-set/literal-tag/document-presence formulations —
and they are the ones findings 1, 6 and 8 attack). INV-8 and INV-10 are not:

- **INV-8** is checked by `test_AC12_public_values_abi_is_224_bytes` (`:942-945`), which
  encodes all four fields at `U256::MAX` and asserts a **lossless round trip** — a semantic
  check, not a length check. `abi.encode`'s 224 bytes is independently correct: a `uint64`
  already occupies a full 32-byte head slot.
- **INV-10** is checked by AC-8's six tests (`:844-858`), each of which asserts both that
  `zk_outcome` maps to `REPRODUCED`/`FAILED` **and** that the raw `ReplayRecordV1` code
  (`reexec-evm/src/lib.rs:567-569`: `Reproduced => 1`, `Failed => 2`) is **not** equal to it.
  A degenerate `fn zk_outcome(_) -> u8 { 0 }` fails five of six. That says something.

### R-4. Codex's tier remark — "§9's proposed 'refunds the buyer' language must stay explicitly framed as local Forge/SP1 proof verification, not a deployed-chain result"

**Rejected: not a defect.** The sentence at `:1148-1149` reads *"Closed by task 008;
`reexec-falserelease-fixture.json` is that exact input, proven, refunding the buyer."* AC-10.3
(`:905-907`) decides it with `forge test` against `SP1Verifier` and a committed Groth16 proof.
The document's header (`:3-6`) declares the tier as *"local machine only — … **No anvil, no
testnet, no mainnet, no network calls.** Nothing in this document claims anything about a
deployed chain."* and §7.4 (`:1084-1085`) forbids describing any result as testnet or mainnet.
The claim is at its own tier.

**Tier discipline overall: no violation found.** I checked every numeric claim in 008. The
cycle figures are the only carried-over numbers and 008's response is to **forbid** carrying
them (AC-14(ii) requires re-measurement into `cycles.json` with exact integers and deletes the
two never-instrumented `~180k` sub-figures at `CLAUDE.md:36` and `zk-verdict/README.md:143`).
That is the correct direction. Not one of `zk-verdict/README.md`'s honest-scope residuals is
written as resolved except the two 008 actually closes, and §9(1)'s replacement text keeps
R-1…R-6 verbatim.

---

## Deferred

None. Every finding above is inside 008's own frame — its acceptance criteria, its invariants,
or its documentation obligations. Nothing needed to move to `docs/decisions/`.

---

## Founder uncertainty 1 — is (a) right, and is it closable by 9/12?

**Keep (a). Do not switch to (b). Cut the harness, not the fix.**

(a) is correct and the rejection of (b) and (c) survives contact with the files, with the one
arithmetic correction in finding 12. Two facts decide it:

- **(b) is not a completion state.** `RecknZkEscrow` has no timeout — the contract declares
  `fund` (`:71`) and `settleWithProof` (`:92`) and nothing else — so a guest that panics on
  out-of-domain inputs converts a theft into a **permanent fund lock** until 003 lands.
- **(b) forecloses 002.** §2.2's table is arithmetically right: `2^64` wei is 18.446744… ETH
  and `2^64` at 18 decimals is 18.446744… tokens, so any realistic ERC-20 balance slot is
  out of domain, and a RAY-scaled value (`≥ 10^27 > 2^64`) is *always* out of domain.
  `AGENTS.md` §3 already rules that 002 cannot start before 008 closes.

**But the spec is larger than the fix, and the excess is where 8 of my 15 findings live.**
The remedy itself — widen to `U256`, carry the environment, close the database over the
witness, move the preimages to v2, regenerate four fixtures, move six documents — touches
roughly 15 files and is a normal two-to-three-day change. The **harness** around it (8 shell
scripts, 79 one-test-per-vector cargo tests, an 18-test forge expectation, a ten-sandbox
selftest, a twelve-site exact-integer cycle gate, two pinned-digest mechanisms) is the
majority of the calendar and is where findings 1, 2, 3, 6, 7, 8 sit. Three of those
(1, 2, 3) mean the harness as written either cannot be built or does not do the job it is
there for.

**Concrete cut list for round 2** — this is the founder-facing recommendation:

*Load-bearing, keep unchanged:*
- **AC-1** (the 15⁴ pool) — the direct kill for the arithmetic defect.
- **AC-2** V-01…V-14 through the real ELF — the only evidence the two engines agree on values.
- **AC-3** E-01…E-10 — the only evidence the environment is applied; all 8 `GuestEnv` fields
  are probed, which I verified field by field.
- **AC-4** W-01…W-03 (+ the two new empty-proof vectors from finding 4) — INV-5 is **false**
  without a witness-closed database, so this is not optional.
- **AC-7a** (18 binding components) and **AC-7b**.
- **AC-9** (vkey freshness) — the only thing tying the committed fixtures to the current guest.
- **AC-10.3** (the false-release vector refunding the buyer on a real Groth16 proof) — this is
  simultaneously the soundness proof and the demo money-shot.
- **AC-0 / AC-0b** — the central claim.

*Shrink:*
- **AC-13** → in-place semantic mutations (NC-1, NC-5, NC-9, NC-10) with a `trap` revert, over
  3 rows, not 10 sandbox copies. This is *more* rigorous and *far* cheaper (findings 1, 3).
- **AC-14** → keep `cycles.json` and a grep that no `~NNNk` literal survives at the 12 sites;
  drop the exact-integer-at-every-site requirement, which will be the first thing quietly
  relaxed under time pressure.
- **AC-6** → the exhaustive destructure already produces a **compile error**, which is the
  strong half. Keep only the two `disable_base_fee` / `disable_nonce_check` greps and the
  `TxEnv` comparison from finding 13; drop the bash parser of Rust struct declarations.
- **AC-5** → fold into AC-6's script.

*Add (cheap, closes findings):*
- One `script` row building `binder` / `keeper` / `reckn-evm-content` (finding 6).
- Two `W-` vectors for the empty-proof case (finding 4).
- `to_guest_input` rejects `Some(block_header)` (finding 5).

With those changes I judge 008 closable well inside 9/12 and comfortably before the 9/9
checkpoint. **As written, I do not.** Codex reached the same conclusion independently, from
the same direction (keep (a), cut AC-13 and the cycle gate).

## Founder uncertainty 2 — is the engine-identity guarantee real?

**No — four layers, four surviving paths.** Named, with what fails to catch each:

1. **`TxEnv`** — covered by none of the four layers (finding 13). Currently identical on both
   sides, so this is convention, not a live bug.
2. **`anchor.block_header = Some(_)`** — dropped by layer 1's *exclusion set*, so layer 1
   cannot fire; not a `GuestEnv` field, so layers 2 and 3 cannot; and no vector supplies a
   header, so layer 4 cannot (finding 5).
3. **Empty MPT proofs** — accepted in-guest, refused off-chain. Layers 1–3 are about
   environment fields and never look at proofs; layer 4's W-01…W-03 do not include the case
   (finding 4).
4. **Precompile backends** — the guest is `default-features = false`, the off-chain engine has
   revm's defaults, so `0x01`, `0x0a`, `0x0b`–`0x11` run different implementations. Layers 1–3
   do not model dispatch; AC-3's E-01…E-10 never enter one; D excludes them but nothing
   enforces D (finding 9).

**On the sub-question — "is layer 4 looking at the real ELF, or a convenient build?"** I found
no evidence of a stale-build path. `zk-verdict/script/build.rs:4-8` calls
`sp1_build::build_program_with_args` for all three guests on every cargo build, and the
consumers use `include_elf!` (`script/src/bin/reexec.rs:41`), so the ELF regenerates from
source. AC-9's vkey check is *not* circular for the normal path: it compares the freshly built
ELF's vkey against the fixture's, so "changed the guest, did not regenerate" is caught.
**One residual I could not close:** `sp1-build 6.3.1` is not in the local registry cache
(`grep -A3 'name = "sp1-build"' zk-verdict/Cargo.lock` → `registry+…crates.io`, no vendored
source), so I could not verify whether it honours a skip-build environment variable. I record
this as a **suspicion, not a finding**. Cheap insurance either way: have `ac008.sh` unset any
`SP1_*` skip variable and record the ELF's `sha256` alongside the cycle counts in `cycles.json`.

**The four layers are good design** — the exhaustive destructure in particular converts a
whole class of omission into a compile error, and running the real ELF rather than an extracted
library is the right call for the reason §3.6.4 gives (`program-revm` is its own cargo
workspace and would feature-unify differently). They are not sufficient, and the spec should
say so where it currently says "engine identity is data, not convention" (INV-6).

---

## What must change before round 2

1. AC-13: replace renames with semantic mutations (finding 1) **and** replace the ten sandbox
   copies with in-place mutation + guaranteed revert over 3 rows (finding 3).
2. AC-11: state the check as the early-return pattern, not the `vm.exists` string (finding 2).
3. §4.1: add P-10 / P-11 for empty account and storage proofs; add W-04 / W-05 to AC-4 and
   raise its manifest count 3 → 5; say why `MissingCodeWitness` has no analogue (finding 4).
4. INV-2: give it an explicit domain, or make `to_guest_input` reject `Some(block_header)` and
   add the P-transition (finding 5).
5. Add a manifest row building `binder` / `keeper` / `reckn-evm-content` (finding 6).
6. OQ-2: add `surfaces.pinned`, and state that 003 re-pins in the same commit (finding 7).
7. AC-14: re-pin the README digest to `222eeeb8…f99b`; drop or restate the already-completed
   precompile obligation in §9(3); re-derive the three line ranges (572-579 / 580-587 /
   588-592); make the literal-sentence check the primary condition (finding 8).
8. §5.1 / AC-4: either enforce D against precompile entry with a new P-transition, or say
   plainly that D is disclosed and not enforced, and put that in §9(1) (finding 9).
9. §2.3: correct the `base_fee` sentence — today's guest does not reject, it runs at basefee 0
   (finding 10).
10. §3.4: strike the `optional_no_base_fee` stop condition (finding 11).
11. §3.2: complete the (b) cost enumeration; keep the decision (finding 12).
12. INV-6 / AC-6: cover `TxEnv`, or state it as the residual (finding 13).
13. AC-7b: fix the fixture path to `zk-verdict/contracts/src/fixtures/` (finding 14).
14. §3.5: relabel the `reckn/zk/verdict/v2` preimage — the SVM guest uses it too (finding 15).
15. Apply the cut list in "Founder uncertainty 1" before implementation starts, or bring the
    scale question to the founder explicitly. This is a 9/9 checkpoint task.

VERDICT: CHANGES

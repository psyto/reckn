# Review 008 spec round 2

Payload: `/tmp/reckn-payload-008-spec-r2.md`
Codex raw: `/tmp/reckn-codex-008-spec-r2.md`

Subject: `docs/specs/008-verdict-domain-soundness.md` (**1731 lines**), drafted by `reckn-spec`
(Claude Code). **Codex did not write it** — author independence holds, and the payload said so
in its first line. Codex was called **once**, `-s read-only`, prompt by argument with
`< /dev/null`.

Codex returned **3 findings (2 BLOCKER / 1 MAJOR)**. After adjudicating each against the files
on disk: **3 kept** (two of them I had reached independently before the call; one — finding 5 —
I had not). I added **5 findings of my own**. Remaining: **8 findings — BLOCKER 2 / MAJOR 4 /
MINOR 2.**

Every empirical statement below was produced on **2026-09-04** by running the command shown or
by reading the cited file. No number is carried over from round 1.

---

## What round 2 fixed, and what is healthy — recorded so round 3 does not re-litigate it

- **All fifteen r1 findings are answered, and the answers are real, not cosmetic.** I spot-checked
  the ones that carried evidence:
  - r1 finding 2 (the `vm.exists` self-contradiction) is closed correctly. Measured today:
    `grep -o 'vm\.exists' zk-verdict/contracts/test/*.t.sol | wc -l` → **7**;
    `grep -cE 'if[[:space:]]*\([[:space:]]*!vm\.exists\(' …` → 2/0/2/1/2 = **7**. The two counts
    do coincide today, exactly as `:1213-1216` claims, so the restated check loses nothing.
  - r1 finding 8 (stale digests / stale line ranges) is closed by **deleting** the documentation
    digests, which is the right call. The three re-derived README ranges are correct: measured
    `grep -n` gives the precompile bullet at **572**, the `u64` bullet at **580**, the UNVERIFIED
    bullet at **588**, next bullet at **593** — so 572-579 / 580-587 / 588-592 ✓.
  - AC-14(i)'s seven "must be absent" literals: I ran `grep -cF` for each against the named file.
    **All seven return 1 today.** They are real removals, not phantom ones.
  - AC-14(iii)'s regex: `grep -noE '~\*{0,2}[0-9]+(\.[0-9]+)?k'` over the five-file doc set
    returns **14**; the naive `~[0-9]…` form returns **12**. The `\*{0,2}` really is load-bearing
    and the breakdown (6 × `410k`, 5 × `980k`, 1 × `21.7k`, 2 × `180k`) is exactly right.
  - r1 finding 6: AC-16 is correct and its premise checks out. `binder/Cargo.toml:26` does take
    `features = ["testkit"]`; `binder/tests/router_two_vms.rs:13` does
    `use reckn_reexec_evm::testkit::{addr, anchored_identity_witness};`; there is **no root
    `Cargo.toml`**, so the three per-directory invocations are the right shape.
- **The empty-MPT-proof correction is right and round 1 was wrong.** Verified directly:
  `alloy-trie-0.9.5/src/proof/verify.rs:29-43` returns `Ok(())` on an empty proof **only** when
  `root == EMPTY_ROOT_HASH` **and** `expected_value.is_none()`; otherwise `ValueMismatch` or
  `RootMismatch`. `zk-verdict/program-revm/src/main.rs:58-60` passes
  `Some(alloy_rlp::encode(trie_account))` for **every** account, so an empty *account* proof can
  never return `Ok` — the account variant already agrees on both sides. `main.rs:67-72` passes
  `None` exactly when the witnessed value is zero, so the *storage* variant does diverge.
  **P-11 closes a real divergence; P-10 makes the reason match. Round 2's asymmetry is correct.**
  Codex reached the same conclusion independently.
- **The manifest arithmetic recomputes.** 18 rows; 8 cargo rows summing to 8+14+13+8+18+6+3+16 =
  **86**; 2 forge rows = **6**; 8 script rows; `lib` = 8+3 = **11**, `script` = 14+13+8+18+6 =
  **59**, `reexec-evm` = **16**; 11+59+16 = **86** ✓. Measured base counts still hold:
  `grep -c '#\[test\]' reexec-evm/src/{lib,header}.rs` → 10 and 6 = **16**;
  `grep -n "function test" zk-verdict/contracts/test/*.t.sol | wc -l` → **12**, so 12 + 6 = 18 ✓.
- **The AC-2 arithmetic recomputes** for V-03, V-08, V-11, V-12, V-13 (I re-derived the
  `guest today` column from `u64_low` + `saturating_sub` in `u64`). One cell is wrong — finding 7.
- **`surfaces.pinned` is not a ritual, and N-1 is achievable.** `RecknZkEscrow.sol:4` imports
  `VerdictPublicValues` from `RecknVerdictVerifier.sol` and `:99-117` reads only `outcome`,
  `dealBinding`, `traceHash` — so widening the struct's four numeric fields to `uint256` changes
  `RecknVerdictVerifier.sol` and **not one byte of `RecknZkEscrow.sol`**. The pin is meaningful
  inside 008's own window. Its one defect is finding 6, not its short life. Codex agrees.
- **Tier discipline: no violation found.** The header (`:3-6`) declares local-only; AC-10's tier
  note repeats it; §7.4 forbids describing any result as a chain result; AC-14(iv) *forbids*
  carrying the old cycle figures and requires re-measurement into `cycles.json` with exact
  integers plus the ELF `sha256`. §9(1)'s replacement honest-scope text keeps every residual
  R-1…R-9 — **except one sentence, which is finding 1.**
- **Settled in r1 and correctly not re-opened:** (a) vs (b); the precompile/database-read
  question (`revm-context-16.0.1/src/journal/inner.rs:920-927`). Codex did not re-open either.

---

## Findings

### 1. [BLOCKER] `docs/specs/008-verdict-domain-soundness.md:452-470`, `:567-569`, `:706-714`, `:1550-1556`, `:1602-1607` — G-1/G-2/G-3 run on the **prover's** machine, so "Δ is unreachable" is false against the adversary this document itself names, and that false sentence is scheduled into the shipped honest scope

Codex's finding 1, verified and kept at BLOCKER. I reached the same conclusion independently
before the call; the payload asked for it explicitly, and Codex added the `reexec.rs` repro.

`:308-311` (§3.2(c)) states the threat model in the document's own words:

> **The prover is the adversary** — `GuestInput` is supplied by whoever generates the proof,
> normally the seller, and **there is no sanitiser between them and the guest**.

`to_guest_input` (`:452-455`) **is** that sanitiser. It is a host function in
`zk-verdict/script/src/lib.rs`. A prover who does not call it loses nothing: the guest's entry
point is `sp1_zkvm::io::read::<GuestInput>()` (`zk-verdict/program-revm/src/main.rs:95`), and
the existing host binary already constructs a `GuestInput` by struct literal and writes it
straight to stdin — `zk-verdict/script/src/bin/reexec.rs:123-140` (the literal) and `:164-166`
(`stdin.write(&input)`). Nothing in §4.1's P-table adds an in-guest Δ check, an in-guest header
check, or an in-guest predicate-shape check.

The consequences are not symmetric, and only one of them is a soundness problem:

- **G-1** (`block_header`): bypassing it yields a `GuestInput` identical to a no-header one. No
  new capability. Liveness/claim only.
- **G-3** (predicate shape): same — see finding 3, it cannot fire anyway.
- **G-2** (Δ = `{0x01, 0x0a, 0x0b–0x11}`): **this one is soundness.** The seller chooses the
  *witness contents*. `dealBinding` commits `state_root`, `env_hash`, `check_hash`, `plan_hash`
  — it does **not** commit which accounts the witness contains. So for a buyer-funded plan whose
  target code reaches `ecrecover` on a nested CALL, the seller may include `0x00…01` with a
  valid inclusion proof against the committed `state_root`, skip `to_guest_input`, and the guest
  executes it on the `k256` backend while `reexec-evm` executes it on `secp256k1`
  (`revm-precompile-34.0.0/src/secp256k1.rs:4-8`). The spec itself declares that pair's
  equivalence **untested** (R-3).

The claim is therefore false in three places, in ascending order of harm:

- `:629-630` (§4.3): *"**A proof of an execution that entered Δ.** G-2 plus the witness-closed
  database, §3.6. Both cases are closed, so this transition has no path."*
- `:1552-1554` (R-3): *"After 008, Δ is **unreachable**: witnessed → G-2 refuses, unwitnessed →
  both engines refuse."*
- `:1602-1607` (§9(1), the text that **ships into `zk-verdict/README.md`'s honest scope**):
  *"008 makes `0x01`, `0x0a` and `0x0b`–`0x11` **unreachable** — a witnessed one is refused at
  the input, an unwitnessed one fails on both sides."*

The third is the product's defined failure mode: a soundness claim published as closed while it
is open. The caveat that follows it ("unreachable is not equivalent") is correct and does not
rescue it — the caveat qualifies the *conclusion*, and the **premise** is what is false.

**Repro:** build W-06's input (a witness containing `0x00…01` with a valid inclusion proof and a
non-zero balance, plan CALLing it), construct the `GuestInput` **by struct literal** the way
`zk-verdict/script/src/bin/reexec.rs:123-140` already does, `stdin.write(&input)`, run the real
ELF through SP1 `execute()`. Under the round-2 specification the guest has no rejection to make.
`to_guest_input` is never called; AC-4's W-06 passes anyway, because W-06 asserts a property of
the **host function**, not of the guest.

**Fix for round 3 (~8 lines of spec):**
1. Move the Δ check **into the guest** as a new P-transition — **P-12: any address in
   `input.accounts`, or `input.plan.target`, is in Δ → panic.** It is a syntactic check on
   `GuestInput`, so it costs nothing and needs no execution tracing. Justify its missing
   off-chain mirror the way **P-9** is already justified at `:583` ("no off-chain analogue …
   reachable only by a hand-built `GuestInput`") — that paragraph is the correct template and it
   is already in the document.
2. Keep G-2 in `to_guest_input` as the *host-side early refusal*, and relabel §5.1's status
   column **"enforced in-guest (P-12), refused early at the host (G-2)"**.
3. Relabel G-1 and G-3 honestly: **"host-side hygiene; no in-guest analogue and none needed,
   because bypassing them yields an input the guest already handles."** Do not leave them in a
   column headed "enforced" beside a soundness gate.
4. Add **W-09** to AC-4: the hand-built-`GuestInput` bypass of W-06, asserting `execute()`
   returns `Err`. AC-4 goes 8 → 9 and the manifest row with it. Without W-09 the fix is another
   claim with no test.
5. Rewrite the three sentences above. `:1602-1607` must say Δ is **rejected by the guest**, not
   "unreachable at the input".

### 2. [BLOCKER] `docs/specs/008-verdict-domain-soundness.md:792-797`, `:1280-1289`, `:1481-1504` — the four mutants guard 4 of 16 acceptance criteria; **AC-3, which is the whole of axis 2, has no mutant**, and §7.3's honesty does not close the hole

Codex's finding 3, verified, kept at BLOCKER, and **extended** — Codex's construction is
sharper than mine on one point and misses the script rows entirely (finding 4).

AC-13 is round 2's answer to r1 BLOCKER 1, and as a mechanism it is a genuine improvement:
in-place patch → assert the `sha256` moved → require the target row to exit non-zero → restore
from byte copies, with `trap` installed first and no git state touched. That design is right.
Its **coverage** is not.

The four mutants target AC-01, AC-02, AC-04, AC-07a. **Twelve of the sixteen acceptance criteria
are unmutated**, including:

- **AC-3 (13 tests)** — the differential over the block environment. §2.3 is one of the two axes
  this task exists to close ("the guest configures only `chain_id`, so it is not even running the
  same EVM"), and **not one mutant touches it**. Axis 1 gets two mutants (M-1, M-2); axis 2 gets
  zero.
- AC-8 (6), AC-12 (3), AC-7b (2), AC-10 (4) — including **AC-10 test 3**, the false-release
  vector refunding the buyer on a real Groth16 proof, which the document itself calls
  "simultaneously the soundness evidence and the demo money-shot" (`:1191-1192`).

That is **28 of the 86 tests plus both forge rows**, unguarded.

Codex supplied a construction that survives all four mutants while still being wrong, and it is
better than mine because it does not need tautologies everywhere:

> Keep only AC-2 V-03 substantive; make V-04…V-14 tautologies; **truncate to 128 bits rather
> than 64**. M-1 still changes V-03 and is detected, while high-limb failures remain.
> … Make all AC-3 tests tautologies and leave environment application wrong; satisfy AC-6's text
> greps with dead or later-overwritten assignments.

I checked the 128-bit variant against the vector table: V-11 (`pre = 2^192`,
`post = 2^192 − 1`) is the only vector above `2^128`, so a 128-bit truncation is caught by
**exactly one** vector body — and that body is one of the ones the construction hollows out.
M-1 (restore limb 0) still flips V-03, so the selftest still reports `4/4`. The construction
holds.

§7.3's lower table (`:1481-1504`) is labelled **"Argued, not measured"** and says *"If the implementer wants any
row of the lower table to be a *claim*, it must become a fifth mutant, not a paragraph."* (`:1503-1504`) That
sentence is honest and it is the right rule — but it is applied to the *implementer* while the
**spec itself** leaves the highest-value row ("apply `spec_id` but leave the block env at
defaults → AC-3") in the argued column. Honesty about a gap is not a closure of it when closing
it costs one patch file.

**Repro:** implement the construction above; run `bash zk-verdict/scripts/ac008-selftest.sh`;
it prints `ac008-selftest: 4/4 mutants detected` while the guest truncates at 128 bits and
applies no block environment.

**Fix for round 3 — priced, because the last cost model is what r1 killed AC-13 for:**

| new mutant | change | target row | cost |
|---|---|---|---|
| **M-5** | delete the whole `modify_block_chained` / env application, leaving `chain_id` only — i.e. restore today's `main.rs:122-127` | **AC-03** | 1 guest rebuild + AC-03's 13 `execute()`s |
| **M-6** | truncate `pre`/`post` to **128** bits instead of 64 | **AC-02** (V-11 only) | 1 guest rebuild + AC-02's 14 `execute()`s |
| **M-7** | drop `check_hash` from the `dealBinding` preimage | **AC-07a** (`check.*` components) | shares M-4's rebuild shape |

M-5 is the one that must land; M-6 and M-7 are cheap follow-ons. Raise AC-13's evidence line to
`7/7 mutants detected` and re-price the budget: the 20-minute stop rule at `:1302-1306` was
computed for four mutants and must be restated for seven, **with the stop rule kept** — it is
the best-designed clause in §6 and it must not be quietly relaxed to fit.

### 3. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:452-455`, `:446-450`, `:711` — G-3 cannot be implemented from the signature the spec gives, so D's first clause is "enforced" by the existence of an enum variant and nothing else

Codex folded this into its finding 1; I split it out because the fix is independent.

`:711` states D's first clause — *"the predicate is a `PostStateDelta` with **exactly one**
check (N-4)"* — with status **"enforced, G-3"**. `:449` declares the variant
`PredicateIsNotSingleDeltaCheck`. But the function that is supposed to return it is

```rust
pub fn to_guest_input(
    anchor: &EvmAnchorV1, witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1, check: (Address, U256, U256, U256),
) -> Result<GuestInput, OutOfDomain>;
```

It takes **`check: (Address, U256, U256, U256)`** — a single check the caller has already
extracted — and never sees a `PredicateV1`. It therefore cannot observe predicate *kind* or
*count*, and `PredicateIsNotSingleDeltaCheck` is unconstructible. No vector tests it either:
AC-4's W-01…W-08 contain no G-3 case.

This is `AGENTS.md` §5's named failure at the level of the spec rather than the tests: an
invariant satisfied because a **name** exists (an enum variant, a table row reading "enforced"),
with no body behind it. It is the same shape as r1 BLOCKER 2 — a prescribed remedy that
contradicts a prescribed mechanism — and it survived a full round.

**Repro:** try to write the body. `to_guest_input`'s parameters contain no value from which
`PredicateV1::ResultEquals` or a two-check `PostStateDelta` can be distinguished. Then
`grep -n "G-3\|PredicateIsNotSingleDeltaCheck" docs/specs/008-verdict-domain-soundness.md` and
observe that no AC-4 row references either.

**Fix for round 3 (choose one, both ~3 lines):**
- (a) change the parameter to `predicate: &PredicateV1`, derive the single check inside the
  gate, keep G-3, and add a **W-10** vector (a two-check `PostStateDelta` and a `ResultEquals`)
  — AC-4 goes to 10 with finding 1's W-09; **or**
- (b) delete `PredicateIsNotSingleDeltaCheck` and restate D's first clause as **enforced by the
  type** — the tuple parameter makes a multi-check predicate unrepresentable — and say so in
  §5.1 instead of naming a gate.

(b) is cheaper and honest. (a) is stronger. Either is fine; leaving the table as it stands is not.

### 4. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:779-781`, `:818-836` — a `kind = script` row is satisfied by `echo`; six of the eight script rows carry substantive claims and none is mutation-tested

Mine. Codex touched one corner of this ("a fixture-check short-circuit mutant is cheap … but
only protects AC-9's script") and did not generalise it.

`:779-781` defines the whole verification contract for a script row:

```
kind = script  (columns: command, evidence)
  run <command>; exit status must be 0; stdout must contain the `evidence` line verbatim.
```

So this passes AC-09:

```sh
#!/usr/bin/env bash
echo "fixtures: 4/4 current (vkey and public values byte-identical)"
```

Round 1's BLOCKER 1 was "the harness counts test **names**". Round 2 closed that for four cargo
rows and left the identical hole one layer up: **eight rows whose entire evidence is a string the
script prints about itself.** Six of them carry load-bearing claims:

| row | what a stub would hide |
|---|---|
| AC-00b `surfaces.sh` | `RecknZkEscrow.sol` was edited — the central claim's guard |
| AC-06 `env-parity.sh` | `u64_low` still present; a cfg flag missing on one side |
| **AC-09 `fixtures-check.sh`** | **the committed fixtures are stale w.r.t. the guest — r1 recorded this as the *only* thing tying the fixtures to the current ELF** |
| AC-11 `no-skip.sh` | fixture-gated early returns restored |
| AC-14 `docs-check.sh` | the honest scope never moved — i.e. the false claims still shipped |
| AC-16 `consumers-check.sh` | `binder`'s test build is broken |

AC-00 (`no-keys.sh`) is exempt: it is pre-existing, `AGENTS.md` §0 owns it, and STATUS.md records
that it was validated against three negative controls.

**Repro:** replace `zk-verdict/scripts/fixtures-check.sh` with the two-line stub above and run
`bash zk-verdict/scripts/ac008.sh --all` → `ac008: 18/18 rows passed`, with a fixture whose vkey
does not match the built ELF.

**Fix for round 3 — this is the cheapest rigor in the whole document, because none of it needs a
guest rebuild:**

| mutant | change | target row | cost |
|---|---|---|---|
| **M-8** | flip one byte of a **comment** in `zk-verdict/contracts/src/RecknZkEscrow.sol` | AC-00b | seconds (`sha256` only) |
| **M-9** | re-insert `fn u64_low(v: U256) -> u64 { v.as_limbs()[0] }` into `program-revm/src/main.rs` | AC-06 | seconds (pure greps; no build) |
| **M-10** | flip one hex byte of `vkey` in `zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json` | AC-09 | one `execute()`, no rebuild |
| **M-11** | restore one `if (!vm.exists(F)) return;` in a `.t.sol` | AC-11 | one `forge test` |
| **M-12** | insert a line containing `~410k` into `zk-verdict/README.md` | AC-14 | one script run |

M-8 and M-9 cost **no compilation at all**. If the AC-13 budget cannot absorb all five, take M-9
and M-10 — they cover the truncation grep and the fixture-freshness check, which are the two
script rows whose failure is silent and permanent.

### 5. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:1080-1090` — AC-7a's `state_root` component cannot be tested the way AC-7a defines the test, and four more of its eighteen components need a witness the spec does not require

Codex's finding 2, verified, kept at MAJOR, and widened by four components.

`:1080-1082`: *"Each takes a baseline `GuestInput`, changes **exactly one** component to a
different value, runs the real ELF through `execute()` twice, and asserts the two committed
`dealBinding` values differ."* The eighteen components include **`state_root`**.

The guest authenticates before it commits anything: `zk-verdict/program-revm/src/main.rs:95-99`
reads the input and immediately calls `verify_prestate_authenticity(&input)`; `dealBinding` is
built at `:176-190`, far below. Changing **only** `state_root` invalidates every account proof
(`verify_proof` → `RootMismatch`), the guest panics, `execute()` returns `Err`, and **there is no
second `dealBinding` to compare**. The test as written cannot exist.

Four more components have the same shape for a different reason — the witness-closed database
008 introduces:

- `plan.caller`, `plan.target`, `coinbase`: a changed address that is **not in the witness** hits
  **P-5** (`MissingAccountWitness`) → panic → no second binding. Note the spec already discovered
  this for AC-3's E-05 (`:516-519`, "E-05's witness must contain `addr(0xc1)`") and did not carry
  the lesson to AC-7a.
- `check.address` / `check.slot`: a changed pair absent from the witness hits **P-8** → panic.

These five are fixable but not by the sentence at `:1080-1082`.

**Repro:** the required `test_AC07_state_root` clones a valid input, flips one byte of
`state_root`, and calls `execute()`. It returns `Err` at MPT verification; the assertion
"the two committed bindings differ" never gets two values.

**Fix for round 3 (~6 lines):**
- For `state_root`: build a **second valid prestate** (e.g. `PrestateSpec` with a different
  `slot7` value) so the root changes *with* a consistent witness, and assert the bindings differ.
  This still isolates `state_root`, because `env_hash` / `check_hash` / `plan_hash` are unchanged
  and `state_root` is the only other input to the binding (`:409-410`).
- For the five address/slot components: state that the **baseline witness contains both values**
  (`PrestateSpec::extra_accounts` already exists for this — `:530`), so the variant execution
  still runs.
- Replace "changes exactly one component" with "changes exactly one **bound** component", which
  is what the invariant actually needs.

### 6. [MAJOR] `docs/specs/008-verdict-domain-soundness.md:878-899`, `:1462` — `surfaces.pinned` is created by the same implementer it constrains, the spec does not state the expected digest, and the `reexec-evm` prefix boundary is ambiguous

Mine. Codex judged the pin "non-ritual" and I agree with that half — this is the other half.

`surfaces.pinned` appears in §7.1's **new files** list (`:1462`) and AC-0b (`:885-889`) says the
script compares against *"the value recorded in `zk-verdict/scripts/surfaces.pinned` **at the 008
base commit**"*. The document never states that value. So the implementer of 008 both **creates
the pin and is bound by it**: edit `RecknZkEscrow.sol`, then generate `surfaces.pinned` from the
edited file, and AC-0b passes while N-1 ("not one byte") is violated. `no-keys.sh` (AC-00) would
still catch an added *key*, but not a changed `transferFrom`, a changed event, or a changed
`require`.

The second half is a genuine ambiguity in a **build condition**. `:887-890` says: `sha256` of
everything in `reexec-evm/src/lib.rs` *"**above** the line `#[cfg(any(test, feature =
"testkit"))]` that precedes `pub mod testkit` (the only occurrence is `:711`)"*. Verified: that
`cfg` line is at **711** and is the only occurrence. But "above the line" does not say whether
line 711 is included, and the two readings give different digests. Two agents will not resolve
this the same way, and the one who resolves it after seeing a failure will resolve it the
convenient way.

**Repro:**
```sh
shasum -a 256 zk-verdict/contracts/src/RecknZkEscrow.sol
# 07d649c2808457f78f9371c96966abdd80a82636171a15e77516c0f5df33e45b
head -710 reexec-evm/src/lib.rs | shasum -a 256
# b4fd62d5b728c704a67ee8aaed463ac186859db079451fc83c47dd3ae5ab29d1   (excludes line 711)
grep -n 'cfg(any(test, feature = "testkit"))' reexec-evm/src/lib.rs   # → 711, only occurrence
```

**Fix for round 3 (2 lines):** write both digests into AC-0b as literals, with the exclusive rule
named — *"lines 1..=710, i.e. `head -710 | shasum -a 256`; the `#[cfg]` line itself is excluded"*
— so `surfaces.pinned` is a **transcription** of a reviewed value rather than a self-measurement.

### 7. [MINOR] `docs/specs/008-verdict-domain-soundness.md:965` — AC-2's V-10 `guest today` cell is wrong: today's guest **agrees**, and the labelling convention for unrepresentable `min`/`max` is inconsistent

Mine. I recomputed the whole column with `u64_low` + `u64` `saturating_sub`:

| vector | expected | spec says guest today | recomputed |
|---|---|---|---|
| V-03 | Failed | Reproduced | **Reproduced** ✓ |
| V-08 | Reproduced | Failed | **Failed** ✓ |
| **V-10** | Reproduced | **Failed** | **Reproduced — the guest agrees** ✗ |
| V-11 | Failed | Reproduced | **Reproduced** ✓ |
| V-12 | Reproduced | Failed | **Failed** ✓ |

`pre = 2^128` has limbs `[0,0,1,0]` so `u64_low(pre) = 0`; `post = 2^128 + 1` gives
`u64_low(post) = 1`; `saturating_sub(1, 0) = 1 ∈ [1, 1]` → `REPRODUCED`. V-10 is a **positive
control**, not a vector today's guest fails. The vector itself is still worth keeping (it probes
limb 2), but the column overstates how much of the table the current guest gets wrong — a small
error in the flattering direction, which `AGENTS.md` §5 names specifically.

Separately, the column has no convention for a `min`/`max` that `u64` cannot express: V-13's
`min = 20·10^18` is annotated *"impossible — `min` is not representable in `u64` today"*, while
V-08's `min = U256::MAX − 1` and V-03's / V-11's `max = U256::MAX` are silently treated as
saturating to `u64::MAX`. Pick one convention and state it once above the table.

**Repro:** the five-line recomputation above, or
`python3 -c "print((1 if (1-0)>=1 else 0))"` on the limb-0 values.

### 8. [MINOR] `zk-verdict/README.md:105-108` — AC-11 falsifies a sentence in `zk-verdict/README.md` and AC-14's stale-claim list does not include it

Mine. AC-11 (`:1221-1224`) replaces every `if (!vm.exists(F)) return;` with
`require(vm.exists(F), "…")`. `zk-verdict/README.md:105-108` says:

> `RecknVerdictVerifierFixture.t.sol` stays gated on the fixture's presence, so `forge test` is
> green for anyone who hasn't regenerated it.

After 008 nothing is gated on fixture presence, so the sentence is false as written. Practically
no one is harmed — all four fixtures are committed and AC-9 keeps them current — but AC-14 exists
precisely to stop a document from describing a mechanism that no longer exists, and its
seven-literal list (`:1322-1330`) does not contain this one.

**Repro:** `grep -n "stays gated on the fixture" zk-verdict/README.md` → `108`. Then read
AC-14(i)'s table: `zk-verdict/README.md` appears twice, for the precompile sentence and the
`u64` sentence, not for this one.

**Fix:** add an eighth literal to AC-14(i) and one replacement sentence to AC-14(ii)
(evidence line becomes `8/8 stale claims absent, 7/7 replacements present`), and rewrite the
sentence in §9 as *"the fixtures are committed, so a missing fixture is a hard failure rather
than a skipped test."*

---

## Rejected findings

**None.** All three Codex findings survived adjudication against the files. Codex made no claim
this round that I could disprove — a change from round 1, where one of its two BLOCKERs rested
on a false premise about `warm_addresses`. It also correctly declined to re-open the two
questions the payload marked settled.

Two Codex **remedies** I did not adopt as stated, recorded so round 3 does not follow them:

- **"For G-1/G-3, carry and bind sufficient anchor/predicate identity so a raw input cannot
  falsify the 'header absent / one delta check' facts."** Rejected as over-engineering.
  Bypassing G-1 produces an input identical to a compliant one (the guest has no header layer,
  N-5) and bypassing G-3 produces a single-check input by construction. Neither yields a
  capability, so neither needs binding. Only G-2 has soundness weight; finding 1 fixes only G-2.
- **"A pure grep cannot prove runtime semantics."** True but beside the point of finding 4: the
  grep-only mutants M-8/M-9 are not proving runtime semantics, they are proving that
  `surfaces.sh` and `env-parity.sh` **are not stubs**. That is the unguarded surface, and it is
  guarded for seconds of wall time.

---

## Deferred

None. Every finding is inside 008's own frame — its gates, its acceptance criteria, its
invariants, or its documentation obligations. Nothing needed to move to `docs/decisions/`.

---

## Founder uncertainty 1 — does this close by 9/9?

**The claim "only the calendar shrank" is largely true, and I did not find the schedule risk
where the founder's question points it. It is somewhere else.**

What the document says it removed, checked:

- **Ten sandbox copies → in-place patch + `trap` restore.** Real and large. Re-measured today:
  `du -sh zk-verdict/target` = **6.8G**, `du -sh .` = **21G**,
  `zk-verdict/program-revm/target/elf-compilation` = **558M** and warm. The r1 design cost ~210 GB
  of copying or ten cold `sp1-sdk` builds; the r2 design costs three single-crate RISC-V rebuilds
  plus one native rebuild. That is not a rounding difference.
- **Twelve enumerated cycle sites → two greps.** Real, and stronger: I ran both forms; the
  spec's regex finds **14** sites and the naive one finds **12**, and the line numbers it
  replaces were demonstrably stale within a day.
- **Two documentation digests → literal sentence presence/absence.** Real. I confirmed all seven
  "must be absent" literals are present today, so the check has actual work to do, and it cannot
  go stale the way a section digest does.
- **AC-6's bash parser of Rust struct declarations, AC-6's `GuestEnv` name grep, AC-5 as a
  separate row.** Removed, and their removal is argued from `AGENTS.md` §5 rather than from cost.

**86 tests is not the schedule blocker.** 59 of them are table rows over four vector tables in
four files, with one differential runner behind all of them; the subject code is small
(`program-revm/src/main.rs` 202 lines, `lib/src/lib.rs` 113, `reexec-io/src/lib.rs` 72, the five
`.t.sol` files 401 lines total). Codex reached the same conclusion independently.

**The unpriced item is the Groth16 regeneration, and it is the tail of every implementation
review round.** AC-9 requires all four fixtures to match the **final** guest ELF's vkey. 008
changes all three guests. Therefore:

- every impl round that touches a guest **invalidates all four fixtures**, and
- the only cost datum anywhere in the repo is `zk-verdict/README.md:97` — *"~15.9M constraints,
  ~34 s once the artifacts are local"* — which is the **predicate** guest (34 lines of Rust),
  not the re-execution guest at ~410k cycles today and more after U256 + a witness-closed DB.
  **Three** Groth16 fixtures exist today; 008 needs **four** current ones plus `alt-binding.json`.

The document requires the implementer to *report* this wall time (§7.5) but never budgets it,
and gives it no stop rule — while giving AC-13, the smaller item, both a budget and a stop
(`:1305-1310`). That is the same shape as r1 finding 3 (the largest schedule item unpriced),
relocated.

**Recommendation to the founder — sequencing, not cuts:**

1. **Measure first, before any code changes.** Regenerate `reexec-groth16-fixture.json` on the
   *current* guest and record the wall time. If it is minutes, the schedule is fine. If it is
   hours, that number — not the test count — decides the 9/9 question, and it can be known today.
2. **Freeze the guest early.** Regenerate all four fixtures **once**, after the impl review
   reaches APPROVE on the Rust, not on every round. State this in §7.2 so a late guest edit is a
   visible decision rather than a silent re-proving cycle.
3. Add a budget and stop rule for the regeneration mirroring AC-13's, in §7.5.

**Cut list, in order, only if (1) says it does not fit** — and note that these save test
*authoring and runtime*, not proving time, so they are the second lever, not the first:

1. **AC-3 E-11 / E-12** (2 tests). The document itself says they *"prove agreement, not fidelity"*
   (`:1010-1012`) and AC-6 check 4 already compares the two `TxEnv` field-name sets for free.
   AC-03 → 11.
2. **AC-8 6 → 2** (`Reproduced` + one `Failed` variant). All five `FailReason`s map to the same
   byte; four of the six tests are the same assertion. Keep the "not equal to the
   `ReplayRecordV1` code" half, which is what makes the test non-trivial.
3. **AC-1 test 2** (200 000 random `U256` draws). The 50 625-quadruple exhaustive pool is the
   part a truncating implementation cannot survive; the fuzz adds runtime, not coverage.
   AC-01 → 7.
4. **AC-12 test 2** (lamports representability) — `u64 ⊂ U256` is true by construction.
   AC-12 → 2.
5. **AC-16** last, and **only if N-3 is explicitly withdrawn** in the same edit (Codex's ordering;
   I agree). Dropping it silently would restore exactly r1 finding 6.

**Do not cut** AC-1's pool, AC-2, AC-3's E-01…E-10, AC-4, AC-7a/b, AC-9, AC-10, AC-13, AC-0/0b.
**And do not fund any cut from finding 2's new mutants** — M-5 (AC-3) is worth more than the
eleven tests in the cut list above, because it is the only thing that would make AC-3's thirteen
bodies mean anything.

## Founder uncertainty 2 — do the four mutants kill a hollow implementation?

**No, and the honest label does not close it — see finding 2.** Stated plainly for the founder:

- The **mechanism** is right. In-place patch, `sha256`-changed assertion, required non-zero exit,
  byte-copy restore under a `trap`, no git state touched. It is a real improvement on round 1's
  renaming, and a body of `assert!(true)` genuinely cannot survive a mutant aimed at its row.
- The **coverage** is not. Four mutants over sixteen criteria. A hollow implementation exists
  that reports `4/4 mutants detected` — Codex constructed one and I verified the key step:
  truncating at **128** bits instead of 64 is caught by exactly one vector body (V-11), M-1 still
  flips V-03, and the selftest still passes.
- The **worst single gap is AC-3**: axis 2 of the defect this task exists to close — "the guest
  configures only `chain_id`, so it is not even running the same EVM" — has thirteen tests and
  **zero** mutants. Axis 1 has two.
- The **second gap is structural**, and Codex only grazed it: eight `script` rows are verified by
  "exit 0 and print this string", which `echo` satisfies. That includes `fixtures-check.sh`, the
  only thing tying the committed Groth16 fixtures to the current ELF.
- **Cost of closing both:** one guest rebuild (M-5) plus four mutants that need **no compilation
  at all** (M-8, M-9, M-10, M-12) and one `forge` run (M-11). This is the cheapest rigor
  available anywhere in the document, and it should be bought before any vector is cut.

Answering the founder's question directly: **§7.3's "argued, not measured" label is honest and it
does not justify the hole.** The label is correct about what the table is; the defect is that the
spec put "apply `spec_id` but leave the block env at defaults → AC-3" in the argued column when
the document's own rule (`:1503-1504`) says a claim must become a mutant rather than a paragraph.
The rule is right. It was applied to the implementer and not to the spec.

## The other questions the founder asked

- **Does the domain gate refuse in-domain inputs?** **Yes, in one place, and it is a spec-internal
  contradiction rather than a design error.** D's Δ clause (`:713`) is *"the execution does not
  **enter** Δ"*, but G-2 (`:470`) refuses any input where a Δ address **appears in the witness**
  or is `plan.target`. A witness that includes `0x00…01` for an execution that never calls it
  satisfies D and is refused by the gate — so INV-2's *iff over D* is false in the liveness
  direction for exactly that shape. Fix is one line: restate D's third clause as the **syntactic**
  condition the gate actually tests (*"no address in Δ appears in `witness.accounts` and
  `plan.target ∉ Δ`"*), which also makes it match the in-guest P-12 that finding 1 requires.
  G-1 and G-3 match their D clauses exactly; no over-rejection there.
- **How much liveness did R-9 cost?** Little, and it is disclosed well. G-1 costs nothing real
  (the header layer is off-chain by N-5 either way). G-3 costs nothing (N-4 already forbids
  multi-check predicates). G-2 costs `ecrecover`-shaped plans, which OQ-3 names, prices, and
  recommends leaving disclosed — and which `002`'s plain-`transfer` workload does not touch.
  R-9 is the honest way to write this.
- **Is INV-2's scoping to D a weakening or a sharpening?** **A sharpening.** The r1 version was an
  unconditional biconditional that was false in both directions; the r2 version is true over a
  stated domain, and the document says out loud (`:1573-1578`, R-9) that outside D it claims
  nothing. D is not drawn around convenience — three of its four clauses are checks, and the
  fourth (`DIFFICULTY` / `BLOBBASEFEE`) is argued from both engines returning the same
  `BlockEnv::default()` constant, which is correct. The two caveats are findings 1 and 3: one
  clause is enforced only on the prover's machine, and one by nothing at all.
- **Is the empty-MPT correction right?** **Yes, and round 1 was wrong.** Verified against
  `alloy-trie-0.9.5/src/proof/verify.rs:29-43` and `program-revm/src/main.rs:58-60,67-72`. Only
  the storage variant diverges. Codex independently agrees.
- **Is `surfaces.pinned` a check that exists to be broken?** **No — but it is self-certified.**
  Within 008's own window it does real work (it stops the implementer touching the one file that
  carries the central claim), and the re-pin protocol in §1.3 — a printed digest copied into a
  one-line diff in the same commit that changes the contract — is the right shape and keeps it
  from being a silent regeneration. Codex agrees. The defect is finding 6: 008's implementer
  creates the pin, so it must be a transcription of a value written in the spec, not a
  measurement of whatever the file happens to contain.
- **Are the "impossible in principle" claims consistent?** **The caveat is; the premise is not.**
  "Unreachable is not equivalent" (`:1554`, `:1606`) is exactly right and is the sentence that
  keeps R-3 honest. What it qualifies — that Δ is unreachable — is false for a prover who does
  not call the host function (finding 1). Fix the premise and the caveat becomes load-bearing
  instead of decorative.

---

## What must change before round 3

**BLOCKER — implementation must not start until these land:**

1. **Move G-2 into the guest as P-12**, relabel G-1/G-3 as host-side hygiene, add vector W-09
   (hand-built `GuestInput` bypass), and rewrite the three "unreachable" sentences at `:640`,
   `:1552-1554` and — most importantly — `:1607-1610`, which ships into
   `zk-verdict/README.md`'s honest scope. (finding 1)
2. **Add mutant M-5 (erase the `GuestEnv` application → AC-03).** Add M-6 / M-7 if they fit.
   Add the script-row mutants M-8…M-12 from finding 4 — four of them need no compilation.
   Restate AC-13's evidence line and re-price its 20-minute stop rule for the new count, keeping
   the stop. (findings 2, 4)

**MAJOR — same round, but they do not block on their own:**

3. Resolve G-3: either take `predicate: &PredicateV1` and add a W-10 vector, or delete the
   variant and state D's first clause as enforced by the type. (finding 3)
4. Rewrite AC-7a's `state_root` component to vary the prestate consistently, and require the
   baseline witness to contain both values for the five address/slot components. (finding 5)
5. Write both `surfaces.pinned` digests into AC-0b as literals
   (`07d649c2…33e45b`, `b4fd62d5…b29d1`) and name the prefix rule as `head -710`, exclusive.
   (finding 6)
6. Restate D's Δ clause as the syntactic condition the gate tests, so INV-2's *iff* stops being
   false for a witnessed-but-unentered Δ address. (Founder question 1 above.)
7. Add a Groth16 regeneration budget and stop rule to §7.5, and state in §7.2 that the four
   fixtures are regenerated **once**, after the Rust reaches APPROVE. (Founder uncertainty 1.)

**MINOR:**

8. Fix AC-2's V-10 `guest today` cell (the guest agrees today) and state one convention for
   `min`/`max` values `u64` cannot represent. (finding 7)
9. Add `zk-verdict/README.md:105-108` ("stays gated on the fixture's presence") to AC-14(i) and a
   replacement to AC-14(ii). (finding 8)

**Not a spec change, but the founder decision that matters most:** measure one Groth16
regeneration on the current guest **today**. That single number, not the test count, decides
whether 008 closes by 9/9.

**On the trajectory:** round 2 is a large, honest improvement. Both r1 BLOCKERs are genuinely
answered at the mechanism level, thirteen of the fifteen r1 findings are closed outright, and one
of them (the empty account proof) is closed by **correcting the reviewer**, with the source to
back it. The two BLOCKERs above are both of the same species — an enforcement placed one layer
outside where the adversary is, and a check whose coverage is narrower than the claim it
certifies — and both are cheap. `AGENTS.md` §2 says five rounds of `CHANGES` is normal; this is
round 2, and the document is converging, not thrashing.

VERDICT: CHANGES

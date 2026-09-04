# Review 008 spec round 3

Payload: `/tmp/reckn-payload-008-spec-r3.md`
Codex raw: `/tmp/reckn-codex-008-spec-r3.md`
Subject: `docs/specs/008-verdict-domain-soundness.md` (**2334 lines**), drafted by
`reckn-spec` (**Claude Code**). Codex did **not** write it, so author independence is
satisfied and Codex was used as a full adversarial reviewer, not only for a second opinion.
One Codex invocation, `-s read-only`, prompt passed as an argument with `< /dev/null`.

Everything below was re-checked against the files on disk on **2026-09-04**. No number from
r1 or r2 is carried over.

---

## What I verified myself before judging any finding

Re-measured, all reproduce exactly as the spec states:

| spec claim | measured today | result |
|---|---|---|
| `sha256(RecknZkEscrow.sol)` = `07d649c2…33e45b` | `shasum -a 256` → identical | ✓ |
| `sha256(head -710 reexec-evm/src/lib.rs)` = `b4fd62d5…b29d1` | identical | ✓ |
| line 711 is `#[cfg(any(test, feature = "testkit"))]`, sole occurrence | `grep -n` → one hit, line 711 | ✓ |
| 12 pre-existing forge tests | `grep -n "function test" …/test/*.t.sol \| wc -l` → 12 | ✓ |
| 7 `if (!vm.exists(` early-return gates in 4 files | 2/2/2/1, and all 7 `vm.exists` are that pattern | ✓ |
| `reexec-evm` = 16 tests (10 `lib.rs` + 6 `header.rs`) | `grep -c '#\[test\]'` → 10, 6 | ✓ |
| AC-14(i) 8 stale literals all present today | 8/8 matched | ✓ |
| AC-14(ii) marker 6 already present at `README.md:572` | present | ✓ |
| AC-14(iii) tilde regex finds **14**, the naive `~[0-9]` finds **12** | 14 / 12 | ✓ |
| fixtures live in `zk-verdict/contracts/src/fixtures/` (3 committed) | ✓ | ✓ |
| revm 38 default features = `{std, secp256k1, portable, tracer, c-kzg, blst}` | `revm-38.0.0/Cargo.toml` | ✓ |

**P-12's closure argument, checked independently of Codex.** All four call opcodes route through
one helper: `revm-interpreter-35.0.1/src/instructions/contract.rs:158` (CALL), `:203` (CALLCODE),
`:248` (DELEGATECALL), `:293` (STATICCALL) → `load_acc_and_calc_gas`
(`instructions/contract/call_helpers.rs`) → `load_account_delegated` → journal →
`db.basic(address)?` at `revm-context-16.0.1/src/journal/inner.rs:927`, which runs before
`precompiles.run`. So a Δ address reached by **any** route — a callee computed at run time, a
nested internal call, `DELEGATECALL`, a Δ address used as `check.address`, as `plan.caller`, or
as `coinbase` — must either be **in the witness** (P-12 panics) or **not** (both sides fail on
the closed database). The syntactic check is therefore sufficient; it does not need to trace
execution. **This is sound and round 4 should not re-open it.**

**Δ's completeness, derived independently.** Guest = `revm { default-features = false }`,
off-chain = defaults + `optional_no_base_fee`. The delta is exactly the six default features.
`bn` and `gmp` are **not** default, so bn128 (`0x06`–`0x08`) and modexp (`0x05`) use the same
`ark-bn254` / `aurora-engine-modexp` on both sides. `portable` only re-flags `c-kzg`/`blst`.
So the backend-differing set is `0x01` (secp256k1 vs k256), `0x0a` (c-kzg vs arkworks),
`0x0b`–`0x11` (blst vs arkworks) = **the 9 addresses the spec names. Δ is complete.**

---

## Findings

1. **[BLOCKER]** `docs/specs/008-verdict-domain-soundness.md:114-118`, `:1163-1165`,
   `:1653`, `:1677`, `:1918`, `:2306-2325` — **M-8 is still specified as an in-place edit of
   `RecknZkEscrow.sol`, which the founder has now ruled against.** The document prices three
   options in OQ-5 and recommends (a) "allow it"; the founder ruled a fourth design (sandbox),
   so the spec as written instructs the implementer to do the one thing `AGENTS.md` §0 exists to
   prevent, and `:114` ("Not one byte **in any committed state**") is written around that
   exception. An implementer following this document faithfully edits §0's file.

   The replacement is not a wording change; it has four load-bearing requirements the spec does
   **not** currently contain, and one of them the spec cannot express today because
   `surfaces.sh` is unspecified in this respect (`:164`, `:965`, `:1115`, `:1144`, `:2273` are
   every mention of it — none says how it locates its targets):

   1. **`surfaces.sh` must derive the repository root from its own location** — the shape
      `scripts/no-keys.sh:17-19` already uses (`here=$(cd "$(dirname "$0")" && pwd);
      root=$(cd "$here/.." && pwd)`) — with **no** root argument, **no** environment override
      and **no** absolute-path fallback. If it burns a path, the sandbox is inert.
   2. **The sandbox must contain both of AC-0b's clauses' inputs**: `zk-verdict/scripts/surfaces.sh`,
      `zk-verdict/scripts/surfaces.pinned`, `zk-verdict/contracts/src/RecknZkEscrow.sol`
      **and `reexec-evm/src/lib.rs`** (AC-0b's second clause is `head -710 reexec-evm/src/lib.rs`
      plus two assertions about line 711). Omitting the fourth file makes the clean control fail.
   3. **A clean-copy control must run *before* the mutation**: unmutated sandbox → the script
      must exit **0**; mutated sandbox → non-zero. Without the control, a degenerate script that
      fails inside the sandbox for the *wrong* reason (a file the sandbox did not copy, a
      hard-coded `/Users/…` path that does not exist under `$S`) is scored as "mutant detected".
      This is the one construction that defeats the sandbox, and Codex and I found it
      independently.
   4. **Restore becomes `rm -rf "$S"`, and no repository file is touched at all**, so N-1
      returns to literal truth. `:1653` ("Step 6 exists because M-8 and M-15 mutate Solidity")
      and `:1918` (§7.3 row 1) must be restated — after the change only **M-15** mutates
      in-tree Solidity, and step 6 stays for M-15.

   Repro of the defect the sandbox must keep catching (this is what makes (a)/(b) inadequate and
   the sandbox adequate): a `surfaces.sh` that prints the two pinned literals from a heredoc and
   the correct `witness=` value, and never reads either file, passes AC-00b, passes `ac008.sh
   --all`, and passes a `surfaces.pinned` mutant — and stops guarding the central claim. Under
   the sandbox it exits 0 on the mutated copy, so AC-13 records a miss and fails.

   Priority: **highest**. Until it is rewritten the implementer has an instruction that violates
   `AGENTS.md` §0.

2. **[MAJOR]** `docs/specs/008-verdict-domain-soundness.md:815-818` (INV-14), `:1044`
   (AC-13's witness recipe), `:1059`, `:1081` (the AC-13 exemption) — **AC-13's own manifest row
   is satisfiable by `echo`, and the document says it is not.**

   AC-13's witness set is *"the sixteen `mutants/*.patch` files"*. **No mutant modifies a patch
   file** — every one of M-1…M-16 modifies source, a fixture, a test or a document. So AC-13's
   `witness=` value is a **constant** across the entire run, and the three substitutes the
   exemption at `:1081` offers are all defeated by the same stub:

   - a two-line `ac008-selftest.sh` that prints
     `ac008-selftest: 16/16 mutants detected; witness=<the constant>` and exits 0 satisfies the
     row completely;
   - **step 0** (the patch count must be 16) and **step 6** (re-run AC-00b and `no-keys.sh`) are
     *inside the stubbed script*, so they never execute; and even read as belonging to `ac008.sh`
     (which `:1081` says), both are satisfied without applying a single mutant;
   - the AC-13 `witness` is exactly the value a stub hard-codes, because nothing ever moves it.

   Consequences: (i) **INV-14 is false as written** — it excepts only AC-00, and AC-13 is a
   second exception; (ii) `:1059`'s *"All three paths end in a failure the implementer cannot
   remove by writing a constant"* does not hold for the row that carries **all** the mutation
   weight; (iii) `:1081`'s "its guard is different in kind" names three things, none of which is
   a guard against this.

   Repro after implementation: replace `zk-verdict/scripts/ac008-selftest.sh` with
   `#!/usr/bin/env bash` + one `echo` of the evidence line carrying the current patch-set
   witness; make every `test_AC*` body `assert!(true);`; `bash zk-verdict/scripts/ac008.sh --all`
   still prints `ac008: 18/18 rows passed`. That is r1 BLOCKER 1 and r2 finding 4 recurring at
   the top of the trust chain.

   **What r4 must do — and what it honestly cannot.** The regress does not terminate inside the
   repository: whatever runs last is trusted. So the requirement is not "close it" but:
   (a) fix INV-14's quantifier and delete the false sentence at `:1059` for this row;
   (b) rewrite **L-3** (`:2067`) to say plainly *AC-13's row is `echo`-satisfiable; the mutation
   gate's integrity rests on the implementation review reading `ac008-selftest.sh` and running
   it, not on a mechanism*; and (c) add the one cheap thing that actually raises the bar:
   **`ac008.sh --all` itself applies one designated zero-build canary mutant** (M-9 is the
   natural choice — no compilation, `grep`-only target row) and requires AC-06 to exit non-zero
   before it may print `18/18`. That moves the single point of failure from a small
   special-purpose script onto the runner every other row already depends on, and costs seconds.
   It does not close the regress and r4 must not claim it does.

3. **[MAJOR]** `docs/specs/008-verdict-domain-soundness.md:2306-2325` — **OQ-5's option set was
   incomplete, in the direction that flattered its own recommendation.** The founder asked
   whether the three-way pricing was right. It was not, in one specific way: the three options
   offered were *violate §0* (a), *weaken the test* (b), *delete the test* (c) — an enumeration
   in which only the §0 violation is strong, so the recommendation follows from the enumeration
   rather than from the problem. Two options were missing, and **both** avoid touching §0's file:
   the founder's sandbox, and the weaker fallback of pointing M-8 at AC-0b's **second** clause
   (a comment byte above line 711 of `reexec-evm/src/lib.rs`), which tests "the script computes a
   digest from a real file" without touching the contract at all.

   On the parts of the pricing that were right: **(b)'s rejection is correct, and the founder's
   reason is the sharper one.** Mutating `surfaces.pinned` makes *every* implementation fail —
   including one that digests the wrong file, or hashes only part of the contract — so it tests
   the comparison, not the binding between the digest and `RecknZkEscrow.sol`, which is the
   property AC-0b exists for. **(c)'s pricing is correct**: with no mutant on AC-00b, nothing
   moves a byte in its witness set, so the row returns to `echo`-satisfiable — for the one row
   that guards §0's file.

   One risk under (a) that the pricing did not carry, recorded because it supports the ruling: a
   `trap` catches `EXIT INT TERM` but **not `SIGKILL`, a panic of the host, or a power loss**. A
   hard kill between `patch` and `restore` leaves a mutated `RecknZkEscrow.sol` in the work tree,
   and `scripts/no-keys.sh` — which is comment-blind by design (`no-keys.sh:28-30` strips
   comments before every check) — would **not** notice it at the next commit. The sandbox removes
   this failure mode entirely rather than mitigating it.

   This finding is closed by the same rewrite as finding 1; it is recorded separately because the
   *enumeration habit* is the thing to watch. It is the same shape as r1 finding 12 ("the (b)
   cost enumeration is incomplete in the flattering direction"), now recurring in §10.

4. **[MINOR]** `docs/specs/008-verdict-domain-soundness.md:2178-2179` (the honest-scope text),
   and its sources at `:136` and `:2123` — the sentence shipped into `zk-verdict/README.md`
   reads *"an anchor that carries a header is refused rather than silently stripped."* Against a
   hostile prover that is a statement about the honest host tool only: the prover starts from an
   anchor **with** a header, builds the `GuestInput` by struct literal (`zk-verdict/script/src/bin/reexec.rs:123`,
   written to stdin at `:166`), and produces bytes indistinguishable from `block_header = None`.
   Nothing is refused; nothing is gained either. The G-1 **argument** is sound (finding
   confirmed sound below) — the defect is only that a host-side property is stated unqualified in
   the product's guarantee list, which is the r2 BLOCKER's species one notch smaller.

   Fix: *"the typed host conversion refuses an anchor that carries a header; a raw `GuestInput`
   has no header field to carry, so the guest neither sees nor checks one — the
   `state_root`↔header binding stays off-chain."* One sentence, §9(1).

5. **[MINOR]** `docs/specs/008-verdict-domain-soundness.md:536` — *"`0x02`–`0x09` and `0x100`
   run **byte-identical code** on both sides"* is false as written, though the **conclusion**
   (Δ = 9 addresses) is right. `default-features = false` also drops `std`, which
   `revm-precompile-34.0.0/Cargo.toml` propagates to `k256`, `ripemd`, `sha2`, `ark-bn254`,
   `ark-bls12-381`, `aurora-engine-modexp` and `p256`; and
   `revm-precompile-34.0.0/src/blake2.rs:135` and `:201` select an **alternate AVX2
   implementation** of `0x09` under `#[cfg(all(target_feature = "avx2", feature = "std"))]`.
   The two builds therefore do not run identical code for those addresses; they run the **same
   implementation crate**, whose outputs are identical by construction. Say that instead —
   the whole document's credibility rests on not overstating this kind of claim.

6. **[MINOR]** `docs/specs/008-verdict-domain-soundness.md:1043` vs `:1880` — AC-11's witness
   recipe is *"the **five** `zk-verdict/contracts/test/*.t.sol` files"*, but §7.1 adds a sixth
   (`RecknVerdictDomain.t.sol`), so after 008 the glob yields six. Either write the recipe as
   "every `*.t.sol` in that directory (six after 008)" or the implementer will hard-code five
   names and silently leave the new file outside the witness set. No soundness impact (M-11
   mutates one of the original five); it is a count that goes stale on the same commit that
   introduces it.

7. **[MINOR]** `docs/specs/008-verdict-domain-soundness.md:1141-1155` — AC-0b's prefix range
   `1..=710` **includes the testkit module's own doc comment** (`reexec-evm/src/lib.rs:708-710`,
   verified), and the uniqueness assertion forbids a **second**
   `#[cfg(any(test, feature = "testkit"))]` anywhere in the file. Both are edits N-3 explicitly
   permits ("008 may add testkit builders freely"), and both would fail AC-0b for a
   non-violation. The failures are loud, not silent, so this is a usability trap rather than a
   hole — one sentence in AC-0b ("builders go **inside** the existing block, below line 711, and
   the block's doc comment is inside the pinned prefix") removes it.

---

## Verified sound — round 4 must not re-open these

- **P-12 closes G-2's soundness half** (evidence above: the four call opcodes share one account-
  loading path; a runtime-computed callee cannot evade it). The move from a dynamic condition
  ("the execution enters Δ") to a syntactic one ("a Δ address is in `accounts` or is
  `plan.target`") is what makes it checkable in the guest, and the complementary unwitnessed case
  is closed by the closed database on both sides.
- **Δ is complete at 9 addresses** for the actual feature delta (derived above from
  `revm-38.0.0/Cargo.toml` and `revm-precompile-34.0.0/Cargo.toml`; `bn` and `gmp` are not
  default, so `0x05`–`0x08` do not differ).
- **G-3's relabel and remedy (a) are correct.** `GuestInput` carries exactly one `DeltaCheck`,
  so a second check is unrepresentable and a bypassing prover produces a single-check input by
  construction; and taking `predicate: &PredicateV1` and extracting inside the gate is the only
  version in which the variant has a body. Rejecting (b) on the grounds that a check at the call
  site does not constrain the operand (003's R-8) is right.
- **The `head -710` rule is sound.** A line inserted above 711 moves the `#[cfg]` marker and the
  assertion fails loudly; an insert-plus-delete changes the digest; edits below 711 do not move
  it. The ambiguity r2 found is genuinely converted into a failure rather than a wrong answer.
- **AC-7a's restatement is correct**, and the `state_root` recipe still isolates it: a second
  internally consistent prestate leaves `env_hash`, `check_hash` and `plan_hash` unchanged, and
  those are the only other inputs to the binding (§3.5). The six constrained components are the
  right six — each is an address or slot the guest must be able to read, and the twelve others
  are genuinely unconstrained under `disable_base_fee` / `disable_nonce_check`.
- **§7.5's treatment complies with `AGENTS.md` §5.** One measurement (`335.02 s`,
  `nbConstraints = 15,972,262`), four itemised phases summing to 47.00 s, the remaining ~288 s
  **named as an inference, not a measurement**; `program-svm`, the predicate guest, cold builds
  and the post-008 guest **named as unmeasured**; `4 × 335.02 s ≈ 22 min` **labelled an
  extrapolation**. The `R = 3` stop can fire and is not a phantom. The budget is not flattering:
  `B = 30 min` against a 22 min extrapolation whose one identified downside risk (the SVM guest
  at ~980k cycles) is named in the unflattering direction. The **only** correction: the
  conclusion *"this is not the 9/9 blocker"* should be marked as **conditional on the post-008
  and SVM numbers**, since both are unmeasured and both move in the same direction.
- **The V-10 correction moved in the unflattering direction** (7 disagreements, not 8) and is
  recorded as such. That is the discipline `AGENTS.md` §5 asks for, applied against the task's
  own interest.
- **§7.6's separation from §8 is honest**, not a hiding place: L-1…L-4 are limits of *this
  document's gate* and §8's R-1…R-9 are limits of *the product*, and every §8 residual is
  scheduled verbatim into the shipped honest scope. Finding 2 is not an argument against the
  separation — it is that **L-3 understates**, and the fix belongs in L-3.

## Rejected findings

- **Codex finding 1 rated BLOCKER — accepted as substance, downgraded to MAJOR.** Evidence for
  the substance: verified above (no mutant touches `mutants/*.patch`; INV-14 at `:815` excepts
  only AC-00). Evidence for the downgrade: the defect does **not** misdirect the implementation
  — an implementer building `ac008-selftest.sh` as specified builds a real one, and the
  16 mutants, their target rows and the run order are all correct. What is wrong is a **claim in
  the document** that the row is not `echo`-satisfiable, plus a false quantifier in INV-14. r1's
  and r2's versions of this species were rated BLOCKER because they left a hole the implementer
  could walk through unnoticed; this one is the terminal trust root, which **no mechanism inside
  the repository can close** — so the honest remedy is to say so, not to add a fourth ceremony.
  It stays MAJOR and second in the r4 order.
- **No Codex finding was rejected outright.** All three reproduce.
- I looked for and did **not** find: a Δ-evading path through `DELEGATECALL`/`STATICCALL` or a
  runtime-computed callee (rejected with `contract.rs:158,203,248,293` → `db.basic` at
  `journal/inner.rs:927`); a missing Δ member (rejected with the feature derivation above); a
  tier violation in §7.5 (rejected — every unmeasured quantity is named as unmeasured); an
  AC that a constant-returning implementation survives (AC-2's mixed polarity 9/5, AC-3's
  E-02/E-08/E-11/E-12 positive controls, and AC-4's `Ok` controls inside W-03/W-08/W-09/W-10/W-11
  each refuse one).

## Deferred

- None. Every finding above is inside 008's scope and is closed by an edit to this spec.

---

## Answers to the founder's questions

**Least-confident point 1 — is P-12 closed?** **Yes**, and for a reason stronger than the
document argues: the closure does not depend on enumerating call shapes at all. Every account
touch in revm goes through one `db.basic`, so with the witness-closed database the input's
**account set** is a superset of every address the execution can reach. A syntactic check on
that set is therefore equivalent to a dynamic one. The residual is not soundness but the
wording at `:536` (finding 5).

**Least-confident point 2 — is the witness/mutant split right?** The split is **correctly
described for the seven other `script` rows** — I checked each one's witness set against the
mutant table and every row has a mutant that moves a byte inside its own witness set
(AC-00b/M-8, AC-06/M-9, AC-09/M-10, AC-11/M-11, AC-14/M-12, AC-16/M-16). It is **wrong for AC-13
itself**, which is the row all the weight rests on (finding 2). And to the sharper form of the
question — *is the honest limit statement being used to license an unclosed hole?* — **for L-2,
no**: L-2 is about builds, and AC-14(iv)'s `elf_sha256` equality plus the `SP1_*` unset are
real guards that are correctly labelled guards. **For L-3, yes**: it names three substitutes and
lets the reader infer they close the gap; none of them does.

**OQ-5 — was the three-way pricing right?** No; see finding 3. (b) is rightly rejected and the
founder's reason is sharper than the spec's; (c) is priced correctly; **(a) should not have been
the recommendation** because the enumeration that produced it omitted both options that avoid
§0 entirely. The sandbox is strictly better than all three: it has (a)'s detection strength,
does not need §0's exception, N-1 becomes literally true, and `003` has already measured that
the technique works on `no-keys.sh`. **The three checks the founder asked for are finding 1's
requirements 1–3, and the answer to "which other mutants should be sandboxed" is: none.** M-15
touches `RecknVerdictVerifier.sol`, which is not the file `AGENTS.md` §0 is about and which
`no-keys.sh` does not read; M-10/M-11/M-12/M-13/M-16 touch fixtures, tests, a README and the
testkit; M-1…M-7 and M-9 touch guest source with heavy build trees where a sandbox would cost a
cold RISC-V build for no §0 benefit.

---

## What round 4 must do, in priority order for 9/9

**BLOCKER (must be in r4):**

1. Rewrite M-8 as the founder's sandbox, with requirements 1–4 of finding 1 written into the
   spec — including the **`surfaces.sh` location-derivation rule** and the **clean-copy control
   before the mutation**. Sections to touch: `:114-118` (N-1's exception disappears),
   AC-0b's Falsify (`:1163-1165`), the M-8 row (`:1677`), step 6's rationale (`:1653`),
   §7.3 row 1 (`:1918`), and OQ-5 (`:2306-2325`) → recorded as **ruled**, not open.

**MAJOR:**

2. Finding 2 (a)(b)(c): fix INV-14's quantifier, delete the false sentence at `:1059` for AC-13,
   rewrite L-3 to state the residual plainly, and add the M-9 canary to `ac008.sh --all`.
3. Finding 3: fold the corrected pricing into the rewritten OQ-5 so the record shows why (a) was
   not taken.

**MINOR (one line each, all mechanical):**

4. `:2178-2179` — qualify the G-1 sentence in the shipped honest scope.
5. `:536` — "the same implementation crate", not "byte-identical code".
6. `:1043` — AC-11's witness set is every `*.t.sol` in the directory (six after 008).
7. `:1141-1155` — one sentence: builders go inside the existing testkit block; its doc comment is
   inside the pinned prefix.
8. `:2044-2052` — mark "this is not the 9/9 blocker" conditional on the post-008 and SVM
   regeneration numbers.

**Why this is not a reset.** None of the eight items changes the fix (§3), the vectors (AC-1…
AC-12), the manifest arithmetic (18 rows / 91 cargo / 6 forge / 16 mutants), the invariants other
than INV-14's quantifier, or the guest freeze rule. Item 1 is a rewrite of one mutant's
mechanism, item 2 is ~15 lines of truth-telling plus one canary, and items 4–8 are single
sentences. **r4 should be a single narrow pass, and the review of it should be scoped to these
eight items plus whatever they touch.** The soundness core of 008 — the U256 widening, the
environment binding, the closed database, P-5…P-12, D and the domain gate — is, on this reading,
implementation-ready.

**Why round 4 is nevertheless required rather than APPROVE-with-conditions.** Item 1 is not a
documentation defect: as written the spec instructs an agent to modify the one file
`AGENTS.md` §0 says must not move, against a founder ruling that already exists. There is no
reading of §0 under which an implementer may start from that instruction.

VERDICT: CHANGES

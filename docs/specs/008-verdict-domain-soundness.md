# 008 — verdict domain soundness

Status: spec, **round 5**. Owner: `reckn-spec`. Implementer: `reckn-codex-impl`.
Tier: **local machine only** — `cargo test`, `forge test`, SP1 `execute`, and SP1 CPU Groth16
for the four committed fixtures. **No anvil, no testnet, no mainnet, no network calls.**
Nothing in this document claims anything about a deployed chain.

Every fact cited below was re-checked against the files on disk on **2026-09-04**, after
`docs/reviews/008-spec-r4.md`. Numbers from earlier rounds are **not** carried over; where an
earlier number was wrong, the correction is named. **Round 5's own new measurements**, all taken
today and reproducible with the commands beside them: `RecknVerdictVerifier.sol`'s stripped
identifier vocabulary (**43 tokens**, §6.4 5b), its assignment count (**5**, §6.4 5e), its
semicolon count (**17** whole file, **2** in `verifyVerdict`'s body, §6.4 5c/5d), its zero `/*`
and `*/` occurrences (§6.4 5a), the four file sizes in AC-13's cost model, and the four
**zero-match** greps behind AC-14's new literal and markers 8–11. The token-set delta of the r4
splice (**5 tokens added**) and of the deleted `verifyProof` call (**1 token removed**) were both
computed, not reasoned about.

**Round-5 summary for the reviewer — one structural change, eight local ones.** Nine r4
findings, all answered (§0.1). **§3, §4, §5.1, AC-1…AC-12, AC-15, the test plan, the 91 cargo /
6 forge arithmetic and the guest freeze rule do not move.** Three things changed, and only the
first is structural:

1. **`RecknVerdictVerifier.sol` enters the checked region, and 008 is the task that puts it
   there** (r4 BLOCKER, orchestrator ruling 2026-09-04). That file is on the settlement-authority
   path — `RecknZkEscrow.sol:99` calls `verifyVerdict` and obeys the struct it returns — **008
   edits it** (§3.4 widens `VerdictPublicValues`), and through round 4 **nothing in this document
   looked at it**: `scripts/no-keys.sh:19` reads one file, AC-0b pins two others, §7.1's file
   table omitted it, and M-15 only swaps two constants. A spliced
   `if (tx.origin == 0x…1337) { v.outcome = REPRODUCED; v.dealBinding = …; return v; }` never
   reaches `verifyProof`, passes the binding check at `RecknZkEscrow.sol:103`, pays the seller at
   `:109-110`, and **every round-4 acceptance criterion stays green**. `scripts/no-keys.sh` gains
   **check 5** over that file (AC-0), stated as **five closure properties and not as a list of
   forbidden constructs** (§6.4), and the claim it enforces is widened in the same commit
   (`AGENTS.md` §0, `CLAUDE.md`, §9(2a)–(2c), INV-15, OQ-6 — **ruled, not open**). Two new
   sandbox mutants, **M-17** and **M-18**, take the mutant count to **18**; AC-00 becomes a
   mutated row and the exempt set shrinks to two.
2. **The two half-degenerate scripts the r4 review constructed are killed** (r4 finding 2).
   Step **8g** now requires the sandboxed `surfaces.sh` to print `computed: <64 hex>` and requires
   it to equal the selftest's **own** digest of the mutated copy — a `grep -q` for a named comment
   cannot produce that value. A **second sandbox phase (M-18)** mutates the copy of
   `reexec-evm/src/lib.rs` **above line 711**, so AC-0b's second clause — the clause protecting
   `reexec-evm::replay`, which is the **oracle INV-1 compares the guest against** — finally has a
   mutant.
3. **The trust root the document names is now assigned to someone** (r4 finding 3). L-3 said the
   mutation gate rests on the implementation review reading and running two scripts; nothing
   obliged any reviewer to. **§7.8** binds `reckn-codex-review(stage=impl)` by name, requires it to
   run both scripts itself rather than accept pasted output, and states that **a report-only
   acceptance of AC-13 is not an acceptance**.

Round 4 changed three things, kept below so a reader of one round has the whole chain:

1. **M-8 is now a sandbox mutant** (§10, OQ-5 — **ruled**, not open). It never touches
   `RecknZkEscrow.sol`; it reconstructs the layout in a temp directory, runs a **clean-copy
   control** there first, mutates the *copy*, requires the copied `surfaces.sh` to fail, and
   restores with `rm -rf`. `AGENTS.md` §0 needs no exception and **N-1 is literally true again**.
   The rule that makes it work — `surfaces.sh` derives its targets from its own location and from
   nothing else — is now a written requirement of AC-0b (§6, AC-0b, "Location rule").
2. **AC-13's own manifest row is admitted to be `echo`-satisfiable.** No mutant modifies a
   `mutants/*.patch` file, so AC-13's `witness=` is a constant for the whole run and INV-14's
   quantifier was false. INV-14 now names the exception, the false sentence in §6.2 is scoped,
   **L-3 states the residual plainly**, and `ac008.sh --all` gains **one zero-build canary**
   (§6.3) that it applies itself. The canary raises the cost; it does **not** close the regress,
   and this document does not claim it does.
3. **OQ-5's option set is recorded as having been incomplete in the flattering direction** —
   the three options offered were "violate §0 / weaken the test / delete the test", an enumeration
   in which only the §0 violation was strong. Two §0-preserving options were missing. The record
   is kept because the *enumeration habit* is the defect, not the conclusion.

Round 3 changed three things, kept for the same reason:

1. **The Δ gate moved into the guest.** Round 2 put G-1/G-2/G-3 in `to_guest_input`, a **host**
   function, while §3.2(c)(1) of the same document says the prover is the adversary and there is
   no sanitiser between them and the guest. `zk-verdict/script/src/bin/reexec.rs:123` builds a
   `GuestInput` by struct literal and `:166` writes it to the ELF's stdin, so the gate was simply
   skippable. G-2 — the only one of the three with soundness weight — is now **P-12, an in-guest
   panic**, with G-2 kept as an early host-side refusal; G-1 and G-3 are relabelled as what they
   are. The three sentences claiming "Δ is unreachable", including the one scheduled into
   `zk-verdict/README.md`'s honest scope, are rewritten (§9(1)).
2. **The mutation gate went from 4 mutants over 16 criteria to 16 mutants over 15 rows**, and
   every `script` row now has one. Round 2's four mutants left AC-3 — the whole of axis 2 —
   unguarded, and left eight `script` rows verifiable by `echo`. §6.2 states which of the two new
   mechanisms actually carries the weight, and which is defence in depth.
3. **The Groth16 regeneration is measured, not estimated.** One fixture on the current
   re-execution guest is **`real 335.02 s`** (measured 2026-09-04, §7.5). `zk-verdict/README.md:97`'s
   "~34 s" turns out to be the **gnark wrap alone** (31.71 s here), not an end-to-end figure.
   §7.5 now carries a budget, a stop rule, and the ordering constraint that actually controls the
   cost — the number of regeneration **rounds**, not the time per round.

AC-4 grows from 8 vectors to 13, because the same audit that found P-12 missing found that four
other new `NoProof` transitions had no vector either. The manifest arithmetic moves with it.
**Round 4 changes none of that.**

---

## 0. Review findings — where each one landed

### 0.1 Round-4 findings (9: BLOCKER 1 / MAJOR 3 / MINOR 5)

| # | sev | finding | round-5 response | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | `zk-verdict/contracts/src/RecknVerdictVerifier.sol` is on the settlement-authority path, **008 must edit it** (§3.4), and no 008 criterion guards it. `no-keys.sh:19` reads one file; AC-0b pins two others; §7.1's table omits it; M-15 only swaps two constants. A `tx.origin` branch spliced into `verifyVerdict` returns a chosen outcome without ever calling `verifyProof`, and **every round-4 AC stays green while `no-keys.sh` exits 0**. `:1842` stated the fact — that `no-keys.sh` does not read the file — and drew the opposite conclusion from it | **Adopted, and 008 owns it** (orchestrator ruling 2026-09-04: 008 is the commit that opens the file, so a check introduced by a later task leaves the region open for two whole tasks). `scripts/no-keys.sh` gains **check 5** over that file. **Interface unchanged** — no argument, no environment variable; the script derives the second path from its own location exactly as `:17-19` already derives the first. **Closed by five properties, not by a denylist** (§6.4, and 003's **R-7**): a pinned import-only string region, a **closed identifier vocabulary** (43 tokens, transcribed into this spec), a closed declaration set, a two-statement `verifyVerdict` body pinned by form, and a closed assignment-target set. `tx.origin`, `msg.sender`, `block.*`, `if`, `for`, `while`, `assembly`, `delegatecall` and every unlisted sibling fail **together**, and none of them is named as forbidden. New sandbox mutant **M-17**; new invariant **INV-15**; AC-00 becomes a mutated row; the claim's widening is declared in the same commit (§9(2a)–(2c)) and recorded as **OQ-6, ruled**. The sentence at `:1842` is rewritten. | **§6.4 (new)**, AC-0, INV-15, N-7, N-12, INV-8, §1.3, AC-13 (M-17, mode paragraph), §6.2, §7.1, §7.3, §7.6 L-5, §8 R-10, §9(2a)–(2c), §10 OQ-6 |
| 2 | **MAJOR** | AC-00b is satisfiable by a `surfaces.sh` that never runs `shasum` and never opens `surfaces.pinned` — a `grep -q` for the exact comment M-8 flips passes 8d, fails 8g, and is scored as a detection (**r2 finding 6 re-opened**). And **AC-0b's second clause has no mutant at all**: M-16 is deliberately below line 711, so nothing tests that the `head -710` prefix — the guard on `reexec-evm::replay`, **the oracle INV-1 compares the guest against** — is enforced | Adopted in all three parts. **(i)** Step **8g** requires the sandboxed script to print `computed: <64 hex>` for the failing clause and requires it to equal the **selftest's own** `shasum` of the mutated copy; a `grep` cannot produce that value, so the half-degenerate script is a **miss** and AC-13 fails. **(ii)** New mutant **M-18**, a second sandbox phase mutating `$S/reexec-evm/src/lib.rs` **above line 711**, with its own clean control and its own `computed:` assertion. **(iii)** *"`surfaces.sh` reads `$root/zk-verdict/scripts/surfaces.pinned` and compares against it"* is written as **requirement R5 of the Location rule**, and — because the founder's OQ-5 ruling forbids a `surfaces.pinned` mutant and this round does not re-open it — it is named in **§7.8(d)** as a property **no mutant covers**, which the stage=impl review must verify by reading. Stated, not hidden. | AC-0b (8g, R5), AC-13 (M-18), INV-14, §7.3, §7.8 |
| 3 | **MAJOR** | L-3 names the implementation review as the mutation gate's sole remaining trust root and **installs no obligation on it**. §7.7 binds the implementer's *report*; nothing binds the reviewer; two `printf`s reproduce every evidence line §7.7 asks for | Adopted. **§7.8 is new** and binds `reckn-codex-review(stage=impl)` by name: read both harness scripts line by line, **run them itself** rather than accept pasted output, record the per-mutant lines **it observed from its own run** in `docs/reviews/008-impl-rN.md`, and verify by reading the four properties no mutant covers. **"A report-only acceptance of AC-13 is not an acceptance"** is in the spec, where implementer and reviewer both see it. | **§7.8 (new)**, §7.6 L-3, §7.7 |
| 4 | **MAJOR** | **INV-11 and §8's preamble are false**: R-7 (`min == 0` admits a no-op) appears in **no** shipped document — `grep` finds zero matches today and zero after 008 as specified — and R-8's disclosure is in the root `README.md`, not in §9's honest scope. AC-14(ii)'s seven markers detect neither | Adopted. §9(1) gains an **R-7 sentence**; AC-14(ii) gains it as **marker 8**; **INV-11 is restated to what AC-14 enforces**, naming R-8's actual site (`README.md:566-571`, untouched by §9(3)) instead of claiming §9 carries it; §8's preamble stops asserting "verbatim, all of them" and says which residual is disclosed where. The review's correction to OQ-4's framing is taken: `zk-verdict/README.md:143` is a statement about **that fixture** (whose floor is `min ≥ 1`), not a universal impossibility claim, so the shipped exposure is smaller than round 4 wrote — **the disclosure gap is unchanged**. | INV-11, §8 preamble, §8 R-7, §9(1), AC-14(ii), §10 OQ-4 |
| 5 | MINOR | INV-14's quantifier is false again, now for AC-00b: after round 4's rewrite M-8 mutates only the sandbox copy and step 8h asserts the four repository inputs are byte-identical, so AC-00b's `witness=` is a run-constant like AC-13's. Same species as r3 finding 2, reintroduced by its fix | Adopted. **INV-14 is restated with three named cases** instead of a quantifier plus two exceptions: (a) rows whose witness set a mutant moves at run time (five); (b) **the sandbox rows** — AC-00b, whose witness is deliberately a run-constant and whose guard is the **sandboxed script's own exit status** under M-8/M-18; and AC-00, which carries **no** `witness=` field and whose guard is M-17's sandbox; (c) **AC-13**, constant and unmutated (L-3). | INV-14, §6.2 |
| 6 | MINOR | §6.3's canary applies `09-restore-u64low.patch` **in-tree** under a `trap`, carrying the exact `SIGKILL` residue argument the same document uses to reject in-tree M-8, and does not say so | Adopted as the review scoped it — a missing sentence, not a new risk. §6.3 now states the residue (an **unused** `fn u64_low`, no semantic change), that it makes the very next `ac008.sh AC-06` fail **loudly** by construction, and that §7.7's clean-`git status` requirement covers it. | §6.3 |
| 7 | MINOR | OQ-2 is stale in both directions and both its cross-spec citations are wrong; 004 additionally computes `planHash` **without** `gas_limit`, which 008's AC-7a adds as a bound component | Adopted, and one more staleness found by reading 004 rather than the citation: 004's `planHash` at `004:369` omits `gas_limit`, and 004 carries a whole residual about that omission (`004:86`, `:1178`, `:1201-1204`, its §11) which 008 **resolves**, so 004 goes stale in three ways, not one. OQ-2 is restated as **answered for `003`, open only as a `004` dependency**. **Line citations into `003` are dropped rather than repaired** — `003` is being revised in parallel, a line number is not a citation, and this document must contain no literal whose truth depends on an unapproved spec. | §10 OQ-2, §1.3 |
| 8 | MINOR | AC-14(i)'s heading says "Seven" over an eight-row table; an implementer writing `docs-check.sh` from the heading writes seven and fails against the manifest's `8/8` | Adopted. The heading is a **count** now — and it moves again this round: **9 stale literals** (the ninth is `no-keys.sh`'s own scope comment, which check 5 falsifies) and **11 replacement markers**. Every count appears in exactly two places, the heading and the manifest evidence line, and both are written here. | AC-14(i), AC-14(ii), §6.1 |
| 9 | MINOR | `zk-verdict/README.md:97`'s "~34 s" survives 008 while §7.5 measures the same operation at 335.02 s — defensible read narrowly, read by everyone else as the cost of producing a proof, and in the flattering direction | Adopted with the coupling respected: **qualified in place, not deleted**, because a later task pins the number of occurrences of that string in that file. §9(1b) is the obligation, AC-14(ii) **marker 9** requires the qualification, and AC-14 gains a **fifth check** asserting **exactly one** `~34 s` occurrence in that file — so 008 enforces the coupling itself instead of relying on the other spec. | §9(1b), AC-14(ii), AC-14(v), §6.1 |

**Not re-litigated** (r3 and r4 verified these independently; round 5 changes nothing about them and
none of the nine responses above depends on re-opening one): **P-12**, **Δ = 9 addresses**, **G-3's
relabel and remedy (a)**, the **`head -710`** rule, **AC-7a**, **§7.5's tier discipline**, the
**sandbox skeleton** (control-before-mutation, four inputs, the Location rule, `rm -rf` restore),
and **N-1's literal truth**. The mutant count moves 16 → 18 and the exempt-row count 3 → 2; that is
new coverage, not a re-argument of §6.1's arithmetic, and §6.1 is recomputed in place.

### 0.2 Round-3 findings (7: BLOCKER 1 / MAJOR 2 / MINOR 4)

| # | sev | finding | round-4 response | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | M-8 is still specified as an **in-place edit of `RecknZkEscrow.sol`**, which the founder ruled against on 2026-09-04. The spec instructs the implementer to do the one thing `AGENTS.md` §0 exists to prevent, and four load-bearing requirements of the replacement are unwritten — one of them (`surfaces.sh`'s target location) not expressible in the document as it stands | **M-8 becomes a sandbox mutant** and the four requirements are written: (1) **AC-0b gains a "Location rule"** — `surfaces.sh` derives root from `$(dirname "$0")/../..`, with no argument, no environment override, no absolute-path fallback and **no `git rev-parse`** (which would escape the sandbox upward into the real repository); (2) the sandbox carries **all four** of AC-0b's inputs including `reexec-evm/src/lib.rs`; (3) a **clean-copy control runs before the mutation** and must exit 0, so a script that fails in the sandbox for the wrong reason is scored as a **harness failure**, not as "mutant detected"; (4) restore is `rm -rf "$S"` and **no repository file is touched at all**, so N-1 returns to literal truth. The `trap`/`SIGKILL` gap that (a) carried is recorded in OQ-5 as part of why it was not taken. | §1.2 N-1, §6 AC-0b, §6.2, AC-13 (M-8 procedure), §7.1, §7.3, §10 OQ-5 |
| 2 | **MAJOR** | **AC-13's own row is satisfiable by `echo`.** Its witness set is the sixteen `.patch` files and **no mutant modifies a patch file**, so the `witness=` value is constant across the run; step 0 and step 6 are inside the stubbed script. **INV-14 is false as written** (it excepts only AC-00) and §6.2's *"all three paths end in a failure the implementer cannot remove by writing a constant"* does not hold for the row carrying all the mutation weight | Adopted in the form the review specified, including its limit. **INV-14's quantifier fixed** (two named exceptions, AC-00 and AC-13, with the reason for each). **§6.2's sentence scoped** to the rows whose witness a mutant actually moves, with AC-13 named as the row it does not cover. **L-3 rewritten** to say plainly that AC-13's row is `echo`-satisfiable and that the mutation gate's integrity rests on the implementation review reading and running `ac008-selftest.sh`, not on a mechanism. **§6.3 adds one zero-build canary**: `ac008.sh --all` itself applies **M-9** and requires AC-06 to exit non-zero before it may print `18/18`. §6.2's AC-13 exemption cell is rewritten — the three things it named are not guards against a stub. **This does not close the regress and the document does not say it does.** | INV-14, §6.2, **§6.3 (new)**, AC-13, §7.2, §7.4, §7.6 L-3 |
| 3 | **MAJOR** | OQ-5's option set was **incomplete in the direction that flattered its own recommendation**: *violate §0* / *weaken the test* / *delete the test* is an enumeration in which only the §0 violation is strong, so the recommendation followed from the enumeration rather than from the problem. Two §0-preserving options were missing — the founder's sandbox, and pointing M-8 at AC-0b's **second** clause | Adopted, and recorded as a **record of the enumeration habit**, not only of the conclusion. OQ-5 is rewritten as **RULED** and now lists **five** options with the two that were missing named as missing. The parts of the r3 pricing that were right are kept and attributed: **(b)'s rejection is correct and the founder's reason is sharper** (mutating the pin makes *every* implementation fail, including one that digests the wrong file, so it tests the comparison and not the binding); **(c)'s pricing is correct**. One risk (a) never carried is added: `trap` does not catch `SIGKILL`, and `no-keys.sh` is comment-blind by design (`scripts/no-keys.sh:28-30`), so a hard kill between `patch` and `restore` leaves a mutated contract that the pre-commit check cannot see. | §10 OQ-5 |
| 4 | MINOR | the shipped honest-scope sentence *"an anchor that carries a header is refused rather than silently stripped"* states a **host-side** property unqualified in the product's guarantee list (the r2 BLOCKER's species, one notch smaller) | Replaced with the qualified sentence in §9(1); N-5 and R-4 carry the same qualification so the verbatim copy stays true. | §1.2 N-5, §8 R-3/R-4, §9(1) |
| 5 | MINOR | `:536`'s *"`0x02`–`0x09` and `0x100` run **byte-identical code**"* is false — `default-features = false` also drops `std`, which propagates to the precompile deps, and `revm-precompile-34.0.0/src/blake2.rs:135,201` selects an AVX2 implementation of `0x09` under `#[cfg(all(target_feature = "avx2", feature = "std"))]`. **Conclusion (Δ = 9 addresses) is right; the wording is not** | Restated as **same implementation crate, identical outputs by construction, different code path** — with the `std` propagation and the blake2 citation written in, so the correction is checkable and not just softer. The same overstatement in OQ-3 (`byte-identical k256/arkworks code`) is fixed with it. | §3.6 G-2 row, §10 OQ-3 |
| 6 | MINOR | AC-11's witness recipe says *"the **five** `*.t.sol` files"* but §7.1 adds a sixth, so the count goes stale on the commit that introduces it | Recipe restated as **the glob, not a name list** — every `*.t.sol` in the directory, five before 008 and six after — with the failure mode (an implementer hard-coding five names) named. | §6.2 |
| 7 | MINOR | AC-0b's pinned prefix `1..=710` **includes the testkit block's own doc comment** (`reexec-evm/src/lib.rs:708-710`) and the uniqueness assertion forbids a **second** `#[cfg(any(test, feature = "testkit"))]` — both edits N-3 explicitly permits, both failing AC-0b for a non-violation | One paragraph in AC-0b: builders go **inside** the existing block, below line 711; the block's doc comment is **inside** the pinned prefix and must not be edited; a second `#[cfg]` block is forbidden. Failures are loud, so this is a trap removed, not a hole closed. | §6 AC-0b |
| 8 | MINOR | §7.5's *"this is not the 9/9 blocker"* should be **conditional on the post-008 and SVM numbers**, both unmeasured and both moving in the same direction | Restated as a conditional, with the two unmeasured quantities named at the point of the conclusion and the direction they move stated. Nothing else in §7.5 changes. | §7.5 |

**Not re-litigated** (the r3 review verified these independently and recorded them as sound; round 4
changes nothing about them): **P-12 closes G-2's soundness half** — all four call opcodes route
through one account-loading path (`revm-interpreter-35.0.1/src/instructions/contract.rs:158`,
`:203`, `:248`, `:293` → `load_acc_and_calc_gas` → `load_account_delegated` → `db.basic` at
`revm-context-16.0.1/src/journal/inner.rs:927`), so with a witness-closed database the input's
account set is a **superset** of every address the execution can reach and a runtime-computed
callee or a `DELEGATECALL` cannot evade the syntactic check; **Δ is complete at 9 addresses**
(`bn` and `gmp` are not default features, so `0x05`–`0x08` do not differ); **G-3's relabel and
remedy (a)**; **the `head -710` rule**; **AC-7a's restatement and its six constrained components**;
**§7.5's tier discipline** (the single correction is finding 8 above); **§7.6's separation from
§8**; and **the V-10 correction's direction**.

### 0.3 Round-2 findings (8: BLOCKER 2 / MAJOR 4 / MINOR 2)

| # | sev | finding | round-3 response | where |
|---|---|---|---|---|
| 1 | **BLOCKER** | G-1/G-2/G-3 run on the **prover's** machine, so "Δ is unreachable" is false against the adversary §3.2(c)(1) names — and that false sentence was scheduled into the shipped honest scope | **G-2 moved into the guest as P-12** (a syntactic check on `GuestInput`, justified with P-9's template). G-2 kept as the host-side early refusal. **G-1 and G-3 relabelled** — they are not "enforced", and bypassing either yields no capability, which is now argued rather than asserted. New vector **W-09** (hand-built `GuestInput` bypass). The three "unreachable" sentences at `:640`, R-3 and §9(1) are rewritten to say **rejected by the guest**. | §3.6, §4.1 P-12, §4.3, §5.1, AC-4 W-09, §8 R-3, §9(1) |
| 2 | **BLOCKER** | 4 mutants guard 4 of 16 criteria; **AC-3 (axis 2) has none**; a 128-bit truncation survives all four while the selftest prints `4/4` | **16 mutants.** M-5 (erase the block-env application → AC-03), M-6 (truncate at **128** bits → AC-02), M-7 (drop `check_hash` → AC-07a), and M-8…M-16 for the `script` and `forge` rows. Every one of the 18 manifest rows either has a mutant or a **written exemption** (§6.2, AC-13). Evidence line `16/16`. The 20-minute stop rule is **re-priced to 40 and kept**, with per-mutant elapsed printed. | AC-13, §6.2, §7.3 |
| 3 | MAJOR | G-3 is unimplementable from the given signature: `to_guest_input` takes an already-extracted `check` tuple and never sees a `PredicateV1`, so `PredicateIsNotSingleDeltaCheck` is unconstructible — a name with no body | Remedy **(a)** taken, not (b): the gate now takes **`predicate: &PredicateV1`** and does the extraction itself, so the single check the guest judges on and the predicate `replay` judges on are the same object. New vector **W-10** (two-check `PostStateDelta`, and `ResultEquals`, plus the single-check control). | §3.6, AC-4 W-10 |
| 4 | MAJOR | a `kind = script` row is satisfied by `echo`; six of eight script rows carry load-bearing claims and none was mutation-tested | Two changes, with the weight-bearing one named: **(1)** every `script` evidence line ends with `witness=<hex>` recomputed **independently by `ac008.sh`**; **(2)** every `script` row has a mutant (M-8…M-13, M-16). §6.2 states that (2) is what detects a stub and (1) only makes the stub stale, and states what neither proves. | §6.0, §6.2, AC-13 |
| 5 | MAJOR | AC-7a's `state_root` component cannot be tested as defined (changing it alone panics at MPT verification), and five address/slot components need a witness the spec never required | AC-7a restated as "changes exactly one **bound** component"; `state_root` varies via a **second consistent prestate**; the five address/slot components require the **baseline witness to contain both values**. A per-component constraint table replaces the one-sentence recipe. Count stays 18. | AC-7a |
| 6 | MAJOR | `surfaces.pinned` is created by the implementer it constrains, the expected digests are unstated, and "above the line" is ambiguous | Both digests written into AC-0b as **literals** (`07d649c2…33e45b`, `b4fd62d5…b29d1`), the rule named as `head -710 \| shasum -a 256` with line 711 **excluded**, and the script must additionally assert that line 711 is still the `#[cfg]` line so a shifted boundary fails loudly. | AC-0b |
| 7 | MINOR | AC-2's V-10 `guest today` cell is wrong (the guest agrees today) and there is no convention for `min`/`max` values `u64` cannot hold | V-10 corrected to **agrees**. One convention stated once above the table (`†`), and every cell that depends on it marked. Recomputed the whole column again under that convention. | AC-2 |
| 8 | MINOR | AC-11 falsifies `zk-verdict/README.md:108` and AC-14's stale-claim list does not include it | Added as AC-14(i)'s **eighth** literal, with a replacement sentence in (ii) and §9(1a). Evidence line becomes `8/8 stale claims absent, 7/7 replacements present`. | AC-14, §9 |

**Not re-litigated** (r2 recorded these as settled, and this round changes nothing about them):
the empty-MPT-proof asymmetry — **008 was right and r1 was wrong**, `alloy-trie` errors whenever
`expected_value` is `Some` and `main.rs:58-60` always passes `Some`, so only the *storage* variant
diverges (P-11 real, P-10 reason-matching); INV-2's scoping to **D** is a **sharpening**, not a
weakening; `surfaces.pinned` is not a ritual; the precompile/database-read question (R-1); the
decision (a) vs (b).

### 0.4 Round-1 findings

| # | sev | finding | round-2 response | where |
|---|---|---|---|---|
| 1 | BLOCKER | the harness reads test *names*; 79 tautologies pass; AC-13 only renames | AC-13 rewritten: **4 committed mutation patches, applied in place by the gate, each required to make a named row exit non-zero** *(round 3: **16** patches — the mechanism was right and the coverage was not, §0.3 finding 2; round 5: **18**, §0.1 findings 1 and 2)*. A body of `assert!(true)` survives a rename but **cannot survive a mutant** — it passes the mutant too, so the row does not fail, so the selftest fails. Self-reporting deleted from §7.3. | §6 AC-13, §7.3 |
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

- **N-1. `RecknZkEscrow.sol` is not modified. Not one byte, in any state, at any moment.
  There is no exception** *(round 4: there was one, and it is gone — §10 OQ-5, **ruled**)*.
  Rounds 1–3 specified AC-13's mutant **M-8** as a transient in-place edit of a comment in that
  file, under a `trap`, restored from a byte copy. That is an agent editing the file
  `AGENTS.md` §0 is about, and no `trap` makes it not one: a `trap` catches `EXIT INT TERM` and
  **not `SIGKILL`**, and `scripts/no-keys.sh` is comment-blind by design
  (`scripts/no-keys.sh:28-30` strips comments before every check), so a hard kill between
  `patch` and `restore` leaves a mutated contract that the pre-commit check **cannot see**.
  **M-8 now runs entirely inside a sandbox copy of the layout** (AC-13, "M-8 — sandbox mode"):
  it reconstructs `$S/zk-verdict/scripts/`, `$S/zk-verdict/contracts/src/` and
  `$S/reexec-evm/src/` in a temp directory, proves the *clean* copy passes, mutates the **copy**,
  requires the copied `surfaces.sh` to fail, and removes the directory with `rm -rf "$S"`.
  No file under the repository is written at any point. This is the construction `003` adopted
  in its §4.5.9 and measured working on 2026-09-04, and it requires exactly one property of
  `surfaces.sh`, now written as a requirement in AC-0b: **it derives its targets from its own
  location and from nothing else.**
  The timeout / refund path is `003`. AC-0b makes this a build condition, which
  is also what keeps AC-0 trivially true:
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
  `block_header`, and after r1 finding 5 the **typed host conversion** `to_guest_input` refuses
  an anchor that **has** a header rather than silently stripping it (§3.6, G-1). *(Round 4,
  r3 finding 4: that refusal is a property of the host tool, not of the guest. A raw
  `GuestInput` has no header field to carry, so the guest neither sees nor checks one, and a
  prover who skips `to_guest_input` is refused nothing — which is exactly why G-1 is scoped as
  hygiene in §3.6 and why the shipped sentence in §9(1) is qualified.)*
- **N-6. Precompile *backend* parity is not closed** — see R-3. The guest and the off-chain
  engine run the *same precompile set* with *different implementations*, and their
  equivalence is untested. 008 puts that set **outside the domain the proof speaks about**
  (P-12 in the guest, G-2 early at the host, and the witness-closed DB for the unwitnessed
  case) but does not close the parity. Those are different claims and §9 says so.
- **N-7. No new external / public function on any contract.** The `no-keys.sh` **function**
  enumeration (`fund` / `settleWithProof` / `refundAfterDeadline`) is unchanged.
  *(Round 5: `AGENTS.md` §0 **does** move, and in the other direction. The **checked region**
  gains a second file — `zk-verdict/contracts/src/RecknVerdictVerifier.sol`, check 5 — because
  008 edits that file and it is on the settlement-authority path (r4 BLOCKER, §0.1 finding 1).
  That is a **tightening**: the set of trees the build condition accepts strictly shrinks, no
  function surface widens, and nothing that was rejected before is accepted now. It is still a
  change to what the central claim asserts, so §9(2a)–(2c) declare it in the same commit and
  OQ-6 records the ruling. **Relaxing check 5 later is a founder call, not an agent's** —
  `AGENTS.md` §0's last line already says so about this script.)*
- **N-12. `RecknVerdictVerifier.sol` changes in exactly one way: four field widths.**
  `VerdictPublicValues.pre` / `.post` / `.minDelta` / `.maxDelta` go `uint64` → `uint256`
  (§3.4). 008 adds **no** function, **no** state variable, **no** constructor parameter, **no**
  modifier, **no** import, **no** string literal and **no** statement to that file, and changes
  neither `verifyVerdict`'s body nor the constructor's. Enforced by check 5, whose pinned
  vocabulary and pinned statement forms are written in §6.4 and differ from today's file in
  exactly one token (`uint64` → `uint256`). This is what makes the check writable in the same
  round that edits the file: **a digest cannot be pinned here, and a structure can.**
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
| the v2 domain tags and the new honest-scope text | `003` (pins the honest-scope digest) and `004` (re-implements the v1 binding formula, and carries a residual about `gas_limit` that 008 resolves) | OQ-2 |
| **`scripts/no-keys.sh` check 5 over `RecknVerdictVerifier.sol`** (AC-0, §6.4), and the second file declared in `AGENTS.md` §0 / `CLAUDE.md` (§9(2a)–(2c)) | **`003` extends it**, in its own numbering | **Orchestrator ruling, 2026-09-04: 008 introduces the check, `003` extends it.** 008 opens the file first (§3.4), and *a check that does not exist at the moment a file is first edited is not a check* — attributing it to `003` would leave the region open for the whole of 008 **and** 009, which are the two tasks the 9/9 checkpoint turns on. **008's part is the minimum that closes the splice**: one new numbered check (**5**) over one new target, with the interface unchanged. **008 does not write `003`'s extension** — the `constructor`'s semantic closure and the on-chain deployment check are `003`'s, and 008 neither specifies nor pre-empts them. `003` may renumber check 5 into its own table; renumbering is not loosening, because the set of rejected trees only grows. **No literal of `003` is copied into this document**: `003` is not APPROVEd, so its counts and strings are not facts here (§0.1 finding 7). |

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

### 2.5 What is **not** wrong (checked, recorded so later rounds do not re-litigate)

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

**That is the whole of 008's edit to `RecknVerdictVerifier.sol` — four tokens (N-12).** The file
is on the settlement-authority path (`RecknZkEscrow.sol:99` calls `verifyVerdict` and obeys the
struct it returns), so from this commit onward it is inside `scripts/no-keys.sh`'s checked region
as **check 5** (AC-0, §6.4). The four widths are the only difference between the file's pinned
structure before and after 008: the pinned identifier vocabulary of §6.4 changes by exactly one
token, `uint64` → `uint256`. **If 008's edit cannot be expressed inside §6.4's pinned forms, stop
and report** (`AGENTS.md` §7) — do not loosen a form to fit the edit.

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

**1. One conversion at the host — and, where it matters, a second copy inside the guest.**
`zk-verdict/script/src/lib.rs` gains

```rust
pub enum OutOfDomain {                       // one variant per §5.1 clause the HOST can see
    AnchorCarriesBlockHeader,                // G-1
    DivergentPrecompileAddress([u8; 20]),    // G-2
    PredicateIsNotSingleDeltaCheck,          // G-3
}

pub fn to_guest_input(
    anchor: &EvmAnchorV1, witness: &PrestateWitnessV1,
    plan: &EvmCallPlanV1, predicate: &PredicateV1,
) -> Result<GuestInput, OutOfDomain>;
```

and it is **the only function in the repository that constructs a `GuestInput` from typed
`reexec-evm` values**. It destructures `EvmAnchorV1`, `AccountWitness`, `StorageWitnessV1` and
`EvmCallPlanV1` **exhaustively, with no `..` rest pattern**, so a new field on any of them is a
compile error rather than a silent omission. One anchor field is carried into an explicit
exclusion set with a reason — `block_hash` (`BLOCKHASH` is unavailable to both engines, R-2).
`block_header` is **not** excluded any more; it is refused (G-1).

**The `predicate` parameter is a round-3 change (r2 finding 3).** Round 2 passed
`check: (Address, U256, U256, U256)` — a single check the caller had already extracted — so the
function could not observe predicate *kind* or *count*, and `PredicateIsNotSingleDeltaCheck` was
**unconstructible**. §5.1 nevertheless read "enforced, G-3": an enum variant and a table row with
no body behind them. That is `AGENTS.md` §5's named failure at the level of the spec, and the same
shape as `003`'s **R-8** — a check at the call site does not constrain the operand. The gate now
performs the extraction itself: `PredicateV1::PostStateDelta { checks }`
(`reexec-evm/src/lib.rs:149`) with `checks.len() == 1` yields the tuple; **every other predicate
shape returns `Err(PredicateIsNotSingleDeltaCheck)`**. This also makes the differential honest —
the single check the guest judges on and the `PredicateV1` that `replay` judges on are now derived
from one object instead of assumed equal. Vector **W-10**.

**Where each gate is enforced — the round-3 correction, and the whole of r2 BLOCKER 1.**

§3.2(c)(1) states, in this document's own words, that **the prover is the adversary and there is
no sanitiser between them and the guest**. `to_guest_input` is a **host** function. The guest's
entry point is `sp1_zkvm::io::read::<GuestInput>()` (`zk-verdict/program-revm/src/main.rs:95`),
and the existing host binary already builds a `GuestInput` **by struct literal** at
`zk-verdict/script/src/bin/reexec.rs:123` and writes it straight to stdin at `:166`. A prover who
never calls `to_guest_input` loses nothing. A gate that lives only there is enforcement placed one
layer outside the adversary — and round 2 nonetheless wrote "Δ is unreachable", into the text
scheduled for `zk-verdict/README.md`'s honest scope.

The consequences are **not** symmetric, and only one of the three is a soundness problem:

| gate | condition | enforced where | why that placement is the right one |
|---|---|---|---|
| **G-1** | `anchor.block_header.is_some()` | **host only — hygiene. No in-guest analogue, and none needed.** | `GuestInput` carries no header field at all (N-5), so an input built without the gate is **byte-identical** to a compliant one. Bypassing G-1 yields no capability; it only means the *off-chain* half of the differential was run against a header the guest never saw. Off-chain a header runs `header::verify_header_against_anchor` (`reexec-evm/src/lib.rs:460-463`) and can return `Err(HeaderMismatch)`; the guest could neither reject a bad header nor honour a good one, so the honest move is to refuse the input at the host rather than silently strip it as round 1 did. Liveness and claim-scope, not soundness. **W-08.** |
| **G-2** | `plan.target`, or any address in `witness.accounts`, is in **Δ** = `{0x01, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11}` | **in-guest: P-12.** G-2 stays at the host as an **early refusal**, so an honest caller gets a typed error instead of a panic. | The only one of the three with soundness weight; the attack is spelled out below. Δ is the backend-delta set and nothing wider: `0x02`–`0x09` and `0x100` resolve to the **same implementation crate** on both sides — `bn` and `gmp` are **not** default features, so modexp (`0x05`) uses `aurora-engine-modexp` and bn128 (`0x06`–`0x08`) uses `ark-bn254` in both builds — and their outputs are therefore identical by construction. **They are not byte-identical *builds*, and round 3 said they were** (r3 finding 5): `default-features = false` also drops `std`, which `revm-precompile-34.0.0/Cargo.toml` propagates to `k256`, `ripemd`, `sha2`, `ark-bn254`, `ark-bls12-381`, `aurora-engine-modexp` and `p256`, and `revm-precompile-34.0.0/src/blake2.rs:135,201` selects an **AVX2** implementation of `0x09` under `#[cfg(all(target_feature = "avx2", feature = "std"))]`. Same crate, same outputs, different code path — which is the claim that survives, and the conclusion (Δ is exactly these 9) is unchanged. Refusing `0x02`–`0x09` / `0x100` would refuse an in-domain input and *create* an INV-2 violation. **W-06 (host), W-09 (guest).** |
| **G-3** | the predicate is not a `PostStateDelta` with exactly one check | **host (G-3), and unrepresentable in `GuestInput`** | `GuestInput` has exactly one `DeltaCheck` field, so no hand-built input can express a second check or a `ResultEquals` — bypassing G-3 produces a single-check input by construction. What G-3 adds is not a guest protection but a **scoping of INV-1**: it fixes which off-chain predicate the guest's verdict is compared against. N-4. **W-10.** |

**Why G-2 needs P-12 — the concrete attack round 2 left open.** `dealBinding` commits
`state_root`, `env_hash`, `check_hash` and `plan_hash` (§3.5). It does **not** commit *which
accounts the witness contains*. So for a buyer-funded deal whose target code reaches `ecrecover`
on a nested CALL, the seller may put `0x00…01` into `witness.accounts` with a **valid inclusion
proof against the committed `state_root`** and a non-zero balance, build the `GuestInput` by
struct literal exactly as `reexec.rs:123` already does, and prove. The guest executes it on the
`k256` backend while `reexec-evm` executes it on `secp256k1`
(`revm-precompile-34.0.0/src/secp256k1.rs:4-8`), and R-3 declares that pair's equivalence
**untested**. Every hash in the binding matches, so `settleWithProof` accepts.

**P-12**, therefore: before anything else, the guest asserts that no address in `input.accounts`
is in Δ and that `input.plan.target` is not in Δ, and panics otherwise. It is a **syntactic**
check on `GuestInput` — one comparison per witnessed account against a 9-element constant set, no
execution tracing, no measurable cycle cost. Its missing off-chain mirror is justified exactly as
**P-9**'s is at §4.1: `replay` has no Δ refusal, so an input carrying a Δ address is **outside D**
(§5.1, whose clause is now the syntactic condition both P-12 and G-2 test), and INV-2 asserts
nothing there. That is a deliberate liveness reduction — R-9, priced in OQ-3.

**The unwitnessed half is unchanged and still closes.** *Δ address absent from the witness* → the
first entry calls `db.basic(address)` (`revm-context-16.0.1/src/journal/inner.rs:920-927`;
top-level via `revm-handler-18.1.0/src/execution.rs:20-22`, nested via
`revm-interpreter-35.0.1/src/instructions/contract.rs:157-158` → `call_helpers.rs:73`;
`precompiles.run` at `revm-handler-18.1.0/src/frame.rs:203` is reached only *after*), and the
closed database errors on **both** sides — in-guest a panic (P-5), off-chain
`MissingAccountWitness`. Agreement holds, no proof exists. This case depends on r1's rejected
finding R-1 being right; it is, and the citation is reproduced so a later round does not re-open
it.

**What is now true about Δ, stated exactly.** A witnessed Δ address is **rejected by the guest**
(P-12) and refused early at the host (G-2); an unwitnessed one fails on both sides. Δ is therefore
**outside D and not provable**. That is a different and stronger statement than round 2's
"unreachable at the input", and it is still **not** a claim that the two backends are equivalent.
R-3 and §9(1) say so in those words.

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
    pub extra_accounts: Vec<(Address, U256 /*balance*/, Bytes /*code*/)>,  // W-06, W-07, AC-7a
    pub extra_slots: Vec<(Address, U256 /*slot*/, U256 /*value*/)>,        // AC-7a check.slot, W-13
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

The gate runs **before** the guest, so an `Err(OutOfDomain)` produces neither a panic nor a
verdict — the guest is never invoked at all. That is what lets INV-2 be an honest biconditional
over **D** instead of a false one over everything (r1 findings 4, 5, 9).

**The gate is not the enforcement.** It is a **host** convenience that gives an honest caller a
typed error instead of a panic. A prover who skips it writes a `GuestInput` to the ELF's stdin
directly (`zk-verdict/script/src/bin/reexec.rs:123,166`), and for the one clause of D that carries
soundness weight the guest therefore checks it **again**, itself: **P-12**. G-1 and G-3 have no
in-guest twin because bypassing them yields no capability — §3.6 argues each case rather than
asserting it. *(Round 2 drew this diagram with all three clauses enforced only in the left-hand
box and then claimed Δ was unreachable. r2 BLOCKER 1.)*

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
| **P-12** | **any address in `input.accounts`, or `input.plan.target`, is in Δ = `{0x01, 0x0a, 0x0b`–`0x11}`** (new — r2 finding 1) | no off-chain analogue — `replay` has no Δ refusal, so an input carrying a Δ address is **outside D** (§5.1) and INV-2 asserts nothing about it. Same shape and same justification as P-9: reachable only by a hand-built `GuestInput`, which is exactly the adversary §3.2(c)(1) names, and which `zk-verdict/script/src/bin/reexec.rs:123,166` shows is one struct literal away. **W-09.** |

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
- **A proof about a witness that contains a Δ address.** **P-12 panics in the guest**, so no
  proof exists; G-2 refuses the same input earlier at the host. The complementary case — a Δ
  address the witness does **not** contain — is closed by the witness-closed database on both
  sides (§3.6). *(Round 2 wrote this as "an execution that **entered** Δ" and located the
  enforcement in a host function the prover can skip. Both halves of that sentence were wrong:
  the condition is syntactic, not dynamic, and the enforcement is now in the guest.)*
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
  enforced rather than described — §3.6.)* **P-12 does not violate this**: it panics only on
  inputs a D clause excludes, so INV-2 has no obligation there. **P-9 likewise.** Those are the
  only two P-transitions with no off-chain mirror, and both are outside D by construction — which
  is the property AC-4's coverage table has to keep true as the P-list grows.
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
- **INV-8 — the on-chain surface does not move, and the checked region does not shrink.**
  `RecknZkEscrow.sol` is byte-identical to the 008 base commit. `scripts/no-keys.sh`'s
  enumerated **function** surface (`fund` / `settleWithProof` / `refundAfterDeadline`) is
  unchanged, and its checked **region** gains exactly one file (check 5, §6.4) — a strict
  tightening: every tree `no-keys.sh` rejected at the base commit is still rejected.
  `RecknVerdictVerifier.sol` changes only in the four field widths (N-12).
  `abi.encode(VerdictPublicValues)` is 224 bytes before and after.
- **INV-9 — the SVM guest is semantics-preserving.** For all `(a, b, lo, hi) ∈ u64⁴`,
  `delta_outcome(U256::from(a), U256::from(b), U256::from(lo), U256::from(hi))` equals the
  pre-008 `u64` result. (`saturating_sub` commutes with zero-extension on `u64` inputs.)
- **INV-10 — one outcome mapping.** The `Verdict → u8` conversion exists in exactly one
  function. No other site compares a `verdict_lib` outcome byte with a `ReplayRecordV1`
  outcome byte.
- **INV-11 — every residual in §8 has a named disclosure site, and AC-14 checks it there.**
  *(Restated in round 5. The round-4 form — "every residual appears **verbatim** in
  `zk-verdict/README.md`'s honest scope" — was **false for two of the ten**: **R-7** appeared in
  no shipped document at all, and **R-8** is disclosed in the root `README.md`'s known-gaps
  bullet, not in the honest scope. Neither was detectable: AC-14(ii)'s markers named neither.
  r4 finding 4.)* The invariant is now what the mechanism actually enforces:
  **(a)** R-1…R-6, R-7, R-9 and R-10 are disclosed in `zk-verdict/README.md`'s honest scope,
  and **the ones AC-14(ii) has a marker for are R-3 (marker 3's sentence), R-4, R-7 (marker 8)
  and R-10 (marker 10's `AGENTS.md` §0 declaration)**;
  **(b)** **R-8** is disclosed in the root `README.md:566-571`, which §9(3) leaves untouched and
  AC-14 does not move; the honest scope does not repeat it;
  **(c)** every claim 008 *does* close is removed from the root `README.md` "Known gaps" list in
  the same commit (AC-14(i) literals 1 and 2).
  A residual with neither a disclosure site nor a marker is a violation of this invariant, and
  finding it is what round 5 did.
- **INV-12 — the gate detects a wrong implementation, not a renamed one.** For each of the
  **eighteen** committed mutants (§7.3), applying it makes **every** manifest row named
  in its `target rows` column exit non-zero. A test body that asserts nothing passes the mutant,
  so it fails this invariant. (AC-13. This is the invariant round 1 was missing — `AGENTS.md` §5,
  added 2026-09-04.)
- **INV-13 — every manifest row is either mutated or exempt in writing.** Each of the 18 rows
  appears in AC-13's coverage table with at least one mutant, or with a stated reason why it has
  none. There is no third category. *(Round 2 had four mutants and twelve unexamined rows; the
  hole was not that the four were weak but that nothing enumerated the other twelve — r2
  BLOCKER 2 and finding 4 are the same defect seen from two sides.)*
- **INV-14 — every `script` row has one of three named guards against a constant, and which
  one it has is written down.** *(Restated in round 5. The round-4 form quantified over "every
  `script` row except AC-00 and AC-13" and claimed a mutant moves a byte inside each remaining
  row's witness set. That is **false for AC-00b**: after round 4's rewrite M-8 mutates only the
  sandbox copy and step **8h** asserts the four repository inputs are byte-identical to 8a, so
  AC-00b's `witness=` is a run-constant exactly like AC-13's. The **protection** was real and
  written elsewhere; the invariant's stated mechanism was not the one operating. Same species as
  r3 finding 2, reintroduced by its fix — r4 finding 5.)*

  **Case (a) — the witness moves at run time.** Five rows: **AC-06/M-9, AC-09/M-10,
  AC-11/M-11, AC-14/M-12, AC-16/M-16.** The evidence line carries a `witness=` field that
  `ac008.sh` recomputes from repository bytes without invoking the row's command, and at least
  one mutant changes a byte inside that row's witness set while the gate runs, so a hardcoded
  digest goes stale mid-run.

  **Case (b) — the guard is a sandboxed script's own exit status.** Two rows, both by
  construction and both deliberate:
  - **AC-00b** carries a `witness=` field and **it is a run-constant** — M-8 and M-18 mutate
    only copies, and 8h/18h re-assert the repository bytes. What kills a stub here is not the
    witness but the **sandbox**: the stubbed script is *the script the sandbox runs*, and it must
    exit non-zero on the mutated copy (8g, 18g) **and** print a `computed:` digest equal to the
    selftest's own digest of that copy. A heredoc script, and a `grep -q` script, both fail that.
  - **AC-00** carries **no** `witness=` field at all. Its evidence line is `AGENTS.md` §0's
    declared output and 008 does not restyle it (§6.2). Its guard is **M-17**, the same sandbox
    construction applied to `scripts/no-keys.sh` and `RecknVerdictVerifier.sol`. *(Round 4 gave
    the exemption a different reason — "008 may not modify `no-keys.sh`" — which round 5 makes
    false: 008 adds check 5 to it. The exemption survives; its reason changed and its
    replacement guard is now stronger than a witness field would have been.)*

  **Case (c) — no guard, stated as such.** **AC-13** carries a `witness=` and it is a constant
  for the whole run: its witness set is the eighteen `mutants/*.patch` files and **no mutant
  modifies a patch file**. **AC-13's own manifest row is satisfiable by `echo`**, and rounds 1–3
  said the opposite (r3 finding 2). This is not closed here — the regress does not terminate
  inside a repository, because whatever runs last is trusted. It is stated in **L-3**, §6.3's
  canary raises its cost without closing it, and **§7.8** assigns the residual to a named
  reviewer instead of leaving it unowned (r4 finding 3).

- **INV-15 — settlement authority in the second contract is a function of the proof alone.**
  `RecknVerdictVerifier.verifyVerdict` reaches its `return` only by way of
  `ISP1Verifier.verifyProof`, and the value it returns is derived from `publicValues` and from
  nothing else. Operationally, and this is exactly what check 5 tests (§6.4): the file's
  identifier vocabulary is closed, so **no** caller-, transaction-, block- or chain-dependent
  value can be read anywhere in it; the body of `verifyVerdict` is two statements of pinned form,
  so there is no branch to take and no second exit; and every assignment target in the file is
  one of five declared names, so no field of the returned struct can be written after the decode.
  **Without this, the escrow's `RecknZkEscrow.sol:99` trusts a struct that a resolver chose** —
  which is `AGENTS.md` §0's failure mode reached from the one file §0 was not looking at
  (r4 BLOCKER). Falsified by M-17.

### 5.1 The domain D over which INV-1 and INV-2 are asserted

**D** = inputs where all of the following hold. **Every clause names where it is enforced, and
"host" and "guest" are different answers** — that distinction is what round 2 collapsed and what
r2 BLOCKER 1 was about.

| clause | enforced where, and what that is worth |
|---|---|
| the predicate is a `PostStateDelta` with **exactly one** check (N-4) | **host, G-3** — the gate now takes `predicate: &PredicateV1` and does the extraction itself (§3.6), so the variant is constructible and the clause has a body. **Also unrepresentable in `GuestInput`**, which carries exactly one `DeltaCheck`: a bypassing prover produces a single-check input by construction. The clause scopes *which off-chain predicate* INV-1 compares against; it is not a guest protection. **W-10.** |
| `anchor.block_header` is `None` (N-5) | **host, G-1 — hygiene only.** No in-guest analogue and none needed: `GuestInput` has no header field, so bypassing the gate yields a byte-identical input and no capability. **W-08.** |
| **no address in `witness.accounts` is in Δ = `0x01`, `0x0a`, `0x0b`–`0x11`, and `plan.target ∉ Δ`** — the backend-delta precompiles (R-3) | **guest, P-12**; refused early at the host by G-2. **W-06 (host), W-09 (guest).** *Restated in round 3 as the **syntactic** condition both checks actually test.* Round 2 wrote "the execution does not **enter** Δ", which is a *dynamic* condition and a different set: a witness that merely **contains** `0x00…01` for an execution that never calls it satisfied round-2's D **and was refused by the gate**, so INV-2's *iff* was false in the liveness direction for exactly that shape. One clause, one condition, one place — now they match. |
| the execution does not read `DIFFICULTY` (0x44 pre-Merge semantics) or `BLOBBASEFEE` (0x4a) | **nowhere — and it does not need to be for INV-1/INV-2.** Both engines return the same `BlockEnv::default()` constant (`revm-context-16.0.1/src/block.rs:121-126`), so they **agree** with each other. The clause exists only to stop anyone reading INV-1 as fidelity to a real block. It is R-1/R-6, not a hole. |

**The unwitnessed Δ case is deliberately *not* a clause of D.** An input whose plan CALLs a Δ
address that the witness does not contain is **inside D** and both sides refuse it (P-5 /
`MissingAccountWitness`) — which is agreement, so INV-2 holds. Writing it as an exclusion would
shrink D for no reason and would hide the fact that the closed database is doing the work. W-07 is
the vector.

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
| AC-13's ten sandbox copies of **the whole repository** | `du -sh zk-verdict/target` = **6.8G**, `du -sh .` = **21G**, and `zk-verdict/script` pulls `sp1-sdk` — ten copies is ~210 GB or ten cold builds, unpriced, on the head task of a 9/9 checkpoint. *(Round 4: M-8's sandbox is a different object — **four files, under 60 KB, no build tree** — and is not a revival of this. AC-13's cost model says so explicitly.)* | 3 |
| AC-14's "exact integer at all 12 enumerated sites" | the enumeration is line numbers, and r1 finding 8 is a demonstration that line numbers in this document go stale within a day. Replaced by two greps that need no line numbers. | 8 |
| AC-6's bash parser of `pub struct` declarations | the exhaustive destructure is already a **compile error**; a bash re-derivation of the same fact is the weaker half of a doubled check | — |
| AC-6's `GuestEnv` field-name grep | AC-3 probes all 8 fields by execution; a name grep adds nothing and is the "名前でなく本体" pattern `AGENTS.md` §5 names | — |
| **AC-5** as a separate criterion | folded into AC-6's script (same file set, same kind of check). **There is no AC-5 in round 2**; the number is not reused. | — |
| the two documentation digest pins | two of the three were already stale within a day (§0) | 8 |

**Added in round 2:** AC-16 (r1 finding 6), W-04…W-08 (r1 findings 4, 5, 9), E-11/E-12 (r1
finding 13).

**Added in round 5:** **check 5** of `scripts/no-keys.sh` (§6.4 — the second contract in the
settlement path, r4 BLOCKER), **M-17** and **M-18** (AC-13, both sandbox, both zero-build),
AC-14(i) literal **9**, AC-14(ii) markers **8–11**, and AC-14 check **(v)**. AC-13's evidence line
goes `16/16` → `18/18` and AC-14's goes `8/8 … 7/7` → `9/9 … 11/11` plus one new clause.
**No row is added and none is removed**: the manifest stays at **18** rows, 16 criteria, 91 cargo
tests and 6 forge tests. The three §7.1 file-table additions are a contract 008 already edits, a
script 008 now edits, and two more `.patch` files.

**Added in round 3:** **W-09** (the hand-built-`GuestInput` Δ bypass — r2 BLOCKER 1), **W-10**
(the predicate gate, now implementable — r2 finding 3), **W-11 / W-12 / W-13** (P-9, P-7, P-8 —
three declared transitions that had no vector, found by auditing the whole of §4.1 rather than
only the row the review named), and **twelve mutants** M-5…M-16 (r2 BLOCKER 2 and finding 4).
AC-04 goes 8 → 13, the `cargo` total 86 → 91, and AC-13's evidence line `4/4` → `16/16`.
**Nothing was removed to pay for this** — §7.5's measurement shows the schedule is bound by the
number of Groth16 regeneration *rounds*, not by test count, so the r2 cut list is not taken.

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
  run <command>; exit status must be 0; stdout must contain the `evidence` line with every
  `{witness}` placeholder replaced by a 16-hex-character value that `ac008.sh` RECOMPUTES
  ITSELF from the recipe in §6.2. `ac008.sh`'s recomputation must not invoke <command>.
  A row whose evidence line contains no `{witness}` is exempt only if §6.2 says so in writing.
```

**Gate 2 — a count is not an assertion.** 14 tests named `test_AC02_V01_…` with bodies of
`assert!(true);` pass gate 1 completely: 14 listed, 14 passed, 0 failed. Round 1 answered this
with AC-13, which **renamed** tests — and a renamed tautology fails exactly as a renamed real test
does, so AC-13 passed too. Round 1 therefore permitted an implementation that prints
`ac008: 18/18 rows passed` while `u64_low` is still in `main.rs` and `pre = 2^64 / post = 2^64 − 1`
still releases to the seller: the claim demonstrated while false.

**Gate 3 — the gate must detect a *wrong* implementation.** AC-13 applies **eighteen** committed
mutation patches — fifteen in place and three to a sandbox copy — each to real source, and requires every manifest row named as that
mutant's target to exit non-zero. A body that asserts nothing passes the mutant, so the row stays
green, so AC-13 fails. **This is the only check in the document that opens a test body — by
breaking the code the body is supposed to be about.** Nothing about it is self-reported; §7.3's
round-1 sentence *"the rest are run once by hand and their output pasted into the implementation
report"* is **deleted**.

*Round 2 had four mutants and did not enumerate what the other twelve criteria were guarded by.
The reviewer then constructed an implementation that reports `4/4 mutants detected` while
truncating at **128** bits and applying no block environment at all — because a 128-bit truncation
is caught by exactly one vector body (V-11), M-1 still flips V-03, and AC-3's thirteen bodies were
never probed. **Coverage, not mechanism, was the defect**, so round 3 changes the coverage and
keeps the mechanism: §6.2 and AC-13 now account for **all 18 rows**, each with a mutant or a
written exemption (INV-13).*

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
`tests` (exact; `-` for `script`), `evidence` (for `script`, the stdout line that must appear,
with `{witness}` standing for a value `ac008.sh` recomputes itself per §6.2; `-` otherwise).
Multi-space separated; `#` starts a comment. **`{witness}` is the only placeholder the parser
understands**; everything else in an evidence line is matched literally.

```ac008-manifest
AC-00   script  -                   bash scripts/no-keys.sh                          -   the claim holds: no key can move a funded escrow.
AC-00b  script  -                   bash zk-verdict/scripts/surfaces.sh              -   surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged; witness={witness}
AC-01   cargo   zk-verdict/lib      _AC01_                                           8   -
AC-02   cargo   zk-verdict/script   _AC02_                                          14   -
AC-03   cargo   zk-verdict/script   _AC03_                                          13   -
AC-04   cargo   zk-verdict/script   _AC04_                                          13   -
AC-06   script  -                   bash zk-verdict/scripts/env-parity.sh            -   env-parity: 5/5 truncation patterns absent; 4/4 cfg flags pinned on both sides; 0 rest patterns in to_guest_input; TxEnv fields identical (7); witness={witness}
AC-07a  cargo   zk-verdict/script   _AC07_                                          18   -
AC-07b  forge   -                   _AC07_                                           2   -
AC-08   cargo   zk-verdict/script   _AC08_                                           6   -
AC-09   script  -                   bash zk-verdict/scripts/fixtures-check.sh        -   fixtures: 4/4 current (vkey and public values byte-identical); witness={witness}
AC-10   forge   -                   _AC10_                                           4   -
AC-11   script  -                   bash zk-verdict/scripts/no-skip.sh               -   no-skip: 0 early-return fixture gates, 18/18 forge tests ran, 0 skipped; witness={witness}
AC-12   cargo   zk-verdict/lib      _AC12_                                           3   -
AC-13   script  -                   bash zk-verdict/scripts/ac008-selftest.sh        -   ac008-selftest: 18/18 mutants detected; witness={witness}
AC-14   script  -                   bash zk-verdict/scripts/docs-check.sh            -   docs: 9/9 stale claims absent, 11/11 replacements present, 0 tilde cycle literals, 1/1 qualified ~34 s site, cycles.json matches 3/3 guests; witness={witness}
AC-15   cargo   reexec-evm          -                                               16   -
AC-16   script  -                   bash zk-verdict/scripts/consumers-check.sh       -   consumers: binder, keeper, reckn-evm-content check --tests clean (3/3); witness={witness}
```

Arithmetic `ac008.sh --check` recomputes and a reviewer can recompute by hand:

- **18** manifest rows, **16** acceptance criteria (AC-0 … AC-16 with **no AC-5**;
  AC-00/AC-00b and AC-07a/AC-07b are two rows each of one criterion).
- **8** `cargo` rows; their `tests` column sums to **91**.
- **2** `forge` rows; their `tests` column sums to **6**.
- **8** `script` rows; **7** of them carry a `{witness}` field (AC-00 is the written exemption,
  §6.2).
- Per package: `zk-verdict/lib` = **11** (8 + 3, the whole package),
  `zk-verdict/script` = **64** (14 + 13 + 13 + 18 + 6),
  `reexec-evm` = **16** (unchanged; 008 adds testkit builders and **zero** tests there —
  measured 2026-09-04: `grep -c '#\[test\]'` gives 10 in `src/lib.rs`, 6 in `src/header.rs`).
  11 + 64 + 16 = **91** ✓.
- `zk-verdict/contracts` = **18** forge tests = **12** pre-existing (measured 2026-09-04:
  `grep -n "function test" zk-verdict/contracts/test/*.t.sol | wc -l` → 12) + **6** new.
  AC-11 asserts 18.
- AC-13's mutants = **18**, over **16** distinct rows; the two rows with no mutant
  (**AC-13, AC-15**) each carry a written exemption in §6.2. 16 + 2 = 18 ✓.
  *(Round 4 had 16 mutants over 15 rows with three exemptions. Round 5 adds **M-17**
  (`no-keys.sh` check 5 over `RecknVerdictVerifier.sol`, sandbox — §0.1 finding 1) and **M-18**
  (AC-0b's second clause, sandbox — §0.1 finding 2). **AC-00 moves from the exempt column to
  the mutated column**, which is the whole point of finding 1: the row that carries the central
  claim had no mutant. Two mutants target rows that already had one — M-18 joins M-8 on AC-00b —
  so rows go 15 → 16 and mutants 16 → 18.)*

*(Round 2 had 86 cargo tests and AC-04 at 8. The +5 is AC-4's five new vectors — W-09…W-13 —
and it is **not** funded by cutting anything: the r2 review's cut list is not taken, because the
measurement in §7.5 shows the schedule is bound by regeneration **rounds**, not by test count.)*

`bash zk-verdict/scripts/ac008.sh --all` runs every row, asserts it ran **18**, then applies the
**M-9 canary of §6.3 itself** and requires AC-06 to exit non-zero, and only then prints

```
ac008: 18/18 rows passed; canary M-9 detected by AC-06
```

`ac008.sh <AC>` runs one row. **AC-13 calls only the single-row form**, so `--all` does not
recurse; the canary likewise calls only the single-row form. `--all` has no `--sandbox` mode:
the one sandbox in this document belongs to AC-13's M-8 and is built by `ac008-selftest.sh`.

### 6.2 Why a `script` row is not satisfied by `echo` (r2 finding 4)

Round 2 defined a `script` row as *"exit 0 and stdout contains this literal line"*. That contract
is satisfied by

```sh
#!/usr/bin/env bash
echo "fixtures: 4/4 current (vkey and public values byte-identical)"
```

and `fixtures-check.sh` is the **only** thing tying the committed Groth16 fixtures to the current
ELF. Round 1's BLOCKER was "the harness counts test *names*"; this is the same defect one layer
up — the harness reads a string the subject prints **about itself**. **Seven** of the eight `script`
rows carry load-bearing claims: **AC-00 (the central claim itself — round 5 brings its script
inside the mutation gate, §6.4 and M-17)**, AC-00b (the pinned-file guard), AC-06 (`u64_low` still
present), AC-09 (stale fixtures), AC-11 (restored skip gates), AC-14 (the false honest-scope text
still shipping), AC-16 (`binder`'s test build).

Two changes. It matters which one carries the weight, so both are named.

**(1) The evidence line is computed, not printed — defence in depth.** Every `script` evidence
line ends with `witness=<16 lowercase hex>`, the first 8 bytes of a `sha256` over that row's
**witness set**: the exact repository bytes the row's claim is about. `ac008.sh` **recomputes the
witness itself** from the recipe below and requires equality; its recomputation must not invoke
the row's command. A stub can no longer print a constant — it must print a **hardcoded digest**,
which is stale the moment any witnessed byte moves.

| row | witness set — `sha256` over the concatenation, in this order |
|---|---|
| AC-00 | **exempt from the `witness=` field, in writing — and mutated instead.** *(Round 5: the round-4 reason for this exemption was "008 may not modify `scripts/no-keys.sh`". **That is now false** — 008 adds check 5 to it, §6.4. The exemption survives on a different and better reason.)* AC-00's evidence line is `AGENTS.md` §0's **declared output**, and every consumer of that script — the pre-commit ritual, `003`, the demo script — reads that line. 008 adds a target and a check to the script; it does **not** restyle the script's output, add a field to it, or change its arguments. What replaces the witness for this row is **M-17**: a sandbox mutant that splices a constant-address branch into a copy of `RecknVerdictVerifier.sol` and requires the **copied `no-keys.sh`** to exit non-zero. A stubbed `no-keys.sh` is the script the sandbox runs, so it exits 0 on the mutated copy, M-17 is recorded as a miss, and AC-13 fails. That is strictly stronger than a `witness=` field, which only makes a stub *stale* (§6.2(1) vs (2)). INV-14 case (b). |
| AC-00b | `sha256(zk-verdict/contracts/src/RecknZkEscrow.sol)` ‖ `sha256(head -710 reexec-evm/src/lib.rs)` |
| AC-06 | the four inspected files, whole, in this order: `zk-verdict/program-revm/src/main.rs`, `zk-verdict/lib/src/lib.rs`, `zk-verdict/script/src/lib.rs`, `reexec-evm/src/lib.rs` |
| AC-09 | the four freshly-computed ELF vkeys (32 bytes each, in AC-9's fixture order) ‖ the four fixture files, whole, same order |
| AC-11 | **every** `*.t.sol` in `zk-verdict/contracts/test/`, whole, `LC_ALL=C` sort order — **the glob, not a name list**: five files before 008, **six after** (§7.1 adds `RecknVerdictDomain.t.sol`). An implementer who hard-codes five names leaves the file 008 introduces outside the witness set on the same commit that introduces it, and M-11 would still pass because it mutates one of the original five (r3 finding 6). |
| AC-13 | the **eighteen** `zk-verdict/scripts/mutants/*.patch` files, whole, `LC_ALL=C` sort order |
| AC-14 | the five doc-set files of AC-14(iii), whole, in the order written there ‖ `zk-verdict/cycles.json` ‖ `scripts/no-keys.sh` (**added in round 5**: AC-14(i) literal 9 inspects that file's own scope comment, so it is a byte the row's claim is about) |
| AC-16 | `sha256(reexec-evm/src/lib.rs)` ‖ `binder/Cargo.toml` ‖ `keeper/Cargo.toml` ‖ `reckn-evm-content/Cargo.toml` ‖ `binder/tests/router_two_vms.rs` |

**(2) Every `script` row has an AC-13 mutant — this is what actually detects a stub.** The witness
digest makes a stub *stale*; the mutant makes staleness *observable*, because the mutant changes a
witnessed byte **at run time**, when no stub author can re-hardcode. Walk M-9 (re-insert
`fn u64_low` into `program-revm/src/main.rs`, target row AC-06):

- honest `env-parity.sh` → finds the pattern → exits non-zero → mutant detected ✓
- stubbed `env-parity.sh` echoing a constant → `ac008.sh`'s recomputed witness has moved (the file
  changed), the printed one has not → mismatch → row exits non-zero → mutant detected ✓
- **both** stubbed to agree → the row exits **zero** under the mutant → AC-13 records a miss and
  fails ✓

For AC-06 — and for **every `script` row whose witness set an AC-13 mutant actually moves**, i.e.
the **five** named in **INV-14 case (a)** — all three paths end in a failure the implementer
cannot remove by writing a constant. The two **sandbox** rows (AC-00, AC-00b) are guarded a
different way and INV-14 case (b) says which; AC-13 is guarded by neither and INV-14 case (c)
and L-3 say so. That is the answer to "an `echo` satisfies AC-09": under **M-10** (flip one
hex byte of the fixture's `vkey`) a stubbed `fixtures-check.sh` keeps printing `4/4` and the row
must go non-zero — it cannot.

**This argument does not extend to AC-13's own row, and round 3 wrote it as though it did**
(r3 finding 2). AC-13's witness set is the eighteen patch files and no mutant modifies a patch
file, so path 2 — "the recomputed witness has moved, the printed one has not" — never fires for
that row: **nothing moves it**. A two-line `ac008-selftest.sh` that echoes
`ac008-selftest: 18/18 mutants detected; witness=<the constant>` and exits 0 satisfies the row
completely, and step 0 and step 6 are *inside* the script it replaces. INV-14 names AC-13 as an
exception, **L-3** states the residual, and §6.3 adds the one cheap thing that raises the bar.

**Row-by-row mutant coverage, all 18 rows, with the exemptions written out** (INV-13):

| row | mutant(s) | if none, why |
|---|---|---|
| AC-00 | **M-17** (**sandbox** — AC-13, mode `sandbox`; the repository's `no-keys.sh` and `RecknVerdictVerifier.sol` are never written) | |
| AC-00b | M-8, **M-18** (both **sandbox**; the repository's `RecknZkEscrow.sol` and `reexec-evm/src/lib.rs` are never written. M-8 exercises AC-0b's **first** clause, M-18 its **second** — r4 finding 2) | |
| AC-01 | M-2 | |
| AC-02 | M-1, M-6 | |
| AC-03 | M-5 | |
| AC-04 | M-3 | |
| AC-06 | M-9 | |
| AC-07a | M-4, M-7 | |
| AC-07b | M-13 | |
| AC-08 | M-14 | |
| AC-09 | M-10 | |
| AC-10 | M-15 | |
| AC-11 | M-11 | |
| AC-12 | M-2 (second target row) | |
| AC-13 | — | self-referential: a mutant on the selftest would be evaluated by the selftest. **Round 3 named three substitutes — step 0's patch count, §6.2's `witness`, step 6's re-runs — and let the reader infer they close the gap. None of them does** (r3 finding 2): all three live inside the script a stub replaces, and the `witness` is a run-constant. What actually stands here is (i) **§6.3's canary**, which moves one detection off `ac008-selftest.sh` and onto `ac008.sh --all` — a different script that every other row already depends on — and (ii) the implementation review **opening `ac008-selftest.sh` and running it**, which is a person, not a mechanism. Both are written as such in **L-3**. |
| AC-14 | M-12 | |
| AC-15 | — | a **no-change** criterion: it asserts that a package 008 does not modify still has exactly 16 green tests. The mutation-equivalent is *any* edit to `reexec-evm`, whose production surface is AC-0b's prefix digest (which M-8 exercises through AC-00b, in the sandbox) and whose testkit surface is AC-16's (mutated by M-16). A mutant here would test `reexec-evm`, which is not 008's subject. |
| AC-16 | M-16 | |

**What neither mechanism proves, stated rather than implied.** Neither the witness digest nor the
mutant proves a script performed a **build**. `fixtures-check.sh` could compute the four vkeys
from a cached artefact rather than from a fresh `sp1-build`. The guards against that are
AC-14(iv)'s `elf_sha256` equality against a freshly built ELF and `ac008.sh`'s `unset` of every
`SP1_*` skip variable (§3.6.4). **They are guards, not proofs** — recorded as **L-2** in §7.6, not
in §8, because it is a limit of this document's gate and not a claim the product makes.

### 6.3 The canary — one mutant that `ac008.sh --all` applies itself (r3 finding 2)

**The problem this is a partial answer to.** Everything in §6.2 rests on `ac008-selftest.sh`
actually applying eighteen mutants. Its own manifest row does not force it to: AC-13's witness set
is the eighteen `.patch` files, **no mutant modifies a patch file**, so the `witness=` value is a
run-constant and a two-line `echo` satisfies the row (INV-14, L-3). The regress does not
terminate inside this repository — whatever runs **last** is trusted — so the honest goal is not
to close it but to **move the single point of failure off a small special-purpose script and onto
the runner every other row already depends on**.

**The canary, exactly.** `zk-verdict/scripts/ac008.sh --all`, after all 18 rows have run and
**before** it is permitted to print its evidence line, does this itself — not by calling
`ac008-selftest.sh`:

```
c1. save a byte copy of `zk-verdict/program-revm/src/main.rs`; install
    `trap restore EXIT INT TERM` FIRST
c2. patch -p1 --batch --forward < zk-verdict/scripts/mutants/09-restore-u64low.patch
    # must apply; a non-applying canary FAILS --all
c3. assert the file's sha256 CHANGED
c4. bash zk-verdict/scripts/ac008.sh AC-06        # must exit NON-ZERO
c5. restore from the byte copy; assert sha256 back to the original
c6. only now may `--all` print `ac008: 18/18 rows passed; canary M-9 detected by AC-06`
```

If c4 exits **0**, `--all` prints `ac008: CANARY FAILED (AC-06 survived M-9)` and exits non-zero.
It **may not** print `18/18` in that case, and an implementation report may not describe such a
run as passing (`AGENTS.md` §5).

**Why M-9 and not another mutant.** It is the only choice that costs nothing: M-9 re-inserts an
unused `fn u64_low` into `program-revm/src/main.rs`, and its target row AC-06 is
`env-parity.sh`, which is **greps only** — no cargo build, no `sp1-build`, no `forge`. The whole
canary is seconds, and it runs on the same warm tree. Every other zero-build mutant targets a row
that is either a sandbox (M-8, M-17, M-18), a `forge` run (M-13, M-15) or a fixture/ELF read (M-10).

**The canary is applied *in-tree*, and that carries the residue this document rejects elsewhere —
stated here rather than left for a reviewer to find** (r4 finding 6). Steps c1–c5 patch
`program-revm/src/main.rs` under `trap … EXIT INT TERM`, and a `trap` does not catch `SIGKILL`.
A hard kill between c2 and c5 leaves the file carrying a **re-inserted, unused `fn u64_low`**.
The argument §1.2 and OQ-5 use against an in-tree M-8 does **not** transfer, and the difference is
the whole reason the canary may stay in-tree: (i) the residue is an **unused function** — it
changes no guest behaviour and no verdict; (ii) it fails **loudly** at the very next
`ac008.sh AC-06`, by construction, because making AC-06 fail is the mutant's entire purpose —
unlike M-8's comment flip, which `no-keys.sh` is comment-blind to by design
(`scripts/no-keys.sh:28-30`); and (iii) §7.7 already requires the implementation report to state
that `git status` is clean after `--all`. It is a residue that announces itself, not one that
hides. **If a cheaper zero-build canary that touches no repository file is ever available, take
it** — but do not swap the canary for one whose failure is silent.

**What the canary buys, precisely.** A stubbed `ac008-selftest.sh` no longer makes the whole
gate green: `--all` will not print its evidence line unless **`env-parity.sh` really detects
`u64_low`**, and `env-parity.sh` is the row that guards axis 1's absence from the guest source.
So the cheapest total stub — one `echo` for the selftest — now also requires stubbing
`env-parity.sh`, which `ac008.sh`'s own recomputed `witness=` for AC-06 will then mismatch, and
that recomputation is in `ac008.sh`, the script the canary is in.

**What it does not buy, stated plainly so nobody reads it as a closure.** `ac008.sh` is itself a
file in this repository and can itself be stubbed. **The canary does not close the regress; it
moves it one script over and makes the two scripts that must be stubbed together larger and more
load-bearing.** The remaining trust root is the implementation review reading and running
`ac008-selftest.sh` and `ac008.sh` — a person, not a mechanism. **L-3.**

---

### 6.4 Check 5 — the second contract in the settlement path is closed (new in round 5 — r4 BLOCKER)

**The hole, exactly.** Settlement authority in the keyless path runs
`RecknZkEscrow.settleWithProof` → `RecknVerdictVerifier.verifyVerdict`
(`RecknZkEscrow.sol:99`) → `ISP1Verifier.verifyProof` + `abi.decode`
(`RecknVerdictVerifier.sol:50-56`). **The escrow trusts whatever struct that function returns**
and reads three of its fields — `dealBinding` at `RecknZkEscrow.sol:103`, `outcome` at `:109`
and `:111`, `traceHash` at `:116` (measured 2026-09-04; `pre`, `post`, `minDelta` and `maxDelta`
are never read, which is §2.5's fact and is why N-12's four-token edit is safe). Splice this in front
of the `verifyProof` call:

```solidity
if (tx.origin == 0x0000000000000000000000000000000000001337) {
    v.outcome = REPRODUCED;
    v.dealBinding = bytes32(publicValues[0:32]);
    return v;
}
```

Call `settleWithProof(dealId, publicValues, "")` from that address with the deal's public
`dealBinding` as the first 32 bytes. `verifyProof` is never reached; the binding check at
`RecknZkEscrow.sol:103` passes; `v.outcome == REPRODUCED` selects the seller at `:109-110` and
the transfer runs at `:117`. **That is a resolver** — the
one thing `AGENTS.md` §0 exists to make impossible — and through round 4 **every criterion in
this document stayed green**: `scripts/no-keys.sh:19` reads one file and it is not this one,
AC-0b pins two other files, §7.1's table did not list it, and M-15 only swaps two constants.
Round 4 even wrote the fact down at `:1842` (*"`RecknVerdictVerifier.sol` … which `no-keys.sh`
does not read"*) and used it as a reason the file needed **no** sandbox, when it is the reason
the file needed a check. **That sentence is rewritten in AC-13's mode paragraph.**

**Why 008 and not `003`** (orchestrator ruling, 2026-09-04). 008 **edits this file** (§3.4,
N-12) and 008 is first in the execution order. A check that does not exist at the moment a file
is first edited is not a check: introducing it in `003` would leave the region open across 008
**and** 009 — the two tasks the 9/9 checkpoint turns on (`AGENTS.md` §7). **008 introduces the
check; `003` extends it** (§1.3). 008 does not write `003`'s extension and does not quote it.

#### What 008 adds to `scripts/no-keys.sh`, and what it does not

- **A second target, derived the same way as the first.** `no-keys.sh:17-19` already computes
  `here=$(cd "$(dirname "$0")" && pwd)` and `root=$(cd "$here/.." && pwd)` and then names its
  target under `$root`. Check 5's target is `$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol`,
  written the same way. **The Location rule of AC-0b applies verbatim to `no-keys.sh` as well**:
  no target argument, no environment override, no absolute path, no `git rev-parse`. This is what
  makes M-17's sandbox possible at all, and it is already how the script behaves — 008 must not
  regress it.
- **One new numbered section.** The script prints **five** sections instead of four
  (`no-keys.sh:33`, `:42`, `:56`, `:64` are 1–4; check 5 is new). It uses the existing
  `say` / `ok` / `bad` helpers and the existing `fail` accumulator.
- **Nothing else.** No argument, no flag, no environment variable, no change to the final line
  (`✓ the claim holds: no key can move a funded escrow.`), no change to the four existing checks,
  no change to the escrow's scope. AC-00's manifest evidence line is therefore unchanged, and so
  is every consumer of that line.
- The script's own header comment (`no-keys.sh:11-12`) says the scope is *the body of
  `contract RecknZkEscrow` only*. **That sentence becomes false in this commit** and is corrected
  with it — AC-14(i) literal 9 is the check that it did not survive.

#### The region and the stripper

Check 5's region is **the whole file**, comments stripped with the same idiom check 1–4 already
use on the escrow (`no-keys.sh:29-30`). That stripper is line-based and quote-blind, which is a
real limitation in general and **not** one here, because 5a closes both of its blind spots for
this file rather than assuming they are absent.

#### The five properties (this is not a list of forbidden constructs)

`003`'s **R-7** is the rule: *a hole in an enforcement script is never closed by adding the name
of the construct that exploited it.* So check 5 does **not** grep for `tx.origin`, `msg.sender`,
`block.`, `if`, `assembly` or `delegatecall`. It states what the file is **permitted** to contain
and rejects everything else, so those six and every unlisted sibling — `blockhash`, `gasleft`,
`chainid`, `selfdestruct`, `staticcall`, `create2`, a ternary, a second `return`, a modifier, a
`fallback`, a `receive`, a free function, a second contract — fail **together and for the same
reason**. Each of the five values below is a **literal of this specification, measured on
2026-09-04 and transcribed here**, not a value the implementer generates from the file: the
implementer must not both author the pin and be bound by it (the discipline of r2 finding 6,
AC-0b).

**5a — the region is literal, so the stripper is exact.**
(i) The raw file contains **zero** occurrences of `/*` and **zero** of `*/` (measured today: 0 and
0), so the stripper's inability to span lines cannot hide anything.
(ii) After stripping, **exactly one** line contains a `"` or `'`, and that line is, after
whitespace normalisation, exactly

```
import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";
```

*What this closes:* every construct that needs a string or character literal —
`require(x, "…")`, `revert("…")`, a `string` field, a second import, an inline comment smuggled
into a string. And it is what makes 5b's tokenizer sound: 5b removes the one quoted span before
tokenizing, and 5a is the proof there is exactly one.

**5b — the identifier vocabulary is closed. This is the property that carries the check.**
Strip comments, remove the one quoted span, tokenize with `[A-Za-z_$][A-Za-z0-9_$]*`, sort
unique. The result must equal **exactly** this 43-element set:

```
FAILED ISP1Verifier REPRODUCED RecknVerdictVerifier VerdictPublicValues
_verdictProgramVKey _verifier abi address bytes bytes32 calldata constant constructor
contract dealBinding decode from function immutable import maxDelta memory minDelta
outcome post pragma pre proofBytes public publicValues returns solidity struct traceHash
uint256 uint8 v verdictProgramVKey verifier verifyProof verifyVerdict view
```

Measured today the file yields the same 43 tokens with `uint64` in place of `uint256`; §3.4's
edit is the only difference, and it is the only difference permitted. **Equality in both
directions is required** — a missing token fails as loudly as an extra one, so deleting the
`verifyProof` call fails here too.

*What this closes, without naming any of it:* every environment read (`tx`, `msg`, `block`,
`blockhash`, `gasleft`, `origin`, `sender`, `chainid`, `this`), every control-flow keyword
(`if`, `else`, `for`, `while`, `do`, `try`, `catch`, `assembly`, `unchecked`), every low-level
escape (`delegatecall`, `call`, `staticcall`, `selfdestruct`, `create`, `create2`, `sstore`),
every added declaration (`owner`, `admin`, `mapping`, `modifier`, `fallback`, `receive`,
`library`, `interface`, `event`, `error`, `enum`), every hex address constant (`0x…1337`
tokenizes as `x…1337`), and every new local name. Measured against the pinned set: the r4 splice introduces `if`, `tx`,
`origin`, `x0000000000000000000000000000000000001337` and `return` — **five tokens outside the
set, and one outside is enough.** (`return` is outside because today's `verifyVerdict` uses a
**named return** `v` and has no `return` statement; that is a fact about this file, not a general
Solidity claim.)

**5c — the declared surface is closed, by count.** In the stripped file: exactly **1** `pragma`,
**1** `import`, **1** `struct`, **1** `contract`, **1** `constructor`, **1** `function` — and
the `function` keyword's identifier is `verifyVerdict` — **2** `constant`, **2** `immutable`.
5b already forbids a second *kind* of declaration; 5c forbids a second *instance* of a permitted
kind, which 5b (a set, not a multiset) cannot see. A second `function verifyVerdict` overload, or
a second `contract`, dies here.

**5d — `verifyVerdict`'s body is two statements of pinned form.** Between the `{` that opens the
function body and its matching `}`, the stripped text contains exactly **2** `;`, and the two
statements, whitespace-normalised, are exactly

```
ISP1Verifier(verifier).verifyProof(verdictProgramVKey, publicValues, proofBytes);
v = abi.decode(publicValues, (VerdictPublicValues));
```

in that order. *What this closes:* a third statement (`v.outcome = REPRODUCED;` uses no token
outside 5b's set and would survive 5b), a reordering that decodes before verifying, a dropped
`verifyProof` call, and any branch — a branch needs either a control-flow token (5b) or an extra
statement (5d), and there is no third way to leave a function early in Solidity.

**5e — assignment targets are closed.** Over the whole stripped file, every `=` that is not part
of `==`, `!=`, `<=`, `>=` or `=>` has a left-hand side drawn from exactly this 5-element set —
the file's own declared names, and no field, index or member of any of them:

```
REPRODUCED   FAILED   verifier   verdictProgramVKey   v
```

and the total number of such assignments is exactly **5** (measured today at
`RecknVerdictVerifier.sol:34, :35, :43, :44, :56`). This is check 4's construction
(`no-keys.sh:66`) generalised from one constructor to one file. *What this closes:* writing a
field of the returned struct after the decode (`v.outcome = …`, `v.dealBinding = …` — the exact
two lines of the r4 splice), writing a new state variable, and writing through an index.

#### What check 5 does **not** establish (R-10, §8)

Written here so nobody reads the check as more than it is, and repeated in §8 because it is a
residual of the product and not only of the gate:

1. **It is a check on source, not on bytecode.** A tree whose source satisfies check 5 can still
   be *deployed* from different bytecode. 008's tier is local (§6) and 008 deploys nothing, so
   008 makes no deployment claim at all. The on-chain half is `003`'s.
2. **It says nothing about the address `verifier` is set to.** `verifyProof` is dispatched to
   whatever the constructor was given, and check 5 constrains the *shape* of the constructor's
   two assignments, not the value of the argument. A verifier constructed against a lying
   `ISP1Verifier` is not detected here. Closing that is `003`'s extension (§1.3) and 008 does not
   pre-empt it.
3. **It says nothing about `ISP1Verifier`'s own source**, which is a vendored dependency and
   outside every file 008 reads.
4. **It is a lexical check.** It rejects a *syntactic* class. Two files that both satisfy it
   compute the same thing only because 5b + 5d pin the body to two statements; there is no
   semantic analysis anywhere in `no-keys.sh` and 008 does not add one.

#### Stop rule

**If 008's edit to `RecknVerdictVerifier.sol` cannot be expressed inside 5a–5e as written above,
stop and report** (`AGENTS.md` §7). Do not loosen a property to fit the edit, do not add a token
to 5b's set, and do not raise a count in 5c/5d/5e. The pinned values are literals of this
specification; changing one is a change to what the central claim asserts, which is §9(2a)'s
declaration and, if it is a *loosening*, a founder call (OQ-6).

### AC-0 — the central claim still holds (fixed text, `reckn-spec` charter)

```sh
bash scripts/no-keys.sh                      # exit 0
bash zk-verdict/scripts/ac008.sh AC-00       # same command, via the manifest
```

008 adds **no** external or public function to any contract. The enumerated **function** surface
(`fund` / `settleWithProof` / `refundAfterDeadline`) is unchanged (N-7).

**What changed this round, stated because the claim moved** (`reckn-spec` charter; `AGENTS.md`
§0's "主張がどう変わったか"). Through round 4 the build condition read **one** file. It now reads
**two**, because 008 edits the second one and the second one is on the settlement-authority path
(§6.4, r4 BLOCKER). The claim before and after:

| | before 008 | after 008 |
|---|---|---|
| what is asserted | *no privileged role exists in `RecknZkEscrow`* | *no privileged role exists in `RecknZkEscrow`, **and** the contract that computes the verdict `RecknZkEscrow` obeys contains no branch, no environment read and no post-decode write — so the struct it returns is a function of the proof alone* (INV-15) |
| files read | `zk-verdict/contracts/src/RecknZkEscrow.sol` | that file **and** `zk-verdict/contracts/src/RecknVerdictVerifier.sol` |
| numbered checks | 4 | **5** |
| final line | `✓ the claim holds: no key can move a funded escrow.` | **unchanged** |
| interface | no argument, no environment variable, root from `$(dirname "$0")` | **unchanged** |

**This is a tightening, in both senses that matter.** The set of trees the script accepts strictly
shrinks — nothing previously rejected is now accepted — and no function surface widens. It is
still a change to what the central claim asserts, so it is declared in the same commit in
`AGENTS.md` §0 and `CLAUDE.md` (§9(2a), §9(2b)) and in the script's own header (§9(2c)), and it is
recorded as **OQ-6 — ruled**, with the note that **relaxing check 5 later is a founder decision,
not an implementer's fix**. What is *orthogonal* to the claim, and stated in §9(1), is the other
half of 008: it removes a way for **a proof** to move a funded escrow wrongly.

Run today at the base commit, verbatim tail:
`✓ the claim holds: no key can move a funded escrow.` `EXIT=0`. After 008 the tail is the same
line and the script prints one more section above it.

**Falsify (three, each one command):**
1. add `address public owner;` to `contract RecknZkEscrow` → checks 1–2 fail.
2. splice the r4 branch of §6.4 into `verifyVerdict` → **check 5 fails at 5b** (`if`, `tx`,
   `origin` and the hex constant are outside the pinned vocabulary) **and at 5d** (four
   statements, not two) **and at 5e** (`v.outcome` is not a permitted assignment target). Three
   independent clauses reject it; that redundancy is the point of stating properties rather than
   names. **Mutant M-17** is the machine-run version, and it runs in a **sandbox**: the
   repository's `no-keys.sh` and `RecknVerdictVerifier.sol` are never written (AC-13, mode
   `sandbox`, phase 17).
3. delete the `ISP1Verifier(verifier).verifyProof(...)` statement from `verifyVerdict` — the
   quietest possible break, since the function still compiles, still takes the same arguments and
   still returns a decoded struct → **5b fails** and **5d fails** (one statement, not two).
   Note what 5b actually loses here: **exactly one token, `verifyProof`**. `ISP1Verifier` survives
   in the import, `proofBytes` survives as a parameter name and `verdictProgramVKey` survives as a
   state variable — which is precisely why 5b's equality must hold in **both** directions and why
   5d exists beside it. A check that only forbade *additions* would pass this.

### AC-0b — `RecknZkEscrow.sol` was not touched, and `reexec-evm`'s production surface was not touched

```sh
bash zk-verdict/scripts/surfaces.sh
# surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged; witness=<16 hex>
```

**The two pinned values are literals of this specification, not measurements of whatever the
files happen to contain** (r2 finding 6). Round 2 put `surfaces.pinned` in §7.1's *new files*
list and never stated its contents, so 008's implementer would have both **created the pin and
been bound by it**: edit `RecknZkEscrow.sol`, then generate the pin from the edited file, and
AC-0b passes while N-1 ("not one byte") is violated. `no-keys.sh` would still catch an added
*key*, but not a changed `transferFrom`, a changed event or a changed `require`.

`zk-verdict/scripts/surfaces.pinned` is a **two-line text file** and it must contain exactly
these two values, transcribed from here:

```
RecknZkEscrow.sol       07d649c2808457f78f9371c96966abdd80a82636171a15e77516c0f5df33e45b
reexec-evm-prefix-710   b4fd62d5b728c704a67ee8aaed463ac186859db079451fc83c47dd3ae5ab29d1
```

Both were measured on **2026-09-04** at the 008 base commit and independently reproduced by the
r2 reviewer. Reproduce them with:

```sh
shasum -a 256 zk-verdict/contracts/src/RecknZkEscrow.sol
head -710 reexec-evm/src/lib.rs | shasum -a 256
```

**The prefix rule is exclusive and stated as a command, because "above the line" was ambiguous
and the two readings give different digests.** The range is **lines 1..=710**, i.e.
`head -710 | shasum -a 256`; **line 711 itself is excluded**. `surfaces.sh` must additionally
assert that line 711 of `reexec-evm/src/lib.rs` is still exactly
`#[cfg(any(test, feature = "testkit"))]` and that it is the **only** occurrence of that string in
the file (both verified today). Without that assertion, inserting a line above 711 would shift
the boundary and the digest would silently cover a different range — the ambiguity would come back
as a wrong answer instead of a failure.

`008` may add testkit builders freely: they live **below** line 711, so the prefix digest does not
move. Anything 008 adds **above** 711 fails AC-0b, which is exactly N-3.

**Location rule — `surfaces.sh` finds its four inputs from its own path and from nothing else**
(r3 finding 1, requirement 1; **this is what makes M-8's sandbox work at all**, and it was
unwritten through round 3). The script's first two effective lines are the shape
`scripts/no-keys.sh:17-19` already uses, adjusted for one more directory of depth:

```sh
here=$(cd "$(dirname "$0")" && pwd)          # …/zk-verdict/scripts
root=$(cd "$here/../.." && pwd)              # repository root, derived, never given
```

and every path below is `"$root/…"`. Four things are **forbidden**, each because it would make
the sandbox inert while the script still passes in the repository:

- **no target/root argument** (`$1`), and no default that a caller can override;
- **no environment override** (`RECKN_ROOT`, `REPO_ROOT`, or any other variable);
- **no absolute path anywhere in the file** — a burned `/Users/…` reads the real file from
  inside `$S` and the mutated copy is never opened;
- **no `git rev-parse --show-toplevel`** and no other git-derived root. This one is the trap
  worth naming: `$S` is not a git repository, so `git rev-parse --show-toplevel` run from
  inside it **walks upward and finds the real repository**, and the sandbox silently becomes a
  second run against the unmutated tree — which is a false "not detected", the safe direction,
  but it is a false answer either way.

The same rule holds for `surfaces.pinned`: it is read as `"$root/zk-verdict/scripts/surfaces.pinned"`,
so the sandbox's copy is the one compared against. `surfaces.sh` must also work from **any**
current directory (`cd /tmp && bash "$S/zk-verdict/scripts/surfaces.sh"` must behave identically),
because AC-13 runs it that way.

**Two further requirements, stated as requirements rather than as prose in this paragraph**
(r4 finding 2, parts i and iii). Round 4 described both of these in passing and neither was
something an implementation could be held to.

- **R5 — `surfaces.sh` reads `$root/zk-verdict/scripts/surfaces.pinned` and compares the two
  values it computes against the two values it read from that file.** It does **not** carry
  either digest as a literal in its own text. A script with the pins in a heredoc satisfies every
  other requirement here, passes on the clean tree, and makes `003`'s re-pin protocol (§1.3) inert
  — the only thing then tying the tree to the base commit is a constant the implementer wrote.
  **No mutant covers R5.** The obvious mutant — flip a byte of `surfaces.pinned` and require the
  script to fail — is the design the founder ruled against in OQ-5 (b), and this round does not
  re-open it: it makes *every* implementation fail, including one that digests the wrong file, so
  it tests the comparison and not the binding. **R5 is therefore verified by reading**, and it is
  named in **§7.8(d)** as one of the four properties the stage=impl review must check by reading
  the script. That is a weaker instrument than a mutant and it is written as such rather than
  presented as a check.
- **R6 — the failure output is machine-checkable, per clause.** On **any** failure `surfaces.sh`
  prints, for the clause that failed, one line of the form

  ```
  <clause-name>   pinned: <64 lowercase hex>   computed: <64 lowercase hex>
  ```

  with `<clause-name>` ∈ {`RecknZkEscrow.sol`, `reexec-evm-prefix-710`} — the same two names
  `surfaces.pinned` uses — and **full 64-character digests, not the 16-hex `witness=` prefix**.
  Two things depend on this. (1) `003`'s re-pin is a copy of a printed value (§1.3). (2) **AC-13
  steps 8g and 18g assert that the printed `computed:` value equals the digest the *selftest*
  computes over the mutated copy**, which is what kills a `surfaces.sh` that never runs `shasum`
  at all — see AC-13, mode `sandbox`.

**Where 008's testkit builders go, exactly** (r3 finding 7). The builders of §3.6 go **inside**
the existing `#[cfg(any(test, feature = "testkit"))] pub mod testkit` block, i.e. **below**
line 711. Two edits that N-3 explicitly permits would nevertheless fail AC-0b, and neither
is a violation of anything:

- **the block's own doc comment is inside the pinned prefix.** `reexec-evm/src/lib.rs:708-710`
  is the doc comment attached to the testkit module, and `head -710` covers it. Editing it —
  e.g. to mention the new builders — moves the prefix digest and AC-0b fails. **Do not edit it**;
  document the builders inside the block instead.
- **a second `#[cfg(any(test, feature = "testkit"))]` is forbidden.** The uniqueness assertion
  above requires exactly one occurrence in the file, so opening a second gated block (for a
  second builder module, say) fails AC-0b. **Put everything in the one block.**

Both failures are **loud** — the script prints `pinned:` / `computed:`, or names the line whose
content is no longer the `#[cfg]` marker — so this is a usability trap being removed rather than
a hole being closed. It is written down because 008 is the head of the execution order and an
implementer should not discover a build condition by tripping it.

**On failure the script prints both digests**, labelled `pinned:` and `computed:`, in the exact
form R6 fixes above, so the re-pin `003` must perform (§1.3) is a copy of a printed value and
lands as a readable one-line diff. `surfaces.pinned` is a two-line text file, not a generated
blob.

(b) covers `replay` and the production API. It does **not** cover the testkit, `header.rs` or
`reexec-evm/Cargo.toml` — that is AC-16's job, and round 1 claimed (b) plus AC-15 "is the
whole of N-3" when it was not (r1 finding 6).

**Falsify:** change any byte of `RecknZkEscrow.sol`, or move a single line of `replay`.
**Mutant M-8** is the machine-run version of the **first** clause: it flips one byte of a
*comment* in `RecknZkEscrow.sol` — a change no compiler, no test and `no-keys.sh` would notice —
and this row must go non-zero. **Mutant M-18** is the machine-run version of the **second**
clause: it flips one byte of a comment **above line 711** of `reexec-evm/src/lib.rs`, a change no
compiler, no test, AC-15 and AC-16 would notice, and this row must go non-zero. *(Round 4 had no
mutant for the second clause at all — M-16 is deliberately below 711 so that AC-0b does **not**
move — so the clause protecting the differential's oracle was verified by nothing. r4 finding 2.)* **M-8 is applied to a sandbox copy of the layout and never to the
repository's file** (AC-13, "M-8 — sandbox mode"; §10 OQ-5, ruled 2026-09-04), which is why N-1
says "not one byte, in any state, at any moment" with no exception, and why the Location rule
above is a requirement of this AC rather than an implementation detail.

**The two degenerate implementations M-8 and M-18 exist to kill, stated so the sandbox's
necessity is checkable.**

- **The fully degenerate one.** A `surfaces.sh` that prints the two pinned literals from a heredoc
  and the correct `witness=` value and **never opens either file** satisfies AC-00b, satisfies
  `ac008.sh --all`, and guards the central claim not at all. Under M-8's sandbox it exits **0** on
  the mutated copy, AC-13 records a miss, and AC-13 fails. That is the whole reason the mutant
  must land on a *file the script is supposed to read*, and the reason option (b) of OQ-5 was
  rejected.
- **The half-degenerate one, which round 4 did not name and M-8 alone does not kill**
  (r4 finding 2). A script that derives `root` correctly, then does
  `grep -q '<the exact comment text M-8 flips>' "$target"` and on success prints the whole
  evidence line with a hardcoded `witness=`, obeys the Location rule, passes the clean control
  (8d), **exits non-zero at 8g** — and is therefore scored as *"M-8 detected"* — while never
  running `shasum`, never opening `surfaces.pinned`, and never opening `reexec-evm/src/lib.rs`.
  Two additions kill it. **(i)** Step **8g** requires the script to print
  `computed: <64 hex>` and requires that value to equal the digest the **selftest itself**
  computes over the mutated copy; a `grep` cannot produce it. **(ii)** **M-18** mutates the
  sandbox's copy of `reexec-evm/src/lib.rs` **above line 711**, so AC-0b's *second* clause — which
  is the guard on `reexec-evm::replay`, **the oracle INV-1 compares the guest against** — has a
  mutant for the first time. A script that only greps the contract exits **0** at 18g and is a
  miss.

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

**One convention for the `guest today` column, stated once** (r2 finding 7). Today's
`DeltaCheck.min` / `.max` are `u64` (`zk-verdict/reexec-io/src/lib.rs:53-58`), so a `U256`
`min`/`max` at or above `2^64` **cannot be supplied to today's guest at all**. The column
therefore reads such a value as saturating to `u64::MAX`, and every cell that depends on that
reading is marked **†**. Round 2 had no convention: V-13 was annotated *"impossible"* while
V-08's `min = U256::MAX − 1` and V-03's / V-11's `max = U256::MAX` were silently saturated. One
rule, applied everywhere, is the only way the column can be checked by hand.

| id | `pre` | `post` (calldata word) | `min` | `max` | true delta | expected | guest **today** |
|---|---|---|---|---|---|---|---|
| V-01 | 42 | 142 | 100 | `U256::MAX` | 100 | `Reproduced` | agrees (regression guard) |
| V-02 | 42 | 42 | 1 | `U256::MAX` | 0 | `Failed` | agrees (no-op control) |
| V-03 | `2^64` | `2^64−1` | 1 | `U256::MAX` † | 0 | **`Failed`** | `Reproduced` — **the false release** |
| V-04 | 1 | `2^64` | `2^64−1` | `U256::MAX` † | `2^64−1` | **`Reproduced`** | `Failed` — false refund |
| V-05 | `2^64−1` | `2^64` | 1 | `U256::MAX` † | 1 | **`Reproduced`** | `Failed` |
| V-06 | `2^64−1` | `2^64−1` | 1 | `U256::MAX` † | 0 | `Failed` | agrees |
| V-07 | `2^64` | `2^64` | 0 | 0 | 0 | `Reproduced` | agrees |
| V-08 | 1 | `U256::MAX` | `U256::MAX−1` † | `U256::MAX` † | `U256::MAX−1` | **`Reproduced`** | `Failed` (limb 0 delta `u64::MAX−1` < `min` read as `u64::MAX`) |
| V-09 | `U256::MAX` | 1 | 1 | `U256::MAX` † | 0 | `Failed` | agrees (by luck) |
| V-10 | `2^128` | `2^128+1` | 1 | 1 | 1 | `Reproduced` | **agrees** — limb 0 is `0 → 1`, so `sat_sub = 1 ∈ [1,1]`. *(Round 2 wrote `Failed` here. Recomputed: the guest is right today by accident. The vector stays — it is the only probe of limb 2 — but it is a **positive control**, not a defect the current guest exhibits, and calling it a defect overstated the table in the flattering direction, which `AGENTS.md` §5 names.)* |
| V-11 | `2^192` | `2^192−1` | 1 | `U256::MAX` † | 0 | **`Failed`** | `Reproduced` — **false release at limb 3**. Also the **only** vector above `2^128`, which is why **mutant M-6** (truncate at 128 bits instead of 64) exists: without it, an implementation that truncates at 128 bits is caught by one vector body and by nothing else. |
| V-12 | `u64::MAX` | `u64::MAX + 10^18` | `10^18` | `U256::MAX` † | `10^18` | **`Reproduced`** | `Failed` — **the `002` case** (limb 0 of `post` is `10^18 − 1`, below `pre`, so `sat_sub = 0`) |
| V-13 | 1 | `20·10^18` | `20·10^18 − 1` † | `U256::MAX` † | `20·10^18 − 1` | **`Reproduced`** | `Failed` † — limb 0 of `post` is `1_553_255_926_290_448_384`, so the credited delta reads as `1_553_255_926_290_448_383` against a `min` read as `u64::MAX`. *(Round 2 wrote "impossible"; under the stated convention it is computable, and it is a false refund of the exact shape `002` needs.)* |
| V-14 | **0, via a storage exclusion proof** | `10^18` | `10^18` | `U256::MAX` † | `10^18` | `Reproduced` | agrees (both below `2^64`) — the zero-balance recipient `002` needs |

**†** — `min` or `max` at or above `2^64`; the `guest today` cell uses the saturating reading
defined above the table. Nine of the fourteen vectors carry a `†`, which is itself the point:
today's `DeltaCheck` cannot express most of this table's predicates.

Recomputed in round 3 under that convention, today's guest **disagrees** with `expected` on
**seven** vectors — V-03, V-04, V-05, V-08, V-11, V-12, V-13 — and **agrees** on the other seven
— V-01, V-02, V-06, V-07, V-09, V-10, V-14. 7 + 7 = 14. Round 2's column claimed eight
disagreements: it had V-10 wrong (the guest agrees) and V-13 unlabelled. The correction moves in
the **unflattering** direction for this task, which is the direction `AGENTS.md` §5 says to
expect the errors *not* to go, so it is recorded rather than quietly fixed.

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
default); or apply the env but omit `disable_nonce_check` (E-10 fails). **Mutant M-5** is the
machine-run version of the first clause, and it is the single most important addition of round 3:
before it, axis 2 of the defect this task exists to close had thirteen test bodies and **no**
mutant, so thirteen tautologies would have passed the whole gate (r2 BLOCKER 2).

### AC-4 — the input domain is closed, and enforced at one place

```sh
bash zk-verdict/scripts/ac008.sh AC-04     # cargo, zk-verdict/script, _AC04_, 13 tests
```

Round 1 had three vectors and called this "the guest's database is closed over the witness".
It is that, **and** the domain gate (§3.6), **and** the in-guest half of the domain gate that
round 2 left on the host (P-12). r1 findings 4, 5, 9 and r2 finding 1 are all here.

**Round 3 audited the whole face rather than the one hole the review named.** r2 BLOCKER 1 was
"a new `NoProof` transition with no in-guest enforcement". Asking the same question of every
row of §4.1 found that **four more new transitions had no vector at all** — P-7, P-8, P-9, and
(once it existed) P-12. A transition declared in a table and tested by nothing is r2 finding 3's
defect ("a name exists, no body") one layer down, so all five are closed together. AC-4 goes
8 → 13.

| id | input | off-chain | required |
|---|---|---|---|
| W-01 | `60 08 54 60 07 55 00` — `SLOAD(8)` then `SSTORE(7)`; slot 8 is **not** in the witness | `Err(MissingStorageWitness)` | SP1 `execute()` returns `Err` — **no verdict exists**. Not a `Failed` verdict (§3.6.3). |
| W-02 | `73 <20-byte un-witnessed addr> 31 60 07 55 00` — `BALANCE` of an un-witnessed account | `Err(MissingAccountWitness)` | `execute()` returns `Err` |
| W-03 | `60 07 54 60 07 55 00` — `SLOAD(7)` then `SSTORE(7)`; slot 7 **is** witnessed; `min = max = 0` | `Reproduced` (post = pre = 42, delta 0) | `Reproduced` — the positive control that W-01/W-02 fail for the missing-witness reason and not because any `SLOAD` panics |
| **W-04** | caller account with `storage_root = EMPTY_ROOT_HASH` carrying `StorageWitnessV1 { slot, value: 0, proof: vec![] }` | `Err(InvalidWitness(EmptyStorageProof{..}))` (`reexec-evm/src/lib.rs:352-357`) | `execute()` returns `Err` (**P-11**). **Today the guest returns `Ok` and proves a verdict** — `alloy-trie-0.9.5/src/proof/verify.rs:29-43` accepts an empty proof for `EMPTY_ROOT_HASH` with `expected_value = None`, which `main.rs:67-72` passes for a zero value. This is the live divergence of r1 finding 4. |
| **W-05** | any witnessed account with `account_proof: vec![]` | `Err(InvalidWitness(EmptyAccountProof{..}))` (`:310`) | `execute()` returns `Err` (**P-10**). **Both sides already refuse today**, because the guest passes `Some(rlp(account))` and `verify_proof` cannot return `Ok`. P-10 makes the reason match; this vector records the agreement and catches a future guest that stops passing `Some(...)`. |
| **W-06** | a witness containing an account at `0x00…01` (`ecrecover`) with a valid inclusion proof and non-zero balance; plan CALLs it | *(no `GuestInput` is built)* | `to_guest_input(...)` returns `Err(OutOfDomain::DivergentPrecompileAddress([0;19] ++ [1]))`. **G-2.** Today nothing rejects this and the plan enters a backend pair whose equivalence §8 R-3 declares untested (r1 finding 9). |
| **W-07** | `0x00…01` **not** in the witness; plan CALLs it | `Err(MissingAccountWitness{address: 0x…01})` | `execute()` returns `Err`. The complementary half of the Δ argument: `db.basic` runs for a precompile address (`revm-context-16.0.1/src/journal/inner.rs:920-927`), so the closed DB refuses on **both** sides — this case is **inside D** and INV-2 holds. Note that W-06 and W-07 together are **not** the whole argument: W-06 is a property of a host function a prover can skip. **W-09 is the vector that closes it.** |
| **W-08** | a valid witness under an anchor with `block_header = Some(header)` that correctly binds `state_root` | `Reproduced` (`replay` verifies the header and proceeds, `reexec-evm/src/lib.rs:460-463`) | `to_guest_input(...)` returns `Err(OutOfDomain::AnchorCarriesBlockHeader)`. **G-1.** Today the field is silently dropped, so the guest proves a verdict about an anchor whose header layer it never checked (r1 finding 5). The test must also assert the **negative** case: with `block_header = None` and everything else equal, `to_guest_input` returns `Ok` — otherwise a gate that always refuses passes. |
| **W-09** | **W-06's input, but the `GuestInput` is built by struct literal and written straight to the ELF's stdin — `to_guest_input` is never called.** Construct it exactly as `zk-verdict/script/src/bin/reexec.rs:123` does and `stdin.write(&input)` as `:166` does. | *(nothing is called off-chain; this vector is about the guest alone)* | SP1 `execute()` returns `Err` — **P-12**. **This is r2 BLOCKER 1.** Under the round-2 specification the guest had *no rejection to make*: W-06 asserted a property of a **host function**, and a prover who skips that function loses nothing. The test must also assert the **control**: the identical hand-built input with `0x00…01` replaced by a non-Δ witnessed account returns `Ok` **and a verdict**, so that a guest which panics on everything does not pass. |
| **W-10** | `to_guest_input(anchor, witness, plan, predicate)` for three predicates: (a) `PostStateDelta { checks: vec![c1, c2] }`, (b) `PredicateV1::ResultEquals{..}`, (c) the control `PostStateDelta { checks: vec![c1] }` | `replay` accepts **all three** and returns a verdict — which is why this is a *domain* restriction and not a claim that multi-check predicates are invalid | (a) and (b) return `Err(OutOfDomain::PredicateIsNotSingleDeltaCheck)`; (c) returns `Ok`. **G-3.** Round 2 declared the variant and passed the gate an already-extracted `check` tuple, so the variant was **unconstructible and untested** (r2 finding 3). One `#[test]` covering the three cases. |
| **W-11** | a **hand-built** `GuestInput` with `env.spec_id = 0xff` | *(not reachable off-chain — `reexec-evm` takes a typed `SpecId`)* | `execute()` returns `Err` — **P-9**. Plus the control: the same input with the `CANCUN` byte returns `Ok`. Round 2 declared P-9, argued correctly that it is reachable only through a hand-built `GuestInput`, and then gave it **no test** — the same shape as the P-12 hole, in the same table. |
| **W-12** | target runtime `43 60 01 90 03 40 60 07 55 00` — `NUMBER; PUSH1 1; SWAP1; SUB; BLOCKHASH; PUSH1 7; SSTORE; STOP` — under `block_number = 19_000_007`, i.e. `BLOCKHASH(n−1)` | `Err(MissingBlockHashWitness{number: 19_000_006})` (`reexec-evm/src/lib.rs:440-442`) | `execute()` returns `Err` — **P-7**. **The `n−1` form is load-bearing:** `revm-interpreter-35.0.1/src/instructions/host.rs:163-192` returns `U256::ZERO` **without consulting the database** when `diff == 0` or `diff > BLOCK_HASH_HISTORY`, so the obvious `PUSH1 0` form (block 0, diff ≈ 19M) never reaches either database and would pass for the wrong reason on both sides. At `diff == 1` the host calls `block_hash`, `None` becomes `halt_fatal()`, and the guest must classify the resulting error as a **database** error (a panic, §3.6.3) and **not** as a `Failed` verdict. A `HaltReason` reaching the verdict path as `Failed` is exactly the regression this vector catches. |
| **W-13** | `check.address = target`, `check.slot = 9`, and slot 9 is **not** in the witness (slot 7 is) | `Err(MissingPredicateWitness)` (`reexec-evm/src/lib.rs:482-486`) | `execute()` returns `Err` — **P-8**. The checked slot is read to obtain `pre` before any execution, so this fires at input-processing time and is independent of what the plan touches. |

**Which `NoProof` transition each vector covers — the whole of §4.1, so a future round does not
have to re-derive it:**

| transition | vector | |
|---|---|---|
| P-1 account MPT proof invalid | — | **pre-existing** in `verify_prestate_authenticity`; 008 does not change it and adds no vector. Stated, not implied — see §7.6 **L-1**. |
| P-2 storage MPT proof invalid | — | same |
| P-3 `keccak(code) != code_hash` | — | same |
| P-4 duplicate account / slot | — | same |
| P-5 unwitnessed account read | **W-02**, and **W-07** for the Δ case | |
| P-6 unwitnessed slot read | **W-01** | |
| P-7 `BLOCKHASH` | **W-12** | new in round 3 |
| P-8 checked `(address, slot)` unwitnessed | **W-13** | new in round 3 |
| P-9 unknown `spec_id` byte | **W-11** | new in round 3 |
| P-10 empty account proof | **W-05** | |
| P-11 empty storage proof | **W-04** | |
| P-12 Δ address in `accounts` or `plan.target` | **W-09** | new in round 3 |
| positive control (a verdict *does* exist) | **W-03**, plus the controls inside W-08, W-09, W-10, W-11 | |

Five controls are load-bearing and are called out because a gate that refuses everything passes
every refusal test: **W-03** (a witnessed `SLOAD` still produces `Reproduced`), and the `Ok`
halves of **W-08**, **W-09**, **W-10**, **W-11**.

**Falsify:** keep `InMemoryDB::default()` (`main.rs:102`) — W-01, W-02, W-07, W-12 and W-13
produce a verdict where none may exist. Or make `to_guest_input` infallible — W-06, W-08 and W-10
fail to compile, then fail. Or put the Δ check **only** in `to_guest_input`, which is what round 2
specified — **W-09 fails and nothing else does**, which is precisely why W-09 exists. **Mutant
M-3** is the machine-run version of the first sentence.

### AC-6 — no truncation survives, and the two engines' constants are pinned by text

```sh
bash zk-verdict/scripts/env-parity.sh
# env-parity: 5/5 truncation patterns absent; 4/4 cfg flags pinned on both sides; 0 rest patterns in to_guest_input; TxEnv fields identical (7); witness=<16 hex>
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

One `#[test]` per bound component. Each takes a baseline `GuestInput`, changes **exactly one
bound** component to a different value, runs the real ELF through `execute()` twice, and asserts
the two committed `dealBinding` values differ:

`state_root`, `chain_id`, `spec_id`, `block_number`, `timestamp`, `base_fee`,
`block_gas_limit`, `coinbase`, `prevrandao`, `check.address`, `check.slot`, `check.min`,
`check.max`, `plan.caller`, `plan.target`, `plan.value`, `plan.gas_limit`, `plan.calldata`.

Eighteen components; the manifest's `tests` column says 18. Anything else in `GuestInput` —
the accounts and their proofs — is bound transitively through `state_root` (INV-5), which
P-1…P-4 and P-10/P-11 make unforgeable.

**"Exactly one **bound** component", not "exactly one component"** (r2 finding 5). Round 2's
recipe cannot be executed for six of the eighteen, because **the guest authenticates and closes
its database before it commits anything**: `program-revm/src/main.rs:95-99` reads the input and
immediately runs `verify_prestate_authenticity`, and `dealBinding` is built far below at
`:176-190`. A variant execution that panics yields **no second `dealBinding` to compare**. The
six, and what each needs:

| component | why the naive variant panics | what the test must do instead |
|---|---|---|
| `state_root` | every account proof now fails `verify_proof` → `RootMismatch` → **P-1** | build a **second, internally consistent prestate** — the same `PrestateSpec` with `slot7 = Value(43)` instead of `Value(42)` — so the root moves *with* a valid witness. This still isolates `state_root`, because `env_hash`, `check_hash` and `plan_hash` are unchanged and `state_root` is the only other input to the binding (§3.5). Both executions must succeed; their verdicts may differ, which is irrelevant — only the bindings are compared. |
| `plan.caller` | the variant caller is not in the witness → **P-5** | the **baseline witness must contain both** callers (`PrestateSpec::extra_accounts`), and the variant caller needs a balance ≥ `plan.value` |
| `plan.target` | same → **P-5** | baseline witness contains both targets, the variant one with the same runtime code, so the execution still runs |
| `coinbase` | revm credits the beneficiary even at `gas_price = 0` → **P-5** | baseline witness contains **both** coinbase accounts. §3.6 already discovered this for AC-3's E-05 and round 2 did not carry the lesson one section down; this is the same fact, third occurrence. |
| `check.address` | the variant `(address, slot)` is not in the witness → **P-8** | baseline witness contains both addresses |
| `check.slot` | same → **P-8** | baseline witness contains **both slots** (7 and 9) for the checked account — `PrestateSpec` gains `extra_slots: Vec<(Address, U256, U256)>` for this |

The other twelve need only that the variant value keep the execution legal, which is a smaller
constraint but still one the implementer should not discover at runtime:

- `spec_id`: `CANCUN → PRAGUE`. Both accept `PUSH0`, so `SSTORE_SLOT7_RUNTIME` runs under both.
- `block_gas_limit`: variant must stay ≥ `plan.gas_limit`.
- `plan.gas_limit`: variant must stay ≥ the execution's actual cost.
- `plan.value`: variant must stay ≤ the caller's witnessed balance.
- `base_fee`, `timestamp`, `block_number`, `prevrandao`, `chain_id`, `check.min`, `check.max`,
  `plan.calldata`: unconstrained — `disable_base_fee` and `disable_nonce_check` are on, and the
  runtime reads none of them except through the calldata word it stores.

**The general rule this makes explicit:** a binding-difference test is a claim about the
*commitment function*, so both executions must reach the commitment. Any component whose variant
value leaves the witness must have that value witnessed in the baseline.

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
`vm.expectRevert` fails. **Mutant M-13** is the machine-run version: it writes the headline
fixture's own `dealBinding` into `alt-binding.json`.

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
directly — every test fails. **Mutant M-14** is the machine-run version of the first sentence.

### AC-9 — the committed fixtures are the current guests'

```sh
bash zk-verdict/scripts/fixtures-check.sh
# fixtures: 4/4 current (vkey and public values byte-identical); witness=<16 hex>
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
**Mutant M-10** is the machine-run version, and it is the one that stops this row from being an
`echo`: it flips one hex byte of the headline fixture's `vkey`, so a stubbed `fixtures-check.sh`
keeps printing `4/4` and the row must go non-zero — it cannot (§6.2).

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
reverts on dirty high bits. **Mutant M-15** covers the other half — swapping the `REPRODUCED` /
`FAILED` constants makes tests 2 and 3 pay the wrong party — because test 3 is the money-shot and
round 2 left it unguarded.

### AC-11 — no test in the contracts suite can pass by not running

```sh
bash zk-verdict/scripts/no-skip.sh
# no-skip: 0 early-return fixture gates, 18/18 forge tests ran, 0 skipped; witness=<16 hex>
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

**Falsify:** restore one `if (!vm.exists(F)) return;` — the gate count is 1. **Mutant M-11** is
the machine-run version.

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
**Mutant M-2** names AC-12 as a second target row for this reason: a constant `delta_outcome`
breaks the zero-extension equivalence in test 1, so AC-12 is mutation-covered without a mutant of
its own (§6.2).

### AC-13 — the gate detects a wrong implementation (mutation, run by the gate)

```sh
bash zk-verdict/scripts/ac008-selftest.sh
# ac008-selftest: sandbox control clean (M-8) 1s
# ac008-selftest: M-8 AC-00b detected (sandbox) 2s
# ac008-selftest: sandbox control clean (M-17) 1s
# ac008-selftest: M-17 AC-00 detected (sandbox) 2s
# ac008-selftest: sandbox control clean (M-18) 1s
# ac008-selftest: M-18 AC-00b detected (sandbox) 2s
# ...                                        (one line per mutant, in run order, elapsed printed)
# ac008-selftest: 18/18 mutants detected; witness=<16 hex>
# ac008-selftest: elapsed <N>s
```

**Read INV-14 case (c) and §7.6 L-3 before reading this AC.** This row's own `witness=` field is
a **constant** for the whole run — no mutant modifies a `mutants/*.patch` file — so **the manifest
row below is satisfiable by a two-line `echo`**, and rounds 1–3 claimed otherwise (r3 finding 2).
Nothing in this repository closes that; §6.3's canary moves one detection onto a different script,
and **§7.8** names the reviewer who has to read and run this one — round 4 stated the dependency on
a person without creating an obligation on any person (r4 finding 3). That is said here, at the
top of the AC that carries all the mutation weight, rather than only in the limits section.

**This is r1 BLOCKER 1's mechanism and r2 BLOCKER 2's coverage.** Round 1 renamed tests; a body
of `assert!(true)` fails a rename exactly as a real test does. Round 2 replaced renaming with
four in-place mutants — the right mechanism — but four mutants over sixteen criteria left an
implementation alive that reports `4/4 mutants detected` while truncating at **128** bits and
applying **no block environment at all**. Round 3 keeps the mechanism unchanged and fixes the
coverage: **16 mutants, 15 rows, and a written exemption for each of the other three** (§6.2,
INV-13). **Round 5 finds that one of those three exemptions was the r4 BLOCKER**: AC-00 — the row
carrying the central claim — had no mutant, and the file 008 edits on the settlement-authority
path was read by nothing. **18 mutants, 16 rows, two written exemptions** (§6.2, §6.4, M-17,
M-18).

**Mechanism — two modes. Fifteen mutants run in place; three run in a sandbox and touch no
repository file at all** (§10 OQ-5 ruled the construction on 2026-09-04; OQ-6 ruled its extension
to the second contract on the same day). The `mode` column of the mutant table below says which,
and it is **`sandbox` for M-8, M-17 and M-18** and **`in-tree` for the other fifteen**.

**The round-4 sentence this replaces, and why it was wrong** (r4 BLOCKER). Round 4 wrote, as the
reason no mutant besides M-8 needed a sandbox: *"M-15 touches `RecknVerdictVerifier.sol`, which is
not the file `AGENTS.md` §0 is about and which `no-keys.sh` does not read."* **Both halves were
true and the conclusion drawn from them was backwards**: "the build condition does not read this
file" is not a reason the file needs no protection, it is the statement of the hole — and the file
is on the settlement-authority path and is one 008 edits (§6.4). After check 5 the premise is
false as well: `no-keys.sh` **does** read it. What survives, restated on a true premise:

- **M-17 is sandboxed**, for exactly the reason M-8 is: it splices a live resolver branch into a
  file that is now inside `AGENTS.md` §0's region, and no agent writes that region in the working
  tree. N-1's rule generalises to both files.
- **M-15 stays `in-tree`**, and the reason is no longer "the file is outside §0". It is: M-15
  swaps two **constant values** and changes **no structure**, so it is invisible to check 5 by
  construction (5b's vocabulary, 5c's counts, 5d's statements and 5e's targets are all unmoved) —
  and its residue after a `SIGKILL` is therefore **loud, not silent**: AC-10 fails, `zk-e2e.sh`
  fails, and step 5's per-file `sha256` assertion is what actually covers the restore. That is the
  opposite of M-8's comment flip, which `no-keys.sh` is comment-blind to by design
  (`no-keys.sh:28-30`). Recorded as **L-5**.
- M-10…M-13 and M-16 touch fixtures, tests, a README and the testkit; M-1…M-7 and M-9 touch guest
  source whose build trees make a sandbox a cold RISC-V build for no §0 benefit.

**Mode `in-tree` — fifteen mutants. Unchanged from round 2.**

```
0. assert `ls zk-verdict/scripts/mutants/*.patch | wc -l` == 18   # a deleted mutant FAILS AC-13
for each mutant M, in the order of §7.3 (zero-build mutants first):
  1. save byte copies of the files M touches into a temp dir; install
     `trap restore EXIT INT TERM` FIRST, before touching anything
  2. patch -p1 --batch --forward < M          # must apply; a non-applying mutant FAILS AC-13
  3. assert the touched files' sha256 CHANGED (a no-op patch is a failed mutant)
  4. for each row in M's `target rows` column:
        bash zk-verdict/scripts/ac008.sh <row>            # must exit NON-ZERO
  5. restore from the byte copies; assert sha256 back to the original; print
     `ac008-selftest: <M> <rows> detected <elapsed>s`
6. after the last restore: re-run `bash zk-verdict/scripts/ac008.sh AC-00b` and
   `bash scripts/no-keys.sh`; BOTH must exit 0.
```

**Mode `sandbox` — three mutants, three independent phases. The repository is read, never
written.** Each phase builds its **own** `$S` so that every phase's clean-copy control runs
against an unmutated copy; a phase never inherits another phase's mutation. All three are
zero-build and the three copies together are well under 100 KB (cost model below).

**Phase 8 — M-8, AC-0b's first clause (`RecknZkEscrow.sol`).**

```
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT INT TERM     # installed FIRST
8a. record sha256 of the four repository inputs (below), for step 8h
8b. mkdir -p "$S/zk-verdict/scripts" "$S/zk-verdict/contracts/src" "$S/reexec-evm/src"
8c. copy ALL FOUR of AC-0b's inputs — both clauses, not just the first:
       zk-verdict/scripts/surfaces.sh              -> $S/zk-verdict/scripts/
       zk-verdict/scripts/surfaces.pinned          -> $S/zk-verdict/scripts/
       zk-verdict/contracts/src/RecknZkEscrow.sol  -> $S/zk-verdict/contracts/src/
       reexec-evm/src/lib.rs                       -> $S/reexec-evm/src/
8d. CLEAN-COPY CONTROL, before any mutation:
       bash "$S/zk-verdict/scripts/surfaces.sh"    # must exit 0
       stdout must contain AC-00b's evidence line with a `witness=<16 hex>` field
    on failure: AC-13 fails and reports `sandbox control failed`, NOT `M-8 detected`
8e. patch -p1 -d "$S" --batch --forward \
        < "$root/zk-verdict/scripts/mutants/08-escrow-comment.patch"   # must apply.
    # The PATCH is read from the repository; `-d "$S"` is what makes it LAND in the sandbox.
    # `-p1` strips the `a/`,`b/` prefixes, so the patch's paths are repo-root-relative and
    # resolve under $S because 8b reproduced the layout.
8f. D8 = sha256("$S/zk-verdict/contracts/src/RecknZkEscrow.sol"), computed BY THE SELFTEST;
    assert D8 != the value 8a recorded for that file
8g. bash "$S/zk-verdict/scripts/surfaces.sh"       # must exit NON-ZERO  = M-8 detected
    AND its stdout must contain a line matching AC-0b's R6 form for clause
    `RecknZkEscrow.sol`, whose `computed:` field is EXACTLY D8.
    If it exits non-zero without printing that value, or prints a different value, the
    result is `M-8 NOT detected` — a MISS, not a detection.
8h. rm -rf "$S"; assert the four repository inputs' sha256 are unchanged from 8a
    print `ac008-selftest: M-8 AC-00b detected (sandbox) <elapsed>s`
```

**Step 8g's `computed:` assertion is new in round 5 and it is the whole of r4 finding 2(i).**
Round 4 asserted only *exit status*. A `surfaces.sh` that greps for the exact comment text M-8
flips — never calling `shasum`, never opening `surfaces.pinned`, never opening
`reexec-evm/src/lib.rs` — passes 8d, exits non-zero at 8g, and was scored as a **detection**. It
cannot produce `D8`. **The selftest computes `D8` itself and compares**; the script under test is
not asked to be honest about it.

**Phase 17 — M-17, `AGENTS.md` §0's second file (`RecknVerdictVerifier.sol`).** Same shape, one
directory shallower, because `scripts/no-keys.sh` derives `root` from `$(dirname "$0")/..`
(`no-keys.sh:17-18`) rather than `/../..`.

```
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT INT TERM     # installed FIRST
17a. record sha256 of the three repository inputs (below), for step 17h
17b. mkdir -p "$S/scripts" "$S/zk-verdict/contracts/src"
17c. copy the three files no-keys.sh reads after check 5 exists:
        scripts/no-keys.sh                                 -> $S/scripts/
        zk-verdict/contracts/src/RecknZkEscrow.sol         -> $S/zk-verdict/contracts/src/
        zk-verdict/contracts/src/RecknVerdictVerifier.sol  -> $S/zk-verdict/contracts/src/
17d. CLEAN-COPY CONTROL, before any mutation:
        bash "$S/scripts/no-keys.sh"                # must exit 0
        stdout must end with AC-00's evidence line
     on failure: AC-13 fails and reports `sandbox control failed`, NOT `M-17 detected`
17e. patch -p1 -d "$S" --batch --forward \
        < "$root/zk-verdict/scripts/mutants/17-verifier-origin-branch.patch"   # must apply
17f. assert sha256("$S/zk-verdict/contracts/src/RecknVerdictVerifier.sol") CHANGED
17g. bash "$S/scripts/no-keys.sh"                   # must exit NON-ZERO = M-17 detected
     AND its stdout must name check 5 and the file. A non-zero exit that names check 1, 2, 3
     or 4 is a HARNESS FAILURE, not a detection: it would mean the escrow copy is wrong.
17h. rm -rf "$S"; assert the three repository inputs' sha256 are unchanged from 17a
     print `ac008-selftest: M-17 AC-00 detected (sandbox) <elapsed>s`
```

`17-verifier-origin-branch.patch` is the r4 splice of §6.4, verbatim, applied to
`verifyVerdict` before the `verifyProof` call. **The mutant is a working resolver**, which is
exactly why it is never applied to the repository: a `SIGKILL` between 17e and 17h would leave a
tree that settles to a chosen address. In the sandbox a hard kill leaves an orphaned temp
directory. **17g asserts *which* check fired**, not only that something did — without that, a
sandbox missing `RecknZkEscrow.sol` would fail at check 2 and be scored as a detection of a
resolver in a different file. 17d's control already makes that a harness failure; 17g's clause is
the second, independent statement of the same requirement, and it is cheap.

**Phase 18 — M-18, AC-0b's second clause (`reexec-evm/src/lib.rs`, above line 711).**

```
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT INT TERM     # installed FIRST
18a…18e. identical to 8a…8e, with the patch
         "$root/zk-verdict/scripts/mutants/18-reexec-prefix-comment.patch"
18f. D18 = sha256 of `head -710 "$S/reexec-evm/src/lib.rs"`, computed BY THE SELFTEST;
     assert D18 != the prefix digest 18a recorded
18g. bash "$S/zk-verdict/scripts/surfaces.sh"      # must exit NON-ZERO = M-18 detected
     AND its stdout must contain a line matching AC-0b's R6 form for clause
     `reexec-evm-prefix-710`, whose `computed:` field is EXACTLY D18.
18h. rm -rf "$S"; assert the four repository inputs' sha256 are unchanged from 18a
     print `ac008-selftest: M-18 AC-00b detected (sandbox) <elapsed>s`
```

`18-reexec-prefix-comment.patch` flips one byte of a **comment above line 711** of
`reexec-evm/src/lib.rs`. It must not touch line 711 itself, must not insert or delete a line (a
line insertion would shift the boundary and the failure would be AC-0b's *line-711 assertion*
rather than its prefix digest — a different clause and a weaker test), and must not touch
`reexec-evm`'s testkit block. **Why this mutant did not exist before round 5:** M-16 is
deliberately placed **below** line 711 so that AC-0b does not move (§0.3 finding 2's design), so
after round 4 the *only* clause of AC-0b with a mutant was the escrow clause. The unmutated clause
is the one that stops 008's implementer from editing `reexec-evm::replay` — **the oracle the whole
differential compares the guest against (INV-1)** — and neither AC-15 (16 tests in the same
package) nor AC-16 (consumers compile) catches a change that still compiles and still passes.
r4 finding 2(ii).

**Why each of the four steps is load-bearing** (r3 finding 1, requirements 1–4; each applies to
all three phases, with the phase-17 differences named):

1. **8b/8c reconstruct the *layout*, not a file**, because `surfaces.sh` derives its targets from
   its own location and from nothing else — AC-0b's **Location rule**. That rule is what makes
   the copied script judge the copied contract through the same code path as the real one, with
   no argument, no environment variable and no default changed. `003` adopted this construction in
   its §4.5.9 and measured it working on 2026-09-04 for `no-keys.sh`'s one-file layout.
2. **All four inputs are copied, even though M-8 mutates one.** AC-0b has **two** clauses and the
   second is `head -710 reexec-evm/src/lib.rs` plus two assertions about line 711. A sandbox
   missing that file makes the **clean control** (8d) fail — which is the correct outcome for an
   incomplete sandbox, and precisely the reason the control exists rather than being an
   afterthought.
3. **The clean-copy control runs before the mutation, and its failure is a different verdict.**
   Without it, a degenerate `surfaces.sh` that fails inside the sandbox for the *wrong* reason —
   a file the sandbox did not copy, a burned `/Users/…` path that does not exist under `$S`, a
   `git rev-parse` that escapes upward — exits non-zero at 8g and is scored **"mutant detected"**.
   That is the one construction that defeats a sandbox, and it is defeated by asserting the clean
   copy passes first. **A control failure is a harness failure, never a detection.**
4. **Restore is `rm -rf "$S"`**, and 8h / 17h / 18h re-assert that the phase's repository inputs
   are byte-identical to what 8a / 17a / 18a recorded. Nothing under the repository was ever
   opened for writing, so **N-1 is literally true** and `AGENTS.md` §0 needs no exception — **for
   either of its two files**. The `trap`/`SIGKILL` gap that mode `in-tree` still carries for the
   other fifteen does not apply to §0's region at all: a hard kill during M-8, M-17 or M-18 leaves
   an orphaned temp directory, not a mutated contract. This matters most for **M-17**, whose
   mutation is a working resolver rather than a comment flip.
5. **Each phase's control runs against its own clean copy** (new in round 5). Phase 17's control is
   `no-keys.sh` over an unmutated pair of contracts; phase 18's is `surfaces.sh` over an unmutated
   pair of pinned files. A phase that reused a previous phase's `$S` would run its control against
   an already-mutated tree, and its "control passed" would mean nothing.

Step 0 and step 6 are from round 2. **Step 0** stops the cheapest possible defeat — deleting a
mutant so the remaining ones all pass. **Step 6 is restated** (r3 finding 1): round 3 justified it
as *"M-8 and M-15 mutate Solidity that the central claim lives in"*, and after the sandbox rewrite
**no mutant touches `RecknZkEscrow.sol` at all**. Step 6 stays, for the fourteen remaining in-tree
restores and **M-15** in particular (`RecknVerdictVerifier.sol`), and its two commands are now
doing two different jobs: `ac008.sh AC-00b` proves the two pinned files are as the run found them,
and `scripts/no-keys.sh` proves no in-tree mutant leaked into §0's file by accident. Neither is
guarding a restore of §0's file any more, because there is none. Per-file restores are asserted
by step 5's `sha256`, which is what actually covers `RecknVerdictVerifier.sol`.

`patch` / `patch -R` is used rather than `git apply` deliberately: this touches **no git
state** — no index, no commit, no stash — so it does not cross `AGENTS.md` §6's line that only
`reckn-codex-impl` owns git. The restore is from byte copies (in-tree) or `rm -rf` (sandbox), not
from `patch -R`, so a half-applied hunk still restores.

**A mutant may break rows other than its targets.** Only the named `target rows` are run and
only they are asserted non-zero. That keeps each mutant cheap and keeps the assertion exact.
**For the three sandbox mutants the "row" is the sandboxed script's own exit status plus its
printed `computed:` digest** (8d/8g, 17d/17g, 18d/18g), not `ac008.sh AC-00b` or `ac008.sh AC-00`
— `ac008.sh` would run the in-tree script over in-tree bytes, which is not what these mutants are
about. This is the one deviation from step 4's form and it is written here so an implementer does
not paper over it. It is also **why AC-00 needs no `witness=` field** (§6.2, INV-14 case (b)): the
sandbox tests the script itself, which is strictly stronger than testing a digest the script
prints about itself.

**The eighteen mutants, each a single small hunk on real source:**

| mutant | file | **mode** | change | target rows (**each** must exit non-zero) | cost |
|---|---|---|---|---|---|
| **M-1** | `zk-verdict/program-revm/src/main.rs` | in-tree | re-truncate: take limb 0 of `pre`/`post` before the delta — restore the defect this task exists to close | **AC-02** (V-03, V-11 flip) | 1 guest rebuild |
| **M-2** | `zk-verdict/lib/src/lib.rs` | in-tree | `delta_outcome` returns `REPRODUCED` unconditionally | **AC-01**, **AC-12** | native |
| **M-3** | `zk-verdict/program-revm/src/main.rs` | in-tree | restore `InMemoryDB::default()` — an unclosed database | **AC-04** (W-01, W-02, W-07, W-12, W-13) | 1 guest rebuild |
| **M-4** | `zk-verdict/program-revm/src/main.rs` | in-tree | drop `env_hash` from the `dealBinding` preimage | **AC-07a** (the 8 environment components) | 1 guest rebuild |
| **M-5** | `zk-verdict/program-revm/src/main.rs` | in-tree | **delete the whole `modify_block_chained` / env application, leaving `chain_id` only** — i.e. restore today's `main.rs:122-127` | **AC-03** (E-03…E-07, E-09) | 1 guest rebuild |
| **M-6** | `zk-verdict/program-revm/src/main.rs` | in-tree | truncate `pre`/`post` to **128** bits instead of 64 | **AC-02** (V-11 only) | 1 guest rebuild |
| **M-7** | `zk-verdict/program-revm/src/main.rs` | in-tree | drop `check_hash` from the `dealBinding` preimage | **AC-07a** (`check.*`, 4 components) | 1 guest rebuild |
| **M-8** | `zk-verdict/contracts/src/RecknZkEscrow.sol` — **the sandbox's copy of it; the repository's file is never written** | **sandbox** | flip one byte of a **comment** — a change no compiler, no test and `no-keys.sh` would notice | **AC-00b**, asserted as the **sandboxed `surfaces.sh`'s own exit status** (step 8g), after the clean-copy control (8d) has passed | none |
| **M-9** | `zk-verdict/program-revm/src/main.rs` | in-tree | re-insert `fn u64_low(v: U256) -> u64 { v.as_limbs()[0] }` (unused) | **AC-06** | none (greps only) |
| **M-10** | `zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json` | in-tree | flip one hex byte of `vkey` | **AC-09** | none (the ELF is already built) |
| **M-11** | `zk-verdict/contracts/test/RecknReexecVerdict.t.sol` | in-tree | restore one `if (!vm.exists(F)) return;` | **AC-11** | none (grep) |
| **M-12** | `zk-verdict/README.md` | in-tree | insert a line containing `~410k` | **AC-14** (check iii) | none |
| **M-13** | `zk-verdict/contracts/src/fixtures/alt-binding.json` | in-tree | replace the alternate binding with the **headline fixture's own** `dealBinding` | **AC-07b** (test 2's `expectRevert` no longer fires) | 1 forge run |
| **M-14** | `zk-verdict/script/src/lib.rs` | in-tree | `fn zk_outcome(_) -> u8 { 0 }` | **AC-08** | native |
| **M-15** | `zk-verdict/contracts/src/RecknVerdictVerifier.sol` | in-tree | swap the `REPRODUCED` / `FAILED` constants | **AC-10** (tests 2 and 3 pay the wrong party) | 1 forge run |
| **M-16** | `reexec-evm/src/lib.rs` (**inside** the testkit `cfg` block, below line 711, so AC-0b does not move) | in-tree | rename `addr` → `addr_` with no wrapper | **AC-16** (`binder`'s `cargo check --tests`) | 1 incremental check |
| **M-17** | `zk-verdict/contracts/src/RecknVerdictVerifier.sol` — **the sandbox's copy; the repository's file and the repository's `scripts/no-keys.sh` are never written** | **sandbox** | splice §6.4's `tx.origin` branch into `verifyVerdict` before the `verifyProof` call — a **working resolver**, which is why it never touches the working tree | **AC-00**, asserted as the **sandboxed `no-keys.sh`'s own exit status and the check it names** (17d/17g) | none |
| **M-18** | `reexec-evm/src/lib.rs` — **the sandbox's copy**, one comment byte **above** line 711 | **sandbox** | flip one byte of a comment inside AC-0b's pinned prefix: no code changes, no line is added or removed, line 711 is untouched | **AC-00b** (second clause), asserted as the sandboxed `surfaces.sh`'s exit status **and** its printed `computed:` digest for clause `reexec-evm-prefix-710` (18d/18g) | none |

**Why these eighteen and not four.** M-5 is the one that must land: axis 2 of the defect this task
exists to close has thirteen test bodies and, before round 3, zero mutants — so an implementation
that applies `spec_id` and leaves the block environment at revm defaults passed. M-6 closes the
reviewer's surviving construction (128-bit truncation is caught by exactly one vector body, and
M-1 alone does not reach it). M-8…M-13, M-15 and M-16 close the `script` and `forge` rows, which
round 2 verified by "exit 0 and print this string" — §6.2. **M-17 closes the row that carries the
central claim**, which had no mutant through four rounds while the file it is about was being
edited by this very task (r4 BLOCKER). **M-18 closes AC-0b's second clause**, which had no mutant
because the only mutant near it was deliberately placed out of its range (r4 finding 2).
**Eleven of the eighteen require no compilation at all.**

**Cost model.** Round-2 measurements re-stated, plus the new count:

- `du -sh zk-verdict/target` = **6.8G**; `du -sh .` = **21G**. **A copy of the *repository* per
  row** is ~210 GB or ten cold `sp1-sdk` builds — that is r1 finding 3's design, and **it is gone
  and is not coming back.**
- **The three sandboxes are not that design and must not be confused with it.**
  Phases **8** and **18** each copy **four files** — `surfaces.sh`, `surfaces.pinned`,
  `RecknZkEscrow.sol` and `reexec-evm/src/lib.rs` — into a three-directory skeleton. Phase **17**
  copies **three** — `scripts/no-keys.sh`, `RecknZkEscrow.sol` and `RecknVerdictVerifier.sol` —
  into a two-directory skeleton. Measured 2026-09-04: `RecknZkEscrow.sol` **4,599 bytes**,
  `RecknVerdictVerifier.sol` **2,525 bytes**, `scripts/no-keys.sh` **3,545 bytes**,
  `reexec-evm/src/lib.rs` **52,150 bytes**. The four measured files that phases 8 and 18 copy sum to
  **56,749 bytes**; the three that phase 17 copies sum to **10,669 bytes**. `surfaces.sh` and
  `surfaces.pinned` do not exist yet, so their sizes are **not measured** — round 4's "under
  60 KB" per phase holds if they are together under ~3 KB, which a two-clause digest script and a
  two-line text file will be. **Stated as a bound rather than a total: the three phases together
  copy well under 200 KB, with no build tree, no `target/`, no cargo, no `forge` and no
  network.** The reason a three- or four-file copy is enough is the Location rule: each script reads exactly those paths
  and derives all of them from its own location, so the sandbox is the whole of the world it can
  see. `scripts/no-keys.sh` already satisfies the rule today (`:17-19`) and §6.4 forbids
  regressing it.
- In place, the warm build trees are reused. `zk-verdict/program-revm/target/elf-compilation`
  is **558M** with dependencies already compiled, so each guest mutant rebuilds **one crate** for
  `riscv64im-succinct-zkvm-elf`, not a dependency graph. `zk-verdict/script/build.rs:4-8` rebuilds
  the guests on every `cargo test` of `script`, so no extra build step is scripted.
- Totals: **6** single-crate guest rebuilds (M-1, M-3, M-4, M-5, M-6, M-7), **2** native rebuilds
  (M-2, M-14), **2** `forge` runs (M-13, M-15), **1** incremental cross-crate check (M-16), and
  **7** mutants with no build at all (M-8…M-12, M-17, M-18) — of which three additionally do a
  small file copy and an `rm -rf`.
- **Ordering:** the seven zero-build mutants run **first**, so a broken harness is discovered in
  seconds instead of after the first RISC-V rebuild. **The three sandbox phases are first of the
  seven, in the order M-8, M-17, M-18**, so their clean-copy controls are the first thing the whole
  gate proves — a sandbox that cannot reproduce a passing AC-00b or AC-00 is a harness failure
  worth finding in second one, not in minute thirty. Round 5 adds no measurable time to this
  phase: two more `mktemp -d`s, five more file copies, two more grep-only script runs.
- **§6.3's canary** adds one `patch`, one grep-only `ac008.sh AC-06`, and one restore to
  `ac008.sh --all`. It is not part of AC-13's 40-minute budget because it is not run by
  `ac008-selftest.sh`; it costs seconds and it is measured in `--all`'s own wall time.

**Budget and decision rule — priced for 18, with the stop kept and the number unchanged.**
Round 2's 20 minutes was computed for 3 guest rebuilds + 1 native and was itself an estimate.
Round 3 doubled the dominant term (3 → 6 guest rebuilds) and set **40 minutes**. **Round 5's two
new mutants add no build of any kind** — three script runs over ~120 KB of copied text — so the
budget stays **40 minutes**. It is not raised to absorb them, and it is not lowered on an estimate
nobody has run.

- `ac008-selftest.sh` prints **per-mutant elapsed seconds** and a total. The per-mutant line is
  what replaces this extrapolation with measurement; the implementation report must paste it.
- **If the total exceeds 40 minutes: stop and report** (`AGENTS.md` §7). **Do not trim mutants,
  do not reorder them out of the run, and do not raise the budget in this file.** 008 is the head
  of the execution order and gates the 9/9 checkpoint, so a selftest that does not fit is a fact
  the founder needs.
- **If any mutant is *not* detected: AC-13 fails. Stop and report.** The remedy is never deleting
  the mutant; it is either fixing the test bodies it exposed or bringing the founder a reason the
  mutant is wrong.

**Falsify:** replace every `test_AC02_*` body with `assert!(true);` — M-1 and M-6 no longer make
AC-02 fail and the selftest reports `16/18`. Or stub `env-parity.sh` to `echo` its evidence line —
M-9 is no longer detected **by this script, and also not by §6.3's canary, which is the second
place it now has to survive**. Or delete one `.patch` file — step 0 fails (18 expected). Or make a
mutant a no-op — step 3 (or 8f / 17f / 18f) fails. Or write a `surfaces.sh` that prints the two
pinned literals from a heredoc without opening either file — the clean control (8d) passes, step
8g exits **0**, M-8 is a **miss**, and AC-13 fails. **Or write the half-degenerate `surfaces.sh`
that greps for M-8's comment text instead of hashing** — it exits non-zero at 8g but prints no
`computed:` digest equal to the selftest's `D8`, so it is a **miss** (round 4 scored it as a
detection), and it exits **0** at 18g, so M-18 is a second miss. Or copy only `RecknZkEscrow.sol`
into a sandbox — the clean control fails and AC-13 reports `sandbox control failed`, which is
**not** a detection. **Or ship a `no-keys.sh` whose check 5 greps for `tx.origin` instead of
implementing §6.4's properties** — M-17's patch is caught, so this Falsify needs its own witness:
apply the same splice with the branch condition written as `block.chainid == 31337` or as an
`assembly { … origin() … }` block, and the name-based check passes it while 5b rejects it. **The
implementation report must state which of §6.4's five clauses fired for M-17**, and if the answer
is "a grep for `tx.origin`", check 5 is not the check this document specifies.

**Falsify — of this AC's own row, stated because it is true:** replace `ac008-selftest.sh` with
`#!/usr/bin/env bash` plus one `echo` of the evidence line carrying the current patch-set witness.
The row passes. `ac008.sh --all` does **not** print `18/18 rows passed`, because §6.3's canary is
applied by `ac008.sh` and not by this script — but every mutant except M-9 goes unrun and nothing
in the repository notices. **This is the residual, not a falsification the gate performs** (L-3),
and **§7.8 is who is responsible for it** — a named reviewer running this script itself, which
round 4 relied on without asking anyone to do it (r4 finding 3).

### AC-14 — the documents moved in the same commit

```sh
bash zk-verdict/scripts/docs-check.sh
# docs: 9/9 stale claims absent, 11/11 replacements present, 0 tilde cycle literals, 1/1 qualified ~34 s site, cycles.json matches 3/3 guests; witness=<16 hex>
```

**Digests are gone** (§0). **Five** checks, all over content.

**(i) Nine stale claims must be absent** — fixed-string `grep -F`, each in the named file.
*(The heading is a count and it has been wrong once: round 2 added the eighth literal and left the
heading at seven, so an implementer writing `docs-check.sh` from the heading would have written
seven and either failed against the manifest's `8/8` or printed a number it had not checked —
r4 finding 8. The count now appears in exactly two places, here and §6.1's evidence line, and both
say **nine**.)*

| # | file | literal (must not match) |
|---|---|---|
| 1 | `README.md` | ``The `u64` verdict boundary is a soundness bug`` |
| 2 | `README.md` | `is UNVERIFIED` |
| 3 | `AGENTS.md` | ``（`u64_low` は limb 0 のみ`` → the substring ``` `u64_low` は limb 0 のみ ``` |
| 4 | `AGENTS.md` | ``` `c-kzg` / `ecrecover` precompile は in-guest で無効 ``` |
| 5 | `zk-verdict/README.md` | ``` the `c-kzg`/`ecrecover` precompiles are disabled ``` |
| 6 | `zk-verdict/README.md` | ``` to `u64` to reuse the on-chain ABI ``` |
| 7 | `zk-verdict/program-revm/src/main.rs` | ``` Values map to `u64` to reuse ``` (the module doc comment at `:14`, which states the defect as a design choice) |
| **8** | `zk-verdict/README.md` | `stays gated on the fixture's presence` (**r2 finding 8** — measured today at `zk-verdict/README.md:108`. AC-11 replaces every `if (!vm.exists(F)) return;` with a `require`, so after 008 nothing is gated on fixture presence and this sentence is false as written. Nobody is harmed in practice — all four fixtures are committed and AC-9 keeps them current — but AC-14 exists precisely to stop a document describing a mechanism that no longer exists, and round 2's seven-literal list did not contain it.) |

| **9** | `scripts/no-keys.sh` | ``the body of `contract RecknZkEscrow` only`` (**new in round 5** — the script's own scope comment at `no-keys.sh:11-12`. Check 5 makes it false in the same commit that adds the check, and a build condition whose header misdescribes its own region is the "documentation drifted from code" failure `CLAUDE.md:41-43` records this repository committing twice. §9(2c).) |

All nine were confirmed present today by `grep -rn -F`, so all nine are real removals.

**(ii) Eleven replacement sentences must be present** — the marker substrings from §9:

| # | file | literal (must match) |
|---|---|---|
| 1 | `zk-verdict/README.md` | `at the committed hardfork and block environment` |
| 2 | `zk-verdict/README.md` | ``Verdict values are `uint256`.`` |
| 3 | `zk-verdict/README.md` | `Engine identity is checked, not assumed.` |
| 4 | `AGENTS.md` | ``旧 `u64` マップは制限ではなく健全性バグだった`` |
| 5 | `AGENTS.md` | `precompile は in-guest でも` |
| 6 | `README.md` | `In-guest precompiles run on different backends, and parity is unverified` |
| **7** | `zk-verdict/README.md` | `a missing fixture is a hard failure` (§9(1a) — the replacement for literal 8) |
| **8** | `zk-verdict/README.md` | `a floor of zero is satisfied by doing nothing` (**new in round 5** — the disclosure of **R-7**, §9(1). Round 4's INV-11 asserted every §8 residual appeared verbatim in the honest scope; `grep -rn 'min == 0\|zero floor\|minDelta == 0' README.md zk-verdict/README.md CLAUDE.md SUBMISSION.md` returned **0 matches** today and would have returned 0 after 008 as specified. r4 finding 4.) |
| **9** | `zk-verdict/README.md` | `the gnark wrap alone` (**new in round 5** — the qualification of the `~34 s` figure at `zk-verdict/README.md:97`, §9(1b). §7.5 measures the same end-to-end operation at 335.02 s, roughly 10×, and the unqualified sentence errs in the flattering direction. r4 finding 9.) |
| **10** | `AGENTS.md` | `RecknVerdictVerifier.sol` (**new in round 5** — §0's declaration of the second file in the checked region, §9(2a). Without this marker the claim widens in the code and not in the document that states it.) |
| **11** | `CLAUDE.md` | `RecknVerdictVerifier.sol` (**new in round 5** — the 中心主張 block, §9(2b). `CLAUDE.md:16-18` names one file as *the* file the claim lives in; after check 5 that is incomplete.) |

Marker 6 is **already present** (`README.md:572`, landed in `9ac4545` on 2026-09-04, *after*
the 008 spec commit `d4f59ba`). Its obligation in §9(3) is therefore **"verify unchanged"**,
not "correct it" — r1 finding 8, which also caught that round 1's `AC-14(i)` would have passed
even if 008 changed nothing, because it only required the digest to *differ* and it already
did.

Markers 8–11 were each confirmed **absent** today, so each is a real addition:
`grep -rn 'a floor of zero\|the gnark wrap alone' zk-verdict/README.md` → 0 matches;
`grep -rn 'RecknVerdictVerifier' AGENTS.md CLAUDE.md` → 0 matches.

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

**(v) The `~34 s` figure is qualified in place, and there is still exactly one of it.**

```sh
grep -c -F '~34 s' zk-verdict/README.md      # must be exactly 1
grep -F  '~34 s' zk-verdict/README.md | grep -q -F 'the gnark wrap alone'   # must succeed
```

`zk-verdict/README.md:97` says a real Groth16 proof was generated *"~34 s once the artifacts are
local"*. §7.5 measured the end-to-end regeneration of one fixture at **`real 335.02 s`** and the
gnark wrap alone at **31.71 s** — so the sentence is defensible read narrowly ("the gnark prover")
and is read by everyone else as the cost of producing a proof, which is **roughly 10× wrong in the
flattering direction** (`AGENTS.md` §5). §9(1b) qualifies it.

**Two constraints on the fix, and they pull against each other, so both are written.**
**(a) Do not delete the figure and do not add a second occurrence** — a later task in the
execution order pins the *number of occurrences* of that string in that file, so a deletion and a
duplication both break it. That is why this is a **count** check and not only a marker.
**(b) Do not restate it as a new measurement** — 31.71 s is the measured gnark-wrap time from
§7.5 and 335.02 s is the measured end-to-end time; 008 measures nothing new here (N-8).

**Falsify:** leave `~410k` anywhere in the doc set (check iii); leave `~**410k` in
`zk-verdict/README.md:142` and use the naive `~[0-9]` regex (check iii, by construction, misses
it — which is why the regex is written out above rather than described); leave the honest-scope
section unchanged (checks i and ii); publish a rounded cycle figure (check iv); **delete the
`~34 s` sentence instead of qualifying it, or add a second `~34 s` elsewhere in the file — check
(v)'s count goes to 0 or 2 and the row exits non-zero**; **ship without R-7's disclosure sentence
— marker 8 is absent** (this is the one round 4 shipped, and it was invisible because no marker
existed); **declare check 5 in the script and not in `AGENTS.md` §0 — marker 10 is absent.**

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
# consumers: binder, keeper, reckn-evm-content check --tests clean (3/3); witness=<16 hex>
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
`ac008.sh --all` reports `17/18`. (Round 1 would have reported `18/18`.) **Mutant M-16** is the
machine-run version; it edits **inside** the testkit `cfg` block, below line 711, so AC-0b's
prefix digest deliberately does **not** move and the failure is isolated to this row.

---

## 7. Test plan

### 7.1 Files

| path | contents |
|---|---|
| `zk-verdict/lib/src/lib.rs` (test module) | AC-1 (8), AC-12 (3) |
| `zk-verdict/script/src/lib.rs` | **new file** (`script` has only `src/bin/*` today; a `[lib]` target is added to its `Cargo.toml`): `to_guest_input` + `OutOfDomain`, `to_predicate`, `zk_outcome`, the differential runner. **No `#[test]`.** |
| `zk-verdict/script/tests/value_domain.rs` | AC-2, V-01…V-14 |
| `zk-verdict/script/tests/engine_identity.rs` | AC-3, E-01…E-12 + the `SpecId` name pinning |
| `zk-verdict/script/tests/domain_closed.rs` | AC-4, W-01…W-13 (five new: the hand-built-`GuestInput` bypass W-09/W-11, the predicate gate W-10, and the two untested transitions W-12/W-13) |
| `zk-verdict/script/tests/binding.rs` | AC-7a, 18 components |
| `zk-verdict/script/tests/outcome_map.rs` | AC-8, 6 |
| `zk-verdict/contracts/test/RecknVerdictDomain.t.sol` | AC-7b (2), AC-10 (4) |
| `zk-verdict/contracts/src/RecknVerdictVerifier.sol` | **modified — four tokens, and nothing else** (§3.4, N-12): `VerdictPublicValues.pre` / `.post` / `.minDelta` / `.maxDelta` go `uint64` → `uint256`. *(Round 4 changed this file in §3.4 and did not list it here, in §6.2's coverage table, or in `no-keys.sh` — the r4 BLOCKER. It is on the settlement-authority path: `RecknZkEscrow.sol:99`.)* |
| `scripts/no-keys.sh` | **modified — one new numbered section, check 5** (§6.4). Second target derived from `$root` exactly as the first is (`:17-19`); the four existing checks, the arguments, and the final line are unchanged. The header comment at `:11-12` is corrected in the same edit (AC-14(i) literal 9). **This is `AGENTS.md` §0's script**: the change is a tightening, it is declared in §9(2a)–(2c), and **relaxing it later is a founder call** (OQ-6). |
| `zk-verdict/scripts/{ac008,surfaces,env-parity,fixtures-check,no-skip,ac008-selftest,docs-check,consumers-check}.sh` | the harness (**8** scripts — `no-truncation.sh` is gone, folded into `env-parity.sh`; `consumers-check.sh` is new) |
| `zk-verdict/scripts/mutants/*.patch` | the **eighteen** committed mutants (AC-13), named `01-truncate`, `02-const-reproduced`, `03-open-db`, `04-drop-envhash`, `05-drop-blockenv`, `06-truncate-128`, `07-drop-checkhash`, `08-escrow-comment`, `09-restore-u64low`, `10-fixture-vkey`, `11-restore-skip-gate`, `12-tilde-cycles`, `13-alt-binding-self`, `14-const-zk-outcome`, `15-swap-outcome-consts`, `16-testkit-signature`, **`17-verifier-origin-branch`**, **`18-reexec-prefix-comment`**. `ac008-selftest.sh` step 0 requires exactly 18. **`08-…`, `17-…` and `18-…` are applied only with `-d "$S"`, inside AC-13's three sandbox phases; none of them is ever applied to the repository.** `17-verifier-origin-branch.patch` is a **working resolver** and the repository must never carry it, not even transiently. `09-restore-u64low.patch` is applied twice per full run — once by `ac008-selftest.sh` and once by `ac008.sh --all` as the §6.3 canary. |
| `zk-verdict/cycles.json`, `zk-verdict/scripts/surfaces.pinned` | committed measurements and the two code digests |

### 7.2 Positive path (must pass), and the guest-freeze rule

`bash zk-verdict/scripts/ac008.sh --all` → `ac008: 18/18 rows passed; canary M-9 detected by AC-06`
(§6.3 — the canary is part of the positive path, not an extra), and
`bash zk-verdict/scripts/zk-e2e.sh` still runs end to end with the regenerated fixtures.

**The guest is frozen once, and `--all` is green only after that** (r2 founder uncertainty 1).
AC-9 requires all four committed Groth16 fixtures to match the **final** ELF's vkey, and 008
changes all three guests, so *every* implementation round that touches a guest invalidates all
four. The ordering that makes this one regeneration instead of one per round:

1. **All guest-touching changes land in a single implementation round** — `program-revm`,
   `program`, `program-svm`, `zk-verdict/lib`, `zk-verdict/reexec-io`. Anything that changes an
   ELF changes its vkey.
2. **Until the freeze, AC-09 / AC-07b / AC-10 are expected red**, and `--all` reports fewer than
   18. The implementation report must name the red rows and say why. A red row may not be
   described as passing (`AGENTS.md` §5), and the rows may not be removed from the manifest to
   make the count look right.
3. **The freeze**: once the impl review reaches APPROVE on the Rust and the Solidity, the four
   fixtures plus `alt-binding.json` are regenerated **once**, in one commit, together with
   `zk-verdict/cycles.json` (three cycle counts, three ELF `sha256`s).
4. **Planned regeneration rounds `R = 1`.** `R = 2` is tolerated and must be reported with the
   reason. **`R = 3` is a stop** (`AGENTS.md` §7): three rounds means the guest was never frozen,
   which is a process fact the founder needs before 9/9, not a wall-clock problem to absorb.

§7.5 carries the measured cost this rule exists to control.

### 7.3 Negative controls

**Measured, by the gate, on every run** — these are AC-13's eighteen mutants, plus §6.3's canary
which `ac008.sh --all` applies itself. Nothing about them is self-reported *(with the one honest
exception that the script doing the measuring is trusted — L-3)*. **Run order is zero-build
first**, so a broken harness fails in seconds:

| # | mutant | break | rows that must go non-zero | build |
|---|---|---|---|---|
| 1 | M-8 (**sandbox**) | flip one byte of a comment in **the sandbox's copy** of `RecknZkEscrow.sol`; the repository's file is never written (§10 OQ-5, ruled) | the sandboxed `surfaces.sh`'s exit status **and its printed `computed:` digest for clause `RecknZkEscrow.sol`** — preceded by the clean-copy control, which must exit 0 | — |
| 2 | **M-17** (**sandbox**) | splice §6.4's `tx.origin` branch into **the sandbox's copy** of `RecknVerdictVerifier.sol`; the repository's file and the repository's `no-keys.sh` are never written (§10 OQ-6, ruled) | the sandboxed `no-keys.sh`'s exit status **and the fact that it names check 5** — preceded by the clean-copy control, which must exit 0 | — |
| 3 | **M-18** (**sandbox**) | flip one byte of a comment **above line 711** in the sandbox's copy of `reexec-evm/src/lib.rs` | the sandboxed `surfaces.sh`'s exit status **and its printed `computed:` digest for clause `reexec-evm-prefix-710`** — preceded by its own clean-copy control | — |
| 4 | M-9 | re-insert `fn u64_low` into `program-revm/src/main.rs` | AC-06 | — |
| 5 | M-10 | flip one hex byte of the headline fixture's `vkey` | AC-09 | — |
| 6 | M-11 | restore one `if (!vm.exists(F)) return;` | AC-11 | — |
| 7 | M-12 | insert a `~410k` line into `zk-verdict/README.md` | AC-14 | — |
| 8 | M-13 | `alt-binding.json` := the headline fixture's own binding | AC-07b | forge |
| 9 | M-15 | swap `REPRODUCED` / `FAILED` in `RecknVerdictVerifier.sol` (**values only — no structural change, so check 5 is silent by construction and AC-10 is the instrument; L-5**) | AC-10 | forge |
| 10 | M-2 | `delta_outcome` returns `REPRODUCED` unconditionally | AC-01, AC-12 | native |
| 11 | M-14 | `fn zk_outcome(_) -> u8 { 0 }` | AC-08 | native |
| 12 | M-16 | rename a testkit builder with no wrapper | AC-16 | cross-crate check |
| 13 | M-1 | re-truncate the verdict to limb 0 | AC-02 | guest |
| 14 | M-6 | truncate at **128** bits instead of 64 | AC-02 | guest |
| 15 | M-5 | **delete the block-environment application** | AC-03 | guest |
| 16 | M-3 | restore `InMemoryDB::default()` | AC-04 | guest |
| 17 | M-4 | drop `env_hash` from the `dealBinding` preimage | AC-07a | guest |
| 18 | M-7 | drop `check_hash` from the `dealBinding` preimage | AC-07a | guest |

**Sixteen** of the eighteen manifest rows appear above. The two that do not — **AC-13 and
AC-15** — carry a **written exemption** in §6.2, which is why INV-13 says "mutated or exempt in
writing" and not "mostly mutated". *(Round 4 had three: **AC-00 was in that list**, and its
exemption was the reason the r4 BLOCKER could exist. M-17 moves it into this table.)*
**AC-13's exemption is the weaker of the two and round 4 stopped calling it a guard**: its row is
`echo`-satisfiable (INV-14 case (c), L-3), and what stands in place of a mutant is §6.3's canary
plus **a named reviewer** — §7.8, which is the part round 4 left unassigned.

**Row 19, run by `ac008.sh --all` rather than by the selftest:**

| # | mutant | break | rows that must go non-zero | build |
|---|---|---|---|---|
| 19 | M-9, **as the §6.3 canary** | re-insert `fn u64_low` into `program-revm/src/main.rs` | AC-06, checked by `ac008.sh --all` **before** it may print its evidence line | — |

**Argued, not measured.** What remains below is a *reading* of the acceptance criteria, not a
transcript. Round 1 said the remaining families would be "run once by hand and their output
pasted into the implementation report"; that sentence is deleted, and with it the claim. Nothing
here may be described as passing or failing until something runs it. **Round 2's version of this
table contained "apply `spec_id` but leave the block env at defaults → AC-3", which is the
highest-value row in the document; round 3 moved it into the measured table as M-5.** The rule
round 2 stated — *a claim must become a mutant, not a paragraph* — was correct and was applied to
the implementer but not to the spec. It is applied to the spec here.

| degenerate implementation | the AC that should refuse it | why (from that AC's vectors) |
|---|---|---|
| judge in `U256` but keep the `uint64` Solidity struct | AC-9, AC-10 | public values differ from the fixture; `abi.decode` reverts on dirty high bits |
| special-case the fixture (`if pre == 42 { … }`) | AC-2 | 13 of 14 vectors use other magnitudes |
| return `FAILED` unconditionally | AC-2, AC-3, AC-4 | **9 / 11 / 3** vectors expect `Reproduced` (recounted in round 3: AC-3's Reproduced count is E-02…E-12 = 11, not the 9 round 2 wrote; AC-4's are W-03 and the `Ok` controls inside W-09 and W-11) |
| hard-code the testkit anchor's env values as constants | AC-3 | E-03…E-09 each differ from the testkit anchor too |
| omit `disable_nonce_check` | AC-3 | E-10 |
| drop `plan.gas_limit` from `plan_hash` | AC-7a | 1 of 18 |
| put the Δ check only in `to_guest_input` (round 2's design) | AC-4 | W-09 |
| add a field to `EvmAnchorV1` without carrying it | AC-6 check 3 + a compile error | the destructure is exhaustive |

Every row still in this table is one whose mutant would cost a guest rebuild for a claim already
covered by a cheaper mutant, or one that is a compile error rather than a test failure. **If the
implementer wants any of them to be a *claim*, it becomes a seventeenth mutant, not a paragraph.**

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
- **Vectors for P-1…P-4.** They are pre-existing transitions in `verify_prestate_authenticity`
  that 008 does not change. AC-4 covers every transition 008 **adds** (P-5…P-12). This is a
  stated limit of the gate, **L-1** in §7.6, not a silent omission — the point of writing it down
  is that the next task to touch `verify_prestate_authenticity` inherits the obligation.
- **A mutant for `ac008-selftest.sh` itself.** It would be evaluated by the thing it mutates.
  Round 3 named three substitutes — step 0, §6.2's `witness`, step 6 — and let the reader infer
  they close the gap; **they do not, and two of the three are inside the script a stub replaces**
  (r3 finding 2). What is written instead: §6.3's canary, which is applied by a *different*
  script; **L-3**, which states in one sentence that AC-13's row is `echo`-satisfiable and that
  the gate's integrity rests on a person reading and running the script; and — new in round 5 —
  **§7.8, which names that person and states what they must do** (r4 finding 3: round 4 asserted
  a trust root and assigned it to nobody). **No fourth ceremony is added**, because a fourth
  ceremony inside the same repository would relocate the trust root again rather than close it.
  §7.8 is not a ceremony; it is an obligation on an agent outside this script.

### 7.5 The Groth16 regeneration — measured, budgeted, ordered

Round 2 required the implementer to *report* this wall time and gave it neither a budget nor a
stop rule, while giving AC-13 — the smaller item — both. It is now measured.

**Measured 2026-09-04, on the *current* (pre-008) re-execution guest, before any code change**,
with `cargo run --release --bin reexec -- --fixture`; warm build tree, `~/.sp1` v6.1.0 circuit
artifacts already local, `acceleration = none`, Apple Silicon:

| quantity | measured |
|---|---|
| **end-to-end regeneration of ONE fixture** | **`real 335.02 s`** (5 min 35 s) |
| R1CS load | 11.73 s |
| proving-key load | 3.18 s |
| witness generation | 0.38 s |
| Groth16 proof generation (the gnark wrap) | **31.71 s** — gnark prover 27.63 s, constraint solver 4.07 s |
| verification | 1.45 ms |
| circuit | `nbConstraints = 15,972,262`, backend `groth16`, curve `bn254` |

The regenerated fixture matched the committed one (`outcome 0`, `pre 42`, `post 142`,
`traceHash 0x4e7b13452b3693d2b788d113ddb870edb282f6f30e528e50ab873492f25ec358`), and the pinned
fixture was restored with `git checkout`; the tree is clean.

**What this corrects, in both directions.** `zk-verdict/README.md:97`'s "~34 s" is the **gnark
wrap alone** — it corresponds to the 31.71 s line above — and the end-to-end regeneration is
roughly **10×** that. The r2 review was right that the figure could not be used as an end-to-end
cost and right that it was written about a different (34-line predicate) guest; it was wrong to
treat the figure as unrelated. Both halves are written down here so neither is re-derived.

**The four itemised phases sum to 47.00 s of the 335.02 s.** The remaining ~288 s is not itemised
in the captured log. Attributing it to the SP1 core and compress stages that precede the gnark
wrap is an **inference, not a measurement**, and it is written as such.

**Not measured, and therefore not written as a number** (`AGENTS.md` §5):

- the **predicate guest** (`program`) and the **SVM guest** (`program-svm`) regeneration times.
  `program-svm` is ~980k cycles against the re-execution guest's ~410k, so its core proving may be
  **longer**. Nobody has run it.
- cold build trees; a machine without the local `~/.sp1` artifacts; any other CPU.
- the **post-008** guest, which will be slower (U256, a witness-closed database, `k256`, P-12).

**Planning figure, labelled as the extrapolation it is:** `4 × 335.02 s ≈ 22 min` per regeneration
round, *assuming the other three fixtures cost what the re-execution one costs*. That assumption
is unverified, and unverified in the direction that would hurt (SVM). The implementation report
replaces this line with four measured numbers.

**Budget and stop rule, in AC-13's form:**

- Measure `T_reexec`, `T_falserelease`, `T_predicate`, `T_svm` **individually**, print each, and
  record all four in the implementation report and in `zk-verdict/cycles.json` alongside the cycle
  counts.
- Budget for one regeneration round: **`B = 30 min`** — the 22 min extrapolation plus headroom for
  the unmeasured SVM guest and the post-008 slowdown.
- **Exceeding `B` is information, not a failure.** Report the measured number and continue; the
  number is the deliverable.
- **Exceeding `3 × B` (90 min) in one round: stop and report** before starting a second round. At
  that point the 9/9 checkpoint turns on a number nobody had. An agent may **not** respond by
  dropping a fixture from AC-9 — that would move its evidence line off `4/4`, which is a founder
  ruling, not an agent's.
- **If `T_predicate` or `T_svm` cannot be measured because the run does not complete: stop and
  report.** Do not publish `fixtures: 4/4 current` on three regenerations and an assumption.
- The **rounds** rule is in §7.2: planned `R = 1`, `R = 2` reported, **`R = 3` is a stop**.

**On the numbers that exist, this is not the 9/9 blocker — and that conclusion is conditional on
two quantities nobody has measured** (r3 finding 8). At 335 s per fixture, one full regeneration
round is ~22 min of wall time and fits inside a single implementation round. The schedule risk is
**`R`**, not `T`: the cost is controlled by *ordering* (freeze the guest, regenerate once), which
§7.2 item 1 exists to enforce. Test count is not the blocker either, which is why round 3
**adds** five vectors and three mutant classes rather than taking the r2 cut list.

**The two conditions, named at the point of the conclusion rather than only in L-4:**

1. **`T_predicate` and `T_svm` are unmeasured.** `program-svm` is ~980k cycles against the
   re-execution guest's ~410k, so its core proving may be **longer**, and `4 × 335.02 s` assumes
   it is not.
2. **The post-008 re-execution guest is unmeasured.** U256 arithmetic, a witness-closed database,
   `k256` under a pinned spec and P-12 all make it **slower** than the 335.02 s that was measured
   on the pre-008 guest.

**Both move in the same direction — up.** If either lands far enough above the extrapolation, the
conclusion inverts and 008's regeneration *does* become a schedule item for 9/9. The `3 × B`
(90 min) stop and the `R = 3` stop are what surface that, and they fire on measurement rather than
on this sentence. Stated as a conditional because a conclusion resting on two unmeasured numbers
that both point the wrong way is exactly what `AGENTS.md` §5 says not to write as a finding.

### 7.6 Limits of the gate itself

These are limits of **this document's evidence**, not claims the product makes, so they live here
and **not** in §8 — §8's residuals are copied verbatim into `zk-verdict/README.md`'s honest scope,
where a statement about the harness would be noise to a reader asking what the escrow guarantees.
They are written down because an unstated limit is indistinguishable from a missed one.

- **L-1 — P-1…P-4 have no vector in AC-4.** The four pre-existing `NoProof` transitions (account
  proof, storage proof, code hash, duplicates) live in `verify_prestate_authenticity`, which 008
  does not change. AC-4's thirteen vectors cover every transition 008 **adds** (P-5…P-12) plus the
  positive controls. Adding four more vectors for unchanged code is coverage this task did not
  buy; if a later task changes `verify_prestate_authenticity`, it inherits the obligation.
- **L-2 — neither the `witness=` field nor a mutant proves a script performed a *build*.**
  `fixtures-check.sh` could compute the four vkeys from a cached artefact instead of a fresh
  `sp1-build`. The guards are AC-14(iv)'s `elf_sha256` equality against a freshly built ELF and
  `ac008.sh`'s `unset` of every `SP1_*` skip variable (§3.6.4). **Guards, not proofs** (§6.2).
- **L-3 — AC-13's own manifest row is satisfiable by `echo`, and nothing inside this repository
  closes that.** Its witness set is the eighteen `mutants/*.patch` files and **no mutant modifies
  a patch file**, so the `witness=` value is a constant for the whole run; step 0 (the patch count
  must be 18) and step 6 (AC-00b and `no-keys.sh` green after the last restore) are **inside the
  script a stub replaces**. A two-line `ac008-selftest.sh` that echoes
  `ac008-selftest: 18/18 mutants detected; witness=<that constant>` passes the row. Rounds 1–3
  named those three things as substitutes and let the reader infer they closed the gap; **they do
  not, and round 3 additionally asserted at §6.2 that no `script` row could be satisfied by a
  constant, which was false for exactly this row** (r3 finding 2).
  **The mutation gate's integrity therefore rests on the implementation review opening
  `ac008-selftest.sh` and `ac008.sh`, reading them, and running them — not on a mechanism.**
  §6.3's canary is the one cheap thing that raises the bar: `ac008.sh --all` applies M-9 itself
  and will not print its evidence line unless AC-06 detects it, so the cheapest stub now has to
  cover two scripts instead of one. **That is a higher bar, not a closure**, and this document
  does not claim otherwise. The regress does not terminate inside a repository: whatever runs
  last is trusted. **What round 5 adds is not a mechanism but an owner**: §7.8 binds
  `reckn-codex-review(stage=impl)` to read both scripts and run them itself, and says that a
  report-only acceptance of AC-13 is not an acceptance. A trust root that is asserted and never
  assigned is not a trust root (r4 finding 3).
- **L-4 — every number in §7.5 for the predicate and SVM guests is unmeasured.** Only the
  re-execution guest's 335.02 s exists. `4 × 335.02 s` is arithmetic on one measurement.
- **L-5 — check 5 is a source-level, lexical check, and three in-tree mutants now run inside
  `AGENTS.md` §0's widened region.** Two limits, both new with §6.4 and both stated rather than
  discovered later.
  **(i)** What check 5 does not establish is enumerated in §6.4 and repeated as **R-10** in §8:
  it says nothing about deployed bytecode, nothing about the *address* `verifier` holds, nothing
  about `ISP1Verifier`'s own source, and it performs no semantic analysis. 008's tier is local and
  008 deploys nothing, so 008 makes no deployment claim at all; the on-chain half belongs to a
  later task (§1.3).
  **(ii)** `RecknVerdictVerifier.sol` is now inside §0's region, and **M-15 still mutates it
  in-tree** under a `trap` that does not catch `SIGKILL`. That is deliberate and the reason is
  the *kind* of residue: M-15 swaps two **constant values**, changing no token, no count, no
  statement and no assignment target, so check 5 is silent on it **by construction** — and its
  residue is therefore **loud** everywhere else (AC-10 red, `zk-e2e.sh` red), unlike M-8's
  comment flip, which `no-keys.sh` is comment-blind to by design. Its restore is asserted by step
  5's per-file `sha256` and by step 6's `no-keys.sh` re-run, and §7.7 requires a clean
  `git status`. **A mutant on that file that changed its *structure* would have to be a sandbox
  mutant** — which is what M-17 is.

### 7.7 What the implementation report must state honestly

- The measured cycle counts for all three guests (they will be larger) and the ELF `sha256`s,
  copied from `cycles.json`.
- **The four Groth16 regeneration wall times, individually**, and the number of regeneration
  rounds `R` actually performed (§7.2, §7.5). If `R ≥ 2`, why.
- **`ac008-selftest.sh`'s per-mutant lines and total elapsed, verbatim** — including **all three**
  `sandbox control clean (M-8 / M-17 / M-18)` lines, which are what distinguish a real detection
  from a sandbox that failed for the wrong reason. If the total exceeded 40 minutes: a **stop**, not a
  trimmed mutant list. If any mutant went undetected: a **stop**, not a deleted mutant. If the
  sandbox control failed: a **stop**, and it must be reported as a **harness failure**, never as
  a detection.
- **`ac008.sh --all`'s evidence line verbatim, including the canary clause** (§6.3). A run that
  printed `18/18` without `canary M-9 detected by AC-06` did not run the canary and may not be
  reported as a pass.
- **That `git status` is clean after `ac008-selftest.sh` and after `ac008.sh --all`**, and that
  `zk-verdict/contracts/src/RecknZkEscrow.sol`'s `sha256` is still
  `07d649c2…33e45b`. M-8 never writes it; this is the cheap statement of that fact. The same
  statement is required for **`scripts/no-keys.sh`** and **`zk-verdict/contracts/src/RecknVerdictVerifier.sol`**
  after the run — M-17 never writes either, and the mutant it applies is a **working resolver**,
  so "the tree does not contain it" is the one sentence that must not be assumed.
- **Which of §6.4's five clauses fired for M-17**, quoted from the sandboxed `no-keys.sh`'s own
  output. If the answer is that a name grep for `tx.origin` fired, check 5 is not the check this
  document specifies and that is a **stop**, not a note (§6.4, AC-13 Falsify, `003`'s **R-7**).
- **The `computed:` digests observed at 8g and 18g**, and the fact that they equalled the
  selftest's own `D8` / `D18`. A run that reports `M-8 detected` without that comparison is
  reporting round 4's weaker assertion.
- If the exclusion-proof builder (V-14, §3.6) does not work as assumed: a **stop**, not a
  workaround and not a dropped vector.
- If `BLOCKHASH(n−1)` does not reach either database (W-12): a **stop** — the vector's premise
  is a read of `revm-interpreter-35.0.1/src/instructions/host.rs:163-192`, and if that read is
  wrong the right response is to say so, not to reshape the vector until it passes.
- Which manifest rows were red before the guest freeze, and for how long (§7.2 item 2).
- Anything in §7.3's lower table that was actually run, with its output — and nothing from
  that table that was not.

---

### 7.8 What the stage=impl review of 008 must do itself (new in round 5 — r4 finding 3)

**Why this section exists.** L-3 states that the mutation gate's integrity rests on the
implementation review opening `ac008-selftest.sh` and `ac008.sh`, reading them, and running them —
not on a mechanism. Round 4 wrote that in four places and **created no obligation on anyone**.
§7.7 binds the implementer's *report*; `AGENTS.md` §2 names the review stage but says nothing about
what it must open. With

```sh
# ac008-selftest.sh
printf 'ac008-selftest: 18/18 mutants detected; witness=<constant>\n'
# ac008.sh --all
printf 'ac008: 18/18 rows passed; canary M-9 detected by AC-06\n'
```

**every evidence line §7.7 asks for can be pasted verbatim into an implementation report, no
mutant runs, and no acceptance criterion in this document fails.** A trust root that is asserted
but not assigned is not a trust root.

**Who.** `reckn-codex-review`, at `stage=impl` for task 008 (`AGENTS.md` §2's cycle). Named,
because "someone should read it" is what round 4 already said.

**What, four obligations. All four are reported in `docs/reviews/008-impl-rN.md`.**

**(a) Read both scripts line by line.** `zk-verdict/scripts/ac008-selftest.sh` and
`zk-verdict/scripts/ac008.sh`, in full, not by grep. The specific things to read for are that step
0 counts **18** patches; that each of the three sandbox phases builds its **own** `$S`, runs its
clean control **before** its mutation, and scores a control failure as a **harness failure and
never as a detection**; that 8g and 18g compare the script's printed `computed:` against a digest
**the selftest computed itself**; that 17g asserts *which* check fired; and that no path under the
repository is ever opened for writing.

**(b) Run both, itself.** Not accept pasted output. `bash zk-verdict/scripts/ac008-selftest.sh`
and `bash zk-verdict/scripts/ac008.sh --all`, from a clean tree, with `git status` observed before
and after. **`AGENTS.md` §5: 走らせていないものを passing と書かない** applies to the reviewer
exactly as it applies to the implementer.

**(c) Record what it observed, from its own run.** The **per-mutant lines**, verbatim, from the
reviewer's own execution — including the three `sandbox control clean` lines and the per-mutant
elapsed times — and `--all`'s evidence line including the canary clause. Numbers copied from the
implementation report are not observations and may not be presented as the review's evidence
(`AGENTS.md` §5, and the same rule the founder applies to this spec's own numbers).

**(d) Verify by reading the four properties no mutant covers**, and say so explicitly rather than
letting the reader assume the gate covered everything:
1. **AC-13's own row** — `echo`-satisfiable, INV-14 case (c), L-3. The reviewer's own run under
   (b) is what stands in for the missing mutant.
2. **AC-0b requirement R5** — that `surfaces.sh` genuinely reads
   `$root/zk-verdict/scripts/surfaces.pinned` and does not carry the digests as literals in its
   own text. No mutant covers this, because the obvious one (mutating the pin) is the design the
   founder ruled against in OQ-5(b) and round 5 does not re-open it.
3. **AC-15** — a no-change criterion with a written exemption (§6.2).
4. **§6.4's five clauses as implemented** — that check 5 states properties and does not grep for
   the names of the constructs that exploit it (`003`'s **R-7**). M-17's patch is one input; a
   name-based check passes M-17 if it happens to grep for `tx.origin`. The reviewer applies the
   two witnesses named in AC-13's Falsify (`block.chainid`, and an `assembly` block reaching
   `origin()`) or reads the implementation and states that it is closed by vocabulary rather than
   by names.

**A report-only acceptance of AC-13 is not an acceptance.** If (b) was not performed, the review
records AC-13 as **unverified** and says so in its verdict line's body; it does not report it as
green on the strength of the implementer's transcript. If the review cannot run the scripts (no
SP1 toolchain, no `forge`), that is a **stop and report** to the founder under `AGENTS.md` §7 —
not a softer verdict, and not a green one.

---

## 8. Residuals — what 008 does not close

**A residual that is only in the spec is not disclosed, so each one below names its disclosure
site and AC-14 checks it there.** *(Round 4's preamble said all of them appear verbatim in the
rewritten honest scope (§9). That was **false for two of ten**, and nothing detected it: **R-7**
appeared in no shipped document at all —
`grep -rn 'min == 0\|zero floor\|minDelta == 0' README.md zk-verdict/README.md CLAUDE.md SUBMISSION.md`
returns **0 matches** today and would have returned 0 after 008 as round 4 specified — and
**R-8** is disclosed in the root `README.md:566-571`, not in the honest scope. AC-14(ii)'s seven
markers named neither. r4 finding 4; INV-11 is restated to what the mechanism enforces.)*

| residual | disclosure site | checked by |
|---|---|---|
| R-1, R-2, R-5, R-6 | `zk-verdict/README.md` honest scope, §9(1) | the section is rewritten wholesale; markers 1–3 pin its shape |
| R-3 | same, §9(1) — the **Not:** bullet | AC-14(i) literals 4–5, AC-14(ii) markers 3, 5, 6 |
| R-4 | same, §9(1) — the qualified header sentence | §9(1)'s round-4 note; no marker (stated) |
| **R-7** | same, §9(1) — **new sentence** | **AC-14(ii) marker 8** (new in round 5) |
| **R-8** | root `README.md:566-571`, which §9(3) leaves **untouched** | not moved by 008; INV-11(b) |
| R-9 | `zk-verdict/README.md` honest scope, §9(1) — the **Not:** bullet's restriction sentence | AC-14(ii) marker 3's neighbourhood |
| **R-10** | `AGENTS.md` §0 and the honest scope, §9(2a) / §9(1) | **AC-14(ii) marker 10** (new in round 5) |

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
  implementations* on the two sides. After 008, Δ is **outside D and not provable**: a witnessed
  Δ address makes **the guest itself panic** (P-12) and is also refused early at the host (G-2);
  an unwitnessed one fails on both sides (§3.6). **Not provable is not equivalent.** If a future
  task needs Δ, the parity is still unmeasured — OQ-3. *(Round 2 wrote "unreachable: witnessed →
  G-2 refuses", locating the enforcement in a host function the prover can skip. That premise was
  false; the caveat that followed it was correct and is kept, now attached to a true premise.)*
- **R-4 — the `state_root` ↔ block-header binding stays off-chain**, in
  `reexec-evm::header`. The guest never sees a header (N-5). After 008 the **typed host
  conversion** `to_guest_input` refuses an anchor that carries one (G-1) rather than silently
  stripping it — **a property of the host tool, not of the guest**: a raw `GuestInput` has no
  header field to carry, so the guest neither sees nor checks one, and a prover who builds the
  input by struct literal is refused nothing. G-1 is hygiene and claim-scope; the binding is
  off-chain either way. *(r3 finding 4: round 3 shipped the unqualified half of this sentence
  into the honest scope, which is the r2 BLOCKER's species one notch smaller.)*
- **R-5 — one CALL, one delta check.** A full block or an arbitrary contract set is more
  cycles on the same architecture. That is a claim about architecture, not a measurement.
- **R-6 — INV-1 is agreement with `reexec-evm`, not with mainnet.** The differential runs two
  local engines. No result here says the guest reproduces a real chain. This is also the
  ceiling on E-11 / E-12 and on AC-6's `TxEnv` check: two sides that are identically wrong
  pass.
- **R-7 — `min == 0` still admits a no-op.** `delta_outcome(x, x, 0, max) = REPRODUCED`, so a
  buyer who funds a zero floor pays for nothing. That is the buyer's predicate choice and 008
  does not override it, but it sits directly under the "a no-op cannot fake the credit"
  headline. **Disclosed in `zk-verdict/README.md`'s honest scope by §9(1), checked by AC-14(ii)
  marker 8.** *(Round 4 listed this residual and shipped no disclosure of it anywhere — the §8
  preamble asserted otherwise and no criterion could see the difference. r4 finding 4.)*
  **One correction to round 4's framing, in the honest direction:** OQ-4 called this "the attack
  `zk-verdict/README.md:143` advertises as impossible". Line 143 reads *"A no-op (`--credit 42`)
  → delta 0 → `Failed`"* — a statement about **that fixture**, whose floor is `min ≥ 1`, not a
  universal claim. **The shipped exposure is smaller than round 4 wrote; the disclosure gap is
  the same size.** See OQ-4.
- **R-8 — the escrow still has no timeout.** If P-1…P-11 make a proof impossible, a funded
  deal stays funded. That is `003`, not 008, and 008 *increases* the set of inputs for which
  no proof exists (P-5…P-11, plus the three gate refusals), which strengthens the case for
  `003` landing next.
- **R-9 — outside D, 008 claims nothing.** Three input shapes are refused: an anchor carrying a
  block header (G-1, host), a predicate that is not a single-check `PostStateDelta` (G-3, host),
  and a witness or plan target containing a Δ precompile address (**P-12 in the guest**, G-2 early
  at the host). For all three, `reexec-evm` may still produce a verdict while the zk path produces
  nothing. That is a **liveness reduction, chosen deliberately over an unsound proof**, and it is
  the honest reading of what "the same engine" means today. Round 1 stated INV-2 as an
  unconditional biconditional and it was false in both directions; round 2 scoped it to D but
  enforced one of D's clauses only on the prover's own machine.
- **R-10 — check 5 constrains the verifier contract's *source*, and only lexically** (new in
  round 5, §6.4). 008 brings `RecknVerdictVerifier.sol` inside the build condition because 008
  edits it and it is on the settlement-authority path. Four things that check does **not**
  establish, stated here because they are limits of the product's claim and not only of the gate
  (L-5): it says nothing about the **bytecode actually deployed** (008's tier is local and 008
  deploys nothing, so 008 makes no deployment claim); nothing about the **address** the
  constructor was given, so a verifier pointed at a lying `ISP1Verifier` is not detected here;
  nothing about **`ISP1Verifier`'s own source**, a vendored dependency outside every file 008
  reads; and it performs **no semantic analysis** — it rejects a syntactic class, and the reason
  that is enough for INV-15 is that 5b + 5d pin the body to two statements rather than reasoning
  about what a body means. Closing the first two is a later task's (§1.3); 008 neither closes them
  nor implies it has.

---

## 9. Documentation obligations (same commit, no exceptions)

Documents move with the code. AC-14 enforces (1), (1a), **(1b)**, (2), **(2a)**, **(2b)**,
**(2c)**, (3) and (4) mechanically — nine numbered obligations with a marker or a literal each.

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
>   puts `0x01`, `0x0a` and `0x0b`–`0x11` **outside the domain a proof can speak about**: if one
>   is in the witness **the guest refuses to produce a proof**, and if it is not, both sides fail
>   on the missing witness. That is a restriction on which plans are provable, **not** a claim
>   that the two backends compute the same thing — their equivalence is still untested. `BLOCKHASH` is unavailable to both. `DIFFICULTY` and
>   `BLOBBASEFEE` read a fixed default on both sides and are not anchored to a real block.
>   One CALL, one delta check. The predicate's floor is the buyer's choice, and
>   **a floor of zero is satisfied by doing nothing**: `min = 0` makes the delta check vacuous,
>   because `post ≥ pre` holds when nothing happened. The causal-delta property — a seller who
>   does nothing, or who reduces the checked slot, is refused — holds **for every `min ≥ 1`, at
>   every magnitude**, which is what task 008 closed; it is not a property of `min = 0`, and the
>   guest does not refuse `min = 0` because the off-chain predicate accepts it. **The typed host conversion refuses an anchor that carries a
>   header; a raw `GuestInput` has no header field to carry, so the guest neither sees nor
>   checks one — the `state_root`↔header binding stays off-chain**, in the
>   `reexec-evm::header` layer. Agreement is with `reexec-evm`, not with mainnet.

*(Round-5 change, r4 finding 4: the `min = 0` sentence is **new**. It is the disclosure of R-7,
which round 4 listed as a residual and shipped nowhere — measured: zero matches in every published
document. AC-14(ii) marker 8 is `a floor of zero is satisfied by doing nothing`. The sentence also
states the property that **is** true, so the disclosure does not read as a retraction of what 008
actually closed: the round-4 honest scope's own `pre = 2^64 / post = 2^64 − 1` sentence is
untouched.)*

*(Round-4 change, r3 finding 4: round 3's last sentence read "an anchor that carries a header is
refused rather than silently stripped", with no subject. Against the adversary §3.2(c)(1) names —
a prover who builds `GuestInput` by struct literal at `zk-verdict/script/src/bin/reexec.rs:123`
and writes it to stdin at `:166` — **nothing is refused**, because there is no header field in the
bytes the guest reads. Nothing is gained by the prover either, which is why G-1 is hygiene and not
soundness (§3.6). But the sentence sat in the product's guarantee list stating a **host-tool**
property unconditionally, which is the r2 BLOCKER's species one notch smaller. The replacement
names the subject and says what the guest does and does not do. AC-14(ii)'s marker list is
unchanged — this sentence is not one of the seven markers.)*

**(1a) `zk-verdict/README.md:105-108`, the fixture-gating sentence** — replaced (r2 finding 8).
AC-11 turns every `if (!vm.exists(F)) return;` into a `require`, so after 008 nothing is gated on
fixture presence and the current sentence is false as written. AC-14(i) literal 8 removes it;
AC-14(ii) marker 7 requires the replacement:

> `RecknVerdictVerifierFixture.t.sol` reads the committed fixture directly. All four fixtures are
> in the repository and AC-9 keeps them current, so **a missing fixture is a hard failure**, not a
> skipped test.

**(1b) `zk-verdict/README.md:97`, the `~34 s` figure** — **qualified in place, not deleted**
(r4 finding 9). The sentence today reads *"a **real Groth16 proof** of the verdict was generated
on CPU (the gnark prover, ~15.9M constraints, ~34 s once the artifacts are local)"*. §7.5 measured
the **gnark wrap alone** at 31.71 s and the **end-to-end regeneration of one fixture** at
`real 335.02 s` — roughly 10×. Narrowly read the sentence is defensible; read by anyone else it is
the cost of producing a proof, and the error is in the flattering direction (`AGENTS.md` §5).
Append, inside the same parenthesis so the file still contains **exactly one** `~34 s`:

> (the gnark prover, ~15.9M constraints, ~34 s once the artifacts are local — **the gnark wrap
> alone**; end-to-end regeneration of one fixture measured at 335 s, §7.5 of `docs/specs/008-*`)

AC-14(ii) marker 9 is `the gnark wrap alone`; AC-14(v) asserts the occurrence count is **1**.
**Do not delete the figure and do not add a second occurrence** — a later task in the execution
order pins how many times that string appears in that file (§1.3), so both directions break it.

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
>   `0x01` / `0x0a` / `0x0b`–`0x11` は **proof が語れる領域の外**に置いた
>   （witness にあれば **guest 自身が proof を作らない**、無ければ両側とも失敗）。
>   これは**証明できる plan の制限**であって、両者が同じ計算をするという主張ではない。等価性は未検証。

The other §5 bullets (one CALL + one delta check; the `state_root`↔header layer; the
"tier を超えない / 走らせていないものを passing と書かない" discipline; and the new
"名前でなく本体" discipline) are unchanged.

**(2a) `AGENTS.md` §0 — the enumerated surface gains a second file.** This is the declaration
`AGENTS.md` §0 itself demands of any agent that changes what the build condition asserts, and
`reckn-spec`'s charter demands of any change to the claim. **What changed, in the words §0 uses:**

> `bash scripts/no-keys.sh` が読むのは `RecknZkEscrow.sol` **と
> `zk-verdict/contracts/src/RecknVerdictVerifier.sol` の二つ**になった。二つ目は決済権限の
> 経路上にあり（`RecknZkEscrow.sol:99` が `verifyVerdict` を呼び、返る struct を信じる）、
> **task 008 がこのファイルを編集する**ため、008 が検査を入れる。検査は**禁止語の列挙ではなく
> 閉包性質**（識別子語彙・宣言数・本体の文形・代入先）で、`verifyVerdict` に分岐も環境読みも
> 追加できない。**これは緩和ではなく締め付け**で、列挙された関数面
> （`fund` / `settleWithProof` / `refundAfterDeadline`）は変わらない。
> **check 5 を緩める変更は founder 判断。**

AC-14(ii) marker 10 is the substring `RecknVerdictVerifier.sol` in `AGENTS.md`; measured today it
appears **0** times in that file. 008 does **not** touch §0's other rules, does not touch §5's
three bullets beyond (2), and does not touch §3, §7 or §8.

**(2b) `CLAUDE.md`, the 中心主張 block (`:16-18`)** — same declaration, one sentence.
`CLAUDE.md:16` names `RecknZkEscrow.sol` as *the* file the claim lives in; after check 5 that is
incomplete rather than false, and an incomplete statement of the central claim in the file every
agent reads first is exactly the drift `CLAUDE.md:41-43` records this repository shipping twice.
AC-14(ii) marker 11 is the substring `RecknVerdictVerifier.sol` in `CLAUDE.md`; measured today it
appears **0** times.

**(2c) `scripts/no-keys.sh`'s own header comment (`:11-12`)** — the scope sentence *"the body of
`contract RecknZkEscrow` only, with comments stripped"* becomes false in this commit. Replace it
with the two-file region and the one-line reason for the second file. **AC-14(i) literal 9** is
the check that the old sentence did not survive; there is no marker for the replacement text
because check 5's own existence is what AC-13's M-17 verifies, and a marker on a comment would be
the "名前でなく本体" pattern `AGENTS.md` §5 forbids.

**(3) Root `README.md`, "Known gaps (not closed)"** — line ranges **re-measured today**
(round 1's three ranges were all wrong, r1 finding 8; the section is now 44 lines,
`222eeeb84230c54050e9db26c9c070e1425ac3c9d92e4193a98431dca05ef99f`):

| bullet | lines today | 008's obligation |
|---|---|---|
| "In-guest precompiles run on different backends, and parity is unverified." | **572-579** | **Already correct** — landed in `9ac4545` (2026-09-04 10:06:43), *after* the 008 spec commit `d4f59ba`. 008 **verifies it is unchanged** (AC-14(ii) marker 6) and appends one sentence recording that Δ is now outside the provable domain. Round 1 instructed 008 to "correct" it, which was already done. |
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
re-pin it (§1.3), **that `scripts/no-keys.sh` now checks two files and that check 5 is 008's
minimal form which the next task extends (§1.3, OQ-6)**, and the two documentation drifts 008
cannot fix itself (OQ-1, OQ-2).

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

- **OQ-2 — answered for `003`; open only as a `004` dependency.** *(Restated in round 5.
  Round 4 called this "the one open question that needs an answer before implementation starts";
  it is not, any more. `003`'s current revision answers all three couplings on its side — the
  honest-scope digest is no longer a literal it carries, it no longer quotes the v1 binding
  preimage, and it re-pins `surfaces.pinned` in the same commit that changes the contract, with
  the path corrected to `zk-verdict/scripts/`. r4 finding 7.)*

  **Both of round 4's cross-spec line citations were stale, and round 5 does not repair them —
  it drops them.** A line number in a document another agent is revising this hour is not a
  citation, and this specification must contain **no literal whose truth depends on a spec that is
  not APPROVEd**. Where 008 needs to refer to a neighbouring spec it does so by **content and by
  the founder/orchestrator ruling that created the coupling**, never by line or by quoted string.

  **What remains open, and it is `004`'s, not `003`'s.** `004` re-implements the v1 preimages
  inside `live-input/`. Read today, it goes stale in **three** ways, not the one round 4 named:
  1. the **domain tag** moves `v1 → v2` (`004:370`);
  2. the **encoding rule** changes — `004:372` uses `le64(MIN_OUT)` / `le64(MAX_DELTA)` and §3.3
     makes every preimage fixed-width **big-endian**, so the widths and the byte order both move;
  3. **`gas_limit` becomes a bound component.** `004:369` computes
     `planHash = keccak256(caller ‖ target ‖ calldata ‖ value)` **without** `gas_limit`, and `004`
     carries a whole residual about that omission (`004:86` defers it, `004:1178` and `:1201-1204`
     state it as an invariant and a limit). **008's `plan_hash` includes `gas_limit:u64BE`**
     (§3.5) and AC-7a tests it as one of the 18 bound components — so 008 **resolves** `004`'s
     residual, and `004`'s text describing it as open becomes false. Round 4 named only (1).

  Options, unchanged in shape: **(a)** 008 lands and `004` updates its preimage section in its
  next round; **(b)** 008 holds its documentation changes until `004` lands.
  **Recommendation: (a).** (b) would ship the code fix with the false honest-scope text still in
  the repository, which is the failure mode `AGENTS.md` §5 exists to prevent, and `004` is behind
  `003` in the execution order anyway. Cost is one line in `STATUS.md` and a section rewrite `004`
  must do regardless. **008 does not edit `004`** (N-11).

- **OQ-3 — precompile backend parity (R-3) is a production performance decision.** 008 puts Δ
  outside D, which is enough for INV-1/INV-2 but is a *liveness* restriction: a future plan
  that legitimately needs `ecrecover` (a permit-style ERC-20, a signature-gated delivery) is
  refused rather than proven. The only way to close it is to build `reexec-evm` with
  `default-features = false` so both engines run the same `k256` / `arkworks` implementations
  under the same feature set. That
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
  **Two round-5 corrections to this question** (r4 finding 4). **(i)** The sentence above claimed
  `zk-verdict/README.md:143` *"advertises as impossible"* what R-7 permits. It does not: line 143
  reads *"A no-op (`--credit 42`) → delta 0 → `Failed`"*, a statement about **that fixture**, whose
  floor is `min ≥ 1`. It is not a universal claim, so **the shipped exposure is smaller than round
  4 wrote**. **(ii)** The recommendation says *"disclose R-7"* and round 4 gave that recommendation
  **no implementing obligation anywhere** — so accepting the recommended option would have shipped
  nothing. It now has one: §9(1)'s sentence and AC-14(ii)'s marker 8. **Accepting the
  recommendation is now the default path; overriding it is what needs the founder.**

- **OQ-5 — RULED 2026-09-04. M-8 becomes a sandbox mutant; `RecknZkEscrow.sol` is never
  written.** *(No longer open. Kept in §10 rather than deleted because the record of **how the
  question was asked** is the part worth keeping — see below.)*

  **The ruling.** Neither (a) nor (b): the founder ruled a **fourth design, the sandbox layout**
  (`STATUS.md`, "裁定 — OQ-5"). `ac008-selftest.sh` reconstructs the layout in a temp directory,
  proves the clean copy passes, mutates the **copy**, requires the copied `surfaces.sh` to fail,
  and `rm -rf`s the directory. `AGENTS.md` §0 needs no exception, **N-1 returns to literal
  truth**, and `003` had already measured the technique working on `no-keys.sh` in its §4.5.9 on
  the same day. The four load-bearing requirements are written into AC-0b (the **Location rule**)
  and AC-13 (**mode `sandbox`**, steps 8a–8h): root derived from `$(dirname "$0")/../..`; all
  four of AC-0b's inputs copied, `reexec-evm/src/lib.rs` included; a **clean-copy control before
  the mutation**; and `rm -rf "$S"` as the restore. Which other mutants are sandboxed: **none**
  (AC-13, mode paragraph).

  **The record of the question, which is the part that was wrong** (r3 finding 3). Rounds 1–3
  offered three options — **(a)** violate §0, **(b)** weaken the test, **(c)** delete the test —
  and recommended (a). **In that enumeration only the §0 violation is strong, so the
  recommendation followed from the enumeration rather than from the problem.** Two options were
  missing, and **both avoid touching §0's file entirely**:

  - **(d) the sandbox** — the one the founder ruled. It has (a)'s detection strength and none of
    its cost.
  - **(e) point M-8 at AC-0b's *second* clause** — a comment byte **above** line 711 of
    `reexec-evm/src/lib.rs`, which tests "the script computes a digest from a real file" without
    going near the contract. Weaker than (d) — it never exercises the clause that guards §0's
    file — but strictly better than (b) and (c), and it was not on the list.

  This is the same shape as r1 finding 12 (*"the (b) cost enumeration is incomplete in the
  flattering direction"*), recurring in §10 two rounds later. **The habit, not the conclusion, is
  what is recorded here**: when this document prices options, the enumeration is itself a claim
  and it has now twice been built in the direction that flattered the option being recommended.
  `AGENTS.md` §5's *"数字が製品に都合よく転んだときこそ疑う"* applies to option **sets**, not only
  to numbers.

  **What round 3 got right, kept and attributed** (the r3 review confirmed both):

  - **(b)'s rejection is correct, and the founder's reason is the sharper one.** Round 3 rejected
    (b) as "only tests the comparison". The founder's form is stronger and is the one to carry:
    mutating `surfaces.pinned` makes **every** implementation fail — including one that digests
    the *wrong file*, or hashes only part of the contract — so it tests the comparison and **not
    the binding between the digest and `RecknZkEscrow.sol`**, which is the only property AC-0b
    exists for. A pin mutant would pass the exact degenerate implementation AC-0b is written to
    kill (AC-0b, "The degenerate implementation M-8 exists to kill").
  - **(c)'s pricing is correct.** With no mutant on AC-00b, nothing moves a byte inside its
    witness set, so the row returns to `echo`-satisfiable — for the one row that guards §0's file.

  **One risk (a) never carried, added because it supports the ruling rather than the
  recommendation.** A `trap` catches `EXIT INT TERM`. It does **not** catch `SIGKILL`, a host
  panic, or a power loss. A hard kill between `patch` and `restore` leaves a **mutated
  `RecknZkEscrow.sol` in the work tree**, and `scripts/no-keys.sh` — comment-blind by design
  (`scripts/no-keys.sh:28-30` strips comments before every check) — would **not** notice it at the
  next commit, because M-8's mutation is a comment. Neither would `AGENTS.md` §0's pre-commit
  ritual, for the same reason. The sandbox **removes** this failure mode rather than mitigating
  it: a hard kill during M-8 leaves an orphaned temp directory. Round 3 priced (a) without this,
  which is a third instance of the same direction of error in the same section.

- **OQ-6 — RULED 2026-09-04. `AGENTS.md` §0's checked region gains a second file, and 008 is
  the task that adds it.** *(Not open. Recorded here, in OQ-5's form, because the **shape of the
  mistake** is worth keeping: the fact that made the hole findable was written into round 4's own
  text and used as an argument in the opposite direction.)*

  **The question, as the r4 review put it:** whether `AGENTS.md` §0's enumerated surface gains a
  second file is a founder-level decision and should not be made silently by an agent.

  **The ruling** (orchestrator, 2026-09-04): **yes, and it is 008's.** Three reasons, in the order
  they bind:
  1. **008 edits the file** (§3.4, N-12). An agent editing a settlement-path contract that the
     build condition does not read is `AGENTS.md` §0's failure mode arriving through the door §0
     was not watching.
  2. **A check that does not exist when a file is first opened is not a check.** The execution
     order is `008 → 009 → 003`. Attributing the check to a later task leaves the region open
     across the two tasks the **9/9 checkpoint** turns on (`AGENTS.md` §7).
  3. **It is a tightening.** The set of trees `no-keys.sh` accepts strictly shrinks; no function
     surface widens; the script's interface, arguments and final line are unchanged. §0's own rule
     that *loosening this check is a founder decision* is untouched — and **relaxing check 5 later
     is exactly such a decision, not an implementer's fix.**

  **What 008 writes and what it does not.** 008 writes the **minimum that closes the splice**: one
  new numbered check over one new target, five closure properties (§6.4), one sandbox mutant
  (M-17), one invariant (INV-15), and the declaration in `AGENTS.md` §0 / `CLAUDE.md` /
  the script's own header (§9(2a)–(2c)). 008 does **not** write the extension — the constructor's
  semantic closure and the on-chain deployment check belong to the next task (§1.3) — and 008
  copies **no literal** from that task's spec, which is not APPROVEd.

  **The record of how the hole survived four rounds, which is the part worth keeping.** Round 4
  wrote, verbatim, that `RecknVerdictVerifier.sol` *"is not the file `AGENTS.md` §0 is about and
  which `no-keys.sh` does not read"* — and used it as the reason the file needed **no** sandbox.
  The same sentence is the statement of the hole. This is the third instance in this document of
  the pattern OQ-5 already records: **an enumeration or a justification built in the direction
  that flatters the option being defended** (r1 finding 12, OQ-5's three-option set, and now
  this). `AGENTS.md` §5's *"数字が製品に都合よく転んだときこそ疑う"* applies to **reasons**, not
  only to numbers and option sets. The operational form of the rule, for whoever writes round 6:
  **when this document states a fact about what a check does not cover, ask whether the sentence
  is a defence or a finding before deciding which.**

**Not open, recorded so round 6 does not re-open it:** the M-8 mechanism (founder ruled the
sandbox on 2026-09-04; OQ-5 above is the record, not a question) and which other mutants are
sandboxed (**none**); that **P-12 closes G-2's soundness half** — the four call opcodes share one
account-loading path (`revm-interpreter-35.0.1/src/instructions/contract.rs:158,203,248,293` →
`load_acc_and_calc_gas` → `db.basic` at `revm-context-16.0.1/src/journal/inner.rs:927`), so the
witness's account set is a superset of every address the execution can reach and the syntactic
check needs no execution tracing; that **Δ is complete at 9 addresses** (`bn` / `gmp` are not
default features); **G-3's relabel and remedy (a)**; the **`head -710` rule**; **AC-7a's
restatement**; **§7.5's tier discipline** (its one correction landed as r3 finding 8); whether
option (a) of §3.1 is right (founder
ruled: yes, keep (a), (b) is not a completion state); whether precompile addresses skip the
database read (rejected with source in r1 R-1, and reproduced in §2.5 and §3.6 because the
unwitnessed Δ case depends on it); the empty-MPT-proof asymmetry (008 was right, r1 was wrong —
`alloy-trie-0.9.5/src/proof/verify.rs:29-43` plus `program-revm/src/main.rs:58-60,67-72`;
r2 verified it independently and Codex agreed); whether scoping INV-2 to **D** is a weakening
(r2: it is a **sharpening**); whether `surfaces.pinned` is a ritual (r2: no — its one defect was
that the digests were unstated, and AC-0b now states them); and whether the r2 cut list should be
taken (no — §7.5 measured the regeneration and the binding constraint is `R`, not test count);
and, added after round 4: **P-12, Δ = 9, G-3, the `head -710` rule, AC-7a, §7.5's tier discipline,
the sandbox skeleton and N-1's literal truth** (the r4 review re-verified each independently);
**that `surfaces.pinned` must not be mutated** (OQ-5(b)'s rejection stands, which is why AC-0b's
R5 is verified by reading and says so — §7.8(d)); and **that 008 introduces check 5 rather than a
later task** (OQ-6 above).

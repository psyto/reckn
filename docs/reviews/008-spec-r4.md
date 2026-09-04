# Review 008 spec round 4

Payload: `/tmp/reckn-payload-008-spec-r4.md`
Codex raw: `/tmp/reckn-codex-008-spec-r4.md`
Subject: `docs/specs/008-verdict-domain-soundness.md` (**2744 lines**), drafted by
`reckn-spec` (**Claude Code**). Codex did **not** write it, so author independence is
satisfied and Codex was used as a full adversarial reviewer. Stated in payload §0.

**Codex invocations this round: 1 effective.** The first invocation was killed by *my* harness
at the 10-minute foreground limit and produced **no output file** (`/tmp/reckn-codex-008-spec-r4.md`
did not exist). The identical payload — not edited, not softened — was re-issued in the
background and returned once. This was a harness failure, not a re-run of a disliked answer;
recorded here because the rule is worth being able to audit.

Everything below was re-checked against the files on disk on **2026-09-04**. No number from
r1/r2/r3 is carried over.

---

## What I verified myself before judging any finding

| claim | measured today | result |
|---|---|---|
| `sha256(RecknZkEscrow.sol)` = `07d649c2…33e45b` (AC-0b literal) | `shasum -a 256` → identical | ✓ |
| `sha256(head -710 reexec-evm/src/lib.rs)` = `b4fd62d5…b29d1` | identical | ✓ |
| line 711 is `#[cfg(any(test, feature = "testkit"))]`, sole occurrence | `grep -c` → 1, at 711 | ✓ |
| `reexec-evm/src/lib.rs:708-710` is the testkit doc comment (inside the pinned prefix) | read | ✓ |
| `no-keys.sh` derives root from its own location (`:17-19`) and reads **only** `RecknZkEscrow.sol` (`:19`) | read | ✓ |
| `zk-verdict/scripts/` contains `zk-e2e.sh` only — `surfaces.sh` / `surfaces.pinned` do not exist yet | `ls` | ✓ |
| the host builds `GuestInput` by struct literal at `script/src/bin/reexec.rs:123` and writes stdin at `:166` | read | ✓ |
| manifest arithmetic: 8 cargo rows sum to 91 (8+14+13+13+18+6+3+16) | recomputed | ✓ |
| AC-13's 16 mutants: 6 guest + 2 native + 2 forge + 1 check + 5 zero-build, all distinct | recomputed | ✓ |
| N-1 consistency: **no remaining instruction anywhere in the spec writes `RecknZkEscrow.sol`** | `grep -n 'RecknZkEscrow'` over all 28 hits, each read in context | ✓ |
| r3 MINOR 5 (`:536` "byte-identical") is actually restated at `:600` (the G-2 row) as *same crate / identical outputs by construction / different code path*, with the `std`→blake2 AVX2 citation; OQ-3's twin overstatement is gone | read | ✓ |
| r3 MINOR 6 (AC-11 witness) is restated as **the glob**, five before / six after (`:1125`) | read | ✓ |
| r3 MINOR 7 (testkit placement) is written at `:1327-1336` | read | ✓ |
| r3 MINOR 4 (host-only qualification) lands in §9(1) `:2529-2532`, N-5 `:193-206` and R-4 `:2468-2476` — all three carry the qualification, so the verbatim copy stays true | read | ✓ |
| r3 MINOR 8 (§7.5 conditional) is stated at the point of the conclusion with both quantities named and the direction given | read | ✓ |
| `003` r5 §1.5.2 answers all three OQ-2 couplings and corrects the path to `zk-verdict/scripts/` | read (`003:297-331`) | ✓ |

**The sandbox construction itself holds where it is specified.** The clean-copy control (8d)
precedes the mutation (8e), a control failure is `sandbox control failed` and not a detection
(8d, and again in §7.7), all four AC-0b inputs are copied (8c), and 8h re-asserts the four
repository digests. The Location rule (`:1294-1320`) forbids the four escapes that would make
the sandbox inert, and it is right that `git rev-parse --show-toplevel` is the one worth naming:
`$S` is not a git repository, so it walks upward into the real tree. An escape yields a
**false "not detected"**, which fails AC-13 — the safe direction. **This is not where the
sandbox is weak.** Findings 1 and 2 are about what the sandbox does *not* reach.

---

## Findings

### 1. [BLOCKER] `zk-verdict/contracts/src/RecknVerdictVerifier.sol` is on the settlement-authority path, 008 must edit it, and no 008 criterion guards it

`docs/specs/008-verdict-domain-soundness.md:465-469` (the `uint64` → `uint256`
`VerdictPublicValues` rewrite), `:1757` (*"Falsify: revert `RecknVerdictVerifier`'s struct to
`uint64`"*), `:1842` — and `scripts/no-keys.sh:19`.

Settlement authority in the keyless path runs
`RecknZkEscrow.settleWithProof` → `RecknVerdictVerifier.verifyVerdict`
(`RecknZkEscrow.sol:99`) → `ISP1Verifier.verifyProof` + `abi.decode`
(`RecknVerdictVerifier.sol:50-56`). The escrow trusts whatever struct that function returns.

008 **modifies that file** — the four value fields go `uint64` → `uint256` (`:465-469`), and
`:1757` names reverting it as a falsification, so the edit is not optional. But:

- `scripts/no-keys.sh:19` targets `RecknZkEscrow.sol` and nothing else — so **AC-0** cannot see
  this file;
- **AC-0b** pins exactly two things, `RecknZkEscrow.sol` and `head -710 reexec-evm/src/lib.rs`
  (`:1269-1272`) — this file is in neither;
- **§7.1's file table (`:2163-2178`) does not list it at all**, although §3.4 changes it;
- the only mutant that touches it, **M-15** (`:1954`), swaps the `REPRODUCED`/`FAILED`
  constants, which a spliced branch does not disturb;
- **`:1842` states the fact and draws the opposite conclusion**: *"M-15 touches
  `RecknVerdictVerifier.sol`, which is not the file `AGENTS.md` §0 is about and which
  `no-keys.sh` does not read"* — used there as a reason it needs no sandbox, while it is also
  the reason nothing guards it.

**Repro** (Codex's, verified by me against the real contract). Splice into `verifyVerdict`
before `verifyProof`:

```solidity
if (tx.origin == 0x0000000000000000000000000000000000001337) {
    v.outcome = REPRODUCED;
    v.dealBinding = bytes32(publicValues[0:32]);
    return v;
}
```

The key holder calls `settleWithProof(dealId, publicValues, "")` with the deal's public
`dealBinding` as the first 32 bytes. `verifyProof` is never reached, `v.dealBinding == d.dealBinding`
passes at `RecknZkEscrow.sol:103`, `v.outcome == REPRODUCED` pays the seller at `:111`.
**Every 008 criterion stays green**: AC-00 never opens the file; AC-00b does not pin it; AC-10's
four forge tests never set that `tx.origin`; AC-8/AC-9 are unaffected; M-15 does not reach the
branch. `bash scripts/no-keys.sh` exits 0.

**Why this is 008's problem and not `003`'s.** `003` r5 adopted exactly this as its own BLOCKER 1
and answers it with check 15 (P4/P5 over that file) — but the execution order is
`008 → 009 → 003`, and **008 is the commit that opens the file**. The gap is live for two whole
tasks, on the head task of the 9/9 checkpoint, and `AGENTS.md` §0's failure mode ("a key exists
after all") is reintroduced by an agent editing a file the build condition does not read.

**Round-5 closure (small, and already designed next door).** Do **not** pin a digest — 008
changes the file, so no literal can be written here. Use the property form `003` r5 already
specifies: extend `surfaces.sh` with a third clause over `RecknVerdictVerifier.sol` —
exactly one `function`, named `verifyVerdict`; its body is two statements; no control-flow
token and no `msg.sender` / `tx.origin` / `block.` anywhere in the contract — plus one
**zero-build sandbox mutant** that splices the branch above and must be detected.
Consequences to state, not to hide: AC-00b's evidence line and witness set grow by one file,
AC-13's patch count moves off 16, and `AGENTS.md` §0's enumerated surface may need a second
file declared (that part is a founder call, and `003` D-12 already proposes it).

### 2. [MAJOR] AC-00b is satisfiable by a `surfaces.sh` that never computes a digest and never reads `surfaces.pinned`; and no mutant exercises AC-0b's second clause at all

`docs/specs/008-verdict-domain-soundness.md:1252-1362` (AC-0b), `:1356-1362` (the degenerate
implementation the spec says M-8 exists to kill), `:1864-1890` (mode `sandbox`), `:1954` (M-16
is explicitly *below* line 711).

The spec names one degenerate implementation — a heredoc that "never opens either file" — and
shows M-8 kills it. It does not name the **half**-degenerate one, which M-8 does not kill:

```sh
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
target="$root/zk-verdict/contracts/src/RecknZkEscrow.sol"
if grep -q '<the exact comment text M-8 flips>' "$target"; then
  echo 'surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged; witness=<clean constant>'
  exit 0
fi
exit 1
```

It obeys the Location rule; the clean control (8d) passes; 8g exits non-zero, so **M-8 is
recorded as detected**; on the clean tree AC-00b passes and `ac008.sh`'s recomputed `witness=`
matches the hardcoded one. It never runs `shasum`, never opens `surfaces.pinned`, and never
opens `reexec-evm/src/lib.rs`.

Two consequences:

- **r2 finding 6's fix is re-openable.** The point of writing the two digests as *literals of
  this specification* (`:1258-1266`) was that the implementer must not both author the pin and
  be bound by it. A script that never reads `surfaces.pinned` restores exactly that: the only
  thing tying the tree to the **base commit** is the pinned literal, and nothing forces it to be
  read. `ac008.sh`'s independent witness recomputation catches drift only *relative to the
  moment the constant was hardcoded*, not relative to the base commit.
  It also makes `003`'s D-11 re-pin protocol (§1.3) inert.
- **AC-0b's second clause has no mutant.** M-8 mutates the contract; **M-16 is specified as
  landing below line 711 precisely so that AC-0b does not move** (`:1954`). So nothing tests
  that `surfaces.sh` enforces the `head -710` prefix at all. That clause is not hygiene: it is
  what stops 008's implementer from editing `reexec-evm::replay` — **the oracle the whole
  differential (INV-1) compares the guest against**. An implementer who "fixes" a disagreement
  by moving the reference instead of the guest is the failure `AGENTS.md` §5 names, and AC-15
  (16 tests, same package) and AC-16 (consumers compile) do not catch a compiling change.
  INV-13's "mutated or exempt in writing" is satisfied at row granularity and violated at clause
  granularity, with no exemption written.

**Round-5 closure, cheap and count-preserving for the first half.** (i) Step **8g** must also
require the script to print `computed: <digest>` and the selftest must check it equals the
selftest's *own* `sha256` of the mutated copy — a `grep` cannot produce that value, so the
half-degenerate script dies; (ii) add a second sandbox phase mutating `$S/reexec-evm/src/lib.rs`
**above line 711** and require non-zero again (still zero-build, still under 60 KB); (iii) state
"`surfaces.sh` reads `$root/zk-verdict/scripts/surfaces.pinned` and compares against it" as a
checked property of AC-0b, not as prose in the Location rule paragraph.
(Do **not** mutate `surfaces.pinned` — the founder's OQ-5 reasoning against that is correct and
is not being reopened.)

### 3. [MAJOR] The spec names the implementation review as its sole remaining trust root and then creates no obligation on it

`docs/specs/008-verdict-domain-soundness.md:2393-2408` (L-3), `:1173` (AC-13's exemption cell),
`:1226-1231` (§6.3's closing), `:2412-2440` (§7.7).

L-3 states that "the mutation gate's integrity therefore rests on the implementation review
opening `ac008-selftest.sh` and `ac008.sh`, reading them, and running them — not on a
mechanism." I accept that framing: the regress genuinely does not terminate inside a repository,
and round 4's honesty about it is not a dodge — it is stated in four places and the section ends
with what the canary does **not** buy. **But the obligation is never installed.** §7.7 binds the
*implementer's report*; nothing binds the *reviewer*. `AGENTS.md` §2 does not name it either. A
trust root that is asserted but not assigned is not a trust root.

**Repro** (Codex's, verified): with

```sh
# ac008-selftest.sh
printf 'ac008-selftest: 16/16 mutants detected; witness=<constant>\n'
# ac008.sh --all
printf 'ac008: 18/18 rows passed; canary M-9 detected by AC-06\n'
```

every displayed evidence line in §7.7 can be pasted verbatim into an implementation report,
no mutant runs, and no acceptance criterion in this document fails.

**Round-5 closure: one subsection.** The stage=impl review of 008 must (a) read
`ac008-selftest.sh` and `ac008.sh` line by line, (b) run both itself rather than accept pasted
output, (c) record in `docs/reviews/008-impl-rN.md` the per-mutant lines it observed **from its
own run**, and (d) verify by reading the properties no mutant covers — AC-13's own row, and
(if finding 2's remedy is not taken) AC-0b's second clause and the reading of `surfaces.pinned`.
**A report-only acceptance of AC-13 is not an acceptance**, and that sentence belongs in the
spec, where the implementer and the reviewer both see it.

*What I did not adopt from Codex here:* its claim that the canary "does not distribute trust" is
already the spec's own position (`:1226-1231`: "moves it one script over … a higher bar, not a
closure"), so it is not a new finding. The finding is the missing obligation.

### 4. [MAJOR] INV-11 and §8's preamble are false as written, and R-7 is disclosed nowhere

`docs/specs/008-verdict-domain-soundness.md:865-869` (INV-11), `:2443-2444` (§8 preamble),
`:2482-2485` (R-7), `:2657-2668` (OQ-4), `:2046-2056` (AC-14(ii)'s 7 markers), `:2508-2532` (§9(1)).

§8 opens *"Each appears verbatim in the rewritten honest scope (§9), because a residual that is
only in the spec is not disclosed,"* and INV-11 asserts the same as an invariant. Checked
against §9(1)'s replacement text: **R-7 (`min == 0` still admits a no-op) does not appear**, and
neither does R-8 (no timeout) — R-8 is disclosed in the root `README.md`'s known-gaps bullet
(566-571, which §9(3) leaves untouched), so only its *location* is wrong; **R-7 has no
disclosure anywhere.**

```sh
grep -rn 'min == 0\|zero floor\|minDelta == 0' README.md zk-verdict/README.md CLAUDE.md SUBMISSION.md
# 0 matches, today and after 008 as specified
```

AC-14(ii) checks seven named markers and none of them is R-7 or R-8, so **nothing detects this**
— the invariant is both false and unenforced. OQ-4's recommendation is literally *"keep
`min == 0` legal and **disclose R-7**"*, and §9 gives that recommendation no implementing
obligation, so accepting the founder's recommended option would still ship nothing.

**Round-5 closure:** add an R-7 sentence to §9(1) and one AC-14(ii) marker for it (evidence line
`7/7 replacements` → `8/8`), and restate INV-11 to what AC-14 actually enforces, naming R-8's
disclosure site in the root README instead of claiming §9 carries it.

*One correction to the spec's own framing, in the honest direction:* OQ-4 says R-7 is the attack
*"which `zk-verdict/README.md:143` advertises as impossible."* Line 143 reads *"A no-op
(`--credit 42`) → delta 0 → `Failed`"* — a statement about that fixture, whose floor is `min ≥ 1`.
It is not a universal claim, so the shipped exposure is smaller than OQ-4 says. The disclosure
gap is still real.

### 5. [MINOR] INV-14's quantifier is still false — now for AC-00b, and for the reason round 4 introduced

`docs/specs/008-verdict-domain-soundness.md:879-894`.

INV-14 says that for every `script` row except AC-00 and AC-13, "**at least one AC-13 mutant
changes a byte inside that row's witness set** — so the value moves during the run," and lists
**AC-00b/M-8** first among the six that satisfy it. After the round-4 rewrite that is false:
M-8 mutates only the sandbox copy, and step **8h explicitly asserts the four repository inputs
are byte-identical to 8a**. AC-00b's witness is a run-constant, exactly like AC-13's.

The *protection* is real and is written elsewhere (`:1931-1934`: for M-8 the "row" is the
sandboxed script's own exit status), so nothing is unguarded. But this is the same species as
r3 finding 2 — an invariant whose stated mechanism does not fire — reintroduced by the fix for
r3 finding 2. **Repro:** run the gate; observe that AC-00b's `witness=` printed under M-8 equals
the one printed on the clean tree.
**Closure:** name AC-00b as a third case in INV-14 with its actual mechanism.

### 6. [MINOR] §6.3's canary carries the in-tree `trap`/`SIGKILL` residue that the same document rejects elsewhere, and does not say so

`docs/specs/008-verdict-domain-soundness.md:1200-1207` (c1–c5), against `:163-172` (N-1) and
`:2716-2726` (OQ-5's SIGKILL argument).

The canary applies `09-restore-u64low.patch` **in-tree** under `trap … EXIT INT TERM`. The
argument the document uses to reject the old in-tree M-8 applies verbatim: `SIGKILL` between c2
and c5 leaves `program-revm/src/main.rs` carrying a re-inserted `fn u64_low`. §6.3 does not
mention it, while §1.2 and OQ-5 spend paragraphs on the same gap for a different file.

I **downgrade Codex's characterisation** of this as a "dangerous intermediate worktree": the
residue is an *unused* function, so it changes no guest behaviour, it makes the very next
`ac008.sh AC-06` fail loudly, and §7.7 already requires reporting `git status` clean after
`--all`. The finding is the missing sentence, not a new risk.
**Closure:** one sentence in §6.3 stating the residue, that it fails loudly at the next AC-06,
and that §7.7's `git status` requirement covers it.

### 7. [MINOR] OQ-2 is stale in both directions, and its two spec citations are wrong

`docs/specs/008-verdict-domain-soundness.md:2626-2642`.

OQ-2 calls itself *"the one open question that needs an answer before implementation starts."*
`003` r5 §1.5.2 (`003:297-331`) answers all three couplings: AC-16 no longer pins a literal;
INV-9 no longer quotes a preimage; `surfaces.pinned` is re-pinned in the same commit that
changes the contract, **with the path corrected to `zk-verdict/scripts/`**. So no founder
ruling remains for the `008 → 003` coupling; what remains is a confirmation of option (a).

Both citations are stale: `003:341` is now about `~34 s`, not the binding formula, and `004:171`
is a fixed-values table — 004's v1 preimages are at **`004:370-375`**, and 004 additionally
computes `planHash = keccak256(caller ‖ target ‖ calldata ‖ value)` **without `gas_limit`**,
which 008's AC-7a adds as a bound component. That is a third way 004 goes stale, and OQ-2 names
only the tag.
**Closure:** restate OQ-2 as *answered for 003, open only as a 004 dependency*, fix the two
citations, and add the `gas_limit` divergence.

### 8. [MINOR] AC-14(i)'s heading says "Seven" over an eight-row table

`docs/specs/008-verdict-domain-soundness.md:2031` — *"(i) **Seven** stale claims must be
absent"*, above eight rows, with `:2044` saying *"All eight were confirmed present today"* and
the manifest evidence line at `:1054` requiring `8/8 stale claims absent`. r2 finding 8 added
the eighth literal and the heading did not move. An implementer writing `docs-check.sh` from the
heading writes seven and the row fails against the manifest — or, worse, writes seven and prints
`8/8`. §(ii)'s "Seven replacement sentences" is correct at seven.

### 9. [MINOR] `zk-verdict/README.md:97`'s "~34 s" survives 008 while §7.5 measures the same operation at 335.02 s

`docs/specs/008-verdict-domain-soundness.md:2292-2376` (§7.5), against `zk-verdict/README.md:95-99`.

The README sentence is *"a **real Groth16 proof** of the verdict was generated on CPU (the gnark
prover, ~15.9M constraints, ~34 s once the artifacts are local)"*. §7.5 establishes that ~34 s is
the **gnark wrap alone** and that end-to-end regeneration is `real 335.02 s` — roughly 10×. The
sentence is defensible read narrowly ("the gnark prover"), and it is read by anyone else as the
cost of producing the proof. §9 schedules no correction and AC-14's tilde and `cycles` checks
cannot reach it (no trailing `k`, no ` cycles`). This is the flattering direction, which
`AGENTS.md` §5 says is where to look.

**Closure, with a coupling to respect:** qualify in place, do not delete — `003` r5's check 17
requires **exactly one** `~34 s` match in that file. Add "(the gnark wrap alone; end-to-end
regeneration of one fixture measured at 335 s — §7.5)" and, if it is to be enforced, one AC-14(ii)
marker.

---

## Rejected findings

Nothing from Codex was rejected outright this round. Two were narrowed, with the evidence:

- **Codex 3, the part claiming the canary "does not distribute trust"** — not a finding. The spec
  says the same thing itself at `:1226-1231` ("moves it one script over … a higher bar, not a
  closure") and at `:2404-2408`. What survives is the missing review obligation, which is
  finding 3 above.
- **Codex 4's "dangerous intermediate worktree"** — narrowed to a documentation gap. The residue
  is an unused `fn u64_low`; it does not alter guest semantics, the next `ac008.sh AC-06` fails
  on it by construction (that is the mutant's whole purpose), and §7.7 (`:2427-2429`) already
  requires a clean `git status` after `--all`. Kept as MINOR for the missing sentence only.

Checked and **not** raised as findings (recorded so round 5 does not spend time on them):

- **N-1 is literally true.** All 28 `RecknZkEscrow` mentions read in context; the only mutation
  path is `patch -p1 -d "$S"` at `:1880`, and `:1947`, `:2176` and `:2215` each restate that the
  repository's file is never written. The remaining "change any byte of `RecknZkEscrow.sol`" string (`:1348`) is a falsification
  *description*, not a procedure; `:1250` is AC-0's.
- **The sandbox's control/mutation ordering, its four inputs, and the Location rule** — sound; an
  escape produces a false "not detected", which fails AC-13.
- **Tier discipline** — I found no claim above its evidence tier. `335.02 s` is labelled as one
  measurement on the *pre-008* guest; `4 × 335.02 s` is labelled an extrapolation; the four
  itemised phases are stated as summing to 47.00 s of 335.02 s with the remainder called an
  inference; §7.5's conclusion is conditioned on `T_predicate` / `T_svm` / the post-008 guest with
  the direction ("up") named. The two AC-0b digests and the line-711 assertions reproduce exactly.
- **Binding (AC-7a / AC-7b / INV-5)** and **AC-4's 13 vectors with five named positive controls** —
  the controls are what stop "a gate that refuses everything", and they are written.
- **Timeout vs settle** — 008 *increases* the no-proof set and says so at R-8; the permissionless
  refund is `003`'s deliverable, and `003` specifies it as callable by anyone after the deadline.
  008 does not need to carry it, and it does not hide it.
- The frozen items (P-12, Δ = 9 addresses, G-3, `head -710`, AC-7a, §7.5's tier discipline, §3,
  AC-1…AC-12, the manifest arithmetic, the freeze rule) were not re-litigated and none of the
  findings above depends on reopening them. Findings 1 and 2 do move the **mutant count** off 16;
  that is a consequence of new coverage, not a re-argument of the arithmetic.

## Deferred

None. Every finding above is an edit to this spec, in scope, and none of them belongs in
`docs/decisions/`.

---

## Verdict and what round 5 is

I cannot approve this. Not because the document is imperfect — it is the strongest of the four
rounds, and finding 1 is the only one that would survive a "is it safe to implement?" test on its
own. But finding 1 is exactly the failure `AGENTS.md` §0 exists to prevent, on the head task of
the execution order, in a file **008 itself opens**, and it is a *spec* gap: the implementer who
follows this document is not told to guard it, and no criterion here would catch it.

**Round 5, in priority order for 9/9:**

1. **Finding 1 (BLOCKER)** — the `RecknVerdictVerifier.sol` guard. The property pair is already
   written in `003` r5; 008 needs its own copy plus one zero-build sandbox mutant. Whether
   `AGENTS.md` §0's enumerated surface gains a second file is a **founder call**, and it should be
   put to the founder in the same round rather than decided by an agent.
2. **Finding 2 (MAJOR)** — `computed:` assertion at 8g, second sandbox phase for the `head -710`
   clause, and `surfaces.pinned` stated as a checked property. Same section, same sandbox, zero
   build cost.
3. **Finding 3 (MAJOR)** — one subsection binding the stage=impl review.
4. **Finding 4 (MAJOR)** — R-7's disclosure sentence, one AC-14 marker, INV-11 restated.
5. **Findings 5–9 (MINOR)** — one sentence each; findings 8 and 9 are trivial and should not be
   allowed to consume attention.

**Round 5 should be short.** Findings 2–9 are local edits and 1 is a copy of a design that exists
next door. Nothing in §3, §4, §5.1, AC-1…AC-12 or the test plan is disturbed. **The hard stop is
round 6** (`AGENTS.md` §7): if round 5 lands items 1–4 as specified, round 6 should be an
APPROVE, and if it does not, the open items go to the founder with the 9/9 checkpoint attached
rather than being absorbed by a softer verdict.

VERDICT: CHANGES

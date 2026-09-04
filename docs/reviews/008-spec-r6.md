# Review 008 spec round 6 — **final round** (`AGENTS.md` §7 hard stop + founder clock of 2026-09-05)

Payload: `/tmp/reckn-payload-008-spec-r6.md`
Codex raw: `/tmp/reckn-codex-008-spec-r6.md`

Codex was run **once**, `-s read-only`, on the payload printed in full before the call. The spec
under review was written by **Claude Code** (`reckn-spec`), not by Codex, so this is a genuine
second model and `AGENTS.md` §1's author-independence rule does not restrict it here. Codex
returned 3 findings (1 BLOCKER / 2 MINOR) and 8 confirmations. **One of its findings is adopted
with its severity re-derived, one is adopted only in its sharper half and its framing rejected with
evidence, one is adopted as written**; four further findings below are the orchestrator's own and
appear nowhere in the Codex output.

Every measurement quoted here was taken **today, 2026-09-05**, against the files on disk. **No
number is carried from r5.** Where I re-ran an r5 measurement I say so; where I did not, I do not
cite it.

---

## 0. What this round is, and why the verdict is what it is

There is no round 7. Under the founder ruling of 2026-09-05 (`AGENTS.md` §7), `CHANGES` and
`APPROVE` produce the **same spec** and the **same implementation**; the only difference is the
label. So the useful output of this review is not the verdict but the split the founder asked for,
and it is in §3 and §4 below.

**The criterion I applied:** *does a path remain by which an implementer, working from this
document alone, produces a green build in which the central claim — the verdict's domain is sound /
no key can judge — is false?*

**Answer: no.** I tested it rather than reasoned about it (§1). The one real hole round 6 leaves is
in the **gate on implementation fidelity**, not in what the document instructs, and the document
already names that exact degenerate as a read obligation at §7.8(d′). What it gets **wrong** is one
bounding sentence about how much that residual admits — and the founder is about to rule **OQ-7**
on that sentence. Finding 1 corrects it so the ruling is made on the true risk.

---

## 1. Verified first, by running it, so the findings are not about things already true

Not trusted — re-derived. I implemented §6.4 5f's five-step extraction rule from the text and ran
it against the real file with §3.4's `uint64` → `uint256` substitution applied.

| the spec's round-6 claim | measured today |
|---|---|
| the five-step rule yields **exactly twenty** pieces, in the transcribed order | **20/20 byte-identical**, in order ✓ |
| 5b's vocabulary is **43** tokens after the edit (`uint256` for `uint64`) | **43**, set-identical ✓ |
| R-10 item 7: inserting `{ }` reproduces the twenty pieces and the 43 tokens | both **identical** ✓ |
| R-10 item 7: closing the contract early (`verifyVerdict` becomes a free function) reproduces both | both **identical** ✓ |
| R-10 item 5: `zk-verdict/contracts/foundry.toml` has **no `solc` key**, five lines, `src`/`out`/`libs`/`fs_permissions` | exactly that ✓ |
| M-15 fires: `traceHash` ↔ `dealBinding` swap → `v.dealBinding` decodes word 5 → `RecknZkEscrow.sol:103` reverts `BindingMismatch` | `reexec-groth16-fixture.json`'s `trace_hash` **≠** `deal_binding` (`0x4e7b1345…` vs `0x81899ffc…`), so the revert is real ✓ |
| the r5 review's alternative remedy (`sol!` twin) is **rejected** because AC-10 reads committed fixture bytes | `RecknReexecVerdict.t.sol:27-30` and `RecknZkEscrow.t.sol:43-47` parse `.vkey` / `.public_values` / `.proof` / `.deal_binding` out of JSON — **nothing the Rust encoder does reaches a forge run**. The spec's rejection is correct and the r5 remedy would have been wrong ✓ |
| r5 BLOCKER 1's premise: the escrow declares its own constants | `RecknZkEscrow.sol:25-26` + `:109-112`; `:4` imports the contract type and the struct only; `v.REPRODUCED()` is read in exactly one test, `RecknVerdictVerifier.t.sol:48`, which is not an `_AC10_` test ✓ |
| M-21 isolates 5f: `minDelta`/`maxDelta` are read by nothing | the escrow reads `dealBinding`(:103), `outcome`(:109,:111), `traceHash`(:116) and nothing else; no test in `zk-verdict/contracts/test/` asserts either field ✓ |
| manifest arithmetic: **18** rows, 8 cargo summing **91**, 2 forge summing **6**, 8 script | 18 / 91 / 6 / 8 — all recomputed by hand ✓ |
| M-17's splice adds exactly 5 tokens outside 5b's set (`if`, `tx`, `origin`, the hex constant, `return`); M-19 removes exactly 1 (`verifyProof`) | both ✓, computed against the 43-set |

**The spec's own measurements are accurate.** Every finding below is about what the document
*concludes* from them — which is where r5 failed too.

---

## 2. Findings

### 1. [MAJOR — **class 1, must be closed during implementation**] `docs/specs/008-verdict-domain-soundness.md:3582` and `:4242` — the residual is bounded by a sentence that is false: a 5f that survives all four check-5 mutants still admits the money-moving struct permutation

Codex finding 1. **Adopted; severity re-derived downward from its BLOCKER, and the repro replaced
with a working one.**

§7.6 **L-5(iii)** (`:3579-3582`) and **OQ-7** (`:4240-4243`) both bound the element-coverage
residual with the same claim:

> `:3582` — "**It would not pass a permuted struct**, because M-21 moves pieces 5 and 6 and M-15
> moves 8 and 9."
> `:4242` — "and it does **not** admit a permuted struct, because M-21 and M-15 move four of the
> twenty pieces between them."

**Both are false.** The reasoning holds only for a *positional* subset comparison. It fails for a
*relational* one — an implementation that checks the piece **count** and the **adjacency** of the
pairs the mutants move. Such an implementation rejects M-15 and M-21 (the pairs are no longer
adjacent in order) and accepts `uint8 outcome;` moved to the head of the struct, because both pairs
stay adjacent and in order and the count stays 20. That permutation is the exact §2.1 false
release: `v.outcome` decodes ABI word 0, and on a genuine proof of a **`Failed`** execution over a
deal whose checked prestate slot is `0`, `RecknZkEscrow.sol:109-110` pays the **seller** — while
`bash scripts/no-keys.sh` exits **0**, and `AGENTS.md` §6's commit ritual does **not** run `forge`.

**Repro — run today, not argued** (`/tmp/v008.sol` = the post-008 file; `full` = §6.4's clause as
written, `degenerate` = count + the two adjacency pairs + pieces 19–20):

```
                                   5b       full-5f   degenerate-5f
clean                              PASS     PASS      PASS
M-17 (tx.origin splice)            REJECT   REJECT    REJECT
M-19 (drop verifyProof)            REJECT   REJECT    REJECT
M-21 (minDelta <-> maxDelta)       PASS     REJECT    REJECT
M-15 (traceHash <-> dealBinding)   PASS     REJECT    REJECT
outcome-to-head (MONEY-MOVING)     PASS     REJECT    **PASS**
```

The degenerate is green on **all 21 mutants and all 18 manifest rows**, and green on the one
permutation that moves money. That is `CLAUDE.md`'s own **R-11** — *「除外で範囲を述べた検査は穴が
空いている」* — arriving one layer down, and it is the fourth appearance of the habit §10 OQ-5 and
OQ-6 already record: **a bound written in the direction that flatters the option being
recommended**, here inside the very paragraph whose job is to state the residual honestly.

**Why MAJOR and not BLOCKER, stated because I first wrote BLOCKER.** The document *instructs* the
conforming implementation unambiguously — `:1683-1684` "**The result must be exactly these twenty
pieces, in exactly this order, and there must be exactly twenty**", `:1710` "**Equality in both
directions**", and §6.4's stop rule at `:1839-1846` forbids touching any of the strings. The
`full-5f` column above is **REJECT** for every permutation. So no *document-conforming* implementer
reaches a green-and-false tree; the hole requires the implementer to disobey the clause, and
§7.7 (`:3624-3628`) and §7.8(d′) (`:3707-3712`) **already name that exact degenerate**: §7.7 requires
the implementer to *"paste the extraction code, all five steps of it"* and to state whether 5f *"is
an equality over the whole twenty-piece list, not a comparison of the pieces M-15, M-17 and M-21
happen to move"* — and says, correctly, *"No mutant can distinguish those two"*; §7.8(d′) makes the
same thing a review obligation. What is genuinely wrong is the **bound**, and its
consequence is that the founder would rule OQ-7 believing the residual is smaller than it is.

**Implementer's obligation (the spec cannot be edited; this is the substitute):**

1. Implement 5f as an **indexed equality over all twenty pieces plus a length assertion**, in both
   directions — `extracted[i] == pinned[i]` for `i = 1..20` and `len == 20`. **Not** an adjacency
   test, **not** a subset test, **not** a substring search over the joined sequence.
2. **Print the extraction, and prove it is the extraction.** `no-keys.sh`'s check 5 prints
   `skeleton: <sha256 of the twenty pieces joined by \n>`; `ac008-selftest.sh` phase 21 computes
   that digest **itself** from `$S`'s mutated file and asserts equality — the exact `computed:`
   instrument the spec already invented at 8g / 18g / 20g. *(Codex is right that this alone is
   insufficient — a script can print a faithful extraction and still decide from a subset — so it is
   obligation 3 that closes it, and this one only removes the "did it even extract" degree of
   freedom.)*
3. **Add the per-position witness that OQ-7 priced at 65 mutants and that costs almost nothing.**
   In phase 21, after the M-21 assertion, loop `i = 1..20` over `$S`'s **clean** copy, perturb
   position `i` mechanically (swap piece `i` with piece `i+1`, wrapping at 20), and require the
   sandboxed `no-keys.sh` to exit non-zero naming `5f` each time. This is **generated**, not twenty
   patch files: **zero new `mutants/*.patch`, zero builds, ~20 grep-only script runs, a few
   seconds**, and the manifest stays at 18 rows and the patch count at 21. It kills the degenerate
   above and every other subset comparison of 5f.
4. **`docs/reviews/008-impl-rN.md` must quote the actual 5f code** and state, as a pass/fail and not
   as prose, that it is an indexed twenty-element equality. §7.8(d)(3) and (d′) already require the
   reading; this makes it a quotation.
5. **The implementation report must state that `:3582` and `:4242` were wrong**, with the corrected
   sentence: *the surviving residual admits any struct permutation that preserves the adjacency of
   `minDelta,maxDelta` and `traceHash,dealBinding`, including the money-moving one, unless 5f is an
   indexed equality.* This sentence is what the founder needs before ruling OQ-7.

### 2. [MINOR — **class 1**] `docs/specs/008-verdict-domain-soundness.md:3338` and `:2807-2809` — M-19 is not "the only mutant a denylist check 5 fails"; **M-21 fails it too**

Adopted from the sharper half of Codex finding 2. §7.3 row 4 calls M-19 "**The only mutant a
denylist check 5 fails**" and `:2807-2809` calls it "the **only mechanical test** that check 5 states
properties rather than forbidding names". A `grep -nE 'tx\.origin|msg\.sender|block\.|assembly|
delegatecall|selfdestruct'` also exits **0** on M-21 — a `minDelta`/`maxDelta` swap contains no
forbidden name — so phase 21 records a miss and AC-13 fails on that script as well.

**Repro:** `sed` the two member declarations into swapped order in a copy and run the denylist —
zero matches, exit 0, while phase 21g requires non-zero naming `5f`.

This one **overstates M-19's uniqueness and understates the gate's coverage**, i.e. it is an error
in the *unflattering* direction, which is why it is MINOR. It is class 1 only because the
implementer must not conclude from `:3338` that phase 21 is redundant with phase 19 and drop one.

**Obligation:** keep both phases; record in the implementation report that two mutants (M-19,
M-21) independently separate check 5 from a denylist, not one.

### 3. [MINOR — **class 1**] `docs/specs/008-verdict-domain-soundness.md:3821` — §8's R-10 says "**Six** things" and then enumerates **seven**, and §9 copies §8's residuals **verbatim** into the shipped honest scope

Codex finding 3, and independently found here. `:3821` reads *"**Six** things that check does **not**
establish"*; the list runs `(1)` … `(7)`, with brace nesting as item 7 added in this same round.
`:3818` likewise says *"items 4–6 corrected and extended in round 6"* while item 7 is new.

§8's own header states its residuals are copied verbatim into `zk-verdict/README.md`'s honest
scope, and the note at `:3846-3849` says, in this same paragraph, *"a wrong residual here becomes a
wrong sentence in a shipped document."* The count is the wrong sentence.

Also in the same block, `:3853-3856`: *"**Two of the three** regions … were **not** among round 5's
four items"* — round 5's four items were bytecode, the `verifier` address, `ISP1Verifier`'s source
and "no semantic analysis"; **none** of the three regions was among them, so the correct word is
"none", not "two".

**Repro:** `sed -n '3818,3860p' docs/specs/008-verdict-domain-soundness.md` and count the
parenthesised item numbers.

**Obligation:** the shipped honest-scope text must say **seven**, and the `AC-14(ii)` marker set
must not be satisfied by a bullet whose own count contradicts its list.

### 4. [MINOR — **class 1**] `docs/specs/008-verdict-domain-soundness.md:3526-3527` — L-3 says AC-13's "step 0 (the patch count must be **18**)" while AC-13 and §7.1 both require **21**

Orchestrator's own. AC-13's in-tree procedure at `:2660` is `assert ... wc -l == 21`; §7.1's file
table at `:3296` says *"`ac008-selftest.sh` step 0 requires exactly 21"*; the same L-3 paragraph
says *"twenty-one `mutants/*.patch` files"* **two lines earlier**. Only `:3527` says 18 — a
round-5-era literal that the 18 → 21 change did not reach.

**Repro:** `grep -n 'patch count\|twenty-one\|== 21' docs/specs/008-verdict-domain-soundness.md`.

**Obligation:** step 0 asserts **21**.

### 5. [MINOR — **class 1**] `docs/specs/008-verdict-domain-soundness.md:3684` — §7.8(c) requires the impl reviewer to record "the **three** `sandbox control clean` lines"; there are now **six** sandbox phases

Orchestrator's own. §7.7 at `:3596` was updated and correctly says *"including **all six**
`sandbox control clean` (M-8 / M-17 / M-18 / M-19 / M-20 / M-21) lines"*; §7.8(c) was not. The
clean-copy control lines are the only thing distinguishing a detection from a sandbox that failed
for the wrong reason, so the reviewer recording three of six is exactly the gap the control exists
to prevent.

**Repro:** `sed -n '3596,3597p;3684,3685p' docs/specs/008-verdict-domain-soundness.md`.

**Obligation:** the impl review records **six** control lines.

### 6. [MINOR — **class 2, disclosure suffices**] `docs/specs/008-verdict-domain-soundness.md:1325` and `:3338` — two further stale statements about the sandbox count and about which clause M-19 may name

- `:1325`: *"the one sandbox in this document belongs to AC-13's M-8 and is built by
  `ac008-selftest.sh`."* There are six. The sentence's actual load — that `ac008.sh --all` has no
  `--sandbox` mode — is unaffected, which is why this is class 2.
- `:3338` (§7.3 row 4) and AC-13's sample output at `:2586` allow M-19's failure to name `5b` or
  `5d`; phase **19g** at `:2790-2793` allows `5b`, `5d` **or `5f`** ("piece 19 is gone") and says the
  clause is not asserted. An implementer following §7.3 alone would score a `5f` naming as a
  **harness failure**, i.e. a false stop on the head task of the checkpoint. **19g governs** — it is
  the procedure, §7.3 is the summary table.

---

## 3. Rejected findings

- **Codex finding 1's severity as it framed it (BLOCKER), and its claim that OQ-7's option set being
  incomplete is itself the blocker.** *Evidence against:* the `full-5f` column of my repro is
  **REJECT** on every permutation including the money-moving one, and §6.4 `:1720-1722` / `:1745` /
  `:1843-1848` instruct precisely that implementation with a stop rule attached. There is therefore
  **no green-and-false path for a document-conforming implementer**, which is the founder's stated
  criterion for this round. The finding survives as finding 1 on the narrower and true basis — the
  *bound* at `:3582` / `:4242` is false and the founder is about to rule OQ-7 on it — and the remedy
  is re-derived into five implementation obligations. Adopting Codex's severity as written would
  have put "the spec leaves a false-release path open" into this review, and that sentence is not
  true.

- **Codex finding 2's framing — "the shown denylist does not pass all 18 manifest rows after round
  6, so `:2814` is wrong."** *Evidence against:* `:2814-2818` is a counterfactual introduced
  explicitly to motivate M-19, and the **next sentence** of the same paragraph says *"Under M-19
  that script exits 0, the mutant is a miss, and AC-13 fails."* The passage is not asserting that
  the denylist passes the round-6 gate; it is stating what it passed before M-19 existed. What is
  genuinely wrong is the **uniqueness** claim at `:3338` / `:2807`, which Codex reached second and
  which I adopt as finding 2.

- **My own payload hypothesis, that requiring check 5 to print the skeleton digest would close
  OQ-7 cheaply — rejected, by Codex, correctly.** *"Merely printing an extracted skeleton/digest is
  insufficient: a script can print a correct full extraction while making its accept/reject decision
  from a subset."* That is right, and it is recorded here because I put it in the payload as a
  leading question and it did not survive. It stays in the obligations only as step 2 of finding 1,
  subordinate to the generated per-position witness of step 3, which is the part that actually
  closes it.

- **"Brace nesting is an exploitable escape from 5f"** — not a finding. I looked for one and Codex
  independently looked for one; neither of us constructed a compiling file that reproduces the
  twenty pieces and changes what `verifyVerdict` returns. Every brace-carrying Solidity construct
  that could do it — call options `f{gas:…}(…)`, named struct literals, `using … for … global`,
  UDVTs — either splits a pinned piece at step 4 or introduces a token outside 5b's 43-element set.
  The spec's own framing at `:1833-1841` — *it cannot move a statement or a declaration, it can
  change scope, and 008 does not claim every such rearrangement fails to compile* — is **correct in
  both directions**, which is the sentence the founder asked me to test. It was reached by the
  drafter **running** a claim it had already written and finding it false; that is the instrument
  the r5 non-approval demanded, and it worked.

- **"`remappings.txt` can neuter `verifyProof` under a pinned import line"** — real but already
  disclosed, not a new finding. `zk-verdict/contracts/remappings.txt` maps `@sp1-contracts/` into
  the repo, so the *source* behind the pinned import string is not pinned by check 5. That is
  **R-10 item 3** verbatim (*"nothing about `ISP1Verifier`'s own source, a vendored dependency
  outside every file 008 reads"*). Recorded here only so the next round knows the concrete artefact
  is `remappings.txt`, and because AC-10 test 4 and `RecknVerdictVerifier.t.sol`'s
  `test_invalid_proof_reverts_so_no_unproven_verdict_settles` do catch a no-op verifier even though
  `no-keys.sh` would not.

- **Tier violations** — none found. §7.5's `4 × 335.02 s` is labelled as the extrapolation it is
  (`:3464`), AC-10's tier note (`:2492-2493`) says *"Not a chain result; §7.4 forbids describing
  it as one"*, and §9(1)'s replacement honest-scope text (`:3877`) qualifies the false-release fixture as
  *"verified locally with `forge test` against `SP1Verifier` — no chain"*. Codex reached the same
  conclusion independently. This was r3 finding 8 and it stays closed.

- **The not-re-litigated list** — P-12, Δ = 9, G-3, `head -710`, AC-7a, §7.5's tier discipline, N-1,
  the sandbox skeleton, §7.8's existence and the §7.6 / §8 separation, solution (a) vs (b), the
  precompile/DB-read question, and every number r5 re-measured clean: **not re-opened**, per the
  founder's instruction and `AGENTS.md` §5's rule against carrying prior-round numbers.

## 4. Deferred

None. All six findings are inside 008 and all six are implementation-time sized. Nothing moves to
`docs/decisions/`.

---

## 5. The split the founder asked for

### (1) Must be closed **during implementation** — otherwise a wrong statement or a weak gate ships

| # | what | obligation | cost |
|---|---|---|---|
| 1 | **5f must be an indexed twenty-element equality**, and the gate must witness every position | finding 1's obligations **1–5**: indexed equality + length; `skeleton:` digest asserted by the selftest itself; **generated** per-position swap witness inside phase 21 (no new patch files, no build); the impl review quotes the code; the report states that `:3582` / `:4242` were wrong | ~20 extra grep-only script runs, seconds |
| 2 | Keep **both** phase 19 and phase 21 | `:3338`'s "only mutant" is false; M-21 also kills a denylist | 0 |
| 3 | Shipped honest scope says **seven**, not six | `:3821`; and `:3853` "two of the three" → "none of the three" | 2 words |
| 4 | AC-13 **step 0 asserts 21** | `:3527` says 18; `:2679` and `:3296` say 21 | 0 |
| 5 | The impl review records **six** `sandbox control clean` lines | `:3684` says three; `:3625` says six | 0 |
| 6 | **19g governs, not §7.3 row 4** — a `5f` naming from M-19 is a detection, not a harness failure | otherwise a false stop on the checkpoint task | 0 |

### (2) Disclosure is sufficient — true, but does not make the claim false

- **R-10 items 1–3**: check 5 is source-level, says nothing about deployed bytecode, nothing about
  the **address** the constructor was given, nothing about `ISP1Verifier`'s own source. The concrete
  artefact for item 3 is `zk-verdict/contracts/remappings.txt`. Closing 1 and 2 belongs to the task
  that extends check 5; 008 correctly does not pre-empt it.
- **R-10 item 5**: the compiler is unpinned (`^0.8.20` is a range; `foundry.toml` has no `solc` key
  — confirmed).
- **R-10 item 7**: brace nesting is invisible to all six clauses. It cannot move a statement or a
  declaration; it can change scope; no exploit was constructed by either model.
- **L-3**: AC-13's own manifest row is `echo`-satisfiable and nothing in the repository closes it;
  §7.8 assigns the owner, and §7.8's closing paragraph correctly states that **no automated detector
  exists** and that the **founder** is the terminal observer.
- **§6.1 `:1325`'s stale "one sandbox"** — harmless; the sentence's load is unaffected.

---

## 6. For the founder — answer these before implementation starts

- **OQ-7 — and read finding 1 first, because round 6's statement of the risk was wrong.** The
  corrected residual: *a 5f that is not an indexed equality admits any struct permutation preserving
  the adjacency of `minDelta,maxDelta` and `traceHash,dealBinding` — **including the money-moving
  one** — while passing all 21 mutants and all 18 rows.* Option **(b)**'s price of "65 mutants" is
  the price of *checked-in patch files*, not of the property: **generated** per-position
  perturbations inside the existing phase 21 cost no patch files, no builds and seconds of wall
  clock, and they are already listed as finding 1's obligation 3. **Recommendation: take (a) as the
  founder's ruling for the mutant *budget*, and take the generated witness as an implementation
  obligation rather than a budget change** — it changes no number in the document (18 rows, 21
  patches, 91 cargo, 6 forge, 40-minute budget all stand).
- **OQ-1** — `docs/ethonline-2026/PLAN.md:20-21` goes stale after 008 and agents may not edit it.
  (a) founder edits it in the same window, or (b) accept the drift and record it in `STATUS.md`.
  Spec recommends (a).
- **OQ-2** — open only as a `004` dependency now: `004` re-implements the v1 preimages and goes
  stale three ways (domain tag `v1 → v2`, `le64` → fixed-width big-endian, and `gas_limit` entering
  `plan_hash`, which 008 **resolves** and `004` still describes as open). (a) 008 lands and `004`
  updates next round, or (b) 008 holds its doc changes. Spec recommends (a).
- **OQ-3** — precompile backend parity stays disclosed for ETHOnline. Spec recommends leaving it.
- **OQ-4** — keep `min == 0` legal and disclose R-7. Since round 5 the recommendation carries an
  implementing obligation (§9(1)'s sentence + AC-14(ii) marker 8), so **accepting is the default and
  only an override needs the founder.**

## 7. Where the implementer should start reading

1. **§3.1–§3.6** — the fix itself: the U256 widening, the v2 preimages, the domain gate, P-12.
2. **§6.4** — check 5, all six clauses, and its stop rule. **5f's five-step extraction rule at
   `:1675-1681` and the twenty pieces at `:1688-1707` are literals; do not re-derive them, and do
   not edit one to make an edit fit** — that routes to `AGENTS.md` §7.
3. **§6.1** — the manifest, which `ac008.sh` parses out of the spec itself.
4. **AC-13** — the six sandbox phases. Build each `$S` separately; run each clean-copy control
   **before** its mutation; a control failure is a **harness failure**, never a detection.
5. **§7.7 and §7.8** — what the report must say and what the impl review must run itself.

---

**What happens if implementation starts on this spec as it stands** (stated because the founder
asked for it even on APPROVE): the U256 fix, the domain gate, engine identity, `dealBinding`
coverage and check 5 all land as specified, and a document-conforming implementation cannot produce
a green tree in which a `Failed` execution pays the seller. The one thing the gate would not catch
by itself is an implementer who writes 5f as a search instead of an equality — which the document
already assigns to a human reader at §7.8(d′), and which finding 1's obligation 3 converts into a
mechanical witness at near-zero cost. The residual that ships is honest once §8's "six/seven" is
corrected: check 5 is lexical, source-level, says nothing about bytecode, the verifier address, the
vendored `ISP1Verifier`, the compiler, or brace nesting.

VERDICT: APPROVE

# 009 — cross-VM settlement

> **Status:** spec, **round 2**. Not approved. `reckn-codex-impl` must not start until
> `docs/reviews/009-spec-rN.md` ends with `VERDICT: APPROVE`. Round 2 answers all fifteen
> findings of `docs/reviews/009-spec-r1.md`; §0 is the index from finding to change.
>
> **Tier: local.** Everything in this document runs in Foundry's in-memory EVM
> (`forge 1.7.1`, measured below) against **committed** Groth16 fixtures. No anvil, no
> testnet, no mainnet, no Solana node of any kind, no RPC. Nothing is deployed anywhere.
> A green 009 says nothing about testnet and nothing about mainnet (`AGENTS.md` §5).
>
> **Measurement provenance.** Round 1's measurements (E-1…E-12) were taken on 2026-09-05 at
> `1db7cd1`. Round 2 re-ran, on 2026-09-05 at **`40d1ce0`**, every measurement it changes or
> adds (**E-4 re-run, E-13…E-16**), with the command shown next to each. `git diff --stat
> 1db7cd1 40d1ce0` touches `AGENTS.md`, `CLAUDE.md`, `README.md`, `STATUS.md`, `SUBMISSION.md`
> and files under `docs/` — **no source file, no contract, no script, no fixture** — so
> E-1…E-12 are measurements of the same bytes and are not stale. Where a number is carried
> from an earlier document it is labelled *history* and is used by no criterion.
> **No number from round 1's review is quoted; every one this round relies on was re-run.**

---

## 0. Round 3 — every finding of `009-spec-r2.md`, and where it landed

**This is the last spec round.** The 2026-09-05 harness ruling (`AGENTS.md` §1/§2) gives each
specification **one** independent review; round 2's findings are closed here and the document is
frozen for implementation. A further round happens only if a **new, reproducible BLOCKER against
the central claim** appears and the founder authorises it.

| # | sev | finding | what changed |
|---|---|---|---|
| 1 | **BLOCKER** | the entry-point closure's **region** is not closed: 7h, 7i and check 2 clause 2a all read *"from the `contract RecknZkEscrow` line onward"*, and an **inherited** `fallback` is declared above that line. Compiled and drained in `/tmp/sbx009` with every check and every clause green | **7j (new)** and **check 2 clause 2c (new)**: the normalised text between `contract RecknZkEscrow` and its `{` must be **empty**, the token `contract` must occur **exactly once** in the file, and `using` is counted over the **whole file** (7i's span corrected). AC-7's evidence line gains `1 contract 0 inherited`, so the clause is observable. r1 finding 4 reappearing one level up |
| 2 | **BLOCKER** | §7.8's extraction rule fails on this document: applied mechanically it returns **seventeen** tokens, the seventeenth being the bare `test_AC` in §7.8's own prose, so `ac009.sh --check` fails on every run and **no row can execute** | The sixteen names move into a fenced **`ac009-testnames`** block and §7.8 reads that block **and nothing else** — the construction §7.1 already uses for the manifest. Re-measured: sixteen names, all matching the regex, per-selector counts 2/4/2/2/3/3 = the manifest's column |
| 3 | **BLOCKER** | **INV-2 is false and §11(4) ships it into `CLAUDE.md`**: *"there is no path to a payout that skips proof verification"* — the buyer names the verifier at `fund`, so a sham verifier is paid out on garbage, and 009's own AC-3 test 2 requires that behaviour | INV-2 restated as what is true (*the funder chooses the program; the proof, checked by that program, chooses the payout*), with the false sentence quoted as false so it cannot return. §11(4) now **forbids** it by name. **The design is not changed** — a registry is a key, a vkey argument is a founder question, two escrows moves the objection up a level. **The seller-side capability 009 newly creates is written down** for the first time: a buyer can name a verifier that always returns `FAILED` and the seller works for nothing, indistinguishable on-chain from an honest `Failed` (INV-2, L-7) |
| 4 | MAJOR | nothing binds either fixture to the guest that produced it — `xvm.pinned` pins no **path**, so the headline claim rides on a filename | The **two paths are literals** of §7 now, in order, with the failure they close spelled out (two copies of one fixture under two names). The deeper half — binding a fixture to its guest rather than to a path — is **not** closed and is disclosed as **L-12** |
| 8 | MINOR | INV-7 says `msg.sender` appears **twice**; `grep -c` says **three** | Corrected to three, with the three sites named and the date measured. Same shape as r1 finding 1: a number transcribed rather than run |
| 5, 6, 7, 9, 10 | MAJOR / MINOR | AC-12's empty-green case; the counted-surface inventory missing three entries; INV-5 asserting value conservation with no ERC-20 model; `defence in depth` being a denylist by 009's own R-7; L-16's residual understated | **Disclosed, not closed** — the r2 review's own classification. Each is recorded where it belongs (§8, §10, L-16) and none blocks implementation. The AC-12 mechanism works; what is wrong is the description |

*(Round 2's findings 1–3 were adopted in full and none of them changed the design. All three were
the same shape as findings the earlier round had closed — a boundary that does not reach far
enough, a gate that cannot pass its own document, an invariant its own AC contradicts.)*

---

## 0.1 Round 2 — every finding of `009-spec-r1.md`, and where it landed

| # | sev | finding | what changed |
|---|---|---|---|
| 1 | **BLOCKER** | AC-7 7f's pinned counts (7 assignments / 6 targets) are wrong against §3.3's own contract; the cheapest route to green is to blind the scanner, which re-opens the R-11(iii) hole 7f exists to close | **Recounted, mechanically, and the scan is widened rather than narrowed.** The LHS set is now the **eight verbatim left-hand sides including their declarators**, the total is **9**, and the RHS pin grows from two statements to **four**. Pinning `Deal storage d` verbatim is the part that matters: `Deal memory d` compiles, makes `d.state = State.Settled` a no-op and is a double-spend — it is now **M-12**. E-14 is the recount |
| 2 | **BLOCKER** | `test_AC03_settleWithProof_has_no_adjudicator_parameter` is rejected by §7.0's own naming regex | Renamed to `test_AC03_settle_with_proof_has_no_adjudicator_parameter`. **All sixteen names re-checked against the regex mechanically** (§7.8, E-16); the regex is not widened |
| 3 | **BLOCKER** | landing 009 turns `008` red — shared mutant directory, shared suite total, shared `no-keys.sh` — so "both green on 9/9" fails for a filename | **§1.4 (new)**: the counted-surface protocol, four surfaces named in **both** directions, no `008` literal, `{P}` measured at 009's base, and **AC-12 (new)** — 009 goes red if any sibling gate in the tree is red. §10 rewritten in both directions |
| 4 | **BLOCKER** | AC-7 does not close the escrow's shape: a `fallback` that drains any funded deal passes all four `no-keys.sh` checks and all twelve ACs | **7h (new)** closes the entry-point set as a **property over the grammar**, not a denylist; **7i (new)** makes the lexical reading well-defined; `no-keys.sh` **check 2** gains the same closure (founder ruling on OQ-A, 2026-09-05); **M-11 (new)** is the drain. §7g's residual rewritten. E-13 is the measurement |
| 5 | MAJOR | §4.4's barrier table inverts the product's claim — SP1 verification called "defence in depth", the deal's committed code called "load-bearing" | §4.4 rewritten: **B-2 is load-bearing for soundness** and is the product; B-1 for *who selected the adjudicator*; B-3 for *which execution*. §11(4) now forbids `CLAUDE.md` from shipping the inversion |
| 6 | MAJOR | L-7 (*"a buyer who commits a sham verifier loses their own money and nobody else's"*) is false for a pooled escrow holding an inexact ERC-20 | L-7 restated with the condition it needs and the pooling named. The **code** fix stays `003`'s (N-5) |
| 7 | MAJOR | T-7 declared unreachable "on every EVM this project targets" — a claim above 009's tier; under EIP-6780 it is reachable and the deal is then permanently unsettleable | §5.2, §5.3, §7.5 and L-8 rewritten; **L-14 (new)**. No AC is added: r1 measured that `forge 1.7.1` does not reproduce it in-test, so an AC here would pass for the wrong reason |
| 8 | MAJOR | §3.6's set argument is sound; its conclusion *"every consumer … is unaffected"* is false — the stripper is now load-bearing and defeatable | §3.6's conclusion corrected; AC-7a's guard **ported into `no-keys.sh` check 4** as clause 4a. E-15 is the defeat, reproduced |
| 9 | MAJOR | AC-10 cannot run: §7.0's sandbox inventory omits the manifest's own file | §7.0's inventory now lists this specification, `xvm.pinned`, `xvm.base.json` and the mutants directory, and states the location-derived path `ac009.sh` uses |
| 10 | MAJOR | *"009 does not require `003` … to be re-reviewed"* is false | Replaced by the four-row inventory at the end of §1.3, which is what OQ-1 is ruled with |
| 11 | MINOR | §7.7 says "two" and enumerates four | §7.7 partitions all sixteen: **4** mock/sham, **8** carrying the cross-VM claim, **4** neither |
| 12 | MINOR | 7d cites today's line numbers as if they were §3.3's | Line numbers labelled as today's and marked as never used by the script |
| 13 | MINOR | §8.1 omits the three `new RecknZkEscrow(verifier)` call sites | Named, with today's line numbers, re-verified |
| 14 | MINOR | §8.1 omits `surfaces.pinned` | Added, and it is CS-4 of §1.4 |
| 15 | MINOR | AC-9's evidence reads as "everything ran", but `forge` reports an early-`return` gate as `Success` | Evidence reworded to `0 forge-reported skips`; the AC prose and **L-15** say what `forge` does and does not report |

**Size.** Round 1: 12 rows, 12 mutants, 7 clauses in AC-7. Round 2: **13 rows, 15 mutants,
9 clauses**. Three of the four blockers were closed by making an existing observer see more;
one (finding 3) needed a new row.

---

## 1. The claim, and what 009 is not

### 1.1 The claim (one sentence)

> **One `RecknZkEscrow` contract, with no deployment parameter of any kind, settles a deal
> funded on EVM using a proof produced by the Solana re-execution guest — because the deal
> names, at funding, the exact adjudicator program whose proof may settle it, and the
> escrow dispatches to that and to nothing a settler can choose.**

The application submitted on 2026-09-04 promises exactly this and nothing more
(`_applications/2026-09-04-ethonline-application.md`, Q2 item 2):

> *a payment escrowed on an EVM chain, disputed over work performed on Solana, settled by
> a proof — with no resolver on either side, no bridge, and no light client in the
> adjudication path.*

The last clause — **in the adjudication path** — is load-bearing and 009 keeps it. §9 says
what is still not true about *anchoring*, and §11 puts that sentence next to the claim in
every document that carries the claim.

### 1.2 Non-goals — including the ones it will be tempting to do anyway

- **N-1. `RecknVerdictVerifier.sol` is not modified. Not one byte.** In particular 009 does
  **not** add a vkey parameter to `verifyVerdict`, does **not** add an overload, does
  **not** delete `verdictProgramVKey`, and does **not** change the constructor. §4 is the
  full argument; the short form is that every one of those is a **loosening** of the check
  `008` installs over that file, and `AGENTS.md` §0's last line makes loosening that script
  a founder call, not an agent's. OQ-2 puts the alternative in front of the founder.
- **N-2. No Rust changes. No guest changes. No fixture regeneration. No proving.** 009 adds
  zero lines to `zk-verdict/lib`, `zk-verdict/program*`, `zk-verdict/*-io`,
  `zk-verdict/svm-bankhash`, `zk-verdict/script`, `reexec-evm`, `reexec-svm`, `binder`.
  009 consumes the two committed Groth16 fixtures as they are. It runs no `sp1-build`, no
  `cargo-prove`, no `--fixture`.
- **N-3. No timeout and no `refundAfterDeadline`.** That is `003`. A funded deal for which
  no proof ever arrives stays funded after 009 exactly as it does before it, and the root
  `README.md` `Known gaps (not closed)` entry saying so is **not** removed by 009.
- **N-4. The optimistic path (`contracts/RecknEscrow`) is untouched** (`AGENTS.md` §8).
- **N-5. The discarded `transferFrom` return value stays discarded.** `RecknZkEscrow.sol:86`
  today is `IERC20Min(token).transferFrom(msg.sender, address(this), amount);` with the
  boolean dropped. `003` r1 ruled that in scope for `003`. 009 moves that statement (the
  function around it grows two parameters) and changes **nothing else about it**: no
  `require`, no `bool ok`, no `SafeERC20`. Same for the `transfer` at `:117`.
- **N-6. No anchoring work.** No block-header binding, no Solana light client, no proof of
  where a `bank_hash` came from, no snapshot-subset proof. §9 states the residual; 009 does
  not narrow it by one word.
- **N-7. `settleWithProof`'s parameter list does not change.** It stays
  `settleWithProof(bytes32,bytes,bytes)` — measured today, `forge inspect RecknZkEscrow
  methodIdentifiers --json` → `"settleWithProof(bytes32,bytes,bytes)":"fdcef1bb"`. This is
  a non-goal *and* a pinned property (AC-3), because the whole safety argument of §3 is
  that a settler cannot name the adjudicator.
- **N-8. No new external / public function on `RecknZkEscrow` — and after round 2 the
  entry-point set is *closed*, not merely enumerated by name.** The `no-keys.sh` function
  enumeration (`fund` / `settleWithProof` / `refundAfterDeadline`) is byte-identical after
  009. What changes is that check 2 stops being satisfiable by an entry point that is not
  spelled `function` (§3.6, 7h, E-13). *(`fund` gains two parameters; `no-keys.sh:46` still
  matches names and not **signatures**. That residual is narrower after round 2 than before
  it, it is OQ-5, and it is not a silence.)*
- **N-9. The predicate does not widen.** One CALL / one System transfer, one delta check,
  exactly as today.
- **N-10. 009 does not touch `docs/specs/003-*.md` or `docs/specs/008-*.md`.** They are in
  review with other agents. Every obligation 009 creates for them is written in §1.3 and in
  an OQ, never as an edit to their text, and **no literal of either document is copied into
  this one**.
- **N-11. No deployment script, no `anvil`, no `broadcast`.** 009 adds no `.s.sol`.
- **N-12. 009 does not claim to test the SVM predicate.** That a 0-lamport transfer fails a
  positive floor is the guest's property, exercised today by
  `cargo run --bin svm -- --execute --amount 500000`. 009 tests **settlement wiring**. §7.4
  says so and no AC below asserts otherwise.

### 1.3 Cross-spec obligations 009 creates (written here, not in their files)

| what 009 installs | who it constrains | protocol |
|---|---|---|
| `RecknZkEscrow.sol` changes (§3.3), so `008`'s `surfaces.pinned` digest of that file goes stale | `003` inherits the new file, not the old one | 009 re-pins `surfaces.pinned` **in the same commit that changes the contract, as a one-line visible diff** (`sha256 = <old>` → `sha256 = <new>`), copied from what `surfaces.sh` prints on failure. This is `008`'s own protocol for exactly this event, applied by the task that fires it first. If `008` has not landed, there is no pin file and this row is inert. |
| `scripts/no-keys.sh` **check 4** is replaced by a strictly stronger property: `RecknZkEscrow` declares **no `constructor` and no `immutable`** (§3.6) | **`003`**, if it still wants a constructor-set `refundDelay` | **OQ-1 — founder ruling required.** 009's recommendation: keep the tightening and let `003` make the delay a `constant` or a per-deal field. A deployer-chosen refund delay is a deployment-time parameter that decides *when* money can move, which is the shape §0 exists to exclude. 009 does **not** write `003`'s replacement. |
| `fund`'s signature widens from 5 to 7 parameters while `no-keys.sh` check 2 still matches only names | nobody, mechanically — which is the problem | **OQ-5.** Pinning signatures is a tightening and belongs in the same file `003` is already extending. 009 pins the two signatures in its own gate (AC-3, AC-7) and does not pre-empt `003`. |

**What `003` inherits, in full — round 1's flat sentence here was false** (r1 finding 10).
Round 1 wrote *"009 does not require `003` or `008` to be re-reviewed for any of this"* and
reduced the `003` collision to one row. Nothing here blocks 009: `AGENTS.md` §7's ruling of
2026-09-05 takes `003` off the 9/9 gate and says it is not to be restarted, so there is no
live `003` draft to break. But **OQ-1 must be ruled against the real inventory**, not against
one row:

| `003` site | what it keys on | state after 009 |
|---|---|---|
| `003:1382` **check 8** — *"the left-hand side of every assignment inside the constructor body ∈ `{verifier, refundDelay}`, and its right-hand side is exactly the corresponding constructor parameter"* | the escrow's constructor | there is no constructor, so check 8 watches nothing — **R-9's exact shape, in `003`'s own vocabulary**. 009's 7f is a strictly larger observer (the whole contract, not the constructor body) but it lives in 009's gate, not in the founder's pre-commit command |
| `003:512` (BUYER row) and `003:515` (DEPLOYER row — *"choose `verifier` and `refundDelay` at construction"*) | a deployment-time choice | the DEPLOYER role loses its only power. The BUYER row gains one: the adjudicator moves from *which deployment to fund* into *a field in the calldata* (INV-11, L-7) |
| `003:904` **G-33** and `003:908` **G-37** (a look-alike escrow carrying the genuine verifier but different bytecode) | deployment-time parameters | those parameters no longer exist; both gauntlet rows must be re-keyed onto the deal's `verifier` / `verifierCodeHash` |
| `003:560` and `003:4096` — the five-part deployment check reads the escrow's `verifier()` | the `verifier()` getter | 009 deletes it. **Measured 2026-09-05 at `40d1ce0`** (E-4 re-run): `forge inspect RecknZkEscrow methodIdentifiers --json` lists `"verifier()": "2b7ac3f3"` today, and §3.3 has no such member. Part 5 must read `deals(dealId).verifier` instead |

**009 still does not edit `docs/specs/003-*.md` or `docs/specs/008-*.md`** (N-10). This table
is the inventory, written here, that OQ-1 is ruled with.

### 1.4 Counted surfaces 009 shares with a sibling task, and the rule that keeps both green

**The problem round 1 did not have** (r1 finding 3). §10 of round 1 argued independence from
`008` in one direction only and concluded *"009 is correct with or without `008`"*. That is
true on the **technical** axis — INV-10, which r1 re-verified independently — and false on the
**harness** axis: a sibling task asserts *totals* over surfaces 009 writes into, so landing
009 as round 1 specified it turns that sibling red. The 9/9 checkpoint requires **both green
at the same time**, not each green in turn (`AGENTS.md` §7).

**Orchestrator ruling, 2026-09-05: 009 takes the "update the counting side in the same commit"
form.** That is the form this repository already established for `surfaces.pinned`
(`003` §1.5.2 / D-11 and §1.5.4, ruled 2026-09-04). Four rules, then the inventory.

1. **Same commit.** The commit that changes a counted surface updates every sibling literal
   that counts it. Splitting them across commits is what makes a break invisible until 9/9.
2. **The new value is a printed value, never a counted one.** No agent counts patches, tests
   or checks by hand. The value written into a sibling literal is either **(a)** the observed
   value that sibling printed on failure, or — if it prints none — **(b)** the output of
   **that sibling's own measuring expression**, run verbatim on the tree being committed.
   D-5 below states (a) as a requirement on siblings; (b) is what makes the rule executable
   against a sibling that changes nothing.
3. **No literal of `008` appears in 009.** `008` is not APPROVE'd; its numbers are not facts
   yet, and a number pasted from a document still in review is a number that was never
   measured. Every quantity 009 needs about a sibling is a token measured at **009's base
   commit** — `{P}` and `{B}` (§7.3) — exactly as `003` uses `{P}`. **This document contains
   no integer describing a sibling's population or total.**
4. **`ac009.sh --all` must not report green while a sibling gate it can see is red.** That is
   **AC-12**, and it is the only thing in this document that tests the checkpoint's word
   *simultaneously*. Every other criterion here is satisfiable in a tree where a sibling gate
   is red. The qualifier *"it can see"* is not hedging: AC-12 discovers gates by a naming
   convention, and what that convention misses is written out as **L-17** rather than assumed
   away.

| # | counted surface | who counts it | what 009 does to it | who performs the update |
|---|---|---|---|---|
| **CS-1** | the population of `zk-verdict/scripts/mutants/*.patch` | a sibling's selftest step 0 asserts a literal over that glob, and its `witness=` is a digest over the same glob | 009 adds **fifteen** `M-*.patch` files to that directory (§8.1). The *globs* do not collide — `M-*` against `NN-*` — but the **population** does | **009**, in `zk-verdict/scripts/ac008-selftest.sh` — a **script**, not a specification — by rule 2(b): run `ls zk-verdict/scripts/mutants/*.patch \| wc -l` on the committed tree and copy the number. The sibling's `witness=` needs no edit at all: it is recomputed on both sides of its own comparison |
| **CS-2** | the **total test count** of the `zk-verdict/contracts` forge suite | a sibling's no-skip evidence line carries the total, and **that line lives in `docs/specs/008-verdict-domain-soundness.md` §6.1**, which its dispatcher parses | 009 adds **16** tests (§7.1), so the total becomes `{B} + 16` | **not 009.** 009 may not edit that document (N-10, and the founder's instruction of 2026-09-05 while it is in its final round). 009's obligations are exactly two: **(i)** state the edit here, precisely, so it is known before the commit rather than discovered on 9/9 — *the sibling's no-skip evidence cell must carry the number its own `no-skip.sh` prints on the post-009 tree*; and **(ii)** **AC-12**, which keeps 009 red until it is done |
| **CS-3** | `scripts/no-keys.sh` | `AGENTS.md` §0 (the declared final line); a sibling adds a check to the same file | 009 replaces check 4's body and **extends check 2** (§3.6) | **009.** 009 changes **no check number**, **no argument**, and **not the declared final line** — so a sibling asserting that line, and a sibling adding check 5, are both unaffected (D-4). **Measured**: `zk-verdict/scripts/surfaces.pinned` is a two-line file pinning `RecknZkEscrow.sol` and a prefix of `reexec-evm/src/lib.rs`; it does **not** pin `scripts/no-keys.sh`, so no digest moves |
| **CS-4** | `zk-verdict/scripts/surfaces.pinned` — `sha256(RecknZkEscrow.sol)` | a sibling's `surfaces.sh` | 009 rewrites the contract (§3.3) | **009**, in the same commit, as a one-line visible diff, copying the value `surfaces.sh` prints on failure. This is §1.3 row 1, unchanged from round 1, and it is the precedent the other three rows are modelled on |

> **D-5 — the output format 009 requires of a sibling gate, stated from 009's side because
> 009 may not write in theirs.** A gate that asserts a **count or total over a surface another
> task also writes** must, on failure, print the expected and the observed value on one line,
> in a form that can be copied without retyping — the shape `surfaces.sh` already has. Where a
> sibling does not, **rule 2(b) applies and the implementation report records which branch was
> used, per surface, by name.** **009 requires no sibling to change anything.** It requires
> that the update be a copy rather than a count, and 2(b) makes that true even against a
> sibling that prints nothing at all.

**What 009 deliberately does *not* do, with the alternative pre-written so the founder can take
it in one line.** 009 could take its own mutant directory (`zk-verdict/scripts/mutants-009/`)
and CS-1 would simply vanish. It does not, for one reason: a second directory means a second
population guard, and a patch deleted from the directory nobody counts is invisible — which is
the failure the sibling's step 0 exists to prevent. One directory keeps one guard over every
patch in the repository. The cost is one cross-task literal in a sibling's **script**, which
then disagrees with that sibling's **specification** until its next round. **OQ-7** puts the
trade in front of the founder. **009's design is correct either way**, because AC-12 names no
sibling and no directory: it discovers what is there.

---

## 2. Exactly where the wire ends today

Every line reference below was read on 2026-09-05 at `1db7cd1`.

### 2.1 What is connected

`zk-verdict/contracts/test/RecknZkEscrow.t.sol:38`, `test_real_proof_settles_to_seller`:
reads `src/fixtures/reexec-groth16-fixture.json`, deploys SP1's real `SP1Verifier`
(v6.1.0) at `:50`, wraps it in `RecknVerdictVerifier` at `:51`, deploys `RecknZkEscrow` at
`:52`, funds at `:55` with the fixture's `.deal_binding`, and calls
`escrow.settleWithProof(...)` at `:59`. The seller is paid at `:61`. **This is a real
Groth16 proof of an in-guest `revm` re-execution moving real ERC-20 balance, with no
signer anywhere in the path.**

Measured today, `cd zk-verdict/contracts && forge test`: **12 tests, 12 passed, 0 skipped**
across 5 suites. The fixture exists (`src/fixtures/reexec-groth16-fixture.json`,
`.outcome = 0`, `.vkey = 0x00248ef8…`), so the early-return gate at
`RecknZkEscrow.t.sol:39-42` does **not** fire.

### 2.2 What is not connected

`zk-verdict/contracts/test/RecknSvmVerdict.t.sol` is the whole SVM on-chain story and it
stops one call short:

- `:20` names `src/fixtures/svm-groth16-fixture.json`.
- `:35-36` deploys `SP1Verifier` and `RecknVerdictVerifier(address(sp1), vkey)` — **the
  same generic verifier contract**, constructed with the SVM guest's vkey.
- `:38` calls `v.verifyVerdict(publicValues, proof)` and asserts `outcome`, `traceHash`
  and a positive delta.
- **There is no `RecknZkEscrow` in this file.** `grep -n "RecknZkEscrow"
  zk-verdict/contracts/test/RecknSvmVerdict.t.sol` → no match. No deal is funded, no money
  moves, nothing is bound to anything.

So the state of the world is: **the SVM verdict is verified on-chain and then thrown away.**

### 2.3 The three facts that decide the design

**(a) The SVM guest already commits a `dealBinding`, and the fixture already carries it.**
`zk-verdict/program-svm/src/main.rs:129-141` computes a SHA-256 over a domain tag, the
authenticated `bank_hash`, the checked account, the predicate bounds and the transaction's
signature, and commits it as `dealBinding` at `:150`.
`zk-verdict/script/src/bin/svm.rs:235` writes it into the fixture as `.deal_binding`.
Measured today: `svm-groth16-fixture.json` has
`deal_binding = 0xe97ff443…`, `vkey = 0x0025224d…`, `outcome = 0`.
`reexec-groth16-fixture.json` has `deal_binding = 0x81899ffc…`, `vkey = 0x00248ef8…`,
`outcome = 0`. **Both bindings are non-zero and differ; both vkeys differ.**
→ **009 needs no guest work.** The binding half of the problem is already solved by the
guest and re-solved in v2 by `008`.

**(b) `RecknVerdictVerifier` holds exactly one vkey, and it is `immutable`.**
`zk-verdict/contracts/src/RecknVerdictVerifier.sol:40`:
```solidity
bytes32 public immutable verdictProgramVKey;
```
set once at `:44` and used at `:55`. One deployed `RecknVerdictVerifier` accepts proofs of
**one** program. `RecknZkEscrow.sol:28` holds **one** `RecknVerdictVerifier`, `immutable`,
set by the constructor at `:65-67`. **One deployed escrow can therefore only ever be
settled by one guest.** This is the obstacle. §4 is about nothing else.

**(c) The escrow reads three members of the verdict record and no numeric field.**
Measured by reading `RecknZkEscrow.sol`: `v.dealBinding` at `:103`; `v.outcome` at `:109`,
`:111` **and `:116`**; `v.traceHash` at `:116`. Five member accesses over three distinct
members. `v.pre`, `v.post`, `v.minDelta`, `v.maxDelta` are **never read**.
→ **009's correctness does not depend on the value width `008` changes.** This is INV-10
and it is what makes 009 safe to specify while `008` is still in review.

### 2.4 Measurements this document relies on

E-1…E-12 run 2026-09-05 at `1db7cd1`; **E-4 re-run and E-13…E-16 run 2026-09-05 at
`40d1ce0`**. `forge Version: 1.7.1`, `Commit SHA
4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, `solc 0.8.35`. Nothing outside `docs/` and five
top-level markdown files differs between the two commits, so no earlier row is stale.

| # | command | observed |
|---|---|---|
| E-1 | `forge test --match-test "test_no_such_test_009"; echo $?` | `No tests found in project!` … `0` |
| E-2 | `forge test --list --json --match-test "test_no_such_test_009"` | `{}`, exit `0` |
| E-3 | `forge test --list --json \| jq '[.[][][]]\|length'` | `12` |
| E-4 | `forge inspect RecknZkEscrow methodIdentifiers --json` *(re-run at `40d1ce0`)* | `"deals(bytes32)": "81cd872a"`, `"fund(bytes32,address,address,uint256,bytes32)": "8f1784c5"`, `"settleWithProof(bytes32,bytes,bytes)": "fdcef1bb"`, `"verifier()": "2b7ac3f3"` — **the `verifier()` getter exists today and §3.3 deletes it** (§1.3's `003` inventory) |
| E-5 | `forge inspect RecknZkEscrow storageLayout --json \| jq '.storage'` | exactly one entry: `label "deals"`, `slot "0"` — **the escrow already has exactly one storage variable**; 009 pins that rather than creating it |
| E-6 | `forge inspect RecknZkEscrow abi --json \| jq '[.[]\|{type,name}]'` | contains `{"type":"constructor"}` **today** |
| E-7 | `forge inspect RecknVerdictVerifier abi --json \| jq '[.[]\|select(.name=="verifyVerdict")\|.outputs[0].components[].name]'` | `["pre","post","minDelta","maxDelta","outcome","traceHash","dealBinding"]` — **the verdict record's member names are derivable from the compiled artifact**, so no criterion in this document has to hard-code them |
| E-8 | scratch probe: `address(contract).codehash` / nonexistent / funded EOA / `keccak256("")` | `0x5de6ebff…`, `0x00…00`, `0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`, **the last two are equal** |
| E-9 | scratch probe: two instances of one contract with **different `immutable` values** | **different `codehash`** — immutables live in runtime code, so `extcodehash` commits them |
| E-10 | scratch probe: a state-writing target called through a **`view`-typed** reference | **reverts**, sink counter `0` (STATICCALL) |
| E-11 | same target called through a **non-`view`** interface | **succeeds**, sink counter `1` (CALL) |
| E-12 | sandbox: `cp -R src test foundry.toml remappings.txt` + `ln -s <repo>/lib lib`; `rm -rf out cache && forge test --force` | **60 KB**, whole suite green in **~0.73 s** wall |
| E-13 | a contract carrying `fund`, `settleWithProof`, a draining `fallback() external` and a `receive() external payable`, run through `no-keys.sh:29-30`'s stripper and then through `no-keys.sh:46`'s enumeration | the enumeration prints **`fund`** and **`settleWithProof`** and nothing else — **`fallback` and `receive` are invisible to check 2** because neither carries the `function` keyword. The same body, counted by token, gives `function 2`, `fallback 1`, `receive 1`, `constructor 0`, `modifier 0` — **the closure of §3.6 sees both.** This is r1 finding 4, reproduced independently |
| E-14 | §3.3's own solidity block, comments stripped line-wise, split at `;` `{` `}`, every `=` that is not part of `==` `!=` `<=` `>=` `=>` taken as an assignment | **9 assignments over 8 distinct verbatim left-hand sides**: `uint8 public constant REPRODUCED`, `uint8 public constant FAILED`, `bytes32 public constant EMPTY_CODEHASH`, `deals[dealId]`, `Deal storage d`, `VerdictPublicValues memory v`, `d.state`, `to` (twice). **Round 1 pinned 7 over 6.** The script is printed in 7f |
| E-15 | `printf '%s\n' 'string constant MASK = "//"; constructor() {}' \| sed -e 's://.*::' -e 's:/\*.*\*/::'` | `string constant MASK = "` — **valid Solidity with a constructor, and the token `constructor` is gone.** The greedy variant: `printf '%s\n' 'uint x; /* a */ uint y; /* constructor() {} */ uint z;' \| sed …` → `uint x;  uint z;`. **The comment stripper is defeatable and, after 009, load-bearing** (r1 finding 8) |
| E-16 | all sixteen mandated test names of §7 matched against §7.0's regex `^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$`, and grouped by selector | **16/16 match**; per-selector counts `_AC01_ 2`, `_AC02_ 4`, `_AC03_ 2`, `_AC04_ 2`, `_AC05_ 3`, `_AC06_ 3`, summing to 16 and equal to the manifest's `tests` column. **Round 1's `test_AC03_settleWithProof_…` did not match** (r1 finding 2) |

E-8 and E-9 are the two facts §3 is built on. E-10 and E-11 are the pair AC-4 is built on —
E-11 is the negative control that makes E-10 mean something. **E-13, E-14, E-15 and E-16 are
the four measurements round 2 exists for: each one is a criterion of round 1 that was false
against the tree it was written about, and each is reproduced here by command rather than
quoted from the review.** E-12 is why every mutant in
§7.4 can run in a sandbox and **the repository's `RecknZkEscrow.sol` is never written by
the gate** (the founder's OQ-5 ruling of 2026-09-04, honoured by construction rather than
by a `trap`).

---

## 3. The design

### 3.1 The question, stated so it has one answer

*Who decides which program's proof may settle this deal, and when is that decided?*

Today the answer is "the deployer of the escrow, at deployment" — because the escrow's
verifier is `immutable` (§2.3b). That is a configuration choice by a party, made once, for
every deal the contract will ever hold. It cannot move a *funded* deal, so `no-keys.sh`
does not see it; but it decides *who is able to*, which is one level up from the thing
`AGENTS.md` §0 forbids, and it is the reason a Solana proof cannot reach `settleWithProof`
today.

**009's answer: the buyer, at `fund`, per deal, in public, in the calldata that funds it —
and nobody afterwards.** The adjudicator becomes a *term of the deal*, exactly like
`seller`, `token`, `amount` and `dealBinding` already are.

### 3.2 The deal terms after 009

A deal is funded against **three** commitments instead of one:

| term | what it fixes | who supplies it | when |
|---|---|---|---|
| `verifier` (address) | which contract adjudicates | buyer | `fund` |
| `verifierCodeHash` (bytes32) | **what code is at that address** — and therefore, by E-9, which SP1 verifier address and which program vkey are baked into it | buyer | `fund` |
| `dealBinding` (bytes32) | which committed prestate + predicate + plan/transaction the verdict must be about | buyer | `fund` |

`verifierCodeHash` is not decoration and it is not redundant with `verifier`. E-9 measured
that a contract's `extcodehash` changes when its `immutable`s change. So for the canonical
`RecknVerdictVerifier`, one 32-byte value commits **both** immutables — the SP1 verifier
address at `:38` and `verdictProgramVKey` at `:40`. The deal therefore names the *program*,
not merely an address, and a seller can check the whole adjudication stack against one hash
computed off-chain from the canonical artefact.

**R-11(iii) check on that sentence** — *does this pin what the dispatch target is set to, or
only that it is what was set?* It pins **what**: the code is fixed by value at funding, and
the address is fixed by value at funding. What it does **not** pin is the code at the
`ISP1Verifier` address *inside* that code — that address is committed, its code is not.
That residual is L-6 in §9, and closing it on-chain is `003`'s deployment check.

### 3.3 `RecknZkEscrow` after 009

The whole diff, written out. **This is the entire contract change 009 makes.**

```solidity
contract RecknZkEscrow {
    uint8 public constant REPRODUCED = 0;
    uint8 public constant FAILED = 1;
    // extcodehash of an account that exists with no code (measured, E-8).
    bytes32 public constant EMPTY_CODEHASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    enum State { None, Funded, Settled }

    struct Deal {
        address buyer;
        address seller;
        address token;
        uint256 amount;
        address verifier;          // NEW
        bytes32 verifierCodeHash;  // NEW
        bytes32 dealBinding;
        State state;
    }

    mapping(bytes32 => Deal) public deals;

    event Funded(
        bytes32 indexed dealId, address indexed buyer, address indexed seller,
        address token, uint256 amount,
        address verifier, bytes32 verifierCodeHash, bytes32 dealBinding
    );
    event SettledByProof(bytes32 indexed dealId, address indexed to, uint8 outcome, bytes32 traceHash);

    error DealExists();
    error BadState();
    error ZeroBinding();
    error BindingMismatch();
    error BadOutcome();
    error NoVerifierCode();     // NEW
    error VerifierMismatch();   // NEW

    // no constructor.

    function fund(
        bytes32 dealId, address seller, address token, uint256 amount,
        address verifier, bytes32 verifierCodeHash, bytes32 dealBinding
    ) external {
        if (deals[dealId].state != State.None) revert DealExists();
        if (dealBinding == bytes32(0)) revert ZeroBinding();
        if (verifierCodeHash == bytes32(0) || verifierCodeHash == EMPTY_CODEHASH) revert NoVerifierCode();
        if (verifier.codehash != verifierCodeHash) revert VerifierMismatch();
        deals[dealId] = Deal({
            buyer: msg.sender, seller: seller, token: token, amount: amount,
            verifier: verifier, verifierCodeHash: verifierCodeHash,
            dealBinding: dealBinding, state: State.Funded
        });
        emit Funded(dealId, msg.sender, seller, token, amount, verifier, verifierCodeHash, dealBinding);
        // State written first; the token pull is the only external interaction.
        IERC20Min(token).transferFrom(msg.sender, address(this), amount);
    }

    function settleWithProof(bytes32 dealId, bytes calldata publicValues, bytes calldata proofBytes)
        external
    {
        Deal storage d = deals[dealId];
        if (d.state != State.Funded) revert BadState();
        if (d.verifier.codehash != d.verifierCodeHash) revert VerifierMismatch();

        VerdictPublicValues memory v =
            RecknVerdictVerifier(d.verifier).verifyVerdict(publicValues, proofBytes);

        if (v.dealBinding != d.dealBinding) revert BindingMismatch();

        d.state = State.Settled;
        address to;
        if (v.outcome == REPRODUCED) {
            to = d.seller;
        } else if (v.outcome == FAILED) {
            to = d.buyer;
        } else {
            revert BadOutcome();
        }
        emit SettledByProof(dealId, to, v.outcome, v.traceHash);
        IERC20Min(d.token).transfer(to, d.amount);
    }
}
```

**Five** properties of that text, each of which an AC checks:

1. **`settleWithProof`'s signature is unchanged** (N-7, AC-3). There is no parameter a
   settler can use to name an adjudicator. This is the safety argument, and it is
   structural rather than lexical: the property is *"the parameter does not exist"*, which
   no operand-resolution question (R-8) can undo.
2. **The dispatch is `view`-typed**, so it compiles to `STATICCALL` (E-10/E-11). The escrow
   calls buyer-chosen code before it has checked the binding, and that is safe only because
   the callee cannot write. AC-4 tests this **with its negative control**.
3. **There is no constructor and no `immutable`.** Two deployments of this source are
   behaviourally identical. There is no deployer choice at all — which is a *strengthening*
   of the central claim, not a weakening (§3.6).
4. **The escrow still reads only `dealBinding`, `outcome`, `traceHash`** (INV-10, AC-7d).
5. **The set of ways an external caller can enter this contract and reach a value-moving
   statement is exactly `{fund, settleWithProof}`** (INV-12, AC-7h, and `no-keys.sh` check 2
   after §3.6). Round 1 asserted this by enumerating what it found; it is now asserted by
   closing what can be there. The compiler also emits four getters — `deals`, `REPRODUCED`,
   `FAILED`, `EMPTY_CODEHASH` — and every one of them is `view` by construction, which is why
   the closure is over value-moving entry points and not over entry points as such.

### 3.4 Who ties Solana work to an EVM deal, and when — including the part that is awkward

**The buyer, at `fund`, by committing a `dealBinding` that is a function of the Solana
side.** The SVM guest's binding (`program-svm/src/main.rs:129-141`) commits, among other
things, the authenticated `bank_hash` and the **signature** of the adjudicated transaction.

A signature does not exist before the transaction is signed. Therefore:

> **The escrow after 009 is a dispute escrow, not a pre-payment escrow. Funding commits to
> an anchor and a transaction that already exist.**

This is not a defect 009 introduces and it is not specific to Solana. The EVM binding
commits `state_root`, and in any flow where the checked predicate is evaluated *after* the
seller's work, that root is a post-work anchor and is likewise unknown at the moment the
work is commissioned. Both paths have the same temporal shape and 009 states it once,
here, rather than implying otherwise anywhere.

The consequence that must be said out loud, because it is what a judge will ask:
**the deal's terms are agreed off-chain and asserted on-chain by the buyer.** The escrow
guarantees exactly one thing about them — that the proof which settles is a proof about
*those* terms and no others. It guarantees nothing about whether the terms were fair, and
nothing about whether the anchor was ever a real chain state (§9, L-1/L-2).

### 3.5 The no-op question, answered for this task

*Can a seller who does nothing be paid under 009?*

To settle a deal to the seller, a proof must (i) verify under the vkey baked into the code
whose hash the deal committed, and (ii) carry the deal's exact `dealBinding`. For the SVM
guest, (ii) forces the committed `bank_hash`, the checked account, the bounds, and the
transaction signature. A prover who changes any committed account changes `bank_hash`,
which changes the binding, which fails (i.e. `BindingMismatch`). A prover who supplies a
different transaction changes the signature, same result. And the guest's own predicate
gives `Failed` for a 0-lamport credit against a positive floor.

So the answer is no — **and the reason is that the binding is a term the buyer fixed, not
that the escrow inspects anything.** 009 adds no new predicate and claims none (N-12).

The 009-specific version of the same question is *"can a settler who does nothing choose a
favourable adjudicator?"* — and the answer is the whole of §3.1: there is no parameter to
choose it with (AC-3), and the deal's `verifier` is written once, in `fund`, and read
everywhere else (INV-1).

### 3.6 `scripts/no-keys.sh` — two checks tightened, no check added, no check renumbered

009 changes the **body** of check 4 and the **body** of check 2. It adds no check, changes no
check number, changes no argument, and does not touch the declared final line
`✓ the claim holds: no key can move a funded escrow.` — so a sibling task adding check 5
collides with nothing here (§1.4 CS-3, D-4).

#### 3.6.1 check 4 — the constructor clause is vacuous after 009, and the observer it uses is defeatable

Today (`scripts/no-keys.sh:64-70`) check 4 is *"the constructor may bind only the verifier"*,
implemented as *"the constructor body does not contain `= msg.sender`"*. After 009 there is no
constructor, so that `sed` range matches nothing and the check passes **vacuously** — an
observer that watches nothing (R-9/R-10 shape). 009 replaces its body with two clauses:

> **check 4a (009): the region the four checks read is a literal one.** The raw target file
> contains **zero** `/*` and **zero** `*/`, and the stripped body contains **zero** `"` and
> **zero** `'`.
>
> **check 4b (009): `RecknZkEscrow`'s body declares no `constructor` and no `immutable`.**
> Over the stripped body: zero occurrences of the token `constructor`, zero of `immutable`.

**4a is not decoration and it is not a second check — it is what makes checks 1, 2, 3 and 4b
mean anything** (r1 finding 8). `no-keys.sh:29-30` strips comments line-wise with
`sed -e 's://.*::' -e 's:/\*.*\*/::'`. Measured (E-15): the line
`string constant MASK = "//"; constructor() {}` becomes `string constant MASK = "` — valid
Solidity carrying a constructor, with the token gone; and a greedy `/* … */` pair deletes
everything between the first `/*` and the last `*/` on its line. Before 009 the stripper was
a convenience; after 009, check 4b's entire content is two token counts over its output, so
**the stripper became load-bearing**, and a load-bearing observer that can be silenced from
inside the file it observes is not an observer. 4a closes both routes in the raw file, before
stripping. AC-7's 7a asserts the same property inside 009's own gate; the reason it is *also*
here is that `AGENTS.md` §6's commit ritual runs `no-keys.sh` **and nothing else**.

#### 3.6.2 check 2 — the entry-point set is closed, not enumerated (founder ruling, OQ-A, 2026-09-05)

Today check 2 enumerates the state-changing surface with
`grep -oE '\bfunction +[a-zA-Z_][a-zA-Z0-9_]*'` and requires every name found to be in
`fund settleWithProof refundAfterDeadline`. **Measured (E-13): a `fallback()` that pays out
any funded deal's tokens to its caller is not found by that grep at all**, because
`fallback()` and `receive()` are declared without the `function` keyword. It is also invisible
to check 1's vocabulary, to check 3 (`require( msg.sender` / `if ( msg.sender`), and to 7f
(the drain performs no assignment). A live money path that the founder's pre-commit ritual
cannot see is a hole in the central claim, so 009 closes it.

**Founder ruling, 2026-09-05 (`docs/reviews/009-spec-r1.md` OQ-A): yes, 009 puts the
entry-point closure into `no-keys.sh` check 2**, subject to §1.4's discipline (same commit,
printed values, no sibling literal) and to R-7: **close it by property, not by adding the two
names to a list.**

> **check 2 (009), clause 2a — the closure.** Let `K` be the set of Solidity keywords that
> introduce a body of executable code reachable **after deployment** at contract-member level.
> Over the grammar of Solidity 0.8.x, `K = {function, fallback, receive, modifier}` — this is
> the complete list of such keywords, not a selection of dangerous ones, and `constructor` is
> deliberately **not** in it because it runs before deployment and is check 4b's. Over the
> stripped body, count the occurrences of each element of `K` as a token, and require:
>
> - the count of `function` equals the number of names clause 2b enumerates, and
> - **the count of every other element of `K` is zero**, and
> - the **sum** over `K` is printed as its own number.
>
> **Clause 2b** is today's check, unchanged: every name following `function` is in
> `fund settleWithProof refundAfterDeadline`.
>
> **Clause 2c — the region reaches everything the deployed contract can execute**
> (r2 BLOCKER 1). Clauses 2a and 2b read *from the `contract RecknZkEscrow` line
> onward*. **An inherited member is declared above that line**, so a base contract
> carrying a `fallback` that drains a funded deal is outside the region every other
> clause reads — measured in `/tmp/sbx009`, compiled:
> `[PASS] test_inherited_fallback_drains_a_funded_deal`, with all four checks and all
> nine AC-7 clauses green. Three properties close it, and none of them names a
> construct:
>
> - the normalised text between the token `contract RecknZkEscrow` and the `{` that
>   opens its body is **empty** — i.e. there is no inheritance specifier, so nothing
>   the contract executes is declared elsewhere in the file;
> - the token `contract` occurs **exactly once** in the whole file, so there is no
>   second contract to inherit from or to declare members in;
> - the token `using` is counted over the **whole file**, not over the region — a
>   `using … for` above the contract line binds member-call resolution inside it.
>
> The first two are what make "from the `contract` line onward" a complete reading of
> the deployed code rather than a convenient one. The third is 7i's precondition,
> which round 2 measured over the wrong span.

**Why this is a closure and not a denylist** (R-7). The rule is not *"`fallback` and `receive`
are forbidden"*. The rule is *"the only member declarations through which this contract can be
entered are `function` declarations whose names are enumerated"*, and `K` is how that sentence
is decided mechanically. A construct nobody has thought of yet fails clause 2a the same way
`fallback` does, provided it is a member-level code-bearing keyword — and if Solidity adds
one, the **printed sum** stops equalling the `function` count and the check goes red rather
than quietly passing. `fallback` and `receive` are witnesses in the corpus (mutant **M-11**),
not entries in a list.

**What the closure does not reach, said here rather than implied.** Public state variables
generate getters, which are entry points; every one of them is `view` by construction and
cannot move value, and the *set* of state variables is pinned by 7c and 7f. Statements
**inside** the two enumerated entry points are a different question, closed by 7f (assignments),
7e (the dispatch site) and 7i (no inline assembly, no `using`); the residual is L-16.

#### 3.6.3 The tightening argument, and the sentence round 1 drew from it that was false

**Both changes are tightenings, and the argument is required, not optional.** For check 4:
every tree that passed old check 4 and has no constructor still passes 4b; every tree with a
constructor is now rejected, and some of those passed before; no previously-rejected tree is
now accepted. 4a rejects trees with block comments or string literals in the escrow, and today
there are none (7a, measured 0/0/0). For check 2: clause 2b is today's predicate verbatim, and
2a only rejects. **r1 independently re-derived the check-4 half of this argument and confirmed
it**; it is the *conclusion* round 1 drew from it that was wrong.

**The false sentence, corrected.** Round 1 wrote *"every consumer of that line, including the
founder's pre-commit ritual and `003`'s harness, is unaffected."* That is false, and it is
false in the direction that flatters 009. The **line** is unchanged; **what the line means is
not.** After 009 the escrow acquires a dispatch into an address held in a mapping, and the
build condition gained no coverage of that dispatch. What is true is narrower and is what this
document now claims:

- the script's **name, arguments, check count and final line** are unchanged, so a consumer
  that reads the exit status or the final string keeps working (D-4, CS-3);
- **the set of trees accepted strictly shrinks**, so no tree that was rejected becomes
  accepted;
- **and `no-keys.sh` exiting 0 does not, after 009, mean what it meant before 009** — it now
  admits a contract that calls out to buyer-named code. What makes that safe is INV-9
  (the dispatch is `STATICCALL`, E-10/E-11, AC-4) and B-1/B-2/B-3 of §4.4, **none of which
  `no-keys.sh` checks**. §11(3) requires `AGENTS.md` §0 to say this in the same commit.

**What the tightening buys:** with no constructor, nothing in the contract can be set at
deployment. Combined with E-5 (one storage variable, the deal mapping) the demo's sentence
becomes *"there is no key, and there is also nothing a deployer chose"* — a stronger claim
than the project ships today, obtained by deleting code.

**What it costs:** `003` cannot have a constructor-set `refundDelay`, and three further `003`
sites move with it. That is OQ-1, ruled with §1.3's inventory, because `003` is another
agent's document (N-10).

### 3.7 Options considered and rejected

| option | why not |
|---|---|
| **Two escrow deployments** — leave every contract untouched and deploy one escrow per verifier. Zero Solidity diff, zero risk. | It answers the application's sentence literally and loses the point. The *deployer* would decide which VM an escrow adjudicates, which reintroduces a deployment-time party at the exact place the product claims there is none, and it dodges the question §4 exists to answer ("one escrow, two proof kinds — why is that safe?") rather than answering it. It is recorded here so the founder can take it if the schedule collapses (§10, OQ-6); its cost is this row. |
| **Give `verifyVerdict` a vkey parameter** (or add `verifyVerdictWith`). One verifier contract for all programs; the deal commits a vkey. | This is the technically cleanest shape and it is **not available to an agent**: it loosens the check `008` installs over `RecknVerdictVerifier.sol` (the token set grows, the function count grows, the constructor form changes), and `AGENTS.md` §0 plus `008`'s own N-7 make loosening that script a founder call. **OQ-2** puts it in front of the founder with this reasoning attached. |
| **Commit only the verifier address** (no `verifierCodeHash`) | An address is a weaker statement than the code at it. With the codehash, a seller checks one hash; without it, a seller must reason about what is deployed there and about whether it can change. The check is three tokens and one comparison. |
| **Commit `keccak256(verifier ‖ codeHash ‖ binding)` as one word**, keeping `fund`'s 5 parameters | Smaller ABI, opaque deal. A funded deal would no longer *say* what it committed to, so a seller could not read it off-chain from `deals(dealId)` and an event could not carry it. Legibility is worth two storage words at local tier. |
| **A registry / allow-list of accepted verifiers** | A key. Rejected without further discussion (`AGENTS.md` §0). |

---

## 4. The one-vkey problem, head on

### 4.1 The obstacle, stated precisely

`RecknVerdictVerifier` binds one vkey at construction (`:40`, `:44`) and checks against it
at `:55`. `RecknZkEscrow` binds one `RecknVerdictVerifier` at construction (`:28`, `:65-67`).
Composing those two immutables gives: **a deployed escrow can be settled by proofs of
exactly one guest program.** That is why `RecknSvmVerdict.t.sol` verifies a Solana proof and
then has nowhere to put it (§2.2).

### 4.2 What 009 does about it

**009 does not remove the verifier's immutable. It removes the *escrow's*.**

`RecknVerdictVerifier` stays a single-program adjudicator, deployed once per guest —
`RecknVerdictVerifier(sp1, evmVkey)` and `RecknVerdictVerifier(sp1, svmVkey)`. Deploying one
is permissionless and parameterless from the protocol's point of view: it is not a
registration, nobody approves it, and nothing enumerates the set of them.

The escrow stops choosing. Each deal names the adjudicator it accepts.

### 4.3 How `settleWithProof` tells an EVM proof from an SVM proof

**It does not, and that is the design, not an omission.**

The escrow never learns which virtual machine a verdict is about. There is no branch, no
tag byte, no `if (isSvm)`, no enum. What it learns is *which program* — because the deal
committed the code of the contract that holds that program's vkey — and the SP1 verifier
does the rest.

The claim is therefore not *"the escrow distinguishes two paths"* but the stronger and
simpler *"the escrow has one path, and the deal decides where it points."* Adding a new
guest — a third VM, a different predicate, a future runtime — requires **zero** contract
changes: deploy a `RecknVerdictVerifier` with the new vkey and fund a deal that names it.

### 4.4 Why one escrow accepting two kinds of proof is safe

Three independent barriers, in the order they fire. The AC that tests each is named, and
the one that carries the weight is named.

| # | barrier | what it answers | what breaks if it is the only one | tested by |
|---|---|---|---|---|
| B-1 | **The deal's committed code.** `settleWithProof` dispatches to `d.verifier`, whose code must still hash to `d.verifierCodeHash`. A settler has no parameter to name a different one (N-7). | *who selected the adjudicator, and can a settler change it after funding* | **the escrow would pay out on whatever a named contract returned, with no proof anywhere.** This is not a hypothetical: it is what **AC-3 test 2 demonstrates and asserts as correct behaviour** for a buyer who names a sham — deal B is funded against `AlwaysReproduces` and submitting garbage settles to the seller | AC-3, AC-5 |
| B-2 | **SP1 verification.** The proof must verify under the vkey baked into that code. An SVM-guest proof does not verify under the EVM guest's vkey. | *whether a payout means anything at all* | **there would be no product.** `CLAUDE.md`: *"決済権限は「proof が検証される」ことから来る"*. Every barrier other than B-2 is about *which* proof; B-2 is why a proof is required | AC-2 (both directions), AC-4 |
| B-3 | **The binding.** The verdict's `dealBinding` must equal the deal's. | *which execution the proof is about* | any proof of the deal's own program, about some other prestate / predicate / plan, would settle this deal — the "other convenient execution" the binding exists to exclude | AC-2 (the third test isolates B-3 from B-2) |

**B-2 is the load-bearing one, and it is the entire product.** B-1 and B-3 narrow *which*
proof settles *which* deal; **only B-2 makes "proof" mean proof.** Round 1's table said the
opposite — it called B-1 load-bearing and B-2/B-3 "defence in depth" — and that sentence, had
it survived into §11(4)'s `CLAUDE.md` edit, would have described a different product than the
one this repository has (r1 finding 5). **B-1 alone would settle on unverified bytes.**

The one thing round 1 got right here, kept: **009 does not rely on the cryptographic
separation of the two guests' domain tags for anything.** The two guests could share a tag and
009's safety argument would be unchanged, because B-1 fixes the *program* and B-2 then refuses
a proof of any other one. That is written so no later round mistakes tag separation for the
mechanism — and it is **not** a claim that B-2 is redundant.

**The degenerate implementation this section exists to exclude:** an escrow that keeps a
single verifier and *"supports SVM"* by having the test deploy that one verifier with
whichever vkey the test needs. Every naive acceptance criterion about "an SVM proof settles
an escrow" is satisfied by it. AC-1 and AC-2 kill it by requiring **one escrow instance,
two verifier instances, two fixtures asserted distinct, and both settlements, inside a
single test function.**

---

## 5. State machine

### 5.1 States

`State { None, Funded, Settled }` — unchanged by 009. There is no fourth state and 009 adds
none.

Per-deal fields other than `state` are written **exactly once**, in `fund`, and read
everywhere else. There is no state in which `deals[id].verifier` differs from the value
`fund` wrote, because no code path writes it twice (INV-1, AC-7f).

### 5.2 Every transition, including the ones that revert

| # | from | call | condition | to | effect |
|---|---|---|---|---|---|
| T-1 | `None` | `fund` | all four guards pass | `Funded` | deal written; `amount` pulled from `msg.sender` |
| T-2 | `None` | `fund` | `dealBinding == 0` | `None` | revert `ZeroBinding` |
| T-3 | `None` | `fund` | `verifierCodeHash` is `0` or `EMPTY_CODEHASH` | `None` | revert `NoVerifierCode` |
| T-4 | `None` | `fund` | `verifier.codehash != verifierCodeHash` | `None` | revert `VerifierMismatch` |
| T-5 | `None` | `settleWithProof` | always | `None` | revert `BadState` |
| T-6 | `Funded` | `fund` | always | `Funded` | revert `DealExists` |
| T-7 | `Funded` | `settleWithProof` | `d.verifier.codehash != d.verifierCodeHash` | `Funded` | revert `VerifierMismatch` — **not reachable at 009's tier; reachable on an EIP-6780 chain, see §5.3 and L-14** |
| T-8 | `Funded` | `settleWithProof` | proof does not verify under the deal's program | `Funded` | revert (from `ISP1Verifier`) |
| T-9 | `Funded` | `settleWithProof` | verifies, `v.dealBinding != d.dealBinding` | `Funded` | revert `BindingMismatch` |
| T-10 | `Funded` | `settleWithProof` | verifies, binding matches, `outcome == REPRODUCED` | `Settled` | `amount` → `seller` |
| T-11 | `Funded` | `settleWithProof` | verifies, binding matches, `outcome == FAILED` | `Settled` | `amount` → `buyer` |
| T-12 | `Funded` | `settleWithProof` | verifies, binding matches, `outcome ∉ {0,1}` | `Funded` | revert `BadOutcome` |
| T-13 | `Settled` | `settleWithProof` | always | `Settled` | revert `BadState` |
| T-14 | `Settled` | `fund` | always | `Settled` | revert `DealExists` |

### 5.3 Transitions and states that do not exist

- **`None` → `Settled` does not exist.** No path writes `State.Settled` other than the one
  in `settleWithProof`, which is guarded by `d.state != State.Funded`.
- **`Settled` → `Funded` does not exist.** `fund` requires `State.None`.
- **No transition rewrites `verifier`, `verifierCodeHash`, `dealBinding`, `buyer`,
  `seller`, `token` or `amount`.** The only assignment to a member of a stored `Deal`
  outside the single `deals[dealId] = Deal({…})` literal is `d.state = State.Settled`
  (AC-7f pins the assignment set).
- **T-7 is not reachable at 009's tier, and no AC asserts that it fires.** Round 1 wrote that
  it is *"unreachable on any chain where deployed runtime code is immutable, which is every EVM
  this project targets"*. **That is a claim above 009's tier and it is wrong** (r1 finding 7).
  Under **EIP-6780** (Cancun) `SELFDESTRUCT` still deletes the account when the contract was
  created in the **same transaction**, so a factory can, in one transaction: create a killable
  verifier, call `fund` with its then-live codehash — every `fund` guard passes, including
  T-4's — and destroy it. Afterwards `d.verifier.codehash == 0 != d.verifierCodeHash`, T-7
  fires on **every** `settleWithProof`, and combined with **N-3** (009 adds no timeout) the
  deal is **permanently unsettleable**: the seller who did the work gets nothing and the money
  is stranded. 009 targets chains beyond mainnet (`AGENTS.md` §3 tasks 005 Arc, 006 Hedera)
  and offers no evidence about any of them.
  **009 neither demonstrates nor closes this**, and it adds no AC for it: r1 measured that in
  `forge 1.7.1` a contract created and `selfdestruct`ed inside one test function keeps its
  codehash and its `code.length` under `evm_version` `osaka` **and** `shanghai`, so a test
  written for this would pass for the wrong reason — the exact shape `AGENTS.md` §5 forbids.
  It is **L-14**, and the guard is kept because it is fail-closed.
- **There is no state in which the escrow dispatches to an address the caller supplied.**
  The parameter does not exist (N-7, AC-3).
- **There is no re-entrant state.** The only external call made before `d.state` is written
  is the `view`-typed dispatch, which is a `STATICCALL` (E-10, AC-4). The two token calls
  happen after the state write.

---

## 6. Invariants

Identifiers are referenced by the ACs in §7.

- **INV-1 (adjudicator fixation).** For every `dealId`, `deals[dealId].verifier` and
  `.verifierCodeHash` are written by exactly one statement, in `fund`, and by no other. The
  program whose proof can settle a deal is therefore decided by the funder and by nobody
  after funding — in particular not by the settler, who has no parameter for it.
- **INV-2 (program identity).** A `settleWithProof` call that does not revert implies that
  **the code whose keccak equals `d.verifierCodeHash` was called and returned a record**, and
  that the payout followed that record.

  **It does not imply that a proof was verified, and round 2 said it did** (r2 BLOCKER 3). The
  earlier wording — *"there is no path to a payout that skips proof verification"* — is **false
  after 009**: the deal's verifier is named by the **buyer** at `fund`, so a buyer who names
  `AlwaysReproduces` (a contract whose `verifyVerdict` returns `REPRODUCED` for any bytes) is
  paid out on garbage, and 009's own AC-3 test 2 requires exactly that behaviour as correct.
  The design is not the defect and this document does not propose changing it — a registry is a
  key, a vkey argument is a founder question, and two escrows only moves the same objection up a
  level. **The false thing was the sentence**, and it was pointed at the file that states the
  central claim (§11(4)).

  What is true, and what INV-3 and §4.4's B-1/B-2/B-3 actually carry: **the funder chooses the
  program; the proof, checked by that program, chooses the payout.** A funder who names a sham
  program has defrauded nobody but themselves — and that is the direction 009 leaves open on the
  **buyer** side.

  **The risk 009 newly creates is on the seller side, and it was unwritten.** Before 009 the
  escrow's verifier was common to every deal, so a seller who reproduced was necessarily paid.
  After 009 a buyer can fund naming a verifier that always returns `FAILED`, and the seller does
  the work for nothing while the refund goes back to the buyer. No AC detects it, because it is
  indistinguishable on-chain from an honest `Failed`. The seller's protection is off-chain — read
  the deal's `verifier` and `verifierCodeHash` before working, which is what L-4 and L-7's
  checklist are for. **This is a capability 009 adds**, not a pre-existing one, and it is
  recorded as such here and in **L-7**.
- **INV-3 (binding).** A payout implies the verified record's `dealBinding` equals the
  value committed at `fund`. A proof of some other execution — other prestate, other
  predicate bounds, other plan or other signed transaction — cannot settle this deal.
- **INV-4 (no path confusion).** For any two deals funded against verifiers `A` and `B`
  whose vkeys differ, no proof that settles the `A` deal can settle the `B` deal. 009 does
  **not** assume the vkeys differ: AC-2 asserts the inequality at run time from the two
  fixtures, so a tree in which the two fixtures became the same artefact fails rather than
  passes.
- **INV-5 (value conservation).** Across `fund` + at most one `settleWithProof` for a deal:
  `balanceOf(buyer) + balanceOf(seller) + balanceOf(escrow)` is constant, `totalSupply` is
  constant, and the escrow's balance attributable to that deal goes from `amount` to `0`
  exactly once. No path pays two recipients and no path pays twice.
- **INV-6 (no double settlement).** `Funded → Settled` is one-way and guarded by the state
  read at the top of `settleWithProof`, before any external call.
- **INV-7 (keylessness).** `msg.sender` appears exactly **three** times in the contract body,
  all three in `fund` — the buyer field (`:77`), the `Funded` event (`:84`) and the
  `transferFrom` debit (`:86`), measured with `grep -c` on 2026-09-05. *(Round 2 wrote "twice",
  in both the current contract and §3.3; it was a number transcribed rather than run — r1
  finding 1's shape, r2 finding 8.)* All three record or debit the funder. `settleWithProof` never reads it. This is
  `no-keys.sh` check 3 and 009 does not weaken it.
- **INV-8 (no configuration).** `RecknZkEscrow` has no constructor and no `immutable`, so
  two deployments of the same source are behaviourally identical and there is no
  deployment-time parameter to disclose, trust, or check.
- **INV-9 (static adjudication).** The dispatch into `d.verifier` cannot write state. It is
  typed through a `view` function and therefore compiles to `STATICCALL` (E-10). This is
  what makes it safe for the escrow to call buyer-supplied code before the binding check.
- **INV-10 (width independence).** The escrow reads exactly three members of the verdict
  record — `dealBinding`, `outcome`, `traceHash` — and no numeric member. Therefore no
  change to the width of `pre` / `post` / `minDelta` / `maxDelta` can change any behaviour
  009 specifies, and 009 is correct against the tree with or without `008`. The member list
  is **derived from the compiled `RecknVerdictVerifier` artefact** (E-7), never written out
  in a script (AC-7d).
- **INV-12 (the callable surface is closed).** The set of member declarations through which
  `RecknZkEscrow` can be entered after deployment is exactly two `function` declarations,
  `fund` and `settleWithProof`. There is no `fallback`, no `receive`, no `modifier`, no
  constructor, no inline assembly and no `using … for`. The compiler additionally emits four
  `view` getters, which cannot move value. This is stated as an invariant because round 1
  asserted the *enumeration* (*"these are the functions I found"*) and a `fallback` that drains
  any funded deal satisfied every criterion round 1 wrote (E-13). An enumeration is not a
  closure. Mechanized by AC-7's 7h/7i and by `no-keys.sh` check 2 clause 2a (§3.6.2).
- **INV-11 (the seller's checklist grew by one).** Before 009 a seller had to check one
  value on a funded deal (`dealBinding`). After 009 they must check three
  (`verifier`, `verifierCodeHash`, `dealBinding`). This is a real cost of the design and is
  stated as an invariant so that no document may describe the funded deal as
  self-authenticating. §9 L-4.

---

## 7. Acceptance criteria

### 7.0 How an AC is decided

Three gates, in `008`'s construction, because the same two failures keep happening in this
repository.

**Gate 1 — exit status is not enough.** Re-measured today (E-1, E-2): `forge test
--match-test` with a pattern that matches nothing prints `No tests found in project!` and
**exits 0**; `--list --json` with the same pattern prints `{}` and exits 0. There is no
`--fail-on-no-tests` in forge 1.7.1. **Every AC therefore asserts an exact count before it
asserts success.** `zk-verdict/scripts/ac009.sh` implements:

```
kind = forge   (columns: selector, tests)
  cd zk-verdict/contracts
  forge test --list --json --match-test "<selector>"      # must be valid JSON
     found := [.[][][]] ;  FAIL unless |found| == <tests>   # ac009.sh refuses <tests> < 1
     every name in found must match ^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$
     # The tail is lower-case on purpose and round 2 does not widen it. Round 1 mandated
     # `test_AC03_settleWithProof_...`, which this regex rejects, so AC-3 was red on day one
     # (r1 finding 2). All sixteen names are re-checked against this exact regex in E-16 and
     # the check is repeated as a gate in §7.8.
  forge test --json --match-test "<selector>"              # must be valid JSON
     ran := every entry of every suite's test_results, "(…)" stripped
     FAIL unless set(ran) == set(found) and |ran| == <tests> and every status == "Success"
  # --match-test takes ONE regex. A space is a literal space and matches nothing.
  # No selector in this document contains a space.
  # Manifest ids are AC-N; test names use the ZERO-PADDED two-digit form AC0N, and the
  # selector column carries the padded form literally. ac009.sh does not derive one from
  # the other -- both are read from the manifest row, so they cannot drift apart silently.

kind = script  (columns: command, evidence)
  run <command>; exit status must be 0; stdout must contain <evidence> verbatim as a
  substring of one line, after replacing every {witness} with a 16-lowercase-hex value
  ac009.sh RECOMPUTES ITSELF from §7.2. ac009.sh's recomputation must not invoke <command>.
  A row whose evidence contains no {witness} is exempt only where §7.2 says so in writing.
```

**Gate 2 — a count is not an assertion.** Sixteen tests named `test_AC01_…` with bodies of
`assertTrue(true);` pass gate 1 completely. Every AC below therefore names, on a
`Falsify:` line, **a concrete degenerate implementation that makes that AC exit non-zero**.
An AC without one is not an acceptance criterion.

**Gate 3 — the gate must detect a wrong implementation.** AC-10 applies **fifteen** committed
mutation patches to a **sandbox copy** of the layout and requires each named row to exit
non-zero. A body that asserts nothing survives the mutant, so its row stays green, so
AC-10 fails.

**The sandbox, and why 009 needs no founder exception for it.** E-12: a copy of
`zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}` with `lib` **symlinked** is
60 KB and runs the whole suite in ~0.73 s including a `--force` rebuild. 009's selftest
reconstructs, under `mktemp -d`:

```
$S/scripts/no-keys.sh
$S/zk-verdict/scripts/*                       (every 009 script, plus ac009.sh)
$S/zk-verdict/scripts/xvm.pinned              (copy — AC-0b reads it)
$S/zk-verdict/scripts/xvm.base.json           (WRITTEN BY THE SELFTEST for this sandbox;
                                               never copied, never a re-measure of the
                                               repository's — see below)
$S/zk-verdict/scripts/mutants/M-*.patch       (copies — AC-10's own witness set)
$S/docs/specs/009-cross-vm-settlement.md      (copy — THE MANIFEST ac009.sh PARSES)
$S/zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}   (copies)
$S/zk-verdict/contracts/lib -> <repo>/zk-verdict/contracts/lib   (symlink, read-only use)
$S/{README.md, AGENTS.md, CLAUDE.md}          (copies, for AC-11's mutant)
$S/zk-verdict/README.md                        (copy)
```

**The manifest's own file was missing from round 1's inventory, and without it AC-10 cannot
run at all** (r1 finding 9). `ac009.sh` resolves the manifest as
`"$root/docs/specs/009-cross-vm-settlement.md"` where `root=$(cd "$here/../.." && pwd)` and
`here=$(cd "$(dirname "$0")" && pwd)` — location-derived, exactly like `no-keys.sh:17-19`.
Inside `$S` that path is `$S/docs/specs/009-cross-vm-settlement.md`; if the file is absent,
`ac009.sh` **exits 2 with `manifest not found: <path>`** and the selftest scores the phase a
**harness failure**, never a detection. Round 1's inventory omitted it, so **every** clean-copy
control would have failed before any patch was applied — and an implementation that skipped
the control would have scored all mutants as detected for the wrong reason.

**`xvm.base.json` is written, not copied** — three reasons, and this is a requirement.
(i) Copying the repository's file would carry the repository's `{B}`, `{P}` and sibling-gate
set into a sandbox whose contents the selftest itself chose. (ii) `ac009.sh` **refuses to run
without it** (§7.3), so it must exist in every sandbox. (iii) **The selftest never writes the
repository's `xvm.base.json`**, under any circumstance: that file is written once, at 009's
base commit, and a re-measure performed by the party being checked is not a measurement
(`003` §1.5.1 rule 1).

mutates the **copy**, runs the **copied** scripts, and finishes with `rm -rf "$S"`. **No
file under the repository is written at any point**, which is the founder's 2026-09-04
ruling on `008` OQ-5 honoured by construction rather than by a `trap`. This requires one
property of every script 009 adds, and it is a requirement, not an observation:

> **Location rule.** Every script under `zk-verdict/scripts/` that 009 adds derives its
> targets from its own location (`here=$(cd "$(dirname "$0")" && pwd)` and `root` relative
> to it) **and from nothing else**: no target argument, no environment override, no
> absolute path, no `git rev-parse`. This is already how `scripts/no-keys.sh:17-19`
> behaves and 009 must not regress it.

The sandbox must **fail loudly** if `lib/forge-std/src/Test.sol` is absent. It must never
run `forge install`, never `git clone`, and never write through the `lib` symlink.

### 7.1 The manifest (parsed by `zk-verdict/scripts/ac009.sh` from this file)

**Six columns, always six, `-` where a column does not apply to that kind:**
`AC` | `kind` ∈ {`forge`,`script`} | `selector` (forge only) | `command` (script only) |
`tests` (forge only, exact) | `evidence` (script only). Fields are separated by **two or more
spaces**, so a command or an evidence string may contain single spaces; `#` starts a comment.

**Four placeholders and no others**: `{witness}` (§7.2) and `{B}`, `{P}`, `{G}` (§7.3).
`ac009.sh` substitutes all four before comparing; everything else in an evidence line is
matched literally. `ac009.sh --check` fails if any row has a column count other than six, if a
`forge` row's `tests` is `< 1`, or if a `script` row's `evidence` is `-`.

```ac009-manifest
# AC     kind    selector  command                                    tests  evidence
AC-0     script  -         bash scripts/no-keys.sh                    -      the claim holds: no key can move a funded escrow.
AC-0b    script  -         bash zk-verdict/scripts/xvm-pins.sh        -      xvm-pins: 2/2 fixtures match the pin, vkeys distinct, bindings distinct, both Reproduced; witness={witness}
AC-1     forge   _AC01_    -                                          2      -
AC-2     forge   _AC02_    -                                          4      -
AC-3     forge   _AC03_    -                                          2      -
AC-4     forge   _AC04_    -                                          2      -
AC-5     forge   _AC05_    -                                          3      -
AC-6     forge   _AC06_    -                                          3      -
AC-7     script  -         bash zk-verdict/scripts/escrow-shape.sh    -      escrow-shape: 0 constructor, 0 immutable, 1 mapping, verdict members 3/3 read (5 accesses) and 4/4 unread, 9 assignments over 8 targets, function 2 (fund settleWithProof) other entry keywords 0 sum 2, 0 assembly 0 using, 1 contract 0 inherited; witness={witness}
AC-9     script  -         bash zk-verdict/scripts/xvm-no-skip.sh     -      no-skip: 0 fixture gates in the cross-VM file, 2/2 fixtures readable, {B}+16 tests listed and ran, 0 forge-reported skips; witness={witness}
AC-10    script  -         bash zk-verdict/scripts/ac009-selftest.sh  -      ac009-selftest: 15/15 mutants detected, 15/15 sandbox controls clean, mutants dir {P}+15; witness={witness}
AC-11    script  -         bash zk-verdict/scripts/xvm-docs.sh        -      docs: 4/4 replacements present, 4/4 retired sentences absent, 1/1 anchoring sentence adjacent, 1/1 authority sentence preserved; witness={witness}
AC-12    script  -         bash zk-verdict/scripts/both-green.sh      -      both-green: {G} sibling gate(s) discovered, {G}/{G} exit 0; witness={witness}
```

**Arithmetic `ac009.sh --check` recomputes, and a reviewer can recompute by hand:**

- **13** manifest rows, **13** acceptance criteria (`AC-0`, `AC-0b`, `AC-1`…`AC-7`, `AC-9`,
  `AC-10`, `AC-11`, `AC-12`). **There is no AC-8** — its clauses are folded into AC-7 (§7.6)
  — and **the number is not reused**.
- **6** `forge` rows; their `tests` column sums to **16**, and the per-selector counts are
  `_AC01_ 2`, `_AC02_ 4`, `_AC03_ 2`, `_AC04_ 2`, `_AC05_ 3`, `_AC06_ 3` (E-16, re-measured
  against the sixteen names §7 mandates).
- **7** `script` rows; **6** carry `{witness}` (AC-0 is the written exemption, §7.2).
- The whole `zk-verdict/contracts` suite after 009 is **`{B} + 16`**, where `{B}` is defined
  in §7.3. AC-9 asserts that number; **no total is spelled out anywhere in this document**,
  and `{B} + 16` is also the value §1.4 CS-2 requires a sibling's no-skip cell to carry.
- AC-10's mutants = **15** (`M-1`, `M-2`, `M-3`, `M-4a`, `M-4b`, `M-4c`, `M-5`, `M-6`, `M-7`,
  `M-8`, `M-9`, `M-10`, `M-11`, `M-12`, `M-13` — the three `M-4` variants are three separate
  patches), covering **12** of the 13 rows; the one row without a mutant (**AC-10**) carries a
  written exemption in §7.2 and a residual in §9 (L-10).
- The `zk-verdict/scripts/mutants/` directory holds `{P} + 15` `*.patch` files after 009,
  where `{P}` is its population at 009's base (§7.3). **AC-10 asserts that number**, which is
  009's half of §1.4 CS-1; the sibling's own step-0 literal is the other half and is updated
  in the same commit by copying the printed value.

`bash zk-verdict/scripts/ac009.sh --all` runs every row, asserts it ran **13**, then
applies the canary of §7.4 and requires **AC-7** to exit non-zero, and only then prints

```
ac009: 13/13 rows passed; canary M-4c detected by AC-7
```

`ac009.sh <AC>` runs one row. **AC-10 calls only the single-row form**, so `--all` does not
recurse; the canary likewise calls only the single-row form. **AC-12's script calls no form of
`ac009.sh` at all** — it runs sibling gates only — so there is no path by which `--all` reaches
itself through row AC-12 (§AC-12).

### 7.2 Witness recipes, and why a `script` row is not satisfied by `echo`

Every `script` evidence line ends with `witness=<16 lowercase hex>`, the first 8 bytes of a
`sha256` over that row's **witness set** — the exact repository bytes the row's claim is
about. `ac009.sh` **recomputes the witness itself** and requires equality; its recomputation
must not invoke the row's command. A stub can no longer print a constant: it must print a
**hardcoded digest**, which is stale the moment any witnessed byte moves — and AC-10's
mutants move witnessed bytes **at run time**, when no stub author can re-hardcode.

| row | witness set — `sha256` over the concatenation, in this order |
|---|---|
| AC-0 | **exempt from `witness=`, in writing.** Its evidence line is `AGENTS.md` §0's declared output and every consumer of that script reads it; 009 changes the bodies of checks 2 and 4 (§3.6) and must not restyle the output. What replaces the witness is **M-4a**: a sandbox mutant that restores a constructor + immutable into the copied `RecknZkEscrow.sol` and requires the **copied** `no-keys.sh` to exit non-zero. A stubbed `no-keys.sh` is the script the sandbox runs, so it exits 0 on the mutated copy, M-4a is a miss, and AC-10 fails. |
| AC-0b | the two fixture files whole, `LC_ALL=C` sorted by path, ‖ `zk-verdict/scripts/xvm.pinned` |
| AC-7 | `zk-verdict/contracts/src/RecknZkEscrow.sol` whole ‖ `zk-verdict/contracts/src/RecknVerdictVerifier.sol` whole |
| AC-9 | **every** `*.t.sol` under `zk-verdict/contracts/test/`, whole, `LC_ALL=C` sort order — **the glob, not a name list**, so the file 009 adds is inside the witness set on the commit that adds it |
| AC-10 | the **fifteen** `zk-verdict/scripts/mutants/M-*.patch` files, whole, `LC_ALL=C` sort order. **The glob is `M-*.patch`, not `*.patch`**: a sibling task's patches share the directory (§1.4 CS-1) and must not enter 009's witness set, or every sibling commit would move 009's evidence line |
| AC-11 | the four documents of AC-11 whole, in the order written there |
| AC-12 | **every discovered sibling gate file, whole, `LC_ALL=C` sorted by path — the glob, not a name list**, so a sibling that lands between 009's base and 009's commit is inside the witness set on the commit that lands it. If the discovery is empty the digest is `sha256` of the empty string, and the evidence line then reads `0 sibling gate(s) discovered` — a self-confessing constant, recorded as L-17 rather than hidden |

### 7.3 Substitution tokens

| token | definition |
|---|---|
| `{B}` | the **cardinality of the recorded test-id set** of `zk-verdict/contracts` at 009's **base commit** — recorded by the implementer in `zk-verdict/scripts/xvm.base.json` as a **sorted list of `<contract>:<test>` strings**, produced by `forge test --list --json` flattened and sorted. `ac009.sh` refuses to run if the file is missing, and AC-9 asserts every recorded id is still present on the current tree. **The set is the artefact; `{B}` is its size.** *(History: on this tree, 2026-09-05, that set has 12 members — E-3. `008` adds tests, so `{B}` will not be 12 at 009's base if `008` lands first. That is exactly why no total appears in this document.)* |
| `{P}` | the **population of `zk-verdict/scripts/mutants/*.patch` at 009's base commit** — the whole glob, including a sibling task's patches, recorded in `zk-verdict/scripts/xvm.base.json` as an integer alongside the id set. AC-10 asserts the directory holds `{P} + 15` after 009. **This is why no integer describing a sibling's mutant population appears in this document** (§1.4 rule 3): at 009's base that population is whatever it is, and `008` is not APPROVE'd, so its number is not a fact. *(History: at `40d1ce0` the directory does not exist, so `{P}` would be 0 today; 009's base is after `008` lands, so it will not be 0.)* |
| `{G}` | the **number of sibling gate files discovered** by AC-12's discovery rule (§AC-12) on the tree being checked. `ac009.sh` computes it by performing the same glob itself — **not** by invoking `both-green.sh` — so a stub that prints a constant is caught by the witness. Recorded at 009's base in `xvm.base.json` as `siblingGates` (a sorted list of basenames); AC-12 requires the discovered set to **include** every recorded name, so a sibling gate that is deleted rather than fixed fails rather than passes |
| `{witness}` | §7.2 |

`{B}`, `{P}`, `{G}` and `{witness}` are the **only four** substitution tokens. Anything else in
an evidence line is matched literally. `ac009.sh` **refuses to run** if
`zk-verdict/scripts/xvm.base.json` is absent or does not carry all three of `{B}`'s id set,
`{P}` and `siblingGates`.

### 7.4 The canary

After all 13 rows pass, `ac009.sh --all` itself applies one mutant — **M-4c**, appending an
unused `immutable` declaration to a sandbox copy of `RecknZkEscrow.sol` — and requires the
**single-row** invocation of AC-7 against the sandbox to exit non-zero. This moves one
detection off `ac009-selftest.sh` and onto the runner every other row already depends on.
It does not close L-10; it raises the bar (`008`'s construction, same reasoning).

---

### AC-0 — the central claim still holds

```sh
bash scripts/no-keys.sh                    # exit 0
bash zk-verdict/scripts/ac009.sh AC-0      # same command, via the manifest
```

009 changes what check 4 and check 2 *assert* (§3.6) and asserts a **strictly smaller** set of
accepted trees in both. It adds **no** external or public function to `RecknZkEscrow`: the
enumerated surface in `AGENTS.md` §0 and at `no-keys.sh:45`
(`fund settleWithProof refundAfterDeadline`) is byte-identical after 009. The **check count,
the arguments and the declared final line are unchanged**, so a sibling task adding check 5
collides with nothing (§1.4 CS-3). Because the meaning of two checks moves, `AGENTS.md` §0 and
`CLAUDE.md` record what changed — **and what `no-keys.sh` exiting 0 no longer means** (§3.6.3)
— **in the same commit** (§11), and the demo script says it out loud.

**Falsify (three, all run in the sandbox):**
1. restore a `constructor(RecknVerdictVerifier _v) { verifier = _v; }` and an `immutable` —
   check 4b exits non-zero (mutant **M-4a**);
2. append a `fallback()` that pays `deals[abi.decode(msg.data,(bytes32))]`'s tokens to
   `msg.sender` — **check 2 clause 2a** exits non-zero. Measured (E-13): before 009 this
   passes all four checks (mutant **M-11**);
3. add the line `string constant MASK = "//"; constructor() {}` — **check 4a** exits non-zero
   on the raw `"`, before the stripper can be defeated. Measured (E-15).

---

### AC-0b — the two fixtures 009 consumes are the two it was pinned against

`kind: script`, `command: bash zk-verdict/scripts/xvm-pins.sh`.

**Round 1 gave this row a manifest line, a witness set, a mutant (M-6), a file and a D-2
derivation — and no body and no `Falsify:` line**, which §7.0's Gate 2 requires of every AC.
An implementer would have had to invent the script's contract. It is written out here.

`zk-verdict/scripts/xvm.pinned` is a **two-line text file**, one line per fixture, each line:

```
<path relative to the repository root>  sha256=<64 hex>  vkey=0x<64 hex>  binding=0x<64 hex>  outcome=<integer>
```

`xvm-pins.sh` obeys the Location rule (§7.0), takes no argument, reads no environment
variable, and **does not invoke `forge`** — so it runs in the zero-build sandbox. It asserts,
in this order:

1. `xvm.pinned` has **exactly two** lines and each has **exactly five** fields; a different
   count is a failure, not a partial run. **The two paths are literals of this specification,
   in this order** (r2 finding 4, the half that is closable here):

   ```
   zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json
   zk-verdict/contracts/src/fixtures/svm-groth16-fixture.json
   ```

   Without them the first field is free-form and the headline claim — *one escrow settled by
   two guests* — rests on a **filename**: two copies of the EVM fixture under two names satisfy
   every other clause here except the vkey inequality, and a single renamed file satisfies even
   that if the second is a copy of the first with a stale vkey pin. The deeper half — binding
   each fixture to the guest that produced it, rather than to a path — is **not** closed by 009
   and is disclosed as **L-12**.
2. For each line: the file at that path exists; `shasum -a 256` of it equals `sha256=`; and
   the JSON's `.vkey`, `.deal_binding` and `.outcome` equal `vkey=`, `binding=` and
   `outcome=`. **The digest and the three parsed fields are four independent comparisons**, so
   a script that checks only the digest fails M-6's sibling case and a script that checks only
   the fields fails a whitespace-level edit.
3. Across the two lines: `vkey` differ, `binding` differ, **neither of the four values is
   `0x00…0`**, and both `outcome` are `0` (`REPRODUCED`). This is the same inequality AC-2
   test 4 asserts from inside `forge`; asserting it in both places is deliberate, because the
   two observers fail on different mutants (§7.2's fixture-swap note).
4. **On any failure, print both values for the failing clause**, labelled
   `pinned: <x>` / `computed: <y>`, so the re-pin is a copy of a printed value and never a
   hand-computed digest (D-2, and the shape §1.4's D-5 asks of siblings).
5. Print `xvm-pins: 2/2 fixtures match the pin, vkeys distinct, bindings distinct, both
   Reproduced; witness={witness}`.

**When a fixture is legitimately regenerated** — by a sibling task, by `ZK_FRESH=1`, by
anyone — this row goes red and the fix is a **one-line visible diff** in `xvm.pinned`, copied
from the printed `computed:`, in the commit that regenerated it. That is the entire mechanism
for *"the version underneath changed and nobody said so"* (D-2).

**Falsify:** flip one hex nibble in the copied `svm-groth16-fixture.json`'s `deal_binding` —
clause 2 fails on both the digest and the parsed field (mutant **M-6**). Point both pinned
lines at the same fixture path — clause 3 fails on `vkeys distinct`. Stub the script with
`echo "<the evidence line with today's witness>"`, then apply M-6 — `ac009.sh` recomputes the
witness over the mutated fixture bytes, the printed one is stale, and the row fails (NC-11).

---

### AC-1 — one escrow, two virtual machines, both settled

`kind: forge`, `selector: _AC01_`, `tests: 2`. File:
`zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol`.

1. `test_AC01_one_escrow_settles_an_evm_proof_and_an_svm_proof`
   - reads **both** fixtures with `vm.readFile` — a missing fixture fails the test rather
     than skipping it (AC-9);
   - asserts `evmVkey != svmVkey`, `evmBinding != svmBinding`,
     `keccak256(evmPublicValues) != keccak256(svmPublicValues)`,
     `keccak256(evmProof) != keccak256(svmProof)`, and both `.outcome == 0`;
   - deploys **one** `SP1Verifier`, **two** `RecknVerdictVerifier`s (`vE` with `evmVkey`,
     `vS` with `svmVkey`), and **exactly one** `RecknZkEscrow`;
   - funds deal `E` (`vE`, `address(vE).codehash`, `evmBinding`) and deal `S`
     (`vS`, `address(vS).codehash`, `svmBinding`) from the same buyer, same token;
   - settles **both** through that one escrow;
   - asserts `token.balanceOf(seller) == 2 * AMOUNT`, `token.balanceOf(address(escrow)) == 0`,
     and both deals' state is `Settled`.
2. `test_AC01_settling_the_svm_deal_leaves_every_other_deal_untouched`
   - one escrow, three funded deals (`E` against `vE`, `S` and `U` against `vS` with
     different `dealId`s and different bindings — `U`'s binding is
     `keccak256("unrelated")`, non-zero and matching no fixture);
   - settles **only** `S`;
   - asserts `E` and `U` are still `Funded`, the escrow still holds `2 * AMOUNT`, the seller
     holds exactly `AMOUNT`, and `U`'s stored `verifier` / `verifierCodeHash` /
     `dealBinding` are unchanged.

**Falsify:** an implementation that keeps a single `immutable` verifier in the escrow —
test 1 cannot construct the escrow with two verifiers, and if it constructs two escrows the
assertion that both settlements happened *through one address* fails. An implementation that
ignores `d.verifier` and dispatches to the first-funded deal's verifier fails test 1's second
settlement. (Mutants **M-4b**, **M-7**.)

---

### AC-2 — the two paths are really two paths

`kind: forge`, `selector: _AC02_`, `tests: 4`.

1. `test_AC02_an_evm_proof_cannot_settle_the_svm_deal` — deal funded against `vS` with
   `svmBinding`; submit the EVM fixture's `publicValues` + `proof`; `vm.expectRevert()`;
   then assert the deal is still `Funded` and the escrow balance is unchanged.
2. `test_AC02_an_svm_proof_cannot_settle_the_evm_deal` — mirror image.
3. `test_AC02_a_verifying_proof_with_the_wrong_binding_reverts_on_the_binding` — deal funded
   against `vS` (so the SVM proof **does** verify) but with `evmBinding` committed; submit
   the SVM fixture; `vm.expectRevert(RecknZkEscrow.BindingMismatch.selector)`. This is the
   test that separates barrier B-3 from barrier B-2 (§4.4): it proves both exist
   independently rather than one masking the other.
4. `test_AC02_the_two_fixtures_are_not_the_same_artifact` — asserts, from the two files:
   `vkey` differ and neither is `bytes32(0)`; `deal_binding` differ and neither is
   `bytes32(0)`; `keccak256(public_values)` differ; `keccak256(proof)` differ; both
   `outcome == 0`.

**Falsify — and this is the one this task will actually hit:** point the test's SVM fixture
constant at `reexec-groth16-fixture.json`. Tests 1–3 would then pass by accident (same
vkey, same binding, everything agrees); **test 4 fails on the first assertion.** (Mutant
**M-5**, which mutates the *test file* for exactly this reason.) Second falsifier: delete
the binding check in `settleWithProof` — test 3 stops reverting (mutant **M-1**).

---

### AC-3 — the settler cannot name the adjudicator; the deal already did

`kind: forge`, `selector: _AC03_`, `tests: 2`.

1. `test_AC03_settle_with_proof_has_no_adjudicator_parameter`
   *(renamed in round 2. Round 1's `test_AC03_settleWithProof_…` is rejected by §7.0's own
   naming regex — capital `W` and `P` against a `[a-z0-9_]+` tail — so AC-3's count gate could
   never reach 2/2 and AC-3 was red on day one, r1 finding 2. The regex is **not** widened;
   all sixteen names are re-checked in E-16 and gated in §7.8.)*
   - `assertEq(escrow.settleWithProof.selector, bytes4(keccak256("settleWithProof(bytes32,bytes,bytes)")))`
   - `assertEq(escrow.fund.selector, bytes4(keccak256("fund(bytes32,address,address,uint256,address,bytes32,bytes32)")))`
   - This is a compile-time-plus-runtime pin of both signatures: if a parameter is added or
     reordered, `.selector` changes and the assertion fails.
2. `test_AC03_the_escrow_dispatches_to_the_deal_s_verifier_and_to_nothing_else`
   - deploys the real `vE` **and** a sham `AlwaysReproduces` contract whose `verifyVerdict`
     is `view`, ignores its arguments, and returns a record with `outcome = REPRODUCED`,
     `traceHash = 0`, and `dealBinding = <a fixed value the test chooses>`;
   - **deal A** is funded against `vE` with that *same* fixed binding; submitting garbage
     `publicValues` and `proof` **reverts** (the real verifier is reached);
   - **deal B** is funded against the sham with the same binding; submitting the same
     garbage **settles to the seller**;
   - both assertions live in one test, so it proves the dispatch **follows `d.verifier` in
     both directions** — it is not merely that some call happened.

**R-8 note.** Neither test is a lexical check on a call site, so neither is exposed to
"can the name resolve to something else": test 2 observes the *effect* of dispatching to
two different addresses from two different deals in one escrow.

**Falsify:** make `fund` store `msg.sender` instead of the `verifier` parameter — test 2's
deal B stops settling (mutant **M-7**). Restore a single `immutable` verifier — deal B
reverts (mutant **M-4b**).

---

### AC-4 — the adjudication call cannot write state, and the control proves the test means it

`kind: forge`, `selector: _AC04_`, `tests: 2`.

1. `test_AC04_the_adjudication_call_cannot_write_state`
   - `Sink` (a counter) and `WritingVerifier` (a **non-`view`** `verifyVerdict` with the same
     selector, which bumps the sink and then returns a record matching the deal's binding
     with `outcome = REPRODUCED`);
   - fund a deal against `WritingVerifier` with its real `codehash` (so `fund` succeeds and
     the settle path is actually reached);
   - `vm.expectRevert()` on `settleWithProof`; then assert `sink.n() == 0`, the deal is
     still `Funded`, and the escrow still holds `AMOUNT`.
2. `test_AC04_the_same_verifier_writes_when_it_is_not_called_through_a_view_type`
   - a `NonViewCaller` helper in the test file calls the **same** `WritingVerifier` through a
     non-`view` interface; assert it **succeeds** and `sink.n() == 1`.

**Test 2 is the negative control and is not optional.** Without it, test 1 is satisfied by
any implementation that reverts for any reason at all, including a broken one. Measured
today as E-10/E-11 in a scratch project, so this is a reproduction of an observed pair, not
a prediction.

**Falsify:** type the dispatch through a non-`view` interface — test 1 stops reverting and
`sink.n()` becomes `1` (mutant **M-3**).

---

### AC-5 — funding pins the adjudicator's code by value

`kind: forge`, `selector: _AC05_`, `tests: 3`.

1. `test_AC05_fund_rejects_an_address_with_no_code` — two `expectRevert(NoVerifierCode.selector)`
   calls: a never-touched address (`codehash == 0`, E-8) and a `vm.deal`-funded EOA
   (`codehash == keccak256("")`, E-8). The second case is the one a naive `!= 0` check misses.
2. `test_AC05_fund_rejects_a_codehash_that_is_not_the_named_verifier_s` — pass `vE`'s address
   with `vS`'s codehash; `expectRevert(VerifierMismatch.selector)`; assert nothing was
   pulled from the buyer.
3. `test_AC05_fund_still_rejects_a_zero_binding` — regression pin on today's `ZeroBinding`
   guard, which is also what keeps the predicate guest (whose committed binding is zero) out
   of the settlement path.

**Falsify:** delete the `verifier.codehash != verifierCodeHash` comparison — test 2 stops
reverting (mutant **M-2**). Weaken `NoVerifierCode` to `== bytes32(0)` only — test 1's second
case stops reverting.

---

### AC-6 — money is conserved and settlement happens once

`kind: forge`, `selector: _AC06_`, `tests: 3`.

1. `test_AC06_the_svm_deal_cannot_be_settled_twice` — settle deal `S` with the SVM fixture,
   then submit the **same** `publicValues` + `proof` again;
   `expectRevert(RecknZkEscrow.BadState.selector)`; assert the seller's balance is exactly
   `AMOUNT` and the escrow holds `0`.
2. `test_AC06_a_failed_verdict_on_an_svm_shaped_deal_refunds_the_buyer` — uses a
   `MockVerdictVerifier` (a real contract, so `fund` accepts its codehash) that returns the
   deal's binding with `outcome = FAILED`; assert the **buyer** is made whole and the seller
   holds `0`. *(This test uses a mock and therefore says nothing about Solana; it says that
   the `Failed` branch of the widened contract still refunds. §7.7 repeats this boundary.)*
3. `test_AC06_no_token_is_created_or_destroyed_across_both_settlements` — records
   `totalSupply()` and the three balances before, funds `E` and `S`, settles both, and
   asserts `totalSupply()` unchanged and
   `balanceOf(buyer) + balanceOf(seller) + balanceOf(escrow)` unchanged at every step.

**Falsify:** pay `d.seller` unconditionally, dropping the `v.outcome` branch — test 2 fails
(mutant **M-8**). Remove the `d.state != State.Funded` guard — test 1 fails.

---

### AC-7 — the escrow's shape is closed

`kind: script`, `command: bash zk-verdict/scripts/escrow-shape.sh`.

Region: `zk-verdict/contracts/src/RecknZkEscrow.sol`, from the `contract RecknZkEscrow` line
onward, comments stripped with the idiom `no-keys.sh:29-30` already uses. This script obeys
the Location rule (§7.0), reads no environment variable, takes no argument, **and does not
invoke `forge`** — so `ac009-selftest.sh` can run it against a sandbox copy with no build.

**Nine clauses.** Every count below is a **literal of this specification, measured against
§3.3 and transcribed here**, not a value the implementer generates from the file — and round 2
re-measured every one of them, because **round 1's 7f transcribed a count that was false
against §3.3** (r1 finding 1, E-14).

> **The failure mode this section exists inside, named once.** When a pinned count disagrees
> with the file, the implementer's cheapest route to green is to **narrow the observer until it
> agrees**. Round 1 pinned `7 assignments over 6 targets` where §3.3 has nine over eight; the
> narrowing that produces 7 is *"do not scan local declarations"*, and that is precisely the
> R-11(iii) hole 7f exists to close — with `d` unscanned, `d = deals[otherId];` retargets the
> settled deal invisibly. **A clause whose numbers are wrong is worse than no clause**, because
> it converts a gate into an instruction to blind it. Round 2's numbers were produced by
> running the scan (E-14), not by reading the contract.

- **7a — the region is literal.** The raw file contains **zero** `/*` and **zero** `*/`, so
  the line-based stripper cannot be spanned; and after stripping, **zero** lines contain a
  `"` or `'`. *(Measured on today's file: 0, 0, 0. §3.3 introduces no string literal.)*
  **This is `no-keys.sh` check 4a after §3.6.1, and round 2 put it there as well as here**
  precisely because it is load-bearing for everything below it and the founder's pre-commit
  ritual runs `no-keys.sh` and nothing else. E-15 is the defeat it closes.
- **7b — no deployment-time configuration.** In the stripped region: **0** occurrences of
  the token `constructor` and **0** of the token `immutable`. This is `no-keys.sh` check 4b
  restated so that AC-7 and AC-0 fail together and for the same reason.
- **7c — one storage variable.** Exactly **1** occurrence of the token `mapping`, on a line
  that whitespace-normalises to exactly `mapping(bytes32 => Deal) public deals;`.
- **7d — the verdict record's read set is exact, in both directions.** The member names of
  `VerdictPublicValues` are **read at run time** from
  `zk-verdict/contracts/src/RecknVerdictVerifier.sol` (the `struct` block), never written in
  the script. Partition them: for the three names `dealBinding`, `outcome`, `traceHash` the
  region must contain the accesses `v.dealBinding` ×1, `v.outcome` ×3, `v.traceHash` ×1 —
  **five accesses in total** — **exactly, as a multiset**. *(On **today's**
  `RecknZkEscrow.sol`, at `40d1ce0`, those five are at `:103`, `:109`, `:111` and twice at
  `:116`. §3.3's file is longer and its line numbers differ; **the script never uses a line
  number** — the multiset is the criterion, and the numbers are printed here only so a reviewer
  can find them today. r1 finding 12.)* for **every other** member name `m` the region must contain
  **0** occurrences of `v.m`. Evidence prints `3/3 read (5 accesses) and K/K unread` with `K` computed
  from the parsed struct, so a member `008` adds is covered on the commit that adds it.
  *(This clause is INV-10's mechanization, and it is why 009 is correct with or without `008`.)*
- **7e — the dispatch site is singular.** Exactly **1** occurrence of the token
  `RecknVerdictVerifier` in the region, on a line that also contains `d.verifier`.
  **R-8 applies and is written here rather than implied:** this clause does not constrain
  what `d.verifier` resolves to at run time; **AC-3 test 2 does**, behaviourally, and the
  two clauses are a pair.
- **7f — assignment targets and sources are closed.** Statements are formed by splitting the
  stripped region at every `;`, `{` and `}` and collapsing runs of whitespace to one space. In
  each statement, the first `=` that is not part of `==`, `!=`, `<=`, `>=` or `=>` is an
  assignment; its **left-hand side is the normalised text before it, verbatim, declarators
  included**, and its right-hand side is the normalised text after it.

  Over §3.3, the multiset of left-hand sides is exactly these **eight**, and the total number
  of assignments is exactly **9**:

  | # | left-hand side, verbatim | times | right-hand side |
  |---|---|---|---|
  | 1 | `uint8 public constant REPRODUCED` | 1 | not pinned lexically — see below |
  | 2 | `uint8 public constant FAILED` | 1 | not pinned lexically |
  | 3 | `bytes32 public constant EMPTY_CODEHASH` | 1 | not pinned lexically |
  | 4 | `deals[dealId]` | 1 | not pinned lexically |
  | 5 | `Deal storage d` | 1 | **pinned: `deals[dealId]`** |
  | 6 | `VerdictPublicValues memory v` | 1 | **pinned: `RecknVerdictVerifier(d.verifier).verifyVerdict(publicValues, proofBytes)`** |
  | 7 | `d.state` | 1 | not pinned lexically |
  | 8 | `to` | **2** | **pinned: `d.seller` then `d.buyer`, in that order** |

  **Why the left-hand sides carry their declarators, which is new in round 2 and is the part
  that catches a real money bug.** `Deal storage d` and `Deal memory d` have the same variable
  name and different semantics: with `memory`, `d.state = State.Settled;` writes to a copy, the
  stored deal stays `Funded`, and **the same proof settles it again, and again**. Pinning the
  bare name `d` would accept it. Pinning `Deal storage d` verbatim rejects it, and it is
  mutant **M-12**.

  **R-11(iii), applied honestly.** An LHS-only pin is not a pin, so four of the nine right-hand
  sides are pinned above. The other five are **not** pinned lexically, and each is pinned
  behaviourally instead — stated here rather than left to the reader:
  `REPRODUCED` / `FAILED` swapped is caught by **AC-6 test 2** (a `Failed` verdict must refund
  the buyer) and **AC-1 test 1** (a `Reproduced` verdict must pay the seller);
  `EMPTY_CODEHASH` altered is caught by **AC-5 test 1's second case** (a `vm.deal`-funded EOA
  must be rejected, E-8); the `Deal({…})` literal with two fields transposed is caught by
  **AC-6 test 2** (the buyer, not the seller, must be made whole) and **AC-1 test 1** (exact
  balances). Where a lexical pin and a behavioural test both exist, both are named; where only
  one exists, that is said.

  *What 7f closes:* a new state variable written from anywhere, a rewrite of any deal field
  after `fund`, a payout to a third address, a swap of the two payout branches, a retarget of
  the settled deal (`d = deals[otherId]`), a redirect of the adjudication call, and a
  storage-to-memory demotion of the deal handle.

  **The scan, so no implementer has to infer it** (this is E-14 verbatim):

  ```sh
  python3 - <<'PY'
  import re
  b = open('zk-verdict/contracts/src/RecknZkEscrow.sol').read()
  b = b[b.index('contract RecknZkEscrow'):]
  b = '\n'.join(re.sub(r'/\*.*\*/','',re.sub(r'//.*','',l)) for l in b.split('\n'))
  t = re.sub(r'\s+',' ',b); out=[]; cur=''
  for ch in t:
      cur += ch
      if ch in ';{}': out.append(cur.strip()); cur=''
  n=0
  for st in out:
      i=0
      while i < len(st):
          if st[i]=='=':
              p = st[i-1] if i else 'X'; q = st[i+1] if i+1 < len(st) else 'X'
              if p in '=!<>' or q in ('=','>'): i+=2; continue
              n+=1; print(repr(st[:i].strip()), '<-', repr(st[i+1:].strip().rstrip(';').strip()))
              break
          i+=1
  print(n)     # must print 9, over 8 distinct left-hand sides
  PY
  ```

- **7h — the callable surface is closed, as a property over the grammar.** Let
  `K = {function, fallback, receive, modifier}` — the complete set of Solidity 0.8.x keywords
  that introduce a body of executable code reachable **after deployment** at contract-member
  level. `constructor` is deliberately not in `K`; it runs before deployment and is 7b's.
  Over the stripped region, counting tokens:

  - `function` occurs exactly **2** times, and the identifiers immediately following them are,
    in file order, exactly `fund` and `settleWithProof`;
  - every other element of `K` occurs exactly **0** times;
  - the **sum** over `K` is exactly **2** and is printed as its own number, so that a future
    grammar keyword added to `K` without updating the counts fails rather than passes.

  The script prints this clause as
  `function 2 (fund settleWithProof) other entry keywords 0 sum 2`, verbatim, which is the
  substring §7.1's evidence line matches. **The two names are printed, not just counted**: an
  implementation that finds two `function` declarations named `fund` and `drain` fails on the
  names, not on the count.

  **This is a closure, not a denylist (R-7).** The rule is not *"`fallback` and `receive` are
  forbidden"*; it is *"the only member declarations through which this contract can be entered
  after deployment are `function` declarations whose names are enumerated"*, and `K` is how
  that sentence is decided mechanically. `fallback` and `receive` are **witnesses in the
  corpus** (mutant **M-11**), not entries in a list.

  **What 7h exists because of.** Round 1's AC-7 was titled *"the escrow's shape is closed"* and
  did not close it. Measured (E-13): a `fallback()` that pays any funded deal's tokens to its
  caller passes all four `no-keys.sh` checks and every one of round 1's twelve criteria — 7b is
  0/0, 7c still sees one mapping, 7e still sees one `RecknVerdictVerifier` token, 7d's multiset
  is unchanged, and **7f is blind because a drain contains no `=` at all**. Anyone sends a
  32-byte dealId as raw calldata and takes the money. No proof, no binding, no state guard, no
  `msg.sender` gate. The same closure is now check 2 of `no-keys.sh` (§3.6.2), because AC-7
  does not run before a commit and the founder's ritual does.

- **7i — the lexical reading is well-defined.** Over the stripped region: **0** occurrences of
  the token `assembly`; and over the **whole stripped file** — not the region, r2 BLOCKER 1 —
  **0** of the token `using`. This is not a ban on two dangerous
  features; it is the **precondition that makes 7a–7h true statements**. Inline assembly is a
  second language inside the source over which none of 7a–7h's readings hold — an `assembly`
  block moves value with no `=`, no member call and no new declaration — and `using … for`
  makes member-call resolution non-local, which is exactly the operand question R-8 exists for.
  A region containing either is a region this script cannot read, and a script that cannot read
  its region must say so rather than pass.

- **7j — the region is the whole of the deployed code** (r2 BLOCKER 1). 7a–7i read from the
  `contract RecknZkEscrow` line onward, and **an inherited member is declared above it**. Two
  properties make that reading complete: the normalised text between the token
  `contract RecknZkEscrow` and the `{` opening its body is **empty** (no inheritance
  specifier), and the token `contract` occurs **exactly once** in the file (no second contract
  to inherit from). Without them the enumeration is closed over a region an attacker chooses
  the boundary of — r1 finding 4 (*"an enumeration is not a closure"*) reappearing one level up.
  Reproduced before the fix, compiled and run in `/tmp/sbx009`:
  `[PASS] test_inherited_fallback_drains_a_funded_deal` — any address sends a 32-byte dealId as
  raw calldata and takes the whole funded deal, with no proof, no binding, no state guard and
  no `msg.sender` gate, while `no-keys.sh`'s four checks and all nine of round 2's AC-7 clauses
  printed green and the evidence line matched the manifest byte for byte. The same two
  properties are check 2 clause 2c (§3.6.2), because AC-7 does not run before a commit and the
  founder's ritual does.

- **7g — the residual, stated rather than implied, and larger than round 1 said.** Round 1
  wrote that 7f's only blind spot is *"a state variable that is declared and never assigned"*.
  **That was false in the direction that flatters 009**: 7f cannot see **any money-moving code
  that performs no assignment**, which is how the `fallback` drain of E-13 passed. What closes
  that is 7h (no such code can be *entered*) and 7i (no such code can be *hidden inside* one of
  the two entry points as assembly). What remains after 7f, 7h and 7i:
  - a state variable **declared and never assigned** — unreachable in every transition of §5.2;
    7c would catch a second *mapping*, a never-written scalar survives;
  - a **statement inside** `fund` or `settleWithProof` that moves value through a member call
    this document does not enumerate. 7f pins every assignment and 7e pins the dispatch site,
    but a bare `IERC20Min(x).transfer(y, z);` statement assigns nothing. It is caught
    behaviourally by AC-6 test 3 (`totalSupply` and the three balances are conserved **at every
    step**) and AC-1 test 2 (settling one deal leaves every other deal's balance untouched),
    and lexically by nothing.

  Recorded in §9 as **L-11** and **L-16**.

**Falsify:** append `RecknVerdictVerifier public immutable fallbackVerifier;` and a
constructor that sets it — 7b fails (mutants **M-4b**, **M-4c**). Pay `d.seller`
unconditionally — 7f's assignment count goes from 9 to 8 and the `to` multiset from 2 to 1
(mutant **M-8**). Read `v.post` anywhere — 7d's unread count fails. Append the draining
`fallback()` of E-13 — **7h** fails on `fallback 1` while every other clause stays green
(mutant **M-11**). Change `Deal storage d` to `Deal memory d` — **7f**'s LHS multiset fails,
and AC-6 test 1 fails too because the deal is now settleable twice (mutant **M-12**).

---

### AC-9 — no test in this suite can pass by not running

`kind: script`, `command: bash zk-verdict/scripts/xvm-no-skip.sh`.

- **0** occurrences of the token `vm.exists` and **0** *bare* `return;` statements in
  `zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol`. Both fixtures are read with
  `vm.readFile`, whose failure is a **test failure**, not a skip. There is no gate to fire.
  *(A `return expr;` inside a helper contract is not a bare `return;` and is not matched.)*
- both fixture files exist and parse as JSON with non-empty `.vkey`, `.deal_binding`,
  `.public_values`, `.proof`, and an integer `.outcome`;
- `forge test --list --json` over the whole `zk-verdict/contracts` project lists exactly
  **`{B} + 16`** tests, `forge test --json` runs exactly that many, **0** reported skipped, all
  `Success`;
  > **What `0 forge-reported skips` does and does not say** (r1 finding 15). `forge` reports a
  > test that hits an early `return;` fixture gate as **`Success`**, not as `Skipped`, so this
  > clause cannot see such a gate anywhere in the directory. Seven exist today
  > (`RecknReexecVerdict.t.sol` ×2, `RecknSvmVerdict.t.sol` ×2,
  > `RecknVerdictVerifierFixture.t.sol` ×2, `RecknZkEscrow.t.sol` ×1). **009 asserts the absence
  > of gates only in its own file**, which is the first clause above and which is decidable
  > lexically; asserting it directory-wide is a sibling task's criterion and 009 will not
  > depend on that task landing (§1.4 rule 3). The evidence line therefore says
  > `0 forge-reported skips` and not `0 skipped`, and **L-15** records the gap.
- every id recorded in `zk-verdict/scripts/xvm.base.json` is still present in the listing.
  *(A base id that vanished means 009 deleted or renamed a pre-existing test, which is not
  in scope and must fail here rather than be absorbed into a total.)*

**Note on scope overlap:** `008`'s own no-skip criterion, if it lands first, asserts a
different number over a different base. The two do not conflict — `{B}` is measured at 009's
base, whatever that is.

**Falsify:** re-insert `if (!vm.exists(FIXTURE)) return;` at the top of the first cross-VM
test — the first clause fails and the listed/ran counts diverge (mutant **M-9**).

---

### AC-10 — the gate detects a wrong implementation

`kind: script`, `command: bash zk-verdict/scripts/ac009-selftest.sh`.

For each of the fifteen mutants: reconstruct the sandbox (§7.0), assert the **clean** copy passes
the target rows (the control), apply the patch to the **copy**, assert every target row exits
**non-zero**, then `rm -rf "$S"`. Print one line per mutant with elapsed time, then the
evidence line. Order is: control, then mutation, then restore-by-deletion — never the reverse.

**Step 0, before any phase:** assert
`ls zk-verdict/scripts/mutants/M-*.patch | wc -l` == **15** and
`ls zk-verdict/scripts/mutants/*.patch | wc -l` == **`{P} + 15`**. The first is 009's own
population guard (a deleted `M-` patch fails AC-10); the second is 009's half of §1.4 CS-1 and
is the number a sibling's own step 0 must also be updated to, by copying rather than counting.

| id | mutation, applied to the sandbox copy | target rows |
|---|---|---|
| M-1 | delete the `BindingMismatch` guard in `settleWithProof` | AC-2 |
| M-2 | delete the `verifier.codehash != verifierCodeHash` guard in `fund` | AC-5 |
| M-3 | declare a non-`view` interface in the escrow file and dispatch through it | AC-4 |
| M-4a | restore a `constructor` + `immutable verifier` (dispatch unchanged) | **AC-0** |
| M-4b | M-4a **and** dispatch to the immutable instead of `d.verifier` | AC-1, AC-3, AC-7 |
| M-4c | append one unused `immutable` declaration, nothing else (**the §7.4 canary**) | AC-7 |
| M-5 | point the cross-VM test's SVM fixture constant at the EVM fixture path | AC-2 |
| M-6 | flip one hex nibble in the copied `svm-groth16-fixture.json`'s `deal_binding` | AC-0b |
| M-7 | `fund` stores `msg.sender` as the deal's verifier instead of the parameter | AC-1, AC-3 |
| M-8 | pay `d.seller` unconditionally (drop the `v.outcome` branch) | AC-6, AC-7 |
| M-9 | re-insert an early-return fixture gate in the cross-VM test | AC-9 |
| M-10 | restore one stale sentence in the copied `zk-verdict/README.md` settlement section | AC-11 |
| **M-11** | append the draining `fallback()` of E-13 to the copied `RecknZkEscrow.sol` — it pays `deals[abi.decode(msg.data,(bytes32))]`'s tokens to `msg.sender`, contains no `=`, and compiles | **AC-0** (check 2 clause 2a), **AC-7** (7h) |
| **M-12** | change `Deal storage d` to `Deal memory d` in `settleWithProof` — compiles; `d.state = State.Settled` writes to a copy, so the deal stays `Funded` and the same proof settles it again | **AC-6** (test 1: the second submission stops reverting `BadState` and the seller is paid twice), **AC-7** (7f's LHS multiset) |
| **M-13** | drop an executable file `ac000.sh` whose body is `exit 1` into the sandbox's `zk-verdict/scripts/` — a sibling gate that is red | **AC-12** |

*(Fifteen patch files; `M-4a` / `M-4b` / `M-4c` are three separate patches and are counted as
three of the fifteen. Rows covered: AC-0, AC-0b, AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7,
AC-9, AC-11, AC-12 = **12 of 13**.)*

**M-13's sandbox is the restricted one, and the reason is cost, not convenience.** AC-12
discovers and runs **every** sibling gate it finds; a sandbox that copied a sibling's full gate
would run that sibling's whole suite — cargo tests included — inside every AC-10 phase. So for
M-13 the selftest builds `$S/zk-verdict/scripts/` with 009's scripts **only**, writes
`$S/zk-verdict/scripts/xvm.base.json` with `siblingGates: []`, and then:

- **control** — discovery finds 0 siblings, AC-12 exits 0 and prints
  `0 sibling gate(s) discovered`;
- **mutated** — discovery finds `ac000.sh`, runs it, it exits 1, **AC-12 exits non-zero**.

That pair is what proves AC-12 actually *runs* what it discovers rather than merely counting
it, and it works whether or not any sibling task has landed — which is the whole reason AC-12
names no sibling.

**AC-10's own row has no mutant.** A mutant on the selftest would be evaluated by the
selftest. §7.4's canary moves one detection onto `ac009.sh --all`, a different script every
other row depends on; the rest is the implementation review opening the script and running
it, which is a person and not a mechanism. **L-10** in §9 says so.

**Falsify:** replace `ac009-selftest.sh`'s loop so it applies only the first two patches —
the count goes to `2/15` and the evidence line does not match. (What this does **not**
falsify is a wholesale stub of the same script; that is L-10.)

---

### AC-11 — the documents moved in the same commit

`kind: script`, `command: bash zk-verdict/scripts/xvm-docs.sh`. Documents: `README.md`,
`zk-verdict/README.md`, `AGENTS.md`, `CLAUDE.md`.

- **4/4 replacements present** — §11(1)…§11(4).
- **4/4 retired sentences absent** — the four sentences §11 retires, matched as text. The
  fourth is new in round 2 and is a **negative on 009's own prose**: over `CLAUDE.md` and
  `zk-verdict/README.md`, **zero** occurrences of the strings `defence in depth` and
  `defense in depth`. Round 1's §4.4 called SP1 verification exactly that, and §11(4) ships
  §4.4's conclusion into the file that states the central claim (r1 finding 5). A text fix in
  §4.4 with nothing enforcing it at the shipping surface is how the sentence would have
  travelled anyway.
- **1/1 authority sentence preserved** — `CLAUDE.md` still contains, verbatim,
  `決済権限は「proof が検証される」ことから来る`. This is the sentence B-2 *is*, it is already in
  the file (`CLAUDE.md:17`), and 009's edit to that file must not remove or weaken it. A
  **preservation**, not a replacement, and it is counted separately for that reason.
- **1/1 anchoring sentence adjacent** — in `zk-verdict/README.md`, the paragraph that
  states cross-VM settlement and the paragraph that states the anchoring limit must be
  **within 25 lines of each other**, and the anchoring paragraph must not be the only place
  the limit appears. *(This is the mechanization of OQ-4's recommendation: the caveat travels
  with the claim rather than living in a footnote.)*

**Falsify:** ship the cross-VM paragraph without the anchoring paragraph — the anchoring
clause fails (mutant **M-10** exercises the mirror case). Write *"SP1 verification is defence
in depth"* into `CLAUDE.md` — the retired-sentence clause fails. Delete
`決済権限は「proof が検証される」ことから来る` from `CLAUDE.md` — the preservation clause fails.

---

### AC-12 — 009 is not green in a tree where a sibling gate is red

`kind: script`, `command: bash zk-verdict/scripts/both-green.sh`.

**Why this row exists.** The 9/9 checkpoint requires `008` and `009` **green at the same
time** (`AGENTS.md` §7). Every other criterion in this document is satisfiable in a tree where
a sibling task's gate is red — indeed round 1 *made* one red, and argued in §10 that it had
not (r1 finding 3). Confirming each gate green in turn, on different trees, does not satisfy
the checkpoint's word *simultaneously*. AC-12 is the only thing here that tests it.

**The discovery rule — a closure, not a name.** AC-12 does **not** know that `008` exists.
`both-green.sh` derives `here=$(cd "$(dirname "$0")" && pwd)` (§7.0's Location rule) and takes
as its **sibling gate set** every file in `$here` whose basename matches
`^ac[0-9]{3}\.sh$` **except `ac009.sh`**. That is the naming convention this repository's
dispatchers already follow, and it is a closure: a task numbered `010` is discovered on the
commit that adds it, with no edit here. If a sibling task ships its dispatcher under a name
that does not match, **that is a fact AC-12 cannot see**, and it is L-17.

Then, in this order:

1. Read `zk-verdict/scripts/xvm.base.json`'s `siblingGates` (a sorted list of basenames,
   measured at 009's base commit). **Every recorded name must be in the discovered set.** A
   sibling gate deleted rather than fixed fails here rather than passing quietly.
2. For each discovered gate `G`, in `LC_ALL=C` sorted order: run `bash "$here/$G" --all` from
   `$root` (`$here/../..`, location-derived, **not** `git rev-parse`), and **require exit
   status 0**. On failure,
   print `sibling <G> exited <N>` and that gate's last 20 lines of output, then exit non-zero.
   `both-green.sh` **never modifies a sibling gate and never passes it an argument other than
   `--all`.**
3. Print
   `both-green: {G} sibling gate(s) discovered, {G}/{G} exit 0; witness={witness}`,
   where the witness is `sha256` over the discovered gate **files, whole**, `LC_ALL=C` sorted
   by path (§7.2).

**`both-green.sh` calls no form of `ac009.sh`.** It runs sibling gates and nothing else, so
`ac009.sh --all` → row AC-12 → sibling gates terminates in one level and cannot reach itself.
If a future sibling adopts the same closure and discovers `ac009.sh`, the recursion is
**mutual and unbounded**, and the guard against it is that the sibling would be the one to add
it — so it is written here as a constraint on whoever does: **a gate that discovers siblings
must not itself be discovered by a gate it runs.** L-17.

**What AC-12 does *not* fix.** It does not repair a sibling's literal. §1.4 says who performs
each update and by what protocol; AC-12 is the thing that makes forgetting one **loud, at the
commit, in 009's own gate**, rather than silent until 9/9.

**Falsify:** drop an `ac000.sh` containing `exit 1` next to `both-green.sh` — AC-12 exits
non-zero (mutant **M-13**, with its clean control). Replace `both-green.sh` with
`echo "<the evidence line with today's witness>"`, then apply M-13 — the recomputed witness has
moved (the discovered set gained a file) and the printed one has not, so AC-12 still fails.

---

### 7.5 What 009 does **not** put in an AC, and why

- **That a Solana transaction really happened.** No AC asserts it, because nothing in this
  repository can (§9, L-1).
- **That the SVM predicate rejects a no-op.** That is the guest's property and it is
  exercised by `cargo run --bin svm -- --execute --amount 500000` today. 009 runs no Rust
  (N-2) and claims nothing about it (N-12).
- **That the committed fixtures are the current guests'.** That is `008`'s criterion over
  `008`'s ELF builds. 009 asserts only that the fixtures **it consumes** are the ones it
  was pinned against (AC-0b) — a weaker and different claim, and §9 L-12 says so.
- **That T-7 (§5.2) ever fires.** Round 1 said *"its precondition cannot be produced on the
  target chains"*; §5.3 now says why that was wrong. The reason there is still no AC is
  different and is a measurement, not an argument: r1 measured that in `forge 1.7.1` a contract
  created and `selfdestruct`ed inside one test function keeps its codehash and its
  `code.length`, under `evm_version` `osaka` **and** `shanghai`. **A test written for this
  would pass for the wrong reason**, which is what `AGENTS.md` §5 forbids. The consequence is
  disclosed as **L-14** instead.

### 7.6 What round 1 folded, so the size change is visible in one place

`AC-8` was going to be a second script running `forge inspect` (`storageLayout`, `abi`,
`methodIdentifiers`). It is folded: `methodIdentifiers` is pinned behaviourally and more
strongly by AC-3 test 1 (`.selector` equality), the absence of a `constructor` ABI entry is
7b restated, and `storageLayout` having one entry is already true today (E-5) and is pinned
lexically by 7c. Keeping it would have added a script that **needs a built project** and
therefore cannot run in the zero-build sandbox, forcing either a mutant exemption or an
in-place mutation of `RecknZkEscrow.sol` — the thing the founder ruled against on
2026-09-04. **The number 8 is not reused.**

### 7.7 Boundary the implementation report must restate

All sixteen tests, partitioned — round 1 wrote *"two"* and then enumerated four (r1
finding 11):

| group | count | tests | what they say about Solana |
|---|---|---|---|
| **mock or sham verifier** | **4** | AC-3 test 2 (`AlwaysReproduces`), AC-4 test 1 and test 2 (`WritingVerifier`), AC-6 test 2 (`MockVerdictVerifier`) | **nothing.** They are about the escrow's own dispatch, its `STATICCALL` typing and its `Failed` branch |
| **carry the cross-VM claim** | **8** | AC-1 tests 1–2, AC-2 tests 1–4, AC-6 tests 1 and 3 | these consume the real `svm-groth16-fixture.json` through SP1's real `SP1Verifier`. Bounded by L-1: *"settled by a proof about a Solana-shaped state the deal named"*, not *"about Solana"* |
| **neither** | **4** | AC-3 test 1 (`.selector` equality), AC-5 tests 1–3 (`fund`'s guards) | ABI and guard pins; no proof is submitted in any of them |

4 + 8 + 4 = 16, which is the manifest's `tests` sum (§7.1). **The implementation report must
reproduce this partition**, not a sentence saying some tests are mocks.

### 7.8 The naming gate, applied to this document's own names

`ac009.sh --check` additionally applies §7.0's regex `^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$` to
**every test name this specification mandates**, and fails if any does not match or if the
per-selector counts do not equal the manifest's `tests` column.

**The names are read from the fenced block below and from nowhere else** (r2 BLOCKER 2).
Round 2 defined the extraction as *"the backtick-quoted tokens beginning `test_AC` in §7"*, and
**that rule does not survive contact with this document**: applied mechanically it returns
seventeen tokens, not sixteen — §7.8's own prose contains the bare token `test_AC`, which fails
the regex — so `ac009.sh --check` fails on every run and **no row can execute**. The gate built
to stop round 1's contradiction reproduced the same contradiction one level up. A fenced block
is the same construction §7.1 already uses for the manifest, and it cannot be widened by prose:

```ac009-testnames
test_AC01_one_escrow_settles_an_evm_proof_and_an_svm_proof
test_AC01_settling_the_svm_deal_leaves_every_other_deal_untouched
test_AC02_an_evm_proof_cannot_settle_the_svm_deal
test_AC02_an_svm_proof_cannot_settle_the_evm_deal
test_AC02_a_verifying_proof_with_the_wrong_binding_reverts_on_the_binding
test_AC02_the_two_fixtures_are_not_the_same_artifact
test_AC03_settle_with_proof_has_no_adjudicator_parameter
test_AC03_the_escrow_dispatches_to_the_deal_s_verifier_and_to_nothing_else
test_AC04_the_adjudication_call_cannot_write_state
test_AC04_the_same_verifier_writes_when_it_is_not_called_through_a_view_type
test_AC05_fund_rejects_an_address_with_no_code
test_AC05_fund_rejects_a_codehash_that_is_not_the_named_verifier_s
test_AC05_fund_still_rejects_a_zero_binding
test_AC06_the_svm_deal_cannot_be_settled_twice
test_AC06_a_failed_verdict_on_an_svm_shaped_deal_refunds_the_buyer
test_AC06_no_token_is_created_or_destroyed_across_both_settlements
```

Sixteen names; per selector **AC-1 2, AC-2 4, AC-3 2, AC-4 2, AC-5 3, AC-6 3**, which is the
manifest's `tests` column. Measured against this block on 2026-09-05: all sixteen match the
regex, the counts agree, and the extraction returns exactly sixteen tokens.

This clause exists because round 1 mandated a name its own gate rejects, and **the gate could
not see it**: the regex was applied to what `forge` *found*, so the contradiction only surfaces
as `0 ≠ 2` at implementation time, indistinguishable from "the test was not written". E-16 is
the measurement for round 2's sixteen; §7.8 is what stops round 3 from needing it.

---

## 8. Test plan

### 8.1 Files

| path | status | contents |
|---|---|---|
| `zk-verdict/contracts/src/RecknZkEscrow.sol` | **modified** | §3.3 |
| `zk-verdict/contracts/src/RecknVerdictVerifier.sol` | **untouched** | N-1 |
| `zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol` | **new** | the 16 tests of AC-1…AC-6, plus `AlwaysReproduces`, `WritingVerifier`, `Sink`, `NonViewCaller`, `MockVerdictVerifier` as helper contracts in the same file |
| `zk-verdict/contracts/test/RecknZkEscrow.t.sol` | **modified** | two mechanical edits, both named so the diff is predictable (r1 finding 13): **(i)** the single `fund` call site (`:33`, in the helper) gains two arguments; **(ii)** the **three** `new RecknZkEscrow(verifier)` call sites — `:52`, `:70`, `:121`, re-verified at `40d1ce0` — become `new RecknZkEscrow()`. **No test is added, renamed or deleted** (AC-9's base-id clause) |
| `scripts/no-keys.sh` | **modified** | check 4's body (4a + 4b) and check 2's body (2a + 2b) — §3.6. **No check added, no check renumbered, final line unchanged** (§1.4 CS-3) |
| `zk-verdict/scripts/surfaces.pinned` | **re-pinned, not authored** | a sibling task's artefact. One line changes: `sha256(RecknZkEscrow.sol)`, copied from what `surfaces.sh` prints on failure, in the same commit that changes the contract (§1.3 row 1, §1.4 **CS-4**). If the sibling has not landed there is no file and this row is inert; the implementation report says which case held (r1 finding 14) |
| `zk-verdict/scripts/ac008-selftest.sh` | **modified — one integer** | §1.4 **CS-1**: the step-0 population literal over `zk-verdict/scripts/mutants/*.patch`, updated by copying the output of that script's own measuring expression on the committed tree. **This is a script, not a specification; `docs/specs/008-*.md` is not edited** (N-10). If the sibling has not landed, this row is inert |
| `zk-verdict/scripts/ac009.sh` | new | dispatcher; manifest parsed from §7.1 of this file |
| `zk-verdict/scripts/xvm-pins.sh` | new | AC-0b |
| `zk-verdict/scripts/xvm.pinned` | new | the two fixture digests + vkeys + bindings, one per line |
| `zk-verdict/scripts/xvm.base.json` | new | §7.3 |
| `zk-verdict/scripts/escrow-shape.sh` | new | AC-7 |
| `zk-verdict/scripts/xvm-no-skip.sh` | new | AC-9 |
| `zk-verdict/scripts/ac009-selftest.sh` | new | AC-10 |
| `zk-verdict/scripts/xvm-docs.sh` | new | AC-11 |
| `zk-verdict/scripts/both-green.sh` | new | AC-12 |
| `zk-verdict/scripts/mutants/M-*.patch` | new | **fifteen** patches, in the directory a sibling task also uses (§1.4 CS-1, OQ-7) |
| `README.md`, `zk-verdict/README.md`, `AGENTS.md`, `CLAUDE.md`, `STATUS.md` | modified | §11 |

**No Rust file appears in this table. No fixture is regenerated. No `.s.sol` is added.**

### 8.2 Positive path

`bash zk-verdict/scripts/ac009.sh --all` → `ac009: 13/13 rows passed; canary M-4c detected by
AC-7`, and `cd zk-verdict/contracts && forge test` → `{B} + 16` passed, 0 skipped. Because
AC-12 is one of the thirteen rows, that single command is also the assertion that every sibling
gate in the tree exits 0 — **the 9/9 checkpoint, in one command, on one tree**.

### 8.3 Negative controls — every one of these must be observed failing, not argued

| # | break this | must go red |
|---|---|---|
| NC-1 | delete `RecknCrossVmSettlement.t.sol` | AC-1…AC-6 (count gate, `0 ≠ N`), AC-9 |
| NC-2 | replace every body in that file with `assertTrue(true);` | AC-10 (every mutant becomes a miss) |
| NC-3 | point the SVM fixture constant at the EVM fixture | AC-2 test 4 — **the fixture-swap control** |
| NC-4 | restore a constructor + immutable to the escrow | AC-0 (check 4), AC-7 (7b) |
| NC-5 | type the dispatch through a non-`view` interface | AC-4 test 1 — and AC-4 test 2 must **still pass**, which is what proves test 1 was measuring the type and not an accident |
| NC-6 | delete the binding check | AC-2 test 3 |
| NC-7 | delete the codehash check in `fund` | AC-5 test 2 |
| NC-8 | store `msg.sender` as the deal's verifier | AC-1, AC-3 test 2 |
| NC-9 | flip a nibble in a fixture | AC-0b |
| NC-10 | stub `escrow-shape.sh` with `echo "<the evidence line with today's witness>"`, then apply M-4c | AC-7 (the recomputed witness has moved; the printed one has not) |
| NC-11 | stub `xvm-pins.sh` the same way, then apply M-6 | AC-0b, same mechanism |
| NC-12 | replace `ac009.sh`'s count gate with `true` | AC-1…AC-6 stop being decidable — **this is not detected by anything in 009** and is L-10 |
| NC-13 | append the draining `fallback()` of E-13 to the escrow | AC-0 (check 2 clause 2a), AC-7 (7h) — **and before 009, nothing at all**, which is why the row exists |
| NC-14 | change `Deal storage d` to `Deal memory d` | AC-6 test 1 (the deal settles twice and the seller is paid twice), AC-7 (7f) — two independent detections of one bug, one behavioural and one lexical |
| NC-15 | make any sibling gate in `zk-verdict/scripts/` exit non-zero | AC-12 — and therefore `ac009.sh --all`. **This is the negative control for the 9/9 checkpoint itself** |
| NC-16 | rename `test_AC03_settle_with_proof_…` back to round 1's `test_AC03_settleWithProof_…` | AC-3 (naming gate, then the count gate at `0 ≠ 2`), and `ac009.sh --check` via §7.8 — the second is the one that names the actual cause |

**NC-5, NC-12, NC-13 and NC-15 are the four that matter most.** NC-5 is the pair that makes
AC-4 mean something. NC-13 is the hole round 1 shipped: it must be observed going red, because
on round 1's spec it went green. NC-15 is the checkpoint. NC-12 is written into the table with
"not detected" rather than being left out of it (R-10(iii)).

### 8.4 Tests that will not be written

- A test that asserts `settleWithProof` "works" without asserting **who** was paid and **how
  much**. Every settlement assertion names a recipient and an exact balance.
- A test whose only assertion is that a revert happened. Every `expectRevert` in AC-2, AC-4,
  AC-5 and AC-6 is followed by an assertion about **state that did not change**.
- A fuzz over the settler address. `settleWithProof` is permissionless and `msg.sender` does
  not appear in it (INV-7); a fuzz that draws 256 callers and finds nothing is evidence of
  nothing. The structural fact is `no-keys.sh` check 3. *(This is `003`'s R-5 applied here.)*
- A test that "checks the SVM binding formula". 009 has no second implementation of it to
  compare against (§9 L-5, OQ-3), and a test that recomputes it from the same constants the
  guest used would be a test of nothing.

---

## 9. Honest limitations

Written here, not in a footnote, and reproduced next to the claim in `zk-verdict/README.md`
(AC-11's **anchoring-adjacency** clause).

- **L-1 (Solana anchoring — the big one).** Nothing in 009 establishes that the committed
  `bank_hash` was ever a real Solana cluster's bank hash. The SVM guest recomputes it from
  the committed account set, and `zk-verdict/README.md:215-218` already records that this is
  conclusive only over a **complete** account set and that the demo treats its committed set
  as the world. 009 does not narrow this by one word. **"Settled by a Solana proof" means
  "settled by a proof about a Solana-shaped state the deal named", not "about Solana".**
- **L-2 (EVM anchoring).** Symmetrically, the `state_root` ↔ block-header binding remains in
  the off-chain `reexec-evm::header` layer.
- **L-3.** Therefore *no bridge, no light client* is a statement about the **adjudication
  path** and not about anchoring — the exact form the 2026-09-04 application used, preserved.
- **L-4 (the seller's checklist grew).** INV-11. A seller must now read three values off the
  funded deal before working, not one. 009 adds no mechanism that checks them for the seller.
- **L-5 (one implementation of each binding).** The repository contains exactly one
  implementation of the SVM binding formula — the guest. So *"either party can independently
  compute the deal's terms"* is **not demonstrated** by 009, and the demo funds a deal by
  copying `.deal_binding` out of a fixture the prover produced. OQ-3.
- **L-6 (the SP1 verifier's code).** `verifierCodeHash` commits the `RecknVerdictVerifier`'s
  runtime code and therefore the *address* of the `ISP1Verifier` it uses (E-9). The **code**
  at that address is committed by nothing 009 adds. On-chain deployment checking is `003`'s.
- **L-7 (a buyer can name a sham — and the blast radius is not their own deal unless the
  token is exact).** The escrow guarantees the adjudicator is the one the buyer committed, not
  that it is honest. A buyer who commits a sham verifier loses their own money and nobody
  else's **provided the token debits exactly `amount` on `transferFrom`**. **The escrow does
  not check that** — N-5 keeps the discarded `transferFrom` return value and 009 adds no
  balance-delta check — **and one escrow instance pools several deals' balances** (AC-1 test 1
  and AC-6 test 3 both fund more than one deal against one escrow). So with a fee-on-transfer
  token: a victim funds 100 and the escrow receives 90 against a recorded claim of 100; an
  attacker funds 100 naming a ten-line `AlwaysReproduces` and settles their own deal for the
  full 100; the escrow is left holding 80 against the victim's recorded 100. A
  false-returning `transferFrom` is worse — the deal is booked with **nothing** pulled. AC-6's
  mock is an exact token and cannot see any of this.
  **What 009 changed here is the exposure, not the accounting**: before 009 the attacker had to
  produce a real Groth16 proof under the one deployed verifier; after 009 they deploy a sham
  and name it at `fund`. **The code fix is `003`'s** (N-5, ruled in `003` r1) and 009 does not
  take it. Round 1 shipped the sentence *"loses their own money and nobody else's"* unqualified
  into `zk-verdict/README.md` via AC-11, and it was untrue (r1 finding 6). A seller who works
  without reading the deal can still be paid nothing, which is the reason L-4 exists.
- **L-8 (T-7 is evidence of nothing *here*).** The codehash re-check in `settleWithProof`
  guards a transition 009 never produces and no AC asserts. It is fail-closed hygiene, not a
  demonstrated protection. Round 1 additionally claimed the transition *cannot* occur on the
  target chains; see **L-14**, which is that claim withdrawn.
- **L-14 (T-7 is reachable under EIP-6780, and firing it strands the money).** On a chain
  implementing EIP-6780, a factory can in **one transaction** create a killable verifier, call
  `fund` with its then-live codehash — every `fund` guard passes — and destroy it. Every later
  `settleWithProof` then reverts `VerifierMismatch`, and because 009 adds no timeout (N-3) the
  deal is **permanently unsettleable**: the seller who did the work gets nothing and the funds
  are stranded. 009 targets chains beyond mainnet (`AGENTS.md` §3 tasks 005, 006) and offers
  evidence about none of them. **009 neither demonstrates nor closes this**, and it writes no
  AC for it because `forge 1.7.1` does not reproduce the account deletion inside a test body
  (§7.5) — a test here would pass for the wrong reason. Round 1 wrote the opposite of this
  paragraph, in the register of an honest limitation, which is why it is spelled out.
- **L-9 (`extcodehash` corner).** `fund` rejects both `0` (no account) and `keccak256("")`
  (account with no code) — E-8. It does **not** and cannot distinguish a contract that is
  mid-construction; a contract calling `fund` from its own constructor would have
  `codehash == 0` and be rejected, which is the fail-closed direction.
- **L-10 (the gate's own regress).** Nothing in 009 detects a stubbed `ac009.sh` or a stubbed
  `ac009-selftest.sh`. §7.4's canary moves one detection onto `ac009.sh --all`; beyond that
  what stands is the implementation review opening those two scripts and running them, which
  is a person. NC-12 records this in the table rather than omitting it.
- **L-11 (7g, first half).** AC-7's assignment closure cannot see a state variable that is
  declared and never written. Such a variable changes no transition in §5.2. 7c catches a
  second *mapping*; a never-written scalar survives.
- **L-16 (7g, second half — what the entry-point closure does not reach).** 7h closes the set
  of ways the contract can be **entered**; 7i keeps the lexical reading well-defined inside it.
  What neither reaches is a **statement inside `fund` or `settleWithProof` that moves value
  through a member call and assigns nothing** — a bare `IERC20Min(x).transfer(y, z);`. 7f pins
  every assignment and 7e pins the dispatch site, and neither sees such a statement. It is
  caught **behaviourally** by AC-6 test 3 (`totalSupply` and the three balances conserved at
  every step) and AC-1 test 2 (settling one deal leaves every other deal untouched), and
  **lexically by nothing**. Round 1's §7g stated a residual far smaller than the real one, and
  the `fallback` drain of E-13 lived in the gap.
- **L-15 (`forge` does not report a fixture gate as a skip).** AC-9's `0 forge-reported skips`
  is not the statement *"no test in this directory can pass without running"*. `forge` reports
  an early-`return;` gate as `Success`; seven such gates exist today outside 009's file. 009
  asserts the absence of gates **only in its own file**, lexically, and will not depend on a
  sibling task landing to say more (§1.4 rule 3).
- **L-17 (what AC-12's closure cannot see).** AC-12 discovers sibling gates by the basename
  pattern `^ac[0-9]{3}\.sh$` in its own directory. A sibling that ships its dispatcher under
  another name, or in another directory, is **not discovered**, and AC-12 then prints a smaller
  `{G}` and passes. The `siblingGates` recorded at 009's base makes a *deleted* gate fail but
  cannot make an *unconventional* one appear. Two further residuals of the same row: if no
  sibling gate exists at all, the evidence line reads `0 sibling gate(s) discovered` and the
  witness is the digest of the empty string — the row is then a printed zero, which is a
  disclosure and not a check; and if a future sibling adopts the same discovery closure, the two
  gates recurse without bound, so **a gate that discovers siblings must not itself be
  discovered by a gate it runs**.
- **L-12 (fixture freshness).** AC-0b asserts the fixtures are the ones 009 was pinned
  against. It does **not** assert they are the current guests' — that is `008`'s criterion
  over `008`'s ELF builds, and 009 builds no ELF (N-2).
- **L-13 (tier).** Local, in-memory, one process. No chain of any kind was contacted. A green
  009 says nothing about testnet or mainnet.

---

## 10. Dependency on `008` — technical, and harness, stated in both directions

**`008` is not APPROVE'd. No literal of it — no tag string, no field order, no type, no
number — appears anywhere in this document.** 009 consumes four things from the tree and
derives each of them rather than restating it, so that if the version underneath 009 changes
silently, a gate goes red instead of a claim going quietly false.

| # | consumed | derivation | what fires if it moves |
|---|---|---|---|
| D-1 | the `VerdictPublicValues` struct | 009 **imports** it and never re-declares it. AC-7d parses the member names out of `RecknVerdictVerifier.sol` **at run time**. | a renamed/reordered member 009 reads → `forge build` fails → every `forge` row fails. A member added or re-typed that 009 does **not** read → AC-7d's `K/K unread` count changes → AC-7 fails until the evidence line is updated deliberately. |
| D-2 | the two guests' binding formulas and domain tags | 009 **never writes them**. `zk-verdict/scripts/xvm.pinned` records `sha256` of each fixture file plus its `.vkey` and `.deal_binding`, and `xvm-pins.sh` prints **both** the pinned and the computed value on failure. | any fixture regeneration — by `008`, by `ZK_FRESH=1`, by anyone — makes AC-0b fail. The fix is a **one-line visible diff** copied from the printed value, in the commit that regenerated it. **This is the entire mechanism for "the version changed and nobody said so."** |
| D-3 | the pre-existing test population | `{B}` (§7.3), recorded as a **sorted id set** at 009's base commit. No total appears in this document. | `008` landing between 009's base and 009's commit changes `{B}` → `ac009.sh` refuses to run until `xvm.base.json` is re-measured at the true base, and AC-9's base-id clause fails if a pre-existing test disappeared. |
| D-4 | `no-keys.sh`'s check count and output | 009 changes the **bodies** of checks 2 and 4 and neither their numbers, the script's arguments, nor its declared final line. AC-0's evidence is that final line, which is `AGENTS.md` §0's declared output. **Measured**: `surfaces.pinned` does not pin this file. | if `008` adds check 5 first, 009 is unaffected: 009 asserts a line, not a count. If `008` adds check 5 *second*, `008` is unaffected for the same reason. |
| **D-5** | a sibling gate's failure output | stated in §1.4: a gate asserting a count over a shared surface should print expected and observed on one line. Where it does not, §1.4 rule 2(b) runs that gate's own measuring expression instead. **009 requires no sibling to change.** | nothing fires; this is a format request, and its enforcement is the implementation report naming which branch was used per surface |
| **D-6** | the presence and exit status of every sibling gate | 009 **discovers** them (`^ac[0-9]{3}\.sh$`, minus its own) and requires each to exit 0 — AC-12. It names no sibling and reads no sibling's document. | a sibling gate that is red makes `ac009.sh --all` red. A sibling gate that is deleted rather than fixed fails the `siblingGates` clause. A sibling under an unconventional name is invisible — L-17 |

**On the technical axis, 009 is correct with or without `008`.** INV-10 is the reason: the
escrow reads no numeric member of the verdict record, so the widening `008` performs cannot
change any behaviour 009 specifies. r1 verified this independently — `008` re-types four
`VerdictPublicValues` members and **renames none**, so AC-7d's run-time parse of the struct
block is unaffected, and grep found no `008` digest, tag string, field order or width anywhere
in this document. If `008` fails to land, 009's only visible difference is that `{B}` and `{P}`
are smaller and the pinned fixture digests are the pre-`008` ones.

**On the harness axis, 009 is *not* independent, and round 1 said it was.** This is r1
finding 3 and it is the one finding that needed a new criterion rather than a corrected
sentence. Round 1's §10 asked *"if `008` lands first, is 009 unaffected?"* and never asked the
reverse. The reverse is where the breakage is: **009 writes into surfaces `008` counts.** The
inventory is §1.4 — the mutants directory's population (CS-1), the forge suite's total (CS-2),
`scripts/no-keys.sh` (CS-3) and `surfaces.pinned` (CS-4). Round 1's OQ-6 asserted that 009
*"touches no file `008` touches except `zk-verdict/contracts/test/RecknZkEscrow.t.sol`"*; that
one named file is genuinely shared, and **all three of the surfaces that actually break were
unnamed**.

| direction | does it break? | why |
|---|---|---|
| `008` lands first, then 009 | **no** for 009 | 009's globs are `M-*.patch` (not `NN-*.patch`), `{B}` and `{P}` are measured at 009's base whatever it is, AC-0's evidence is a line and not a check count (D-4), and INV-10 covers the struct |
| 009 lands first, or lands after, without §1.4 | **yes** for `008` | its mutant-population literal, its suite total and its `witness=` over the shared glob all move. **Round 1 would have shipped this**, and the checkpoint would have failed for a filename and an integer |
| 009 lands **with** §1.4 | no | the counting side is updated in the same commit, from printed values, and **AC-12 keeps 009 red until every sibling gate in the tree exits 0** |

**009 must still not be blocked on `008`'s approval** — AC-12 is a discovery over what is in
the tree, not a dependency on a document. See OQ-6, rewritten.

---

## 11. Documents that move in the same commit

1. **`zk-verdict/README.md`, "Settlement — the proof moves money"** — `fund`'s signature
   changes (5 → 7 parameters) and the paragraph that describes the binding gains the
   adjudicator terms. **Retire** the sentence that presents the escrow as bound to one
   verifier at construction. **Add** a short "Honest scope of cross-VM settlement" block
   carrying L-1, L-3, L-4, L-5, L-13 — placed **within 25 lines of** the cross-VM claim
   (AC-11).
   **The existing "Honest scope" blocks for the EVM guest and the SVM guest are not
   overwritten and not edited** (`AGENTS.md` §5).
2. **`README.md`, "Known gaps (not closed)"** — add the cross-VM anchoring gap (L-1/L-2/L-3)
   and the local-tier statement (L-13). **Do not remove** the `RecknZkEscrow has no timeout`
   entry; 009 does not close it (N-3).
3. **`AGENTS.md` §0** — record **three** things, not one: (a) check 4 now asserts *the region
   is literal* (4a) and *no constructor and no `immutable`* (4b); (b) **check 2 now closes the
   entry-point set** rather than enumerating what it finds, so `fallback` and `receive` cannot
   pass by not being matched (§3.6.2, founder ruling on OQ-A); (c) both are **tightenings**,
   with the argument of §3.6.3 — **and that `no-keys.sh` exiting 0 no longer means what it
   meant before 009**, because the escrow now dispatches into buyer-named code and the build
   condition does not check that. What makes that safe is INV-9 and §4.4's B-1/B-2/B-3, none of
   which `no-keys.sh` sees. The enumerated function surface is unchanged. `AGENTS.md` §3's 009
   row can then say the wire is closed.
4. **`CLAUDE.md`** — the "verified facts" block says the escrow is settled by real Groth16
   proofs; after 009 it must say **from two guests, through one escrow with no constructor**,
   and must carry L-1 in the same breath. Two things it **must not** say, and round 2 had it
   shipping the second of them (r2 BLOCKER 3):
   - not that the deal's committed verifier is what makes a payout **sound** — B-1 alone would
     settle on unverified bytes (r1 finding 5);
   - **not that "there is no path to a payout that skips proof verification"**, which is false
     after 009: the buyer names the verifier at `fund`, so a buyer who names a sham is paid out
     on garbage, and AC-3 test 2 requires that behaviour.

   The sentence that is true, and the one this clause ships: **the funder chooses the program;
   the proof, checked by that program, chooses the payout** (§4.4 B-2, INV-2). It must be
   accompanied by the seller-side capability 009 adds — a buyer can name a verifier that always
   returns `FAILED`, and no on-chain check distinguishes that from an honest `Failed` (INV-2,
   L-7).
5. **The four sentences retired, listed so `xvm-docs.sh` has a set to match and not a
   judgement to make**: (i) the `zk-verdict/README.md` sentence presenting the escrow as bound
   to one verifier at construction (§11(1)); (ii) the root `README.md` sentence describing
   settlement as EVM-only (§11(2)); (iii) the `AGENTS.md` §0 sentence describing check 4 as
   *"the constructor may bind only the verifier"* (§11(3)); (iv) **any occurrence of
   `defence in depth` / `defense in depth` in `CLAUDE.md` or `zk-verdict/README.md`** — round 1
   wrote it about SP1 verification and §11(4) would have shipped it (r1 finding 5).
   **Preserved, not replaced:** `CLAUDE.md`'s `決済権限は「proof が検証される」ことから来る`
   must survive 009's edit verbatim. That sentence is B-2.
6. **`STATUS.md`** — the review row, the 9/9 checkpoint state, and the `surfaces.pinned`
   re-pin if `008` landed first. *(`STATUS.md` is not in AC-11's document set: it is a log,
   and pinning log text is how the last three specs shipped stale numbers.)*
7. **`docs/ethonline-2026/PLAN.md` and `DISCLOSURE.md` are founder documents and are not
   edited** (`AGENTS.md` §8).
8. **A sibling task's counted literals move in this same commit** — §1.4's CS-1…CS-4, each
   with the party who performs it and the printed value it copies. This is a document
   obligation as much as a code one, and **AC-12 is what makes forgetting it loud**.

---

## 12. OPEN QUESTIONS — founder

- **OQ-1 — `no-keys.sh` check 4's tightening constrains `003`.** 009 replaces check 4 with
  *no constructor and no `immutable`* (§3.6). `003`'s current draft expects a
  constructor-set `refundDelay` — **and three further `003` sites move with it: check 8, the
  ROLE table's DEPLOYER and BUYER rows, G-33/G-37, and the five-part deployment check's read of
  `verifier()`. The inventory is at the end of §1.3 and this ruling should be made against it,
  not against the single `refundDelay` row round 1 showed.** *(`AGENTS.md` §7's ruling of
  2026-09-05 takes `003` off the 9/9 gate and says it is not to be restarted, so there is no
  live `003` draft to break — the cost is deferred, not paid now.)*
  **Recommendation: keep the tightening**; a deployer-chosen
  refund delay decides *when* a funded deal can be drained, which is the shape §0 exists to
  exclude, and a `constant` or a per-deal deadline says the same thing without a deployment
  parameter. **009 will not write `003`'s replacement.** If the founder rules the other way,
  009 leaves check 4 alone and AC-7's 7b becomes the only place the property is asserted —
  which is weaker, because it is not the founder's pre-commit command.
- **OQ-2 — the alternative vkey design.** The cleanest shape is one verifier contract that
  takes the vkey as a call argument, with the deal committing the vkey. 009 **rejects it as
  an agent decision** because it loosens the check `008` installs over
  `RecknVerdictVerifier.sol` and `AGENTS.md` §0's last line makes that a founder call. If the
  founder wants it, it is a small change to that file plus an extension of `008`'s check 5,
  and it removes the need for `verifierCodeHash`. **009's design does not depend on the
  answer**; this is an invitation, not a blocker.
- **OQ-3 — should either party be able to compute a deal's terms without the prover?**
  Today they cannot (L-5). Closing it means a host-side binding printer plus a differential
  criterion against the fixture — Rust work, which 009 excludes (N-2). **Recommendation: not
  in 009**, but it is the honest next step and it is the first thing a judge will ask after
  "who computed that hash?".
- **OQ-4 — how loudly must L-1 travel?** 009's answer is AC-11's **anchoring-adjacency**
  clause: the anchoring
  paragraph must sit within 25 lines of the cross-VM claim in `zk-verdict/README.md`.
  **Does the same rule apply to the 3-minute demo script and the submission text?** Those are
  `reckn-demo`'s and the founder's surfaces and 009 does not legislate them.
- **OQ-5 — `no-keys.sh` check 2 matches function *names*, not *signatures*.** Round 2 closed
  the larger half of this: check 2 now closes the **entry-point set**, so a `fallback` or a
  `receive` can no longer hide (§3.6.2, ruled). What remains is narrower and still real:
  `fund` goes from 5 to 7 parameters and the build condition does not see it, and a **same-named
  overload** would be listed once by `grep … | sort -u`. **Measured by r1**: an added
  `settleWithProof` overload does not compile against AC-3 test 1's
  `escrow.settleWithProof.selector` — *"Member `settleWithProof` not unique after
  argument-dependent lookup"* — so **009's gate catches it and only the pre-commit ritual does
  not**. Pinning signatures is a further tightening and belongs in the file `003` is already
  extending. **009's recommendation: not in 009.** It is one week, one script, and two tasks;
  the entry-point closure was worth the collision because `fallback` is a live money path that
  nothing saw, and a signature pin is not.
- **OQ-6 — ordering, given the 9/9 checkpoint.** The execution order is `008 → 009` and the
  checkpoint requires **both** green **at once**. §10 now answers this in both directions.
  **Technically**, 009 is independent of `008` (INV-10, re-verified). **On the harness**, it is
  not, and §1.4 plus AC-12 are what make that safe rather than what make it go away.
  So: if `008`'s review is still in `CHANGES` on **2026-09-07**, may 009's implementation start
  in parallel against the current tree, accepting a `{B}` / `{P}` re-measure and a fixture
  re-pin when `008` lands? **009's recommendation: yes, and it is safer than in round 1**,
  because AC-12 makes a parallel-work collision fail at 009's commit instead of at the
  checkpoint. Round 1's stated reason for "yes" was wrong and is withdrawn: 009 touches three
  surfaces `008` counts, not one file. If the answer is no, the fallback of §3.7 row 1 — two
  escrow deployments, zero Solidity diff — is what fits in the remaining time, and its cost is
  written in that row.
- **OQ-7 — one mutants directory or two.** §1.4 CS-1: 009 puts its **fifteen** `M-*.patch`
  files in `zk-verdict/scripts/mutants/`, which a sibling task's step 0 counts, and updates that
  sibling's population literal **in its script** in the same commit, by copying a printed value.
  The cost is that the sibling's script then disagrees with the sibling's **specification**
  (which 009 may not edit) until that specification's next round.
  **The one-line alternative, pre-written:** 009 uses `zk-verdict/scripts/mutants-009/`, CS-1
  vanishes, and no sibling file is touched at all — at the price of a second directory and a
  second population guard, so that a patch deleted from the directory nobody counts becomes
  invisible.
  **009's recommendation: one directory**, because the guard against a deleted mutant is worth
  more than the cosmetic divergence, and because CS-2 forces the same protocol to exist anyway.
  **009's design is correct either way**: AC-12 names no sibling and no directory, and switching
  is a rename plus one glob.
- **OQ-A — answered, recorded here so the answer travels with the change.** *"May 009 put the
  entry-point closure into `scripts/no-keys.sh` check 2, given that a sibling task edits the
  same script this week?"* **Founder ruling, 2026-09-05: yes.** The reasons, as ruled:
  `fallback` is a live money path the pre-commit ritual cannot see, this is a **tightening** and
  therefore not the "loosening" `AGENTS.md` §0 reserves to the founder, and it must be closed
  **by property rather than by a denylist** (R-7) — which is 7h and §3.6.2's `K`. §1.4's
  discipline applies to it as CS-3. **This is not an open question and is listed so no later
  round re-opens it as one.**
- **OQ-8 — who edits the one cell 009 cannot reach, and when.** §1.4 **CS-2** is the only
  counted surface 009 breaks and cannot repair: a sibling's no-skip evidence cell carries the
  forge suite total, that cell lives in `docs/specs/008-verdict-domain-soundness.md` §6.1 and
  is parsed from there by `ac008.sh`, and **009 may not edit that document** (N-10, and the
  founder's instruction of 2026-09-05 while it is in its final round). The edit itself is
  trivial — replace the total with the number that sibling's own `no-skip.sh` prints on the
  post-009 tree, which is `{B} + 16` — but **009 cannot name who makes it.** Three
  possibilities, with 009's recommendation:
  1. **the `008` agent, in its final round**, replaces the literal with a base-measured token
     of its own — the `{P}` shape `003` already uses — after which no future task breaks that
     cell again. **This is 009's recommendation**, and it is the only one of the three that
     does not recur for `004` and `002`;
  2. `reckn-codex-impl` edits the cell in 009's landing commit under a founder instruction,
     copying the printed value (§1.4 rule 2);
  3. the cell stays stale, and **AC-12 fails the checkpoint on purpose**, with the reason
     printed by the sibling gate 009 ran.

  **009 is not blocked on the answer.** AC-12 behaves correctly in all three cases — it is red
  in case 3, which is the honest outcome. What 009 needs from the founder is **the instruction,
  before the commit rather than on 9/9**, because the whole point of §1.4 is that this stops
  being a discovery.

# Review 009 spec round 2

Payload: `/tmp/reckn-payload-009-spec-r2.md`
Codex raw: `/tmp/reckn-codex-009-spec-r2.md`
(one Codex call, `-s read-only`, `-C /Users/hiroyusai/src/reckn`. The first invocation was killed
by my own 10-minute cap before it wrote anything — no output file existed — and was relaunched
detached. That is one *answered* call for this round.)

Target: `docs/specs/009-cross-vm-settlement.md` (2049 lines), **written by Claude Code
(`reckn-spec`), not by Codex** — stated in the payload, so full adversarial review applied.

Measurements below were taken by me on 2026-09-05 against the working tree
(`forge 1.7.1`, `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, `solc 0.8.35`). **No number from
round 1's review is quoted.** Where I re-ran the specification's own scan, the command is given.

---

## Findings

### 1. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:1260`, `:1377`, `:1410`, `:550`, `:571`, `:795` — the entry-point closure is evaluated over a region that is not itself closed. A base contract carries a draining `fallback` past **every** clause of `no-keys.sh` and **every** clause of AC-7, and produces the manifest's demanded evidence line byte-for-byte.

7h, 7i and `no-keys.sh` check 2 clause 2a all read *"the stripped region: from the
`contract RecknZkEscrow` line onward"* (`:1260`; `scripts/no-keys.sh:29`). Solidity inheritance
makes every member of a base contract a member of `RecknZkEscrow` — and the base's text lives
**above** that line, or in another file entirely. `K`'s completeness is irrelevant when the
scanner never reads the declaration.

This is r1 finding 4 (*"an enumeration is not a closure"*) reproduced one level up: round 2
closed the **set of keywords** and left the **region** open.

**Repro** (built, compiled and run; nothing in the repository was written):

```sh
# /tmp/sbx009 — foundry sandbox, lib symlinked to zk-verdict/contracts/lib
# src/Drainer.sol
abstract contract Drainer {
    fallback() external {
        bytes32 id = abi.decode(msg.data, (bytes32));
        address token; uint256 amount;
        assembly { mstore(0x00, id) mstore(0x20, 0)
                   let base := keccak256(0x00, 0x40)
                   token := sload(add(base,2)) amount := sload(add(base,3)) }
        IERC20Drain(token).transfer(msg.sender, amount);
    }
}
# src/RecknZkEscrow.sol — §3.3 verbatim, one token changed:
contract RecknZkEscrow is Drainer { ... }
```

```
forge test --match-test test_inherited_fallback_drains_a_funded_deal -vv
[PASS] test_inherited_fallback_drains_a_funded_deal() (gas: 1712521)
  escrow funded 100 ether -> THIEF TOOK THE WHOLE DEAL -> escrow drained
```

An arbitrary address sends the 32-byte `dealId` as raw calldata and takes a fully funded deal.
No proof, no binding, no state guard, no `msg.sender` gate.

Now every observer 009 installs, run over that file:

```
check 1 privilege vocabulary ......... no hits
check 2 clause 2b .................... fund, settleWithProof
check 3 msg.sender gating ............ no hits
check 4a / 7a ........................ /* 0   */ 0   quotes 0
check 4b / 7b ........................ constructor 0   immutable 0
7c ................................... mapping 1
7d ................................... v.dealBinding 1  v.outcome 3  v.traceHash 1  others 0
7e ................................... RecknVerdictVerifier 1
7f ................................... 9 assignments over 8 distinct LHS
7h / clause 2a ....................... function 2   fallback 0   receive 0   modifier 0   sum 2
7i ................................... assembly 0   using 0
```

and the evidence string AC-7 produces is **identical** to the one the manifest demands at `:934`:

```
escrow-shape: 0 constructor, 0 immutable, 1 mapping, verdict members 3/3 read (5 accesses)
and 4/4 unread, 9 assignments over 8 targets, function 2 (fund settleWithProof)
other entry keywords 0 sum 2, 0 assembly 0 using
```

Note the second half: the drain **uses inline assembly**, and 7i reports `assembly 0`. So 7i's
claim at `:1410` — *"the precondition that makes 7a–7h true statements"* — is false for the
contract as deployed, for the same reason.

Three further statements fall with it:
- **INV-12** (`:795`): *"The set of member declarations through which `RecknZkEscrow` can be
  entered after deployment is exactly two"* — false, and its stated mechanization is the
  region-scoped clause.
- **INV-8** (`:783`): *"no constructor and no `immutable`, so two deployments of the same source
  are behaviourally identical"* — a base constructor / base `immutable` is invisible to 4b and 7b.
- **§3.6.2's** *"What the closure does not reach, said here rather than implied"* (`:571`) lists
  public getters and statements inside the two entry points. It does not list **inherited
  members**, which is the larger of the two omissions.

**Remedy (must be in the spec before implementation; it is small).** Close the region before
closing the keyword set. Minimum property form, all mechanical, none a denylist:
1. the normalised text between `contract RecknZkEscrow` and its opening `{` is **empty** (no
   inheritance specifier) — one clause, and it makes the region equal the member set;
2. the file contains exactly **one** `contract` declaration and the region begins at it;
3. 7i's `using` count is taken over the **whole file**, not the region (file-level
   `using … for … global` is a prologue construct);
4. `no-keys.sh` check 4a's literality clause extends to the prologue, so the region boundary
   itself cannot be moved by a comment.

Add the base-contract drain as a mutant beside **M-11** (M-11 appends `fallback` *inside* the
region and is detected; this variant is not).

---

### 2. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:1668` (§7.8) — the naming gate's own extraction rule fails on this document, so `ac009.sh --check` cannot pass and no row can run.

§7.8 defines the mandated-name set as *"the backtick-quoted tokens beginning `test_AC`"*
extracted from §7's AC bodies, and fails if any does not match
`^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$` **or** if the per-selector counts differ from the manifest.

**Repro** (the rule applied literally to §7 of the document under review):

```sh
python3 -c "
import re
s=open('docs/specs/009-cross-vm-settlement.md').read().split('\n')
i=next(n for n,l in enumerate(s) if l.startswith('## 7. Acceptance criteria'))
j=next(n for n,l in enumerate(s) if l.startswith('## 8. Test plan'))
t=re.findall(r'\`(test_AC[^\`]*)\`','\n'.join(s[i:j]))
rx=re.compile(r'^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+\$')
print(len(t),'tokens;','NOMATCH:',sorted({x for x in t if not rx.match(x)}))"
```

```
20 tokens; NOMATCH: ['test_AC', 'test_AC01_…', 'test_AC03_settleWithProof_...',
                     'test_AC03_settleWithProof_…']
```

The four are the bare token in §7.8's own sentence, the prose placeholder in §7.0's Gate-2
paragraph, and **two citations of round 1's rejected name** — one in §7.0's comment block and one
in AC-3's parenthetical at `:1158`. Including them also breaks the second clause: `_AC03_` counts
4, not the manifest's 2.

So the gate written to stop round 1's contradiction reproduces it inside itself. An implementer
who writes §7.8 as specified gets a `--check` that always exits non-zero, and the cheapest route
to green is to narrow the extractor until it agrees — **the exact failure mode 7f's own warning
box at `:1266` names** (*"a clause whose numbers are wrong converts a gate into an instruction to
blind it"*).

**Remedy.** Make the mandated set machine-delimited rather than inferred from prose: put the
sixteen names in a fenced ```` ```ac009-testnames ```` block the way §7.1 fences the manifest,
and have §7.8 read that block. Historical citations then live in prose where they belong. One
block, no new mechanism.

---

### 3. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:762` (INV-2), `:666` (§4.4 B-1), `:1923` (§11(4)) — INV-2 is false as written, AC-3 test 2 asserts its negation as passing behaviour, and §11(4) instructs the implementer to ship the resulting sentence into the file that states the central claim.

INV-2 (`:762`): *"A `settleWithProof` call that does not revert implies that
`ISP1Verifier.verifyProof` was reached … **there is no path to a payout that skips proof
verification.**"*

009's own AC-3 test 2 (`:1172`) funds deal B against a sham `AlwaysReproduces` and requires that
**submitting garbage settles to the seller**. §4.4 B-1 (`:666`) states this plainly and calls it
correct behaviour. Both cannot be true. There *is* a path to a payout that skips proof
verification: the buyer commits it at `fund`.

I am **not** rejecting the design. A registry of blessed verifiers is a key and is correctly
refused (`:620`); making the adjudicator a deal term is the only shape that delivers the
application's sentence without one. But three consequences must be written before an implementer
touches `CLAUDE.md`:

- **INV-2 needs its precondition**: *for a deal whose `verifierCodeHash` is the codehash of a
  canonical `RecknVerdictVerifier`*, there is no path to a payout that skips proof verification.
  Without the clause the invariant is false and no AC mechanizes it.
- **The party 009 moves risk onto is the seller, and the direction is new.** Before 009 the
  escrow's verifier was fixed for all deals; a seller who reproduced was paid. After 009 a buyer
  can fund against a sham that returns `FAILED` for everything, the seller works, anyone submits
  garbage, the money returns to the buyer. INV-11 (`:803`) and L-4/L-7 (`:1772`, `:1781`) state
  the checklist and the sham; **neither states that this is a capability the buyer did not have
  before 009**, which is the sentence a judge will extract.
- **§11(4) as written is unsafe.** It tells the implementer that `CLAUDE.md` *"must not say, or
  imply, that the deal's committed verifier is what makes a payout sound"* and that *"settlement
  authority comes from the proof verifying (B-2)"*. For a sham-verifier deal that is untrue, and
  `CLAUDE.md` is the file the whole product claim lives in. The sentence 009 wants preserved
  verbatim — `決済権限は「proof が検証される」ことから来る` — is correct **only** with the same
  precondition INV-2 needs.

**Remedy.** One qualified restatement of INV-2, one sentence in §11(4) tying B-2 to the seller's
pre-work check of `verifier` / `verifierCodeHash`, and one line in L-7 saying the capability is
new in 009. No mechanism changes. Cheap, and it is the difference between an honest claim and
`AGENTS.md` §0's failure mode.

**Credit where due:** §3.6.3 (`:598`) already says *"`no-keys.sh` exiting 0 does not, after 009,
mean what it meant before 009 — it now admits a contract that calls out to buyer-named code"*, and
§11(3) requires that into `AGENTS.md` §0. That discipline is right. This finding is that the same
honesty has not reached INV-2 or §11(4).

---

### 4. [MAJOR] `:1044` (AC-0b), `:1848` (L-12), §7.5 — nothing in 009 ties either pinned fixture to the guest whose name it carries. The headline claim rests on a filename.

`xvm.pinned`'s line format is `<path> sha256= vkey= binding= outcome=` with clauses "exactly two
lines / five fields", "digest and three parsed fields match", "vkeys differ, bindings differ,
none zero, both `Reproduced`". **No clause names either path.** AC-1/AC-2 likewise say *"both
fixtures"* without fixing which. §7.5 explicitly excludes *"that the committed fixtures are the
current guests'"* and assigns it to `008`; §1.4 rule 3 then forbids 009 from depending on `008`
landing. On a tree where `008` has not landed, the sentence *"settled by a proof produced by the
Solana re-execution guest"* (`:53`) is supported by the string `svm` in a filename and by nothing
else in 009.

Two halves, and they need different answers:
- **cheap half — close it.** Require the two exact paths, `src/fixtures/svm-groth16-fixture.json`
  and `src/fixtures/reexec-groth16-fixture.json`, as literals in `xvm.pinned` and as the test
  constants, and reject non-canonical / duplicate paths. One clause.
- **deep half — disclose it.** L-12 currently says AC-0b does not assert the fixtures are the
  *current* guests'. It must also say AC-0b does not assert **which guest either came from**, and
  that on a `008`-less tree nothing in the repository does. N-2 forbids 009 the Rust work that
  would close it, so disclosure is the honest ceiling.

---

### 5. [MAJOR] `:1573`–`:1621` (AC-12), `:1713` (§8.2), `:1838` (L-17) — AC-12 is a weaker instrument than §8.2 claims, and three of its gaps are not in L-17.

Accepting the mechanism; disputing the sentence built on it. §8.2 (`:1713`) says
`ac009.sh --all` *"is also the assertion that every sibling gate in the tree exits 0 — the 9/9
checkpoint, in one command, on one tree."* Not established:

- **(a) vacuous green is the case the founder authorized.** OQ-6 (`:2000`) recommends starting
  009's implementation in parallel while `008` is still in `CHANGES`. In that tree
  `zk-verdict/scripts/` contains only `zk-e2e.sh`, so `siblingGates` is recorded as `[]`,
  discovery finds nothing, and the row prints `0 sibling gate(s) discovered, 0/0 exit 0` with a
  witness of `sha256("")`. L-17 concedes this is *"a disclosure and not a check"*. §8.2 does not
  carry the qualifier and must.
- **(b) nothing validates `siblingGates`.** It is written by the implementer at 009's base;
  `ac009.sh` only refuses to run if the file is absent (`:1003`). A `[]` recorded on a tree that
  already had `ac008.sh` silently kills the deletion clause. One line: the implementation report
  must show the recorded value beside the discovery output at the base commit.
- **(c) `exit 0` from a sibling is not evidence the sibling checked anything.** 009 cannot police
  `008`'s integrity and should not try — but AC-12's own witness cannot see it either, because
  the witness is over the gate *files* and a stub moves both sides equally. Not in L-17. One
  sentence.
- **(d) not in the document at all: `ac009.sh --all` now writes the working tree.**
  `docs/specs/008-verdict-domain-soundness.md:1439` has `ac008.sh --all` apply
  `mutants/09-restore-u64low.patch` **in-tree** under a `trap` as its canary. AC-12 runs
  `bash ac008.sh --all`, so 009's own gate patches and reverts repository sources, and an
  interrupt leaves the tree carrying a sibling's mutant. §7.0 (`:899`) makes a point of *"No file
  under the repository is written at any point"* — true of `ac009-selftest.sh`, and now untrue of
  the command §8.2 promotes to the checkpoint. Must be stated.
- **(e) cost is unstated and may be prohibitive.** `ac008.sh --all` is 18 rows including cargo
  suites, `ac008-selftest.sh`'s 21 sandbox mutants with controls, and AC-14(iv) which
  `--execute`s three SP1 guests and rebuilds each ELF to compare `elf_sha256`. §7.0 advertises
  ~0.73 s for 009's own sandbox; `--all` is now dominated by a sibling gate whose runtime nobody
  has measured. A gate too slow to run is R-9's shape. The spec must require the implementation
  report to measure and print the wall time of `ac009.sh --all` with siblings present.

M-13 remains a good mutant — it proves discovery executes what it finds. It does not prove the
real sibling is present, meaningful, or complete, and AC-12's prose should say so.

---

### 6. [MAJOR] `:143` (§1.4), `:1890` (§10 direction table), `:2030` (OQ-8) — the counted-surface inventory is asserted complete and is not. Three surfaces are missing, and OQ-8's *"the only counted surface 009 breaks and cannot repair"* is false.

Verified against `008`'s own manifest and AC bodies. What 009's landing actually moves:

| surface | in 009's CS list? | breaks? |
|---|---|---|
| `ac008-selftest.sh` step-0 literal `21` over `mutants/*.patch` (`008:2660`) | CS-1 ✓ | yes; 009 fixes it in the script |
| `008` AC-13 witness over `mutants/*.patch` (`008:1361`) | CS-1 ✓ | **no** — recomputed on both sides at run time. 009's analysis is correct |
| `008` AC-11 witness over `*.t.sol` (`008:1360`) | not listed | **no** — same reason |
| `008` AC-11 evidence `18/18 forge tests ran` (`008:1276`, and the body at `008:2548` requires `forge test --json` to report **18**) | CS-2 ✓ | **yes, and 009 cannot repair it** |
| `surfaces.pinned` escrow digest | CS-4 ✓ | yes; 009 re-pins from the printed value |
| `scripts/no-keys.sh` | CS-3 ✓ | no; numbers, args and final line unchanged |
| **`008` AC-14 `docs-check.sh`: 9 absent literals + 11 required markers over `README.md`, `AGENTS.md`, `CLAUDE.md`, `zk-verdict/README.md`, `scripts/no-keys.sh`** (`008:3104`–`008:3212`) | **missing** | **plausibly yes.** 009 §11 prescribes rewrites of exactly those files; e.g. `008` markers 10 and 11 require the literal `RecknVerdictVerifier.sol` to be present in `AGENTS.md` and `CLAUDE.md`, and `008` literal 9 requires ``the body of `contract RecknZkEscrow` only`` to be **absent** from `no-keys.sh` — a comment 009 has good reason to rewrite |
| **`008` §AC-0b's transcribed digest literal `07d649c2…33e45b`** (`008:1936`), which its spec says `surfaces.pinned` *"must contain exactly"* | **missing** | not gate-visible (R5 makes `surfaces.sh` read the pin file, `008:1992`), but it becomes wrong the moment 009 lands, and it is a **landmine if `008` lands second**: that implementer transcribes a stale digest and is red on arrival. §1.4 CS-4's *"if the sibling has not landed this row is inert"* is true for 009 and false for the sibling |
| **`008` forge selector counts `_AC07_`=2, `_AC10_`=4 over the shared `zk-verdict/contracts` project** (`008:1272`, `008:1275`) | **missing** | **no** — 009's sixteen names are all `_AC01_`…`_AC06_`. Safe by luck of numbering, not by criterion. One sentence closes it |

This is r1 finding 3 in its second instance: an inventory over shared surfaces asserted complete
and short by three. **AC-12 does make each of them loud at 009's commit**, which is the design
working — so this is a correction to §1.4, §10 and OQ-8, not a new mechanism. Add a **CS-5** row
for the sibling's document-content gate with the rule *"009's document edits are additive to a
sibling's markers; the implementation report names each sibling-asserted marker verified still
present or still absent after 009's edits"*, a **CS-6** row for the sibling-spec digest literal,
and delete the word *"only"* from OQ-8.

---

### 7. [MAJOR] `:774` (INV-5), `:1246` (AC-6 test 3), `:1793` (L-7) — INV-5 states unconditional value conservation for a contract that discards both ERC-20 booleans, and L-7 covers only the inbound half.

INV-5 asserts *"the escrow's balance attributable to that deal goes from `amount` to `0` exactly
once"* with no token model. With a `transferFrom` that returns `false` and moves nothing, the deal
is booked `Funded` with **nothing pulled** (state is written before the pull, `:405`), and a
sham-verifier settle then marks it `Settled`. With a `transfer` that returns `false` on the way
out, the deal is marked `Settled` and **nobody is paid** — a case L-7 does not mention at all;
L-7's whole discussion is the inbound side and pooling.

N-5 (`:86`) correctly keeps the code fix in `003`'s scope and 009 should not take it. What must
not ship is the unconditional invariant and AC-6's framing as general conservation. Add the
precondition — *"for an exact ERC-20 that reverts on failure"* — to INV-5 and to AC-6 test 3's
description, and extend L-7 with the outbound `transfer` case.

---

### 8. [MINOR] `:780` (INV-7) — `msg.sender` appears **three** times, not twice, both in today's contract and in §3.3.

```sh
grep -c 'msg\.sender' zk-verdict/contracts/src/RecknZkEscrow.sol      # 3
```
`buyer: msg.sender`, `emit Funded(dealId, msg.sender, …)`, `transferFrom(msg.sender, …)` — same
three in §3.3 (`:400`, `:404`, `:406`). Nothing depends on the number (no AC mechanizes INV-7;
`no-keys.sh` check 3 tests a different predicate), which is exactly why it survived. It is the
same species as r1 finding 1: a count transcribed rather than run. Fix the number or drop it.

---

### 9. [MINOR] `:1552` (AC-11), `:1931` (§11(5)(iv)) — the `defence in depth` clause is a denylist by 009's own R-7 standard.

`grep -F 'defence in depth'` over `CLAUDE.md` and `zk-verdict/README.md` is defeated by
*"a secondary safeguard"*, *"belt and braces"*, *"多重防御"*, or by writing the inversion without
the phrase. 009 argues at `:562` and `:1395` that a rule one new name defeats is not a rule, then
installs one. The **positive** clause beside it — `決済権限は「proof が検証される」ことから来る`
preserved verbatim — is the property-shaped instrument and should carry the weight, qualified per
finding 3. Keep the grep if it is free, but it must not be counted as the thing that stops the
B-2 inversion; the implementation review is (R-10: name where it lands on a human, and 009 should
name it here as it does in L-10).

---

### 10. [MINOR] `:1824` (L-16) — the residual is again stated smaller than it is.

L-16 says a value-moving statement inside an entry point that assigns nothing is *"caught
behaviourally by AC-6 test 3 … and AC-1 test 2, and lexically by nothing."* Under R-11 the
attacker branches on the observer: `if (block.chainid != 31337) IERC20Min(t).transfer(x, y);`
contains no `=`, adds no entry keyword, and passes every behavioural test in the suite because
the suite runs on the local chain id. The honest form is *"caught behaviourally only on the paths
these tests exercise; an implementation that branches on the observer is caught by neither"* —
plus a named human step. Round 1's §7g understated its residual and the drain lived in the gap
(r1 finding 4); round 2's L-16 repeats the shape one level out.

A cheap closure exists if the founder wants it, since §3.3 *is* the whole contract: extend 7f's
statement scan to pin the **ordered statement list** of `fund` and `settleWithProof` verbatim,
not just the assignments. That closes L-11 and L-16 together. It is a tightening of an existing
observer, not a new one.

---

## Rejected findings

- **Codex 4's specific repro — "point `xvm.pinned` and the SVM test constant at the committed
  predicate fixture `groth16-fixture.json`; AC-0b, AC-1 and AC-2 all pass."** Rejected: measured,
  `zk-verdict/contracts/src/fixtures/groth16-fixture.json` has **no `deal_binding` key at all**
  (`keys: max_delta, min_delta, outcome, post, pre, proof, public_values, trace_hash, vkey`), so
  AC-0b clause 2's parse of `.deal_binding` fails, clause 3's non-zero test fails, AC-9's
  non-empty `.deal_binding` clause fails, and `fund` would revert `ZeroBinding` anyway. The
  *general* observation that the paths are unpinned is correct and is finding 4; the repro is not.
- **Codex 3's sub-item "an AC-11 witness over every `*.t.sol` (`008:1360`)" and "an AC-13 witness
  over every `mutants/*.patch` (`008:1361`)" listed as collisions 009 must repair.** Rejected:
  both witnesses are placeholders that `ac008.sh` recomputes from the live glob and that the row's
  own command computes at run time, so both sides move together and neither needs an edit
  (`008:1213-1216`, `008:1387` — *"no mutant modifies a patch file, so the witness is a constant
  **for the whole run**"*, i.e. computed, not hard-coded). 009's CS-1 analysis of this is right and
  I am not overturning it.
- **Codex 3's framing that 009 must "avoid the shared counted surfaces" or obtain a coordinated
  `008` spec change as a BLOCKER on 009.** Downgraded to MAJOR (finding 6) plus the OQ-8
  escalation below. 009 already identifies CS-2 as unrepairable, states the three possible owners,
  and makes case 3 (*"the cell stays stale and AC-12 fails on purpose"*) the honest outcome
  (`:2044`). A specification that names its own unclosable coordination cost and keeps its gate red
  until someone closes it is behaving correctly; what is wrong is the claim of completeness, which
  is finding 6.
- **Codex 1's framing as a design BLOCKER ("buyer-selected code is an adjudication key; disclosure
  is not sufficient").** Partially rejected. The finding is real and is kept as finding 3, but as a
  defect in INV-2, L-7 and §11(4) — not in the mechanism. The alternatives are a registry (a key,
  correctly refused at `:620`), a vkey parameter on `verifyVerdict` (a loosening of `008`'s check,
  reserved to the founder, OQ-2), or two escrow deployments (a deployer choosing the VM — the same
  objection one level up, §3.7 row 1). There is no shape that both delivers the application's
  sentence and removes the buyer's choice; the buyer choosing terms of their own deal is not the
  same object as a third party holding a key.
- **Codex's "confirmed non-finding: §7.8 fixes the prior mandated-name regex contradiction."**
  Rejected — see finding 2. Applied literally, §7.8's extraction rule returns four non-matching
  tokens and makes `ac009.sh --check` fail on this document.

## Verified and could not break

- **7f / E-14's recount is correct.** I ran the scan printed at `:1354` against §3.3's own
  solidity block: **9 assignments over 8 distinct verbatim left-hand sides**, and the eight are
  exactly the ones tabulated at `:1319`. `Deal memory d` does compile, does make
  `d.state = State.Settled` a write to a copy, and does leave the deal `Funded` — so **M-12 and
  AC-6 test 1 are two genuinely independent detections** of one double-spend, one lexical and one
  behavioural. Round 2's correction of round 1's `7 over 6` holds.
- **INV-9 / the `view` dispatch.** `RecknVerdictVerifier.verifyVerdict` is `public view`
  (`zk-verdict/contracts/src/RecknVerdictVerifier.sol:50-52`), so §3.3's dispatch through the
  imported type is a `STATICCALL` **without modifying that file** — N-1 and INV-9 are compatible.
  I checked this specifically because they would contradict if it were not `view`.
- **`v.dealBinding` ×1, `v.outcome` ×3, `v.traceHash` ×1 at `:103`, `:109`, `:111`, `:116`, `:116`**
  — 7d's multiset and §2.3(c) verified against the shipped file. No numeric member is read, so
  INV-10 (009 is correct with or without `008`'s widening) holds.
- **`008` mutant filenames are `01-…`…`21-…`**, so 009's `M-*.patch` glob genuinely does not
  collide (`008:3296`). §1.4 CS-1's premise is correct.
- **Tier discipline.** The header at `:6-10` declares local tier and repeats it in L-13; §7.5
  refuses an AC for T-7 on a *measurement* rather than an argument; §5.3 withdraws round 1's
  "unreachable on every EVM this project targets" and replaces it with the EIP-6780 case, in the
  direction that hurts 009. I looked for the "confess and absolve in the same paragraph" pattern
  and did not find it — L-14 and L-16 both state the withdrawal without granting relief. Finding 10
  is an understatement, not an absolution.

## Deferred

- **The EIP-6780 stranding path (L-14, `:1803`).** Real, correctly stated, and **new in 009**: a
  buyer can create a killable verifier and `fund` against its live codehash in one transaction,
  after which every `settleWithProof` reverts `VerifierMismatch` forever and, because N-3 adds no
  timeout, the seller who worked gets nothing. It is griefing, not theft (the buyer burns their own
  money), `forge 1.7.1` will not reproduce the account deletion in-test so an AC would pass for the
  wrong reason, and the closure is a deadline — which is `003`/`001`, frozen off the 9/9 gate. Not
  in 009's scope. It belongs in the root `README.md` `Known gaps (not closed)` entry alongside the
  existing no-timeout line, and §11(2) should say so explicitly rather than leaving it in §9.
- **The discarded `transferFrom` / `transfer` booleans (N-5).** Ruled into `003` and correctly not
  taken here. Only the invariant wording moves (finding 7).

---

## Answers to the two founder questions

### OQ-8 — does the orchestrator's ruling close it?

**No. It closes the intent and not the mechanism, and one founder instruction is still required
before 009's landing commit.**

`008`'s AC-11 fixes the suite total in **two** places, and both are in the document 009 may not
edit: the body at `docs/specs/008-verdict-domain-soundness.md:2548` (*"`forge test --json` over
the whole suite must report **18** results"*) and the §6.1 manifest evidence cell at `:1276`
(`no-skip: 0 early-return fixture gates, 18/18 forge tests ran, 0 skipped; witness={witness}`).
`ac008.sh` requires stdout to **contain that evidence line verbatim** after `{witness}`
substitution (`008:1213-1216`). So an `008` implementation that asserts an id set instead of a
total prints a line its own dispatcher cannot match. **"Assert id sets, not totals" is not
implementable in `008` without editing `008`'s approved spec manifest** — which is not the
implementation agent's role under `AGENTS.md` §2.

What is needed, in one line, before the landing commit: **authorize the `008` side to replace
AC-11's `18/18` with a base-measured token (the `{P}`/`{B}` shape `003` already uses) in both
`008:2548` and `008:1276`, in the commit that lands 009.** That is 009's own recommendation 1 at
`:2038` and it is the only one of the three that does not recur for `004` and `002`.

Two things remain that the ruling does not reach and that 009 must add (finding 6):
- **`008` AC-14's document assertions** over the four files 009's §11 rewrites plus
  `scripts/no-keys.sh`. Not a total, so "id sets not totals" does not touch it. AC-12 makes it
  loud; the inventory must name it so the implementer checks rather than discovers.
- **`008` §AC-0b's transcribed digest literal `07d649c2…33e45b`** (`008:1936`). Not gate-visible,
  but wrong the instant 009 lands, and actively harmful if `008` lands second.

### OQ-1 (expanded) — is the `003` collision inventory right?

**Yes, and I verified all four rows are real sites.** `003:1382` check 8 does key on the
constructor body and becomes an observer of nothing (R-9's shape, in `003`'s own vocabulary);
`003:512`/`:515` do give the DEPLOYER the `verifier`/`refundDelay` choice that ceases to exist;
`003:904`/`:908` G-33/G-37 are keyed on deployment-time parameters; and `forge inspect
RecknZkEscrow methodIdentifiers --json` does list `"verifier()": "2b7ac3f3"` today, which §3.3
deletes, so the five-part deployment check's read must move to `deals(dealId).verifier`.

`003` is stopped by `AGENTS.md` §7 and off the 9/9 gate, so nothing here blocks 009 — the cost is
deferred, not paid. **I concur with 009's recommendation to keep the check-4 tightening.** One
addition the founder should note when `003` reopens: finding 1's remedy makes check 4/7's region
closure part of the same file `003` extends, so `003`'s check 8 should be re-keyed onto the region
property rather than onto the constructor body it will no longer have.

---

## Classification, for the case where 9/7 arrives before round 3

Per the founder's ruling, if 009 is not APPROVE'd by end of 2026-09-07 the implementation proceeds
against the spec as it stands with open items disclosed. In that case:

**Must be closed during implementation — do not ship without them.** All three are spec text or
one clause of one script; none is architecture.
1. **Finding 1** — the region closure. Without it `no-keys.sh` and AC-7 both certify a drainable
   escrow, and the repro above is thirty lines. This one is not disclosable: it makes the build
   condition of `AGENTS.md` §0 return a false positive, which is the single thing the project
   cannot ship.
2. **Finding 2** — §7.8's extraction rule. Without it `ac009.sh --check` cannot pass and the
   implementer's cheapest exit is to blind the extractor.
3. **Finding 3** — INV-2's precondition and §11(4)'s `CLAUDE.md` sentence. The implementer is
   instructed by §11(4) to write a claim into the file that states the central claim, and for a
   sham-verifier deal that claim is false.
4. **Finding 4's cheap half** — pin the two fixture paths as literals. One clause; without it the
   task's headline claim rests on a filename.

**Disclosure is sufficient — record in the implementation report and in `README.md`'s
`Known gaps (not closed)`.**
- Finding 4's deep half (which guest each fixture came from) — L-12 extended.
- Finding 5(a)(b)(c)(d)(e) — AC-12's true strength, `siblingGates` provenance, in-tree mutation by
  `ac008.sh --all`, and the measured wall time of `ac009.sh --all`.
- Finding 6 — corrected inventory, CS-5 and CS-6, and the word *"only"* struck from OQ-8.
- Findings 7, 8, 9, 10 — invariant preconditions and residual wording.
- Deferred: EIP-6780 stranding, the discarded ERC-20 booleans.

**Founder action required regardless of the verdict:** the OQ-8 instruction above. Without it the
9/9 checkpoint cannot be green, and AC-12 will correctly say so.

---

Six of the ten findings run in the direction that flatters 009 (1, 3, 4, 5, 6, 10); none runs in
the KILL direction. That matches this repository's prior, and I looked specifically for the
opposite bias after r1 recorded the same split. **Round 2 is a large and genuine improvement over
round 1** — the 7f recount, the E-13/E-14/E-15/E-16 reproductions, the §5.3 withdrawal and the
whole of §1.4 are real work, and three of round 1's four blockers are closed. The three that
remain are the same shape as the ones that were fixed: **a closure asserted over a boundary that
was not itself closed, a gate that cannot pass its own document, and an invariant that its own
acceptance criterion contradicts.** None is architectural and all are closable in one round.

VERDICT: CHANGES

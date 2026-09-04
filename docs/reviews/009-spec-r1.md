# Review 009 spec round 1

Payload: `/tmp/reckn-payload-009-spec-r1.md`
Codex raw: `/tmp/reckn-codex-009-spec-r1.md`

Target: `docs/specs/009-cross-vm-settlement.md` (1291 lines), written by **Claude Code**
(`reckn-spec`), **not by Codex** — stated in payload §0, so author independence holds and every
Codex finding was adjudicated against the real files before adoption.

One Codex call, `-s read-only`, `-C /Users/hiroyusai/src/reckn`. Codex returned 7 findings
(2 BLOCKER, 5 MAJOR) and a "attacks that held" list. **Two of the three items on that "held" list
are false**, and I detected them independently before reading the Codex output; they are findings
1 and 2 below and the rejections are recorded with mechanical evidence.

All measurements below were taken 2026-09-05 with `forge 1.7.1`
(`Commit SHA 4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, `evm_version = "osaka"`) in a scratch
sandbox (`mktemp -d`, `lib` symlinked). **No repository file was written by this review** except
this document. No number is carried from any earlier round.

---

## Findings

### 1. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:1010-1017` (AC-7 clause 7f) and `:640` (manifest evidence) — the pinned assignment counts are wrong against §3.3's own contract, and the only way to make them true is to blind the observer

7f says: *"every `=` that is not part of `==`, `!=`, `<=`, `>=` or `=>` has a left-hand side drawn
from exactly `{REPRODUCED, FAILED, EMPTY_CODEHASH, deals[dealId], d.state, to}`, and the total
number of such assignments is exactly **7**"*, and §7 above it insists *"Every count below is a
literal of this specification, measured against §3.3 and transcribed here, not a value the
implementer generates from the file."* The manifest evidence line at `:640` carries
`7 assignments over 6 targets` and is machine-compared.

Applying that exact rule to the contract §3.3 writes gives **9 assignments over 8 targets**. The
LHS enumeration omits the two local bindings `d` and `v`:

```
line  2 | uint8 public constant REPRODUCED = 0;
line  3 | uint8 public constant FAILED = 1;
line  5 | bytes32 public constant EMPTY_CODEHASH =        <- omitted from the count
line 48 | deals[dealId] = Deal({
line 61 | Deal storage d = deals[dealId];                 <- LHS `d` not in the enumerated set
line 65 | VerdictPublicValues memory v =                  <- LHS `v` not in the enumerated set
line 70 | d.state = State.Settled;
line 73 | to = d.seller;
line 75 | to = d.buyer;
```

No correct implementation of 7f can print `7 assignments over 6 targets` on the contract 009
specifies, so **AC-7 is red on day one**. The failure mode this creates is the one `AGENTS.md` §5
names: the implementer's cheapest route to green is to tune the counter until it says 7 — i.e. to
exclude local declarations from the LHS scan. That exclusion is exactly the R-11(iii) hole 7f
exists to close: with `d` unscanned, a mutation `d = deals[otherId];` (retarget the settled deal)
becomes invisible to 7f, and no other AC covers it.

**Repro** (run from the repo root; extracts §3.3's own solidity block and applies 7f's stated rule):

```sh
python3 - <<'PY'
import re
s=open('docs/specs/009-cross-vm-settlement.md').read()
b='contract RecknZkEscrow {'+re.search(r'```solidity\ncontract RecknZkEscrow \{(.*?)\n```',s,re.S).group(1)
st='\n'.join(re.sub(r'//.*','',re.sub(r'/\*.*\*/','',l)) for l in b.split('\n'))
n=0
for l in st.split('\n'):
    j=0
    while j<len(l):
        if l[j]=='=':
            p=l[j-1] if j else 'X'; q=l[j+1] if j+1<len(l) else 'X'
            if p in '=!<>' or q in ('=','>'): j+=2; continue
            n+=1
        j+=1
print(n)   # prints 9, not 7
PY
```

**Remedy (round 2):** add `d` and `v` to the LHS set, correct both literals to
`9 assignments over 8 targets`, and keep the RHS pin on the two `to = …` statements. Do **not**
narrow the scan.

---

### 2. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:819` — a test name the spec mandates is rejected by the naming gate the spec mandates

§7.0 requires `ac009.sh` to enforce
`every name in found must match ^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$`.
§AC-3 mandates the test `test_AC03_settleWithProof_has_no_adjudicator_parameter`. The tail
`settleWithProof` contains `W` and `P`; the regex tail is `[a-z0-9_]+`. **The gate rejects the
spec's own test**, so AC-3 fails its naming gate and, because the count gate is exact, AC-3 can
never reach 2/2.

**Repro:**

```sh
python3 -c "import re;print(bool(re.match(r'^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$','test_AC03_settleWithProof_has_no_adjudicator_parameter')))"
# False
```

All 15 other mandated names pass (checked mechanically). **Remedy:** rename to
`test_AC03_settle_with_proof_has_no_adjudicator_parameter`, or widen the regex tail to
`[A-Za-z0-9_]+`. Renaming is the smaller change and keeps the gate strict.

---

### 3. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:1197` (§8.1 file table) and `:1281-1289` (OQ-6) — landing 009 turns **`008` red**, which defeats the 9/9 checkpoint's "both green, simultaneously"

009's §10 argues independence in one direction only ("if `008` lands first, 009 is unaffected")
and never asks the reverse. Two mechanical breaks run the other way:

**(a) shared mutant directory.** §8.1 puts 009's **twelve** patches in
`zk-verdict/scripts/mutants/M-*.patch`. `docs/specs/008-verdict-domain-soundness.md:2620` makes
`ac008-selftest.sh` step 0 assert:

```
0. assert `ls zk-verdict/scripts/mutants/*.patch | wc -l` == 21   # a deleted mutant FAILS AC-13
```

009 makes that count 33 → **008's AC-13 fails**. It also changes 008's AC-13 witness set, which
`008:1347` defines as *"the **twenty-one** `zk-verdict/scripts/mutants/*.patch` files, whole"* →
008's hardcoded `witness=` no longer matches. The break is asymmetric: 009's own witness glob is
`M-*.patch`, which does not match 008's `NN-*.patch`, so 008 does not break 009.

**(b) hardcoded suite total.** `008:2500-2508` (AC-11) requires
`forge test --json` over the whole `zk-verdict/contracts` suite to report **18** results, and its
evidence line is the literal `no-skip: 0 early-return fixture gates, 18/18 forge tests ran, 0
skipped; witness=<16 hex>`. 009 adds 16 tests to that same suite (§7.1, 6 forge rows summing to
16) → 34 → **008's AC-11 fails**.

009's OQ-6 states the opposite: *"it touches no file `008` touches except
`zk-verdict/contracts/test/RecknZkEscrow.t.sol`"*. That one named file is genuinely shared
(008's AC-11 must remove its early-return gate), but the three genuinely colliding surfaces —
`zk-verdict/scripts/mutants/`, the suite total, and `scripts/no-keys.sh` (008 adds check 5 at
`008:3253`; 009 replaces check 4) — are all unnamed.

**Repro:** after both land, `bash zk-verdict/scripts/ac008.sh AC-13` and `… AC-11` exit non-zero
while `bash zk-verdict/scripts/ac009.sh --all` exits 0.

**Remedy (round 2, cheap and entirely within 009):** move 009's patches to
`zk-verdict/scripts/mutants-009/` (or `xvm-mutants/`), and rewrite §10 / OQ-6 to state the
collision inventory in **both** directions, naming `scripts/no-keys.sh` and the shared suite
total. 009 must not edit `008` (N-10) — the fix is to stop standing on 008's glob and to stop
asserting an independence it does not have.

---

### 4. [BLOCKER] `docs/specs/009-cross-vm-settlement.md:988-1030` — AC-7 is titled *"the escrow's shape is closed"* and does not close it: a `fallback` that drains any funded deal passes all four `no-keys.sh` checks **and** all twelve ACs

`scripts/no-keys.sh:46` enumerates the state-changing surface with
`grep -oE '\bfunction +[a-zA-Z_][a-zA-Z0-9_]*'`. Modern Solidity declares `fallback()` and
`receive()` **without** the `function` keyword, so check 2 never sees them. Check 1's vocabulary
does not contain them, check 3 only matches `require( msg.sender` / `if ( msg.sender`, and 009's
new check 4 counts only `constructor` and `immutable`. On 009's side: 7b (0/0), 7c (1 mapping),
7e (1 `RecknVerdictVerifier` on a `d.verifier` line) and 7d (the `v.` multiset) are all unchanged
by the addition, and **7f is blind because the drain contains no `=` at all**.

Added to the §3.3 contract:

```solidity
fallback() external {
    IERC20Min(deals[abi.decode(msg.data,(bytes32))].token)
        .transfer(msg.sender, deals[abi.decode(msg.data,(bytes32))].amount);
}
```

Anyone sends a 32-byte dealId as raw calldata and takes any funded deal's tokens. No proof, no
binding, no state guard, no `msg.sender` gate.

**Measured**: the contract compiles (`forge build`, "Compiler run successful"); over its
comment-stripped body, check 1 = no match, check 2 lists only `fund`/`settleWithProof`, check 3 =
no match, check 4 = `constructor 0, immutable 0`, and 7f's assignment scan finds **0** assignments
in the added region.

§7g's stated residual is *"7f cannot see a state variable that is declared and never assigned"*.
The real residual is much larger: **7f cannot see any money-moving code that performs no
assignment**, and no clause of AC-7 enumerates the contract's callable surface. This is the
failure `AGENTS.md` §5 names verbatim — *"AC を書いたら必ず問え: これを満たしつつ何も検定していない
実装は作れるか"*.

**Remedy (round 2, one clause + one mutant):** AC-7 gains **7h** — over the stripped region, the
set of declared entry points is exactly `{fund, settleWithProof}`, with **0** occurrences of the
tokens `fallback`, `receive`, `assembly` and `delegatecall`; and §7g is rewritten to state the
real residual. Add **M-11** (a sandbox mutant appending the fallback above) targeting AC-7. This
is a tightening of `no-keys.sh` too and should be carried into check 2 in the same commit — but
see finding 8: that part is an OQ, not an agent decision.

---

### 5. [MAJOR] `docs/specs/009-cross-vm-settlement.md:455-463` (§4.4) — the barrier table inverts the product's own claim: it calls SP1 verification *"defence in depth"*

§4.4's table says of **B-1** (the deal's committed code): *"what breaks if it is the only one:
**nothing** — this is the load-bearing barrier"*, and concludes **"B-1 is the load-bearing one.
B-2 and B-3 are defence in depth."**

That cell is false. If B-1 were the only barrier, the escrow would pay out on whatever a
buyer-named contract returned, with no proof anywhere — which is precisely what **AC-3 test 2
demonstrates and asserts as correct behaviour** (`:826-833`: deal B is funded against a sham
`AlwaysReproduces` and *"submitting the same garbage settles to the seller"*). B-1 answers *"who
chose the judge, and can a settler change it"*. **B-2 is what makes a payout mean anything**, and
B-2 is the entire product (`CLAUDE.md`: *"決済権限は「proof が検証される」ことから来る"*).

009 then instructs later rounds off this inversion — *"this document does not rely on the
cryptographic separation of the two domain tags for anything"* — and §11(4) requires `CLAUDE.md`'s
verified-facts block to be rewritten in the same commit. A shipped sentence built on "B-1 is
load-bearing" would describe a different product.

**Repro / test:** AC-3 test 2 is itself the repro; it is already specified and already asserts the
payout. Nothing needs to be written.

**Remedy (round 2, text only):** swap the roles in the table — B-2 is load-bearing for
*soundness*, B-1 is load-bearing for *who selected the adjudicator*, B-3 for *which execution* —
and say plainly that B-1 alone would settle on unverified bytes.

**Codex reported this as a BLOCKER ("a buyer can select an outcome-deciding program with their
key"). I reject that severity**: the capability is not new. `docs/specs/003-key-gauntlet.md:512`
already records that the BUYER may *"choose which deployment to fund, and therefore its bytecode,
verifier, vkey and `refundDelay`"* (G-29/G-33/G-37). 009 moves that choice from *which escrow
address* into *a field in the calldata* — same power, more legible, and disclosed as L-7 and
INV-11. What is genuinely wrong is the §4.4 text, and that is MAJOR.

---

### 6. [MAJOR] `docs/specs/009-cross-vm-settlement.md:1178-1181` (L-7) — *"a buyer who commits a sham verifier loses their own money and nobody else's"* is false for a pooled escrow holding an inexact ERC-20

009 keeps the discarded `transferFrom` boolean (N-5, `:37-40`) and adds no balance-delta check, so
`fund` books `amount` regardless of what the token actually moved; §7's AC-1 test 1 and AC-6 test
3 establish that **one escrow instance pools several deals' balances**. Before 009 an attacker had
to produce a real Groth16 proof under the one deployed verifier to settle their own bogus deal;
after 009 they deploy a ten-line sham and name it at `fund`. Codex's reproduction (adopted):

- a fee-on-transfer token where `transferFrom(100)` credits the escrow 90, returns `true`;
- victim funds a 100-unit deal → escrow holds 90 against a recorded 100 claim;
- attacker funds a 100-unit deal naming `AlwaysReproduces` → escrow holds 180;
- attacker settles their own deal for 100 → escrow holds 80 against the victim's recorded 100.

No false-returning token is required; a false-returning `transferFrom` makes it worse (the deal is
booked with **nothing** pulled). AC-6's mock is an exact token and cannot see it.

The code fix is `003`'s (N-5, ruled in `003` r1). **What is 009's is the sentence**: 009 ships L-7
into `zk-verdict/README.md` via AC-11, and as written it is untrue.

**Remedy (round 2, text; the test is optional):** restate L-7 as *"…loses their own money and
nobody else's **provided the token debits exactly `amount` on `transferFrom`; the escrow does not
check that, and its balance is pooled across deals, so an inexact or false-returning ERC-20 lets a
sham-verifier deal reach another deal's tokens — the accounting fix is `003`'s"*, and add it as a
new limitation. If cheap, AC-6 gains one fee-on-transfer mock test; I do not require it.

---

### 7. [MAJOR] `docs/specs/009-cross-vm-settlement.md:496`, `:514-517`, `:1187-1189` — T-7 is declared unreachable "on every EVM this project targets", which is a claim above 009's tier, and the consequence of it firing is permanent loss

§5.2 T-7 is annotated *"unreachable, see §5.3"*; §5.3 says *"T-7 is unreachable on any chain where
deployed runtime code is immutable, **which is every EVM this project targets**"*; L-8 says it is
*"evidence of nothing"*; and §7.5 declines an AC because *"its precondition cannot be produced on
the target chains"*.

Under EIP-6780 (Cancun), `SELFDESTRUCT` **does** delete the account when the contract was created
in the same transaction. A factory can, in one transaction: create a killable verifier, call
`fund` with its then-live codehash (every `fund` guard passes), and destroy it. Afterwards
`d.verifier.codehash == 0 != d.verifierCodeHash`, T-7 fires on every `settleWithProof`, and with
N-3 (no timeout, `:31-33`) the deal is **permanently unsettleable** — the seller who did the work
gets nothing and the money is stranded. 009 also targets chains beyond mainnet (`AGENTS.md` §3
tasks 005 Arc, 006 Hedera); no evidence is offered for the universal quantifier over them.

**Codex's proposed Foundry reproduction is rejected — I ran it and it does not reproduce.** In
`forge 1.7.1` the account deletion is not observable inside the test body: created + destroyed in
one test function, `address(k).codehash` is **unchanged** and `address(k).code.length == 129`,
under `evm_version` `osaka` **and** `shanghai` alike. So this cannot be turned into a 009 AC, and
an implementer told to "add a test for this" would ship a test that passes for the wrong reason.
The finding stands as a **consensus-level** fact about the target chains, not a local one.

**Remedy (round 2, text only, no test):** replace the three sentences with *"T-7 is not reachable
at 009's tier and no AC asserts it fires. On chains implementing EIP-6780 a same-transaction
create-fund-destroy sequence makes it reachable; combined with N-3 the deal is then permanently
unsettleable. 009 neither demonstrates nor closes this"*, and add it to §9 as a limitation.

---

### 8. [MAJOR] `docs/specs/009-cross-vm-settlement.md:375-395` (§3.6) — the tightening argument is correct about check 4's predicate and false about its conclusion

§3.6's set argument is **sound as stated**: I checked it and every tree accepted by
*"0 `constructor`, 0 `immutable`"* was accepted by the old *"the constructor body has no
`= msg.sender`"* (vacuously), and trees with a constructor are now rejected. **The accepted set
does strictly shrink.** That half of OQ-6.2 is confirmed, not overturned.

What is false is the sentence it draws from it: *"every consumer of that line, including the
founder's pre-commit ritual and `003`'s harness, is unaffected."* After 009 the contract acquires
a dispatch into an address held in a mapping, and **the build condition gained no coverage of it
at all**. Two measured demonstrations that `bash scripts/no-keys.sh` exiting 0 no longer carries
the meaning `AGENTS.md` §0 assigns it:

- **the comment stripper is now load-bearing and is defeatable** (Codex's example, verified):
  `scripts/no-keys.sh:29-30` applies `sed -e 's://.*::' -e 's:/\*.*\*/::'` per line, so
  `printf '%s\n' 'string constant MASK = "//"; constructor() {}' | sed -e 's://.*::'` yields
  `string constant MASK = "` — valid Solidity with a constructor, and the token is gone. Check 4's
  entire new content is two token counts over that body. (A line bracketed by `/*` … `*/` does the
  same, greedily.) **AC-7a catches both** (it requires zero `/*`, zero `*/`, and zero quotes after
  stripping), but `AGENTS.md` §6's commit ritual runs `no-keys.sh` and nothing else.
- **check 2 matches names, not selectors**, so a same-named overload is invisible to it
  (`grep -oE '\bfunction +…' | sort -u` emits `settleWithProof` once). 009 discloses only the
  weaker half of this gap in N-8/OQ-5 (a *widened* signature); an *added* overload is a second
  money-moving surface. See also finding 4, which is the same blindness for `fallback`/`receive`.

**Codex reported the overload as a BLOCKER claiming "AC-1…AC-6 still pass". That is rejected with
evidence:** with an overload present, `escrow.settleWithProof.selector` in AC-3 test 1 does not
compile — `Error (6675): Member "settleWithProof" not unique after argument-dependent lookup` —
so the whole `forge` suite is red and 009's gate **does** catch it. Only the pre-commit ritual
does not.

**Remedy (round 2):** keep the tightening; correct the "every consumer is unaffected" sentence;
port AC-7a's guard (zero `/*`, zero `*/`, zero quotes after stripping) into `no-keys.sh` so
check 4's own observer cannot be blinded. That last part is a tightening and permitted; whether
`no-keys.sh` should also gain the entry-point closure of finding 4's 7h is **OQ-A below**, because
`008` is editing the same script this week.

---

### 9. [MAJOR] `docs/specs/009-cross-vm-settlement.md:606-616` (§7.0 sandbox inventory) vs `:632-634` (§7.1) — AC-10 cannot run as specified

§7.1: *"the manifest (parsed by `zk-verdict/scripts/ac009.sh` from this file)"*. §7.0's Location
rule: every 009 script derives its targets from `$(dirname "$0")` *"and from nothing else: no
target argument, no environment override, no absolute path, no `git rev-parse`"*. §7.0's sandbox
inventory lists `scripts/no-keys.sh`, `zk-verdict/scripts/*`, the contracts tree, the `lib`
symlink and four documents — and **not** `docs/specs/009-cross-vm-settlement.md`.

So inside `$S`, `ac009.sh` resolves its manifest to `$S/docs/specs/009-cross-vm-settlement.md`,
which does not exist, and cannot reach the repository copy without violating the Location rule.
AC-10's step 1 — *"assert the **clean** copy passes the target rows (the control)"* — therefore
fails on every mutant, before any patch is applied. Worse for a careless implementation: if the
control step is skipped, every row exits non-zero and all twelve mutants are scored as
**detected** for the wrong reason.

**Repro:** `bash zk-verdict/scripts/ac009-selftest.sh` — the M-1 clean-copy control exits non-zero
with the manifest file missing.

**Remedy (round 2):** add `docs/specs/009-cross-vm-settlement.md` (and explicitly
`zk-verdict/scripts/xvm.pinned`, `xvm.base.json` and the mutants directory) to §7.0's inventory,
and state the location-derived path `ac009.sh` uses to reach it. Independently found by me and by
Codex.

---

### 10. [MAJOR] `docs/specs/009-cross-vm-settlement.md:91` — *"009 does not require `003` or `008` to be re-reviewed for any of this"* is false for `003`

009's §1.3 reduces the `003` collision to one row (a constructor-set `refundDelay`, OQ-1). Reading
`003` shows the contract rewrite reaches much further:

- `docs/specs/003-key-gauntlet.md:1382` — **check 8** pins *"the left-hand side of every assignment
  inside the constructor body ∈ `{verifier, refundDelay}`, and its right-hand side is exactly the
  corresponding constructor parameter"*. After 009 there is no constructor, so check 8 watches
  nothing — R-9's exact shape, in `003`'s own vocabulary.
- `:512` and `:515` — the ROLE table's DEPLOYER row (*"choose `verifier` and `refundDelay` at
  construction"*) and the BUYER row both describe an escrow 009 deletes.
- `:908` **G-37** (a look-alike escrow with the genuine verifier but different bytecode) and
  `:904` **G-33** are keyed on deployment-time parameters that no longer exist.
- `:560` and `:4096` — `003`'s five-part deployment check reads the escrow's `verifier`; 009
  removes the `verifier()` getter entirely (`forge inspect RecknZkEscrow methodIdentifiers --json`
  today lists `"verifier()": "2b7ac3f3"`; §3.3 has no such member).

None of this blocks 009 — `AGENTS.md` §7 (founder ruling 2026-09-05) says `003` is **not** to be
restarted and is out of the 9/9 gate — but the flat sentence at `:91` is what would let a founder
rule OQ-1 without seeing its real cost. **Remedy:** replace it with an inventory of what `003`
inherits, and route it through OQ-1.

---

### 11. [MINOR] `:1104-1106` (§7.7) — *"Two of 009's sixteen tests use a mock verifier … or a sham verifier"* then enumerates four (AC-6 test 2, AC-3 test 2, AC-4 tests 1 and 2). §7.7 is the section whose job is stating the boundary of the Solana claim; the count must be four.

### 12. [MINOR] `:1005-1008` (AC-7d) — the access sites are cited as *"at `:103`, `:109`, `:111` and twice at `:116` **on the file of §3.3**"*. Those are today's line numbers (verified correct against the current `RecknZkEscrow.sol`); §3.3's file is longer and its lines differ. Cite them as today's file or drop them — the multiset itself (`v.dealBinding` ×1, `v.outcome` ×3, `v.traceHash` ×1 = 5; 4 unread) is **correct** and I verified it mechanically against §3.3.

### 13. [MINOR] `:1200` (§8.1) — the `RecknZkEscrow.t.sol` row says only *"its four existing tests call `fund` with two more arguments"*. The file also has **three** `new RecknZkEscrow(verifier)` call sites (`:52`, `:70`, `:121`) which must become `new RecknZkEscrow()`. Say so, so the diff is predictable.

### 14. [MINOR] `:1197-1215` (§8.1) — the file table omits `zk-verdict/scripts/surfaces.pinned`, although §1.3 row 1 commits 009 to re-pinning it in the same commit. §8.1 claims to be the whole file list. (Partial adoption of Codex finding 7; Codex's stronger claim — that 008 stays red until 009 re-pins — is rejected, §1.3 already handles it.)

### 15. [MINOR] `:640` and `:1039-1049` (AC-9) — the evidence line `{B}+16 tests listed and ran, 0 skipped` reads as "everything actually ran", but `forge` reports an early-`return` fixture gate as `Success`, not `Skipped`. Seven such gates exist today (`RecknReexecVerdict.t.sol` 2, `RecknSvmVerdict.t.sol` 2, `RecknVerdictVerifierFixture.t.sol` 2, `RecknZkEscrow.t.sol` 1); 009's own file is correctly exempt because it uses `vm.readFile` and AC-9's first clause bans bare `return;` there. 009 cannot assert 0 gates directory-wide without depending on `008` landing, so **reword the evidence** rather than adding the clause.

---

## Rejected findings

- **Codex finding 1, severity BLOCKER** — *"a buyer can select an outcome-deciding program with
  their key at funding time"*. Adopted in substance and **downgraded to MAJOR** (finding 5):
  the capability is not introduced by 009. `docs/specs/003-key-gauntlet.md:512` already assigns
  the BUYER *"choose which deployment to fund, and therefore its bytecode, verifier, vkey and
  `refundDelay`"* (G-29/G-33/G-37), and 009 discloses it as L-7 and INV-11. What is defective is
  §4.4's barrier table, which is a text error.
- **Codex finding 2, the claim that the overload "passes those gates" and "AC-1…AC-6 still
  pass"** — false. Measured: a second `settleWithProof` overload makes AC-3 test 1 fail to
  compile with `Error (6675): Member "settleWithProof" not unique after argument-dependent lookup
  in contract Ov` (`forge build`, forge 1.7.1), so the whole `forge` suite is red. 009's gate
  catches it. The surviving half — `no-keys.sh:46` matching names, not selectors — is kept in
  finding 8.
- **Codex finding 4's reproduction** — the proposed Foundry test does not reproduce. Measured in a
  scratch project: a contract created and `selfdestruct`ed inside one test function keeps its
  codehash (`0x3b5fdcf8…` before and after) and `code.length == 129`, under `evm_version` `osaka`
  **and** `shanghai`. The underlying consensus fact is real, so the finding is adopted (finding 7)
  with the repro replaced by an EIP-6780 argument and an explicit "no AC is possible at this
  tier".
- **Codex finding 7, "008's AC-0b pins `RecknZkEscrow.sol`'s digest, so 008 is red until 009
  changes `surfaces.pinned`"** — 009 §1.3 row 1 already commits to re-pinning it in the same
  commit, using 008's own printed-value protocol. Only the §8.1 omission survives (finding 14).
  Codex also **missed** the two collisions that actually break 008 (finding 3).
- **Codex's "attacks that held": "the §3.3 assignment count is indeed seven"** — false; it is 9
  over 8 targets, demonstrated mechanically in finding 1.
- **Codex's "attacks that held": "the listed AC test names match the stated regex"** — false;
  `test_AC03_settleWithProof_has_no_adjudicator_parameter` does not, finding 2.

## Verified and could not break

Re-measured today, not carried from any earlier document:

- **E-3 / E-4 / E-5 / N-7.** `forge test --list --json | jq '[.[][][]]|length'` → `12`;
  `forge inspect RecknZkEscrow methodIdentifiers --json` → `"settleWithProof(bytes32,bytes,bytes)":
  "fdcef1bb"`; `storageLayout` → exactly one entry, `deals` at slot 0.
- **E-8.** nonexistent address `codehash == 0`; `vm.deal`-funded EOA `codehash ==
  0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == keccak256("")`. The
  `EMPTY_CODEHASH` constant in §3.3 is correct, and AC-5 test 1's second case is the real one.
- **E-9, and the question the payload asked about it.** Two instances of one contract with
  **different** immutables have **different** `codehash`; two with **equal** immutables have
  **equal** `codehash`. Since the deal commits the *address* as well, the pair still pins a unique
  adjudicator — nothing in the design depends on codehash being unique per address. §3.2's claim
  that one 32-byte value commits both of `RecknVerdictVerifier`'s immutables is correct.
- **E-10 / E-11 and INV-9.** A `view`-typed reference to a state-writing `verifyVerdict` reverts
  under STATICCALL with the sink at 0; the same target through a non-`view` interface succeeds with
  the sink at 1. AC-4's negative control is a reproduction of a real pair, not a prediction.
  *(One implementation note for stage=impl: if `WritingVerifier` writes through a low-level
  `.call` and swallows the failure, the STATICCALL does **not** revert and AC-4 test 1 silently
  inverts. I measured this. The helper must propagate — a high-level `s.bump()`.)*
- **§7.1 manifest arithmetic.** 12 rows / 12 ACs / no AC-8; 6 `forge` rows summing to 16;
  6 `script` rows, 5 carrying `{witness}`; 12 mutants covering 11 of 12 rows, AC-10 uncovered.
  All correct.
- **AC-7 clauses 7a, 7c, 7d against §3.3.** 0 `/*`, 0 `*/`, 0 quote-bearing lines after stripping;
  exactly 1 `mapping`; the verdict-member multiset 3/3 read (5 accesses) and 4/4 unread; exactly 1
  `RecknVerdictVerifier` token. Only 7f's counts are wrong (finding 1).
- **§10's "no literal of `008`".** Confirmed by grep: no digest, no suite total, no tag string,
  no field order, no width from `008` appears in 009. The `uint256` occurrences are the escrow's
  own pre-existing `amount`. **INV-10 also survives `008`**: 008 retypes four `VerdictPublicValues`
  members but renames none, so AC-7d's run-time parse of the struct block is unaffected.
- **§3.6's set argument itself.** Every tree accepted by the new check 4 was accepted by the old
  one; trees with a constructor are newly rejected; no previously-rejected tree is now accepted.
  The predicate is a strict tightening. (Its *conclusion* is not — finding 8.)
- **The fixture-swap defence.** The two routes are genuinely separate for M-5: `xvm-pins.sh`
  (AC-0b) reads the fixture bytes and cannot see a mutated test file, so only AC-2 test 4 catches
  M-5; M-6 (a mutated fixture) is caught by both. The spec assigns them correctly.
- **§3.5's no-op question and INV-1/INV-6.** `settleWithProof` remains permissionless, has no
  `msg.sender`, and the state guard precedes every external call. I found no path by which a
  settler influences `d.verifier`.

---

## Deferred

None. Every finding above is either inside 009's cut or is a sentence 009 itself ships; nothing
was moved to `docs/decisions/`. Finding 6's **code** fix (the discarded `transferFrom` boolean and
the missing balance-delta check) remains `003`'s, per N-5 and `003` r1 — only the false sentence
is 009's, and that is what round 2 must fix.

---

## Round 2 — closing order (`009` must be APPROVE'd or force-implemented by end of 2026-09-07, `AGENTS.md` §7)

**Do these four first; they are the ones that make the spec unbuildable or make the 9/9 gate
unreachable.**

1. **Finding 3** — move 009's mutants out of `zk-verdict/scripts/mutants/`; rewrite §10/OQ-6's
   independence claim in both directions. *Without this, "008 and 009 both green" is impossible
   and the checkpoint fails for a filename.*
2. **Finding 1** — 7f's counts → `9 assignments over 8 targets`, LHS set gains `d` and `v`.
3. **Finding 2** — rename the AC-3 test.
4. **Finding 4** — AC-7 gains clause 7h (entry-point closure) + mutant M-11; §7g's residual
   rewritten.

**Then the text corrections — all cheap, none requiring a new mechanism:**

5. Finding 5 (§4.4's barrier table), 6 (L-7), 7 (T-7 / §5.3 / §7.5 / L-8), 8 (§3.6's conclusion +
   port AC-7a's stripper guard into `no-keys.sh`), 9 (§7.0's sandbox inventory), 10 (§1.3's `003`
   sentence).

**Then the five MINORs (11–15).** If time runs short on 9/7, items 11–15 may ship as disclosed
open items; items 1–10 may not.

---

## Open questions for the founder

- **OQ-A (new, and it blocks part of finding 4/8).** Finding 4's remedy is naturally *two* edits:
  one in 009's own gate (AC-7's 7h) and one in `scripts/no-keys.sh` check 2 (close the entry-point
  set so `fallback` / `receive` cannot hide). The second is a **tightening** and therefore
  permitted in principle, but `008` is editing the same script this week (it adds check 5) and
  009's own OQ-5 recommends against two tasks touching one check in one week. **Ruling needed: may
  009 put the entry-point closure into `no-keys.sh`, or does it stay in AC-7 only until `008`
  lands?** My recommendation: **put it in `no-keys.sh`**. `fallback` is a live money path that the
  founder's pre-commit ritual currently cannot see, and 009 is the task that rewrites the contract
  the ritual guards. AC-7 alone does not run before a commit.
- **OQ-1 (009's, answered).** 009's recommendation — keep the check-4 tightening, let `003` make
  `refundDelay` a `constant` or a per-deal field — is **correct, and the conflict is now smaller
  than 009 states**: `AGENTS.md` §7's 2026-09-05 ruling takes `003` off the 9/9 gate and says it
  is not to be restarted. So there is no live `003` draft to break. But finding 10 shows the cost
  is larger than §1.3's one row — `003`'s checks 7b/8, its five-part deployment check, G-33/G-37
  and its ROLE table all key on the escrow constructor 009 deletes. Rule on OQ-1 with that
  inventory in front of you, not with the single `refundDelay` row.
- **OQ-6 (009's, answered — the answer is "yes, but not for the reason 009 gives").** 009 **is**
  substantively independent of `008`: INV-10 holds (verified — 008 retypes struct members, renames
  none, and the escrow reads no numeric member), and no `008` literal appears in 009. So starting
  009's implementation in parallel is safe **on the technical axis**. It is **not** safe on the
  harness axis until finding 3 is fixed: as specified, 009 lands and `008`'s AC-11 and AC-13 both
  go red. Fix finding 3 first, then parallel work is fine.
- **OQ-4 (009's, unanswered by 009 and worth answering).** 009 mechanises "the anchoring caveat
  travels with the claim" only inside `zk-verdict/README.md` (AC-11, within 25 lines) and
  explicitly declines to legislate the demo script and the submission text. **Those are the two
  surfaces where L-1 actually matters** — the 2026-09-04 application sentence is the thing being
  demonstrated. 009 is right that they are not its files; the founder should decide whether the
  same adjacency rule binds `reckn-demo` and the submission text.
- **OQ-2 / OQ-3 / OQ-5 (009's)** — I found no reason to overturn 009's recommendations on any of
  the three. OQ-5's gap (check 2 matches names, not signatures) is real and is now **larger** than
  009 states, which is why it reappears as OQ-A.

**Honesty check, run explicitly.** 009's three most self-incriminating statements — *"this is a
dispute escrow, not a pre-payment escrow"* (§3.4), **L-1** (the committed `bank_hash` is not proven
to be a real cluster's), and **L-10** (a stubbed `ac009.sh` is detected by nothing) — are all
disclosures of things 009 genuinely cannot close at its tier, not alibis for holes it could have
closed. I looked for the Veil-lab pattern (a violation confessed and absolved in the same
paragraph) and did not find it. **L-7 and L-8 are the two exceptions**, and both are findings above
(6 and 7): they are written in the register of honest limitations while stating something false.

Six of the fifteen findings are in the "flatters the proposal" direction (1, 3, 5, 6, 8, 10) and
none in the KILL direction, which matches the prior on this repository. `009` is a good spec with
a small number of load-bearing arithmetic and cross-spec errors; none of the four BLOCKERs is
architectural, and all four are closable in one round.

VERDICT: CHANGES

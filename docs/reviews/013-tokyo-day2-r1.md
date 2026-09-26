# Review 013 tokyo-day2 round 1

Payload:   `/tmp/reckn-payload-013-tokyo-day2-r1.md`
Codex raw: `/tmp/reckn-codex-013-tokyo-day2-r1.md`
Scope:     `git log --oneline a5b6cd1..HEAD` (35 commits, 2026-09-26), all written by Claude,
           none previously reviewed. One Codex pass (`codex-cli 0.152.1`, `-s read-only`).
Method:    every finding below was re-derived against the files or against a **Sepolia fork**
           (`anvil --fork-url …publicnode.com`, block 11,783,986 / 11,784,011 / 11,784,018).
           No transaction was sent to Sepolia. `renounce.sh` was never run.
           Gate mutations were planted in an isolated copy via `NOKEYS_ROOT`, never in the tree.

---

## What was measured and is TRUE (stated first, because the blockers below are about gates,
## not about the two transactions)

All on a Sepolia fork, both revokes executed as `reckn-agent`:

| | |
|---|---|
| `revokeRootRoles(ALL, agent)` on the resolver | status 1, 39,137 gas; `hasRootRoles(ALL, agent)` → false |
| `revokeRootRoles(ALL, agent)` on the registry | status 1, 30,066 gas; `hasRootRoles(ALL, agent)` → false |
| partial success? | no. `_revokeRoles` does `currentRoles & ~ALL`; `ALL_ROLES` covers all 64 nybbles, so the map goes to 0 in one write. `resolver.roleCount(0)` 2×ALL → 1×ALL, `registry.roleCount(0)` 1×ALL → 0 |
| the adapter's whole path, **after both revokes** | `grantSetterRoles` from `0xA6966f9f…` ✓ 89,420 gas → buyer `setText` ✓ 71,207 gas → `UniversalResolverV2.resolve` returns the record ✓ → `revokeRoles` ✓ 38,524 gas → buyer `setText` now reverts `0x4b27a133` ✓ |
| does the adapter need root on the REGISTRY? | **no.** The line above ran with registry root already at zero |
| UUPS proxy escape hatch | none. `0x740e02cE…` is an EIP-1167 clone → ENS `VerifiableProxy` `0x7e98c31a…` → impl `0x14f09fd0…`. Post-renounce `upgradeToAndCall` reverts `EACUnauthorizedAccountRoles` for the agent, for a stranger **and for the VerifiableFactory `0x118bc31a…`**. Upgrade authority lives entirely inside the resolver's own EAC, where only the adapter will hold it |
| third root holder? | **none today.** `resolver.roleCount(ROOT_RESOURCE)` = exactly `2 × ALL_ROLES` (agent + adapter), `registry.roleCount(ROOT_RESOURCE)` = exactly `1 × ALL_ROLES` (agent). Nobody else |
| name survives | `renew(agent, …)` from the agent still succeeds after registry root is gone |

So the two transactions do what they say and do not break the record surface. The blockers are
elsewhere.

---

## Findings

1. **[BLOCKER]** `scripts/no-keys.sh:293` (check 6, 267–331) — **check 6 re-opens the inheritance
   hole that check 2 was tightened to close.** The contract is isolated with
   `awk -v c="^contract $name" '$0 ~ c {f=1} f'`, i.e. from the `contract SettlementRecord` line to
   EOF. Everything declared **above** that line is invisible to 6a, 6b and 6c alike. Check 2 forbids
   inheritance, a second contract and `using` for exactly this reason (`AGENTS.md` §0: *"継承したメンバーは
   `contract` 行より上に宣言されるので、それを許すと検査領域そのものが不完全になる … 実測"*). Check 6
   forbids none of the three.
   **CONFIRMED.** Repro (isolated copy, tree untouched):
   ```sh
   cp -r <the four files> /tmp/c
   perl -0pi -e 's/^contract SettlementRecord \{/contract Steward {\n  address public steward;\n  modifier onlySteward() { require(msg.sender == steward); _; }\n  function seize(address r_, bytes calldata n_, string calldata k, string calldata v) external onlySteward {\n    IPermissionedResolver(r_).setText(n_, k, v);\n  }\n  fallback() external { }\n}\n\ncontract SettlementRecord is Steward {/m' /tmp/c/tokyo-2026/src/SettlementRecord.sol
   NOKEYS_ROOT=/tmp/c bash scripts/no-keys.sh   # → exit 0
   ```
   Output: `✓ 6a … no owner/admin/…`, `✓ 6b … 0 fallback, 0 receive, 0 modifier`,
   `✓ 6c SettlementRecord.open/close`, `✓ the claim holds`. The adapter holds **all** root roles on
   the resolver, so an inherited `seize` gated on one address is a resolver — the thing the whole
   submission says does not exist. `no-keys-control.sh` plants five shapes and none is this one.

2. **[BLOCKER]** `scripts/no-keys.sh:39` and check 6's missing analogue of check 3 — **a
   constructor-set `immutable` owner gating `open()` passes the entire gate.**
   **CONFIRMED.** Repro (isolated copy):
   ```sh
   # in /tmp/c/tokyo-2026/src/SettlementRecord.sol
   #   + address public immutable owner;
   #   + owner = msg.sender;                       (in the constructor)
   #   + require(msg.sender == owner, "not owner"); (first line of open)
   NOKEYS_ROOT=/tmp/c bash scripts/no-keys.sh   # → exit 0, "✓ the claim holds"
   ```
   Two independent reasons it survives, both worth fixing:
   - **The bare-`owner` alternative in the vocabulary is a dead branch.** Line 39 is single-quoted,
     so `\\bowner\\b` reaches `grep -E` as a literal backslash + `bowner` + backslash + `b`.
     Measured: `printf 'address public owner;' | grep -E "$forbidden"` finds **nothing**, while
     `admin` is caught. `scripts/no-keys-control.sh:57-58` states the opposite in prose —
     *"The vocabulary was tightened to include bare `owner` … so the name alone now trips as well"*.
     **That sentence is false**, and no control row tests it (row 1 plants `admin_`, which is caught
     by 2b/3, not by the vocabulary).
   - **Check 6 never looks inside an allowed function.** Checks 3 (no caller-identity gating) and 4b
     (no constructor / no `immutable`) are escrow-only, and the adapter legitimately has both a
     constructor and immutables, so nothing constrains what `open` may require of `msg.sender`.
   → **The author's least-confident point 3 does not survive.** A privileged construct passes 6a,
   6b and 6c, by two different routes.

3. **[BLOCKER]** `tokyo-2026/scripts/take-check.sh` (whole file; the gap is beat 2 at :68-76 and the
   absence of any registry row) — **the rig reports "Record." on a chain state where the central
   claim of beat 2 is false.**
   **CONFIRMED by execution.** On a fresh Sepolia fork with **only step 1 of `renounce.sh`** applied
   (resolver root revoked, registry root left with the agent):
   ```sh
   anvil --fork-url https://ethereum-sepolia-rpc.publicnode.com --port 8547
   cast rpc anvil_impersonateAccount 0xfa2582ec…  --rpc-url http://127.0.0.1:8547
   cast send 0x740e02cE… "revokeRootRoles(uint256,address)" 0x1111…1111 0xfa2582ec… --unlocked …
   TAKE_RPC=http://127.0.0.1:8547 bash tokyo-2026/scripts/take-check.sh
   ```
   → **14/14 green, exit 0, "every load-bearing line is true right now. Record."** — including
   `✓ the agent's write reverts EACUnauthorizedAccountRoles`.
   In that exact state, measured on the same fork:
   ```
   cast call 0x1Ad360D9… "setResolver(uint256,address)" $(cast keccak agent) 0x…dEaD --from 0xfa2582ec…
   → 0x        (succeeds)
   ```
   The agent can repoint `agent.reckn.eth` at a resolver it wholly controls and serve any text it
   likes. `take-check.sh` **never reads the registry**, and beat 3 (:78-87) asserts only that *some*
   resolver returned a string starting `reproduced` — it does not pin which resolver answered.
   So the two facts the video asserts ("the agent cannot write its own record"; "this record came
   from the settlement") are both falsifiable while the gate is green.
   → **The author's least-confident point 2 does not survive.**
   This is also the ordering hazard in `renounce.sh`: resolver-first means an interrupted run lands
   in exactly this state. (`renounce.sh` step 3 does read both back, so the *script* would catch it
   if it gets that far; under `set -e` a failing `cast send` at step 2 exits before step 3, and
   nothing afterwards can tell.)

4. **[MAJOR]** `tokyo-2026/scripts/renounce.sh:40-48` — **the precondition list is sound for the
   adapter path (measured, see the table above) but does not close the claim it is making.** It
   never asserts:
   - **that nobody else holds root.** The script says *"throw the last key away"*; it verifies that
     one named address loses root. The property is directly measurable and is true today:
     `resolver.roleCount(0) == 2 × ALL_ROLES` and `registry.roleCount(0) == 1 × ALL_ROLES`. Assert
     those before, and `1 × ALL_ROLES` / `0` after. Codex raised this as a BLOCKER on a hypothetical
     third holder; the hypothetical is false today (measured), so it is the *check* that is
     incomplete, not the state.
   - **that this adapter is wired to this deployment.** `nameDotted()` and `WRITE_WINDOW()` are two
     constants. `adapter.resolver()` and `adapter.escrow()` are the load-bearing wiring and are
     unchecked. (Both correct today: `0x740e02cE…` / `0x6d6a9deb…`.)
   - `renounce.sh:60,70` also prints the transaction `status` without asserting it. Step 3's
     readback covers this; the print is a decoy that reads like a check.

5. **[MAJOR]** `tokyo-2026/scripts/renounce.sh` — **an irreversible consequence that is not on the
   list: after tonight the Uniswap v4 pool is shut forever.** Measured on Sepolia:
   ```
   adapter.opened(0x214524e3…) = true    adapter.closed(0x214524e3…) = true    (the hook's deal)
   adapter.opened(0x48a603c2…) = true    adapter.closed(0x48a603c2…) = true    (the join deal)
   adapter.open(0x214524e3…, …)  → reverts AlreadyOpened (0x1da42b26)
   hook.isOpen() = false     hook.recordKey() = "reckn:job:agent.reckn.eth:214524e3…"  (fixed at construction)
   ```
   `opened[dealId]` never resets, the hook's key is immutable, and a new deal yields a different key
   the hook does not read. Today the agent, as root, can still write that key by hand — that is the
   only remaining way to make `isOpen()` true. **At 21:30 that ends permanently.** Beat 3's record
   (`reproduced block=11782541 verifier=0xe0de264d…`) is stored and survives; beat 5's is not, and
   the last thing beat 5 did on chain was clear it. If anything in the submission invites a judge or
   a booth visitor to re-run beat 5 live, decide that before the renounce, not after.

6. **[MAJOR]** `tokyo-2026/scripts/take-check.sh:116` — the frame rows test `[[ -s … ]]`. A non-empty
   file of any kind passes. `DEMO.md` §5 item 1 is *"every number on screen is from the take being
   recorded"*, and this is the row that is supposed to enforce it; it cannot distinguish a fresh
   frame from one left over from the take before the adapter was redeployed. Nothing ties a frame to
   the transaction hash it depicts. **CONFIRMED by code path** (`-s` is true for any non-empty file;
   not exercised, because exercising it means writing into the repo). Raised by Codex; kept.

7. **[MINOR]** `zk-verdict/scripts/sepolia-receipts.sh:29-30` — the structural gather is a net
   improvement for clause (b) (it now demands that all 54 recorded hashes be linked, including the
   six in `supersededJoin0925`, and it passes: `54 linked … 54/54 recorded tx linked`). It is
   **weaker in one direction**: clause (a) now accepts a link to a *superseded* transaction as a
   valid receipt, so a page linking the 09-25 broken-adapter `joinWrite` instead of the 09-26 one
   passes. Those six hashes are currently linked only in `docs/tokyo-2026/RECEIPTS.md`, in a
   superseded context, so nothing is wrong today. Clause (c) is still named by section
   (`.eventWork[]`), so a refusal that moves to another section stops being checked at all.

8. **[MINOR / resolved]** `zk-verdict/scripts/zk-e2e.sh:97-106` — **the second fix is correct.**
   `set +e; forge_out=$( cd … && forge test -vv 2>&1 ); forge_status=$?; set -e` captures forge's own
   status before any pipeline exists, and the later `grep … || true` cannot overwrite it.
   **CONFIRMED** by reproducing the pattern against a command that exits 3: `captured status = 3`,
   while the same value under the old `| grep … || true; ${PIPESTATUS[0]}` shape is 0. It also
   survives `forge` failing to start (non-zero from the subshell) and a failing `cd`.

9. **[MINOR]** `tokyo-2026/scripts/.tcm.sh` — an untracked, un-gitignored **hidden copy of
   `take-check.sh`** with beat 4's transaction hash altered by one character (`…bae74d6` → `…bae74d7`),
   mtime 2026-09-26 14:01. It predates this review. A dotfile in `scripts/` that no gate reads and
   git does not track is the kind of thing that ends up in a `git add -A`. Delete it or move it to
   `/tmp`. (It is the only reason `git status` was not clean when this review started.)

---

## Rejected findings

- **Codex finding 1, the BLOCKER framing** — *"A third root holder can survive both revocations,
  retain `ROLE_UPGRADE` on the UUPS resolver … or write records directly."* Rejected as stated; the
  premise is false on chain. Evidence: `resolver.roleCount(ROOT_RESOURCE)` =
  `0x2222…2222` = exactly `2 × ALL_ROLES` = two assignees per root role (agent + adapter);
  `registry.roleCount(ROOT_RESOURCE)` = `0x1111…1111` = exactly one (agent). There is no third
  holder to survive. Codex's repro begins with `resolver.grantRootRoles(ALL, attacker)`, i.e. it
  manufactures its own premise. The *check-completeness* half is real and is kept as finding 4.
- **Codex finding 1, the proxy sub-claim** — *"retain `ROLE_UPGRADE` on the UUPS resolver … replace
  the resolver implementation."* Rejected. Measured on the fork **after both revokes**:
  `upgradeToAndCall(0x14f09fd0…, 0x)` reverts `EACUnauthorizedAccountRoles (0x4b27a133)` from the
  agent, from `0x…dEaD`, and from the VerifiableFactory `0x118bc31a…`. Upgrade authority is
  `onlyRootRoles(ROLE_UPGRADE)` inside the resolver's own EAC; after tonight only the adapter holds
  it, and the adapter has no code path that calls it.
- **Codex's line numbers** — `take-check.sh:136-142` does not exist (the file is 126 lines; the frame
  loop is 111-117). `DEMO.md:278-280` is off by a few lines. The findings survive; the citations do
  not. Corrected above.
- **Codex: "no local→Sepolia or Sepolia→mainnet tier escalation."** Accepted; I did not find one
  either. Finding 5 is the adjacent risk: a *recorded* transaction being read as a property of the
  live system. `take-check.sh` beat 5 asserts three historical receipts and the hook's flag bits,
  and nothing about the hook's current state — `hook.isOpen()` is never read.

## Deferred

- None. Everything above is either in scope for tonight or a one-line addition to a gate.

---

## The three least-confident points

| | |
|---|---|
| 1. `renounce.sh`'s precondition list is complete | **PARTIALLY SURVIVES.** The four conditions are *sufficient for the adapter's write path* — proven, not argued: the full grant → write → resolve → revoke cycle runs on a fork with both roots already gone. They are **not** sufficient for the claim the script is making ("the last key"): findings 4 and 5. |
| 2. `take-check.sh` cannot go green on a false fact | **DOES NOT SURVIVE.** Finding 3 — 14/14 green, exit 0, on a chain where the agent can still repoint the name and write whatever it wants. |
| 3. check 6's "which functions can write" is closed by property | **DOES NOT SURVIVE.** Findings 1 and 2 — two different privileged constructs pass 6a, 6b and 6c with the gate at exit 0. |

---

## Is it safe to run `renounce.sh` tonight?

**The two transactions are safe. The script around them is not yet, and one decision has to be
made first.** Measured on a fork: both revokes succeed, nothing partial, the adapter keeps working
with registry root at zero, the name is still renewable, and no upgrade path survives — so the
irreversible part does not strand the record surface. Four changes before 21:30, none of which
touches a contract:

1. **Reverse the order — registry first, resolver second.** An interrupted run then leaves the
   agent holding resolver root, which is the one state `take-check.sh` beat 2 already reports RED.
   As written (resolver first), an interrupted run leaves the state in finding 3, which every gate
   in the repository calls green.
2. **Add two preconditions and one postcondition.** Before: `resolver.roleCount(0) == 2 × ALL_ROLES`
   and `registry.roleCount(0) == 1 × ALL_ROLES` (nobody else holds root), and
   `adapter.resolver() == RESOLVER && adapter.escrow() == ESCROW`. After (step 3): the same counts
   at `1 × ALL_ROLES` and `0`, not just `hasRootRoles(agent) == false`.
3. **Give `take-check.sh` a registry row** before it is allowed to print "Record." — at minimum
   `hasRootRoles(ALL, agent)` on `0x1Ad360D9…` is false, and beat 3 should assert *which* resolver
   answered, not only what it said.
4. **Decide about the hook, consciously** (finding 5). After tonight `0x68116b80…` never trades
   again. If that is acceptable, say so in `DEMO.md`; if the booth needs a live beat 5, write the
   hook's record **before** the renounce, while the agent still can.

Findings 1 and 2 are not blockers for the renounce itself — they are blockers for `no-keys.sh`
being allowed to say the claim holds, and they should be fixed in the same session, because the
control script currently asserts in prose a property the regex does not have.

VERDICT: CHANGES

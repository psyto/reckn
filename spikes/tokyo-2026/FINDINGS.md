# S1 findings — ENSv2 Permissioned Resolver, measured on Sepolia

**2026-09-21. Fork test against the deployed implementation
`0x14F09Fd05d4585759e54844DC9B00147131Cf243`. No deployment, no funded key, no permissions.**
Every line below is a run, not a reading. Run: `forge test --fork-url sepolia -vv`.

---

## ★ The finding that would have cost the most on the day

**The deployed Sepolia beta and `ensdomains/contracts-v2` main branch have different ABIs.**
Spec 013 §2.3 was written from the main branch on the same day and is wrong about two signatures:

| | main branch (read) | deployed on Sepolia (measured) |
|---|---|---|
| initialize | `initialize(address admin, uint256 roleBitmap, bytes[] setters)` | **`initialize((address,uint256)[] admins, bytes[] setters)`** |
| text write | `setText(bytes32 node, string key, string value)` | **`setText(bytes name, string key, string value)`** — DNS-encoded name, not a namehash |

Recovered by extracting `PUSH4` selectors from the runtime code and resolving them
(openchain signature database). Sourcify has no metadata for this address.

**A second trap inside the same finding**: `grantSetterRoles(bytes, address)` does **not** take a
name. Passing the DNS-encoded name reverts `UnsupportedResolverProfile(0x05616765)` — the first
four bytes of the name, read as a profile selector. **The first argument is the setter's
calldata**: you authorise *the call you want someone to be able to make*.

```solidity
bytes memory setter = abi.encodeWithSelector(IResolver.setText.selector, name, "job:1", "");
adapter.grantSetterRoles(setter, client);   // called BY A CONTRACT
```

## Answers to spec 013 §3.6

| # | question | answer |
|---|---|---|
| **Q1** | Can a contract hold the admin role and grant/revoke? | **YES.** `AdapterStub`, a contract, was the initial admin and successfully granted |
| **Q2** | What grants the adapter its admin role, and can that path be closed? | `initialize` takes a list of `(account, roleBitmap)`. **Root roles CAN be renounced**: `revokeRootRoles(ALL_ROLES, self)` from the adapter succeeded and left `roles(ROOT) == 0` |
| **Q3** | Does `EACMinAssignees` block revoking the last holder? | **Not yet measured** — the S1 cap test used the wrong `grantSetterRoles` shape and must be rerun |

## The claim, demonstrated

| step | result |
|---|---|
| agent writes its own record, before any grant | **refused** — `EACUnauthorizedAccountRoles` |
| adapter (a **contract**) grants the setter role for `job:1` to the client | **OK** |
| client writes `job:1` | **OK** |
| **agent writes `job:1` while the window is open for the client** | **refused** — `0x4b27a133`, resource `0xdf324b4b…`, roleBitmap `0x10`, account `0x…a9e7` |
| **client writes a *different* record (`other:key`)** | **refused** — `0x4b27a133`, resource `0xdcfb0dbf…`, roleBitmap `0x10`, account `0x…beef` |

**`roleBitmap` in both refusals is `0x10` = `1 << 4` = `ROLE_SET_TEXT`** — the constant read from
`PermissionedResolverLib` is confirmed against deployed bytecode.

**The last row is the important one.** The grant for `job:1` does not authorise `other:key`, and
the two resources differ. **Granularity is per-record, not per-name.** This is what makes the ENS
integration load-bearing rather than cosmetic: "who may write *which record*" is native.

## Smaller measured facts

- `ROOT_RESOURCE() == 0`.
- A holder of root roles (the adapter) can write directly; root is a real override, as reviewed.
- `getRecordId(keccak256(name))` returns `0`; `getRecordCount()` went `0 → 1` after the first
  write. **Record ids are not keyed by `keccak256(dns-name)`** — the derivation is still unknown,
  and the adapter needs it to *revoke*. Next measurement.
- The implementation is **UUPS**: an EIP-1167 clone reverts in `onlyProxy` because the ERC-1967
  slot is empty (210 gas, no revert data). A minimal ERC-1967 proxy works.

## What spec 013 must change

1. **§2.3** — mark the two signatures as main-branch readings that the deployment contradicts.
2. **§3.3/§3.4** — the window is opened with **setter calldata**, not a `(node, part)` resource.
3. **§3.6 Q3** — still open; add "how is a record id derived" as Q4, because **revoke needs it**.
4. The ENS explanation in the submission form should say **per-record**, which is now measured.

## Not done

- The assignee cap and whether revoke frees a slot (Q3).
- Anything at the **registry** level: the token-owner `setResolver` bypass from r1 B2 is
  untouched by this spike and remains the open half of the authority boundary.

---

# S1c / S1d — closing the window, and a correction to the spec

**2026-09-21, same fork harness.**

## The window closes (§3.3 stands)

`test_revoke_closes_the_window` **PASS**: client writes inside the window → adapter revokes →
the same client's second write is **REFUSED**. The mechanism of spec 013 §3.3 is demonstrated
end to end on deployed bytecode.

## ★ `decodeSetter` gives the resource — revoke needs no guesswork

`decodeSetter(bytes setter)` is a **view** function and returns the **resource**, the **role
bitmap**, and the record key:

```
decodeSetter(abi.encodeWithSelector(setText.selector, name, "job:1", ""))
  -> resource  0xdf324b4b…b00111e9
     roles     0x10                 (= 1 << 4 = ROLE_SET_TEXT)
     key       "job:1"
```

So the adapter closes the loop without reading logs or errors:

```
(res, role, ) = decodeSetter(setter);
grantSetterRoles(setter, buyer);   // open
...                                // buyer writes
revokeRoles(res, role, buyer);     // close
```

**This answers the open Q4 (record-id derivation) — it is not needed.** The resolver computes it.

## ★ CORRECTION — spec 013 §3.3's justification for revoking is wrong

§3.3 says: *"The revoke is not hygiene; it is forced by the mechanism"*, because a role holds at
most 15 assignees. **Measurement does not support that.**

- The second grant reverts with **`EACCannotGrantRoles` (`0xd1a3b355`), not `EACMaxAssignees`**.
- `roles(resource, adapter) == 0` — the adapter has **no role on that specific resource**. It can
  grant through `grantSetterRoles` (its own authority path) but cannot call `grantRoles` directly
  on a record resource where it holds no admin role.
- `getAssigneeCount` / `roleCount` / `roles` all returned `0x10` for one assignee. **These are
  nybble-packed bitmaps, not plain counts** — `0x10` is "one assignee in the nybble-1 slot", i.e.
  **count 1**. Nothing here was anywhere near 15.

**Therefore**: revoking is a **choice**, not a constraint. The honest sentence is *"a settlement
should create a right that ends, not a standing one"* — and the spec must stop claiming the cap
forces it. The `R-5` control arm built on "the 16th reverts" is measuring the wrong thing and
must be rewritten or dropped.

**This is the second time on this spec that a correct-sounding sentence sat on top of a mechanism
that does something else.** The first was `R-9`.

---

# S2 — can a hook read the record, and is v4 actually there?

**2026-09-21.**

## The record is readable on chain, synchronously

| path | result |
|---|---|
| `resolve(name, text(node,key))` **directly at the resolver** | **OK** — returned `"1"` |
| via `UniversalResolverV2` | REVERT `0x95c0c752` — **not** `OffchainLookup` (`0x556f1830`) |

**No CCIP-Read on this path**, so a contract — a v4 hook — can gate on the record. The
UniversalResolver revert is expected: the spike's name is not registered in the registry, so
there is no resolver to find. **The hook must read the resolver directly** (or resolve the
resolver address from the registry first). Measured, not assumed.

## Uniswap v4 is live on Sepolia

| contract | address | code |
|---|---|---|
| PoolManager | `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543` | 48,021 bytes |
| Universal Router | `0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b` | 39,083 bytes |

`BEFORE_SWAP_FLAG = 1 << 7` (`Uniswap/v4-core/src/libraries/Hooks.sol:38`) — a `beforeSwap`-only
hook needs bit 7 of its address set, so the address is CREATE2-mined.

## What 012 §2.3 does and does not forbid

It rules out **Universal Router as the *proven* execution**, because Permit2's signature path uses
`ecrecover`, which is on the guest's divergent-precompile list with equivalence unverified. **It
says nothing about using v4 or the Universal Router elsewhere in the product.**

So the two halves stand on separate, measured ground:

> **The job is delivered on v3 and proven (13,006,200 cycles, measured 09-08).
> The record it earns is the pass to a v4 pool (new, and the prize's named category).**

## Still unmeasured

- **The v4 build itself**: mining the hook address, initialising a pool with it, and a swap
  refused-then-accepted across the record. This is now the largest unknown.
- **The registry-level bypass** (token owner calls `setResolver`) — untouched.

---

# S3 — the v4 gate, measured end to end

**2026-09-21. Fork of Sepolia, against the real PoolManager
`0xE03A1074c86CFeDd5C142C4F04F1a1536e203543`.**

```
hook salt found at: 8653
hook: 0x00F6B7a999b7893E7d60939C87a9Ff60406d4080      <- low bits 0x0080 = BEFORE_SWAP_FLAG
pool initialized on the real Sepolia PoolManager
outer selector: 0x90bfb865   WrappedError(address,bytes4,bytes,bytes)   (ERC-7751)
  wrapped target: 0x00F6B7a9…4080                      <- asserted == our hook
  reason:         NoSettledRecord                      <- asserted
CONFIRMED: the refusal is our hook's NoSettledRecord
record written by the client
swap after record: SUCCEEDED
```

**The round trip works**: the same swap is refused before the record exists and passes after it
is written. The hook reads the ENS record **on chain, synchronously**, inside `beforeSwap`.

## What had to be got right, and would have cost hours on the day

- **Hook address mining.** `uint160(hook) & ALL_HOOK_MASK` must equal exactly `BEFORE_SWAP_FLAG`.
  Found at salt 8653 by brute force in the test — sub-second, no miner library needed. **The salt
  changes whenever the constructor args or the hook's code change.**
- **ERC-7751.** The PoolManager does not bubble the hook's error: it wraps it in
  `WrappedError(target, selector, reason, details)`. **A test that asserts on the outer selector
  proves nothing.** The `bytes4` field is the *hook function* being called (`beforeSwap`
  = `0x575e24b4`), and the error is in `reason`. Both were asserted here, and the first attempt
  at this test asserted the wrong field.
- **Types moved.** `SwapParams` and `ModifyLiquidityParams` live in `src/types/PoolOperation.sol`,
  not on `IPoolManager`; `afterSwap` returns `int128` and the liquidity hooks take `BalanceDelta`.
  Getting these wrong is a compile error, not a silent one — cheap, but it costs time.
- **v4-core needs no submodules** for the files used here (interfaces + types + Hooks), so a
  shallow clone is enough; its `lib/` can stay empty.

## The honest limit of this measurement

**No liquidity was provided.** The post-record swap "succeeded" as a no-op against an empty pool.
What is measured is exactly that **`beforeSwap` stopped refusing** — not that a swap moved tokens.
**Do not let the demo or the submission text say more than that** until a funded pool is run.

## What is now standing

| | measured on 2026-09-21 |
|---|---|
| a contract holds the resolver's admin role | ✓ |
| the settlement window opens for one named party | ✓ |
| the subject (the agent) is refused — `EACUnauthorizedAccountRoles` | ✓ |
| granularity is per-record, not per-name | ✓ |
| the window closes; the second write is refused | ✓ |
| root roles can be renounced | ✓ |
| the record is readable on chain by a contract | ✓ |
| a v4 hook gates a real-PoolManager pool on that record, both directions | ✓ |

**The only demo beat never run is the join between them**: a real settlement driving the grant.
Both halves of that join exist and have been run separately.

---

# S4 — the registry bypass (§3.6 Q5), closed by construction

**2026-09-21.** `PermissionedRegistry` deployed from `ensdomains/contracts-v2` source — the same
thing we would deploy as the parent registry, so main-branch source is the right target here
(the deployed `ETHRegistry` is not an ERC-1967 proxy and is not the registry we would use).

**The issuer chooses the roles that ride on the token:**

```solidity
register(string label, address owner, IRegistry registry, address resolver,
         uint256 roleBitmap, uint64 expiry)
```

| test | result |
|---|---|
| agent **owns** the token (`ownerOf` asserted) but was registered **without** `ROLE_SET_RESOLVER` → `setResolver` | **REFUSED** `0x4b27a133` `EACUnauthorizedAccountRoles` |
| same, `setSubregistry` | **REFUSED**; `getResolver("agent")` unchanged |
| **CONTROL ARM** — same call, same agent, name registered **with** `ROLE_SET_RESOLVER` | **SUCCEEDS** |
| root grants `ROLE_SET_RESOLVER` after the fact | **SUCCEEDS** |

**The control arm is the point.** Without it, the first row is green for any reason at all —
a typo in the token id would pass it. With it, the refusal is attributable to the withheld role.

**So r1 B2's first bypass is closable by construction**, and its second (the root override) by the
renunciation measured in S1. **Row 4 is why §3.2's "renounce root" is a requirement and not a
nicety**: while root is held, the power can be handed over at any time, silently.

## Q5 → CLOSED. Remaining open: Q6 only

The only unmeasured thing left in this spec is whether a swap **executes on a funded pool**
through the hook (§2.4's last row ran with no liquidity).

## Spike hygiene notes

- `lib/` here holds shallow clones of `v4-core`, `contracts-v2` and `openzeppelin-contracts`.
  They are gitignored. **None of this is ported.**
- OZ master renamed `interfaces/draft-IERC6093.sol` → `IERC6093.sol`; a one-line shim under the
  old path is enough for ENSv2's `ERC1155Singleton` to compile.
- The real `LabelStore` drags in the v1 `ens-contracts` tree. A 10-line mock of `ILabelStore`
  avoids it entirely; nothing measured here depends on label storage.

---

# S5 — the join seam. **This was the one thing in the demo never run.**

**2026-09-21.** Against the repository's own committed Groth16 fixtures
(`zk-verdict/contracts/src/fixtures/`), a real `SP1Verifier`, and an unmodified `RecknZkEscrow`.

**`OutcomeProbe` is not the adapter.** The adapter is §4-2 = event work and does not exist. The
probe touches no ENS, grants nothing and writes nothing; it is read-only and answers one
question — **can a contract derive the verdict of a deal it did not settle?**

| test | result |
|---|---|
| a third party settles directly with a real `Reproduced` proof; the probe derives the outcome | **outcome 0**, and the recipient it returns is **the buyer fixed at funding** |
| the same with the `Failed` fixture | **outcome 1** — `Failed` comes back as `Failed` (`R-7`'s ground) |
| **r2 B2 mechanically**: fund, pass `REFUND_AFTER`, `refundAfterDeadline` | `State.Settled` is really written by a refund |
| the probe against that refunded deal | **REFUSED** `RefundWindowPassed` |
| **control arm**: the same proof, inside the window, after a real settlement | **derivable** |

**So r1 B1 and r2 B2 are now demonstrated closed, not argued closed.** The verdict comes from
the proof through the verifier the funder named; the caller supplies no outcome; and the terminal
state a timeout refund writes cannot be mistaken for a settlement.

## Suite state

`forge test --fork-url sepolia` → **17 passed, 0 failed** across 8 suites.

Three tests were **deleted** from `S1` rather than left red: they used the wrong
`grantSetterRoles` argument shape and were superseded by `S1c`/`S1d`. **Nothing in this directory
is a failure whose reason has been forgotten.**

## What is left

**Q6 only** — a swap that actually executes on a *funded* v4 pool (`R-15`). Everything else in
the demo has now run at least once.

---

# S6 — Q6 / `R-15` closed. The swap executes and tokens move.

**2026-09-21.** Real Sepolia PoolManager, two test ERC-20s, **liquidity actually provided**
(`modifyLiquidity` inside `unlock`, with `sync`/`settle`/`take`).

| | |
|---|---|
| swap with no record | **refused** — `target` asserted to be our hook, `reason` asserted to be `NoSettledRecord` |
| record written, same swap | **executed** |
| **token0 spent** | `1.000000000000000000` |
| **token1 received** | `0.987158034397061298` |
| **`R-16`**: record cleared, same swap again | **refused again** |

`1.0 → 0.9872` is the 0.3% fee plus slippage on 100e18 of liquidity — **a real swap through a
real pool**, not a no-op. §2.4's caveat ("no liquidity was provided") **no longer applies**, and
the spec's `R-15` is satisfied by measurement.

**`R-16` is what stops the gate from being green for the wrong reason**: with the record cleared
the same caller, the same pool and the same swap are refused again, so it is the record doing the
gating.

**Note on where the hook is not consulted**: `beforeAddLiquidity` is not flagged, so liquidity
provision never calls the hook. That is deliberate — **the gate is on trading, not on providing
liquidity** — and it should be said out loud rather than discovered by a judge.

## Every beat of the demo has now run at least once

| beat | measured in |
|---|---|
| 1. no record → the v4 pool refuses | S3, S6 |
| 2–3. job settled by a re-execution proof, no key | S5 (repo fixtures, unmodified escrow) |
| 4. a contract derives the verdict it was not told, and opens a one-record window | S5 + S1c |
| 5. the client writes; **the agent itself is refused** | S1b, S1c |
| 5b. the agent owns its name and still cannot repoint it | S4 (+ control arm) |
| 6. the same swap now executes, tokens move | **S6** |

**What remains for the event is assembly under the rules' ordering — not discovery.**

---

# S7 — the ENS *prize requirements*, not the mechanism

**2026-09-21.** The ENS tracks require *"built on ENSv2 (Sepolia)"*, *"functional and not just
hard-coded values"*, and for Continuity *"target an existing project's testnet deployment"*.
Everything before S7 used a **stand-in name that was never registered** and reached the resolver
**directly** — a judge will not.

| step | result |
|---|---|
| `isAvailable("recknspike7391")` on the real ETHRegistrar | YES |
| register price, min duration, paid in **MockUSDC** `0x16f95D91…aA8e` | **613,701** base, **0** premium |
| commit → warp `MIN_COMMITMENT_AGE` → **register on the real Sepolia `ETHRegistrar`** | **OK** |
| our own `PermissionedRegistry` hung under it as the **subregistry** | OK |
| `agent.recknspike7391.eth` issued **without** `ROLE_SET_RESOLVER` (S4) | OK |
| the record written through the settlement-shaped window | OK |
| **`UniversalResolverV2.resolve(name, text(node,key))`** | **OK — returned `"1"`, routed to our resolver** |

**This is the row that matters**: the record is reachable **through ENS's own resolution path**,
not by calling our resolver directly. The earlier `UniversalResolver` revert (S2) was the
unregistered stand-in name, exactly as suspected — now confirmed by fixing the cause.

## Traps on the way

- **The name is an ERC-1155.** `register` reverts `ERC1155InvalidReceiver` for a contract owner
  with no receiver hook. On the day, either own names from an EOA or implement the hooks.
- Registration is **commit → wait → register**; `MIN_COMMITMENT_AGE` must actually pass.
- Fees are paid in **MockUSDC on Sepolia**, and the registrar must be approved for it.

## Bearing on the prize requirements

| requirement | status |
|---|---|
| ENS: built on ENSv2 (Sepolia) | **mechanism proven on a fork of Sepolia** |
| ENS: functional, not hard-coded | the name is **really registered** and resolution is **through ENS** |
| ENS Continuity: targets an existing project's testnet deployment | **still short** — `RecknZkEscrow` is on Arc testnet, **not Sepolia** |
| ENS both: **a live demo link** | **still missing entirely** |
| Uniswap: `FEEDBACK.md` + feedback form + README pointing at contracts and line numbers | **still missing entirely** |

**Nothing is deployed on Sepolia. All 20 tests are fork tests.** That is a different claim from
"it works", and the ENS tracks are asking for the other one.

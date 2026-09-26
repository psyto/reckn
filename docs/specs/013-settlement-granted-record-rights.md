# 013 r4 — Settlement-granted record rights: an agent that cannot write its own history

## r4 — what measurement changed (2026-09-21, `spikes/tokyo-2026/FINDINGS.md`)

**r1 and r2 were paper rounds. r4 is the first version any of whose mechanism has been run.**

| change | why |
|---|---|
| **§2.4 added, §2.3 superseded** | the deployed Sepolia beta's ABI is **not** the main branch's. Two signatures in §2.3 were wrong |
| **§3.3's justification withdrawn** | "the revoke is forced by the 15-assignee cap" is **false**. The second grant fails with `EACCannotGrantRoles`, not `EACMaxAssignees`, and the counts read were nybble-packed bitmaps — one assignee, not sixteen. **Revoking is a choice** |
| **`R-5` deleted** | it was the control arm for that false constraint. It measured the wrong thing |
| **§3.1 and §4 extended: a v4 hook** | the Uniswap surface was passive — a workload we re-execute and nothing built. A `beforeSwap` hook that **gates a pool on the record** closes the loop and is the prize's named category. Measured working against the real Sepolia PoolManager |
| **§8: "No v4" removed** | `012` §2.3 rules out the Universal Router **as the proven execution** (Permit2 → `ecrecover`, on the guest's divergent-precompile list). It says nothing about v4 elsewhere in the product |
| **§3.6 Q1/Q2/Q5 closed, Q3 dropped, Q4 answered** | see §3.6. **Q5 — the registry bypass, r1 B2's first path — is closed by construction and measured with a control arm.** Only **Q6** (a swap on a *funded* pool) is still unrun |

**Status: r4, 2026-09-21.** **The join has now been run too (S5)**: a contract derived the verdict
of a deal settled by a third party, from the repository's own Groth16 fixtures, and refused a
deal that a timeout refund had merely left in `Settled`. **r1 B1 and r2 B2 are demonstrated
closed, not argued closed.** Spike suite: **17 passed, 0 failed**.

**Every open question in this spec is now closed, and every beat of the demo has run at least
once** (`spikes/tokyo-2026/FINDINGS.md`). **What remains for the event is assembly under the
rules' ordering — not discovery.** Nothing here entitles the submission text to say more than
what was run: in particular `beforeAddLiquidity` is unflagged, so **the gate is on trading, not
on providing liquidity**, and that must be said out loud.

## r2 review response (`docs/reviews/013-spec-r2.md`, 2 BLOCKER / 1 MAJOR)

**Round 2 was opened by founder permission. Neither round-1 finding was re-raised — both new
blockers are defects in the round-1 fixes**, which is the argument for having opened it.

| finding | response |
|---|---|
| **B1 — the r1 fix closed the outcome and opened the author.** The role was granted to `msg.sender` and `dealId` was never consumed, so the agent could be handed the write right by our own contract, and one settlement yielded unbounded records | **§3.4: the recipient is now `d.buyer`, fixed at funding**, and `recorded[dealId]` opens the window at most once. Anyone may still *call* `record`. New rows **R-12**. §1.1 now discloses the residue this cannot close: **self-dealing** |
| **B2 — `state == Settled` does not mean a proof settled it.** `refundAfterDeadline` writes the same terminal state with no proof (`RecknZkEscrow.sol:178-182`) | **§3.4: the record must be written strictly inside `fundedAt + REFUND_AFTER`**, the window in which a refund is impossible by the escrow's own guard. **The 30-day cost is stated, not hidden.** New row **R-13** with a control arm |
| **M3 — R-9's negative control is sentinel-shaped and prescribes in-tree mutation** | **R-9 now requires ≥3 _dissimilar_ mutations, each independently red, applied in an isolated copy**, worktree hash unchanged |

## r1 review response (`docs/reviews/013-spec-r1.md`, 2 BLOCKER / 1 MINOR)

| finding | response |
|---|---|
| **B1 — the adapter cannot know the verdict it records.** `Deal` has no outcome field; the outcome exists only in an event, which contracts cannot read. A third party may settle directly | **Closed by mechanism, not by trust.** §3.4 rewritten: the adapter **re-verifies the proof itself** through the verifier the *funder* named (`verifyVerdict` is `public view` — `RecknVerdictVerifier.sol:50-57`). The outcome is never a caller argument. Works regardless of who settled |
| **B2 — the authority boundary is not closed, and R-6/R-9 do not close it.** Token-owner `setResolver`; root-resource override; `no-keys.sh` never reads the new contracts | **§3.2 rewritten and the claim narrowed** (§1.1). R-6 now asserts through `UniversalResolverV2`, not internal bitmaps. **R-9 now has a negative control** — a planted key must turn the check red, or the criterion fails |
| **M3 — the 09-26 fallback is timestamped but not decidable** | §7 now names the two tests whose output decides it |

Written 4 days before ETHGlobal Tokyo 2026 (09-25 → 09-27) as **pre-event design**, which the
rules permit and which `DISCLOSURE.md` must therefore list. **No submission code exists.**

Supersedes `012` as the live lane for Tokyo. `012` is **not deleted**: its Uniswap half is
absorbed here as the workload being proven, and its acceptance criteria `U-1`…`U-8` are carried
over unchanged. If the ENS half of this spec fails to land, `012` is what remains, and the
fallback decision point is stated in §7.

---

## 1. The claim (one sentence, and the wording is load-bearing)

> **An agent cannot write its own history. The right to write one record is created by a
> settlement and destroyed after the write.**

This sits beside — and does not modify — the claim the repository already enforces:

> **There is no key that decides the verdict.** (`scripts/no-keys.sh`)

Together: *re-execution decides whether the work was reproduced; settlement, and nothing else,
creates the right to record that it happened.*

### 1.1 What this is NOT, said before anything else

- **This is not privacy.** ENS records are public. We do **not** claim ENSv2 hides anything.
  What ENSv2 enforces here is **who may write**.
- **This is not a reputation score.** No aggregation, no ranking, no weighting. A record is one
  settled job. Any scoring is somebody else's layer.
- **This does not make a record true.** It makes a record **earned**: it exists only if a
  settlement produced it. Whether the buyer's floor was a *sensible* floor is not our claim.
- **This does not replace ERC-8004.** The registries stay where they are. This addresses the
  one thing 8004 does not: that an agent can be the source of its own history.
- **No claim about Uniswap's or ENS's quality, safety, or pricing.** One is the workload being
  verified; the other is the permission system being used as designed.
- **We are a trust root for the namespace.** The parent registry in §3.2 is deployed by us.
  Anyone reading these records trusts that deployment. Stated here, not buried in §8.
- **★ The claim is narrower than "nobody can forge a record" (r1 B2).** What is closed is that
  **the agent cannot write its own history**. Whoever holds root-resource roles on the parent
  registry can. §3.2 requires those roles to be renounced and `R-6` tests it — but if renouncing
  proves impossible on the beta, **the residue is disclosed and the claim stays narrow.** We do
  not write "nobody".
- **★ A settlement can be self-dealt, and we do not claim otherwise (r2 B1).** The write right now
  goes to `d.buyer`, fixed at funding. An agent that funds its own deal from a second address is
  its own buyer, and buys itself a record. **This cannot be closed without identity, and this spec
  does not close it.** What is closed is narrower and still worth saying: **a record cannot exist
  without a settlement.** Do not write "unforgeable".
- **★ The record is no stronger than the deal's verifier (r1 B1).** The funder names the verifier
  at funding time. A funder who names a sham verifier gets a sham settlement *and* a sham record.
  `CLAUDE.md`'s standing prohibition applies verbatim: **do not write "there is no path that
  skips proof verification"** — it is false for the payout and it is equally false here.

---

## 2. What exists before the event — pre-existing work

Measured from the repository on **2026-09-21**. Every line here is disclosed as pre-existing.

### 2.1 In the repository

| | |
|---|---|
| `zk-verdict/contracts/src/RecknZkEscrow.sol` | No owner / resolver / admin / pause / upgrade. `settleWithProof` permissionless. `refundAfterDeadline` after 30 days, callable by anyone, paying the caller nothing |
| `zk-verdict/program-revm` | Real `revm` run **in-guest** over a prestate **MPT-verified against the block `state_root`** (account + storage proofs) |
| `zk-verdict/program-svm` | The SVM guest (986,097 cycles). Not used by this spec |
| ERC-8004 | Reputation surface implemented (`README.md`) |
| `docs/specs/012` | Written **2026-09-08**, 17 days before the event. Pre-existing **design** |
| Arc testnet | Escrow deployed, 4 real settlements. Pre-existing, and **not** part of this submission |

### 2.2 Measured on 2026-09-08, against Ethereum mainnet (carried from `012` §2.2)

A real `SwapRouter02.exactInputSingle` re-executed inside an **unmodified** guest:
witness **7 accounts / 12 storage slots / 141 MPT nodes**, **13,006,200 cycles**,
Groth16 end-to-end **497.40 s** on a laptop.

**This is a pre-event measurement. It is not event work and must not be presented as such.**

### 2.3 ★ SUPERSEDED at r4 by measurement — read from the main branch, contradicted by the deployment

**The table below was read from `ensdomains/contracts-v2` main on 2026-09-21. The Sepolia beta
does not match it.** Corrected facts are in §2.4; the table is kept because two rows of it are
still quoted elsewhere and because the divergence is itself a finding.

| fact | source | status at r4 |
|---|---|---|
| `grantRoles(uint256 resource, uint256 roleBitmap, address account)` is `external`; `revokeRoles` likewise | `IEnhancedAccessControl.sol` | **confirmed on chain** |
| Unauthorized write reverts `EACUnauthorizedAccountRoles(resource, roleBitmap, account)` | same | **confirmed on chain** (`0x4b27a133`) |
| 32 roles + 32 admin roles; the admin of a role is that role `<< 128`; admin roles imply their regular roles | `EACBaseRolesLib.withAdminRolesApplied` | not exercised |
| `account` is a plain `address` — **nothing requires an EOA**, so a contract can hold an admin role and be granted roles | `IEnhancedAccessControl.sol` | **confirmed on chain** |
| **A role has at most 15 assignees per resource** — counts are nybbles (0–15); exceeding it reverts `EACMaxAssignees` | `EACBaseRolesLib.fromCounts`, `uint4x64` | **★ NOT what constrains us — see §2.4** |
| `EACMinAssignees` exists — a resource cannot be orphaned | `IEnhancedAccessControl.sol` | not reached |
| **`IPermissionedResolver is IExtendedResolver, IEnhancedAccessControl`** — the resolver *is* an access-control surface | `IPermissionedResolver.sol` | **confirmed on chain** |
| `initialize(address admin, uint256 roleBitmap, bytes[] setters)` on the resolver proxy | same | **★ WRONG for the deployment — see §2.4** |
| `ROLE_SET_SUBREGISTRY`, `ROLE_SET_RESOLVER` exist at token level; `ROLE_REGISTRAR` is root-only | `RegistryRolesLib.sol` | not exercised (registry layer untouched) |
| Sepolia: ETHRegistry `0x657ea849…`, UniversalResolverV2 `0x5d25c1d6…`, PermissionedResolverImpl `0x14f09fd0…`, VerifiableFactory `0x9e726eb5…` | `docs.ens.domains/learn/deployments` | **all four have code** |

### 2.4 ★ Measured on 2026-09-21 — fork of Sepolia, real deployed bytecode

**`spikes/tokyo-2026/`, `FINDINGS.md`.** Disposable, disclosed, and **not ported**. Every row is a
run, not a reading.

**The deployment's ABI is not the main branch's:**

| | main branch (read) | Sepolia (measured) |
|---|---|---|
| initialize | `(address, uint256, bytes[])` | **`((address,uint256)[], bytes[])`** |
| text write | `setText(bytes32 node, …)` | **`setText(bytes name, …)`** — DNS-encoded name |

`grantSetterRoles(bytes, address)` takes **the setter's calldata**, not a name; passing a name
reverts `UnsupportedResolverProfile` with the name's first four bytes read as a selector.
`decodeSetter(bytes)` is a **view** returning `(resource, roleBitmap, key)` — **so the adapter can
compute what to revoke**. The implementation is **UUPS**; an EIP-1167 clone dies in `onlyProxy`.

**What ran:**

| | |
|---|---|
| a **contract** holds the resolver's admin role, grants, and revokes | ✓ |
| the agent's own write is refused — `EACUnauthorizedAccountRoles`, roleBitmap `0x10` = `ROLE_SET_TEXT` | ✓ |
| **granularity is per-key**: a grant for `job:1` does not authorise `other:key`, and the resources differ | ✓ |
| **granularity is NOT per-name** — the resource is a function of the key alone, so one grant reaches every name the resolver serves. Measured 2026-09-26, three names, one resource. Handled by fixing the adapter's name at construction and putting the name inside the key: the foreign write is not refused, it is unattributable (`Grief.t.sol` L-4, L-5) | ✗ by design of ENSv2 |
| the window closes — the same client's second write is refused | ✓ |
| **root roles can be renounced** (`revokeRootRoles` from the holder → `roles(ROOT) == 0`) | ✓ |
| the record is readable **on chain, synchronously**, by a contract; **no CCIP-Read on this path** | ✓ |
| **a v4 hook on the real Sepolia PoolManager refuses a swap without the record and passes it after** | ✓ |

**★ 2026-09-26: the last row's limits are gone, and the hook is no longer on a fork.** It is
deployed at `0x68116b8086283E51227c61FD791b6Da1A4230080` with `100e18` of liquidity in the pool,
and beat 5 is three transactions on Sepolia — refused, executed (`1.0` token0 out), refused
again. Receipts in `docs/tokyo-2026/RECEIPTS.md`. What follows is the 09-21 text, kept because
it is what was true when the row was written.

~~**Honest limits of the last row: no liquidity was provided**, so the post-record swap is a
no-op against an empty pool. What is measured is that **`beforeSwap` stopped refusing** — not
that a swap moved tokens.~~ The refusal was asserted to come from our hook and to be our error, after
unwrapping ERC-7751 `WrappedError(target, selector, reason, details)`; **asserting the outer
selector proves nothing, and the first version of that test asserted the wrong field.**

---

## 3. Design

### 3.1 The two surfaces, and why they are one product

| surface | question it answers | decided by |
|---|---|---|
| **Uniswap** | *Did the agent do the job?* A real swap, re-executed, against the floor the buyer set | a proof — no key |
| **ENS** | *May this job be written into the agent's history?* | a settlement — no self-issue |
| **Uniswap v4 (new at r4)** | *May this agent trade here at all?* | the record — read on chain in `beforeSwap` |

The agent's job **is** the Uniswap swap. The record **is** what the settlement produces.
**And at r4 the record is also read**: a `beforeSwap` hook refuses a swap from an agent with no
settled record, and passes it once one exists (measured, §2.4).

**★ Why this is one product and not three.** Until r4 the Uniswap surface was passive — a workload
we re-execute, with nothing built on it — and the ENS surface wrote records **nobody read**, which
is a diary, not a credential. The hook closes the loop: **deliver → earn a record → the record is
the pass.**

**★ Where each half runs, and why they are deliberately different venues.** The *proven* job stays
on **v3 `SwapRouter02`**, which is the only execution measured through the guest (13,006,200
cycles, §2.2) and which touches no precompile. The *pass* is spent on a **v4** pool. Earning and
spending are different acts and do not need the same venue; **moving the proven execution to v4 or
the Universal Router would abandon the only measured ground this spec has** (§8).

### 3.2 ★ The record surface is not owned by the agent

**The obvious construction fails.** If the agent owns the name whose resolver holds its records,
the agent holds — or can obtain — the admin role over its own history, and the central claim
collapses. An adversarial reviewer will find this in one pass, so it is answered in the design:

- Reckn deploys a **parent registry** for an agents namespace (e.g. `…agents.<parent>.eth`),
  using ENSv2's hierarchical registries and on-demand subregistry deployment.
- Each agent gets a **subname** under it. The agent is identified by that name.
- The **resolver that holds job records is controlled by the record contract, not by the agent.**
- The agent may publish whatever it likes under names it *does* own. It cannot write under this one.

**★ r1 B2 — the first draft of this section did not close. Two paths went around it:**

| path | why the first draft missed it | what r2 requires |
|---|---|---|
| **Token-owner powers.** `RegistryRolesLib` puts `ROLE_SET_RESOLVER` and `ROLE_SET_SUBREGISTRY` at **token** level. An agent owning its subname token can point the node at a resolver it controls — **while the original resolver keeps correctly rejecting its direct write**, so the old `R-2` stayed green and proved nothing | the draft asserted the *resolver's* permissions and never asked **who owns the node** | **The agent does not hold the record node's token**, or that token carries neither role. Asserted by resolving through `UniversalResolverV2` after the agent has actually attempted both calls (`R-6`) |
| **Root-resource override.** `IEnhancedAccessControl` has `ROOT_RESOURCE` / `grantRootRoles`, and `hasRoles(resource, …)` returns true for a holder of the role **in the root resource**. Per-resource scoping is not a boundary against root | the draft treated `resource` as if it were the only scope | **Root roles on the parent registry are renounced after setup**, subject to `EACMinAssignees`. If they cannot be renounced on the beta, the residue is **disclosed** and §1.1's narrowed claim is what ships |

**This is the part that makes ENSv2 load-bearing rather than cosmetic.** A flat registry with a
shared public resolver cannot express "this name's records are writable by a contract and not by
its subject". Remove ENSv2 and the property disappears.

### 3.3 The window: granted by settlement, closed after the write

```
settle (proof verified, no key)  →  grantRoles(resource, ROLE_WRITE_JOB, client)
                                 →  client writes the job record
                                 →  revokeRoles(resource, ROLE_WRITE_JOB, client)
```

**★ r4 — the r1 justification for this was false and is withdrawn.** It read: *"the revoke is not
hygiene; it is forced by the mechanism"*, because a role holds at most 15 assignees. Measurement
says otherwise: the second grant fails with **`EACCannotGrantRoles`, not `EACMaxAssignees`**
(the adapter holds no role on that specific resource), and `roleCount` / `getAssigneeCount` /
`roles` return **nybble-packed bitmaps** — the `0x10` observed is **one** assignee, not sixteen.
Nothing came near the cap.

**So the window is a choice, and the honest sentence is the design one**: *a settlement should
create a right that ends, not a standing one.* **This is the second time on this spec that a
correct-sounding sentence sat on a mechanism doing something else** (the first was `R-9`).

**Measured shape** (§2.4): open with `grantSetterRoles(setterCalldata, buyer)`; recover the
resource with `decodeSetter(setterCalldata)`; close with `revokeRoles(resource, role, buyer)`.
The second write by the same party is then refused — run, not argued.

This is the same shape the portfolio already uses for disclosure —
`Grant { recipient, granularity, not_after }` — with `recipient` = the settling counterparty,
`granularity` = the role bitmap on that resource, and `not_after` = the revoke that follows the
write. **It is not secrecy. It is a bounded right.**

### 3.4 ★ The escrow's function surface does not change

`AGENTS.md` §0 enumerates the escrow's surface, and adding a function to `RecknZkEscrow` is a
change to the central claim. **So the escrow is not modified.**

`settleWithProof` is permissionless. The record path is therefore an **adapter** external to the
escrow. **Anyone may call the adapter**, exactly as anyone may call `settleWithProof`.

**★ r1 B1 — "read the settled state" does not work, and the draft was wrong.**
`struct Deal` has **no outcome field** and `enum State` is `None | Funded | Settled`
(`RecknZkEscrow.sol:56-65`). The outcome is only ever **emitted**
(`:151-161`), and contracts cannot read logs. Because settlement is permissionless, a third party
can settle directly and leave the adapter with nothing to authenticate. Taking the outcome from
the caller instead would let anyone write **false history that looks earned** — worse than the
problem this spec exists to solve.

**The adapter re-derives the outcome from the proof, and never accepts it as an argument:**

```
record(dealId, publicValues, proofBytes):
  d = escrow.deals[dealId]
  require !recorded[dealId]; recorded[dealId] = true           // r2 B1: one record per deal
  require d.state == Settled                                   // the escrow already decided
  require block.timestamp < d.fundedAt + REFUND_AFTER          // r2 B2: see below
  require codehash(d.verifier) == d.verifierCodeHash           // the verifier the FUNDER named
  v = IRecknVerdictVerifier(d.verifier).verifyVerdict(publicValues, proofBytes)   // public view
  require v.dealBinding == d.dealBinding                       // this deal, not a favourable one
  outcome = v.outcome                                          // NEVER a parameter
  grant(resource, ROLE_WRITE_JOB, d.buyer) → write → revoke     // r2 B1: the counterparty, never msg.sender
```

**★ r2 B1 — the r1 fix closed the outcome and opened the author.** The previous draft granted the
role to `msg.sender` and consumed no `dealId`, so **the agent could write its own history through
our own contract** (its deal settles honestly, then it calls `record` itself and is handed the
role) and **one settlement yielded unbounded records**. `R-2` did not catch it, because the agent
was no longer writing *directly*. The recipient is now **`d.buyer`, fixed at funding and not
chosen by the caller**, and `recorded[dealId]` makes the window open at most once.
**Anyone may still call `record`** — permissionlessness is preserved; only the *recipient* is fixed.

**★ r2 B2 — `Settled` does not mean "a proof settled it".** `refundAfterDeadline` writes the same
terminal state with no proof (`RecknZkEscrow.sol:178-182`), and `Deal` carries no settlement-kind
field. A **withheld but valid** proof could therefore be re-verified after a timeout refund and
produce a "settled job" record for work nobody paid for. The escrow cannot be changed
(`AGENTS.md` §0), so the separation is taken from the clock the escrow already enforces: a refund
is impossible before `fundedAt + REFUND_AFTER` (`:179`, `TooEarly`), so **a record written strictly
inside that window cannot be standing on a refund.**

**The cost is stated, not hidden: a job must be recorded within `REFUND_AFTER` (30 days) of
funding, or it is never recordable.** That is a real limitation of not touching the escrow.

`verifyVerdict` is `public view` and returns `outcome`, `traceHash` and `dealBinding`
(`RecknVerdictVerifier.sol:8-18,50-57`), so this costs the adapter no privilege it did not have.

**The adapter has no discretion**: it cannot record an outcome no proof produces, cannot record
for a deal the escrow has not settled, and cannot record against a different deal's binding. It
inherits the escrow's authority model unchanged — *the funder chose the verifier, and the proof
chooses the outcome* — including that model's known weakness (§1.1).

**Not claimed**: that a single deal admits only one valid proof. If two proofs with different
outcomes existed for one binding, that would be a soundness failure of the guest, not of the
adapter, and this spec does not assert it is impossible.

> **Open**: what grants the adapter its admin role, and whether that path can be closed so no
> second admin can appear later. Tested by `R-6`; unresolved questions in §3.6.

### 3.5 What goes into a record

Minimum, and deliberately small:

- the deal id, the verdict (`Reproduced` / `Failed`), the settlement block, and the verifier address

**Not** in the record: the counterparty's identity, the terms, the amounts. Selective disclosure
of those is **out of scope for this spec** and must not be claimed in the submission text.

**`Failed` is recorded, not omitted.** A surface that records only successes is a highlight reel,
and `R-7` exists to stop us from shipping one.

### 3.6 OPEN QUESTIONS — status at r4

| # | question | status |
|---|---|---|
| Q1 | what is `resource` for a Permissioned Resolver | **CLOSED.** It is derived per `(name, record)`; the adapter never needs the formula because **`decodeSetter` returns it** |
| Q2 | who grants the adapter its admin role, and can the path be closed | **CLOSED.** `initialize` takes `(account, roleBitmap)` pairs; **root roles can be renounced** afterwards, measured |
| Q3 | does `EACMinAssignees` block revoking the last holder | **DROPPED.** It rested on the cap reading that §3.3 has withdrawn. Revoking the only holder was run and worked |
| Q4 | how is a record id derived | **ANSWERED by not being needed** — `decodeSetter` computes it |
| **Q5** | **the registry layer: can the agent hold the subname token and call `setResolver`?** | **CLOSED (S4).** `register(label, owner, registry, resolver, roleBitmap, expiry)` — **the issuer chooses the roles on the token**. Registered without `ROLE_SET_RESOLVER`, the agent **owns its name and still cannot repoint it** (`EACUnauthorizedAccountRoles`); `setSubregistry` likewise. **Control arm run**: granted the role, the same call succeeds. **And root can hand the power over later — which is why renouncing root is a requirement, not a nicety** |
| **Q6** | **does a swap actually execute through the hook on a funded pool?** | **CLOSED (S6).** Liquidity provided on the real PoolManager; refused without the record (target and reason both asserted to be ours), then **1.0 token0 out / 0.987158034397061298 token1 in**. `R-16` run too: clearing the record closes the pool again |

---

## 4. What will be built **during** the event (2026-09-25 → 09-27)

Nothing below exists. This is the "substantive new features developed during the event" the
Continuity Track requires, and it is the list a judge should be able to check commit by commit.

| # | to build | source |
|---|---|---|
| 1 | **Parent registry + agent subname issuance** on Sepolia ENSv2 | new (§3.2) |
| 2 | **Record contract / adapter**: settle → grant → write → revoke | new (§3.3, §3.4) |
| 3 | **Host-side binding calculator** — the buyer computes `dealBinding` from the deal terms *before the agent works* | `012` §4-1 (today's scripts read it out of a proof fixture: fine for a demo, wrong for a buyer) |
| 4 | **Settlement wiring** for a named swap on a public chain, and fixture generation | `012` §4-2/3 |
| 5 | **The test matrix in §5** | new + `012` §5 |
| 6 | **`FEEDBACK.md`** and the Uniswap Developer Feedback Form | prize qualification |
| 7 | **A judge-checkable surface** in the style of the Arc and Tempo pages | `012` §4-6 |
| **9** | **The `beforeSwap` hook and its pool** — address mined so `uint160(hook) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG`, pool initialised on the Sepolia PoolManager, **and liquidity provided so a swap actually executes** (Q6) | new at r4 |
| **10** | **The join**: a real settlement driving the grant, so beats 3→4→5 run as one path rather than two that each work | **seam measured in S5**; the assembled path is event work |
| **11** | **`RecknZkEscrow` deployed on Sepolia** | **★ was missing from this list.** ENS Continuity requires the integration to *"target an existing project's testnet deployment"*, and Reckn's escrow is on **Arc**, not Sepolia. Without this the $4,000 track is arguable |
| **12** | **A live demo link.** ★ **GitHub Pages is already live at `https://psyto.github.io/reckn/`, served from `master:/docs`** — a file under `docs/` publishes itself, no new branch. **But it currently shows "Reckn on Arc — check it yourself", whose second section is the four Arc settlements this submission disclaims.** Replacing that page is the work | **★ was missing.** **Both** ENS tracks require one in the showcase. Static page, no wallet, no install — the `psyto.github.io` pattern that already works elsewhere |
| **13** | **README section pointing at the contracts and line numbers** |
| **15** | **The GitHub About.** The Arc sentence was dropped on 09-21 because the disclosure disclaims Arc. Still to do **once the work exists, not before**: add the `ens` / `uniswap` / `uniswap-v4` / `erc-8004` topics, and replace *"Building the standard for proof-driven settlement"* — an ambition, not a measurement, and it does not contain the word *agent* for a project that is an agent payment escrow |
| **14** | **Make `zk-verdict/scripts/zk-e2e.sh` able to fail** — `:85` pipes `forge test` into `grep … \|\| true`, so the advertised one-command demo exits 0 and prints its success paragraph with tests failing. Measured 2026-09-21 (`PREFLIGHT` §5.1). **A demo that cannot fail is not a demo** | **★ was missing.** Uniswap: *"Make sure your README clearly points to the relevant contracts and lines of code so we can verify your integration"* |
| **16** | **The opening shot, against the official ERC-8004 registries already on Sepolia.** Register our agent in `IdentityRegistry` `0x8004A818…`, then call `giveFeedback` on `ReputationRegistry` `0x8004B663…` **twice**: from the agent's own address, which **reverts `Self-feedback not allowed`**, and from a second address the same agent controls, which **succeeds**. **★ Added 2026-09-25, rewritten the same day by §7-7.** The first version said "deploy the reference registries and write to yourself, which succeeds" — **measurement says it does not.** Nothing is deployed for this item: the official contracts are live on 30+ chains and we use them unmodified. **Sepolia, labelled on screen**; `AGENTS.md` §8 forbids a mainnet deployment and `DEMO.md` §4 forbids the claim. **Do not substitute the ChaosChain reference implementation to make shot A succeed** — that is choosing the implementation without the check | **★ was missing.** `DEMO.md` §1 |
| 8 | **New screenshots and the demo video** | the existing `dashboard/media/*` are Arc/ETHOnline assets and **must not be reused** |

---

## 5. Acceptance criteria

**Carried unchanged from `012` §5**: `U-1`…`U-8` (floor met → fee released; floor raised by one
unit → refund; a real proof of a *different* swap → `BindingMismatch()` with no token movement;
`check.address` / `check.slot` / `plan.calldata` each mutated → mismatch; revert → `Failed`;
witness slot removed → no proof rather than a false `Failed`; `minOut = 0` pinned as a limit;
replay → `BadState`).

**New for the record surface.** Every row asserts a **named error or a read-back value**, never
an exit status — `forge test --match-test` exits 0 on zero matches (`CLAUDE.md`).

| # | condition |
|---|---|
| **R-1** | A settled deal → the role is granted → the client writes → **the record reads back through `UniversalResolverV2`**. Assert the resolved value, not the write receipt |
| **R-2** | **The agent writes its own record → `EACUnauthorizedAccountRoles`.** This is the central claim; it is the one row that may not be weakened |
| **R-3** | A client writes **without** a settlement → `EACUnauthorizedAccountRoles` |
| **R-4** | After the write, the role is revoked → **the same client writing a second time reverts** |
| ~~**R-5**~~ | **DELETED at r4.** It required "the 16th grant reverts `EACMaxAssignees`" as a control arm for a constraint that measurement shows does not exist (§3.3). **A control arm for a false mechanism is worse than no control arm** — it would have gone green for the wrong reason |
| **R-6** | **★ Rewritten after r1 B2. The old row asserted the record resource's role bitmap, which both bypass paths leave untouched.** The agent, from its own account, must actually attempt (a) `setResolver` on the record node, (b) `setSubregistry` on it, and (c) acquisition of the write role by every root path — and afterwards **`UniversalResolverV2` must still not return a record no settlement produced**. **The assertion is the resolved value, not an internal bitmap** |
| **R-6c** | **The agent's token carries neither `ROLE_SET_RESOLVER` nor `ROLE_SET_SUBREGISTRY`** (S4). **With the control arm**: the same call by the same agent on a name registered *with* the role must succeed, or R-6c is green for the wrong reason |
| **R-6b** | Root roles on the parent registry are renounced, and a later attempt to grant the write role through the root path reverts. **If renouncing is impossible on the beta, this row fails and §1.1's narrowed claim ships instead** — it is not quietly downgraded |
| **R-7** | A `Failed` verdict **writes a `Failed` record**. Omission is a failure of this criterion |
| **R-8** | A record for a deal id the escrow never settled → reverts. The deal, not the caller, is the authority |
| **R-9** | **★ Rewritten twice — r1 killed it as vacuous, r2 killed the replacement as sentinel-shaped.** `scripts/no-keys.sh` does not read the new contracts, so it exits 0 whatever they contain. The criterion is: the key check reads the record contracts, and **at least three _dissimilar_ privilege mutations each independently turn it red** — a single planted sentinel does not count, because a check that greps for that sentinel passes while a real privileged path stays green. **The mutations are applied in an isolated copy, never in the tracked worktree** (`CLAUDE.md`: in-tree mutation runs contaminate concurrent reads and once produced "a plausible lie"), and the worktree's source hash must be unchanged afterwards |
| **R-12** | **The author is fixed, not chosen** (r2 B1). The agent calls `record` **itself** on its own honestly-settled deal → **no record appears**. Then any third party calls `record` for the same `dealId` a second time → **no second window and no second record**. Assert through `UniversalResolverV2` |
| **R-14** | **The gate refuses.** A swap from an agent with no record reverts, and **after unwrapping ERC-7751 `WrappedError(target, selector, reason, details)`** the `target` is our hook and `reason` is our error. **Asserting the outer selector is not this criterion** — the first attempt at this test asserted the wrong field (§2.4) |
| **R-15** | **The gate opens, and something happens.** With the record written, the same swap **executes on a funded pool** and balances move. **A no-op swap against an empty pool does not satisfy this row** (Q6) |
| **R-16** | **The gate is the record, not the caller.** Revoking/clearing the record closes the pool to that agent again. Without this row the hook could be passing for an unrelated reason |
| **R-13** | **A timeout refund is not a settlement** (r2 B2). Fund, pass `REFUND_AFTER`, call `refundAfterDeadline`, then submit a **valid bound proof** to the adapter → **no record**. Control arm: the same proof inside the window **does** produce one, so the row is not passing by being broken |
| **R-10** | **The outcome is not a caller argument** (r1 B1). Settle a `Reproduced` deal **directly** through `settleWithProof`, then call the adapter as an attacker attempting to record `Failed` → resolution must not return a `Failed` record |
| **R-11** | **A deal settled by a third party is still recordable and still truthful.** The adapter was not the settler in this row; the record must match the proof |

---

## 6. The rules boundary

Unchanged from `012` §6 and restated as rules for ourselves:

1. **§4 is not to be built before 2026-09-25 at 21:00 JST** — the moment hacking begins, not the
   start of the calendar day. **The published schedule corrects an assumption this repository
   carried**: registration opens 13:00, the sponsor workshops run 15:00–17:50, dinner 18:30,
   opening ceremony 20:00, and **hacking begins at 21:00**. A commit dated 2026-09-25 is not
   automatically event work. Building it now and re-committing it during the
   event is exactly the practice the rules exist to prevent (`AGENTS.md` §4).
2. **The repository is public and every commit is dated** — the boundary is checkable by anyone,
   including against us.
3. **Continuous commits during the event**, never one large one. A single-commit history is
   default-assumed unqualified.
4. **The written disclosure to ETHGlobal is a separate action from the submission form.**
   **This document is pre-existing design and must appear in it**, as must `012` and §2.3.
5. Track: **Continuity**. Submission type: **Top 10 Finalist & Partner Prizes** (live judging
   2026-09-27 14:30 JST). Partners applied for: **ENS**, **Uniswap Foundation**. Not 1inch.

---

## 7. Pre-work before 09-25, and why each is legitimate

Infrastructure and reading are not the submission.

1. **Throwaway spikes for §3.6** — deploy a Permissioned Resolver on Sepolia, discover what
   `resource` is, and drive grant / write / revoke **from a contract**, including the 16th-client
   behaviour. **These are disposable and are not ported** (`fultus` learned this the expensive way).
2. **Sepolia ETH and a registered test name** (registration fees can be simulated with MockUSDC).
3. **An archive RPC key** with `eth_getProof` and `eth_createAccessList`. The public endpoint
   serves no archive state and will rate-limit; a demo depending on it over conference wifi is a
   demo that fails in the room.
4. **The 497 s question**: decide whether a proof is generated live, and what is said while it
   runs. A Succinct Prover Network account as fallback. **Generating submission fixtures in
   advance is not permitted** — that is §4.
5. **The Tokyo disclosure**, and the form fields that do not depend on the build.
6. **Rewrite the opening 60 seconds.** ETHOnline Round 1 was lost on the entry, not the claim —
   the video was a verification checklist for an already-interested judge. Script only.
7. **★ Added and ANSWERED 2026-09-25. "Does ERC-8004 actually let an agent write its own
   entry?"** §4-16 and the demo's opening both assumed yes. **The answer is no on the contract
   that matters, and the question was worth twenty minutes.**

   | source | the rule about a self-write |
   |---|---|
   | **EIP-8004**, `erc-8004.md:217` | *"The feedback submitter **MUST NOT be the agent owner or an approved operator** for agentId."* |
   | **ChaosChain reference implementation**, `src/ReputationRegistry.sol` | **absent.** `giveFeedback` carries two requires — `valueDecimals <= 18` and `agentExists` — which are the paragraph's other two sentences. **No owner comparison exists anywhere in the 509-line file.** The Jan 2026 update removed `feedbackAuth` and signature verification on purpose: *"Direct feedback submission (anyone can submit)"* |
   | **official contracts**, `erc-8004/erc-8004-contracts`, `ReputationRegistryUpgradeable.sol:108` | **enforced**: `require(!isAuthorizedOrOwner(msg.sender, agentId), "Self-feedback not allowed")`. Deployed on 30+ chains — mainnet `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63`, **Sepolia `0x8004B663056A597Dffe9eCcC1965A193B7388713`**, both carrying bytecode (checked 09-25 by `eth_getCode`) |

   **Consequence**: §4-16 became two shots, the second one a **different address**, and the
   opening is stronger for it — the hole is not that nobody checks, it is that **the check asks
   who you are, and a second address answers it.** `DEMO.md` §1 carries the script.

   **★ And the rule this produced, which is the repository's own doctrine arriving from outside:
   two of that paragraph's three sentences became `require`s and the third did not.** A `MUST NOT`
   in a document is not a mechanism — `R-7`, met in the wild.

   **Not verified, and recorded as such**: that the Sepolia proxy's implementation is
   byte-for-byte that source (the revert string settles it on the day), and what
   `IdentityRegistry` requires at registration time.

   **★ This entry is the evidence. It is not what to say to a person.** The same finding, shaped
   for the 15:00 ENS talk — the spoken opening, the identity-versus-capability comparison, the
   four questions and the three things not to say — is **`docs/tokyo-2026/PREFLIGHT.md` §7.1**,
   beside the other things being carried to the two talks. **Read §7.1 and not this entry before
   talking to anybody**: this one records that the reference implementation omits a check, and
   **omits that the standard defers it deliberately and says so twice.** Someone who reads only
   this and then speaks to the spec's authors will say the one wrong sentence.

**Fallback decision point: 2026-09-26, 09:00 JST** — twelve hours into a thirty-six hour window
(21:00 on the 25th to 09:00 on the 27th), not a whole day in as the earlier reading assumed.

**★ r1 M3 — the first draft was timestamped but not decidable.** "§3.6 is unresolved" and
"§4-1/§4-2 are not standing" named no artifact, so under pressure a partial deployment could be
called standing. The predicate is now a command and two rows:

> From a **fresh clone**, `R-2`, `R-10` **and `R-12`** all pass against a **deployed Sepolia
> resolver**, and **§4-10 (the join) runs end to end at least once**.

`R-2` is the central claim (the agent's own write reverts), `R-10` stops a forged outcome, and
**`R-12` is in this list because round 2 proved `R-2` alone does not protect the claim** — the
agent writing *through the adapter* leaves `R-2` green. **Anything less — contracts that compile, a
green test that never touched the resource or the revoke path, a resolver deployed but unexercised
— fires the fallback.** If it fires: the ENS half is dropped, the submission reverts to `012`, and
the short description loses its second sentence.

**Decided by running named tests, not by judgement under deadline.**

**★ r4 note on what the fallback now costs.** The hook (§4-9) has been measured standing on its
own, so if the fallback fires the demo does not lose the Uniswap surface — it loses **the join**,
and the two halves would have to be shown separately. **Say that plainly if it happens; do not
edit the demo to hide the seam.**

---

## ★ 9. Qualification requirements — the checklist that loses the prize if forgotten

**These are not design; they are the gate.** A mechanism that works and a submission that
qualifies are different things, and this section exists because at 03:00 on the last night the
second one is what gets dropped.

### Uniswap Foundation (both tracks, identical requirements)

| # | requirement | where |
|---|---|---|
| U-Q1 | public GitHub repository, open source | `psyto/reckn` — already public |
| U-Q2 | **`FEEDBACK.md`** | §4-5 |
| U-Q3 | **submission to the Uniswap Developer Feedback Form, including the link to `FEEDBACK.md`** — the prize names the URL and this row did not: **https://developers.uniswap.org/hackathon-feedback**. *A separate action from the ETHGlobal form, and not the `?form=feedback` widget on the docs site.* **Submitted 2026-09-26** | §4-5 |
| U-Q4 | **README points at the relevant contracts and lines of code** | §4-13 |

### ENS (both tracks)

| # | requirement | where |
|---|---|---|
| E-Q1 | built on **ENSv2, Sepolia** | measured (S7): registered on the real `ETHRegistrar`, resolved through `UniversalResolverV2` |
| E-Q2 | **ENSv2 features central, not a cosmetic add-on** | EAC *is* the mechanism (§3.3); remove ENSv2 and the claim disappears |
| E-Q3 | **functional demo, not hard-coded values** | the name is really registered and resolution goes through ENS — **not** a direct call to our own resolver |
| E-Q4 | **a live demo link in the showcase** | §4-12 — **currently missing entirely** |
| E-Q5 | open source, accessible | `psyto/reckn` |
| E-Q6 | *(Continuity only)* the integration **targets an existing project's testnet deployment** | §4-11 — **the escrow must be on Sepolia** |

### ETHGlobal

| # | requirement | where |
|---|---|---|
| G-Q1 | written pre-existing-work disclosure to ETHGlobal, **separate from the submission form** | §6-4 |
| G-Q2 | version control throughout; **no single large commit** | §6-3 |
| G-Q3 | Top 10 Finalist ⇒ **live judging 2026-09-27 14:30 JST** | founder's calendar, not a file |

**★ Everything in §9 is unstarted except what S7 measured.** The technical unknowns are closed;
these are not technical.

---

## 8. Non-goals

- **No privacy claim.** Records are public (§1.1).
- **No score, ranking, or aggregation** (§1.1).
- **No new function on `RecknZkEscrow`** (`AGENTS.md` §0, §3.4).
- **No ENSv2 mainnet.** Sepolia beta only.
- **The Universal Router is not the *proven* execution** (`012` §2.3: Permit2's `ecrecover` is on
  the guest's divergent-precompile list, equivalence unverified). **v4 elsewhere in the product is
  in scope and is now built** (§3.1, §4) — the two are different statements and must not be merged.
- **No claim that a swap executed through the hook moved tokens** until a funded pool is run (Q6).
- **No anchoring claim.** `state_root` ↔ block header stays off the adjudication path.
- **No claim that the parent registry is trustless.** We deployed it (§1.1).

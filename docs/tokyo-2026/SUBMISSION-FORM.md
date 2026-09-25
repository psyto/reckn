# ETHGlobal Tokyo 2026 — submission form copy

**Drafted 2026-09-21 from measured results (`spikes/tokyo-2026/FINDINGS.md`).**

> **How to read this file.** Everything inside a `~~~text` block is **the copy — paste it
> verbatim**. Everything outside one is a note to you and must not go into the form.
>
> **★ No counted number goes in the copy.** "310 commits before the event" was pasted into the
> form on 09-21 and was false by 09-22, because fourteen more pre-event commits landed — the same
> trap `DISCLOSURE.md` §0 was rewritten to avoid, left standing here because only one of the two
> files was fixed. **State the boundary, not the tally.** Anything that must be counted is counted
> by `git log`, by whoever is reading.
>
> **The copy is plain text on purpose.** The form's fields do not render Markdown: the description
> actually filed at ETHOnline is prose with no `**`, no backticks, and capitals where a sentence
> has to carry weight. Asterisks pasted into that field arrive as asterisks. Two earlier versions
> of this document got this wrong — first by wrapping the copy in blockquotes, then by leaving
> Markdown emphasis inside it.
The form can be edited until the deadline, so this is written as the submission **will** be —
with §9 below listing exactly which sentences become false if a piece does not land, so that
nothing in here quietly turns into a claim we did not earn.

---

## 0. State of the form — 2026-09-21

| field | state |
|---|---|
| project name, emoji, **category (Artificial Intelligence)** | **entered** |
| track (Continuity), submission type (Top 10 Finalist + Partner) | **entered** |
| partner prizes: ENS, Uniswap Foundation | **entered** |
| GitHub repository | **entered** — `psyto/reckn` |
| tech stack pages | **entered** |
| AI tools | **entered** — the form's own placeholder was false here and was replaced. **One sentence to add at the event**: implementation written by Codex, diffs read back by Claude. It cannot be written yet because no implementation exists |
| short description, description, how it's made, both partner explanations | **drafted here, not yet pasted.** They quote measurements taken on a fork; re-check each number against the deployed run before pasting (§9) |
| **the disclosure, in full, inside the description** | **not pasted.** The only omission that is a disqualification rather than a lost point |
| demo link, images (logo, cover, ≥3 screenshots), video | **event work.** The Arc/ETHOnline images must not be reused |
| Future Opportunities | **not answered** — grants/accelerator interest |

## 1. Project name

`Reckn`

## 2. Category / emoji

**Artificial Intelligence** · ⚖

> **Changed from Wallet/Payments on 2026-09-21.** That was the right label for the ETHOnline
> submission, which was the escrow. `013` moved the centre of gravity: of the three surfaces, only
> one is payments — the record surface is identity, and the hook is access control — and the
> subject from end to end is **an agent**. ERC-8004 is the standard in question; ENS's own prize
> text gives bonus consideration to *"agents as namespaces, each with their own identity and
> permissions"*; and this same form asks *"Are you building an AI-powered or agentic project?"*,
> which is answered **yes**. Leaving the category at Payments would have made the submission
> disagree with itself two fields apart.
>
> The emoji stays ⚖ — it points at the verdict, which is unchanged.

## 3. Short description (≤100 characters)

~~~text
An agent earns a record it cannot write itself, and that record is its pass to a v4 pool.
~~~

*(89 characters.)*

## 4. Description

> **★ This field must also carry the pre-existing-work disclosure, reproduced in full.**
> ETHGlobal's rules require the disclosure *"in writing to the ETHGlobal team"* and **name no
> channel**; the same rules require full details *"in your submission (repo history, video, and
> description)"*. This repository settled the question at ETHOnline
> (`docs/ethonline-2026/SUBMISSION-FORM.md:66`): **"There is no other place to file it."**
>
> **Do not paste from this section, and do not paste `DISCLOSURE.md` — it is Markdown.**
> Run:
>
> ```bash
> python3 docs/tokyo-2026/build-description.py
> ```
>
> and paste **the whole of `docs/tokyo-2026/DESCRIPTION.txt`**, in one go. It is the narrative
> below followed by the entire disclosure, rendered to the plain prose the field actually stores —
> headings as capitals, tables as lines, no asterisks and no backticks.
>
> **Neither half is retyped**, so the form and the repository cannot silently disagree — the
> failure ETHOnline's own post-mortem lists is two documents a judge reads disagreeing about the
> same number. **Re-run it and re-paste after any edit to the disclosure or to the narrative.**

~~~text
Reckn is an escrow for agent-to-agent payments where the arbiter is deterministic
re-execution. A buyer funds a deal with a floor; an agent does the work; the fee is released
only if replaying that work reproduces the agreed outcome. THERE IS NO KEY THAT CAN DECIDE
OTHERWISE — the escrow has no owner, resolver, admin, pause or upgrade, settleWithProof is
permissionless, and a build-time check enforces that rather than promising it.

ERC-8004 reached Ethereum mainnet in January 2026 and gives agents identity and reputation. A
second address can submit feedback without establishing that any work happened. We build the
narrower condition here: a record's write right comes from a settlement.

A completed job becomes a record under the agent's ENSv2 subname, and the right to write it
is an Enhanced Access Control role that the settlement creates and then destroys. The agent
cannot write it. Its client can, once, for that one record. Attempting otherwise reverts with
EACUnauthorizedAccountRoles. The agent owns its name and still cannot repoint it: the subname
is issued without ROLE_SET_RESOLVER.

Then the record is spent. A Uniswap v4 beforeSwap hook reads it on chain and refuses a
swap from an agent with no settled record. The same swap passes once the record exists, and is
refused again if the record is cleared. DELIVER, EARN A RECORD, AND THE RECORD IS THE PASS.

The job that is proven runs on v3 SwapRouter02, which is the execution we have measured
through the zk guest. The pass is spent on v4. Earning and spending are different acts and
deliberately use different venues.

PRE-EXISTING WORK IS DISCLOSED IN FULL BELOW. In short: this repository began on 2026-07-26;
its product history runs to 501cbde on 2026-09-14, and everything dated after that is the
pre-event design, measurement, and materials the disclosure describes. It was submitted to ETHOnline 2026,
where it did not pass Round 1. The escrow, the guests and the proving pipeline are old. The ENS
record surface, the v4 hook, and everything that joins them are the event's work. The full
disclosure follows.
~~~

*(then the `<!--DISCLOSURE:BEGIN-->` block.)*

## 5. How it's made

~~~text
THE VERDICT. An SP1 zkVM guest runs real revm in-guest over a prestate MPT-verified
against the block state_root — account proofs plus storage proofs — so the guest cannot be
fed a state that never existed. Measured against Ethereum mainnet on 2026-09-08: a real
SwapRouter02.exactInputSingle, witness of 7 accounts / 12 storage slots / 141 MPT nodes,
13,006,200 cycles, Groth16 end-to-end in 497.40 s on a laptop. That measurement
predates the event and is disclosed as pre-existing. A Groth16 verifier checks the proof on
chain and settleWithProof moves the money. The deal is bound to one execution — the token
checked, the storage slot read (which is whose balance) and the calldata are all inside the
binding, so a real proof of a different swap reverts with BindingMismatch() and nothing moves.

DERIVING THE VERDICT WITHOUT BEING TOLD IT. The escrow's Deal has no outcome field, and
the outcome exists only in an event, which contracts cannot read — and settlement is
permissionless, so a third party may settle first. The record contract therefore re-verifies
the proof itself through the verifier the funder named (pinned by codehash), and takes the
outcome from verifyVerdict, never from its caller. It also refuses anything outside
fundedAt + REFUND_AFTER, because a timeout refund writes the same terminal state as a real
settlement and would otherwise be recordable as one.

THE ENS SIDE. Each agent is a subname under a parent PermissionedRegistry we deploy, and
its job records live on a Permissioned Resolver, which is itself an access-control surface.
grantSetterRoles takes the setter's CALLDATA rather than a name, and decodeSetter returns
the resource to revoke. We measured what that resource is derived from: the key alone. The
same key under agent.reckn.eth and under victim.reckn.eth is one identical resource, so a
setter role is never scoped to a single name. We handle it rather than claim otherwise --
the adapter's name is fixed at construction instead of taken from the caller, and the name
is written inside the record key, so bytes placed on a foreign name sit under a key that
names whose record it is and the canonical lookup for that name does not find them. The
write onto a foreign name is not prevented; it is made unattributable. Records resolve
through UniversalResolverV2, not by calling our resolver directly.

THE UNISWAP SIDE. A beforeSwap-only hook, its address CREATE2-mined so
uint160(hook) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG, reads the record inside beforeSwap —
synchronously, no CCIP-Read — and reverts NoSettledRecord. The PoolManager wraps that in
ERC-7751 WrappedError, so our tests assert the wrapped target and reason, not the outer
selector. beforeAddLiquidity is deliberately unflagged: THE GATE IS ON TRADING, NOT ON
PROVIDING LIQUIDITY.

HACKY AND WORTH MENTIONING. Before writing any of it we spent a day measuring against forked
Sepolia, and the design was wrong twice. The deployed ENSv2 beta's ABI is not the main
branch's (initialize and setText both differ); grantSetterRoles rejects a name with
UnsupportedResolverProfile because its first argument is calldata; the resolver is UUPS, so an
EIP-1167 clone dies inside onlyProxy with 210 gas and no revert data; and a name is an
ERC-1155, so a contract owner without a receiver hook cannot register one. All of it is in
FEEDBACK.md and spikes/tokyo-2026/FINDINGS.md.
~~~

## 6. Partner prize — Uniswap Foundation

~~~text
The agent's job is a real Uniswap swap, and what we built is the hook that consumes the result.

A new v4 beforeSwap hook gates a pool on an agent's on-chain reputation record: no settled
record, no swap. Measured against the real Sepolia PoolManager with liquidity provided —
refused first (target and reason both asserted to be ours), then executed: 1.000000000000000000
token0 out, 0.987158034397061298 token1 in. Clearing the record closes the pool to that agent
again, so it is the record doing the gating and not something incidental.

The swap that is proven stays on v3 SwapRouter02 — re-executed inside an unmodified zk
guest, 13,006,200 cycles, measured on 2026-09-08 and disclosed as pre-existing. We do not put the
Universal Router on the proving path: Permit2's signature step uses ecrecover, which is on our
guest's divergent-precompile list with equivalence unverified, and we will not claim soundness we
have not established.

FEEDBACK.md is in the repository root and the README points at the exact contracts and lines.
We make no claim about Uniswap's pricing, safety or quality — the protocol is the workload being
verified and the venue being gated, not the subject of a critique.
~~~

## 7. Partner prize — ENS

~~~text
ERC-8004 gives agents identity and reputation but nothing stops an agent from being the source of
its own history. ENSv2 is what closes that, and it is the mechanism rather than a lookup.

Each agent is a subname under a parent PermissionedRegistry we deploy on Sepolia. Its job
records sit on a Permissioned Resolver, and the right to write one is an Enhanced Access
Control role that the escrow grants on settlement and revokes after the write. Measured:
the agent's own write reverts EACUnauthorizedAccountRoles; a grant for job:1 does not
authorise other:key, and the two resources differ — GRANULARITY IS PER RECORD, NOT PER NAME;
the second write by the same party after revocation is refused.

The authority boundary is closed at the registry too. register lets the issuer choose the roles
that ride on the token, so the agent's subname carries no ROLE_SET_RESOLVER — it owns its
name and still cannot repoint its own record surface. With a control arm: the same call on a
name registered with the role succeeds, so the refusal is attributable. Root roles on the parent
registry are renounced after setup, because while they are held that power can be handed over at
any time.

Everything resolves through UniversalResolverV2 against a name really registered on the
Sepolia ETHRegistrar — not hard-coded, and not a direct call to our own resolver.

REMOVE ENSv2 AND THE CLAIM DISAPPEARS: a flat registry with a shared public resolver cannot
express "this name's records are writable by a contract and not by their subject".
~~~

## 8. AI tools

~~~text
Claude Code and the Codex CLI were both used, under a rule of AUTHOR INDEPENDENCE: whoever
writes a spec does not implement it, and whoever implements does not review. The design was
drafted by Claude and reviewed adversarially by Codex; both rounds returned CHANGES, and the
four blockers and their fixes are in docs/reviews/013-spec-r1.md and -r2.md along with the
exact prompts the reviewer was given. AI did not produce the measurements or the on-chain
results — those come from running the code.
~~~

## 9. ★ Sentences that become false if a piece does not land

**Check this list before submitting. Do not let a draft survive into a claim.**

| if this does not land | these must change |
|---|---|
| the ENS record surface | §3 short description entirely; §4 paragraphs 3–4; §7 |
| the v4 hook | §3 "pass to a v4 pool"; §4 paragraph 4; §6 paragraph 2 |
| liquidity in the demo pool | the token figures in §6 — **a no-op swap on an empty pool is not what those numbers say** |
| `RecknZkEscrow` on Sepolia | the ENS Continuity claim that we target an existing project's testnet deployment |
| a live demo link | **both** ENS tracks' qualification |
| `FEEDBACK.md` + the feedback form | **both** Uniswap tracks' qualification |
| the disclosure pasted into §4 | **the whole submission** — omission is a disqualification, not a lost point |

**Everything quoted as a measurement above was run on a fork of Sepolia on 2026-09-21, not on
Sepolia itself.** When the event's deployments exist, re-check each number against the deployed
run and correct it here rather than leaving the fork figure standing.

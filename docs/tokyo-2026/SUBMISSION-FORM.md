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

## 0. State of the form — **2026-09-26 12:40 JST**

*(The 09-21 version of this table is gone rather than struck through: it described a submission
where nothing had been built, and every row of it had stopped being true.)*

| field | state |
|---|---|
| project name, emoji, category (Artificial Intelligence) | **entered** |
| track (Continuity), submission type (**Top 10 Finalist + Partner**) | **entered.** Live judging 09-27 14:30, 4 min demo + 3 min Q&A |
| partner prizes | **ENS and Uniswap Foundation, and only those two.** The form offers three slots. **Do not take the third** — 1inch appeared in the form and this project does not use it |
| GitHub repository, tech stack pages | **entered** — `psyto/reckn` |
| **About: topics, description, homepage** | **done 09-26.** `ens` / `uniswap` / `uniswap-v4` / `erc-8004` added, `arc` gone, description rewritten, homepage points at the Tokyo page |
| AI tools | **entered**, and §8 now points at `docs/tokyo-2026/AI-USE.md` — per-file attribution, the spec and prompt locations the rules require, and the five things the models got wrong |
| **short description, how it's made, both partner explanations** | **drafted here, still not pasted.** Every number in them is now from the deployed run, not a fork |
| **description + the disclosure in full** | **`DESCRIPTION.txt` is current; the form field is STALE.** Paste the whole file, then `bash docs/tokyo-2026/check-description.sh --record`. The omission that is a disqualification rather than a lost point |
| demo link | **done** — `psyto.github.io/reckn` reads Sepolia in the judge's browser |
| images (logo, cover, **≥3 screenshots**) | **9 frames exist** in `docs/tokyo-2026/media/`. Arc/ETHOnline images must not be reused |
| video | **not shot.** Beats 1, 3 and 5 are in the can; **beat 2 needs the renounce first** |
| Future Opportunities | **not answered** — grants / accelerator interest |
| **Uniswap Developer Feedback Form (`U-Q3`)** | **not submitted.** A separate action from this form. The URL to give it: `github.com/psyto/reckn/blob/master/FEEDBACK.md` |

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
EACUnauthorizedAccountRoles. The agent owns its name and holds only ROLE_RENEW on it: the
subname is issued without ROLE_SET_RESOLVER, so it cannot repoint its own name away from the
resolver that refuses it. See the residue paragraph below for the one thing that still
overrides that.

Then the record is spent. A Uniswap v4 beforeSwap hook reads it on chain, inside the swap,
synchronously and with no CCIP-Read, and refuses a swap from an agent with no settled record.
DELIVER, EARN A RECORD, AND THE RECORD IS THE PASS.

ALL OF THIS IS ON SEPOLIA, NOT ON A FORK. The hook is at
0x68116b8086283E51227c61FD791b6Da1A4230080, its address mined so that its low bits are exactly
the beforeSwap flag, on the real PoolManager with liquidity provided. Three transactions, the
same sender and the same pool and the same swap, and the only thing that changes between them
is whether the record exists: refused, then executed with 1.000000000000000000 in and
0.987158034397061298 out, then refused again once the record was cleared. Both refusals were
re-simulated at their own blocks, so we can say WHO refused and WHY rather than that something
failed: the PoolManager's ERC-7751 wrapper carries our hook as the target and our own
NoSettledRecord as the reason.

The proving pipeline ran here too. A fresh Groth16 proof of the re-execution was generated on
2026-09-26 in 416.56 seconds over 15,972,262 constraints, and forty minutes later it settled a
deal on chain and paid an agent 250 USDC. Every other settlement in this repository was decided
by a proof committed before the event, which is disclosed; this one was not.

The job that is proven runs on v3 SwapRouter02, which is the execution we have measured
through the zk guest. The pass is spent on v4. Earning and spending are different acts and
deliberately use different venues.

WHAT IS NOT CLOSED, SAID BEFORE YOU FIND IT. The settlement grants the right to write the
record, not its contents: a buyer can write "reproduced" under a job whose proof said "failed".
The contents are checkable by anyone against the escrow and the proof; they are not enforced.
The hook cannot identify the swapper, because beforeSwap's sender is whoever unlocked the
PoolManager rather than the trader, so a second agent could trade behind the first one's
record. An ENSv2 setter role is scoped to the key alone and never to a name, which we measured;
we handle it by fixing the adapter to one name and putting that name inside the record key, so
a write onto a foreign name is unattributable rather than impossible. And this is a testnet.

THE RESIDUE, WHICH IS THE ONE THAT MATTERS. The account that is the agent also deployed the
registry and the resolver, and root roles override every per-key role above. While it holds
them, that account CAN write its own record and CAN repoint its own name — we measured both
rather than assume either. Root is renounced before this is submitted, and renouncing is
irreversible, which is why it is the last thing done and not the first. Do not take our word
for whether it happened: the demo page runs those three calls in your browser every time it
loads, and says which of them still succeed.

Nothing above is a screenshot. The demo page reads Sepolia in your browser as it loads, and it
reports the residue that is still open by asking the chain rather than by telling you. Every
transaction is in a record generated from the chain, and a script checks in both directions
that every link in the repository names a transaction the record holds and that every
transaction the record holds is linked somewhere.

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
predates the event and is disclosed as pre-existing. The pipeline also ran DURING the event: a
fresh proof on 2026-09-26 in 416.56 s over 15,972,262 constraints, which then settled a deal on
Sepolia and paid an agent 250 USDC forty minutes later. A Groth16 verifier checks the proof on
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
record, no swap. IT IS DEPLOYED, NOT SIMULATED — 0x68116b8086283E51227c61FD791b6Da1A4230080 on
the real Sepolia PoolManager, its address CREATE2-mined so its low bits are exactly the
beforeSwap flag, with liquidity provided. Three transactions, same sender and same pool and
same swap, and the only difference between them is whether the record exists: refused, then
executed with 1.000000000000000000 in and 0.987158034397061298 out, then refused again once the
record was cleared. Both refusals were re-simulated at their own blocks, so we can say WHO
refused and WHY rather than that something failed: the PoolManager's ERC-7751 wrapper carries
our hook as the target and our own NoSettledRecord as the reason. Asserting the outer selector
would have passed for any hook failing for any reason, and our first test did exactly that.

THE THING WE MOST WANT TO ASK YOU. beforeSwap's sender is whoever unlocked the PoolManager,
not the trader. On our live refusal the error carries our router 0x25cc9656... while the
transaction came from 0xfa2582ec... So a hook cannot gate on who is trading using sender —
everyone behind one router is the same address to it. Is there an intended pattern for a hook
that needs to know the end user? We state the limit in the contract rather than leave it to be
found: this pool is gated on a record existing, not on who is spending it.

The swap that is proven stays on v3 SwapRouter02 — re-executed inside an unmodified zk
guest, 13,006,200 cycles, measured on 2026-09-08 and disclosed as pre-existing. We do not put the
Universal Router on the proving path: Permit2's signature step uses ecrecover, which is on our
guest's divergent-precompile list with equivalence unverified, and we will not claim soundness we
have not established.

FEEDBACK.md is in the repository root — six items, each with the measurement or the address
behind it — and the README points at the exact contracts and lines:
https://github.com/psyto/reckn/blob/master/FEEDBACK.md
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
authorise other:key, and the two resources differ; the second write by the same party after
revocation is refused.

AND THE PART WE GOT WRONG, BECAUSE WE MEASURED IT. We believed granularity was per record
rather than per name. It is not. The resource decodeSetter returns comes from the KEY ALONE:
agent.reckn.eth and victim.reckn.eth with one identical key return one identical resource, so
a setter role is never scoped to a name. We handle it instead of claiming otherwise — the
adapter's name is fixed at construction rather than taken from its caller, and the name is
written inside the record key, so bytes placed on a foreign name sit under a key that says
whose record it is and the canonical lookup for that name does not find them. THE FOREIGN
WRITE IS NOT PREVENTED; IT IS MADE UNATTRIBUTABLE. If there is a way to scope a setter role to
a name, we would like to know it — that is the question we brought to the ENS team.

The authority boundary is closed at the registry too. register lets the issuer choose the roles
that ride on the token, so the agent's subname carries no ROLE_SET_RESOLVER and the agent holds
only ROLE_RENEW on its own name. With a control arm: the same call on a name registered with the
role succeeds, so the refusal is attributable.

One thing overrides all of that while it exists: root roles on the registry and the resolver,
held by the account that deployed them, which is also the agent. We measured that it can write
its own record and repoint its own name, rather than assuming it could not. Root is renounced
before this submission, and renouncing is irreversible, which is why it is the last thing done
and not the first. The demo page runs those calls in your browser on every load and reports
which of them still succeed — do not take our word for it.

Everything resolves through UniversalResolverV2 against a name really registered on the
Sepolia ETHRegistrar — not hard-coded, and not a direct call to our own resolver.

REMOVE ENSv2 AND THE CLAIM DISAPPEARS: a flat registry with a shared public resolver cannot
express "this name's records are writable by a contract and not by their subject".
~~~

## 8. AI tools

~~~text
Claude Code and the Codex CLI were both used, under a rule of AUTHOR INDEPENDENCE: whoever
writes a spec does not implement it, and whoever implements does not review. Claude Code wrote
the event contracts, tests, scripts and most documentation under founder direction. Codex
independently reviewed the specification and settlement adapter, and produced the demo-page UI
and the three submission visual explainers. The founder made the scope decisions, held the keys,
sent every Sepolia transaction, and checked the generated claims and assets. AI did not produce
the measurements or the on-chain results — those come from running the code and reading the
chain receipts.

Full attribution, file by file, including what the models got wrong and where the spec files,
the prompts and the agent definitions live:
https://github.com/psyto/reckn/blob/master/docs/tokyo-2026/AI-USE.md
~~~

## 9. ★ Sentences that became false, and the ones still load-bearing

**This section used to be a list of things that might not land. They all landed.** What replaces
it is the list of sentences that were WRONG and are corrected, so nobody reinstates one from an
older draft:

| was written | why it was false | where it is corrected |
|---|---|---|
| "granularity is per record, not per name" | the resolver derives the resource from the **key alone** — three names, one resource, measured 09-26 | §5, §7, `FEEDBACK.md`, the ENS deck |
| "the agent owns its name and still cannot repoint it" | **root overrides it, and the agent holds root** until the renounce | §4, §7 |
| "no liquidity was provided" (`013` §2.4) | liquidity is in the pool and the swap moved tokens | `013` §2.4, struck with the date |
| "497.40 s" as the recorded proof's duration | the proof the settlement consumed took **416.56 s**, generated during the event | §5, `DEMO.md` §2 |
| "Nothing of the Tokyo submission exists yet" (README) | it all exists | README |

**Still load-bearing, and checked by something that can fail:**

| | |
|---|---|
| every number in this form comes from the deployed run | `bash zk-verdict/scripts/sepolia-receipts.sh` — 54/54, both directions |
| every fact the video shows is true at the moment of recording | `bash tokyo-2026/scripts/take-check.sh` — **refuses to record**, and today reports exactly one red row: beat 2, until the renounce |
| the central claim | `bash scripts/no-keys.sh`, and `no-keys-control.sh` plants five dissimilar keys and requires it to go red for each |
| the form field and the repository cannot disagree | `bash docs/tokyo-2026/check-description.sh` |

**The one thing none of those can check** is whether the description field actually holds
`DESCRIPTION.txt`. That is a human paste, and `--record` is what closes it.

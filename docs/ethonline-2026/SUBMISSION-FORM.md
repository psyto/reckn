# ETHOnline 2026 — submission form, paste-ready

> **This file is the single source of truth for what goes into the form.**
> Everything to paste is inside a fenced block. Nothing outside the repository is
> current any more; the drafts that used to live in `~/src/_applications/` are listed as
> superseded at the bottom, with what each of them got wrong.
>
> Every number here was **measured on 2026-09-07** unless a different date is written
> next to it. Nothing is transcribed from an older document — that is how the earlier
> drafts went stale without anyone noticing.
>
> **One number is deliberately absent from the narrative half of §5**: the pre-event test
> total. The live form says *129, re-measured 2026-09-04*; the disclosure — which is the
> second half of that same block — says *~140*. They disagree inside one submission, and
> neither was re-measured today, because counting them means checking out the pre-event
> baseline `a122b44` and nobody has. The narrative therefore points at the disclosure
> rather than repeating a number, so the block states it **once**. **Settle it before
> submitting** if you want the number to be right rather than merely consistent.

---

## What the form currently gets wrong — twelve things, ranked

Audited 2026-09-07 against the form's live contents. Ranked, because they are not equal.

| # | field | what it says | why it is wrong |
|---|---|---|---|
| **1** | demo link | `https://hackathon.project.io` | **The form's own placeholder.** Nobody would reach anything. |
| **2** | description | *(no disclosure)* | ETHGlobal's rules and `DISCLOSURE.md` itself require the disclosure **reproduced in full in this field**. There is no other place to file it. |
| **3** | description | *"Spec approved … implementation under way"*, *"We are closing that"* | **008, 009, 005 and the keyless timeout have all landed.** On a track judged by the event's diff, describing finished work as in-progress is the most expensive possible understatement. |
| **4** | description / how it's made | Arc appears nowhere; *"No partner technology is integrated yet."* | **False.** Arc is the sponsor integration, deployed to testnet, four settlements, two decided by Solana proofs. The form has **no bounty field**, so the bounty Arc's rules require you to name must go in the description. |
| 5 | description | *"…does that decider belong to a chain?"* then a fragment beginning *"per-chain — you redeploy the judge…"* | A clause was lost when this was pasted. It currently reads as a broken sentence. |
| 6 | description | *"129 tests, re-measured 2026-09-04"* | The disclosure in the same submission says **~140**. Two documents a judge reads, disagreeing about the same number. |
| 7 | how it's made | *"…or if the constructor stores its caller"* | That was check 4 **before 009**. There is no constructor at all now — and the old wording would match an empty range and pass **vacuously**, which is precisely why it was replaced. |
| 8 | description | key gauntlet listed as being built, *"including a permissionless timeout"* | The **timeout landed** on 2026-09-06 as its own task. The key gauntlet is **stopped at a hard stop** and is a founder decision. |
| 9 | description | *"try to talk the judge into approving"* | 004's specification removed exactly that framing: the claim is judge-independent, because a judge we wrote ourselves being persuaded is evidence of nothing. |
| **10** | video upload | *(the cut that exists is 1 min 41 s, silent)* | The event requires **2–4 minutes, ≥720p, audio without music**. 1080p is fine; **the duration is under the floor and there is no audio track at all** — measured with `ffprobe`, not assumed. Round 1 of Live Judging grades "video presentation and quality" explicitly. |
| **11** | images | *(nothing uploaded)* | A **logo** (square), a **cover** (16:9) and **at least three screenshots** are all required fields. |
| 12 | AI tools | *"ChatGPT was used to generate the initial boilerplate…"* | The form's own placeholder, and false here. It is also the one field where the truthful answer is an advantage rather than a disclosure — see §9. |

**Verified still accurate and not to be touched**: the 43-token vocabulary and 20-piece
skeleton in check 5, ~410k / ~980k cycles, and the 335 s fixture regeneration against the
34 s the repository used to advertise for a different guest.

---

## 1. Project name

```
Reckn
```

## 2. Category and emoji

```
Wallet/Payments
```

```
⚖
```

## 3. Demo link — **replace the placeholder**

```
https://psyto.github.io/reckn/
```

> One static page, no install, no wallet, no clone. It calls Arc's public RPC from the
> reader's own browser and checks three things in front of them: the deployed bytecode
> against the source in this repository, four settlements with the verdict and recipient
> **decoded out of the receipts**, and one deal frozen-but-refundable.
>
> **Not an artifact link.** On 2026-09-05 the two artifact links in the README turned out
> to be openable by their owner only, and they were the first two lines of a public README.

## 4. Short description (96 characters — the limit is 100)

```
Agent-payment escrow where a disputed delivery is re-executed, not judged. Reproduce, or refund.
```

## 5. Description — **one block, copy it once**

> Everything between the markers below is the whole field: the narrative, then the
> pre-existing-work disclosure reproduced in full because ETHGlobal's rules require it in
> this field and there is nowhere else to file it.
>
> **It is generated, not written.** `docs/ethonline-2026/build-form.py` assembles it from
> `description-intro.txt` and `DISCLOSURE.md`, so the disclosure here and the disclosure in
> the repository cannot drift apart, and the script refuses to run if either of the two
> corrections recorded in `DISCLOSURE.md` §0 has been lost. Edit the narrative in
> `description-intro.txt` and re-run the script; do not edit the block by hand.

<!--DISCLOSURE:BEGIN-->
```
When one AI agent pays another, the hard question is not which chain to deploy on. It is:
when the payment is disputed, who decides — and does that decider belong to a chain?
Every answer on offer is a party with a key: an operator inside a TEE, a bonded resolver,
a quorum of voters. Each of those is per-chain — you redeploy the judge and re-earn the
reputation on every chain your agent touches.

Reckn's answer is that the decider should not be a party at all. A disputed delivery is
re-executed: the pre-state is pinned, the disputed work is replayed against it, and the
predicate the deal was funded against is evaluated. Reproduce, or refund. Because
re-execution is deterministic anyone can redo it and reach the same verdict, and because
it is a computation rather than an authority, it does not live on a chain.

SUBMITTING FOR: Arc — Launch on Arc Testnet & Push to Mainnet (primary), and Arc — Best
DeFi or Agentic Application. Arc mainnet is not deployed and the reason is not ours:
Circle had not published Arc mainnet contract addresses as of 2026-09-06, so the bounty's
"deployed OR deployment-ready" is met on the second branch, and the same script deploys
there unchanged once that address list exists.

WHAT EXISTED BEFORE THE EVENT (built July–August 2026; the disclosure below is exact)

The disputed work is re-executed inside an SP1 zkVM and a real Groth16 proof settles the
escrow directly. RecknZkEscrow has no owner, admin, resolver, pause or upgrade path, and
settleWithProof is permissionless: the right to move money comes from a proof verifying
and nothing else. That is enforced as a build condition — scripts/no-keys.sh fails the
build if a privileged role, an unlisted state-changing function, or a msg.sender gate
appears.

The same re-execution runs on two deliberately dissimilar runtimes. On EVM, every account
and storage slot is MPT-verified against the committed state root before real revm
executes the seller's committed CALL in-guest. On Solana, the block bank_hash is
recomputed with the SIMD-0215 lattice hash, the real transaction is signature-verified,
and its transfer is re-executed. Two state models with nothing in common, and one generic
on-chain verifier accepts both proofs.

WHAT WAS BUILT DURING ETHONLINE (Continuity Track) — all of the following has LANDED

1. VERDICT DOMAIN SOUNDNESS. On day one we found a soundness bug in our own proof: the
   guest judged the balance delta on the low 64 bits while the off-chain engine used the
   full U256, so a DECREASE — pre = 2^64, post = 2^64 - 1 — proved as a maximal credit and
   released to the seller. A false release, found by writing the specification rather than
   by a test failing. Verdict values are uint256 on both sides now, the guest runs under a
   committed hardfork and block environment whose fields are bound into dealBinding, and
   every vector is decided twice — replayed off-chain and executed in-guest — and required
   to agree.

2. CROSS-VM SETTLEMENT — the headline, and it is done. One escrow settles an EVM proof and
   a Solana proof. The adjudicating program is named by the FUNDER, per deal, and pinned by
   its codehash; settleWithProof has no parameter with which a settler could name an
   adjudicator, and the dispatch is view-typed, so funder-chosen code runs under STATICCALL
   and cannot write state. The escrow lost its constructor, so any deployment of the same
   source is behaviourally identical. No resolver, no bridge, no light client on the path
   that decides who gets paid.

3. ARC / USDC — and it went to a public chain. The contract needed no change to settle in
   Circle's USDC, because a deal names its payment token at funding; what it needed was
   evidence in USDC's own units and semantics — six decimals, revert rather than a false
   return, and a blacklisting token. Then it was deployed to Arc testnet, where four
   settlements moved real testnet USDC: a proof released the seller, a proof of a decrease
   refunded the buyer, and TWO OF THE FOUR WERE DECIDED BY PROOFS ABOUT WORK PERFORMED ON
   SOLANA.

4. A KEYLESS TIMEOUT. Before it, a funded deal whose prover never appeared stayed funded
   forever. refundAfterDeadline returns it to the buyer after 30 days, permissionless —
   anyone may call it, and calling it gives the caller nothing. The waiting period is fixed
   in the protocol, chosen by no deployer and no funder.

5. THE BUILD CONDITION GREW. The script enforcing "no key can move a funded escrow" now
   reads two files rather than one, because the verifier the escrow calls carries the same
   authority. Its entry-point check became a CLOSURE rather than a list of forbidden names
   — a fallback() draining any funded deal passed all four of the old checks.

WHAT WE DID NOT PLAN, AND KEPT. The first live settlement reverted with "Blocked address":
Circle's USDC blacklists well-known compromised keys and the first deal had named one as
its seller. That deal still holds 1.000000 USDC and can never release, because the seller
is fixed at funding — and it is not lost, because the keyless timeout returns it. It is on
the live page and in the repository rather than quietly redeployed around.

STILL OPEN, AND NAMED: the adversarial key gauntlet is stopped at a hard stop; the live
adversarial-input feature has a round-3 specification and no implementation; the real
ERC-20 workload is not started.

WHAT IS NOT TRUE YET

A proof carries the verdict's authority. It does not by itself prove the committed
pre-state was the chain's real state: on EVM that anchoring lives in an off-chain layer,
and on Solana the provenance of the committed bank_hash is not proven on-chain — a
fabricated account set hashes just as well, and there is a test that says so. "No bridge,
no light client" is true of the ADJUDICATION and not yet of the anchoring. Cross-VM
settlement also created a new risk for the seller: a buyer can name a verifier that always
returns Failed, and on-chain that is indistinguishable from an honest failure, so sellers
must read the deal's verifier before working. Our open gaps are in the README, not in a
footnote.

HOW TO CHECK ANY OF THIS WITHOUT TRUSTING US. Open https://psyto.github.io/reckn/ — your
browser reads Arc directly and compares the deployed bytecode against the source in this
repository. RecknZkEscrow has no constructor, so the same source always produces the same
deployment, which is what makes that comparison mean anything.

==============================================================================
PRE-EXISTING WORK DISCLOSURE — reproduced in full, as ETHGlobal's rules require
==============================================================================

Pre-existing work disclosure — Reckn (ETHOnline 2026, Continuity: Ship a Feature)

Project: Reckn — escrow for agent-to-agent payments where the dispute adjudicator is
deterministic re-execution, not a trusted judge.

Repository: github.com/psyto/reckn

Track: Continuity — Ship a Feature

Team: Hiroyuki Saito (solo)

0. AMENDMENTS

This document is reproduced in full in the submission description, so a reader is entitled
to know where it has changed since it was first written and why. Nothing is removed; the
superseded wording is quoted here.

| date | section | was | why it changed |
|---|---|---|---|
| 2026-09-04 | §1 | "the repository is still private" | It was made public that day, ahead of submission, so the application could be reviewed against the actual source. |
| 2026-09-05 | §3 | five items | Tasks 008 (verdict domain soundness) and 009 (cross-VM settlement) did not exist when this was written and became the event's two headline items. Declaring them late is worse only than not declaring them. |
| 2026-09-05 | §5 | "c-kzg and ecrecover are disabled in-guest" | False, and inherited from the same false sentence in zk-verdict/README.md. The true limitation is narrower and is stated in §5. |
| 2026-09-07 | §3 item 5 | "Sponsor integrations (new): World AgentKit gating who may open a dispute. (Integrations against Arc/USDC and Hedera/x402 … will be attempted only if those sponsors are confirmed for this event.)" | World AgentKit was never built and is out of scope by ruling, while Arc was built, deployed to testnet, and settled four times. The old wording named the thing that does not exist and left the strongest thing that does in a conditional parenthetical — for a track judged on the event's diff, exactly backwards. |
| 2026-09-07 | §3 item 3 | "…so any observer can attempt to persuade the LLM judge, and watch re-execution disagree." | Task 004's specification made its headline claim judge-independent by founder ruling, and forbids citing a judge we wrote ourselves as evidence of persuasion. The disclosure was promising the thing the specification deliberately removed. |

The two 2026-09-07 amendments were made before submission, not after, and the
superseded text is quoted above rather than deleted.

1. THIS PROJECT HAS NEVER BEEN SUBMITTED TO ANY HACKATHON

Reckn was built in July–August 2026 and was never submitted anywhere — not to an
ETHGlobal event, not elsewhere. A submission kit (SUBMISSION.md) was drafted but its
pre-flight items "Repo public" and "Submission form" were never completed. The
repository was private until 2026-09-04, when it was made public so that this
application could be reviewed against the actual source. It has received no prize, no
judging, and no public showcase.

2. WHAT EXISTS BEFORE THE EVENT (BUILT 2026-07-26 → 2026-08-02)

93 commits on master plus ~20 feature branches, all authored before ETHOnline begins.
Full history is preserved in the repository and is available for inspection.

Pre-existing components:

- contracts/ — RecknEscrow (optimistic settlement: bonded resolver, challenge
  window, resolver quorum, slashing, seller data-availability bond). 57 tests.
- reexec-evm/, reexec-svm/ — deterministic re-execution engines with four
  predicate forms. 16 + 30 tests.
- zk-verdict/ — the keyless path. Three SP1 zkVM guests (program/,
  program-revm/, program-svm/) committing identical public values to one on-chain
  verifier; RecknZkEscrow, which settles escrow on a verified Groth16 proof with no
  resolver. 12 tests, including a real Groth16 proof settling to the seller on-chain.
- keeper/, reckn-svm-keeper/, binder/, escrow-svm/, dashboard/ — keepers,
  the LLM-judge-vs-replay money-shot dashboard, and a 35-second demo video.
- ERC-8004 reputation projection and x402 / EIP-3009 payment plumbing.

Total: ~140 tests. All of the above is pre-existing and is not offered as work done
during ETHOnline.

Also pre-existing (added 2026-09-03, before the event begins): an autonomous development
harness (AGENTS.md, CLAUDE.md, .claude/agents/, scripts/no-keys.sh) and the planning
documents in docs/ethonline-2026/. These are tooling and planning, not product features, and
none of the five items in section 3 is implemented by them. They are disclosed here so that the
repository history before 2026-09-04 is fully accounted for.

3. WHAT WILL BE BUILT DURING THE EVENT (2026-09-04 → SUBMISSION)

1. Keyless timeout for RecknZkEscrow. The keyless escrow currently has no deadline:
   if no proof is ever produced, funds lock permanently. A permissionless, deadline-based
   refund closes this without reintroducing any privileged key.
2. Adversarial key gauntlet. A test suite and UI that publish every participant's
   private key and demonstrate that no key can move a funded escrow.
3. Live adversarial dispute input. (Amended 2026-09-07 — see Amendments.) Open the
   seller's delivery claim to free-form input, so any observer can write whatever they like
   about what was delivered — and watch it change nothing. The claim is that prose does not
   move re-execution, and it is stated without reference to any judge, because a judge we
   wrote ourselves being "persuaded" would be evidence of nothing.
4. Real ERC-20 workload. Extend the in-guest re-execution from the current single-slot
   SSTORE fixture to a real token-credit predicate, with measured cycle counts.
5. Sponsor integration: Arc. (Amended 2026-09-07 — see Amendments.) Reckn's keyless
   escrow settles in Circle's USDC on Arc with no change to the contract — a deal names
   its payment token at funding, so a chain whose money is USDC needs evidence rather than
   adaptation. Built during the event and deployed to Arc testnet, where four settlements
   moved real testnet USDC: a proof released the seller, a proof of a wrong execution
   refunded the buyer, and two of the four were decided by proofs about work performed on
   Solana — one escrow, two virtual machines, no bridge and no resolver in the path that
   chose the payout. A fifth deal is frozen at 1.00 USDC because Circle's USDC blacklists its
   recipient; it is refundable by the keyless deadline and by nothing else, and it is
   recorded rather than hidden.
   (At application time Arc and Hedera were both listed as conditional, because the full
   prize list was not yet published. Arc is the only sponsor integration attempted; Hedera
   and World AgentKit were dropped by ruling on 2026-09-06.)
6. Verdict domain soundness. The zkVM guest takes its balance delta on limb 0 of a
   U256, so a decrease from 2^64 to 2^64−1 is accepted as the largest possible
   credit — a false release. The guest also sets only chain_id, leaving the spec and
   block environment out of sync with the off-chain re-execution, which uses the full
   U256. Both are closed, with tests.
7. Cross-VM settlement. A proof of work performed on Solana settles an escrow funded
   on Ethereum. Today the SVM verdict is verified on-chain by the same general verifier,
   but only EVM proofs reach settleWithProof. This closes that gap with no resolver,
   no bridge, and no light client in the adjudication path.

4. HOW THE BOUNDARY IS ENFORCED

- All event work lands in commits dated within the event window, pushed continuously — no
  single squashed commit.
- Event work is confined to identifiable paths and is summarized in a CHANGELOG entry
  that names the pre-event baseline commit.
- All new parts remain open source, permanently.

5. HONEST LIMITS OF THE PRE-EXISTING ENGINE

Carried from zk-verdict/README.md so nothing is overstated: verdict values map to
u64 (closed by item 6 above); the guest proves one CALL plus one delta check (a full
block or arbitrary contract set is more cycles, same architecture); and the
state_root-to-block-header binding remains an off-chain layer.

On precompiles, this document said until 2026-09-04 that c-kzg and ecrecover are
disabled in-guest. That is false, and it was inherited from the same sentence in
zk-verdict/README.md. revm-precompile falls back to pure-Rust backends when the
native features are off — k256 for ecrecover (secp256k1.rs:1-8, preference order
secp256k1 → k256) and arkworks for KZG (kzg_point_evaluation.rs:87-101). Nothing
is missing in-guest. The true limitation is narrower and worse to state loosely: the
guest and the off-chain engine run different implementations of the same
precompiles, and equivalence has never been checked. Corrected here rather than left
standing, because a disclosure that carries a false sentence is not a disclosure.
```
<!--DISCLOSURE:END-->

---

## 6. How it's made

> This is the form's own text with **two corrections**: check 4 no longer says what it
> said before 009, and "no partner technology is integrated yet" stopped being true when
> Arc was deployed.

```
The re-execution engines are Rust. On EVM, reexec-evm drives revm 38 and verifies each
account and storage slot against the committed state root with alloy-trie before replay;
on Solana, reexec-svm replays a committed signed transaction against a committed account
snapshot under LiteSVM. Both emit the identical VM-neutral ReplayRecordV1 through one
shared codec, which is what makes the trace hashes comparable across VMs at all, and a
cross-VM router replays either kind through a single interface.

The keyless path runs that same re-execution inside an SP1 zkVM. The EVM guest
MPT-verifies the prestate in-guest with alloy-trie and then runs real revm over the
seller's committed CALL (406,715 cycles, measured); the Solana guest recomputes the block
bank_hash from the committed accounts with solana-lattice-hash, signature-verifies the
real transaction, and re-executes its transfer (986,097 cycles). Both commit the same
public values, and one generic verifier contract checks either Groth16 proof against
SP1's canonical verifier. Settlement contracts are Foundry/Solidity; the Solana escrow
half is Pinocchio.

ARC IS THE PARTNER TECHNOLOGY, AND IT IS DEPLOYED. On Arc, USDC is the native gas token
and Circle predeploys an ERC-20 face over the same balance at six decimals. Reckn's
escrow settles against that face with no contract change at all, because a deal names its
payment token when it is funded — which is the whole reason a chain whose money is USDC
needed evidence from us rather than adaptation. Adding a payable path would have been the
easy move and was refused: the function surface is part of the central claim, and
widening it to chase a chain's ergonomics would have cost the thing the project is for.
The escrow is live on Arc testnet with four settlements behind it.

The part worth calling out is not a library. Our whole claim is "no key can judge", and a
claim like that decays the moment someone adds one privileged field — so it is a build
condition rather than a promise. scripts/no-keys.sh fails the build if a privileged role
appears, if the state-changing surface grows beyond the enumerated functions, if any
msg.sender gate is introduced, or if any deployment-time configuration exists at all —
and it is itself tested against negative controls. During the event it grew from a
denylist of forbidden names into a property: every call-shaped token in the audited files
must belong to a closed allowlist, and the verifier contract is pinned to a 43-token
vocabulary and a fixed twenty-piece skeleton — so approve, permit, low-level calls and
inline assembly are each rejected by a rule that never mentions them. The old check said
"the constructor does not store msg.sender"; after the constructor was removed entirely
that sentence would have matched an empty range and passed vacuously, so it was replaced.
An observer that watches nothing is not an observer.

Development runs through a harness that writes a spec with mechanically checkable
acceptance criteria, has a second independent model review it adversarially, and only
then implements. Every spec and every review verdict is committed, including the ones
that failed. That process is why the soundness bug above was found on day one rather than
after shipping, and why we know things like: both test runners exit 0 on a filter
matching nothing, so criteria that only check exit status pass with no tests written; our
one-command demo discarded its suite's exit status; and regenerating one Groth16 fixture
takes 335 seconds, not the 34 the repo advertised for a different guest.

The gates repaid the effort in a way worth reporting, because it is the opposite of a
success story. Three full acceptance runs were red before one was green, for three
different reasons, and two of them were the same defect wearing different clothes: a
correct sentence in a specification sitting on top of code that enumerated names. One
specification said its mutation witness covered a narrow glob; the gate globbed wider and
swept in a sibling task's files. Another said a sandbox holds "this task's scripts only";
the script implemented "only" as a list of two filenames. Both were invisible while
exactly one sibling gate existed — landing a second one exposed both in a single run. The
second is the one worth reading twice: the mutant that exists to prove a discovery rule is
a closure was itself defeated by one new name.
```

## 7. GitHub repositories

```
psyto/reckn — Primary, Monorepo
```

## 8. Tech Stack page

**Ethereum developer tools**

```
Foundry   (forge / cast / anvil — the settlement contracts, the gates, and the local demo chain)
```

**Blockchain networks**

```
Arc        (testnet — the escrow is deployed and has settled four times)
Solana     (the SVM guest re-executes a committed Solana transaction)
Ethereum   (the EVM guest re-executes against an MPT-verified prestate)
```

**Programming languages**

```
Rust · Solidity · JavaScript · Python · Shell
```

**Web frameworks** — none. The pages are plain HTML and vanilla JavaScript on purpose:
the live page must run from a static host with no build step, so that "open this and
check it yourself" has nothing between the reader and the chain.

**Databases** — none. There is no server-side state to keep.

**Design tools** — none.

**Other technologies you make heavy use of**

```
SP1 (Succinct) · revm · alloy / alloy-trie · LiteSVM · Pinocchio ·
solana-lattice-hash (SIMD-0215) · Groth16 · Puppeteer
```

## 9. "Describe how AI tools were used" — **the form currently holds its own example text**

> What is in the field now — *"ChatGPT was used to generate the initial boilerplate code
> with the client and server. Claude Code was used to implement the smart contract
> logic."* — is the form's placeholder, and it is **false for this project**. It is also
> the field where the truth happens to be a differentiator, so it is worth writing
> properly rather than dismissing.

```
Heavily, and the interesting part is not that code was generated — it is the structure the
generation was forced through.

Development runs as a harness with a deliberate separation of powers. One model (Claude,
via Claude Code) writes a specification with mechanically checkable acceptance criteria
before any implementation exists. A DIFFERENT model (OpenAI's Codex CLI) then reviews that
specification adversarially, as an independent author, and returns a verdict. Only after
that does implementation begin, and the acceptance gate is derived from the specification
document itself, so the two cannot drift apart.

Every specification and every review verdict is committed to the repository, including —
especially — the ones that failed. Six specifications have produced sixteen review
verdicts, and fifteen of those sixteen were CHANGES rather than APPROVE. That ratio is the
honest output of the process, not a sign it went badly: the soundness bug in our own zk
proof, where a decreasing balance proved as a maximal credit, was found by writing the
specification rather than by a test failing, on day one.

Two things this process caught that a human reviewer plausibly would not have, both
verified against the code rather than argued: an acceptance criterion that no
implementation could ever satisfy, because the fixture-reconstruction recipe it named had
been deleted by a sibling task; and a black-box criterion set that a twenty-six-row lookup
table would pass without an engine behind it. Both are written up in the specifications
under docs/specs/.

The models are also wrong regularly, and the repository records that too. A review cited a
line range in a sibling specification that had since moved to different content; a page of
live transaction hashes was transcribed by hand and two of four were wrong, which is why
that page is now generated from the deployment record rather than typed. The commit
messages say so where it happened.

AI tools were used for: specification writing, adversarial specification review,
implementation, the acceptance gates and their mutation tests, and the demo tooling. They
were not used to generate the cryptographic constructions, the measurements, or any number
in this submission — every figure here came from running something and reading the output.
```

## 10. Judging & Prizes page

**Track**: Continuity Track.

**Partner prizes — select Arc, and only Arc.** Three are allowed; claiming partners whose
technology is not integrated is the kind of thing a judge checks. Hedera is the largest
purse on offer at $15,000 and is deliberately **not** selected: nothing here runs on
Hedera, and the founder ruled it out of scope on 2026-09-06.

**Submission type — decided 2026-09-07: `Top 10 Finalist & Partner Prizes`.**

That commits to a **Live Judging session, Monday 2026-09-14, 12:00 EDT = 01:00 JST on
2026-09-15**. Put it in the calendar as a JST time, because it is the small hours of the
next day and it lands inside the window already given to the R[3]sidency application
(deadline 09-15). Reaching it is not automatic: round 1 is an asynchronous review and
only projects that pass it present live.

**Round 1's three criteria, against where we actually stand:**

| criterion | state |
|---|---|
| **Video presentation and quality** | **The weakest of the three, and the only one not finished.** 1080p 16:9 footage exists in two cuts with a timed narration script; the pitch section and the voice are being produced. Until they are, the cut on disk is 1:41 and silent against a 2–4 minute, audio-required rule. |
| **Project live demo quality** | Strong. <https://psyto.github.io/reckn/> needs no install, no wallet and no clone: the visitor's own browser compares the deployed bytecode against the source and reads four settlements off Arc testnet. |
| **Proper use of git commit history** | Strong, and measured rather than asserted — **89 commits inside the event window, spread across every day of it** (23 / 37 / 18 / 11 on 09-04 → 09-07), no squash, the largest touching 22 files. This is the same evidence the Continuity boundary rests on, so it was going to be true anyway. |

The one thing to protect between now and then is the video, because it is the only
criterion where the current artefact does not yet meet a stated rule.

## 10b. Arc prize application — the four sub-fields

### "How are you using this Protocol / API?"

> The field asks for **a sentence or two**. It gets two. An earlier draft here ran to four
> paragraphs, which is not an answer to the question that was asked — and everything it
> said already lives in the description field, where there is room for it.

```
Reckn's keyless escrow settles agent-to-agent payments in Circle's USDC on Arc, through
the ERC-20 face predeployed at 0x3600000000000000000000000000000000000000 over the same
balance Arc uses as native gas — and it needed no contract change to do it, because a deal
names its payment token when it is funded. It is live on Arc testnet with four settlements
behind it, two of them decided by proofs about work performed on Solana, and
https://psyto.github.io/reckn/ lets you verify that from a browser with nothing installed.
```

### "Link to the line of code where the tech is used"

```
https://github.com/psyto/reckn/blob/687bb0f/zk-verdict/contracts/script/DeployArc.s.sol#L36
```

> A **commit-pinned** permalink, not a branch one: line numbers move, and a reviewer who
> opens this next week should see what it said when it was submitted. Line 36 is the
> USDC predeploy address the escrow settles against; line 37 is the chain id.
>
> Worth adding underneath if the field takes more than one:
> `.../blob/687bb0f/zk-verdict/contracts/test/RecknArcUsdcSettlement.t.sol#L212` — the
> test where USDC on Arc is released by a proof about work performed on Solana.

### "How easy is it to use the API / Protocol? (1–10)"

```
8
```

> Honest, and the reasons are in the feedback below. It is not a 10 because two things
> cost real time that documentation could have prevented, and not lower because the core
> design decision — USDC as native gas with a predeployed ERC-20 face over the same
> balance — is genuinely clean and meant our contract needed no changes at all.

### "Additional feedback for the Sponsor"

```
Four things, in the order they cost us time.

1. ONE OF ANVIL'S DEFAULT ACCOUNTS IS BLACKLISTED BY USDC, AND NOTHING WARNS YOU.
Our first live settlement reverted with "Blocked address". We then queried isBlacklisted
on 0x3600...0000 for the first six accounts of the standard test mnemonic, and the result
is narrower and stranger than "dev keys are blocked":

    anvil #0  0xf39Fd6e5...  false
    anvil #1  0x70997970...  TRUE
    anvil #2  0x3C44CdDd...  false
    anvil #3  0x90F79bf6...  false
    anvil #4  0x15d34AAf...  false
    anvil #5  0x9965507D...  false

Exactly one, and it is the account almost every tutorial uses as "the second party" — the
counterparty in any two-sided example. So a team writing a buyer-and-seller flow has a
good chance of picking precisely the blocked one, and the revert string does not say which
side is blocked or why. A line in the testnet docs naming that address would be worth a
lot; "some addresses are blacklisted" would not, because the useful part is that it is not
a pattern you can reason your way to.

(For us it became the most honest thing in the demo: that deal still holds 1.00 USDC and
can never settle, so it demonstrates why a keyless timeout has to exist. That was luck,
not design.)

2. MAINNET CONTRACT ADDRESSES ARE NOT PUBLISHED, AND A PRIZE ASKS FOR MAINNET.
The "Launch on Arc Testnet & Push to Mainnet" prize asks for a mainnet deployment or
deployment-readiness, and as of 2026-09-06 the contract-addresses page lists testnet only,
with mainnet "not yet available". That is a fine state for a young chain, but it means the
prize's first branch is unreachable through no fault of the entrant. Either publish the
list or say plainly in the prize text that deployment-ready is the expected answer today.

3. THE DECIMALS DUALITY DESERVES TO BE THE LOUDEST LINE ON THE PAGE.
USDC is the native gas token at 18 decimals, and the ERC-20 face over the same balance is
6 decimals. That is the single most consequential fact for anyone writing a contract that
moves value on Arc, and getting it backwards silently moves a million times the intended
amount. It is documented, but it reads as a detail rather than as the thing to check first.

4. THE PUBLIC RPC SENDS CORS HEADERS, AND THAT MATTERED MORE THAN YOU MIGHT EXPECT.
rpc.testnet.arc.io echoes the request Origin, so a static page on any host can read Arc
straight from a visitor's browser with no key, no backend and no wallet. We used that to
build a verification page where a judge with nothing installed watches their own browser
compare the deployed bytecode against our source and read the settlements off-chain. Please
do not regress it. It converted our strongest claim from "trust our README" into "look at
the chain yourself", which is worth more than any amount of writing.
```

### "Which other partners' technologies have you used?" (not applying for prizes)

**Of the ten partners offering Continuity prizes, exactly one is used: Arc.** The Graph,
Hedera, World, 1inch, ENS, Uniswap, Ledger, Chainlink and Bazantic appear nowhere in the
dependency graph — checked, not assumed, and the one apparent hit for ENS was substring
noise across `tokens`. Selecting a partner whose technology is not integrated is the kind
of claim a judge opens the repository to check.

**This dropdown is usually wider than the prize list**, so look for these two, which are
used heavily and should be selected if they appear:

```
Succinct (SP1)   — three zkVM guests (program / program-revm / program-svm) on sp1-zkvm
                   6.0.1, proving real Groth16 through sp1-sdk with native-gnark. This is
                   the whole keyless path: the proof IS the settlement authority.
Solana           — the SVM guest re-executes a committed Solana transaction under LiteSVM,
                   recomputing the block bank_hash with the SIMD-0215 lattice hash and
                   signature-verifying the real transaction in-guest.
```

If **Circle** is listed separately from Arc, it is honest to select it too — the token
being settled is Circle's USDC, and the blacklist behaviour in the feedback above is
Circle's, not Arc's. If Circle appears only as Arc, do not double-count.

**Select nothing else.**

## 11. Images page

All three fields are required and none was uploaded.

| field | file | size |
|---|---|---|
| **Logo** (square) | `dashboard/media/brand/logo-512.png` | 512 × 512 |
| **Cover** (16:9) | `dashboard/media/brand/cover-1280x720.png` | 1280 × 720 |
| **Screenshot 1** | `dashboard/media/arc-demo-steal.jpg` | the theft attempt: a **real** Groth16 proof of another execution, submitted against a funded deal — reverted, `BindingMismatch()`, the money did not move |
| **Screenshot 2** | `dashboard/media/arc-live-page.jpg` | the live page: the browser has compared the deployed bytecode against the source and read four settlements off Arc |
| **Screenshot 3** | `dashboard/media/arc-demo-solana.jpg` | USDC released by a proof about work performed on Solana |

Screenshot 1 first if the order is preserved. It is the only one that shows the claim
being *attacked*, and a judge scrolling a gallery gives the first image the most attention.

## 12. Video page — **the cut on disk does not yet satisfy the requirements**

| requirement | screen footage as it stands |
|---|---|
| 2–4 minutes | **1:41** — under the floor |
| ≥ 720p | **1920 × 1080** ✅ |
| audio, no music | **no audio track at all** |

Both cuts are 1080p **16:9**, re-recorded on 2026-09-07 for exactly this reason: the
earlier one was 1280 × 800, which is 16:10, and putting that on a 16:9 timeline either
letterboxes it or crops it — and cropping a screen recording eats the thing being shown.

| file | use |
|---|---|
| `dashboard/media/reckn-arc-demo-clean.mp4` | **for compositing.** No title cards, so narration and titles can be added in the editor without the screen repeating the voice. |
| `dashboard/media/reckn-arc-demo.mp4` | titles burned in — the standalone cut, if no voice is added |

**Both hold for identical durations**, so [`dashboard/video/NARRATION.md`](../../dashboard/video/NARRATION.md)
— which is timed from the recorder's own beat lengths, not estimated — fits either.
It carries a 60–75 s pitch script for the front, which is what closes the gap to the
two-minute floor.

## 12. Measured, on the tree at commit `5d86292` (2026-09-07)

| what | result |
|---|---|
| **008 and 009 green *simultaneously*** | `ac009: 13/13 rows passed; canary M-4c detected by AC-7`, whose AC-12 ran `ac005.sh --all` and `ac008.sh --all` to completion inside the same run: `both-green: 2 sibling gate(s) discovered, 2/2 exit 0` |
| 008 mutation | `ac008-selftest: 21/21 mutants detected; witness=797a221a69627422` |
| 009 mutation | `ac009-selftest: 15/15 mutants detected, 15/15 sandbox controls clean` |
| 005 (Arc) gate | `ac005: 4/4 rows passed` |
| forge — `zk-verdict/contracts` | **47** tests (`forge test --list --json`) |
| forge — `contracts` | **57** tests |
| `reexec-svm` | 30 passed (2026-09-06) |
| deployed bytecode vs local build | **byte-identical, 5,569 bytes** |
| Arc testnet settlements | **4**, two decided by Solana proofs; one deal frozen by Circle's blacklist at 1.000000 USDC |
| cycles (measured, unrounded) | verdict **30,355** / reexec **406,715** / svm **986,097** (2026-09-05, `zk-verdict/cycles.json`) |
| Groth16 fixture, end-to-end regeneration | **335 s** (the gnark wrap alone is 31.71 s) |

**Not done, named rather than omitted:** 003 (key gauntlet) is stopped at a hard stop and
is a founder decision, not a scheduling one; 002 (real ERC-20 workload) is not started;
004 (live adversarial input) has a round-3 specification and no implementation.

---

## 13. Superseded drafts outside the repository

These were the working copies. **They are no longer current** and should not be pasted
from. Each is listed with what it got wrong, because "it is old" is not a useful warning.

| file | what it says that is now false |
|---|---|
| `~/src/_applications/2026-09-16-ethonline-submission.md` (mtime 2026-09-06 11:09) | Its checklist says *"DISCLOSURE §3 に 008 / 009 が入っていない"* — they were added on 2026-09-05 07:48 (`86cc053`). Its Arc paste-block was written **before the deployment**: the first live deal was funded 2026-09-06 17:46, and the block mentions no testnet, no four settlements, no Solana-decided ones, and says "6 tests" where there are 7. It carries `tier: すべてローカル。どのチェーンにも接続していない`, which is now flatly untrue. Its demo-field guidance predates the live page. |
| `~/src/_applications/2026-09-04-ethonline-application.md` (2026-09-04) | The application answers. Historically accurate and **should not be edited** — it is the record of what was disclosed at application time. Its statement that Solana verdicts are verified but *"settleWithProof を呼ぶテストは EVM の fixture のみ"* was true then and was closed by 009. |
| `~/src/_applications/HANDOFF-2026-09-05-reckn-disclosure-s3.md` (2026-09-05) | A proposal to add 008 and 009 to DISCLOSURE §3. **Already applied**; nothing left to do from it. |
| `~/src/_applications/HANDOFF-2026-09-03-reckn-spec-timing.md` (2026-09-03) | Superseded by `AGENTS.md` §7, which caps the specification loop by clock rather than by round count. |

The other files in that directory belong to different projects (Custos, R[3]sidency,
ETHGlobal Tokyo / Aqua) and are deliberately not brought here.

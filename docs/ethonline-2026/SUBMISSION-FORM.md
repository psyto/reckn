# ETHOnline 2026 — submission form, paste-ready

> **This file is the single source of truth for what goes into the form.**
> Everything to paste is inside a fenced block. Nothing outside the repository is
> current any more; the drafts that used to live in `~/src/_applications/` are listed as
> superseded at the bottom, with what each of them got wrong.
>
> Every number here was **measured on 2026-09-07** unless a different date is written
> next to it. Nothing is transcribed from an older document — that is how the earlier
> drafts went stale without anyone noticing.

---

## 1. Project name

```
Reckn
```

## 2. Short description / tagline

```
An escrow for agent-to-agent payments where the dispute adjudicator is deterministic
re-execution — and no key can move a funded escrow.
```

## 3. Which track and which bounty (Arc requires this to be explicit)

```
Track: Continuity — Ship a Feature

Bounty: Arc — Launch on Arc Testnet & Push to Mainnet ($1,500), primary.
Also eligible for: Arc — Best DeFi or Agentic Application ($1,666).

Arc mainnet is not deployed and the reason is not ours: Circle had not published Arc
mainnet contract addresses as of 2026-09-06, so the bounty's "deployed OR
deployment-ready" is met on the second branch. The same script deploys there unchanged
once the address list exists.
```

## 4. Demo link

```
https://psyto.github.io/reckn/
```

> One static page, no install, no wallet, no clone. It calls Arc's public RPC from the
> reader's own browser and checks three things in front of them: that the bytecode
> holding the money is byte-identical to the source in this repository, that four
> settlements really happened with the verdict and recipient **decoded out of the
> receipts**, and that one deal is frozen-but-refundable. The repository URL
> `https://github.com/psyto/reckn` goes in the source/repo field.
>
> **Do not put an artifact link here.** On 2026-09-05 the two artifact links in the
> README turned out to be openable by their owner only, and they were the first two
> lines of a public README.

## 5. Video

```
dashboard/media/reckn-arc-demo.mp4 — 101 seconds, no audio needed, title cards carry it.
The last third leaves the local chain and films the browser checking Arc itself.
```

---

## 6. Description (long) — **must contain the disclosure in full**

ETHGlobal's rules require the pre-existing-work disclosure to be reproduced in full in
this field; there is no separate place to file it. Paste block 6a, then block 6b.

### 6a — what was built during the event

```
Reckn is an escrow for agent-to-agent payments whose dispute adjudicator is deterministic
re-execution rather than a trusted judge. The claim it is built around is not "trust our
resolver" but "there is no key that can move a funded escrow", and that is enforced as a
build condition — scripts/no-keys.sh fails the build if an owner, resolver, admin, pause
or upgrade path appears.

Built during the event (2026-09-04 onward):

1. VERDICT DOMAIN SOUNDNESS (008). The zkVM guest took its balance delta on limb 0 of a
   U256 while the off-chain engine used the full width, so an execution in which the
   balance DECREASED — pre = 2^64, post = 2^64 - 1 — proved as the largest possible
   credit and released to the seller. A false release, found by writing the specification
   rather than by a test failing. Verdict values are uint256 on both sides now, and the
   guest runs under a committed hardfork and block environment whose fields are bound
   into dealBinding. Every vector is decided twice — replayed off-chain and executed
   in-guest — and required to agree.

2. CROSS-VM SETTLEMENT (009). One escrow settles an EVM proof and a Solana proof. The
   adjudicating program is named by the FUNDER, per deal, and pinned by its codehash;
   settleWithProof has no parameter with which a settler could name an adjudicator, and
   the dispatch is view-typed, so the funder-chosen code runs under STATICCALL and cannot
   write state. The escrow lost its constructor, so any deployment of the same source is
   behaviourally identical. No resolver, no bridge, and no light client on the path that
   decides who gets paid.

3. ARC / USDC (005), and it went to a public chain. The contract needed no change to
   settle in Circle's USDC — a deal names its payment token at funding — so the
   deliverable was evidence in USDC's own units and semantics: six decimals, revert
   rather than a false return, and a blacklisting token. Then it was deployed to Arc
   testnet, where four settlements moved real testnet USDC: a proof released the seller,
   a proof of a decrease refunded the buyer, and TWO OF THE FOUR WERE DECIDED BY PROOFS
   ABOUT WORK PERFORMED ON SOLANA.

4. A KEYLESS TIMEOUT (001). Before it, a funded deal whose prover never appeared stayed
   funded forever. refundAfterDeadline returns it to the buyer after 30 days,
   permissionless — anyone may call it and calling it gives the caller nothing. The
   waiting period is fixed in the protocol, chosen by no deployer and no funder.

5. THE BUILD CONDITION GREW. The script enforcing "no key can move a funded escrow" now
   reads two files rather than one, because the verifier the escrow calls has the same
   authority, and its entry-point check became a CLOSURE instead of a list of forbidden
   names — a fallback() draining any funded deal passed all four of the old checks.

WHAT WE DID NOT PLAN, AND KEPT. The first live settlement reverted with "Blocked
address": Circle's USDC blacklists well-known compromised keys and the first deal had
named one as its seller. That deal still holds 1.000000 USDC and can never release,
because the seller is fixed at funding — and it is not lost, because the keyless timeout
returns it. It is on the live page and in arc.json rather than quietly redeployed around.

HOW TO CHECK ANY OF THIS WITHOUT TRUSTING US. Open https://psyto.github.io/reckn/ — your
browser reads Arc directly and compares the deployed bytecode against the source in the
repository. RecknZkEscrow has no constructor, so the same source always produces the same
deployment, which is what makes that comparison mean something.

WHAT THIS SUBMISSION DOES NOT CLAIM.
- "No bridge, no light client" describes the ADJUDICATION PATH, not anchoring. The Solana
  guest recomputes a bank_hash over the account set the deal committed to; that proves
  internal consistency, not provenance. A fabricated account set hashes just as well, and
  there is a test that says so.
- 009 created a new risk for the seller: a buyer can name a verifier that always returns
  Failed, and on-chain that is indistinguishable from an honest failure. Sellers must read
  the deal's verifier before working. This is written in the contract's own comments.
- The EVM binding still has one implementation. The Solana one has two, deliberately
  unshared, so a transcription error shows up as a mismatch.
- Arc mainnet is not deployed; Circle had not published mainnet addresses as of
  2026-09-06.
```

### 6b — the disclosure, reproduced in full

> **This block is not written — it is rendered from `DISCLOSURE.md`** by
> `docs/ethonline-2026/build-form.py`, markdown stripped because the form field is plain
> text. Retyping a hundred lines into a form is a transcription, and this repository spent
> 2026-09-06 learning what transcriptions do to it.
>
> **It is now verbatim: zero divergences.** Until 2026-09-07 the script applied two
> corrections on the way through, because two sentences in the committed disclosure had
> stopped being true. Both are now applied to `DISCLOSURE.md` itself — with the superseded
> wording quoted in its new §0 Amendments rather than deleted — so the form and the
> disclosure say the same words. What the script still does is refuse to render if either
> correction has been lost again.

<!--DISCLOSURE:BEGIN-->
```
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

## 7. How it's made

```
Solidity (Foundry) for the escrow and the verifier; Rust for the re-execution engines and
the SP1 zkVM guests; real Groth16 proofs, no mock verifier anywhere in the settlement
tests. Arc is an EVM-compatible L1 where USDC is the native gas token, with an ERC-20
face predeployed at 0x3600000000000000000000000000000000000000 at six decimals — the
escrow settles against that face unchanged, because a deal names its payment token when
it is funded.

The part worth describing is the acceptance discipline, because it is what makes the
numbers above checkable rather than assertable. Each task carries a gate whose manifest
is parsed out of that task's own specification, so the document and the checker cannot
drift apart. Every script row ends in a witness= digest that the runner RECOMPUTES ITSELF
from repository bytes — never read out of the checked program's output — so a stub that
prints the expected line does not pass; it would have to print a hardcoded digest, which
goes stale the moment any witnessed byte moves. And each gate is mutation-tested: the
code is broken twenty-one and fifteen different ways, and the rows that claim to guard
each break are required to go red.

The gates repaid this. Three full runs were red before one was green, for three different
reasons, and two of them were the same defect wearing different clothes: a correct
sentence in a specification sitting on top of code that enumerated names. One
specification said its mutation witness covered a glob; the gate globbed wider and swept
in a sibling task's files. Another said a sandbox holds "this task's scripts only"; the
script implemented "only" as a list of two filenames. Both were invisible while exactly
one sibling gate existed — landing a second one exposed both in a single run. The second
is the one worth reading twice: the mutant that exists to prove a discovery rule is a
closure was itself defeated by one new name.
```

---

## 8. Measured, on the tree at commit `437d541` (2026-09-07)

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

## 9. Superseded drafts outside the repository

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

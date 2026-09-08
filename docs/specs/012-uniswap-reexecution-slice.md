# 012 — Uniswap re-execution slice: an agent fee that only a proof releases

> **Status:** spec, round 0. Written **2026-09-08**, seventeen days before the event it is for.
>
> **Lane:** ETHGlobal Tokyo 2026 (2026-09-25 → 09-27), **Uniswap Foundation Continuity
> Track**. This document exists as much to draw the pre-work / event-work boundary as to
> describe the work — see §6, which is the part with teeth.
>
> **Nothing in §4 has been built.** Everything in §2 was measured on 2026-09-08 and is
> **pre-existing work** under ETHGlobal's rules. The distinction is not cosmetic: the penalty
> for getting it wrong is disqualification, revoked prizes, and a ban from future events.

---

## 1. The claim (one sentence, and the wording is load-bearing)

> **Against a prestate committed before the work, a re-executable proof shows that a specific
> Uniswap execution satisfied pre-declared min-out / post-state delta conditions — and only
> that proof decides whether the agent's fee is released or refunded.**

### 1.1 What this is NOT, said before anything else

| do not say | why it is false |
|---|---|
| **best execution** / 最良執行 | Nothing is compared against another venue, route or price. The check is a **declared floor**, not a comparison. Reckn has no notion of a better fill |
| proves the swap was optimal, or fairly priced | Optimality is not an input, so it is not a conclusion |
| MEV or slippage **protection** | Reckn does not change execution. It decides a **payment, afterwards** |
| verifies Uniswap | What is verified is *one CALL the deal named, against the prestate the deal named*. Uniswap is where that CALL happens to go |
| proves mainnet state | `state_root` is bound to a block header **off-chain** (`reexec-evm::header`), not on the adjudication path. Same boundary as the Solana side, and it does not move |

---

## 2. What exists before the event — **pre-existing work, measured 2026-09-08**

**This whole section is disclosure.** It is what a judge must be told existed before 09-25.

### 2.1 In the repository, before this document

`RecknZkEscrow` (no constructor, no `immutable`, no owner), `RecknVerdictVerifier`, the SP1
re-execution guest `program-revm`, the MPT-verified witness path in `reexec-evm`, the
`eth_createAccessList` → `eth_getProof` witness builder in `keeper`, and settlement on two
public testnets (Arc, Tempo). None of it was written for Uniswap or for this event.

### 2.2 Measured on 2026-09-08, against Ethereum mainnet

A real `SwapRouter02.exactInputSingle` (WETH → USDC, 0.05 % pool, 0.1 WETH) was re-executed
by the **unmodified** guest. No product code was written to obtain these numbers; the
measuring harness is not part of the product.

| | measured |
|---|---|
| witness | **7 accounts, 12 storage slots, 141 trie nodes, 75,413 bytes of code** |
| gas of the swap | **117,655** |
| result | `pre` 50,828,497,920 → `post` 51,074,921,121, **delta 246,423,201** (246.42 USDC for 0.1 WETH) |
| verdict at `min = delta` | **Reproduced** — 13,006,200 cycles |
| verdict at `min = delta + 1` | **Failed** — 13,006,175 cycles |
| against the existing fixture | 406,715 cycles → **32.0×** |
| **Groth16 proof, end to end** | **497.40 s** (setup 1.56 s) on this laptop's CPU, no prover network |
| against the existing fixture's 335.02 s | **1.49×** — for 32× the cycles |

**Three findings that decide the design, and one that closes a risk.**

1. **The predicate needs no change.** The guest's check is already `(address, slot, min,
   max)` over a post-state delta. Point it at the output token's balance slot —
   `check.slot = keccak256(recipient ‖ 9)` for USDC — and *that is* the min-out condition.
   The slot was confirmed present in the access list, so the witness contains it **by
   construction**.
2. **The witness needs no new machinery.** `eth_createAccessList` returns the transitively
   touched set; `eth_getProof` materialises it. Both already exist in `keeper`.
3. **The contract needs no change**, so `AGENTS.md` §0 is untouched and `no-keys.sh` keeps
   its meaning.
4. **The cost is real but bounded.** 13.0 M cycles, dominated by revm interpreting 117,655
   gas — not by trie verification and not by hashing 75 KB of code. Shrinking the witness
   would not help much; this is the honest price of the path.
5. **Proving is not the obstacle it was assumed to be.** An end-to-end Groth16 proof of the
   real swap took **8 min 17 s on a laptop CPU**. Thirty-two times the cycles cost only
   **1.49×** the wall clock, because the gnark wrap dominates and is close to fixed. An
   extrapolation made before measuring said 20–25 minutes and would have shaped the plan
   around a constraint that does not exist. A prover network is **not** required for this
   slice; §7.2 stands only as a fallback.

### 2.2b The binding separates deals that execute identically

Measured the same day, by varying one committed field at a time:

| variation | outcome | `dealBinding` |
|---|---|---|
| baseline | Reproduced | `0x31d91cfc…` |
| `check.min` + 1 — **same execution**, different floor | Failed | `0x3855ca85…` |
| `plan.gas_limit` + 1 — **same outcome**, different plan | Reproduced | `0x4ea71efd…` |

Both the predicate and the plan are inside the binding, so a proof of one deal cannot settle
another **even when the execution and the result are identical**. That is the property U-3
and U-4 exist to demonstrate on-chain; here it is shown at the guest level.

### 2.3 Two constraints found by measuring, not by reading

- **`ecrecover` is on the guest's divergent-precompile list** (`program-revm/src/main.rs`,
  `DIVERGENT_PRECOMPILE_LAST_BYTES`), and `zk-verdict/README.md`'s honest scope says the
  guest and the off-chain engine run **different implementations** of the precompiles with
  equivalence unverified. **Permit2's signature path is therefore out of scope**, which rules
  out Universal Router for this slice. v3 through `SwapRouter02` touches no precompile.
- **The public RPC serves no archive state.** Anchors must be recent blocks. This is a
  demo-day dependency, not a design problem — see §7.

---

## 3. Design

**No contract change. No guest change. No new predicate.** A deal escrows the **agent's
fee**, names the anchor and the swap as its binding, and settles on the proof.

```
buyer  fund(dealId, agent, feeToken, fee, verifier, codehash, dealBinding)
                                                                  |
dealBinding = H( state_root ‖ env ‖ (tokenOut, balanceSlot(recipient), minOut, max) ‖ (caller, router, calldata) )
                                                                  |
agent  executes the swap on Uniswap                               |
       re-executes it in the guest against the committed prestate |
       settleWithProof(dealId, publicValues, proof) --------------+
                Reproduced -> fee to the agent
                Failed     -> fee back to the buyer
```

**What the escrow custodies is the fee, never the principal.** The swap moves the trader's
own funds through Uniswap in the ordinary way; Reckn never touches them.

---

## 4. What will be built **during** the event (2026-09-25 → 09-27)

Nothing below exists. This is the "substantive new features developed during the event" the
Continuity Track requires, and it is the list a judge should be able to check commit by
commit.

| # | to build | why it is not already done |
|---|---|---|
| 1 | **Host-side binding calculator** — a buyer computes `dealBinding` from the deal terms **before the agent works** | `docs/integrate.md` already records this as a gap: today's scripts read `dealBinding` out of a proof fixture, which is fine for a demo and **wrong for a buyer** |
| 2 | **Anchor + deal construction** for a named swap, and fixture generation | — |
| 3 | **Settlement wiring**: fund the fee, settle on the proof, on a public chain | — |
| 4 | **The test matrix in §5** | — |
| 5 | **`FEEDBACK.md`** and the Uniswap Developer Feedback Form | prize qualification |
| 6 | **A judge-checkable surface** in the style of the Arc and Tempo pages | — |

---

## 5. Acceptance criteria

| # | condition |
|---|---|
| **U-1** | min-out met → `Reproduced` → **the fee is released to the agent** |
| **U-2** | min-out not met (the same swap, floor raised by one unit) → `Failed` → **the buyer is refunded** |
| **U-3** | a **real proof of a different swap** → `BindingMismatch()`, and **no token moves** |
| **U-4a** | `check.address` changed to another token → binding mismatch |
| **U-4b** | `check.slot` changed to **another recipient's** balance → binding mismatch. This is what proves *who receives it* is inside the binding |
| **U-4c** | `plan.calldata` changed to another route or pool → binding mismatch |
| **U-5** | the swap **reverts** → `Failed`. Execution failure and floor failure land on the same side, deliberately |
| **U-6** | a touched slot removed from the witness → the guest **cannot produce a proof** (`P-5/P-6/P-7`). It must not read zero and call it `Failed` |
| **U-7** | `minOut = 0` → satisfied by doing nothing. The limit `zk-verdict/README.md` already states, pinned by a test so no one can claim more later |
| **U-8** | the same proof submitted twice → `BadState` |

**U-1 and U-2 were already observed on mainnet data on 2026-09-08** (§2.2) — with the guest,
not with the escrow. Wiring them to a settlement is event work.

---

## 6. The rules boundary — the part with teeth

ETHGlobal's rules, quoted:

> "you may build on an existing codebase according to the rules of that track"
> "must include **substantive new features, improvements, or functionality developed during
> the event**"
> "must clearly document what work existed before the hackathon"
> "you must **disclose any pre-existing work in writing to the ETHGlobal team** and include
> full details in your submission (repo history, video, and description)"
> "You must **use version control for your code throughout the course of the event**. Any
> repositories with single commits of large files without proper history will be default
> assumed to be unqualified"
> violations: "the project may be **disqualified, prizes revoked, and the team may be banned
> from future events**"

**Consequences, stated as rules for ourselves:**

1. **§4 is not to be built before 2026-09-25.** Building it now and re-committing it during
   the event is the exact practice these rules exist to prevent, and this repository's own
   `AGENTS.md` §4 already forbids it: *"事前に書いて当日1発 push は不可"*.
2. **The repository is public and every commit is dated.** That is a feature here: the
   boundary is checkable by anyone, and it is checkable *against us*. It also means a
   pre-event commit cannot later be presented as event work.
3. **Continuous commits during the event**, not one large one. Already this repository's
   practice.
4. **The written disclosure to ETHGlobal is a separate action from the submission form.**
   `docs/ethonline-2026/DISCLOSURE.md` is the template; a Tokyo equivalent is founder work.
5. **Concurrency with Crypto World's Fair must be disclosed.** Tokyo (09-25 → 09-27) falls
   inside CWF (09-14 → 10-12). The rules page contains no clause found on concurrent
   submission to a non-ETHGlobal event — **absence of a prohibition is not permission**, so
   it is disclosed rather than assumed.

---

## 7. Founder actions, and why each is legitimate pre-work

Preparing infrastructure is not building the submission. Each of these is needed *before*
09-25 and none of them is a feature.

1. **An Ethereum RPC key with `eth_getProof` and `eth_createAccessList`.** The public
   endpoint used on 09-08 works for recent blocks but **serves no archive state** and will
   rate-limit. A demo that depends on a public endpoint over conference wifi is a demo that
   fails in the room.
2. ~~**Decide the proving path.**~~ **Closed by measurement (§2.2): 497 s on a laptop.** A
   Succinct Prover Network account is a **fallback**, not a prerequisite. Worth having
   anyway if the venue machine is slower than this one, but the plan no longer depends on
   it. Generating fixtures in advance is *not* an option for anything in §4 — that would be
   pre-building the submission.
3. **Read the Continuity Track's own page** for Tokyo, not this summary of it.
4. **The written pre-existing-work disclosure to ETHGlobal.**

## 8. Non-goals

- **No v4 and no Universal Router** in this slice (§2.3).
- **No new function on `RecknZkEscrow`.** A payable path or a router-aware entry point would
  change the surface `AGENTS.md` §0 enumerates, which is a change to the central claim.
- **No claim about Uniswap's quality, safety, or pricing.** See §1.1.
- **No anchoring claim.** `state_root` ↔ block header stays off the adjudication path.

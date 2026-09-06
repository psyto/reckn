# 005 — Arc / USDC

## 1. The claim, and what 005 is not

### 1.1 The claim (one sentence)

> **`RecknZkEscrow` settles a deal denominated in Circle's USDC on Arc, in USDC's own
> units, without a single change to the contract** — because a deal names its payment
> token at funding, so a chain whose money is USDC needs no adaptation, only evidence.

### 1.2 Non-goals — including the one that is tempting

- **No `payable` path.** Arc's native gas token *is* USDC, so a native-value escrow is
  the obvious idea. It is prohibited: `AGENTS.md` §0 enumerates the function surface as
  `fund / settleWithProof / refundAfterDeadline`, and a fourth entry point is a change
  to the central claim, not an Arc feature. The ERC-20 face Circle predeploys at
  `0x3600…0000` is the same balance, and it needs nothing new.
- **No mainnet.** Circle had not published Arc mainnet addresses as of 2026-09-06
  (`arc.json`), so "deployment-ready" is the ceiling, and the missing address list is a
  precondition rather than a task.
- **No second adjudicator.** Arc is a *payment rail*. Nothing here touches who decides.
- **005 does not claim Arc-specific soundness.** Every settlement property is proved on
  the shared escrow by 008 and 009; 005 proves the properties that USDC's *units* and
  *semantics* put at risk, and nothing else.

### 1.3 What USDC actually risks, which is why this task is not empty

Three of them, and each has a test rather than a sentence:

1. **6 decimals, not 18.** An escrow that rounds, truncates, or assumes `1e18` moves the
   wrong amount. `test_ARC04` requires exact movement at six-decimal amounts.
2. **Revert, not `false`.** Circle's USDC reverts on a failed transfer instead of
   returning `false`, so an escrow that checks a boolean return sees success on a
   revert-style token only because the call already unwound. `test_ARC05` funds a deal
   whose seller is **blacklisted** and requires settlement to revert **with the money
   still in the escrow** — not swallowed, not stranded silently.
3. **A frozen recipient is not a theoretical case.** It happened to us on Arc testnet on
   the first live settlement, and the deal is still funded, refundable by
   `refundAfterDeadline` and by nothing else. Recorded in `arc.json`, not hidden.

## 2. Where the wire ends

**Connected**: the seven `test_ARC0*` tests settle real Groth16 proofs against a
six-decimal, revert-on-failure, blacklisting USDC mock; `scripts/arc-usdc-e2e.sh` runs
the same path on a local anvil at Arc's chain id; and the contracts are **deployed on
Arc testnet**, where four settlements moved real testnet USDC — two of them decided by
proofs about work performed on Solana.

**Not connected**: Arc mainnet (no published addresses); and `arc.json`'s network
constants are **transcribed from Circle's documentation**, so they are only as right as
that reading was. The gate below checks that the repository agrees with the record; it
cannot check the record against Circle. That boundary is the same shape as the guest's
`bank_hash`: internal consistency is not provenance.

## 3. What 005 adds, and why it is two transcription gates

The contract needed no change, so 005's deliverable is evidence — and the evidence is
**numbers copied by hand into six files**. On 2026-09-06, four live transaction hashes
were transcribed into the demo page and **two of the four were wrong**: right length,
right prefix, plausible hex, linking to nothing. Review did not catch it; reading the
record did.

A receipt nobody can check is worth less than no receipt, because it looks like proof.
So both transcriptions are closed by a gate rather than by care:

- `arc-receipts.sh` — every arcscan link in the repository names a settlement `arc.json`
  records, **and** every settlement it records is linked somewhere. The first direction
  catches typos; the second catches a settlement quietly dropped from the story.
- `arc-constants.sh` — the chain id, the three Arc URLs, and any address **claiming to
  be the USDC predeploy** must equal the record, and each recorded constant must appear
  at least once.

Both scan once, with `--include` filters, and neither pipes into a short-circuiting
reader: `sed … | grep -q` SIGPIPEs its producer and reports a **false pass**, which has
bitten this repository twice.

## 7. Acceptance

### 7.1 Manifest

```ac005-manifest
AC-0    script  -       bash scripts/no-keys.sh                        -      ✓ the claim holds: no key can move a funded escrow.
AC-1    forge   _ARC0   -                                              7      forge _ARC0_ — {N} tests, all Success
AC-2    script  -       bash zk-verdict/scripts/arc-receipts.sh        -      arc-receipts: {L} linked tx hashes all recorded, {R}/{R} recorded settlements linked; witness={witness}
AC-3    script  -       bash zk-verdict/scripts/arc-constants.sh       -      arc-constants: {C} Arc-shaped literals all match the record, 5/5 recorded constants present; witness={witness}
```

**AC-1 is a set, not a count.** `ac005.sh` requires these seven ids to be present and
Success — a suite that deletes one and adds another keeps the total at seven and must
still fail:

```ac005-tests
test_ARC01_usdc_deal_settles_to_the_seller_on_a_real_proof
test_ARC02_usdc_deal_refunds_the_buyer_on_a_proven_failure
test_ARC03_a_proof_of_another_execution_cannot_take_the_usdc
test_ARC04_six_decimal_amounts_move_exactly
test_ARC05_a_blacklisted_seller_makes_settlement_revert_and_the_money_stays
test_ARC06_no_usdc_is_created_or_destroyed_by_a_settlement
test_ARC07_usdc_on_arc_settled_by_a_proof_about_work_on_solana
```

### 7.2 Witness recipes

`ac005.sh` recomputes each `script` row's witness itself, without invoking that row's
command, so a stub must print a **hardcoded digest** — stale the moment a witnessed byte
moves.

| row | witness set |
|---|---|
| AC-0 | **exempt, in writing** — its evidence line is `AGENTS.md` §0's declared output, and 005 must not restyle it. What replaces the witness: AC-0 is the *first* row, so a tree whose central claim is broken fails 005 before any Arc row runs. |
| AC-2 | the settlement transaction hashes `arc.json` records, `LC_ALL=C` sorted, one per line |
| AC-3 | the five recorded constants — chain id, USDC predeploy, RPC, explorer, faucet — one per line, in that order |

### 7.3 Substitution tokens

`{N}` (measured: the number of ids in the `ac005-tests` block), `{L}`, `{R}`, `{C}`
(measured by the runner from the same sources the row's command reads, never
transcribed) and `{witness}`.

### 7.4 What landing this gate tells us about AC-12's closure

`both-green.sh` discovers sibling gates by the pattern `^ac[0-9]{3}\.sh$`, and 009's
§10 already tests that the discovery is not hardcoded: mutant **M-13** drops an
executable `ac000.sh` whose body is `exit 1` into a sandbox's `zk-verdict/scripts/` and
requires AC-12 to go red. So the closure **does** find a file it was not written
against — that much is already measured, and an earlier draft of this section claimed
the opposite.

What M-13 does not show is the ordinary case: a **real** sibling gate landing in the
real tree and being adopted without a hand edit. On the commit that adds `ac005.sh`,
009's AC-12 must move from one discovered sibling to two, and its witness must change,
with **no edit to 009's manifest** — because `{G}` and `{witness}` are computed by
`ac009.sh` rather than transcribed into the document. `xvm.base.json` gains `ac005.sh`
in `siblingGates` for the other direction: a gate deleted rather than fixed must fail
rather than pass quietly.

If either of those needs a manual edit, the parameterisation was decorative even though
the discovery was not.

## 8. Limitations, recorded rather than closed

- **L-5a**: `arc.json`'s constants are checked for internal agreement only. Nothing here
  reads Circle's documentation, so a value that was mis-read on 2026-09-06 stays wrong
  and consistent. Re-read before a mainnet deployment.
- **L-5b**: `arc-constants.sh` catches an address claiming to be the USDC predeploy
  (`0x3600`-prefixed) whose tail is wrong — the realistic typo. **A typo in the prefix
  escapes it.** Two looser shapes were tried first and both produced false positives
  (any address starting `0x36`; any address ending in many zeros, which matches every
  ABI-encoded word). A check that cries wolf is a check people stop reading.
- **L-5c**: the mock is not Circle's deployed USDC. It reproduces the three behaviours
  that matter here — six decimals, revert-not-false, blacklist — and the live testnet
  settlements are the answer to what it cannot model, including the blacklist that
  actually froze one of them.
- **L-5d**: no mutation family. 008 and 009 each carry one; 005's rows are transcription
  checks whose failure mode was demonstrated live rather than simulated, and adding a
  third family before the freeze buys less than it risks.

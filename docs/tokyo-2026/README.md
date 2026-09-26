# Reckn at ETHGlobal Tokyo 2026

## Pay for work. Not for a claim.

Reckn is the Tokyo Continuity entry for **ENS** and **Uniswap Foundation**. A work replay settles
an escrow; the settlement gives a buyer one ENSv2 record-writing right; a Uniswap v4 pool reads
that record inside `beforeSwap`.

Start here:

1. **[Open the live Sepolia page](https://psyto.github.io/reckn/).** It reads the chain in the
   browser, including the parts that are not closed.
2. **[Read the receipts](RECEIPTS.md).** They tie every demo claim to a transaction.
3. **[Read the demo runbook](DEMO.md).** The 3-minute story and the live-judging spine.

## What is new for Tokyo

| New event work | Evidence |
|---|---|
| A settlement-to-ENS adapter that grants the buyer a one-record setter role and later revokes it | [`SettlementRecord.sol`](../../tokyo-2026/src/SettlementRecord.sol) |
| A Uniswap v4 `beforeSwap` hook that reads the settled record synchronously | [`RecordGatedHook.sol`](../../tokyo-2026/src/RecordGatedHook.sol) |
| Sepolia deployment, chain receipts, live demo page, tests, and visual assets | [RECEIPTS.md](RECEIPTS.md) · [media/submission](media/submission/README.md) |

The zk escrow and proof pipeline are pre-existing. The exact boundary is not inferred from this
summary: read the full [disclosure](DISCLOSURE.md).

## Judge the claim, not the prose

The v4 demonstration is three Sepolia transactions with the same sender, pool, and swap:

| State | Result |
|---|---|
| No record | [refused](https://sepolia.etherscan.io/tx/0xda60d7df7940bf25fd01466444573d0b364a8865641e97dc061096ad1f1f94be) |
| Settled record | [1.000000 in → 0.987158034 out](https://sepolia.etherscan.io/tx/0xa40bb3162ed17e084155277cd2d0a9605c1fea510ddef6df62dbf502831f5698) |
| Record cleared | [refused again](https://sepolia.etherscan.io/tx/0xce00489eb9f2ebca202643c28841360737b35bc30e81a276e47fab64e2f1fa79) |

The project does not claim to solve identity, prove that a buyer-selected verifier is trustworthy,
or gate liquidity provision. It is Sepolia, not mainnet. The live page reports whether a root
role can still override the per-record rule instead of asking a judge to trust this document.

## Submission materials

| Need | File |
|---|---|
| Form copy | [SUBMISSION-FORM.md](SUBMISSION-FORM.md) |
| Paste-safe short description | [SHORT-DESCRIPTION.txt](SHORT-DESCRIPTION.txt) |
| Paste-safe technical explanation | [HOW-ITS-MADE.txt](HOW-ITS-MADE.txt) |
| Submission images | [media/submission/README.md](media/submission/README.md) |
| AI-use disclosure | [AI-USE.md](AI-USE.md) |
| Sponsor-specific answers | [SPONSOR-CARDS.md](SPONSOR-CARDS.md) |

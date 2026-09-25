# `tokyo-2026/` — the event's own contracts

**This is where code written during ETHGlobal Tokyo 2026 lives.** It exists because the two
places that already had the dependencies cannot hold it:

- `spikes/tokyo-2026/` is **declared disposable and not ported** (`013` §7-1). Its throwaway
  helpers — `MiniProxy`, `AdapterStub`, `MockLabelStore2` — measured what the design needed and
  are not the submission.
- `zk-verdict/contracts/` has no ENS dependency, and the record surface needs both ENS and the
  escrow.

**Nothing here existed before 2026-09-25 21:00 JST.** `git log --oneline eddac8d..HEAD` is the
boundary, and `STATUS.md` records it.

## Dependencies are fetched and pinned, not committed and not borrowed

```
bash tokyo-2026/scripts/deps.sh
cd tokyo-2026 && forge test --fork-url sepolia
```

| | pinned at |
|---|---|
| `forge-std/` | v1.9.4 |
| `@sp1-contracts/` | v6.1.0 — the circuit the committed fixtures were proven against |
| `@ens/` | `ensdomains/contracts-v2` @ `48b3e2d` (2026-07-03) |
| `@openzeppelin/contracts/` | v5.0.2 |
| `@zk/` | this repository's own `zk-verdict/contracts/src` — committed, not fetched |

> **★ The first version of this file pointed `@ens/` and `@openzeppelin/` into `spikes/`,
> and said out loud that deleting the spikes would break the build.** It was worse than that:
> `lib/` is gitignored and the ENSv2 tree had been placed there by hand, so **a fresh clone of
> this repository could not compile the submission at all** — `013` §7's fallback predicate
> reads *"from a fresh clone"*, and it was false. Cloning it the way a judge would is the only
> reason that was found. `scripts/deps.sh` exists so the answer is a command rather than a
> memory, and so the submission no longer reaches into a directory this repository calls
> disposable (`013` §7-1).

## What is deployed

Addresses and receipts: [`../zk-verdict/contracts/sepolia.json`](../zk-verdict/contracts/sepolia.json),
readable form in [`../docs/tokyo-2026/RECEIPTS.md`](../docs/tokyo-2026/RECEIPTS.md), checked both
ways by `bash zk-verdict/scripts/sepolia-receipts.sh`.

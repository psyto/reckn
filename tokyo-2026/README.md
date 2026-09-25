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

## Dependencies are borrowed, not copied

`remappings.txt` points at libraries already checked out elsewhere in this repository rather than
cloning them again:

| | from |
|---|---|
| `forge-std/` | `zk-verdict/contracts/lib/` |
| `@ens/` | `spikes/tokyo-2026/lib/ens-v2/` |
| `@openzeppelin/contracts/` | `spikes/tokyo-2026/lib/oz/` |
| `@zk/` | `zk-verdict/contracts/src/` — the escrow and the verifier themselves |
| `@sp1-contracts/` | `zk-verdict/contracts/lib/` |

> **The `@ens/` and `@openzeppelin/` paths reach into `spikes/`, which this repository calls
> disposable.** What is borrowed there is a third-party checkout, not spike code, so nothing of
> the spikes' own reasoning leaks in. It does mean deleting `spikes/tokyo-2026/lib/` breaks this
> build, which is a fair trade for not cloning ENSv2 twice during a 36-hour window. **Said here
> rather than discovered later.**

## What is deployed

Addresses and receipts: [`../zk-verdict/contracts/sepolia.json`](../zk-verdict/contracts/sepolia.json),
readable form in [`../docs/tokyo-2026/RECEIPTS.md`](../docs/tokyo-2026/RECEIPTS.md), checked both
ways by `bash zk-verdict/scripts/sepolia-receipts.sh`.

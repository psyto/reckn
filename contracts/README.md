# Reckn contracts (EVM V1 — settlement half)

Frame-thin skeleton of the on-chain settlement layer. Stores canonical
commitments and acts on a registered resolver's EIP-712 signature. Holds no
EVM/Solana/RPC-specific types (cross-VM cut-line). This is **not** trustless
settlement — see `../docs/protocol-architecture.md` for the reproducibility vs
settlement-authority split.

## Layout

- `src/RecknEscrow.sol` — 4-state machine (Held → Delivered → Disputed →
  Resolved) with four deadlines and timeout escape hatches so funds never lock.
- `src/ResolverRegistry.sol` — allow-list of resolver keys and exact
  (backendId, backendVersionHash) pairs.
- `src/libraries/VerdictHash.sol` — EIP-712 hashing + low-s recovery of a
  `VerdictCommitment`.
- `src/interfaces/IUSDC3009.sol` — minimal EIP-3009 pull + transfer surface.

## Build & test

`lib/` is git-ignored; install the test dependency first:

```bash
forge install foundry-rs/forge-std --no-git
forge test -vv
```

Requires `via_ir = true` (set in `foundry.toml`) — `fundWithAuthorization` has a
wide argument list.

## Open protocol questions (blocked on Codex, review C1/C2)

- **C2 — seller's degrees of freedom.** This skeleton assumes the seller supplies
  the execution plan in `delivery` and the spec fixes anchor+predicate. If the
  plan is instead fixed at funding time, the escrow is degenerate. Resolve before
  building `reexec-evm`.
- **C1 — data-availability responsibility.** Timeout currently refunds the buyer
  (delivery/anchor availability treated as the seller's burden). Confirm this is
  the intended default and which party must persist which artifact.

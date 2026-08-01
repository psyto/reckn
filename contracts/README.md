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
wide argument list. **57 tests currently pass**: lifecycle (reproduced/failed
verdicts), timeout escape hatches (review C1), settlement-authority guards
(unknown resolver, commitment mismatch, disallowed backend, double-resolve),
nonzero-window guards (review M2), a value-conservation fuzz test, optimistic
settlement + K-of-N quorum slashing, and the opt-in **seller data-availability
bond** (posted at `deliver`, forfeited to the buyer only on a dispute timeout,
returned on every other exit).

## Resolved protocol decisions (review C1/C2)

- **Seller freedom (C2):** funding fixes the spec's anchor, predicate, and
  delivery schema. The seller supplies the concrete execution plan and claim in
  `delivery`; re-execution tests that plan against the fixed predicate. See the
  EVM V1 profile in `../docs/protocol-architecture.md`.
- **Data availability / timeout (C1):** buyer-authored spec and anchor bytes must
  be published at funding. Seller supplies delivery plus replay witness at
  `deliver()`. After a seller delivery, no valid verdict by `resolveDeadline`
  refunds the buyer. The next contract pass must add raw spec/anchor publication
  or checked content-store registration; hashes alone are not sufficient.

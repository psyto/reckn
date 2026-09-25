#!/usr/bin/env bash
# deps — everything `tokyo-2026` needs, fetched into its own lib/.
#
# This exists because a fresh clone of the repository could not build the submission.
# `013` §7's fallback predicate is "from a FRESH CLONE, R-2, R-10 and R-12 pass", and on
# 2026-09-25 that was false: `lib/` is gitignored, and the ENSv2 tree had been placed by hand
# under `spikes/tokyo-2026/lib/` with nothing to reproduce it. A judge cloning `psyto/reckn`
# got a compile error, not a test run.
#
# It also removes a dependency that should never have existed: the submission's contracts were
# reaching into `spikes/`, which this repository declares **disposable and not ported**
# (`013` §7-1). Deleting the spikes would have broken the submission. Now `tokyo-2026` owns
# what it needs and borrows only `@zk/` — the escrow's own committed source.
#
# Everything is pinned. An unpinned dependency is a demo that works until upstream moves.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lib="$here/lib"
root=$(cd "$here/.." && pwd)
mkdir -p "$lib"

say() { printf '  %s\n' "$*"; }

# forge-std ------------------------------------------------------------------------------
if [[ ! -f "$lib/forge-std/src/Test.sol" ]]; then
  say "forge-std…"
  git clone --quiet --depth 1 --branch v1.9.4 \
    https://github.com/foundry-rs/forge-std.git "$lib/forge-std"
fi

# SP1 verifier contracts — v6.1.0, the circuit the committed fixtures were proven against ----
if [[ ! -f "$lib/sp1-contracts/contracts/src/ISP1Verifier.sol" ]]; then
  say "sp1-contracts v6.1.0…"
  rm -rf "$lib/sp1-contracts"
  git clone --quiet --depth 1 --branch v6.1.0 \
    https://github.com/succinctlabs/sp1-contracts.git "$lib/sp1-contracts"
fi

# ENSv2 — pinned to the commit the measurements were taken against ------------------------
# 48b3e2d "Post Audit Changes", 2026-07-03. Note its deployments/ directory is a snapshot of
# a DIFFERENT live family than the one this submission registered into; the addresses that
# matter are in zk-verdict/contracts/sepolia.json, reached from the chain.
ENS_COMMIT=48b3e2d39513b9dd32ef1850877a29009bc807b9
if [[ ! -f "$lib/ens-v2/contracts/src/registry/PermissionedRegistry.sol" ]]; then
  say "ensdomains/contracts-v2 @ ${ENS_COMMIT:0:7}…"
  rm -rf "$lib/ens-v2"
  git clone --quiet https://github.com/ensdomains/contracts-v2.git "$lib/ens-v2"
  ( cd "$lib/ens-v2" && git checkout --quiet "$ENS_COMMIT" )
fi

# OpenZeppelin ----------------------------------------------------------------------------
if [[ ! -f "$lib/oz/contracts/token/ERC20/IERC20.sol" ]]; then
  say "openzeppelin-contracts v5.0.2…"
  git clone --quiet --depth 1 --branch v5.0.2 \
    https://github.com/OpenZeppelin/openzeppelin-contracts.git "$lib/oz"
fi

# The escrow's own lib, because @zk/ imports @sp1-contracts/ from there -------------------
if [[ ! -f "$root/zk-verdict/contracts/lib/forge-std/src/Test.sol" ]]; then
  say "zk-verdict/contracts deps (via its own e2e script's fetcher)…"
  mkdir -p "$root/zk-verdict/contracts/lib"
  git clone --quiet --depth 1 --branch v1.9.4 \
    https://github.com/foundry-rs/forge-std.git "$root/zk-verdict/contracts/lib/forge-std"
fi

say "ready. now: cd tokyo-2026 && forge test --fork-url sepolia"

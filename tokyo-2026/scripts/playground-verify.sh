#!/usr/bin/env bash
# playground-verify — run AFTER renounce.sh. A stranger mints and trades.
#
# This is the acceptance condition for the playground pool, and without it the pool is a claim
# rather than a thing. Everything before this point can be told; only this can be tried.
#
# It runs as `reckn-agent2` -- the third address, which has never held a role on the resolver,
# never funded a deal, and is not the buyer. It mints its own test tokens, because the demo
# tokens are open to anyone, and swaps. Root is gone by now, so nobody could have opened this
# pool for it: the record it trades on was written by one buyer, once, under a right that a
# settlement created and that has since been revoked.
#
# Three keystore prompts (reckn-agent2).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$here"
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}
J="$here/playground.json"; LOG="$here/playground-verify-txs.txt"
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
STRANGER=0xF81dFf68aE2581CfCb62D68D824403Ae9F4d68d4
ALL=0x1111111111111111111111111111111111111111111111111111111111111111

say() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
die() { printf '\n\033[31mplayground-verify: %s\033[0m\n' "$*" >&2; exit 1; }
send() {
  local label=$1; shift
  local out; out=$(cast send "$@" --rpc-url "$SEPOLIA_RPC")
  local h st; h=$(printf '%s' "$out" | awk '/^transactionHash/{print $2}'); st=$(printf '%s' "$out" | awk '/^status/{print $2}')
  printf '   status %s  gas %s\n   https://sepolia.etherscan.io/tx/%s\n' "$st" "$(printf '%s' "$out" | awk '/^gasUsed/{print $2}')" "$h"
  printf '%s %s\n' "$label" "$h" >> "$LOG"
  [[ "$st" == "1" ]] || die "$label failed"
}

[[ -f "$J" ]] || die "no playground.json — run scripts/playground.sh first"
HOOK=$(jq -r .hook "$J"); ROUTER=$(jq -r .router "$J")
T0=$(jq -r .token0 "$J"); T1=$(jq -r .token1 "$J")

# The point of this script is what it proves AFTER the key is gone. Running it before proves
# much less, so it refuses.
[[ "$(cast call "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$AGENT" --rpc-url "$READ_RPC")" == "false" ]] \
  || die "root has NOT been renounced yet. Run scripts/renounce.sh first — trading before that proves nothing about who opened the pool."
[[ "$(cast call "$HOOK" 'isOpen()(bool)' --rpc-url "$READ_RPC")" == "true" ]] \
  || die "the playground pool is not open. Something cleared the record."
: > "$LOG"

say "0. root is gone, and the pool is still open"
printf '   hook   %s\n   open   true\n   root   renounced\n' "$HOOK"

say "1. a stranger mints its own test tokens  [reckn-agent2]"
send strangerMint0 "$T0" "mint(address,uint256)" "$STRANGER" 5000000000000000000 --account reckn-agent2
send strangerMint1 "$T1" "mint(address,uint256)" "$STRANGER" 5000000000000000000 --account reckn-agent2

# The router holds the pool's side of a swap and settles it, so the stranger funds it and then
# sends the swap. What is being shown is not custody -- it is that a transaction from an address
# that was never granted anything now succeeds, and would not have an hour ago.
say "2. it sends them to the router and trades  [reckn-agent2]"
send strangerFund "$T0" "transfer(address,uint256)" "$ROUTER" 2000000000000000000 --account reckn-agent2
B1=$(cast call "$T1" "balanceOf(address)(uint256)" "$ROUTER" --rpc-url "$READ_RPC" | awk '{print $1}')
PK="($T0,$T1,3000,60,$HOOK)"
send strangerSwap "$ROUTER" "swap((address,address,uint24,int24,address),(bool,int256,uint160))" \
  "$PK" "(true,-1000000000000000000,4295128740)" --account reckn-agent2
A1=$(cast call "$T1" "balanceOf(address)(uint256)" "$ROUTER" --rpc-url "$READ_RPC" | awk '{print $1}')

say "done"
python3 -c "print('   token1 received', ($A1 - $B1)/1e18)"
echo "   A pool opened by one settlement, traded by somebody who was never granted anything,"
echo "   after the only key that could have opened it was destroyed."
cat "$LOG"

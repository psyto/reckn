#!/usr/bin/env bash
# hook-onchain — put the gate on Sepolia, and film it refusing, passing, and refusing again.
#
# Everything about this hook has so far been measured on a FORK. That is the one part of the
# submission with no receipt, and the rest of it is built on receipts, so a judge would notice
# the asymmetry before anything else. This sends the transactions.
#
# The deal it uses is settled and its window opened, but NOT written, because a pool that is
# already open cannot be filmed opening.
#
# Eight keystore prompts. Stages 1 and 2 are `forge script`, which prompts once and sends many;
# the tail alternates between the buyer and the agent, so those are one transaction each.
#
# The two refusals are sent with --gas-limit on purpose: a reverting transaction cannot be gas
# estimated, and the point is to land a FAILED transaction on chain that anybody can open. Beat
# 1 works the same way.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$here"
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}
J="$here/hook-onchain.json"
LOG="$here/hook-onchain-txs.txt"

ADAPTER=0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
VERIFIER=0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608
DNS=0x056167656e74057265636b6e0365746800
BUYER=0x4b55f9e4d87505F3347c7CAFcB8C7eb589970eE3
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321

say()  { printf '\n\033[1m── %s\033[0m\n' "$*"; }
link() { printf '   https://sepolia.etherscan.io/tx/%s\n' "$1"; }

# Records the hash under a label so the ledger can be built from this file instead of from a
# human reading the terminal. This repo has been bitten by hand-copied hashes before.
send() {
  local label=$1; shift
  local out
  out=$(cast send "$@" --rpc-url "$SEPOLIA_RPC")
  local h st
  h=$(printf '%s' "$out" | awk '/^transactionHash/{print $2}')
  st=$(printf '%s' "$out" | awk '/^status/{print $2}')
  printf '   status %s  gas %s\n' "$st" "$(printf '%s' "$out" | awk '/^gasUsed/{print $2}')"
  link "$h"
  printf '%s %s %s\n' "$label" "$h" "$st" >> "$LOG"
}

: > "$LOG"

say "1. the buyer funds the deal that will earn the record  [reckn-buyer]"
forge script script/HookOnchain.s.sol:HookOnchain --sig 'stage1()' \
  --rpc-url "$SEPOLIA_RPC" --account reckn-buyer --sender "$BUYER" --broadcast \
  | grep -E 'ONCHAIN EXECUTION|Error'

say "2. settle it, open the window, stand up the pool  [reckn-agent]"
echo "   (nothing is written here -- the refusal has to be filmable)"
forge script script/HookOnchain.s.sol:HookOnchain --sig 'stage2()' \
  --rpc-url "$SEPOLIA_RPC" --account reckn-agent --sender "$AGENT" --broadcast \
  | grep -E 'ONCHAIN EXECUTION|Error'

[[ -f "$J" ]] || { echo "hook-onchain: stage 2 wrote no address file" >&2; exit 1; }
T0=$(jq -r .token0 "$J"); T1=$(jq -r .token1 "$J")
HOOK=$(jq -r .hook "$J"); ROUTER=$(jq -r .router "$J")
KEY=$(jq -r .recordKey "$J"); DEAL=$(jq -r .dealId "$J")
PK="($T0,$T1,3000,60,$HOOK)"
SP="(true,-1000000000000000000,4295128740)"
SIG="swap((address,address,uint24,int24,address),(bool,int256,uint160))"

printf '\n   hook    %s   (flags %s)\n   router  %s\n   key     %s\n' \
  "$HOOK" "$(python3 -c "print(hex(int('$HOOK',16)&0x3fff))")" "$ROUTER" "$KEY"

say "3. BEAT 5, shot one — a swap with no record  [reckn-agent]   expect: FAILED"
send swapRefused "$ROUTER" "$SIG" "$PK" "$SP" --account reckn-agent --gas-limit 400000
echo "   isOpen = $(cast call "$HOOK" 'isOpen()(bool)' --rpc-url "$READ_RPC")"
echo "   >>> screenshot this one before going on <<<"

say "4. the buyer writes the record  [reckn-buyer]"
BLK=$(cast block-number --rpc-url "$READ_RPC")
VALUE=$(cast call "$ADAPTER" "recordValue(uint8,uint64,address)(string)" 0 "$BLK" "$VERIFIER" --rpc-url "$READ_RPC" | tr -d '"')
echo "   value: $VALUE"
send recordWritten "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$KEY" "$VALUE" --account reckn-buyer
echo "   isOpen = $(cast call "$HOOK" 'isOpen()(bool)' --rpc-url "$READ_RPC")"

say "5. BEAT 5, shot two — the SAME swap  [reckn-agent]   expect: success, balances move"
B0=$(cast call "$T0" "balanceOf(address)(uint256)" "$ROUTER" --rpc-url "$READ_RPC" | awk '{print $1}')
send swapExecuted "$ROUTER" "$SIG" "$PK" "$SP" --account reckn-agent
A0=$(cast call "$T0" "balanceOf(address)(uint256)" "$ROUTER" --rpc-url "$READ_RPC" | awk '{print $1}')
A1=$(cast call "$T1" "balanceOf(address)(uint256)" "$ROUTER" --rpc-url "$READ_RPC" | awk '{print $1}')
python3 -c "print('   token0 spent   ', ($B0 - $A0)/1e18)"
echo "   >>> screenshot this one <<<"

say "6. the buyer clears the record  [reckn-buyer]"
send recordCleared "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$KEY" "" --account reckn-buyer
echo "   isOpen = $(cast call "$HOOK" 'isOpen()(bool)' --rpc-url "$READ_RPC")"

say "7. BEAT 5, shot three — the same swap again  [reckn-agent]   expect: FAILED"
send swapRefusedAgain "$ROUTER" "$SIG" "$PK" "$SP" --account reckn-agent --gas-limit 400000
echo "   >>> screenshot this one <<<"

say "8. the window closes  [reckn-buyer]"
send windowClosed "$ADAPTER" "close(bytes32)" "$DEAL" --account reckn-buyer

say "done"
echo "   the pool is live and shut. Hashes in $(basename "$LOG"):"
cat "$LOG"

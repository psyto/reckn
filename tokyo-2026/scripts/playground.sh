#!/usr/bin/env bash
# playground — a pool that a settlement opened, and that survives us throwing the key away.
#
# The evidence pool (0x68116b80…) is CLOSED, on purpose: its last act was clearing the record,
# which is the third of beat 5's transactions and the proof that the record is what gates it.
# Because `opened[dealId]` never resets and the hook's key is fixed at construction, nothing can
# ever reopen it. That is the right ending for a piece of evidence and the wrong one for a thing
# a person might want to touch.
#
# So: a SECOND pool, identical code, standing at the other end of the same argument.
#
#   settle -> the buyer writes -> THE BUYER CLOSES -> renounce -> a stranger trades
#
# `close` matters. Leaving the window open would leave a standing right, which `013` §3.3 says
# should not exist; closing revokes the role and leaves the record. After the renounce nobody
# can write that key again -- not the buyer, not a stranger, not us -- so the pool is open
# permanently and attributably, on the strength of one settlement.
#
# THIS SCRIPT STOPS BEFORE THE RENOUNCE. Run renounce.sh next, then playground-verify.sh.
# Around 8 keystore prompts.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$here"
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}

export DEAL_TAG=${DEAL_TAG:-reckn-tokyo-playground-1}
export HOOK_OUT=./playground.json
J="$here/playground.json"
LOG="$here/playground-txs.txt"

ADAPTER=0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
VERIFIER=0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608
DNS=0x056167656e74057265636b6e0365746800
BUYER=0x4b55f9e4d87505F3347c7CAFcB8C7eb589970eE3
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321

say()  { printf '\n\033[1m── %s\033[0m\n' "$*"; }
die()  { printf '\n\033[31mplayground: %s\033[0m\n' "$*" >&2; exit 1; }
send() {
  local label=$1; shift
  local out; out=$(cast send "$@" --rpc-url "$SEPOLIA_RPC")
  local h st
  h=$(printf '%s' "$out" | awk '/^transactionHash/{print $2}')
  st=$(printf '%s' "$out" | awk '/^status/{print $2}')
  printf '   status %s  gas %s\n   https://sepolia.etherscan.io/tx/%s\n' \
    "$st" "$(printf '%s' "$out" | awk '/^gasUsed/{print $2}')" "$h"
  printf '%s %s\n' "$label" "$h" >> "$LOG"
  [[ "$st" == "1" ]] || die "$label failed — stop here"
}

# Refuse if root is already gone: after the renounce the adapter can still grant (it holds its
# own root), but this script's whole point is to finish BEFORE it, and running it after would
# quietly produce a pool with a different provenance story.
ALL=0x1111111111111111111111111111111111111111111111111111111111111111
[[ "$(cast call "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$AGENT" --rpc-url "$READ_RPC")" == "true" ]] \
  || die "root is already renounced. This pool was meant to be settled BEFORE that, so that the renounce is what it survives."
: > "$LOG"

say "1. the buyer mints test USDC and funds a new deal  [reckn-buyer]"
forge script script/HookOnchain.s.sol:HookOnchain --sig 'stage1()' \
  --rpc-url "$SEPOLIA_RPC" --account reckn-buyer --sender "$BUYER" --broadcast \
  | grep -E 'ONCHAIN EXECUTION|Error'

say "2. settle it, open the window, stand up a SECOND pool  [reckn-agent]"
forge script script/HookOnchain.s.sol:HookOnchain --sig 'stage2()' \
  --rpc-url "$SEPOLIA_RPC" --account reckn-agent --sender "$AGENT" --broadcast \
  | grep -E 'ONCHAIN EXECUTION|Error'

[[ -f "$J" ]] || die "stage 2 wrote no address file"
HOOK=$(jq -r .hook "$J"); ROUTER=$(jq -r .router "$J")
T0=$(jq -r .token0 "$J"); T1=$(jq -r .token1 "$J")
KEY=$(jq -r .recordKey "$J"); DEAL=$(jq -r .dealId "$J")
printf '\n   hook   %s  (flags %s)\n   pool   %s / %s\n   key    %s\n' \
  "$HOOK" "$(python3 -c "print(hex(int('$HOOK',16)&0x3fff))")" "$T0" "$T1" "$KEY"
[[ "$(cast call "$HOOK" 'isOpen()(bool)' --rpc-url "$READ_RPC")" == "false" ]] \
  || die "the new pool is open before anything was written — that cannot be right"

say "3. the buyer writes the record  [reckn-buyer]   — not root, and this is the whole point"
BLK=$(cast block-number --rpc-url "$READ_RPC")
VALUE=$(cast call "$ADAPTER" "recordValue(uint8,uint64,address)(string)" 0 "$BLK" "$VERIFIER" --rpc-url "$READ_RPC" | tr -d '"')
echo "   $VALUE"
send playgroundWrite "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$KEY" "$VALUE" --account reckn-buyer

say "4. the buyer CLOSES the window  [reckn-buyer]   — the right ends, the record stays"
send playgroundClose "$ADAPTER" "close(bytes32)" "$DEAL" --account reckn-buyer

say "5. what is true now"
printf '   pool open        %s\n' "$(cast call "$HOOK" 'isOpen()(bool)' --rpc-url "$READ_RPC")"
for who in "the buyer:$BUYER" "a stranger:0x000000000000000000000000000000000000dEaD"; do
  n=${who%%:*}; a=${who#*:}
  r=$(cast call "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$KEY" "x" --from "$a" --rpc-url "$READ_RPC" 2>&1 | head -1)
  case "$r" in 0x*) printf '   %-16s CAN still write — the window did not close\n' "$n" ;;
                 *) printf '   %-16s refused\n' "$n" ;; esac
done
echo
echo "   the agent can still write it, because root is not renounced yet. That is next."
echo "   then: bash scripts/playground-verify.sh   (a stranger mints and trades)"
cat "$LOG"

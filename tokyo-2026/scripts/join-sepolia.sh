#!/usr/bin/env bash
# join-sepolia — §4-10, on the real chain instead of a fork.
#
# One path: a buyer funds, a stranger settles on a proof, the adapter opens a window for the
# buyer and nobody else, the buyer writes, ENS resolves it, the window closes.
#
# It is a script and not a list of commands to paste because the proof is ~700 bytes of hex,
# and a terminal that wraps a long argument inserts spaces into it. That has already cost this
# repository two failed transactions tonight.
#
# Needs: SEPOLIA_RPC, and the keystores reckn-buyer and reckn-arc. Four password prompts,
# batched so the same key is used twice in a row.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIX="$here/../zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json"
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
# Reads need no key, so they do not need the metered endpoint. Sending stays on SEPOLIA_RPC.
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}

ESCROW=0x6d6a9deb67d785BC131a5d732617EABE751098C5
VERIFIER=0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
ADAPTER=0x6691283d8B77E1e22D08836c55E3f952c304Ccc1
UR=0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3
USDC=0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e
BUYER=0x4b55f9e4d87505F3347c7CAFcB8C7eb589970eE3
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
DNS=0x056167656e74057265636b6e0365746800
AMOUNT=250000000

BINDING=$(python3 -c "import json;print(json.load(open('$FIX'))['deal_binding'])")
PUB=$(python3 -c "import json;print(json.load(open('$FIX'))['public_values'])")
PRF=$(python3 -c "import json;print(json.load(open('$FIX'))['proof'])")
DEAL=${DEAL_ID:-$(cast keccak "reckn-tokyo-join-1")}

say() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
send() { cast send "$@" --rpc-url "$SEPOLIA_RPC" | grep -E '^(status|gasUsed|transactionHash)'; }

# A read that retries. The RPC returned 503 once mid-run, cast printed the error, the command
# substitution yielded "", and an EMPTY ARGUMENT went into `fund` as the verifier codehash.
# `set -e` does not catch a failure inside $( ) used as an argument. So: retry, then check the
# shape, then refuse to continue. A demo that sends a transaction built from an empty string is
# worse than one that stops.
retry() {
  local i out
  for i in 1 2 3; do
    printf '   … %s (try %d)\n' "$1 $2" "$i" >&2
    if out=$("$@") && [[ -n "$out" ]]; then printf '%s' "$out"; return 0; fi
    sleep 2
  done
  echo "join-sepolia: gave up on: $*" >&2
  return 1
}
want_hex32() {
  [[ "$1" =~ ^0x[0-9a-fA-F]{64}$ ]] || { echo "join-sepolia: not a 32-byte value: '$1'" >&2; exit 1; }
}

# The verifier has no owner and no upgrade path, so its codehash cannot change. It is still
# read rather than pasted, because a hardcoded hash is one more thing that can be wrong.
CODEHASH=$(retry cast codehash "$VERIFIER" --rpc-url "$READ_RPC")
want_hex32 "$CODEHASH"
want_hex32 "$BINDING"
want_hex32 "$DEAL"
[[ ${#PUB} -gt 100 && ${#PRF} -gt 100 ]] || { echo "join-sepolia: the fixture did not load" >&2; exit 1; }

say "0. what we are about to do"
printf '   deal      %s\n   binding   %s\n   codehash  %s\n   buyer     %s\n   agent     %s\n   adapter   %s\n' \
  "$DEAL" "$BINDING" "$CODEHASH" "$BUYER" "$AGENT" "$ADAPTER"

say "1. the buyer approves the escrow  [reckn-buyer]"
send "$USDC" "approve(address,uint256)" "$ESCROW" "$AMOUNT" --account reckn-buyer

say "2. the buyer funds the deal, naming the verifier  [reckn-buyer]"
send "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
  "$DEAL" "$AGENT" "$USDC" "$AMOUNT" "$VERIFIER" "$CODEHASH" "$BINDING" \
  --account reckn-buyer

say "3. somebody who is not the buyer settles it, on the proof  [reckn-arc]"
send "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$DEAL" "$PUB" "$PRF" --account reckn-arc

# No name argument. The adapter serves exactly one name, fixed at construction, because the
# resolver's resource is a function of the KEY alone -- a caller who could name the target
# could aim this grant at somebody else's name. See src/SettlementRecord.sol and Grief.t.sol.
say "4. the adapter opens the window — for the buyer, chosen by nobody  [reckn-arc]"
send "$ADAPTER" "open(bytes32,bytes,bytes)" "$DEAL" "$PUB" "$PRF" --account reckn-arc
KEY=$(cast call "$ADAPTER" "recordKey(bytes32)(string)" "$DEAL" --rpc-url "$READ_RPC" | tr -d '"')
WRITER=$(cast call "$ADAPTER" "writerOf(bytes32)(address)" "$DEAL" --rpc-url "$READ_RPC")
printf '   key       %s\n   writer    %s\n' "$KEY" "$WRITER"

BLK=$(cast block-number --rpc-url "$READ_RPC")
VALUE=$(cast call "$ADAPTER" "recordValue(uint8,uint64,address)(string)" 0 "$BLK" "$VERIFIER" --rpc-url "$READ_RPC" | tr -d '"')
printf '   value     %s\n' "$VALUE"

say "5. the buyer writes it. Nobody else can.  [reckn-buyer]"
send "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$KEY" "$VALUE" --account reckn-buyer

say "6. ENS resolves it back — through UniversalResolverV2, not our resolver directly"
NODE=$(cast namehash agent.reckn.eth)
INNER=$(cast calldata "text(bytes32,string)" "$NODE" "$KEY")
cast call "$UR" "resolve(bytes,bytes)(bytes,address)" "$DNS" "$INNER" --rpc-url "$READ_RPC"

# The buyer closes, not the agent. Anybody MAY close, but only after WRITE_WINDOW; before
# that only the writer can, because otherwise `close` is a weapon -- see test/Grief.t.sol.
say "7. the window closes  [reckn-buyer]"
send "$ADAPTER" "close(bytes32)" "$DEAL" --account reckn-buyer

say "done. the record exists, the agent never held the right to write it."

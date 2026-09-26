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
# Needs: SEPOLIA_RPC, and the keystores reckn-buyer and reckn-agent. Four password prompts,
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
ADAPTER=0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8
UR=0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3
USDC=0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e
BUYER=0x4b55f9e4d87505F3347c7CAFcB8C7eb589970eE3
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
DNS=0x056167656e74057265636b6e0365746800
AMOUNT=250000000

# The buyer computes the binding from the TERMS. Reading it out of a proof fixture -- which is
# what this line used to do -- is the reverse of the design the escrow rests on: `fund` commits
# to a binding BEFORE the seller works, and a proof settles only if the execution it describes
# hashes to that same value. A script that copies the answer out of the proof cannot show that
# (`013` §4-3). The fixture's copy is still read, and the two must agree.
BINDING_FIXTURE=$(python3 -c "import json;print(json.load(open('$FIX'))['deal_binding'])")
CALC="$here/../zk-verdict/target/release/binding"
if [[ ! -x "$CALC" ]]; then
  ( cd "$here/../zk-verdict/script" && cargo build --quiet --release --bin binding ) 2>/dev/null || true
fi
if [[ -x "$CALC" ]]; then
  BINDING=$("$CALC" --quiet)
  if [[ "$BINDING" != "$BINDING_FIXTURE" ]]; then
    echo "join-sepolia: the buyer's calculator and the proof disagree about the binding" >&2
    echo "  calculator $BINDING" >&2
    echo "  fixture    $BINDING_FIXTURE" >&2
    exit 1
  fi
  BINDING_SOURCE="computed from the terms by the buyer, and it matches the proof"
else
  BINDING="$BINDING_FIXTURE"
  BINDING_SOURCE="READ OUT OF THE PROOF -- the calculator could not be built, so this run does not show the buyer computing it in advance"
fi
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
printf '   deal      %s\n   binding   %s\n     \u21b3 %s\n   codehash  %s\n   buyer     %s\n   agent     %s\n   adapter   %s\n' \
  "$DEAL" "$BINDING" "$BINDING_SOURCE" "$CODEHASH" "$BUYER" "$AGENT" "$ADAPTER"

# The buyer's MockUSDC runs out, because every run of this spends 250 of it. Minting is open to
# anyone on this mock -- which is also why a stranger can trade in the playground pool -- so top
# up only when short, rather than minting on every run and muddying the receipts.
HAVE=$(cast call "$USDC" "balanceOf(address)(uint256)" "$BUYER" --rpc-url "$READ_RPC" | awk '{print $1}')
if [[ "$HAVE" -lt "$AMOUNT" ]]; then
  say "0b. the buyer is short on test USDC ($HAVE < $AMOUNT) — minting  [reckn-buyer]"
  send "$USDC" "mint(address,uint256)" "$BUYER" "$AMOUNT" --account reckn-buyer
fi

say "1. the buyer approves the escrow  [reckn-buyer]"
send "$USDC" "approve(address,uint256)" "$ESCROW" "$AMOUNT" --account reckn-buyer

say "2. the buyer funds the deal, naming the verifier  [reckn-buyer]"
send "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
  "$DEAL" "$AGENT" "$USDC" "$AMOUNT" "$VERIFIER" "$CODEHASH" "$BINDING" \
  --account reckn-buyer

say "3. somebody who is not the buyer settles it, on the proof  [reckn-agent]"
send "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$DEAL" "$PUB" "$PRF" --account reckn-agent

# No name argument. The adapter serves exactly one name, fixed at construction, because the
# resolver's resource is a function of the KEY alone -- a caller who could name the target
# could aim this grant at somebody else's name. See src/SettlementRecord.sol and Grief.t.sol.
say "4. the adapter opens the window — for the buyer, chosen by nobody  [reckn-agent]"
send "$ADAPTER" "open(bytes32,bytes,bytes)" "$DEAL" "$PUB" "$PRF" --account reckn-agent
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

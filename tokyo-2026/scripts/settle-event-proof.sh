#!/usr/bin/env bash
# settle-event-proof — a proof made during the event, verified on chain during the event.
#
# Every settlement in this repository so far was decided by a Groth16 proof generated BEFORE the
# event and committed to the tree. That is disclosed and it is fine, but it leaves one sentence
# unavailable: that the proving pipeline ran here. This closes that.
#
#   generated 2026-09-26 10:15-10:22 JST, 416.56 s wall, into
#   zk-verdict/contracts/src/fixtures/event-reexec-groth16-fixture.json
#
# The committed fixture is NOT touched. `reexec --fixture` defaults to pre=42/post=142, not the
# shipped pre=2^64, so running it without --fixture-path would have replaced the shipped fixture
# with a proof of DIFFERENT TERMS -- every field still plausible, `deal_binding` and `trace_hash`
# quietly different. DEMO.md §5-5 warns about the overwrite; this is the sharper half.
#
# The buyer computes the binding from the proof's own public values here, which is the one place
# it is legitimate: this deal is being created to match a proof that already exists. For the
# normal direction -- buyer first, proof later -- see scripts/binding (013 §4-3).
#
# Three keystore prompts.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}
FIX="$here/../zk-verdict/contracts/src/fixtures/event-reexec-groth16-fixture.json"
LOG="$here/event-proof-txs.txt"

ESCROW=0x6d6a9deb67d785BC131a5d732617EABE751098C5
VERIFIER=0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608
USDC=0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
AMOUNT=250000000

[[ -f "$FIX" ]] || { echo "settle-event-proof: no event fixture at $FIX" >&2; exit 1; }
BINDING=$(python3 -c "import json;print(json.load(open('$FIX'))['deal_binding'])")
PUB=$(python3 -c "import json;print(json.load(open('$FIX'))['public_values'])")
PRF=$(python3 -c "import json;print(json.load(open('$FIX'))['proof'])")
VKEY=$(python3 -c "import json;print(json.load(open('$FIX'))['vkey'])")
DEAL=${DEAL_ID:-$(cast keccak "reckn-tokyo-event-proof-1")}

say()  { printf '\n\033[1m── %s\033[0m\n' "$*"; }
send() {
  local label=$1; shift
  local out; out=$(cast send "$@" --rpc-url "$SEPOLIA_RPC")
  local h; h=$(printf '%s' "$out" | awk '/^transactionHash/{print $2}')
  printf '   status %s  gas %s\n   https://sepolia.etherscan.io/tx/%s\n' \
    "$(printf '%s' "$out" | awk '/^status/{print $2}')" \
    "$(printf '%s' "$out" | awk '/^gasUsed/{print $2}')" "$h"
  printf '%s %s\n' "$label" "$h" >> "$LOG"
}

# The deployed verifier's vkey is immutable and pins ONE guest. If the fresh proof were built
# from a different ELF it could never settle, and finding that out by sending is expensive.
ONCHAIN=$(cast call "$VERIFIER" "verdictProgramVKey()(bytes32)" --rpc-url "$READ_RPC")
[[ "$ONCHAIN" == "$VKEY" ]] || {
  echo "settle-event-proof: the fresh proof's vkey is not the one the deployed verifier pins" >&2
  echo "  fixture  $VKEY" >&2; echo "  on chain $ONCHAIN" >&2; exit 1; }

CODEHASH=$(cast codehash "$VERIFIER" --rpc-url "$READ_RPC")
: > "$LOG"

say "0. a proof that did not exist when this event started"
printf '   deal      %s\n   binding   %s\n   vkey      %s  (matches the deployed verifier)\n' \
  "$DEAL" "$BINDING" "$VKEY"

BEFORE=$(cast call "$USDC" "balanceOf(address)(uint256)" "$AGENT" --rpc-url "$READ_RPC" | awk '{print $1}')

say "1. the buyer approves  [reckn-buyer]"
send eventApprove "$USDC" "approve(address,uint256)" "$ESCROW" "$AMOUNT" --account reckn-buyer

say "2. the buyer funds, naming the verifier and committing to the binding  [reckn-buyer]"
send eventFund "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
  "$DEAL" "$AGENT" "$USDC" "$AMOUNT" "$VERIFIER" "$CODEHASH" "$BINDING" --account reckn-buyer

say "3. settle it on the proof generated this morning  [reckn-agent]"
send eventSettle "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$DEAL" "$PUB" "$PRF" --account reckn-agent

AFTER=$(cast call "$USDC" "balanceOf(address)(uint256)" "$AGENT" --rpc-url "$READ_RPC" | awk '{print $1}')
say "done"
python3 -c "print('   the agent was paid', ($AFTER - $BEFORE)/1000000, 'USDC')"
cat "$LOG"

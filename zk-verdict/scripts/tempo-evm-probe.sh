#!/usr/bin/env bash
# tempo-evm-probe — make Tempo's own EVM run Reckn's whole settlement path, with no key,
# no transaction and no funds.
#
# WHY THIS IS NOT JUST ANOTHER TEST. `forge test` runs the path in the local revm. A fork
# test (`--fork-url`) still runs it in the local revm, over remote *state*. Neither one asks
# the question that matters here, which is whether the REMOTE NODE's EVM — its BN254
# precompiles, its gas schedule, its EIP set — executes a real SP1 Groth16 verification and
# pays out. `tempo.json` records that 0x06/0x07/0x08 answer correctly on trivial inputs;
# that is necessary and nowhere near sufficient, because a Groth16 verification is thousands
# of field operations and two real pairings.
#
# The trick: `eth_call` with `to: null` makes the node execute a constructor. A constructor
# returns "runtime code", so a constructor that ends in an assembly `return` hands back
# measurements instead. No key, no signature, no state written, nothing to pay.
#
# WHAT A GREEN RUN DOES NOT ESTABLISH, and no README, page or submission may say it does:
#   * it pays no fee, mines no block, writes no state. It is not a deployment and it is not
#     T-4. `tempo.json -> deployedByReckn` stays empty until a real receipt exists.
#   * it funds a MockTIP20, not the real PathUSD -- giving the probe a balance in a real
#     token needs a faucet. The real token's semantics are measured separately, by
#     `tempo-tip20-probe.sh`, and against the real contract.
# What it DOES establish is the thing that could have ended this direction: on Tempo, a real
# proof of a real Solana execution verifies and moves money, and a real proof of a DIFFERENT
# execution does not.
#
# The local control is not decoration. "It ran on Tempo" is worth little on its own; "it ran
# on Tempo and on a stock EVM, from bytecode with identical codehashes, to the same balances,
# and here is exactly where the gas differs" is a measurement. If the codehashes disagree the
# two sides were not running the same contract and every other row is meaningless.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root/zk-verdict/contracts"
rec="$root/zk-verdict/contracts/tempo.json"
# The endpoint is READ FROM THE RECORD, never typed here. tempo-constants.sh enforces that a
# Tempo-shaped literal in the tree is the recorded one; taking it from the record instead of
# restating it means this script cannot be the file that drifts.
RPC=$(jq -r '.testnet.rpc' "$rec")
CHAIN=$(jq -r '.testnet.chainId' "$rec")
CONTROL_PORT=${CONTROL_PORT:-8599}

command -v forge >/dev/null || { echo "tempo-evm-probe: forge is required"; exit 2; }
command -v cast  >/dev/null || { echo "tempo-evm-probe: cast is required"; exit 2; }
command -v jq    >/dev/null || { echo "tempo-evm-probe: jq is required"; exit 2; }

forge build >/dev/null

BC=$(forge inspect TempoEvmProbe bytecode)

# One eth_call. $1 endpoint, $2 fixture path, $3 decimals, $4 mode -> the raw 512-byte return.
probe() {
  local url=$1 fx=$2 dec=$3 mode=$4
  local vk pv pr db args data
  vk=$(jq -r .vkey "$fx"); pv=$(jq -r .public_values "$fx")
  pr=$(jq -r .proof "$fx"); db=$(jq -r .deal_binding "$fx")
  args=$(cast abi-encode "c(bytes32,bytes,bytes,bytes32,uint8,uint256)" "$vk" "$pv" "$pr" "$db" "$dec" "$mode")
  data="${BC}${args#0x}"
  # 100M gas: measured, not guessed. The path costs ~31M on Tempo, whose block limit is
  # 500M, and the node rejects a call whose supplied gas is short rather than silently
  # truncating -- the first run of this probe failed at 33.5M and said so.
  printf '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":null,"data":"%s","gas":"0x5F5E100"},"latest"]}' "$data" \
    | curl -s --max-time 180 -X POST -H 'content-type: application/json' --data @- "$url"
}

# Decode the 16 slots into `k=v` lines.
decode() {
  python3 -c '
import json,sys
raw=sys.stdin.read()
try: o=json.loads(raw)
except Exception: print("err=unparseable"); sys.exit(0)
if "error" in o:
    print("err="+o["error"].get("message","?").replace("\n"," ")); sys.exit(0)
h=o["result"][2:]
n=["chainid","blocknumber","mode","sp1_codehash","verifier_codehash","escrow_codehash",
   "seller","buyer","escrow","gas_deploy_sp1","gas_deploy_verifier","gas_deploy_escrow",
   "gas_fund","gas_settle","revert_selector","settled"]
for i,k in enumerate(n):
    v=int(h[i*64:(i+1)*64],16)
    if k.endswith("codehash"): print(f"{k}=0x{v:064x}")
    elif k=="revert_selector": print(f"{k}=0x{h[i*64:i*64+8]}")
    else: print(f"{k}={v}")
'
}

get() { sed -n "s/^$2=//p" <<<"$1"; }

# ---- the local control ---------------------------------------------------------------
control=""
if command -v anvil >/dev/null; then
  anvil --port "$CONTROL_PORT" --silent >/dev/null 2>&1 &
  ctl_pid=$!
  trap 'kill $ctl_pid 2>/dev/null || true' EXIT
  for _ in $(seq 1 40); do
    cast chain-id --rpc-url "http://127.0.0.1:$CONTROL_PORT" >/dev/null 2>&1 && break
    sleep 0.25
  done
  control="http://127.0.0.1:$CONTROL_PORT"
else
  echo "tempo-evm-probe: anvil not found -- running WITHOUT the local control."
  echo "  Every Tempo row below is then unanchored: nothing shows the same bytecode behaves"
  echo "  the same way elsewhere. Install Foundry's anvil before quoting a gas number."
fi

# ---- the three cases ------------------------------------------------------------------
# Chosen so that a pass means something a failure could not have faked:
#   reproduced  the seller is paid, by a real Groth16 proof of a real Solana execution
#   failed      the same machinery pays the BUYER -- the refund direction the demo shows,
#               and NOT the 30-day timeout (011 SS7.1: 30 days > the 28-day judging window)
#   mismatch    a real proof meets a deal it does not prove. Nothing moves.
declare -a CASES=(
  "reproduced:src/fixtures/svm-groth16-fixture.json:6:0"
  "failed:src/fixtures/svm-failed-fixture.json:6:0"
  "mismatch:src/fixtures/svm-groth16-fixture.json:6:1"
)

echo "tempo-evm-probe: $RPC (chain $CHAIN)${control:+ vs local control}"
echo
printf '%-11s %-9s %10s %10s %10s %12s %12s\n' case where seller buyer escrow gas_settle settled
fail=0
rows="[]"
for c in "${CASES[@]}"; do
  IFS=: read -r name fx dec mode <<<"$c"
  t=$(probe "$RPC" "$fx" "$dec" "$mode" | decode)
  if [[ -n "$(get "$t" err)" ]]; then
    echo "  $name: TEMPO CALL FAILED: $(get "$t" err)"; fail=1; continue
  fi
  [[ "$(get "$t" chainid)" == "$CHAIN" ]] || { echo "  $name: answered chain $(get "$t" chainid), not $CHAIN"; fail=1; }
  printf '%-11s %-9s %10s %10s %10s %12s %12s\n' "$name" tempo \
    "$(get "$t" seller)" "$(get "$t" buyer)" "$(get "$t" escrow)" "$(get "$t" gas_settle)" "$(get "$t" settled)"

  l=""
  if [[ -n "$control" ]]; then
    l=$(probe "$control" "$fx" "$dec" "$mode" | decode)
    if [[ -n "$(get "$l" err)" ]]; then
      echo "  $name: control call failed: $(get "$l" err)"; fail=1
    else
      printf '%-11s %-9s %10s %10s %10s %12s %12s\n' "" control \
        "$(get "$l" seller)" "$(get "$l" buyer)" "$(get "$l" escrow)" "$(get "$l" gas_settle)" "$(get "$l" settled)"
      # The comparison, and the reason the control exists.
      for k in sp1_codehash verifier_codehash escrow_codehash; do
        [[ "$(get "$t" $k)" == "$(get "$l" $k)" ]] || {
          echo "  $name: $k DIFFERS between the two sides -- they were not running the same contract"; fail=1; }
      done
      for k in seller buyer escrow settled revert_selector; do
        [[ "$(get "$t" $k)" == "$(get "$l" $k)" ]] || {
          echo "  $name: $k differs: tempo=$(get "$t" $k) control=$(get "$l" $k)"; fail=1; }
      done
    fi
  fi
  rows=$(jq --argjson r "$rows" -n --arg name "$name" --arg fx "$fx" --arg mode "$mode" \
    --arg tc "$t" --arg lc "${l:-}" '
      def kv: split("\n") | map(select(length>0) | split("=") | {key:.[0], value:.[1]}) | from_entries;
      $r + [{case:$name, fixture:$fx, mode:($mode|tonumber), tempo:($tc|kv),
             control: (if ($lc|length)>0 then ($lc|kv) else null end)}]')
done

# The invariants the three cases exist to state, checked here rather than left to a reader.
check() { # name expr
  if ! eval "$2"; then echo "tempo-evm-probe: FAILED -- $1"; fail=1; fi
}
r0=$(jq -r '.[0].tempo' <<<"$rows"); r1=$(jq -r '.[1].tempo' <<<"$rows"); r2=$(jq -r '.[2].tempo' <<<"$rows")
check "reproduced must pay the seller in full and empty the escrow" \
  '[[ $(jq -r .seller <<<"$r0") == 250000000 && $(jq -r .escrow <<<"$r0") == 0 && $(jq -r .buyer <<<"$r0") == 0 ]]'
check "failed must refund the buyer in full and pay the seller nothing" \
  '[[ $(jq -r .buyer <<<"$r1") == 250000000 && $(jq -r .escrow <<<"$r1") == 0 && $(jq -r .seller <<<"$r1") == 0 ]]'
check "a real proof of another execution must move NOTHING and leave the escrow funded" \
  '[[ $(jq -r .settled <<<"$r2") == 0 && $(jq -r .escrow <<<"$r2") == 250000000 && $(jq -r .seller <<<"$r2") == 0 && $(jq -r .buyer <<<"$r2") == 0 ]]'
# BindingMismatch() -- computed, not transcribed, because a transcribed selector is exactly
# the kind of right-shaped dead value this repository has been bitten by.
want=$(cast sig "BindingMismatch()")
check "the mismatch must revert with BindingMismatch(), not with something else" \
  '[[ $(jq -r .revert_selector <<<"$r2") == "$want" ]]'

echo
echo "gas, same bytecode both sides (codehashes compared above):"
printf '  %-24s %14s %14s %8s\n' what tempo control ratio
for k in gas_deploy_sp1 gas_deploy_verifier gas_deploy_escrow gas_fund gas_settle; do
  a=$(jq -r ".[0].tempo.$k" <<<"$rows"); b=$(jq -r ".[0].control.$k // empty" <<<"$rows")
  if [[ -n "$b" && "$b" != null && "$b" -gt 0 ]]; then
    printf '  %-24s %14s %14s %7sx\n' "$k" "$a" "$b" "$(python3 -c "print(f'{$a/$b:.2f}')")"
  else
    printf '  %-24s %14s %14s %8s\n' "$k" "$a" "-" "-"
  fi
done

out="$root/zk-verdict/contracts/tempo-evm-probe.json"
jq -n --argjson rows "$rows" --arg rpc "$RPC" --arg chain "$CHAIN" --arg control "${control:+local anvil}" '{
  _: "Output of zk-verdict/scripts/tempo-evm-probe.sh. Written by the script, never by hand. This is an eth_call measurement: no key, no transaction, no fee, no state written, and NOT a deployment. It does not satisfy 011 T-4 and it does not fill tempo.json -> deployedByReckn.",
  rpc: $rpc, chainId: ($chain|tonumber), control: (if ($control|length)>0 then $control else null end),
  cases: $rows
}' > "$out"
echo
echo "written: ${out#"$root"/}"

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "tempo-evm-probe: Tempo's own EVM verified a real Groth16 proof of a Solana execution and paid the seller;"
echo "                 the same machinery refunded the buyer on the failed proof; a real proof of another"
echo "                 execution moved nothing. No key, no transaction, no funds -- and therefore NOT T-4."

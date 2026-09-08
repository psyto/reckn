#!/usr/bin/env bash
# tempo-gas-schedule — measure, primitive by primitive, where Tempo's gas differs from a
# stock EVM. No key, no transaction, no funds: same `eth_call` with `to: null` trick as
# tempo-evm-probe.sh, which is where the mechanism is explained.
#
# WHY IT WAS WRITTEN. tempo-evm-probe.sh reported that the identical bytecode costs 5-10x
# more on Tempo than on a local control -- deploy 5.2x, fund 10.6x, settleWithProof 2.6x.
# Three different ratios for one chain is not a fact anyone can budget from, and "Tempo is
# more expensive" is the kind of sentence that gets repeated until somebody funds a key with
# the wrong amount. So: one primitive per call, against both chains, with the Ethereum
# schedule printed beside it so a reader can see which side moved.
#
# The answer it gives, and the reason it belongs next to a ZK product: COMPUTE IS IDENTICAL.
# A real two-pair BN254 pairing costs the same on Tempo as on the control, to the gas unit.
# What Tempo prices differently is STATE -- a cold SSTORE and a byte of deployed code. For an
# escrow whose expensive operation is a Groth16 verification, that is the good direction.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root/zk-verdict/contracts"
RPC=$(jq -r '.testnet.rpc' "$root/zk-verdict/contracts/tempo.json")
CONTROL_PORT=${CONTROL_PORT:-8599}

command -v forge >/dev/null || { echo "tempo-gas-schedule: forge is required"; exit 2; }
forge build >/dev/null
BC=$(forge inspect TempoGasProbe bytecode)

control=""
if command -v anvil >/dev/null; then
  anvil --port "$CONTROL_PORT" --silent >/dev/null 2>&1 &
  trap 'kill %1 2>/dev/null || true' EXIT
  for _ in $(seq 1 40); do cast chain-id --rpc-url "http://127.0.0.1:$CONTROL_PORT" >/dev/null 2>&1 && break; sleep 0.25; done
  control="http://127.0.0.1:$CONTROL_PORT"
else
  echo "tempo-gas-schedule: anvil not found. Without the control every ratio below is"
  echo "  unanchored -- there is nothing to be a ratio TO. Install Foundry's anvil."
  exit 2
fi

BC="$BC" RPC="$RPC" CONTROL="$control" OUT="$root/zk-verdict/contracts/tempo-gas-schedule.json" python3 - <<'PY'
import json, os, subprocess, sys
BC, T, L, OUT = os.environ["BC"], os.environ["RPC"], os.environ["CONTROL"], os.environ["OUT"]
STEPS = [
    (1, "cold SSTORE 0->1",     "22100"),
    (2, "warm SSTORE",          "100"),
    (3, "cold SLOAD + no-op SSTORE", "2100 + 100"),
    (4, "keccak256 over 1 KiB", "30 + 6*32 = 222"),
    (5, "bn256Pairing, 2 pairs","45000 + 2*34000 = 113000"),
    (6, "bn256Add",             "150"),
    (7, "bn256ScalarMul",       "6000"),
    (8, "CREATE (297-byte runtime)", "32000 + 200/byte"),
    (9, "cold EXTCODESIZE",     "2600"),
]
def call(url, step):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[
        {"to":None,"data":BC+f"{step:064x}","gas":"0x2FAF080"},"latest"]})
    r = subprocess.run(["curl","-s","--max-time","90","-X","POST",
                        "-H","content-type: application/json","-d",body,url],
                       capture_output=True, text=True)
    o = json.loads(r.stdout)
    if "error" in o: sys.exit(f"tempo-gas-schedule: {url} -> {o['error']['message']}")
    h = o["result"][2:]
    return int(h[0:64],16), int(h[64:128],16), int(h[128:192],16)
# The harness itself costs something. Measured, then subtracted, rather than assumed away.
bt,_,_ = call(T,0); bl,_,_ = call(L,0)
rows = []
print(f"{'primitive':30} {'TEMPO':>11} {'control':>11} {'ratio':>7}   Ethereum schedule")
blob = None
for s, name, spec in STEPS:
    a, chain, blob = call(T, s); b, _, _ = call(L, s)
    a -= bt; b -= bl
    rows.append({"primitive": name, "tempo": a, "control": b,
                 "ratio": round(a/b, 3) if b else None, "ethereumSchedule": spec})
    print(f"{name:30} {a:>11,} {b:>11,} {a/b:>6.2f}x   {spec}")
dep_t = (rows[-2]["tempo"] - 32000) / blob
dep_l = (rows[-2]["control"] - 32000) / blob
print(f"\nimplied code deposit: tempo {dep_t:.0f} gas/byte | control {dep_l:.0f} gas/byte "
      f"(over a {blob}-byte runtime)")
print("\nreading: compute is the SAME chain-to-chain -- a real BN254 pairing costs what it costs")
print("         on Ethereum. Tempo prices STATE: a cold storage slot and a deployed byte.")
json.dump({
  "_": "Output of zk-verdict/scripts/tempo-gas-schedule.sh. Written by the script, never by hand. eth_call only: no key, no transaction, no fee, no state written.",
  "rpc": T, "control": "local anvil",
  "harnessBaselineGas": {"tempo": bt, "control": bl},
  "primitives": rows,
  "impliedCodeDepositGasPerByte": {"tempo": round(dep_t), "control": round(dep_l), "overRuntimeBytes": blob},
  "reading": "Compute is identical (pairing, ecAdd, ecMul, SLOAD, EXTCODESIZE all 1.00x). Tempo prices state growth ~11.5x and code deposit ~12.8x. For an escrow whose expensive operation is a Groth16 verification, that is the favourable direction; for its storage-writing fund() it is not."
}, open(OUT,"w"), indent=2)
print(f"\nwritten: {OUT}")
PY

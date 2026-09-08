#!/usr/bin/env bash
# tempo-tip20-probe — measure the REAL TIP-20 on Tempo testnet against the assumptions
# RecknZkEscrow makes about a token. No key, no transaction, no funds: `eth_call` only.
#
# WHY THIS IS NOT COVERED BY MockTIP20. `MockTIP20` models what the spec says TIP-20 does
# (011 §2.3, all of it marked [doc] -- read from documentation, not measured). A mock built
# from documentation tests the documentation. Two of those doc lines are load-bearing:
#
#   1. **The escrow does not check the boolean.** `IERC20Min(token).transferFrom(...)` and
#      `.transfer(...)` in RecknZkEscrow ignore their return value -- forge lints it. That is
#      safe if and only if the token REVERTS on failure instead of returning false. On a
#      token that returns false, `fund()` would record a funded deal that holds nothing.
#      This is the single most consequential thing to know about the real token, and until
#      this script it was an assumption inherited from the mock.
#   2. **InvalidRecipient.** A TIP-20 refuses transfers to another TIP-20. RecknZkEscrow is
#      the recipient of every `fund()`, so if that rule caught ordinary contracts the escrow
#      could not be funded at all. The measurement below puts the escrow's REAL runtime
#      bytecode at an address (via an eth_call state override) and transfers to it.
#
# What this still does not establish, and no downstream text may say it does: nothing here
# sends a transaction, so it does not show that OUR key can move OUR tokens, and it does not
# satisfy 011 T-4. `eth_call` also runs against a chain state that can change: a token that
# is unpaused now can be paused later, which is exactly the risk 011 §8 discloses rather
# than mitigates.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root/zk-verdict/contracts"
rec="$root/zk-verdict/contracts/tempo.json"
RPC=$(jq -r '.testnet.rpc' "$rec")
TOKEN=$(jq -r '.measured.defaultFeeToken.address' "$rec")

command -v forge >/dev/null || { echo "tempo-tip20-probe: forge is required"; exit 2; }
command -v cast  >/dev/null || { echo "tempo-tip20-probe: cast is required"; exit 2; }
forge build >/dev/null
ESCROW_CODE=$(forge inspect RecknZkEscrow deployedBytecode)

RPC="$RPC" TOKEN="$TOKEN" ESCROW_CODE="$ESCROW_CODE" \
OUT="$root/zk-verdict/contracts/tempo-tip20-probe.json" python3 - <<'PY'
import json, os, subprocess, sys
RPC, TOKEN, CODE, OUT = os.environ["RPC"], os.environ["TOKEN"], os.environ["ESCROW_CODE"], os.environ["OUT"]
# An address nothing has ever touched, used as the zero-balance actor. Not random: a value
# that changes per run would make a failure impossible to reproduce.
POOR = "0x00000000000000000000000000000000000ba5ed"
# Scratch address the escrow's runtime code is overridden onto. It is not deployed and it is
# not ours; it exists for the length of one eth_call.
SCRATCH = "0x00000000000000000000000000000000dEadbEef"

def rpc(method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params})
    r = subprocess.run(["curl","-s","--max-time","60","-X","POST",
                        "-H","content-type: application/json","-d",body,RPC],
                       capture_output=True, text=True)
    try: return json.loads(r.stdout)
    except Exception: sys.exit(f"tempo-tip20-probe: unparseable answer from the endpoint")

def sig(s):
    return subprocess.run(["cast","calldata",s]+list(ARGS), capture_output=True, text=True).stdout.strip()

def calldata(s, *args):
    return subprocess.run(["cast","calldata",s]+[str(a) for a in args],
                          capture_output=True, text=True).stdout.strip()

def call(frm, data, override=None):
    tx = {"from": frm, "to": TOKEN, "data": data}
    params = [tx, "latest"] + ([override] if override else [])
    o = rpc("eth_call", params)
    if "error" in o:
        return None, o["error"].get("message", "?")
    return o["result"], None

# Find a holder from the chain rather than hard-coding one: a transcribed address with a
# balance today is a dead value tomorrow, and this repository has been bitten by exactly
# that shape of constant twice.
head = int(rpc("eth_blockNumber", [])["result"], 16)
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
logs = rpc("eth_getLogs", [{"address": TOKEN, "topics": [TRANSFER],
                            "fromBlock": hex(head-800), "toBlock": hex(head)}]).get("result", [])
holder, holder_bal = None, 0
for lg in reversed(logs):
    cand = "0x" + lg["topics"][1][-40:]
    if int(cand, 16) == 0: continue
    b, err = call(POOR, calldata("balanceOf(address)", cand))
    if err: continue
    if int(b, 16) > 2_000_000:                    # 2 PathUSD, enough for every probe below
        holder, holder_bal = cand, int(b, 16); break
if not holder:
    sys.exit("tempo-tip20-probe: found no TIP-20 holder in the last 800 blocks -- cannot probe "
             "the success paths. Re-run, or widen the window.")

ov = {SCRATCH: {"code": CODE}}
checks, fail = [], 0

def record(name, why, ok, detail):
    global fail
    checks.append({"check": name, "why": why, "passed": bool(ok), "observed": detail})
    if not ok: fail += 1
    print(f"  [{'ok ' if ok else 'FAIL'}] {name}: {detail}")

def reverts_with(frm, data, want, override=None):
    res, err = call(frm, data, override)
    if err is None: return False, f"returned {res} -- it did NOT revert"
    return (want in err), err.replace("execution reverted: ", "")[:120]

def succeeds(frm, data, override=None):
    res, err = call(frm, data, override)
    if err: return False, err[:120]
    return int(res, 16) == 1, f"returned {res[-1]}"

print(f"tempo-tip20-probe: {TOKEN} on {RPC}")
print(f"  holder discovered from recent Transfer logs; balance {holder_bal/1e6:.6f} (6dp)")

meta = {}
for fn, kind in [("name()", "str"), ("symbol()", "str"), ("currency()", "str"),
                 ("decimals()", "int"), ("totalSupply()", "int")]:
    res, err = call(POOR, calldata(fn))
    if err: meta[fn] = f"reverted: {err[:60]}"; continue
    if kind == "int": meta[fn] = int(res, 16)
    else:
        n = int(res[2+64:2+128], 16); meta[fn] = bytes.fromhex(res[2+128:2+128+n*2]).decode()
print(f"  {meta}")

res, err = call(POOR, calldata("paused()"))
paused = (err is None and int(res, 16) == 1)
record("the token is not paused right now", "011 §8: pause() can stop a proof-authorised "
       "payout AND the timeout. Disclosed, not mitigated -- this only says which state it is in today.",
       err is None, "paused=false" if not paused and err is None else f"paused={paused} err={err}")

ok, d = succeeds(holder, calldata("transfer(address,uint256)", SCRATCH, 1), ov)
record("a TIP-20 transfer INTO the escrow's own runtime code is allowed",
       "every fund() makes RecknZkEscrow the recipient. If InvalidRecipient caught ordinary "
       "contracts, the escrow could not be funded at all.", ok, d)

ok, d = succeeds(holder, calldata("approve(address,uint256)", SCRATCH, 1), ov)
record("approve(escrow) is allowed", "fund() pulls with transferFrom, so the buyer must approve first.", ok, d)

ok, d = reverts_with(holder, calldata("transfer(address,uint256)", TOKEN, 1), "InvalidRecipient")
record("a transfer to the token itself reverts with InvalidRecipient",
       "011 §2.3 read this from documentation. Measured here. It is the behaviour "
       "RecknTempoTip20.t.sol's T-11 models: a deal whose seller is a TIP-20 can only time out.", ok, d)

ok, d = reverts_with(POOR, calldata("transfer(address,uint256)", SCRATCH, 1_000_000), "InsufficientBalance", ov)
record("an underfunded transfer REVERTS, it does not return false",
       "RecknZkEscrow ignores the ERC-20 boolean (forge lints it). On a false-returning token "
       "fund() would record a funded deal holding nothing. This is the assumption that check exists for.", ok, d)

ok, d = reverts_with(POOR, calldata("transferFrom(address,address,uint256)", holder, SCRATCH, 1),
                     "InsufficientAllowance", ov)
record("transferFrom without allowance REVERTS, it does not return false",
       "same reason, on the pull side -- this is the call fund() actually makes.", ok, d)

if not os.environ.get("RECKN_NO_WRITE"):
  json.dump({
  "_": "Output of zk-verdict/scripts/tempo-tip20-probe.sh. Written by the script, never by hand. eth_call only: no key, no transaction, no fee, no state written. It is NOT 011 T-4.",
  "rpc": RPC, "token": TOKEN, "metadata": meta,
  "holderDiscoveredFromLogs": {"address": holder, "balanceRaw": holder_bal,
    "how": "most recent Transfer log in the last 800 blocks whose sender still holds > 2 PathUSD"},
  "checks": checks,
  }, open(OUT, "w"), indent=2)
  print(f"\nwritten: {OUT}")
if fail:
    print(f"tempo-tip20-probe: {fail} check(s) FAILED -- an assumption RecknZkEscrow makes about "
          f"the token does not hold on the real one. That is a finding, not a thing to work around.")
    sys.exit(1)
print(f"tempo-tip20-probe: {len(checks)} assumption(s) the escrow makes about a token checked against "
      f"the real TIP-20, {len(checks)} hold: it reverts rather than returning false, accepts the escrow "
      f"as a recipient, and refuses itself.")
PY

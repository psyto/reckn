#!/usr/bin/env python3
"""The backend behind the Arc demo page.

It is deliberately small and deliberately real: every endpoint shells out to `cast`
and performs an actual transaction against the chain the demo started. Nothing here
is simulated, and there is no code path that reports success without a transaction —
if `cast` fails, the failure text is what the page shows.

Tier, because the page says it too: the chain is a local anvil configured to look
like Arc (chain id 5042002). Deploying to Arc testnet needs a funded key, which this
process does not have and must not have.
"""
import json, os, re, subprocess, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
RPC = os.environ.get("ARC_DEMO_RPC", "http://127.0.0.1:8545")
# anvil's first development key. Local only; it holds nothing anywhere.
KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
STATE = os.path.join(ROOT, "arc-demo-state.json")


def cast(*args, check=True):
    r = subprocess.run(["cast", *args, "--rpc-url", RPC], capture_output=True, text=True)
    blob = (r.stderr or "") + (r.stdout or "")
    if check and r.returncode != 0:
        raise RuntimeError(_revert_reason(blob))
    return (blob if r.returncode != 0 else r.stdout).strip(), r.returncode


def send(to, sig, *args):
    """Simulate first, then send.

    `cast send` fails at gas estimation when a call reverts, and reports it as
    "Failed to estimate gas" — which tells a judge nothing. The simulation reports
    the decoded custom error instead, and on this contract the error name IS the
    result: `BindingMismatch` on screen is a theft attempt failing, not a bug.
    """
    out, rc = cast("call", to, sig, *args, "--from", env()["buyer"], check=False)
    if rc != 0:
        raise RuntimeError(_revert_reason(out))
    out, _ = cast("send", to, sig, *args, "--private-key", KEY)
    m = re.search(r"transactionHash\s+(0x[0-9a-fA-F]+)", out)
    return m.group(1) if m else ""


ERROR_NAMES = [
    "BindingMismatch", "BadState", "TooEarly", "NoVerifierCode", "VerifierMismatch",
    "BadOutcome", "ZeroBinding", "DealExists", "InsufficientAllowance",
    "InsufficientBalance",
]


def _selectors():
    """selector -> name, computed rather than transcribed."""
    out = {}
    for n in ERROR_NAMES:
        r = subprocess.run(["cast", "sig", f"{n}()"], capture_output=True, text=True)
        if r.returncode == 0:
            out[r.stdout.strip().lower()] = n
    return out


SELECTORS = _selectors()


def _revert_reason(text):
    m = re.search(r"custom error (0x[0-9a-fA-F]{8})", text or "")
    if m and m.group(1).lower() in SELECTORS:
        return SELECTORS[m.group(1).lower()] + "()"
    for line in reversed((text or "").splitlines()):
        line = line.strip()
        if not line:
            continue
        m = re.search(r"custom error[^:]*:\s*(\w+)", line, re.I)
        if m:
            return m.group(1) + "()"
        m = re.search(r"\b(BindingMismatch|BadState|TooEarly|NoVerifierCode|VerifierMismatch|BadOutcome|ZeroBinding|DealExists)\b", line)
        if m:
            return m.group(1) + "()"
        if "revert" in line.lower() or "error" in line.lower():
            return line[:200]
    return (text or "reverted").strip()[:200]


def env():
    with open(STATE) as f:
        return json.load(f)


def usdc_balance(token, who):
    out, _ = cast("call", token, "balanceOf(address)(uint256)", who)
    return int(out.split()[0].replace(",", ""))


def deal_state(escrow, deal_id):
    out, _ = cast(
        "call", escrow, "deals(bytes32)(address,address,address,uint256,address,bytes32,bytes32,uint64,uint8)", deal_id
    )
    parts = [p.strip() for p in out.splitlines() if p.strip()]
    return int(parts[-1]) if parts else 0


def snapshot():
    e = env()
    return {
        "chainId": int(cast("chain-id")[0]),
        "buyer": usdc_balance(e["usdc"], e["buyer"]),
        "seller": usdc_balance(e["usdc"], e["seller"]),
        "escrow": usdc_balance(e["usdc"], e["escrow"]),
        "deals": {name: deal_state(e["escrow"], d["id"]) for name, d in e["deals"].items()},
        "addresses": {k: e[k] for k in ("escrow", "usdc", "verifierEvm", "verifierSvm")},
        "now": int(cast("block", "latest", "--field", "timestamp")[0]),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/state":
            try:
                return self._json(snapshot())
            except Exception as exc:
                return self._json({"error": str(exc)}, 500)
        if path in ("/", "/arc"):
            path = "/arc.html"
        f = os.path.join(ROOT, path.lstrip("/"))
        if os.path.isfile(f) and os.path.commonpath([ROOT, os.path.abspath(f)]) == ROOT:
            data = open(f, "rb").read()
            ctype = "text/html" if f.endswith(".html") else "application/json" if f.endswith(".json") else "text/plain"
            self.send_response(200)
            self.send_header("Content-Type", ctype + "; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self._json({"error": "not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(length) or b"{}")
        e = env()
        try:
            if path == "/api/fund":
                d = e["deals"][req["deal"]]
                send(e["usdc"], "approve(address,uint256)", e["escrow"], str(d["amount"]))
                tx = send(
                    e["escrow"],
                    "fund(bytes32,address,address,uint256,address,bytes32,bytes32)",
                    d["id"], e["seller"], e["usdc"], str(d["amount"]),
                    d["verifier"], d["codehash"], d["binding"],
                )
                return self._json({"ok": True, "tx": tx, "state": snapshot()})

            if path == "/api/settle":
                d = e["deals"][req["deal"]]
                proof = e["proofs"][req.get("proof", d["proof"])]
                tx = send(e["escrow"], "settleWithProof(bytes32,bytes,bytes)", d["id"], proof["publicValues"], proof["proof"])
                return self._json({"ok": True, "tx": tx, "state": snapshot()})

            if path == "/api/warp":
                cast("rpc", "evm_increaseTime", str(req.get("seconds", 30 * 24 * 3600)))
                cast("rpc", "evm_mine")
                return self._json({"ok": True, "state": snapshot()})

            if path == "/api/refund":
                d = e["deals"][req["deal"]]
                tx = send(e["escrow"], "refundAfterDeadline(bytes32)", d["id"])
                return self._json({"ok": True, "tx": tx, "state": snapshot()})

            return self._json({"error": "unknown endpoint"}, 404)
        except Exception as exc:
            # The page shows this verbatim. A failed steal is a RESULT, not an error
            # to hide: `BindingMismatch` on screen is the demo working.
            return self._json({"ok": False, "revert": str(exc), "state": snapshot()}, 200)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()

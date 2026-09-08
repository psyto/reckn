#!/usr/bin/env python3
"""Generate docs/tempo.html — task 011's live page.

Same rule as generate.py, for the same reason: every constant is READ OUT OF THE RECORD
here, never typed. On 2026-09-06 two of four transaction hashes were hand-copied into a
page and both were wrong — right length, right prefix, linking to nothing. A generator
cannot make that mistake.

What is different from the Arc page, and deliberate: this one has nothing deployed to show.
Section 5 is empty and says it is empty. The page's value is that sections 1-4 are read
LIVE by the visitor's browser — the chain id, the BN254 precompiles Groth16 needs, the
absent native balance, and the feeToken on real receipts — so a judge does not have to
believe a claim about Tempo, they can watch their own browser check it.

  python3 dashboard/live/generate-tempo.py       # writes docs/tempo.html
"""
import json, pathlib, subprocess

root = pathlib.Path(__file__).resolve().parents[2]
rec = json.loads((root / "zk-verdict/contracts/tempo.json").read_text())
commit = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
                        capture_output=True, text=True).stdout.strip()

tok = rec["measured"]["defaultFeeToken"]
CFG = {
    "rpc": rec["testnet"]["rpc"],
    "chainId": rec["testnet"]["chainId"],
    "explorer": rec["testnet"]["explorer"] if rec["testnet"].get("explorerVerified") else "",
    # The key NAMES the chain this endpoint answers on. That is not decoration: the page and
    # the record both carry the wrong URL on purpose, and tempo-constants.sh requires any
    # line holding it to also hold 4217 — so the identifier itself has to say what it is.
    "wrongRpc_4217": rec["wrongEndpoint"]["url"],
    "feeToken": tok["address"],
    "feeTokenDecimals": tok["decimals"],
    "scanBlocks": 12,
    "commit": commit,
}

tpl = (root / "dashboard/live/tempo-template.html").read_text()
out = root / "docs/tempo.html"
out.write_text(tpl.replace("/*__CONFIG__*/", json.dumps(CFG, indent=2)))
print(f"docs/tempo.html  {out.stat().st_size:,} bytes  "
      f"chain {CFG['chainId']}  fee token {CFG['feeToken']} ({CFG['feeTokenDecimals']} dp)  "
      f"explorer {'linked' if CFG['explorer'] else 'NOT linked (unverified in the record)'}")

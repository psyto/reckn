#!/usr/bin/env python3
"""Generate docs/tempo.html — task 011's live page.

Same rule as generate.py, for the same reason: every constant is READ OUT OF THE RECORD
here, never typed. On 2026-09-06 two of four transaction hashes were hand-copied into a
page and both were wrong — right length, right prefix, linking to nothing. A generator
cannot make that mistake.

Every section is read LIVE by the visitor's browser — the chain id, the BN254 precompiles
Groth16 needs, the absent native balance, the feeToken on real receipts, and now the
settlements themselves. A judge does not have to believe a claim about Tempo; they can
watch their own browser check it.

Section 5 was empty until 2026-09-08, and said so. It is now filled FROM THE CHAIN: this
generator passes only identifiers — addresses, deal ids, transaction hashes, all read out
of `deployedByReckn`, which tempo-testnet.sh wrote from receipts and tempo-verify.sh
re-derived independently — and the page reads the state and the receipts itself. It still
carries the empty branch, because a record with no deployment must still produce an honest
page rather than a broken one.

  python3 dashboard/live/generate-tempo.py       # writes docs/tempo.html
"""
import json, pathlib, subprocess

root = pathlib.Path(__file__).resolve().parents[2]
rec = json.loads((root / "zk-verdict/contracts/tempo.json").read_text())
commit = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
                        capture_output=True, text=True).stdout.strip()

tok = rec["measured"]["defaultFeeToken"]

dep = rec.get("deployedByReckn") or {}
ver = dep.get("verified") or {}
deployment = None
if dep.get("RecknZkEscrow"):
    deployment = {
        "escrow": dep["RecknZkEscrow"],
        "verifier": dep["RecknVerdictVerifier"],
        "sp1": dep["SP1Verifier"],
        "escrowCodehash": ver.get("deployedEscrowCodehash"),
        "buyer": dep["run"]["buyer"],
        "seller": dep["run"]["seller"],
        "amount": dep["run"]["amountPerDeal"],
        "deployedAt": dep["deployedAt"],
        "cases": [
            {"name": c["case"], "dealId": c["dealId"], "settleTx": c.get("settleTx")}
            for c in ver.get("cases", [])
        ],
    }
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
    # Identifiers only. Not one OUTCOME is passed to the page: the page re-reads `deals()`
    # and the settlement receipts and works them out. Passing "the seller was paid" would
    # make section 5 a screenshot in HTML, which is what the rest of this file exists to
    # avoid. None of these values was typed -- tempo-testnet.sh wrote them from receipts and
    # tempo-verify.sh re-derived them from the chain.
    "deployment": deployment,
}

tpl = (root / "dashboard/live/tempo-template.html").read_text()
out = root / "docs/tempo.html"
out.write_text(tpl.replace("/*__CONFIG__*/", json.dumps(CFG, indent=2)))
print(f"docs/tempo.html  {out.stat().st_size:,} bytes  "
      f"chain {CFG['chainId']}  fee token {CFG['feeToken']} ({CFG['feeTokenDecimals']} dp)  "
      f"explorer {'linked' if CFG['explorer'] else 'NOT linked (unverified in the record)'}\n"
      f"  section 5: " + (f"{len(deployment['cases'])} deal(s) at escrow {deployment['escrow']}"
                          if deployment else "EMPTY -- the record carries no deployment"))

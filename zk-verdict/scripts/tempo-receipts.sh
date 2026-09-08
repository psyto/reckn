#!/usr/bin/env bash
# tempo-receipts — a transaction hash written by hand is a claim nobody checks.
#
# Sibling of arc-receipts.sh, written after the failure that one exists for: on 2026-09-06
# two of four Arc tx hashes were transcribed into the demo page WRONG -- plausible hex, right
# prefix, linking to nothing. A reader cannot tell a real receipt from a typo, which makes an
# unchecked receipt worth LESS than no receipt, because it looks like evidence.
#
# Three directions. The first two are arc-receipts.sh's; the third is the one that would have
# caught the Arc failure at its source instead of after it was noticed by eye.
#   (a) every explorer tx link in the repo names a hash tempo.json records  -> typos
#   (b) every transaction tempo.json records is linked somewhere            -> silent drops
#   (c) every hash tempo.json records EXISTS ON CHAIN and succeeded         -> dead values
#
# AND ONE CLAUSE ARC'S DOES NOT HAVE. If nothing is deployed yet, (a) and (b) are vacuous:
# an empty record satisfies "every recorded hash is linked" perfectly. A gate that prints a
# green line over an empty population is the exact shape this repository has been bitten by
# twice. So the empty state is reported as EMPTY, out loud, and exits 0 only because "not
# deployed" is a legitimate state -- never because it looks like a pass.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
rec="$root/zk-verdict/contracts/tempo.json"
[[ -f "$rec" ]] || { echo "tempo-receipts: missing $rec"; exit 2; }

RPC=$(jq -r '.testnet.rpc' "$rec")
EXPLORER_HOST=$(jq -r '.testnet.explorer' "$rec" | sed 's#https://##')
offline=0; [[ "${1:-}" == "--offline" ]] && offline=1

# Every hash the record carries, from wherever in deployedByReckn it sits. `..` rather than a
# fixed path on purpose: a record that grows a new section must not silently escape the gate.
known=()
while IFS= read -r t; do [[ -n "$t" ]] && known+=("$t"); done < <(
  jq -r '[.deployedByReckn | .. | strings | select(test("^0x[0-9a-fA-F]{64}$"))] | unique[]' "$rec")

if [[ ${#known[@]} -eq 0 ]]; then
  echo "tempo-receipts: tempo.json -> deployedByReckn records NO transactions."
  echo "  Nothing is deployed to Tempo. That is the honest state, not a pass:"
  echo "  every check below has an empty population and would agree with anything."
  echo "  Run zk-verdict/scripts/tempo-testnet.sh with a funded key to change it."
  exit 0
fi

# One scan of the tree, not one per hash: a `grep -r` per item contends with a running build
# badly enough to look like a hang. Never `... | grep -q` -- that SIGPIPEs the producer and
# reports a false pass, which has happened here twice.
links=$(grep -rhoE "$EXPLORER_HOST/tx/0x[0-9a-fA-F]+" \
          --include='*.md' --include='*.html' --include='*.sh' --include='*.json' --include='*.js' \
          --exclude-dir=out --exclude-dir=cache --exclude-dir=lib --exclude-dir=broadcast \
          --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=target \
          "$root" 2>/dev/null | sed 's#.*/tx/##' | LC_ALL=C sort -u || true)

bad=0; n=0
# (a)
while IFS= read -r h; do
  [[ -n "$h" ]] || continue
  n=$((n+1)); hit=0
  for k in "${known[@]}"; do [[ "$k" == "$h" ]] && hit=1; done
  [[ $hit -eq 1 ]] || { echo "tempo-receipts: linked tx is not in tempo.json: $h"; bad=1; }
done <<< "$links"

# (b) — only for hashes the record presents as evidence. A deploy transaction that nothing
# links to is not a silent drop; a settlement that nothing links to is.
linked_required=()
while IFS= read -r t; do [[ -n "$t" ]] && linked_required+=("$t"); done < <(
  jq -r '[.deployedByReckn.run.steps[]? | select(.step | test("^settle")) | .tx // empty] | unique[]' "$rec")
for k in "${linked_required[@]}"; do
  hit=0
  while IFS= read -r h; do [[ "$h" == "$k" ]] && hit=1; done <<< "$links"
  [[ $hit -eq 1 ]] || { echo "tempo-receipts: a recorded SETTLEMENT is linked nowhere: $k"; bad=1; }
done

# (c) — the clause that catches a right-shaped dead value. This is the only direction that
# leaves the repository, and it is named here because a chain of checks that never touches
# reality ends inside the tree (R-10).
if [[ $offline -eq 0 ]] && command -v curl >/dev/null; then
  for k in "${known[@]}"; do
    st=$(curl -s --max-time 30 -X POST -H 'content-type: application/json' \
          -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$k\"]}" \
          "$RPC" | jq -r '.result.status // "missing"')
    case "$st" in
      0x1) ;;
      missing) echo "tempo-receipts: $k is recorded but the chain has NO receipt for it"; bad=1 ;;
      *)       echo "tempo-receipts: $k exists but status=$st -- a failed transaction is not evidence"; bad=1 ;;
    esac
  done
else
  echo "tempo-receipts: --offline; skipped the on-chain existence check. The record was compared"
  echo "  only against itself, which is exactly what let a dead hash through on Arc."
fi

[[ $bad -eq 0 ]] || exit 1
w=$(printf '%s\n' "${known[@]}" | shasum -a 256 | cut -c1-16)
echo "tempo-receipts: $n linked tx hash(es) all recorded; ${#linked_required[@]} settlement(s) linked;" \
     "${#known[@]} recorded hash(es)$([[ $offline -eq 0 ]] && echo ' all exist on chain with status 1'); witness=$w"

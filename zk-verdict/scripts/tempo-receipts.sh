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

# Which 32-byte values in the record are TRANSACTION HASHES.
#
# The first version of this collected every 0x+64-hex string under deployedByReckn and
# treated them all as tx hashes. That is a check written by SHAPE, and R-7 says a check
# written by shape is not a check. It was wrong in both directions at once:
#
#   * `RecknVerdictVerifierCodehash` is 32 bytes and is not a transaction. After a real
#     deploy, clause (c) would have reported "the chain has NO receipt for it" -- a red gate
#     for a correct record, which is how gates get commented out rather than fixed.
#   * a real tx hash filed under a key it did not expect would have been skipped silently.
#
# So classification is by the LABEL the record itself puts on the value, and anything the
# script cannot classify is a FAILURE rather than a default. Adding a field to tempo.json
# now forces a decision here instead of quietly picking a side.
classify() { # reads the record, prints "<kind>\t<value>" for every 32-byte string in it
  jq -r 'paths(strings and test("^0x[0-9a-fA-F]{64}$")) as $p
         | (($p | map(select(type=="string")) | last)) as $k
         | (if ($k == "failedTx") then "failed-tx"
            elif ($k == "tx" or ($k | startswith("exampleType"))) then "tx"
            elif ($k | test("[Cc]odehash|vkey|[Bb]inding|dealId|output|programVKey")) then "not-a-tx"
            else "UNCLASSIFIED:" + $k end) + "\t" + getpath($p)' "$1"
}

unclassified=$(classify "$rec" | grep '^UNCLASSIFIED:' | sed 's/^UNCLASSIFIED://' | sort -u || true)
if [[ -n "$unclassified" ]]; then
  echo "tempo-receipts: tempo.json holds 32-byte value(s) this gate cannot classify (key, value):"
  echo "$unclassified" | sed 's/^/  /'
  echo "  Decide in classify() whether each is a transaction hash. Defaulting either way is how"
  echo "  a real receipt gets skipped, or a codehash gets reported as a dead transaction."
  exit 1
fi

known_list=$(classify "$rec" | sed -n 's/^tx\t//p' | LC_ALL=C sort -u)
known_n=$(printf '%s' "$known_list" | grep -c . || true)
# A transaction that FAILED is evidence too -- of what went wrong -- and hiding it would be
# the opposite of what this record is for. But it is a different claim, so it is checked
# against a different expectation: it must exist and it must have status 0. A hash filed as
# a failure that actually succeeded is as wrong as the reverse.
failed_list=$(classify "$rec" | sed -n 's/^failed-tx\t//p' | LC_ALL=C sort -u)
failed_n=$(printf '%s' "$failed_list" | grep -c . || true)

deployed=$(jq -r '.deployedByReckn.RecknZkEscrow // "null"' "$rec")
if [[ "$deployed" == "null" ]]; then
  echo "tempo-receipts: tempo.json -> deployedByReckn records NO deployment."
  echo "  Nothing is deployed to Tempo. That is the honest state, not a pass: clauses (a)"
  echo "  and (b) have an empty population and would agree with anything."
  echo "  Run zk-verdict/scripts/tempo-testnet.sh with a funded key to change it."
  echo "  Clause (c) still runs below over the $known_n hash(es) the record does carry."
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
  while IFS= read -r k; do [[ "$k" == "$h" ]] && hit=1; done <<< "$known_list"
  [[ $hit -eq 1 ]] || { echo "tempo-receipts: linked tx is not in tempo.json: $h"; bad=1; }
done <<< "$links"

# (b) — only for hashes the record presents as evidence. A deploy transaction that nothing
# links to is not a silent drop; a settlement that nothing links to is.
settlements=$(jq -r '[.deployedByReckn.run.steps[]? | select(.step | test("^settle")) | .tx // empty] | unique[]' "$rec")
settlements_n=$(printf '%s' "$settlements" | grep -c . || true)
while IFS= read -r k; do
  [[ -n "$k" ]] || continue
  hit=0
  while IFS= read -r h; do [[ "$h" == "$k" ]] && hit=1; done <<< "$links"
  [[ $hit -eq 1 ]] || { echo "tempo-receipts: a recorded SETTLEMENT is linked nowhere: $k"; bad=1; }
done <<< "$settlements"

# (c) — the clause that catches a right-shaped dead value. This is the only direction that
# leaves the repository, and it is named here because a chain of checks that never touches
# reality ends inside the tree (R-10).
if [[ $offline -eq 0 ]] && command -v curl >/dev/null; then
  while IFS= read -r k; do
    [[ -n "$k" ]] || continue
    st=$(curl -s --max-time 30 -X POST -H 'content-type: application/json' \
          -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$k\"]}" \
          "$RPC" | jq -r '.result.status // "missing"')
    case "$st" in
      0x1) ;;
      missing) echo "tempo-receipts: $k is recorded but the chain has NO receipt for it"; bad=1 ;;
      *)       echo "tempo-receipts: $k exists but status=$st -- a failed transaction is not evidence"; bad=1 ;;
    esac
  done <<< "$known_list"
  while IFS= read -r k; do
    [[ -n "$k" ]] || continue
    st=$(curl -s --max-time 30 -X POST -H 'content-type: application/json' \
          -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$k\"]}" \
          "$RPC" | jq -r '.result.status // "missing"')
    case "$st" in
      0x0) ;;
      missing) echo "tempo-receipts: $k is recorded as a FAILURE but the chain has no receipt for it"; bad=1 ;;
      *)       echo "tempo-receipts: $k is recorded as a FAILURE but its status is $st -- it succeeded"; bad=1 ;;
    esac
  done <<< "$failed_list"
else
  echo "tempo-receipts: --offline; skipped the on-chain existence check. The record was compared"
  echo "  only against itself, which is exactly what let a dead hash through on Arc."
fi

[[ $bad -eq 0 ]] || exit 1
w=$(printf '%s' "$known_list" | shasum -a 256 | cut -c1-16)
echo "tempo-receipts: $n linked tx hash(es) all recorded; $settlements_n settlement(s) linked;" \
     "$known_n succeeded + $failed_n failed recorded hash(es)$([[ $offline -eq 0 ]] && echo ' all confirmed on chain'); witness=$w"

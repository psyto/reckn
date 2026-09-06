#!/usr/bin/env bash
# arc-receipts — a transaction hash written by hand is a claim nobody checks.
#
# The live-Arc receipts appear in the README, the docs, the demo page and the
# submission. `zk-verdict/contracts/arc.json` is the record; everything else is a
# transcription, and on 2026-09-06 two of four transcriptions into the demo page were
# WRONG — plausible hex, right prefix, links to nothing. A reader cannot tell a real
# receipt from a typo, which makes an unchecked receipt worth less than no receipt.
#
# Two directions, because each catches a different mistake:
#   (a) every arcscan tx link in the repo names a hash arc.json records  -> typos
#   (b) every settlement arc.json records is linked somewhere            -> silent drops
set -euo pipefail
root=$(git rev-parse --show-toplevel)
rec="$root/zk-verdict/contracts/arc.json"

# bash 3.2 (the macOS default) has no `mapfile`.
known=()
while IFS= read -r t; do known+=("$t"); done < <(jq -r '.deployedByReckn.settlements[].tx' "$rec" | LC_ALL=C sort)
[[ ${#known[@]} -ge 4 ]] || { echo "arc-receipts: arc.json records only ${#known[@]} settlements"; exit 1; }

# (a) — collect links WITHOUT a pipe into a short-circuiting reader (a `grep -q` at the
# end of a pipe SIGPIPEs the producer and reports a false pass; this repo has been
# bitten by that twice).
links=$(grep -rhoE 'testnet\.arcscan\.app/tx/0x[0-9a-fA-F]+' \
          --include='*.md' --include='*.html' --include='*.sh' --include='*.json' \
          "$root" 2>/dev/null | sed 's#.*/tx/##' | LC_ALL=C sort -u || true)
bad=0; n=0
while IFS= read -r h; do
  [[ -n "$h" ]] || continue
  n=$((n+1)); hit=0
  for k in "${known[@]}"; do [[ "$k" == "$h" ]] && hit=1; done
  [[ $hit -eq 1 ]] || { echo "arc-receipts: linked tx not in arc.json: $h"; bad=1; }
done <<< "$links"

# (b) — set membership against the SAME single scan. One `grep -r` per settlement over
# the whole tree contends with a running build badly enough to look like a hang.
for k in "${known[@]}"; do
  hit=0
  while IFS= read -r h; do [[ "$h" == "$k" ]] && hit=1; done <<< "$links"
  [[ $hit -eq 1 ]] || { echo "arc-receipts: recorded settlement is linked nowhere: $k"; bad=1; }
done

[[ $bad -eq 0 ]] || exit 1
w=$(printf '%s\n' "${known[@]}" | shasum -a 256 | cut -c1-16)
echo "arc-receipts: $n linked tx hashes all recorded, ${#known[@]}/${#known[@]} recorded settlements linked; witness=$w"

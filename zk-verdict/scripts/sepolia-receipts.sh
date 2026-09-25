#!/usr/bin/env bash
# sepolia-receipts — the Tokyo counterpart of arc-receipts.
#
# A transaction hash written by hand is a claim nobody checks. On 2026-09-06 two of four
# Arc hashes transcribed into the demo page were WRONG — plausible hex, right prefix,
# links to nothing — and `arc-receipts.sh` exists because a reader cannot tell a real
# receipt from a typo. `zk-verdict/contracts/sepolia.json` is the record for the Tokyo
# work; everything else is a transcription.
#
# Three directions, because each catches a different mistake:
#   (a) every sepolia.etherscan.io tx link in the repo names a hash the record holds -> typos
#   (b) every tx the record holds is linked somewhere                                -> silent drops
#   (c) the record still shows the thing beat 1 claims                               -> a demo that
#       quietly stopped demonstrating. (a) and (b) both stay green if the refusal turns
#       into a success, which is exactly what one approve() on the agent token would do.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
rec="$root/zk-verdict/contracts/sepolia.json"
[[ -f "$rec" ]] || { echo "sepolia-receipts: no record at $rec"; exit 1; }

# bash 3.2 (the macOS default) has no `mapfile`.
known=()
while IFS= read -r t; do known+=("$t"); done \
  < <(jq -r '(.eventWork,.preEvent) | .[].tx' "$rec" | LC_ALL=C sort)
[[ ${#known[@]} -ge 5 ]] || { echo "sepolia-receipts: record holds only ${#known[@]} transactions"; exit 1; }

# (a) — collect links WITHOUT a pipe into a short-circuiting reader. A `grep -q` at the
# end of a pipe SIGPIPEs the producer and reports a false pass; this repo has been bitten
# by that twice.
links=$(grep -rhoE 'sepolia\.etherscan\.io/tx/0x[0-9a-fA-F]+' \
          --include='*.md' --include='*.html' --include='*.sh' --include='*.json' \
          "$root" 2>/dev/null | sed 's#.*/tx/##' | LC_ALL=C sort -u || true)
bad=0; n=0
while IFS= read -r h; do
  [[ -n "$h" ]] || continue
  n=$((n+1)); hit=0
  for k in "${known[@]}"; do [[ "$k" == "$h" ]] && hit=1; done
  [[ $hit -eq 1 ]] || { echo "sepolia-receipts: linked tx not in the record: $h"; bad=1; }
done <<< "$links"

# (b) — set membership against the SAME single scan. One `grep -r` per entry over the
# whole tree contends with a running build badly enough to look like a hang.
for k in "${known[@]}"; do
  hit=0
  while IFS= read -r h; do [[ "$h" == "$k" ]] && hit=1; done <<< "$links"
  [[ $hit -eq 1 ]] || { echo "sepolia-receipts: recorded tx is linked nowhere: $k"; bad=1; }
done

# (c) — the demonstration, asserted as a property of the record rather than by name.
# Exactly one event-work transaction failed; it came from the account that owns the
# agent; the identical accepted call came from a different account. Any of those three
# ceasing to be true means beat 1 no longer shows what the submission says it shows.
owner=$(jq -r '.accounts.agentOwner.address      | ascii_downcase' "$rec")
second=$(jq -r '.accounts.secondAddress.address  | ascii_downcase' "$rec")
nfail=$(jq '[.eventWork[] | select(.status==0)] | length' "$rec")
failfrom=$(jq -r 'first(.eventWork[] | select(.status==0) | .from) // "" | ascii_downcase' "$rec")
oksenders=$(jq -r '[.eventWork[] | select(.status==1) | .from | ascii_downcase] | unique | join(" ")' "$rec")

[[ "$nfail" == "1" ]] \
  || { echo "sepolia-receipts: expected exactly one refused transaction, record has $nfail"; bad=1; }
[[ "$failfrom" == "$owner" ]] \
  || { echo "sepolia-receipts: the refused transaction did not come from the agent's owner ($failfrom)"; bad=1; }
case " $oksenders " in
  *" $second "*) ;;
  *) echo "sepolia-receipts: no accepted transaction came from the second address"; bad=1 ;;
esac
[[ "$owner" != "$second" ]] \
  || { echo "sepolia-receipts: owner and second address are the same account"; bad=1; }

[[ $bad -eq 0 ]] || exit 1
w=$(printf '%s\n' "${known[@]}" | shasum -a 256 | cut -c1-16)
echo "sepolia-receipts: $n linked tx hashes all recorded, ${#known[@]}/${#known[@]} recorded tx linked;"
echo "sepolia-receipts: refused from the owner, accepted from a second address; witness=$w"

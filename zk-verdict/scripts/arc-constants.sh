#!/usr/bin/env bash
# arc-constants — the Arc network values are TRANSCRIBED from Circle's docs, and a
# transcription that lives in six files is six chances to be wrong. `arc.json` is the
# record; the README, the Arc doc, the deploy script and the demo page each restate
# parts of it. Nothing checked that they agree until a hash typo on 2026-09-06 showed
# how a wrong-but-plausible literal survives review: right shape, right prefix, dead.
#
# Two directions, as with the receipts:
#   (a) a literal in the docs that LOOKS like an Arc constant must BE the recorded one
#   (b) each recorded constant must actually appear somewhere, or the record is prose
#
# What this cannot do: tell you the record itself is right. `arc.json` carries its
# source URL and read date for exactly that reason — this checks internal agreement,
# not Circle's documentation. Same boundary as the guest's bank_hash.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
rec="$root/zk-verdict/contracts/arc.json"
[[ -f "$rec" ]] || { echo "arc-constants: missing $rec"; exit 2; }

chain=$(jq -r '.testnet.chainId' "$rec")
usdc=$(jq -r '.testnet.usdcErc20' "$rec")
rpc=$(jq -r '.testnet.rpc' "$rec")
exp=$(jq -r '.testnet.explorer' "$rec")
fau=$(jq -r '.testnet.faucet' "$rec")

# Scoping direction (a) for the address took two tries. "Starts with 0x36" also matches
# unrelated addresses whose first byte is 0x36, and two did. "Ends in a long run of
# zeros" matches every ABI-encoded word, the zero address and the OP-stack predeploys.
# What is left is narrow and honest: an address CLAIMING to be the USDC predeploy —
# 0x3600-prefixed — that is not the recorded one. That is the realistic typo (wrong
# digits in the tail). A typo in the prefix itself escapes this, and saying so is
# better than a regex that cries wolf until someone stops reading it.
# One scan, filtered — never `... | grep -q`, which SIGPIPEs the producer and reports
# a false pass. This repo has been bitten by that twice.
scan=$(grep -rhoE '\b504[0-9]{4}\b|0x3600[0-9a-fA-F]{36}|https://(rpc\.testnet\.arc\.io|testnet\.arcscan\.app|faucet\.circle\.com)' \
        --include='*.md' --include='*.html' --include='*.sh' --include='*.sol' --include='*.json' \
        "$root" 2>/dev/null | LC_ALL=C sort -u || true)

bad=0; n=0
while IFS= read -r lit; do
  [[ -n "$lit" ]] || continue
  n=$((n+1))
  case "$lit" in
    504*)   [[ "$lit" == "$chain" ]] || { echo "arc-constants: chain-id-shaped literal '$lit' != recorded $chain"; bad=1; } ;;
    0x*)    [[ "$(echo "$lit" | tr 'A-F' 'a-f')" == "$(echo "$usdc" | tr 'A-F' 'a-f')" ]] \
              || { echo "arc-constants: USDC-predeploy-shaped address '$lit' != recorded $usdc"; bad=1; } ;;
    *)      case "$lit" in "$rpc"|"$exp"|"$fau") ;; *) echo "arc-constants: unrecorded Arc URL '$lit'"; bad=1 ;; esac ;;
  esac
done <<< "$scan"

for want in "$chain" "$usdc" "$rpc" "$exp" "$fau"; do
  hit=0
  while IFS= read -r lit; do [[ "$lit" == "$want" ]] && hit=1; done <<< "$scan"
  [[ $hit -eq 1 ]] || { echo "arc-constants: recorded constant appears nowhere: $want"; bad=1; }
done

[[ $bad -eq 0 ]] || exit 1
w=$(printf '%s\n%s\n%s\n%s\n%s\n' "$chain" "$usdc" "$rpc" "$exp" "$fau" | shasum -a 256 | cut -c1-16)
echo "arc-constants: $n Arc-shaped literals all match the record, 5/5 recorded constants present; witness=$w"

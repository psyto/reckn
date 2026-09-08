#!/usr/bin/env bash
# tempo-constants — task 011's sibling of arc-constants.sh, and it exists for a sharper
# reason than that one did.
#
# On 2026-09-08 two published URLs both claimed to be "the Tempo RPC". Measured:
#
#   https://rpc.moderato.tempo.xyz  ->  eth_chainId 0xa5bf = 42431   (Moderato testnet)
#   https://rpc.tempo.xyz           ->  eth_chainId 0x1079 =  4217   (TEMPO MAINNET)
#
# The second line said "a DIFFERENT chain" until 2026-09-08, when the connection-details page
# was actually read: 4217 is MAINNET, for "production assets such as pathUSD, and live payment
# flows". So this is not a tidiness check about a stale URL. It is the mainnet guard, and
# AGENTS.md §8 forbids what the wrong endpoint would have done outright.
#
# Every constant around the wrong one still looks plausible: right scheme, right domain,
# right shape. That is exactly the failure mode arc-constants.sh was written for after a
# hash typo survived review — right prefix, dead value — and here it would have meant
# deploying to the wrong network.
#
# Two directions, as with Arc:
#   (a) a literal in the tree that LOOKS like a Tempo constant must BE the recorded one
#   (b) each recorded constant must actually appear somewhere, or the record is prose
#
# Plus one clause Arc does not need:
#   (c) the wrong endpoint must not appear in the tree AS AN ENDPOINT at all.
#
# What this cannot do: tell you tempo.json is right. It carries how each value was obtained
# for that reason — same boundary as the guest's bank_hash, and as arc-constants.sh.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
rec="$root/zk-verdict/contracts/tempo.json"
[[ -f "$rec" ]] || { echo "tempo-constants: missing $rec"; exit 2; }

chain=$(jq -r '.testnet.chainId' "$rec")
rpc=$(jq -r '.testnet.rpc' "$rec")
wrong=$(jq -r '.wrongEndpoint.url' "$rec")
factory=$(jq -r '.measured.tip20Factory.address' "$rec")
feetoken=$(jq -r '.measured.defaultFeeToken.address' "$rec")

# Build output is excluded, and not only for tidiness: an unfiltered scan of this tree
# took over two minutes, and a gate that slow gets commented out rather than fixed.
files=(--include='*.md' --include='*.html' --include='*.sh' --include='*.sol' --include='*.json' --include='*.js'
       --exclude-dir=out --exclude-dir=cache --exclude-dir=lib --exclude-dir=broadcast
       --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=target)

# ---- (c) the wrong endpoint, named -------------------------------------------------
# Scoped to the HOSTNAME, and deliberately not to the string "tempo.xyz" — the docs URLs
# in tempo.json and in the spec are legitimately on that domain, and a check that cried
# wolf about them would be switched off within a week. What is forbidden is the endpoint.
# `tempo.json` itself records it as the wrong one, so that file is the single exemption.
# Per LINE, not per file. The first version of this clause was per-file and failed the
# spec, the deploy script and this file itself — all three of which name the wrong
# endpoint precisely in order to WARN about it. A check that cannot tell "used" from
# "named as wrong" punishes the documentation that prevents the mistake.
#
# The rule that separates them: you may name it only where you also say what it is. Any
# honest mention carries the chain id it actually answers, so a line holding the wrong
# host must also hold 4217. A line that has the host and not the number is using it.
wrong_host=${wrong#https://}
wrong_chain=$(jq -r '.wrongEndpoint.chainId' "$rec")
hits=$(grep -rn --fixed-strings "$wrong_host" "${files[@]}" "$root" 2>/dev/null \
        | grep -v '^[^:]*/tempo.json:' \
        | grep -v "$wrong_chain" || true)
if [[ -n "$hits" ]]; then
  echo "tempo-constants: the WRONG endpoint $wrong is used without saying so at:"
  echo "$hits" | sed 's/^/  /' | cut -c1-160
  echo "  that is Tempo MAINNET (chain $wrong_chain), not the testnet's $chain. Use $rpc."
  exit 1
fi

# ---- (a) Tempo-shaped literals must be the recorded ones ---------------------------
# Narrow on purpose. `42431` alone is a bare integer that could mean anything, so the
# scan is over things that can only be Tempo constants: the moderato hostnames and
# 0x20Fc-prefixed addresses (the TIP20Factory shape). An address whose PREFIX is
# mistyped escapes this, and saying so is better than a regex nobody reads.
# One scan, filtered — never `... | grep -q`, which SIGPIPEs the producer and reports a
# false pass. This repository has been bitten by that twice.
# The trailing [a-z.]* is not decoration. Without it the pattern matched only the PREFIX of
# the recorded host, so the same host with a DOUBLED FINAL LETTER was reported as matching
# the record — a check that passes a mistyped hostname is worse than no check, and this one
# did until it was probed with exactly that string. Capturing any trailing letters turns the
# typo into a non-match against the record instead of a silent prefix hit.
#
# The typo is described here rather than written out, because writing it out is what the
# clause below is for and this file is not exempt from its own rule.
scan=$(grep -rhoE 'https://[a-z.]*moderato\.tempo\.xyz[a-z.]*|0x20[Ff]c[0-9a-fA-F]{36}|0x20[Cc]0[0-9a-fA-F]{36}' \
        "${files[@]}" "$root" 2>/dev/null | LC_ALL=C sort -u || true)

# Addresses are HEX: case carries no meaning, and EIP-55 checksumming deliberately varies
# it. Solidity requires the checksummed form, so a source file and a JSON record will
# legitimately disagree in case for the same address — and a case-sensitive comparison
# reported exactly that as a mismatch the first time this gate met a real one. Compare the
# digits, not the shift key. (The RPC hostname above is NOT compared this way: DNS is
# case-insensitive too, but a hostname is not hex and a stray capital there is worth seeing.)
same() { [[ "$(printf '%s' "$1" | tr 'A-F' 'a-f')" == "$(printf '%s' "$2" | tr 'A-F' 'a-f')" ]]; }

bad=0; n=0
while IFS= read -r lit; do
  [[ -n "$lit" ]] || continue
  n=$((n + 1))
  case "$lit" in
    https://*)
      # explore.testnet.tempo.xyz is not a moderato host, so only the RPC lands here.
      [[ "$lit" == "$rpc" ]] || { echo "tempo-constants: $lit is not the recorded rpc $rpc"; bad=1; } ;;
    0x20Fc* | 0x20fc*)
      same "$lit" "$factory" || { echo "tempo-constants: $lit is not the recorded factory $factory"; bad=1; } ;;
    0x20C0* | 0x20c0*)
      # PathUSD, measured 2026-09-08 as the token both sampled receipts paid their fee in.
      same "$lit" "$feetoken" || { echo "tempo-constants: $lit is not the recorded fee token $feetoken"; bad=1; } ;;
  esac
done <<<"$scan"

# ---- (b) each recorded constant must be used somewhere ------------------------------
# The URL is distinctive enough to search for as itself. The CHAIN ID is not: it is a bare
# integer, and a probe that pointed the record at an unrelated six-digit number passed,
# because that number genuinely appears in an old spec. So the chain id must be found on a
# line that ALSO says Tempo — the presence of a number is not evidence that the number is
# being used as this chain's id.
#
# Two things that version still got wrong, both found by probing rather than by reading:
#   - the context grep ran over `path:line:text`, so every file with "tempo" in its NAME
#     passed automatically. The prefix is stripped now.
#   - the witness was this script's own comment about the probe. The record and the checker
#     are both excluded: a constant is in use only if something OTHER than the two files
#     that define and verify it uses it. The probe value is described, not written.
used_plain() { grep -rl --fixed-strings "$1" "${files[@]}" "$root" 2>/dev/null | grep -v '/tempo.json$' | head -1; }
self="zk-verdict/scripts/tempo-constants.sh"
used_in_context() {
  grep -rn --fixed-strings "$1" "${files[@]}" "$root" 2>/dev/null \
    | grep -v '^[^:]*/tempo.json:' | grep -v "^[^:]*/${self##*/}:" \
    | sed 's/^[^:]*:[0-9]*://' | grep -i 'tempo' | head -1
}
if [[ -z "$(used_in_context "$chain")" ]]; then
  echo "tempo-constants: chain $chain appears on no line that also names Tempo -- the record is prose"
  bad=1
fi
if [[ -z "$(used_plain "$rpc")" ]]; then
  echo "tempo-constants: $rpc is recorded but appears nowhere outside tempo.json -- the record is prose"
  bad=1
fi

[[ $bad -eq 0 ]] || exit 1
echo "tempo-constants: $n Tempo-shaped literal(s) all match the record; chain $chain and $rpc are both in use; the 4217 endpoint appears nowhere"

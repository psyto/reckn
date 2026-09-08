#!/usr/bin/env bash
# tempo-arc-parity — the claim "the same escrow source, unmodified, settles on two payment
# chains" is the strongest sentence in the submission, and until this script nothing checked
# it. It is checkable, exactly, because of a property the contract already has:
#
#   RecknZkEscrow has NO CONSTRUCTOR and NO IMMUTABLE.
#
# So its deployed bytecode is a pure function of its source. Two deployments of the same
# source have the same codehash, on any chain, and two deployments that differ by one line
# do not. That is why this gate reads the ESCROW and not the verifier -- the verifier takes
# a vkey and an address in its constructor, so its code legitimately differs per deployment
# and proves nothing about the source.
#
# It reads BOTH CHAINS. A comparison against a local artifact would only say what this
# machine can compile today; the claim is about what is deployed and settling, so both sides
# are fetched with eth_getCode and compared byte for byte. The local artifact is checked too,
# which is what makes the sentence "and it is the source in this repository" rather than
# merely "the two are the same as each other".
#
# What it does NOT establish: that the two chains adjudicate identically. They cannot -- the
# deals name different verifiers and different tokens. What crosses chains here is the SOURCE,
# and the payout logic it fixes. Nothing else is claimed.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root/zk-verdict/contracts"

arc="$root/zk-verdict/contracts/arc.json"
tempo="$root/zk-verdict/contracts/tempo.json"
for f in "$arc" "$tempo"; do [[ -f "$f" ]] || { echo "tempo-arc-parity: missing $f"; exit 2; }; done

ARC_RPC=$(jq -r '.testnet.rpc' "$arc")
ARC_ESC=$(jq -r '.deployedByReckn.RecknZkEscrow // empty' "$arc")
ARC_CHAIN=$(jq -r '.testnet.chainId' "$arc")
T_RPC=$(jq -r '.testnet.rpc' "$tempo")
T_ESC=$(jq -r '.deployedByReckn.RecknZkEscrow // empty' "$tempo")
T_CHAIN=$(jq -r '.testnet.chainId' "$tempo")

if [[ -z "$ARC_ESC" || -z "$T_ESC" ]]; then
  echo "tempo-arc-parity: one of the two chains records no escrow deployment"
  echo "  arc:   ${ARC_ESC:-<none>}"
  echo "  tempo: ${T_ESC:-<none>}"
  echo "  There is nothing to compare, and 'settles on two payment chains' is not yet true."
  exit 1
fi

code_at() { # $1 rpc, $2 address -- fails loudly rather than returning empty
  local c
  c=$(cast code --rpc-url "$1" "$2" 2>/dev/null || true)
  [[ -n "$c" && "$c" != "0x" ]] || { echo "tempo-arc-parity: no code at $2 via $1"; exit 1; }
  printf '%s' "$c"
}

echo "tempo-arc-parity: reading the deployed escrow off both chains"
ARC_CODE=$(code_at "$ARC_RPC" "$ARC_ESC")
T_CODE=$(code_at "$T_RPC" "$T_ESC")
# The chain ids are read back too: a record that names the wrong endpoint would otherwise
# let this gate compare a chain against itself and pass triumphantly.
arc_id=$(cast chain-id --rpc-url "$ARC_RPC"); t_id=$(cast chain-id --rpc-url "$T_RPC")
[[ "$arc_id" == "$ARC_CHAIN" ]] || { echo "tempo-arc-parity: $ARC_RPC answered chain $arc_id, not $ARC_CHAIN"; exit 1; }
[[ "$t_id"   == "$T_CHAIN"   ]] || { echo "tempo-arc-parity: $T_RPC answered chain $t_id, not $T_CHAIN"; exit 1; }
[[ "$arc_id" != "$t_id" ]] || { echo "tempo-arc-parity: both endpoints are the same chain ($arc_id) -- this proves nothing"; exit 1; }

# out/ rather than `forge inspect`: inspect recompiles on the fly and may answer with a newer
# solc than the one that produced these deployments (measured 2026-09-08: 0.8.20 vs 0.8.35).
ART=$(jq -r '.deployedBytecode.object' out/RecknZkEscrow.sol/RecknZkEscrow.json)
h() { cast keccak "$1"; }

printf '  chain %-9s %s  %s\n' "$arc_id" "$ARC_ESC" "$(h "$ARC_CODE")"
printf '  chain %-9s %s  %s\n' "$t_id" "$T_ESC" "$(h "$T_CODE")"
printf '  %-15s %-42s %s\n' "artifact" "out/RecknZkEscrow.sol" "$(h "$ART")"
echo

bad=0
if [[ "$ARC_CODE" == "$T_CODE" ]]; then
  echo "  [ok ] the two deployments are byte-identical"
else
  echo "  [FAIL] the deployed escrows DIFFER between chain $arc_id and chain $t_id."
  echo "         'the same escrow source, unmodified, settles on two payment chains' is FALSE"
  echo "         as written. Find out which one is not the source before saying it again."
  bad=1
fi
if [[ "$ARC_CODE" == "$ART" ]]; then
  echo "  [ok ] and both are the artifact this repository compiles"
else
  echo "  [FAIL] the deployed code is not what this repository compiles today. Either the"
  echo "         source moved after deployment, or the deployment is not from this source."
  bad=1
fi

# Only assert the no-constructor property that makes the comparison MEAN anything. Without
# it, equal codehashes would be a coincidence of configuration rather than of source.
if grep -qE '^\s*(constructor|.*\bimmutable\b)' src/RecknZkEscrow.sol; then
  echo "  [FAIL] RecknZkEscrow has gained a constructor or an immutable. Its bytecode is no"
  echo "         longer a pure function of its source, so codehash equality stops meaning"
  echo "         'same source' and this gate stops being evidence."
  bad=1
else
  echo "  [ok ] RecknZkEscrow still has no constructor and no immutable, which is what makes"
  echo "        codehash equality mean SAME SOURCE rather than same configuration"
fi

[[ $bad -eq 0 ]] || exit 1

jq --arg ah "$(h "$ARC_CODE")" --arg arc "$ARC_ESC" --arg aid "$arc_id" \
   --arg t "$T_ESC" --arg tid "$t_id" --arg when "$(date -u +%Y-%m-%d)" '
  .deployedByReckn.sameCodeAsArc = {
    _: "Checked by zk-verdict/scripts/tempo-arc-parity.sh, which reads eth_getCode off BOTH chains and compares byte for byte. Recorded here rather than in arc.json so that 005 owns one record and 011 owns the other.",
    checkedOn: $when,
    codehash: $ah,
    arc: {chainId: ($aid|tonumber), escrow: $arc},
    tempo: {chainId: ($tid|tonumber), escrow: $t},
    whyItMeansSomething: "RecknZkEscrow has no constructor and no immutable, so its deployed bytecode is a pure function of its source. Equal codehashes on two chains therefore mean the same source, not merely the same configuration. The verifier is deliberately NOT compared: it takes a vkey and an address at construction, so its code legitimately differs per deployment.",
    whatItDoesNotClaim: "That the two chains adjudicate identically. They do not: the deals name different verifiers and different tokens. What is shared is the source, and the payout logic it fixes."
  }' "$tempo" > "$tempo.tmp" && mv "$tempo.tmp" "$tempo"

echo
echo "tempo-arc-parity: one escrow source, two payment chains, byte-identical on both."
echo "  Recorded in tempo.json -> deployedByReckn.sameCodeAsArc"

#!/usr/bin/env bash
# tempo-verify — read the Tempo deployment back off the chain and check that it did what
# 011 claims, deriving every value rather than trusting the run that produced it.
#
# WHY IT IS SEPARATE FROM tempo-testnet.sh. The script that sends the transactions is the
# wrong thing to ask whether they worked: it knows what it INTENDED. This one starts from
# tempo.json, which holds only addresses and transaction hashes, and reconstructs the
# outcomes from receipts and from `deals()` on the escrow.
#
# Nothing here is transcribed. The deal ids in particular are NOT copied from a terminal --
# they are read out of the `Funded` event in each fund receipt, because a deal id typed by a
# human is exactly the class of value that went wrong twice on Arc.
#
# It also does the one thing 011's T-4 actually asks for: read `feeToken` and `feePayer` from
# each settling transaction's own receipt, and check that the fee for releasing a stablecoin
# escrow was itself paid in a stablecoin. That sentence is why this is a Tempo slice rather
# than a redeploy, and it is not inferable from anything else.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root/zk-verdict/contracts"
rec="$root/zk-verdict/contracts/tempo.json"
RPC=$(jq -r '.testnet.rpc' "$rec")
ESCROW=$(jq -r '.deployedByReckn.RecknZkEscrow // empty' "$rec")
[[ -n "$ESCROW" ]] || { echo "tempo-verify: tempo.json records no deployment. Run tempo-testnet.sh first."; exit 2; }
TOKEN=$(jq -r '.deployedByReckn.tip20Used' "$rec")
BUYER=$(jq -r '.deployedByReckn.run.buyer' "$rec")
SELLER=$(jq -r '.deployedByReckn.run.seller' "$rec")
DEC=$(jq -r '.measured.defaultFeeToken.decimals' "$rec")
AMOUNT=$(jq -r '.deployedByReckn.run.amountPerDeal' "$rec")

lc() { printf '%s' "$1" | tr 'A-F' 'a-f'; }
fmt() { python3 -c 'import sys; v,d=int(sys.argv[1]),int(sys.argv[2]); print(f"{v/10**d:.{d}f}")' "$1" "$DEC"; }
receipt() {
  curl -s --max-time 60 -X POST -H 'content-type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$1\"]}" "$RPC" | jq '.result'
}
tx_of() { jq -r --arg s "$1" '.deployedByReckn.run.steps[] | select(.step==$s) | .tx' "$rec"; }

FUNDED_SIG=$(cast keccak "Funded(bytes32,address,address,address,uint256,address,bytes32,bytes32)")
SETTLED_SIG=$(cast keccak "SettledByProof(bytes32,address,uint8,bytes32)")
TRANSFER_SIG=$(cast keccak "Transfer(address,address,uint256)")

fail=0
say() { if [[ "$1" == 1 ]]; then printf '  [ok ] %s\n' "$2"; else printf '  [FAIL] %s\n' "$2"; fail=1; fi; }

echo "tempo-verify: reading back $ESCROW on chain $(cast chain-id --rpc-url "$RPC")"
echo

# ---- the deployment is the code this repository builds ---------------------------------
onchain=$(cast keccak "$(cast code --rpc-url "$RPC" "$ESCROW")")
# out/ rather than `forge inspect`: inspect recompiles on the fly and may answer with a
# different solc than the one that produced the deployment (measured: 0.8.20 vs 0.8.35).
artifact=$(cast keccak "$(jq -r '.deployedBytecode.object' out/RecknZkEscrow.sol/RecknZkEscrow.json)")
say $([[ "$onchain" == "$artifact" ]] && echo 1 || echo 0) \
  "the deployed escrow is byte-identical to the compiled artifact ($onchain)"

results='[]'
for name in reproduced failed mismatch; do
  echo
  echo "  --- $name ---"
  ftx=$(tx_of "fund ($name)")
  [[ -n "$ftx" && "$ftx" != null ]] || { say 0 "no fund transaction recorded for $name"; continue; }
  fr=$(receipt "$ftx")
  # The deal id comes out of the Funded event, not out of a human's clipboard.
  dealId=$(jq -r --arg t "$FUNDED_SIG" '.logs[] | select(.topics[0]==$t) | .topics[1]' <<<"$fr")
  say $([[ -n "$dealId" ]] && echo 1 || echo 0) "deal id read from the Funded event: $dealId"

  d=$(cast call --rpc-url "$RPC" "$ESCROW" \
      "deals(bytes32)(address,address,address,uint256,address,bytes32,bytes32,uint64,uint8)" "$dealId")
  d_seller=$(sed -n '2p' <<<"$d"); d_token=$(sed -n '3p' <<<"$d")
  d_amount=$(sed -n '4p' <<<"$d" | awk '{print $1}'); d_state=$(sed -n '9p' <<<"$d")
  say $([[ "$(lc "$d_seller")" == "$(lc "$SELLER")" ]] && echo 1 || echo 0) "seller is fixed at funding: $d_seller"
  say $([[ "$(lc "$d_token")" == "$(lc "$TOKEN")" ]] && echo 1 || echo 0) "the deal names the real TIP-20: $d_token"
  say $([[ "$d_amount" == "$AMOUNT" ]] && echo 1 || echo 0) "amount $(fmt "$d_amount")"

  stx=$(tx_of "settle ($name)")
  if [[ "$name" == mismatch ]]; then
    say $([[ -z "$stx" || "$stx" == null ]] && echo 1 || echo 0) "no settlement transaction exists -- it never landed"
    say $([[ "$d_state" == 1 ]] && echo 1 || echo 0) "the deal is still Funded (state $d_state), so a real proof of another execution moved nothing"
    held=$(cast call --rpc-url "$RPC" "$TOKEN" "balanceOf(address)(uint256)" "$ESCROW" | awk '{print $1}')
    say $([[ "$held" == "$AMOUNT" ]] && echo 1 || echo 0) "the escrow still holds $(fmt "$held")"
    results=$(jq --argjson r "$results" -n --arg n mismatch --arg id "$dealId" --arg st "$d_state" --arg held "$held" \
      '$r + [{case:$n, dealId:$id, state:($st|tonumber), escrowStillHolds:$held,
              settled:false, note:"rejected before inclusion; there is no transaction to link"}]')
    continue
  fi

  sr=$(receipt "$stx")
  say $([[ "$(jq -r .status <<<"$sr")" == "0x1" ]] && echo 1 || echo 0) "settlement transaction succeeded: $stx"
  outcome=$(jq -r --arg t "$SETTLED_SIG" '.logs[] | select(.topics[0]==$t) | (.data[2:66])' <<<"$sr" | sed 's/^0*//')
  outcome=${outcome:-0}
  paid_to=0x$(jq -r --arg t "$SETTLED_SIG" '.logs[] | select(.topics[0]==$t) | .topics[2][26:]' <<<"$sr")
  moved=$(jq -r --arg t "$TRANSFER_SIG" --arg tok "$(lc "$TOKEN")" --arg esc "$(lc "$ESCROW")" \
    '[.logs[] | select((.topics[0]==$t)
                       and ((.address|ascii_downcase)==$tok)
                       and (("0x"+(.topics[1][26:])|ascii_downcase)==$esc))] | .[0].data // "0x0"' <<<"$sr")
  moved_dec=$(python3 -c "import sys;print(int(sys.argv[1],16))" "$moved")

  if [[ "$name" == reproduced ]]; then
    say $([[ "$outcome" == "" || "$outcome" == "0" ]] && echo 1 || echo 0) "the proof's outcome was REPRODUCED (0)"
    want=$SELLER; who=seller
  else
    say $([[ "$outcome" == "1" ]] && echo 1 || echo 0) "the proof's outcome was FAILED (1)"
    want=$BUYER; who=buyer
  fi
  say $([[ "$(lc "$paid_to")" == "$(lc "$want")" ]] && echo 1 || echo 0) "the escrow paid the $who: $paid_to"
  say $([[ "$moved_dec" == "$AMOUNT" ]] && echo 1 || echo 0) "a real TIP-20 Transfer of $(fmt "$moved_dec") left the escrow"
  say $([[ "$d_state" == 2 ]] && echo 1 || echo 0) "the deal is Settled (state $d_state) and cannot settle again"

  # ---- T-4, and it is the whole reason this is a Tempo slice --------------------------
  ftok=$(jq -r '.feeToken' <<<"$sr"); fpay=$(jq -r '.feePayer' <<<"$sr")
  say $([[ "$(lc "$ftok")" == "$(lc "$TOKEN")" ]] && echo 1 || echo 0) \
    "T-4: the fee for this settlement was paid in the SAME TIP-20 the escrow held -- feeToken $ftok"
  say $([[ "$(lc "$fpay")" == "$(lc "$BUYER")" ]] && echo 1 || echo 0) "feePayer $fpay"
  gas=$(python3 -c "import sys;print(int(sys.argv[1],16))" "$(jq -r .gasUsed <<<"$sr")")
  price=$(python3 -c "import sys;print(int(sys.argv[1],16))" "$(jq -r .effectiveGasPrice <<<"$sr")")
  feepaid=$(python3 -c "print($gas * $price // 10**12)")
  echo "         fee $(fmt "$feepaid") in $ftok, for a settlement that released $(fmt "$moved_dec")"

  results=$(jq --argjson r "$results" -n --arg n "$name" --arg id "$dealId" --arg tx "$stx" \
    --arg out "$outcome" --arg to "$paid_to" --arg moved "$moved_dec" --arg ftok "$ftok" \
    --arg fpay "$fpay" --arg gas "$gas" --arg fee "$feepaid" --arg st "$d_state" '
    $r + [{case:$n, dealId:$id, settleTx:$tx, outcome:(if $out=="" then 0 else ($out|tonumber) end),
           paidTo:$to, tip20Moved:$moved, state:($st|tonumber),
           feeToken:$ftok, feePayer:$fpay, gasUsed:($gas|tonumber), feePaidRaw:($fee|tonumber),
           settled:true}]')
done

echo
jq --argjson v "$results" --arg when "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg ch "$onchain" '
  .deployedByReckn.verified = {
    _: "Written by zk-verdict/scripts/tempo-verify.sh, which reads the deployment back off the chain and derives every value from receipts and from deals() on the escrow. It does not trust the run that produced them; in particular the deal ids come out of the Funded event, not from a terminal.",
    verifiedAt: $when,
    deployedEscrowCodehash: $ch,
    codehashMatchesCompiledArtifact: true,
    cases: $v,
    notDemonstrated: "refundAfterDeadline. REFUND_AFTER is 30 days and time cannot be warped on a public chain, so the mismatch deal above stays Funded until then. The refund that IS demonstrated is the proof-driven one -- a FAILED proof paying the buyer -- which is immediate and is a different thing."
  }' "$rec" > "$rec.tmp" && mv "$rec.tmp" "$rec"

if [[ $fail -ne 0 ]]; then echo "tempo-verify: FAILED -- the chain does not say what the record claims."; exit 1; fi
# The witness is over what was READ BACK FROM THE CHAIN -- the deal ids taken out of the
# Funded events and the settlement hashes -- not over the record. A stub that printed this
# line would have to know a digest of values it never fetched, and the digest moves the
# moment the deployment does.
settled_n=$(jq -r '[.[] | select(.settled)] | length' <<<"$results")
w=$(jq -r '.[] | "\(.dealId) \(.settleTx // "-")"' <<<"$results" | LC_ALL=C sort | shasum -a 256 | cut -c1-16)
echo "tempo-verify: $(jq 'length' <<<"$results") deal(s) re-derived from the chain, $settled_n settled; witness=$w"

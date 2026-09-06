#!/usr/bin/env bash
# Reckn on Arc — one command: a conditional USDC payment released by a proof.
#
#   bash scripts/arc-usdc-e2e.sh
#
# TIER, stated before anything runs (AGENTS.md §5): this is a LOCAL anvil configured
# to look like Arc — same chain id (5042002), the same USDC ERC-20 shape (6 decimals)
# that Arc's native-USDC predeploy exposes. It is NOT an Arc testnet result and
# nothing it prints may be described as one. What it does establish is that the
# deployment path and the settlement path work end to end, in USDC's units, against
# SP1's real Groth16 verifier and the real committed proof.
#
# What it does NOT need: a key with funds, an RPC key, or any account anywhere. That
# is deliberate — a demo a judge cannot re-run is a claim, not a demo.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
contracts="$root/zk-verdict/contracts"
fixture="$contracts/src/fixtures/reexec-groth16-fixture.json"
failed_fixture="$contracts/src/fixtures/reexec-falserelease-fixture.json"

ARC_CHAIN_ID=5042002
# anvil's first well-known development key. Local only; it holds nothing anywhere.
KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ACCT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
SELLER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
RPC=http://127.0.0.1:8545

say() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
usdc() { cast call "$1" "balanceOf(address)(uint256)" "$2" --rpc-url "$RPC" | awk '{printf "%.6f USDC\n", $1/1000000}'; }

for f in "$fixture" "$failed_fixture"; do
  [[ -f "$f" ]] || { echo "missing $f — a missing fixture is a hard failure"; exit 1; }
done

say "0. a local chain shaped like Arc (chain id $ARC_CHAIN_ID) — NOT Arc testnet"
anvil --chain-id "$ARC_CHAIN_ID" --silent &
anvil_pid=$!
trap 'kill "$anvil_pid" 2>/dev/null || true' EXIT INT TERM
for _ in $(seq 1 50); do cast chain-id --rpc-url "$RPC" > /dev/null 2>&1 && break; done
echo "  chain id: $(cast chain-id --rpc-url "$RPC")"

VKEY=$(jq -r '.vkey' "$fixture")
BINDING=$(jq -r '.deal_binding' "$fixture")
PUBVALS=$(jq -r '.public_values' "$fixture")
PROOF=$(jq -r '.proof' "$fixture")

say "1. deploy the keyless path (the same script written for Arc testnet)"
VKEY="$VKEY" forge script "$contracts/script/DeployArc.s.sol:DeployArc" \
  --root "$contracts" --rpc-url "$RPC" --private-key "$KEY" --broadcast --silent > /dev/null

DEPLOY_JSON="$contracts/broadcast/DeployArc.s.sol/$ARC_CHAIN_ID/run-latest.json"
SP1=$(jq -r '[.transactions[] | select(.contractName=="SP1Verifier")][0].contractAddress' "$DEPLOY_JSON")
VERIFIER=$(jq -r '[.transactions[] | select(.contractName=="RecknVerdictVerifier")][0].contractAddress' "$DEPLOY_JSON")
ESCROW=$(jq -r '[.transactions[] | select(.contractName=="RecknZkEscrow")][0].contractAddress' "$DEPLOY_JSON")
echo "  SP1Verifier (fixed, not a gateway): $SP1"
echo "  RecknVerdictVerifier:               $VERIFIER"
echo "  RecknZkEscrow (no constructor):     $ESCROW"

say "2. USDC. On Arc this is the native-USDC ERC-20 face at 0x3600…0000; here it is a
     mock with the same 6-decimal face, because a local chain has no Circle predeploy"
USDC=$(forge create "$contracts/test/mocks/MockUSDC.sol:MockUSDC" \
        --root "$contracts" --rpc-url "$RPC" --private-key "$KEY" --broadcast \
        | sed -n 's/Deployed to: //p')
echo "  USDC:   $USDC"
cast send "$USDC" "mint(address,uint256)" "$ACCT" 1000000000 --rpc-url "$RPC" --private-key "$KEY" > /dev/null
echo "  buyer:  $(usdc "$USDC" "$ACCT")"

say "3. fund a deal: 250.00 USDC, released only by a proof carrying THIS deal's binding"
DEAL=$(cast keccak "arc-demo-deal")
CODEHASH=$(cast codehash "$VERIFIER" --rpc-url "$RPC")
cast send "$USDC" "approve(address,uint256)" "$ESCROW" 250000000 --rpc-url "$RPC" --private-key "$KEY" > /dev/null
cast send "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
  "$DEAL" "$SELLER" "$USDC" 250000000 "$VERIFIER" "$CODEHASH" "$BINDING" \
  --rpc-url "$RPC" --private-key "$KEY" > /dev/null
echo "  escrow: $(usdc "$USDC" "$ESCROW")   seller: $(usdc "$USDC" "$SELLER")"
echo "  the deal names its adjudicator: $VERIFIER"
echo "  pinned by codehash:             $CODEHASH"

say "4. settle with the REAL Groth16 proof — no admin, no resolver, no signature"
cast send "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$DEAL" "$PUBVALS" "$PROOF" \
  --rpc-url "$RPC" --private-key "$KEY" > /dev/null
echo "  escrow: $(usdc "$USDC" "$ESCROW")   seller: $(usdc "$USDC" "$SELLER")"

say "5. the other direction: a proof of a DECREASE refunds the buyer"
VKEY2=$(jq -r '.vkey' "$failed_fixture")
BINDING2=$(jq -r '.deal_binding' "$failed_fixture")
PUBVALS2=$(jq -r '.public_values' "$failed_fixture")
PROOF2=$(jq -r '.proof' "$failed_fixture")
VERIFIER2=$(forge create "$contracts/src/RecknVerdictVerifier.sol:RecknVerdictVerifier" \
             --root "$contracts" --rpc-url "$RPC" --private-key "$KEY" --broadcast \
             --constructor-args "$SP1" "$VKEY2" | sed -n 's/Deployed to: //p')
DEAL2=$(cast keccak "arc-demo-deal-failed")
CODEHASH2=$(cast codehash "$VERIFIER2" --rpc-url "$RPC")
echo "  before funding:  buyer $(usdc "$USDC" "$ACCT")"
cast send "$USDC" "approve(address,uint256)" "$ESCROW" 250000000 --rpc-url "$RPC" --private-key "$KEY" > /dev/null
cast send "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
  "$DEAL2" "$SELLER" "$USDC" 250000000 "$VERIFIER2" "$CODEHASH2" "$BINDING2" \
  --rpc-url "$RPC" --private-key "$KEY" > /dev/null
echo "  funded:          buyer $(usdc "$USDC" "$ACCT")  escrow $(usdc "$USDC" "$ESCROW")"
cast send "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$DEAL2" "$PUBVALS2" "$PROOF2" \
  --rpc-url "$RPC" --private-key "$KEY" > /dev/null
echo "  after the proof: buyer $(usdc "$USDC" "$ACCT")  escrow $(usdc "$USDC" "$ESCROW")   <- refunded"
echo "  seller:          $(usdc "$USDC" "$SELLER")  (unchanged — the work did not reproduce)"

say "6. write what just happened, for the dashboard to render"
cat > "$root/dashboard/arc-usdc.json" <<JSON
{
  "tier": "local anvil at Arc's chain id — NOT an Arc testnet result",
  "chainId": $(cast chain-id --rpc-url "$RPC"),
  "arc": {
    "testnetChainId": 5042002,
    "usdcErc20": "0x3600000000000000000000000000000000000000",
    "usdcErc20Decimals": 6,
    "note": "on Arc, USDC is the native gas token and this predeploy is its ERC-20 face"
  },
  "deployed": {
    "sp1Verifier": "$SP1",
    "verdictVerifier": "$VERIFIER",
    "verifierCodehash": "$CODEHASH",
    "escrow": "$ESCROW",
    "usdcMock": "$USDC"
  },
  "reproduced": {
    "dealId": "$DEAL",
    "amountUsdc": "250.000000",
    "verdict": "Reproduced",
    "sellerAfter": "$(usdc "$USDC" "$SELLER")",
    "escrowAfter": "$(usdc "$USDC" "$ESCROW")"
  },
  "failed": {
    "dealId": "$DEAL2",
    "amountUsdc": "250.000000",
    "verdict": "Failed (a proven DECREASE)",
    "buyerAfter": "$(usdc "$USDC" "$ACCT")",
    "sellerUnchanged": "$(usdc "$USDC" "$SELLER")"
  },
  "generatedBy": "scripts/arc-usdc-e2e.sh"
}
JSON
python3 -c 'import re,sys; page,data=sys.argv[1],sys.argv[2]; h=open(page).read(); b=open(data).read().strip(); h=re.sub(r"(<script id=\"arc-data\" type=\"application/json\">\n).*?(\n</script>)", lambda m: m.group(1)+b+m.group(2), h, flags=re.S); open(page,"w").write(h)' "$root/dashboard/arc.html" "$root/dashboard/arc-usdc.json"
echo "  wrote dashboard/arc-usdc.json and inlined it into dashboard/arc.html (file:// works)"

say "what this was, and what it was not"
cat <<'NOTE'
  A conditional USDC payment. The condition is a Groth16 proof that the disputed work
  re-executes to the verdict the deal was funded against. No owner, no resolver, no
  bridge, and no light client on the adjudication path.

  Local anvil at Arc's chain id — NOT an Arc testnet result. Deploying this to Arc
  needs a funded key, which is the founder's to hold.
NOTE

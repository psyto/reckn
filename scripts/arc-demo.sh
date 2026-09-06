#!/usr/bin/env bash
# Reckn on Arc — the demo a judge can operate.
#
#   bash scripts/arc-demo.sh        then open http://127.0.0.1:8787
#
# It starts a local chain at Arc's chain id, deploys the keyless path, mints USDC,
# and serves a page whose buttons perform REAL transactions against it. Nothing on
# that page is simulated: every number it shows was read back from the chain.
#
# TIER (AGENTS.md §5): a local anvil at chain id 5042002 is not Arc testnet, and the
# page says so before it says anything else. Deploying to Arc needs a funded key.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
contracts="$root/zk-verdict/contracts"
fx="$contracts/src/fixtures"

ARC_CHAIN_ID=5042002
KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
BUYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
SELLER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
RPC=http://127.0.0.1:8545
PORT=${PORT:-8787}

for f in reexec-groth16-fixture.json reexec-falserelease-fixture.json svm-groth16-fixture.json; do
  [[ -f "$fx/$f" ]] || { echo "missing $fx/$f — a missing fixture is a hard failure"; exit 1; }
done

cleanup() { [[ -n "${anvil_pid:-}" ]] && kill "$anvil_pid" 2>/dev/null || true
            [[ -n "${srv_pid:-}" ]] && kill "$srv_pid" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

echo "▶ local chain at Arc's chain id ($ARC_CHAIN_ID) — not Arc testnet"
anvil --chain-id "$ARC_CHAIN_ID" --silent &
anvil_pid=$!
for _ in $(seq 1 60); do cast chain-id --rpc-url "$RPC" > /dev/null 2>&1 && break; done

echo "▶ deploy: SP1 Groth16 verifier (fixed, not a gateway) → verdict verifier → escrow"
VKEY_EVM=$(jq -r .vkey "$fx/reexec-groth16-fixture.json")
VKEY_SVM=$(jq -r .vkey "$fx/svm-groth16-fixture.json")
VKEY="$VKEY_EVM" forge script "$contracts/script/DeployArc.s.sol:DeployArc" \
  --root "$contracts" --rpc-url "$RPC" --private-key "$KEY" --broadcast --silent > /dev/null
DJ="$contracts/broadcast/DeployArc.s.sol/$ARC_CHAIN_ID/run-latest.json"
SP1=$(jq -r '[.transactions[]|select(.contractName=="SP1Verifier")][0].contractAddress' "$DJ")
VERIFIER_EVM=$(jq -r '[.transactions[]|select(.contractName=="RecknVerdictVerifier")][0].contractAddress' "$DJ")
ESCROW=$(jq -r '[.transactions[]|select(.contractName=="RecknZkEscrow")][0].contractAddress' "$DJ")
VERIFIER_SVM=$(forge create "$contracts/src/RecknVerdictVerifier.sol:RecknVerdictVerifier" \
  --root "$contracts" --rpc-url "$RPC" --private-key "$KEY" --broadcast \
  --constructor-args "$SP1" "$VKEY_SVM" | sed -n 's/Deployed to: //p')

echo "▶ USDC (here a mock with Arc's 6-decimal ERC-20 face) and 1,000.00 to the buyer"
USDC=$(forge create "$contracts/test/mocks/MockUSDC.sol:MockUSDC" \
  --root "$contracts" --rpc-url "$RPC" --private-key "$KEY" --broadcast | sed -n 's/Deployed to: //p')
cast send "$USDC" "mint(address,uint256)" "$BUYER" 1000000000 --rpc-url "$RPC" --private-key "$KEY" > /dev/null

deal() { cast keccak "$1"; }
codehash() { cast codehash "$1" --rpc-url "$RPC"; }
pv() { jq -r .public_values "$fx/$1"; }
pf() { jq -r .proof "$fx/$1"; }
bind() { jq -r .deal_binding "$fx/$1"; }

cat > "$root/dashboard/arc-demo-state.json" <<JSON
{
  "buyer": "$BUYER", "seller": "$SELLER",
  "usdc": "$USDC", "escrow": "$ESCROW",
  "verifierEvm": "$VERIFIER_EVM", "verifierSvm": "$VERIFIER_SVM", "sp1": "$SP1",
  "proofs": {
    "reproduced": { "publicValues": "$(pv reexec-groth16-fixture.json)", "proof": "$(pf reexec-groth16-fixture.json)" },
    "decrease":   { "publicValues": "$(pv reexec-falserelease-fixture.json)", "proof": "$(pf reexec-falserelease-fixture.json)" },
    "solana":     { "publicValues": "$(pv svm-groth16-fixture.json)", "proof": "$(pf svm-groth16-fixture.json)" }
  },
  "deals": {
    "honest":    { "id": "$(deal honest)",    "amount": 250000000, "verifier": "$VERIFIER_EVM", "codehash": "$(codehash "$VERIFIER_EVM")", "binding": "$(bind reexec-groth16-fixture.json)",       "proof": "reproduced" },
    "decrease":  { "id": "$(deal decrease)",  "amount": 250000000, "verifier": "$VERIFIER_EVM", "codehash": "$(codehash "$VERIFIER_EVM")", "binding": "$(bind reexec-falserelease-fixture.json)",  "proof": "decrease" },
    "solana":    { "id": "$(deal solana)",    "amount": 250000000, "verifier": "$VERIFIER_SVM", "codehash": "$(codehash "$VERIFIER_SVM")", "binding": "$(bind svm-groth16-fixture.json)",          "proof": "solana" },
    "abandoned": { "id": "$(deal abandoned)", "amount": 250000000, "verifier": "$VERIFIER_EVM", "codehash": "$(codehash "$VERIFIER_EVM")", "binding": "$(bind reexec-groth16-fixture.json)",       "proof": "reproduced" }
  }
}
JSON

echo "▶ serving on http://127.0.0.1:$PORT   (ctrl-c stops the chain and the server)"
python3 "$root/dashboard/arc-demo.py" "$PORT" &
srv_pid=$!
sleep 1 2>/dev/null || true
curl -sf "http://127.0.0.1:$PORT/api/state" > /dev/null && echo "  backend is answering: /api/state" || echo "  WARNING: backend did not answer"
echo
echo "  Open http://127.0.0.1:$PORT and drive it. Every button is a real transaction."
wait "$srv_pid"

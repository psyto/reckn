#!/usr/bin/env bash
# Bring up a throwaway local chain with the keyless path on it, and write the addresses
# where the TypeScript can find them.
#
# TIER, before anything runs: this is a LOCAL anvil at Arc's chain id. **It is not an Arc
# testnet result.** It shows that the deploy path and the settlement path work end to end;
# it says nothing about any public chain. The Arc testnet procedure is in README.md and uses
# YOUR wallet, not this one.
#
# The key below is anvil's first well-known development key. It is in every Foundry install,
# it holds nothing anywhere, and it exists in this file so that nobody is ever tempted to put
# a real one here. **No command in this starter takes a private key you own.**
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
contracts="$root/zk-verdict/contracts"
fixture="$contracts/src/fixtures/reexec-groth16-fixture.json"

for t in anvil forge cast jq; do command -v $t >/dev/null || { echo "need $t (https://getfoundry.sh)"; exit 2; }; done
[[ -f "$fixture" ]] || { echo "missing $fixture"; exit 1; }

CHAIN_ID=5042002
RPC=http://127.0.0.1:8545
DEV_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEV_ACCT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

pkill -f "anvil --chain-id $CHAIN_ID" 2>/dev/null || true
anvil --chain-id "$CHAIN_ID" --silent &
echo $! > "$here/.anvil.pid"
for _ in $(seq 1 40); do cast chain-id --rpc-url "$RPC" >/dev/null 2>&1 && break; sleep 0.25; done

VKEY=$(jq -r .vkey "$fixture")
cd "$contracts"
VKEY="$VKEY" forge script script/DeployArc.s.sol:DeployArc --rpc-url "$RPC" \
  --private-key "$DEV_KEY" --broadcast >/dev/null 2>&1
B="broadcast/DeployArc.s.sol/$CHAIN_ID/run-latest.json"
addr(){ jq -r --arg n "$1" '[.transactions[] | select(.contractName==$n)][0].contractAddress' "$B"; }
ESCROW=$(addr RecknZkEscrow); VERIFIER=$(addr RecknVerdictVerifier)

# A local chain has no Circle predeploy, so the sample uses the repository's 6-decimal mock.
# On Arc testnet you use the real USDC face and this line disappears.
TOKEN=$(forge create "test/mocks/MockUSDC.sol:MockUSDC" --rpc-url "$RPC" --private-key "$DEV_KEY" \
        --broadcast --json 2>/dev/null | jq -r .deployedTo)
cast send "$TOKEN" "mint(address,uint256)" "$DEV_ACCT" 1000000000 --rpc-url "$RPC" --private-key "$DEV_KEY" >/dev/null

CODEHASH=$(cast keccak "$(cast code --rpc-url "$RPC" "$VERIFIER")")
jq -n --arg rpc "$RPC" --argjson chainId "$CHAIN_ID" --arg escrow "$ESCROW" --arg verifier "$VERIFIER" \
      --arg codehash "$CODEHASH" --arg token "$TOKEN" --arg acct "$DEV_ACCT" --arg key "$DEV_KEY" '{
  _: "Written by setup-chain.sh. A throwaway local chain. The key here is anvil dev key #0, public in every Foundry install; it is NOT a key anyone owns.",
  rpc:$rpc, chainId:$chainId, escrow:$escrow, verifier:$verifier, verifierCodeHash:$codehash,
  token:$token, account:$acct, devKey:$key
}' > "$here/.local-chain.json"

echo "local chain up: escrow $ESCROW  verifier $VERIFIER  token $TOKEN"

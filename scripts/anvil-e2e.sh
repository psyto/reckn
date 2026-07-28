#!/usr/bin/env bash
# Reckn V1.1 money-shot: a seller commits a plan that does not satisfy the
# funded predicate; proof-verified re-execution returns Failed and refunds the
# buyer.  No BLOCKHASH opcode is used.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
rpc_url=${RECKN_RPC_URL:-http://127.0.0.1:8545}
store=$(mktemp -d "${TMPDIR:-/tmp}/reckn-content.XXXXXX")
anvil_pid=""

cleanup() {
  if [[ -n "$anvil_pid" ]]; then kill "$anvil_pid" 2>/dev/null || true; fi
  rm -rf "$store"
}
trap cleanup EXIT

# Anvil's explicit, deterministic development mnemonic. These are only demo
# identities; deriving rather than copying key literals keeps the three roles
# aligned with the node's actual accounts.
mnemonic='test test test test test test test test test test test junk'
buyer_pk=$(cast wallet private-key "$mnemonic" 0)
seller_pk=$(cast wallet private-key "$mnemonic" 1)
resolver_pk=$(cast wallet private-key "$mnemonic" 2)
buyer=$(cast wallet address --private-key "$buyer_pk")
seller=$(cast wallet address --private-key "$seller_pk")
resolver=$(cast wallet address --private-key "$resolver_pk")

anvil --port 8545 --mnemonic "$mnemonic" --silent >"$store/anvil.log" 2>&1 &
anvil_pid=$!
for _ in $(seq 1 30); do
  cast chain-id --rpc-url "$rpc_url" >/dev/null 2>&1 && break
  sleep 0.1
done
cast chain-id --rpc-url "$rpc_url" >/dev/null

pushd "$root/contracts" >/dev/null
# forge-std is git-ignored; install it on first run so this is truly one command.
[[ -d lib/forge-std ]] || forge install foundry-rs/forge-std --no-git >/dev/null 2>&1
forge build --quiet
deploy() {
  forge create --broadcast --rpc-url "$rpc_url" --private-key "$buyer_pk" "$@" \
    | awk '/Deployed to:/ {print $3}'
}
registry=$(deploy src/ResolverRegistry.sol:ResolverRegistry --constructor-args "$buyer")
escrow=$(deploy src/RecknEscrow.sol:RecknEscrow --constructor-args "$registry")
token=$(deploy test/mocks/MockUSDC3009.sol:MockUSDC3009)
popd >/dev/null

backend_id=$(cast keccak 'reckn/backend/evm')
backend_ver=$(cast keccak 'reckn/backend/evm@v1')
cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" "$registry" \
  'setResolver(address,bool)' "$resolver" true >/dev/null
cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" "$registry" \
  'setBackend(bytes32,bytes32,bool)' "$backend_id" "$backend_ver" true >/dev/null
cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" "$token" \
  'mint(address,uint256)' "$buyer" 1000000 >/dev/null

# This is the committed prestate. Later escrow transactions do not affect the
# replayed historic state. `blockHash` is committed for V1.1; the plan below
# never executes BLOCKHASH, whose connected-header verification is deferred.
block=$(cast block latest --rpc-url "$rpc_url" --json)
block_number=$(cast to-dec "$(jq -r .number <<<"$block")")
anchor=$(jq -cn \
  --argjson chainId "$(cast chain-id --rpc-url "$rpc_url")" \
  --argjson blockNumber "$block_number" \
  --arg blockHash "$(jq -r .hash <<<"$block")" \
  --arg stateRoot "$(jq -r .stateRoot <<<"$block")" \
  --argjson timestamp "$(cast to-dec "$(jq -r .timestamp <<<"$block")")" \
  --argjson baseFee "$(cast to-dec "$(jq -r .baseFeePerGas <<<"$block")")" \
  --argjson blockGasLimit "$(cast to-dec "$(jq -r .gasLimit <<<"$block")")" \
  --arg coinbase "$(jq -r .miner <<<"$block")" \
  --arg prevrandao "$(jq -r '.mixHash // .prevRandao' <<<"$block")" \
  '{chainId:$chainId,blockNumber:$blockNumber,blockHash:$blockHash,stateRoot:$stateRoot,timestamp:$timestamp,baseFee:$baseFee,blockGasLimit:$blockGasLimit,coinbase:$coinbase,prevrandao:$prevrandao,specId:"CANCUN"}')
anchor_hash=$(printf %s "$anchor" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$anchor" >"$store/${anchor_hash#0x}.json"

# Calling balanceOf is a genuine SLOAD plan, so the keeper must collect and
# prove the mapping slot. The buyer-funded predicate intentionally expects an
# impossible return hash; seller's implicit claim is therefore disproved.
calldata=$(cast calldata 'balanceOf(address)' "$buyer")
# Seller first publishes the proof-carrying witness for a staging plan.  The
# final delivery then commits its SHA-256, so once/verify never replay a live
# RPC witness.
delivery_draft=$(jq -cn --arg caller "$buyer" --arg target "$token" --arg calldata "$calldata" \
  '{caller:$caller,target:$target,calldata:$calldata,value:"0x0",gasLimit:200000}')
delivery_draft_hash=$(printf %s "$delivery_draft" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$delivery_draft" >"$store/${delivery_draft_hash#0x}.json"
witness_out=$(cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  witness "$rpc_url" "$store" "$anchor_hash" "$delivery_draft_hash" --write "$store")
witness_hash=$(awk -F= '/^witnessContentHash=/{print $2}' <<<"$witness_out")
[[ "$witness_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]
delivery=$(jq -cn --arg caller "$buyer" --arg target "$token" --arg calldata "$calldata" --arg witness "$witness_hash" \
  '{caller:$caller,target:$target,calldata:$calldata,value:"0x0",gasLimit:200000,witnessContentHash:$witness}')
delivery_hash=$(printf %s "$delivery" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$delivery" >"$store/${delivery_hash#0x}.json"
spec=$(jq -cn --arg anchor "$anchor_hash" --arg backendId "$backend_id" --arg backendVersionHash "$backend_ver" \
  '{backendId:$backendId,backendVersionHash:$backendVersionHash,prestateAnchorHash:$anchor,predicate:{kind:"RESULT_EQUALS",expectedResultHash:"0x0000000000000000000000000000000000000000000000000000000000000000"}}')
spec_hash=$(printf %s "$spec" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$spec" >"$store/${spec_hash#0x}.json"

salt=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
auth_nonce=0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
fund_tx=$(cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" --json "$escrow" \
  'fundWithAuthorization(bytes32,address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint64,uint256,uint256,bytes32,uint8,bytes32,bytes32)' \
  "$salt" "$seller" "$token" 1000000 "$spec_hash" "$anchor_hash" "$backend_id" "$backend_ver" \
  3600 0 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff "$auth_nonce" 0 \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000000000000000000000000000)
fund_receipt=$(cast receipt --rpc-url "$rpc_url" "$(jq -r .transactionHash <<<"$fund_tx")" --json)
funded_topic=$(cast keccak 'Funded(bytes32,address,address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint64)')
deal_id=$(jq -r --arg topic "$funded_topic" '.logs[] | select(.topics[0] == $topic) | .topics[1]' <<<"$fund_receipt")
[[ "$deal_id" != "null" && -n "$deal_id" ]]

cast send --rpc-url "$rpc_url" --private-key "$seller_pk" "$escrow" \
  'deliver(bytes32,bytes32,uint64)' "$deal_id" "$delivery_hash" 3600 >/dev/null
cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" "$escrow" \
  'challenge(bytes32,uint64)' "$deal_id" 3600 >/dev/null

cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  once "$rpc_url" "$escrow" "$store" "$resolver_pk"

buyer_balance=$(cast call --rpc-url "$rpc_url" "$token" 'balanceOf(address)(uint256)' "$buyer")
escrow_balance=$(cast call --rpc-url "$rpc_url" "$token" 'balanceOf(address)(uint256)' "$escrow")
[[ "$buyer_balance" == "1000000" && "$escrow_balance" == "0" ]]
echo "PASS: re-execution returned Failed and refunded buyer; deal=$deal_id"

# Independent, keyless re-verification: a third party reproduces the resolver's
# on-chain verdict from public inputs alone (content store + re-execution) — no
# resolver key. This is the trust property made executable: don't trust the
# resolver, reproduce its verdict yourself. A mismatch here fails the script.
cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  verify "$rpc_url" "$escrow" "$store" "$deal_id"
echo "PASS: independent re-verification reproduced the on-chain verdict."

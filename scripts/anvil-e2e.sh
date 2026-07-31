#!/usr/bin/env bash
# Reckn V1.1 money-shot, two acts over the same frozen state:
#   Act I  — exact-match predicate: a seller's plan does not satisfy it, so
#            proof-verified re-execution returns Failed and REFUNDS the buyer.
#   Act II — causal delta predicate (the flagship "swap at ≤X slippage"): the
#            buyer funds "the fill must CREDIT ≥ minOut" (post−pre of the balance
#            slot), which a no-op plan cannot fake; an honest crediting fill
#            clears the floor, reproduces, and is RELEASED to the seller.
# No BLOCKHASH opcode is used.
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

# Progress markers (no logic; they narrate the run for the reader and the demo).
say() { printf '\n\342\226\266 %s\n' "$*"; }

# Anvil's explicit, deterministic development mnemonic. These are only demo
# identities; deriving rather than copying key literals keeps the three roles
# aligned with the node's actual accounts.
mnemonic='test test test test test test test test test test test junk'
buyer_pk=$(cast wallet private-key "$mnemonic" 0)
seller_pk=$(cast wallet private-key "$mnemonic" 1)
resolver_pk=$(cast wallet private-key "$mnemonic" 2)
# The facilitator only relays the buyer's signed x402/EIP-3009 authorization; it
# is not a deal party and never holds the funds.
facilitator_pk=$(cast wallet private-key "$mnemonic" 3)
buyer=$(cast wallet address --private-key "$buyer_pk")
seller=$(cast wallet address --private-key "$seller_pk")
resolver=$(cast wallet address --private-key "$resolver_pk")
facilitator=$(cast wallet address --private-key "$facilitator_pk")

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
say "Setting up: an escrow and a test USDC on a fresh local chain"
registry=$(deploy src/ResolverRegistry.sol:ResolverRegistry --constructor-args "$buyer")
escrow=$(deploy src/RecknEscrow.sol:RecknEscrow --constructor-args "$registry")
token=$(deploy test/mocks/MockUSDC3009.sol:MockUSDC3009)
popd >/dev/null
printf '  escrow   %s\n  registry %s\n  token    %s\n' "$escrow" "$registry" "$token"

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
say "Freezing the exact chain state the work will be judged against"
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
say "Seller attaches tamper-proof evidence of the state it ran against"
witness_out=$(cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  witness "$rpc_url" "$store" "$anchor_hash" "$delivery_draft_hash" --write "$store")
witness_hash=$(awk -F= '/^witnessContentHash=/{print $2}' <<<"$witness_out")
header_hash=$(awk -F= '/^headerContentHash=/{print $2}' <<<"$witness_out")
[[ "$witness_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]
[[ "$header_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]
printf '  witnessContentHash %s\n  headerContentHash  %s\n' "$witness_hash" "$header_hash"
# Commit the block header too: the keyless verdict path proves it binds
# state_root to the real block_hash before trusting the state root.
delivery=$(jq -cn --arg caller "$buyer" --arg target "$token" --arg calldata "$calldata" --arg witness "$witness_hash" --arg header "$header_hash" \
  '{caller:$caller,target:$target,calldata:$calldata,value:"0x0",gasLimit:200000,witnessContentHash:$witness,headerContentHash:$header}')
delivery_hash=$(printf %s "$delivery" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$delivery" >"$store/${delivery_hash#0x}.json"
spec=$(jq -cn --arg anchor "$anchor_hash" --arg backendId "$backend_id" --arg backendVersionHash "$backend_ver" \
  '{backendId:$backendId,backendVersionHash:$backendVersionHash,prestateAnchorHash:$anchor,predicate:{kind:"RESULT_EQUALS",expectedResultHash:"0x0000000000000000000000000000000000000000000000000000000000000000"}}')
spec_hash=$(printf %s "$spec" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$spec" >"$store/${spec_hash#0x}.json"

salt=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
deliver_window=3600
valid_after=0
valid_before=0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
# One buyer signature both pays and opens the escrow. The EIP-3009 authorization
# nonce is bound to the exact deal (dealId + deliver window), so the facilitator
# that relays it cannot redirect the payment or change any funded term — a
# tampered term reverts either on the escrow's nonce check or the token's
# signature check.
deal_id=$(cast call --rpc-url "$rpc_url" "$escrow" \
  'computeDealId(bytes32,address,address,address,uint256,bytes32,bytes32,bytes32,bytes32)(bytes32)' \
  "$salt" "$buyer" "$seller" "$token" 1000000 "$spec_hash" "$anchor_hash" "$backend_id" "$backend_ver")
auth_nonce=$(cast call --rpc-url "$rpc_url" "$escrow" \
  'fundingNonce(bytes32,uint64)(bytes32)' "$deal_id" "$deliver_window")

# Build and sign the EIP-712 ReceiveWithAuthorization digest the way the token
# (and real USDC) verifies it. `to` is the escrow, the payee that pulls funds.
domain_sep=$(cast call --rpc-url "$rpc_url" "$token" 'DOMAIN_SEPARATOR()(bytes32)')
auth_typehash=$(cast call --rpc-url "$rpc_url" "$token" 'RECEIVE_WITH_AUTHORIZATION_TYPEHASH()(bytes32)')
auth_struct=$(cast keccak "$(cast abi-encode \
  'f(bytes32,address,address,uint256,uint256,uint256,bytes32)' \
  "$auth_typehash" "$buyer" "$escrow" 1000000 "$valid_after" "$valid_before" "$auth_nonce")")
auth_digest=$(cast keccak "$(cast concat-hex 0x1901 "$domain_sep" "$auth_struct")")
auth_sig=$(cast wallet sign --no-hash --private-key "$buyer_pk" "$auth_digest")
auth_r=0x${auth_sig:2:64}
auth_s=0x${auth_sig:66:64}
auth_v=$(cast to-dec "0x${auth_sig:130:2}")

say "Buyer signs one x402/EIP-3009 authorization; a facilitator relays it on-chain"
fund_tx=$(cast send --rpc-url "$rpc_url" --private-key "$facilitator_pk" --json "$escrow" \
  'fundWithAuthorization(bytes32,address,address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint64,uint256,uint256,bytes32,uint8,bytes32,bytes32)' \
  "$salt" "$buyer" "$seller" "$token" 1000000 "$spec_hash" "$anchor_hash" "$backend_id" "$backend_ver" \
  "$deliver_window" "$valid_after" "$valid_before" "$auth_nonce" "$auth_v" "$auth_r" "$auth_s")
fund_receipt=$(cast receipt --rpc-url "$rpc_url" "$(jq -r .transactionHash <<<"$fund_tx")" --json)
funded_topic=$(cast keccak 'Funded(bytes32,address,address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint64)')
funded_deal=$(jq -r --arg topic "$funded_topic" '.logs[] | select(.topics[0] == $topic) | .topics[1]' <<<"$fund_receipt")
# The event's dealId must match the one the buyer's nonce was bound to.
[[ "$funded_deal" != "null" && -n "$funded_deal" && "$funded_deal" == "$deal_id" ]]
say "Buyer pays 1,000 USDC into escrow for the promised result (relayed, not self-sent)"
printf '  deal        %s\n  facilitator %s (relayer, not a party)\n' "$deal_id" "$facilitator"

say "Seller delivers a wrong result but claims success; buyer disputes it"
cast send --rpc-url "$rpc_url" --private-key "$seller_pk" "$escrow" \
  'deliver(bytes32,bytes32,uint64)' "$deal_id" "$delivery_hash" 3600 >/dev/null
cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" "$escrow" \
  'challenge(bytes32,uint64)' "$deal_id" 3600 >/dev/null

say "Reckn replays the actual work and checks it against the promise"
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
say "Anyone can reproduce this verdict themselves — no trust in the keeper"
cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  verify "$rpc_url" "$escrow" "$store" "$deal_id"
echo "PASS: independent re-verification reproduced the on-chain verdict."

# ── Act II: the honest, released deal on a CAUSAL DELTA predicate ─────────────
# Act I proved refund with an exact match. The flagship claim ("executed this
# swap at ≤X slippage") is *causal*: the buyer wants proof the fill CREDITED at
# least minOut — not merely that some balance is ≥ minOut, which a no-op plan
# could satisfy straight off the prestate. POST_STATE_DELTA adjudicates
# `post − pre` of the output-balance slot, so only a plan that actually moves the
# balance can clear the floor. The crediting plan here is a real state-changing
# call (`mint` credits balanceOf[buyer]); the keeper proves the touched slot just
# as in Act I, and re-execution measures the increase the plan itself produced.
say "Act II: buyer funds a *causal* slippage floor — the fill must CREDIT ≥ minOut"
balance_slot=$(cast index address "$buyer" 0)          # balanceOf[buyer] @ slot 0
credit=500000                                           # the fill credits this much
min_out=$(cast to-hex 400000)                           # buyer's minOut (a strict floor)
u256_max=0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

# A real crediting plan and its proof-carrying witness (an SSTORE, unlike Act I's
# read-only balanceOf). Frozen balanceOf[buyer] is 1,000,000; the plan credits
# +500,000, so the adjudicated delta is 500,000 ≥ the 400,000 floor.
calldata_b=$(cast calldata 'mint(address,uint256)' "$buyer" "$credit")
delivery_draft_b=$(jq -cn --arg caller "$buyer" --arg target "$token" --arg calldata "$calldata_b" \
  '{caller:$caller,target:$target,calldata:$calldata,value:"0x0",gasLimit:200000}')
delivery_draft_b_hash=$(printf %s "$delivery_draft_b" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$delivery_draft_b" >"$store/${delivery_draft_b_hash#0x}.json"
say "Seller attaches tamper-proof evidence for the crediting plan"
witness_out_b=$(cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  witness "$rpc_url" "$store" "$anchor_hash" "$delivery_draft_b_hash" --write "$store")
witness_hash_b=$(awk -F= '/^witnessContentHash=/{print $2}' <<<"$witness_out_b")
header_hash_b=$(awk -F= '/^headerContentHash=/{print $2}' <<<"$witness_out_b")
[[ "$witness_hash_b" =~ ^0x[0-9a-fA-F]{64}$ ]]
[[ "$header_hash_b" =~ ^0x[0-9a-fA-F]{64}$ ]]
delivery_b=$(jq -cn --arg caller "$buyer" --arg target "$token" --arg calldata "$calldata_b" --arg witness "$witness_hash_b" --arg header "$header_hash_b" \
  '{caller:$caller,target:$target,calldata:$calldata,value:"0x0",gasLimit:200000,witnessContentHash:$witness,headerContentHash:$header}')
delivery_b_hash=$(printf %s "$delivery_b" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$delivery_b" >"$store/${delivery_b_hash#0x}.json"

spec_b=$(jq -cn --arg anchor "$anchor_hash" --arg backendId "$backend_id" --arg backendVersionHash "$backend_ver" \
  --arg token "$token" --arg slot "$balance_slot" --arg min "$min_out" --arg max "$u256_max" \
  '{backendId:$backendId,backendVersionHash:$backendVersionHash,prestateAnchorHash:$anchor,predicate:{kind:"POST_STATE_DELTA",checks:[{address:$token,slot:$slot,min:$min,max:$max}]}}')
spec_b_hash=$(printf %s "$spec_b" | shasum -a 256 | awk '{print "0x" $1}')
printf %s "$spec_b" >"$store/${spec_b_hash#0x}.json"

salt_b=0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
deal_b=$(cast call --rpc-url "$rpc_url" "$escrow" \
  'computeDealId(bytes32,address,address,address,uint256,bytes32,bytes32,bytes32,bytes32)(bytes32)' \
  "$salt_b" "$buyer" "$seller" "$token" 1000000 "$spec_b_hash" "$anchor_hash" "$backend_id" "$backend_ver")
auth_nonce_b=$(cast call --rpc-url "$rpc_url" "$escrow" \
  'fundingNonce(bytes32,uint64)(bytes32)' "$deal_b" "$deliver_window")
auth_struct_b=$(cast keccak "$(cast abi-encode \
  'f(bytes32,address,address,uint256,uint256,uint256,bytes32)' \
  "$auth_typehash" "$buyer" "$escrow" 1000000 "$valid_after" "$valid_before" "$auth_nonce_b")")
auth_digest_b=$(cast keccak "$(cast concat-hex 0x1901 "$domain_sep" "$auth_struct_b")")
auth_sig_b=$(cast wallet sign --no-hash --private-key "$buyer_pk" "$auth_digest_b")
auth_r_b=0x${auth_sig_b:2:64}
auth_s_b=0x${auth_sig_b:66:64}
auth_v_b=$(cast to-dec "0x${auth_sig_b:130:2}")

cast send --rpc-url "$rpc_url" --private-key "$facilitator_pk" "$escrow" \
  'fundWithAuthorization(bytes32,address,address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint64,uint256,uint256,bytes32,uint8,bytes32,bytes32)' \
  "$salt_b" "$buyer" "$seller" "$token" 1000000 "$spec_b_hash" "$anchor_hash" "$backend_id" "$backend_ver" \
  "$deliver_window" "$valid_after" "$valid_before" "$auth_nonce_b" "$auth_v_b" "$auth_r_b" "$auth_s_b" >/dev/null

say "Seller delivers the crediting fill; buyer disputes to force the check"
cast send --rpc-url "$rpc_url" --private-key "$seller_pk" "$escrow" \
  'deliver(bytes32,bytes32,uint64)' "$deal_b" "$delivery_b_hash" 3600 >/dev/null
cast send --rpc-url "$rpc_url" --private-key "$buyer_pk" "$escrow" \
  'challenge(bytes32,uint64)' "$deal_b" 3600 >/dev/null

say "Reckn replays the work: the plan CREDITED ≥ minOut, so the seller is paid"
cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  once "$rpc_url" "$escrow" "$store" "$resolver_pk"

seller_balance=$(cast call --rpc-url "$rpc_url" "$token" 'balanceOf(address)(uint256)' "$seller")
escrow_balance_b=$(cast call --rpc-url "$rpc_url" "$token" 'balanceOf(address)(uint256)' "$escrow")
[[ "$seller_balance" == "1000000" && "$escrow_balance_b" == "0" ]]
echo "PASS: delta predicate reproduced (credited ≥ minOut); seller released; deal=$deal_b"

say "Anyone can reproduce the released verdict too — same public inputs, no key"
cargo run --quiet --manifest-path "$root/keeper/Cargo.toml" -- \
  verify "$rpc_url" "$escrow" "$store" "$deal_b"
echo "PASS: independent re-verification reproduced the RELEASE verdict."

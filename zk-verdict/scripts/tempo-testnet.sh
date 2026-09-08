#!/usr/bin/env bash
# tempo-testnet — 011's testnet half, as ONE scripted run: deploy, fund, settle both
# directions, prove a mismatched proof moves nothing, and write every address and receipt
# into tempo.json FROM THE RECEIPTS.
#
# THIS IS THE ONLY SCRIPT HERE THAT SENDS A TRANSACTION. Everything else in this directory
# is eth_call. It therefore needs a key, and the way it takes one is the point:
#
#   * it never accepts a private key in an argument or an environment variable. It takes the
#     NAME of a Foundry keystore account (`TEMPO_ACCOUNT`), created once by the founder with
#     `cast wallet import <name> --interactive`. The key stays encrypted on disk; no
#     plaintext key exists in a shell history, a process list, a log or this repository.
#   * it prints addresses, hashes and balances. It never prints a key, a password, or the
#     contents of any environment variable it did not itself compute.
#
# WHY A SCRIPT AND NOT A SESSION OF `cast send`. On Arc the settlements were real and the
# RECORD of them was hand-transcribed, and two of four tx hashes went into arc.json wrong --
# right length, right prefix, dead link. `arc-receipts.sh` exists because of that. Here the
# record is written by the same run that produced it, from `eth_getTransactionReceipt`, so
# there is no step at which a human retypes a hash.
#
# WHAT IT DELIBERATELY DOES NOT DO:
#   * no mainnet. It refuses to run anywhere but chain 42431 (AGENTS.md §8).
#   * it does not demonstrate `refundAfterDeadline`. REFUND_AFTER is 30 days and time cannot
#     be warped on a public chain (011 §7.1). The refund it DOES demonstrate is the
#     proof-driven one -- a FAILED proof paying the buyer, which is immediate. Any sentence
#     that lets a reader merge the two is wrong.
#   * it does not touch `src/`. 011 is additive; if it ever needs to, that is a finding.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root/zk-verdict/contracts"
rec="$root/zk-verdict/contracts/tempo.json"
RPC=$(jq -r '.testnet.rpc' "$rec")
CHAIN=$(jq -r '.testnet.chainId' "$rec")
EXPLORER=$(jq -r '.testnet.explorer' "$rec")
TOKEN=${TIP20:-$(jq -r '.measured.defaultFeeToken.address' "$rec")}
DECIMALS=$(jq -r '.measured.defaultFeeToken.decimals' "$rec")
# 1.000000 per deal, as on Arc, so the two records are comparable at a glance.
AMOUNT=${AMOUNT:-1000000}
REPRO=src/fixtures/svm-groth16-fixture.json
FAILED=src/fixtures/svm-failed-fixture.json

for t in forge cast jq curl; do command -v $t >/dev/null || { echo "tempo-testnet: $t is required"; exit 2; }; done

# --preflight runs every check that does not require a signature, then stops. It exists so
# the checks can be run by somebody who does NOT hold the key -- the founder's one manual
# step should not be the first place a wrong chain id, a short balance or a mismatched pair
# of fixtures is discovered. It takes an ADDRESS (TEMPO_ADDRESS), not an account, precisely
# because it must work without a keystore password.
preflight=0
[[ "${1:-}" == "--preflight" ]] && preflight=1

if [[ $preflight -eq 1 ]]; then
  : "${TEMPO_ADDRESS:?tempo-testnet --preflight: set TEMPO_ADDRESS to the address you will deploy from.}"
  ACCT=()
else
  : "${TEMPO_ACCOUNT:?tempo-testnet: set TEMPO_ACCOUNT to the name of a Foundry keystore account.
  Create one, once, with:  cast wallet new ~/.foundry/keystores <name>
  Do NOT pass a private key to this script. It will not read one.
  To check everything WITHOUT a password first:  TEMPO_ADDRESS=0x... bash $0 --preflight}"
  ACCT=(--account "$TEMPO_ACCOUNT")
  if [[ -n "${TEMPO_PASSWORD_FILE:-}" ]]; then
    ACCT+=(--password-file "$TEMPO_PASSWORD_FILE")
  else
    # This run sends about eleven transactions, and `cast send --account` prompts for the
    # keystore password on EVERY one of them. Eleven prompts in the middle of a sequence that
    # is half-committed to the chain is not a safety feature; it is where somebody pastes the
    # password into the wrong window, or gives up and puts it in the command line where `ps`
    # can read it. So: asked ONCE, with echo off, and held in a 0600 file inside a private
    # directory that a trap removes on any exit, including a failure or a ^C.
    #
    # This is a deliberate trade, and it is the better half of it: the alternative that avoids
    # disk entirely is --password <value>, which puts the secret in the process list where
    # every other user on the machine can read it. Nothing is echoed, nothing reaches the
    # shell history, and nothing is written inside the repository.
    pwdir=$(mktemp -d "${TMPDIR:-/tmp}/tempo-testnet.XXXXXX")
    chmod 700 "$pwdir"
    trap 'rm -rf "$pwdir"' EXIT INT TERM
    printf 'keystore password for account "%s" (not echoed): ' "$TEMPO_ACCOUNT" >&2
    IFS= read -rs pw; echo >&2
    # The umask is scoped to a SUBSHELL. The first version set `umask 177` inline and never
    # restored it, so every directory created for the rest of the run came out `drw-------`
    # -- no execute bit, which makes a directory unusable -- and `forge script` died on
    # "failed to create dir .../broadcast/DeployTempo.s.sol/42431" before sending anything.
    # A umask is process-wide state; changing it for one line means changing it for one line.
    ( umask 177; printf '%s' "$pw" > "$pwdir/p" )
    unset pw
    ACCT+=(--password-file "$pwdir/p")
    # Fail here, not eleven transactions in, if the password is wrong.
    cast wallet address "${ACCT[@]}" >/dev/null 2>&1 || {
      echo "tempo-testnet: that password does not open keystore \"$TEMPO_ACCOUNT\". Nothing was sent."; exit 1; }
    # Prove the umask really was scoped. This is not paranoia about the line above: it is the
    # bug that actually happened, and it surfaced as a permissions error from `forge` three
    # steps later, which is a long way from its cause.
    probe="$pwdir/dirtest"
    mkdir -p "$probe" && [[ -x "$probe" ]] || {
      echo "tempo-testnet: the umask leaked -- new directories are being created unusable."
      echo "  forge would fail later with 'failed to create dir'. Nothing was sent."; exit 2; }
    rmdir "$probe"
  fi
fi

# ---- preflight ------------------------------------------------------------------------
# Every one of these is a way the run could have looked successful while being wrong.
onchain_chain=$(cast chain-id --rpc-url "$RPC")
if [[ "$onchain_chain" == "4217" ]]; then
  # Named separately from the generic mismatch below, because this one is not a typo, it is a
  # prohibited action: 4217 is TEMPO MAINNET, with production assets. AGENTS.md §8.
  echo "tempo-testnet: that endpoint is TEMPO MAINNET (chain 4217). REFUSING -- mainnet"
  echo "  deployment and real funds are forbidden (AGENTS.md §8). Use $RPC."; exit 1
fi
[[ "$onchain_chain" == "$CHAIN" ]] || {
  echo "tempo-testnet: $RPC answered chain $onchain_chain, not $CHAIN. REFUSING."; exit 1; }

if [[ $preflight -eq 1 ]]; then
  BUYER=$(cast to-check-sum-address "$TEMPO_ADDRESS")
else
  BUYER=$(cast wallet address "${ACCT[@]}")
fi
SELLER=${TEMPO_SELLER:-0x5e11e40000000000000000000000000000000000}
[[ "$(tr A-F a-f <<<"$SELLER")" != "$(tr A-F a-f <<<"$BUYER")" ]] || { echo "tempo-testnet: seller and buyer must differ, or no transfer is visible"; exit 1; }
[[ "$(tr A-F a-f <<<"$SELLER")" != "$(tr A-F a-f <<<"$TOKEN")" ]] || { echo "tempo-testnet: seller must not be the TIP-20 itself (InvalidRecipient)"; exit 1; }

bal() { cast call --rpc-url "$RPC" "$TOKEN" "balanceOf(address)(uint256)" "$1" | awk '{print $1}'; }
fmt() { python3 -c 'import sys; v,d=int(sys.argv[1]),int(sys.argv[2]); print(f"{v/10**d:.{d}f}")' "$1" "$DECIMALS"; }
# Prove the formatter works before any of its output is trusted. It silently printed nothing
# once, next to a comparison that kept working, and "holds  needs about" read as fine.
[[ "$(fmt 1000000)" == "1.000000" ]] || { echo "tempo-testnet: fmt() is broken -- refusing to print numbers nobody can check"; exit 2; }

# balanceOf, NOT eth_getBalance: on Tempo the native balance is a constant (011 §2.2.3), so a
# funding check that reads it passes with an empty account.
have=$(bal "$BUYER")
# Measured, not guessed: tempo-gas-schedule.sh shows Tempo prices a cold SSTORE at ~11.5x and
# a deployed byte at ~12.8x Ethereum's, while compute is 1.00x. tempo-evm-probe.sh measured
# the whole path at ~31M gas. 40M leaves room for the three deals and the approvals.
price=$(cast gas-price --rpc-url "$RPC")
# Fees are charged in the TIP-20 at gasUsed * effectiveGasPrice / 1e12 -- derived from two
# real receipts on 2026-09-08, not from documentation.
need_fee=$(python3 -c 'import sys; print(40_000_000 * int(sys.argv[1]) // 10**12)' "$price")
need=$((need_fee + AMOUNT * 3))
echo "tempo-testnet: chain $CHAIN via $RPC"
echo "  buyer   $BUYER"
echo "  seller  $SELLER"
echo "  token   $TOKEN ($DECIMALS decimals)"
echo "  holds   $(fmt "$have")   needs about $(fmt "$need")  (fees ~$(fmt "$need_fee") + 3 x $(fmt "$AMOUNT") escrowed)"
if (( have < need )); then
  echo
  echo "tempo-testnet: NOT ENOUGH. Fund this address and re-run:"
  echo
  echo "    cast rpc tempo_fundAddress $BUYER --rpc-url $RPC"
  echo
  echo "  That is the whole faucet -- an RPC method, no browser and no wallet connection, and"
  echo "  the caller does not have to be the address being funded. One call mints 1,000,000"
  echo "  of pathUSD, AlphaUSD, BetaUSD and ThetaUSD, which is about 20,000x what this run"
  echo "  needs. Tempo has no native gas token: the same TIP-20 pays the fee AND fills the escrow."
  exit 1
fi

if [[ $preflight -eq 1 ]]; then
  echo "  enough for the run"
fi
VKEY=$(jq -r .vkey "$REPRO")
[[ "$VKEY" == "$(jq -r .vkey "$FAILED")" ]] || {
  echo "tempo-testnet: the two fixtures carry DIFFERENT vkeys, so one verifier cannot judge both."
  echo "  On Arc a second verifier was deployed before this was checked. Check first."; exit 1; }

if [[ $preflight -eq 1 ]]; then
  echo
  echo "  simulating the deploy (no --broadcast, no key, nothing sent)"
  if VKEY="$VKEY" TIP20="$TOKEN" forge script script/DeployTempo.s.sol:DeployTempo \
       --rpc-url "$RPC" --sender "$BUYER" >/dev/null 2>"$root/.tempo-preflight.err"; then
    echo "    DeployTempo simulates cleanly against chain $CHAIN"
    rm -f "$root/.tempo-preflight.err"
  else
    echo "    DeployTempo FAILED to simulate. The real run would fail the same way:"
    sed 's/^/      /' "$root/.tempo-preflight.err" | tail -20
    rm -f "$root/.tempo-preflight.err"
    exit 1
  fi
  echo
  echo "tempo-testnet --preflight: every check that does not need a signature passed."
  echo "  chain id, buyer/seller/token distinctness, TIP-20 balance, that both fixtures carry"
  echo "  the same vkey so ONE verifier can judge both (on Arc a second verifier was deployed"
  echo "  before that was checked), and a full simulation of the deploy."
  echo "  Nothing was sent. Run without --preflight, with TEMPO_ACCOUNT set, to deploy."
  exit 0
fi

run="$root/zk-verdict/contracts/tempo-run.json"
jq -n --arg rpc "$RPC" --arg chain "$CHAIN" --arg buyer "$BUYER" --arg seller "$SELLER" \
      --arg token "$TOKEN" --arg vkey "$VKEY" --arg amount "$AMOUNT" '{
  _: "Raw output of zk-verdict/scripts/tempo-testnet.sh. Every hash here came from eth_getTransactionReceipt in the same run that sent it. Nothing in this file was typed by a human.",
  rpc:$rpc, chainId:($chain|tonumber), buyer:$buyer, seller:$seller, token:$token,
  vkey:$vkey, amountPerDeal:($amount|tonumber), steps:[]}' > "$run"

# Append one receipt, read back from the chain, to the run record.
note() { # $1 label, $2 txhash, $3 note
  # RAW RPC, not `cast receipt --json`: feeToken and feePayer are Tempo's own receipt
  # fields, and a client that models Ethereum's receipt shape may drop exactly the two
  # fields 011's T-4 is about. Waits for inclusion first.
  cast receipt --rpc-url "$RPC" "$2" >/dev/null
  local r; r=$(curl -s --max-time 60 -X POST -H 'content-type: application/json' \
      -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$2\"]}" \
      "$RPC" | jq '.result')
  [[ "$r" != "null" && -n "$r" ]] || { echo "tempo-testnet: no receipt for $2"; exit 1; }
  jq --arg stepName "$1" --arg note "$3" --argjson r "$r" '
    def h: if type=="string" then ltrimstr("0x") | reduce explode[] as $c (0; . * 16 + (if $c>=97 then $c-87 elif $c>=65 then $c-55 else $c-48 end)) else . end;
    .steps += [{
      step:$stepName, note:$note, tx:$r.transactionHash, block:($r.blockNumber|h),
      status:($r.status|h), gasUsed:($r.gasUsed|h),
      effectiveGasPrice:($r.effectiveGasPrice|h), type:$r.type,
      feeToken:$r.feeToken, feePayer:$r.feePayer,
      feePaidRaw: (((($r.gasUsed|h) * ($r.effectiveGasPrice|h)) / 1000000000000) | floor),
      contractAddress:$r.contractAddress,
      transferLogs: [$r.logs[] | select(.topics[0]=="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
                     | {token:.address, from:("0x"+(.topics[1]|.[26:])), to:("0x"+(.topics[2]|.[26:])), value:(.data|h)}]
    }]' "$run" > "$run.tmp" && mv "$run.tmp" "$run"
  printf '  %-28s %s  gas %s  fee %s in %s\n' "$1" "$2" \
    "$(jq -r '.steps[-1].gasUsed' "$run")" "$(fmt "$(jq -r '.steps[-1].feePaidRaw' "$run")")" \
    "$(jq -r '.steps[-1].feeToken' "$run")"
}

send() { # echoes the tx hash only
  cast send --rpc-url "$RPC" "${ACCT[@]}" --json "$@" | jq -r .transactionHash
}

# ---- 1. deploy ------------------------------------------------------------------------
echo; echo "1/5 deploying (DeployTempo.s.sol, unmodified -- the escrow source is identical to Arc's)"
VKEY="$VKEY" TIP20="$TOKEN" forge script script/DeployTempo.s.sol:DeployTempo \
  --rpc-url "$RPC" "${ACCT[@]}" --broadcast --slow >/dev/null
bc="broadcast/DeployTempo.s.sol/$CHAIN/run-latest.json"
[[ -f "$bc" ]] || { echo "tempo-testnet: no broadcast record at $bc -- the deploy did not land"; exit 1; }
addr_of() { jq -r --arg n "$1" '.transactions[] | select(.contractName==$n) | .contractAddress' "$bc" | tail -1; }
tx_of()   { jq -r --arg n "$1" '.transactions[] | select(.contractName==$n) | .hash' "$bc" | tail -1; }
SP1=$(addr_of SP1Verifier); VERIF=$(addr_of RecknVerdictVerifier); ESCROW=$(addr_of RecknZkEscrow)
[[ -n "$SP1" && -n "$VERIF" && -n "$ESCROW" ]] || { echo "tempo-testnet: could not read all three addresses from the broadcast record"; exit 1; }
for n in SP1Verifier RecknVerdictVerifier RecknZkEscrow; do note "deploy $n" "$(tx_of $n)" "from DeployTempo.s.sol"; done

# The codehash is what a seller reads before working, and what `fund` pins. Read it from the
# CHAIN, not from the local artifact: they agree only if the deploy really landed as built.
CODEHASH=$(cast keccak "$(cast code --rpc-url "$RPC" "$VERIF")")
LOCAL_CODEHASH=$(cast keccak "$(forge inspect RecknVerdictVerifier deployedBytecode)")
echo "  verifier codehash on-chain $CODEHASH"
[[ "$CODEHASH" == "$LOCAL_CODEHASH" ]] || echo "  note: on-chain codehash differs from the local artifact's (immutables are baked in; expected)"

# ---- 2..4. three deals ----------------------------------------------------------------
deal() { # $1 label, $2 fixture, $3 binding-override(optional)
  local label=$1 fx=$2 override=${3:-}
  local id binding pv pr
  id=$(cast keccak "tempo/011/$label/$(date -u +%Y%m%dT%H%M%SZ)")
  binding=${override:-$(jq -r .deal_binding "$fx")}
  pv=$(jq -r .public_values "$fx"); pr=$(jq -r .proof "$fx")
  echo; echo "  deal $label  id $id"
  note "approve ($label)" "$(send "$TOKEN" "approve(address,uint256)" "$ESCROW" "$AMOUNT")" "buyer approves the escrow to pull"
  note "fund ($label)" "$(send "$ESCROW" "fund(bytes32,address,address,uint256,address,bytes32,bytes32)" \
        "$id" "$SELLER" "$TOKEN" "$AMOUNT" "$VERIF" "$CODEHASH" "$binding")" "escrow holds the TIP-20"
  local before_s before_b; before_s=$(bal "$SELLER"); before_b=$(bal "$BUYER")
  if [[ -n "$override" ]]; then
    # The mismatch case. A REAL proof of a real execution meets a deal it does not prove.
    # It must revert, and the escrow must still hold the money. `cast send` fails, so this
    # is the one place the script expects a non-zero exit.
    local err
    if err=$(cast send --rpc-url "$RPC" "${ACCT[@]}" --json "$ESCROW" \
             "settleWithProof(bytes32,bytes,bytes)" "$id" "$pv" "$pr" 2>&1); then
      echo "  MISMATCH SETTLED. That is a central-claim failure, not a test failure."; exit 1
    fi
    local held reason
    held=$(cast call --rpc-url "$RPC" "$ESCROW" "deals(bytes32)(address,address,address,uint256,address,bytes32,bytes32,uint64,uint8)" "$id" 2>/dev/null | sed -n '9p')
    held=${held:-unreadable}
    reason=$(grep -oE 'BindingMismatch|0x[0-9a-fA-F]{8}' <<<"$err" | head -1 || true)
    jq --arg id "$id" --arg st "$held" --arg e "${reason:-unknown}" \
       '.steps += [{step:"settle (mismatch)", note:"a real proof of ANOTHER execution was rejected; no transaction exists because it never landed", dealId:$id, stateAfter:$st, revert:$e}]' \
       "$run" > "$run.tmp" && mv "$run.tmp" "$run"
    echo "  settle (mismatch)            rejected: ${reason:-unknown}; deal state $held (1 = Funded)"
  else
    note "settle ($label)" "$(send "$ESCROW" "settleWithProof(bytes32,bytes,bytes)" "$id" "$pv" "$pr")" \
         "settled on a real Groth16 proof of a Solana execution"
  fi
  jq --arg id "$id" --arg l "$label" --arg bs "$before_s" --arg bb "$before_b" \
     --arg as "$(bal "$SELLER")" --arg ab "$(bal "$BUYER")" --arg ae "$(bal "$ESCROW")" \
     '.steps += [{step:("balances after " + $l), dealId:$id,
        sellerBefore:$bs, sellerAfter:$as, buyerBefore:$bb, buyerAfter:$ab, escrowAfter:$ae}]' \
     "$run" > "$run.tmp" && mv "$run.tmp" "$run"
  echo "  seller $(fmt "$before_s") -> $(fmt "$(bal "$SELLER")")   escrow now $(fmt "$(bal "$ESCROW")")"
}

echo; echo "2/5 REPRODUCED: a Solana proof releases the TIP-20 to the seller"
deal reproduced "$REPRO"
echo; echo "3/5 FAILED: the same machinery refunds the buyer (NOT the 30-day timeout)"
deal failed "$FAILED"
echo; echo "4/5 MISMATCH: a real proof of another execution must move nothing"
# Flip one bit of the binding: the proof stays real, the deal stops being the one it proves.
MISBINDING=$(python3 -c "print('0x%064x' % (int('$(jq -r .deal_binding "$REPRO")', 16) ^ 1))")
deal mismatch "$REPRO" "$MISBINDING"

# ---- 5. fold into the record ----------------------------------------------------------
echo; echo "5/5 writing tempo.json -> deployedByReckn from the receipts"
jq --slurpfile r "$run" --arg sp1 "$SP1" --arg v "$VERIF" --arg e "$ESCROW" --arg ch "$CODEHASH" \
   --arg tok "$TOKEN" --arg exp "$EXPLORER" --arg when "$(date -u +%Y-%m-%d)" --arg chain "$CHAIN" '
  .deployedByReckn = {
    _: "Written by zk-verdict/scripts/tempo-testnet.sh from eth_getTransactionReceipt, in the same run that sent the transactions. Never transcribed. tempo-receipts.sh checks it in both directions.",
    network: ("Tempo Moderato testnet (chainId " + $chain + ")"),
    deployedAt: $when, explorer: $exp,
    SP1Verifier: $sp1, RecknVerdictVerifier: $v, RecknVerdictVerifierCodehash: $ch,
    RecknZkEscrow: $e, tip20Used: $tok,
    run: $r[0],
    notDemonstrated: "refundAfterDeadline. REFUND_AFTER is 30 days, time cannot be warped on a public chain, and the mismatch deal above is therefore FUNDED until then. The refund shown here is the proof-driven one (a FAILED proof paying the buyer), which is immediate and is a different thing."
  }' "$rec" > "$rec.tmp" && mv "$rec.tmp" "$rec"

echo
echo "tempo-testnet: done. Addresses and receipts are in tempo.json -> deployedByReckn."
echo "  Now run: bash zk-verdict/scripts/tempo-receipts.sh   (closes the record in both directions)"
echo "  A deal funded with a mismatched binding is still FUNDED and returns to the buyer"
echo "  30 days from today via refundAfterDeadline. That is recorded, not hidden."

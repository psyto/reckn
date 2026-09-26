#!/usr/bin/env bash
# renounce — throw the last key away. THIS CANNOT BE UNDONE.
#
# `reckn-agent` deployed the registry and the resolver and still holds root on both. Root
# overrides every per-key role the submission rests on, so until this runs the agent can write
# its own record and repoint its own name — measured, disclosed, and the one red row
# take-check.sh reports.
#
# It is last and not first because after it we cannot grant a role to a replacement adapter. If
# the adapter is wrong, it is wrong forever. So the preconditions below are checked HARD and this
# script refuses rather than asks.
#
# Two keystore prompts, then four read-only verifications.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}

REGISTRY=0x1Ad360D93ccD6230FB14D213134107BF89a428cf
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
ADAPTER=0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8
ESCROW=0x6d6a9deb67d785BC131a5d732617EABE751098C5
OLD_ADAPTER=0x6691283d8B77E1e22D08836c55E3f952c304Ccc1
HOOK=0x68116b8086283E51227c61FD791b6Da1A4230080
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
BUYER=0x4b55f9e4d87505F3347c7CAFcB8C7eb589970eE3
ALL=0x1111111111111111111111111111111111111111111111111111111111111111
DNS=0x056167656e74057265636b6e0365746800
LOG="$here/renounce-txs.txt"

say() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
die() { printf '\n\033[31mrenounce: %s\033[0m\n' "$*" >&2; exit 1; }
rd()  { cast call "$@" --rpc-url "$READ_RPC"; }

say "0. preconditions — this refuses rather than asks"

# The adapter must be the FIXED one and must already hold root, or the record surface dies with
# this transaction and cannot be revived.
[[ "$(rd "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$ADAPTER")" == "true" ]] \
  || die "the adapter $ADAPTER does not hold root. Renouncing now would strand the record surface forever."
[[ "$(rd "$ADAPTER" "nameDotted()(string)" | tr -d '"')" == "agent.reckn.eth" ]] \
  || die "the adapter at $ADAPTER is not the one serving agent.reckn.eth"
[[ "$(rd "$ADAPTER" "WRITE_WINDOW()(uint64)" | awk '{print $1}')" == "86400" ]] \
  || die "the adapter is not the FIXED build (no WRITE_WINDOW)"
[[ "$(rd "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$OLD_ADAPTER")" == "false" ]] \
  || die "the OLD adapter still holds root — revoke it first, or it survives as a second admin"

# The four checks above say the adapter is right. They do NOT say nobody ELSE holds root, and
# that is measurable rather than assumed: roleCount over the root resource is the SUM of every
# holder's bitmap, so "exactly two holders, each with everything" is one number.
ALL_DEC=$(python3 -c "print(int('$ALL',16))")
want_res=$(python3 -c "print(2*int('$ALL',16))")
got_res=$(rd "$RESOLVER" "roleCount(uint256)(uint256)" 0 | awk '{print $1}')
got_reg=$(rd "$REGISTRY" "roleCount(uint256)(uint256)" 0 | awk '{print $1}')
[[ "$got_res" == "$want_res" ]] \
  || die "the resolver has root holders this script does not know about (roleCount $got_res, expected $want_res = agent + adapter)"
[[ "$got_reg" == "$ALL_DEC" ]] \
  || die "the registry has root holders this script does not know about (roleCount $got_reg, expected $ALL_DEC = the agent alone)"

# And that the adapter is wired to the surfaces we are about to lock. nameDotted and
# WRITE_WINDOW are two constants; these two are the load-bearing wiring.
[[ "$(rd "$ADAPTER" "resolver()(address)")" == "$RESOLVER" ]] || die "the adapter points at a different resolver"
[[ "$(rd "$ADAPTER" "escrow()(address)")"   == "$ESCROW"   ]] || die "the adapter points at a different escrow"
echo "   the fixed adapter holds root, is wired to this resolver and escrow, and nobody else holds root"

# Nothing else may be mid-flight. A window left open would be granted against a resolver we can
# no longer administer.
[[ "$(rd "$HOOK" "isOpen()(bool)")" == "false" ]] \
  || echo "   note: the gate is currently OPEN — that is fine, but beat 5's first shot needs it shut"

# REGISTRY FIRST, and the order is the safety property, not a preference. If the run is
# interrupted between the two, the state it lands in must be one that LOOKS unfinished.
#   registry first  -> the agent can no longer repoint the name, but can still write records.
#                      Beat 2 is visibly false and every gate says so. Fail-obvious.
#   resolver first  -> the agent cannot write records, but CAN still repoint the name at a
#                      resolver it controls. Until 2026-09-26 take-check.sh printed "Record."
#                      in exactly that state -- measured by the review, on a fork.
step() { # label | contract
  local label=$1 addr=$2 out h st
  out=$(cast send "$addr" "revokeRootRoles(uint256,address)" "$ALL" "$AGENT" \
        --rpc-url "$SEPOLIA_RPC" --account reckn-agent)
  h=$(printf '%s' "$out" | awk '/^transactionHash/{print $2}')
  st=$(printf '%s' "$out" | awk '/^status/{print $2}')
  printf '   status %s\n   https://sepolia.etherscan.io/tx/%s\n' "$st" "$h"
  printf '%s %s\n' "$label" "$h" >> "$LOG"
  [[ "$st" == "1" ]] || die "$label did not succeed — stop and read the transaction before going on"
}

: > "$LOG"
say "1. give up root on the REGISTRY  [reckn-agent]   irreversible"
step renounceRegistry "$REGISTRY"

say "2. give up root on the RESOLVER  [reckn-agent]   irreversible"
step renounceResolver "$RESOLVER"

say "3. it is gone — read it back rather than believe it"
after_res=$(rd "$RESOLVER" "roleCount(uint256)(uint256)" 0 | awk '{print $1}')
after_reg=$(rd "$REGISTRY" "roleCount(uint256)(uint256)" 0 | awk '{print $1}')
[[ "$after_res" == "$ALL_DEC" ]] \
  && printf '   ✓ resolver: exactly one root holder left, and it is the adapter\n' \
  || die "resolver roleCount is $after_res, expected $ALL_DEC (the adapter alone)"
[[ "$after_reg" == "0" ]] \
  && printf '   ✓ registry: no root holder at all\n' \
  || die "registry roleCount is $after_reg, expected 0"
for pair in "resolver:$RESOLVER" "registry:$REGISTRY"; do
  n=${pair%%:*}; a=${pair#*:}
  v=$(rd "$a" "hasRootRoles(uint256,address)(bool)" "$ALL" "$AGENT")
  [[ "$v" == "false" ]] && printf '   ✓ %s: the agent no longer holds root\n' "$n" \
                        || die "$n STILL reports the agent as root"
done

say "4. the three writes that decide whether beat 2 is true"
KEY=$(rd "$HOOK" "recordKey()(string)" | tr -d '"')
for who in "the buyer:$BUYER" "a stranger:0x000000000000000000000000000000000000dEaD" "THE AGENT:$AGENT"; do
  n=${who%%:*}; a=${who#*:}
  r=$(cast call "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$KEY" "x" --from "$a" --rpc-url "$READ_RPC" 2>&1 | head -1)
  case "$r" in
    0x*) printf '   \033[31m✗ %s can still write\033[0m\n' "$n" ;;
    *)   printf '   ✓ %s: refused\n' "$n" ;;
  esac
done

say "5. the rig decides, not us"
if bash "$here/scripts/take-check.sh" >/dev/null 2>&1; then
  printf '   \033[32m✓ take-check is green. Beat 2 is recordable. Film it now.\033[0m\n'
else
  printf '   \033[31m✗ take-check is still red — run it and read the rows before recording.\033[0m\n'
  bash "$here/scripts/take-check.sh" 2>&1 | grep '✗' | sed 's/^/     /'
fi

#!/usr/bin/env bash
# take-check — refuse to record if the thing behind the demo has stopped being true.
#
# `DEMO.md` §5-1: *every number on screen is from the take being recorded; a rig that keeps
# rendering after the thing behind it broke is the failure mode to fear.* This is that rig. It
# asserts the load-bearing facts against the live chain, per beat, and exits non-zero if any one
# of them is missing. **A beat that cannot be verified is reported as NOT RECORDABLE**, never as
# fine, because the whole point is that silence is the failure mode.
#
# Read-only. No keys, no SEPOLIA_RPC -- it uses a public endpoint on purpose, so running it can
# never put the Alchemy key anywhere near a terminal that is being filmed (§5.7).
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(cd "$here/.." && pwd)
RPC=${TAKE_RPC:-https://ethereum-sepolia-rpc.publicnode.com}

REPUTATION=0x8004B663056A597Dffe9eCcC1965A193B7388713
UR=0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
REGISTRY=0x1Ad360D93ccD6230FB14D213134107BF89a428cf
ESCROW=0x6d6a9deb67d785BC131a5d732617EABE751098C5
HOOK=0x68116b8086283E51227c61FD791b6Da1A4230080
AGENT=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
SECOND=0xF81dFf68aE2581CfCb62D68D824403Ae9F4d68d4
DNS=0x056167656e74057265636b6e0365746800
JOINKEY="reckn:job:agent.reckn.eth:48a603c2442fe4f372a025f32a6c879e002bc44a860552d6adc0e086cc00dae9"

fail=0
declare -a broken
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; broken+=("$1"); }
# NOT named `head`. It was, and it shadowed the coreutil: `… | head -1` inside the ENS check
# called this function instead, which printed a bold "-1" and returned nothing, so the record
# read as "no answer" while resolving perfectly from the same shell one line earlier. A rig whose
# own helper silently replaces a command it depends on is the exact failure it exists to catch.
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# A read that returns "" on any failure, so an unanswered call is never mistaken for a value.
rd() { cast call "$@" --rpc-url "$RPC" 2>/dev/null || true; }
# `cast receipt … status` prints true/false, not 1/0. Normalising here rather than at each call
# site: the first version compared against 1/0 and reported every good transaction as broken, and
# a rig that cries wolf is ignored exactly as fast as one that stays green.
st() {
  case "$(cast receipt "$1" status --rpc-url "$RPC" 2>/dev/null)" in
    true|1)  echo 1 ;;
    false|0) echo 0 ;;
    *)       echo "" ;;
  esac
}

# Everything on screen must come from a chain that is answering. If it is not, stop here rather
# than report five green ticks that mean "no answer".
if [[ -z "$(cast block-number --rpc-url "$RPC" 2>/dev/null)" ]]; then
  printf '\033[31mtake-check: the endpoint is not answering. Nothing below can be trusted.\033[0m\n'
  exit 1
fi

section "beat 1 — the official registry refuses the agent's own feedback"
a=$(rd "$REPUTATION" "getLastIndex(uint256,address)(uint64)" 10518 "$AGENT" | awk '{print $1}')
b=$(rd "$REPUTATION" "getLastIndex(uint256,address)(uint64)" 10518 "$SECOND" | awk '{print $1}')
[[ "$a" == "0" ]] && ok "the agent has written 0 records about itself" \
                  || bad "agent self-records = '${a:-no answer}', expected 0"
[[ -n "$b" && "$b" -ge 1 ]] 2>/dev/null && ok "a second address has $b" \
                  || bad "second address = '${b:-no answer}', expected at least 1"
[[ "$(st 0x87f5a04b4a044d7426eecec0ce45e6d3c830234c2b81a2b0ecbd39222b250fb8)" == "0" ]] \
  && ok "the self-feedback transaction is still a FAILED transaction on chain" \
  || bad "the beat-1 refusal is not readable as a failure"

section "beat 2 — the agent's own ENS write is refused  [needs the renounce]"
w=$(cast call "$RESOLVER" "setText(bytes,string,string)" "$DNS" "$JOINKEY" "x" --from "$AGENT" --rpc-url "$RPC" 2>&1)
if [[ "$w" == 0x* ]]; then
  bad "the agent can STILL write -- root is not renounced, so beat 2 is not recordable yet"
elif [[ "$w" == *"0x4b27a133"* ]]; then
  ok "the agent's write reverts EACUnauthorizedAccountRoles"
else
  bad "the write neither succeeded nor reverted our way: ${w:0:80}"
fi

section "beat 2b — and the agent cannot repoint the name out from under it"
# take-check never read the REGISTRY. With only the resolver's root renounced, every row below
# went green and the agent could still call setResolver and serve anything it liked from a
# resolver of its own. Found by the 2026-09-26 review, by executing it on a fork.
ROOT_ALL=0x1111111111111111111111111111111111111111111111111111111111111111
reg=$(rd "$REGISTRY" "hasRootRoles(uint256,address)(bool)" "$ROOT_ALL" "$AGENT")
case "$reg" in
  false) ok "the agent holds no root on the registry" ;;
  true)  bad "the agent STILL holds root on the REGISTRY — it can repoint agent.reckn.eth, so beat 2 is not true no matter what the resolver says" ;;
  *)     bad "the registry did not answer (got '${reg:-nothing}') — unknown, not closed" ;;
esac

section "beat 3 — the record resolves through ENS"
inner=$(cast calldata "text(bytes32,string)" "$(cast namehash agent.reckn.eth)" "$JOINKEY")
both=$(rd "$UR" "resolve(bytes,bytes)(bytes,address)" "$DNS" "$inner")
out=$(printf '%s' "$both" | sed -n 1p)
answered=$(printf '%s' "$both" | sed -n 2p)
# WHICH resolver answered is the half this row was missing. UniversalResolverV2 follows the
# registry's pointer, so if the name is repointed the record still "resolves" -- from a
# resolver the agent controls. Pinning it is what makes beat 3 about OUR surface.
if [[ -n "$answered" && "$(printf '%s' "$answered" | tr 'A-Z' 'a-z')" != "$(printf '%s' "$RESOLVER" | tr 'A-Z' 'a-z')" ]]; then
  bad "ENS answered from $answered, not our resolver — the name has been repointed"
else
  ok "the answer came from our resolver, not one substituted for it"
fi
val=""
if [[ -n "$out" ]]; then
  val=$(cast abi-decode 'f()(string)' "$out" 2>/dev/null | tr -d '"')
fi
[[ "$val" == reproduced* ]] && ok "ENS returns: $val" \
                            || bad "ENS did not return the record (got '${val:-no answer}')"

section "beat 4 — the settlement that a proof decided"
s4=$(st 0x60ff6e9ed2c4a2f20efa68124f38fa8afa55e03c8823f74def3ebf0c6bae74d6)
[[ "$s4" == "1" ]] && ok "the event-proof settlement is a success on chain" \
                   || bad "the event-proof settlement is not readable as a success"
d=$(rd "$ESCROW" "deals(bytes32)(address,address,address,uint256,address,bytes32,bytes32,uint64,uint8)" \
      "$(cast keccak 'reckn-tokyo-event-proof-1')" | tail -1)
[[ "$d" == "2" ]] && ok "the escrow says that deal is Settled" \
                  || bad "the escrow's state for that deal is '${d:-no answer}', expected 2 (Settled)"

section "beat 5 — the gate refuses, passes, refuses"
flags=$(python3 -c "print(hex(int('$HOOK',16) & 0x3fff))")
[[ "$flags" == "0x80" ]] && ok "the hook's low 14 bits are 0x80 (beforeSwap and nothing else)" \
                         || bad "the hook's flags are $flags, expected 0x80"
for pair in "0xda60d7df7940bf25fd01466444573d0b364a8865641e97dc061096ad1f1f94be:0:refused" \
            "0xa40bb3162ed17e084155277cd2d0a9605c1fea510ddef6df62dbf502831f5698:1:executed" \
            "0xce00489eb9f2ebca202643c28841360737b35bc30e81a276e47fab64e2f1fa79:0:refused again"; do
  h=${pair%%:*}; rest=${pair#*:}; want=${rest%%:*}; label=${rest#*:}
  got=$(st "$h")
  [[ "$got" == "$want" ]] && ok "the swap that is '$label' still reads as status $want" \
                          || bad "the swap that should be '$label' reads '${got:-no answer}'"
done

section "the frames themselves"
for f in beat1-00-self-write-refused beat1-01-state-contrast \
         beat3-02-window-opened beat3-03-buyer-writes beat3-04-ens-resolves-the-record \
         beat5-01-swap-refused beat5-02-buyer-writes-the-record beat5-03-swap-executes \
         beat5-04-record-cleared beat5-05-refused-again; do
  [[ -s "$root/docs/tokyo-2026/media/$f.png" ]] && ok "$f.png" || bad "missing frame: $f.png"
done

printf '\n'
if [[ $fail -eq 0 ]]; then
  printf '\033[32mevery load-bearing line is true right now. Record.\033[0m\n'
else
  printf '\033[31mDO NOT RECORD — %d line(s) are not true right now:\033[0m\n' "${#broken[@]}"
  for b in "${broken[@]}"; do printf '  · %s\n' "$b"; done
fi
exit $fail

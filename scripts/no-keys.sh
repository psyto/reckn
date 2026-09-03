#!/usr/bin/env bash
# The central claim, mechanically enforced.
#
#   "There is no key that can move a funded escrow."
#
# Reckn's entire differentiation is that `RecknZkEscrow` has no privileged role:
# no owner, no resolver, no admin, no pause, no upgrade path. That property is
# easy to destroy with one well-meaning line, and a demo built on it becomes a
# lie the moment it is destroyed. So it is a build condition, not a promise.
#
# Scope: the body of `contract RecknZkEscrow` only, with comments stripped —
# imported interfaces and prose are not the surface that moves money.
#
# Run: bash scripts/no-keys.sh   (exit 0 = the claim still holds)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
target="$root/zk-verdict/contracts/src/RecknZkEscrow.sol"

fail=0
say() { printf '\n\342\226\266 %s\n' "$*"; }
bad() { printf '  \342\234\227 %s\n' "$*"; fail=1; }
ok()  { printf '  \342\234\223 %s\n' "$*"; }

[[ -f "$target" ]] || { echo "missing $target"; exit 2; }

# Contract body, comments stripped. Everything below reads THIS, not the file.
body=$(awk '/^contract RecknZkEscrow/{f=1} f' "$target" \
       | sed -e 's://.*::' -e 's:/\*.*\*/::' )
[[ -n "$body" ]] || { echo "could not isolate contract body"; exit 2; }

# 1. Forbidden privilege vocabulary. Any of these reintroduces an actor with a key.
say "no privileged role in RecknZkEscrow"
forbidden='onlyOwner|Ownable|_owner|\badmin\b|Admin|governance|Governance|\bauthority\b|Authority|allowlist|allowList|whitelist|onlyRole|AccessControl|\bpause\b|Pausable|upgrade|Upgradeable|initializer|delegatecall|selfdestruct|ecrecover|isValidSignature'
if hits=$(printf '%s\n' "$body" | grep -nE "$forbidden" || true); [[ -n "$hits" ]]; then
  bad "privileged construct found:"; printf '      %s\n' "$hits"
else
  ok "none of: owner / admin / authority / allowlist / pause / upgrade / delegatecall / signature-recovery"
fi

# 2. The state-changing surface must be exactly the functions we intend, and each
#    must be callable by anyone. A new external function is a new way to move money.
say "state-changing surface is enumerated"
expected='fund settleWithProof refundAfterDeadline'
actual=$(printf '%s\n' "$body" | grep -oE '\bfunction +[a-zA-Z_][a-zA-Z0-9_]*' \
         | awk '{print $2}' | sort -u)
[[ -n "$actual" ]] || bad "no functions found — the body scan is broken, not the contract"
for f in $actual; do
  case " $expected " in
    *" $f "*) ok "function $f — expected" ;;
    *)        bad "function $f — NOT in the enumerated surface ($expected). If this is intended, the claim changed: update AGENTS.md and this script in the same commit, and say so in the demo." ;;
  esac
done

# 3. No function may gate on the caller's identity.
say "no caller-identity gating"
if hits=$(printf '%s\n' "$body" | grep -nE 'require\( *msg\.sender|if *\( *msg\.sender' || true); [[ -n "$hits" ]]; then
  bad "settlement gated on msg.sender:"; printf '      %s\n' "$hits"
else
  ok "no require/if on msg.sender — anyone may call"
fi

# 4. The constructor may bind only the verifier. Anything else is a stored authority.
say "constructor binds only the verifier"
if printf '%s\n' "$body" | sed -n '/constructor(/,/}/p' | grep -qE '= *msg\.sender'; then
  bad "constructor stores msg.sender"
else
  ok "constructor stores no caller"
fi

echo
if [[ $fail -eq 0 ]]; then
  printf '\342\234\223 the claim holds: no key can move a funded escrow.\n'
else
  printf '\342\234\227 THE CENTRAL CLAIM IS BROKEN. Do not demo, do not submit.\n'
  exit 1
fi

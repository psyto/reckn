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
# Scope: two files, both on the settlement-authority path, with comments stripped.
# Checks 1-4 read the body of `contract RecknZkEscrow`. Check 5 reads the whole of
# `RecknVerdictVerifier.sol`, because `settleWithProof` obeys the struct that file's
# `verifyVerdict` returns — a constant-address branch spliced in front of the proof
# check there is a resolver, and until 2026-09-05 this script could not see it.
# Prose and imported interfaces are still not the surface that moves money.
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

# 5. Settlement authority does not stop at the escrow. `settleWithProof` obeys the
#    struct `RecknVerdictVerifier.verifyVerdict` returns, so that file is inside the
#    claim and was outside this script until 2026-09-05. It is closed by six
#    PROPERTIES — what the file is permitted to contain — not by a list of forbidden
#    constructs: a hole in an enforcement script is never closed by adding the name
#    of the construct that exploited it. So `tx.origin`, `msg.sender`, `block.*`,
#    `if`, `assembly`, `delegatecall`, a `fallback`, a second `contract` and every
#    unlisted sibling fail together and for the same reason, and none is named here.
#    Each pinned value below is transcribed from docs/specs/008-verdict-domain-soundness.md
#    §6.4 — the script does not generate its own pin from the file it is checking.
say "the second contract on the settlement path is closed"
verifier_src="$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol"
if [[ ! -f "$verifier_src" ]]; then
  bad "5a: missing $verifier_src"
else
  stripped=$(sed -e 's://.*::' -e 's:/\*.*\*/::' "$verifier_src")
  # 5a — the region is literal, so the line-based, quote-blind stripper is exact.
  blk_open=$(grep -c -F '/*' "$verifier_src" || true)
  blk_close=$(grep -c -F '*/' "$verifier_src" || true)
  quoted=$(printf '%s\n' "$stripped" | grep -c '["'"'"']' || true)
  quoted_line=$(printf '%s\n' "$stripped" | grep '["'"'"']' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g')
  want_import='import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";'
  if [[ "$blk_open" != "0" || "$blk_close" != "0" ]]; then
    bad "5a: block comments present ($blk_open /* , $blk_close */) — the stripper cannot span lines"
  elif [[ "$quoted" != "1" ]]; then
    bad "5a: $quoted lines carry a quote; exactly 1 is permitted"
  elif [[ "$quoted_line" != "$want_import" ]]; then
    bad "5a: the one quoted line is not the pinned import: $quoted_line"
  else
    ok "5a region is literal — one quoted line, and it is the import"
  fi

  # 5b — the identifier vocabulary is closed. Equality in BOTH directions: a missing
  #      token fails as loudly as an extra one, so a dropped verifyProof dies here.
  vocab=$(printf '%s\n' "$stripped" | sed 's/"[^"]*"//g' \
          | grep -oE '[A-Za-z_$][A-Za-z0-9_$]*' | LC_ALL=C sort -u)
  want_vocab=$(printf '%s\n' \
    FAILED ISP1Verifier REPRODUCED RecknVerdictVerifier VerdictPublicValues \
    _verdictProgramVKey _verifier abi address bytes bytes32 calldata constant constructor \
    contract dealBinding decode from function immutable import maxDelta memory minDelta \
    outcome post pragma pre proofBytes public publicValues returns solidity struct traceHash \
    uint256 uint8 v verdictProgramVKey verifier verifyProof verifyVerdict view | LC_ALL=C sort -u)
  if [[ "$vocab" != "$want_vocab" ]]; then
    bad "5b: identifier vocabulary is not the pinned 43-token set"
    printf '      %s\n' "+ $(comm -13 <(printf '%s\n' "$want_vocab") <(printf '%s\n' "$vocab") | tr '\n' ' ')"
    printf '      %s\n' "- $(comm -23 <(printf '%s\n' "$want_vocab") <(printf '%s\n' "$vocab") | tr '\n' ' ')"
  else
    ok "5b identifier vocabulary is exactly the pinned 43 tokens"
  fi

  # 5c — the declared surface is closed by COUNT; 5b is a set and cannot see a second
  #      instance of a permitted kind.
  count_word() { printf '%s\n' "$stripped" | grep -ow "$1" | wc -l | tr -d ' '; }
  c_fail=0
  for pair in "pragma 1" "import 1" "struct 1" "contract 1" "constructor 1" "function 1" "constant 2" "immutable 2"; do
    set -- $pair
    got=$(count_word "$1")
    [[ "$got" == "$2" ]] || { bad "5c: $got '$1' declarations, exactly $2 permitted"; c_fail=1; }
  done
  fname=$(printf '%s\n' "$stripped" | grep -oE '\bfunction +[A-Za-z_$][A-Za-z0-9_$]*' | awk '{print $2}')
  [[ "$fname" == "verifyVerdict" ]] || { bad "5c: the one function is '$fname', not verifyVerdict"; c_fail=1; }
  [[ $c_fail -eq 1 ]] || ok "5c declared surface is closed by count, and the one function is verifyVerdict"

  # The 5f extraction, also used by 5d and 5e. Machine-decidable, not a parse:
  #   strip comments -> drop the one quoted line -> collapse ALL whitespace ->
  #   cut at ; { } -> trim -> drop empties.
  flat=$(printf '%s\n' "$stripped" | sed '/["'"'"']/d' | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')
  pieces=$(printf '%s' "$flat" | tr ';{}' '\n\n\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')

  # 5d — verifyVerdict's body is two statements of pinned form, in order.
  body=${flat##*returns (VerdictPublicValues memory v) }
  semis=$(printf '%s' "$body" | tr -cd ';' | wc -c | tr -d ' ')
  stmts=$(printf '%s' "$body" | tr ';{}' '\n\n\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
  want_stmts=$(printf '%s\n' \
    'ISP1Verifier(verifier).verifyProof(verdictProgramVKey, publicValues, proofBytes)' \
    'v = abi.decode(publicValues, (VerdictPublicValues))')
  if [[ "$semis" != "2" ]]; then
    bad "5d: verifyVerdict's body carries $semis statements, exactly 2 permitted"
  elif [[ "$stmts" != "$want_stmts" ]]; then
    bad "5d: verifyVerdict's two statements are not the pinned pair, in order"
  else
    ok "5d verifyVerdict verifies first and decodes second — two statements, nothing else"
  fi

  # 5e — assignment targets are closed: the file's own declared names, no field,
  #      index or member of any of them. `v.outcome = REPRODUCED` dies here.
  targets=$(printf '%s' "$flat" | sed -e 's/==/ /g' -e 's/!=/ /g' -e 's/<=/ /g' -e 's/>=/ /g' -e 's/=>/ /g' \
            | grep -oE '[A-Za-z_$][A-Za-z0-9_$.]*(\[[^]]*\])?[[:space:]]*=' | sed 's/[[:space:]]*=$//')
  n_targets=$(printf '%s\n' "$targets" | grep -v '^$' | wc -l | tr -d ' ')
  e_fail=0
  for t in $targets; do
    case " REPRODUCED FAILED verifier verdictProgramVKey v " in
      *" $t "*) ;;
      *) bad "5e: assignment to '$t', which is not one of the five permitted targets"; e_fail=1 ;;
    esac
  done
  if [[ "$n_targets" != "5" ]]; then
    bad "5e: $n_targets assignments, exactly 5 permitted"; e_fail=1
  fi
  [[ $e_fail -eq 1 ]] || ok "5e all 5 assignments land on the file's own declared names"

  # 5f — the normalised skeleton is closed, in full and in order. This is the only
  #      clause that sees an ORDER or a VALUE: a permuted struct, a re-valued
  #      constant and a swapped parameter list are invisible to 5a-5e.
  want_pieces=$(cat <<'PIECES'
pragma solidity ^0.8.20
struct VerdictPublicValues
uint256 pre
uint256 post
uint256 minDelta
uint256 maxDelta
uint8 outcome
bytes32 traceHash
bytes32 dealBinding
contract RecknVerdictVerifier
uint8 public constant REPRODUCED = 0
uint8 public constant FAILED = 1
address public immutable verifier
bytes32 public immutable verdictProgramVKey
constructor(address _verifier, bytes32 _verdictProgramVKey)
verifier = _verifier
verdictProgramVKey = _verdictProgramVKey
function verifyVerdict(bytes calldata publicValues, bytes calldata proofBytes) public view returns (VerdictPublicValues memory v)
ISP1Verifier(verifier).verifyProof(verdictProgramVKey, publicValues, proofBytes)
v = abi.decode(publicValues, (VerdictPublicValues))
PIECES
)
  n_pieces=$(printf '%s\n' "$pieces" | wc -l | tr -d ' ')
  if [[ "$pieces" != "$want_pieces" ]]; then
    bad "5f: the normalised skeleton is not the pinned 20 pieces in order ($n_pieces pieces)"
    diff <(printf '%s\n' "$want_pieces") <(printf '%s\n' "$pieces") | sed 's/^/      /' | head -12
  else
    ok "5f skeleton is exactly the pinned 20 pieces, in order"
  fi
fi

echo
if [[ $fail -eq 0 ]]; then
  printf '\342\234\223 the claim holds: no key can move a funded escrow.\n'
else
  printf '\342\234\227 THE CENTRAL CLAIM IS BROKEN. Do not demo, do not submit.\n'
  exit 1
fi

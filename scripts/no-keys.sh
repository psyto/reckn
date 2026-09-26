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
root=${NOKEYS_ROOT:-$(cd "$here/.." && pwd)}
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
forbidden='onlyOwner|Ownable|_owner|\bowner\b|\badmin\b|Admin|governance|Governance|\bauthority\b|Authority|allowlist|allowList|whitelist|onlyRole|AccessControl|\bpause\b|Pausable|upgrade|Upgradeable|initializer|delegatecall|selfdestruct|ecrecover|isValidSignature'
if hits=$(printf '%s\n' "$body" | grep -nE "$forbidden" || true); [[ -n "$hits" ]]; then
  bad "privileged construct found:"; printf '      %s\n' "$hits"
else
  ok "none of: owner / admin / authority / allowlist / pause / upgrade / delegatecall / signature-recovery"
fi

# 2. The state-changing surface is CLOSED, not enumerated (009). Enumerating what the
#    grep finds is not a closure: `fallback()` and `receive()` carry no `function`
#    keyword, so a fallback that drains any funded deal was invisible to this check —
#    measured, compiled and drained. K below is the complete set of Solidity 0.8.x
#    keywords that introduce executable code reachable AFTER deployment at member
#    level; `constructor` is deliberately not in it (it is check 4b's).
say "state-changing surface is closed"
sum=0
for kw in function fallback receive modifier; do
  n=$( (printf '%s\n' "$body" | grep -ow "$kw" || true) | wc -l | tr -d ' ')
  sum=$((sum + n))
  if [[ "$kw" != "function" && "$n" != "0" ]]; then
    bad "2a: $n '$kw' — the only entry points may be functions, and only the enumerated ones"
  fi
done
expected='fund settleWithProof refundAfterDeadline'
actual=$(printf '%s\n' "$body" | grep -oE '\bfunction +[a-zA-Z_][a-zA-Z0-9_]*' \
         | awk '{print $2}' | sort -u)
[[ -n "$actual" ]] || bad "2b: no functions found — the body scan is broken, not the contract"
for f in $actual; do
  case " $expected " in
    *" $f "*) ok "function $f — expected" ;;
    *)        bad "2b: function $f — NOT in the enumerated surface ($expected). If this is intended, the claim changed: update AGENTS.md and this script in the same commit, and say so in the demo." ;;
  esac
done
ok "entry keywords sum $sum (function only; 0 fallback, 0 receive, 0 modifier)"

# 2c. The region above reads from the `contract RecknZkEscrow` line down. An
#     INHERITED member is declared above that line, so the reading is only complete
#     if there is nothing to inherit from and no `using` binding member calls
#     elsewhere. Measured: a base contract carrying a draining `fallback` compiled and
#     took a funded deal while every other clause here stayed green.
# Counted over comment-STRIPPED source: a doc comment that says "the contract" is
# not a second contract, and counting it would make honest documentation fail the
# clause. (Found 2026-09-06 by writing exactly such a comment.)
stripped_file=$(sed -e 's://.*::' -e 's:/\*.*\*/::' "$target")
inherit=$(printf '%s\n' "$stripped_file" | sed -n 's/.*contract RecknZkEscrow\(.*\){.*/\1/p' | tr -d ' \t')
contracts=$( (printf '%s\n' "$stripped_file" | grep -ow contract || true) | wc -l | tr -d ' ')
usings=$( (printf '%s\n' "$stripped_file" | grep -ow using || true) | wc -l | tr -d ' ')
if [[ -n "$inherit" ]]; then
  bad "2c: RecknZkEscrow inherits ($inherit) — members declared above the contract line are outside every check here"
elif [[ "$contracts" != "1" ]]; then
  bad "2c: $contracts 'contract' declarations in the file; exactly 1 keeps the region complete"
elif [[ "$usings" != "0" ]]; then
  bad "2c: $usings 'using' directives — member-call resolution is no longer local"
else
  ok "2c region is the whole of the deployed code — 1 contract, 0 inherited, 0 using"
fi

# 3. No function may gate on the caller's identity.
say "no caller-identity gating"
if hits=$(printf '%s\n' "$body" | grep -nE 'require\( *msg\.sender|if *\( *msg\.sender' || true); [[ -n "$hits" ]]; then
  bad "settlement gated on msg.sender:"; printf '      %s\n' "$hits"
else
  ok "no require/if on msg.sender — anyone may call"
fi

# 4. There is no constructor at all (009), so the old body — "the constructor does not
#    store msg.sender" — would match an empty range and pass vacuously. An observer
#    that watches nothing is not an observer.
say "no deployment-time configuration, over a literal region"
# 4a. What makes 1, 2, 3 and 4b mean anything. The stripper is line-based and
#     quote-blind: `string constant MASK = "//"; constructor() {}` becomes
#     `string constant MASK = "` — valid Solidity carrying a constructor, with the
#     token gone. Both routes are closed in the RAW file, before stripping.
blk_open=$(grep -c -F '/*' "$target" || true)
blk_close=$(grep -c -F '*/' "$target" || true)
quotes=$(printf '%s\n' "$body" | grep -c '["'"'"']' || true)
if [[ "$blk_open" != "0" || "$blk_close" != "0" ]]; then
  bad "4a: block comments present ($blk_open /* , $blk_close */) — the stripper cannot span lines"
elif [[ "$quotes" != "0" ]]; then
  bad "4a: $quotes quoted line(s) in the body — a string can hide a declaration from the stripper"
else
  ok "4a region is literal — no block comments, no string or char literals"
fi
# 4b. No constructor, no immutable: two deployments of this source are behaviourally
#     identical and there is no deployer choice to disclose or trust.
ctor=$( (printf '%s\n' "$body" | grep -ow constructor || true) | wc -l | tr -d ' ')
immut=$( (printf '%s\n' "$body" | grep -ow immutable || true) | wc -l | tr -d ' ')
if [[ "$ctor" != "0" || "$immut" != "0" ]]; then
  bad "4b: $ctor constructor, $immut immutable — deployment-time configuration is a key by another name"
else
  ok "4b no constructor, no immutable — every deployment of this source is the same contract"
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

# 6. The Tokyo surfaces (R-9 / the 013 review's B2: "no-keys.sh never reads the new contracts").
#
#    `settleWithProof` stopped being the only thing with authority the moment the event work
#    landed. `SettlementRecord` decides WHO may write an agent's history, and `RecordGatedHook`
#    decides whether a pool trades at all. Neither moves money, so neither is covered by the
#    sentence at the top of this file — but both would be a key if they had one, and until now
#    this script could not see either.
#
#    Set NOKEYS_ROOT to point the whole script at an isolated copy. scripts/no-keys-control.sh
#    uses it to plant keys in a temp directory and require this check to go red, which is what
#    R-9 asks for: a criterion nobody has watched fail is not a criterion.
adapter="$root/tokyo-2026/src/SettlementRecord.sol"
hook="$root/tokyo-2026/src/RecordGatedHook.sol"

strip() { sed -e 's://.*::' -e 's:/\*.*\*/::' "$1"; }
# "function name(…) external view returns (…)" up to the body — newlines joined first, because
# this repository's signatures wrap.
headers() { printf '%s\n' "$1" | tr '\n' ' ' | grep -oE 'function +[a-zA-Z_][a-zA-Z0-9_]*[^{;]*' || true; }

for spec in "SettlementRecord|$adapter|open close" "RecordGatedHook|$hook|"; do
  IFS='|' read -r name file allowed <<< "$spec"
  say "no privileged role in $name"
  if [[ ! -f "$file" ]]; then
    bad "6: $file is missing — this check cannot pass by not finding its subject"
    continue
  fi
  src=$(awk -v c="^contract $name" '$0 ~ c {f=1} f' <(strip "$file"))
  [[ -n "$src" ]] || { bad "6: could not isolate contract $name"; continue; }

  # 6d — FIRST, because 6a-6c read from the `contract NAME` line down and therefore cannot see
  #      anything declared above it. A base contract with a privileged function, a `modifier` and
  #      a `fallback()` passed all three and exited 0 — measured. Check 2 was tightened for this
  #      in 2c; check 6 shipped without the equivalent. The closure is: this file defines exactly
  #      ONE contract, and that contract inherits from nothing. There is then nothing above the
  #      line to hide in, and adding a base turns this red rather than turning the others blind.
  ncontracts=$( (grep -cE '^[[:space:]]*(abstract +)?contract ' <(strip "$file")) || true)
  [[ "$ncontracts" == "1" ]] \
    && ok "6d $name: the file defines exactly one contract" \
    || bad "6d: $file defines $ncontracts contracts — 6a-6c only read one of them, so the others are invisible"
  # An INTERFACE base carries no code, so it cannot hide a privileged function; a contract,
  #      abstract contract or library base can, and would sit above the line 6a-6c read from.
  #      So the property is not "inherits from nothing" — the first version of this said that and
  #      turned red on `is IHooks`, which proves nothing — it is "every base resolves to an
  #      `interface` declaration, and none resolves to a contract".
  hdr=$(printf '%s\n' "$src" | head -1)
  bases=$(printf '%s' "$hdr" | sed -n 's/.* is \([^{]*\).*/\1/p' | tr ',' ' ')
  # The sources under test come from $root, which NOKEYS_ROOT may redirect to an isolated copy;
  # a base's DECLARATION lives in the dependency tree, which that copy does not carry. Resolving
  # against $root alone made every base read as unresolved and the CLEAN COPY FAIL, which would
  # have made no-keys-control.sh useless -- it needs the clean copy green to mean anything.
  decl_roots="$root/tokyo-2026/src $root/zk-verdict/contracts/src $here/../tokyo-2026/lib"
  for b in $bases; do
    b=${b%%(*}
    [[ -n "$b" ]] || continue
    if grep -rqE "^[[:space:]]*(abstract +)?contract +$b\b" $decl_roots 2>/dev/null; then
      bad "6d: $name inherits $b, and $b is declared as a CONTRACT somewhere — its members sit above the line 6a-6c read from"
    elif grep -rqE "^[[:space:]]*interface +$b\b" $decl_roots 2>/dev/null; then
      ok "6d $name: base $b is an interface — no code to inherit"
    else
      bad "6d: $name inherits $b and this check could not find its declaration. Unresolved is not the same as safe."
    fi
  done
  [[ -n "$bases" ]] || ok "6d $name: inherits from nothing"
  if printf '%s\n' "$src" | grep -qE '\busing +[A-Za-z_]'; then
    bad "6d: $name has a \`using\` binding — member calls can resolve to a library this check never read"
  fi

  # 6a — the same vocabulary as check 1. A key is a key wherever it is declared.
  if hits=$(printf '%s\n' "$src" | grep -nE "$forbidden" || true); [[ -n "$hits" ]]; then
    bad "6a: privileged construct in $name:"; printf '      %s\n' "$hits"
  else
    ok "6a $name: no owner / admin / authority / pause / upgrade / delegatecall"
  fi

  # 6b — fallback and receive carry no `function` keyword, which is how a draining entry point
  #      hid from check 2 once already.
  for kw in fallback receive modifier; do
    n=$( (printf '%s\n' "$src" | grep -ow "$kw" || true) | wc -l | tr -d ' ')
    [[ "$n" == "0" ]] || bad "6b: $n '$kw' in $name — entry points may only be functions"
  done
  ok "6b $name: 0 fallback, 0 receive, 0 modifier"

  # 6e — caller-identity gating, which check 6 had no analogue of. A blanket ban like check 3's
  #      would be wrong here: `close` gates on msg.sender ON PURPOSE, and that guard is what
  #      stops a stranger closing a window before the writer has used it. The property is
  #      narrower and is `013` R-8 — THE DEAL IS THE AUTHORITY, NOT THE CALLER — so every
  #      comparison against msg.sender must be against state derived from the deal, never
  #      against a constant, an immutable, or a stored address that is not deal-derived.
  #      `address public immutable boss = msg.sender;` gating `open` passes 6a (no forbidden
  #      word), 6c (an immutable is not a function that writes) and 6d. It lands here.
  allowed_cmp='writerOf\[dealId\]'
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if printf '%s' "$line" | grep -qE "msg\.sender *[!=]= *$allowed_cmp|$allowed_cmp *[!=]= *msg\.sender"; then
      ok "6e $name: msg.sender compared against the deal's own writer"
    else
      bad "6e: $name compares msg.sender against something that is not deal-derived — $(printf '%s' "$line" | sed 's/^ *//' | cut -c1-70)"
    fi
  done < <(printf '%s\n' "$src" | grep -nE 'msg\.sender *[!=]=|[!=]= *msg\.sender' || true)

  # 6c — which functions can write. For the hook the allowed set is EMPTY: everything after the
  #      constructor is view or pure, so nothing can change what it reads. For the adapter it is
  #      exactly `open` and `close`. A setter for the name, the key, the resolver or the writer
  #      would be a key with a different spelling, and lands here.
  #      A header carrying `view` or `pure` cannot write. Only `external`/`public` ones are
  #      entry points: a `private` helper is reachable only through one of them, so listing it
  #      here would say the surface is wider than it is. The name is cut at the paren, because
  #      `awk '{print $2}'` on a header yields `open(bytes32`.
  #      `|| true`, because a contract where NOTHING can write is the good case and grep exits
  #      1 on no match. Without it `set -e` killed the script right there -- after the hook's
  #      own rows had printed, so the run looked complete and the final verdict never appeared.
  writers=$(headers "$src" | grep -E '\b(external|public)\b' | grep -vE '\b(view|pure)\b' \
            | awk '{print $2}' | sed 's/(.*//' | sort -u || true)
  for fn in $writers; do
    case " $allowed " in
      *" $fn "*) ok "6c $name.$fn — may write, and is expected to" ;;
      *)         bad "6c: $name.$fn can write state and is NOT in the allowed set (${allowed:-none}). If this is intended, the claim changed: say so in AGENTS.md and here in the same commit." ;;
    esac
  done
  [[ -n "$writers" ]] || ok "6c $name: no function can write state after deployment"
done

echo
if [[ $fail -eq 0 ]]; then
  printf '\342\234\223 the claim holds: no key can move a funded escrow.\n'
else
  printf '\342\234\227 THE CENTRAL CLAIM IS BROKEN. Do not demo, do not submit.\n'
  exit 1
fi

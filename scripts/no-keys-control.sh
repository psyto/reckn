#!/usr/bin/env bash
# no-keys-control — watch the gate fail, or stop believing it.
#
# `no-keys.sh` is the build condition the whole project rests on, and until now nobody had seen
# it go red. R-9: *a criterion satisfied by breaking your own observer is not a criterion*, and
# the 013 review sharpened it — **at least three DISSIMILAR mutations, each independently red,
# applied in an isolated copy, worktree unchanged.** Similar mutations would only prove that one
# clause works several times.
#
# Nothing here touches the tracked tree. Each mutation is planted in a temp directory and the
# gate is pointed at it with NOKEYS_ROOT; the worktree's own `git status` is compared before and
# after, and this script fails if it moved.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
before=$(cd "$root" && git status --porcelain | sort)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

FILES=(
  "zk-verdict/contracts/src/RecknZkEscrow.sol"
  "zk-verdict/contracts/src/RecknVerdictVerifier.sol"
  "tokyo-2026/src/SettlementRecord.sol"
  "tokyo-2026/src/RecordGatedHook.sol"
)
fresh() {
  rm -rf "$tmp/c"; for f in "${FILES[@]}"; do mkdir -p "$tmp/c/$(dirname "$f")"; cp "$root/$f" "$tmp/c/$f"; done
}
gate() { NOKEYS_ROOT="$tmp/c" bash "$here/no-keys.sh" >"$tmp/out" 2>&1; echo $?; }

pass=0; failn=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; failn=$((failn+1)); }

printf '\n\033[1mthe unmutated copy must be green — otherwise every red below means nothing\033[0m\n'
fresh
if [[ "$(gate)" == "0" ]]; then ok "clean copy: the gate passes"
else bad "clean copy: the gate FAILS, so this control cannot distinguish anything"; sed 's/^/      /' "$tmp/out" | tail -5; fi

# Five dissimilar keys. Each one is a different SHAPE of privilege, in a different file, caught
# by a different clause — not the same edit five times.
plant() { # name | file | sed program | which clause should catch it
  local name=$1 file=$2 prog=$3 clause=$4
  fresh
  perl -0pi -e "$prog" "$tmp/c/$file"
  local rc; rc=$(gate)
  if [[ "$rc" != "0" ]]; then
    ok "$name → red ($clause): $(grep -m1 '✗' "$tmp/out" | sed 's/^ *✗ *//' | cut -c1-72)"
  else
    bad "$name → THE GATE STAYED GREEN. $clause does not close."
  fi
}

printf '\n\033[1meight dissimilar keys, each planted alone\033[0m\n'
# The first version of this planted `address public owner;` and nothing else, and the gate
# stayed green -- correctly. An unread variable is a NAME, not a key: nothing can move money
# with it. The mutation has to be an actual key, and then two independent clauses catch it.
# (The vocabulary was tightened to include bare `owner` in the same commit, so the name alone
# now trips as well; this row is here for the key, not the word.)
plant "an owner-gated sweep on the escrow" \
      "zk-verdict/contracts/src/RecknZkEscrow.sol" \
      's/(contract RecknZkEscrow[^\n]*\{)/$1\n    address public admin_;/; s/(function refundAfterDeadline)/function sweep(bytes32 d) external { require(msg.sender == admin_); }\n\n    $1/' \
      "checks 2b and 3, an unenumerated function gated on msg.sender"

plant "a draining fallback on the adapter" \
      "tokyo-2026/src/SettlementRecord.sol" \
      's/(contract SettlementRecord[^\n]*\{)/$1\n    fallback() external {}/' \
      "check 6b, fallback carries no function keyword"

plant "a setter for the adapter's name" \
      "tokyo-2026/src/SettlementRecord.sol" \
      's/(function close\(bytes32 dealId\) external \{)/function setName(bytes calldata n) external { dnsName = n; }\n\n    $1/' \
      "check 6c, a writer outside {open, close}"

plant "a setter for the hook's record key" \
      "tokyo-2026/src/RecordGatedHook.sol" \
      's/(function isOpen\(\) public view returns \(bool\) \{)/function setRecordKey(string calldata k) external { recordKey = k; }\n\n    $1/' \
      "check 6c, the hook may write nothing"

plant "an admin on the verdict verifier" \
      "zk-verdict/contracts/src/RecknVerdictVerifier.sol" \
      's/(contract RecknVerdictVerifier[^\n]*\{)/$1\n    address public admin;/' \
      "check 5, the file settleWithProof obeys"

plant "a bare owner, with nothing reading it" \
      "zk-verdict/contracts/src/RecknZkEscrow.sol" \
      's/(contract RecknZkEscrow[^\n]*\{)/$1\n    address public owner;/' \
      "check 1, the word alone — the branch that was DEAD until 2026-09-26"

plant "a base contract above the adapter" \
      "tokyo-2026/src/SettlementRecord.sol" \
      's/(contract SettlementRecord \{)/abstract contract Steward {\n    address st;\n    modifier onlySt() { require(msg.sender == st); _; }\n    fallback() external {}\n    function sweep(address r, uint256 a) external onlySt {}\n}\n\n$1/; s/contract SettlementRecord \{/contract SettlementRecord is Steward {/' \
      "check 6d, everything above the contract line was invisible to 6a-6c"

plant "a caller gate that is not deal-derived" \
      "tokyo-2026/src/SettlementRecord.sol" \
      's/(function open\(bytes32 dealId)/address public immutable boss = msg.sender;\n\n    $1/; s/(if \(opened\[dealId\]\) revert AlreadyOpened\(\);)/require(msg.sender == boss);\n        $1/' \
      "check 6e, 013 R-8: the deal is the authority, not the caller"

printf '\n\033[1mthe tracked tree must not have moved\033[0m\n'
after=$(cd "$root" && git status --porcelain | sort)
if [[ "$before" == "$after" ]]; then ok "git status is byte-identical before and after"
else bad "the worktree CHANGED — mutations escaped the isolated copy"; diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/      /'; fi

printf '\n'
if [[ $failn -eq 0 ]]; then
  printf '\033[32m%d/%d — the gate has now been seen to fail, eight different ways.\033[0m\n' "$pass" "$((pass+failn))"
else
  printf '\033[31m%d of %d checks did not hold.\033[0m\n' "$failn" "$((pass+failn))"
fi
exit $(( failn > 0 ))

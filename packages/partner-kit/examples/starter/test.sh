#!/usr/bin/env bash
# Run the starter end to end and check that it did the three things it claims.
#
# Separate from `npm test` in the package above, which is pure TypeScript and runs anywhere:
# this one needs anvil and forge and about a minute. It exists because "I ran the demo once
# and it looked right" is not a regression test, and the demo's three outcomes are the
# product's whole claim.
#
# The demo throws on any violation, so a zero exit already means a lot. The greps below are
# for the other failure: a demo that stops printing what it did while still exiting cleanly.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
log=$(mktemp "${TMPDIR:-/tmp}/starter-test.XXXXXX")
cleanup() { kill "$(cat "$here/.anvil.pid" 2>/dev/null)" 2>/dev/null || true
            pkill -f 'anvil --chain-id 5042002' 2>/dev/null || true; }
trap cleanup EXIT INT TERM

bash setup-chain.sh > "$log" 2>&1 || { echo "setup-chain failed:"; tail -20 "$log"; exit 1; }
node --experimental-strip-types src/demo.ts >> "$log" 2>&1 || {
  echo "the demo exited non-zero — it asserts its own outcomes, so this is a real failure:"
  tail -25 "$log"; exit 1; }

fail=0
check() { # description, pattern
  if grep -qE "$2" "$log"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s  (no line matching /%s/)\n' "$1" "$2"; fail=1; fi
}
echo "starter, end to end:"
check "the buyer's binding matches the proof's"        'they match'
check "RELEASE settled and paid the seller in full"    'verdict     Reproduced'
check "the seller balance went 0 -> the full amount"   'seller balance 0 -> 250000000'
check "REFUND settled the other way"                   'verdict     Failed'
check "the buyer was made whole"                       'buyer balance unchanged'
check "a real proof of another job was refused"        'rejected:'
check "the refused deal is still Funded"               'deal state: Funded'
check "and the escrow still holds the money"           'the escrow still holds 250000000'
check "the local-chain tier is stated, not implied"    'Nothing here is evidence about a public network'
check "the sample boundary is printed while it runs"   'SAMPLE BOUNDARY'

[[ $fail -eq 0 ]] || { echo; echo "full output: $log"; exit 1; }
rm -f "$log"
echo
echo "starter: all three paths behaved, and said so."

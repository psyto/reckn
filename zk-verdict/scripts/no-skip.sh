#!/usr/bin/env bash
# AC-11 — no test in the contracts suite can pass by not running.
#
# `forge test` has no --fail-on-no-tests in 1.7.1 and a test that returns early
# because a fixture is absent is reported as a pass. Both make a green suite mean
# less than it looks. So: zero early-return fixture gates, and a counted run.
#
# The check is over the EARLY RETURN, not over `vm.exists`: the permitted
# replacement — require(vm.exists(F), "...") — contains that exact string, and a
# check that forbids its own remedy is a check nobody can satisfy.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
testdir="$root/zk-verdict/contracts/test"
want_tests=18
fail=0

gates=0
for f in "$testdir"/*.t.sol; do
  n=$(grep -cE 'if[[:space:]]*\([[:space:]]*!vm\.exists\(' "$f" || true)
  gates=$((gates + n))
  [[ "$n" == "0" ]] || { printf '  EARLY RETURN   %s: %s fixture gate(s)\n' "${f#$root/}" "$n"; fail=1; }
done

json=$(mktemp "${TMPDIR:-/tmp}/no-skip.XXXXXX")
if ! (cd "$root/zk-verdict/contracts" && forge test --json) > "$json" 2>/dev/null; then
  printf '  FORGE FAILED   the suite did not exit 0\n'; fail=1
fi
ran=0; skipped=0; nonsuccess=0
if jq -e . "$json" > /dev/null 2>&1; then
  ran=$(jq '[.[].test_results | to_entries[]] | length' "$json")
  skipped=$(jq '[.[].test_results | to_entries[] | select(.value.status == "Skipped")] | length' "$json")
  nonsuccess=$(jq '[.[].test_results | to_entries[] | select(.value.status != "Success")] | length' "$json")
else
  printf '  NO JSON        forge produced no parsable output\n'; fail=1
fi
rm -f "$json"
[[ "$ran" == "$want_tests" ]] || { printf '  COUNT          %s tests ran, the manifest requires %s\n' "$ran" "$want_tests"; fail=1; }
[[ "$nonsuccess" == "0" ]] || { printf '  NOT SUCCESS    %s test(s) did not report Success\n' "$nonsuccess"; fail=1; }

witness=$(cat $(find "$testdir" -maxdepth 1 -name '*.t.sol' | LC_ALL=C sort) | shasum -a 256 | cut -c1-16)
echo "no-skip: $gates early-return fixture gates, $ran/$want_tests forge tests ran, $skipped skipped; witness=$witness"
[[ $fail -eq 0 ]] || exit 1

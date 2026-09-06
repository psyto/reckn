#!/usr/bin/env bash
# AC-9 — no test in this suite can pass by not running.
#
# `forge` reports a test that hits an early `return;` fixture gate as Success, not as
# Skipped, so a count of forge-reported skips cannot see one. 009 therefore asserts
# the ABSENCE of gates lexically, in its own file, and says so in the evidence line:
# `0 forge-reported skips`, not `0 skipped`. Seven such gates existed elsewhere in
# this directory before a sibling task removed them; asserting it directory-wide is
# that task's criterion and 009 does not depend on it landing (L-15).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
xvm="$root/zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol"
base="$here/xvm.base.json"
fixtures=(
  "$root/zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json"
  "$root/zk-verdict/contracts/src/fixtures/svm-groth16-fixture.json"
)
for f in "$xvm" "$base"; do [[ -f "$f" ]] || { echo "missing $f"; exit 2; }; done

fail=0
note() { printf '  %s\n' "$*"; fail=1; }

# 1. no gate to fire, in this file. Comments are stripped first: a comment that
#    NAMES the construct is not the construct, and counting it would make the honest
#    documentation of this clause fail the clause.
xvm_code=$(sed -e 's://.*::' -e 's:/\*.*\*/::' "$xvm")
gates=$( (printf '%s\n' "$xvm_code" | grep -c -F 'vm.exists' || true) )
bare=$( (printf '%s\n' "$xvm_code" | grep -cE '^[[:space:]]*return;[[:space:]]*$' || true) )
gates=$((gates + bare))
[[ "$gates" == "0" ]] || note "$gates fixture gate(s) or bare return(s) in the cross-VM file"

# 2. both fixtures exist and carry the five fields the tests read.
readable=0
for f in "${fixtures[@]}"; do
  if [[ -f "$f" ]] && jq -e '(.vkey|length>0) and (.deal_binding|length>0) and (.public_values|length>0) and (.proof|length>0) and (.outcome|type=="number")' "$f" > /dev/null 2>&1; then
    readable=$((readable + 1))
  else
    note "fixture not readable or incomplete: ${f#$root/}"
  fi
done

# 3. listed == ran == {B} + 16, none skipped, all Success.
B=$(jq -r '.B' "$base")
want=$((B + 16))
listed_json=$(mktemp "${TMPDIR:-/tmp}/xvm-list.XXXXXX")
ran_json=$(mktemp "${TMPDIR:-/tmp}/xvm-ran.XXXXXX")
(cd "$root/zk-verdict/contracts" && forge test --list --json) > "$listed_json" 2>/dev/null || note "forge --list failed"
(cd "$root/zk-verdict/contracts" && forge test --json) > "$ran_json" 2>/dev/null || note "forge test failed"

listed=$(jq '[.[] | .[] | .[]] | length' "$listed_json" 2>/dev/null || echo 0)
ran=$(jq '[.[].test_results | to_entries[]] | length' "$ran_json" 2>/dev/null || echo 0)
skipped=$(jq '[.[].test_results | to_entries[] | select(.value.status == "Skipped")] | length' "$ran_json" 2>/dev/null || echo -1)
nonsuccess=$(jq '[.[].test_results | to_entries[] | select(.value.status != "Success")] | length' "$ran_json" 2>/dev/null || echo -1)
[[ "$listed" == "$want" ]] || note "$listed tests listed, {B}+16 = $want expected"
[[ "$ran" == "$want" ]] || note "$ran tests ran, $want expected"
[[ "$skipped" == "0" ]] || note "$skipped forge-reported skip(s)"
[[ "$nonsuccess" == "0" ]] || note "$nonsuccess test(s) did not report Success"

# 4. every id recorded at 009's base is still there. A vanished base id means a
#    pre-existing test was deleted or renamed, which is not in 009's scope.
missing=$(python3 - "$base" "$listed_json" <<'PY'
import json, sys
base = json.load(open(sys.argv[1]))
d = json.load(open(sys.argv[2]))
ids = set()
for f, cs in d.items():
    for c, ts in cs.items():
        for t in ts:
            ids.add(f"{c}:{t}")
gone = [i for i in base["testIds"] if i not in ids]
print(len(gone), ";".join(gone[:3]))
PY
)
n_missing=$(printf '%s' "$missing" | awk '{print $1}')
[[ "$n_missing" == "0" ]] || note "$n_missing base test id(s) missing: $(printf '%s' "$missing" | cut -d' ' -f2-)"
rm -f "$listed_json" "$ran_json"

witness=$(cat $(find "$root/zk-verdict/contracts/test" -maxdepth 1 -name '*.t.sol' | LC_ALL=C sort) | shasum -a 256 | cut -c1-16)
echo "no-skip: $gates fixture gates in the cross-VM file, $readable/2 fixtures readable, $B+16 tests listed and ran, $skipped forge-reported skips; witness=$witness"
[[ $fail -eq 0 ]] || exit 1

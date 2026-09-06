#!/usr/bin/env bash
# The 009 acceptance gate. The manifest is parsed out of the ```ac009-manifest``` block
# of docs/specs/009-cross-vm-settlement.md §7.1, so the document and the gate cannot
# drift apart.
#
#   bash zk-verdict/scripts/ac009.sh --check   # manifest arithmetic and the naming gate
#   bash zk-verdict/scripts/ac009.sh AC-1      # one row
#   bash zk-verdict/scripts/ac009.sh --all     # every row, then the §7.4 canary
#
# Four substitution tokens and no others: {witness} (§7.2), {B} and {P} (measured at
# 009's base and recorded in xvm.base.json), {G} (the sibling gates discovered by the
# same closure AC-12 uses — computed HERE, not by invoking both-green.sh, so a stub
# that prints a constant is caught by the witness).
#
# Location rule: root comes from this file's own path — no argument, no environment
# override, no absolute path, no `git rev-parse`.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
spec="$root/docs/specs/009-cross-vm-settlement.md"
base="$here/xvm.base.json"

[[ -f "$spec" ]] || { echo "missing $spec"; exit 2; }
# Refuse to run without the base measurement: {B}, {P} and {G}'s recorded set are not
# things this script may invent.
[[ -f "$base" ]] || { echo "ac009: $base is absent — 009's base measurement is not optional"; exit 2; }
jq -e '(.testIds|type=="array") and (.P|type=="number") and (.siblingGates|type=="array")' "$base" > /dev/null 2>&1 \
  || { echo "ac009: $base does not carry testIds, P and siblingGates"; exit 2; }

for v in $(env | sed -n 's/^\(SP1_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

# ---------------------------------------------------------------- manifest ----
# Columns: AC, kind, selector, command, tests, evidence. Multi-space separated.
manifest() {
  awk '
    /^```ac009-manifest$/ { inb = 1; next }
    inb && /^```/         { inb = 0; next }
    !inb                  { next }
    /^[[:space:]]*#/      { next }
    /^[[:space:]]*$/      { next }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      n = split(line, f, /  +/)
      if (n < 6) { printf "ac009: unparsable manifest row: %s\n", line > "/dev/stderr"; exit 2 }
      ev = f[6]
      for (i = 7; i <= n; i++) ev = ev " " f[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], f[5], ev
    }
  ' "$spec"
}
row_for() { manifest | awk -F'\t' -v ac="$1" '$1 == ac { print; found = 1 } END { exit !found }'; }

# ---------------------------------------------------------------- tokens ------
sha16() { shasum -a 256 | cut -c1-16; }
need() { [[ -f "$1" ]] || { echo "ac009: witness input missing: $1" >&2; exit 2; }; }

discovered_gates() {
  find "$here" -maxdepth 1 -type f -name 'ac[0-9][0-9][0-9].sh' \
    | sed 's|.*/||' | grep -v '^ac009\.sh$' | LC_ALL=C sort || true
}

param_for() {
  case "$1" in
    B) jq -r '.testIds | length' "$base" ;;
    P) jq -r '.P' "$base" ;;
    G) discovered_gates | wc -l | tr -d ' ' ;;
    # {S} — what a SIBLING task added to the forge suite after 009. Measured here,
    # by this runner, from the listing itself: 009's own no-skip cell used to pin the
    # total `{B}+16`, and task 005 (Arc/USDC) legitimately adds tests to the same
    # suite. §1.4 rule 2 — the value is measured, never transcribed — and the strength
    # the pinned total carried moved into xvm-no-skip.sh's clause 5, which requires
    # 009's own sixteen names to still be in the listing.
    S) local j; j=$(mktemp "${TMPDIR:-/tmp}/ac009-list.XXXXXX")
       (cd "$root/zk-verdict/contracts" && forge test --list --json) > "$j" 2>/dev/null || true
       local n; n=$(jq '[.[] | .[] | .[]] | length' "$j" 2>/dev/null || echo 0)
       rm -f "$j"
       echo $(( n - $(jq -r '.testIds | length' "$base") - 16 )) ;;
  esac
}

witness_for() {
  local fx="$root/zk-verdict/contracts/src/fixtures"
  case "$1" in
    AC-0b)
      local f1="$fx/reexec-groth16-fixture.json" f2="$fx/svm-groth16-fixture.json"
      need "$f1"; need "$f2"; need "$here/xvm.pinned"
      cat "$f1" "$f2" "$here/xvm.pinned" | sha16 ;;
    AC-7)
      need "$root/zk-verdict/contracts/src/RecknZkEscrow.sol"
      need "$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol"
      cat "$root/zk-verdict/contracts/src/RecknZkEscrow.sol" \
          "$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol" | sha16 ;;
    AC-9)
      local fs=(); while IFS= read -r f; do fs+=("$f"); done \
        < <(find "$root/zk-verdict/contracts/test" -maxdepth 1 -name '*.t.sol' | LC_ALL=C sort)
      [[ ${#fs[@]} -gt 0 ]] || { echo "ac009: no *.t.sol for AC-9's witness" >&2; exit 2; }
      cat "${fs[@]}" | sha16 ;;
    AC-10)
      # The glob is M-*.patch, NOT *.patch: a sibling task's patches share this
      # directory and must not enter 009's witness set, or every sibling commit
      # would move 009's evidence line.
      local fs=(); while IFS= read -r f; do fs+=("$f"); done \
        < <(find "$here/mutants" -maxdepth 1 -name 'M-*.patch' 2>/dev/null | LC_ALL=C sort)
      [[ ${#fs[@]} -gt 0 ]] || { echo "ac009: no mutants/M-*.patch for AC-10's witness" >&2; exit 2; }
      cat "${fs[@]}" | sha16 ;;
    AC-11)
      local fs=("$root/README.md" "$root/zk-verdict/README.md" "$root/AGENTS.md" "$root/CLAUDE.md")
      local f; for f in "${fs[@]}"; do need "$f"; done
      cat "${fs[@]}" | sha16 ;;
    AC-12)
      local gs=(); while IFS= read -r g; do gs+=("$here/$g"); done < <(discovered_gates)
      if [[ ${#gs[@]} -eq 0 ]]; then printf '' | sha16; else cat "${gs[@]}" | sha16; fi ;;
    *) echo "ac009: no witness recipe for $1" >&2; exit 2 ;;
  esac
}

# ---------------------------------------------------------------- row kinds ---
run_forge() {
  local ac=$1 selector=$2 want=$3 json
  json=$(mktemp "${TMPDIR:-/tmp}/ac009-forge.XXXXXX")
  if ! (cd "$root/zk-verdict/contracts" && forge test --match-test "$selector" --json) > "$json" 2>/dev/null; then
    rm -f "$json"; echo "$ac: forge test exited non-zero"; return 1
  fi
  if ! jq -e . "$json" > /dev/null 2>&1; then
    rm -f "$json"; echo "$ac: forge produced no JSON — no test matched '$selector'"; return 1
  fi
  if ! jq -e --argjson n "$want" '
        [.[].test_results | to_entries[]] as $t
        | ($t | length) == $n
          and ([$t[] | select(.value.status != "Success")] | length) == 0' "$json" > /dev/null; then
    rm -f "$json"; echo "$ac: forge did not report exactly $want successful tests for $selector"; return 1
  fi
  rm -f "$json"
  echo "$ac: forge $selector — $want tests, all Success"
}

run_script() {
  local ac=$1 cmd=$2 evidence=$3 out expected rc=0
  local t
  for t in B P G S; do
    if [[ "$evidence" == *"{$t}"* ]]; then
      local v; v=$(param_for "$t")
      evidence=${evidence//\{$t\}/$v}
    fi
  done
  if [[ "$evidence" == *"{witness}"* ]]; then
    local w; w=$(witness_for "$ac")
    expected=${evidence//\{witness\}/$w}
  else
    # AC-0 is the written exemption (§7.2): its evidence line is AGENTS.md §0's
    # declared output and 009 must not restyle it.
    if [[ "$ac" != "AC-0" ]]; then
      echo "$ac: evidence line carries no {witness} and is not the written exemption"; return 1
    fi
    expected=$evidence
  fi
  out=$(cd "$root" && bash -c "$cmd" 2>&1) || rc=$?
  if [[ $rc -ne 0 ]]; then echo "$out" | tail -10; echo "$ac: '$cmd' exited $rc"; return 1; fi
  if ! grep -qF -- "$expected" <<<"$out"; then
    echo "$ac: stdout does not contain the evidence line"
    echo "  expected: $expected"
    echo "  got:      $(echo "$out" | tail -1)"
    return 1
  fi
  echo "$ac: $expected"
}

run_row() {
  local ac=$1 line kind selector cmd tests evidence
  line=$(row_for "$ac") || { echo "ac009: no manifest row for $ac"; return 2; }
  IFS=$'\t' read -r _ kind selector cmd tests evidence <<<"$line"
  case "$kind" in
    forge)  run_forge  "$ac" "$selector" "$tests" ;;
    script) run_script "$ac" "$cmd" "$evidence" ;;
    *)      echo "ac009: unknown kind '$kind' for $ac"; return 2 ;;
  esac
}

# ---------------------------------------------------------------- --check -----
check_arithmetic() {
  local rows forge_rows forge_tests script_rows script_witness fail=0
  rows=$(manifest | wc -l | tr -d ' ')
  forge_rows=$(manifest | awk -F'\t' '$2=="forge"' | wc -l | tr -d ' ')
  forge_tests=$(manifest | awk -F'\t' '$2=="forge" {s+=$5} END {print s+0}')
  script_rows=$(manifest | awk -F'\t' '$2=="script"' | wc -l | tr -d ' ')
  script_witness=$(manifest | awk -F'\t' '$2=="script" && $6 ~ /\{witness\}/' | wc -l | tr -d ' ')
  expect() {
    if [[ "$2" == "$3" ]]; then printf '  ok   %-26s %s\n' "$1" "$2"
    else printf '  FAIL %-26s %s (spec says %s)\n' "$1" "$2" "$3"; fail=1; fi
  }
  expect "manifest rows"      "$rows"           13
  expect "forge rows"         "$forge_rows"     6
  expect "forge tests"        "$forge_tests"    16
  expect "script rows"        "$script_rows"    7
  expect "script witness="    "$script_witness" 6

  # §7.8 — the naming gate, applied to this document's own names, read from the
  # fenced block and from nowhere else.
  local names bad=0 n=0
  names=$(awk '/^```ac009-testnames$/{f=1;next} f&&/^```/{exit} f{print}' "$spec")
  while IFS= read -r nm; do
    [[ -n "$nm" ]] || continue
    n=$((n + 1))
    [[ "$nm" =~ ^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$ ]] || { printf '  FAIL name %s\n' "$nm"; bad=1; }
  done <<<"$names"
  expect "mandated test names" "$n" 16
  [[ $bad -eq 0 ]] || fail=1
  local sel
  for sel in "AC-1 01 2" "AC-2 02 4" "AC-3 03 2" "AC-4 04 2" "AC-5 05 3" "AC-6 06 3"; do
    set -- $sel
    expect "names for $1" "$(printf '%s\n' "$names" | grep -c "^test_AC$2_" || true)" "$3"
  done
  [[ $fail -eq 0 ]] || { echo "ac009: --check FAILED"; return 1; }
  echo "ac009: manifest arithmetic and the naming gate check out"
}

# ---------------------------------------------------------------- canary ------
canary() {
  # §7.4. Applied by THIS script, in a sandbox: M-4c appends an unused `immutable`
  # to a copy of RecknZkEscrow.sol and AC-7's script, run against the copy, must
  # exit non-zero. No repository file is written.
  local S; S=$(mktemp -d "${TMPDIR:-/tmp}/ac009-canary.XXXXXX")
  mkdir -p "$S/zk-verdict/scripts" "$S/zk-verdict/contracts/src"
  cp "$here/escrow-shape.sh" "$S/zk-verdict/scripts/"
  cp "$root/zk-verdict/contracts/src/RecknZkEscrow.sol" \
     "$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol" "$S/zk-verdict/contracts/src/"
  if ! (cd /tmp && bash "$S/zk-verdict/scripts/escrow-shape.sh") > /dev/null 2>&1; then
    echo "ac009: CANARY FAILED (the clean sandbox copy did not pass)"; rm -rf "$S"; return 1
  fi
  python3 - "$S/zk-verdict/contracts/src/RecknZkEscrow.sol" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.rindex('}')
open(p, 'w').write(s[:i] + "    bytes32 public immutable unused;\n" + s[i:])
PY
  local rc=0
  (cd /tmp && bash "$S/zk-verdict/scripts/escrow-shape.sh") > /dev/null 2>&1 || rc=$?
  rm -rf "$S"
  [[ $rc -ne 0 ]] || { echo "ac009: CANARY FAILED (AC-7 survived M-4c)"; return 1; }
  return 0
}

run_all() {
  local ran=0 failed=0 ac
  while IFS= read -r ac; do
    ran=$((ran + 1))
    run_row "$ac" || failed=$((failed + 1))
  done < <(manifest | cut -f1)
  [[ $ran -eq 13 ]] || { echo "ac009: ran $ran rows, the manifest has 13"; return 1; }
  [[ $failed -eq 0 ]] || { echo "ac009: $failed/13 rows failed"; return 1; }
  canary || return 1
  echo "ac009: 13/13 rows passed; canary M-4c detected by AC-7"
}

case "${1:---all}" in
  --check) check_arithmetic ;;
  --all)   run_all ;;
  AC-*)    run_row "$1" ;;
  *)       echo "usage: ac009.sh [--check | --all | AC-n]"; exit 2 ;;
esac

#!/usr/bin/env bash
# The 005 acceptance gate. The manifest is parsed out of the ```ac005-manifest``` block
# of docs/specs/005-arc-usdc-settlement.md §7.1, so the document and the gate cannot
# drift apart.
#
#   bash zk-verdict/scripts/ac005.sh --check   # manifest arithmetic and the id set
#   bash zk-verdict/scripts/ac005.sh AC-2      # one row
#   bash zk-verdict/scripts/ac005.sh --all     # every row
#
# `--all` is the entry point both-green.sh calls on a sibling; 009's AC-12 discovers
# this file by pattern, so adding it moves 009's evidence line with no edit to 009.
#
# Tokens: {N} (ids in the §7.1 ac005-tests block), {L}, {R}, {C} — all MEASURED here,
# by this runner, from the same sources the row's command reads and never by invoking
# that command — and {witness} (§7.2).
#
# Location rule: root comes from this file's own path — no argument, no environment
# override, no absolute path, no `git rev-parse`.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
spec="$root/docs/specs/005-arc-usdc-settlement.md"
rec="$root/zk-verdict/contracts/arc.json"
[[ -f "$spec" ]] || { echo "missing $spec"; exit 2; }
[[ -f "$rec" ]]  || { echo "ac005: missing $rec — the Arc record is not optional"; exit 2; }

for v in $(env | sed -n 's/^\(SP1_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

# ---------------------------------------------------------------- manifest ----
manifest() {
  awk '
    /^```ac005-manifest$/ { inb = 1; next }
    inb && /^```/         { inb = 0; next }
    !inb                  { next }
    /^[[:space:]]*#/      { next }
    /^[[:space:]]*$/      { next }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      n = split(line, f, /  +/)
      if (n < 6) { printf "ac005: unparsable manifest row: %s\n", line > "/dev/stderr"; exit 2 }
      ev = f[6]
      for (i = 7; i <= n; i++) ev = ev " " f[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], f[5], ev
    }
  ' "$spec"
}
row_for() { manifest | awk -F'\t' -v ac="$1" '$1 == ac { print; found = 1 } END { exit !found }'; }

want_tests() {
  awk '/^```ac005-tests$/ { inb = 1; next } inb && /^```/ { inb = 0; next }
       inb && NF { print $1 }' "$spec"
}

sha16() { shasum -a 256 | cut -c1-16; }

# ---------------------------------------------------------------- scans -------
# Recomputed here rather than read out of the row's own output. If this scan and the
# checker's scan disagree, the row is red — which is the point: two implementations of
# the same question, and no way to satisfy both by editing one.
scan_links() {
  grep -rhoE 'testnet\.arcscan\.app/tx/0x[0-9a-fA-F]+' \
    --include='*.md' --include='*.html' --include='*.sh' --include='*.json' \
    "$root" 2>/dev/null | sed 's#.*/tx/##' | LC_ALL=C sort -u || true
}
scan_consts() {
  grep -rhoE '\b504[0-9]{4}\b|0x3600[0-9a-fA-F]{36}|https://(rpc\.testnet\.arc\.io|testnet\.arcscan\.app|faucet\.circle\.com)' \
    --include='*.md' --include='*.html' --include='*.sh' --include='*.sol' --include='*.json' \
    "$root" 2>/dev/null | LC_ALL=C sort -u || true
}
nonempty_lines() { grep -c . || true; }

param_for() {
  case "$1" in
    N) want_tests | wc -l | tr -d ' ' ;;
    R) jq -r '.deployedByReckn.settlements | length' "$rec" ;;
    L) scan_links  | nonempty_lines | tr -d ' ' ;;
    C) scan_consts | nonempty_lines | tr -d ' ' ;;
  esac
}

witness_for() {
  case "$1" in
    AC-2) jq -r '.deployedByReckn.settlements[].tx' "$rec" | LC_ALL=C sort | sha16 ;;
    AC-3) jq -r '.testnet | .chainId, .usdcErc20, .rpc, .explorer, .faucet' "$rec" | sha16 ;;
    *) echo "ac005: no witness recipe for $1" >&2; exit 2 ;;
  esac
}

expand() {
  local e=$1 ac=$2 t
  for t in N R L C; do
    if [[ "$e" == *"{$t}"* ]]; then e=${e//\{$t\}/$(param_for "$t")}; fi
  done
  if [[ "$e" == *"{witness}"* ]]; then e=${e//\{witness\}/$(witness_for "$ac")}; fi
  printf '%s' "$e"
}

# ---------------------------------------------------------------- row kinds ---
run_forge() {
  local ac=$1 selector=$2 json
  json=$(mktemp "${TMPDIR:-/tmp}/ac005-forge.XXXXXX")
  if ! (cd "$root/zk-verdict/contracts" && forge test --match-test "$selector" --json) > "$json" 2>/dev/null; then
    rm -f "$json"; echo "$ac: forge test exited non-zero"; return 1
  fi
  # `forge test --match-test` exits 0 when NOTHING matches, so the listing is checked,
  # never the exit status alone.
  if ! jq -e . "$json" > /dev/null 2>&1; then
    rm -f "$json"; echo "$ac: forge produced no JSON — no test matched '$selector'"; return 1
  fi
  local names total
  names=$(jq -r '[.[].test_results | to_entries[]] | .[] | .key' "$json" | sed 's/(.*//' | LC_ALL=C sort -u)
  total=$(printf '%s\n' "$names" | nonempty_lines | tr -d ' ')
  # A SET, not a count: deleting one required test and adding an unrelated one keeps
  # the total at seven, and must still fail.
  local missing=0 t n hit
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    hit=0
    while IFS= read -r n; do [[ "$n" == "$t" ]] && hit=1; done <<< "$names"
    [[ $hit -eq 1 ]] || { echo "$ac: required test absent from the suite: $t"; missing=1; }
  done < <(want_tests)
  if ! jq -e '[.[].test_results | to_entries[] | .value.status] | length > 0 and all(. == "Success")' \
        "$json" > /dev/null 2>&1; then
    jq -r '.[].test_results | to_entries[] | select(.value.status != "Success") | "    " + .key + " -> " + .value.status' "$json"
    rm -f "$json"; echo "$ac: not every matched test succeeded"; return 1
  fi
  rm -f "$json"
  [[ $missing -eq 0 ]] || return 1
  echo "forge ${selector}_ — $total tests, all Success"
}

run_row() {
  local line ac kind selector cmd tests ev got exp
  line=$(row_for "$1") || { echo "ac005: no such row: $1" >&2; exit 2; }
  IFS=$'\t' read -r ac kind selector cmd tests ev <<< "$line"
  exp=$(expand "$ev" "$ac")
  case "$kind" in
    forge)  got=$(run_forge "$ac" "$selector") || { echo "$got"; return 1; } ;;
    script) got=$( (cd "$root" && eval "$cmd") 2>&1 | tail -1 ) || { echo "$ac: command exited non-zero"; return 1; } ;;
    *) echo "ac005: unknown row kind '$kind'" >&2; exit 2 ;;
  esac
  if [[ "$got" != "$exp" ]]; then
    echo "$ac: evidence mismatch"
    echo "    expected: $exp"
    echo "    actual:   $got"
    return 1
  fi
  echo "$ac: $got"
}

case "${1:---all}" in
  --check)
    n=$(manifest | wc -l | tr -d ' ')
    t=$(param_for N)
    [[ "$t" -eq 7 ]] || { echo "ac005: the ac005-tests block lists $t ids, not 7"; exit 1; }
    echo "ac005: manifest $n rows, $t required test ids, $(param_for R) recorded settlements"
    ;;
  --all)
    fail=0
    while IFS= read -r ac; do run_row "$ac" || fail=1; done < <(manifest | cut -f1)
    n=$(manifest | wc -l | tr -d ' ')
    [[ $fail -eq 0 ]] || { echo "ac005: at least one row failed"; exit 1; }
    echo "ac005: $n/$n rows passed"
    ;;
  *) run_row "$1" ;;
esac

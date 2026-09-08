#!/usr/bin/env bash
# The 011 acceptance gate. The manifest is parsed out of the ```ac011-manifest``` block of
# docs/specs/011-tempo-tip20-slice.md §7.1, so the document and the gate cannot drift apart.
#
#   bash zk-verdict/scripts/ac011.sh --check   # manifest arithmetic and the id set
#   bash zk-verdict/scripts/ac011.sh AC-4      # one row
#   bash zk-verdict/scripts/ac011.sh --all     # every row
#
# `--all` is the entry point both-green.sh calls on a sibling. 009's AC-12 discovers this
# file by pattern, so adding it moves 009's evidence line with no edit to 009: {G} and its
# witness are computed live there, and the recorded siblingGates set is an INCLUSION
# requirement, so a new gate is discovered rather than rejected.
#
# THIS GATE MUST NEVER CALL both-green.sh. both-green runs every acNNN.sh it finds, and
# 009's AC-12 runs both-green; a call from here would be an unbounded loop through the whole
# harness. 009 excludes itself from the closure for the same reason.
#
# Every token is MEASURED HERE, by this runner, from the same sources the row's command
# reads and never by invoking that command — two implementations of one question, and no way
# to satisfy both by editing one. §7.1.1 of the spec lists them and states the limit: these
# rows check that each checker's output tracks its inputs, not that its internals are sound.
#
# UNLIKE its siblings, several rows here READ THE NETWORK — 011's claims are half on-chain
# and a gate that checked only the local half would be checking the easy half. A network
# failure is therefore a FAILURE, not a skip: a criterion that is satisfied by breaking your
# own observer is not a criterion (R-9). The message distinguishes "the chain disagrees" from
# "the chain could not be reached" so the operator knows which, but both are red.
#
# Location rule: root comes from this file's own path — no argument, no environment
# override, no absolute path, no `git rev-parse`.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
spec="$root/docs/specs/011-tempo-tip20-slice.md"
rec="$root/zk-verdict/contracts/tempo.json"
arc="$root/zk-verdict/contracts/arc.json"
art="$root/zk-verdict/contracts/out/RecknZkEscrow.sol/RecknZkEscrow.json"
[[ -f "$spec" ]] || { echo "missing $spec"; exit 2; }
[[ -f "$rec" ]]  || { echo "ac011: missing $rec — the Tempo record is not optional"; exit 2; }
[[ -f "$arc" ]]  || { echo "ac011: missing $arc — {ARC} exists so this gate cannot compare Tempo with itself"; exit 2; }

for v in $(env | sed -n 's/^\(SP1_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

# ---------------------------------------------------------------- manifest ----
manifest() {
  awk '
    /^```ac011-manifest$/ { inb = 1; next }
    inb && /^```/         { inb = 0; next }
    !inb                  { next }
    /^[[:space:]]*#/      { next }
    /^[[:space:]]*$/      { next }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      n = split(line, f, /  +/)
      if (n < 6) { printf "ac011: unparsable manifest row: %s\n", line > "/dev/stderr"; exit 2 }
      ev = f[6]
      for (i = 7; i <= n; i++) ev = ev " " f[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], f[5], ev
    }
  ' "$spec"
}
row_for() { manifest | awk -F'\t' -v ac="$1" '$1 == ac { print; found = 1 } END { exit !found }'; }
want_tests() {
  awk '/^```ac011-tests$/ { inb = 1; next } inb && /^```/ { inb = 0; next }
       inb && NF { print $1 }' "$spec"
}
# The assumptions the escrow makes about a token are a claim of the SPECIFICATION. Taking
# them from the probe would be asking the checker to grade itself: the first version counted
# `record(` calls in the probe, and deleting a check moved both numbers together and stayed
# green. Provoked, observed, and rewritten.
want_assumptions() {
  awk '/^```ac011-assumptions$/ { inb = 1; next } inb && /^```/ { inb = 0; next }
       inb && NF { print }' "$spec"
}
sha16() { shasum -a 256 | cut -c1-16; }
nonempty_lines() { grep -c . || true; }

# ---------------------------------------------------------------- scans -------
# Recomputed here rather than read out of a row's own output. If this scan and the checker's
# scan disagree, the row is red — which is the point.
files=(--include='*.md' --include='*.html' --include='*.sh' --include='*.sol' --include='*.json' --include='*.js'
       --exclude-dir=out --exclude-dir=cache --exclude-dir=lib --exclude-dir=broadcast
       --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=target)

scan_consts() {
  # Deliberately the SAME pattern tempo-constants.sh uses. Copying it is the weakest link
  # here and is preferable to the alternative: a different pattern would make the two
  # disagree for reasons that are about regexes rather than about the tree.
  grep -rhoE 'https://[a-z.]*moderato\.tempo\.xyz[a-z.]*|0x20[Ff]c[0-9a-fA-F]{36}|0x20[Cc]0[0-9a-fA-F]{36}' \
    "${files[@]}" "$root" 2>/dev/null | LC_ALL=C sort -u || true
}
scan_links() {
  local host; host=$(jq -r '.testnet.explorer' "$rec" | sed 's#https://##')
  grep -rhoE "$host/tx/0x[0-9a-fA-F]+" "${files[@]}" "$root" 2>/dev/null \
    | sed 's#.*/tx/##' | LC_ALL=C sort -u || true
}
# The same classification tempo-receipts.sh performs, written again. A 32-byte value is a
# transaction hash because the record LABELS it one — never because of its shape.
classify() {
  jq -r 'paths(strings and test("^0x[0-9a-fA-F]{64}$")) as $p
         | (($p | map(select(type=="string")) | last)) as $k
         | (if ($k == "failedTx") then "failed-tx"
            elif ($k == "tx" or $k == "settleTx" or ($k | startswith("exampleType"))) then "tx"
            elif ($k | test("[Cc]odehash|vkey|[Bb]inding|dealId|output|programVKey")) then "not-a-tx"
            else "UNCLASSIFIED" end) + "\t" + getpath($p)' "$rec"
}

# ---------------------------------------------------------------- tokens ------
param_for() {
  case "$1" in
    N)     want_tests | nonempty_lines | tr -d ' ' ;;
    C)     scan_consts | nonempty_lines | tr -d ' ' ;;
    L)     scan_links  | nonempty_lines | tr -d ' ' ;;
    CHAIN) jq -r '.testnet.chainId' "$rec" ;;
    RPC)   jq -r '.testnet.rpc' "$rec" ;;
    ARC)   jq -r '.testnet.chainId' "$arc" ;;
    S)     jq -r '[.deployedByReckn.run.steps[]? | select(.step | test("^settle")) | .tx // empty] | unique | length' "$rec" ;;
    K)     classify | sed -n 's/^tx\t//p' | LC_ALL=C sort -u | nonempty_lines | tr -d ' ' ;;
    F)     classify | sed -n 's/^failed-tx\t//p' | LC_ALL=C sort -u | nonempty_lines | tr -d ' ' ;;
    D)     jq -r '.deployedByReckn.verified.cases | length' "$rec" ;;
    V)     jq -r '[.deployedByReckn.verified.cases[] | select(.settled)] | length' "$rec" ;;
    H)     [[ -f "$art" ]] || { echo "ac011: $art is absent — run forge build" >&2; exit 2; }
           cast keccak "$(jq -r '.deployedBytecode.object' "$art")" ;;
    A)     want_assumptions | nonempty_lines | tr -d ' ' ;;
    *)     echo "ac011: no recipe for token $1" >&2; exit 2 ;;
  esac
}

witness_for() {
  case "$1" in
    # The same recipe tempo-receipts.sh uses, over the same classified set.
    AC-3) classify | sed -n 's/^tx\t//p' | LC_ALL=C sort -u | sha16 ;;
    # Read out of the RECORD, against a script that derives the same digest from the CHAIN.
    # They agree only if the record still describes what is deployed.
    AC-4) jq -r '.deployedByReckn.verified.cases[] | "\(.dealId) \(.settleTx // "-")"' "$rec" \
            | LC_ALL=C sort | sha16 ;;
    *) echo "ac011: no witness recipe for $1" >&2; exit 2 ;;
  esac
}

expand() {
  local e=$1 ac=$2 t
  for t in N C L CHAIN RPC ARC S K F D V H A; do
    if [[ "$e" == *"{$t}"* ]]; then e=${e//\{$t\}/$(param_for "$t")}; fi
  done
  if [[ "$e" == *"{witness}"* ]]; then e=${e//\{witness\}/$(witness_for "$ac")}; fi
  printf '%s' "$e"
}

# ---------------------------------------------------------------- row kinds ---
run_forge() {
  local ac=$1 selector=$2 json
  json=$(mktemp "${TMPDIR:-/tmp}/ac011-forge.XXXXXX")
  if ! (cd "$root/zk-verdict/contracts" && forge test --match-test "$selector" --json) > "$json" 2>/dev/null; then
    rm -f "$json"; echo "$ac: forge test exited non-zero"; return 1
  fi
  # `forge test --match-test` exits 0 when NOTHING matches, so the listing is checked, never
  # the exit status alone. An implementation with no tests would otherwise be green.
  if ! jq -e . "$json" > /dev/null 2>&1; then
    rm -f "$json"; echo "$ac: forge produced no JSON — no test matched '$selector'"; return 1
  fi
  local names total missing=0 t n hit
  names=$(jq -r '[.[].test_results | to_entries[]] | .[] | .key' "$json" | sed 's/(.*//' | LC_ALL=C sort -u)
  total=$(printf '%s\n' "$names" | nonempty_lines | tr -d ' ')
  # A SET, not a count: deleting one required test and adding an unrelated one keeps the
  # total at eight, and must still fail.
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

# The command's own exit status, kept. Piping straight into `tail` hands the pipeline tail's
# status, so a checker that exits 1 is reported only if its last line also fails to match —
# which is true here but is a defence by luck rather than by construction.
run_script() {
  local ac=$1 cmd=$2 out rc
  out=$(mktemp "${TMPDIR:-/tmp}/ac011-script.XXXXXX")
  set +e
  # RECKN_NO_WRITE: a gate must not dirty the tree it is judging. tempo-verify.sh and
  # tempo-tip20-probe.sh rewrite their records on every run, which is right for a tool and
  # wrong for a row -- ac009's AC-12 watches the working tree for movement during a run, so
  # a sibling that moves it makes the parent unable to tell drift from defect. Observed
  # 2026-09-08: AC-12 went red and ac009 correctly refused to say whether that was real.
  (cd "$root" && RECKN_NO_WRITE=1 eval "$cmd") > "$out" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "$ac: \`$cmd\` exited $rc"
    if grep -qiE 'could not|curl|timed out|Connection|resolve|no receipt|did not estimate' "$out"; then
      echo "    this reads like the chain could not be REACHED rather than the chain disagreeing."
      echo "    It is still a failure: 011's claims are half on-chain, and a gate that skipped"
      echo "    them when the network hiccups would be checking only the easy half."
    fi
    tail -12 "$out" | sed 's/^/    /'
    rm -f "$out"; return 1
  fi
  tail -1 "$out"
  rm -f "$out"
}

run_row() {
  local line ac kind selector cmd tests ev got exp
  line=$(row_for "$1") || { echo "ac011: no such row: $1" >&2; exit 2; }
  IFS=$'\t' read -r ac kind selector cmd tests ev <<< "$line"
  exp=$(expand "$ev" "$ac")
  # AC-7 is a set, not a count, for the same reason AC-1 is: swapping one assumption for
  # another keeps the total and must still fail.
  if [[ "$ac" == "AC-7" ]]; then
    local a miss=0
    while IFS= read -r a; do
      [[ -n "$a" ]] || continue
      grep -qF "record(\"$a\"" "$here/tempo-tip20-probe.sh" \
        || { echo "$ac: the spec requires an assumption the probe does not check: $a"; miss=1; }
    done < <(want_assumptions)
    [[ $miss -eq 0 ]] || return 1
  fi
  case "$kind" in
    forge)  got=$(run_forge "$ac" "$selector")  || { echo "$got"; return 1; } ;;
    script) got=$(run_script "$ac" "$cmd")      || { echo "$got"; return 1; } ;;
    *) echo "ac011: unknown row kind '$kind'" >&2; exit 2 ;;
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
    # Double entry: the manifest's own count for AC-1 against the ids in the tests block.
    declared=$(manifest | awk -F'\t' '$1=="AC-1" { print $5 }')
    [[ "$t" -eq "$declared" ]] || { echo "ac011: the ac011-tests block lists $t ids, the manifest declares $declared"; exit 1; }
    echo "ac011: manifest $n rows, $t required test ids, $(param_for D) recorded deals, $(param_for K) recorded tx hashes"
    ;;
  --all)
    fail=0
    while IFS= read -r ac; do run_row "$ac" || fail=1; done < <(manifest | cut -f1)
    n=$(manifest | wc -l | tr -d ' ')
    [[ $fail -eq 0 ]] || { echo "ac011: at least one row failed"; exit 1; }
    echo "ac011: $n/$n rows passed"
    ;;
  *) run_row "$1" ;;
esac

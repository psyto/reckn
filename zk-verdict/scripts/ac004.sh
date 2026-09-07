#!/usr/bin/env bash
# The 004 acceptance gate. The manifest is parsed out of the ```ac004-manifest``` block of
# docs/specs/004-live-adversarial-input.md §0.6.2.1, so the document and the gate cannot
# drift apart.
#
#   bash zk-verdict/scripts/ac004.sh --check   # manifest arithmetic
#   bash zk-verdict/scripts/ac004.sh AC-3      # one row
#   bash zk-verdict/scripts/ac004.sh --all     # every row — what both-green.sh calls
#
# The `live` rows draw their SEED FROM /dev/urandom on every run. A seed pinned in the
# manifest would put the input set back into the document, and a finite published input
# set is passed by a lookup table — the defect §6.1 of the spec exists to name. The
# evidence line carries counts and outcomes, never the seed, so the inputs change every
# run while the evidence stays stable.
#
# Location rule: root comes from this file's own path — no argument, no environment
# override, no absolute path, no `git rev-parse` (which walks out of a sandbox into the
# real repository).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
spec="$root/docs/specs/004-live-adversarial-input.md"
bin="$root/reckn-live/target/release/reckn-live"
[[ -f "$spec" ]] || { echo "missing $spec"; exit 2; }

for v in $(env | sed -n 's/^\(SP1_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

manifest() {
  awk '
    /^```ac004-manifest$/ { inb = 1; next }
    inb && /^```/         { inb = 0; next }
    !inb                  { next }
    /^[[:space:]]*#/      { next }
    /^[[:space:]]*$/      { next }
    {
      line = $0; sub(/[[:space:]]+$/, "", line)
      n = split(line, f, /  +/)
      # columns: AC | kind | selector | command | tests | evidence…
      if (n < 6) { printf "ac004: unparsable manifest row: %s\n", line > "/dev/stderr"; exit 2 }
      ev = f[6]; for (i = 7; i <= n; i++) ev = ev " " f[i]
      printf "%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[4], f[5], ev
    }
  ' "$spec"
}
row_for() { manifest | awk -F'\t' -v ac="$1" '$1 == ac { print; found = 1 } END { exit !found }'; }

sha16() { shasum -a 256 | cut -c1-16; }
seed()  { od -An -N8 -tu8 < /dev/urandom | tr -d ' \n'; }

witness_for() {
  case "$1" in
    AC-NC) shasum -a 256 "$root/reckn-live/src/main.rs" | cut -c1-16 ;;
    *) echo "ac004: no witness recipe for $1" >&2; exit 2 ;;
  esac
}

build() { (cd "$root/reckn-live" && cargo build --release --quiet) 2>/dev/null; }

run_row() {
  local line ac kind cmd n ev got exp
  line=$(row_for "$1") || { echo "ac004: no such row: $1" >&2; exit 2; }
  IFS=$'\t' read -r ac kind cmd n ev <<< "$line"
  exp=${ev//\{D\}/3}
  if [[ "$exp" == *"{witness}"* ]]; then exp=${exp//\{witness\}/$(witness_for "$ac")}; fi
  case "$kind" in
    live)
      build || { echo "$ac: reckn-live does not build"; return 1; }
      got=$( (cd "$root/reckn-live" && "$bin" $cmd --seed "$(seed)") 2>&1 | grep -E '^gate=.*ran=' | tail -1 ) \
        || { echo "$ac: reckn-live exited non-zero"; return 1; } ;;
    script)
      got=$( (cd "$root" && eval "$cmd") 2>&1 | tail -1 ) \
        || { echo "$ac: command exited non-zero"; return 1; } ;;
    *) echo "ac004: unknown row kind '$kind'" >&2; exit 2 ;;
  esac
  if [[ "$got" != "$exp" ]]; then
    echo "$ac: evidence mismatch"; echo "    expected: $exp"; echo "    actual:   $got"; return 1
  fi
  echo "$ac: $got"
}

case "${1:---all}" in
  --check)
    n=$(manifest | wc -l | tr -d ' ')
    [[ "$n" -eq 4 ]] || { echo "ac004: the manifest has $n rows, not 4"; exit 1; }
    echo "ac004: manifest $n rows"
    ;;
  --all)
    fail=0
    while IFS= read -r ac; do run_row "$ac" || fail=1; done < <(manifest | cut -f1)
    [[ $fail -eq 0 ]] || { echo "ac004: at least one row failed"; exit 1; }
    echo "ac004: 4/4 rows passed"
    ;;
  *) run_row "$1" ;;
esac

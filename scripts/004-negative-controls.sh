#!/usr/bin/env bash
# 004 — the negative controls. This is the only thing in the task that shows the gates
# would go RED if the implementation were wrong, and 004's specification says so in §6.1:
# a black-box acceptance criterion over a finite, published input set is passed by a
# lookup table, so the gates alone prove less than they look like they prove.
#
# Each control mutates the tree IN PLACE under `trap restore EXIT INT TERM`, runs the row
# that claims to guard the break, and requires it to exit non-zero. A control that is
# clean on the unmutated copy first, so a permanently-red gate cannot masquerade as a
# detection.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
crate="$root/reckn-live"
src="$crate/src/main.rs"
backup=$(mktemp "${TMPDIR:-/tmp}/004-nc.XXXXXX")
cp "$src" "$backup"
restore() { cp "$backup" "$src"; rm -f "$backup"; }
trap restore EXIT INT TERM

detected=0
want=3
say() { printf '004-nc: %s\n' "$*"; }
bad() { printf '004-nc: FAIL %s\n' "$*"; }
fail=0

build() { (cd "$crate" && cargo build --release --quiet) 2>/dev/null; }
run()   { (cd "$crate" && ./target/release/reckn-live "$@") > /dev/null 2>&1; }

# 0 — the controls must be green before anything is broken, or "it went red" means
#     nothing. This is the step that catches a harness that is simply broken.
build || { bad "the clean tree does not build"; exit 1; }
run --prose-invariance --seed 1 || { bad "prose-invariance is not green on the clean tree"; exit 1; }
run --gas-seeded --seed 7      || { bad "gas-seeded is not green on the clean tree"; exit 1; }
say "clean tree: both rows green"

# NC-1 — the claim reaches the re-execution. This is the whole failure mode 004 exists to
#        rule out: if prose can touch the replay input, the record moves with the prose.
cp "$backup" "$src"
python3 - "$src" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
a="        let got = reexec_json(&f, delivered)?;"
b="        let got = reexec_json(&f, delivered + claim.len() as u64)?;"
assert s.count(a)==1, "NC-1 anchor moved"
open(p,"w").write(s.replace(a,b,1))
PY
build || { bad "NC-1 did not compile — refusing to evaluate with a stale binary"; exit 1; }
if run --prose-invariance --seed 1; then
  bad "NC-1: the claim reached the re-execution and prose-invariance stayed green"
  fail=1
else
  detected=$((detected+1)); say "NC-1 prose-invariance detected"
fi

# NC-26 — the analytic gas formula is decorative. Drop the opcode term and the row must
#         notice; this exact term was missing on the first run, off by 8.
cp "$backup" "$src"
python3 - "$src" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
a="    intrinsic + OPCODES_BUT_SSTORE + 2_100 + sstore"
b="    intrinsic + 2_100 + sstore"
assert s.count(a)==1, "NC-26 anchor moved"
open(p,"w").write(s.replace(a,b,1))
PY
build || { bad "NC-26 did not compile — refusing to evaluate with a stale binary"; exit 1; }
if run --gas-seeded --seed 7; then
  bad "NC-26: the gas formula was wrong by 8 and gas-seeded stayed green"
  fail=1
else
  detected=$((detected+1)); say "NC-26 gas-seeded detected"
fi

# NC-25 — the gate PRETENDS. Its body is replaced by the COUNT CONTRACT lines and nothing
#         else, which passes `check-counts` because that compares strings the checked
#         program printed about itself. No row catches this. What catches it is that NC-1
#         then stops being detected — so this control is composed, not direct.
cp "$backup" "$src"
python3 - "$src" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
i=s.index("    let f = fixed();\n    // One amount, fixed")
j=s.index("fn gas_seeded(")
# everything from the fixture setup to the end of the function becomes the two COUNT
# CONTRACT lines and nothing else — the exact shape `check-counts` cannot tell apart
# from a gate that did the work.
open(p,"w").write(s[:i] + "    count_close(\"prose-invariance\", N);\n    Ok(())\n}\n\n" + s[j:])
PY
build || { bad "NC-25 did not compile — refusing to evaluate with a stale binary"; exit 1; }
if run --prose-invariance --seed 1; then
  # It passes, as predicted. Now apply NC-1 on top: a gate that runs nothing cannot
  # detect anything, and THAT is the observable.
  python3 - "$src" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
open(p,"w").write(s.replace("let delivered = 6_000_000u64;","let delivered = 6_000_001u64;",1))
PY
  build || { bad "NC-25+NC-1 did not compile — refusing to evaluate with a stale binary"; exit 1; }
  if run --prose-invariance --seed 1; then
    detected=$((detected+1))
    say "NC-25 detected (a print-only gate passes, and then fails to detect NC-1 — which is the point)"
  else
    bad "NC-25: the print-only body somehow still detected a mutation"
    fail=1
  fi
else
  bad "NC-25: a body that only prints the COUNT CONTRACT lines did not pass — the harness changed"
  fail=1
fi

restore; trap - EXIT INT TERM
build || { bad "the tree does not build after restore"; fail=1; }
run --prose-invariance --seed 1 || { bad "prose-invariance is not green after restore"; fail=1; }

w=$(shasum -a 256 "$src" | cut -c1-16)
say "$detected/$want controls detected; witness=$w"
[[ $fail -eq 0 && $detected -eq $want ]] || exit 1

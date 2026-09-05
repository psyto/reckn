#!/usr/bin/env bash
# AC-14 — the documents moved in the same commit as the code.
#
# Five checks, all over content. No digests, no line numbers: a line number goes
# stale the moment a paragraph moves, and a digest over a section three agents edit
# measures calendar noise rather than the obligation.
#
#   (i)   nine stale claims are ABSENT      — each a fixed string in a named file
#   (ii)  eleven replacements are PRESENT   — the marker substrings of §9
#   (iii) no tilde cycle literal survives   — over the fixed doc set
#   (iv)  every published cycle figure is one of three MEASURED integers, and the
#         measurement is re-run here against a freshly built ELF
#   (v)   the `~34 s` figure is qualified in place, and there is exactly one of it
#
# Check (iv) runs all three guests. That is the point: a figure this file blesses
# has been produced by the ELF in the tree, not copied from a previous run.
#
# Location rule, as in surfaces.sh: root comes from this file's own path and from
# nothing else — no argument, no environment override, no absolute path, no git.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
cycles_json="$root/zk-verdict/cycles.json"

for v in $(env | sed -n 's/^\(SP1_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

doc_set=(README.md CLAUDE.md SUBMISSION.md zk-verdict/README.md docs/cross-chain-settlement.md)
fail=0
note() { printf '  %s\n' "$*"; }

# ---------------------------------------------------------------- (i) absent --
# file <TAB> literal. Nine of them; all nine were present before 008 touched them.
absent_want=9
absent_ok=0
while IFS=$'\t' read -r f lit; do
  [[ -n "$f" ]] || continue
  if grep -qF -- "$lit" "$root/$f"; then
    note "STILL PRESENT  $f: $lit"; fail=1
  else
    absent_ok=$((absent_ok + 1))
  fi
done <<'LITERALS'
README.md	The `u64` verdict boundary is a soundness bug
README.md	is UNVERIFIED
AGENTS.md	`u64_low` は limb 0 のみ
AGENTS.md	`c-kzg` / `ecrecover` precompile は in-guest で無効
zk-verdict/README.md	the `c-kzg`/`ecrecover` precompiles are disabled
zk-verdict/README.md	to `u64` to reuse the on-chain ABI
zk-verdict/program-revm/src/main.rs	Values map to `u64` to reuse
zk-verdict/README.md	stays gated on the fixture's presence
scripts/no-keys.sh	the body of `contract RecknZkEscrow` only
LITERALS

# ---------------------------------------------------------------- (ii) present -
present_want=11
present_ok=0
while IFS=$'\t' read -r f marker; do
  [[ -n "$f" ]] || continue
  if grep -qF -- "$marker" "$root/$f"; then
    present_ok=$((present_ok + 1))
  else
    note "MISSING        $f: $marker"; fail=1
  fi
done <<'MARKERS'
zk-verdict/README.md	at the committed hardfork and block environment
zk-verdict/README.md	Verdict values are `uint256`.
zk-verdict/README.md	Engine identity is checked, not assumed.
AGENTS.md	旧 `u64` マップは制限ではなく健全性バグだった
AGENTS.md	precompile は in-guest でも
README.md	In-guest precompiles run on different backends, and parity is unverified
zk-verdict/README.md	a missing fixture is a hard failure
zk-verdict/README.md	a floor of zero is satisfied by doing nothing
zk-verdict/README.md	the gnark wrap alone
AGENTS.md	RecknVerdictVerifier.sol
CLAUDE.md	RecknVerdictVerifier.sol
MARKERS

# ---------------------------------------------------------------- (iii) tildes -
# The `\*{0,2}` is load-bearing: `~**410k cycles**` puts markdown bold between the
# tilde and the digit, and the obvious `~[0-9]` misses two of the fourteen sites.
tildes=$( (cd "$root" && grep -hoE '~\*{0,2}[0-9]+(\.[0-9]+)?k' "${doc_set[@]}" || true) | wc -l | tr -d ' ')
if [[ "$tildes" != "0" ]]; then
  note "TILDE FIGURES  $tildes surviving:"
  (cd "$root" && grep -noE '~\*{0,2}[0-9]+(\.[0-9]+)?k' "${doc_set[@]}" | sed 's/^/    /')
  fail=1
fi

# ---------------------------------------------------------------- (iv) measured -
[[ -f "$cycles_json" ]] || { echo "missing $cycles_json"; exit 2; }
guests_ok=0
guests_want=3
declare_measured=""
for g in verdict reexec svm; do
  want_cycles=$(jq -r ".cycles.$g" "$cycles_json")
  want_elf=$(jq -r ".elf_sha256.$g" "$cycles_json")
  elf_path=$(jq -r ".elf_path.$g" "$cycles_json")
  out=$(cd "$root/zk-verdict/script" && cargo run --release --bin "$g" -- --execute 2>&1) || {
    note "GUEST FAILED   $g did not execute"; fail=1; continue; }
  got_cycles=$(echo "$out" | sed -n 's/.*cycles: \([0-9][0-9]*\).*/\1/p' | tail -1)
  if [[ -z "$got_cycles" ]]; then note "GUEST FAILED   $g printed no cycle count"; fail=1; continue; fi
  if [[ ! -f "$root/$elf_path" ]]; then note "ELF MISSING    $elf_path"; fail=1; continue; fi
  got_elf=$(shasum -a 256 "$root/$elf_path" | cut -d' ' -f1)
  if [[ "$got_cycles" != "$want_cycles" ]]; then
    note "CYCLES MOVED   $g: measured $got_cycles, cycles.json says $want_cycles"; fail=1; continue; fi
  if [[ "$got_elf" != "$want_elf" ]]; then
    note "ELF MOVED      $g: built $got_elf, cycles.json says $want_elf"; fail=1; continue; fi
  guests_ok=$((guests_ok + 1))
  declare_measured="$declare_measured $(printf "%'d" "$want_cycles")"
done

# Every published "N cycles" site must be one of the three measured integers.
while IFS= read -r site; do
  [[ -n "$site" ]] || continue
  n=${site%% cycles}
  found=0
  for m in $declare_measured; do [[ "$m" == "$n" ]] && found=1; done
  [[ $found -eq 1 ]] || { note "UNMEASURED     '$site' is not one of the measured figures"; fail=1; }
done < <( (cd "$root" && grep -hoE '[0-9][0-9,]{4,} cycles' "${doc_set[@]}" || true) | sort -u)

# ---------------------------------------------------------------- (v) ~34 s ----
s34=$( (grep -cF -- '~34 s' "$root/zk-verdict/README.md" || true) | tr -d ' ')
qualified=0
if [[ "$s34" != "1" ]]; then
  note "~34 s SITES    $s34 (must be exactly 1: do not delete it, do not add a second)"; fail=1
elif grep -A2 -F -- '~34 s' "$root/zk-verdict/README.md" | grep -qF -- 'the gnark wrap alone'; then
  qualified=1
else
  note "~34 s UNQUALIFIED — the bare figure reads ~10x flattering against the 335 s end-to-end"; fail=1
fi

# ---------------------------------------------------------------- evidence ----
witness=$( (cd "$root" && cat "${doc_set[@]}" "zk-verdict/cycles.json" "scripts/no-keys.sh") \
           | shasum -a 256 | cut -c1-16)
echo "docs: $absent_ok/$absent_want stale claims absent, $present_ok/$present_want replacements present, $tildes tilde cycle literals, $qualified/1 qualified ~34 s site, cycles.json matches $guests_ok/$guests_want guests; witness=$witness"
[[ $fail -eq 0 ]] || exit 1

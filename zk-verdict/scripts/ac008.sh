#!/usr/bin/env bash
# The 008 acceptance gate. One runner, one manifest, three kinds of row.
#
# The manifest is NOT duplicated here: it is parsed out of the ```ac008-manifest
# block of `docs/specs/008-verdict-domain-soundness.md` §6.1, so the document and
# the gate cannot drift apart.
#
#   bash zk-verdict/scripts/ac008.sh --check   # manifest arithmetic only, no runs
#   bash zk-verdict/scripts/ac008.sh AC-02     # one row
#   bash zk-verdict/scripts/ac008.sh --all     # every row, then the §6.3 canary
#
# Row contract (§6.0), in one sentence per kind:
#   cargo  — the count is asserted BEFORE success: `--list` must name exactly N
#            tests, then the run must show N passed, 0 failed, 0 ignored.
#   forge  — `forge test` has no --fail-on-no-tests in 1.7.1, so the count is
#            asserted from --json.
#   script — exit 0 AND stdout contains the evidence line, with `{witness}`
#            replaced by a digest THIS script recomputes from repository bytes
#            (§6.2). The recomputation never invokes the row's command, so a row
#            that prints a constant goes stale the moment a witnessed byte moves.
#
# Location rule, as in `surfaces.sh`: root is derived from this file's own path
# and from nothing else — no argument, no environment override, no absolute path,
# no `git rev-parse` (which would walk out of a sandbox into the real repository).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)          # …/zk-verdict/scripts
root=$(cd "$here/../.." && pwd)              # repository root, derived, never given
spec="$root/docs/specs/008-verdict-domain-soundness.md"

[[ -f "$spec" ]] || { echo "missing $spec"; exit 2; }

# §3.6.4 — no skip variable may silence a guest build under this gate.
for v in $(env | sed -n 's/^\(SP1_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done

# ---------------------------------------------------------------- manifest ----
# Columns: AC, kind, dir, selector (the command, for `script` rows), tests,
# evidence. Multi-space separated; `#` starts a comment.
manifest() {
  awk '
    /^```ac008-manifest$/ { inb = 1; next }
    inb && /^```/         { inb = 0; next }
    !inb                  { next }
    /^[[:space:]]*#/      { next }
    /^[[:space:]]*$/      { next }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      n = split(line, f, /  +/)
      if (n < 6) { printf "ac008: unparsable manifest row: %s\n", line > "/dev/stderr"; exit 2 }
      ev = f[6]
      for (i = 7; i <= n; i++) ev = ev " " f[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], f[5], ev
    }
  ' "$spec"
}

row_for() {
  manifest | awk -F'\t' -v ac="$1" '$1 == ac { print; found = 1 } END { exit !found }'
}

# ---------------------------------------------------------------- witnesses ---
# §6.2. Each recipe is the exact repository bytes the row's claim is about,
# concatenated in the order the spec writes them, sha256'd, first 8 bytes.
# A recipe that cannot be computed FAILS; it never falls back to a constant.
sha_raw() { shasum -a 256 "$1" | cut -d' ' -f1 | tr -d '\n' | xxd -r -p; }
head_raw() { head -710 "$1" | shasum -a 256 | cut -d' ' -f1 | tr -d '\n' | xxd -r -p; }
need()    { [[ -f "$1" ]] || { echo "ac008: witness input missing: $1" >&2; exit 2; }; }
digest16() { shasum -a 256 | cut -c1-16; }

witness_for() {
  local ac=$1
  case "$ac" in
    AC-00b)
      need "$root/zk-verdict/contracts/src/RecknZkEscrow.sol"; need "$root/reexec-evm/src/lib.rs"
      { sha_raw "$root/zk-verdict/contracts/src/RecknZkEscrow.sol"
        head_raw "$root/reexec-evm/src/lib.rs"; } | digest16
      ;;
    AC-06)
      local fs=("$root/zk-verdict/program-revm/src/main.rs" "$root/zk-verdict/lib/src/lib.rs" \
                "$root/zk-verdict/script/src/lib.rs" "$root/reexec-evm/src/lib.rs")
      local f; for f in "${fs[@]}"; do need "$f"; done
      cat "${fs[@]}" | digest16
      ;;
    AC-09)
      # Recipe: the four freshly-computed ELF vkeys (in AC-9's fixture order) ‖ the
      # four fixture files. The vkeys come from `--vkey`, a cheap setup-only mode of
      # the three bins — NOT from fixtures-check.sh, which §6.2 forbids this
      # recomputation from invoking.
      local fx="$root/zk-verdict/contracts/src/fixtures"
      local files=("$fx/groth16-fixture.json" "$fx/reexec-groth16-fixture.json"                    "$fx/reexec-falserelease-fixture.json" "$fx/svm-groth16-fixture.json")
      local f; for f in "${files[@]}"; do need "$f"; done
      vkey_of() { (cd "$root/zk-verdict/script" && cargo run --release --quiet --bin "$1" -- --vkey) 2>/dev/null                   | sed -n 's/^vkey: //p' | tail -1; }
      local vk_evm vk_reexec vk_svm
      vk_evm=$(vkey_of evm); vk_reexec=$(vkey_of reexec); vk_svm=$(vkey_of svm)
      for f in "$vk_evm" "$vk_reexec" "$vk_svm"; do
        [[ "$f" =~ ^0x[0-9a-f]{64}$ ]] || { echo "ac008: could not compute a vkey for AC-09's witness" >&2; exit 2; }
      done
      { for v in "$vk_evm" "$vk_reexec" "$vk_reexec" "$vk_svm"; do
          printf '%s' "${v#0x}" | xxd -r -p
        done
        cat "${files[@]}"; } | digest16
      ;;
    AC-11)
      local fs=(); while IFS= read -r f; do fs+=("$f"); done \
        < <(find "$root/zk-verdict/contracts/test" -maxdepth 1 -name '*.t.sol' | LC_ALL=C sort)
      [[ ${#fs[@]} -gt 0 ]] || { echo "ac008: no *.t.sol found for AC-11's witness" >&2; exit 2; }
      cat "${fs[@]}" | digest16
      ;;
    AC-13)
      local fs=(); while IFS= read -r f; do fs+=("$f"); done \
        < <(find "$root/zk-verdict/scripts/mutants" -maxdepth 1 -name '*.patch' 2>/dev/null | LC_ALL=C sort)
      [[ ${#fs[@]} -gt 0 ]] || { echo "ac008: no mutants/*.patch found for AC-13's witness" >&2; exit 2; }
      cat "${fs[@]}" | digest16
      ;;
    AC-14)
      local fs=("$root/README.md" "$root/CLAUDE.md" "$root/SUBMISSION.md" \
                "$root/zk-verdict/README.md" "$root/docs/cross-chain-settlement.md" \
                "$root/zk-verdict/cycles.json" "$root/scripts/no-keys.sh")
      local f; for f in "${fs[@]}"; do need "$f"; done
      cat "${fs[@]}" | digest16
      ;;
    AC-16)
      need "$root/reexec-evm/src/lib.rs"
      local fs=("$root/binder/Cargo.toml" "$root/keeper/Cargo.toml" \
                "$root/reckn-evm-content/Cargo.toml" "$root/binder/tests/router_two_vms.rs")
      local f; for f in "${fs[@]}"; do need "$f"; done
      { sha_raw "$root/reexec-evm/src/lib.rs"; cat "${fs[@]}"; } | digest16
      ;;
    *)
      echo "ac008: no witness recipe for $ac" >&2; exit 2 ;;
  esac
}

# ---------------------------------------------------------------- row kinds ---
run_cargo() {
  local ac=$1 dir=$2 selector=$3 want=$4 out listed passed
  local -a filter=()
  [[ "$selector" == "-" ]] || filter=("$selector")

  listed=$(cd "$root/$dir" && cargo test -- --list ${filter[@]+"${filter[@]}"} 2>/dev/null | grep -c ': test$' || true)
  if [[ "$listed" != "$want" ]]; then
    echo "$ac: --list names $listed tests, manifest says $want"; return 1
  fi

  if ! out=$(cd "$root/$dir" && cargo test -- ${filter[@]+"${filter[@]}"} 2>&1); then
    echo "$out" | tail -20; echo "$ac: cargo test exited non-zero"; return 1
  fi

  local lines; lines=$(echo "$out" | grep '^test result:' || true)
  [[ -n "$lines" ]] || { echo "$ac: no 'test result:' line in cargo output"; return 1; }
  passed=$(echo "$lines" | sed -n 's/.*result: ok\. \([0-9]*\) passed.*/\1/p' | paste -sd+ - | bc)
  if [[ "${passed:-0}" != "$want" ]]; then
    echo "$ac: ${passed:-0} passed, manifest says $want"; return 1
  fi
  if echo "$lines" | grep -qv '0 failed'; then echo "$ac: a test failed"; return 1; fi
  if echo "$lines" | grep -qv '0 ignored'; then echo "$ac: a test is #[ignore]d"; return 1; fi
  echo "$ac: cargo $dir $selector — $passed passed, 0 failed, 0 ignored"
}

run_forge() {
  local ac=$1 selector=$2 want=$3 json
  json=$(mktemp "${TMPDIR:-/tmp}/ac008-forge.XXXXXX")
  if ! (cd "$root/zk-verdict/contracts" && forge test --match-test "$selector" --json) > "$json" 2>/dev/null; then
    rm -f "$json"; echo "$ac: forge test exited non-zero"; return 1
  fi
  # forge 1.7.1 prints "No tests found in project!" and exits 0 when the selector
  # matches nothing — the exact hole §6.0 makes every row assert a count for.
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
  if [[ "$evidence" == *"{witness}"* ]]; then
    local w; w=$(witness_for "$ac")
    expected=${evidence//\{witness\}/$w}
  else
    # §6.0: exempt only where §6.2 says so in writing. AC-00 is the one.
    if [[ "$ac" != "AC-00" ]]; then
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
  local ac=$1 line kind dir selector tests evidence
  line=$(row_for "$ac") || { echo "ac008: no manifest row for $ac"; return 2; }
  IFS=$'\t' read -r _ kind dir selector tests evidence <<<"$line"
  case "$kind" in
    cargo)  run_cargo  "$ac" "$dir" "$selector" "$tests" ;;
    forge)  run_forge  "$ac" "$selector" "$tests" ;;
    script) run_script "$ac" "$selector" "$evidence" ;;
    *)      echo "ac008: unknown kind '$kind' for $ac"; return 2 ;;
  esac
}

# ---------------------------------------------------------------- --check -----
check_arithmetic() {
  local rows criteria cargo_rows cargo_tests forge_rows forge_tests script_rows script_witness fail=0
  rows=$(manifest | wc -l | tr -d ' ')
  criteria=$(manifest | cut -f1 | sed -e 's/^AC-00b$/AC-00/' -e 's/^AC-07[ab]$/AC-07/' | sort -u | wc -l | tr -d ' ')
  cargo_rows=$(manifest | awk -F'\t' '$2=="cargo"' | wc -l | tr -d ' ')
  cargo_tests=$(manifest | awk -F'\t' '$2=="cargo" {s+=$5} END {print s+0}')
  forge_rows=$(manifest | awk -F'\t' '$2=="forge"' | wc -l | tr -d ' ')
  forge_tests=$(manifest | awk -F'\t' '$2=="forge" {s+=$5} END {print s+0}')
  script_rows=$(manifest | awk -F'\t' '$2=="script"' | wc -l | tr -d ' ')
  script_witness=$(manifest | awk -F'\t' '$2=="script" && $6 ~ /\{witness\}/' | wc -l | tr -d ' ')

  expect() { # name got want
    if [[ "$2" == "$3" ]]; then printf '  ok   %-28s %s\n' "$1" "$2"
    else printf '  FAIL %-28s %s (spec says %s)\n' "$1" "$2" "$3"; fail=1; fi
  }
  expect "manifest rows"        "$rows"           18
  expect "acceptance criteria"  "$criteria"       16
  expect "cargo rows"           "$cargo_rows"     8
  expect "cargo tests"          "$cargo_tests"    91
  expect "forge rows"           "$forge_rows"     2
  expect "forge tests"          "$forge_tests"    6
  expect "script rows"          "$script_rows"    8
  expect "script witness=       " "$script_witness" 7
  local pkg
  for pkg in "zk-verdict/lib 11" "zk-verdict/script 64" "reexec-evm 16"; do
    set -- $pkg
    expect "cargo tests in $1" "$(manifest | awk -F'\t' -v d="$1" '$2=="cargo" && $3==d {s+=$5} END {print s+0}')" "$2"
  done
  [[ $fail -eq 0 ]] || { echo "ac008: --check FAILED"; return 1; }
  echo "ac008: manifest arithmetic checks out"
}

# ---------------------------------------------------------------- --all -------
canary() {
  # §6.3. Applied by THIS script, not by ac008-selftest.sh: a stubbed selftest
  # must not be able to make the whole gate green.
  local target="$root/zk-verdict/program-revm/src/main.rs"
  local patch="$root/zk-verdict/scripts/mutants/09-restore-u64low.patch"
  local copy before after
  [[ -f "$patch" ]] || { echo "ac008: CANARY FAILED (missing $patch)"; return 1; }
  copy=$(mktemp "${TMPDIR:-/tmp}/ac008-canary.XXXXXX")
  cp "$target" "$copy"                                             # c1
  restore() { cp "$copy" "$target"; rm -f "$copy"; }
  trap restore EXIT INT TERM
  before=$(shasum -a 256 "$target" | cut -d' ' -f1)
  (cd "$root" && patch -p1 --batch --forward < "$patch") > /dev/null || {  # c2
    echo "ac008: CANARY FAILED (M-9 did not apply)"; return 1; }
  after=$(shasum -a 256 "$target" | cut -d' ' -f1)
  [[ "$after" != "$before" ]] || { echo "ac008: CANARY FAILED (M-9 changed nothing)"; return 1; }  # c3
  local rc=0
  bash "$here/ac008.sh" AC-06 > /dev/null 2>&1 || rc=$?              # c4
  restore; trap - EXIT INT TERM                                      # c5
  [[ "$(shasum -a 256 "$target" | cut -d' ' -f1)" == "$before" ]] || {
    echo "ac008: CANARY FAILED (restore did not restore)"; return 1; }
  [[ $rc -ne 0 ]] || { echo "ac008: CANARY FAILED (AC-06 survived M-9)"; return 1; }
  return 0
}

run_all() {
  local ran=0 failed=0 ac
  while IFS= read -r ac; do
    ran=$((ran + 1))
    run_row "$ac" || failed=$((failed + 1))
  done < <(manifest | cut -f1)
  [[ $ran -eq 18 ]] || { echo "ac008: ran $ran rows, the manifest has 18"; return 1; }
  [[ $failed -eq 0 ]] || { echo "ac008: $failed/18 rows failed"; return 1; }
  canary || return 1                                                  # c6
  echo "ac008: 18/18 rows passed; canary M-9 detected by AC-06"
}

case "${1:---all}" in
  --check) check_arithmetic ;;
  --all)   run_all ;;
  AC-*)    run_row "$1" ;;
  *)       echo "usage: ac008.sh [--check | --all | AC-nn]"; exit 2 ;;
esac

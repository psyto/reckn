#!/usr/bin/env bash
# AC-10 — the gate detects a WRONG implementation.
#
# Fifteen mutations, each applied to a SANDBOX COPY of the layout. No repository file
# is written at any point: every phase builds its own $S, proves the clean copy
# passes, mutates the copy, requires the rows that claim to guard the mutation to
# exit non-zero, and removes the sandbox with `rm -rf`.
#
# Read this before trusting it (L-10): AC-10's own row has no mutant, because a
# mutant on the selftest would be evaluated by the selftest. §7.4's canary moves one
# detection onto ac009.sh — a different script every other row depends on — and the
# rest rests on a person opening this file and running it. That is a person, not a
# mechanism, and it is said here rather than only in §9.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
mutants="$here/mutants"
want_mutants=15

detected=0
controls=0
fail=0
t0=$(python3 -c 'import time;print(int(time.time()))')
now() { python3 -c 'import time;print(int(time.time()))'; }
say() { printf 'ac009-selftest: %s\n' "$*"; }
bad() { printf 'ac009-selftest: FAIL %s\n' "$*"; fail=1; }

have=$(ls "$mutants"/M-*.patch 2>/dev/null | wc -l | tr -d ' ')
[[ "$have" == "$want_mutants" ]] || { echo "ac009-selftest: $have M-*.patch, expected $want_mutants"; exit 1; }
# 009's half of the shared-directory protocol: the whole glob, siblings included.
pop=$(ls "$mutants"/*.patch 2>/dev/null | wc -l | tr -d ' ')
base_p=$(jq -r '.P' "$here/xvm.base.json")
[[ "$pop" == "$((base_p + want_mutants))" ]] || bad "mutants dir holds $pop patches, {P}+15 = $((base_p + 15)) expected"

# A full sandbox: 009's scripts, both contracts, the suite, the four documents and the
# spec ac009.sh parses. `lib/` is symlinked rather than copied — 17 MB per phase would
# be the whole cost of this row — and nothing ever writes into it.
sandbox_new() {
  local S; S=$(mktemp -d "${TMPDIR:-/tmp}/ac009-sbx.XXXXXX")
  mkdir -p "$S/scripts" "$S/zk-verdict/scripts" "$S/zk-verdict/contracts" "$S/docs/specs"
  cp "$root/scripts/no-keys.sh" "$S/scripts/"
  cp "$here"/*.sh "$here/xvm.pinned" "$here/xvm.base.json" "$S/zk-verdict/scripts/"
  # Strip sibling gates by the SAME CLOSURE both-green.sh discovers with, not by name.
  # These two builders used to delete `ac008.sh` and `ac008-selftest.sh` literally.
  # When task 005 landed a gate on 2026-09-06 a second sibling appeared in the
  # scripts-only sandbox, both-green ran it against a tree that has no contracts and
  # no arc.json, and the CONTROL went red — "a target row was not green on the clean
  # copy" — so M-13's mutant never got evaluated at all. R-7 in this repository's own
  # words: a check that one new name defeats is not a check. This one was the harness
  # for the very row that tests a closure.
  find "$S/zk-verdict/scripts" -maxdepth 1 -type f \
    \( -name 'ac[0-9][0-9][0-9].sh' -o -name 'ac[0-9][0-9][0-9]-selftest.sh' \) \
    ! -name 'ac009.sh' ! -name 'ac009-selftest.sh' -delete
  cp -R "$mutants" "$S/zk-verdict/scripts/mutants"
  cp "$root/docs/specs/009-cross-vm-settlement.md" "$S/docs/specs/"
  cp "$root/README.md" "$root/CLAUDE.md" "$root/AGENTS.md" "$S/"
  mkdir -p "$S/zk-verdict"
  cp "$root/zk-verdict/README.md" "$S/zk-verdict/"
  cp "$root/zk-verdict/contracts/foundry.toml" "$root/zk-verdict/contracts/remappings.txt" "$S/zk-verdict/contracts/"
  cp -R "$root/zk-verdict/contracts/src" "$root/zk-verdict/contracts/test" "$S/zk-verdict/contracts/"
  ln -s "$root/zk-verdict/contracts/lib" "$S/zk-verdict/contracts/lib"
  printf '%s' "$S"
}

# M-13 only: scripts alone, and a base file that records no sibling gates — so the
# control measures "0 discovered" and the mutant measures "1 discovered, and it is
# actually RUN". A full sandbox would run a sibling's entire suite inside this row.
sandbox_scripts_only() {
  local S; S=$(mktemp -d "${TMPDIR:-/tmp}/ac009-sbx13.XXXXXX")
  mkdir -p "$S/zk-verdict/scripts" "$S/docs/specs"
  cp "$here"/*.sh "$here/xvm.pinned" "$S/zk-verdict/scripts/"
  # Strip sibling gates by the SAME CLOSURE both-green.sh discovers with, not by name.
  # These two builders used to delete `ac008.sh` and `ac008-selftest.sh` literally.
  # When task 005 landed a gate on 2026-09-06 a second sibling appeared in the
  # scripts-only sandbox, both-green ran it against a tree that has no contracts and
  # no arc.json, and the CONTROL went red — "a target row was not green on the clean
  # copy" — so M-13's mutant never got evaluated at all. R-7 in this repository's own
  # words: a check that one new name defeats is not a check. This one was the harness
  # for the very row that tests a closure.
  find "$S/zk-verdict/scripts" -maxdepth 1 -type f \
    \( -name 'ac[0-9][0-9][0-9].sh' -o -name 'ac[0-9][0-9][0-9]-selftest.sh' \) \
    ! -name 'ac009.sh' ! -name 'ac009-selftest.sh' -delete
  # ac009.sh parses its manifest out of the spec and refuses to run without it; the
  # spec is not a mutation target here, it is the runner's input.
  cp "$root/docs/specs/009-cross-vm-settlement.md" "$S/docs/specs/"
  jq '.siblingGates = []' "$here/xvm.base.json" > "$S/zk-verdict/scripts/xvm.base.json"
  printf '%s' "$S"
}

# $1 name, $2 sandbox builder, $3.. target rows
run_mutant() {
  local name=$1 builder=$2; shift 2
  local rows=("$@")
  local start; start=$(now)
  local patch="$mutants/$name.patch"
  [[ -f "$patch" ]] || { bad "$name: no patch"; return; }
  local S; S=$($builder)

  # control: every target row must be GREEN on the clean copy, or a phase that fails
  # for the wrong reason would be scored as a detection.
  local row ok=1
  for row in "${rows[@]}"; do
    (cd /tmp && bash "$S/zk-verdict/scripts/ac009.sh" "$row") > /dev/null 2>&1 || ok=0
  done
  if [[ $ok -ne 1 ]]; then bad "$name: a target row was not green on the clean copy — harness failure"; rm -rf "$S"; return; fi
  controls=$((controls + 1))
  say "sandbox control clean ($name) $(( $(now) - start ))s"

  if ! (cd "$S" && patch -p1 --batch --forward -d "$S" < "$patch") > /dev/null 2>&1; then
    bad "$name did not apply in the sandbox"; rm -rf "$S"; return
  fi

  local all=1 rc
  for row in "${rows[@]}"; do
    rc=0
    (cd /tmp && bash "$S/zk-verdict/scripts/ac009.sh" "$row") > /dev/null 2>&1 || rc=$?
    [[ $rc -ne 0 ]] || { bad "$name: $row stayed green under the mutant"; all=0; }
  done
  rm -rf "$S"
  if [[ $all -eq 1 ]]; then
    detected=$((detected + 1))
    say "$name ${rows[*]} detected (sandbox) $(( $(now) - start ))s"
  fi
}

# Cheapest first, so a broken harness fails in seconds.
run_mutant M-4a sandbox_new AC-0
run_mutant M-11 sandbox_new AC-0 AC-7
run_mutant M-4c sandbox_new AC-7
run_mutant M-6  sandbox_new AC-0b
run_mutant M-10 sandbox_new AC-11
run_mutant M-9  sandbox_new AC-9
run_mutant M-13 sandbox_scripts_only AC-12
run_mutant M-1  sandbox_new AC-2
run_mutant M-2  sandbox_new AC-5
run_mutant M-3  sandbox_new AC-4
run_mutant M-5  sandbox_new AC-2
run_mutant M-7  sandbox_new AC-1 AC-3
run_mutant M-8  sandbox_new AC-6 AC-7
run_mutant M-12 sandbox_new AC-6 AC-7
run_mutant M-4b sandbox_new AC-1 AC-3 AC-7

witness=$(cat $(ls "$mutants"/M-*.patch | LC_ALL=C sort) | shasum -a 256 | cut -c1-16)
say "$detected/$want_mutants mutants detected, $controls/$want_mutants sandbox controls clean, mutants dir $base_p+15; witness=$witness"
say "elapsed $(( $(now) - t0 ))s"
[[ $fail -eq 0 && "$detected" == "$want_mutants" && "$controls" == "$want_mutants" ]] || exit 1

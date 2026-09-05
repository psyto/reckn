#!/usr/bin/env bash
# AC-13 — the gate detects a WRONG implementation.
#
# Every other row asks "does the tree pass?". This one asks "would the tree fail if
# it were wrong?", by breaking the code twenty-one different ways and requiring the
# rows that claim to guard each break to go non-zero. A test body of `assert!(true)`
# passes its own row and dies here.
#
# Read this before trusting it (INV-14 case (c), L-3): this row's own witness is a
# constant for the whole run — no mutant edits a mutants/*.patch file — so the
# manifest row it satisfies is satisfiable by a two-line `echo`. Nothing in this
# repository closes that. §6.3's canary moves ONE detection onto ac008.sh, and the
# rest rests on a person reading and running this script. It is said here, at the
# top of the script carrying all the mutation weight, and not only in §8.
#
# Two modes. Fifteen mutants run IN TREE under `trap restore EXIT INT TERM`. Six run
# in a SANDBOX and never write a repository file: their asserted rows are AC-00 and
# AC-00b, which ARE the exit status of scripts/no-keys.sh and surfaces.sh, so
# asserting them non-zero in place would mean leaving the build condition red in the
# working tree while the gate runs.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
mutants="$here/mutants"
want_mutants=21

detected=0
fail=0
t0=$(python3 -c 'import time;print(int(time.time()))')
now() { python3 -c 'import time;print(int(time.time()))'; }
say() { printf 'ac008-selftest: %s\n' "$*"; }
bad() { printf 'ac008-selftest: FAIL %s\n' "$*"; fail=1; }

# 0. a deleted mutant fails this row.
have=$(ls "$mutants"/*.patch 2>/dev/null | wc -l | tr -d ' ')
[[ "$have" == "$want_mutants" ]] || { echo "ac008-selftest: $have mutants, expected $want_mutants"; exit 1; }

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
files_of() { grep -E '^\+\+\+ b/' "$1" | sed 's|^+++ b/||'; }

# ---------------------------------------------------------------- in tree ------
run_in_tree() {
  local name=$1; shift
  local patch="$mutants/$name.patch"
  local rows=("$@")
  local start; start=$(now)
  local tmp; tmp=$(mktemp -d "${TMPDIR:-/tmp}/ac008-mut.XXXXXX")
  local f before after
  local -a touched=()
  while IFS= read -r f; do touched+=("$f"); done < <(files_of "$patch")
  [[ ${#touched[@]} -gt 0 ]] || { bad "$name touches no file"; return; }

  # 1. byte copies FIRST, then the trap, then the patch.
  local i=0
  for f in "${touched[@]}"; do cp "$root/$f" "$tmp/$i"; i=$((i + 1)); done
  restore_now() {
    local j=0 g
    for g in "${touched[@]}"; do cp "$tmp/$j" "$root/$g"; j=$((j + 1)); done
  }
  trap 'restore_now; rm -rf "$tmp"' EXIT INT TERM

  before=$(sha "$root/${touched[0]}")
  if ! (cd "$root" && patch -p1 --batch --forward < "$patch") > /dev/null 2>&1; then
    bad "$name did not apply"; restore_now; rm -rf "$tmp"; trap - EXIT INT TERM; return
  fi
  after=$(sha "$root/${touched[0]}")
  if [[ "$before" == "$after" ]]; then
    bad "$name changed nothing"; restore_now; rm -rf "$tmp"; trap - EXIT INT TERM; return
  fi

  # 4. every row the mutant targets must go non-zero.
  local row rc all=1
  for row in "${rows[@]}"; do
    rc=0
    bash "$here/ac008.sh" "$row" > /dev/null 2>&1 || rc=$?
    [[ $rc -ne 0 ]] || { bad "$name: $row stayed green under the mutant"; all=0; }
  done

  # 5. restore, and prove the restore.
  restore_now
  rm -rf "$tmp"
  trap - EXIT INT TERM
  [[ "$(sha "$root/${touched[0]}")" == "$before" ]] || { bad "$name: restore did not restore"; return; }

  if [[ $all -eq 1 ]]; then
    detected=$((detected + 1))
    say "$name ${rows[*]} detected $(( $(now) - start ))s"
  fi
}

# ---------------------------------------------------------------- sandbox ------
# Each phase builds its OWN $S, so a phase never inherits another's mutation, and
# each runs a clean-copy control first: a script that fails in the sandbox for the
# wrong reason is a harness failure, not a detection.
sandbox_new() {
  local S; S=$(mktemp -d "${TMPDIR:-/tmp}/ac008-sbx.XXXXXX")
  mkdir -p "$S/scripts" "$S/zk-verdict/scripts" "$S/zk-verdict/contracts/src" "$S/reexec-evm/src"
  cp "$root/scripts/no-keys.sh" "$S/scripts/"
  cp "$root/zk-verdict/scripts/surfaces.sh" "$root/zk-verdict/scripts/surfaces.pinned" "$S/zk-verdict/scripts/"
  cp "$root/zk-verdict/contracts/src/RecknZkEscrow.sol" \
     "$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol" "$S/zk-verdict/contracts/src/"
  cp "$root/reexec-evm/src/lib.rs" "$S/reexec-evm/src/"
  printf '%s' "$S"
}

# $1 name  $2 script (surfaces|no-keys)  $3 assertion function
run_sandbox() {
  local name=$1 which=$2 assertion=$3
  local start; start=$(now)
  local patch="$mutants/$name.patch"
  local S; S=$(sandbox_new)
  local script out rc
  if [[ "$which" == "surfaces" ]]; then script="$S/zk-verdict/scripts/surfaces.sh"; else script="$S/scripts/no-keys.sh"; fi

  # control: the clean copy must pass.
  if ! (cd /tmp && bash "$script") > /dev/null 2>&1; then
    bad "$name: the clean sandbox copy did not pass — harness failure"; rm -rf "$S"; return
  fi
  say "sandbox control clean ($name) $(( $(now) - start ))s"

  if ! (cd "$S" && patch -p1 --batch --forward -d "$S" < "$patch") > /dev/null 2>&1; then
    bad "$name did not apply in the sandbox"; rm -rf "$S"; return
  fi
  rc=0
  out=$( (cd /tmp && bash "$script" 2>&1) ) || rc=$?
  if [[ $rc -eq 0 ]]; then
    bad "$name: the sandboxed script exited 0 — not detected"; rm -rf "$S"; return
  fi
  if ! "$assertion" "$S" "$out"; then rm -rf "$S"; return; fi
  rm -rf "$S"
  detected=$((detected + 1))
  say "$name $(sandbox_row "$name") detected (sandbox$(sandbox_note "$name")) $(( $(now) - start ))s"
}

sandbox_row() {
  case "$1" in
    08-escrow-comment|18-reexec-prefix-comment|20-pinned-digest-flip) echo "AC-00b" ;;
    *) echo "AC-00" ;;
  esac
}
sandbox_note() {
  case "$1" in
    19-verifier-drop-verifyproof) echo ", check 5 clause 5b/5d" ;;
    21-verifier-struct-permute)   echo ", check 5 clause 5f" ;;
    17-verifier-origin-branch)    echo ", check 5" ;;
    *) echo "" ;;
  esac
}

# The `computed:` field must equal the digest THIS script computes over the mutated
# copy. A surfaces.sh that greps for the flipped byte instead of hashing cannot
# produce that value, so a half-degenerate implementation is a miss, not a detection.
assert_computed_escrow() {
  local S=$1 out=$2
  local want; want=$(sha "$S/zk-verdict/contracts/src/RecknZkEscrow.sol")
  local got; got=$(printf '%s\n' "$out" | sed -n 's/^RecknZkEscrow.sol.*computed: //p' | tr -d ' ')
  [[ "$got" == "$want" ]] || { bad "computed: $got, the selftest's own digest is $want"; return 1; }
}
assert_computed_prefix() {
  local S=$1 out=$2
  local want; want=$(head -710 "$S/reexec-evm/src/lib.rs" | shasum -a 256 | cut -d' ' -f1)
  local got; got=$(printf '%s\n' "$out" | sed -n 's/^reexec-evm-prefix-710.*computed: //p' | tr -d ' ')
  [[ "$got" == "$want" ]] || { bad "computed: $got, the selftest's own prefix digest is $want"; return 1; }
}
# M-20 flips the PIN, so both targets are untouched: `computed:` must be the real,
# unchanged digest. A script carrying the pins in a heredoc matches its own literal
# and exits 0 — this is the only phase that sees it.
assert_pin_untouched() {
  local S=$1 out=$2
  local want; want=$(sha "$S/zk-verdict/contracts/src/RecknZkEscrow.sol")
  local got; got=$(printf '%s\n' "$out" | sed -n 's/^RecknZkEscrow.sol.*computed: //p' | tr -d ' ')
  [[ "$got" == "$want" ]] || { bad "M-20: computed: $got is not the unchanged target digest $want"; return 1; }
}
assert_clause() {
  local expect=$1 out=$2
  printf '%s\n' "$out" | grep -qE "✗ $expect" || { bad "check 5 named a different clause than $expect"; return 1; }
}
assert_check5_any() { assert_clause '5[a-f]:' "$2"; }
assert_check5_5f()  { assert_clause '5f:' "$2"; }
assert_check5_5b5d() {
  printf '%s\n' "$2" | grep -qE '✗ 5(b|d):' || { bad "M-19: check 5 named neither 5b nor 5d"; return 1; }
}

# ---------------------------------------------------------------- run order ----
# Zero-build first, so a broken harness fails in seconds.
run_sandbox 08-escrow-comment            surfaces assert_computed_escrow
run_sandbox 17-verifier-origin-branch    no-keys  assert_check5_any
run_sandbox 18-reexec-prefix-comment     surfaces assert_computed_prefix
run_sandbox 19-verifier-drop-verifyproof no-keys  assert_check5_5b5d
run_sandbox 20-pinned-digest-flip        surfaces assert_pin_untouched
run_sandbox 21-verifier-struct-permute   no-keys  assert_check5_5f

run_in_tree 09-restore-u64low   AC-06
run_in_tree 10-fixture-vkey     AC-09
run_in_tree 11-restore-skip-gate AC-11
run_in_tree 12-tilde-cycles     AC-14
run_in_tree 13-alt-binding-self AC-07b
run_in_tree 15-swap-record-fields AC-10
run_in_tree 02-const-reproduced AC-01 AC-12
run_in_tree 14-const-zk-outcome AC-08
run_in_tree 16-testkit-signature AC-16
run_in_tree 01-truncate         AC-02
run_in_tree 06-truncate-128     AC-02
run_in_tree 05-drop-blockenv    AC-03
run_in_tree 03-open-db          AC-04
run_in_tree 04-drop-envhash     AC-07a
run_in_tree 07-drop-checkhash   AC-07a

# 6. after the last restore, the tree must be exactly as it was found.
bash "$here/ac008.sh" AC-00b > /dev/null 2>&1 || bad "AC-00b is not green after the last restore"
bash "$root/scripts/no-keys.sh" > /dev/null 2>&1 || bad "no-keys.sh is not green after the last restore"

witness=$(cat $(ls "$mutants"/*.patch | LC_ALL=C sort) | shasum -a 256 | cut -c1-16)
say "$detected/$want_mutants mutants detected; witness=$witness"
say "elapsed $(( $(now) - t0 ))s"
[[ $fail -eq 0 && "$detected" == "$want_mutants" ]] || exit 1

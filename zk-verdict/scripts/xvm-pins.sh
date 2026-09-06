#!/usr/bin/env bash
# AC-0b — the two fixtures 009's claim rides on are the ones it was pinned against,
# and they are two DIFFERENT artefacts.
#
# The headline claim is "one escrow, two virtual machines". Nothing in a forge run
# distinguishes two copies of the same fixture under two names — the tests would pass
# — so the distinctness is asserted here, from the files, four ways: the digest, the
# vkey, the binding and the outcome. The two PATHS are literals of the spec (§7), so
# the claim cannot ride on a filename either.
#
# What this does NOT assert: that either fixture is the current guest's. That is
# 008's criterion over 008's ELF builds, and 009 builds no ELF (L-12).
#
# Location rule (§7.0): root from this file's own path, no argument, no environment
# variable, no absolute path, no `git rev-parse`.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
pinfile="$here/xvm.pinned"

want_paths=(
  "zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json"
  "zk-verdict/contracts/src/fixtures/svm-groth16-fixture.json"
)

[[ -f "$pinfile" ]] || { echo "missing $pinfile"; exit 2; }

fail=0
report() { printf '%s   pinned: %s   computed: %s\n' "$1" "$2" "$3"; fail=1; }

nlines=$(grep -c . "$pinfile" || true)
[[ "$nlines" == "2" ]] || { echo "xvm.pinned has $nlines lines; exactly 2 are permitted"; exit 1; }

i=0
vkeys=(); bindings=(); outcomes=()
while read -r path sha vkey binding outcome extra; do
  [[ -n "$path" ]] || continue
  if [[ -n "${extra:-}" ]]; then echo "xvm.pinned line $((i+1)) has more than five fields"; exit 1; fi
  if [[ "$path" != "${want_paths[$i]}" ]]; then
    report "path[$i]" "${want_paths[$i]}" "$path"
  fi
  f="$root/$path"
  if [[ ! -f "$f" ]]; then echo "missing $path"; fail=1; i=$((i+1)); continue; fi

  got_sha=$(shasum -a 256 "$f" | cut -d' ' -f1)
  [[ "sha256=$got_sha" == "$sha" ]] || report "$path sha256" "${sha#sha256=}" "$got_sha"

  got_vkey=$(jq -r '.vkey' "$f")
  got_binding=$(jq -r '.deal_binding' "$f")
  got_outcome=$(jq -r '.outcome' "$f")
  [[ "vkey=$got_vkey" == "$vkey" ]] || report "$path vkey" "${vkey#vkey=}" "$got_vkey"
  [[ "binding=$got_binding" == "$binding" ]] || report "$path binding" "${binding#binding=}" "$got_binding"
  [[ "outcome=$got_outcome" == "$outcome" ]] || report "$path outcome" "${outcome#outcome=}" "$got_outcome"

  vkeys+=("$got_vkey"); bindings+=("$got_binding"); outcomes+=("$got_outcome")
  i=$((i+1))
done < "$pinfile"

zero="0x0000000000000000000000000000000000000000000000000000000000000000"
if [[ ${#vkeys[@]} -eq 2 ]]; then
  [[ "${vkeys[0]}" != "${vkeys[1]}" ]] || { echo "the two fixtures carry the SAME vkey — one guest, not two"; fail=1; }
  [[ "${bindings[0]}" != "${bindings[1]}" ]] || { echo "the two fixtures carry the SAME binding"; fail=1; }
  for v in "${vkeys[@]}" "${bindings[@]}"; do
    [[ "$v" != "$zero" ]] || { echo "a pinned value is zero"; fail=1; }
  done
  for o in "${outcomes[@]}"; do
    [[ "$o" == "0" ]] || { echo "a fixture is not Reproduced (outcome $o)"; fail=1; }
  done
fi

witness=$( { cat "$root/${want_paths[0]}" "$root/${want_paths[1]}"; cat "$pinfile"; } \
           | shasum -a 256 | cut -c1-16)
echo "xvm-pins: 2/2 fixtures match the pin, vkeys distinct, bindings distinct, both Reproduced; witness=$witness"
[[ $fail -eq 0 ]] || exit 1

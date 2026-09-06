#!/usr/bin/env bash
# AC-12 — 009 is not green in a tree where a sibling gate is red.
#
# The 9/9 checkpoint requires 008 and 009 green AT THE SAME TIME. Every other
# criterion in 009 is satisfiable in a tree where a sibling's gate is red, and
# confirming each gate green in turn, on different trees, does not satisfy the word
# *simultaneously*. This row is the only thing that tests it.
#
# The discovery rule is a CLOSURE, not a name: this script does not know that 008
# exists. It takes every file beside it whose basename matches ^ac[0-9]{3}\.sh$
# except its own runner. A task numbered 010 is discovered on the commit that adds
# it, with no edit here. A sibling that ships its dispatcher under a name that does
# not match is a fact this cannot see — L-17.
#
# It calls no form of ac009.sh, so ac009.sh --all -> AC-12 -> siblings terminates in
# one level. A gate that discovers siblings must not itself be discovered by a gate
# it runs.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
base="$here/xvm.base.json"
[[ -f "$base" ]] || { echo "missing $base"; exit 2; }

gates=()
while IFS= read -r g; do
  b=$(basename "$g")
  [[ "$b" == "ac009.sh" ]] && continue
  gates+=("$b")
done < <(find "$here" -maxdepth 1 -type f -name 'ac[0-9][0-9][0-9].sh' | LC_ALL=C sort)

fail=0
# A sibling gate DELETED rather than fixed must fail here, not pass quietly.
while IFS= read -r want; do
  [[ -n "$want" ]] || continue
  found=0
  for g in ${gates[@]+"${gates[@]}"}; do [[ "$g" == "$want" ]] && found=1; done
  [[ $found -eq 1 ]] || { echo "recorded sibling gate '$want' is no longer present"; fail=1; }
done < <(jq -r '.siblingGates[]' "$base")

green=0
for g in ${gates[@]+"${gates[@]}"}; do
  out=$(mktemp "${TMPDIR:-/tmp}/both-green.XXXXXX")
  if (cd "$root" && bash "$here/$g" --all) > "$out" 2>&1; then
    green=$((green + 1))
  else
    rc=$?
    echo "sibling $g exited $rc"
    tail -20 "$out" | sed 's/^/    /'
    fail=1
  fi
  rm -f "$out"
done

n=${#gates[@]}
if [[ $n -eq 0 ]]; then
  witness=$(printf '' | shasum -a 256 | cut -c1-16)
else
  witness=$( (cd "$here" && cat $(printf '%s\n' "${gates[@]}" | LC_ALL=C sort)) | shasum -a 256 | cut -c1-16)
fi
echo "both-green: $n sibling gate(s) discovered, $green/$n exit 0; witness=$witness"
[[ $fail -eq 0 ]] || exit 1

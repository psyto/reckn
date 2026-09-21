#!/usr/bin/env bash
# Is the submission's description field current?
#
# Two questions, and only one of them is visible from inside the repository:
#
#   1. Is DESCRIPTION.txt what the generator would produce right now?   -> checkable
#   2. Is what is IN the form the same text?                            -> not checkable,
#      so the paste is recorded by hand in PASTED and compared by hash.
#
# A note in a document saying "remember to re-paste" is an admonition. This is the check
# that goes red instead.
#
#   bash docs/tokyo-2026/check-description.sh            # ask
#   bash docs/tokyo-2026/check-description.sh --record   # after pasting, say so
#
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
say() { printf '  %s\n' "$*"; }

regenerate() {
  ( cd "$repo" && python3 docs/tokyo-2026/build-description.py >/dev/null ) \
    || { say "the generator failed"; exit 1; }
}

if [[ "${1:-}" == "--record" ]]; then
  regenerate
  h=$(shasum -a 256 "$here/DESCRIPTION.txt" | cut -c1-16)
  printf 'pasted: %s\nsha256-16: %s\n\nThe description field of the ETHGlobal Tokyo 2026 submission form was last set to\nthe DESCRIPTION.txt with this hash. check-description.sh compares the two.\n' \
    "$(date -u '+%Y-%m-%d %H:%M UTC')" "$h" > "$here/PASTED"
  printf '\n✓ recorded: the form holds %s, as of %s\n\n' "$h" "$(date -u '+%Y-%m-%d %H:%M UTC')"
  exit 0
fi

fail=0

printf '\n▶ 1. DESCRIPTION.txt against its sources\n'
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp "$here/DESCRIPTION.txt" "$tmp/before.txt" 2>/dev/null || : > "$tmp/before.txt"
regenerate
if diff -q "$tmp/before.txt" "$here/DESCRIPTION.txt" >/dev/null 2>&1; then
  say "✓ current — the generator reproduces it exactly"
else
  say "✗ STALE. The disclosure or the §4 narrative changed and this was not regenerated."
  say "  It has been regenerated just now. Commit it, paste it, then --record."
  fail=1
fi

printf '\n▶ 2. the form field against DESCRIPTION.txt\n'
now=$(shasum -a 256 "$here/DESCRIPTION.txt" | cut -c1-16)
was=$(awk '/^sha256-16:/{print $2}' "$here/PASTED" 2>/dev/null)
when=$(awk '/^pasted:/{ $1=""; sub(/^ /,""); print }' "$here/PASTED" 2>/dev/null)

if [[ "${was:-}" == "$now" ]]; then
  say "✓ the text pasted on $when is this text"
  if (( fail == 0 )); then
    printf '\n✓ the description field is current.\n\n'; exit 0
  fi
elif [[ -z "${was:-}" ]]; then
  say "✗ no paste has ever been recorded."
  fail=1
else
  say "✗ THE FORM IS STALE — pasted $when was $was, this is $now."
  fail=1
fi

printf '\n'
say "Paste the whole of docs/tokyo-2026/DESCRIPTION.txt into the description field,"
say "replacing what is there, then:"
say ""
say "    bash docs/tokyo-2026/check-description.sh --record"
printf '\n'
exit "$fail"

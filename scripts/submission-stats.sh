#!/usr/bin/env bash
# submission-stats — regenerate every drift-prone number the ETHOnline submission quotes.
#
# WHY. `SUBMISSION-FORM.md` §10 presents the commit history as "measured rather than
# asserted" and tells a judge to go and run git themselves. On 2026-09-08 it said 129
# commits and git said 151; §13's forge count said 47 and forge said 55; §12's video said
# 3:04 and the file was 2:55. Every one of those was true on the day it was typed. A number
# a human copies into a document is a number that starts decaying immediately, and the
# damage is worst precisely where the document invites the reader to check.
#
# So: nothing here is typed. Run this at freeze time, paste what it prints, and the
# invitation to verify becomes safe to accept.
#
# It reports. It does not edit the documents, because which of them may be edited is a
# question about what has already been SENT (see AGENTS.md §4) and a script must not decide
# that.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root"
START=${EVENT_START:-2026-09-04}

echo "submission-stats @ $(date -u '+%Y-%m-%d %H:%M UTC')  (event start $START)"
echo

echo "== git, the way PREFLIGHT.md §1 does it =="
# `--since` resolves the date in another timezone and silently drops commits from the
# morning of the first day. Formatting each commit's own date and comparing strings does not.
total=$(git log --format='%cd' --date=short | awk -v s="$START" '$1>=s' | wc -l | tr -d ' ')
echo "  commits in the window : $total"
printf '  per day               : '
git log --format='%cd' --date=short | awk -v s="$START" '$1>=s' | sort | uniq -c \
  | awk '{printf "%s on %s, ", $1, $2}' | sed 's/, $//'; echo
echo "  squash / wip subjects : $(git log --format='%s' | grep -ci 'squash\|wip' || true)"
# Only commits inside the window, selected by the same string comparison as above so the
# two figures cannot disagree about which commits they are counting.
in_window=$(git log --format='%cd %H' --date=short | awk -v s="$START" '$1>=s {print $2}')
biggest=0
for h in $in_window; do
  n=$(git show --stat --format='' "$h" 2>/dev/null | tail -1 | grep -oE '^[[:space:]]*[0-9]+' | tr -d ' ' || true)
  [[ -n "${n:-}" && "$n" -gt "$biggest" ]] && biggest=$n
done
echo "  largest commit        : $biggest files"

echo
echo "== tests, counted by the tools rather than remembered =="
for d in zk-verdict/contracts contracts; do
  n=$( (cd "$d" && forge test --list --json 2>/dev/null | jq '[.[][]|length]|add') 2>/dev/null || echo '?')
  printf '  forge %-22s: %s\n' "$d" "$n"
done

echo
echo "== the video, measured from the file =="
for f in dashboard/media/reckn-demo-v3.mp4 dashboard/media/reckn-demo-v3-cwf.mp4; do
  [[ -f "$f" ]] || continue
  if command -v ffprobe >/dev/null; then
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
    res=$(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0:s=x "$f")
    aud=$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$f")
    printf '  %-28s %s  %s  audio=%s  %.1f MB\n' "$(basename "$f")" \
      "$(python3 -c "import sys;d=float(sys.argv[1]);print(f'{int(d)//60}:{int(d)%60:02d}')" "$dur")" \
      "$res" "${aud:-NONE}" "$(python3 -c "import os,sys;print(os.path.getsize(sys.argv[1])/1048576)" "$f")"
    [[ -z "$aud" ]] && echo "      ^ NO AUDIO TRACK. The submission's own requirement table lists audio."
  fi
done

echo
echo "== the acceptance gates, discovered rather than listed =="
gates=$(find zk-verdict/scripts -maxdepth 1 -name 'ac[0-9][0-9][0-9].sh' | sed 's|.*/||' | LC_ALL=C sort)
echo "  gate files            : $(printf '%s ' $gates)"
echo "  siblings both-green.sh will run (all but ac009): $(printf '%s\n' $gates | grep -vc '^ac009\.sh$')"
echo
echo "Paste these into the submission at FREEZE time, not before: every one of them moves."

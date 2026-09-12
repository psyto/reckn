#!/usr/bin/env bash
# cwf-baseline -- record, once, the commit the Crypto World's Fair window opens on.
#
# CWF's rule is that "products are judged only on the work completed between the competition's
# start and end dates" (docs/cwf-2026/RULES.md §1). That makes one fact load-bearing: which
# commit was HEAD at kickoff. A date cannot answer it -- ETHOnline's own preflight records
# `git log --since` dropping twelve commits to a timezone -- and a hash written in advance is
# always wrong, because the commit that writes it comes after it.
#
# So this script refuses to guess: it will not write the baseline before kickoff, and it will
# not overwrite one that exists. Report and diff modes never write anything.
#
#   bash scripts/cwf-baseline.sh            # report: where we are relative to the window
#   bash scripts/cwf-baseline.sh --write    # at/after kickoff only, once
#   bash scripts/cwf-baseline.sh --diff     # what has changed since the recorded baseline
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
base="$root/docs/cwf-2026/baseline.json"

# 2026-09-14 04:00 PDT = 11:00 UTC = 20:00 JST, from the registration confirmation.
KICKOFF_ISO="2026-09-14T11:00:00+00:00"
# The date is quoted from colosseum.com/worldsfair. The TIME OF DAY is not published, so
# nothing here treats the deadline as an instant.
DEADLINE_DATE="2026-10-12"

iso2epoch() { python3 -c "import datetime,sys;print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))" "$1"; }
epoch2jst()  { python3 -c "import datetime,sys;print((datetime.datetime.fromtimestamp(int(sys.argv[1]),datetime.timezone.utc)+datetime.timedelta(hours=9)).strftime('%Y-%m-%d %H:%M JST'))" "$1"; }

now=$(date -u +%s)
kick=$(iso2epoch "$KICKOFF_ISO")

mode="${1:---report}"

case "$mode" in
--report)
  echo "cwf-baseline: kickoff $KICKOFF_ISO ($(epoch2jst "$kick")), deadline date $DEADLINE_DATE"
  if [ "$now" -lt "$kick" ]; then
    printf 'cwf-baseline: %s until kickoff -- the window has NOT opened\n' \
      "$(python3 -c "d=$kick-$now;print(f'{d//3600}h {d%3600//60}m')")"
  else
    echo "cwf-baseline: the window is OPEN"
  fi
  if [ -f "$base" ]; then
    python3 - "$base" <<'PY'
import json,sys
b=json.load(open(sys.argv[1]))
print(f"cwf-baseline: baseline recorded at {b['recordedAtUtc']} -- HEAD was {b['head']} on branch {b['branch']}")
print(f"cwf-baseline: {b['commitsBeforeKickoff']} commit(s) existed before the window")
PY
  else
    echo "cwf-baseline: NO baseline recorded yet -- run --write at or after kickoff"
  fi
  ;;
--write)
  if [ "$now" -lt "$kick" ]; then
    echo "cwf-baseline: REFUSING to write -- kickoff is $KICKOFF_ISO and it has not arrived." >&2
    echo "cwf-baseline: a baseline written early names a commit that is not the boundary." >&2
    exit 1
  fi
  if [ -f "$base" ]; then
    echo "cwf-baseline: REFUSING to overwrite $base -- the boundary is recorded once." >&2
    echo "cwf-baseline: use --diff to see what has happened since it." >&2
    exit 1
  fi
  head=$(git -C "$root" rev-parse HEAD)
  branch=$(git -C "$root" rev-parse --abbrev-ref HEAD)
  headdate=$(git -C "$root" log -1 --format=%cI)
  total=$(git -C "$root" rev-list --count HEAD)
  python3 - "$base" "$head" "$branch" "$headdate" "$total" "$KICKOFF_ISO" "$DEADLINE_DATE" <<'PY'
import json,sys,datetime
p,head,branch,headdate,total,kick,deadline=sys.argv[1:8]
json.dump({
 "_": "Written once by scripts/cwf-baseline.sh at or after kickoff. The hash is the boundary: "
      "CWF judges the work completed between the competition's start and end dates, and this is "
      "the commit the start date found. Nothing in this file was typed by a human.",
 "event":"Crypto World's Fair (Colosseum)","kickoffUtc":kick,"deadlineDate":deadline,
 "recordedAtUtc":datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
 "head":head,"branch":branch,"headCommitterDate":headdate,"commitsBeforeKickoff":int(total),
}, open(p,"w"), indent=2)
open(p,"a").write("\n")
print(f"cwf-baseline: wrote {p}\ncwf-baseline: boundary = {head} ({total} commits before the window)")
PY
  ;;
--diff)
  [ -f "$base" ] || { echo "cwf-baseline: no baseline at $base -- nothing to diff against" >&2; exit 1; }
  b=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['head'])" "$base")
  n=$(git -C "$root" rev-list --count "$b"..HEAD)
  echo "cwf-baseline: $n commit(s) since the boundary $b"
  git -C "$root" log --format='  %h %cd %s' --date=short "$b"..HEAD | tail -40
  echo "cwf-baseline: files touched in the window --"
  git -C "$root" diff --stat "$b"..HEAD | tail -30
  ;;
*) echo "usage: bash scripts/cwf-baseline.sh [--report|--write|--diff]" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# A SCRATCH voice track, for checking pace. NOT the deliverable.
#
# It renders VO.md's lines with the macOS `say` voice at their timecodes so the founder can
# hear which lines run past their shot before recording the real one. A synthetic voice on
# a hackathon submission reads as the one corner that was cut, and this project's whole
# argument is that it does not cut corners quietly — so the output is named `-scratch` and
# `check.sh` will not tell you it is fine.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out="$root/dashboard/media/vo-scratch.m4a"
work=$(mktemp -d "${TMPDIR:-/tmp}/vo.XXXXXX")
trap 'rm -rf "$work"' EXIT

# start(seconds) | text — parsed out of VO.md so the two cannot drift apart
python3 - "$here/VO.md" "$work/lines.tsv" <<'PY'
import re, sys
rows = []
for line in open(sys.argv[1]):
    m = re.match(r"\|\s*(\d+)\s*\|\s*(\d+):(\d+)\s*\|[^|]*\|[^|]*\|\s*\"(.+?)\"\s*\|", line)
    if m:
        rows.append((int(m.group(2)) * 60 + int(m.group(3)), m.group(4)))
if not rows:
    sys.exit("scratch-vo: no timecoded lines found in VO.md")
with open(sys.argv[2], "w") as f:
    for t, text in rows:
        f.write(f"{t}\t{text}\n")
print(f"scratch-vo: {len(rows)} lines")
PY

i=0; filters=""; inputs=""
while IFS=$'\t' read -r t text; do
  say -v Samantha -o "$work/$i.aiff" "$(printf '%s' "$text" | sed 's/\*\*//g')"
  inputs+=" -i $work/$i.aiff"
  filters+="[$((i+1)):a]adelay=$((t*1000))|$((t*1000))[a$i];"
  i=$((i+1))
done < "$work/lines.tsv"

mix=$(seq 0 $((i-1)) | sed 's/^/[a/;s/$/]/' | tr -d '\n')
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$root/dashboard/media/reckn-arc-demo.mp4")
ffmpeg -v error -y -f lavfi -t "$dur" -i anullsrc=r=44100:cl=stereo $inputs \
  -filter_complex "${filters}${mix}amix=inputs=$i:normalize=0[m]" -map "[m]" -c:a aac "$out"
echo "scratch-vo: $out  (SCRATCH — synthetic voice, for timing only, do not submit)"

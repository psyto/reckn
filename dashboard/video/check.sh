#!/usr/bin/env bash
# Check a cut against ETHOnline 2026's stated video requirements, before submitting rather
# than after. The rules are a floor, not a preference:
#
#   "Please ensure the video is between 2 and 4 minutes"
#   "Please ensure that minimum video resolution is 720p"
#   "Please ensure the video has audio without music"
#
# The third cannot be checked mechanically — a track's *content* is not measurable here —
# so this reports whether an audio track exists at all and says plainly that the rest is
# a human's judgement. Reporting "green" on something unmeasured is the failure mode this
# repository spends most of its gates preventing.
set -euo pipefail
f=${1:-dashboard/media/reckn-arc-demo.mp4}
[[ -f "$f" ]] || { echo "check: no such file: $f"; exit 2; }

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
read -r w h < <(ffprobe -v error -select_streams v -show_entries stream=width,height \
  -of csv=p=0 "$f" | tr ',' ' ')
acodec=$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$f" || true)
mb=$(python3 -c "import os;print(f'{os.path.getsize(\"$f\")/1e6:.1f}')")
fail=0
say() { printf '  %s %s\n' "$1" "$2"; }

python3 - "$dur" "$w" "$h" <<'PY'
import sys
d, w, h = float(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
ok = lambda b: "✓" if b else "✗"
print(f"  {ok(120 <= d <= 240)} duration      {int(d//60)}:{int(d%60):02d}  (must be 2:00–4:00)")
print(f"  {ok(h >= 720)} resolution    {w}x{h}  (must be at least 720 lines)")
r = w / h
print(f"  {ok(abs(r - 16/9) < 0.01)} aspect        {r:.4f}  (16:9 is {16/9:.4f})")
sys.exit(0 if (120 <= d <= 240 and h >= 720 and abs(r - 16/9) < 0.01) else 1)
PY
rc=$?
if [[ -n "$acodec" ]]; then say "✓" "audio         a $acodec track is present"
else say "✗" "audio         NO TRACK — the event requires audio"; fail=1; fi
say " " "size          $mb MB"
echo "  · whether the audio is speech, is clear, and carries no music is NOT checked here."
echo "    Listen to it. A mechanical green on an unmeasured property is worse than no check."
[[ $rc -eq 0 && $fail -eq 0 ]] || { echo "check: $f does not meet the stated requirements"; exit 1; }
echo "check: $f meets every requirement this script can measure"

#!/usr/bin/env bash
# Is the submission video one ETHGlobal will accept?
#
# The rules reject a video automatically, before anybody watches it: too short or too
# long, below 720p, no audio, or a music bed with on-screen text standing in for a
# person talking. Four of those are measurable. The fifth is not, and §6 says where it
# rides on a human instead of pretending otherwise.
#
#   bash docs/tokyo-2026/check-video.sh            # measure
#   bash docs/tokyo-2026/check-video.sh --record   # after §6 was done by eye
#
# One measurement here was wrong once, and the way it was wrong is worth keeping:
# `ffmpeg -v error ... silencedetect` reports NOTHING, because silencedetect logs at
# info level. It does not fail; it returns "0 silent regions", which reads exactly like
# a continuous music bed. Do not add -v error to the silence pass below.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)

video=${1:-}
[[ "$video" == "--record" ]] && video=""
if [[ -z "$video" ]]; then
  video=$(awk '/^file:/{ $1=""; sub(/^ /,""); print }' "$here/WATCHED" 2>/dev/null)
  [[ -n "$video" ]] || { echo "no WATCHED record and no path given"; exit 1; }
fi
# a path on the command line is the caller's, relative to where they stand;
# a path out of the VIDEO record is relative to this directory.
if [[ "$video" != /* && ! -f "$video" ]]; then video="$here/$video"; fi
[[ -f "$video" ]] || { echo "no such file: $video"; exit 1; }
command -v ffprobe >/dev/null && command -v ffmpeg >/dev/null \
  || { echo "ffprobe/ffmpeg not on PATH"; exit 1; }

say() { printf '  %s\n' "$*"; }
probe() { ffprobe -v error -select_streams "$1" -show_entries "$2" -of default=nw=1:nk=1 "$video" 2>/dev/null | head -1; }

dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$video")
h=$(probe v:0 stream=height); w=$(probe v:0 stream=width)
acodec=$(probe a:0 stream=codec_name)
sha=$(shasum -a 256 "$video" | cut -c1-16)

if [[ "${1:-}" == "--record" || "${2:-}" == "--record" ]]; then
  # the path as this directory sees it, so a bare run can find it again
  rel=${video#"$here"/}
  printf 'file: %s\nsha256-16: %s\nwatched: %s\n\nThe frames of this file were looked at by eye for §6 (an expanded SEPOLIA_RPC\nburnt into a terminal capture). A re-export changes the hash and this goes red.\n' \
    "$rel" "$sha" "$(date -u '+%Y-%m-%d %H:%M UTC')" > "$here/WATCHED" \
    || { echo "could not write $here/WATCHED — nothing was recorded"; exit 1; }
  # Saying "recorded" without looking is how a green row gets written by a failed write.
  grep -q "^sha256-16: $sha\$" "$here/WATCHED" \
    || { echo "wrote $here/WATCHED but it does not hold $sha — nothing was recorded"; exit 1; }
  printf '\n✓ recorded: %s (%s) was watched %s\n\n' "$(basename "$video")" "$sha" "$(date -u '+%Y-%m-%d %H:%M UTC')"
  exit 0
fi

fail=0
printf '\n▶ %s  (%s)\n\n' "$(basename "$video")" "$sha"

printf '▶ 1. length — between 2:00 and 4:00\n'
if awk -v d="$dur" 'BEGIN{exit !(d>=120 && d<=240)}'; then
  say "$(awk -v d="$dur" 'BEGIN{printf "✓ %.1f s (%d:%02d)", d, d/60, d%60}')"
else
  say "$(awk -v d="$dur" 'BEGIN{printf "✗ %.1f s — outside the window", d}')"; fail=1
fi

printf '\n▶ 2. resolution — at least 720p\n'
if [[ -n "$h" ]] && (( h >= 720 )); then say "✓ ${w}x${h}"; else say "✗ ${w}x${h}"; fail=1; fi

printf '\n▶ 3. an audio track exists\n'
if [[ -n "$acodec" ]]; then say "✓ $acodec, $(probe a:0 stream=sample_rate) Hz"; else say "✗ none"; fail=1; fi

printf '\n▶ 4. somebody is talking, not a music bed\n'
# Speech breathes: every phrase boundary drops the whole signal near the noise floor.
# A continuous bed never lets it fall. Counting the falls separates them without
# anybody having to listen.
n=$(ffmpeg -hide_banner -nostats -i "$video" -af silencedetect=noise=-45dB:d=0.25 -f null - 2>&1 | grep -c silence_start)
if (( n >= 10 )); then
  say "✓ $n pauses below -45 dB — the floor falls where sentences end"
else
  say "✗ only $n pauses — the signal never falls, which is what a music bed sounds like"; fail=1
fi

printf '\n▶ 5. no still image standing in for a video\n'
scenes=$(ffmpeg -hide_banner -nostats -i "$video" -vf "select='gt(scene,0.04)',metadata=print" -f null - 2>&1 | grep -c 'lavfi.scene_score')
if (( scenes >= 5 )); then say "✓ $scenes scene changes"; else say "✗ $scenes scene changes"; fail=1; fi

printf '\n▶ 6. NOT MEASURED HERE — an expanded SEPOLIA_RPC in a frame (PREFLIGHT §5.7)\n'
say "No OCR runs here, so this one rides on a person. The chain of checks ends at:"
say ""
say "    ffmpeg -v error -i <video> -vf \"select='gt(scene,0.04)',scale=640:-1,tile=5x5\" \\"
say "      -vsync vfr -frames:v 4 /tmp/sc%d.png -y     # then look at every tile"
say ""
was=$(awk '/^sha256-16:/{print $2}' "$here/WATCHED" 2>/dev/null)
when=$(awk '/^watched:/{ $1=""; sub(/^ /,""); print }' "$here/WATCHED" 2>/dev/null)
if [[ "${was:-}" == "$sha" ]]; then
  say "✓ these exact bytes were looked at on $when"
elif [[ -z "${was:-}" ]]; then
  say "✗ nobody has recorded looking at any cut."; fail=1
else
  say "✗ what was watched on $when was $was. This is a different export."; fail=1
fi

printf '\n'
if (( fail == 0 )); then printf '✓ the submission video clears every automatic rejection.\n\n'
else say "After looking at the tiles:  bash docs/tokyo-2026/check-video.sh '$video' --record"; printf '\n'; fi
exit "$fail"

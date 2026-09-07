#!/usr/bin/env python3
"""How many distinct frames appear in four seconds, at the least lively point of a cut.

A screen recording of a page that only repaints on events is a SLIDESHOW. The first cut of
this film had TWO distinct frames inside a nine-second hold — and duration, resolution,
aspect and the card ratio were all green while that was true. It took a person watching it
to notice, which is the definition of a property nobody was measuring.

Prints the worst of three sample points. 8 is continuous motion; 2 is a still image.
"""
import hashlib, os, subprocess, sys, tempfile

f = sys.argv[1]
dur = float(subprocess.run(
    ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
    capture_output=True, text=True).stdout.strip())
worst = 8
with tempfile.TemporaryDirectory() as d:
    for frac in (0.35, 0.55, 0.9):
        seen = set()
        for i in range(8):
            t = dur * frac + i * 0.5
            out = os.path.join(d, "f.png")
            subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t}", "-i", f,
                            "-frames:v", "1", out, "-y"], capture_output=True)
            if os.path.exists(out):
                seen.add(hashlib.sha256(open(out, "rb").read()).hexdigest())
                os.remove(out)
        worst = min(worst, len(seen))
print(worst)

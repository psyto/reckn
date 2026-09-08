#!/usr/bin/env python3
"""Publish the money-shot page to docs/money-shot.html.

WHY IT EXISTS. The film ends by sending a judge to psyto.github.io/reckn, and the founder's
read of that destination was that it is not very interesting to look at — which is fair. The
published page is a VERIFICATION INSTRUMENT: a bytecode comparison, four receipts, a cost
table. The page with a story in it — a seller claiming "1024 USDC out, please release", an
opinion LLM saying APPROVE, a re-execution saying FAILED, and the judge being OVERRULED while
1,000 USDC goes back to the buyer — was `dashboard/index.html`, and it was never published.
The film was sending people to the duller of the two.

It can be published as-is: the page is 62 KB, self-contained, with no external script, no
stylesheet and no network call. The one grep hit for a URL is a <pre> block showing a shell
command as text. Verified by serving it statically and driving it headless — the two verdicts
diverge and the console reports zero page errors.

COPIED, NOT FORKED. This script rewrites docs/money-shot.html from dashboard/index.html every
time it runs, so the published copy cannot drift from the demo the recorder films. The only
edits are a canonical <title> and a banner saying what the page is, because a visitor
arriving from the video has no context that a local operator running arc-demo.sh does.

  python3 dashboard/live/publish-money-shot.py
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
src = root / "dashboard/index.html"
out = root / "docs/money-shot.html"

html = src.read_text()

# The page tells a local operator to run a script and open a port. A visitor arriving from
# the film cannot do that and should not be told to; the banner replaces it with what they
# are actually looking at, and where to go to check that it is real.
BANNER = """<div style="max-width:1200px;margin:18px auto 0;padding:14px 18px;border:1px solid #2b241d;
     border-radius:10px;background:#17130f;color:#cbbfae;font:14.5px/1.55 ui-sans-serif,
     -apple-system,'SF Pro Display',Inter,sans-serif">
  <b style="color:#f2ede6">One dispute, judged two ways.</b> A seller claims the work paid out.
  An opinion model reads the claim and approves it. Re-execution replays the work and returns
  <b style="color:#f2ede6">Failed — not reproduced</b>, and the money goes back to the buyer.
  This page is a <b style="color:#f2ede6">simulation of that mechanism</b> — the settlements that
  actually happened are on
  <a href="index.html" style="color:#3fb950">the live page</a>, read from Arc testnet by your
  own browser.
</div>
"""

if "<body" not in html:
    sys.exit("publish-money-shot: no <body> in dashboard/index.html")
html = re.sub(r"(<body[^>]*>)", r"\1\n" + BANNER, html, count=1)

title = "Reckn — one dispute, judged two ways"
if re.search(r"<title>.*?</title>", html, re.S):
    html = re.sub(r"<title>.*?</title>", f"<title>{title}</title>", html, count=1, flags=re.S)

# A published copy that quietly loses the thing it exists to show would be worse than no page.
for must in ("btnFalse", "btnReplay", "vOpinionText", "vRecknText"):
    if must not in html:
        sys.exit(f"publish-money-shot: {must} is missing — the page cannot do what it is for")

out.write_text(html)
print(f"docs/money-shot.html  {out.stat().st_size:,} bytes  (from dashboard/index.html)")

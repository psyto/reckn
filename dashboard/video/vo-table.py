#!/usr/bin/env python3
"""Generate VO.md's timing table from beats.tsv — so the timecodes are measured, not derived.

The first draft of that table was arithmetic. Its last line landed at 2:48 against a 2:08
cut, and when it was regenerated from the recorder's own beats it turned out that six lines
ran past their shots, one of them into a window that was NEGATIVE. Hand-computed timecodes
for a video are the same class of mistake as a hand-copied transaction hash.

  python3 dashboard/video/vo-table.py        # prints the table; over-budget lines are flagged
"""
import sys, pathlib

WPM = 145
here = pathlib.Path(__file__).resolve().parent
beats = {}
order = []
for line in (here / __import__("os").environ.get("BEATS", "beats-v3.tsv")).read_text().splitlines():
    t, label = line.split("\t")
    beats[label] = float(t)
    order.append(label)
END = beats["END"]

# Card lengths are derived by holdFor() in record.js; the two composite plates (opening
# and closing) run on their own timers. Only the gaps matter here, and every one of them is
# read from beats.tsv rather than assumed.
def at(label):
    # A missing label used to surface as a bare KeyError from inside the SCRIPT literal, and
    # a caller that piped stdout got an EMPTY table with no obvious cause — which is how a
    # regenerated VO.md briefly ended up with zero lines in it. Say which label, and say
    # which ones exist.
    if label not in beats:
        raise SystemExit(
            f"vo-table: no beat named {label!r}.\nThe cut has:\n  " + "\n  ".join(order))
    return beats[label]

CLOSE = 6.0   # closingPlate(6000)

SCRIPT = [
    # Written for a HUMAN first take: contractions, one idea per breath, no stacked noun
    # phrases. And written for a film whose job is not to explain but to get the viewer to
    # open the page — so the voice never recites a slide, it says the thing the slide leaves
    # out and then gets out of the way.
    (at("TITLE Reckn"), 8.0, None,
     "plate: **Reckn — Keep assets native. Settle on proof.** then the door question"),
    (at("SLIDE 02 the claim, and the offer"), 6.5, 1,
     "Nobody can move this money. Not the seller, not the buyer, and not us."),
    (at("SLIDE 03 check 1"), 6.0, 2,
     "That is easy to say, so don't take our word for it. Four checks."),
    (at("01 fund"), 6.5, 3,
     "Here's a funded deal. Two hundred and fifty dollars, and no key to it."),
    (at("01 BindingMismatch"), 8.0, 4,
     "That's a real Groth16 proof. It verifies. It's just about a different job — so the money stays put."),
    (at("02 evidence: release"), 6.0, 5,
     "The proof this deal was funded against reproduces. The seller gets paid."),
    (at("02 evidence: refund"), 8.0, 6,
     "And when the work doesn't reproduce, the same machinery sends the money back."),
    (at("SLIDE 04 check 2"), 7.5, 7,
     "Check two. Your browser reads the contract off the chain and compares it to our source."),
    (at("02 evidence: bytecode + no-keys"), 9.0, 8,
     "Byte for byte. And if an owner or an admin ever showed up in it, the build would fail."),
    (at("SLIDE 05 check 3"), 7.0, 9,
     "Check three. Four settlements, in real money, on Arc testnet."),
    (at("04 evidence: four settlements"), 9.0, 10,
     "Two of them were decided by proofs about work done on Solana. One escrow, two virtual machines."),
    (at("17 SVG: out to Arc, scope held"), 7.5, 11,
     "The proof crosses. The money never does. There's no bridge in here."),
    (at("SLIDE 07 check 4 - what it does not prove"), 9.0, 12,
     "Check four is the one nobody else shows you: what this does not prove."),
    (at("06 evidence: the two rows"), 8.5, 13,
     "It's consistency, not provenance. And it doesn't save you from holding funds where you pay."),
    (at("SLIDE 08 check it yourself"), 8.0, 14,
     "So go and check it. Nothing to install, no wallet."),
    (END - CLOSE, CLOSE, None,
     "plate: the door's last line"),
]

# A line has to fit its SHOT, not just its own stated seconds.
shots = [(beats[l], l) for l in order if l != "END"]
shots.sort()
def shot_of(t):
    hit = None
    for k, (s0, lab) in enumerate(shots):
        if s0 <= t + 1e-9:
            hit = (s0, lab, shots[k + 1][0] if k + 1 < len(shots) else END)
    return hit

# A line has to fit its SHOT, not just its own stated seconds. The old table only checked
# words-per-minute against the duration written next to the line, so a line could be
# comfortably paced and still run forty seconds past the picture it describes — which is
# the mistake that produced a 2:48 table for a 2:08 cut. Anchor each line to the beat it
# starts in and check it ends before that beat does.
shots = [(beats[l], l) for l in order if l != "END"]
shots.sort()
def shot_of(t):
    hit = None
    for k, (s0, lab) in enumerate(shots):
        if s0 <= t + 1e-9:
            hit = (s0, lab, shots[k + 1][0] if k + 1 < len(shots) else END)
    return hit

# A line has to fit its SHOT, not just its own stated seconds. The old table only checked
# words-per-minute against the duration written next to the line, so a line could be
# comfortably paced and still run forty seconds past the picture it describes — which is
# the mistake that produced a 2:48 table for a 2:08 cut. Anchor each line to the beat it
# starts in and check it ends before that beat does.
shots = [(beats[l], l) for l in order if l != "END"]
shots.sort()
def shot_of(t):
    hit = None
    for k, (s0, lab) in enumerate(shots):
        if s0 <= t + 1e-9:
            hit = (s0, lab, shots[k + 1][0] if k + 1 < len(shots) else END)
    return hit

# A line has to fit its SHOT, not just its own stated seconds. The old table only checked
# words-per-minute against the duration written next to the line, so a line could be
# comfortably paced and still run forty seconds past the picture it describes — which is
# the mistake that produced a 2:48 table for a 2:08 cut. Anchor each line to the beat it
# starts in and check it ends before that beat does.
shots = [(beats[l], l) for l in order if l != "END"]
shots.sort()
def shot_of(t):
    hit = None
    for k, (s0, lab) in enumerate(shots):
        if s0 <= t + 1e-9:
            hit = (s0, lab, shots[k + 1][0] if k + 1 < len(shots) else END)
    return hit


def mmss(t): return f"{int(t // 60)}:{int(t % 60):02d}"

rows = ["| # | in | for | words | line |", "|---|---|---|---|---|"]
over = 0
for start, dur, n, text in SCRIPT:
    if n is None:
        rows.append(f"| — | {mmss(start)} | {dur:.1f} s | — | *({text})* |")
        continue
    words, budget = len(text.split()), int(dur * WPM / 60)
    flag = ""
    if words > budget:
        over += 1
        flag += " ⚠ **OVER (words)**"
    sh = shot_of(start)
    if sh and start + dur > sh[2] + 0.35:
        over += 1
        flag += f" ⚠ **RUNS PAST `{sh[1]}` by {start + dur - sh[2]:.1f} s**"
    rows.append(f"| {n} | {mmss(start)} | {dur:.1f} s | {words} / {budget} | \"{text}\"{flag} |")

print("\n".join(rows))
if over:
    print(f"\n{over} line(s) run past their shot at {WPM} wpm.", file=sys.stderr)
    sys.exit(1)

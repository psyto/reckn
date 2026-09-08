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

CLOSE = 8.0   # closingPlate(8000)

SCRIPT = [
    # Written to be SPOKEN by a person, not read off a page. Contractions, one idea per
    # breath, and no stacked noun phrases — an unrehearsed narrator trips on "a re-executable
    # deterministic settlement predicate" and does not trip on "we replay the work".
    # The event forbids a synthetic voice, so this has to survive a human first take.
    (at("00 cold open: fund"), 7.0, 1,
     "This escrow is holding two hundred and fifty dollars. Nobody has a key to it."),
    (at("00 cold open: BindingMismatch"), 7.5, 2,
     "Now watch. That's a real proof, and it verifies — it's just about a different job."),
    (at("00 cold open: BindingMismatch") + 8.0, 7.0, 3,
     "Binding mismatch. The money didn't move. Being valid wasn't enough."),
    (at("TITLE Reckn"), 9.0, None,
     "plate: **Reckn — Keep assets native. Settle on proof.** then the door question"),
    # Over the problem slide. It does NOT read the table out — a narrator reciting what is
    # already on screen is the fastest way to make a good demo feel like a bad one. One line
    # names the insight, then silence while it is read.
    (at("SLIDE 02 the problem"), 6.0, 4,
     "Both are guessing. One from a claim, one from nothing."),
    (at("SLIDE 05 nobody could have overridden that"), 9.0, 5,
     "Nobody could have stepped in and overridden that. There's no owner, no admin, no resolver."),
    (at("SLIDE 05 nobody could have overridden that") + 9.5, 7.5, 6,
     "And it isn't a promise. If one ever appeared, the build would fail."),
    (at("02 evidence: release"), 7.0, 7,
     "Here's the proof this deal was funded against. It reproduces, so the seller gets paid."),
    (at("02 evidence: refund"), 8.5, 10,
     "And when the work doesn't reproduce, the same machinery sends the money back."),
    (at("03 evidence: what it replaces"), 8.5, 8,
     "What we took out isn't a fee. It's the person who used to approve this."),
    # SLIDE 03, the inversion, is DELIBERATELY silent. It carries one sentence in very large
    # type; a voice over it either repeats it or competes with it, and seven seconds of
    # quiet before the diagram is the only pause this film has.
    (at("17 SVG: out to Arc, scope held"), 8.5, 9,
     "The work happened on Solana. We re-ran it inside a zkVM. The proof crosses — the money never does."),
    (at("04 evidence: four settlements"), 10.0, 11,
     "Four settlements on Arc testnet, read straight off the chain by your browser. Two were decided by proofs about work done on Solana."),
    # Over "what this does not claim". Three refusals are on the slide; the voice adds the
    # reason they are there at all, and then gets out of the way.
    (at("SLIDE 07 what this does not claim"), 5.5, 12,
     "We would rather you heard this part from us."),
    (at("06 evidence: the two rows"), 7.5, 13,
     "Arc never runs a Solana virtual machine — and we put that limit on the page."),
    (at("06 evidence: the two rows") + 8.0, 5.0, 14,
     "It's consistency. It isn't provenance."),
    (at("07 evidence: typing"), 6.5, 15,
     "The one thing an observer controls is the story. So watch what the story moves."),
    (at("07 evidence: typing") + 7.0, 6.0, 16,
     "Every keystroke, a new hash. The verdict comes from the chain. It doesn't budge."),
    (END - CLOSE, CLOSE, None,
     "plate: **Keep assets native. Settle on proof.** then the door's last line"),
]

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

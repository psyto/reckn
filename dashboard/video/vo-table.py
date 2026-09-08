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
def at(label): return beats[label]

CLOSE = 8.0   # closingPlate(8000)

SCRIPT = [
    # The cold open. The picture is doing the arguing here, so the voice stays out of its
    # way and says only what a viewer cannot read off the screen.
    (at("00 cold open: fund"), 7.0, 1,
     "This escrow holds two hundred and fifty dollars. Nobody has a key to it."),
    (at("00 cold open: BindingMismatch"), 7.5, 2,
     "That is a real Groth16 proof. It verifies. It is a proof of a different execution."),
    (at("00 cold open: BindingMismatch") + 8.0, 7.0, 3,
     "Binding mismatch. The money did not move. A valid proof was not enough."),
    (at("TITLE Reckn"), 9.0, None,
     "plate: **Reckn — Keep assets native. Settle on proof.** then the door question"),
    (at("CARD 01 Nobody could have overridden that."), 9.0, 4,
     "Nobody could have overridden it. This escrow has no owner, no admin and no resolver."),
    (at("CARD 01 Nobody could have overridden that.") + 9.5, 7.5, 5,
     "And that is a build condition — if one appeared, the build would fail."),
    (at("02 evidence: release"), 7.0, 6,
     "The proof this deal was funded against reproduces, and the seller is paid."),
    (at("02 evidence: refund"), 8.5, 7,
     "A delivery that did not reproduce refunds the buyer. Same machinery, both directions."),
    (at("03 evidence: what it replaces"), 8.5, 8,
     "What was removed is not a fee. It is the person who had to approve it."),
    (at("17 SVG: out to Arc, scope held"), 8.5, 9,
     "The work happened on Solana; a zkVM re-executed it. The proof crosses. The money does not."),
    (at("04 evidence: four settlements"), 10.0, 10,
     "Four settlements on Arc testnet, read out of the receipts by your browser. Two were decided by proofs about work performed on Solana."),
    (at("06 evidence: the two rows"), 7.5, 11,
     "Arc never runs a Solana virtual machine, and that limit is on the page."),
    (at("06 evidence: the two rows") + 8.0, 5.0, 12,
     "Consistency, not provenance."),
    (at("07 evidence: typing"), 6.5, 13,
     "The one thing an observer controls is the story. Watch what it moves."),
    (at("07 evidence: typing") + 7.0, 6.0, 14,
     "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved."),
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

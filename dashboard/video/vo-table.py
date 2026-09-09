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
for line in (here / __import__("os").environ.get("BEATS", "beats-reckn-demo-v3.tsv")).read_text().splitlines():
    t, label = line.split("\t")
    beats[label] = float(t)
    order.append(label)
END = beats["END"]

# The default used to be `beats-v3.tsv`, which the recorder STOPPED WRITING when the beat
# tables were split per cut -- so on 2026-09-09 this script read a file from the previous
# day, resolved every label, reported no warnings, and produced a table timecoded to a film
# that no longer existed. Nothing was missing; everything was simply about the wrong cut.
# The test is AGREEMENT, not timestamps: the recorder writes the beats before it encodes,
# so the table is always a little older than the file, and a modified-time comparison
# rejected the correct pairing on its first run. What cannot differ is the ENDING -- a beat
# table that describes this film ends where this film ends.
_mp4 = here.parent / "media" / "reckn-demo-v3.mp4"
_bts = here / __import__("os").environ.get("BEATS", "beats-reckn-demo-v3.tsv")
if _mp4.exists():
    import subprocess
    _d = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
         str(_mp4)], capture_output=True, text=True, check=True).stdout.strip())
    if abs(_d - END) > 3.0:
        raise SystemExit(
            f"vo-table: {_bts.name} ends at {END:.1f}s but {_mp4.name} runs {_d:.1f}s.\n"
            "The table describes a different cut. Re-record, or point BEATS at this film's table.")

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

CLOSE = 12.0  # closingPlate(12000) — the plate is spoken now, so it has to be readable aloud

SCRIPT = [
    # Written for a HUMAN first take: contractions, one idea per breath, no stacked noun
    # phrases. And written for a film whose job is not to explain but to get the viewer to
    # open the page — so the voice never recites a slide, it says the thing the slide leaves
    # out and then gets out of the way.
    (at("TITLE Reckn"), 8.0, None,
     "plate: **Reckn — Keep assets native. Settle on proof.** then the door question"),
    # THE MONEY SHOT HAD NO VOICE ON IT. Twelve seconds carrying two captions and the whole
    # argument for re-execution over a judge, and the first line did not arrive until the beat
    # was over -- because the captions live in record.js and moved with the picture, while this
    # file did not. The captions already say "two judges" and "only one you can redo yourself",
    # so these two lines carry what the captions do not: the stake, and why anyone should care
    # which kind of judge it is.
    (at("00 opinion vs re-execution") + 1.0, 5.4, 1,
     "An agent says the work is done, and asks to be paid."),
    (at("00 opinion vs re-execution") + 6.8, 5.2, 2,
     "Usually a person decides. Here, the work itself is run again."),
    (at("SLIDE 02 the claim, and the offer"), 6.5, 3,
     "Nobody can move this money. Not the seller, not the buyer, and not us."),
    (at("SLIDE 02 the claim, and the offer") + 8.0, 6.5, 31,
     "The terms are fixed before the work starts — the job, the inputs, the target."),
    (at("SLIDE 02 the claim, and the offer") + 15.0, 5.5, 32,
     "After that, only a proof that the work reproduced can release it."),
    (at("SLIDE 03 check 1"), 6.0, 2,
     "That is easy to say, so don't take our word for it. Four checks."),
    (at("SLIDE 03 check 1") + 7.0, 5.0, 33,
     "Check one is a theft attempt, and we run it on camera."),
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
    (at("SLIDE 05 check 3") + 8.0, 6.0, 34,
     "A public testnet, so your browser can read every one of them without us."),
    (at("04 evidence: four settlements"), 9.0, 10,
     "Two of them were decided by proofs about work done on Solana. One escrow, two virtual machines."),
    (at("17 SVG: out to Arc, scope held"), 7.5, 11,
     "The proof crosses. The money never does. There's no bridge in here."),
    # Sixteen seconds on the slide that answers the question ETHOnline asks hardest -- why this
    # chain -- and not a word spoken over it. The slide argues; this says what the slide is for.
    (at("SLIDE 06 why Arc") + 2.0, 8.0, 90,
     "Arc is not a deployment target here. It is where the dollar already lives, and stays."),
    (at("SLIDE 09 check 4 - what it does not prove"), 9.0, 12,
     "Check four is the one nobody else shows you: what this does not prove."),
    (at("SLIDE 09 check 4 - what it does not prove") + 11.0, 7.0, 35,
     "Three of them. You should hear these from us rather than find them yourself."),
    (at("06 evidence: the two rows"), 7.5, 13,
     "It's consistency, not provenance. And it doesn't save you from holding funds where you pay."),
    (at("SLIDE 11 check it yourself"), 8.0, 14,
     "So go and check it. Nothing to install, no wallet."),
    # The second rung, and the reason this slide grew. Until 2026-09-07 a binding could only
    # be computed inside the guest, so a viewer could verify our receipts but could not set
    # up a deal of their own; `reckn terms` is that gap closed, and the ending is where a
    # viewer decides whether there is anything here for them.
    (at("SLIDE 11 check it yourself") + 9.0, 8.0, 15,
     "Then clone it. One command runs a release, a refund, and a real proof of a different job refused."),
    (END - CLOSE, CLOSE, None,
     "plate: the door's last line"),
    # READ THE PLATE. Three lines landing on the three things already on screen -- the
    # principle, the closer, and the ambition. Founder's call, and the right one: this is the
    # last thing anyone sees, and a closing plate that nobody says out loud is a film that
    # stops rather than ends.
    (END - CLOSE + 0.8, 3.2, 36,
     "Keep assets native. Settle on proof."),
    (END - CLOSE + 4.4, 2.6, 37,
     "Reproduce, or refund."),
    (END - CLOSE + 7.2, 4.8, 38,
     "Reckn is building the standard for proof-driven settlement across execution environments."),
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


def mmss(t): return f"{int(t // 60)}:{int(t % 60):02d}"

# PLAY ORDER, NOT SOURCE ORDER. A narrator reads this table top to bottom, so a row that
# appears above another must also be *spoken* before it. The SCRIPT list below is written in
# the order the film was built, and on 2026-09-09 that stopped matching: the boundary diagram
# and its SVG were moved from after check 3 to before check 1, and the line anchored to them
# travelled with the picture -- correctly -- landing at 0:48 while still sitting eleventh in
# the source. The table said 3:05, 3:16, 0:48. Sorting here means moving a beat can never
# again silently produce a script nobody can read aloud, and the numbers are assigned after
# the sort so they always count in the order a person speaks them.
SCRIPT = sorted(SCRIPT, key=lambda r: r[0])
_n = 0
_renumbered = []
for _start, _dur, _num, _text in SCRIPT:
    if _num is not None:
        _n += 1
        _num = _n
    _renumbered.append((_start, _dur, _num, _text))
SCRIPT = _renumbered

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

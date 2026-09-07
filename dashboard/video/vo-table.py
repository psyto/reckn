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
for line in (here / "beats.tsv").read_text().splitlines():
    t, label = line.split("\t")
    beats[label] = float(t)
    order.append(label)
END = beats["END"]

# Card lengths are derived by holdFor() in record.js; the two composite plates (opening
# and closing) run on their own timers. Only the gaps matter here, and every one of them is
# read from beats.tsv rather than assumed.
def at(label): return beats[label]

CLOSE = 7.0   # closingPlate(7000)

SCRIPT = [
    (at("01 PNG: two agents disagree"), 8.5, 1,
     "An agent paid another agent for work. They disagree about what was delivered. Who decides?"),
    (at("03 evidence: opinion vs re-execution"), 7.0, 2,
     "Two judges, one dispute. One reads the seller's claim and believes it."),
    (at("03 evidence: opinion vs re-execution") + 7.5, 7.0, 3,
     "The other replays the work. It produced six, not a thousand and twenty-four."),
    (at("01 evidence: live page, bytecode check"), 9.5, 4,
     "That page is not a screenshot. Your browser just read Arc and compared the contract holding the money against our source."),
    (at("01 evidence: live page, bytecode check") + 10.0, 9.0, 5,
     "Byte for byte. And it is a build condition — an owner, an admin, a pause, and the build fails."),
    (at("02 evidence: fund"), 7.5, 6,
     "A funded deal in USDC. Its release condition is not a signature."),
    (at("02 evidence: BindingMismatch"), 10.0, 7,
     "Now a real Groth16 proof goes in — valid, of a different execution. Binding mismatch. The money does not move."),
    (at("02 evidence: BindingMismatch") + 10.5, 8.0, 8,
     "The deal's own proof releases it. A proof of a decrease refunds the buyer. Nobody approved either."),
    (at("03 evidence: what it replaces"), 10.0, 9,
     "Normally a person approves a release. That person is a queue, and agents do not stop. Deciding these four cost under three cents."),
    (at("04 evidence: four settlements"), 10.0, 10,
     "Four settlements on Arc testnet, read out of the receipts by your browser. Two were decided by proofs about work performed on Solana."),
    (at("17 SVG: out to Arc, scope held"), 8.5, 11,
     "Nothing is bridged. The work happened on Solana; a zkVM re-executed it. The proof crosses — nothing else does."),
    (at("06 evidence: the two rows"), 7.0, 12,
     "Arc never runs a Solana virtual machine, and that limit is on the page."),
    (at("06 evidence: the two rows") + 7.5, 8.0, 13,
     "It recomputes a bank hash over the set the deal named. Consistency, not provenance."),
    (at("07 evidence: typing"), 6.5, 14,
     "The one thing an observer controls is the story. Watch what it moves."),
    (at("07 evidence: typing") + 7.0, 6.5, 15,
     "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved."),
    (END - CLOSE, CLOSE, None,
     "plate: **Reckn makes payment conditional on reproducible work. / Reproduce, or refund.** — hold, then silence"),
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

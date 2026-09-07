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
    (0.0, 7.3, None, "plate: **Reckn** — the one-liner, then *An agent paid another agent. They disagree. Who decides?*"),
    (at("00 evidence: opinion vs re-execution"), 7.5, 1,
     "Two judges, one dispute. One reads the seller's claim and believes it."),
    (at("00 evidence: opinion vs re-execution") + 8.0, 7.0, 2,
     "The other replays the work. It produced six, not a thousand and twenty-four."),
    (at("01 evidence: live page, bytecode check"), 10.0, 3,
     "That page is not a screenshot. Your browser just read Arc and compared the contract holding the money against our source."),
    (at("01 evidence: live page, bytecode check") + 10.5, 9.5, 4,
     "Byte for byte. And it is a build condition — an owner, an admin, a pause, and the build fails."),
    (at("02 evidence: fund"), 7.5, 5,
     "A funded deal in USDC. Its release condition is not a signature."),
    (at("02 evidence: BindingMismatch"), 10.0, 6,
     "Now a real Groth16 proof goes in — valid, of a different execution. Binding mismatch. The money does not move."),
    (at("02 evidence: BindingMismatch") + 10.5, 8.0, 7,
     "The deal's own proof releases it. A proof of a decrease refunds the buyer. Nobody approved either."),
    (at("03 evidence: what it replaces"), 9.0, 8,
     "Normally a person approves a release. That person is a queue, and agents do not stop."),
    (at("03 evidence: what it replaces") + 9.5, 9.0, 9,
     "All four settlements cost under three cents to decide, computed here from their receipts."),
    (at("04 evidence: four settlements"), 8.0, 10,
     "Four settlements on Arc testnet, read out of the receipts by your browser."),
    (at("04 evidence: four settlements") + 8.5, 8.0, 11,
     "Two were decided by proofs about work performed on Solana."),
    (at("05 evidence: what crosses"), 7.0, 12,
     "Nothing is bridged. The work happened on Solana; a zkVM re-executed it."),
    (at("05 evidence: what crosses") + 7.5, 6.5, 13,
     "The proof crosses. Nothing else does. Arc never runs a Solana virtual machine."),
    (at("06 evidence: the two rows"), 7.0, 14,
     "That distinction is ours to make, not to hide."),
    (at("06 evidence: the two rows") + 7.5, 8.0, 15,
     "It recomputes a bank hash over the set the deal named. Consistency, not provenance."),
    (at("07 evidence: typing"), 8.0, 16,
     "The one thing an observer controls is the story. Watch what it moves."),
    (at("07 evidence: typing") + 8.5, 9.0, 17,
     "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved."),
    (END - CLOSE, CLOSE, None,
     "plate: **Reckn makes payment conditional on reproducible work. / Reproduce, or refund.** — hold, then silence"),
]

def mmss(t): return f"{int(t // 60)}:{int(t % 60):02d}"

rows = ["| # | in | for | words | line |", "|---|---|---|---|---|"]
over = 0
for start, dur, n, text in SCRIPT:
    if n is None:
        rows.append(f"| — | {mmss(start)} | {dur:.1f} s | — | *({text})* |")
        continue
    words, budget = len(text.split()), int(dur * WPM / 60)
    if words > budget:
        over += 1
    flag = "" if words <= budget else " ⚠ **OVER**"
    rows.append(f"| {n} | {mmss(start)} | {dur:.1f} s | {words} / {budget} | \"{text}\"{flag} |")

print("\n".join(rows))
if over:
    print(f"\n{over} line(s) run past their shot at {WPM} wpm.", file=sys.stderr)
    sys.exit(1)

# English voice-over — timecoded to `reckn-arc-demo.mp4`

**This is not a recorded track. It is the script and the procedure for making one.**
No speech audio ships from this repository; saying otherwise would be the one lie the rest
of the project is built to avoid. What exists is below, plus a synthetic scratch track for
checking pace — clearly marked, and not the deliverable.

**Read at ~145 words per minute, conversational, no music.** Each line's word budget is the
cell beside it: going over means the voice runs past its shot. Lines are written to say what
the picture does *not* — the on-screen chapter cards are already saying the claim, so the
voice supplies the evidence, never the caption.

**This table is generated** by `python3 dashboard/video/vo-table.py`, from the `beats.tsv`
the recorder writes on every run — not from arithmetic. The first draft of this table was arithmetic and its last line landed at
2:48 against a 2:08 cut; regenerating it from the measured beats also flagged six lines as
running past their shots, one of them into a window that was NEGATIVE. Those are trimmed
here. Both cuts (`reckn-arc-demo.mp4` with cards, `reckn-arc-demo-clean.mp4` without) hold
identically, so the table fits either.

The `words / budget` column is the count against 145 wpm for that shot. Every line fits.

---

| # | in | for | words | line |
|---|---|---|---|---|
| — | 0:00 | 7.3 s | — | *(plate: **Reckn** — the one-liner, then *An agent paid another agent. They disagree. Who decides?*)* |
| 1 | 0:09 | 7.5 s | 12 / 18 | "Two judges, one dispute. One reads the seller's claim and believes it." |
| 2 | 0:17 | 7.0 s | 13 / 16 | "The other replays the work. It produced six, not a thousand and twenty-four." |
| 3 | 0:26 | 10.0 s | 21 / 24 | "That page is not a screenshot. Your browser just read Arc and compared the contract holding the money against our source." |
| 4 | 0:36 | 9.5 s | 20 / 22 | "Byte for byte. And it is a build condition — an owner, an admin, a pause, and the build fails." |
| 5 | 1:02 | 7.5 s | 12 / 18 | "A funded deal in USDC. Its release condition is not a signature." |
| 6 | 1:10 | 10.0 s | 20 / 24 | "Now a real Groth16 proof goes in — valid, of a different execution. Binding mismatch. The money does not move." |
| 7 | 1:21 | 8.0 s | 17 / 19 | "The deal's own proof releases it. A proof of a decrease refunds the buyer. Nobody approved either." |
| 8 | 1:46 | 9.0 s | 16 / 21 | "Normally a person approves a release. That person is a queue, and agents do not stop." |
| 9 | 1:55 | 9.0 s | 14 / 21 | "All four settlements cost under three cents to decide, computed here from their receipts." |
| 10 | 2:07 | 8.0 s | 13 / 19 | "Four settlements on Arc testnet, read out of the receipts by your browser." |
| 11 | 2:15 | 8.0 s | 10 / 19 | "Two were decided by proofs about work performed on Solana." |
| 12 | 2:26 | 7.0 s | 12 / 16 | "Nothing is bridged. The work happened on Solana; a zkVM re-executed it." |
| 13 | 2:33 | 6.5 s | 13 / 15 | "The proof crosses. Nothing else does. Arc never runs a Solana virtual machine." |
| 14 | 2:40 | 7.0 s | 9 / 16 | "That distinction is ours to make, not to hide." |
| 15 | 2:47 | 8.0 s | 14 / 19 | "It recomputes a bank hash over the set the deal named. Consistency, not provenance." |
| 16 | 2:57 | 8.0 s | 13 / 19 | "The one thing an observer controls is the story. Watch what it moves." |
| 17 | 3:05 | 9.0 s | 14 / 21 | "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved." |
| — | 3:11 | 7.0 s | — | *(plate: **Reckn makes payment conditional on reproducible work. / Reproduce, or refund.** — hold, then silence)* |

---

## Recording it

1. **Read it once against the picture before recording.** The word budgets assume 145 wpm;
   if a line runs long, cut the *second* half — the first clause carries the evidence.
2. **No music.** The event requires audio without it, and a proof-of-execution demo scored
   like a product trailer argues against itself.
3. **Do not read the cards aloud.** They are already on screen. Line 5 is the only place
   where voice and picture say nearly the same thing, and that is deliberate.
4. Any tool is fine — the founder is generating this in Google Vids. Export mono or stereo
   AAC and mux:

   ```bash
   ffmpeg -i dashboard/media/reckn-arc-demo.mp4 -i vo.m4a \
     -c:v copy -c:a aac -shortest dashboard/media/reckn-arc-demo-vo.mp4
   ```

5. **Check the result before submitting**, because the event's floor is a hard one:

   ```bash
   bash dashboard/video/check.sh dashboard/media/reckn-arc-demo-vo.mp4
   ```

## The scratch track

`bash dashboard/video/scratch-vo.sh` renders these lines with the macOS `say` voice at the
timecodes above, producing `dashboard/media/vo-scratch.m4a`. **It is for checking pace and
nothing else** — a synthetic voice on a submission would read as the one corner we cut. Use
it to find the lines that run long, then throw it away.

# English voice-over — timecoded to `reckn-arc-demo.mp4`

**This is not a recorded track. It is the script and the procedure for making one.**
No speech audio ships from this repository; saying otherwise would be the one lie the rest
of the project is built to avoid. What exists is below, plus a synthetic scratch track for
checking pace — clearly marked, and not the deliverable.

**Read at ~145 words per minute, conversational, no music.** Each line's word budget is the
cell beside it: going over means the voice runs past its shot. Lines are written to say what
the picture does *not* — the on-screen chapter cards are already saying the claim, so the
voice supplies the evidence, never the caption.

**Timecodes are generated from `beats.tsv`, which the recorder writes on every run** — not
from arithmetic. The first draft of this table was arithmetic and its last line landed at
2:48 against a 2:08 cut; regenerating it from the measured beats also flagged six lines as
running past their shots, one of them into a window that was NEGATIVE. Those are trimmed
here. Both cuts (`reckn-arc-demo.mp4` with cards, `reckn-arc-demo-clean.mp4` without) hold
identically, so the table fits either.

The `words / budget` column is the count against 145 wpm for that shot. Every line fits.

---

| # | in | for | words | line |
|---|---|---|---|---|
| — | 0:00 | 3.7 s | — | *(card **No key can move the money.** — silence)* |
| 1 | 0:03 | 9.5 s | 21 / 22 | "That page is not a screenshot. Your browser just read Arc and compared the contract holding the money against our source." |
| 2 | 0:13 | 9.3 s | 20 / 22 | "Byte for byte. And it is a build condition — an owner, an admin, a pause, and the build fails." |
| — | 0:23 | 4.2 s | — | *(card **A real proof can still be the wrong proof.**)* |
| 3 | 0:30 | 6.1 s | 12 / 14 | "A funded deal in USDC. Its release condition is not a signature." |
| 4 | 0:36 | 9.5 s | 21 / 22 | "Now a real Groth16 proof goes in — cryptographically valid, of a different execution. Binding mismatch. The money does not move." |
| 5 | 0:46 | 6.0 s | 9 / 14 | "The deal's own proof releases it. Nobody approved that." |
| 6 | 0:53 | 6.6 s | 10 / 15 | "A proof that the balance went down refunds the buyer." |
| — | 0:59 | 3.7 s | — | *(card **The money stays on Arc.**)* |
| 7 | 1:03 | 5.5 s | 13 / 13 | "Four settlements on Arc testnet, read out of the receipts by your browser." |
| 8 | 1:09 | 5.0 s | 9 / 12 | "Two were decided by proofs about work on Solana." |
| — | 1:14 | 3.7 s | — | *(card **This is not a bridge.**)* |
| 9 | 1:18 | 5.5 s | 11 / 13 | "Nothing is bridged. The USDC is on Arc at both ends." |
| 10 | 1:24 | 6.0 s | 11 / 14 | "Only a proof crosses. Arc never runs a Solana virtual machine." |
| — | 1:30 | 4.7 s | — | *(card **The proof decides the payout. It does not prove state origin.**)* |
| 11 | 1:34 | 4.5 s | 9 / 10 | "That distinction is ours to make, not to hide." |
| 12 | 1:39 | 6.0 s | 14 / 14 | "It recomputes a bank hash over the set the deal named. Consistency, not provenance." |
| — | 1:45 | 3.7 s | — | *(card **Check it yourself.**)* |
| 13 | 1:50 | 6.5 s | 13 / 15 | "The one thing an observer controls is the story. Watch what it moves." |
| 14 | 1:57 | 6.0 s | 14 / 14 | "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved." |
| — | 2:03 | 4.1 s | — | *(card **Reproduce, or refund.** — hold, then silence)* |

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

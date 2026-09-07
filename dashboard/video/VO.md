# English voice-over — timecoded to `reckn-arc-demo-v2.mp4`

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
here. Each cut now writes its OWN beats file — `beats.tsv` for the carded master,
`beats-clean.tsv` for the clean one. They shared a single file until 2026-09-07, which meant
whichever take finished last silently decided the timecodes this table was built from. The
table below is the master's.

The generator also checks that each line ends before the SHOT it is anchored to ends. The
word budget alone never caught that: a line can be comfortably paced and still describe a
picture that left the screen ten seconds ago.

The `words / budget` column is the count against 145 wpm for that shot. Every line fits,
and no line runs past its shot.

---

| # | in | for | words | line |
|---|---|---|---|---|
| 1 | 0:00 | 8.5 s | 15 / 20 | "An agent paid another agent for work. They disagree about what was delivered. Who decides?" |
| 2 | 0:14 | 7.0 s | 12 / 16 | "Two judges, one dispute. One reads the seller's claim and believes it." |
| 3 | 0:22 | 7.0 s | 13 / 16 | "The other replays the work. It produced six, not a thousand and twenty-four." |
| 4 | 0:29 | 9.5 s | 21 / 22 | "That page is not a screenshot. Your browser just read Arc and compared the contract holding the money against our source." |
| 5 | 0:39 | 9.0 s | 20 / 21 | "Byte for byte. And it is a build condition — an owner, an admin, a pause, and the build fails." |
| 6 | 1:02 | 7.5 s | 12 / 18 | "A funded deal in USDC. Its release condition is not a signature." |
| 7 | 1:10 | 10.0 s | 20 / 24 | "Now a real Groth16 proof goes in — valid, of a different execution. Binding mismatch. The money does not move." |
| 8 | 1:21 | 8.0 s | 17 / 19 | "The deal's own proof releases it. A proof of a decrease refunds the buyer. Nobody approved either." |
| 9 | 1:38 | 10.0 s | 23 / 24 | "Normally a person approves a release. That person is a queue, and agents do not stop. Deciding these four cost under three cents." |
| 10 | 1:54 | 10.0 s | 23 / 24 | "Four settlements on Arc testnet, read out of the receipts by your browser. Two were decided by proofs about work performed on Solana." |
| 11 | 2:09 | 8.5 s | 19 / 20 | "Nothing is bridged. The work happened on Solana; a zkVM re-executed it. The proof crosses — nothing else does." |
| 12 | 2:25 | 7.0 s | 14 / 16 | "Arc never runs a Solana virtual machine, and that limit is on the page." |
| 13 | 2:33 | 8.0 s | 14 / 19 | "It recomputes a bank hash over the set the deal named. Consistency, not provenance." |
| 14 | 2:42 | 6.5 s | 13 / 15 | "The one thing an observer controls is the story. Watch what it moves." |
| 15 | 2:49 | 6.5 s | 14 / 15 | "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved." |
| — | 2:56 | 7.0 s | — | *(plate: **Reckn makes payment conditional on reproducible work. / Reproduce, or refund.** — hold, then silence)* |

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

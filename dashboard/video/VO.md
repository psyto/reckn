# English voice-over — timecoded to `reckn-demo-v3.mp4`

**This is not a recorded track. It is the script and the procedure for making one.**
No speech audio ships from this repository; saying otherwise would be the one lie the rest
of the project is built to avoid. What exists is below, plus a synthetic scratch track for
checking pace — clearly marked, and not the deliverable.

**This is the v3 cut, which opens on the theft.** The first three lines run over a live
screen rather than a title card, so they say only what a viewer cannot read for themselves —
the picture is doing the arguing and the voice must not race it.

**The `-cwf` cut is the same film**: identical footage, identical timings, and only the
opening question and the closing line differ. Lines 1–14 fit it unchanged.

**Read at ~145 words per minute, conversational, no music.** Each line's word budget is the
cell beside it: going over means the voice runs past its shot. Lines are written to say what
the picture does *not* — the on-screen chapter cards are already saying the claim, so the
voice supplies the evidence, never the caption.

**This table is generated** by `python3 dashboard/video/vo-table.py`, from the `beats.tsv`
the recorder writes on every run — not from arithmetic. The first draft of this table was arithmetic and its last line landed at
2:48 against a 2:08 cut; regenerating it from the measured beats also flagged six lines as
running past their shots, one of them into a window that was NEGATIVE. Those are trimmed
here. Each cut writes its OWN beats file — `beats-v3.tsv`, `beats-v3-cwf.tsv`, and the `-clean`
pair. They shared a single file until 2026-09-07, which meant
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
| 1 | 0:01 | 7.0 s | 14 / 16 | "This escrow holds two hundred and fifty dollars. Nobody has a key to it." |
| 2 | 0:09 | 7.5 s | 16 / 18 | "That is a real Groth16 proof. It verifies. It is a proof of a different execution." |
| 3 | 0:17 | 7.0 s | 13 / 16 | "Binding mismatch. The money did not move. A valid proof was not enough." |
| — | 0:24 | 9.0 s | — | *(plate: **Reckn — Keep assets native. Settle on proof.** then the door question)* |
| 4 | 0:35 | 9.0 s | 15 / 21 | "Nobody could have overridden it. This escrow has no owner, no admin and no resolver." |
| 5 | 0:44 | 7.5 s | 14 / 18 | "And that is a build condition — if one appeared, the build would fail." |
| 6 | 0:59 | 7.0 s | 13 / 16 | "The proof this deal was funded against reproduces, and the seller is paid." |
| 7 | 1:07 | 8.5 s | 13 / 20 | "A delivery that did not reproduce refunds the buyer. Same machinery, both directions." |
| 8 | 1:22 | 8.5 s | 16 / 20 | "What was removed is not a fee. It is the person who had to approve it." |
| 9 | 1:34 | 8.5 s | 16 / 20 | "The work happened on Solana; a zkVM re-executed it. The proof crosses. The money does not." |
| 10 | 1:49 | 10.0 s | 23 / 24 | "Four settlements on Arc testnet, read out of the receipts by your browser. Two were decided by proofs about work performed on Solana." |
| 11 | 2:07 | 7.5 s | 14 / 18 | "Arc never runs a Solana virtual machine, and that limit is on the page." |
| 12 | 2:15 | 5.0 s | 3 / 12 | "Consistency, not provenance." |
| 13 | 2:20 | 6.5 s | 13 / 15 | "The one thing an observer controls is the story. Watch what it moves." |
| 14 | 2:27 | 6.0 s | 14 / 14 | "Every keystroke, a new hash. The binding and the verdict come from Arc, unmoved." |
| — | 2:34 | 8.0 s | — | *(plate: **Keep assets native. Settle on proof.** then the door's last line)* |

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

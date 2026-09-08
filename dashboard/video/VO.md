# English voice-over — timecoded to `reckn-demo-v3.mp4` (the four-checks cut)

**This is not a recorded track. It is the script and the procedure for making one.**
No speech audio ships from this repository; saying otherwise would be the one lie the rest
of the project is built to avoid. What exists is below, plus a synthetic scratch track for
checking pace — clearly marked, and not the deliverable.

**This is the v3 cut, which opens on the theft.** The first three lines run over a live
screen rather than a title card, so they say only what a viewer cannot read for themselves —
the picture is doing the arguing and the voice must not race it.

**The `-cwf` cut is the same film**: identical footage, identical timings, and only the
opening question and the closing line differ. Lines 1–14 fit it unchanged.

**A HUMAN must read this. The event forbids a synthetic voice, and there is no instrument
in this repository that can tell one from the other** — `check.sh` can prove an audio track
exists and is not silence, and it stops there. That last step is a person's signature, not a
green tick.

**One rule decides who is speaking, on screen and in the voice alike: green is the CHAIN's
voice, cream and warm grey are ours.** The captions used to be centred with a green second
line — the same green the live UI uses for its own output — so a viewer could not tell our
commentary from the app's. Everything of ours is now left-aligned at the deck's own margin
and carries no green at all.

**Slides are revealed a band at a time rather than held.** Read the lines at the pace the
slide fills in; the evidence arrives after the words, not under them.

**Three deck slides carry no narration on purpose, and two of them carry only one line.**
A narrator reciting text that is already on screen is the fastest way to make a good demo
feel like a bad one. Where a slide states the argument, the voice names the insight the slide
does *not* state and then stops. The inversion slide is silent end to end — one sentence in
very large type, and the only pause this film has.

**Read at ~145 words per minute, conversational, no music.** The lines are written to be
spoken on a first take: contractions, one idea per breath, no stacked noun phrases. If a
line makes you stumble, change it and re-run `vo-table.py` — it will tell you whether the
new wording still fits its shot. Each line's word budget is the cell beside it.

**Rebuilding this table used to be able to blank it.** The generator raised a bare `KeyError`
when a beat was renamed, and a caller piping its stdout wrote the empty result straight into
this file. It now names the missing label and lists the beats the cut actually has, and the
rebuild refuses to write a table with fewer than fourteen rows.

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
| — | 0:00 | 8.0 s | — | *(plate: **Reckn — Keep assets native. Settle on proof.** then the door question)* |
| 1 | 0:09 | 6.5 s | 14 / 15 | "Nobody can move this money. Not the seller, not the buyer, and not us." |
| 2 | 0:22 | 6.0 s | 14 / 14 | "That is easy to say, so don't take our word for it. Four checks." |
| 3 | 0:32 | 6.5 s | 14 / 15 | "Here's a funded deal. Two hundred and fifty dollars, and no key to it." |
| 4 | 0:40 | 8.0 s | 19 / 19 | "That's a real Groth16 proof. It verifies. It's just about a different job — so the money stays put." |
| 5 | 0:54 | 6.0 s | 12 / 14 | "The proof this deal was funded against reproduces. The seller gets paid." |
| 6 | 1:01 | 8.0 s | 13 / 19 | "And when the work doesn't reproduce, the same machinery sends the money back." |
| 7 | 1:11 | 7.5 s | 16 / 18 | "Check two. Your browser reads the contract off the chain and compares it to our source." |
| 8 | 1:22 | 9.0 s | 19 / 21 | "Byte for byte. And if an owner or an admin ever showed up in it, the build would fail." |
| 9 | 1:34 | 7.0 s | 10 / 16 | "Check three. Four settlements, in real money, on Arc testnet." |
| 10 | 1:47 | 9.0 s | 17 / 21 | "Two of them were decided by proofs about work done on Solana. One escrow, two virtual machines." |
| 11 | 2:03 | 7.5 s | 12 / 18 | "The proof crosses. The money never does. There's no bridge in here." |
| 12 | 2:12 | 9.0 s | 14 / 21 | "Check four is the one nobody else shows you: what this does not prove." |
| 13 | 2:29 | 8.5 s | 15 / 20 | "It's consistency, not provenance. And it doesn't save you from holding funds where you pay." |
| 14 | 2:40 | 8.0 s | 10 / 19 | "So go and check it. Nothing to install, no wallet." |
| — | 2:48 | 6.0 s | — | *(plate: the door's last line)* |

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

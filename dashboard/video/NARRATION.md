# Narration script — timed to `reckn-arc-demo-clean.mp4`

For the composite: pitch video + this screen footage + a generated voice track. The
timings below are the **recorder's own beat durations**, not estimates — both cuts hold
for identical lengths, so this script fits `reckn-arc-demo-clean.mp4` (no titles, for when
you add your own) and `reckn-arc-demo.mp4` (titles burned in) equally.

**Read at ~145 words per minute.** Each line's word budget is the cell next to it; going
over means the voice runs past its shot. Every line is written to say something the
picture does *not* — narration that reads the on-screen text aloud is how a good demo
reads like a bad one.

**Total screen footage ≈ 1:45, and the narration now runs to ≈ 2:05** because beat 9b adds twenty seconds of the boundary explanation over held shots. The event requires **2–4 minutes**, so the pitch section
must carry **at least 20 seconds** and comfortably more. Suggested split: **60–75 s of
pitch, then this footage.**

---

## Before the footage — the pitch section (60–75 s, ~150–185 words)

> Not screen-recorded; this is the part you speak to camera or over a title.

```
When one AI agent pays another and the delivery is disputed, someone has to decide who
was right. Every answer on offer today is a party with a key — an operator inside a
trusted enclave, a bonded resolver, a quorum of voters. That party has to be redeployed
and re-trusted on every chain your agent touches.

Reckn's answer is that the decider should not be a party at all. The disputed work is
re-executed: the pre-state is pinned, the work is replayed against it, and the condition
the payment was funded against is evaluated. Reproduce, or refund.

Because re-execution is deterministic, anyone can redo it and get the same verdict. And
because it is a computation rather than an authority, it does not belong to a chain.

What you are about to see is a live escrow on Arc, holding real testnet USDC, that no key
can open. Everything on screen is a real chain — nothing is a mock.
```

---

## Over the footage

| # | at | for | words | line |
|---|---|---|---|---|
| 1 | 0:00 | 3.0 s | ≤ 7 | *(silence — let the first shot land)* |
| 2 | 0:03 | 11 s | ≤ 26 | "Two agents disagree about a delivery. One of them reads the claim and forms an opinion. The other replays the work and reports what actually happened." |
| 3 | 0:14 | 6 s | ≤ 14 | "The opinion can be argued with. The replay cannot." |
| 4 | 0:20 | 4 s | ≤ 10 | "So don't take our word for it — try to steal the money." |
| 5 | 0:26 | 8 s | ≤ 19 | "Here is a funded escrow denominated in USDC. The condition on it is not a signature. It is a proof." |
| 6 | 0:34 | 10 s | ≤ 24 | "This is a real Groth16 proof — of a different execution. It verifies. It is simply not about this deal, so the money does not move." |
| 7 | 0:44 | 7 s | ≤ 17 | "The deal's own proof releases it. No approval, no resolver, no signer." |
| 8 | 0:51 | 8 s | ≤ 19 | "And when the work did not reproduce, the same mechanism sends the money back to the buyer." |
| 9 | 0:59 | 10 s | ≤ 24 | "Now the same escrow, settled by a proof about work performed on Solana. One contract, two virtual machines." |
| **9b** | **1:09** | **20 s** | **≤ 48** | **The boundary. Do not skip it — without it a viewer cannot tell this from a bridge or an oracle.** "Nothing is bridged. The USDC is on Arc at the start and on Arc at the end — only a proof crosses, and Arc never runs a Solana VM. It checks that one program executed correctly. What that buys is conditional settlement on a re-executed result. What it does **not** buy is proof that those inputs came from Solana mainnet — the guest recomputes a bank hash over the account set the deal named, which is consistency, not provenance. We say both halves." |
| 10 | 1:29 | 9 s | ≤ 21 | "And if nobody ever proves anything, the money still comes home — anyone can call the refund, and calling it earns them nothing." |
| 11 | 1:38 | 4 s | ≤ 10 | "Everything so far was a local chain. This is not." |
| 12 | 1:42 | 12 s | ≤ 29 | "Your browser is reading Arc testnet right now. It just compared the bytecode holding the money against the source in the repository — byte for byte identical. Four settlements, two of them decided by proofs about Solana." |
| 13 | 1:54 | 6 s | ≤ 14 | "One deal is frozen: the stablecoin blacklisted its recipient. It is refundable, and we left it there." |
| 14 | 2:00 | 5 s | ≤ 12 | "There is no key that can move a funded escrow. It is a build condition, not a promise." |

---

## Notes for the edit

- **Line 6 is the money shot.** Hold on the revert. If anything gets extra time, this.
- **Do not narrate over the failing transaction's error text** — let it be read.
- Line 12 is the longest; if the voice runs over, cut "byte for byte identical" (the
  screen already says it) rather than the settlement count.
- The closing shot is the actual stdout of `scripts/no-keys.sh` from that recording run,
  not a transcription of an older one. It is worth one beat of silence.
- **No music.** The event requires audio without music, and a proof-of-execution demo
  scored like a product trailer undercuts itself.

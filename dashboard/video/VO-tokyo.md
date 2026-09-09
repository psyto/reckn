# Tokyo voice-over — the closing lines only

**This file does not replace [`VO.md`](VO.md) and does not touch the ETHOnline cut.** It
exists so that the call to action can change for a room full of builders without editing a
script that is already attached to a submission. Lines 1–13 of `VO.md` are used **unchanged**;
only line 14 and the closing plate differ, which is the same shape the `-cwf` cut already uses.

**The ETHOnline narration is still not recorded.** Nothing here changes that, and nothing here
should be read as though it were done. `dashboard/video/check.sh` reports `audio ✗ NO TRACK`
on the current cut, and that is the honest status until somebody reads `VO.md` into a
microphone. **No synthetic voice ships.** The scratch track exists to check pace and is thrown
away — a generated voice on a submission would be the one corner cut in a project whose whole
argument is that it cuts none.

---

## Why the ending changes for Tokyo

The ETHOnline ending asks the viewer to **check** something: *"So go and check it. Nothing to
install, no wallet."* That is right for a judge deciding whether to believe a claim.

A room of builders is not deciding whether to believe it. The useful ask is **bring me a job**,
and the difference matters: "go and look" produces admiration, "bring one step" produces a
deal with somebody else's wallet in it — which is the only thing that will count as adoption
later.

---

## The CTA has two stages, and stage two is gated

**Stage 1 — while the Partner Kit is incomplete.** This is the truthful line today:

> **"If your agent has a job that can be replayed, talk to us. We're opening the integration
> kit on Arc testnet."**

It promises a conversation and an intent. It does **not** promise that a stranger can run
anything, because right now they cannot.

**Stage 2 — only after every box below is ticked.** Do not record this line before then:

> **"Have a deterministic job your agent needs to settle? Run the starter on Arc testnet.
> Your wallet. Your job. No one decides the payout."**

**The gate.** Stage 2 says *run the starter*, so it may be said only when a stranger actually
can:

- [ ] `createDeal` / `sellerPreflight` / `submitProof` / `verifySettlement` exist and are
      documented in [`docs/partner-kit.md`](../../docs/partner-kit.md)
- [ ] the deal binding a partner computes is checked against golden vectors derived from the
      guest's own output, and the test passes
- [ ] the starter runs end to end on a local chain from a clean clone, **happy path and refund
      path**
- [ ] the Arc testnet path is written for **the partner's own wallet**, with the faucet,
      funding and proving time stated rather than hidden
- [ ] no private key appears in any command, README, or `.env.example`
- [ ] **at least one person who is not us has run it**

The last box is the one that makes the sentence true rather than aspirational. Until it is
ticked, stage 1 is the line.

## The Tokyo closer

Short enough to say at the end of a live demo, and it asks for exactly one thing:

> **"Bring one deterministic step from your agent. We'll open a test deal with your wallet,
> replay it, and settle it on proof."**

Three details in it are load-bearing and should not be smoothed away:

- **"one deterministic step"** — not "your agent", not "your workflow". Reckn settles the step
  that was fixed in advance, and asking for more than that oversells it in the first sentence.
- **"with your wallet"** — the partner funds it. A deal we fund on their behalf demonstrates
  our tooling, not their adoption.
- **"settle it on proof"** — not "verify it", not "prove it works". The payout is the point.

---

## The line table, as a diff against `VO.md`

Lines 1–13 and their timings are unchanged. Only these differ:

| # | in | for | words | line |
|---|---|---|---|---|
| 14 | 2:59 | 8.0 s | 17 / 19 | **stage 1:** "If your agent has a job that can be replayed, talk to us. We're opening the integration kit on Arc testnet." |
| 14 | 2:59 | 8.0 s | 19 / 19 | **stage 2:** "Have a deterministic job your agent needs to settle? Run the starter on Arc testnet. Your wallet. Your job." |
| — | 3:08 | 6.0 s | — | *(plate: the Tokyo closer, on screen rather than spoken — it is an ask, and an ask reads better than it listens)* |

Word counts are against the same 145 wpm budget `VO.md` uses. Stage 1 is 17 words in a
19-word shot; stage 2 is 19 in 19 and has **no room** — if it runs long when read aloud, cut
*"Your job."* first, not *"Your wallet."*, because the wallet is the part that makes it about
the listener.

## What must not be said in the Tokyo cut

- **Do not claim adoption that has not happened.** Until a team outside this project has
  opened a deal with their own wallet, "teams are using it" is false. `docs/tokyo-partner-pilot.md`
  defines what may be claimed at one team and at three.
- **Do not present the Tempo work as event work for ETHOnline.** It is not in that
  submission, deliberately, and it is not to be mixed in afterwards.
- **Do not say the video is narrated when it is not.** The audio row is red until it is not.
- Everything in [`docs/messaging.md`](../../docs/messaging.md) §2 still applies — in
  particular the thirty-day timeout is never conflated with the proof-driven refund, and
  provenance is never claimed.

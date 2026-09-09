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

> **Correction, 2026-09-09.** Stage one used to read "talk to us — we're opening the kit on
> Arc testnet", and that was weaker than the truth. The gate belongs on the **Arc testnet path
> with your own wallet**, which nobody outside this project has walked. The **local** starter
> needs no wallet, no funds and no key, and it was verified end to end on 2026-09-09: release,
> refund, and a real proof of a different job refused, exit 0. Telling people to email us about
> something they could already run was under-claiming, which is its own kind of inaccuracy.


**Stage 1 — while the Partner Kit is incomplete.** This is the truthful line today:

> **"If your agent has a job that can be replayed, clone the starter and run it. No wallet,
> no funds, no key — release, refund, and a real proof of a different job being refused."**

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

## Three chain-specific lines, and the one that keeps them honest

Tokyo and CWF get a *why this chain* beat that the ETHOnline cut does not have. Use whichever
chain the room is about — **never both in one cut**, because the two lines say different things
and stacking them turns a specific claim into a sponsor list.

**Arc.**

> **"Arc is where the dollar stays. The work happened on Solana; the USDC never left Arc."**

**The standard, said at the strength it has earned.** Tokyo is where the ambition may be
stated first rather than last, because the room is about whether an outside team can adopt this:

> **"Reckn is building the standard for proof-driven settlement across execution environments.
> Agents may choose where work happens. Assets remain native. Reproducible execution decides
> payout."**

**`building`, and not a word stronger.** There is no independent adoption, no second
implementation and no standards body — [`messaging.md`](../../docs/messaging.md) names the three
things that would have to be true first, and the five boundaries are in
[`positioning.md`](../../docs/positioning.md#what-a-standard-would-have-to-fix). If someone in
the room asks "whose standard?", the honest answer is *nobody's yet, and here is exactly what
would make it one*.

**Tempo.**

> **"Tempo is not just another EVM deployment. The escrow and the cost of deciding it are paid
> in the same stablecoin."**

**Say the geography before the property, or the property has nowhere to land:**

> **"The work happens on Solana. A TIP-20 stays on Tempo, and a proof about the Solana work
> decides whether it is released or refunded — the token never moves to Solana."**

Backed by [`zk-verdict/contracts/tempo.json`](../../zk-verdict/contracts/tempo.json): chain
**42431** (Moderato testnet), escrow funded with **PathUSD** `0x20C0…0000`, two settlements —
one released on a `Reproduced` proof, one refunded on a `Failed` one — and on **both receipts
the `feeToken` is `0x20c0…0000`**, the token the escrow was holding. That last row is the whole
Tempo argument, and it is read off the receipt rather than asserted.

**And immediately after either one, without a pause:**

> **"Reckn removes a protocol-level judge. It does not erase issuer policy."**

That third line is not a caveat to fit in if there is time. It is the sentence that makes the
first two believable, and on Tempo it is load-bearing: a TIP-20 issuer can pause the token, and
a pause stops a proof-authorised release **and** the thirty-day refund. Saying the good part
without it is the kind of claim a judge checks and a partner discovers later.

Full argument and receipts: [`../../docs/chain-fit.md`](../../docs/chain-fit.md).

## The line table, as a diff against `VO.md`

Lines 1–13 and their timings are unchanged. Only these differ:

| # | in | for | words | line |
|---|---|---|---|---|
| 14 | — | 8.0 s | — | **stage 1 (now):** "If your agent has a job that can be replayed, clone the starter and run it. No wallet, no funds, no key." |
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

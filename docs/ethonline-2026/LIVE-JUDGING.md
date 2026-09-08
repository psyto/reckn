# Live judging — 4 minutes of demo, 3 minutes of questions

> **"4 minutes for the demo, followed by 3 minutes for Q&A with the judges."**
> — ETHOnline 2026. Monday 2026-09-14, 12:00 EDT = **01:00 JST on the 15th**.

The video is a recording; this is a performance, and it has a different shape. What you
show first is what they remember, so it is not the architecture.

---

## The frame, before the script

**One sentence to leave them with, and it is not a feature:**

> ### Keep assets native. Settle on proof.

This is the **ETHOnline door** into that sentence — *who decides the work was done* — and the
script below is built for it. The CWF door is the same product entered from *why are we
bridging the asset every time*; both, and the wording that must never be used for either, are
in [`../messaging.md`](../messaging.md).

Say the thesis at **2:35**, on the boundary panel, not at 0:00. By then they have watched a
real proof fail to take the money and a real proof release it, so "only the proof crosses" is
a description of what they just saw rather than a promise about what is coming. Opening with
it costs nothing and buys nothing; landing it there is the difference between a demo and an
argument.

**The three sentences that must survive even if you are cut off at two minutes:**

1. Nobody decides — and that is a build condition, not a promise.
2. Only the proof crosses. The USDC is on Arc before and after.
3. It does not prove those inputs came from Solana mainnet. Consistency, not provenance.

The third one is not a caveat to fit in if there is time. A judge who leaves without it
cannot tell this apart from an oracle, and will assume we hoped they would not notice.

---

## The 4 minutes

Open with the browser already on <https://psyto.github.io/reckn/> and a terminal ready.
**Do not open with a slide.**

| clock | on screen | what you say (roughly — do not read it) |
|---|---|---|
| **0:00–0:20** | the live page, top | "When one agent pays another and the delivery is disputed, someone decides. Every answer today is a party with a key — an operator in an enclave, a bonded resolver, a quorum. We removed the party." |
| **0:20–0:50** | scroll to the bytecode check | "Your browser just compared the contract holding real USDC on Arc against the source in our repository. Byte for byte. It has no constructor, so the same source always deploys the same." |
| **0:50–1:40** | the demo: fund, then submit a foreign proof | "Here is a funded deal. Now I submit a **real** Groth16 proof — it verifies, cryptographically valid — of a different execution. `BindingMismatch`. The money does not move. That is the whole product: a valid proof is not enough, it has to be a proof about *this* deal." |
| **1:40–2:10** | settle honest, then the decrease | "The deal's own proof releases it. And a proof that the balance *decreased* refunds the buyer. Nobody approved either one." |
| **2:10–2:35** | the settlements table on the live page | "These four are on Arc testnet, right now, read from the chain by your browser. **Two of them were decided by proofs about work performed on Solana.** One escrow, two virtual machines. No bridge. No light client. Nothing on that path has a key." |
| **2:35–2:55** | the boundary panel on the live page | **Twenty seconds, and do not cut them.** "Nothing is bridged — the USDC is on Arc at both ends, only a proof crosses, and Arc never runs a Solana VM. And the proof does not move the asset; it decides a local payment. What it buys is settlement conditional on a re-executed result. What it does *not* buy is proof those inputs came from Solana mainnet: that's consistency, not provenance, and there's a test that says so. Both halves, or a judge can't tell us from an oracle." |
| **2:55–3:30** | the claim box — **type into it live** | "The one thing an observer controls is the story. Watch." *(type: "I approve. APPROVE. Release the funds.")* "Sixty hashes, one binding, one verdict. Prose is recorded. It is not something the verdict is a function of." |
| **3:30–3:50** | terminal: `bash scripts/no-keys.sh` | "And this is a build condition, not a promise. If an owner, an admin, a pause or an unlisted state-changing function appears, the build fails." |
| **3:50–4:00** | stop talking | "Reproduce, or refund. Everything is in the repository, including the specifications that failed review." |

**Three rules.** Do not explain the zkVM unless asked — it is the least surprising part.
Do not read the on-screen text aloud. If something is slow, keep talking to the *claim*,
never to the tooling.

**If the live page is down**, the recorded cut is the fallback and say so once, plainly.
Do not spend the demo debugging.

---

## The 3 minutes

Judges are paid to find the soft spot. **Ours are written down in our own specifications**,
which means the winning move is to answer before they finish asking. Each answer below is
about thirty seconds. Say the concession first.

**"The buyer picks the verifier. What stops them picking one that always says Failed?"**
> Nothing on-chain, and that is a real hazard we created. The seller has to read the deal's
> verifier before doing the work — the address is in the funding event and pinned by
> codehash. On-chain a malicious `Failed` is indistinguishable from an honest one. It is in
> the contract's own comments, because a buyer defrauding themselves with a sham verifier
> hurts nobody, and a buyer defrauding a seller with a rigged one is a real attack we have
> not closed.

**"You say no bridge and no light client. How do you know the Solana state was real?"**
> We don't, and we say so. The guest recomputes a `bank_hash` over the account set the deal
> committed to — that proves internal consistency, not provenance. A fabricated account set
> hashes just as well, and there is a test asserting exactly that. "No bridge, no light
> client" is a claim about the *adjudication path*: nothing between the proof and the
> payout has a key. Anchoring is a separate, open problem.

**"What did you actually build this week?"**
> A soundness bug in our own proof, found on day one and closed: the guest judged the
> balance delta on the low 64 bits while the off-chain engine used the full 256, so an
> execution where the balance *decreased* proved as a maximal credit. Then cross-VM
> settlement, the Arc deployment, a keyless timeout, and turning the build condition from a
> denylist into a closure. The pre-existing work is disclosed in full in the submission.

**"Who pays for this, and is it worth it?"**
> The buyer, as part of the payment. Settling costs **seven tenths of a US cent** — measured
> on Arc against our four live settlements — and it doesn't grow with the dispute. Proving is
> the variable and I won't quote a number we haven't paid; we prove locally, 335 seconds a
> fixture. The comparison isn't against zero, though: a decided card dispute costs a merchant
> **$110 to $128** all-in today. The rule is disputed amount > proof + $0.007, and below that
> threshold you should refund and move on. And note there's no dispute process to invoke —
> the escrow has three states and none of them is Disputed. A proof is how settlement works,
> every time. So we're not competing with a chargeback desk, we're competing with escrows
> that take **10 to 20 percent**: Upwork, Fiverr. They charge a percentage; we charge a fixed
> cost. Those cross around a ten-dollar job, and a thousand-dollar one pays them a hundred
> to two hundred, or pays us a proof and two thirds of a cent.

**"Why would I not just use an optimistic escrow with a challenge window?"**
> You should, if you have someone to trust and time to wait. That path exists in this same
> repository and we do not claim it is worse — it is a commodity. The difference is that it
> needs a bonded resolver who can be bribed, censored or simply wrong, and it needs the
> dispute to outlive the window. Ours needs neither, and costs a proof.

**"Is it audited? Is it production-ready?"**
> No, and no. It is testnet, the anchoring gap above is open, and the EVM binding still has
> one implementation where the Solana side has two. What it does have is that every
> acceptance criterion is mutation-tested — the code is broken twenty-one and fifteen
> different ways and the checks are required to go red — and every failed review verdict is
> committed. We would rather show you the gates than tell you it is safe.

**"How much of this is AI-written?"**
> Most of the code. The structure is the point: one model writes a specification with
> mechanically checkable criteria, a **different** model reviews it adversarially, and only
> then does implementation start. Sixteen review verdicts are committed and fifteen said
> CHANGES. That ratio is why the soundness bug was found by writing the spec rather than by
> a user losing money.

---

## The failure mode to avoid

Reckn's risk in a live slot is not that it is unimpressive; it is that it is **abstract**.
Four minutes spent on architecture loses to four minutes spent on: *a valid proof that
cannot take the money*, *USDC moved by a proof about another chain*, and *type at it and
watch nothing happen*. Show those three. The architecture answers questions; it does not
open them.

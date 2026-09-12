# Traction — the two instruments, their asks, and the ledgers that stay empty until they are not

**Nothing on this page has happened yet.** Every table below is currently empty and says so. This
file exists so that the evidence lands somewhere that cannot be quietly rounded up, and so the word
*adoption* stays unusable until [`../tokyo-partner-pilot.md`](../tokyo-partner-pilot.md) §1 has real
names in it — that rule is not suspended by this page.

**Why these two.** `PREFLIGHT.md` §6 records that four of CWF's seven judging criteria have no
artefact here, and that two of them — market size and viability — were closed by
[`MARKET.md`](MARKET.md) and [`ECONOMICS.md`](ECONOMICS.md). **Traction was the one no document can
close**, because it means somebody outside this repository did something. These are the two cheapest
honest ways to get that, and both were unblocked by the ruling in §0.

---

## 0. Founder ruling 2026-09-12 — `AGENTS.md` §8, narrowly relaxed

`AGENTS.md` §8 forbids, among other things, **contacting external users**. That rule was written for
the ETHOnline lane, and it made traction structurally impossible. The founder has relaxed it **for
these two instruments only**:

**Permitted from 2026-09-12, CWF lane:**

1. asking people outside this repository to **run a published command and report what they got**
2. asking one person to **send a transaction that anyone may already send** — the permissionless
   `refundAfterDeadline` (§2)

**Still forbidden, unchanged:** mainnet deployment · real funds · external service contracts ·
agent rewriting of `PLAN.md` / `DISCLOSURE.md`.

**Explicitly NOT ruled on, and therefore still forbidden:** publishing `@reckn/partner-kit` to npm.
It is close to irreversible and it would flip the premise of `scripts/no-unpublished-cli.sh`, whose
current PASS depends on the documented fact that those names do **not** resolve. If that is wanted,
it is its own decision and its own commit.

**Who acts:** the founder sends both asks. **The agent contacts nobody** — that part of §8 is not
relaxed for agents, and nothing in this repository sends a message.

---

## 1. Instrument A — somebody else reproduces it

The product's claim is reproducibility. So the evidence for it should be **other people
reproducing**, which is also the only traction artefact that needs no wallet, no funds and no key.

**The ask, as it should be sent** (short on purpose — a long ask gets skipped):

> Reckn settles agent payments by re-executing the disputed work and letting a proof decide, with no
> resolver and no admin key. The repo is public. Would you run one command from a fresh clone and
> paste what it printed?
>
> ```sh
> git clone https://github.com/psyto/reckn && cd reckn
> bash zk-verdict/scripts/zk-e2e.sh
> ```
>
> No wallet, no funds, no key. It verifies committed Groth16 proofs and settles a local escrow. I am
> collecting what other machines print, including failures — a failure is the more useful result and
> I will publish it as-is.

**Rules for this ledger, so it cannot become marketing:**

- **Paste their output verbatim.** No trimming, no re-running until it is green. If it failed on
  their machine, the row says it failed and the output shows why.
- **Record the machine** (OS, CPU) and whether the SP1 toolchain was present — `zk-e2e.sh` step 1
  needs it, step 2 runs on committed fixtures with `forge` alone.
- **A reproduction is not an audit**, and this ledger must never be described as one.
- Reports are only counted with the reporter's consent to publish; no name goes here without it.

| date | who (as they wish to be named) | machine | result | output |
|---|---|---|---|---|
| — | — | — | — | — |

**Reports so far: 0.** This row is the honest state, not a placeholder to be quietly deleted.

---

## 2. Instrument B — a stranger returns the money, and gets nothing for it

On **2026-10-08 11:59:56 JST** the thirty days on the Tempo `mismatch` deal elapse, and
`refundAfterDeadline` becomes callable **by anyone**. The caller receives **nothing**: the money goes
to the buyer address that `fund` fixed. *(Derived from the chain on 2026-09-12: funded at block
34352010, timestamp 1788836396 = 2026-09-08 02:59:56 UTC, plus `REFUND_AFTER = 30 days`.)*

**So one ask produces two things at once**: the first demonstration of the keyless timeout on a
public chain, and a transaction whose sender is not us.

| | |
|---|---|
| chain | Tempo Moderato, **42431** — RPC `https://rpc.moderato.tempo.xyz` |
| escrow | `0x7e953a6ac16744ef1a02e343277ec55d7410f439` |
| deal id | `0x35eb5b4e79d4f3dcaee28aeb0cabc5c8e4ce6b3ee8be7e67f40e736ed227957d` |
| holds | 1.000000 PathUSD (`0x20C0…0000`), state `Funded` |
| callable from | **2026-10-08 11:59:56 JST** — earlier reverts with `TooEarly()` |

**The steps, for whoever does it.** Fees on Tempo are paid in a TIP-20, and the faucet is an **RPC
method that needs no key and no wallet connection** — anyone can fund anyone:

```sh
cast rpc tempo_fundAddress <THEIR_ADDRESS> --rpc-url https://rpc.moderato.tempo.xyz
cast send 0x7e953a6ac16744ef1a02e343277ec55d7410f439 \
  "refundAfterDeadline(bytes32)" \
  0x35eb5b4e79d4f3dcaee28aeb0cabc5c8e4ce6b3ee8be7e67f40e736ed227957d \
  --rpc-url https://rpc.moderato.tempo.xyz --account <THEIR_KEYSTORE>
```

**They use their own key and we never see it** — the same discipline as the deployment: a named
Foundry keystore, never a private key in an argument or an environment variable.

**What may be said afterwards, and what may not:**

- ✅ *"The thirty-day refund was called by someone who is not us, on a public chain, and they
  received nothing for it."* — with the transaction hash.
- ❌ **Never merge it with the proof-driven refund.** That one is immediate and is a different thing
  (`messaging.md` §2 has the row).
- ❌ Not *"the timeout works"* as though it had been untested — it has six tests
  (`RecknTimeout.t.sol`); what is new is that a **public chain** finally reached the deadline.
- ❌ Not a claim about mainnet. Tempo mainnet is not deployed.

| date | caller | tx | result |
|---|---|---|---|
| — | — | — | — |

**Calls so far: 0**, and the deal cannot be called before 2026-10-08 — a table that is empty
*because the clock has not arrived* is a different fact from one that is empty because nobody came,
and this line is here so the two do not get conflated.

---

## 3. What is still not closed by either instrument

**Instrument A produces validation, instrument B produces participation. Neither produces a
customer.** The only thing that does is the six-point checklist in
[`../tokyo-partner-pilot.md`](../tokyo-partner-pilot.md) §1 — a deal opened from somebody else's
repository, with their own wallet, against their own job — and its window is ETHGlobal Tokyo,
**2026-09-25 → 09-27**, inside CWF's own window. That remains the highest-value open item on
[`PREFLIGHT.md`](PREFLIGHT.md) §6 and this page does not substitute for it.

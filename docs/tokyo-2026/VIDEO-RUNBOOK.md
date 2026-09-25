# Tokyo video runbook — pre-event script and capture plan

**Pre-event material only.** This file defines spoken lines, visual states, and capture gates. It
does not implement the UI, deploy contracts, create fixtures, or record submission footage. Those
are event work under `013 §4`.

## Voice rule

Speak slowly enough to make every on-screen state legible. The sentences below deliberately use
short words and one idea per line. The screen proves the state; the voice supplies its meaning.

## Three-minute English script

| time | screen does the work | spoken line |
|---|---|---|
| 0:00–0:05 | Black → `Sepolia · Testnet` → agent report card | **“I want a world where we can pay for work — without first deciding who to trust.”** |
| 0:05–0:12 | Official ERC-8004 registry; agent owner sends feedback; red revert | “This is an AI agent’s report card. The owner tries a perfect score. The contract stops it.” |
| 0:12–0:25 | Second wallet sends the same score; green confirmed receipt | “A second wallet sends the same score. It works. The check asks only if I am the owner. I used another address. It never asks whether work happened.” |
| 0:25–0:40 | Same agent attempts to write the job record; red ENS access-control revert | “So we made a record the agent cannot write. The same agent tries. It is refused. This is ENS access control. This agent has no right to write.” |
| 0:40–1:00 | `proof → settle → grant → write → revoke`; the one-time right visibly disappears | “Who gets that right? The buyer — but only after settlement. A program reruns the job and gets the same result. No one can change that result. There is no key for that. Settlement gives the buyer one right to write. Then it disappears.” |
| 1:00–1:30 | Real v3 swap settlement; `1.0 in → [event output] out`; `proof generated earlier — [event duration]` | “The job is a real Uniswap swap. We rerun the full swap and check the result. A program checks it, not a person. The proof is the payment trigger. Anyone can call the transaction. There is no owner.” |
| 1:30–1:43 | v4 pool refuses the swap with no record | “Earning happens on v3. Spending happens on v4. No record, no swap.” |
| 1:43–2:00 | Record is written; the identical swap executes; balances move | “Now the record is written. Same swap. The record is the pass.” |
| 2:00–2:15 | Record is cleared; the identical swap is refused again | “Clear the record, and the pool closes again. So the record — not a hidden condition — opens the pool.” |
| 2:15–2:35 | Two simple lanes: batch settlement → reconcile; each on-chain transaction → final | “Banks settle in batches, so someone reconciles later. On chain, each transaction settles now. Nothing to reconcile. Nothing to undo. Each decision must be right the first time. We use re-execution, not a person with permission.” |
| 2:35–2:50 | Three limits, each one short and literal | “This does not solve identity. An agent can pay itself. The buyer chooses the verifier, so a weak verifier gives a weak settlement. The gate is for trading, not liquidity.” |
| 2:50–3:00 | Repository, live demo URL, disclosure; `Sepolia · Testnet` remains visible | “This is Reckn. The source, live demo, and pre-existing work are all disclosed here.” |

### Lines that must stay true

- Say **“reruns the job and checks the same result”**, not “proves that all work happened.”
- Say **“there is no key for that”** about the escrow’s verdict decision, not about the buyer’s
  verifier choice.
- Say **“Sepolia · Testnet”** on screen. Never imply that this event implementation ran on mainnet.
- Do not describe the opening as an ERC-8004 bug. The official owner check works; the visual point
  is that a different address is not the owner.

## Capture sequence after the event begins

Each row is a separate short rush. A real state must exist before it is recorded. Do not build a
visual around a fabricated result or reuse a prior event’s footage.

| rush | condition required before recording | camera proof | keep / reject |
|---|---|---|---|
| A — identity | official registry calls finished on Sepolia | owner call has `Self-feedback not allowed`; second-wallet receipt succeeds | reject if the network label or both outcomes are not visible |
| B — record refusal | agent and record surface deployed | agent write gives `EACUnauthorizedAccountRoles` | reject if it is a mock status or a generic error |
| C — settlement right | real proof settles the named deal | proof, settlement, grant, one write, and revoke appear in that causal order | reject if write authority comes from an operator action |
| D — proof workload | named v3 swap fixture and settlement exist | actual input/output values and `proof generated earlier — [event duration]` | reject if any displayed number came from the 09-21 fork instead of this run |
| E — gate | funded v4 pool is active | no record refuses; record passes with balance movement; cleared record refuses again | reject if the passing swap is a no-op or only the outer wrapped-error selector is shown |
| F — closing | source and disclosure are reachable | repository, live demo, and disclosure in one clean plate | reject if any Arc/ETHOnline media or private URL appears |

## Before every take

1. Confirm every load-bearing value comes from the current run.
2. Keep `Sepolia · Testnet` in the frame.
3. Check the full frame, including terminal scrollback, for RPC URLs, secrets, or private keys.
4. Use no music.
5. Film the rush immediately once its row becomes real; do not wait for the final edit block.
6. Read the spoken line once without recording. If it feels too fast, shorten the line—not the
   screen evidence.

## Values to replace after the event run

| location | pre-event placeholder | replace with |
|---|---|---|
| v3 swap panel | `[event output]` | exact input/output from the event’s executed swap |
| proof panel | `[event duration]` | duration of the proof consumed by the recorded settlement |
| settlement panel | `[deal id]`, `[tx hash]`, `[block]` | values from the recorded settlement receipt |
| record panel | `[agent name]`, `[record key]` | values resolved through `UniversalResolverV2` |
| v4 gate panel | `[before balance] → [after balance]` | balances from the successful funded-pool swap |
| submission form | any illustrative swap figure | the same exact figure shown in the final video |

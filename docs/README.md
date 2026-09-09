# Reckn documentation

Eighteen pages accumulate faster than anyone can guess an order for them, so this is the order.
Each line says what the page is *for*, because a title tells you the subject and not whether you
should be reading it.

The [repository README](../README.md) is the argument and the evidence. Everything here is the
detail underneath it.

---

## Start here

| page | what it is for |
|---|---|
| **[use-with-your-service.md](use-with-your-service.md)** | **The one page to read if you are thinking about adopting Reckn.** What it can decide and how to tell in a minute whether it fits your agent; the two calls; the buyer path and the seller path; what you have to bring. |
| [partner-kit.md](partner-kit.md) | The TypeScript package in detail: the five kinds of terms it refuses, the profiles, the endpoint requirements, and the known limits — which are not in an appendix. |
| [integrate.md](integrate.md) | The **reference** underneath the guide: the raw contract surface, and computing a `dealBinding` yourself before any work happens. |

## Understand the idea

| page | what it is for |
|---|---|
| [why.md](why.md) | The two constraints Reckn exists to satisfy, what they cost, and what has to be true for it to matter. The long-form argument. |
| [positioning.md](positioning.md) | Which layer this is and which layers it composes with — *AI chooses, negotiates and explains; re-execution decides the payout* — including what Reckn does **not** suit. |
| [messaging.md](messaging.md) | The wording this project holds itself to, the claims it refuses to make, and why the same product is entered through different doors at different events. |
| [chain-fit.md](chain-fit.md) | Why Arc and why Tempo are different answers rather than the same answer twice, with the receipts for each and the limits neither fixes. |

## Check the claims

| page | what it is for |
|---|---|
| [status.md](status.md) | What is built, what closed during the event, and **`Known gaps (not closed)`** — the section worth reading first if you are deciding whether to believe any of this. |
| [arc-usdc.md](arc-usdc.md) | The Arc deployment in full, and the **architecture diagram** — the only copy of it. |
| [protocol-architecture.md](protocol-architecture.md) | How the pieces fit: escrow, verifier, guest, and the boundaries between them. |
| [cross-chain-settlement.md](cross-chain-settlement.md) | The fail-closed protocol for settling on one chain about work on another. |
| [reexec-evm-mpt-verification.md](reexec-evm-mpt-verification.md) | How the EVM witness is verified against the state root, which is what makes the prestate a commitment rather than an assertion. |
| [svm-snapshot-authenticity.md](svm-snapshot-authenticity.md) | The Solana side of the same question — and why `bank_hash` recomputation is consistency, not provenance. |
| [layout.md](layout.md) | Where everything lives, crate by crate. |

## Adjacent and forward-looking

| page | what it is for |
|---|---|
| [roadmap-crossvm.md](roadmap-crossvm.md) | EVM → Solana → cross-VM, and what each step actually requires. |
| [x402-payments.md](x402-payments.md) | How x402 / EIP-3009 payments relate to a Reckn deal. |
| [tokyo-partner-pilot.md](tokyo-partner-pilot.md) | A runbook for producing adoption evidence with one partner, in one session. |
| [architecture-brief.md](architecture-brief.md) | The convergence brief written for an independent reviewer. |

## The ETHOnline 2026 entry

Everything in **[ethonline-2026/](ethonline-2026/)** is about the submission rather than the
protocol: the boundary between pre-event and event work, the submission text, the AI-usage
disclosure, the preflight checklist, and the live-judging plan.

## Specifications

**[specs/](specs/)** holds the numbered specs. They are the working record — written before the
code, reviewed adversarially, and left in place afterwards rather than tidied. Read them if you
want to see what was decided and what was rejected, not as an introduction.

---

## Checking this index

```bash
python3 docs/check-links.py
```

Every relative link and every `#anchor` in the README and in these pages has to resolve. It
exists because on 2026-09-09 the README was split and twenty-seven links in the two pages it
split into pointed at nothing — in the pages a reader is sent to when they want to know what is
*not* done. Nothing turned red, because nothing was looking.

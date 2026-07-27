# Reckn dashboard — the money-shot

`index.html` is a single self-contained page (no build, no external requests) that
dramatizes one dispute, judged two ways:

- **Opinion judge** — reads the seller's persuasive claim and approves. On a false
  claim it releases escrow to a delivery that never happened.
- **Reckn · re-execution** — replays the seller's actual plan against the pinned,
  proof-verified pre-state and reaches a reproducible verdict. It catches the
  false claim and refunds the buyer.

It plays as one orchestrated scene: the 1,000 USDC pot moves, a live
`reckn-keeper` console + escrow ledger stream the resolve (`disputed → fetch
content (hash-checked) → re-execute in revm → sign verdict → resolve tx →
confirmed`), and the outcome lands on an on-chain `resolve()` receipt. Toggle
*Honest delivery* / *False claim*, hit *Replay*, or check *instant*.

**Live (zero setup):**
<https://claude.ai/code/artifact/88a370e4-bfeb-480c-af14-015661e6e6f7>

## The data is real

Every value on the Reckn side is real output of the `reexec-evm` engine (revm 38,
MPT-verified prestate); the trace hashes are the SHA-256 of the canonical
`ReplayRecordV1`, reproducible by anyone. To see it settle on an actual chain (not
a scripted scene), run the live end-to-end — it even re-verifies the verdict
keylessly at the end:

```bash
bash ../scripts/anvil-e2e.sh
```

`reexec-evm/examples/moneyshot.rs` (→ `moneyshot.json`) is the standalone engine
output the earlier split-screen was built from; the current page inlines its own
data so it stays self-contained and opens from `file://`.

## Design exploration

`variants/` holds the five money-shot directions that were compared
(v1 cinematic · v2 character · v3 live console · v4 hybrid · v5 fusion). **v5 is
the one promoted to `index.html`**; the rest are kept for reference.

## View it

Open `index.html` in a browser (data is inline, so `file://` works), or serve the
folder: `python3 -m http.server` then visit `/dashboard/`.

## Honest framing

The opinion judge is a stand-in that approves on the claim regardless of what
executed — the point is the contrast, not a strawman of any specific product. The
on-chain receipt is explorer-agnostic. Settlement is authorized by a registered
resolver signature; reproducibility and settlement authority are deliberately
separate (a trace hash alone is not trustless settlement — but the verdict *is*
independently reproducible; see `reckn-keeper verify`).

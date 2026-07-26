# Reckn dashboard — the money-shot

A single self-contained page (`index.html`, no build, no external requests) that
puts the two adjudicators side by side on the same dispute:

- **Opinion judge** — reads the seller's persuasive claim and approves. On a false
  claim it releases escrow to a delivery that never happened.
- **Reckn · re-execution** — replays the seller's actual plan against the pinned,
  proof-verified pre-state and reaches a reproducible verdict. It catches the
  false claim and refunds the buyer.

Toggle *Honest delivery* / *False claim* to watch the two agree, then diverge.

## The data is real

Every value on the Reckn side is real output of the `reexec-evm` engine (revm 38,
MPT-verified prestate). The embedded `DATA` in `index.html` mirrors
`moneyshot.json`. Regenerate both from the engine:

```bash
cd ../reexec-evm
cargo run --example moneyshot > ../dashboard/moneyshot.json
# then paste the JSON into the DATA const in index.html (kept inline so the page
# is self-contained and opens from file://)
```

`trace_hash` is the SHA-256 of the canonical `ReplayRecordV1` — anyone can replay
the same inputs and reach the same verdict.

## View it

Open `index.html` in a browser (the data is inline, so `file://` works), or serve
the folder: `python3 -m http.server` then visit `/dashboard/`.

## Honest framing

The opinion judge is a stand-in that approves on the claim regardless of what
executed — the point is the contrast, not a strawman of any specific product.
Settlement is authorized by a registered resolver signature; reproducibility and
settlement authority are deliberately separate (a trace hash alone is not
trustless settlement).

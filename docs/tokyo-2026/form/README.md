# Form fields, one file each

## ★ Pasted 2026-09-27 07:5x JST — all four partner fields

`uniswap-using.txt`, `uniswap-easy.txt`, `ens-using.txt`, `ens-easy.txt` are in the form.
Scores unchanged: Uniswap **8**, ENS **7**. Source links unchanged and re-checked the same
morning.

**The description field was re-pasted too**, at 07:57 JST: 18,100 characters, `cf209eb7`,
carrying the *why a pool, and why v4* paragraph. `check-description.sh` is green again, and
green because the paste happened, not because anything was recorded around it.

So all five fields in the form are the five files beside this one.

**Paste targets, not prose.** Each file is the whole of one ETHGlobal field, so a paste is
select-all-and-replace and there is nothing to assemble by hand. Written 2026-09-27, after the
project was already submitted and while the form was still editable.

| file | field |
|---|---|
| `uniswap-using.txt` | Uniswap Foundation — *How are you using this Protocol / API?* |
| `uniswap-using-SHORT.txt` | the same, under 1000 characters, **if the field is capped** |
| `uniswap-easy.txt` | Uniswap Foundation — *How easy is it to use…* (score **8**) |
| `ens-using.txt` | ENS — *How are you using this Protocol / API?* |
| `ens-easy.txt` | ENS — *How easy is it to use…* (score **7**) |

The two source links in those fields are unchanged and were checked on 2026-09-27:
`RecordGatedHook.sol#L83` is `beforeSwap`, `SettlementRecord.sol#L235` is the
`grantSetterRoles(setter, buyer)` call itself.

**These are not the description field.** That one is `../DESCRIPTION.txt`, it is generated, and
`../check-description.sh` compares it to what was pasted. Nothing in this directory feeds it, so
editing here never makes that gate red.

## What changed from the first submitted version, and why

- **Uniswap, "using"**: it said the hook makes the record "usable", which never answered *why a
  pool*. A record that only says an agent did the work is a badge; in front of a pool it is a
  key. That, and the fact the check is **inside** the swap and so cannot be delegated to a
  router operator, is the actual answer to the question the prize asks.
- **Both "how easy" fields asked for a pattern that both teams had already given us.** Dayitva
  answered the `msgSender()` question at the booth and Kevin answered the name-scoping one. A
  request we had already had answered reads as not having listened. They now say what was asked,
  what was answered, and what we decided — and in ENS's case that their answer was better than
  ours.
- **ENS, "using"** did not mention the renounce, which is the strongest ENS-specific fact we
  have: root overrides every per-key role, we held it, and we destroyed it. Until that sentence
  is there, the claim is one the reader has to take on trust.

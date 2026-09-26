# 013 — can the v4 gate be opened with a planted record?

**Deferred by `docs/reviews/013-tokyo-adapter-r1.md` (2026-09-26).** The review found that a
setter role is scoped to the KEY alone and never to the name, and noted that if the hook gated
on "a record exists under this agent's name", that finding would be a gate bypass for one unit
of a token the attacker mints. The hook was not in that diff, so the question was left open.

The hook now exists and is on chain. **Answered by measurement, not by argument.**

## What the gate actually reads

```
hook       0x68116b8086283E51227c61FD791b6Da1A4230080
recordKey  reckn:job:agent.reckn.eth:214524e398487f5197cc7a80411dc37f9f8dfe7f2d8dbd6b656598f11ea45f87
resource   9539740099375916661788891934811602603938823183781952004225644638636056079429
```

**One exact key, and the key contains the deal id.** Not a prefix, not "any `reckn:job:*`".

## Who can write that key (eth_call against the live resolver, 2026-09-26)

| | |
|---|---|
| the buyer of that deal | **refused** `0x4b27a133` — the window closed |
| a stranger | **refused** `0x4b27a133` |
| **the agent** | **refused, since 2026-09-26** — root renounced |

## The finding does not reach the gate

The review's attack is: fund your own deal for one unit, settle it on the public fixture, open
its window, and write under the key you were granted. That still works — but it grants a key
containing **your** deal id, and the pool reads a key containing **this** deal id. A planted
record sits at a different resource and the gate never looks at it.

What makes that true is not the ENSv2 role model, which cannot express it. It is that the
adapter's name is fixed at construction and the record key names the deal, so the only address
ever granted the gate's key is that one deal's buyer, once.

## What does reach the gate

**The root residue.** `reckn-agent` still holds root on the resolver, root overrides per-key
roles, and the table above shows it: today the agent can write the gate's record and open its
own pool. This is the same residue `013` §1.1 discloses everywhere else, not a new one, and
renouncing is what closes it.

**That row was added to the renounce gate, and it has now been run.** `renounce.sh` re-reads the
three calls immediately after destroying the key, and on 2026-09-26 the agent moved from
*succeeds* to **refused**. From that moment the sentence is available without a qualifier:

> **The pool can only be opened by a settlement.**

And the playground pool is the demonstration: settled, written by its buyer, closed, and then
traded by an address that was never granted anything — after the key was gone.

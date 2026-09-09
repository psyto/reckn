# `@reckn/partner-kit`

Open a Reckn deal, check one before you work on it, settle it on a proof, and verify the
settlement — without reading an ABI.

**Full guide: [`docs/partner-kit.md`](../../docs/partner-kit.md).** This file is the package's
own README; the guide is the 10-minute onboarding.

**This package is not published to npm.** `reckn` and `@reckn/partner-kit` both 404 on the
registry (checked 2026-09-09), so `npm install @reckn/partner-kit` does not work and neither
does `npx reckn` from outside a tree that has it installed. Use it from the repository:

```bash
git clone <this repo> && cd packages/partner-kit
npm install && npm test          # no chain needed
npx reckn                        # resolves via node_modules/.bin, from THIS directory
```

## What it is for

Reckn is an escrow whose disputes are decided by **replaying the work**. A proof of that replay
is the only thing that releases or refunds the money: the escrow has no owner, no admin, no
resolver, no pause and no upgrade path. This package is the client side of that.

```ts
import { buildTerms, createDeal, sellerPreflight, submitProof, verifySettlement } from "@reckn/partner-kit";
```

| | |
|---|---|
| `buildTerms` | turn **your** transaction into deal terms. One read-only call, no key. |
| `createDeal` | fund a deal against those terms. |
| `sellerPreflight` | *what am I about to work on?* Read it before you start. |
| `submitProof` | settle. **Permissionless** — this function has no payment authority, and neither do you. |
| `verifySettlement` | decode what happened from the chain, not from anyone's report of it. |

There is also a read-only CLI: `npx reckn terms | preflight | verify | profiles`.

## The part worth knowing before you adopt it

- **The buyer names the adjudicator.** A buyer who names a verifier that always fails makes the
  seller work for nothing, and on-chain that is indistinguishable from an honest failure.
  `sellerPreflight` exists because of this. Run it.
- **Verifier Profiles are discovery metadata, not a trust root.** Nothing on-chain reads them.
  They are checked against the chain, and the check is what you should believe.
- **Proving is not instant.** It needs the SP1 toolchain and minutes of CPU. Measured, not
  estimated: 497.40 s for the shipped EVM guest.
- **Nobody outside this project has used this yet**, and that is not claimed anywhere.

`docs/partner-kit.md` carries the known limits in full. They are not in an appendix.

## Local development

```bash
npm install
npm test        # no chain needed
```

Apache-2.0.

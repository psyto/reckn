# Sepolia receipts — ETHGlobal Tokyo 2026

**Event work.** Every hash below is recorded in
[`zk-verdict/contracts/sepolia.json`](../../zk-verdict/contracts/sepolia.json), which was
**generated from the chain, not typed**, and `bash zk-verdict/scripts/sepolia-receipts.sh`
closes the loop in both directions: no link here is absent from the record, and no entry in
the record is linked nowhere.

It also checks a third thing, because the first two stay green while the demonstration dies:
**exactly one event transaction failed, it came from the account that owns the agent, and the
identical accepted call came from a different account.** One `approve()` on the agent token
would make the refusal disappear, and this check is what notices.

## Beat 1 — an agent's own address cannot write its record, and a second address can

ERC-8004 registries, deployed by the 8004 team and used unmodified
([`0x8004A818…`](https://sepolia.etherscan.io/address/0x8004A818BFB912233c491871b3d84c89A494BD9e) ·
[`0x8004B663…`](https://sepolia.etherscan.io/address/0x8004B663056A597Dffe9eCcC1965A193B7388713)),
`getVersion()` = **2.0.0** on both. **agentId 10518.**

| | transaction | result | gas | block |
|---|---|---|---|---|
| register the agent | [`0xfb324823…`](https://sepolia.etherscan.io/tx/0xfb32482311af79c9aedffc915c1b5f6b0bec48027216a64926e436c7168b029e) | success | 106,883 | 11,779,151 |
| **the agent writes its own record** | [`0x87f5a04b…`](https://sepolia.etherscan.io/tx/0x87f5a04b4a044d7426eecec0ce45e6d3c830234c2b81a2b0ecbd39222b250fb8) | **failed** | 42,322 | 11,779,188 |
| a second address writes it | [`0xe8a44a1a…`](https://sepolia.etherscan.io/tx/0xe8a44a1a0e81d4e7109a76a2c66def4d17339a444bbce98f840f78d9bfd3f226) | success | 190,352 | 11,779,191 |

The refusal is `Self-feedback not allowed` —
[`ReputationRegistryUpgradeable.sol:108`](https://github.com/erc-8004/erc-8004-contracts).
It was sent with an explicit gas limit so estimation could not swallow it: **a refusal nobody
can click is weaker than one they can.**

### The state, which outlives the transactions

| | |
|---|---|
| `getClients(10518)` | one address: `0xf81dff68…` — the second address |
| `getLastIndex(agent's own address)` | **0** |
| `getLastIndex(second address)` | **1** |
| `readFeedback(…, 1)` | value **100**, tag `quality`, `isRevoked false` |

**The owner wrote nothing. A second address wrote one record.** That is what beat 1 claims,
and it is readable from the chain by anyone.

### What this does not show

The standard **requires** the refusal — [`erc-8004.md:217`](https://eips.ethereum.org/EIPS/eip-8004)
— and the official contracts enforce it. **This is not a hole anyone missed.** The spec says so
itself in Security Considerations: *"Sybil attacks are possible… We expect many players to build
reputation systems."* ERC-8004 defers *who may write* to a layer above it. What the rest of this
submission builds is one answer in that layer: the right to write a record is created by a
settlement.

## Pre-event, disclosed as such

Neither is submission work; both are here because the record holds them and an unlinked
receipt is the failure this file exists to prevent.

| | transaction | result | gas | block |
|---|---|---|---|---|
| deploy rehearsal (throwaway) | [`0xb78889ce…`](https://sepolia.etherscan.io/tx/0xb78889ce66645a11e759650cd5745fbcbeee3ed7a45773bf0cd8d94864c6671a) | success | 75,238 | 11,777,027 |
| fund the second address | [`0x9765c2f7…`](https://sepolia.etherscan.io/tx/0x9765c2f765ab3f0c9d1428ce8ad5e51752818771de1cd5506c57cfdd13bcb1b6) | success | 21,000 | 11,777,053 |

> **The rehearsal's contract address equals `arc.json`'s `RecknVerdictVerifier`.** Both are
> `reckn-arc` at nonce 1 on their own chain, and CREATE addresses do not depend on the chain.
> The Sepolia one writes `1` to slot 0 and returns empty code. **It is not a verifier.**

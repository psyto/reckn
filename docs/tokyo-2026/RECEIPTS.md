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


## The night's deployments

| | address |
|---|---|
| `RecknZkEscrow` | [`0x6d6a9deb67d785BC131a5d732617EABE751098C5`](https://sepolia.etherscan.io/address/0x6d6a9deb67d785BC131a5d732617EABE751098C5) |
| `RecknVerdictVerifier` | [`0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608`](https://sepolia.etherscan.io/address/0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608) |
| our `PermissionedRegistry` | [`0x1Ad360D93ccD6230FB14D213134107BF89a428cf`](https://sepolia.etherscan.io/address/0x1Ad360D93ccD6230FB14D213134107BF89a428cf) |
| our resolver (UUPS proxy) | [`0x740e02cE9fb52629FEf861ca02DF7091f416BBF8`](https://sepolia.etherscan.io/address/0x740e02cE9fb52629FEf861ca02DF7091f416BBF8) |

| | transaction | result | gas |
|---|---|---|---|
| the escrow, on Sepolia this time | [`0x43c3c7e3…`](https://sepolia.etherscan.io/tx/0x43c3c7e30f3f61c79b3937c1b8cf33e9e332fd737c474d28603817eb667226c6) | success | 1,252,808 |
| the verdict verifier | [`0xefd497fc…`](https://sepolia.etherscan.io/tx/0xefd497fc27f448f239821058ccd6605c0011896ec655d2ff3370fe66cb638536) | success | 476,388 |
| the parent registry | [`0x62191904…`](https://sepolia.etherscan.io/tx/0x6219190438d0b63cce4895ed8c67e02613d07968c9c36eb7be699be215631b24) | success | 5,273,028 |
| the resolver instance | [`0xd7900814…`](https://sepolia.etherscan.io/tx/0xd7900814c322aca1b5eb41ee7c7e9e64ddbd395237c6be4492c8189631f69085) | success | 177,868 |
| allow the registrar to take MockUSDC | [`0x3069906c…`](https://sepolia.etherscan.io/tx/0x3069906c378c5125729bf3773fed2f5c61e58ebe5e89e4f0e288ed5afd43f61b) | success | 46,354 |
| commit `reckn` | [`0xa43ffa3a…`](https://sepolia.etherscan.io/tx/0xa43ffa3aef645c43d1e3ca1f246c7856ff533d1fadc9190e90edc7170a264fe5) | success | 45,438 |
| **register `reckn` on the real ETHRegistrar** | [`0x1a66082b…`](https://sepolia.etherscan.io/tx/0x1a66082b77cffdb95490fc65f6d361eb09b3e3569907299961ac2a20c22a9d5f) | success | 241,718 |
| **issue `agent.reckn.eth`, ROLE_RENEW only** | [`0x5643607d…`](https://sepolia.etherscan.io/tx/0x5643607ddf2e06e9b8d609f49316d893784e43bfbe9d2c9ac558e972fba2a6f3) | success | 143,627 |

### Three choices worth stating

**The verifier points at SP1's immutable contract, not at the gateway.**
[`0xb69f2584…`](https://sepolia.etherscan.io/address/0xb69f2584CBcFf99a58C4e7002E8b89Af54a6f4e2) has no owner. The
`SP1VerifierGateway` does, and its route for our proof's selector is not frozen. A project whose
claim is that **no key decides** should not put an owner in the adjudication path. The proof's
first four bytes are `0x4388a21c`, which is that verifier's `VERIFIER_HASH` — matched, not assumed.

**The resolver instance was created by ENS's own `VerifiableFactory`**, not by a proxy we wrote.
The implementation is UUPS, so an EIP-1167 clone dies inside `onlyProxy` with 210 gas and no
revert data.

**There are three live ENSv2 families on Sepolia** and `reckn` was available on all of them.
Registering into the wrong one produces a name nobody can resolve, and nothing fails loudly. We
used the family the measurements were taken against, and reached its `LabelStore` by walking
`ETHRegistrar → ETH_REGISTRY() → LABEL_STORE()` rather than guessing.

### What resolves, and what does not yet

| | |
|---|---|
| `ETHRegistry.getSubregistry(reckn)` | our registry |
| `ETHRegistry.getResolver(reckn)` | our resolver |
| `roles(agent.reckn.eth, the agent)` | **`0x10000` = `ROLE_RENEW` only** — no `ROLE_SET_RESOLVER` |
| `UniversalResolverV2.resolve(agent.reckn.eth, …)` | **routes to our resolver** — the ENS tracks ask for resolution through ENS, not a direct call, and this is it |
| `setResolver` by a third party | reverts `EACUnauthorizedAccountRoles` |
| **`setResolver` by the agent itself** | **still succeeds** |

**That last row is not closed and is not claimed to be.** The deployer still holds **root roles**
on the parent registry, and root overrides per-name roles. `013` §1.1 discloses this residue in
advance, and `S4`'s own spike says *"root CAN hand the power over afterwards — which is why root
must be renounced"*. The order is: deploy the adapter, grant it, renounce root, renounce the
resolver admin, **then re-run this check**. Until that last step runs, the claim is that the agent
holds no such role — not that nobody does.

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

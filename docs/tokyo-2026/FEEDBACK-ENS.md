# ENSv2 Permissioned Resolver — what we hit, measured

Written for the ENS team after ETHGlobal Tokyo 2026. Our resolver instance is
[`0x740e02cE9FB52629feF861CA02DF7091f416BBF8`](https://sepolia.etherscan.io/address/0x740e02cE9FB52629feF861CA02DF7091f416BBF8)
and our registry is
[`0x1Ad360D93ccD6230FB14D213134107BF89a428cf`](https://sepolia.etherscan.io/address/0x1Ad360D93ccD6230FB14D213134107BF89a428cf),
both on Sepolia. Everything below is something we hit while building, with the measurement or
the address that shows it. Raw notes: [`spikes/tokyo-2026/FINDINGS.md`](../../spikes/tokyo-2026/FINDINGS.md).

> **A correction.** Talking it through in person at the booth on 2026-09-27, this came out as
> *"four EAS contracts on devnet"*, which is not what we meant and not something we measured. **The finding is §1
> below: the deployed Sepolia beta and the `contracts-v2` main branch have different ABIs.**
> The mistake was ours, made out loud, so it is corrected here in writing rather than quietly.

## 1. ★ The deployed Sepolia beta and `contracts-v2` main have different ABIs

This cost us the most time, because the code compiles against main and then reverts on chain.

| | main branch | deployed Sepolia beta |
|---|---|---|
| `initialize` | `initialize(address admin, uint256 roleBitmap, bytes[] setters)` | **`initialize((address,uint256)[] admins, bytes[] setters)`** |
| text write | `setText(bytes32 node, string key, string value)` | **`setText(bytes name, string key, string value)`** |

The second row is the sharp one: the beta's `setText` takes a **DNS-encoded name, not a
namehash**. Passing the namehash reverts `UnsupportedResolverProfile(0x05616765)` — and
`0x05616765` is the first five bytes of a DNS-encoded label, so the selector it reports back is
itself a hint that the argument was the wrong shape. We only saw that after decoding it by hand.

**What would have helped:** the beta's ABI published beside the deployment address, or a note in
the main-branch README that the deployed beta is not it.

## 2. `decodeSetter` is the answer to a question we thought we had to solve

`decodeSetter(bytes setter)` is a **view** that returns the **resource**, the **role bitmap** and
the **key**:

```solidity
(uint256 res, uint256 role, string memory key) =
    resolver.decodeSetter(abi.encodeWithSelector(setText.selector, name, "job:1", ""));
```

We had an open design question about how to derive a record id so a grant could be revoked
later. **It is not needed — the resolver computes it.** This is good design and it is hard to
find; we found it by reading the library.

## 3. ★ The resource comes from the key alone, never from the name

The resource `decodeSetter` returns is derived from the setter's calldata, so **three different
names with the same key produce the same resource.** We measured it, having first written the
opposite in our own docs and had to correct it.

For us that means a setter role granted for `job:1` is not bound to the name it was granted
against. We handle it by fixing the adapter to one name at construction and putting the name
**inside** the key, so a write onto a foreign name is unattributable rather than impossible.

**We asked Kevin, who answered on Discord on 2026-09-26 and again in person at the booth on
the 27th, and the answer was better than ours: partition names across resolver instances,
because the resolver instance is the trust boundary.** Our deployment is
already that in its smallest form — one resolver serving one name — and we did not realise that
was the intended pattern. **Saying so next to `decodeSetter` would have saved us the
measurement, and would stop someone else assuming the role is name-scoped.**

## 4. A second grant reverts `EACCannotGrantRoles`, not `EACMaxAssignees`

Granting the same setter role twice reverts **`EACCannotGrantRoles` (`0xd1a3b355`)**. We were
expecting an assignee-cap error and spent time looking for a cap that was not the cause.

## 5. `UniversalResolverV2` reverts `0x95c0c752` for an unregistered name

Reading our record **directly at the resolver** with `resolve(name, text(node,key))` returned the
value. The same read **via `UniversalResolverV2` reverted `0x95c0c752`** — notably **not**
`OffchainLookup` (`0x556f1830`), which is what we were watching for.

The cause turned out to be ours: the name was not registered in the registry, so there was no
resolver to find. The revert is correct. **It is just not self-describing**, and a hook that
reads through the universal resolver gets an opaque four bytes at the moment a swap fails.

## 6. What worked, and mattered most: root roles really can be renounced

`revokeRootRoles(ALL_ROLES, self)` from the holder succeeded and left `roleCount(ROOT) == 0` on
the registry and exactly one holder — our adapter — on the resolver.
[`0x5cd3b7fc…`](https://sepolia.etherscan.io/tx/0x5cd3b7fc000e0e6a0ef1a14f3fdefd9a308c75d48f4c53f7bc75e0635670dff3)
and [`0x9416e39e…`](https://sepolia.etherscan.io/tx/0x9416e39e0fdd99bb11409ac3fa61f6f67c20118829a9327f9b20fe5ce1ae4719).

**This is what made our whole submission sayable.** Root overrides every per-key role, so while
we held it, "only a settlement can write this record" was a claim about us rather than about the
contracts. After the renounce the chain answers instead: the buyer is refused, a stranger is
refused, **and our own agent account is refused.** An access-control system where the last key
can actually be destroyed is rarer than it should be. Thank you for building one.

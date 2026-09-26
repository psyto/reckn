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
| our resolver (UUPS proxy) | [`0x740e02cE9FB52629feF861CA02DF7091f416BBF8`](https://sepolia.etherscan.io/address/0x740e02cE9FB52629feF861CA02DF7091f416BBF8) |

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


## What it looks like

Five stills, taken 2026-09-25 from the live chain. Nothing is mocked and nothing is staged;
each is a page or a call anyone can reproduce from the hashes above.

**Beat 1 — the agent cannot write its own record, and a second address can.**

![The agent's own giveFeedback, mined and failed: "Fail with error 'Self-feedback not allowed'".](media/beat1-00-self-write-refused.png)

![Read back from the registry: the agent that owns the agentId has 0 records, a second address has 1.](media/beat1-01-state-contrast.png)

That second image is the claim. The transactions are what happened; **this is what is true now**,
and anyone can call `getLastIndex` and get the same two numbers.

**Beat 3 — a settlement creates the right to write, for somebody else.**

![The adapter opening the one window this deal will ever have.](media/beat3-02-window-opened.png)

![Etherscan decodes it: "Set Text" on our resolver, sent by the buyer -- not by the agent.](media/beat3-03-buyer-writes.png)

![UniversalResolverV2 returns: ENS says "reproduced block=11782541 verifier=0xe0de264d...".](media/beat3-04-ens-resolves-the-record.png)

**Beat 2 is missing on purpose.** It is the agent's ENS write being refused, and it cannot be
photographed honestly yet: `reckn-agent` still holds root, so today that write succeeds. It is
taken immediately after the renounce, and the renounce's own verification is the shot.

## The join, on the real chain

`bash tokyo-2026/scripts/join-sepolia.sh` — one path, seven steps, no fork. Run again on
**2026-09-26** against the rebuilt adapter
[`0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8`](https://sepolia.etherscan.io/address/0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8).

| | transaction | result | gas |
|---|---|---|---|
| deploy the **fixed** adapter | [`0xc198491d…`](https://sepolia.etherscan.io/tx/0xc198491d3f2323f0da08d6b960ba98c2d8244e414757f90ac9e2ad4ddda96387) | success | 2,311,987 |
| give it the role it needs | [`0x765afbe7…`](https://sepolia.etherscan.io/tx/0x765afbe7f4f4378d52bd28ed74279259286740a3ba49113bcdeeec13b0344625) | success | 63,098 |
| **take the role away from the old one** | [`0x0d5bbf3e…`](https://sepolia.etherscan.io/tx/0x0d5bbf3e221d611ebd9ee9513ed3ff6be41bd1bc2deaed8caa77d0093901b90b) | success | 41,137 |
| the buyer approves the escrow | [`0x79a5cff5…`](https://sepolia.etherscan.io/tx/0x79a5cff538e0818c738f379103c5d5972b1dd70bae8cba2b44bf6143079f2302) | success | 46,366 |
| the buyer funds 250 USDC and names the verifier | [`0xb12350b6…`](https://sepolia.etherscan.io/tx/0xb12350b69da947615b35f81d42abbc9594784defc8c1e8f9ada793627234f285) | success | 244,587 |
| **a stranger settles it, on a real proof** | [`0x2275f36d…`](https://sepolia.etherscan.io/tx/0x2275f36d3d04b5e1655d54d8d4195af38e146ca554e0ad59466f76301acec128) | success | 293,893 |
| **the adapter opens one window, for the buyer** | [`0x2bb286d5…`](https://sepolia.etherscan.io/tx/0x2bb286d529a5a29a35a039be4631ba09252e959303c4212ac495ffd312c641b0) | success | 530,377 |
| **the buyer writes the record** | [`0x860a8e91…`](https://sepolia.etherscan.io/tx/0x860a8e9170c22c9d68eb898308b1c6562c3cf356fbba788cf48a0c21ddaa1692) | success | 139,131 |
| the window closes | [`0x9c597a4d…`](https://sepolia.etherscan.io/tx/0x9c597a4d86efd7c09014f989ea97154d59442658db843f5b4f368405601ffa55) | success | 75,204 |

ENS returns, through `UniversalResolverV2` and not by calling our resolver directly:

```
reckn:job:agent.reckn.eth:48a603c2442fe4f372a025f32a6c879e002bc44a860552d6adc0e086cc00dae9
  -> "reproduced block=11782541 verifier=0xe0de264d76f0664c4e943fc02e3d9fb46cd27608"
```

ENS names our resolver as the one that answered. The agent's balance moved by 250 USDC, because
the escrow paid it — this is a settlement, not a simulation of one.

**The key names the name it belongs to**, which it did not on 09-25. The resolver derives a
role's resource from the key alone — `agent.reckn.eth` and `victim.reckn.eth` with one key give
one identical resource, measured — so a role is never scoped to a name. Putting the name in the
key does not stop bytes being written onto somebody else's name; it stops them being read as
that somebody's record.

### The 09-25 run, superseded

Kept, not deleted. It happened, and a record that drops what it later finds inconvenient is not
a record. That adapter is
[`0x6691283d8B77E1e22D08836c55E3f952c304Ccc1`](https://sepolia.etherscan.io/address/0x6691283d8B77E1e22D08836c55E3f952c304Ccc1);
its root was revoked on 09-26, so its window can never be opened again. **Two defects, both
found overnight**: `close` was callable by anyone with no further condition, so a stranger could
open a deal's one window and close it in the same block and leave the record permanently
unwritable; and the name was a caller argument, so a grant could be aimed at another name.

| | transaction | result | gas |
|---|---|---|---|
| deploy the adapter | [`0x07b1fdf0…`](https://sepolia.etherscan.io/tx/0x07b1fdf08c6a65adff0b7b190f78b08da87ea6cc95ba2f02866a2044b6953acd) | success | 1,953,465 |
| give it the role | [`0xb4c7d8b7…`](https://sepolia.etherscan.io/tx/0xb4c7d8b71c40ed6ab9b23d617a12fc9785dc1fdcec4aff3aee970739b8e7b6dc) | success | 63,098 |
| approve | [`0xe2237ae6…`](https://sepolia.etherscan.io/tx/0xe2237ae614dd6a8a367c5913e774a5b5ef10c79bf1c11c6600d51ab62b00fe27) | success | 26,466 |
| fund | [`0xf93c1c53…`](https://sepolia.etherscan.io/tx/0xf93c1c53484150aa04c5910a55f43ac0a2fdf69488f1029bcd142f46577b8d1f) | success | 244,611 |
| settle | [`0x51d7c9ce…`](https://sepolia.etherscan.io/tx/0x51d7c9ce802133a7793a2a29c7d3be6ee01585ea2eb8059dcc0022b363f14592) | success | 293,917 |
| open | [`0xd14d7978…`](https://sepolia.etherscan.io/tx/0xd14d797802a88d88c06a8542372f1cf3672fc71c847009775651b168c6c54602) | success | 504,363 |
| write | [`0xbf2ca290…`](https://sepolia.etherscan.io/tx/0xbf2ca29051e842867b44d2b43c19812b42c24c4529acd964aa8ed730fe1276aa) | success | 183,719 |
| close | [`0x6b2081b8…`](https://sepolia.etherscan.io/tx/0x6b2081b844dacdbe04612a8f1dc13990e5e4061a9200f948c7f4bed7a29d1e20) | success | 74,956 |

**What that string is, exactly.** The buyer typed it. The grant authorises the KEY, not the
bytes, so nothing on chain forced those words: a buyer could write `reproduced` under a deal
whose proof said `failed`. What the settlement created is the RIGHT to write one record — which
is what `013` is named for — not the record's contents. The contents are *checkable*: anyone can
re-derive `recordValue(outcome, block, verifier)` from the escrow and the proof and compare. They
are not *enforced*. This paragraph exists because the block above, sitting under a row of green
transaction hashes, invites the reader to think the chain produced the words. It did not.

## The gate, on the real chain

Until 2026-09-26 the v4 hook existed only on a fork. Everything else here has a receipt, so the
hook was the one part a judge could not click, and that asymmetry is worth more than the feature.
It is on Sepolia now.

**Hook [`0x68116b8086283E51227c61FD791b6Da1A4230080`](https://sepolia.etherscan.io/address/0x68116b8086283E51227c61FD791b6Da1A4230080)** — the low 14 bits are
`0x80`, `BEFORE_SWAP_FLAG` and nothing else, mined with a CREATE2 salt so the PoolManager will
accept it. Pool on the real PoolManager
[`0xE03A1074c86CFeDd5C142C4F04F1a1536e203543`](https://sepolia.etherscan.io/address/0xE03A1074c86CFeDd5C142C4F04F1a1536e203543),
fee 3000, with **100e18 of liquidity actually provided** — a swap through an empty pool is a
no-op and would prove nothing.

### Beat 5, as five transactions

![A swap with no record: Fail, execution reverted. Sent by the agent to the router.](media/beat5-01-swap-refused.png)

![The buyer writes the record. Decoded: key = reckn:job:agent.reckn.eth:214524e3..., value = reproduced block=11782689 verifier=0xe0de264d...](media/beat5-02-buyer-writes-the-record.png)

![The same swap, now Success, with two ERC-20 transfers: 1 Reckn Demo B out and 0.987158034 Reckn Demo A back.](media/beat5-03-swap-executes.png)

![The buyer clears the record. Etherscan's decoded input data: name, then key = reckn:job:agent.reckn.eth:214524e3..., then value = empty.](media/beat5-04-record-cleared.png)

![The same swap once more: Fail.](media/beat5-05-refused-again.png)

**The two swaps that fail and the one that does not are the same transaction.** Same sender,
same router, same pool, same amounts. Between them sit the two writes, and nothing else changed
— and the record could only be written because a job was re-executed, reproduced and settled.

**Both writes are shown decoded, and that is the point of showing them at all.** On etherscan's
summary a `Set Text` that writes and a `Set Text` that erases are the same picture: same sender,
same resolver, same green `Success`. The difference lives in the input data. Decoded, the two
frames are the same three-row table and **exactly one row differs**:

| | `key` | `value` |
|---|---|---|
| writes | `reckn:job:agent.reckn.eth:214524e3…` | `reproduced block=11782689 verifier=0xe0de264d…` |
| clears | `reckn:job:agent.reckn.eth:214524e3…` | |

The key carries the name it belongs to, which is what stops a grant being aimed at somebody
else's name. That is visible in the frame rather than asserted in a caption.

#### The transactions

| | transaction | result | gas |
|---|---|---|---|
| **a swap, with no record** — refused | [`0xda60d7df…`](https://sepolia.etherscan.io/tx/0xda60d7df7940bf25fd01466444573d0b364a8865641e97dc061096ad1f1f94be) | FAILED | 81,680 |
| the buyer writes the record | [`0xd5610433…`](https://sepolia.etherscan.io/tx/0xd561043323073bc9b704a35aab59d147be4ad97c4735ddfe41b5993eabb619e8) | success | 139,131 |
| **the SAME swap** — executes, 1.0 token0 out | [`0xa40bb316…`](https://sepolia.etherscan.io/tx/0xa40bb3162ed17e084155277cd2d0a9605c1fea510ddef6df62dbf502831f5698) | success | 180,432 |
| the buyer clears the record | [`0x427ee98a…`](https://sepolia.etherscan.io/tx/0x427ee98a7a117c91604fed12f6e16bb5eb0473967f0a9e054e1ce75a1fe073a4) | success | 54,876 |
| **the same swap again** — refused | [`0xce00489e…`](https://sepolia.etherscan.io/tx/0xce00489eb9f2ebca202643c28841360737b35bc30e81a276e47fab64e2f1fa79) | FAILED | 81,680 |
| the window closes | [`0x2a6bf895…`](https://sepolia.etherscan.io/tx/0x2a6bf895e4fbe9187a976882275fbd066e323b7f1b0abf921e69a7068e2e03df) | success | 75,228 |

**The two refusals are failed transactions on purpose.** A reverting call cannot be gas
estimated, so they were sent with an explicit limit; what lands is a transaction anybody can
open and read, the same way beat 1's refusal does.

**And they were refused by us — both of them.** `status 0` on its own means only that something
went wrong. Each refusal was re-simulated at its own block, and each returns the PoolManager's
ERC-7751 `WrappedError` carrying the same two things:

```
target : 0x68116b8086283E51227c61FD791b6Da1A4230080   <- our hook
reason : 0x43a7f347                                    <- NoSettledRecord(address)
```

Asserting the outer selector would have passed for any hook failing for any reason. Checking
only the first refusal would have left the one that closes the argument — the pool shutting
again after the record went away — resting on `status 0`.

### Standing the pool up

| | transaction | result | gas |
|---|---|---|---|
| the buyer funds the deal | [`0x78118df6…`](https://sepolia.etherscan.io/tx/0x78118df6140eeb3838543853e21234b5dcb2b08d19a9a97e155c690fe76c7ff5) | success | 46,366 |
| the approval it needed | [`0x282ce902…`](https://sepolia.etherscan.io/tx/0x282ce902fa565a76060faed717dacc0bf1cb51e49bfdfa9193ed0feb7dd1e1fc) | success | 244,611 |
| settled on a real proof | [`0x1111d485…`](https://sepolia.etherscan.io/tx/0x1111d485dd3520708ce02f29727420aa47918d5d5f20173fff6a1f78feb25fb6) | success | 293,917 |
| the window opens — **and is left unwritten** | [`0x7a8e4345…`](https://sepolia.etherscan.io/tx/0x7a8e4345109d35a205aef83f8ebe2d4f517322893b6625826becf26e1365823b) | success | 530,391 |
| the hook, CREATE2 at a mined address | [`0xb3578c58…`](https://sepolia.etherscan.io/tx/0xb3578c58f25cda04b4cfcdf99fc1d4609dc54a1c84a0f9f74cb4a2b3a25ecff9) | success | 68,928 |
| the router that does the unlock dance | [`0x880b42a4…`](https://sepolia.etherscan.io/tx/0x880b42a4b71a69175f3cd0e172caeafab2943ac9e6aa0dc95fd917dc1b8d8f79) | success | 68,928 |
| a demo token | [`0x7320c2ee…`](https://sepolia.etherscan.io/tx/0x7320c2eedf5487e845da0ab15a9c8fd8630ab59212352f0e89fa2dc50b0c7e2f) | success | 804,857 |
| the other demo token | [`0xdbd77c62…`](https://sepolia.etherscan.io/tx/0xdbd77c621d5161375ce791ba8887dedab7042366536e717364aa9a7ff4b44517) | success | 804,857 |
| mint | [`0x297b2707…`](https://sepolia.etherscan.io/tx/0x297b270736dcfc3176d34b59b7777c63e05a0074ef3ee14063b3dafabc60c128) | success | 288,284 |
| mint | [`0xeb87fc2c…`](https://sepolia.etherscan.io/tx/0xeb87fc2c199bd1e2d93d64c329c6f6393e702d03fda0479791e00d205acb2647) | success | 1,422,199 |
| initialise the pool on the real PoolManager | [`0xd7b40b08…`](https://sepolia.etherscan.io/tx/0xd7b40b081665cbc9a4a25758938c8407f2e495723c9472543a123fb6caeb154c) | success | 1,322,523 |
| provide liquidity — the hook is **not** consulted here | [`0x7102a243…`](https://sepolia.etherscan.io/tx/0x7102a2437a489d2e587ee241b6a48301e0417c4a751e1d75538d81e05fa7c16e) | success | 51,751 |

The window was left unwritten on purpose. A pool that is already open cannot be filmed opening.

### Who can write now

| | |
|---|---|
| the buyer, again | reverts — **the window closed** |
| a third party | reverts |
| **the agent itself** | **still succeeds** |

**The last row is the residue, and it is the same one as before.** `reckn-agent` is both the agent
and the account still holding **root** on the resolver and the registry, and root overrides
per-record roles. `013` §1.1 discloses it in advance. Renouncing is what closes it, and it has
not been done yet because redeploying the adapter would then be impossible.

### Supporting transactions

Not part of the claim, listed because the record holds them and an unlinked receipt is the
failure this file exists to prevent.

| | transaction | gas |
|---|---|---|
| the buyer approves the escrow | [`0xe2237ae6…`](https://sepolia.etherscan.io/tx/0xe2237ae614dd6a8a367c5913e774a5b5ef10c79bf1c11c6600d51ab62b00fe27) | 26,466 |
| gas for the buyer | [`0x21f87060…`](https://sepolia.etherscan.io/tx/0x21f8706062f6e7c48b988aa6c7b69a4f19055887f6337acf254f8ef23a150e72) | 21,000 |
| MockUSDC for the buyer — its mint has no owner guard | [`0x93d0e7a1…`](https://sepolia.etherscan.io/tx/0x93d0e7a111767fef27d530aea9e3f295a021f2a4dbe86190047150f5f3d8fbbc) | 51,369 |
| **revoke a grant that went to a predicted address** | [`0x4154fe16…`](https://sepolia.etherscan.io/tx/0x4154fe162abfe109f86fa6d42d66fe1590a5a5975dfa3c9d022016286e3aea2d) | 41,125 |

That last one is worth a sentence. Two funding transactions moved the nonce between predicting
the adapter's address and deploying it, so the role was granted to
`0xF3Ef66B7…` — where nothing is, and where nothing can ever be, because that CREATE address
needs `reckn-agent` at nonce 13 and nonce 13 was spent on a transfer. It was revoked anyway.
`013` R-6 asks whether a second admin can appear later, and an unexplained root grant sitting in
the state is not an answer to that question.

> **It must be done before anything is filmed.** Until root is renounced, beat 2's refusal is
> true in the acceptance tests and false on the chain, and the video would show the wrong thing.

## Pre-event, disclosed as such

Neither is submission work; both are here because the record holds them and an unlinked
receipt is the failure this file exists to prevent.

| | transaction | result | gas | block |
|---|---|---|---|---|
| deploy rehearsal (throwaway) | [`0xb78889ce…`](https://sepolia.etherscan.io/tx/0xb78889ce66645a11e759650cd5745fbcbeee3ed7a45773bf0cd8d94864c6671a) | success | 75,238 | 11,777,027 |
| fund the second address | [`0x9765c2f7…`](https://sepolia.etherscan.io/tx/0x9765c2f765ab3f0c9d1428ce8ad5e51752818771de1cd5506c57cfdd13bcb1b6) | success | 21,000 | 11,777,053 |

> **The rehearsal's contract address equals `arc.json`'s `RecknVerdictVerifier`.** Both are
> `reckn-agent` at nonce 1 on their own chain, and CREATE addresses do not depend on the chain.
> The Sepolia one writes `1` to slot 0 and returns empty code. **It is not a verifier.**

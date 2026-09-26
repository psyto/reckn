# Developer feedback — building a `beforeSwap` hook on Uniswap v4

**Reckn**, ETHGlobal Tokyo 2026. Repository: <https://github.com/psyto/reckn>.
The hook: [`tokyo-2026/src/RecordGatedHook.sol`](tokyo-2026/src/RecordGatedHook.sol).
Deployed on Sepolia at [`0x68116b8086283E51227c61FD791b6Da1A4230080`](https://sepolia.etherscan.io/address/0x68116b8086283E51227c61FD791b6Da1A4230080),
pool on the real PoolManager `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543`.

Everything below is something we hit while building, with the measurement or the address that
shows it. We have tried to keep out opinions we cannot back.

---

## 1. `beforeSwap`'s `sender` is the unlocker, not the trader

This one cost us a wrong assumption and is the item we would most like an answer to.

Our hook reverts `NoSettledRecord(address swapper)` and we expected `swapper` to be the account
that sent the transaction. On chain it is not. From the real refusal
[`0xda60d7df…`](https://sepolia.etherscan.io/tx/0xda60d7df7940bf25fd01466444573d0b364a8865641e97dc061096ad1f1f94be):

```
reason 0x43a7f347 000000000000000000000000 25cc9656151acfd74e1cb4bd31f0e6e42bcb9525
                                            ^ our router, the contract that called unlock()
tx from 0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321   <- the EOA that actually swapped
```

That is correct and documented behaviour once you know it — `sender` is whoever the PoolManager
is unlocked for — but it has a consequence worth stating loudly somewhere a hook author will
read it: **a hook cannot gate on "who is trading" using `sender`.** Everyone behind the same
router looks identical. The options we could find are `hookData`, which the router has to be
willing to forward and which the trader can therefore choose, or trusting a specific router
address, which is a different trust assumption than the hook looks like it is making.

**Question:** is there an intended pattern for a hook that must know the end user? If the answer
is "there isn't, and that is deliberate", we would rather read that sentence than infer it.

We stated the limit in our own contract rather than let it be found later:

> *It does not identify the swapper. … A second agent could trade behind the first one's record.*

## 2. ERC-7751 makes it very easy to write a test that proves nothing

A hook revert reaches the caller wrapped: `WrappedError(address target, bytes4 selector, bytes
reason, bytes details)`, outer selector `0x90bfb865`. The trap is that
`vm.expectRevert(WrappedError.selector)` passes for **any** hook failing for **any** reason —
including a hook that is broken rather than refusing.

Our first version of that test asserted the outer selector and was green while proving nothing.
What the row actually needs is to strip four bytes, decode, and assert `target` is your hook and
`reason` starts with your error:

```solidity
(address target,, bytes memory reason,) = abi.decode(stripped, (address, bytes4, bytes, bytes));
assertEq(target, address(hook));
assertEq(bytes4(reason_first_word), RecordGatedHook.NoSettledRecord.selector);
```

**Suggestion:** a `expectWrappedRevert(target, selector)` style helper, or just this snippet in
the hook docs. Everyone writing a gating hook needs exactly this and will otherwise ship the
weaker assertion. (Our rows: [`test/RecordGatedHook.t.sol`](tokyo-2026/test/RecordGatedHook.t.sol).)

## 3. An empty pool makes a swap a no-op that still succeeds

Our first gate test initialised a pool, never added liquidity, and asserted the swap "went
through". It did — and moved nothing. `beforeSwap` had stopped refusing, which is a strictly
weaker claim than a swap executing, and the test could not tell the difference.

Adding liquidity via `modifyLiquidity` inside `unlock` turned it into a real measurement:
`1.000000000000000000` in, `0.987158034397061298` out on `100e18` of liquidity over
`[-600, 600]` — 0.3% fee plus slippage. On chain:
[`0xa40bb316…`](https://sepolia.etherscan.io/tx/0xa40bb3162ed17e084155277cd2d0a9605c1fea510ddef6df62dbf502831f5698).

**Suggestion:** the hook examples that ship with a test would be much stronger if the swap test
provided liquidity and asserted balances. As written they teach the shape that cannot fail.

## 4. Mining the hook address: the deployer is not who you think

`uint160(hook) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG` needs a mined CREATE2 salt, which is
expected. What is not obvious is that `forge script` broadcasts `new X{salt: s}(...)` **through
the deterministic factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`**, so the address must be
predicted against *that* address and not against the sending EOA. Predicting against the sender
produces a plausible address, a successful deploy, and a pool that then rejects the hook.

We found it by dry-running the whole script against a local anvil forked from Sepolia before
sending anything; the hook landed at the same address there as on the real chain, which is what
determinism is supposed to give you. Salt `20541` for `BEFORE_SWAP_FLAG` alone.

**Suggestion:** one line in the hook-deployment docs naming the factory. `HookMiner` handles this
for you, which is precisely why someone hand-rolling it will get it wrong.

## 5. `beforeAddLiquidity` being unflagged is a good default that reads as a gap

Because we only flagged `beforeSwap`, liquidity provision never consults the hook. That is what
we want — our gate is on trading, not on providing liquidity — but it is the kind of thing a
reviewer notices and assumes is an oversight. We wrote it into the contract comment for that
reason.

**Suggestion:** the flag docs could say out loud that gating trading and gating liquidity are
separate decisions, since the flags make it look like one surface.

## 6. Smaller things

- `SwapParams` and `ModifyLiquidityParams` live in `v4-core/src/types/PoolOperation.sol`, not in
  `IPoolManager`. Several examples and answers still show the old import path.
- A swap cannot be one EOA transaction: `unlock` means you deploy a router even for a demo where
  each step has to be a separate transaction somebody can open in a block explorer.
- To land a *refused* swap on chain — which is the whole point of a gate — you have to send it
  with an explicit `--gas-limit`, because a reverting call cannot be gas-estimated. Not a v4
  issue, but it is what a hook demo needs and nothing says so.

---

## What we built with it

A settlement, not a self-report, creates the right to write one ENS record about a job — and the
hook makes that record the pass to a pool. Three transactions, same sender, same pool, same swap:
refused, then executed, then refused again after the record was cleared.
[`docs/tokyo-2026/RECEIPTS.md`](docs/tokyo-2026/RECEIPTS.md) has all of them, checked in both
directions against a record generated from the chain.

The workload our zkVM re-executes is a **v3** `SwapRouter02` swap. **Earning happens on v3,
spending happens on v4**, and we keep those apart deliberately: we have not proven a v4 swap
inside the zkVM and do not claim to.

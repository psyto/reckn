import { test } from "node:test";
import assert from "node:assert/strict";
import { evmDealBinding, erc20BalanceSlot, type EvmDealTerms } from "../dist/binding.js";

const base: EvmDealTerms = {
  stateRoot: "0x" + "11".repeat(32),
  env: {
    chainId: 5042002n, specId: 17, blockNumber: 60_720_091n, timestamp: 1_788_000_000n,
    baseFee: 7n, blockGasLimit: 30_000_000n,
    coinbase: "0x" + "c0".repeat(20), prevrandao: "0x" + "22".repeat(32),
  },
  check: {
    address: "0x3600000000000000000000000000000000000000",
    slot: "0x" + "33".repeat(32),
    min: "0x" + "00".repeat(31) + "64",
    max: "0x" + "ff".repeat(32),
  },
  plan: {
    caller: "0x" + "ca".repeat(20), target: "0x" + "77".repeat(20),
    value: "0x" + "00".repeat(32), gasLimit: 100_000n, calldata: "0xdeadbeef",
  },
};

test("the same terms always give the same binding", () => {
  assert.equal(evmDealBinding(base), evmDealBinding(structuredClone(base)));
});

/**
 * The property the Rust test states in its own words: "dropping a single field from the
 * preimage makes that test fail". Here it is asserted directly — every committed field must
 * move the binding, because a field that does not is a field a counterparty can change after
 * you agreed to it.
 */
test("every committed field changes the binding", () => {
  const b0 = evmDealBinding(base);
  const mutate: Array<[string, (t: EvmDealTerms) => void]> = [
    ["stateRoot",      (t) => { t.stateRoot = "0x" + "12".repeat(32); }],
    ["env.chainId",    (t) => { t.env.chainId += 1n; }],
    ["env.specId",     (t) => { t.env.specId += 1; }],
    ["env.blockNumber",(t) => { t.env.blockNumber += 1n; }],
    ["env.timestamp",  (t) => { t.env.timestamp += 1n; }],
    ["env.baseFee",    (t) => { t.env.baseFee += 1n; }],
    ["env.blockGasLimit", (t) => { t.env.blockGasLimit += 1n; }],
    ["env.coinbase",   (t) => { t.env.coinbase = "0x" + "c1".repeat(20); }],
    ["env.prevrandao", (t) => { t.env.prevrandao = "0x" + "23".repeat(32); }],
    ["check.address",  (t) => { t.check.address = "0x" + "aa".repeat(20); }],
    ["check.slot",     (t) => { t.check.slot = "0x" + "34".repeat(32); }],
    ["check.min",      (t) => { t.check.min = "0x" + "00".repeat(31) + "65"; }],
    ["check.max",      (t) => { t.check.max = "0x" + "fe".repeat(32); }],
    ["plan.caller",    (t) => { t.plan.caller = "0x" + "cb".repeat(20); }],
    ["plan.target",    (t) => { t.plan.target = "0x" + "78".repeat(20); }],
    ["plan.value",     (t) => { t.plan.value = "0x" + "00".repeat(31) + "01"; }],
    ["plan.gasLimit",  (t) => { t.plan.gasLimit += 1n; }],
    ["plan.calldata",  (t) => { t.plan.calldata = "0xdeadbeef00"; }],
  ];
  const seen = new Map<string, string>([[b0, "base"]]);
  for (const [name, f] of mutate) {
    const t = structuredClone(base); f(t);
    const b = evmDealBinding(t);
    assert.notEqual(b, b0, `changing ${name} did not change the binding — it is not committed`);
    const prior = seen.get(b);
    assert.equal(prior, undefined, `changing ${name} collides with ${prior}`);
    seen.set(b, name);
  }
  assert.equal(seen.size, mutate.length + 1);
});

/**
 * The trap the Rust carries a comment about: the calldata length is a u64 big-endian word,
 * not a platform-sized integer. If it were emitted as anything narrower, these two would
 * collide — the length bytes would run into the calldata and the boundary would be ambiguous.
 */
test("the calldata length is framed, so length and content cannot be confused", () => {
  const a = structuredClone(base); a.plan.calldata = "0x0000000000000001ff";
  const b = structuredClone(base); b.plan.calldata = "0x01ff";
  assert.notEqual(evmDealBinding(a), evmDealBinding(b));
});

test("empty calldata is a valid, distinct plan", () => {
  const t = structuredClone(base); t.plan.calldata = "0x";
  assert.notEqual(evmDealBinding(t), evmDealBinding(base));
  assert.match(evmDealBinding(t), /^0x[0-9a-f]{64}$/);
});

test("wrong-width fields are rejected rather than padded", () => {
  for (const [field, bad] of [
    ["stateRoot", "0x1234"], ["env.coinbase", "0xdead"], ["check.slot", "0x00"],
  ] as const) {
    const t = structuredClone(base);
    if (field === "stateRoot") t.stateRoot = bad;
    if (field === "env.coinbase") t.env.coinbase = bad;
    if (field === "check.slot") t.check.slot = bad;
    assert.throws(() => evmDealBinding(t), /expected \d+ bytes/, `${field} must not be silently padded`);
  }
});

test("a u64 field out of range throws instead of wrapping", () => {
  const t = structuredClone(base);
  t.env.chainId = 2n ** 64n;
  assert.throws(() => evmDealBinding(t), /not a u64/);
});

/**
 * Ground truth from a real mainnet access list: for USDC (balances at slot 9) the slot this
 * computes is the one a Uniswap v3 swap actually writes. Measured 2026-09-08 — the holder is
 * a real address whose balance slot appeared in `eth_createAccessList` output.
 */
test("erc20BalanceSlot reproduces a slot observed in a real access list", () => {
  assert.equal(
    erc20BalanceSlot("0x28C6c06298d514Db089934071355E5743bf21d60", 9),
    "0x07081a045c3dbf2e63b62a407ef205e7586e2629d2e2b95ff093308ca0ff3727",
  );
});

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  reproduces, assertPredicateCanDecide, MAX_U256, formatUnits, isMethodMissing,
} from "../dist/index.js";
import { touchedByCall, assertPredicateSlotIsTouched } from "../dist/witness.js";
import { createAccessList, getBlock, getChainId, getProof } from "../dist/rpc.js";

/**
 * These four modules were inside `buildTerms` and `sellerPreflight` until they were split out.
 * The split is only worth anything if it means they can be ASKED DIRECTLY — before, the
 * predicate rule could be exercised only by driving a fake JSON-RPC endpoint, so a test of the
 * rule was also a test of the transport, and neither was isolated when one failed.
 */

// ───────────────────────────────────────────────────────────── predicate ──
test("assertPredicateCanDecide refuses both undecidable shapes and admits the smallest real one", () => {
  assert.throws(() => assertPredicateCanDecide(0n, MAX_U256), /satisfied by doing nothing/);
  assert.throws(() => assertPredicateCanDecide(10n, 9n), /cannot be satisfied by any execution/);
  assert.doesNotThrow(() => assertPredicateCanDecide(1n, MAX_U256));
  assert.doesNotThrow(() => assertPredicateCanDecide(5n, 5n), "an exact-equality band decides");
});

test("reproduces saturates, so a decrease is delta zero rather than a wrapped enormous number", () => {
  assert.equal(reproduces(2n ** 64n, 2n ** 64n - 1n, 1n, MAX_U256), false, "a decrease must not pay");
  assert.equal(reproduces(2n ** 64n, 2n ** 64n - 1n, 0n, MAX_U256), true, "…and scores 0, not 2^256-1");
  assert.equal(reproduces(42n, 142n, 100n, MAX_U256), true);
  assert.equal(reproduces(42n, 141n, 100n, MAX_U256), false, "one short of the floor is Failed");
});

// ──────────────────────────────────────────────────────────────── format ──
test("formatUnits is exact past 2^53 and grows no trailing dot", () => {
  assert.equal(formatUnits(123456789012345678901n, 18), "123.456789012345678901");
  assert.equal(formatUnits(5_000000n, 6), "5");
  assert.equal(formatUnits(1n, 6), "0.000001");
  assert.equal(formatUnits(0n, 6), "0");
  assert.equal(formatUnits(250n, 0), "250");
});

// ─────────────────────────────────────────────────────────────────── rpc ──
test("isMethodMissing recognises every wording we have actually met, and does not overreach", () => {
  // Arc, geth-family, and the spec. The first pattern missed the middle one.
  assert.ok(isMethodMissing(new Error("method not supported")));
  assert.ok(isMethodMissing(new Error("the method eth_createAccessList does not exist")));
  assert.ok(isMethodMissing(new Error("Method not found")));
  assert.ok(isMethodMissing(Object.assign(new Error("anything at all"), { code: -32601 })));
  // and the failures that are NOT this, which is the half that matters
  assert.equal(isMethodMissing(new Error("execution reverted")), false);
  assert.equal(isMethodMissing(new Error("insufficient funds")), false);
  assert.equal(isMethodMissing(new Error("connection reset by peer")), false);
});

test("createAccessList tells the three failures apart by TYPE, not only by wording", async () => {
  const missing = async () => { throw new Error("method not supported"); };
  await assert.rejects(() => createAccessList(missing as never, {}, "0x1"),
    (e: Error) => e.name === "EndpointCapabilityError" && /Nothing is wrong with your call/.test(e.message));

  const reverts = async () => ({ error: "execution reverted" });
  await assert.rejects(() => createAccessList(reverts as never, {}, "0x1"),
    (e: Error) => e.name === "CallRevertedError" && /REVERTS at block/.test(e.message));

  const weird = async () => { throw new Error("connection reset by peer"); };
  await assert.rejects(() => createAccessList(weird as never, {}, "0x1"),
    (e: Error) => e.name === "SimulationInconclusiveError" && /cannot tell you why/.test(e.message));
});

test("a node answering with the wrong shape fails at the edge, not inside a binding", async () => {
  // The point of validating here: `block.number` used to be read straight off the wire, so a
  // node returning something else put `undefined` into a preimage instead of raising an error.
  await assert.rejects(() => getBlock((async () => ({ number: "0x1" })) as never, "latest"),
    (e: Error) => e.name === "MalformedResponseError" && /eth_getBlockByNumber/.test(e.message));
  await assert.rejects(() => getChainId((async () => "not a number") as never),
    (e: Error) => e.name === "MalformedResponseError");
  await assert.rejects(() => getProof((async () => ({ balance: "0x0" })) as never, "0xa", [], "0x1"),
    (e: Error) => e.name === "MalformedResponseError" && /missing nonce/.test(e.message));
});

// ─────────────────────────────────────────────────────────────── witness ──
test("touchedByCall adds the three accounts every transaction touches", () => {
  const t = touchedByCall([{ address: "0xAA", storageKeys: ["0x01"] }], ["0xCa", "0x77", "0xC0"]);
  assert.deepEqual([...t.keys()].sort(), ["0x77", "0xaa", "0xc0", "0xca"]);
  assert.deepEqual([...t.get("0xaa")!], ["0x01"], "and lowercases what it was given");
});

test("assertPredicateSlotIsTouched names the slots that WERE touched", () => {
  const t = touchedByCall([{ address: "0xtok".toLowerCase(), storageKeys: ["0xdead"] }], []);
  assert.doesNotThrow(() => assertPredicateSlotIsTouched(t,
    { token: "0xTOK", holder: "0xh", balancesSlotIndex: 9, slot: "0xDEAD" }), "case must not matter");
  assert.throws(() => assertPredicateSlotIsTouched(t,
    { token: "0xTOK", holder: "0xh", balancesSlotIndex: 0, slot: "0xbeef" }),
    /never touches the slot[\s\S]*0xdead/, "the refusal must print what was touched");
});

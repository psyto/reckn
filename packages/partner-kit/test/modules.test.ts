import { test } from "node:test";
import assert from "node:assert/strict";
import { reproduces, assertPredicateCanDecide, MAX_U256, formatUnits } from "../dist/index.js";
// isMethodMissing is transport-internal and not on the package surface — reached directly.
import { isMethodMissing } from "../dist/rpc.js";
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

// ────────────── the endpoint must never be reported as the reader's mistake ──
test("a node answering null for the simulation is named as such, not blamed on --slot-index", async () => {
  // The regression this guards is not hypothetical: `createAccessList` coerced a non-object
  // response to an empty access list, the empty set flowed into the witness, and
  // assertPredicateSlotIsTouched then told the reader in four confident lines that their
  // balances slot index was wrong. A gateway proxying an unsupported method answers null.
  // At HEAD this was a TypeError — ugly, but impossible to believe. The refactor made it
  // articulate, which is worse.
  const nullish = async () => null;
  await assert.rejects(() => createAccessList(nullish as never, {}, "0x1"),
    (e: Error) => e.name === "MalformedResponseError" && /answered null/.test(e.message));

  const noList = async () => ({ gasUsed: "0x1" });
  await assert.rejects(() => createAccessList(noList as never, {}, "0x1"),
    (e: Error) => /no accessList in the result/.test(e.message));
});

test("buildTerms surfaces that fault as the endpoint's, not the caller's", async () => {
  const { buildTerms } = await import("../dist/index.js");
  const BLK = { number: "0x64", hash: "0x" + "b1".repeat(32), stateRoot: "0x" + "57".repeat(32),
    timestamp: "0x1000", baseFeePerGas: "0x7", gasLimit: "0x1c9c380", miner: "0x" + "c0".repeat(20) };
  const rpc = async (m: string) => {
    if (m === "eth_chainId") return "0x" + (5042002).toString(16);
    if (m === "eth_getBlockByNumber") return BLK;
    if (m === "eth_createAccessList") return null;
    throw new Error(m);
  };
  const prof = { id: "t", version: "1.0.0", status: "testnet",
    chain: { name: "T", chainId: 5042002, rpc: "http://x" },
    escrow: "0x" + "e5".repeat(20), verifier: "0x" + "1f".repeat(20),
    verifierCodeHash: "0x" + "aa".repeat(32), verdictProgramVKey: "0x" + "bb".repeat(32),
    vm: "evm", specId: 17, predicate: { kind: "poststate-delta", description: "d" },
    dealBindingScheme: "reckn/zk/bind/evm/v2", knownLimits: ["x"] };
  await assert.rejects(
    () => buildTerms({ profile: prof, rpc, caller: "0x" + "ca".repeat(20), target: "0x" + "77".repeat(20),
      calldata: "0xdead", check: { token: "0x" + "70".repeat(20), holder: "0x" + "ca".repeat(20),
        balancesSlotIndex: 9, min: 100n } } as never),
    (e: Error) => /eth_createAccessList/.test(e.message) && !/slot-index|balances slot index/.test(e.message),
  );
});

test("gasUsed is accepted as a number and refused as anything else, never substituted", async () => {
  // It decides nothing — and a substituted zero printed next to measured values is still a lie.
  const num = async () => ({ accessList: [], gasUsed: 4660 });
  assert.equal((await createAccessList(num as never, {}, "0x1")).gasUsed, "0x1234");
  const obj = async () => ({ accessList: [], gasUsed: {} });
  await assert.rejects(() => createAccessList(obj as never, {}, "0x1"), /gasUsed was object/);
});

test("a storage proof without a value is refused rather than given one", async () => {
  // `value` is the committed PRESTATE of a slot. Inventing it puts a fabricated number inside
  // a witness. It fails closed downstream; that is not a reason to write it.
  const p = async () => ({ balance: "0x0", nonce: "0x0", storageHash: "0x" + "55".repeat(32),
    codeHash: "0x" + "66".repeat(32), accountProof: ["0xab"],
    storageProof: [{ key: "0x" + "01".repeat(32), proof: [] }] });
  await assert.rejects(() => getProof(p as never, "0xa", [], "0x1"),
    (e: Error) => e.name === "MalformedResponseError" && /bad storageProof entry/.test(e.message));
});

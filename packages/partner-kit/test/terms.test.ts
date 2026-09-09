import { test } from "node:test";
import assert from "node:assert/strict";
import { buildTerms, evmDealBinding } from "../dist/index.js";
import type { VerifierProfile } from "../dist/profile.js";

/**
 * `buildTerms` is the step a partner had no tool for. Its value is not that it produces
 * terms — it is that it REFUSES to produce terms that would open a deal nobody can settle.
 * Each refusal below corresponds to a failure that is silent at funding time and expensive
 * at settlement time.
 */
const CALLER = "0x00000000000000000000000000000000000ca11e";
const TARGET = "0x0000000000000000000000000000000000007a67";
const TOKEN = "0x0000000000000000000000000000000000707550";

const profile = (over: Partial<VerifierProfile> = {}): VerifierProfile => ({
  id: "t", version: "1.0.0", status: "testnet",
  chain: { name: "T", chainId: 5042002, rpc: "http://x" },
  escrow: "0x" + "e5".repeat(20), verifier: "0x" + "1f".repeat(20),
  verifierCodeHash: "0x" + "aa".repeat(32), verdictProgramVKey: "0x" + "bb".repeat(32),
  vm: "evm", specId: 17,
  predicate: { kind: "poststate-delta", description: "d" },
  dealBindingScheme: "reckn/zk/bind/evm/v2", knownLimits: ["x"], ...over,
});

const BLOCK = {
  number: "0x64", hash: "0x" + "b1".repeat(32), stateRoot: "0x" + "57".repeat(32),
  timestamp: "0x1000", baseFeePerGas: "0x7", gasLimit: "0x1c9c380",
  miner: "0x" + "c0".repeat(20), mixHash: "0x" + "22".repeat(32),
};

function rpcFor(over: Partial<{ chainId: number; accessError: string; throwOnSim: string }> = {}) {
  return async (method: string, params: unknown[]) => {
    if (method === "eth_chainId") return "0x" + (over.chainId ?? 5042002).toString(16);
    if (method === "eth_getBlockByNumber") return BLOCK;
    if (method === "eth_createAccessList") {
      if (over.throwOnSim) throw new Error(over.throwOnSim);
      if (over.accessError) return { error: over.accessError, gasUsed: "0x0", accessList: [] };
      return { gasUsed: "0x1234", accessList: [{ address: TOKEN, storageKeys: ["0x" + "01".repeat(32)] }] };
    }
    if (method === "eth_getProof") {
      return { balance: "0x0", nonce: "0x0", storageHash: "0x" + "55".repeat(32),
        codeHash: "0x" + "66".repeat(32), accountProof: ["0xabcd"],
        storageProof: [{ key: "0x" + "01".repeat(32), value: "0x0", proof: ["0xef"] }] };
    }
    if (method === "eth_getCode") return "0x6000";
    throw new Error(`unexpected ${method}`);
  };
}

const args = (over: object = {}) => ({
  profile: profile(), rpc: rpcFor(), caller: CALLER, target: TARGET, calldata: "0xdeadbeef",
  value: 1n, gasLimit: 500_000n,
  check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 9, min: 100n },
  ...over,
} as never);

test("a successful call yields terms, a binding, and a self-contained witness", async () => {
  const b = await buildTerms(args());
  assert.match(b.dealBinding, /^0x[0-9a-f]{64}$/);
  assert.equal(b.terms.env.specId, 17, "the hardfork comes from the profile");
  assert.equal(b.anchor.blockNumber, "0x64");
  // The witness must include the caller, the target and the coinbase on top of the access
  // list — the keeper does the same, and a bundle missing them cannot be proved.
  const addrs = b.witness.map((w) => w.address);
  for (const a of [TOKEN, CALLER, TARGET, BLOCK.miner]) {
    assert.ok(addrs.includes(a.toLowerCase()), `witness is missing ${a}`);
  }
  assert.ok(b.witness.every((w) => w.accountProof.length > 0), "every account carries a proof");
});

test("REFUSES a call that reverts at the anchor", async () => {
  // The expensive silent failure: a plan that fails at the anchor settles as Failed, so the
  // buyer pays to be told the work did not reproduce. It must not be possible to open that.
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ accessError: "execution reverted" }) })),
    /REVERTS at block .*Terms were not produced/s,
  );
});

test("REFUSES when the node will not simulate at all", async () => {
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ throwOnSim: "insufficient funds" }) })),
    /could not be simulated/,
  );
});

test("REFUSES a profile that does not pin the hardfork", async () => {
  // specId is committed into the binding. A guess produces a valid-looking hash that no proof
  // from this guest can match, and nothing errors at funding time.
  await assert.rejects(
    () => buildTerms(args({ profile: profile({ specId: undefined }) })),
    /does not pin specId/,
  );
});

test("REFUSES when the endpoint is a different chain from the profile's", async () => {
  await assert.rejects(() => buildTerms(args({ rpc: rpcFor({ chainId: 1 }) })), /answers chain 1/);
});

test("REFUSES an SVM profile for EVM terms", async () => {
  await assert.rejects(
    () => buildTerms(args({ profile: profile({ vm: "svm", specId: null }) })),
    /adjudicates svm/,
  );
});

test("the binding it returns is the one evmDealBinding computes from the same terms", async () => {
  // Guards against buildTerms and the escrow path drifting apart: they must be one value.
  const b = await buildTerms(args());
  assert.equal(b.dealBinding, evmDealBinding(b.terms));
});

test("the predicate points at the holder's balance slot, not somewhere else", async () => {
  const b = await buildTerms(args());
  assert.equal(b.terms.check.address, TOKEN);
  assert.equal(BigInt(b.terms.check.min), 100n);
  assert.equal(b.terms.check.slot.length, 66);
});

test("provenance says what was and was not established", async () => {
  const b = await buildTerms(args());
  assert.match(b.provenance.note, /SIMULATED/);
  assert.match(b.provenance.note, /not a promise it will satisfy the floor/);
  assert.match(b.provenance.note, /still needs the SP1 toolchain/);
});

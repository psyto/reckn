import { test } from "node:test";
import assert from "node:assert/strict";
import { buildTerms, evmDealBinding, reproduces, erc20BalanceSlot } from "../dist/index.js";
import { readFileSync } from "node:fs";
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

/** The slot the predicate measures. The mock below MUST touch it: a call that does not is
 *  precisely the bundle `buildTerms` now refuses, so a fixture that omitted it was quietly
 *  asserting the happy path over an unprovable deal. */
const CHECK_SLOT = erc20BalanceSlot(CALLER, 9);

function rpcFor(over: Partial<{ chainId: number; accessError: string; throwOnSim: string; touchSlot: string }> = {}) {
  return async (method: string, params: unknown[]) => {
    if (method === "eth_chainId") return "0x" + (over.chainId ?? 5042002).toString(16);
    if (method === "eth_getBlockByNumber") return BLOCK;
    if (method === "eth_createAccessList") {
      if (over.throwOnSim) throw new Error(over.throwOnSim);
      if (over.accessError) return { error: over.accessError, gasUsed: "0x0", accessList: [] };
      return { gasUsed: "0x1234", accessList: [{ address: TOKEN, storageKeys: [over.touchSlot ?? CHECK_SLOT] }] };
    }
    if (method === "eth_getProof") {
      const keys = (params as [string, string[], string])[1] ?? [];
      return { balance: "0x0", nonce: "0x0", storageHash: "0x" + "55".repeat(32),
        codeHash: "0x" + "66".repeat(32), accountProof: ["0xabcd"],
        storageProof: keys.map((k) => ({ key: k, value: "0x0", proof: ["0xef"] })) };
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
  // Asserts the BEHAVIOUR — nothing is produced when the simulation does not complete —
  // rather than a sentence. This test pinned the old wording and went red when the message
  // was made more accurate, which is a test measuring the phrasing of an answer, not the answer.
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ throwOnSim: "insufficient funds" }) })),
    (e: Error) => /No terms were produced/.test(e.message) && /insufficient funds/.test(e.message),
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
  // This asserted `slot.length === 66` until 2026-09-09, which every keccak satisfies —
  // including the wrong one. It measured the shape of the answer and never the answer.
  const b = await buildTerms(args());
  assert.equal(b.terms.check.address, TOKEN);
  assert.equal(BigInt(b.terms.check.min), 100n);
  assert.equal(b.terms.check.slot, erc20BalanceSlot(CALLER, 9));
  // and it must actually depend on both inputs, or the equality above proves nothing
  assert.notEqual(erc20BalanceSlot(CALLER, 9), erc20BalanceSlot(CALLER, 0));
  assert.notEqual(erc20BalanceSlot(CALLER, 9), erc20BalanceSlot(TARGET, 9));
});

test("REFUSES a predicate aimed at a slot the call never touches", async () => {
  // The default `balancesSlotIndex` of 9 is Circle's layout, not a standard. Aim it at a
  // token whose balances live at slot 0 and everything downstream still works: the slot is a
  // well-formed keccak, the binding is well-formed, funding succeeds — and the guest then
  // measures a slot no execution writes, returning Failed on a correct replay forever.
  await assert.rejects(
    () => buildTerms(args({ check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 0, min: 100n } })),
    /never touches the slot this predicate measures[\s\S]*seller would work and not be paid/,
  );
});

test("the refusal reports the slots the call did touch, so the right index is recoverable", async () => {
  // A refusal that only says no leaves the partner guessing at 2^256 slots. It has the
  // access list in hand; the correct index is one comparison away.
  await assert.rejects(
    () => buildTerms(args({ check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 0, min: 100n } })),
    new RegExp(CHECK_SLOT),
  );
});

test("the predicate slot is carried into the witness with a storage proof", async () => {
  // Refusing the untouched case is only half of it: when the slot IS touched, the bundle must
  // actually prove it, or the guest cannot read `pre` and the deal is unprovable anyway.
  const b = await buildTerms(args());
  const tokenAcct = b.witness.find((w) => w.address === TOKEN.toLowerCase());
  assert.ok(tokenAcct, "the token must be in the witness");
  const proven = tokenAcct.storageProof.map((s) => s.key);
  assert.ok(proven.includes(b.terms.check.slot), "the predicate slot must carry a proof");
});

test("provenance says what was and was not established", async () => {
  const b = await buildTerms(args());
  assert.match(b.provenance.note, /SIMULATED/);
  assert.match(b.provenance.note, /not a promise it will satisfy the floor/);
  assert.match(b.provenance.note, /still needs the SP1 toolchain/);
});

// ─────────────────────────── the predicate has to be able to decide ──
/**
 * `reproduces` is a fourth transcription of guest logic, so it is checked the way the other
 * three are: against what the guest ACTUALLY COMMITTED, not against review. Each fixture below
 * carries `pre`, `post`, `min_delta`, `max_delta` and the `outcome` the guest produced inside
 * SP1 for exactly those numbers.
 *
 * `reexec-falserelease-fixture` is the one that earns its place: pre = 2^64 and post = 2^64-1,
 * a DECREASE, with `max` wide open. Transcribe the subtraction as wrapping instead of
 * saturating and the delta becomes enormous, lands inside the band, and this returns
 * Reproduced where the guest returned Failed. The test fails.
 */
const FIXTURES = [
  "groth16-fixture.json",
  "reexec-groth16-fixture.json",
  "reexec-falserelease-fixture.json",
  "svm-groth16-fixture.json",
  "svm-failed-fixture.json",
];

test("reproduces() agrees with every verdict the guest actually committed", () => {
  const dir = new URL("../../../zk-verdict/contracts/src/fixtures/", import.meta.url);
  const seen = new Set<number>();
  for (const name of FIXTURES) {
    const f = JSON.parse(readFileSync(new URL(name, dir), "utf8"));
    const got = reproduces(BigInt(f.pre), BigInt(f.post), BigInt(f.min_delta), BigInt(f.max_delta));
    const guest = f.outcome === 0;
    assert.equal(got, guest, `${name}: guest said ${guest ? "Reproduced" : "Failed"}, we said ${got}`);
    seen.add(f.outcome);
  }
  // A row set that only ever says one thing would pass for a function stuck on that answer.
  assert.deepEqual([...seen].sort(), [0, 1], "the fixtures must exercise both verdicts");
});

test("buildTerms refuses a floor of zero, and says who loses", async () => {
  await assert.rejects(
    () => buildTerms(args({ check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 9, min: 0n } })),
    /satisfied by doing nothing[\s\S]*BUYER/,
  );
});

test("buildTerms refuses a band no execution can satisfy", async () => {
  await assert.rejects(
    () => buildTerms(args({ check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 9, min: 10n, max: 9n } })),
    /cannot be satisfied by any execution/,
  );
});

test("a predicate that decides nothing is refused before a single request goes out", async () => {
  // Not cosmetic: it is the difference between a local mistake costing nothing and costing an
  // eth_getProof sweep. The rpc here THROWS on any call, so reaching one fails the test.
  let calls = 0;
  const rpc = async (m: string) => { calls++; throw new Error(`must not reach the network: ${m}`); };
  await assert.rejects(
    () => buildTerms(args({ rpc, check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 9, min: 0n } })),
    /satisfied by doing nothing/,
  );
  assert.equal(calls, 0);
});

test("a floor of exactly one is accepted — the smallest predicate that decides anything", async () => {
  const b = await buildTerms(args({ check: { token: TOKEN, holder: CALLER, balancesSlotIndex: 9, min: 1n } }));
  assert.equal(BigInt(b.terms.check.min), 1n);
});

test("an endpoint that cannot simulate is not reported as a bad call", async () => {
  // Opposite problems, and one message blamed the caller for both. Measured 2026-09-09: Arc's
  // public RPC implements neither eth_createAccessList nor eth_getProof, so `reckn terms`
  // against the profile we ship FOR ARC failed with "the call could not be simulated" — which
  // sends a partner to debug a call that is fine.
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ throwOnSim: "method not supported" }) })),
    /does not implement eth_createAccessList[\s\S]*Nothing is wrong with your call/,
  );
});

test("that refusal still says what CAN be done from a limited endpoint", async () => {
  // A refusal that only says no strands the reader. The binding needs one block read; only
  // the proof of success and the witness need the methods this node lacks.
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ throwOnSim: "the method eth_createAccessList does not exist" }) })),
    /BINDING commits only stateRoot, env, check and plan/,
  );
});

test("a genuine revert is still reported as a bad call, not as a bad endpoint", async () => {
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ accessError: "execution reverted" }) })),
    /REVERTS at block/,
  );
});

test("an unrecognised simulation failure does not guess which side is at fault", async () => {
  // The default used to be "your work did not reproduce", which is an accusation. When the
  // cause is genuinely unknown, saying so beats picking the reading that blames the reader.
  await assert.rejects(
    () => buildTerms(args({ rpc: rpcFor({ throwOnSim: "connection reset by peer" }) })),
    /cannot tell you why[\s\S]*one of two unrelated things/,
  );
});

import { test } from "node:test";
import assert from "node:assert/strict";
import { keccak256 } from "viem";
import { createDeal, verifySettlement, verifyProfileAgainstChain } from "../dist/index.js";
import type { VerifierProfile } from "../dist/profile.js";

/**
 * **The refusal paths.**
 *
 * The starter runs the three success paths and it runs them for real. None of it exercises
 * the cases where this package is supposed to say NO — which are exactly the ones the
 * documentation makes promises about. A comment claiming a property, with nothing that fails
 * when the property is broken, is the shape this project keeps finding in other people's code
 * and had four instances of in its own.
 */

const ESCROW = "0x00000000000000000000000000000000000e5c70" as const;
const VERIFIER = "0x0000000000000000000000000000000000ae1f1e" as const;
const TOKEN = "0x0000000000000000000000000000000000707550" as const;
const SELLER = "0x0000000000000000000000000000000000005e11" as const;
const BUYER = "0x000000000000000000000000000000000000b0b0" as const;
const DEAL = "0xd0d0000000000000000000000000000000000000000000000000000000000d0d" as const;
const CODE = "0x60006000";
const REAL_CODEHASH = keccak256(CODE);
const VKEY = "0x00c2ee9999a00a5987a5b5c5261bee355bbb6e86c145429775d9fe89f496e16d" as const;

const terms = {
  stateRoot: "0x" + "11".repeat(32),
  env: { chainId: 5042002n, specId: 17, blockNumber: 1n, timestamp: 2n, baseFee: 3n,
    blockGasLimit: 4n, coinbase: "0x" + "c0".repeat(20), prevrandao: "0x" + "22".repeat(32) },
  check: { address: TOKEN, slot: "0x" + "33".repeat(32), min: "0x" + "00".repeat(32), max: "0x" + "ff".repeat(32) },
  plan: { caller: "0x" + "ca".repeat(20), target: "0x" + "77".repeat(20),
    value: "0x" + "00".repeat(32), gasLimit: 1n, calldata: "0x" },
};

function baseProfile(over: Partial<VerifierProfile> = {}): VerifierProfile {
  return {
    id: "t", version: "1.0.0", status: "testnet",
    chain: { name: "T", chainId: 5042002, rpc: "http://x" },
    escrow: ESCROW, verifier: VERIFIER, verifierCodeHash: REAL_CODEHASH, verdictProgramVKey: VKEY,
    vm: "evm", predicate: { kind: "poststate-delta", description: "d" },
    dealBindingScheme: "reckn/zk/bind/evm/v2", knownLimits: ["x"], ...over,
  };
}

function clients(over: Partial<{
  chainId: number; verifierCode: string; vkey: string; dealState: number; allowance: bigint;
}> = {}) {
  const writes: Array<{ functionName: string }> = [];
  const publicClient = {
    async request({ method, params }: { method: string; params: unknown[] }) {
      if (method === "eth_chainId") return "0x" + (over.chainId ?? 5042002).toString(16);
      if (method === "eth_getCode") {
        const addr = String((params as string[])[0]).toLowerCase();
        if (addr === ESCROW) return CODE;
        return over.verifierCode ?? CODE;
      }
      if (method === "eth_call") return over.vkey ?? VKEY;
      throw new Error(`unexpected ${method}`);
    },
    async readContract({ functionName }: { functionName: string }) {
      if (functionName === "deals") {
        return [BUYER, SELLER, TOKEN, 1n, VERIFIER, REAL_CODEHASH,
          "0x" + "00".repeat(32), 0n, over.dealState ?? 0];
      }
      if (functionName === "allowance") return over.allowance ?? 0n;
      throw new Error(`unexpected readContract ${functionName}`);
    },
    async waitForTransactionReceipt() { return {}; },
  } as never;
  const walletClient = {
    async writeContract(a: { functionName: string }) { writes.push({ functionName: a.functionName }); return "0x01"; },
  } as never;
  return { publicClient, walletClient, writes };
}

const args = (c: ReturnType<typeof clients>, profile = baseProfile()) => ({
  profile, publicClient: c.publicClient, walletClient: c.walletClient, account: BUYER,
  dealId: DEAL, seller: SELLER, token: TOKEN, amount: 1n, terms,
} as never);

// ─────────────────────────────────────────────────────────────── createDeal ──

test("createDeal refuses when the verifier's code on chain is not what the profile claims", async () => {
  // The promise in docs/partner-kit.md: "refuses to fund if the verifier's codehash on chain
  // differs from the file's". Funding against something nobody has looked at is the mistake
  // this package exists to prevent, and until now nothing checked that it did.
  const c = clients({ verifierCode: "0xdeadbeef" });
  await assert.rejects(() => createDeal(args(c)), /does not match the chain/);
  assert.deepEqual(c.writes, [], "nothing may be sent when the profile does not match");
});

test("createDeal refuses when the verifier judges a different guest", async () => {
  const c = clients({ vkey: "0x" + "ab".repeat(32) });
  await assert.rejects(() => createDeal(args(c)), /does not match the chain/);
  assert.deepEqual(c.writes, []);
});

test("createDeal refuses when the endpoint is a different chain", async () => {
  const c = clients({ chainId: 1 });
  await assert.rejects(() => createDeal(args(c)), /does not match the chain/);
  assert.deepEqual(c.writes, []);
});

test("createDeal refuses an SVM profile for EVM terms, and says why", async () => {
  // This is the mistake the Tempo profile warns about: Tempo's verifier judges the SVM guest,
  // so an EVM binding funded there could never settle.
  const c = clients();
  await assert.rejects(
    () => createDeal(args(c, baseProfile({ vm: "svm", dealBindingScheme: "reckn/zk/bind/svm/v2" }))),
    /adjudicates svm/,
  );
  assert.deepEqual(c.writes, []);
});

test("createDeal refuses to reuse a dealId that already exists", async () => {
  const c = clients({ dealState: 1 });
  await assert.rejects(() => createDeal(args(c)), /already exists/);
  assert.deepEqual(c.writes, []);
});

test("createDeal skips the approve when the allowance already covers it", async () => {
  const c = clients({ allowance: 10n });
  const r = await createDeal(args(c));
  assert.deepEqual(c.writes.map((w) => w.functionName), ["fund"], "no redundant approve");
  assert.equal(r.approveTx, undefined);
});

test("createDeal in dryRun sends nothing and still returns the binding", async () => {
  const c = clients();
  const r = await createDeal({ ...(args(c) as object), dryRun: true } as never);
  assert.deepEqual(c.writes, []);
  assert.match(r.dealBinding, /^0x[0-9a-f]{64}$/);
  assert.equal(r.dryRun, true);
});

// ──────────────────────────────────────────────────────── verifySettlement ──

const TRANSFER = keccak256(new TextEncoder().encode("Transfer(address,address,uint256)"));
const SETTLED = keccak256(new TextEncoder().encode("SettledByProof(bytes32,address,uint8,bytes32)"));
const pad = (a: string) => "0x" + a.slice(2).toLowerCase().padStart(64, "0");
const word = (n: bigint) => "0x" + n.toString(16).padStart(64, "0");

function receiptClient(logs: unknown[]) {
  return {
    async readContract() {
      return [BUYER, SELLER, TOKEN, 250n, VERIFIER, REAL_CODEHASH, "0x" + "da".repeat(32), 0n, 2];
    },
    async getTransactionReceipt() { return { blockNumber: 1n, gasUsed: 2n, logs }; },
  } as never;
}

test("verifySettlement counts only the escrow's own Transfer, not somebody else's", async () => {
  // The code says so in a comment; this is the test that makes it true. A receipt can carry
  // unrelated Transfers -- a fee, a router hop -- and reporting one of those as "moved out of
  // the escrow" would put a wrong number into a third party's verification.
  const ours = { topics: [TRANSFER, pad(ESCROW), pad(SELLER)], data: word(250n), address: TOKEN };
  const foreign = { topics: [TRANSFER, pad("0x00000000000000000000000000000000deadbeef"), pad(SELLER)], data: word(999999n), address: TOKEN };
  const settled = { topics: [SETTLED, DEAL, pad(SELLER)], data: word(0n) + "aa".repeat(32), address: ESCROW };
  // ORDER MATTERS, and the first version of this test got it wrong: with the foreign log
  // FIRST, an implementation that took any Transfer would still end on ours and pass. The
  // foreign one is last so that "take the last Transfer" yields 999999 and fails.
  const out = await verifySettlement({
    publicClient: receiptClient([ours, settled, foreign]) as never,
    escrow: ESCROW, dealId: DEAL, tx: "0xaa" as never,
  });
  assert.equal(out.amountMoved, 250n, "the foreign Transfer must not be reported as this settlement's");
});

test("verifySettlement ignores a SettledByProof for a different deal in the same receipt", async () => {
  const other = "0xeeee000000000000000000000000000000000000000000000000000000000eee" as const;
  const wrongDeal = { topics: [SETTLED, other, pad(BUYER)], data: word(1n) + "bb".repeat(32), address: ESCROW };
  const out = await verifySettlement({
    publicClient: receiptClient([wrongDeal]) as never,
    escrow: ESCROW, dealId: DEAL, tx: "0xaa" as never,
  });
  assert.equal(out.outcome, undefined, "another deal's verdict is not this deal's");
  assert.equal(out.paidTo, undefined);
});

// ────────────────────────────────────────────── verifyProfileAgainstChain ──

const rpcFor = (over: Partial<{ chainId: number; code: string; vkey: string }> = {}) =>
  async (method: string, params: unknown[]) => {
    if (method === "eth_chainId") return "0x" + (over.chainId ?? 5042002).toString(16);
    if (method === "eth_getCode") {
      return String((params as string[])[0]).toLowerCase() === ESCROW ? CODE : (over.code ?? CODE);
    }
    if (method === "eth_call") return over.vkey ?? VKEY;
    throw new Error(method);
  };

test("verifyProfileAgainstChain catches each disagreement separately", async () => {
  const ok = await verifyProfileAgainstChain(baseProfile(), rpcFor(), keccak256 as never);
  assert.equal(ok.ok, true, `a matching profile must pass: ${JSON.stringify(ok.findings)}`);

  for (const [label, over, field] of [
    ["wrong chain", { chainId: 1 }, "chain.chainId"],
    ["wrong code", { code: "0xdeadbeef" }, "verifierCodeHash"],
    ["wrong guest", { vkey: "0x" + "ab".repeat(32) }, "verdictProgramVKey"],
  ] as const) {
    const r = await verifyProfileAgainstChain(baseProfile(), rpcFor(over), keccak256 as never);
    assert.equal(r.ok, false, label);
    assert.ok(r.findings.some((f) => f.field === field), `${label}: expected a finding on ${field}`);
  }
});

test("verifyProfileAgainstChain reports a verifier with no code at all", async () => {
  const r = await verifyProfileAgainstChain(baseProfile(), rpcFor({ code: "0x" }), keccak256 as never);
  assert.equal(r.ok, false);
  assert.ok(r.findings.some((f) => f.field === "verifier" && /no code/.test(f.message)));
});

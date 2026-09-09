import { test } from "node:test";
import assert from "node:assert/strict";
import { sellerPreflight } from "../dist/index.js";
import type { VerifierProfile } from "../dist/profile.js";

/**
 * The preflight is the only surface a seller reads before committing work, so what it says —
 * and what it refuses to leave out — is a property worth pinning. It was checked by eye
 * against a real deal on Tempo and inside the starter, and neither of those notices if a
 * warning quietly disappears.
 *
 * A stub client rather than a chain: this is about what the report SAYS, and a test that
 * needs a network is a test that gets skipped.
 */
const ESCROW = "0x00000000000000000000000000000000000e5c70" as const;
const VERIFIER = "0x0000000000000000000000000000000000ae1f1e" as const;
const CODE = "0x60006000";                       // any non-empty code
const CODEHASH = "0x1f5eb51ceb9b9dc5d8a5b7d0d1c3fe0da6b5ea8d7e0c9c8ac1e4c1c6d1b3e5f7";

function stub(over: Partial<{ codehash: string; code: string; state: number;
    sellerBlocked: boolean; paused: boolean; noPolicy: boolean;
    amount: bigint; decimals: number }> = {}) {
  const state = over.state ?? 1;
  const pinned = over.codehash ?? CODEHASH;
  return {
    async readContract({ functionName }: { functionName: string }) {
      if (functionName === "deals") {
        return ["0xb0b0000000000000000000000000000000000b0b", "0x5e11000000000000000000000000000000005e11",
          "0x7075500000000000000000000000000000000705", over.amount ?? 250_000000n, VERIFIER, pinned,
          "0xda1da1da1da1da1da1da1da1da1da1da1da1da1da1da1da1da1da1da1da1da1d", 1_700_000_000n, state];
      }
      if (functionName === "REFUND_AFTER") return 2_592_000n;      // 30 days
      if (functionName === "symbol") return "USDC";
      if (functionName === "decimals") return over.decimals ?? 6;
      throw new Error(`unexpected readContract ${functionName}`);
    },
    async getCode() { return over.code ?? CODE; },
    async call({ data }: { data: string }) {
      const ONE = "0x" + "0".repeat(63) + "1";
      const ZERO = "0x" + "0".repeat(64);
      if (data.startsWith("0x4f074a62")) {
        return { data: "0x00c2ee9999a00a5987a5b5c5261bee355bbb6e86c145429775d9fe89f496e16d" };
      }
      // A token that implements none of the probed shapes reverts, exactly as PathUSD does
      // for isBlacklisted. That path must not be mistaken for "not blocked".
      if (over.noPolicy) throw new Error("execution reverted");
      if (data.startsWith("0xfe575a87")) {
        // The seller argument is the first (and only) word.
        const isSeller = data.toLowerCase().includes("5e11000000000000000000000000000000005e11");
        return { data: isSeller && over.sellerBlocked ? ONE : ZERO };
      }
      if (data.startsWith("0x5c975abb")) return { data: over.paused ? ONE : ZERO };
      return { data: ZERO };
    },
  } as never;
}

const profile: VerifierProfile = {
  id: "t", version: "1.0.0", status: "testnet",
  chain: { name: "Test", chainId: 1, rpc: "http://x" },
  escrow: ESCROW, verifier: VERIFIER, verifierCodeHash: CODEHASH,
  verdictProgramVKey: "0x00c2ee9999a00a5987a5b5c5261bee355bbb6e86c145429775d9fe89f496e16d",
  vm: "evm", specId: 17,
  predicate: { kind: "poststate-delta", description: "the slot must rise by at least 100" },
  dealBindingScheme: "reckn/zk/bind/evm/v2",
  knownLimits: ["the token can be paused"],
};

const DEAL = "0xd0d0000000000000000000000000000000000000000000000000000000000d0d" as const;

test("the report carries everything a seller needs to decide", async () => {
  // Pinned as a list rather than eyeballed: this is what "you should not have to read an
  // ABI to know what you are working on" means, made checkable.
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL, profile });
  for (const required of [
    "buyer", "seller", "token / amount", "verifier", "pinned hash", "on-chain hash",
    "judges guest", "binding", "predicate", "chain", "funded at", "refund opens",
  ]) {
    assert.ok(out.report.includes(required), `the report omits "${required}"`);
  }
  assert.ok(out.report.includes("250000000"), "the amount");
  assert.ok(out.report.includes("USDC"), "the token symbol, resolved from the token");
  assert.ok(out.report.includes("the slot must rise by at least 100"), "the predicate in words");
});

test("the two warnings that must never be dropped are always present", async () => {
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL, profile });
  assert.ok(
    out.warnings.some((w) => /buyer chose this verifier/i.test(w) && /work for nothing/i.test(w)),
    "the seller must be told the buyer picked the adjudicator and could have picked a hostile one",
  );
  assert.ok(
    out.warnings.some((w) => /NOT on-chain consent/i.test(w)),
    "the seller must be told this check is not enforced by the contract",
  );
});

test("the known limits from the profile reach the seller", async () => {
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL, profile });
  assert.ok(out.warnings.some((w) => w.includes("the token can be paused")));
});

test("a verifier whose code no longer matches is a loud failure, not a footnote", async () => {
  const out = await sellerPreflight({
    publicClient: stub({ codehash: "0x" + "ab".repeat(32) }),
    escrow: ESCROW, dealId: DEAL, profile,
  });
  assert.equal(out.verifierCodeHashMatches, false);
  assert.ok(out.report.includes("*** MISMATCH ***"));
  assert.ok(out.warnings.some((w) => /can only ever time out|Do not work on it/i.test(w)));
});

test("no profile means the seller is told what they are NOT being shown", async () => {
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL });
  assert.ok(
    out.warnings.some((w) => /No verifier profile supplied/.test(w) && /not a clean bill of health/.test(w)),
    "an absent profile must read as a gap, not as an all-clear",
  );
});

test("an unknown deal says so instead of rendering a blank form", async () => {
  const out = await sellerPreflight({ publicClient: stub({ state: 0 }), escrow: ESCROW, dealId: DEAL, profile });
  assert.equal(out.exists, false);
  assert.ok(out.warnings.some((w) => /No such deal/.test(w)));
});

test("the refund deadline is thirty days after funding, in the report", async () => {
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL, profile });
  assert.equal(out.refundOpensAt, 1_700_000_000n + 2_592_000n);
  assert.ok(out.report.includes("pays the caller nothing"));
});

test("a blacklisted seller is told they specifically will not be paid", async () => {
  // The generic warning ("this token carries a blacklist") was already there and was not
  // enough: on Arc there is a real deal whose seller IS on it, and the seller reading the
  // old preflight saw only the caveat. Measured on chain 2026-09-09 — isBlacklisted returns
  // 1 for that seller and 0 for the one who was actually paid.
  const out = await sellerPreflight({
    publicClient: stub({ sellerBlocked: true }), escrow: ESCROW, dealId: DEAL, profile,
  });
  assert.equal(out.tokenPolicy.sellerBlocked, true);
  assert.ok(out.report.includes("THE TOKEN WILL NOT PAY THIS SELLER"));
  assert.ok(out.warnings.some((w) => /would not get you paid/i.test(w)));
});

test("a seller who is not blocked gets no such warning", async () => {
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL, profile });
  assert.notEqual(out.tokenPolicy.sellerBlocked, true);
  assert.ok(!out.report.includes("WILL NOT PAY"));
});

test("a paused token blocks both directions and says so", async () => {
  const out = await sellerPreflight({ publicClient: stub({ paused: true }), escrow: ESCROW, dealId: DEAL, profile });
  assert.equal(out.tokenPolicy.paused, true);
  assert.ok(out.warnings.some((w) => /PAUSED/.test(w) && /either direction/i.test(w)));
});

test("what was probed is always reported, and never as a guarantee", async () => {
  // A quiet result must not read as "you will be paid". The probe list plus the disclaimer
  // is what keeps it honest, so both are pinned.
  const out = await sellerPreflight({ publicClient: stub(), escrow: ESCROW, dealId: DEAL, profile });
  assert.ok(out.tokenPolicy.probed.length > 0);
  assert.ok(out.warnings.some((w) => /known shapes, not a closed set/.test(w)
    && /not a promise that you will be paid/.test(w)));
});

test("a token exposing none of the shapes is reported as such, not as clean", async () => {
  const out = await sellerPreflight({ publicClient: stub({ noPolicy: true }), escrow: ESCROW, dealId: DEAL, profile });
  assert.deepEqual(out.tokenPolicy.probed, []);
  assert.ok(out.warnings.some((w) => /exposes none of the shapes we know/.test(w)));
});


test("the amount a seller reads is exact, not rounded through a float", async () => {
  // `Number(amount) / 10 ** decimals` is fine for 6-decimal USDC and silently wrong above
  // 2^53. This is the line a seller reads to decide whether the job is worth doing.
  const amount = 123456789012345678901n;                       // 18 decimals, > 2^53
  const out = await sellerPreflight({
    publicClient: stub({ amount, decimals: 18 }) as never,
    escrow: ESCROW, dealId: DEAL,
  } as never);
  assert.ok(out.report.includes("123.456789012345678901"), `exact value missing:\n${out.report}`);
  assert.ok(!out.report.includes("123.45678901234568"), "a float-rounded amount must not appear");
});

test("a whole amount does not grow a trailing dot", async () => {
  const out = await sellerPreflight({
    publicClient: stub({ amount: 5_000000n, decimals: 6 }) as never, escrow: ESCROW, dealId: DEAL,
  } as never);
  assert.ok(out.report.includes("(5 USDC)"), out.report);
});

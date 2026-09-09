import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { evmDealBinding, type EvmDealTerms } from "../dist/binding.js";

/**
 * **The test that decides whether this package's binding may be used at all.**
 *
 * `expectedBinding` is not this repository's Rust opinion: the emitter asserts that the Rust
 * host agrees with the value the GUEST committed inside SP1 for the shipped Groth16 fixture,
 * and refuses to write a vector otherwise. So a pass here means the TypeScript agrees with
 * the thing that actually decides payments.
 *
 * If this fails, `docs/partner-kit.md` says to use the Rust path instead. An unverified
 * re-implementation of the value that decides who gets paid is worse than none.
 */
const golden = JSON.parse(readFileSync(new URL("./vectors/evm-binding.json", import.meta.url), "utf8"));

test("the vector file is what it claims to be", () => {
  assert.equal(golden.scheme, "reckn/zk/bind/evm/v2");
  assert.ok(Array.isArray(golden.vectors) && golden.vectors.length > 0);
  for (const v of golden.vectors) {
    assert.match(v.expectedBinding, /^0x[0-9a-f]{64}$/);
    assert.match(String(v.groundTruth), /guest/i, "a vector must say where its expected value came from");
  }
});

test("TypeScript reproduces the binding the guest committed", () => {
  for (const v of golden.vectors) {
    const t = v.terms;
    const terms: EvmDealTerms = {
      stateRoot: t.stateRoot,
      env: {
        chainId: BigInt(t.env.chainId), specId: t.env.specId,
        blockNumber: BigInt(t.env.blockNumber), timestamp: BigInt(t.env.timestamp),
        baseFee: BigInt(t.env.baseFee), blockGasLimit: BigInt(t.env.blockGasLimit),
        coinbase: t.env.coinbase, prevrandao: t.env.prevrandao,
      },
      check: { address: t.check.address, slot: t.check.slot, min: t.check.min, max: t.check.max },
      plan: {
        caller: t.plan.caller, target: t.plan.target, value: t.plan.value,
        gasLimit: BigInt(t.plan.gasLimit), calldata: t.plan.calldata,
      },
    };
    assert.equal(evmDealBinding(terms), v.expectedBinding, `vector "${v.name}"`);
  }
});

test("a vector with one field altered no longer matches", () => {
  // Guards the guard: a comparison that passes for the wrong reason would pass here too.
  const v = golden.vectors[0];
  const t = structuredClone(v.terms);
  t.env.timestamp = String(BigInt(t.env.timestamp) + 1n);
  const terms = {
    stateRoot: t.stateRoot,
    env: { chainId: BigInt(t.env.chainId), specId: t.env.specId, blockNumber: BigInt(t.env.blockNumber),
      timestamp: BigInt(t.env.timestamp), baseFee: BigInt(t.env.baseFee),
      blockGasLimit: BigInt(t.env.blockGasLimit), coinbase: t.env.coinbase, prevrandao: t.env.prevrandao },
    check: t.check,
    plan: { ...t.plan, gasLimit: BigInt(t.plan.gasLimit) },
  } as EvmDealTerms;
  assert.notEqual(evmDealBinding(terms), v.expectedBinding);
});

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { validateProfile, assertValidProfile } from "../src/profile.ts";

const load = (f: string) => JSON.parse(readFileSync(new URL(`../profiles/${f}`, import.meta.url), "utf8"));

test("every shipped profile validates", () => {
  const files = readdirSync(new URL("../profiles", import.meta.url)).filter((f) => f.endsWith(".json"));
  assert.ok(files.length >= 3, "expected the three shipped profiles");
  for (const f of files) {
    const { warnings } = assertValidProfile(load(f));
    // Warnings are allowed; an unexplained one is not. Each shipped profile carries
    // measuredOn and howMeasured, so there should be nothing to warn about.
    assert.deepEqual(warnings, [], `${f} produced warnings: ${JSON.stringify(warnings)}`);
  }
});

test("a profile whose vm and binding scheme disagree is rejected", () => {
  // This is the mistake that would actually happen: copy the Arc EVM profile, point it at
  // Tempo, forget that Tempo's verifier judges the SVM guest. The deal would fund and could
  // never settle.
  const p = { ...load("arc-testnet-evm.json"), vm: "svm" };
  const f = validateProfile(p);
  assert.ok(
    f.some((x) => x.severity === "error" && x.field === "dealBindingScheme"),
    "an SVM profile carrying an EVM binding scheme must be an error",
  );
});

test("the empty-account codehash is rejected", () => {
  const p = { ...load("arc-testnet-evm.json"),
    verifierCodeHash: "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470" };
  const f = validateProfile(p);
  assert.ok(f.some((x) => x.field === "verifierCodeHash" && x.severity === "error"),
    "fund() rejects this codehash with NoVerifierCode(), so a profile naming it is broken");
});

test("malformed addresses and hashes are rejected, one finding each", () => {
  const p = { ...load("arc-testnet-evm.json"), escrow: "0x1234", verifierCodeHash: "not-hex" };
  const f = validateProfile(p);
  assert.ok(f.some((x) => x.field === "escrow" && x.severity === "error"));
  assert.ok(f.some((x) => x.field === "verifierCodeHash" && x.severity === "error"));
});

test("an empty knownLimits list is an error, not an omission", () => {
  const p = { ...load("arc-testnet-evm.json"), knownLimits: [] };
  const f = validateProfile(p);
  assert.ok(f.some((x) => x.field === "knownLimits" && x.severity === "error"),
    "every deployment has limits; an empty list means nobody wrote them down");
});

test("claiming mainnet warns, because nothing is on mainnet", () => {
  const p = { ...load("arc-testnet-evm.json"), status: "mainnet" };
  assert.ok(validateProfile(p).some((x) => x.field === "status" && x.severity === "warning"));
});

test("validateProfile reports every problem at once, not the first", () => {
  const f = validateProfile({});
  assert.ok(f.length >= 5, `expected many findings from an empty object, got ${f.length}`);
});

test("the Tempo profile states that no EVM verifier exists there", () => {
  // Measured on chain 2026-09-09: Tempo's verifier is bound to the SVM guest. A partner who
  // assumes otherwise funds a deal that can never settle, so the profile must say so.
  const p = load("tempo-moderato-svm.json");
  assert.equal(p.vm, "svm");
  assert.ok(
    p.knownLimits.some((l: string) => /NO EVM-GUEST VERIFIER/i.test(l)),
    "the Tempo profile must state that an EVM deal binding cannot settle there",
  );
});

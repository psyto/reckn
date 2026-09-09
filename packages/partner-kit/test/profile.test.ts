import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { existsSync, readFileSync as rf } from "node:fs";
import { validateProfile, assertValidProfile, validateProfileEvidence } from "../dist/profile.js";

/** Repo-relative paths, resolved from this test file. Injected so the module needs no fs. */
const repoRoot = new URL("../../../", import.meta.url);
const resolve = (rel: string): unknown => {
  const u = new URL(rel, repoRoot);
  if (!existsSync(u)) return undefined;
  if (!rel.endsWith(".json")) return "exists";
  try { return JSON.parse(rf(u, "utf8")); } catch { return "exists"; }
};

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

test("every shipped profile's evidence actually exists", () => {
  // Until this test, a profile could cite a gate or a test vector that was never there and
  // still validate green. A claim with a footnote to nowhere is the shape this repository
  // treats as worse than no claim.
  for (const f of readdirSync(new URL("../profiles", import.meta.url)).filter((x) => x.endsWith(".json"))) {
    const findings = validateProfileEvidence(load(f), resolve);
    const errs = findings.filter((x) => x.severity === "error");
    assert.deepEqual(errs, [], `${f}: ${JSON.stringify(errs)}`);
  }
});

test("evidence pointing at a file that does not exist is an error", () => {
  const p = load("arc-testnet-evm.json");
  p.evidence.testVectors = ["packages/partner-kit/test/vectors/does-not-exist.json"];
  const f = validateProfileEvidence(p, resolve);
  assert.ok(f.some((x) => x.severity === "error" && /does not exist/.test(x.message)));
});

test("a test vector for the wrong binding scheme is an error", () => {
  // An SVM profile citing the EVM vector proves nothing about itself.
  const p = load("tempo-moderato-svm.json");
  p.evidence.testVectors = ["packages/partner-kit/test/vectors/evm-binding.json"];
  const f = validateProfileEvidence(p, resolve);
  assert.ok(
    f.some((x) => x.severity === "error" && /scheme/.test(x.message)),
    "a vector for reckn/zk/bind/evm/v2 must not count as evidence for an svm profile",
  );
});

test("a missing gate script is an error", () => {
  const p = load("arc-testnet-evm.json");
  p.evidence.gates = ["zk-verdict/scripts/ac999.sh"];
  const f = validateProfileEvidence(p, resolve);
  assert.ok(f.some((x) => x.field === "evidence.gates" && x.severity === "error"));
});

test("a profile with no evidence at all warns rather than passing silently", () => {
  const p = load("arc-testnet-evm.json");
  delete p.evidence;
  const f = validateProfileEvidence(p, resolve);
  assert.ok(f.some((x) => x.field === "evidence" && x.severity === "warning"));
});

test("evidence that is entirely unreachable is reported as not-here, not as an invalid profile", () => {
  // Measured 2026-09-09 by installing the packed tarball into a clean consumer: `reckn
  // profiles` printed INVALID for all three shipped profiles, with four "does not exist"
  // errors each. The profiles were fine. The gates and records are repository paths and are
  // not shipped — correctly — so every one of them missed. Calling a valid thing invalid is
  // worse than saying nothing, and it is the first thing an adopter would have seen.
  const p = load("arc-testnet-evm.json");
  const nothingResolves = () => undefined;
  const f = validateProfileEvidence(p, nothingResolves);
  assert.deepEqual(f.filter((x) => x.severity === "error"), [], "must not be an error");
  assert.ok(f.some((x) => x.severity === "warning" && /this is not the repository/.test(x.message)));
});

test("but ONE missing path among present ones is still an error, and one path alone fails closed", () => {
  // The distinction is a property — all-absent versus some-absent — not a question about
  // where the code is installed. A profile citing a single path cannot tell the two apart, so
  // it keeps the stricter reading.
  const p = load("arc-testnet-evm.json");
  p.evidence.testVectors = ["packages/partner-kit/test/vectors/does-not-exist.json"];
  assert.ok(validateProfileEvidence(p, resolve).some((x) => x.severity === "error"));

  const single = load("arc-testnet-evm.json");
  single.evidence = { record: "nowhere/at/all.json" };
  assert.ok(validateProfileEvidence(single, () => undefined).some((x) => x.severity === "error"),
    "a lone absent citation must not be excused as 'not the repository'");
});

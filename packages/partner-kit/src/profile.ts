/**
 * Verifier Profiles — **discovery and description, never authority.**
 *
 * A profile helps you find a deployment and understand what it can adjudicate. It is a JSON
 * file. Anyone can write one, including someone who wants your money to go somewhere else.
 *
 * **Nothing in a profile authorises a payment.** The escrow settles on the `verifierCodeHash`
 * the FUNDER pinned on chain at `fund()` time, re-checked at settlement — never on what a
 * file claimed. If a profile and the chain disagree, the chain is right and the profile is
 * either stale or lying, and `verifyProfileAgainstChain` is how you find out which.
 *
 * The split below is deliberate:
 *   - `validateProfile`  — is this file well-formed and internally consistent? Offline.
 *   - `verifyProfileAgainstChain` — does the deployment it describes actually exist and match?
 *
 * A green `validateProfile` means the file is not obviously broken. It means nothing about
 * whether the addresses in it are real, which is exactly the mistake this comment exists to
 * prevent.
 */

export type Vm = "evm" | "svm";

export interface VerifierProfile {
  id: string;
  version: string;
  status: "testnet" | "mainnet";
  chain: { name: string; chainId: number; rpc: string; explorer?: string };
  /** 20-byte hex — `RecknZkEscrow`. */
  escrow: string;
  /** 20-byte hex — the adjudicating program a deal may name. */
  verifier: string;
  /** 32-byte hex — what `fund()` pins and `settleWithProof` re-checks. */
  verifierCodeHash: string;
  /** 32-byte hex — the ONE guest this verifier can judge. Immutable on chain. */
  verdictProgramVKey: string;
  vm: Vm;
  /**
   * revm's `SpecId` discriminant — the hardfork the guest executes under. **Committed into
   * the deal binding**, so a wrong value yields a valid-looking binding that no proof from
   * this guest can ever match, with nothing erroring at funding time. It lives in the profile
   * precisely so a partner is never asked to pick it. `null` for guests where it does not apply.
   */
  specId?: number | null | undefined;
  specIdNote?: string | undefined;
  predicate: { kind: string; description: string; floorOfZeroIsSatisfiedByDoingNothing?: boolean };
  /** The domain tag of the binding preimage, e.g. `reckn/zk/bind/evm/v2`. */
  dealBindingScheme: string;
  settlementTokenExample?: { symbol: string; address: string; decimals: number; note?: string };
  proving?: Record<string, unknown>;
  settlementCostMeasured?: Record<string, unknown>;
  /** Stated limits. A profile with an empty list is a profile that has not been read. */
  knownLimits: string[];
  evidence?: Record<string, unknown>;
  measuredOn?: string;
  howMeasured?: string;
}

export interface Finding { severity: "error" | "warning"; field: string; message: string }

const HEX20 = /^0x[0-9a-fA-F]{40}$/;
const HEX32 = /^0x[0-9a-fA-F]{64}$/;

/**
 * Check a profile's shape and internal consistency. **Offline: touches no chain.**
 *
 * Returns findings rather than throwing, because a partner should be able to see *all* of
 * what is wrong with a profile at once rather than one field per run.
 */
export function validateProfile(input: unknown): Finding[] {
  const f: Finding[] = [];
  const err = (field: string, message: string) => f.push({ severity: "error", field, message });
  const warn = (field: string, message: string) => f.push({ severity: "warning", field, message });

  if (typeof input !== "object" || input === null) {
    return [{ severity: "error", field: "<root>", message: "not an object" }];
  }
  const p = input as Partial<VerifierProfile> & Record<string, unknown>;

  for (const k of ["id", "version", "status", "vm", "dealBindingScheme"] as const) {
    if (typeof p[k] !== "string" || (p[k] as string).length === 0) err(k, "required, must be a non-empty string");
  }
  if (p.status !== undefined && p.status !== "testnet" && p.status !== "mainnet") {
    err("status", `must be "testnet" or "mainnet", got ${JSON.stringify(p.status)}`);
  }
  if (p.vm !== undefined && p.vm !== "evm" && p.vm !== "svm") {
    err("vm", `must be "evm" or "svm", got ${JSON.stringify(p.vm)}`);
  }

  const chain = p.chain as VerifierProfile["chain"] | undefined;
  if (!chain || typeof chain !== "object") err("chain", "required");
  else {
    if (!Number.isInteger(chain.chainId) || chain.chainId <= 0) err("chain.chainId", "must be a positive integer");
    if (typeof chain.rpc !== "string" || !/^https?:\/\//.test(chain.rpc)) err("chain.rpc", "must be an http(s) URL");
    if (typeof chain.name !== "string" || !chain.name) err("chain.name", "required");
  }

  for (const k of ["escrow", "verifier"] as const) {
    const v = p[k];
    if (typeof v !== "string" || !HEX20.test(v)) err(k, "must be a 20-byte 0x-prefixed hex address");
  }
  for (const k of ["verifierCodeHash", "verdictProgramVKey"] as const) {
    const v = p[k];
    if (typeof v !== "string" || !HEX32.test(v)) err(k, "must be a 32-byte 0x-prefixed hex value");
  }
  // An empty codehash is the escrow's own sentinel for "not a program", and a profile that
  // names it is describing something that `fund()` would reject outright.
  const EMPTY_CODEHASH = "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";
  if (typeof p.verifierCodeHash === "string" &&
      (p.verifierCodeHash.toLowerCase() === EMPTY_CODEHASH ||
       /^0x0{64}$/.test(p.verifierCodeHash))) {
    err("verifierCodeHash", "is the empty-account codehash: fund() rejects this with NoVerifierCode()");
  }

  // Capability consistency: one verifier adjudicates one guest, and the binding scheme names
  // which VM's preimage that guest commits. A profile claiming an EVM binding on an SVM
  // verifier describes a deal that can never settle.
  if (typeof p.vm === "string" && typeof p.dealBindingScheme === "string") {
    const want = `reckn/zk/bind/${p.vm}/`;
    if (!p.dealBindingScheme.startsWith(want)) {
      err("dealBindingScheme",
        `vm is "${p.vm}" so the scheme must start with "${want}", got "${p.dealBindingScheme}"`);
    }
  }

  if (!Array.isArray(p.knownLimits)) err("knownLimits", "required (an array, and not an empty one)");
  else if (p.knownLimits.length === 0) {
    err("knownLimits", "is empty. Every deployment has limits; an empty list means they were not written down, not that there are none");
  }

  const pred = p.predicate as VerifierProfile["predicate"] | undefined;
  if (!pred || typeof pred.description !== "string" || !pred.description) {
    err("predicate.description", "required — a seller has to be able to read what decides their payment");
  }
  if (pred && pred.floorOfZeroIsSatisfiedByDoingNothing === false) {
    warn("predicate.floorOfZeroIsSatisfiedByDoingNothing",
      "a floor of zero IS satisfied by doing nothing on every predicate shipped so far; claiming otherwise needs evidence");
  }

  if (p.vm === "evm" && typeof p.specId !== "number") {
    err("specId", "an EVM profile must pin the hardfork the guest executes under; it is committed into every binding");
  }
  if (p.status === "mainnet") {
    warn("status", "no Reckn deployment is on mainnet. If this profile is real, the claim in the README is out of date; if it is not, this field is wrong");
  }
  if (typeof p.measuredOn !== "string") warn("measuredOn", "no measurement date: a reader cannot tell how stale this is");
  if (typeof p.howMeasured !== "string") warn("howMeasured", "not stated. A value that does not say how it was obtained is a value nobody can check");

  return f;
}

/** Convenience: throws on any `error`-severity finding. Warnings are returned, not thrown. */
export function assertValidProfile(input: unknown): { profile: VerifierProfile; warnings: Finding[] } {
  const findings = validateProfile(input);
  const errors = findings.filter((x) => x.severity === "error");
  if (errors.length > 0) {
    throw new Error(
      `invalid verifier profile:\n` + errors.map((e) => `  ${e.field}: ${e.message}`).join("\n"),
    );
  }
  return { profile: input as VerifierProfile, warnings: findings };
}

/**
 * Check that a profile's `evidence` points at things that exist and agree with it.
 *
 * A profile lists gates, records and test vectors as its evidence. Until this existed,
 * **nothing checked that any of them were real** — a profile could cite
 * `test/vectors/does-not-exist.json` and validate green, which is a claim with a footnote to
 * nowhere. That is the shape this repository treats as worse than no claim at all, and it
 * was sitting inside the validator whose job is to catch it.
 *
 * `resolve` is injected so this module needs no filesystem and stays usable in a browser:
 * pass something that returns the parsed JSON for a repo-relative path, `undefined` if the
 * path does not exist, and the string `"exists"` for a non-JSON file that is merely present.
 */
export function validateProfileEvidence(
  profile: VerifierProfile,
  resolve: (repoRelativePath: string) => unknown,
): Finding[] {
  const f: Finding[] = [];
  const err = (field: string, message: string) => f.push({ severity: "error", field, message });
  const warn = (field: string, message: string) => f.push({ severity: "warning", field, message });

  const ev = profile.evidence as
    | { record?: string; gates?: string[]; testVectors?: string[]; spec?: string }
    | undefined;
  if (!ev) { warn("evidence", "no evidence listed: nothing here can be followed up"); return f; }

  for (const [field, path] of [["evidence.record", ev.record], ["evidence.spec", ev.spec]] as const) {
    if (path === undefined) continue;
    if (resolve(path) === undefined) err(field, `points at ${path}, which does not exist`);
  }
  for (const g of ev.gates ?? []) {
    if (resolve(g) === undefined) err("evidence.gates", `points at ${g}, which does not exist`);
  }

  for (const v of ev.testVectors ?? []) {
    const doc = resolve(v);
    if (doc === undefined) { err("evidence.testVectors", `points at ${v}, which does not exist`); continue; }
    if (typeof doc !== "object" || doc === null) {
      err("evidence.testVectors", `${v} is not a JSON object`); continue;
    }
    const d = doc as { scheme?: unknown; vectors?: unknown };
    // The vector must be for THIS profile's binding scheme. A profile citing an SVM vector
    // as evidence for an EVM deployment is citing something that proves nothing about it.
    if (typeof d.scheme !== "string") {
      err("evidence.testVectors", `${v} declares no scheme, so nothing ties it to this profile`);
    } else if (d.scheme !== profile.dealBindingScheme) {
      err("evidence.testVectors",
        `${v} is for scheme "${d.scheme}" but this profile uses "${profile.dealBindingScheme}"`);
    }
    if (!Array.isArray(d.vectors) || d.vectors.length === 0) {
      err("evidence.testVectors", `${v} contains no vectors`);
    }
  }
  return f;
}

export interface ChainCheck { ok: boolean; findings: Finding[] }

/**
 * The half that matters. Reads the chain and compares it to the file.
 *
 * `read` is injected so this module needs no chain client of its own — pass a viem
 * `publicClient.request`-shaped function, or anything that speaks JSON-RPC.
 */
export async function verifyProfileAgainstChain(
  profile: VerifierProfile,
  rpc: (method: string, params: unknown[]) => Promise<unknown>,
  keccak256: (bytes: Uint8Array) => string,
): Promise<ChainCheck> {
  const findings: Finding[] = [];
  const err = (field: string, message: string) => findings.push({ severity: "error", field, message });

  const chainId = (await rpc("eth_chainId", [])) as string;
  if (parseInt(chainId, 16) !== profile.chain.chainId) {
    err("chain.chainId", `the endpoint answers chain ${parseInt(chainId, 16)}, not ${profile.chain.chainId}`);
  }

  const codeOf = async (addr: string) => (await rpc("eth_getCode", [addr, "latest"])) as string;

  const escrowCode = await codeOf(profile.escrow);
  if (!escrowCode || escrowCode === "0x") err("escrow", "no code at this address on this chain");

  const verifierCode = await codeOf(profile.verifier);
  if (!verifierCode || verifierCode === "0x") {
    err("verifier", "no code at this address on this chain");
  } else {
    const bytes = new Uint8Array((verifierCode.length - 2) / 2);
    for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(verifierCode.slice(2 + i * 2, 4 + i * 2), 16);
    const actual = keccak256(bytes).toLowerCase();
    if (actual !== profile.verifierCodeHash.toLowerCase()) {
      err("verifierCodeHash",
        `the chain says ${actual}, the profile says ${profile.verifierCodeHash}. ` +
        `The chain is right. Do not fund against this profile.`);
    }
  }

  // `verdictProgramVKey()` — the guest this verifier is permanently bound to.
  // The selector is `cast sig 'verdictProgramVKey()'` = 0x4f074a62, and it is written here
  // rather than derived because this module carries no ABI encoder. The first draft of this
  // line held a different four bytes that looked exactly as plausible and returned nothing —
  // which is the failure mode this whole file is about, committed inside the file itself.
  const VKEY_SELECTOR = "0x4f074a62";
  const vkey = (await rpc("eth_call", [{ to: profile.verifier, data: VKEY_SELECTOR }, "latest"])) as string;
  if (typeof vkey === "string" && HEX32.test(vkey) &&
      vkey.toLowerCase() !== profile.verdictProgramVKey.toLowerCase()) {
    err("verdictProgramVKey",
      `the verifier judges guest ${vkey}, the profile claims ${profile.verdictProgramVKey}. ` +
      `A proof from the guest this profile names would revert.`);
  }

  return { ok: findings.length === 0, findings };
}

#!/usr/bin/env node
/**
 * `reckn` — read a deal before you work on it, and verify a settlement afterwards.
 *
 * **Both subcommands are read-only.** This CLI never sends a transaction, never asks for a
 * key, and has no flag that would take one. Funding and settling are done from your own code
 * with your own wallet; see `docs/partner-kit.md`.
 */
import { readFileSync, readdirSync } from "node:fs";
import { createPublicClient, http } from "viem";
import { writeFileSync } from "node:fs";
import { sellerPreflight, verifySettlement, buildTerms } from "./index.js";
import { existsSync, readFileSync as readFileRaw } from "node:fs";
import { assertValidProfile, validateProfile, validateProfileEvidence, type VerifierProfile } from "./profile.js";

const USAGE = `reckn — read-only checks on a Reckn deal

  reckn preflight --rpc <url> --escrow <0x..> --deal <0x..> [--profile <id|file>]
      What am I about to work on? Prints buyer, seller, token, amount, the verifier and
      whether its code still hashes to what the deal pinned, the predicate, the deadline,
      and the known limits. Read it before you start.

  reckn verify --rpc <url> --escrow <0x..> --deal <0x..> [--tx <0x..>]
      Did it settle, and where did the money go? Decoded from the chain, not from anyone's
      report of it.

  reckn terms --rpc <url> --profile <id> --from <0x..> --to <0x..> --data <0x..>
              --check-token <0x..> --check-holder <0x..> --min <n>
              [--value <n>] [--gas <n>] [--block <n>] [--out terms.json]
      Turn YOUR transaction into deal terms. Reads a block, SIMULATES the call at it, and
      REFUSES to emit terms for a call that reverts there — a plan that fails at the anchor
      settles as Failed, and you would pay to be told your work did not reproduce. Captures
      the prestate witness in the same run, because public endpoints do not serve historical
      eth_getProof later. The hardfork comes from the profile; you are not asked for it.

  reckn profiles
      List the shipped verifier profiles and validate them.

Shipped profiles: ${readdirSync(new URL("../profiles", import.meta.url))
  .filter((f) => f.endsWith(".json")).map((f) => f.replace(/\.json$/, "")).join(", ")}

Neither subcommand sends a transaction or accepts a private key.`;

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

function need(name: string): string {
  const v = arg(name);
  if (!v) { console.error(`missing --${name}\n\n${USAGE}`); process.exit(2); }
  return v;
}

function loadProfile(idOrPath: string): VerifierProfile {
  const asShipped = new URL(`../profiles/${idOrPath}.json`, import.meta.url);
  let raw: string;
  try { raw = readFileSync(asShipped, "utf8"); }
  catch { raw = readFileSync(idOrPath, "utf8"); }
  const { profile, warnings } = assertValidProfile(JSON.parse(raw));
  for (const w of warnings) console.error(`profile warning — ${w.field}: ${w.message}`);
  return profile;
}

const main = async () => {
  const cmd = process.argv[2];

  if (cmd === "profiles") {
    const dir = new URL("../profiles", import.meta.url);
    let bad = 0;
    for (const f of readdirSync(dir).filter((x) => x.endsWith(".json"))) {
      const p = JSON.parse(readFileSync(new URL(f, `${dir}/`), "utf8"));
      // Repo-relative, from packages/partner-kit/dist/ up to the repository root.
      const repoRoot = new URL("../../../", import.meta.url);
      const resolveEvidence = (rel: string): unknown => {
        const u = new URL(rel, repoRoot);
        if (!existsSync(u)) return undefined;
        if (!rel.endsWith(".json")) return "exists";
        try { return JSON.parse(readFileRaw(u, "utf8")); } catch { return "exists"; }
      };
      const findings = [
        ...validateProfile(p),
        ...(p.dealBindingScheme ? validateProfileEvidence(p as VerifierProfile, resolveEvidence) : []),
      ];
      const errs = findings.filter((x) => x.severity === "error");
      console.log(`${errs.length ? "INVALID" : "ok     "} ${p.id ?? f}  ${p.chain?.name ?? "?"} (${p.chain?.chainId ?? "?"})  vm=${p.vm}`);
      console.log(`        escrow ${p.escrow}  verifier ${p.verifier}`);
      for (const x of findings) { console.log(`        ${x.severity}: ${x.field}: ${x.message}`); }
      if (errs.length) bad++;
    }
    console.log("\nA profile describes a deployment. It does not authorise anything: the escrow");
    console.log("settles on the codehash the funder pinned on chain, never on a file.");
    process.exit(bad ? 1 : 0);
  }

  if (cmd === "terms") {
    const url = need("rpc");
    const profile = loadProfile(need("profile"));
    const rpc = async (method: string, params: unknown[]) => {
      const r = await fetch(url, { method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }) });
      const j = await r.json() as { result?: unknown; error?: { message?: string } };
      if (j.error) throw new Error(j.error.message ?? "rpc error");
      return j.result;
    };
    const b = await buildTerms({
      profile, rpc,
      caller: need("from"), target: need("to"), calldata: need("data"),
      ...(arg("value") ? { value: BigInt(arg("value")!) } : {}),
      ...(arg("gas") ? { gasLimit: BigInt(arg("gas")!) } : {}),
      ...(arg("block") ? { blockNumber: BigInt(arg("block")!) } : {}),
      check: {
        token: need("check-token"), holder: need("check-holder"),
        balancesSlotIndex: Number(arg("slot-index") ?? 9),
        min: BigInt(need("min")),
      },
    });
    console.log(`anchor        block ${BigInt(b.anchor.blockNumber)}  stateRoot ${b.anchor.stateRoot}`);
    console.log(`simulation    ok — ${BigInt(b.simulation.gasUsed)} gas, ${b.simulation.touchedAccounts} accounts, ${b.simulation.touchedSlots} slots`);
    console.log(`predicate     ${b.terms.check.address} slot ${b.terms.check.slot}`);
    console.log(`              must rise by at least ${BigInt(b.terms.check.min)}`);
    console.log(`dealBinding   ${b.dealBinding}`);
    console.log(`\nThis is what you fund against. It commits the prestate, the plan and the`);
    console.log(`condition, so neither side can move them afterwards.`);
    console.log(`\nThe call was simulated and does not revert. That is NOT a promise it clears`);
    console.log(`the floor — only that it runs. Proving it still needs the SP1 toolchain and`);
    console.log(`minutes of CPU; the witness is in the bundle so that can happen later.`);
    const out = arg("out");
    if (out) { writeFileSync(out, JSON.stringify(b, (_k, v) => typeof v === "bigint" ? v.toString() : v, 2)); console.log(`\nwritten: ${out}`); }
    process.exit(0);
  }

  if (cmd === "preflight" || cmd === "verify") {
    const client = createPublicClient({ transport: http(need("rpc")) });
    const escrow = need("escrow") as `0x${string}`;
    const dealId = need("deal") as `0x${string}`;

    if (cmd === "preflight") {
      const pid = arg("profile");
      const out = await sellerPreflight({
        publicClient: client, escrow, dealId,
        ...(pid ? { profile: loadProfile(pid) } : {}),
      });
      console.log(out.report);
      // A mismatched verifier means this deal can never settle. Exit non-zero so a script
      // that pipes this cannot mistake "printed something" for "safe to start".
      if (!out.exists || !out.verifierCodeHashMatches) process.exit(1);
      process.exit(0);
    }

    const tx = arg("tx");
    const out = await verifySettlement({ publicClient: client, escrow, dealId, ...(tx ? { tx: tx as `0x${string}` } : {}) });
    console.log(out.report);
    process.exit(out.settled ? 0 : 1);
  }

  console.log(USAGE);
  process.exit(cmd ? 2 : 0);
};

main().catch((e) => { console.error(String(e?.message ?? e)); process.exit(1); });

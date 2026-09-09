/**
 * The whole shape, in one command, on a throwaway local chain.
 *
 * buyer agent -> seller service -> committed deterministic step -> proof -> release or refund
 * -> third-party verification.
 *
 * Three deals are opened, because two of them are the parts people do not believe:
 *
 *   1. RELEASE   the proof reproduces, the seller is paid
 *   2. REFUND    the proof says the work did NOT reproduce, the buyer gets the money back
 *   3. REFUSAL   a REAL proof of a different job is submitted against deal 1's shape and the
 *                escrow will not move the money
 *
 * Deal 3 is the one worth watching. Nothing about it is a trick: the proof verifies.
 */
import { readFileSync } from "node:fs";
import { createPublicClient, createWalletClient, http, type Hex, keccak256, toBytes } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  createDeal, sellerPreflight, submitProof, verifySettlement, evmDealBinding,
  type VerifierProfile,
} from "@reckn/partner-kit";
import { sampleTerms, sampleWorkloadSummary } from "./terms.ts";

const here = (p: string) => new URL(p, import.meta.url);
const chainCfg = JSON.parse(readFileSync(here("../.local-chain.json"), "utf8"));
const fx = (n: string) =>
  JSON.parse(readFileSync(here(`../../../../../zk-verdict/contracts/src/fixtures/${n}.json`), "utf8"));

const REPRODUCED = fx("reexec-groth16-fixture");
const FAILED = fx("reexec-falserelease-fixture");

const line = (s = "") => console.log(s);
const head = (n: number, s: string) => { line(); line(`── ${n}. ${s} ${"─".repeat(Math.max(0, 62 - s.length))}`); };

const account = privateKeyToAccount(chainCfg.devKey as Hex);
const publicClient = createPublicClient({ transport: http(chainCfg.rpc) });
const walletClient = createWalletClient({ account, transport: http(chainCfg.rpc) });

/** Built at runtime from the local deployment. On a public chain you load a shipped profile. */
const profile: VerifierProfile = {
  id: "local-anvil-evm", version: "0.0.0-local", status: "testnet",
  chain: { name: "local anvil at Arc's chain id", chainId: chainCfg.chainId, rpc: chainCfg.rpc },
  escrow: chainCfg.escrow, verifier: chainCfg.verifier,
  verifierCodeHash: chainCfg.verifierCodeHash,
  verdictProgramVKey: REPRODUCED.vkey,
  vm: "evm",
  predicate: { kind: "poststate-delta", description: sampleWorkloadSummary, floorOfZeroIsSatisfiedByDoingNothing: true },
  dealBindingScheme: "reckn/zk/bind/evm/v2",
  knownLimits: [
    "This is a local chain. Nothing here is evidence about any public network.",
    "The proofs are the repository's shipped fixtures, not proofs of your job.",
    "The buyer names the verifier; a seller must read it before working.",
  ],
  measuredOn: new Date().toISOString().slice(0, 10),
  howMeasured: "read from the local deployment by setup-chain.sh",
};

const AMOUNT = 250_000000n; // 250.00 at 6 decimals
const dealIdFor = (label: string) => keccak256(toBytes(`starter/${label}/${Date.now()}`));

async function balance(who: Hex): Promise<bigint> {
  return publicClient.readContract({
    address: chainCfg.token, abi: [{ type: "function", name: "balanceOf", stateMutability: "view",
      inputs: [{ name: "a", type: "address" }], outputs: [{ type: "uint256" }] }] as const,
    functionName: "balanceOf", args: [who],
  });
}

const SELLER = "0x0000000000000000000000000000000000005e11" as Hex;

/**
 * `createDeal` approves for you. The two paths below call `fund` directly — because they
 * deliberately fund against a binding this package did NOT compute — so they have to approve
 * themselves. The first run of this demo forgot, and the escrow reverted with
 * InsufficientAllowance, which is the token refusing rather than the escrow: a deal is never
 * half-opened.
 */
async function approve(amount: bigint) {
  const hash = await walletClient.writeContract({
    address: chainCfg.token,
    abi: [{ type: "function", name: "approve", stateMutability: "nonpayable",
      inputs: [{ name: "s", type: "address" }, { name: "v", type: "uint256" }],
      outputs: [{ type: "bool" }] }] as const,
    functionName: "approve", args: [chainCfg.escrow, amount], account, chain: null,
  });
  await publicClient.waitForTransactionReceipt({ hash });
}

async function run() {
  head(1, "the buyer computes the binding BEFORE the seller works");
  const terms = sampleTerms();
  const computed = evmDealBinding(terms);
  line(`   computed by this package : ${computed}`);
  line(`   carried by the proof     : ${REPRODUCED.deal_binding}`);
  if (computed.toLowerCase() !== String(REPRODUCED.deal_binding).toLowerCase()) {
    throw new Error("the binding this package computes is not the one the proof carries — stop here");
  }
  line(`   they match. This is the ordering that makes the escrow sound: the terms were fixed`);
  line(`   before any proof existed, so a proof of some other, more favourable job cannot settle.`);

  // ─────────────────────────────────────────────────────────────── 1. release ──
  head(2, "RELEASE — the work reproduces, the seller is paid");
  const d1 = dealIdFor("release");
  const r1 = await createDeal({
    profile, publicClient, walletClient, account, dealId: d1,
    seller: SELLER, token: chainCfg.token, amount: AMOUNT, terms,
  });
  line(`   funded  ${r1.fundTx}`);

  const pre = await sellerPreflight({ publicClient, escrow: chainCfg.escrow, dealId: d1, profile });
  line();
  line("   what the seller sees before starting work:");
  line(pre.report.split("\n").map((l) => `     ${l}`).join("\n"));
  if (!pre.verifierCodeHashMatches) throw new Error("preflight says the verifier does not match — a seller would stop here");

  const before1 = await balance(SELLER);
  const s1 = await submitProof({
    publicClient, walletClient, account, escrow: chainCfg.escrow, dealId: d1,
    publicValues: REPRODUCED.public_values, proofBytes: REPRODUCED.proof,
  });
  const v1 = await verifySettlement({ publicClient, escrow: chainCfg.escrow, dealId: d1, tx: s1.tx });
  line();
  line(v1.report.split("\n").map((l) => `   ${l}`).join("\n"));
  const after1 = await balance(SELLER);
  line(`   seller balance ${before1} -> ${after1}`);
  if (after1 - before1 !== AMOUNT) throw new Error("the seller was not paid in full");

  // ──────────────────────────────────────────────────────────────── 2. refund ──
  head(3, "REFUND — the work did NOT reproduce, the buyer gets it back");
  line("   SAMPLE BOUNDARY: this path funds against the shipped FAILURE fixture's binding rather");
  line("   than one this package computed, because its terms are not in the golden vector and a");
  line("   fresh proof takes minutes. The release path above is the one that demonstrates");
  line("   buyer-side binding computation. Said here rather than left for you to notice.");
  const d2 = dealIdFor("refund");
  await approve(AMOUNT);
  const buyerBefore = await balance(account.address);
  const fundTx2 = await walletClient.writeContract({
    address: chainCfg.escrow,
    abi: [{ type: "function", name: "fund", stateMutability: "nonpayable", outputs: [], inputs: [
      { name: "dealId", type: "bytes32" }, { name: "seller", type: "address" }, { name: "token", type: "address" },
      { name: "amount", type: "uint256" }, { name: "verifier", type: "address" },
      { name: "verifierCodeHash", type: "bytes32" }, { name: "dealBinding", type: "bytes32" }]}] as const,
    functionName: "fund",
    args: [d2, SELLER, chainCfg.token, AMOUNT, chainCfg.verifier, chainCfg.verifierCodeHash, FAILED.deal_binding],
    account, chain: null,
  });
  await publicClient.waitForTransactionReceipt({ hash: fundTx2 });
  const s2 = await submitProof({
    publicClient, walletClient, account, escrow: chainCfg.escrow, dealId: d2,
    publicValues: FAILED.public_values, proofBytes: FAILED.proof,
  });
  const v2 = await verifySettlement({ publicClient, escrow: chainCfg.escrow, dealId: d2, tx: s2.tx });
  line(v2.report.split("\n").map((l) => `   ${l}`).join("\n"));
  const buyerAfter = await balance(account.address);
  if (buyerAfter !== buyerBefore) throw new Error("the buyer was not made whole");
  line(`   buyer balance unchanged across fund+refund: ${buyerBefore}`);

  // ─────────────────────────────────────────────────────────────── 3. refusal ──
  head(4, "REFUSAL — a REAL proof of a different job cannot take the money");
  const d3 = dealIdFor("refusal");
  const flipped = ("0x" + (BigInt(REPRODUCED.deal_binding) ^ 1n).toString(16).padStart(64, "0")) as Hex;
  line(`   funding against a binding one bit away from the proof's: ${flipped}`);
  await approve(AMOUNT);
  await publicClient.waitForTransactionReceipt({
    hash: await walletClient.writeContract({
      address: chainCfg.escrow,
      abi: [{ type: "function", name: "fund", stateMutability: "nonpayable", outputs: [], inputs: [
        { name: "dealId", type: "bytes32" }, { name: "seller", type: "address" }, { name: "token", type: "address" },
        { name: "amount", type: "uint256" }, { name: "verifier", type: "address" },
        { name: "verifierCodeHash", type: "bytes32" }, { name: "dealBinding", type: "bytes32" }]}] as const,
      functionName: "fund",
      args: [d3, SELLER, chainCfg.token, AMOUNT, chainCfg.verifier, chainCfg.verifierCodeHash, flipped],
      account, chain: null,
    }),
  });
  const escrowBefore = await balance(chainCfg.escrow);
  let refused = false;
  try {
    await submitProof({ publicClient, walletClient, account, escrow: chainCfg.escrow, dealId: d3,
      publicValues: REPRODUCED.public_values, proofBytes: REPRODUCED.proof });
  } catch (e) {
    refused = true;
    line(`   rejected: ${String((e as Error).message).split("\n")[0].slice(0, 100)}`);
  }
  if (!refused) throw new Error("a proof of another job settled this deal — that is a central-claim failure");
  const v3 = await verifySettlement({ publicClient, escrow: chainCfg.escrow, dealId: d3 });
  line(`   deal state: ${v3.state}`);
  if (await balance(chainCfg.escrow) !== escrowBefore) throw new Error("the escrow balance moved");
  line(`   the escrow still holds ${escrowBefore}. The proof verified. The money did not move.`);

  line();
  line("── all three paths behaved ────────────────────────────────────────────────");
  line("   Local chain only. Nothing here is evidence about a public network.");
  line("   The Arc testnet procedure, with YOUR wallet, is in README.md.");
}

run().catch((e) => { console.error("\nFAILED: " + (e?.message ?? e)); process.exit(1); });

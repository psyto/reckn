/**
 * Opening a deal — the only call in this package that moves money, and the only one that can
 * refuse to.
 *
 * Split from the rest because funding is where every earlier mistake becomes expensive: a
 * profile that does not match the chain, a predicate that cannot decide, a dealId already
 * taken. Each of those is checked HERE as well as wherever it was checked first, because
 * terms can be hand-written or carried from an older version, and a pin on one side of a
 * boundary is not a pin.
 */
import type { Address, Hex, PublicClient, WalletClient, Account } from "viem";
import { keccak256 } from "viem";
import { escrowAbi, erc20Abi, DealState, dealStateName } from "./escrow.js";
import { evmDealBinding, type EvmDealTerms } from "./binding.js";
import { assertValidProfile, verifyProfileAgainstChain, type VerifierProfile } from "./profile.js";
import { reproduces } from "./predicate.js";

export interface CreateDealArgs {
  profile: VerifierProfile;
  publicClient: PublicClient;
  /** Your wallet. This package never takes a private key. */
  walletClient: WalletClient;
  account: Account | Address;
  dealId: Hex;
  seller: Address;
  token: Address;
  amount: bigint;
  /** The terms the binding commits to. The seller must be shown these before working. */
  terms: EvmDealTerms;
  /** Compute and check everything, send nothing. Default false. */
  dryRun?: boolean;
}

export interface CreateDealResult {
  dealId: Hex;
  dealBinding: Hex;
  verifier: Address;
  verifierCodeHash: Hex;
  approveTx?: Hex | undefined;
  fundTx?: Hex | undefined;
  dryRun: boolean;
  /** Show this to the seller. They should not have to read your code to know the terms. */
  humanSummary: string;
}

/**
 * Open a deal.
 *
 * The binding is computed from the terms **before** anything is sent, and the profile is
 * checked against the chain first — because a profile is a JSON file and the chain is not.
 * If the verifier's codehash on chain differs from the profile's, this refuses rather than
 * funding against something whose code nobody has looked at.
 */
export async function createDeal(args: CreateDealArgs): Promise<CreateDealResult> {
  const { profile, publicClient, walletClient, account, dealId, seller, token, amount, terms } = args;
  const dryRun = args.dryRun ?? false;

  assertValidProfile(profile);
  if (profile.vm !== "evm") {
    throw new Error(
      `profile "${profile.id}" adjudicates ${profile.vm}, and these terms are EVM. ` +
      `One verifier is bound to one guest, so a proof from the EVM guest cannot settle there. ` +
      `Use a profile with "vm": "evm".`,
    );
  }

  // `buildTerms` refuses a predicate that decides nothing, but terms can be written by hand,
  // carried from an older version, or produced by someone else's tool. This is where the money
  // actually leaves, so the question is asked again here rather than trusted upstream — a pin
  // on one side of a boundary is not a pin.
  const pMin = BigInt(terms.check.min);
  const pMax = BigInt(terms.check.max);
  if (pMax < pMin) {
    throw new Error(
      `refusing to fund: no execution satisfies this predicate (max ${pMax} < min ${pMin}), so ` +
      `every replay returns Failed and the seller cannot be paid for work they actually did.`,
    );
  }
  if (reproduces(0n, 0n, pMin, pMax)) {
    throw new Error(
      `refusing to fund: this predicate is satisfied by doing nothing (min = ${pMin}), so the ` +
      `seller can take the ${amount} you are about to escrow without performing the work. ` +
      `Set a floor the work must clear.`,
    );
  }

  const chain = await verifyProfileAgainstChain(
    profile,
    (method, params) => publicClient.request({ method, params } as never) as Promise<unknown>,
    (b) => keccak256(b),
  );
  if (!chain.ok) {
    throw new Error(
      `the profile does not match the chain, so funding against it would be funding against ` +
      `something unverified:\n` + chain.findings.map((f) => `  ${f.field}: ${f.message}`).join("\n"),
    );
  }

  const dealBinding = evmDealBinding(terms);
  const escrow = profile.escrow as Address;
  const verifier = profile.verifier as Address;
  const verifierCodeHash = profile.verifierCodeHash as Hex;

  const existing = await publicClient.readContract({
    address: escrow, abi: escrowAbi, functionName: "deals", args: [dealId],
  });
  if (Number(existing[8]) !== DealState.None) {
    throw new Error(`dealId ${dealId} already exists (state ${dealStateName(Number(existing[8]))}). Pick another.`);
  }

  const humanSummary = [
    `deal        ${dealId}`,
    `chain       ${profile.chain.name} (${profile.chain.chainId})`,
    `escrow      ${escrow}`,
    `seller      ${seller}`,
    `token       ${token}`,
    `amount      ${amount}`,
    `verifier    ${verifier}`,
    `  codehash  ${verifierCodeHash}`,
    `  judges    guest ${profile.verdictProgramVKey}`,
    `binding     ${dealBinding}`,
    `predicate   ${profile.predicate.description}`,
    `  target    ${terms.check.address} slot ${terms.check.slot}`,
    `  must rise by at least ${BigInt(terms.check.min)}`,
    `plan        call ${terms.plan.target} from ${terms.plan.caller}`,
    `if no proof arrives, the buyer may reclaim after 30 days (anyone may call it; the caller gets nothing)`,
  ].join("\n");

  if (dryRun) return { dealId, dealBinding, verifier, verifierCodeHash, dryRun: true, humanSummary };

  const acct = typeof account === "string" ? account : account.address;
  const allowance = await publicClient.readContract({
    address: token, abi: erc20Abi, functionName: "allowance", args: [acct, escrow],
  });

  let approveTx: Hex | undefined;
  if (allowance < amount) {
    approveTx = await walletClient.writeContract({
      address: token, abi: erc20Abi, functionName: "approve", args: [escrow, amount],
      account: account as never, chain: null,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveTx });
  }

  const fundTx = await walletClient.writeContract({
    address: escrow, abi: escrowAbi, functionName: "fund",
    args: [dealId, seller, token, amount, verifier, verifierCodeHash, dealBinding],
    account: account as never, chain: null,
  });
  await publicClient.waitForTransactionReceipt({ hash: fundTx });

  return { dealId, dealBinding, verifier, verifierCodeHash, approveTx, fundTx, dryRun: false, humanSummary };
}


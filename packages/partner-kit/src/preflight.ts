/**
 * Seller preflight — *what am I about to work on?*
 *
 * This is a reading aid and **not** on-chain consent. The escrow does not require you to have
 * run it and nothing you do here is recorded, which is exactly why it exists: the buyer names
 * the adjudicator, and a buyer who names a verifier that always fails makes the seller work
 * for nothing, indistinguishably from an honest failure.
 */
import type { Address, Hex, PublicClient } from "viem";
import { keccak256 } from "viem";
import { escrowAbi, erc20Abi, DealState, dealStateName } from "./escrow.js";
import { type VerifierProfile } from "./profile.js";
import { formatUnits } from "./format.js";
import { probeTokenPolicy, type TokenPolicy } from "./token-policy.js";

export interface Preflight {
  exists: boolean;
  state: string;
  buyer: Address; seller: Address; token: Address; amount: bigint;
  tokenSymbol?: string | undefined; tokenDecimals?: number | undefined;
  verifier: Address; verifierCodeHash: Hex;
  verifierCodeHashOnChain: Hex;
  verifierCodeHashMatches: boolean;
  verdictProgramVKeyOnChain?: Hex | undefined;
  /**
   * What the TOKEN says about the people this deal would pay. A valid proof can authorise a
   * payout that the token then refuses, which leaves the deal Funded until the deadline.
   */
  tokenPolicy: TokenPolicy;
  dealBinding: Hex;
  fundedAt: bigint;
  refundOpensAt: bigint;
  profile?: VerifierProfile | undefined;
  warnings: string[];
  /** Printable. A seller should not need an ABI to decide whether to start work. */
  report: string;
}

/**
 * **Read this before you do the work.**
 *
 * A buyer chooses the adjudicating program, per deal. That is a real power and a real hazard:
 * a buyer who names a verifier that always returns `Failed` makes you work for nothing, and on
 * chain that is indistinguishable from an honest failure. Nothing in the contract prevents it.
 *
 * **This check is not on-chain seller consent.** There is no `accept()` and no signature from
 * you anywhere in the settlement path. It is a reading aid, and the escrow does not enforce
 * that you ran it.
 */
export async function sellerPreflight(opts: {
  publicClient: PublicClient;
  escrow: Address;
  dealId: Hex;
  profile?: VerifierProfile;
}): Promise<Preflight> {
  const { publicClient, escrow, dealId, profile } = opts;
  const d = await publicClient.readContract({ address: escrow, abi: escrowAbi, functionName: "deals", args: [dealId] });
  const [buyer, seller, token, amount, verifier, verifierCodeHash, dealBinding, fundedAt, state] = d;
  const warnings: string[] = [];

  const exists = Number(state) !== DealState.None;
  const code = exists
    ? await publicClient.getCode({ address: verifier as Address })
    : undefined;
  const onChainHash = (code && code !== "0x" ? keccak256(code) : "0x" + "0".repeat(64)) as Hex;
  const matches = exists && onChainHash.toLowerCase() === (verifierCodeHash as string).toLowerCase();

  let vkey: Hex | undefined;
  if (exists && code && code !== "0x") {
    try {
      vkey = (await publicClient.call({ to: verifier as Address, data: "0x4f074a62" })).data as Hex;
    } catch { /* a verifier need not expose it; absence is not a fault */ }
  }

  const tokenPolicy = exists
    ? await probeTokenPolicy(publicClient, token as string, seller as string, buyer as string)
    : { probed: [] };

  let tokenSymbol: string | undefined, tokenDecimals: number | undefined;
  if (exists) {
    try {
      tokenSymbol = await publicClient.readContract({ address: token as Address, abi: erc20Abi, functionName: "symbol" });
      tokenDecimals = await publicClient.readContract({ address: token as Address, abi: erc20Abi, functionName: "decimals" });
    } catch { /* a token need not implement them */ }
  }

  const refundAfter = exists
    ? await publicClient.readContract({ address: escrow, abi: escrowAbi, functionName: "REFUND_AFTER" })
    : 0n;
  const refundOpensAt = BigInt(fundedAt) + BigInt(refundAfter);

  if (!exists) warnings.push("No such deal on this chain. Check the escrow address and the chain id before anything else.");
  if (exists && !matches) {
    warnings.push(
      "THE VERIFIER'S CODE DOES NOT HASH TO WHAT THE DEAL PINNED. settleWithProof will revert " +
      "with VerifierMismatch and this deal can only ever time out. Do not work on it.",
    );
  }
  if (profile) {
    if (profile.verifier.toLowerCase() !== (verifier as string).toLowerCase()) {
      warnings.push(`The deal names verifier ${verifier}, but the profile you passed describes ${profile.verifier}. They are different programs.`);
    }
    if (vkey && profile.verdictProgramVKey.toLowerCase() !== vkey.toLowerCase()) {
      warnings.push(`The verifier judges guest ${vkey}; the profile claims ${profile.verdictProgramVKey}.`);
    }
    for (const l of profile.knownLimits) warnings.push(`known limit: ${l}`);
  } else {
    warnings.push("No verifier profile supplied, so nothing here describes what this verifier is or what it can judge. That is a gap in what you are being shown, not a clean bill of health.");
  }
  if (tokenPolicy.sellerBlocked) {
    warnings.push(
      "THE TOKEN WILL NOT PAY THIS SELLER. The token reports this deal's seller as blacklisted or frozen, so " +
      "a `Reproduced` verdict would revert on the transfer and the deal would stay Funded until the 30-day " +
      "deadline returns it to the buyer. Doing this work would not get you paid.",
    );
  }
  if (tokenPolicy.buyerBlocked) {
    warnings.push(
      "The token reports the BUYER as blocked, so a `Failed` verdict — and the deadline refund — would revert. " +
      "The money would stay in the escrow with no exit.",
    );
  }
  if (tokenPolicy.paused) {
    warnings.push("The token is PAUSED. No payout can move, in either direction, until that changes.");
  }
  if (exists) {
    warnings.push(
      `Token policy probed with: ${tokenPolicy.probed.join(", ") || "nothing — this token exposes none of the shapes we know"}. ` +
      "These are known shapes, not a closed set: a token can refuse a transfer for reasons no probe here can see, " +
      "so a quiet result is not a promise that you will be paid.",
    );
  }
  warnings.push(
    "The buyer chose this verifier. If it is a program that always returns Failed, you will work for nothing " +
    "and the chain cannot tell that from an honest failure. Read the verifier, not just this summary.",
  );
  warnings.push("This preflight is NOT on-chain consent. The escrow does not require you to have run it, and nothing you do here is recorded.");

  const amt = tokenDecimals !== undefined
    ? `${amount} (${formatUnits(amount, tokenDecimals)} ${tokenSymbol ?? ""})`.trim()
    : `${amount}`;
  const report = [
    `deal            ${dealId}`,
    `state           ${dealStateName(Number(state))}`,
    `buyer           ${buyer}`,
    `seller (you?)   ${seller}`,
    `token / amount  ${token}  ${amt}`,
    `verifier        ${verifier}`,
    `  pinned hash   ${verifierCodeHash}`,
    `  on-chain hash ${onChainHash}   ${matches ? "MATCH" : "*** MISMATCH ***"}`,
    vkey ? `  judges guest  ${vkey}` : `  judges guest  (verifier does not expose verdictProgramVKey)`,
    tokenPolicy.sellerBlocked ? `token policy    *** THE TOKEN WILL NOT PAY THIS SELLER ***` : "",
    `binding         ${dealBinding}`,
    profile ? `predicate       ${profile.predicate.description}` : `predicate       (no profile supplied)`,
    profile ? `chain           ${profile.chain.name} (${profile.chain.chainId})` : "",
    `funded at       ${fundedAt}`,
    `refund opens    ${refundOpensAt}  (unix; 30 days after funding, callable by anyone, pays the caller nothing)`,
    "",
    ...warnings.map((w) => `!  ${w}`),
  ].filter(Boolean).join("\n");

  return {
    exists, state: dealStateName(Number(state)),
    buyer: buyer as Address, seller: seller as Address, token: token as Address, amount,
    tokenSymbol, tokenDecimals,
    verifier: verifier as Address, verifierCodeHash: verifierCodeHash as Hex,
    verifierCodeHashOnChain: onChainHash, verifierCodeHashMatches: matches,
    verdictProgramVKeyOnChain: vkey, tokenPolicy,
    dealBinding: dealBinding as Hex, fundedAt: BigInt(fundedAt), refundOpensAt,
    profile, warnings, report,
  };
}

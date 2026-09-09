/**
 * Reckn Partner Kit — open a deal, check one before you work on it, settle it on a proof,
 * and verify the settlement.
 *
 * **What this package does not do, stated first.** It does not decide payments, it cannot
 * override a verdict, and it holds no key. Every function here either reads the chain or
 * hands a transaction to a wallet *you* supply. `submitProof` is permissionless and pays the
 * caller nothing — the proof carries the authority, which is the entire point.
 */
import type { Address, Hex, PublicClient, WalletClient, Account } from "viem";
import { keccak256, toBytes } from "viem";
import { escrowAbi, erc20Abi, DealState, Outcome, dealStateName } from "./escrow.js";
import { evmDealBinding, erc20BalanceSlot, type EvmDealTerms } from "./binding.js";
import { assertValidProfile, verifyProfileAgainstChain, type VerifierProfile } from "./profile.js";
import { reproduces } from "./terms.js";

export * from "./binding.js";
export * from "./profile.js";
export * from "./terms.js";
export { escrowAbi, erc20Abi, DealState, Outcome, dealStateName } from "./escrow.js";

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
  tokenPolicy: {
    probed: string[];
    sellerBlocked?: boolean | undefined;
    buyerBlocked?: boolean | undefined;
    paused?: boolean | undefined;
  };
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

  /**
   * Probe the token for the policies that can block a payout a proof already authorised.
   *
   * **These are known shapes, not a closed set.** `isBlacklisted` is what Circle's FiatToken
   * exposes and `isFrozen` is the other common spelling; a token can refuse a transfer for
   * reasons no probe here can see. **A quiet result is not a promise that you will be paid** —
   * it means none of the questions we knew how to ask came back yes.
   *
   * This exists because the generic warning was not enough. On Arc there is a deal whose
   * seller IS blacklisted, and until this probe the preflight told them only that "USDC on Arc
   * carries a blacklist" — true, and not the same sentence as "you specifically will not be
   * paid".
   */
  const policyProbes: Array<[string, string, "seller" | "buyer" | "token"]> = [
    ["isBlacklisted(address)", "0xfe575a87", "seller"],
    ["isBlacklisted(address)", "0xfe575a87", "buyer"],
    ["isFrozen(address)", "0xe5839836", "seller"],
    ["paused()", "0x5c975abb", "token"],
  ];
  const tokenPolicy: Preflight["tokenPolicy"] = { probed: [] };
  if (exists) {
    for (const [name, selector, subject] of policyProbes) {
      const who = subject === "seller" ? (seller as string) : subject === "buyer" ? (buyer as string) : undefined;
      const data = who ? (selector + who.slice(2).toLowerCase().padStart(64, "0")) : selector;
      try {
        const res = await publicClient.call({ to: token as Address, data: data as Hex });
        if (!res.data || res.data === "0x") continue;
        const truthy = BigInt(res.data) === 1n;
        tokenPolicy.probed.push(`${name}${who ? `(${subject})` : ""}`);
        if (subject === "seller") tokenPolicy.sellerBlocked = tokenPolicy.sellerBlocked || truthy;
        else if (subject === "buyer") tokenPolicy.buyerBlocked = tokenPolicy.buyerBlocked || truthy;
        else tokenPolicy.paused = truthy;
      } catch { /* the token does not implement it; that is not a fault */ }
    }
  }

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
    ? `${amount} (${Number(amount) / 10 ** tokenDecimals} ${tokenSymbol ?? ""})`.trim()
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

/**
 * Submit a proof.
 *
 * **This function has no authority over the payout and could not be given any.**
 * `settleWithProof` is permissionless: the key that pays the gas has no bearing on where the
 * money goes, there is no allow-list, and the verdict comes from the public values the proof
 * commits to. Anyone may call it, including someone who is neither party.
 */
export async function submitProof(opts: {
  publicClient: PublicClient;
  walletClient: WalletClient;
  account: Account | Address;
  escrow: Address;
  dealId: Hex;
  publicValues: Hex;
  proofBytes: Hex;
}): Promise<{ tx: Hex }> {
  const tx = await opts.walletClient.writeContract({
    address: opts.escrow, abi: escrowAbi, functionName: "settleWithProof",
    args: [opts.dealId, opts.publicValues, opts.proofBytes],
    account: opts.account as never, chain: null,
  });
  await opts.publicClient.waitForTransactionReceipt({ hash: tx });
  return { tx };
}

export interface Settlement {
  dealId: Hex;
  settled: boolean;
  state: string;
  outcome?: "Reproduced" | "Failed" | undefined;
  paidTo?: Address | undefined;
  amountMoved?: bigint | undefined;
  traceHash?: Hex | undefined;
  dealBinding: Hex;
  tx?: Hex | undefined;
  blockNumber?: bigint | undefined;
  gasUsed?: bigint | undefined;
  /** Tempo and chains like it put these on every receipt. Absent elsewhere. */
  feeToken?: Address | undefined;
  feePayer?: Address | undefined;
  report: string;
}

/**
 * Verify a settlement **as a third party**, from the chain rather than from whoever told you
 * about it. Every field below is decoded out of the receipt and the escrow's own storage; none
 * is taken from an argument except the identifiers used to look it up.
 */
export async function verifySettlement(opts: {
  publicClient: PublicClient;
  escrow: Address;
  dealId: Hex;
  /** Optional: if you have the settling transaction, its receipt is decoded too. */
  tx?: Hex;
}): Promise<Settlement> {
  const { publicClient, escrow, dealId } = opts;
  const d = await publicClient.readContract({ address: escrow, abi: escrowAbi, functionName: "deals", args: [dealId] });
  const state = Number(d[8]);
  const dealBinding = d[6] as Hex;

  let outcome: Settlement["outcome"], paidTo: Address | undefined, traceHash: Hex | undefined;
  let amountMoved: bigint | undefined, blockNumber: bigint | undefined, gasUsed: bigint | undefined;
  let feeToken: Address | undefined, feePayer: Address | undefined;

  if (opts.tx) {
    const r = await publicClient.getTransactionReceipt({ hash: opts.tx });
    blockNumber = r.blockNumber; gasUsed = r.gasUsed;
    const raw = r as unknown as Record<string, unknown>;
    if (typeof raw.feeToken === "string") feeToken = raw.feeToken as Address;
    if (typeof raw.feePayer === "string") feePayer = raw.feePayer as Address;

    const settled = keccak256(toBytes("SettledByProof(bytes32,address,uint8,bytes32)"));
    const transfer = keccak256(toBytes("Transfer(address,address,uint256)"));
    for (const log of r.logs) {
      if (log.topics[0] === settled && log.topics[1]?.toLowerCase() === dealId.toLowerCase()) {
        paidTo = ("0x" + (log.topics[2] as string).slice(26)) as Address;
        outcome = Number(BigInt("0x" + log.data.slice(2, 66))) === Outcome.Reproduced ? "Reproduced" : "Failed";
        traceHash = ("0x" + log.data.slice(66, 130)) as Hex;
      }
      // The transfer OUT of the escrow is the money actually moving. A Transfer log that is
      // not from the escrow is somebody else's business and must not be counted as this one.
      if (log.topics[0] === transfer && log.topics[1] &&
          ("0x" + (log.topics[1] as string).slice(26)).toLowerCase() === escrow.toLowerCase()) {
        amountMoved = BigInt(log.data);
      }
    }
  }

  const report = [
    `deal        ${dealId}`,
    `state       ${dealStateName(state)}`,
    `binding     ${dealBinding}`,
    outcome ? `verdict     ${outcome}  (0 = Reproduced -> seller, 1 = Failed -> buyer)` : `verdict     (no settling transaction supplied)`,
    paidTo ? `paid to     ${paidTo}` : "",
    amountMoved !== undefined ? `moved       ${amountMoved} out of the escrow` : "",
    traceHash ? `traceHash   ${traceHash}` : "",
    opts.tx ? `tx          ${opts.tx}` : "",
    blockNumber !== undefined ? `block       ${blockNumber}  gas ${gasUsed}` : "",
    feeToken ? `feeToken    ${feeToken}   feePayer ${feePayer}` : "",
    "",
    state === DealState.Settled
      ? `The escrow's own state says Settled, so this deal cannot settle again and cannot be refunded.`
      : state === DealState.Funded
        ? `Still Funded. No proof has moved this money; the buyer may reclaim it after the deadline.`
        : `No such deal at this escrow on this chain.`,
  ].filter(Boolean).join("\n");

  return {
    dealId, settled: state === DealState.Settled, state: dealStateName(state),
    outcome, paidTo, amountMoved, traceHash, dealBinding,
    tx: opts.tx, blockNumber, gasUsed, feeToken, feePayer, report,
  };
}

export { erc20BalanceSlot };

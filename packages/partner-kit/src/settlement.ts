/**
 * Settling, and reading what a settlement did.
 *
 * `submitProof` has **no payment authority**: it forwards a proof and the escrow decides. Any
 * key can call it and the key that pays the gas has no bearing on where the money goes.
 *
 * `verifySettlement` decodes the receipt rather than trusting a report of it, and it keeps the
 * distinction the escrow emits two separate events to preserve — a payout a proof authorised
 * is not the same thing as the 30-day timeout refund, and the deal state reads Settled for both.
 */
import type { Address, Hex, PublicClient, WalletClient, Account } from "viem";
import { keccak256, toBytes } from "viem";
import { escrowAbi, DealState, Outcome, dealStateName } from "./escrow.js";

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
  outcome?: "Reproduced" | "Failed" | "RefundedAfterDeadline" | undefined;
  /**
   * WHAT AUTHORISED the payout — the distinction the escrow declares two separate events to
   * preserve. `"proof"` means a verified verdict decided it. `"deadline"` means nothing did:
   * the money went back because no proof arrived in 30 days. Only present when a settling
   * transaction was supplied; the escrow's `state` is `Settled` either way and cannot tell
   * them apart.
   */
  settledBy?: "proof" | "deadline" | undefined;
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

  const dealToken = (d[2] as Address).toLowerCase();
  let outcome: Settlement["outcome"], paidTo: Address | undefined, traceHash: Hex | undefined;
  let settledBy: Settlement["settledBy"];
  let amountMoved: bigint | undefined, blockNumber: bigint | undefined, gasUsed: bigint | undefined;
  let feeToken: Address | undefined, feePayer: Address | undefined;

  if (opts.tx) {
    const r = await publicClient.getTransactionReceipt({ hash: opts.tx });
    blockNumber = r.blockNumber; gasUsed = r.gasUsed;
    const raw = r as unknown as Record<string, unknown>;
    if (typeof raw.feeToken === "string") feeToken = raw.feeToken as Address;
    if (typeof raw.feePayer === "string") feePayer = raw.feePayer as Address;

    const settled = keccak256(toBytes("SettledByProof(bytes32,address,uint8,bytes32)"));
    // The escrow declares this as a SEPARATE event on purpose — see its own comment: this is
    // the one payout in the contract that no proof authorised, and a reader "should never
    // have to infer which kind it was". Decoding only the first event forces exactly that
    // inference, and answers "Settled" to a question about proofs.
    const refunded = keccak256(toBytes("RefundedAfterDeadline(bytes32,address,uint256)"));
    const transfer = keccak256(toBytes("Transfer(address,address,uint256)"));
    for (const log of r.logs) {
      if (log.topics[0] === settled && log.topics[1]?.toLowerCase() === dealId.toLowerCase()) {
        paidTo = ("0x" + (log.topics[2] as string).slice(26)) as Address;
        outcome = Number(BigInt("0x" + log.data.slice(2, 66))) === Outcome.Reproduced ? "Reproduced" : "Failed";
        traceHash = ("0x" + log.data.slice(66, 130)) as Hex;
        settledBy = "proof";
      }
      if (log.topics[0] === refunded && log.topics[1]?.toLowerCase() === dealId.toLowerCase()) {
        paidTo = ("0x" + (log.topics[2] as string).slice(26)) as Address;
        outcome = "RefundedAfterDeadline";
        settledBy = "deadline";
        amountMoved = BigInt(log.data);
      }
      // The transfer OUT of the escrow is the money actually moving. Two filters, not one:
      // it must come FROM the escrow, and it must be THIS DEAL'S TOKEN. A settling
      // transaction that also touches another deal in a different token emits a second
      // qualifying log, and taking the last one silently reports the wrong token's amount
      // under this deal's name.
      if (log.topics[0] === transfer && log.topics[1] &&
          log.address.toLowerCase() === dealToken &&
          ("0x" + (log.topics[1] as string).slice(26)).toLowerCase() === escrow.toLowerCase()) {
        amountMoved = BigInt(log.data);
      }
    }
  }

  const report = [
    `deal        ${dealId}`,
    `state       ${dealStateName(state)}`,
    `binding     ${dealBinding}`,
    settledBy === "proof"
      ? `verdict     ${outcome}  (0 = Reproduced -> seller, 1 = Failed -> buyer)`
      : settledBy === "deadline"
        ? `verdict     none — NO PROOF AUTHORISED THIS PAYOUT`
        : opts.tx
          ? `verdict     the transaction you supplied settles no deal with this id`
          : `verdict     (no settling transaction supplied)`,
    paidTo ? `paid to     ${paidTo}` : "",
    amountMoved !== undefined ? `moved       ${amountMoved} out of the escrow` : "",
    traceHash ? `traceHash   ${traceHash}` : "",
    opts.tx ? `tx          ${opts.tx}` : "",
    blockNumber !== undefined ? `block       ${blockNumber}  gas ${gasUsed}` : "",
    feeToken ? `feeToken    ${feeToken}   feePayer ${feePayer}` : "",
    "",
    settledBy === "deadline"
      ? `This is a TIMEOUT REFUND, not a settlement on proof. The deadline passed with no proof, ` +
        `so the money went back to the buyer and no verdict was ever reached. The escrow's ` +
        `state reads Settled for this and for a proof settlement alike — only the event tells ` +
        `them apart, which is why the contract emits two.`
      : state === DealState.Settled
        ? `The escrow's own state says Settled, so this deal cannot settle again and cannot be refunded.`
      : state === DealState.Funded
        ? `Still Funded. No proof has moved this money; the buyer may reclaim it after the deadline.`
        : `No such deal at this escrow on this chain.`,
  ].filter(Boolean).join("\n");

  return {
    dealId, settled: state === DealState.Settled, state: dealStateName(state),
    outcome, settledBy, paidTo, amountMoved, traceHash, dealBinding,
    tx: opts.tx, blockNumber, gasUsed, feeToken, feePayer, report,
  };
}


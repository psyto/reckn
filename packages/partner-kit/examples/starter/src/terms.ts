/**
 * ════════════════════════════════════════════════════════════════════════════════════
 *  THIS IS THE FILE YOU REPLACE. Everything else in the starter stays as it is.
 * ════════════════════════════════════════════════════════════════════════════════════
 *
 * These terms describe **one deterministic step** and the condition that decides whether it
 * was done. They are hashed into a single `dealBinding` at funding, and after that neither
 * party can change any of them.
 *
 * **What is sample and what is yours:**
 *
 *   sample (ours)  the numbers below, and the shipped Groth16 proof that matches them. They
 *                  come from `zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json`
 *                  and exist so the starter runs in one command without a prover.
 *   yours          the same four things, for your job:
 *                    - the prestate you both anchor to      (stateRoot + env)
 *                    - the call you expect to be executed   (plan)
 *                    - the condition that decides payment   (check)
 *                    - and a proof of your own execution
 *
 * **The honest part.** Producing a proof for YOUR terms takes minutes — 335 s for this
 * fixture, 497 s for a real mainnet Uniswap v3 swap, measured on a laptop CPU, and it needs
 * the SP1 toolchain plus about 6.2 GB of Groth16 artifacts. The starter ships a proof so you
 * can see the whole shape first. Swapping in your own step is a separate, slower loop, and
 * pretending otherwise would waste your afternoon.
 *
 * **What Reckn does not do**, so you do not model your job wrongly: it does not evaluate an
 * agent's output for quality, correctness of judgement, or anything a person would argue
 * about. It answers exactly one question — *did this call, replayed against this prior state,
 * move this storage slot up by at least this much?* If your valuable step cannot be phrased
 * that way, this is the wrong tool for it, and finding that out now is the cheapest outcome
 * available.
 */
import { readFileSync } from "node:fs";
import type { EvmDealTerms } from "@reckn/partner-kit";

const vectors = JSON.parse(
  readFileSync(new URL("../../../test/vectors/evm-binding.json", import.meta.url), "utf8"),
);

/** The sample terms, loaded from the golden vector so they cannot drift from the proof. */
export function sampleTerms(): EvmDealTerms {
  const t = vectors.vectors[0].terms;
  return {
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
}

/**
 * A human sentence for the same thing. Your seller reads this, not the struct — and if you
 * cannot write this sentence, the deal is not ready to be funded.
 */
export const sampleWorkloadSummary =
  "Execute the committed call against the committed prestate; the checked slot must rise by " +
  "at least 100. (Sample: a single SSTORE. Yours would be, e.g., 'swap 0.1 WETH for USDC via " +
  "SwapRouter02; the recipient's USDC balance must rise by at least 246_000000'.)";

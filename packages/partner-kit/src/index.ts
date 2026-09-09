/**
 * `@reckn/partner-kit` — the public surface.
 *
 * This file is deliberately thin. It used to be 509 lines holding four public functions that
 * never call each other, a token-policy prober and a number formatter; the responsibilities
 * now live next to each other in modules named for what they do. Nothing here is new and
 * nothing was removed: this is the same API, re-exported from where it belongs.
 */
export * from "./binding.js";
export * from "./profile.js";
export * from "./terms.js";
export * from "./predicate.js";
export * from "./format.js";
// NOT `export *`. rpc.ts and witness.ts are transport and plumbing; publishing getBlock,
// getCode, captureWitness and friends would make every one of them a compatibility promise
// for no reader who asked. What a consumer legitimately needs from them is the ability to
// TELL FAILURES APART — an endpoint that lacks a method is not a call that reverts — and the
// shapes that appear in a TermsBundle.
export type { Rpc } from "./rpc.js";
export type { WitnessAccount } from "./witness.js";
export {
  EndpointCapabilityError, CallRevertedError, SimulationInconclusiveError, MalformedResponseError,
} from "./rpc.js";
export * from "./deal.js";
export * from "./preflight.js";
export * from "./settlement.js";
export { escrowAbi, erc20Abi, DealState, Outcome, dealStateName } from "./escrow.js";
export { erc20BalanceSlot } from "./binding.js";

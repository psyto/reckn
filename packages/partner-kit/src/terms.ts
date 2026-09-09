/**
 * `buildTerms` — turn *your* transaction into a Reckn deal.
 *
 * This is the step that had no tool. A partner could run the starter and see our sample
 * settle, and then had to read the `keeper` crate and assemble an anchor, a plan and a
 * predicate by hand. The API was never the barrier; this was.
 *
 * **Four things it refuses to let you get wrong.** Each produces a deal that opens cleanly and
 * then settles wrongly — or never settles at all — which is worse than an error, because the
 * cost lands after the money has moved:
 *
 *   1. **The hardfork.** `specId` is committed into the binding. Choose a different one and
 *      you get a valid-looking hash that no proof from this guest can match, with nothing
 *      failing at funding time. It is taken from the profile and you are not asked.
 *   2. **A call that does not succeed at the anchor.** The plan is replayed against the
 *      committed prestate. If it reverts there, you find out at settlement — having paid —
 *      that "your work did not reproduce". So the call is simulated first and this refuses
 *      to emit terms for one that fails.
 *   3. **An anchor that ages out.** Public endpoints do not serve historical `eth_getProof`
 *      (measured on both Arc and Tempo). Capture the witness later and it is simply gone. So
 *      the witness is captured *now*, in the same run, and the bundle is self-contained.
 *   4. **A predicate that decides nothing.** A band the *empty* execution already satisfies
 *      pays the seller for doing no work, and a band *no* execution can satisfy makes the
 *      seller work for a payment that can never arrive. Both are asked as questions about the
 *      guest's predicate rather than as comparisons against a constant — see `reproduces`.
 *   5. **A predicate aimed at a slot the plan never moves.** The slot is computed from a
 *      `balancesSlotIndex` that defaults to Circle's layout and a holder the caller supplies,
 *      and neither is checked by anything else. Point it one slot wrong and the bundle still
 *      builds, still binds, and still funds — and then proves a delta of zero forever. The
 *      simulation already knows every slot the call touches, so it is asked.
 *
 * No key, no signature, nothing sent: every call here is `eth_`-read-only.
 */
import { keccak_256 } from "@noble/hashes/sha3";
import { evmDealBinding, erc20BalanceSlot, type EvmDealTerms } from "./binding.js";
import type { VerifierProfile } from "./profile.js";
import { assertPredicateCanDecide, MAX_U256 } from "./predicate.js";
import { createAccessList, getBlock, getChainId, type Rpc } from "./rpc.js";
import { assertPredicateSlotIsTouched, captureWitness, touchedByCall, type WitnessAccount } from "./witness.js";

// Re-exported so `reproduces` keeps its place in the package's public surface after moving to
// predicate.ts. The name a consumer imports must not depend on where we filed the code.
export { reproduces, assertPredicateCanDecide, NOTHING_HAPPENED, MAX_U256 } from "./predicate.js";

export type { Rpc } from "./rpc.js";
export {
  EndpointCapabilityError, CallRevertedError, SimulationInconclusiveError, MalformedResponseError,
  isMethodMissing,
} from "./rpc.js";

export interface BuildTermsArgs {
  profile: VerifierProfile;
  rpc: Rpc;
  /** The address the call is made from. It must be able to make it **at the anchor block**. */
  caller: string;
  target: string;
  calldata: string;
  value?: bigint;
  gasLimit?: bigint;
  /** The condition that decides payment: a token balance that must rise. */
  check: {
    token: string;
    /** Whose balance. Usually the recipient of the work. */
    holder: string;
    /** The Solidity slot index of the `mapping(address => uint256)` balances (USDC: 9). */
    balancesSlotIndex: number;
    min: bigint;
    max?: bigint;
  };
  /** Defaults to the latest block. Pinned to a NUMBER immediately, never left as a tag. */
  blockNumber?: bigint;
}

export type { WitnessAccount } from "./witness.js";

export interface TermsBundle {
  terms: EvmDealTerms;
  dealBinding: `0x${string}`;
  anchor: { blockNumber: string; blockHash: string; stateRoot: string };
  simulation: { gasUsed: string; touchedAccounts: number; touchedSlots: number };
  witness: WitnessAccount[];
  /** Everything a reader needs to judge whether this bundle is worth trusting. */
  provenance: {
    profile: string; chainId: number; specId: number;
    builtBy: "@reckn/partner-kit buildTerms";
    note: string;
  };
}

const hexToBigInt = (h: string): bigint => BigInt(h);
const pad32 = (v: bigint): string => "0x" + v.toString(16).padStart(64, "0");
const lc = (s: string) => s.toLowerCase();

export async function buildTerms(args: BuildTermsArgs): Promise<TermsBundle> {
  const { profile, rpc } = args;

  if (profile.vm !== "evm") {
    throw new Error(`profile "${profile.id}" adjudicates ${profile.vm}; these terms are EVM.`);
  }
  if (typeof profile.specId !== "number") {
    throw new Error(
      `profile "${profile.id}" does not pin specId. It is committed into every binding, so a ` +
      `guess would produce a deal that opens and can never settle. Fix the profile.`,
    );
  }

  // (4) The predicate has to be capable of deciding — see predicate.ts for the two ways it
  // cannot be. Asked here, before a single request goes out, because neither depends on the chain.
  const min = args.check.min;
  const max = args.check.max ?? MAX_U256;
  assertPredicateCanDecide(min, max);

  const onChainId = await getChainId(rpc);
  if (onChainId !== profile.chain.chainId) {
    throw new Error(`the endpoint answers chain ${onChainId}, not the profile's ${profile.chain.chainId}`);
  }

  // Pin the block by NUMBER at once. Everything after this reads the same block, so nothing
  // can shift underneath the bundle mid-build.
  const tag = args.blockNumber !== undefined ? "0x" + args.blockNumber.toString(16) : "latest";
  const block = await getBlock(rpc, tag);
  const blockNumber = block.number;

  const value = args.value ?? 0n;
  const gasLimit = args.gasLimit ?? 500_000n;
  // A gas price at or above the base fee, or the node refuses to simulate at all. Learned by
  // hitting both failures: zero is rejected after London, and one wei is below the base fee.
  const baseFee = hexToBigInt(block.baseFeePerGas ?? "0x0");
  const gasPrice = baseFee === 0n ? 1_000_000_000n : baseFee * 2n;

  const tx = {
    from: args.caller, to: args.target, data: args.calldata,
    value: "0x" + value.toString(16), gas: "0x" + gasLimit.toString(16),
    gasPrice: "0x" + gasPrice.toString(16),
  };

  // (2) Simulate. One request both proves the call succeeds at the anchor and enumerates the
  // witness. The three ways this fails — endpoint lacks the method, the call reverts, or we
  // cannot tell — are classified in rpc.ts, because telling them apart is transport knowledge
  // and not something a terms builder should carry.
  const access = await createAccessList(rpc, tx, blockNumber);

  const touches = touchedByCall(access.accessList, [args.caller, args.target, block.miner]);

  // (5) The predicate must be about something this plan actually moves — see witness.ts.
  const checkSlot = erc20BalanceSlot(args.check.holder, args.check.balancesSlotIndex);
  assertPredicateSlotIsTouched(touches, { ...args.check, slot: checkSlot });

  // (3) Capture the witness now, in the same run, so the bundle is self-contained.
  const witness: WitnessAccount[] = await captureWitness(rpc, touches, blockNumber);

  const terms: EvmDealTerms = {
    stateRoot: block.stateRoot,
    env: {
      chainId: BigInt(profile.chain.chainId),
      specId: profile.specId,                       // (1) from the profile, never from the caller
      blockNumber: hexToBigInt(blockNumber),
      timestamp: hexToBigInt(block.timestamp),
      baseFee,
      blockGasLimit: hexToBigInt(block.gasLimit),
      coinbase: block.miner,
      prevrandao: block.mixHash ?? block.difficulty ?? "0x" + "00".repeat(32),
    },
    check: {
      address: args.check.token,
      slot: checkSlot,
      min: pad32(min),
      max: pad32(max),
    },
    plan: {
      caller: args.caller, target: args.target, value: pad32(value),
      gasLimit, calldata: args.calldata,
    },
  };

  return {
    terms,
    dealBinding: evmDealBinding(terms),
    anchor: { blockNumber, blockHash: block.hash, stateRoot: block.stateRoot },
    simulation: {
      gasUsed: access.gasUsed ?? "0x0",
      touchedAccounts: witness.length,
      touchedSlots: witness.reduce((n, a) => n + a.storageProof.length, 0),
    },
    witness,
    provenance: {
      profile: profile.id, chainId: profile.chain.chainId, specId: profile.specId,
      builtBy: "@reckn/partner-kit buildTerms",
      note:
        "Read-only: no key, no signature, nothing sent. The call was SIMULATED at this anchor " +
        "and succeeded — that is not a promise it will satisfy the floor, only that it does not " +
        "revert. The witness was captured at build time because public endpoints do not serve " +
        "historical eth_getProof. Proving this still needs the SP1 toolchain and minutes of CPU.",
    },
  };
}

/** Convenience for the common case: keccak of the caller's own label, as a deal id. */
export function dealIdFromLabel(label: string): `0x${string}` {
  const b = keccak_256(new TextEncoder().encode(`reckn/deal/${label}`));
  return ("0x" + Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("")) as `0x${string}`;
}

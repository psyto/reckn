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

export type Rpc = (method: string, params: unknown[]) => Promise<any>;

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

export interface WitnessAccount {
  address: string; balance: string; nonce: string;
  storageHash: string; codeHash: string; code: string;
  accountProof: string[];
  storageProof: Array<{ key: string; value: string; proof: string[] }>;
}

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

/**
 * `delta_outcome`, transcribed from `zk-verdict/lib/src/lib.rs:36` — the **only** predicate the
 * EVM guest has. `Reproduced` iff `post - pre`, saturating at zero, lies in `[min, max]`.
 *
 * It is transcribed rather than described because the two refusals below are *evaluations of
 * the guest's own rule*, not comparisons against a magic constant. `min === 0n` happens to be
 * the answer today; asking the predicate means a differently-shaped one still has to answer.
 *
 * Saturation is why a *decrease* is delta 0 rather than a wrapped enormous number, and so why
 * the default `max` of 2^256-1 does not quietly admit every losing execution.
 */
export function reproduces(pre: bigint, post: bigint, min: bigint, max: bigint): boolean {
  const delta = post > pre ? post - pre : 0n;
  return delta >= min && delta <= max;
}

/** The empty execution: nothing ran, so the slot ends where it started. */
const NOTHING_HAPPENED = { pre: 0n, post: 0n };

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

  // (4) The predicate has to be capable of deciding. Two ways it is not, both of which fund
  // cleanly and both of which are only discovered once someone is owed money. Checked here,
  // before a single request goes out, because neither depends on the chain.
  const min = args.check.min;
  const max = args.check.max ?? (2n ** 256n - 1n);
  if (max < min) {
    throw new Error(
      `this predicate cannot be satisfied by any execution: max (${max}) is below min (${min}).\n` +
      `The guest would return Failed for every replay, including a perfect one, so the seller ` +
      `would work and the money would sit until the buyer's 30-day refund. No terms were produced.`,
    );
  }
  if (reproduces(NOTHING_HAPPENED.pre, NOTHING_HAPPENED.post, min, max)) {
    throw new Error(
      `this predicate is satisfied by doing nothing, so it decides nothing.\n` +
      `The guest measures the increase the plan itself caused, saturating at zero. With ` +
      `min = ${min} the empty execution scores a delta of 0 and settles as Reproduced: the ` +
      `seller is paid in full for no work, and it is the BUYER who loses. Set a floor the work ` +
      `must clear.\n` +
      `If what you wanted was a cap, note this guest has one check, and a delta check with no ` +
      `floor cannot express "at most X" as a condition for payment. No terms were produced.`,
    );
  }

  const onChainId = Number(await rpc("eth_chainId", []));
  if (onChainId !== profile.chain.chainId) {
    throw new Error(`the endpoint answers chain ${onChainId}, not the profile's ${profile.chain.chainId}`);
  }

  // Pin the block by NUMBER at once. Everything after this reads the same block, so nothing
  // can shift underneath the bundle mid-build.
  const tag = args.blockNumber !== undefined ? "0x" + args.blockNumber.toString(16) : "latest";
  const block = await rpc("eth_getBlockByNumber", [tag, false]);
  if (!block) throw new Error(`no block at ${tag}`);
  const blockNumber: string = block.number;

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

  // (2) Simulate. `eth_createAccessList` executes the call and reports what it touched, so
  // one request both proves the call succeeds and enumerates the witness.
  let access: any;
  try {
    access = await rpc("eth_createAccessList", [tx, blockNumber]);
  } catch (e) {
    throw new Error(
      `the call could not be simulated at block ${blockNumber}: ${(e as Error).message}\n` +
      `A plan that does not succeed at the anchor settles as Failed — you would pay to be told ` +
      `your work did not reproduce. No terms were produced.`,
    );
  }
  if (access?.error) {
    throw new Error(
      `the call REVERTS at block ${blockNumber}: ${access.error}\n` +
      `Terms were not produced. Fix the call, or pick an anchor where it succeeds.`,
    );
  }

  const touches = new Map<string, Set<string>>();
  for (const e of access.accessList ?? []) {
    const set = touches.get(lc(e.address)) ?? new Set<string>();
    for (const k of e.storageKeys ?? []) set.add(lc(k));
    touches.set(lc(e.address), set);
  }
  for (const a of [args.caller, args.target, block.miner]) {
    if (a && !touches.has(lc(a))) touches.set(lc(a), new Set());
  }

  // (5) The predicate must be about something this plan actually moves. The simulation has
  // just enumerated every slot the call touches, so this costs nothing and closes the gap
  // between "the slot I meant" and "the slot I computed" — a gap that nothing else in the
  // pipeline can see: `erc20BalanceSlot` returns a well-formed keccak for a wrong slot index
  // just as happily as for the right one, funding succeeds, and the guest then measures a
  // slot no execution writes. Delta is zero forever, the verdict is Failed forever, and the
  // seller does the work and is not paid.
  const checkSlot = erc20BalanceSlot(args.check.holder, args.check.balancesSlotIndex);
  const touchedByToken = touches.get(lc(args.check.token));
  if (!touchedByToken?.has(lc(checkSlot))) {
    throw new Error(
      `the call never touches the slot this predicate measures, so no execution of this plan ` +
      `can satisfy it.\n` +
      `  predicate slot  ${checkSlot}\n` +
      `                  (holder ${args.check.holder}, balances slot index ${args.check.balancesSlotIndex})\n` +
      `  token           ${args.check.token}\n` +
      `  slots the call actually touches on that token: ` +
      `${touchedByToken && touchedByToken.size ? [...touchedByToken].join(", ") : "(none)"}\n` +
      `The two usual causes: the balances mapping is not at index ${args.check.balancesSlotIndex} ` +
      `for this token (that default is Circle's FiatToken layout, not a standard), or the holder ` +
      `is not the address this call credits. The guest would prove a delta of zero and return ` +
      `Failed on a correct replay, so the seller would work and not be paid. No terms were produced.`,
    );
  }

  // (3) Capture the witness now. A public endpoint will not serve these proofs for this block
  // later; "we can fetch it when we prove" is how a bundle becomes unprovable.
  const witness: WitnessAccount[] = [];
  for (const [address, slots] of [...touches].sort(([a], [b]) => (a < b ? -1 : 1))) {
    const proof = await rpc("eth_getProof", [address, [...slots].sort(), blockNumber]);
    const code = await rpc("eth_getCode", [address, blockNumber]);
    witness.push({
      address, balance: proof.balance, nonce: proof.nonce,
      storageHash: proof.storageHash, codeHash: proof.codeHash, code,
      accountProof: proof.accountProof,
      storageProof: (proof.storageProof ?? []).map((s: any) => ({ key: s.key, value: s.value, proof: s.proof })),
    });
  }

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

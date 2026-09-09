/**
 * The witness — which accounts and slots a prover will need, and the proofs for them.
 *
 * Split out of `buildTerms` because it answers a question of its own: *given what the call
 * touched, what must travel with the deal?* Two of the three answers here are not obvious.
 *
 *   1. The access list is not enough. The caller, the target and the coinbase are touched by
 *      every transaction whether or not a node lists them, and a bundle missing them cannot
 *      be replayed. The keeper adds them too.
 *   2. The predicate's slot must be among the slots the call ACTUALLY TOUCHED. Nothing else
 *      in the pipeline can see this: `erc20BalanceSlot` returns a well-formed keccak for a
 *      wrong slot index exactly as happily as for the right one, and funding then succeeds
 *      against a predicate the plan can never move.
 */
import { getCode, getProof, type Rpc } from "./rpc.js";

export interface WitnessAccount {
  address: string; balance: string; nonce: string;
  storageHash: string; codeHash: string; code: string;
  accountProof: string[];
  storageProof: Array<{ key: string; value: string; proof: string[] }>;
}

const lc = (s: string) => s.toLowerCase();

/**
 * Everything the replay must be able to read: the access list, plus the three accounts every
 * transaction touches regardless of what a node chose to report.
 */
export function touchedByCall(
  accessList: Array<{ address: string; storageKeys?: string[] }>,
  always: Array<string | undefined>,
): Map<string, Set<string>> {
  const touches = new Map<string, Set<string>>();
  for (const e of accessList) {
    const set = touches.get(lc(e.address)) ?? new Set<string>();
    for (const k of e.storageKeys ?? []) set.add(lc(k));
    touches.set(lc(e.address), set);
  }
  for (const a of always) if (a && !touches.has(lc(a))) touches.set(lc(a), new Set());
  return touches;
}

/**
 * Refuse a predicate aimed at a slot this plan never moves. The refusal prints the slots that
 * WERE touched, because a refusal that only says no leaves the reader guessing over 2^256
 * slots when the correct one is a single comparison away.
 */
export function assertPredicateSlotIsTouched(
  touches: Map<string, Set<string>>,
  check: { token: string; holder: string; balancesSlotIndex: number; slot: string },
): void {
  const touched = touches.get(lc(check.token));
  if (touched?.has(lc(check.slot))) return;
  throw new Error(
    `the call never touches the slot this predicate measures, so no execution of this plan ` +
    `can satisfy it.\n` +
    `  predicate slot  ${check.slot}\n` +
    `                  (holder ${check.holder}, balances slot index ${check.balancesSlotIndex})\n` +
    `  token           ${check.token}\n` +
    `  slots the call actually touches on that token: ` +
    `${touched && touched.size ? [...touched].join(", ") : "(none)"}\n` +
    `The two usual causes: the balances mapping is not at index ${check.balancesSlotIndex} ` +
    `for this token (that default is Circle's FiatToken layout, not a standard), or the holder ` +
    `is not the address this call credits. The guest would prove a delta of zero and return ` +
    `Failed on a correct replay, so the seller would work and not be paid. No terms were produced.`,
  );
}

/**
 * Capture the proofs NOW, in the same run. A public endpoint will not serve them for this
 * block later — measured on both Arc and Tempo — so "we can fetch it when we prove" is how a
 * bundle becomes unprovable.
 */
export async function captureWitness(
  rpc: Rpc, touches: Map<string, Set<string>>, blockNumber: string,
): Promise<WitnessAccount[]> {
  const witness: WitnessAccount[] = [];
  for (const [address, slots] of [...touches].sort(([a], [b]) => (a < b ? -1 : 1))) {
    const proof = await getProof(rpc, address, [...slots].sort(), blockNumber);
    const code = await getCode(rpc, address, blockNumber);
    witness.push({
      address, balance: proof.balance, nonce: proof.nonce,
      storageHash: proof.storageHash, codeHash: proof.codeHash, code,
      accountProof: proof.accountProof, storageProof: proof.storageProof,
    });
  }
  return witness;
}

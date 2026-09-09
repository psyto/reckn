/**
 * The predicate — the rule that decides whether a replay pays the seller or refunds the buyer.
 *
 * This is separated from `terms.ts` because it is the only part of building a deal that
 * involves no chain, no endpoint and no I/O: given four numbers it answers, and it answers the
 * same way the guest does. Everything else in `buildTerms` is transport, and mixing the two
 * meant the rule could only be exercised by driving a fake JSON-RPC endpoint.
 */

/**
 * `delta_outcome`, transcribed from `zk-verdict/lib/src/lib.rs:36` — the **only** predicate the
 * EVM guest has. `Reproduced` iff `post - pre`, saturating at zero, lies in `[min, max]`.
 *
 * It is transcribed rather than described because the refusals below are *evaluations of the
 * guest's own rule*, not comparisons against a magic constant. `min === 0n` happens to be the
 * answer today; asking the predicate means a differently-shaped one still has to answer.
 *
 * Saturation is why a *decrease* is delta 0 rather than a wrapped enormous number, and so why
 * the default `max` of 2^256-1 does not quietly admit every losing execution.
 */
export function reproduces(pre: bigint, post: bigint, min: bigint, max: bigint): boolean {
  const delta = post > pre ? post - pre : 0n;
  return delta >= min && delta <= max;
}

/** The empty execution: nothing ran, so the slot ends where it started. */
export const NOTHING_HAPPENED = { pre: 0n, post: 0n } as const;

/** The widest band, and the default when a caller names only a floor. */
export const MAX_U256 = 2n ** 256n - 1n;

/**
 * Refuse a predicate that cannot decide. Two ways it cannot, both of which **fund cleanly**
 * and are only discovered once somebody is owed money — which is why this throws rather than
 * warns, and why it runs before any request goes out: neither case depends on the chain.
 */
export function assertPredicateCanDecide(min: bigint, max: bigint): void {
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
}

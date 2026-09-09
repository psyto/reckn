/**
 * Asking the token whether it will actually pay this seller.
 *
 * Separated from `preflight.ts` because it answers a different question from the rest of the
 * preflight — everything else there reads the DEAL, and this interrogates the TOKEN — and
 * because index.ts claimed this had been separated while it was still thirty-five inline
 * lines inside `sellerPreflight`. A review caught the claim, not the code.
 */
import type { Address, Hex, PublicClient } from "viem";

export interface TokenPolicy {
  /** The questions that were answered at all. An empty list is not a clean bill of health. */
  probed: string[];
  sellerBlocked?: boolean | undefined;
  buyerBlocked?: boolean | undefined;
  paused?: boolean | undefined;
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
const POLICY_PROBES: Array<[string, string, "seller" | "buyer" | "token"]> = [
  ["isBlacklisted(address)", "0xfe575a87", "seller"],
  ["isBlacklisted(address)", "0xfe575a87", "buyer"],
  ["isFrozen(address)", "0xe5839836", "seller"],
  ["paused()", "0x5c975abb", "token"],
];

export async function probeTokenPolicy(
  publicClient: PublicClient, token: string, seller: string, buyer: string,
): Promise<TokenPolicy> {
  const policy: TokenPolicy = { probed: [] };
  for (const [name, selector, subject] of POLICY_PROBES) {
    const who = subject === "seller" ? seller : subject === "buyer" ? buyer : undefined;
    const data = who ? (selector + who.slice(2).toLowerCase().padStart(64, "0")) : selector;
    try {
      const res = await publicClient.call({ to: token as Address, data: data as Hex });
      if (!res.data || res.data === "0x") continue;
      const truthy = BigInt(res.data) === 1n;
      policy.probed.push(`${name}${who ? `(${subject})` : ""}`);
      if (subject === "seller") policy.sellerBlocked = policy.sellerBlocked || truthy;
      else if (subject === "buyer") policy.buyerBlocked = policy.buyerBlocked || truthy;
      else policy.paused = truthy;
    } catch { /* the token does not implement it; that is not a fault */ }
  }
  return policy;
}

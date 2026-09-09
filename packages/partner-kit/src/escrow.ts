/**
 * The escrow's surface, as ABI. **Three functions, and that is the whole of it.**
 *
 * `RecknZkEscrow` has no owner, no admin, no resolver, no pause and no upgrade path, and
 * `scripts/no-keys.sh` fails the build if one appears. If you are looking for the call that
 * lets someone override a verdict, it is not missing from this file — it does not exist.
 */
export const escrowAbi = [
  {
    type: "function", name: "fund", stateMutability: "nonpayable", outputs: [],
    inputs: [
      { name: "dealId", type: "bytes32" }, { name: "seller", type: "address" },
      { name: "token", type: "address" }, { name: "amount", type: "uint256" },
      { name: "verifier", type: "address" }, { name: "verifierCodeHash", type: "bytes32" },
      { name: "dealBinding", type: "bytes32" },
    ],
  },
  {
    type: "function", name: "settleWithProof", stateMutability: "nonpayable", outputs: [],
    inputs: [
      { name: "dealId", type: "bytes32" }, { name: "publicValues", type: "bytes" },
      { name: "proofBytes", type: "bytes" },
    ],
  },
  {
    type: "function", name: "refundAfterDeadline", stateMutability: "nonpayable", outputs: [],
    inputs: [{ name: "dealId", type: "bytes32" }],
  },
  {
    type: "function", name: "deals", stateMutability: "view",
    inputs: [{ name: "", type: "bytes32" }],
    outputs: [
      { name: "buyer", type: "address" }, { name: "seller", type: "address" },
      { name: "token", type: "address" }, { name: "amount", type: "uint256" },
      { name: "verifier", type: "address" }, { name: "verifierCodeHash", type: "bytes32" },
      { name: "dealBinding", type: "bytes32" }, { name: "fundedAt", type: "uint64" },
      { name: "state", type: "uint8" },
    ],
  },
  { type: "function", name: "REFUND_AFTER", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  {
    type: "event", name: "Funded",
    inputs: [
      { name: "dealId", type: "bytes32", indexed: true }, { name: "buyer", type: "address", indexed: true },
      { name: "seller", type: "address", indexed: true }, { name: "token", type: "address" },
      { name: "amount", type: "uint256" }, { name: "verifier", type: "address" },
      { name: "verifierCodeHash", type: "bytes32" }, { name: "dealBinding", type: "bytes32" },
    ],
  },
  {
    type: "event", name: "SettledByProof",
    inputs: [
      { name: "dealId", type: "bytes32", indexed: true }, { name: "to", type: "address", indexed: true },
      { name: "outcome", type: "uint8" }, { name: "traceHash", type: "bytes32" },
    ],
  },
  {
    type: "event", name: "RefundedAfterDeadline",
    inputs: [
      { name: "dealId", type: "bytes32", indexed: true }, { name: "buyer", type: "address", indexed: true },
      { name: "amount", type: "uint256" },
    ],
  },
] as const;

export const erc20Abi = [
  { type: "function", name: "approve", stateMutability: "nonpayable", inputs: [{ name: "spender", type: "address" }, { name: "value", type: "uint256" }], outputs: [{ type: "bool" }] },
  { type: "function", name: "allowance", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ type: "uint256" }] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "a", type: "address" }], outputs: [{ type: "uint256" }] },
  { type: "function", name: "decimals", stateMutability: "view", inputs: [], outputs: [{ type: "uint8" }] },
  { type: "function", name: "symbol", stateMutability: "view", inputs: [], outputs: [{ type: "string" }] },
] as const;

/** `None` is not a state a funded deal is ever in — it is what an unknown `dealId` reads as. */
export const DealState = { None: 0, Funded: 1, Settled: 2 } as const;
export const Outcome = { Reproduced: 0, Failed: 1 } as const;

export const dealStateName = (s: number): string =>
  s === 0 ? "None (no such deal)" : s === 1 ? "Funded" : s === 2 ? "Settled" : `unknown(${s})`;

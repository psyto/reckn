/**
 * The JSON-RPC boundary — the only place in this package that trusts nothing.
 *
 * Everything a node returns arrives as `unknown`. It used to arrive as `any`, spread across
 * `buildTerms`, where `block.number` and `proof.storageProof` were read straight off the wire:
 * a node that answered with the wrong shape produced `undefined` deep inside a binding
 * preimage rather than an error at the edge. The validators below are small on purpose —
 * they assert only the fields we actually read, and they name the method that misbehaved.
 *
 * The other half is telling failures apart. "This endpoint does not implement the method" and
 * "your call reverts at the anchor" are OPPOSITE problems with opposite fixes, and for a while
 * both produced the same message, which blamed the caller. Measured 2026-09-09: Arc's public
 * RPC serves neither `eth_createAccessList` nor `eth_getProof`; Tempo's Moderato RPC serves
 * both. That is a property of the endpoint — not of the chain, and not of your transaction.
 */

export type Rpc = (method: string, params: unknown[]) => Promise<any>;

/** The endpoint does not implement a method we need. Nothing is wrong with the caller's call. */
export class EndpointCapabilityError extends Error {
  readonly method: string;
  constructor(method: string, message: string) { super(message); this.name = "EndpointCapabilityError"; this.method = method; }
}
/** The call was executed and reverted at the anchor. The caller's plan is the problem. */
export class CallRevertedError extends Error {
  constructor(message: string) { super(message); this.name = "CallRevertedError"; }
}
/** Neither of the above could be established. This exists so that nothing has to guess. */
export class SimulationInconclusiveError extends Error {
  constructor(message: string) { super(message); this.name = "SimulationInconclusiveError"; }
}
/** A node answered with a shape we cannot read. */
export class MalformedResponseError extends Error {
  constructor(method: string, detail: string) {
    super(`${method} returned something this cannot read: ${detail}`);
    this.name = "MalformedResponseError";
  }
}

/**
 * Is this failure "no such method"? JSON-RPC's -32601 is the reliable signal; the text is not,
 * and every node words it differently ("method not supported" on Arc, "the method X does not
 * exist" on geth-family nodes, "Method not found" per the spec). Both are checked, and when
 * neither matches, the caller must NOT assume — see `SimulationInconclusiveError`. The first
 * version of this pattern missed "does not exist", the most common wording, and a test caught it.
 */
export function isMethodMissing(e: unknown): boolean {
  const msg = (e as Error | undefined)?.message ?? String(e);
  const code = (e as { code?: number } | undefined)?.code;
  return code === -32601 ||
    /(-32601)|method[^\n]*(not (found|supported|available)|does not exist|unsupported)/i.test(msg);
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null;
const isHex = (v: unknown): v is string => typeof v === "string" && /^0x[0-9a-fA-F]*$/.test(v);

export interface BlockHeader {
  number: string; hash: string; stateRoot: string; timestamp: string; gasLimit: string;
  miner: string; baseFeePerGas?: string; mixHash?: string; difficulty?: string;
}

export async function getBlock(rpc: Rpc, tag: string): Promise<BlockHeader> {
  const b: unknown = await rpc("eth_getBlockByNumber", [tag, false]);
  if (!isObj(b)) throw new Error(`no block at ${tag}`);
  for (const f of ["number", "hash", "stateRoot", "timestamp", "gasLimit", "miner"]) {
    if (typeof b[f] !== "string") throw new MalformedResponseError("eth_getBlockByNumber", `missing ${f}`);
  }
  return b as unknown as BlockHeader;
}

export async function getChainId(rpc: Rpc): Promise<number> {
  const raw: unknown = await rpc("eth_chainId", []);
  const n = Number(raw);
  if (!Number.isFinite(n)) throw new MalformedResponseError("eth_chainId", String(raw));
  return n;
}

export interface AccessListResult {
  accessList: Array<{ address: string; storageKeys: string[] }>;
  /** What the node charged the simulated call. Reported, never used to decide anything. */
  gasUsed: string;
}

/**
 * Simulate, and classify the three ways it can fail. `eth_createAccessList` executes the call
 * and reports what it touched, so one request both proves the call succeeds and enumerates the
 * witness — which is why it is worth needing an endpoint that has it.
 */
export async function createAccessList(rpc: Rpc, tx: unknown, blockNumber: string): Promise<AccessListResult> {
  let res: unknown;
  try {
    res = await rpc("eth_createAccessList", [tx, blockNumber]);
  } catch (e) {
    if (isMethodMissing(e)) {
      throw new EndpointCapabilityError("eth_createAccessList",
        `this endpoint cannot simulate: it does not implement eth_createAccessList.\n` +
        `  endpoint  ${(e as Error).message ?? String(e)}\n` +
        `Nothing is wrong with your call — the node will not answer the question. Terms need an ` +
        `endpoint that serves eth_createAccessList AND eth_getProof; a node you run yourself, or ` +
        `an archive provider, will. Measured 2026-09-09: Arc's public RPC serves neither; ` +
        `Tempo's Moderato RPC serves both.\n` +
        `What still works without them: the deal BINDING commits only stateRoot, env, check and ` +
        `plan, so it needs one eth_getBlockByNumber. You can compute and fund terms from this ` +
        `endpoint; what you cannot do here is prove the call succeeds, or capture the witness ` +
        `the prover will need.`);
    }
    throw new SimulationInconclusiveError(
      `the simulation at block ${blockNumber} did not complete, and this cannot tell you why.\n` +
      `  raw error  ${(e as Error).message ?? String(e)}\n` +
      `It is one of two unrelated things: your call fails at the anchor, or this endpoint will ` +
      `not answer. Terms need an endpoint serving eth_createAccessList and eth_getProof — check ` +
      `that first, because it is the cheaper of the two to rule out. No terms were produced.`);
  }
  if (isObj(res) && res["error"]) {
    throw new CallRevertedError(
      `the call REVERTS at block ${blockNumber}: ${String(res["error"])}\n` +
      `Terms were not produced. Fix the call, or pick an anchor where it succeeds.`);
  }
  const list = isObj(res) ? res["accessList"] : undefined;
  const gasUsed = isObj(res) && typeof res["gasUsed"] === "string" ? res["gasUsed"] : "0x0";
  return { accessList: Array.isArray(list) ? (list as AccessListResult["accessList"]) : [], gasUsed };
}

export interface ProofResult {
  balance: string; nonce: string; storageHash: string; codeHash: string;
  accountProof: string[];
  storageProof: Array<{ key: string; value: string; proof: string[] }>;
}

export async function getProof(rpc: Rpc, address: string, keys: string[], blockNumber: string): Promise<ProofResult> {
  let p: unknown;
  try {
    p = await rpc("eth_getProof", [address, keys, blockNumber]);
  } catch (e) {
    if (isMethodMissing(e)) {
      throw new EndpointCapabilityError("eth_getProof",
        `this endpoint cannot capture a witness: it does not implement eth_getProof.\n` +
        `  endpoint  ${(e as Error).message ?? String(e)}\n` +
        `The simulation already succeeded, so your call is fine. Without the proofs, a prover ` +
        `has nothing to replay against, and public endpoints do not serve them for a past ` +
        `block later — which is why they are captured now rather than when you prove.`);
    }
    throw e;
  }
  if (!isObj(p)) throw new MalformedResponseError("eth_getProof", "not an object");
  for (const f of ["balance", "nonce", "storageHash", "codeHash"]) {
    if (typeof p[f] !== "string") throw new MalformedResponseError("eth_getProof", `missing ${f} for ${address}`);
  }
  if (!Array.isArray(p["accountProof"])) throw new MalformedResponseError("eth_getProof", `no accountProof for ${address}`);
  const sp = Array.isArray(p["storageProof"]) ? p["storageProof"] : [];
  return {
    balance: p["balance"] as string, nonce: p["nonce"] as string,
    storageHash: p["storageHash"] as string, codeHash: p["codeHash"] as string,
    accountProof: p["accountProof"] as string[],
    storageProof: sp.map((s: unknown) => {
      if (!isObj(s) || typeof s["key"] !== "string") throw new MalformedResponseError("eth_getProof", `bad storageProof entry for ${address}`);
      return { key: s["key"] as string, value: String(s["value"] ?? "0x0"), proof: Array.isArray(s["proof"]) ? s["proof"] as string[] : [] };
    }),
  };
}

export async function getCode(rpc: Rpc, address: string, blockNumber: string): Promise<string> {
  const c: unknown = await rpc("eth_getCode", [address, blockNumber]);
  if (!isHex(c)) throw new MalformedResponseError("eth_getCode", `not hex for ${address}`);
  return c;
}

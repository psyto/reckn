/**
 * The EVM deal binding — a **third independent transcription**.
 *
 * `docs/integrate.md` states the rule this file follows, and it is the reason this is not a
 * thin wrapper around the Rust:
 *
 *   > Two independent transcriptions make an error surface as a *mismatch*; one shared
 *   > implementation makes the same error surface as *agreement*, which is indistinguishable
 *   > from correctness.
 *
 * So: the guest computes the binding inside SP1 (`zk-verdict/program-revm/src/main.rs`), the
 * Rust host transcribes it (`verdict_script::evm_deal_binding`), and this transcribes it
 * again. All three must agree, and `test/binding.golden.test.ts` requires this one to
 * reproduce, byte for byte, vectors whose expected value came out of the guest.
 *
 * **If that test does not pass, do not use this module.** Use `bindingViaRust()` in
 * `./binding-cli.ts`, which shells out to the Rust implementation instead. An unverified
 * re-implementation of the value that decides who gets paid is worse than no implementation.
 *
 * The only dependency here is a keccak, deliberately: the part that decides a payment should
 * not pull in a chain client to compute a hash.
 */
import { keccak_256 } from "@noble/hashes/sha3";

/** Big-endian u64. JS numbers cannot hold one, so every such field is a bigint. */
function u64be(value: bigint): Uint8Array {
  if (value < 0n || value > 0xffff_ffff_ffff_ffffn) throw new RangeError(`not a u64: ${value}`);
  const out = new Uint8Array(8);
  for (let i = 7; i >= 0; i--) { out[i] = Number(value & 0xffn); value >>= 8n; }
  return out;
}

function bytes(hex: string, expected: number): Uint8Array {
  const s = hex.startsWith("0x") || hex.startsWith("0X") ? hex.slice(2) : hex;
  if (!/^[0-9a-fA-F]*$/.test(s)) throw new TypeError(`not hex: ${hex}`);
  if (s.length !== expected * 2) {
    throw new RangeError(`expected ${expected} bytes, got ${s.length / 2}: ${hex}`);
  }
  const out = new Uint8Array(expected);
  for (let i = 0; i < expected; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
}

/** Arbitrary-length hex, for calldata. */
function varBytes(hex: string): Uint8Array {
  const s = hex.startsWith("0x") || hex.startsWith("0X") ? hex.slice(2) : hex;
  if (!/^[0-9a-fA-F]*$/.test(s) || s.length % 2 !== 0) throw new TypeError(`not hex bytes: ${hex}`);
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
}

const ascii = (s: string): Uint8Array => new TextEncoder().encode(s);

function concat(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; }
  return out;
}

const hex = (b: Uint8Array): `0x${string}` =>
  `0x${Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("")}` as `0x${string}`;

/**
 * The block environment the re-execution is pinned to. Every field is committed: a proof
 * produced under a different `timestamp` carries a different binding and cannot settle.
 */
export interface EvmEnv {
  chainId: bigint;
  /** revm `SpecId` as its u8 discriminant — the hardfork the guest executes under. */
  specId: number;
  blockNumber: bigint;
  timestamp: bigint;
  baseFee: bigint;
  blockGasLimit: bigint;
  /** 20-byte hex. */ coinbase: string;
  /** 32-byte hex. */ prevrandao: string;
}

/** The predicate: one storage slot must rise by at least `min` and at most `max`. */
export interface EvmCheck {
  /** 20-byte hex — the contract whose storage is checked (e.g. the output token). */
  address: string;
  /** 32-byte hex — the slot (e.g. `keccak256(abi.encode(recipient, balancesSlot))`). */
  slot: string;
  /** 32-byte hex, big-endian. */ min: string;
  /** 32-byte hex, big-endian. */ max: string;
}

/** The single CALL that is replayed. */
export interface EvmPlan {
  /** 20-byte hex. */ caller: string;
  /** 20-byte hex. */ target: string;
  /** 32-byte hex, big-endian. */ value: string;
  gasLimit: bigint;
  /** arbitrary-length hex. */ calldata: string;
}

export interface EvmDealTerms {
  /** 32-byte hex — the state root the prestate witness is proven against. */
  stateRoot: string;
  env: EvmEnv;
  check: EvmCheck;
  plan: EvmPlan;
}

/**
 * Compute the `dealBinding` a buyer passes to `fund()` — **before** the seller works and
 * without a prover.
 *
 * Transcribed from the guest. The four domain tags and the field order are part of the
 * consensus value; changing any of them changes every binding.
 */
export function evmDealBinding(terms: EvmDealTerms): `0x${string}` {
  const { stateRoot, env, check, plan } = terms;

  const envHash = keccak_256(concat([
    ascii("reckn/zk/env/evm/v2"),
    u64be(env.chainId),
    Uint8Array.of(env.specId & 0xff),
    u64be(env.blockNumber),
    u64be(env.timestamp),
    u64be(env.baseFee),
    u64be(env.blockGasLimit),
    bytes(env.coinbase, 20),
    bytes(env.prevrandao, 32),
  ]));

  const checkHash = keccak_256(concat([
    ascii("reckn/zk/check/evm/v2"),
    bytes(check.address, 20),
    bytes(check.slot, 32),
    bytes(check.min, 32),
    bytes(check.max, 32),
  ]));

  const calldata = varBytes(plan.calldata);
  // The length is a u64 big-endian word, NOT a platform-sized integer. The Rust carries the
  // same warning: on a 32-bit host a naive `len().to_be_bytes()` is four bytes and every
  // binding differs. In JS the equivalent trap is emitting a JS number.
  const planHash = keccak_256(concat([
    ascii("reckn/zk/plan/evm/v2"),
    bytes(plan.caller, 20),
    bytes(plan.target, 20),
    bytes(plan.value, 32),
    u64be(plan.gasLimit),
    u64be(BigInt(calldata.length)),
    calldata,
  ]));

  return hex(keccak_256(concat([
    ascii("reckn/zk/bind/evm/v2"),
    bytes(stateRoot, 32),
    envHash,
    checkHash,
    planHash,
  ])));
}

/**
 * The storage slot of `balanceOf[holder]` for a Solidity `mapping(address => uint256)` at
 * `slotIndex` — which is how a "the recipient received at least X of token T" predicate is
 * expressed. Verified against a real mainnet swap's access list: for USDC (`slotIndex` 9)
 * this is the slot the transfer actually writes.
 */
export function erc20BalanceSlot(holder: string, slotIndex: number | bigint): `0x${string}` {
  const idx = BigInt(slotIndex);
  const word = new Uint8Array(32);
  let v = idx;
  for (let i = 31; i >= 0 && v > 0n; i--) { word[i] = Number(v & 0xffn); v >>= 8n; }
  const padded = new Uint8Array(32);
  padded.set(bytes(holder, 20), 12);
  return hex(keccak_256(concat([padded, word])));
}

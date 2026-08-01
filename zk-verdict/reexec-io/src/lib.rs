//! Shared host↔guest input for the **full re-execution** ZK verdict. Deliberately
//! primitive (fixed byte arrays, no alloy/revm types) so it serializes with plain
//! bincode and both sides agree byte-for-byte. The guest converts these into revm
//! types, **verifies the prestate against a committed `state_root` (MPT proofs)**,
//! seeds an in-memory DB, executes the CALL, and derives the post-state — so both
//! the prestate authenticity AND `post` are established *under proof*, not trusted.
#![no_std]
extern crate alloc;
use alloc::vec::Vec;
use serde::{Deserialize, Serialize};

/// One committed storage slot with its MPT proof against the account storage root.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GuestStorage {
    pub slot: [u8; 32],
    pub value: [u8; 32],
    /// RLP-encoded trie nodes proving `slot -> value` under `storage_root`.
    pub proof: Vec<Vec<u8>>,
}

/// One committed prestate account, with the material needed to prove it authentic
/// against the anchor `state_root` (mirrors `reexec-evm`'s `AccountWitness`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GuestAccount {
    pub address: [u8; 20],
    pub balance: [u8; 32],
    pub nonce: u64,
    /// Runtime code (empty for an EOA). Its keccak must equal `code_hash`.
    pub code: Vec<u8>,
    /// Proven account storage root (part of the account leaf).
    pub storage_root: [u8; 32],
    /// keccak256(code); part of the account leaf.
    pub code_hash: [u8; 32],
    /// RLP-encoded trie nodes proving this account under `state_root`.
    pub account_proof: Vec<Vec<u8>>,
    pub storage: Vec<GuestStorage>,
}

/// The seller's committed CALL plan.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GuestPlan {
    pub caller: [u8; 20],
    pub target: [u8; 20],
    pub calldata: Vec<u8>,
    pub value: [u8; 32],
    pub gas_limit: u64,
}

/// A causal delta check on one storage slot: after execution, `post - pre`
/// (saturating) must lie in `[min, max]`. `pre` is the committed prestate value
/// of the slot; `post` is what the guest's re-execution produces.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeltaCheck {
    pub address: [u8; 20],
    pub slot: [u8; 32],
    pub min: u64,
    pub max: u64,
}

/// Everything the guest needs to prove prestate authenticity, re-execute, and
/// adjudicate one deal.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GuestInput {
    pub chain_id: u64,
    /// The committed anchor state root the prestate is proven against, and which
    /// the verdict's trace hash binds — so the proof is *about a specific state*.
    pub state_root: [u8; 32],
    pub accounts: Vec<GuestAccount>,
    pub plan: GuestPlan,
    /// One delta check, mapped 1:1 to the on-chain `VerdictPublicValues`.
    pub check: DeltaCheck,
}

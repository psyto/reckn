//! Shared host↔guest input for the **full re-execution** ZK verdict. Deliberately
//! primitive (fixed byte arrays, no alloy/revm types) so it serializes with plain
//! bincode and both sides agree byte-for-byte. The guest converts these into revm
//! types, seeds an in-memory DB, executes the CALL, and derives the post-state —
//! so `post` is *computed under proof*, not trusted.
#![no_std]
extern crate alloc;
use alloc::vec::Vec;
use serde::{Deserialize, Serialize};

/// One committed prestate account (execution material only — MPT authenticity vs
/// a state root is the off-chain layer, orthogonal to proving the execution).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GuestAccount {
    pub address: [u8; 20],
    pub balance: [u8; 32],
    pub nonce: u64,
    /// Runtime code (empty for an EOA).
    pub code: Vec<u8>,
    /// Committed storage: (slot, value), each a 32-byte big-endian word.
    pub storage: Vec<([u8; 32], [u8; 32])>,
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

/// Everything the guest needs to re-execute and adjudicate one deal.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GuestInput {
    pub chain_id: u64,
    pub accounts: Vec<GuestAccount>,
    pub plan: GuestPlan,
    /// One delta check, mapped 1:1 to the on-chain `VerdictPublicValues`.
    pub check: DeltaCheck,
}

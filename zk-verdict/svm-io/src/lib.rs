//! Shared host↔guest input for the **SVM re-execution** ZK verdict (the Solana
//! mirror of `program-revm`). Primitive types only — the committed transaction is
//! passed separately as a real `solana_transaction::Transaction` (both sides use
//! the same serde impl), and these carry the committed prestate accounts + the
//! delta check.
#![no_std]
extern crate alloc;
use alloc::vec::Vec;
use serde::{Deserialize, Serialize};

/// One committed prestate account. Carries the full fields the SIMD-0215 lattice
/// hash commits to, so the guest can recompute `bank_hash` and prove authenticity.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SvmAccount {
    pub pubkey: [u8; 32],
    pub lamports: u64,
    pub owner: [u8; 32],
    pub executable: bool,
    /// Account data (a System-owned account funding a transfer must carry none).
    pub data: Vec<u8>,
}

/// A causal lamports delta check: after execution, `post - pre` (saturating) on
/// `account` must lie in `[min, max]`. Mirrors `reexec-svm`'s `LamportsDelta`.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SvmCheck {
    pub account: [u8; 32],
    pub min: u64,
    pub max: u64,
}

/// The committed prestate + check + the `bank_hash` authenticity material. The
/// guest recomputes `bank_hash` from `accounts` and the preimage and requires it to
/// equal `bank_hash` before trusting any account — the SVM analogue of the EVM
/// state-root MPT check. The transaction is read separately.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SvmPrestate {
    pub accounts: Vec<SvmAccount>,
    pub check: SvmCheck,
    /// Post-SIMD-0215 `bank_hash` preimage (block fields other than the accounts).
    pub parent_bank_hash: [u8; 32],
    pub signature_count: u64,
    pub last_blockhash: [u8; 32],
    /// The committed block `bank_hash` the accounts must reproduce.
    pub bank_hash: [u8; 32],
}

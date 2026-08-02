//! Shared host↔guest input for the **SVM re-execution** ZK verdict (the Solana
//! mirror of `program-revm`). Primitive types only — the committed transaction is
//! passed separately as a real `solana_transaction::Transaction` (both sides use
//! the same serde impl), and these carry the committed prestate accounts + the
//! delta check.
#![no_std]
extern crate alloc;
use alloc::vec::Vec;
use serde::{Deserialize, Serialize};

/// One committed prestate account (the lamports the guest re-executes against).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SvmAccount {
    pub pubkey: [u8; 32],
    pub lamports: u64,
    pub owner: [u8; 32],
    /// Data length (a System-owned account funding a transfer must carry no data).
    pub data_len: u64,
}

/// A causal lamports delta check: after execution, `post - pre` (saturating) on
/// `account` must lie in `[min, max]`. Mirrors `reexec-svm`'s `LamportsDelta`.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SvmCheck {
    pub account: [u8; 32],
    pub min: u64,
    pub max: u64,
}

/// The committed prestate + check. The transaction is read separately.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SvmPrestate {
    pub accounts: Vec<SvmAccount>,
    pub check: SvmCheck,
}

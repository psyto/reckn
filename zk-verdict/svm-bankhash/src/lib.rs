//! In-guest recomputation of Solana's post-SIMD-0215 `bank_hash` from a committed
//! account set — the SVM analogue of the EVM MPT check. Byte-for-byte identical to
//! `reexec-svm::bankhash` (same lattice primitive, same field order), so the guest
//! verifies exactly what the off-chain backend computes. Shared by guest and host
//! so the two cannot drift.

use sha2::{Digest, Sha256};
use solana_lattice_hash::lt_hash::LtHash;
use svm_io::SvmAccount;

/// SIMD-0215 per-account lattice contribution: blake3 over
/// `lamports(LE) ‖ data ‖ executable(1) ‖ owner(32) ‖ pubkey(32)`; `rent_epoch`
/// excluded, and a zero-lamport account contributes the lattice identity.
pub fn account_lt_hash(a: &SvmAccount) -> LtHash {
    if a.lamports == 0 {
        return LtHash::identity();
    }
    let mut h = blake3::Hasher::new();
    h.update(&a.lamports.to_le_bytes());
    h.update(&a.data);
    h.update(&[a.executable as u8]);
    h.update(&a.owner);
    h.update(&a.pubkey);
    LtHash::with(&h)
}

/// `bank_hash = sha256(parent_bank_hash ‖ lt_checksum ‖ signature_count(u64 LE) ‖
/// last_blockhash)`, where `lt_checksum` is the checksum of the homomorphic sum of
/// every account's contribution (order-independent).
pub fn compute_bank_hash(
    accounts: &[SvmAccount],
    parent_bank_hash: &[u8; 32],
    signature_count: u64,
    last_blockhash: &[u8; 32],
) -> [u8; 32] {
    let mut acc = LtHash::identity();
    for a in accounts {
        acc.mix_in(&account_lt_hash(a));
    }
    let checksum = acc.checksum();

    let mut h = Sha256::new();
    h.update(parent_bank_hash);
    h.update(checksum.0);
    h.update(signature_count.to_le_bytes());
    h.update(last_blockhash);
    let mut out = [0u8; 32];
    out.copy_from_slice(&h.finalize());
    out
}

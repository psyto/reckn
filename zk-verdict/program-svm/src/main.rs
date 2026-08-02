//! The **SVM re-execution** zkVM guest — the Solana mirror of `program-revm`.
//!
//! reckn's Solana backend adjudicates System-program transactions only (its closed
//! runtime profile permits just the System builtin — no custom SBF). This guest
//! does the same under proof: it (1) **signature-verifies the real committed
//! transaction** in-guest (`Transaction::verify`, real ed25519), (2) applies the
//! **System transfer semantics** to the committed prestate accounts to derive the
//! post-lamports, and (3) applies reckn's causal `LamportsDelta`. So `post` is
//! *computed by re-executing the transfer under proof*, not trusted from a
//! resolver. It commits the same `VerdictPublicValues` the on-chain
//! `RecknVerdictVerifier` consumes.
//!
//! Scope: the full Agave/LiteSVM runtime is not run in-zk (JIT/OS-bound) and is
//! unnecessary — reckn permits only the System builtin. Custom SBF bytecode and
//! prestate `bank_hash` authenticity (the SVM analogue of the EVM MPT check) are
//! the documented follow-ups.

#![no_main]
sp1_zkvm::entrypoint!(main);

use alloy_sol_types::SolType;
use solana_transaction::Transaction;
use svm_io::SvmPrestate;
use verdict_lib::{delta_outcome, verdict_trace_hash, VerdictPublicValues, FAILED};

const SYSTEM_PROGRAM: [u8; 32] = [0u8; 32];

pub fn main() {
    let tx = sp1_zkvm::io::read::<Transaction>();
    let prestate = sp1_zkvm::io::read::<SvmPrestate>();

    // 0. Prove the prestate is authentic: recompute the block `bank_hash` from the
    //    committed accounts (SIMD-0215 lattice hash) and require it to match the
    //    committed one. A valid proof cannot exist for a tampered account set.
    let got_bank_hash = svm_bankhash::compute_bank_hash(
        &prestate.accounts,
        &prestate.parent_bank_hash,
        prestate.signature_count,
        &prestate.last_blockhash,
    );
    assert_eq!(got_bank_hash, prestate.bank_hash, "bank_hash authenticity");

    // 1. Signer bits are authority in the SVM: verify the real signatures in-guest.
    let mut exec_ok = tx.verify().is_ok();

    // Working lamports/owner/data_len map, seeded from the committed prestate.
    // (pubkey, lamports, owner, data_len)
    let mut accts: Vec<([u8; 32], u64, [u8; 32], u64)> = prestate
        .accounts
        .iter()
        .map(|a| (a.pubkey, a.lamports, a.owner, a.data.len() as u64))
        .collect();
    let find = |accts: &Vec<([u8; 32], u64, [u8; 32], u64)>, k: &[u8; 32]| -> Option<usize> {
        accts.iter().position(|e| &e.0 == k)
    };

    let msg = &tx.message;
    let num_sig = msg.header.num_required_signatures as usize;

    // 2. Re-execute each instruction. reckn's closed profile permits ONLY the System
    //    builtin; anything else is an operational failure (Failed verdict here).
    if exec_ok {
        for ix in &msg.instructions {
            let prog: [u8; 32] = msg.account_keys[ix.program_id_index as usize].to_bytes();
            if prog != SYSTEM_PROGRAM {
                exec_ok = false;
                break;
            }
            // System instruction wire format: 4-byte LE tag + payload. Transfer
            // (tag 2) carries an 8-byte LE lamports value — decoded exactly as reckn
            // encodes it. Other System instructions (CreateAccount/Assign/...) don't
            // move lamports for the adjudicated recipient, so they're inert here.
            if ix.data.len() >= 12 && ix.data[0..4] == [2, 0, 0, 0] {
                let mut le = [0u8; 8];
                le.copy_from_slice(&ix.data[4..12]);
                let lamports = u64::from_le_bytes(le);

                let from_idx = ix.accounts[0] as usize;
                let to_idx = ix.accounts[1] as usize;
                let from_key = msg.account_keys[from_idx].to_bytes();
                let to_key = msg.account_keys[to_idx].to_bytes();

                // System transfer rules (Agave): `from` is a signer, is owned by the
                // System program, carries no data, and has the funds.
                let from_is_signer = from_idx < num_sig;
                let (fi, ti) = match (find(&accts, &from_key), find(&accts, &to_key)) {
                    (Some(fi), Some(ti)) => (fi, ti),
                    _ => {
                        exec_ok = false;
                        break;
                    }
                };
                let ok = from_is_signer
                    && accts[fi].2 == SYSTEM_PROGRAM
                    && accts[fi].3 == 0
                    && accts[fi].1 >= lamports;
                if !ok {
                    exec_ok = false;
                    break;
                }
                accts[fi].1 -= lamports;
                accts[ti].1 += lamports;
            }
        }
    }

    // 3. Causal lamports delta on the checked account: pre from the committed
    //    prestate, post from the re-executed balances.
    let check = &prestate.check;
    let pre = prestate
        .accounts
        .iter()
        .find(|a| a.pubkey == check.account)
        .map(|a| a.lamports)
        .unwrap_or(0);
    let post = if exec_ok {
        find(&accts, &check.account).map(|i| accts[i].1).unwrap_or(pre)
    } else {
        pre
    };

    let outcome = if exec_ok {
        delta_outcome(pre, post, check.min, check.max)
    } else {
        FAILED
    };
    let trace = verdict_trace_hash(pre, post, check.min, check.max, outcome);

    // Deal binding: commit the authenticated bank_hash + the predicate + the signed
    // transaction (via its signature), so an escrow can require a proof to be about
    // its exact committed deal.
    use sha2::{Digest, Sha256};
    let mut bh = Sha256::new();
    bh.update(b"reckn/zk/bind/svm/v1");
    bh.update(prestate.bank_hash);
    bh.update(check.account);
    bh.update(check.min.to_le_bytes());
    bh.update(check.max.to_le_bytes());
    bh.update(tx.signatures[0].as_ref());
    let mut deal_binding = [0u8; 32];
    deal_binding.copy_from_slice(&bh.finalize());

    let bytes = VerdictPublicValues::abi_encode(&VerdictPublicValues {
        pre,
        post,
        minDelta: check.min,
        maxDelta: check.max,
        outcome,
        traceHash: trace.into(),
        dealBinding: deal_binding.into(),
    });
    sp1_zkvm::io::commit_slice(&bytes);
}

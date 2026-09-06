#![allow(non_snake_case)]
//! L-5, closed: the SVM deal's terms are computable by someone who is not the prover.
//!
//! `docs/specs/009-cross-vm-settlement.md` recorded that the repository contained
//! **one** implementation of the SVM binding formula — the guest — so *"either party
//! can independently compute the deal's terms"* was a claim, and the demo funded a
//! deal by copying `deal_binding` out of a fixture the prover produced. That is a
//! real trust gap: a seller who cannot compute the binding cannot check what they are
//! being asked to work for.
//!
//! These tests close it against the SHIPPED artifact. The binding is recomputed from
//! the five deal terms by `verdict_script::svm_deal_binding` — a second
//! transcription, not a helper shared with the guest — and required to equal the
//! `deal_binding` inside `svm-groth16-fixture.json`, the same bytes that settled
//! 1.000000 USDC on Arc testnet.

use std::path::PathBuf;
use verdict_script::{svm_deal_binding, svm_demo_terms, SvmDealTerms};

/// The demo deal the committed fixture was produced from.
const AMOUNT: u64 = 2_000_000;
const MIN: u64 = 1_000_000;

fn fixture_binding() -> [u8; 32] {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../contracts/src/fixtures/svm-groth16-fixture.json");
    let text = std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("a missing fixture is a hard failure: {} — {e}", path.display()));
    let json: serde_json::Value = serde_json::from_str(&text).expect("fixture is JSON");
    let hex = json["deal_binding"].as_str().expect("fixture carries deal_binding");
    let bytes = hex::decode(hex.trim_start_matches("0x")).expect("deal_binding is hex");
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    out
}

/// The one that matters: the shipped proof's binding, recomputed from the deal terms
/// alone, by code that never runs the guest.
#[test]
fn test_SVMBIND_the_shipped_binding_is_recomputable_without_the_prover() {
    let terms = svm_demo_terms(AMOUNT, MIN);
    assert_eq!(
        svm_deal_binding(&terms),
        fixture_binding(),
        "the host-side transcription disagrees with what the guest committed — one of \
         the two implementations is wrong, and until they agree a seller cannot check \
         a deal without trusting the prover"
    );
}

/// Every term is load-bearing. If any of the five could be changed without moving the
/// binding, a deal could be re-pointed at different work after it was agreed.
#[test]
fn test_SVMBIND_every_term_moves_the_binding() {
    let base = svm_demo_terms(AMOUNT, MIN);
    let baseline = svm_deal_binding(&base);

    let mut bank = base.clone();
    bank.bank_hash[0] ^= 1;
    assert_ne!(svm_deal_binding(&bank), baseline, "bank_hash is not bound");

    let mut account = base.clone();
    account.account[31] ^= 1;
    assert_ne!(svm_deal_binding(&account), baseline, "the checked account is not bound");

    let mut min = base.clone();
    min.min += 1;
    assert_ne!(svm_deal_binding(&min), baseline, "the floor is not bound");

    let mut max = base.clone();
    max.max -= 1;
    assert_ne!(svm_deal_binding(&max), baseline, "the ceiling is not bound");

    let mut sig = base.clone();
    sig.signature[0] ^= 1;
    assert_ne!(svm_deal_binding(&sig), baseline, "the delivered transaction is not bound");
}

/// The width trap this second implementation exists to catch: `min` and `max` are
/// `u64` in the input struct and enter the preimage as 32-byte big-endian words. A
/// transcription that hashed them as eight bytes would produce a plausible binding
/// that no proof can ever match — and nothing else in the repository would notice.
#[test]
fn test_SVMBIND_the_widths_are_the_ones_the_guest_uses() {
    use sha2::{Digest, Sha256};
    let terms = svm_demo_terms(AMOUNT, MIN);

    let mut narrow = Sha256::new();
    narrow.update(b"reckn/zk/bind/svm/v2");
    narrow.update(terms.bank_hash);
    narrow.update(terms.account);
    narrow.update(terms.min.to_be_bytes()); // 8 bytes — the mistake
    narrow.update(terms.max.to_be_bytes());
    narrow.update(terms.signature);
    let narrow: [u8; 32] = narrow.finalize().into();

    assert_ne!(narrow, fixture_binding(), "the eight-byte encoding must NOT match");
    assert_eq!(svm_deal_binding(&terms), fixture_binding(), "the 32-byte one must");
}

/// A seller checks a deal by comparing what they compute against what the deal says.
/// This is that check, written as the seller would run it.
#[test]
fn test_SVMBIND_a_seller_can_reject_a_deal_bound_to_other_work() {
    let honest = svm_demo_terms(AMOUNT, MIN);
    let offered_by_the_buyer = fixture_binding();
    assert_eq!(svm_deal_binding(&honest), offered_by_the_buyer, "the honest deal checks out");

    // The same deal, but the buyer quietly raised the floor: the seller would have to
    // credit more than agreed to be paid. Recomputing catches it before any work.
    let moved = SvmDealTerms { min: MIN + 1, ..honest };
    assert_ne!(
        svm_deal_binding(&moved),
        offered_by_the_buyer,
        "a seller who recomputes sees that the binding is not the deal they were shown"
    );
}

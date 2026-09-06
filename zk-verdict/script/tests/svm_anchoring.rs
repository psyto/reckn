#![allow(non_snake_case)]
//! L-1, made concrete instead of described.
//!
//! The SVM guest recomputes the block's `bank_hash` from the committed account set
//! and refuses to trust an account until that hash matches. The honest scope has
//! always said this is *conclusive only over a **complete** account set, and the demo
//! treats its committed set as the world*. That sentence is easy to read past. These
//! tests make it a measurement, in both directions:
//!
//! 1. an **incomplete** set cannot claim the real set's hash — so the check does
//!    catch a prover who quietly drops an account from a world that already exists;
//! 2. a **fabricated** set produces a perfectly valid `bank_hash` **of its own** —
//!    so the check proves internal consistency, **not provenance**. Nothing in it
//!    references a real cluster, and nothing here claims otherwise.
//!
//! (2) is L-1. It is not closed by this file and closing it needs the whole account
//! world, which is why the limitation stays in `zk-verdict/README.md`. What changes
//! is that its boundary is now pinned by a test rather than by a paragraph.

use svm_io::SvmAccount;

fn account(tag: u8, lamports: u64) -> SvmAccount {
    SvmAccount {
        pubkey: [tag; 32],
        lamports,
        owner: [0u8; 32],
        executable: false,
        data: Vec::new(),
    }
}

const PARENT: [u8; 32] = [0x11u8; 32];
const BLOCKHASH: [u8; 32] = [0u8; 32];

fn hash(accounts: &[SvmAccount]) -> [u8; 32] {
    svm_bankhash::compute_bank_hash(accounts, &PARENT, 1, &BLOCKHASH)
}

/// Direction one: dropping an account from a world moves that world's hash, so a
/// prestate that omits an account cannot pass itself off as the full one.
#[test]
fn test_SVMANCHOR_an_incomplete_set_cannot_claim_the_complete_sets_hash() {
    let world = vec![account(0xaa, 1_000_000_000), account(0x09, 1), account(0x0c, 42)];
    let missing_one = vec![account(0xaa, 1_000_000_000), account(0x09, 1)];

    assert_ne!(
        hash(&world),
        hash(&missing_one),
        "an account could be dropped without moving the bank_hash — the authenticity \
         check would then be blind to a prover who hides an account"
    );

    // And a perturbed balance moves it too: this is the check the guest's
    // `--tamper-prestate` path exercises end to end.
    let mut perturbed = world.clone();
    perturbed[1].lamports += 1;
    assert_ne!(hash(&world), hash(&perturbed), "a lamport change is not bound");
}

/// Direction two, and this is L-1 itself: a set nobody ever saw on a cluster hashes
/// perfectly well. The guest would accept it and produce a verdict about it.
///
/// So **"settled by a Solana proof" means "settled by a proof about a Solana-shaped
/// state the deal named"** — the phrasing used in the README and in the submission —
/// and not "about Solana". The proof is sound over the world it was given; what it
/// does not carry is evidence that the world was real.
#[test]
fn test_SVMANCHOR_a_world_we_invented_hashes_just_as_well_as_a_real_one() {
    let invented = vec![
        account(0xf0, 999_999_999_999),
        account(0xf1, 7),
        account(0xf2, 0),
    ];
    let h = hash(&invented);

    assert_ne!(h, [0u8; 32], "the fabricated world produced a hash");
    assert_eq!(h, hash(&invented), "and the computation is deterministic over it");

    // The point, stated as an assertion so it cannot be quietly dropped: there is no
    // input to this computation that could distinguish the fabricated world from a
    // real one. It sees accounts, a parent hash, a signature count and a blockhash —
    // all supplied by whoever built the prestate.
    let real_looking = vec![account(0xaa, 1_000_000_000), account(0x09, 1)];
    assert_ne!(h, hash(&real_looking), "different worlds, different hashes");
    assert!(
        hash(&invented) == h && hash(&real_looking) != h,
        "both are valid bank_hashes of their own account sets; provenance is not an \
         input, and therefore not a conclusion"
    );
}

/// The parent hash and the blockhash are inputs a prestate builder supplies, so they
/// do not anchor anything either — pinned here so nobody later mistakes them for a
/// link to a real chain.
#[test]
fn test_SVMANCHOR_the_parent_hash_and_blockhash_are_inputs_not_anchors() {
    let accounts = vec![account(0xaa, 1_000_000_000), account(0x09, 1)];
    let base = hash(&accounts);

    let other_parent = svm_bankhash::compute_bank_hash(&accounts, &[0x22u8; 32], 1, &BLOCKHASH);
    let other_blockhash = svm_bankhash::compute_bank_hash(&accounts, &PARENT, 1, &[0x33u8; 32]);
    let other_sigcount = svm_bankhash::compute_bank_hash(&accounts, &PARENT, 2, &BLOCKHASH);

    assert_ne!(base, other_parent, "the parent hash is bound into the result");
    assert_ne!(base, other_blockhash, "the blockhash is bound");
    assert_ne!(base, other_sigcount, "the signature count is bound");
    // Bound, yes — but supplied by the same party that supplies the accounts. Being
    // bound is not the same as being anchored, and that distinction is L-1.
}

//! binding — what the BUYER computes, before the seller works.
//!
//! The escrow's soundness rests on the buyer committing to the terms first: `fund` takes a
//! `dealBinding`, and a proof settles only if the execution it describes hashes to that same
//! value. Until 2026-09-07 the binding existed in exactly one place, inside the guest, so the
//! only way to learn it was to already hold a proof — and every script in this repository read
//! it out of a fixture. That is the reverse of the design (`013` §4-3).
//!
//! This is the other end. No zkVM, no proof, no network: deal terms in, 32 bytes out.
//!
//! It is a second transcription of something the guest computes, which is a drift risk, and the
//! drift is checked rather than trusted: `tests/evm_binding.rs` recomputes the shipped fixture's
//! terms here and requires the result to equal the `deal_binding` the guest committed inside
//! SP1. If the two ever disagree, that test fails before anything reaches a chain.
use clap::Parser;
use revm::primitives::U256;
use std::str::FromStr;
use verdict_script::{evm_deal_binding, evm_deal_input};

#[derive(Parser)]
#[command(about = "Compute a deal binding from the terms, before any work is done.")]
struct Args {
    /// the value the checked slot holds before the job
    #[arg(long, default_value = "18446744073709551616")]
    pre: String,
    /// the value the job is supposed to leave behind
    #[arg(long, default_value = "18446744073709551716")]
    post: String,
    /// the floor the result must clear for the seller to be paid
    #[arg(long, default_value = "100")]
    min: String,
    /// the ceiling
    #[arg(long, default_value = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")]
    max: String,
    /// print only the 32 bytes, for `BINDING=$(… --quiet)`
    #[arg(long)]
    quiet: bool,
}

fn parse(value: &str) -> U256 {
    if let Some(hex) = value.strip_prefix("0x") {
        U256::from_str_radix(hex, 16).expect("valid U256 hex")
    } else {
        U256::from_str(value).expect("valid U256 decimal")
    }
}

fn main() {
    let args = Args::parse();
    let (pre, post, min, max) = (parse(&args.pre), parse(&args.post), parse(&args.min), parse(&args.max));
    let binding = evm_deal_binding(&evm_deal_input(pre, post, min, max));
    let hex = format!("0x{}", hex::encode(binding));
    if args.quiet {
        println!("{hex}");
        return;
    }
    println!("terms the buyer is committing to");
    println!("  pre   {pre}");
    println!("  post  {post}");
    println!("  min   {min}");
    println!("  max   {max}");
    println!();
    println!("dealBinding  {hex}");
    println!();
    println!("Hand this to RecknZkEscrow.fund(). No proof exists yet, and none is needed:");
    println!("a proof settles this deal only if the execution it describes hashes to it.");
}

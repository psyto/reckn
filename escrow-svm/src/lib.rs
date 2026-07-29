//! Reckn's Pinocchio SVM escrow.
//!
//! The program stores only content commitments and settles only a resolver's
//! Ed25519-attested `VerdictCommitment`. It never accepts an operational replay
//! error as a verdict: no valid `Reproduced | Failed` commitment means the deal
//! remains disputed until `timeout_refund` favors the buyer.

#![cfg_attr(not(test), no_std)]
// Pinocchio 0.9's allocator macros use Solana's target cfg, which stable host
// Rust does not yet enumerate for check-cfg. The SBF build remains checked.
#![allow(unexpected_cfgs)]

use bytemuck::{Pod, Zeroable};
use pinocchio::{
    account_info::AccountInfo,
    instruction::{AccountMeta, Instruction, Seed, Signer},
    msg,
    program_error::ProgramError,
    pubkey::{create_program_address, find_program_address, Pubkey},
    sysvars::{clock::Clock, instructions::Instructions, rent::Rent, Sysvar},
    ProgramResult,
};
use pinocchio_system::instructions::CreateAccount;

pinocchio::program_entrypoint!(process_instruction);
pinocchio::default_allocator!();
pinocchio::nostd_panic_handler!();

pub const TOKEN_2022_PROGRAM_ID: Pubkey =
    pinocchio_pubkey::from_str("TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb");
pub const ED25519_PROGRAM_ID: Pubkey =
    pinocchio_pubkey::from_str("Ed25519SigVerify111111111111111111111111111");
pub const DEAL_SEED: &[u8] = b"reckn-deal";
pub const CONFIG_SEED: &[u8] = b"reckn-resolver-config";

const TOKEN_IX_TRANSFER_CHECKED: u8 = 12;
const TOKEN_ACCOUNT_LEN: usize = 165;
const MINT_DECIMALS_OFFSET: usize = 44;
const ED25519_CURRENT_IX: u16 = u16::MAX;
const VERDICT_DOMAIN: &[u8] = b"reckn/svm/verdict/v1";
const EVIDENCE_DOMAIN: &[u8] = b"reckn-evidence/v1";

pub mod ix {
    pub const INITIALIZE_RESOLVER_CONFIG: u8 = 0;
    pub const FUND: u8 = 1;
    pub const DELIVER: u8 = 2;
    pub const CHALLENGE: u8 = 3;
    pub const RESOLVE: u8 = 4;
    pub const TIMEOUT_REFUND: u8 = 5;
}

pub mod state {
    pub const HELD: u8 = 1;
    pub const DELIVERED: u8 = 2;
    pub const DISPUTED: u8 = 3;
    pub const RESOLVED: u8 = 4;
}

pub mod outcome {
    pub const REPRODUCED: u8 = 0;
    pub const FAILED: u8 = 1;
}

pub mod err {
    use pinocchio::program_error::ProgramError;

    pub const BAD_STATE: ProgramError = ProgramError::Custom(0x5201);
    pub const NOT_BUYER: ProgramError = ProgramError::Custom(0x5202);
    pub const NOT_SELLER: ProgramError = ProgramError::Custom(0x5203);
    pub const DEADLINE_PASSED: ProgramError = ProgramError::Custom(0x5204);
    pub const DEADLINE_NOT_REACHED: ProgramError = ProgramError::Custom(0x5205);
    pub const PDA_MISMATCH: ProgramError = ProgramError::Custom(0x5206);
    pub const CONFIG_MISMATCH: ProgramError = ProgramError::Custom(0x5207);
    pub const TOKEN_PROGRAM_MISMATCH: ProgramError = ProgramError::Custom(0x5208);
    pub const TOKEN_ACCOUNT_MISMATCH: ProgramError = ProgramError::Custom(0x5209);
    pub const MINT_MISMATCH: ProgramError = ProgramError::Custom(0x520A);
    pub const COMMITMENT_MISMATCH: ProgramError = ProgramError::Custom(0x520B);
    pub const DISALLOWED_BACKEND: ProgramError = ProgramError::Custom(0x520C);
    pub const BAD_ED25519: ProgramError = ProgramError::Custom(0x520D);
    pub const BAD_ED25519_SIGNER: ProgramError = ProgramError::Custom(0x520E);
    pub const BAD_ED25519_MESSAGE: ProgramError = ProgramError::Custom(0x520F);
    pub const BAD_ED25519_REFERENCE: ProgramError = ProgramError::Custom(0x5210);
    pub const BAD_OUTCOME: ProgramError = ProgramError::Custom(0x5211);
    pub const BAD_DATA: ProgramError = ProgramError::Custom(0x5212);
    pub const ZERO_AMOUNT: ProgramError = ProgramError::Custom(0x5213);
    pub const BAD_DEADLINES: ProgramError = ProgramError::Custom(0x5214);
    pub const VAULT_NOT_EMPTY: ProgramError = ProgramError::Custom(0x5215);
}

/// A resolver configuration is an allowlist of exactly one V2 backend/runtime
/// tuple. Rotating it is intentionally a new config/program deployment rather
/// than an unchecked mutable administrative action.
#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
pub struct ResolverConfig {
    pub bump: u8,
    pub _pad: [u8; 7],
    pub admin: [u8; 32],
    pub resolver: [u8; 32],
    pub backend_id: [u8; 32],
    pub backend_version_hash: [u8; 32],
    pub runtime_profile_hash: [u8; 32],
    pub cluster_genesis_hash: [u8; 32],
}

impl ResolverConfig {
    pub const LEN: usize = core::mem::size_of::<Self>();
}

/// The entire escrow state machine. All deadlines are absolute slots and fixed
/// at funding: `deliver < challenge < resolve`.
#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
pub struct Deal {
    pub bump: u8,
    pub state: u8,
    pub _pad: [u8; 6],
    pub amount: u64,
    pub buyer: [u8; 32],
    pub seller: [u8; 32],
    pub mint: [u8; 32],
    pub spec_hash: [u8; 32],
    pub delivery_hash: [u8; 32],
    pub anchor_hash: [u8; 32],
    pub backend_id: [u8; 32],
    pub backend_version_hash: [u8; 32],
    pub runtime_profile_hash: [u8; 32],
    pub deliver_deadline: u64,
    pub challenge_deadline: u64,
    pub resolve_deadline: u64,
    pub nonce: [u8; 32],
}

impl Deal {
    pub const LEN: usize = core::mem::size_of::<Self>();
}

/// The bytes bound by the resolver's native Ed25519 instruction. This is not
/// an account and contains no operational-error variant: only two settled
/// outcomes exist.
#[derive(Clone, Copy)]
pub struct VerdictCommitment {
    pub deal_id: [u8; 32],
    pub spec_hash: [u8; 32],
    pub delivery_hash: [u8; 32],
    pub anchor_hash: [u8; 32],
    pub backend_id: [u8; 32],
    pub backend_version_hash: [u8; 32],
    pub runtime_profile_hash: [u8; 32],
    pub prestate_root: [u8; 32],
    pub outcome: u8,
    pub result_hash: [u8; 32],
    pub trace_hash: [u8; 32],
}

impl VerdictCommitment {
    pub const LEN: usize = 321;

    fn parse(data: &[u8]) -> Result<Self, ProgramError> {
        if data.len() != Self::LEN {
            return Err(err::BAD_DATA);
        }
        Ok(Self {
            deal_id: array32(data, 0)?,
            spec_hash: array32(data, 32)?,
            delivery_hash: array32(data, 64)?,
            anchor_hash: array32(data, 96)?,
            backend_id: array32(data, 128)?,
            backend_version_hash: array32(data, 160)?,
            runtime_profile_hash: array32(data, 192)?,
            prestate_root: array32(data, 224)?,
            outcome: data[256],
            result_hash: array32(data, 257)?,
            trace_hash: array32(data, 289)?,
        })
    }

    pub fn encode(&self, out: &mut [u8; Self::LEN]) {
        out[0..32].copy_from_slice(&self.deal_id);
        out[32..64].copy_from_slice(&self.spec_hash);
        out[64..96].copy_from_slice(&self.delivery_hash);
        out[96..128].copy_from_slice(&self.anchor_hash);
        out[128..160].copy_from_slice(&self.backend_id);
        out[160..192].copy_from_slice(&self.backend_version_hash);
        out[192..224].copy_from_slice(&self.runtime_profile_hash);
        out[224..256].copy_from_slice(&self.prestate_root);
        out[256] = self.outcome;
        out[257..289].copy_from_slice(&self.result_hash);
        out[289..321].copy_from_slice(&self.trace_hash);
    }
}

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    data: &[u8],
) -> ProgramResult {
    let (tag, rest) = data
        .split_first()
        .ok_or(ProgramError::InvalidInstructionData)?;
    match *tag {
        ix::INITIALIZE_RESOLVER_CONFIG => initialize_resolver_config(program_id, accounts, rest),
        ix::FUND => fund(program_id, accounts, rest),
        ix::DELIVER => deliver(program_id, accounts, rest),
        ix::CHALLENGE => challenge(program_id, accounts),
        ix::RESOLVE => resolve(program_id, accounts, rest),
        ix::TIMEOUT_REFUND => timeout_refund(program_id, accounts),
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

// Accounts: [payer signer, config PDA writable, system]
// Data: admin(32) resolver(32) backend(32) backend_version(32)
//       runtime_profile(32) genesis_hash(32)
fn initialize_resolver_config(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    data: &[u8],
) -> ProgramResult {
    let [payer, config, _system] = take3(accounts)?;
    require_signer(payer)?;
    if data.len() != 192 {
        return Err(err::BAD_DATA);
    }
    let (expected, bump) = find_program_address(&[CONFIG_SEED], program_id);
    if config.key() != &expected {
        return Err(err::CONFIG_MISMATCH);
    }
    if array32(data, 0)? != *payer.key() {
        return Err(err::CONFIG_MISMATCH);
    }
    let lamports = Rent::get()?.minimum_balance(ResolverConfig::LEN);
    let bump_seed = [bump];
    let seeds = [Seed::from(CONFIG_SEED), Seed::from(&bump_seed)];
    CreateAccount {
        from: payer,
        to: config,
        lamports,
        space: ResolverConfig::LEN as u64,
        owner: program_id,
    }
    .invoke_signed(&[Signer::from(&seeds)])?;
    let mut raw = config.try_borrow_mut_data()?;
    let value: &mut ResolverConfig =
        bytemuck::try_from_bytes_mut(raw.get_mut(..ResolverConfig::LEN).ok_or(err::BAD_DATA)?)
            .map_err(|_| err::BAD_DATA)?;
    *value = ResolverConfig {
        bump,
        _pad: [0; 7],
        admin: array32(data, 0)?,
        resolver: array32(data, 32)?,
        backend_id: array32(data, 64)?,
        backend_version_hash: array32(data, 96)?,
        runtime_profile_hash: array32(data, 128)?,
        cluster_genesis_hash: array32(data, 160)?,
    };
    Ok(())
}

// Accounts: [buyer signer, deal PDA writable, buyer token writable, vault
// writable, mint, token_2022, system]
// Data: seller(32) amount(8) spec(32) anchor(32) backend(32) backend_ver(32)
//       runtime_profile(32) deliver_slot(8) challenge_slot(8) resolve_slot(8)
//       nonce(32)
fn fund(program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    let [buyer, deal_ai, source, vault, mint, token_program, _system] = take7(accounts)?;
    require_signer(buyer)?;
    require_token_program(token_program)?;
    if data.len() != 256 {
        return Err(err::BAD_DATA);
    }
    let seller = array32(data, 0)?;
    let amount = read_u64(data, 32)?;
    let spec_hash = array32(data, 40)?;
    let anchor_hash = array32(data, 72)?;
    let backend_id = array32(data, 104)?;
    let backend_version_hash = array32(data, 136)?;
    let runtime_profile_hash = array32(data, 168)?;
    let deliver_deadline = read_u64(data, 200)?;
    let challenge_deadline = read_u64(data, 208)?;
    let resolve_deadline = read_u64(data, 216)?;
    let nonce = array32(data, 224)?;
    if amount == 0 {
        return Err(err::ZERO_AMOUNT);
    }
    let slot = Clock::get()?.slot;
    if seller == *buyer.key()
        || seller == [0; 32]
        || !(slot < deliver_deadline
            && deliver_deadline < challenge_deadline
            && challenge_deadline < resolve_deadline)
    {
        return Err(err::BAD_DEADLINES);
    }
    let (expected, bump) = find_program_address(
        &[DEAL_SEED, buyer.key().as_ref(), &seller, &nonce],
        program_id,
    );
    if deal_ai.key() != &expected {
        return Err(err::PDA_MISMATCH);
    }
    validate_mint(mint)?;
    validate_token_account(source, mint.key(), buyer.key())?;
    validate_token_account(vault, mint.key(), deal_ai.key())?;
    if token_amount(vault)? != 0 {
        return Err(err::VAULT_NOT_EMPTY);
    }
    let lamports = Rent::get()?.minimum_balance(Deal::LEN);
    let bump_seed = [bump];
    let seeds = [
        Seed::from(DEAL_SEED),
        Seed::from(buyer.key().as_ref()),
        Seed::from(&seller),
        Seed::from(&nonce),
        Seed::from(&bump_seed),
    ];
    CreateAccount {
        from: buyer,
        to: deal_ai,
        lamports,
        space: Deal::LEN as u64,
        owner: program_id,
    }
    .invoke_signed(&[Signer::from(&seeds)])?;
    {
        let mut raw = deal_ai.try_borrow_mut_data()?;
        let deal: &mut Deal =
            bytemuck::try_from_bytes_mut(raw.get_mut(..Deal::LEN).ok_or(err::BAD_DATA)?)
                .map_err(|_| err::BAD_DATA)?;
        *deal = Deal {
            bump,
            state: state::HELD,
            _pad: [0; 6],
            amount,
            buyer: *buyer.key(),
            seller,
            mint: *mint.key(),
            spec_hash,
            delivery_hash: [0; 32],
            anchor_hash,
            backend_id,
            backend_version_hash,
            runtime_profile_hash,
            deliver_deadline,
            challenge_deadline,
            resolve_deadline,
            nonce,
        };
    }
    cpi_transfer_checked(
        source,
        mint,
        vault,
        buyer,
        amount,
        mint_decimals(mint)?,
        &[],
    )?;
    msg!("RecknFunded");
    Ok(())
}

// Accounts: [seller signer, deal PDA writable]
// Data: delivery_hash(32)
fn deliver(program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    let [seller, deal_ai] = take2(accounts)?;
    require_signer(seller)?;
    if data.len() != 32 {
        return Err(err::BAD_DATA);
    }
    let mut raw = deal_ai.try_borrow_mut_data()?;
    let deal: &mut Deal =
        bytemuck::try_from_bytes_mut(raw.get_mut(..Deal::LEN).ok_or(err::BAD_DATA)?)
            .map_err(|_| err::BAD_DATA)?;
    validate_deal_pda(program_id, deal, deal_ai)?;
    if deal.state != state::HELD {
        return Err(err::BAD_STATE);
    }
    if seller.key() != &deal.seller {
        return Err(err::NOT_SELLER);
    }
    if Clock::get()?.slot > deal.deliver_deadline {
        return Err(err::DEADLINE_PASSED);
    }
    deal.delivery_hash = array32(data, 0)?;
    deal.state = state::DELIVERED;
    msg!("RecknDelivered");
    Ok(())
}

// Accounts: [buyer signer, deal PDA writable]
fn challenge(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let [buyer, deal_ai] = take2(accounts)?;
    require_signer(buyer)?;
    let mut raw = deal_ai.try_borrow_mut_data()?;
    let deal: &mut Deal =
        bytemuck::try_from_bytes_mut(raw.get_mut(..Deal::LEN).ok_or(err::BAD_DATA)?)
            .map_err(|_| err::BAD_DATA)?;
    validate_deal_pda(program_id, deal, deal_ai)?;
    if deal.state != state::DELIVERED {
        return Err(err::BAD_STATE);
    }
    if buyer.key() != &deal.buyer {
        return Err(err::NOT_BUYER);
    }
    if Clock::get()?.slot > deal.challenge_deadline {
        return Err(err::DEADLINE_PASSED);
    }
    deal.state = state::DISPUTED;
    msg!("RecknDisputed");
    Ok(())
}

// Accounts: [deal PDA writable, vault writable, destination token writable,
// mint, token_2022, resolver config, instructions sysvar]
// Data: VerdictCommitment (321 bytes)
fn resolve(program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    let [deal_ai, vault, destination, mint, token_program, config_ai, instructions_ai] =
        take7(accounts)?;
    require_token_program(token_program)?;
    let commitment = VerdictCommitment::parse(data)?;
    let config = read_config(program_id, config_ai)?;
    let deal = read_deal(program_id, deal_ai)?;
    if deal.state != state::DISPUTED {
        return Err(err::BAD_STATE);
    }
    if Clock::get()?.slot > deal.resolve_deadline {
        return Err(err::DEADLINE_PASSED);
    }
    if commitment.outcome != outcome::REPRODUCED && commitment.outcome != outcome::FAILED {
        return Err(err::BAD_OUTCOME);
    }
    if commitment.deal_id != *deal_ai.key()
        || commitment.spec_hash != deal.spec_hash
        || commitment.delivery_hash != deal.delivery_hash
        || commitment.anchor_hash != deal.anchor_hash
        || commitment.backend_id != deal.backend_id
        || commitment.backend_version_hash != deal.backend_version_hash
        || commitment.runtime_profile_hash != deal.runtime_profile_hash
    {
        return Err(err::COMMITMENT_MISMATCH);
    }
    if config.backend_id != deal.backend_id
        || config.backend_version_hash != deal.backend_version_hash
        || config.runtime_profile_hash != deal.runtime_profile_hash
    {
        return Err(err::DISALLOWED_BACKEND);
    }
    let message = verdict_message(program_id, &config, &commitment);
    verify_preceding_ed25519(instructions_ai, &config.resolver, &message)?;
    validate_mint(mint)?;
    validate_token_account(vault, mint.key(), deal_ai.key())?;
    let expected_recipient = if commitment.outcome == outcome::REPRODUCED {
        deal.seller
    } else {
        deal.buyer
    };
    validate_token_account(destination, mint.key(), &expected_recipient)?;

    set_state(deal_ai, state::RESOLVED)?;
    let bump = [deal.bump];
    let seeds = [
        Seed::from(DEAL_SEED),
        Seed::from(&deal.buyer),
        Seed::from(&deal.seller),
        Seed::from(&deal.nonce),
        Seed::from(&bump),
    ];
    let signer = Signer::from(&seeds);
    cpi_transfer_checked(
        vault,
        mint,
        destination,
        deal_ai,
        deal.amount,
        mint_decimals(mint)?,
        &[signer],
    )?;
    // Reputation evidence is an append-only event projection. It is deliberately
    // not read by settlement and no operational-error code can reach this path.
    emit_reputation_evidence(
        &deal.seller,
        deal_ai.key(),
        commitment.outcome,
        &commitment.trace_hash,
        &deal.backend_id,
        &config.resolver,
        Clock::get()?.slot,
    );
    msg!("RecknSettled");
    Ok(())
}

// Accounts: [deal PDA writable, vault writable, buyer destination token
// writable, mint, token_2022]
fn timeout_refund(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let [deal_ai, vault, buyer_destination, mint, token_program] = take5(accounts)?;
    require_token_program(token_program)?;
    let deal = read_deal(program_id, deal_ai)?;
    if deal.state != state::DISPUTED {
        return Err(err::BAD_STATE);
    }
    if Clock::get()?.slot <= deal.resolve_deadline {
        return Err(err::DEADLINE_NOT_REACHED);
    }
    validate_mint(mint)?;
    validate_token_account(vault, mint.key(), deal_ai.key())?;
    validate_token_account(buyer_destination, mint.key(), &deal.buyer)?;
    set_state(deal_ai, state::RESOLVED)?;
    let bump = [deal.bump];
    let seeds = [
        Seed::from(DEAL_SEED),
        Seed::from(&deal.buyer),
        Seed::from(&deal.seller),
        Seed::from(&deal.nonce),
        Seed::from(&bump),
    ];
    let signer = Signer::from(&seeds);
    // C1: a seller cannot avoid the negative reputation projection simply by
    // withholding replay material until the dispute expires. `FAILED` plus a
    // zero trace is evidence-withheld, not a reproduced Failed verdict.
    // No resolver/config account is available on this permissionless path, so
    // the resolver field is the all-zero sentinel rather than an inferred key.
    emit_reputation_evidence(
        &deal.seller,
        deal_ai.key(),
        outcome::FAILED,
        &[0; 32],
        &deal.backend_id,
        &[0; 32],
        Clock::get()?.slot,
    );
    cpi_transfer_checked(
        vault,
        mint,
        buyer_destination,
        deal_ai,
        deal.amount,
        mint_decimals(mint)?,
        &[signer],
    )?;
    msg!("RecknTimeoutRefund");
    Ok(())
}

/// Emit ERC-8004-style seller reputation evidence without participating in
/// settlement. `reckn-evidence/v1` fields are, in order:
/// `(domain, seller_agent, outcome, deal_id, trace_hash, backend_id, resolver,
/// settlement_slot)`. A normal resolve has a non-zero trace and the registered
/// resolver. A C1 timeout uses `outcome::FAILED`, a zero trace, and a zero
/// resolver sentinel; consumers must classify that shape as
/// *evidence-withheld*, not a replay-produced `Failed` verdict.
fn emit_reputation_evidence(
    seller: &[u8; 32],
    deal_id: &Pubkey,
    evidence_outcome: u8,
    trace_hash: &[u8; 32],
    backend_id: &[u8; 32],
    resolver: &[u8; 32],
    slot: u64,
) {
    let evidence_outcome = [evidence_outcome];
    let evidence_slot = slot.to_le_bytes();
    msg!("ReputationEvidence");
    pinocchio::log::sol_log_data(&[
        EVIDENCE_DOMAIN,
        seller,
        &evidence_outcome,
        deal_id.as_ref(),
        trace_hash,
        backend_id,
        resolver,
        &evidence_slot,
    ]);
}

fn read_config(
    program_id: &Pubkey,
    config_ai: &AccountInfo,
) -> Result<ResolverConfig, ProgramError> {
    let (expected, _) = find_program_address(&[CONFIG_SEED], program_id);
    if config_ai.key() != &expected || config_ai.owner() != program_id {
        return Err(err::CONFIG_MISMATCH);
    }
    let raw = config_ai.try_borrow_data()?;
    bytemuck::try_from_bytes::<ResolverConfig>(raw.get(..ResolverConfig::LEN).ok_or(err::BAD_DATA)?)
        .copied()
        .map_err(|_| err::BAD_DATA)
}

fn read_deal(program_id: &Pubkey, deal_ai: &AccountInfo) -> Result<Deal, ProgramError> {
    if deal_ai.owner() != program_id {
        return Err(err::PDA_MISMATCH);
    }
    let raw = deal_ai.try_borrow_data()?;
    let deal = bytemuck::try_from_bytes::<Deal>(raw.get(..Deal::LEN).ok_or(err::BAD_DATA)?)
        .copied()
        .map_err(|_| err::BAD_DATA)?;
    validate_deal_pda(program_id, &deal, deal_ai)?;
    Ok(deal)
}

fn validate_deal_pda(program_id: &Pubkey, deal: &Deal, deal_ai: &AccountInfo) -> ProgramResult {
    let bump = [deal.bump];
    let expected = create_program_address(
        &[DEAL_SEED, &deal.buyer, &deal.seller, &deal.nonce, &bump],
        program_id,
    )?;
    if deal_ai.key() != &expected {
        return Err(err::PDA_MISMATCH);
    }
    Ok(())
}

fn set_state(deal_ai: &AccountInfo, state: u8) -> ProgramResult {
    let mut raw = deal_ai.try_borrow_mut_data()?;
    let deal: &mut Deal =
        bytemuck::try_from_bytes_mut(raw.get_mut(..Deal::LEN).ok_or(err::BAD_DATA)?)
            .map_err(|_| err::BAD_DATA)?;
    deal.state = state;
    Ok(())
}

fn cpi_transfer_checked(
    source: &AccountInfo,
    mint: &AccountInfo,
    destination: &AccountInfo,
    authority: &AccountInfo,
    amount: u64,
    decimals: u8,
    signers: &[Signer<'_, '_>],
) -> ProgramResult {
    let mut data = [0u8; 10];
    data[0] = TOKEN_IX_TRANSFER_CHECKED;
    data[1..9].copy_from_slice(&amount.to_le_bytes());
    data[9] = decimals;
    let metas = [
        AccountMeta::new(source.key(), true, false),
        AccountMeta::new(mint.key(), false, false),
        AccountMeta::new(destination.key(), true, false),
        AccountMeta::new(authority.key(), false, true),
    ];
    let ix = Instruction {
        program_id: &TOKEN_2022_PROGRAM_ID,
        data: &data,
        accounts: &metas,
    };
    pinocchio::cpi::slice_invoke_signed(&ix, &[source, mint, destination, authority], signers)
}

fn validate_mint(mint: &AccountInfo) -> ProgramResult {
    if mint.owner() != &TOKEN_2022_PROGRAM_ID || mint.try_borrow_data()?.len() < 45 {
        return Err(err::MINT_MISMATCH);
    }
    Ok(())
}

fn validate_token_account(account: &AccountInfo, mint: &Pubkey, owner: &Pubkey) -> ProgramResult {
    if account.owner() != &TOKEN_2022_PROGRAM_ID {
        return Err(err::TOKEN_ACCOUNT_MISMATCH);
    }
    let data = account.try_borrow_data()?;
    if data.len() < TOKEN_ACCOUNT_LEN || &data[0..32] != mint || &data[32..64] != owner {
        return Err(err::TOKEN_ACCOUNT_MISMATCH);
    }
    Ok(())
}

fn token_amount(account: &AccountInfo) -> Result<u64, ProgramError> {
    let data = account.try_borrow_data()?;
    read_u64(&data, 64)
}

fn mint_decimals(mint: &AccountInfo) -> Result<u8, ProgramError> {
    let data = mint.try_borrow_data()?;
    data.get(MINT_DECIMALS_OFFSET)
        .copied()
        .ok_or(err::MINT_MISMATCH)
}

fn require_token_program(program: &AccountInfo) -> ProgramResult {
    if program.key() != &TOKEN_2022_PROGRAM_ID {
        return Err(err::TOKEN_PROGRAM_MISMATCH);
    }
    Ok(())
}

fn require_signer(account: &AccountInfo) -> ProgramResult {
    if !account.is_signer() {
        return Err(ProgramError::MissingRequiredSignature);
    }
    Ok(())
}

fn verify_preceding_ed25519(
    instructions_ai: &AccountInfo,
    expected_signer: &[u8; 32],
    expected_message: &[u8],
) -> ProgramResult {
    let instructions = Instructions::try_from(instructions_ai)?;
    if instructions.load_current_index() == 0 {
        return Err(err::BAD_ED25519);
    }
    let ix = instructions
        .get_instruction_relative(-1)
        .map_err(|_| err::BAD_ED25519)?;
    if ix.get_program_id() != &ED25519_PROGRAM_ID {
        return Err(err::BAD_ED25519);
    }
    let data = ix.get_instruction_data();
    if data.len() < 16 || data[0] != 1 {
        return Err(err::BAD_ED25519);
    }
    let sig_off = read_u16(data, 2)? as usize;
    let sig_ix = read_u16(data, 4)?;
    let pk_off = read_u16(data, 6)? as usize;
    let pk_ix = read_u16(data, 8)?;
    let msg_off = read_u16(data, 10)? as usize;
    let msg_len = read_u16(data, 12)? as usize;
    let msg_ix = read_u16(data, 14)?;
    if sig_ix != ED25519_CURRENT_IX || pk_ix != ED25519_CURRENT_IX || msg_ix != ED25519_CURRENT_IX {
        return Err(err::BAD_ED25519_REFERENCE);
    }
    if slice(data, sig_off, 64).is_err() {
        return Err(err::BAD_ED25519);
    }
    if slice(data, pk_off, 32)? != expected_signer {
        return Err(err::BAD_ED25519_SIGNER);
    }
    if msg_len != expected_message.len() || slice(data, msg_off, msg_len)? != expected_message {
        return Err(err::BAD_ED25519_MESSAGE);
    }
    Ok(())
}

const VERDICT_MESSAGE_LEN: usize = VERDICT_DOMAIN.len() + 32 + 32 + 32 + VerdictCommitment::LEN;
pub fn verdict_message(
    program_id: &Pubkey,
    config: &ResolverConfig,
    commitment: &VerdictCommitment,
) -> [u8; VERDICT_MESSAGE_LEN] {
    let mut out = [0u8; VERDICT_MESSAGE_LEN];
    let mut offset = 0;
    out[offset..offset + VERDICT_DOMAIN.len()].copy_from_slice(VERDICT_DOMAIN);
    offset += VERDICT_DOMAIN.len();
    out[offset..offset + 32].copy_from_slice(&config.cluster_genesis_hash);
    offset += 32;
    out[offset..offset + 32].copy_from_slice(program_id);
    offset += 32;
    out[offset..offset + 32].copy_from_slice(&commitment.deal_id);
    offset += 32;
    let mut encoded = [0u8; VerdictCommitment::LEN];
    commitment.encode(&mut encoded);
    out[offset..].copy_from_slice(&encoded);
    out
}

fn array32(data: &[u8], offset: usize) -> Result<[u8; 32], ProgramError> {
    let mut out = [0u8; 32];
    out.copy_from_slice(slice(data, offset, 32)?);
    Ok(out)
}

fn read_u16(data: &[u8], offset: usize) -> Result<u16, ProgramError> {
    Ok(u16::from_le_bytes(
        slice(data, offset, 2)?
            .try_into()
            .map_err(|_| err::BAD_DATA)?,
    ))
}

fn read_u64(data: &[u8], offset: usize) -> Result<u64, ProgramError> {
    Ok(u64::from_le_bytes(
        slice(data, offset, 8)?
            .try_into()
            .map_err(|_| err::BAD_DATA)?,
    ))
}

fn slice(data: &[u8], offset: usize, len: usize) -> Result<&[u8], ProgramError> {
    data.get(offset..offset.checked_add(len).ok_or(err::BAD_DATA)?)
        .ok_or(err::BAD_DATA)
}

fn take2(accounts: &[AccountInfo]) -> Result<[&AccountInfo; 2], ProgramError> {
    match accounts {
        [a, b, ..] => Ok([a, b]),
        _ => Err(ProgramError::NotEnoughAccountKeys),
    }
}
fn take3(accounts: &[AccountInfo]) -> Result<[&AccountInfo; 3], ProgramError> {
    match accounts {
        [a, b, c, ..] => Ok([a, b, c]),
        _ => Err(ProgramError::NotEnoughAccountKeys),
    }
}
fn take5(accounts: &[AccountInfo]) -> Result<[&AccountInfo; 5], ProgramError> {
    match accounts {
        [a, b, c, d, e, ..] => Ok([a, b, c, d, e]),
        _ => Err(ProgramError::NotEnoughAccountKeys),
    }
}
fn take7(accounts: &[AccountInfo]) -> Result<[&AccountInfo; 7], ProgramError> {
    match accounts {
        [a, b, c, d, e, f, g, ..] => Ok([a, b, c, d, e, f, g]),
        _ => Err(ProgramError::NotEnoughAccountKeys),
    }
}

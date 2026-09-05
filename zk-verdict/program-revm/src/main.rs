//! The **full re-execution** zkVM guest. It verifies the committed prestate
//! against its state root, executes the seller's committed CALL against a
//! witness-closed `revm` database under the committed EVM environment, reads the
//! resulting post-state, and applies reckn's causal delta predicate. The proof
//! commits the resulting `VerdictPublicValues` for the exact state, environment,
//! predicate, and plan it re-executes.

#![no_main]
sp1_zkvm::entrypoint!(main);

use core::fmt;

use alloy_sol_types::SolType;
use alloy_trie::{proof::verify_proof, Nibbles, TrieAccount};
use reexec_io::GuestInput;
use revm::context::result::{EVMError, ExecutionResult};
use revm::context::TxEnv;
use revm::database::Database;
use revm::primitives::hardfork::SpecId;
use revm::primitives::{keccak256, Address, Bytes, TxKind, B256, U256};
use revm::state::{AccountInfo, Bytecode};
use revm::{Context, ExecuteEvm, MainBuilder, MainContext};
use verdict_lib::{delta_outcome, reexec_trace_hash, VerdictPublicValues, FAILED};

const DIVERGENT_PRECOMPILE_LAST_BYTES: [u8; 9] = [
    0x01, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11,
];

fn is_divergent_precompile(address: [u8; 20]) -> bool {
    address[..19].iter().all(|byte| *byte == 0)
        && DIVERGENT_PRECOMPILE_LAST_BYTES.contains(&address[19])
}

/// Errors from the witness-closed database. They deliberately remain errors
/// until `transact` returns them, where they become the corresponding NoProof
/// transition instead of a `Failed` verdict.
#[derive(Debug)]
enum WitnessDbError {
    MissingAccount(Address),
    MissingCode(B256),
    MissingStorage(Address, U256),
    MissingBlockHash(u64),
}

impl fmt::Display for WitnessDbError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingAccount(address) => write!(f, "missing account witness: {address}"),
            Self::MissingCode(code_hash) => write!(f, "missing code witness: {code_hash}"),
            Self::MissingStorage(address, slot) => {
                write!(f, "missing storage witness: {address} {slot}")
            }
            Self::MissingBlockHash(number) => write!(f, "missing block hash witness: {number}"),
        }
    }
}

impl core::error::Error for WitnessDbError {}
impl revm::database_interface::DBErrorMarker for WitnessDbError {}

#[derive(Clone)]
struct WitnessedAccount {
    info: AccountInfo,
    storage: Vec<(U256, U256)>,
}

/// A database containing precisely the previously authenticated witness. There
/// is no default value for a missing account, slot, code, or block hash.
#[derive(Clone)]
struct WitnessDb {
    accounts: Vec<(Address, WitnessedAccount)>,
    codes: Vec<(B256, Bytecode)>,
}

impl WitnessDb {
    fn from_verified_witness(input: &GuestInput) -> Self {
        let mut accounts = Vec::with_capacity(input.accounts.len());
        let mut codes = Vec::with_capacity(input.accounts.len());

        for account in &input.accounts {
            let address = Address::from(account.address);
            let code = Bytecode::new_raw(Bytes::from(account.code.clone()));
            let info = AccountInfo {
                balance: U256::from_be_bytes(account.balance),
                nonce: account.nonce,
                code_hash: B256::from(account.code_hash),
                code: Some(code.clone()),
                ..Default::default()
            };
            let storage = account
                .storage
                .iter()
                .map(|entry| {
                    (
                        U256::from_be_bytes(entry.slot),
                        U256::from_be_bytes(entry.value),
                    )
                })
                .collect();

            codes.push((B256::from(account.code_hash), code));
            accounts.push((address, WitnessedAccount { info, storage }));
        }

        Self { accounts, codes }
    }
}

impl Database for WitnessDb {
    type Error = WitnessDbError;

    fn basic(&mut self, address: Address) -> Result<Option<AccountInfo>, Self::Error> {
        self.accounts
            .iter()
            .find(|(candidate, _)| *candidate == address)
            .map(|(_, account)| Some(account.info.clone()))
            .ok_or(WitnessDbError::MissingAccount(address))
    }

    fn code_by_hash(&mut self, code_hash: B256) -> Result<Bytecode, Self::Error> {
        self.codes
            .iter()
            .find(|(candidate, _)| *candidate == code_hash)
            .map(|(_, code)| code.clone())
            .ok_or(WitnessDbError::MissingCode(code_hash))
    }

    fn storage(&mut self, address: Address, slot: U256) -> Result<U256, Self::Error> {
        let account = self
            .accounts
            .iter()
            .find(|(candidate, _)| *candidate == address)
            .map(|(_, account)| account)
            .ok_or(WitnessDbError::MissingAccount(address))?;
        account
            .storage
            .iter()
            .find(|(candidate, _)| *candidate == slot)
            .map(|(_, value)| *value)
            .ok_or(WitnessDbError::MissingStorage(address, slot))
    }

    fn block_hash(&mut self, number: u64) -> Result<B256, Self::Error> {
        Err(WitnessDbError::MissingBlockHash(number))
    }
}

/// Prove the committed prestate is authentic against `state_root`: each account
/// is MPT-verified against the state root, and each storage slot against the
/// proven account storage root, exactly as the off-chain verifier does.
fn verify_prestate_authenticity(input: &GuestInput) {
    let state_root = B256::from(input.state_root);
    for (account_index, account) in input.accounts.iter().enumerate() {
        assert!(
            !account.account_proof.is_empty(),
            "P-10: empty account proof"
        );
        for prior in &input.accounts[..account_index] {
            assert_ne!(prior.address, account.address, "P-4: duplicate account witness");
        }

        let address = Address::from(account.address);
        let code_hash = keccak256(&account.code);
        assert_eq!(code_hash.0, account.code_hash, "P-3: code hash mismatch");

        let trie_account = TrieAccount {
            nonce: account.nonce,
            balance: U256::from_be_bytes(account.balance),
            storage_root: B256::from(account.storage_root),
            code_hash: B256::from(account.code_hash),
        };
        let key = Nibbles::unpack(keccak256(address.as_slice()));
        let proof: Vec<Bytes> = account
            .account_proof
            .iter()
            .map(|node| Bytes::copy_from_slice(node))
            .collect();
        verify_proof(state_root, key, Some(alloy_rlp::encode(trie_account)), proof.iter())
            .expect("P-1: account proof invalid");

        let storage_root = B256::from(account.storage_root);
        for (storage_index, entry) in account.storage.iter().enumerate() {
            assert!(
                !entry.proof.is_empty(),
                "P-11: empty storage proof"
            );
            for prior in &account.storage[..storage_index] {
                assert_ne!(prior.slot, entry.slot, "P-4: duplicate storage witness");
            }

            let slot = U256::from_be_bytes(entry.slot);
            let value = U256::from_be_bytes(entry.value);
            let key = Nibbles::unpack(keccak256(slot.to_be_bytes::<32>()));
            let expected = if value.is_zero() {
                None
            } else {
                Some(alloy_rlp::encode(value))
            };
            let proof: Vec<Bytes> = entry
                .proof
                .iter()
                .map(|node| Bytes::copy_from_slice(node))
                .collect();
            verify_proof(storage_root, key, expected, proof.iter())
                .expect("P-2: storage proof invalid");
        }
    }
}

/// The committed prestate value of the checked slot. Its absence is an
/// unavailable predicate witness, never an implicit zero baseline.
fn read_committed(input: &GuestInput, address: [u8; 20], slot: [u8; 32]) -> U256 {
    for account in &input.accounts {
        if account.address == address {
            for entry in &account.storage {
                if entry.slot == slot {
                    return U256::from_be_bytes(entry.value);
                }
            }
        }
    }
    panic!("P-8: missing predicate witness")
}

fn calldata_len_be(calldata: &[u8]) -> [u8; 8] {
    let source = calldata.len().to_be_bytes();
    let mut out = [0u8; 8];
    out[8 - source.len()..].copy_from_slice(&source);
    out
}

fn deal_binding(input: &GuestInput) -> B256 {
    let mut env_pre = Vec::new();
    env_pre.extend_from_slice(b"reckn/zk/env/evm/v2");
    env_pre.extend_from_slice(&input.env.chain_id.to_be_bytes());
    env_pre.push(input.env.spec_id);
    env_pre.extend_from_slice(&input.env.block_number.to_be_bytes());
    env_pre.extend_from_slice(&input.env.timestamp.to_be_bytes());
    env_pre.extend_from_slice(&input.env.base_fee.to_be_bytes());
    env_pre.extend_from_slice(&input.env.block_gas_limit.to_be_bytes());
    env_pre.extend_from_slice(&input.env.coinbase);
    env_pre.extend_from_slice(&input.env.prevrandao);
    let env_hash = keccak256(&env_pre);

    let mut check_pre = Vec::new();
    check_pre.extend_from_slice(b"reckn/zk/check/evm/v2");
    check_pre.extend_from_slice(&input.check.address);
    check_pre.extend_from_slice(&input.check.slot);
    check_pre.extend_from_slice(&input.check.min);
    check_pre.extend_from_slice(&input.check.max);
    let check_hash = keccak256(&check_pre);

    let mut plan_pre = Vec::new();
    plan_pre.extend_from_slice(b"reckn/zk/plan/evm/v2");
    plan_pre.extend_from_slice(&input.plan.caller);
    plan_pre.extend_from_slice(&input.plan.target);
    plan_pre.extend_from_slice(&input.plan.value);
    plan_pre.extend_from_slice(&input.plan.gas_limit.to_be_bytes());
    plan_pre.extend_from_slice(&calldata_len_be(&input.plan.calldata));
    plan_pre.extend_from_slice(&input.plan.calldata);
    let plan_hash = keccak256(&plan_pre);

    let mut binding_pre = Vec::new();
    binding_pre.extend_from_slice(b"reckn/zk/bind/evm/v2");
    binding_pre.extend_from_slice(&input.state_root);
    binding_pre.extend_from_slice(env_hash.as_slice());
    binding_pre.extend_from_slice(check_hash.as_slice());
    binding_pre.extend_from_slice(plan_hash.as_slice());
    keccak256(&binding_pre)
}

pub fn main() {
    let input = sp1_zkvm::io::read::<GuestInput>();

    // P-12 is first: backend-divergent precompiles are outside the guest domain.
    for account in &input.accounts {
        assert!(
            !is_divergent_precompile(account.address),
            "P-12: divergent precompile witness"
        );
    }
    assert!(
        !is_divergent_precompile(input.plan.target),
        "P-12: divergent precompile target"
    );

    let spec = SpecId::try_from_u8(input.env.spec_id)
        .expect("P-9: unknown EVM spec identifier");

    verify_prestate_authenticity(&input);
    let pre = read_committed(&input, input.check.address, input.check.slot);
    let db = WitnessDb::from_verified_witness(&input);

    let mut evm = Context::mainnet()
        .with_db(db)
        .modify_cfg_chained(|cfg| {
            cfg.chain_id = input.env.chain_id;
            cfg.spec = spec;
            cfg.disable_base_fee = true;
            cfg.disable_nonce_check = true;
        })
        .modify_block_chained(|block| {
            block.number = U256::from(input.env.block_number);
            block.timestamp = U256::from(input.env.timestamp);
            block.basefee = input.env.base_fee;
            block.gas_limit = input.env.block_gas_limit;
            block.beneficiary = Address::from(input.env.coinbase);
            block.prevrandao = Some(B256::from(input.env.prevrandao));
        })
        .build_mainnet();

    let tx = TxEnv {
        caller: Address::from(input.plan.caller),
        kind: TxKind::Call(Address::from(input.plan.target)),
        value: U256::from_be_bytes(input.plan.value),
        data: Bytes::from(input.plan.calldata.clone()),
        gas_limit: input.plan.gas_limit,
        gas_price: 0,
        chain_id: Some(input.env.chain_id),
        ..Default::default()
    };

    let (exec_ok, post_state) = match evm.transact(tx) {
        Ok(result) => match result.result {
            ExecutionResult::Success { .. } => (true, Some(result.state)),
            _ => (false, None),
        },
        Err(EVMError::Database(_)) => panic!("P-5/P-6/P-7: witness database read failed"),
        Err(_) => (false, None),
    };

    let check = &input.check;
    let check_address = Address::from(check.address);
    let check_slot = U256::from_be_bytes(check.slot);
    let post = post_state
        .as_ref()
        .and_then(|state| state.get(&check_address))
        .and_then(|account| account.storage.get(&check_slot))
        .map(|slot| slot.present_value)
        .unwrap_or(pre);
    let min = U256::from_be_bytes(check.min);
    let max = U256::from_be_bytes(check.max);
    let outcome = if exec_ok {
        delta_outcome(pre, post, min, max)
    } else {
        FAILED
    };
    let trace = reexec_trace_hash(input.state_root, pre, post, min, max, outcome);
    let binding = deal_binding(&input);

    let bytes = VerdictPublicValues::abi_encode(&VerdictPublicValues {
        pre,
        post,
        minDelta: min,
        maxDelta: max,
        outcome,
        traceHash: trace.into(),
        dealBinding: binding.0.into(),
    });
    sp1_zkvm::io::commit_slice(&bytes);
}

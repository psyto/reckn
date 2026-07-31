use {
    bytemuck::pod_read_unaligned,
    ed25519_dalek::SigningKey,
    litesvm::LiteSVM,
    reckn_escrow_svm::{
        ix, state, Deal, ResolverConfig, CONFIG_SEED, DEAL_SEED, MIN_BOND, TOKEN_2022_PROGRAM_ID,
    },
    reckn_reexec_svm::{
        runtime_profile_hash, snapshot_commitment, AccountSnapshotV2, RuntimeProfileV1,
    },
    reckn_svm_keeper::{
        deposit_bond_ix, finalize_settlement_ix, replay_disputed, resolver_pda, set_resolver_ix,
        signed_resolve_optimistic_ixs, verify, write_content, FinalizeAccounts, FileContentStore,
        OptimisticResolveAccounts, StoredAnchorV2, StoredDeliveryV1, StoredPredicateV1,
        StoredRuntimeProfileV1, StoredSnapshotV2, StoredSpecV1,
    },
    serde::Serialize,
    solana_account::Account,
    solana_address::Address,
    solana_instruction::{AccountMeta, Instruction},
    solana_keypair::Keypair,
    solana_sdk_ids::system_program,
    solana_signer::Signer,
    solana_transaction::Transaction,
    std::path::PathBuf,
    tempfile::tempdir,
};

const PROGRAM_ID: Address = Address::new_from_array([0x52; 32]);
const AMOUNT: u64 = 1_000_000;
const DECIMALS: u8 = 6;
// The replay's transfer destination. It starts at 1 lamport, so a `transfer`
// of N settles it at N + 1 — the value every predicate below is written against.
const REPLAY_TO: [u8; 32] = [5; 32];

#[test]
fn keeper_full_loop_equality_and_bound_predicates_release_refund_and_keyless_verify_agree() {
    for (transfer, predicate, seller_paid) in [
        // Exact equality: the destination must hold precisely `expected`.
        (
            2_000_000,
            StoredPredicateV1::LamportsEquals {
                account: REPLAY_TO,
                expected: 2_000_001,
            },
            true,
        ),
        (
            1_500_000,
            StoredPredicateV1::LamportsEquals {
                account: REPLAY_TO,
                expected: 2_000_001,
            },
            false,
        ),
        // Funded envelope "received >= minOut" (the swap slippage bound): an
        // honest fill clears the floor and releases; a short fill refunds. Same
        // escrow loop, same keyless verify — only the funded predicate differs.
        (
            2_000_000,
            StoredPredicateV1::LamportsBounded {
                account: REPLAY_TO,
                min: 2_000_000,
                max: u64::MAX,
            },
            true,
        ),
        (
            1_500_000,
            StoredPredicateV1::LamportsBounded {
                account: REPLAY_TO,
                min: 2_000_000,
                max: u64::MAX,
            },
            false,
        ),
    ] {
        let mut env = Env::new(transfer, predicate);
        env.fund_deliver_challenge();
        let disputed = env.deal();

        let replay = replay_disputed(&env.store, &disputed).expect("committed replay");
        assert_eq!(replay.reproduced(), seller_paid);
        let destination = if seller_paid {
            env.seller_destination
        } else {
            env.source
        };
        // Optimistic settlement: the admin registers + bonds the resolver, the
        // bonded resolver opens a challenge window with resolve_optimistic, and —
        // with no conflicting verdict — anyone finalizes once it elapses.
        let resolver_key = env.resolver.verifying_key().to_bytes();
        env.send_buyer(vec![set_resolver_ix(
            PROGRAM_ID,
            env.buyer.pubkey(),
            env.config,
            resolver_key,
            true,
        )])
        .expect("register resolver");
        env.send_buyer(vec![deposit_bond_ix(
            PROGRAM_ID,
            env.buyer.pubkey(),
            resolver_key,
            MIN_BOND,
        )])
        .expect("bond resolver");

        let (onchain, ixs) = signed_resolve_optimistic_ixs(
            PROGRAM_ID,
            env.deal_id,
            &disputed,
            &env.config_value,
            &env.resolver,
            &replay,
            OptimisticResolveAccounts {
                config: env.config,
                resolver_pda: resolver_pda(PROGRAM_ID, resolver_key),
            },
        )
        .expect("bonded resolver opens the window");
        env.send_buyer(ixs.to_vec())
            .expect("ed25519 then resolve_optimistic accepted");
        assert_eq!(env.deal().state, state::SETTLING);

        env.svm.warp_to_slot(1_000);
        env.svm.expire_blockhash();
        env.send_buyer(vec![finalize_settlement_ix(
            PROGRAM_ID,
            env.deal_id,
            FinalizeAccounts {
                vault: env.vault,
                destination,
                mint: env.mint,
            },
        )])
        .expect("finalize after window");

        assert_eq!(env.deal().state, state::RESOLVED);
        assert_eq!(env.amount(env.vault), 0);
        assert_eq!(
            env.amount(env.seller_destination),
            if seller_paid { AMOUNT } else { 0 }
        );
        assert_eq!(env.amount(env.source), if seller_paid { 0 } else { AMOUNT });
        assert_eq!(
            env.amount(env.source) + env.amount(env.vault) + env.amount(env.seller_destination),
            AMOUNT
        );
        assert!(verify(&env.store, *env.deal_id.as_array(), &disputed, &onchain).unwrap());
    }
}

struct Env {
    svm: LiteSVM,
    buyer: Keypair,
    seller: Keypair,
    resolver: SigningKey,
    mint: Address,
    source: Address,
    vault: Address,
    seller_destination: Address,
    deal_id: Address,
    config: Address,
    config_value: ResolverConfig,
    store: FileContentStore,
    seller_bytes: [u8; 32],
    nonce: [u8; 32],
    spec: [u8; 32],
    delivery: [u8; 32],
    anchor: [u8; 32],
    backend: [u8; 32],
    version: [u8; 32],
    profile: [u8; 32],
}
impl Env {
    fn new(transfer: u64, predicate: StoredPredicateV1) -> Self {
        let dir = tempdir().unwrap().keep();
        let store = FileContentStore::new(&dir);
        let buyer = Keypair::new_from_array([1; 32]);
        let seller = Keypair::new_from_array([2; 32]);
        let resolver = SigningKey::from_bytes(&[3; 32]);
        let agent = Keypair::new_from_array([4; 32]);
        let replay_to = Address::new_from_array(REPLAY_TO);
        let mut plan = Transaction::new_with_payer(
            &[system_transfer(agent.pubkey(), replay_to, transfer)],
            Some(&agent.pubkey()),
        );
        plan.sign(&[&agent], Default::default());
        let profile = RuntimeProfileV1::default();
        let runtime = runtime_profile_hash(&profile).unwrap();
        let snapshot = StoredSnapshotV2 {
            accounts: vec![
                stored_account(agent.pubkey(), 1_000_000_000),
                stored_account(replay_to, 1),
            ],
        };
        let typed_snapshot = reckn_reexec_svm::PrestateSnapshotV2 {
            accounts: snapshot
                .accounts
                .iter()
                .map(|x| AccountSnapshotV2 {
                    pubkey: solana_pubkey::Pubkey::new_from_array(x.pubkey),
                    lamports: x.lamports,
                    owner: solana_pubkey::Pubkey::new_from_array(x.owner),
                    executable: x.executable,
                    rent_epoch: x.rent_epoch,
                    data: x.data.clone(),
                })
                .collect(),
        };
        let snapshot_hash = put(&dir, &snapshot);
        let backend = [6; 32];
        let version = [7; 32];
        let anchor = StoredAnchorV2 {
            state_commitment: bytes(snapshot_commitment(&typed_snapshot, &profile).unwrap()),
            cluster_genesis_hash: [8; 32],
            slot: 1,
            blockhash: plan.message.recent_blockhash.to_bytes(),
            bank_hash: [9; 32],
            parent_bank_hash: [0; 32],
            signature_count: 0,
            snapshot_is_complete: false,
            full_snapshot_hash: [0; 32],
            runtime_profile_hash: bytes(runtime),
            snapshot_archive_hash: bytes(snapshot_hash),
            snapshot_format_version: 2,
        };
        let anchor_hash = put(&dir, &anchor);
        let profile_hash = put(
            &dir,
            &StoredRuntimeProfileV1 {
                allowed_ambient_programs: vec![[0; 32]],
            },
        );
        let spec = StoredSpecV1 {
            backend_id: backend,
            backend_version_hash: version,
            anchor_hash: bytes(anchor_hash),
            runtime_profile_content_hash: bytes(profile_hash),
            predicate,
        };
        let spec_hash = put(&dir, &spec);
        let delivery_hash = put(
            &dir,
            &StoredDeliveryV1 {
                transaction: bincode::serialize(&plan).unwrap(),
            },
        );
        let mut svm = LiteSVM::new();
        let so = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../escrow-svm/target/deploy/reckn_escrow_svm.so");
        assert!(
            so.exists(),
            "run cargo build-sbf --manifest-path escrow-svm/Cargo.toml"
        );
        svm.add_program_from_file(PROGRAM_ID, so).unwrap();
        svm.airdrop(&buyer.pubkey(), 10_000_000_000).unwrap();
        svm.airdrop(&seller.pubkey(), 10_000_000_000).unwrap();
        let mint = Address::new_from_array([10; 32]);
        let source = Address::new_from_array([11; 32]);
        let seller_destination = Address::new_from_array([12; 32]);
        let nonce = [13; 32];
        let seller_bytes = *seller.pubkey().as_array();
        let (deal_id, _) = Address::find_program_address(
            &[DEAL_SEED, buyer.pubkey().as_ref(), &seller_bytes, &nonce],
            &PROGRAM_ID,
        );
        let vault = Address::new_from_array([14; 32]);
        let (config, _) = Address::find_program_address(&[CONFIG_SEED], &PROGRAM_ID);
        svm.set_account(mint, mint_account()).unwrap();
        svm.set_account(source, token_account(mint, buyer.pubkey(), AMOUNT))
            .unwrap();
        svm.set_account(vault, token_account(mint, deal_id, 0))
            .unwrap();
        svm.set_account(seller_destination, token_account(mint, seller.pubkey(), 0))
            .unwrap();
        let config_value = ResolverConfig {
            bump: 0,
            _pad: [0; 7],
            admin: *buyer.pubkey().as_array(),
            resolver: resolver.verifying_key().to_bytes(),
            backend_id: backend,
            backend_version_hash: version,
            runtime_profile_hash: bytes(runtime),
            cluster_genesis_hash: [8; 32],
        };
        Self {
            svm,
            buyer,
            seller,
            resolver,
            mint,
            source,
            vault,
            seller_destination,
            deal_id,
            config,
            config_value,
            store,
            seller_bytes,
            nonce,
            spec: bytes(spec_hash),
            delivery: bytes(delivery_hash),
            anchor: bytes(anchor_hash),
            backend,
            version,
            profile: bytes(runtime),
        }
    }
    fn fund_deliver_challenge(&mut self) {
        let mut init = vec![ix::INITIALIZE_RESOLVER_CONFIG];
        for x in [
            &self.config_value.admin,
            &self.config_value.resolver,
            &self.backend,
            &self.version,
            &self.profile,
            &self.config_value.cluster_genesis_hash,
        ] {
            init.extend_from_slice(x);
        }
        self.send_buyer(vec![instruction(
            init,
            vec![
                AccountMeta::new(self.buyer.pubkey(), true),
                AccountMeta::new(self.config, false),
                AccountMeta::new_readonly(system_program::id(), false),
            ],
        )])
        .unwrap();
        let mut fund = vec![ix::FUND];
        fund.extend_from_slice(&self.seller_bytes);
        fund.extend_from_slice(&AMOUNT.to_le_bytes());
        for x in [
            &self.spec,
            &self.anchor,
            &self.backend,
            &self.version,
            &self.profile,
        ] {
            fund.extend_from_slice(x);
        }
        for x in [10u64, 20, 30] {
            fund.extend_from_slice(&x.to_le_bytes());
        }
        fund.extend_from_slice(&self.nonce);
        self.send_buyer(vec![instruction(
            fund,
            vec![
                AccountMeta::new(self.buyer.pubkey(), true),
                AccountMeta::new(self.deal_id, false),
                AccountMeta::new(self.source, false),
                AccountMeta::new(self.vault, false),
                AccountMeta::new_readonly(self.mint, false),
                AccountMeta::new_readonly(token2022(), false),
                AccountMeta::new_readonly(system_program::id(), false),
            ],
        )])
        .unwrap();
        let mut deliver = vec![ix::DELIVER];
        deliver.extend_from_slice(&self.delivery);
        self.send_seller(vec![instruction(
            deliver,
            vec![
                AccountMeta::new_readonly(self.seller.pubkey(), true),
                AccountMeta::new(self.deal_id, false),
            ],
        )])
        .unwrap();
        self.send_buyer(vec![instruction(
            vec![ix::CHALLENGE],
            vec![
                AccountMeta::new_readonly(self.buyer.pubkey(), true),
                AccountMeta::new(self.deal_id, false),
            ],
        )])
        .unwrap();
    }
    fn send_buyer(&mut self, ixs: Vec<Instruction>) -> Result<(), String> {
        let tx = Transaction::new_signed_with_payer(
            &ixs,
            Some(&self.buyer.pubkey()),
            &[&self.buyer],
            self.svm.latest_blockhash(),
        );
        self.svm
            .send_transaction(tx)
            .map(|_| ())
            .map_err(|e| format!("{:?}", e.err))
    }
    fn send_seller(&mut self, ixs: Vec<Instruction>) -> Result<(), String> {
        let tx = Transaction::new_signed_with_payer(
            &ixs,
            Some(&self.buyer.pubkey()),
            &[&self.buyer, &self.seller],
            self.svm.latest_blockhash(),
        );
        self.svm
            .send_transaction(tx)
            .map(|_| ())
            .map_err(|e| format!("{:?}", e.err))
    }
    fn deal(&self) -> Deal {
        let a = self.svm.get_account(&self.deal_id).unwrap();
        pod_read_unaligned(&a.data[..Deal::LEN])
    }
    fn amount(&self, key: Address) -> u64 {
        u64::from_le_bytes(
            self.svm.get_account(&key).unwrap().data[64..72]
                .try_into()
                .unwrap(),
        )
    }
}
fn instruction(data: Vec<u8>, accounts: Vec<AccountMeta>) -> Instruction {
    Instruction {
        program_id: PROGRAM_ID,
        data,
        accounts,
    }
}
fn system_transfer(from: Address, to: Address, amount: u64) -> Instruction {
    let mut data = 2u32.to_le_bytes().to_vec();
    data.extend_from_slice(&amount.to_le_bytes());
    Instruction {
        program_id: Address::default(),
        accounts: vec![AccountMeta::new(from, true), AccountMeta::new(to, false)],
        data,
    }
}
fn bytes(v: alloy_primitives::B256) -> [u8; 32] {
    let mut out = [0; 32];
    out.copy_from_slice(v.as_slice());
    out
}
fn put<T: Serialize>(dir: &std::path::Path, v: &T) -> alloy_primitives::B256 {
    write_content(dir, &serde_json::to_vec(v).unwrap())
}
fn stored_account(pubkey: Address, lamports: u64) -> reckn_svm_keeper::StoredAccountV2 {
    reckn_svm_keeper::StoredAccountV2 {
        pubkey: *pubkey.as_array(),
        lamports,
        owner: [0; 32],
        executable: false,
        rent_epoch: u64::MAX,
        data: vec![],
    }
}
fn token2022() -> Address {
    Address::from(TOKEN_2022_PROGRAM_ID)
}
fn mint_account() -> Account {
    let mut a = Account::new(1_000_000, 82, &token2022());
    a.data[44] = DECIMALS;
    a.data[45] = 1;
    a
}
fn token_account(mint: Address, owner: Address, amount: u64) -> Account {
    let mut a = Account::new(1_000_000, 165, &token2022());
    a.data[..32].copy_from_slice(mint.as_array());
    a.data[32..64].copy_from_slice(owner.as_array());
    a.data[64..72].copy_from_slice(&amount.to_le_bytes());
    a.data[108] = 1;
    a
}

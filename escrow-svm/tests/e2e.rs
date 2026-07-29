use {
    base64::{engine::general_purpose::STANDARD as BASE64, Engine},
    ed25519_dalek::{Signer as DalekSigner, SigningKey},
    litesvm::LiteSVM,
    reckn_escrow_svm::{
        ix, outcome, state, verdict_message, ResolverConfig, VerdictCommitment, CONFIG_SEED,
        DEAL_SEED, TOKEN_2022_PROGRAM_ID,
    },
    solana_account::Account,
    solana_address::Address,
    solana_ed25519_program::new_ed25519_instruction_with_signature,
    solana_instruction::{AccountMeta, Instruction},
    solana_keypair::Keypair,
    solana_sdk_ids::{system_program, sysvar::instructions},
    solana_signer::Signer,
    solana_transaction::Transaction,
    std::path::PathBuf,
};

const PROGRAM_ID: Address = Address::new_from_array([0x52; 32]);
const AMOUNT: u64 = 1_000_000;
const DECIMALS: u8 = 6;
const DELIVER_BY: u64 = 10;
const CHALLENGE_BY: u64 = 20;
const RESOLVE_BY: u64 = 30;

struct Env {
    svm: LiteSVM,
    buyer: Keypair,
    seller: Keypair,
    resolver: SigningKey,
    mint: Address,
    source: Address,
    vault: Address,
    seller_destination: Address,
    deal: Address,
    config: Address,
    seller_bytes: [u8; 32],
    buyer_bytes: [u8; 32],
    nonce: [u8; 32],
}

#[test]
fn reproduced_releases_once_and_preserves_tokens() {
    let mut env = Env::new();
    env.initialize_and_dispute();
    let commitment = env.commitment(outcome::REPRODUCED);

    let receipt = env.resolve(&commitment, false);
    assert!(receipt.is_ok(), "{receipt:?}");
    assert_eq!(env.token_amount(env.source), 0);
    assert_eq!(env.token_amount(env.vault), 0);
    assert_eq!(env.token_amount(env.seller_destination), AMOUNT);
    assert_eq!(env.total_tokens(), AMOUNT);
    assert_eq!(env.deal_state(), state::RESOLVED);
    assert!(
        env.resolve(&commitment, false).is_err(),
        "double resolve accepted"
    );
}

#[test]
fn failed_refunds_buyer_and_bad_ed25519_cannot_settle() {
    let mut env = Env::new();
    env.initialize_and_dispute();
    let commitment = env.commitment(outcome::FAILED);

    assert!(
        env.resolve(&commitment, true).is_err(),
        "wrong signed bytes accepted"
    );
    assert_eq!(env.deal_state(), state::DISPUTED);
    assert_eq!(env.token_amount(env.vault), AMOUNT);

    let mut substituted_anchor = commitment;
    substituted_anchor.anchor_hash = [0xaa; 32];
    assert!(
        env.resolve(&substituted_anchor, false).is_err(),
        "resolver could introduce a new anchor"
    );
    let mut operational_error = commitment;
    operational_error.outcome = 2;
    assert!(
        env.resolve(&operational_error, false).is_err(),
        "operational error encoded as settlement"
    );
    assert_eq!(env.deal_state(), state::DISPUTED);
    assert_eq!(env.token_amount(env.vault), AMOUNT);

    let logs = env
        .resolve_logs(&commitment, false)
        .expect("failed resolves");
    let evidence = evidence_fields(&logs);
    assert_eq!(evidence[2], [outcome::FAILED]);
    assert_eq!(
        evidence[4], [17; 32],
        "resolved Failed carries its reproducible non-zero trace"
    );
    assert_eq!(env.token_amount(env.source), AMOUNT);
    assert_eq!(env.token_amount(env.vault), 0);
    assert_eq!(env.token_amount(env.seller_destination), 0);
    assert_eq!(env.total_tokens(), AMOUNT);
}

#[test]
fn only_timeout_refund_can_finish_without_a_verdict() {
    let mut env = Env::new();
    env.initialize_and_dispute();
    assert!(
        env.timeout().is_err(),
        "timeout before resolve deadline accepted"
    );
    env.svm.warp_to_slot(RESOLVE_BY + 1);
    env.svm.expire_blockhash();
    let receipt = env.timeout();
    assert!(receipt.is_ok(), "{receipt:?}");
    assert_eq!(env.deal_state(), state::RESOLVED);
    assert_eq!(env.token_amount(env.source), AMOUNT);
    assert_eq!(env.token_amount(env.vault), 0);
    assert_eq!(env.total_tokens(), AMOUNT);
}

#[test]
fn timeout_refund_emits_seller_attributed_evidence_withheld_before_refund() {
    let mut env = Env::new();
    env.initialize_and_dispute();
    env.svm.warp_to_slot(RESOLVE_BY + 1);
    env.svm.expire_blockhash();
    let logs = env.timeout_logs().expect("timeout refund succeeds");
    let fields = evidence_fields(&logs);

    assert_eq!(fields[0], b"reckn-evidence/v1");
    assert_eq!(fields[1], env.seller_bytes, "seller is the evidence agent");
    assert_eq!(fields[2], [outcome::FAILED]);
    assert_eq!(fields[3], *env.deal.as_array());
    assert_eq!(fields[4], [0; 32], "zero trace marks evidence-withheld");
    assert_eq!(fields[5], [11; 32], "backend comes only from the deal");
    assert_eq!(fields[6], [0; 32], "timeout has no resolver authority");
    assert_eq!(
        u64::from_le_bytes(fields[7].as_slice().try_into().unwrap()),
        RESOLVE_BY + 1
    );
    assert_eq!(env.deal_state(), state::RESOLVED);
    assert_eq!(env.token_amount(env.source), AMOUNT);
    assert_eq!(env.token_amount(env.vault), 0);
}

impl Env {
    fn new() -> Self {
        let mut svm = LiteSVM::new();
        let so =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/deploy/reckn_escrow_svm.so");
        assert!(
            so.exists(),
            "build the program first: cargo build-sbf --manifest-path escrow-svm/Cargo.toml"
        );
        svm.add_program_from_file(PROGRAM_ID, so).unwrap();

        let buyer = Keypair::new_from_array([1; 32]);
        let seller = Keypair::new_from_array([2; 32]);
        let resolver = SigningKey::from_bytes(&[3; 32]);
        svm.airdrop(&buyer.pubkey(), 10_000_000_000).unwrap();
        svm.airdrop(&seller.pubkey(), 10_000_000_000).unwrap();

        let mint = Address::new_from_array([4; 32]);
        let source = Address::new_from_array([5; 32]);
        let seller_destination = Address::new_from_array([6; 32]);
        let nonce = [7; 32];
        let seller_bytes = *seller.pubkey().as_array();
        let buyer_bytes = *buyer.pubkey().as_array();
        let (deal, _) = Address::find_program_address(
            &[DEAL_SEED, buyer.pubkey().as_ref(), &seller_bytes, &nonce],
            &PROGRAM_ID,
        );
        let vault = Address::new_from_array([8; 32]);
        let (config, _) = Address::find_program_address(&[CONFIG_SEED], &PROGRAM_ID);

        svm.set_account(mint, mint_account()).unwrap();
        svm.set_account(source, token_account(mint, buyer.pubkey(), AMOUNT))
            .unwrap();
        svm.set_account(vault, token_account(mint, deal, 0))
            .unwrap();
        svm.set_account(seller_destination, token_account(mint, seller.pubkey(), 0))
            .unwrap();

        Self {
            svm,
            buyer,
            seller,
            resolver,
            mint,
            source,
            vault,
            seller_destination,
            deal,
            config,
            seller_bytes,
            buyer_bytes,
            nonce,
        }
    }

    fn initialize_and_dispute(&mut self) {
        self.send_buyer(vec![initialize_config_ix(
            self.buyer.pubkey(),
            self.config,
            self.resolver.verifying_key().to_bytes(),
        )])
        .unwrap();
        self.send_buyer(vec![self.fund_ix()]).unwrap();
        self.send_seller(vec![self.deliver_ix()]).unwrap();
        self.send_buyer(vec![self.challenge_ix()]).unwrap();
        assert_eq!(self.deal_state(), state::DISPUTED);
    }

    fn fund_ix(&self) -> Instruction {
        let mut data = vec![ix::FUND];
        data.extend_from_slice(&self.seller_bytes);
        data.extend_from_slice(&AMOUNT.to_le_bytes());
        data.extend_from_slice(&[9; 32]); // spec hash
        data.extend_from_slice(&[10; 32]); // SvmAnchorV2 hash
        data.extend_from_slice(&[11; 32]); // backend id
        data.extend_from_slice(&[12; 32]); // backend version hash
        data.extend_from_slice(&[13; 32]); // runtime profile hash
        data.extend_from_slice(&DELIVER_BY.to_le_bytes());
        data.extend_from_slice(&CHALLENGE_BY.to_le_bytes());
        data.extend_from_slice(&RESOLVE_BY.to_le_bytes());
        data.extend_from_slice(&self.nonce);
        program_ix(
            data,
            vec![
                AccountMeta::new(self.buyer.pubkey(), true),
                AccountMeta::new(self.deal, false),
                AccountMeta::new(self.source, false),
                AccountMeta::new(self.vault, false),
                AccountMeta::new_readonly(self.mint, false),
                AccountMeta::new_readonly(token_2022(), false),
                AccountMeta::new_readonly(system_program::id(), false),
            ],
        )
    }

    fn deliver_ix(&self) -> Instruction {
        let mut data = vec![ix::DELIVER];
        data.extend_from_slice(&[14; 32]);
        program_ix(
            data,
            vec![
                AccountMeta::new_readonly(self.seller.pubkey(), true),
                AccountMeta::new(self.deal, false),
            ],
        )
    }

    fn challenge_ix(&self) -> Instruction {
        program_ix(
            vec![ix::CHALLENGE],
            vec![
                AccountMeta::new_readonly(self.buyer.pubkey(), true),
                AccountMeta::new(self.deal, false),
            ],
        )
    }

    fn commitment(&self, outcome: u8) -> VerdictCommitment {
        VerdictCommitment {
            deal_id: *self.deal.as_array(),
            spec_hash: [9; 32],
            delivery_hash: [14; 32],
            anchor_hash: [10; 32],
            backend_id: [11; 32],
            backend_version_hash: [12; 32],
            runtime_profile_hash: [13; 32],
            prestate_root: [15; 32],
            outcome,
            result_hash: [16; 32],
            trace_hash: [17; 32],
        }
    }

    fn resolve(
        &mut self,
        commitment: &VerdictCommitment,
        sign_wrong_message: bool,
    ) -> Result<(), String> {
        self.resolve_logs(commitment, sign_wrong_message)
            .map(|_| ())
    }

    fn resolve_logs(
        &mut self,
        commitment: &VerdictCommitment,
        sign_wrong_message: bool,
    ) -> Result<Vec<String>, String> {
        let config = ResolverConfig {
            bump: 0,
            _pad: [0; 7],
            admin: self.buyer_bytes,
            resolver: self.resolver.verifying_key().to_bytes(),
            backend_id: [11; 32],
            backend_version_hash: [12; 32],
            runtime_profile_hash: [13; 32],
            cluster_genesis_hash: [18; 32],
        };
        let program_id_bytes = *PROGRAM_ID.as_array();
        let message = verdict_message(&program_id_bytes, &config, commitment);
        let signed = if sign_wrong_message {
            b"wrong verdict".as_slice()
        } else {
            &message
        };
        let signature = self.resolver.sign(signed).to_bytes();
        let ed = new_ed25519_instruction_with_signature(
            signed,
            &signature,
            &self.resolver.verifying_key().to_bytes(),
        );
        let mut encoded = [0u8; VerdictCommitment::LEN];
        commitment.encode(&mut encoded);
        let destination = if commitment.outcome == outcome::REPRODUCED {
            self.seller_destination
        } else {
            self.source
        };
        let mut data = Vec::with_capacity(1 + encoded.len());
        data.push(ix::RESOLVE);
        data.extend_from_slice(&encoded);
        let resolve = program_ix(
            data,
            vec![
                AccountMeta::new(self.deal, false),
                AccountMeta::new(self.vault, false),
                AccountMeta::new(destination, false),
                AccountMeta::new_readonly(self.mint, false),
                AccountMeta::new_readonly(token_2022(), false),
                AccountMeta::new_readonly(self.config, false),
                AccountMeta::new_readonly(instructions::id(), false),
            ],
        );
        self.send_buyer_logs(vec![ed, resolve])
    }

    fn timeout(&mut self) -> Result<(), String> {
        self.timeout_logs().map(|_| ())
    }

    fn timeout_logs(&mut self) -> Result<Vec<String>, String> {
        self.send_buyer_logs(vec![program_ix(
            vec![ix::TIMEOUT_REFUND],
            vec![
                AccountMeta::new(self.deal, false),
                AccountMeta::new(self.vault, false),
                AccountMeta::new(self.source, false),
                AccountMeta::new_readonly(self.mint, false),
                AccountMeta::new_readonly(token_2022(), false),
            ],
        )])
    }

    fn send_buyer(&mut self, ixs: Vec<Instruction>) -> Result<(), String> {
        self.send_buyer_logs(ixs).map(|_| ())
    }

    fn send_buyer_logs(&mut self, ixs: Vec<Instruction>) -> Result<Vec<String>, String> {
        let transaction = Transaction::new_signed_with_payer(
            &ixs,
            Some(&self.buyer.pubkey()),
            &[&self.buyer],
            self.svm.latest_blockhash(),
        );
        self.svm
            .send_transaction(transaction)
            .map(|metadata| metadata.logs)
            .map_err(|failure| format!("{:?}: {}", failure.err, failure.meta.pretty_logs()))
    }

    fn send_seller(&mut self, ixs: Vec<Instruction>) -> Result<(), String> {
        let transaction = Transaction::new_signed_with_payer(
            &ixs,
            Some(&self.buyer.pubkey()),
            &[&self.buyer, &self.seller],
            self.svm.latest_blockhash(),
        );
        self.svm
            .send_transaction(transaction)
            .map(|_| ())
            .map_err(|failure| format!("{:?}: {}", failure.err, failure.meta.pretty_logs()))
    }

    fn token_amount(&self, address: Address) -> u64 {
        u64::from_le_bytes(
            self.svm.get_account(&address).unwrap().data[64..72]
                .try_into()
                .unwrap(),
        )
    }
    fn total_tokens(&self) -> u64 {
        self.token_amount(self.source)
            + self.token_amount(self.vault)
            + self.token_amount(self.seller_destination)
    }
    fn deal_state(&self) -> u8 {
        self.svm.get_account(&self.deal).unwrap().data[1]
    }
}

fn evidence_fields(logs: &[String]) -> Vec<Vec<u8>> {
    let line = logs
        .iter()
        .find(|line| line.starts_with("Program data: "))
        .unwrap_or_else(|| panic!("ReputationEvidence sol_log_data: {logs:?}"));
    let data = line.strip_prefix("Program data: ").unwrap();
    data.split_whitespace()
        .map(|field| BASE64.decode(field).expect("base64 evidence field"))
        .collect()
}

fn initialize_config_ix(admin: Address, config: Address, resolver: [u8; 32]) -> Instruction {
    let mut data = vec![ix::INITIALIZE_RESOLVER_CONFIG];
    data.extend_from_slice(admin.as_array());
    data.extend_from_slice(&resolver);
    data.extend_from_slice(&[11; 32]);
    data.extend_from_slice(&[12; 32]);
    data.extend_from_slice(&[13; 32]);
    data.extend_from_slice(&[18; 32]);
    program_ix(
        data,
        vec![
            AccountMeta::new(admin, true),
            AccountMeta::new(config, false),
            AccountMeta::new_readonly(system_program::id(), false),
        ],
    )
}

fn program_ix(data: Vec<u8>, accounts: Vec<AccountMeta>) -> Instruction {
    Instruction {
        program_id: PROGRAM_ID,
        accounts,
        data,
    }
}

fn token_2022() -> Address {
    Address::from(TOKEN_2022_PROGRAM_ID)
}

fn mint_account() -> Account {
    let mut account = Account::new(1_000_000, 82, &token_2022());
    account.data[44] = DECIMALS;
    account.data[45] = 1; // Mint::is_initialized
    account
}

fn token_account(mint: Address, owner: Address, amount: u64) -> Account {
    let mut account = Account::new(1_000_000, 165, &token_2022());
    account.data[0..32].copy_from_slice(mint.as_array());
    account.data[32..64].copy_from_slice(owner.as_array());
    account.data[64..72].copy_from_slice(&amount.to_le_bytes());
    account.data[108] = 1; // AccountState::Initialized
    account
}

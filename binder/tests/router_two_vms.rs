//! Act 3 proof: one routing engine dispatches both VMs, while every VM-specific
//! input remains content-addressed and offline.

use alloy_primitives::{keccak256, Bytes, B256, U256};
use reckn_binder::{
    adapters::{EvmBackend, SvmBackend},
    BackendRouter, ContentHash, ReexecRequestV1, RouterError, VerdictEnvelopeV1,
    VerifyingArtifactStore,
};
use reckn_evm_content::{
    canonical_json, hash, AnchorV11Json, DeliveryV11, PredicateJson, SpecV11Json, WitnessJson,
};
use reckn_reexec_evm::testkit::{addr, anchored_identity_witness};
use reckn_reexec_svm::{
    runtime_profile_hash, snapshot_commitment, AccountSnapshotV2, PrestateSnapshotV2,
    RuntimeProfileV1,
};
use reckn_svm_keeper::{
    StoredAccountV2, StoredAnchorV2, StoredDeliveryV1, StoredPredicateV1, StoredRuntimeProfileV1,
    StoredSnapshotV2, StoredSpecV1,
};
use solana_instruction::{AccountMeta, Instruction};
use solana_keypair::Keypair;
use solana_pubkey::Pubkey;
use solana_signer::Signer;
use solana_transaction::Transaction;
use std::collections::HashMap;

const EVM_BACKEND: B256 = B256::repeat_byte(0xe1);
const EVM_VERSION: B256 = B256::repeat_byte(0xe2);
const SVM_BACKEND: B256 = B256::repeat_byte(0x51);
const SVM_VERSION: B256 = B256::repeat_byte(0x52);

type ArtifactMap = HashMap<ContentHash, Vec<u8>>;

fn b32(value: B256) -> [u8; 32] {
    let mut out = [0; 32];
    out.copy_from_slice(value.as_slice());
    out
}

fn request(
    deal_id: u8,
    backend_id: B256,
    backend_version_hash: B256,
    spec: Vec<u8>,
    delivery: Vec<u8>,
    prestate_anchor: Vec<u8>,
) -> ReexecRequestV1 {
    ReexecRequestV1 {
        deal_id: B256::repeat_byte(deal_id),
        backend_id,
        backend_version_hash,
        spec_hash: hash(&spec),
        spec,
        delivery_hash: hash(&delivery),
        delivery,
        prestate_anchor_hash: hash(&prestate_anchor),
        prestate_anchor,
    }
}

/// Build a valid proof-carrying EVM delivery.  The exact testkit builder is the
/// EVM unit-test fixture, so adapters cannot accidentally test against a
/// weaker, drifted pseudo-witness.
fn evm_case(
    deal_id: u8,
    calldata: Bytes,
    expected_result_hash: B256,
    artifacts: &mut ArtifactMap,
) -> (ReexecRequestV1, B256) {
    let caller = addr(0xaa);
    let target = addr(0xbb);
    let (anchor, witness) = anchored_identity_witness(caller, target);
    let anchor_bytes = canonical_json(&AnchorV11Json {
        chain_id: anchor.chain_id,
        block_number: anchor.block_number,
        block_hash: anchor.block_hash,
        state_root: anchor.state_root,
        timestamp: anchor.timestamp,
        base_fee: anchor.base_fee,
        block_gas_limit: anchor.block_gas_limit,
        coinbase: anchor.coinbase,
        prevrandao: anchor.prevrandao,
        spec_id: "CANCUN".into(),
    })
    .unwrap();
    let witness_bytes = canonical_json(&WitnessJson::from(witness)).unwrap();
    let witness_hash = hash(&witness_bytes);
    artifacts.insert(witness_hash, witness_bytes);

    let spec = canonical_json(&SpecV11Json {
        backend_id: EVM_BACKEND,
        backend_version_hash: EVM_VERSION,
        prestate_anchor_hash: hash(&anchor_bytes),
        predicate: PredicateJson::ResultEquals {
            expected_result_hash,
        },
    })
    .unwrap();
    let delivery = canonical_json(&DeliveryV11 {
        caller,
        target,
        calldata,
        value: U256::ZERO,
        gas_limit: 200_000,
        witness_content_hash: Some(witness_hash),
        header_content_hash: None,
    })
    .unwrap();
    (
        request(
            deal_id,
            EVM_BACKEND,
            EVM_VERSION,
            spec,
            delivery,
            anchor_bytes,
        ),
        witness_hash,
    )
}

fn system_transfer(from: Pubkey, to: Pubkey, lamports: u64) -> Instruction {
    let mut data = 2u32.to_le_bytes().to_vec();
    data.extend_from_slice(&lamports.to_le_bytes());
    Instruction {
        program_id: Pubkey::new_from_array([0; 32]),
        accounts: vec![AccountMeta::new(from, true), AccountMeta::new(to, false)],
        data,
    }
}

fn stored_account(pubkey: Pubkey, lamports: u64) -> StoredAccountV2 {
    StoredAccountV2 {
        pubkey: pubkey.to_bytes(),
        lamports,
        owner: [0; 32],
        executable: false,
        rent_epoch: u64::MAX,
        data: vec![],
    }
}

/// Build the same closed-world System-transfer bundle exercised by the SVM
/// keeper full-loop test, but expose its content graph to the binder adapter.
fn svm_case(
    deal_id: u8,
    transfer: u64,
    expected: u64,
    artifacts: &mut ArtifactMap,
) -> (ReexecRequestV1, B256) {
    let signer = Keypair::new_from_array([0x44; 32]);
    let recipient = Pubkey::new_from_array([0x45; 32]);
    let mut transaction = Transaction::new_with_payer(
        &[system_transfer(signer.pubkey(), recipient, transfer)],
        Some(&signer.pubkey()),
    );
    transaction.sign(&[&signer], Default::default());

    let profile = RuntimeProfileV1::default();
    let typed_snapshot = PrestateSnapshotV2 {
        accounts: vec![
            AccountSnapshotV2 {
                pubkey: signer.pubkey(),
                lamports: 1_000_000_000,
                owner: Pubkey::new_from_array([0; 32]),
                executable: false,
                rent_epoch: u64::MAX,
                data: vec![],
            },
            AccountSnapshotV2 {
                pubkey: recipient,
                lamports: 1,
                owner: Pubkey::new_from_array([0; 32]),
                executable: false,
                rent_epoch: u64::MAX,
                data: vec![],
            },
        ],
    };
    let snapshot = StoredSnapshotV2 {
        accounts: vec![
            stored_account(signer.pubkey(), 1_000_000_000),
            stored_account(recipient, 1),
        ],
    };
    let snapshot_bytes = serde_json::to_vec(&snapshot).unwrap();
    let snapshot_hash = hash(&snapshot_bytes);
    artifacts.insert(snapshot_hash, snapshot_bytes);

    let profile_stored = StoredRuntimeProfileV1 {
        allowed_ambient_programs: vec![[0; 32]],
    };
    let profile_bytes = serde_json::to_vec(&profile_stored).unwrap();
    let profile_content_hash = hash(&profile_bytes);
    artifacts.insert(profile_content_hash, profile_bytes);
    let runtime_hash = runtime_profile_hash(&profile).unwrap();

    let anchor = StoredAnchorV2 {
        state_commitment: b32(snapshot_commitment(&typed_snapshot, &profile).unwrap()),
        cluster_genesis_hash: [0x61; 32],
        slot: 21_000_000,
        blockhash: transaction.message.recent_blockhash.to_bytes(),
        bank_hash: [0x62; 32],
        parent_bank_hash: [0; 32],
        signature_count: 0,
        snapshot_is_complete: false,
            full_snapshot_hash: [0; 32],
        runtime_profile_hash: b32(runtime_hash),
        snapshot_archive_hash: b32(snapshot_hash),
        snapshot_format_version: 2,
    };
    let anchor_bytes = serde_json::to_vec(&anchor).unwrap();
    let spec = serde_json::to_vec(&StoredSpecV1 {
        backend_id: b32(SVM_BACKEND),
        backend_version_hash: b32(SVM_VERSION),
        anchor_hash: b32(hash(&anchor_bytes)),
        runtime_profile_content_hash: b32(profile_content_hash),
        predicate: StoredPredicateV1::LamportsEquals {
            account: recipient.to_bytes(),
            expected,
        },
    })
    .unwrap();
    let delivery = serde_json::to_vec(&StoredDeliveryV1 {
        transaction: bincode::serialize(&transaction).unwrap(),
    })
    .unwrap();
    (
        request(
            deal_id,
            SVM_BACKEND,
            SVM_VERSION,
            spec,
            delivery,
            anchor_bytes,
        ),
        snapshot_hash,
    )
}

fn router() -> BackendRouter {
    let mut router = BackendRouter::new();
    router.register(Box::new(EvmBackend {
        backend_id: EVM_BACKEND,
        backend_version_hash: EVM_VERSION,
    }));
    router.register(Box::new(SvmBackend {
        backend_id: SVM_BACKEND,
        backend_version_hash: SVM_VERSION,
    }));
    router
}

fn assert_envelope_type(_: &VerdictEnvelopeV1) {}

#[test]
fn one_router_reexecutes_evm_and_svm_and_fails_closed_on_artifacts() {
    let good = Bytes::from_static(b"swap-out>=1000USDC-good-output--");
    let bad = Bytes::from_static(b"swap-out==5USDC-actually-bad----");
    let expected = keccak256(good.as_ref());
    let mut artifacts = ArtifactMap::new();
    let (evm_honest, witness_hash) = evm_case(0x01, good, expected, &mut artifacts);
    let (evm_false, _) = evm_case(0x02, bad, expected, &mut artifacts);
    let (svm_honest, _) = svm_case(0x03, 2_000_000, 2_000_001, &mut artifacts);
    let (svm_false, snapshot_hash) = svm_case(0x04, 1_500_000, 2_000_001, &mut artifacts);
    let resolver = VerifyingArtifactStore::new(|hash| artifacts.get(&hash).cloned());
    let router = router();

    let evm_honest_out: VerdictEnvelopeV1 = router.route(&evm_honest, &resolver).unwrap();
    let evm_false_out: VerdictEnvelopeV1 = router.route(&evm_false, &resolver).unwrap();
    let svm_honest_out: VerdictEnvelopeV1 = router.route(&svm_honest, &resolver).unwrap();
    let svm_false_out: VerdictEnvelopeV1 = router.route(&svm_false, &resolver).unwrap();
    assert_envelope_type(&evm_honest_out);
    assert_envelope_type(&evm_false_out);
    assert_envelope_type(&svm_honest_out);
    assert_envelope_type(&svm_false_out);
    assert_eq!(evm_honest_out.record.outcome, 1, "EVM honest -> Reproduced");
    assert_eq!(evm_false_out.record.outcome, 2, "EVM false -> Failed");
    assert_eq!(svm_honest_out.record.outcome, 1, "SVM honest -> Reproduced");
    assert_eq!(svm_false_out.record.outcome, 2, "SVM false -> Failed");

    let mut wrong_backend = evm_honest.clone();
    wrong_backend.backend_id = B256::repeat_byte(0x99);
    assert!(matches!(
        router.route(&wrong_backend, &resolver),
        Err(RouterError::UnknownBackend { .. })
    ));

    let missing = VerifyingArtifactStore::new(|_| None);
    assert!(matches!(
        router.route(&svm_honest, &missing),
        Err(RouterError::Backend(_))
    ));

    let mut tampered_artifacts = artifacts.clone();
    tampered_artifacts
        .get_mut(&witness_hash)
        .unwrap()
        .push(0xff);
    let tampered = VerifyingArtifactStore::new(|hash| tampered_artifacts.get(&hash).cloned());
    assert!(matches!(
        router.route(&evm_honest, &tampered),
        Err(RouterError::Backend(_))
    ));
    assert!(
        artifacts.contains_key(&snapshot_hash),
        "SVM snapshot is a separately committed transitive artifact"
    );
}

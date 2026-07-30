//! Concrete offline adapters. Artifact reads are always hash-addressed.
use crate::{
    BackendArtifactResolver, BackendError, BackendId, ContentHash, ReexecBackend, ReexecRequestV1,
    VerdictEnvelopeV1,
};
use alloy_primitives::B256;
use reckn_evm_content::{AnchorV11Json, DeliveryV11, SpecV11Json, WitnessJson};
use reckn_record::ReexecCommitmentsV1 as SvmCommitments;
use reckn_reexec_evm::{
    replay as evm_replay, EvmAnchorV1, EvmCallPlanV1, PrestateWitnessV1, ReexecCommitmentsV1,
};
use reckn_reexec_svm::{
    replay as svm_replay, AccountSnapshotV2, PredicateV1 as SvmPredicate, PrestateSnapshotV2,
    RuntimeProfileV1, SvmAnchorV2, SvmPlanV2,
};
use reckn_svm_keeper::{
    StoredAnchorV2, StoredDeliveryV1, StoredPredicateV1, StoredRuntimeProfileV1, StoredSnapshotV2,
    StoredSpecV1,
};
use solana_pubkey::Pubkey;

fn b32(v: [u8; 32]) -> B256 {
    B256::from(v)
}
fn pubkey(v: [u8; 32]) -> Pubkey {
    Pubkey::new_from_array(v)
}

pub struct EvmBackend {
    pub backend_id: BackendId,
    pub backend_version_hash: ContentHash,
}

/// Offline SVM adapter.  Snapshot and runtime profile are resolved only from
/// hashes embedded in already-committed spec/anchor bytes.
pub struct SvmBackend {
    pub backend_id: BackendId,
    pub backend_version_hash: ContentHash,
}
impl ReexecBackend for SvmBackend {
    fn id(&self) -> BackendId {
        self.backend_id
    }
    fn version(&self) -> ContentHash {
        self.backend_version_hash
    }
    fn verdict(
        &self,
        r: &ReexecRequestV1,
        a: &dyn BackendArtifactResolver,
    ) -> Result<VerdictEnvelopeV1, BackendError> {
        let spec: StoredSpecV1 =
            serde_json::from_slice(&r.spec).map_err(|e| BackendError(e.to_string()))?;
        if b32(spec.backend_id) != r.backend_id
            || b32(spec.backend_version_hash) != r.backend_version_hash
            || b32(spec.anchor_hash) != r.prestate_anchor_hash
        {
            return Err(BackendError("SVM spec/request commitment mismatch".into()));
        }
        let delivery: StoredDeliveryV1 =
            serde_json::from_slice(&r.delivery).map_err(|e| BackendError(e.to_string()))?;
        let anchor: StoredAnchorV2 =
            serde_json::from_slice(&r.prestate_anchor).map_err(|e| BackendError(e.to_string()))?;
        let snapshot: StoredSnapshotV2 =
            serde_json::from_slice(&a.resolve(b32(anchor.snapshot_archive_hash))?)
                .map_err(|e| BackendError(e.to_string()))?;
        let profile: StoredRuntimeProfileV1 =
            serde_json::from_slice(&a.resolve(b32(spec.runtime_profile_content_hash))?)
                .map_err(|e| BackendError(e.to_string()))?;
        let plan = SvmPlanV2 {
            transaction: bincode::deserialize(&delivery.transaction)
                .map_err(|e| BackendError(e.to_string()))?,
        };
        let predicate = match spec.predicate {
            StoredPredicateV1::ResultEquals {
                expected_result_hash,
            } => SvmPredicate::ResultEquals {
                expected_result_hash: b32(expected_result_hash),
            },
            StoredPredicateV1::LamportsEquals { account, expected } => {
                SvmPredicate::LamportsEquals {
                    account: pubkey(account),
                    expected,
                }
            }
            StoredPredicateV1::LamportsBounded { account, min, max } => {
                SvmPredicate::LamportsBounded {
                    account: pubkey(account),
                    min,
                    max,
                }
            }
        };
        let out = svm_replay(
            &SvmAnchorV2 {
                state_commitment: b32(anchor.state_commitment),
                cluster_genesis_hash: b32(anchor.cluster_genesis_hash),
                slot: anchor.slot,
                blockhash: b32(anchor.blockhash),
                bank_hash: b32(anchor.bank_hash),
                runtime_profile_hash: b32(anchor.runtime_profile_hash),
                snapshot_archive_hash: b32(anchor.snapshot_archive_hash),
                snapshot_format_version: anchor.snapshot_format_version,
            },
            &PrestateSnapshotV2 {
                accounts: snapshot
                    .accounts
                    .into_iter()
                    .map(|x| AccountSnapshotV2 {
                        pubkey: pubkey(x.pubkey),
                        lamports: x.lamports,
                        owner: pubkey(x.owner),
                        executable: x.executable,
                        rent_epoch: x.rent_epoch,
                        data: x.data,
                    })
                    .collect(),
            },
            &RuntimeProfileV1 {
                allowed_ambient_programs: profile
                    .allowed_ambient_programs
                    .into_iter()
                    .map(pubkey)
                    .collect(),
            },
            &plan,
            &predicate,
            &SvmCommitments {
                backend_id: r.backend_id,
                backend_version_hash: r.backend_version_hash,
                spec_hash: r.spec_hash,
                delivery_hash: r.delivery_hash,
                prestate_anchor_hash: r.prestate_anchor_hash,
            },
        )
        .map_err(|e| BackendError(format!("operational SVM replay: {e:?}")))?;
        Ok(VerdictEnvelopeV1 {
            deal_id: r.deal_id,
            trace_hash: out.trace_hash,
            record: out.record,
        })
    }
}
impl ReexecBackend for EvmBackend {
    fn id(&self) -> BackendId {
        self.backend_id
    }
    fn version(&self) -> ContentHash {
        self.backend_version_hash
    }
    fn verdict(
        &self,
        r: &ReexecRequestV1,
        a: &dyn BackendArtifactResolver,
    ) -> Result<VerdictEnvelopeV1, BackendError> {
        let spec: SpecV11Json =
            serde_json::from_slice(&r.spec).map_err(|e| BackendError(e.to_string()))?;
        if spec.backend_id != r.backend_id
            || spec.backend_version_hash != r.backend_version_hash
            || spec.prestate_anchor_hash != r.prestate_anchor_hash
        {
            return Err(BackendError("EVM spec/request commitment mismatch".into()));
        }
        let delivery: DeliveryV11 =
            serde_json::from_slice(&r.delivery).map_err(|e| BackendError(e.to_string()))?;
        let witness_hash = delivery.require_witness().map_err(BackendError)?;
        let witness: PrestateWitnessV1 =
            serde_json::from_slice::<WitnessJson>(&a.resolve(witness_hash)?)
                .map_err(|e| BackendError(e.to_string()))?
                .into();
        let anchor: EvmAnchorV1 = serde_json::from_slice::<AnchorV11Json>(&r.prestate_anchor)
            .map_err(|e| BackendError(e.to_string()))?
            .try_into()
            .map_err(BackendError)?;
        let plan: EvmCallPlanV1 = delivery.into();
        let predicate = spec.predicate.into();
        let out = evm_replay(
            &anchor,
            &witness,
            &plan,
            &predicate,
            &ReexecCommitmentsV1 {
                backend_id: r.backend_id,
                backend_version_hash: r.backend_version_hash,
                spec_hash: r.spec_hash,
                delivery_hash: r.delivery_hash,
                prestate_anchor_hash: r.prestate_anchor_hash,
            },
        )
        .map_err(|e| BackendError(format!("operational EVM replay: {e:?}")))?;
        Ok(VerdictEnvelopeV1 {
            deal_id: r.deal_id,
            trace_hash: out.trace_hash,
            record: out.record,
        })
    }
}

//! Concrete offline adapters. Artifact reads are always hash-addressed.
use crate::{
    BackendArtifactResolver, BackendError, BackendId, ContentHash, ReexecBackend, ReexecRequestV1,
    VerdictEnvelopeV1,
};
use reckn_evm_content::{AnchorV11Json, DeliveryV11, SpecV11Json, WitnessJson};
use reckn_reexec_evm::{
    replay as evm_replay, EvmAnchorV1, EvmCallPlanV1, PrestateWitnessV1, ReexecCommitmentsV1,
};

pub struct EvmBackend {
    pub backend_id: BackendId,
    pub backend_version_hash: ContentHash,
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

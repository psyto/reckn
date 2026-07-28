//! Reckn cross-VM binder (Act 3, routing spine).
//!
//! A dispute commits a `backend_id` (which VM re-executes it) and the opaque,
//! content-addressed bytes of its spec / delivery / prestate anchor. The binder
//! does the VM-neutral part:
//!
//! 1. checks the committed bytes hash to their committed hashes (SHA-256),
//! 2. routes the request to the registered [`ReexecBackend`] whose `(id, version)`
//!    matches — never silently to a different VM,
//! 3. returns a [`VerdictEnvelopeV1`] carrying the shared [`ReplayRecordV1`], and
//!    checks the backend didn't claim a different VM than it was asked for.
//!
//! Because the record codec is shared (`reckn-record`), an EVM verdict and a
//! Solana verdict are the *same type* — the whole reason this routing layer is
//! thin. Each VM's backend adapter (deserializing its own anchor/plan/predicate
//! and calling `reexec-evm` / `reexec-svm`) plugs in behind this trait; those
//! adapters, and the cross-chain settlement around them (finality on both chains,
//! propagating a verdict from the executing chain to the paying chain, and
//! double-settlement rules), are the frame-thick next step — deliberately not in
//! this routing core.

use alloy_primitives::B256;
use reckn_record::ReplayRecordV1;
use sha2::{Digest, Sha256};

pub type BackendId = B256;
pub type ContentHash = B256;

/// The VM-neutral re-execution request the binder routes. `spec` / `delivery` /
/// `prestate_anchor` are opaque backend-owned bytes; the binder only checks they
/// hash to the committed hashes and hands them to the chosen backend.
#[derive(Clone, Debug)]
pub struct ReexecRequestV1 {
    pub deal_id: B256,
    pub backend_id: BackendId,
    pub backend_version_hash: ContentHash,
    pub spec: Vec<u8>,
    pub spec_hash: ContentHash,
    pub delivery: Vec<u8>,
    pub delivery_hash: ContentHash,
    pub prestate_anchor: Vec<u8>,
    pub prestate_anchor_hash: ContentHash,
}

/// A routed verdict. The record is the shared, VM-neutral [`ReplayRecordV1`];
/// `trace_hash` is its digest. Same type whether EVM or Solana produced it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerdictEnvelopeV1 {
    pub deal_id: B256,
    pub record: ReplayRecordV1,
    pub trace_hash: B256,
}

/// A re-execution backend for one VM. Its `verdict` deserializes the request's
/// opaque bytes internally and returns the shared record. An operational failure
/// (missing/inauthentic input) must be `Err(Operational)`, never a verdict.
pub trait ReexecBackend {
    fn id(&self) -> BackendId;
    fn version(&self) -> ContentHash;
    fn verdict(&self, request: &ReexecRequestV1) -> Result<VerdictEnvelopeV1, BackendError>;
}

/// A backend-side failure that is not a buyer/seller verdict.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BackendError(pub String);

/// Why the binder could not produce a routed verdict. None of these are verdicts.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RouterError {
    /// A committed content blob does not hash to its committed hash.
    ContentHashMismatch { field: &'static str, expected: ContentHash, got: ContentHash },
    /// No registered backend matches the deal's committed `(backend_id, version)`.
    UnknownBackend { backend_id: BackendId, backend_version_hash: ContentHash },
    /// Two backends registered the same `(id, version)`.
    AmbiguousBackend { backend_id: BackendId },
    /// The backend returned a record for a different VM than it was asked for.
    BackendIdentityMismatch { asked: BackendId, returned: BackendId },
    /// The chosen backend reported an operational (non-verdict) error.
    Backend(BackendError),
}

/// Routes a dispute to the backend named by its committed `backend_id`.
#[derive(Default)]
pub struct BackendRouter {
    backends: Vec<Box<dyn ReexecBackend>>,
}

impl BackendRouter {
    pub fn new() -> Self {
        Self { backends: Vec::new() }
    }

    pub fn register(&mut self, backend: Box<dyn ReexecBackend>) {
        self.backends.push(backend);
    }

    /// VM-neutral routing: verify content hashes, find the exact `(id, version)`
    /// backend, dispatch, and confirm it answered for the VM it was asked for.
    pub fn route(&self, request: &ReexecRequestV1) -> Result<VerdictEnvelopeV1, RouterError> {
        check_hash("spec", &request.spec, request.spec_hash)?;
        check_hash("delivery", &request.delivery, request.delivery_hash)?;
        check_hash("prestate_anchor", &request.prestate_anchor, request.prestate_anchor_hash)?;

        let mut matches = self
            .backends
            .iter()
            .filter(|b| b.id() == request.backend_id && b.version() == request.backend_version_hash);
        let backend = matches.next().ok_or(RouterError::UnknownBackend {
            backend_id: request.backend_id,
            backend_version_hash: request.backend_version_hash,
        })?;
        if matches.next().is_some() {
            return Err(RouterError::AmbiguousBackend {
                backend_id: request.backend_id,
            });
        }

        let envelope = backend.verdict(request).map_err(RouterError::Backend)?;
        // A backend cannot answer for a VM other than the one it was routed as.
        if envelope.record.backend_id != request.backend_id {
            return Err(RouterError::BackendIdentityMismatch {
                asked: request.backend_id,
                returned: envelope.record.backend_id,
            });
        }
        Ok(envelope)
    }
}

fn sha256(bytes: &[u8]) -> B256 {
    B256::from_slice(&Sha256::digest(bytes))
}

fn check_hash(field: &'static str, bytes: &[u8], expected: ContentHash) -> Result<(), RouterError> {
    let got = sha256(bytes);
    if got != expected {
        return Err(RouterError::ContentHashMismatch { field, expected, got });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use reckn_record::ReexecCommitmentsV1;

    // A stand-in backend: it emits a record for its own VM id and a fixed outcome.
    struct MockBackend {
        id: BackendId,
        version: ContentHash,
        outcome: u8,
    }

    impl ReexecBackend for MockBackend {
        fn id(&self) -> BackendId {
            self.id
        }
        fn version(&self) -> ContentHash {
            self.version
        }
        fn verdict(&self, request: &ReexecRequestV1) -> Result<VerdictEnvelopeV1, BackendError> {
            let record = ReplayRecordV1::new(
                &ReexecCommitmentsV1 {
                    backend_id: self.id,
                    backend_version_hash: self.version,
                    spec_hash: request.spec_hash,
                    delivery_hash: request.delivery_hash,
                    prestate_anchor_hash: request.prestate_anchor_hash,
                },
                B256::from([0x06; 32]),
                self.outcome,
                B256::from([0x07; 32]),
            );
            let trace_hash = record.trace_hash();
            Ok(VerdictEnvelopeV1 {
                deal_id: request.deal_id,
                record,
                trace_hash,
            })
        }
    }

    const EVM_ID: BackendId = B256::repeat_byte(0xee);
    const SVM_ID: BackendId = B256::repeat_byte(0x55);
    const V1: ContentHash = B256::repeat_byte(0x01);

    fn router() -> BackendRouter {
        let mut r = BackendRouter::new();
        r.register(Box::new(MockBackend { id: EVM_ID, version: V1, outcome: 1 }));
        r.register(Box::new(MockBackend { id: SVM_ID, version: V1, outcome: 2 }));
        r
    }

    fn request(backend_id: BackendId, version: ContentHash) -> ReexecRequestV1 {
        let spec = b"spec-bytes".to_vec();
        let delivery = b"delivery-bytes".to_vec();
        let anchor = b"anchor-bytes".to_vec();
        ReexecRequestV1 {
            deal_id: B256::repeat_byte(0xd1),
            backend_id,
            backend_version_hash: version,
            spec_hash: sha256(&spec),
            spec,
            delivery_hash: sha256(&delivery),
            delivery,
            prestate_anchor_hash: sha256(&anchor),
            prestate_anchor: anchor,
        }
    }

    #[test]
    fn routes_to_the_committed_backend_and_shares_the_record_type() {
        let r = router();
        // Same request shape, different committed backend_id -> different VM runs it,
        // and both come back as the one VerdictEnvelopeV1 / ReplayRecordV1 type.
        let evm = r.route(&request(EVM_ID, V1)).unwrap();
        assert_eq!(evm.record.backend_id, EVM_ID);
        assert_eq!(evm.record.outcome, 1);
        assert_eq!(evm.trace_hash, evm.record.trace_hash());

        let svm = r.route(&request(SVM_ID, V1)).unwrap();
        assert_eq!(svm.record.backend_id, SVM_ID);
        assert_eq!(svm.record.outcome, 2);
        // Same deal-neutral fields, different VM -> different trace hash.
        assert_ne!(evm.trace_hash, svm.trace_hash);
    }

    #[test]
    fn unknown_backend_is_not_routed_to_the_wrong_vm() {
        let r = router();
        let err = r.route(&request(B256::repeat_byte(0xab), V1)).unwrap_err();
        assert!(matches!(err, RouterError::UnknownBackend { .. }));
        // A registered id but the wrong version also fails closed.
        let err = r.route(&request(EVM_ID, B256::repeat_byte(0x02))).unwrap_err();
        assert!(matches!(err, RouterError::UnknownBackend { .. }));
    }

    #[test]
    fn tampered_content_is_rejected_before_dispatch() {
        let r = router();
        let mut req = request(EVM_ID, V1);
        req.spec.push(0xff); // bytes no longer match spec_hash
        let err = r.route(&req).unwrap_err();
        assert!(matches!(
            err,
            RouterError::ContentHashMismatch { field: "spec", .. }
        ));
    }

    #[test]
    fn backend_cannot_answer_for_a_different_vm() {
        // A backend registered under EVM_ID that lies and returns an SVM record.
        struct LiarBackend;
        impl ReexecBackend for LiarBackend {
            fn id(&self) -> BackendId {
                EVM_ID
            }
            fn version(&self) -> ContentHash {
                V1
            }
            fn verdict(&self, request: &ReexecRequestV1) -> Result<VerdictEnvelopeV1, BackendError> {
                let record = ReplayRecordV1::new(
                    &ReexecCommitmentsV1 {
                        backend_id: SVM_ID, // <- lies about its VM
                        ..Default::default()
                    },
                    B256::ZERO,
                    1,
                    B256::ZERO,
                );
                let trace_hash = record.trace_hash();
                Ok(VerdictEnvelopeV1 { deal_id: request.deal_id, record, trace_hash })
            }
        }
        let mut r = BackendRouter::new();
        r.register(Box::new(LiarBackend));
        let err = r.route(&request(EVM_ID, V1)).unwrap_err();
        assert!(matches!(err, RouterError::BackendIdentityMismatch { .. }));
    }
}

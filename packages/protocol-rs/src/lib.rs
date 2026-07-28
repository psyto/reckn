//! Canonical, VM-neutral Reckn verdict record.
//!
//! `trace_hash` in a Reckn verdict is the SHA-256 of a canonical
//! [`ReplayRecordV1`]. Every re-execution backend — EVM (revm) today, Solana
//! (LiteSVM) next — folds its VM-specific work into the same 32-byte commitments
//! (`spec_hash` / `delivery_hash` / `prestate_anchor_hash` / `result_hash`) and
//! emits this identical record, so a verdict is comparable and reproducible
//! across VMs. The encoding is specified in
//! `packages/protocol/REPLAY_RECORD_V1.md`; this crate is the reference Rust
//! implementation shared by all backends so they can never drift.

use alloy_primitives::B256;
use sha2::{Digest, Sha256};

/// Commitment hashes that bind a replay to a specific deal. Opaque, backend-owned
/// content the engine folds into the record.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ReexecCommitmentsV1 {
    pub backend_id: B256,
    pub backend_version_hash: B256,
    pub spec_hash: B256,
    pub delivery_hash: B256,
    pub prestate_anchor_hash: B256,
}

/// Canonical, VM-neutral record of an adjudicated replay.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReplayRecordV1 {
    pub protocol_version: u64,
    pub backend_id: B256,
    pub backend_version_hash: B256,
    pub spec_hash: B256,
    pub delivery_hash: B256,
    pub prestate_anchor_hash: B256,
    pub prestate_root: B256,
    /// 1 = Reproduced, 2 = Failed (matches the ReexecVerdict enum).
    pub outcome: u8,
    /// SHA-256 ContentHash of the normalized backend result.
    pub result_hash: B256,
}

impl ReplayRecordV1 {
    /// Assemble a record from the deal commitments and the replay's own outputs.
    pub fn new(
        commitments: &ReexecCommitmentsV1,
        prestate_root: B256,
        outcome: u8,
        result_hash: B256,
    ) -> Self {
        Self {
            protocol_version: 1,
            backend_id: commitments.backend_id,
            backend_version_hash: commitments.backend_version_hash,
            spec_hash: commitments.spec_hash,
            delivery_hash: commitments.delivery_hash,
            prestate_anchor_hash: commitments.prestate_anchor_hash,
            prestate_root,
            outcome,
            result_hash,
        }
    }

    /// TLV bytes: entries with strictly ascending 1-byte tags, 1-byte length
    /// (all V1 values ≤ 32 bytes), minimal-big-endian unsigned integers.
    pub fn canonical_bytes(&self) -> Vec<u8> {
        fn tlv(out: &mut Vec<u8>, tag: u8, value: &[u8]) {
            out.push(tag);
            out.push(value.len() as u8);
            out.extend_from_slice(value);
        }
        fn minimal_be(v: u64) -> Vec<u8> {
            if v == 0 {
                return Vec::new();
            }
            let bytes = v.to_be_bytes();
            let first = bytes.iter().position(|&b| b != 0).unwrap();
            bytes[first..].to_vec()
        }
        let mut o = Vec::new();
        tlv(&mut o, 0x01, &minimal_be(self.protocol_version));
        tlv(&mut o, 0x02, self.backend_id.as_slice());
        tlv(&mut o, 0x03, self.backend_version_hash.as_slice());
        tlv(&mut o, 0x04, self.spec_hash.as_slice());
        tlv(&mut o, 0x05, self.delivery_hash.as_slice());
        tlv(&mut o, 0x06, self.prestate_anchor_hash.as_slice());
        tlv(&mut o, 0x07, self.prestate_root.as_slice());
        tlv(&mut o, 0x08, &minimal_be(self.outcome as u64));
        tlv(&mut o, 0x09, self.result_hash.as_slice());
        o
    }

    /// `SHA-256("reckn/v1/" || "replay-record" || canonicalBytes)`.
    pub fn trace_hash(&self) -> B256 {
        let mut h = Sha256::new();
        h.update(b"reckn/v1/");
        h.update(b"replay-record");
        h.update(self.canonical_bytes());
        B256::from_slice(&h.finalize())
    }
}

/// Backend `result_hash` for opaque return bytes:
/// `SHA-256("reckn/v1/" || typeTag || bytes)`. Each backend passes its own type
/// tag (e.g. `"evm-return-data"`, `"svm-return-data"`) so results are namespaced
/// per VM while sharing the record shape.
pub fn result_content_hash(type_tag: &[u8], bytes: &[u8]) -> B256 {
    let mut h = Sha256::new();
    h.update(b"reckn/v1/");
    h.update(type_tag);
    h.update(bytes);
    B256::from_slice(&h.finalize())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Golden vector — the same one asserted cross-language in
    /// `packages/protocol/golden/replay-record-v1.json`. Any backend that builds a
    /// record from these fields must reach this exact trace hash.
    #[test]
    fn golden_replay_record_v1() {
        let rec = ReplayRecordV1 {
            protocol_version: 1,
            backend_id: B256::from([0x01; 32]),
            backend_version_hash: B256::from([0x02; 32]),
            spec_hash: B256::from([0x03; 32]),
            delivery_hash: B256::from([0x04; 32]),
            prestate_anchor_hash: B256::from([0x05; 32]),
            prestate_root: B256::from([0x06; 32]),
            outcome: 1,
            result_hash: B256::from([0x07; 32]),
        };
        assert_eq!(rec.canonical_bytes().len(), 244);
        assert_eq!(
            format!("{:x}", rec.trace_hash()),
            "94b20b2330662638857fb412dc648f84c183e8e214431bd25f8915452258d33e",
            "shared record codec must match the cross-language golden",
        );
    }
}

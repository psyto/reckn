//! Canonical content codecs shared by the EVM keeper and binder adapter.
use alloy_primitives::{Address, Bytes, B256, U256};
use reckn_reexec_evm::{
    AccountWitness, EvmAnchorV1, EvmCallPlanV1, PredicateV1, PrestateWitnessV1, StorageWitnessV1,
};
use revm::primitives::hardfork::SpecId;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct DeliveryV11 {
    pub caller: Address,
    pub target: Address,
    pub calldata: Bytes,
    pub value: U256,
    pub gas_limit: u64,
    #[serde(default)]
    pub witness_content_hash: Option<B256>,
}
impl From<DeliveryV11> for EvmCallPlanV1 {
    fn from(x: DeliveryV11) -> Self {
        Self {
            caller: x.caller,
            target: x.target,
            calldata: x.calldata,
            value: x.value,
            gas_limit: x.gas_limit,
        }
    }
}
impl DeliveryV11 {
    pub fn require_witness(&self) -> Result<B256, String> {
        self.witness_content_hash
            .ok_or("delivery missing witnessContentHash".into())
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AnchorV11Json {
    pub chain_id: u64,
    pub block_number: u64,
    pub block_hash: B256,
    pub state_root: B256,
    pub timestamp: u64,
    pub base_fee: u64,
    pub block_gas_limit: u64,
    pub coinbase: Address,
    pub prevrandao: B256,
    pub spec_id: String,
}
impl TryFrom<AnchorV11Json> for EvmAnchorV1 {
    type Error = String;
    fn try_from(x: AnchorV11Json) -> Result<Self, String> {
        if x.spec_id != "CANCUN" {
            return Err("unsupported specId".into());
        }
        Ok(Self {
            chain_id: x.chain_id,
            block_number: x.block_number,
            block_hash: x.block_hash,
            state_root: x.state_root,
            timestamp: x.timestamp,
            base_fee: x.base_fee,
            block_gas_limit: x.block_gas_limit,
            coinbase: x.coinbase,
            prevrandao: x.prevrandao,
            spec_id: SpecId::CANCUN,
        })
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SpecV11Json {
    pub backend_id: B256,
    pub backend_version_hash: B256,
    pub prestate_anchor_hash: B256,
    pub predicate: PredicateJson,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "SCREAMING_SNAKE_CASE", deny_unknown_fields)]
pub enum PredicateJson {
    ResultEquals {
        #[serde(rename = "expectedResultHash")]
        expected_result_hash: B256,
    },
    PostStateEquals {
        checks: Vec<StorageCheckJson>,
    },
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct StorageCheckJson {
    pub address: Address,
    pub slot: U256,
    pub expected: U256,
}
impl From<PredicateJson> for PredicateV1 {
    fn from(x: PredicateJson) -> Self {
        match x {
            PredicateJson::ResultEquals {
                expected_result_hash,
            } => Self::ResultEquals {
                expected_result_hash,
            },
            PredicateJson::PostStateEquals { checks } => Self::PostStateEquals {
                checks: checks
                    .into_iter()
                    .map(|x| (x.address, x.slot, x.expected))
                    .collect(),
            },
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WitnessJson {
    pub accounts: Vec<AccountJson>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AccountJson {
    pub address: Address,
    pub balance: U256,
    pub nonce: u64,
    pub storage_root: B256,
    pub code_hash: B256,
    pub code: Bytes,
    pub account_proof: Vec<Bytes>,
    pub storage: Vec<StorageJson>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StorageJson {
    pub slot: U256,
    pub value: U256,
    pub proof: Vec<Bytes>,
}
impl From<PrestateWitnessV1> for WitnessJson {
    fn from(x: PrestateWitnessV1) -> Self {
        Self {
            accounts: x
                .accounts
                .into_iter()
                .map(|a| AccountJson {
                    address: a.address,
                    balance: a.balance,
                    nonce: a.nonce,
                    storage_root: a.storage_root,
                    code_hash: a.code_hash,
                    code: a.code,
                    account_proof: a.account_proof,
                    storage: a
                        .storage
                        .into_iter()
                        .map(|s| StorageJson {
                            slot: s.slot,
                            value: s.value,
                            proof: s.proof,
                        })
                        .collect(),
                })
                .collect(),
        }
    }
}
impl From<WitnessJson> for PrestateWitnessV1 {
    fn from(x: WitnessJson) -> Self {
        Self {
            accounts: x
                .accounts
                .into_iter()
                .map(|a| AccountWitness {
                    address: a.address,
                    balance: a.balance,
                    nonce: a.nonce,
                    storage_root: a.storage_root,
                    code_hash: a.code_hash,
                    code: a.code,
                    account_proof: a.account_proof,
                    storage: a
                        .storage
                        .into_iter()
                        .map(|s| StorageWitnessV1 {
                            slot: s.slot,
                            value: s.value,
                            proof: s.proof,
                        })
                        .collect(),
                })
                .collect(),
        }
    }
}
pub fn canonical_json<T: Serialize>(x: &T) -> Result<Vec<u8>, serde_json::Error> {
    serde_json::to_vec(x)
}
pub fn hash(bytes: &[u8]) -> B256 {
    B256::from_slice(&Sha256::digest(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> PrestateWitnessV1 {
        PrestateWitnessV1 {
            accounts: vec![AccountWitness {
                address: Address::from([0x11; 20]),
                balance: U256::from(7u64),
                nonce: 3,
                storage_root: B256::from([0x22; 32]),
                code_hash: B256::from([0x33; 32]),
                code: Bytes::from_static(&[0x60, 0x00]),
                account_proof: vec![Bytes::from_static(&[0xaa, 0xbb])],
                storage: vec![StorageWitnessV1 {
                    slot: U256::from(5u64),
                    value: U256::from(9u64),
                    proof: vec![Bytes::from_static(&[0xcc])],
                }],
            }],
        }
    }

    /// The anti-drift guarantee: the witness the keeper *builds* and the witness an
    /// adapter *reads* serialize to the same canonical bytes and thus the same
    /// `witnessContentHash`. A lossy conversion here would silently break the
    /// delivery-bound witness.
    #[test]
    fn witness_roundtrips_losslessly() {
        let w = witness();
        let json1 = canonical_json(&WitnessJson::from(w)).unwrap();
        let decoded: WitnessJson = serde_json::from_slice(&json1).unwrap();
        let engine: PrestateWitnessV1 = decoded.into();
        let json2 = canonical_json(&WitnessJson::from(engine)).unwrap();
        assert_eq!(
            json1, json2,
            "witness canonical bytes must round-trip losslessly"
        );
        assert_eq!(hash(&json1), hash(&json2));
    }

    /// The delivery wire uses camelCase, and `witnessContentHash` is optional so
    /// the current (pre-migration) anvil-e2e delivery still parses — while an
    /// adapter enforces its presence via `require_witness`.
    #[test]
    fn delivery_wire_is_camelcase_and_witness_hash_is_enforced_by_adapter_not_codec() {
        let d = DeliveryV11 {
            caller: Address::ZERO,
            target: Address::ZERO,
            calldata: Bytes::new(),
            value: U256::ZERO,
            gas_limit: 1,
            witness_content_hash: Some(B256::from([0x44; 32])),
        };
        let s = String::from_utf8(canonical_json(&d).unwrap()).unwrap();
        assert!(
            s.contains("witnessContentHash"),
            "wire field must be camelCase: {s}"
        );
        assert!(d.require_witness().is_ok());

        // A delivery without the field still decodes (Option/default) ...
        let mut v: serde_json::Value = serde_json::from_str(&s).unwrap();
        v.as_object_mut().unwrap().remove("witnessContentHash");
        let parsed: DeliveryV11 = serde_json::from_value(v).unwrap();
        // ... but the adapter refuses to replay without it.
        assert!(parsed.require_witness().is_err());
    }

    #[test]
    fn anchor_rejects_unfrozen_spec_id() {
        let mut a: serde_json::Value = serde_json::from_str(
            r#"{"chainId":1,"blockNumber":1,"blockHash":"0x0000000000000000000000000000000000000000000000000000000000000000","stateRoot":"0x0000000000000000000000000000000000000000000000000000000000000000","timestamp":1,"baseFee":0,"blockGasLimit":1,"coinbase":"0x0000000000000000000000000000000000000000","prevrandao":"0x0000000000000000000000000000000000000000000000000000000000000000","specId":"CANCUN"}"#,
        )
        .unwrap();
        let ok: AnchorV11Json = serde_json::from_value(a.clone()).unwrap();
        assert!(EvmAnchorV1::try_from(ok).is_ok());
        a["specId"] = serde_json::Value::String("PRAGUE".into());
        let bad: AnchorV11Json = serde_json::from_value(a).unwrap();
        assert!(EvmAnchorV1::try_from(bad).is_err());
    }
}

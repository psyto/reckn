//! Reckn keeper — live-chain shell around the verified replay/signature core.
//!
//! Trust boundary, in order:
//! `deal.prestateAnchorHash -> checked anchor bytes -> anchor.state_root ->
//! MPT-proven witness -> closed-world replay`.  A failure at any stage is an
//! operational error: this process deliberately does **not** sign a verdict.

use alloy::{
    eips::{BlockId, BlockNumberOrTag},
    network::{Ethereum, EthereumWallet},
    providers::Provider,
    rpc::types::{Filter, TransactionInput, TransactionRequest},
    sol,
    sol_types::{SolCall, SolEvent},
};
use alloy_primitives::{Address, Bytes, B256, U256};
use alloy_signer_local::PrivateKeySigner;
use anyhow::{bail, Context as _, Result};
use reckn_keeper::{build_commitment, sign_verdict, DealTerms, VerdictCommitment};
use reckn_reexec_evm::{
    header::verify_header_rlp_against_anchor, replay, verify_witness_against_root, AccountWitness,
    EvmAnchorV1, EvmCallPlanV1, PredicateV1, PrestateWitnessV1, ReexecCommitmentsV1,
    StorageWitnessV1,
};
use reckn_evm_content::{
    AnchorV11Json, BlockHeaderContentV1, DeliveryV11, SpecV11Json, WitnessJson, canonical_json, hash,
};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::PathBuf,
};

// The optimistic-settlement challenge window the keeper opens when it commits a
// verdict. Long enough for an independent party to reproduce the verdict and, if
// wrong, challenge it before `finalizeSettlement` moves funds.
const SETTLE_WINDOW_SECS: u64 = 3600;

// Deliberately local ABI: the escrow itself remains VM-neutral and the keeper
// uses this only at its chain-I/O edge.  Field ordering mirrors VerdictHash.sol.
sol! {
    struct VerdictCommitmentWire {
        bytes32 dealId;
        bytes32 specHash;
        bytes32 deliveryHash;
        bytes32 prestateAnchorHash;
        bytes32 prestateRoot;
        bytes32 backendId;
        bytes32 backendVersionHash;
        uint8 outcome;
        bytes32 resultHash;
        bytes32 traceHash;
    }
    function resolve(VerdictCommitmentWire calldata c, uint8 v, bytes32 r, bytes32 s);
    function resolveOptimistic(VerdictCommitmentWire calldata c, uint8 v, bytes32 r, bytes32 s, uint64 settleWindow);
    event Disputed(
        bytes32 indexed dealId,
        bytes32 specHash,
        bytes32 deliveryHash,
        bytes32 prestateAnchorHash,
        bytes32 backendId,
        bytes32 backendVersionHash,
        uint64 resolveDeadline
    );
    event VerdictCommitted(
        bytes32 indexed dealId,
        uint8 outcome,
        bytes32 prestateRoot,
        bytes32 resultHash,
        bytes32 traceHash,
        address resolver
    );
}

/// On-disk content-addressed store used by the demo.  The filename is merely a
/// lookup hint: the raw file bytes are SHA-256 checked before JSON parsing.
#[derive(Clone, Debug)]
struct FileContentStore {
    root: PathBuf,
}

impl FileContentStore {
    fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    fn load_checked(&self, expected: B256) -> Result<Vec<u8>> {
        let hex = format!("{expected:x}");
        // Accept the canonical 0x-less filename only. `expected` is a B256,
        // never caller-controlled path text, so this cannot escape `root`.
        let path = self.root.join(format!("{hex}.json"));
        let bytes =
            fs::read(&path).with_context(|| format!("content missing: {}", path.display()))?;
        let got = B256::from_slice(&Sha256::digest(&bytes));
        if got != expected {
            bail!("content hash mismatch for {path:?}: committed {expected:#x}, got {got:#x}");
        }
        Ok(bytes)
    }

    fn load_json<T: for<'de> Deserialize<'de>>(&self, expected: B256) -> Result<T> {
        let bytes = self.load_checked(expected)?;
        serde_json::from_slice(&bytes).context("committed content is not valid V1.1 JSON")
    }
}

/// Build a proof-carrying prestate from an RPC at one committed block.
///
/// `eth_createAccessList` runs the seller plan once against that historical
/// state. The returned transitive addresses/slots are augmented with caller,
/// target and coinbase, then every entry is materialized by `eth_getProof`.
/// The replay engine verifies those proofs again offline and remains the final
/// closed-world completeness check (`Missing*Witness` => no signature).
async fn build_transitive_witness<P>(
    provider: &P,
    anchor: &EvmAnchorV1,
    plan: &EvmCallPlanV1,
) -> Result<(PrestateWitnessV1, Vec<u8>)>
where
    P: Provider<Ethereum>,
{
    let block = BlockId::Number(BlockNumberOrTag::Number(anchor.block_number));
    // `eth_getProof(..., blockNumber)` is only an acquisition transport. Pin it
    // to the hash committed in the anchor before accepting any RPC material.
    // The MPT verifier below independently binds the returned nodes to
    // `anchor.state_root`.
    let rpc_block = provider
        .get_block_by_number(BlockNumberOrTag::Number(anchor.block_number))
        .await
        .context("fetch committed block header")?
        .context("committed block is unavailable from RPC")?;
    if rpc_block.hash() != anchor.block_hash {
        bail!(
            "RPC block hash differs from committed anchor at block {}",
            anchor.block_number
        );
    }
    // Capture the block header's consensus RLP so the keyless verdict path can
    // later prove `anchor.state_root` is bound to `anchor.block_hash` offline
    // (see `reexec_evm::header`). It must hash to the committed block hash.
    let header_rlp = alloy_rlp::encode(&rpc_block.header.inner);
    if alloy_primitives::keccak256(&header_rlp) != anchor.block_hash {
        bail!("encoded header RLP does not hash to the committed block hash");
    }
    let request = TransactionRequest::default()
        .from(plan.caller)
        .to(plan.target)
        .value(plan.value)
        .gas_limit(plan.gas_limit)
        .input(TransactionInput::both(plan.calldata.clone()));

    let access = provider
        .create_access_list(&request)
        .block_id(block)
        .await
        .context("eth_createAccessList at committed block")?
        .ensure_ok()
        .map_err(|message| anyhow::anyhow!("access-list execution failed: {message}"))?;

    // BTree ordering makes the witness bytes stable even when an RPC changes
    // its access-list ordering. The proof verifier itself never trusts order.
    let mut touches: BTreeMap<Address, BTreeSet<U256>> = BTreeMap::new();
    for (address, slots) in access.access_list.flatten() {
        touches.entry(address).or_default().extend(slots);
    }
    for required in [plan.caller, plan.target, anchor.coinbase] {
        touches.entry(required).or_default();
    }

    let mut accounts = Vec::with_capacity(touches.len());
    for (address, slots) in touches {
        let proof_slots = slots
            .iter()
            .copied()
            .map(|slot| B256::from(slot.to_be_bytes::<32>()))
            .collect();
        let proof = provider
            .get_proof(address, proof_slots)
            .block_id(block)
            .await
            .with_context(|| format!("eth_getProof({address:#x})"))?;
        let code = provider
            .get_code_at(address)
            .block_id(block)
            .await
            .with_context(|| format!("eth_getCode({address:#x})"))?;

        // `eth_getProof` returns raw RLP trie nodes. Preserve them as-is; the
        // engine checks their path/value against `anchor.state_root` offline.
        let storage = proof
            .storage_proof
            .into_iter()
            .map(|entry| StorageWitnessV1 {
                slot: U256::from_be_bytes(entry.key.as_b256().0),
                value: entry.value,
                proof: entry.proof,
            })
            .collect();
        accounts.push(AccountWitness {
            address: proof.address,
            balance: proof.balance,
            nonce: proof.nonce,
            storage_root: proof.storage_hash,
            code_hash: proof.code_hash,
            code,
            account_proof: proof.account_proof,
            storage,
        });
    }

    let witness = PrestateWitnessV1 { accounts };
    verify_witness_against_root(anchor, &witness)
        .map_err(|error| anyhow::anyhow!("operational witness verification error: {error:?}"))?;
    Ok((witness, header_rlp))
}

/// Reconstruct the verdict from PUBLIC inputs only (content store + committed
/// deal terms), with no resolver key. Shared by the keeper (which then signs it)
/// and the independent verifier (which compares it to the on-chain verdict), so
/// the two can never drift: the thing the keeper signs is exactly the thing
/// anyone else re-derives.
async fn recompute_verdict<P>(
    _read_provider: &P,
    chain_id: u64,
    store: &FileContentStore,
    terms: &DealTerms,
) -> Result<VerdictCommitment>
where
    P: Provider<Ethereum>,
{
    // Each lookup verifies the raw bytes against the event/deal commitment.
    let spec: SpecV11Json = store.load_json(terms.spec_hash)?;
    if spec.backend_id != terms.backend_id
        || spec.backend_version_hash != terms.backend_version_hash
    {
        bail!("committed spec backend identity differs from the disputed deal");
    }
    if spec.prestate_anchor_hash != terms.prestate_anchor_hash {
        bail!(
            "committed spec binds a different anchor: spec={:#x}, deal={:#x}",
            spec.prestate_anchor_hash,
            terms.prestate_anchor_hash
        );
    }
    let anchor: EvmAnchorV1 = store
        .load_json::<AnchorV11Json>(terms.prestate_anchor_hash)?
        .try_into()
        .map_err(anyhow::Error::msg)?;
    if anchor.chain_id != chain_id {
        bail!(
            "anchor chainId {} differs from connected chain {chain_id}",
            anchor.chain_id
        );
    }
    let delivery: DeliveryV11 = store.load_json(terms.delivery_hash)?;
    let witness_hash = delivery.require_witness().map_err(anyhow::Error::msg)?;
    // Snapshot authenticity: when a block header is committed, prove it binds
    // `anchor.state_root` to `anchor.block_hash` (a real consensus value) before
    // trusting the state root the witness is verified against. A mismatch is an
    // operational error — no verdict — exactly like a bad witness. Enforced here,
    // in the shared keyless path, so resolver and independent verifier agree.
    if let Some(header_hash) = delivery.header_content_hash {
        let header: BlockHeaderContentV1 = store.load_json(header_hash)?;
        verify_header_rlp_against_anchor(header.header_rlp.as_ref(), &anchor)
            .map_err(|e| anyhow::anyhow!("operational header verification error: {e:?}"))?;
    }
    let plan: EvmCallPlanV1 = delivery.into();
    let predicate = PredicateV1::from(spec.predicate);
    // The resolver never feeds an RPC-created witness into settlement replay.
    // Seller-published, delivery-committed bytes are re-hashed by the store,
    // then replay verifies their MPT proofs against anchor.state_root.
    let witness: PrestateWitnessV1 = store.load_json::<WitnessJson>(witness_hash)?.into();
    let replay = replay(
        &anchor,
        &witness,
        &plan,
        &predicate,
        &ReexecCommitmentsV1 {
            backend_id: terms.backend_id,
            backend_version_hash: terms.backend_version_hash,
            spec_hash: terms.spec_hash,
            delivery_hash: terms.delivery_hash,
            prestate_anchor_hash: terms.prestate_anchor_hash,
        },
    )
    .map_err(|error| anyhow::anyhow!("operational replay error: {error:?}"))?;
    Ok(build_commitment(terms, &replay))
}

/// Independent, keyless re-verification of a settled dispute. Reads the resolver's
/// on-chain `VerdictCommitted` and the committed deal terms, re-derives the verdict
/// from public inputs (content store + re-execution), and asserts they match. This
/// is the trust property Reckn is built on, made executable: don't trust the
/// resolver — reproduce its verdict yourself. Returns Err on any mismatch.
async fn verify_dispute<P>(
    read_provider: &P,
    escrow: Address,
    chain_id: u64,
    store: &FileContentStore,
    deal_id: B256,
) -> Result<()>
where
    P: Provider<Ethereum>,
{
    let disputed_logs = read_provider
        .get_logs(
            &Filter::new()
                .address(escrow)
                .event_signature(Disputed::SIGNATURE_HASH)
                .topic1(deal_id)
                .from_block(0u64),
        )
        .await?;
    let disputed = disputed_logs
        .last()
        .context("no Disputed event for this deal")?
        .log_decode_validate::<Disputed>()?
        .inner
        .data;
    let terms = DealTerms {
        deal_id,
        spec_hash: disputed.specHash,
        delivery_hash: disputed.deliveryHash,
        prestate_anchor_hash: disputed.prestateAnchorHash,
        backend_id: disputed.backendId,
        backend_version_hash: disputed.backendVersionHash,
    };

    let verdict_logs = read_provider
        .get_logs(
            &Filter::new()
                .address(escrow)
                .event_signature(VerdictCommitted::SIGNATURE_HASH)
                .topic1(deal_id)
                .from_block(0u64),
        )
        .await?;
    let committed = verdict_logs
        .last()
        .context("no VerdictCommitted event — the deal is not resolved on-chain yet")?
        .log_decode_validate::<VerdictCommitted>()?
        .inner
        .data;

    // Re-derive from public inputs only. No resolver key is involved.
    let recomputed = recompute_verdict(read_provider, chain_id, store, &terms).await?;

    let mark = |ok: bool| if ok { "OK" } else { "MISMATCH" };
    let outcome_ok = recomputed.outcome == committed.outcome;
    let result_ok = recomputed.result_hash == committed.resultHash;
    let root_ok = recomputed.prestate_root == committed.prestateRoot;
    let trace_ok = recomputed.trace_hash == committed.traceHash;

    println!("independent re-verification · deal {deal_id:#x}");
    println!(
        "  outcome      {} (on-chain {}, recomputed {})",
        mark(outcome_ok),
        committed.outcome,
        recomputed.outcome
    );
    println!("  resultHash   {}", mark(result_ok));
    println!("  prestateRoot {}", mark(root_ok));
    println!(
        "  traceHash    {} {:#x}",
        mark(trace_ok),
        recomputed.trace_hash
    );

    if outcome_ok && result_ok && root_ok && trace_ok {
        println!(
            "VERIFIED — resolver verdict reproduced from public inputs with no resolver key. Reproduce, or refund."
        );
        Ok(())
    } else {
        bail!("MISMATCH — the resolver's on-chain verdict does not reproduce under independent re-execution");
    }
}

/// Decode, authenticate, replay and settle exactly one Disputed event.
///
/// Every `?` before `send_transaction` is operational: the caller logs it and
/// continues polling, while the contract's C1 `timeoutRefund` remains available.
#[allow(clippy::too_many_arguments)]
async fn resolve_dispute<P>(
    read_provider: &P,
    rpc_url: &str,
    escrow: Address,
    chain_id: u64,
    store: &FileContentStore,
    signer: &PrivateKeySigner,
    event: Disputed,
    submitted: &mut BTreeSet<(u64, B256, B256)>,
) -> Result<Option<B256>>
where
    P: Provider<Ethereum>,
{
    let terms = DealTerms {
        deal_id: event.dealId,
        spec_hash: event.specHash,
        delivery_hash: event.deliveryHash,
        prestate_anchor_hash: event.prestateAnchorHash,
        backend_id: event.backendId,
        backend_version_hash: event.backendVersionHash,
    };
    let commitment = recompute_verdict(read_provider, chain_id, store, &terms).await?;
    let signed =
        sign_verdict(commitment, chain_id, escrow, signer).context("EIP-712 verdict signing")?;
    let idempotency_key = (chain_id, terms.deal_id, signed.digest);
    if submitted.contains(&idempotency_key) {
        return Ok(None);
    }

    // A signing provider is created only after all untrusted content and proof
    // material survived verification. This is what keeps C1 timeout reachable.
    let submitter = alloy::providers::ProviderBuilder::new()
        .wallet(EthereumWallet::from(signer.clone()))
        .connect_http(rpc_url.parse()?);
    // Optimistic settlement is the default path: the verdict is committed and a
    // challenge window opens (the reproducible verdict is public immediately), so
    // a bonded resolver's wrong verdict can be challenged before funds move.
    // `finalizeSettlement` pays after the window; a conflicting verdict refunds
    // the buyer. See contracts/src/RecknEscrow.sol.
    let calldata = resolveOptimisticCall {
        c: VerdictCommitmentWire {
            dealId: signed.commitment.deal_id,
            specHash: signed.commitment.spec_hash,
            deliveryHash: signed.commitment.delivery_hash,
            prestateAnchorHash: signed.commitment.prestate_anchor_hash,
            prestateRoot: signed.commitment.prestate_root,
            backendId: signed.commitment.backend_id,
            backendVersionHash: signed.commitment.backend_version_hash,
            outcome: signed.commitment.outcome,
            resultHash: signed.commitment.result_hash,
            traceHash: signed.commitment.trace_hash,
        },
        v: signed.v,
        r: signed.r,
        s: signed.s,
        settleWindow: SETTLE_WINDOW_SECS,
    }
    .abi_encode();
    let pending = submitter
        .send_transaction(
            TransactionRequest::default()
                .to(escrow)
                .input(TransactionInput::both(Bytes::from(calldata))),
        )
        .await
        .context("submit resolveOptimistic()")?;
    let receipt = pending
        .get_receipt()
        .await
        .context("wait for resolve receipt")?;
    if !receipt.status() {
        bail!(
            "resolve transaction reverted: {:#x}",
            receipt.transaction_hash
        );
    }
    submitted.insert(idempotency_key);
    Ok(Some(signed.digest))
}

/// One poll pass. Failed acquisition/replay remains absent from `submitted`, so
/// a later pass can retry if the seller republishes missing evidence before C1.
async fn poll_disputes<P>(
    provider: &P,
    rpc_url: &str,
    escrow: Address,
    chain_id: u64,
    store: &FileContentStore,
    signer: &PrivateKeySigner,
    submitted: &mut BTreeSet<(u64, B256, B256)>,
) -> Result<()>
where
    P: Provider<Ethereum>,
{
    let logs = provider
        .get_logs(
            &Filter::new()
                .address(escrow)
                .event_signature(Disputed::SIGNATURE_HASH),
        )
        .await?;
    for log in logs {
        let decoded = log.log_decode_validate::<Disputed>()?.inner.data;
        match resolve_dispute(
            provider,
            rpc_url,
            escrow,
            chain_id,
            store,
            signer,
            decoded,
            submitted,
        )
        .await
        {
            Ok(Some(digest)) => println!("resolved verdict {digest:#x}"),
            Ok(None) => println!("skipped duplicate resolved verdict"),
            Err(error) => eprintln!("operational: no verdict signed/submitted: {error:#}"),
        }
    }
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    // `witness` is the R2 acquisition probe. `once`/`watch` poll Disputed
    // events, apply full content/proof/replay validation, then resolve valid
    // events. `watch` deliberately reuses the exact one-pass state machine.
    let mut args = std::env::args().skip(1);
    let Some(command) = args.next() else {
        eprintln!(
            "usage:\n  reckn-keeper witness <rpc-url> <content-store> <anchor-hash> <delivery-hash> [--write <store>]\n\
              reckn-keeper once|watch <rpc-url> <escrow> <content-store> <resolver-private-key>\n\
              reckn-keeper verify <rpc-url> <escrow> <content-store> <deal-id>\n\
             content files are <sha256-without-0x>.json and are checked before parsing.\n\
             `verify` is keyless: it reproduces a resolved deal's on-chain verdict from public inputs."
        );
        return Ok(());
    };
    let rpc_url = args.next().context("missing rpc-url")?;
    match command.as_str() {
        "witness" => {
            let store = FileContentStore::new(args.next().context("missing content-store")?);
            let anchor_hash: B256 = args.next().context("missing anchor hash")?.parse()?;
            let delivery_hash: B256 = args.next().context("missing delivery hash")?.parse()?;
            let write = match args.next().as_deref() { None => None, Some("--write") => Some(PathBuf::from(args.next().context("missing --write store")?)), Some(_) => bail!("expected --write <store>") };
            if args.next().is_some() { bail!("too many arguments"); }
            let provider = alloy::providers::ProviderBuilder::new().connect_http(rpc_url.parse()?);
            let anchor: EvmAnchorV1 = store.load_json::<AnchorV11Json>(anchor_hash)?.try_into().map_err(anyhow::Error::msg)?;
            let plan: EvmCallPlanV1 = store.load_json::<DeliveryV11>(delivery_hash)?.into();
            let (witness, header_rlp) = build_transitive_witness(&provider, &anchor, &plan).await?;
            if let Some(dir) = write {
                let bytes = canonical_json(&WitnessJson::from(witness.clone()))?;
                let witness_hash = hash(&bytes);
                fs::write(dir.join(format!("{witness_hash:x}.json")), bytes)?;
                println!("witnessContentHash={witness_hash:#x}");
                // The block header binds state_root to block_hash for the keyless
                // verdict path; commit it alongside the witness.
                let header_bytes = canonical_json(&BlockHeaderContentV1 {
                    header_rlp: header_rlp.into(),
                })?;
                let header_hash = hash(&header_bytes);
                fs::write(dir.join(format!("{header_hash:x}.json")), header_bytes)?;
                println!("headerContentHash={header_hash:#x}");
            }
            println!(
                "witness verified: {} accounts at block {} ({:#x})",
                witness.accounts.len(),
                anchor.block_number,
                anchor.state_root
            );
            Ok(())
        }
        "once" | "watch" => {
            let escrow: Address = args.next().context("missing escrow")?.parse()?;
            let store = FileContentStore::new(args.next().context("missing content-store")?);
            let signer: PrivateKeySigner = args
                .next()
                .context("missing resolver private key")?
                .parse()?;
            if args.next().is_some() {
                bail!("too many arguments");
            }
            let provider = alloy::providers::ProviderBuilder::new().connect_http(rpc_url.parse()?);
            let chain_id = provider.get_chain_id().await?;
            let mut submitted = BTreeSet::new();
            if command == "once" {
                return poll_disputes(
                    &provider,
                    &rpc_url,
                    escrow,
                    chain_id,
                    &store,
                    &signer,
                    &mut submitted,
                )
                .await;
            }
            let poll_ms = std::env::var("RECKN_POLL_MS")
                .ok()
                .and_then(|value| value.parse::<u64>().ok())
                .unwrap_or(3_000);
            loop {
                poll_disputes(
                    &provider,
                    &rpc_url,
                    escrow,
                    chain_id,
                    &store,
                    &signer,
                    &mut submitted,
                )
                .await?;
                tokio::time::sleep(std::time::Duration::from_millis(poll_ms)).await;
            }
        }
        "verify" => {
            let escrow: Address = args.next().context("missing escrow")?.parse()?;
            let store = FileContentStore::new(args.next().context("missing content-store")?);
            let deal_id: B256 = args.next().context("missing deal-id")?.parse()?;
            if args.next().is_some() {
                bail!("too many arguments");
            }
            let provider = alloy::providers::ProviderBuilder::new().connect_http(rpc_url.parse()?);
            let chain_id = provider.get_chain_id().await?;
            verify_dispute(&provider, escrow, chain_id, &store, deal_id).await
        }
        _ => bail!("unsupported command {command:?}; use witness, once, watch, or verify"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checked_store_rejects_substitution_before_json_parsing() {
        let root =
            std::env::temp_dir().join(format!("reckn-keeper-store-test-{}", std::process::id()));
        fs::create_dir_all(&root).unwrap();
        let expected = B256::from_slice(&Sha256::digest(b"{\"v\":1}"));
        fs::write(
            root.join(format!("{expected:x}.json")),
            b"not the committed bytes",
        )
        .unwrap();
        let error = FileContentStore::new(&root)
            .load_checked(expected)
            .unwrap_err();
        assert!(error.to_string().contains("content hash mismatch"));
        fs::remove_dir_all(root).unwrap();
    }
}

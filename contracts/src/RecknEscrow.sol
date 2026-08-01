// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {IUSDC3009} from "./interfaces/IUSDC3009.sol";
import {ResolverRegistry} from "./ResolverRegistry.sol";
import {VerdictHash} from "./libraries/VerdictHash.sol";

/// @title RecknEscrow
/// @notice Escrow for agent-to-agent payments where a disputed delivery is
///         adjudicated by a re-executed, reproducible verdict. This contract is
///         the settlement half only: it stores canonical commitments and acts on
///         a registered resolver's EIP-712 signature. It never parses spec bytes
///         and holds no EVM/Solana/RPC-specific types (cross-VM cut-line).
///
/// @dev Phase-clock policy (review M2):
///        fundedAt < deliveredAt <= deliverDeadline
///        deliveredAt < challengeDeadline; challengedAt < resolveDeadline
///      Each configurable window must be nonzero (enforced). Phase timestamp
///      recording and richer window validation remain a next-pass hardening item;
///      callers must not treat the three windows as an informal global ordering.
///      Escape hatches so funds never lock forever (review C1):
///        - Held      + past deliverDeadline  -> buyer reclaims (seller no-show)
///        - Delivered + past challengeDeadline -> seller claims (buyer silent)
///        - Disputed  + past resolveDeadline   -> buyer refunded (no verdict:
///          seller-provided delivery/replay evidence is unavailable, so timeout
///          favors the buyer). The buyer publishes the spec/anchor descriptor
///          at funding under the protocol's data-availability policy. If the buyer
///          committed an optional seller data-availability bond, this path also
///          forfeits it to the buyer — so withholding evidence has an economic
///          cost, not just a reputation mark (see {deliver} / {_pay}).
///
///      This is NOT a trustless settlement. Reproducibility (anyone re-derives
///      the verdict from published inputs) is separate from settlement authority
///      (a registered resolver signs). A fraud proof / challenge game / bonded
///      quorum is a later layer; do not overclaim.
contract RecknEscrow {
    using VerdictHash for VerdictHash.VerdictCommitment;

    enum DealState {
        None,
        Held,
        Delivered,
        Disputed,
        Settling,
        Resolved
    }

    enum Outcome {
        Reproduced,
        Failed
    }

    struct Deal {
        address buyer;
        address seller;
        address paymentToken;
        uint256 amount;
        // Committed at funding (from the buyer-authored spec):
        bytes32 specHash;
        bytes32 prestateAnchorHash;
        bytes32 backendId;
        bytes32 backendVersionHash;
        // Filled as the deal progresses:
        bytes32 deliveryHash; // set at deliver()
        uint64 deliverDeadline; // set at fund()
        uint64 challengeDeadline; // set at deliver()
        uint64 resolveDeadline; // set at challenge()
        DealState state;
        // Recorded by resolveOptimistic(), read by finalizeSettlement() and
        // compared by challengeVerdict(). Unused on the instant resolve() path.
        uint64 settleDeadline;
        uint8 verdictOutcome;
        address verdictResolver;
        bytes32 verdictTraceHash;
        // Optional seller data-availability bond (opt-in, buyer-committed at
        // funding). `requiredSellerBond` is the amount the seller MUST lock to
        // `deliver()`; `sellerBondLocked` is what is actually held (== required,
        // once delivered) and is 0 until deliver / after payout. Same token as the
        // payment. Returned to the seller on every terminal path EXCEPT a dispute
        // timeout (evidence withheld), where it is forfeited to the buyer.
        uint256 requiredSellerBond;
        uint256 sellerBondLocked;
    }

    /// @notice An ECDSA signature of a `VerdictCommitment`, used to present a
    ///         resolver quorum to `slashWithQuorum`.
    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    ResolverRegistry public immutable registry;
    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(bytes32 => Deal) public deals;
    /// @notice Replay guard for `slashWithQuorum`: `(dealId, faultyResolver)`.
    mapping(bytes32 => mapping(address => bool)) public quorumSlashed;

    event Funded(
        bytes32 indexed dealId,
        address indexed buyer,
        address indexed seller,
        address paymentToken,
        uint256 amount,
        bytes32 specHash,
        bytes32 prestateAnchorHash,
        bytes32 backendId,
        bytes32 backendVersionHash,
        uint64 deliverDeadline,
        uint256 requiredSellerBond
    );
    event Delivered(bytes32 indexed dealId, bytes32 deliveryHash, uint64 challengeDeadline);
    /// @notice The seller locked their committed data-availability bond at delivery.
    event SellerBondPosted(bytes32 indexed dealId, address indexed seller, uint256 amount);
    /// @notice The seller bond was released (`forfeited=false`, back to the seller)
    ///         or forfeited to the buyer (`forfeited=true`, on a dispute timeout —
    ///         the seller withheld replay evidence).
    event SellerBondSettled(bytes32 indexed dealId, address indexed to, uint256 amount, bool forfeited);
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
        Outcome outcome,
        bytes32 prestateRoot,
        bytes32 resultHash,
        bytes32 traceHash,
        address resolver
    );
    event Settled(bytes32 indexed dealId, address indexed to, uint256 amount, uint8 reason);
    // reason: 0 = verdict release, 1 = verdict refund, 2 = timeout refund,
    //         3 = unchallenged release, 4 = undelivered reclaim, 5 = conflict fault refund
    /// @notice Two registered resolvers signed conflicting verdicts for the same
    ///         deterministic deal — a provable resolver-set fault. The deal
    ///         fail-safes to a buyer refund; governance slashes the liar's bond in
    ///         the registry, using the public reproducible verdict as evidence.
    event Fault(bytes32 indexed dealId, address indexed resolver, address indexed challenger, bytes32 challengerTraceHash);
    /// @notice A verdict was recorded and the optimistic settlement window opened.
    event SettlementOpened(bytes32 indexed dealId, address indexed resolver, Outcome outcome, uint64 settleDeadline);
    /// @notice A resolver whose verdict a K-of-N quorum contradicted was slashed
    ///         automatically; its bond went to the submitter as a bounty.
    event QuorumSlashed(bytes32 indexed dealId, address indexed faultyResolver, address indexed submitter, uint256 amount, bytes32 quorumTraceHash);

    /// @notice Reputation evidence about the seller-agent, projected from a
    ///         re-execution verdict (ERC-8004 style). Unlike self-reported
    ///         feedback, the evidence is a reproducible verdict: `traceHash`
    ///         (the canonical ReplayRecordV1 digest) can be re-derived by anyone.
    ///         Emission is a pure projection — it never infers quality and never
    ///         affects settlement.
    ///
    ///         Two shapes, distinguished by `verdictTraceHash`:
    ///         - a resolved verdict: `reproduced` is the verdict, `verdictTraceHash`
    ///           is the (non-zero) canonical trace anyone can re-derive;
    ///         - a dispute that timed out with no verdict: `reproduced = false` and
    ///           `verdictTraceHash = 0`. The seller owns delivery/replay evidence
    ///           (§C1), so withholding it does not let a seller dodge the negative
    ///           signal by forcing a timeout — the zero trace marks it as
    ///           evidence-withheld rather than a reproduced `Failed`.
    event ReputationEvidence(
        address indexed agent,
        bool reproduced,
        bytes32 indexed dealId,
        bytes32 verdictTraceHash,
        bytes32 backendId
    );

    error BadState();
    error NotBuyer();
    error NotSeller();
    error DeadlinePassed();
    error DeadlineNotReached();
    error DealExists();
    error ZeroAmount();
    error BadParty();
    error UnknownResolver();
    error DisallowedBackend();
    error CommitmentMismatch();
    error BadSignature();
    error ZeroWindow();
    error BadNonce();
    error NotBonded();
    error SettleWindowOpen();
    error SettleWindowClosed();
    error SameResolver();
    error NotConflicting();
    error BelowQuorum();
    error QuorumNotRegistered();
    error QuorumUnordered();
    error AlreadySlashed();

    /// @dev Domain tag that binds an EIP-3009 authorization nonce to the exact
    ///      deal it funds. See {fundingNonce}.
    bytes32 public constant FUND_NONCE_TAG = keccak256("Reckn.FundAuthNonce.v1");

    constructor(ResolverRegistry registry_) {
        registry = registry_;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Reckn"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice The deterministic deal id for a set of funding terms. Pure over the
    ///         terms plus this chain/escrow, so a buyer and a facilitator derive
    ///         the same id off-chain before funding.
    function computeDealId(
        bytes32 salt,
        address buyer,
        address seller,
        address paymentToken,
        uint256 amount,
        bytes32 specHash,
        bytes32 prestateAnchorHash,
        bytes32 backendId,
        bytes32 backendVersionHash
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                block.chainid,
                address(this),
                salt,
                buyer,
                seller,
                paymentToken,
                amount,
                specHash,
                prestateAnchorHash,
                backendId,
                backendVersionHash
            )
        );
    }

    /// @notice The EIP-3009 authorization nonce a buyer MUST sign to fund `dealId`
    ///         for `deliverWindow`. Binding the nonce to the deal is what lets a
    ///         single buyer signature both pay AND fix the terms: the nonce is part
    ///         of the signed authorization, and `dealId` commits to seller, token,
    ///         amount, spec, anchor, and backend. A relayer that alters any term
    ///         recomputes a different expected nonce here, so either this check or
    ///         the token's signature check reverts — the buyer's intent is
    ///         tamper-evident even though anyone may submit the transaction.
    ///         `requiredSellerBond` is committed here too, so a relayer cannot
    ///         weaken (or drop) the seller's data-availability bond the buyer chose.
    function fundingNonce(bytes32 dealId, uint64 deliverWindow, uint256 requiredSellerBond)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(FUND_NONCE_TAG, dealId, deliverWindow, requiredSellerBond));
    }

    /// @notice Fund a deal atomically with the buyer's EIP-3009 authorization and
    ///         bind it to the spec's canonical commitments, entering `Held`. The
    ///         buyer (`from`) is the payer whose off-chain signature authorizes the
    ///         pull; `msg.sender` may be a third-party facilitator relaying it
    ///         (x402-style), since the token's `receiveWithAuthorization` requires
    ///         only that `to` is this escrow. The authorization's `authNonce` must
    ///         equal {fundingNonce}, so one signature cannot be replayed against
    ///         different terms.
    function fundWithAuthorization(
        bytes32 salt,
        address from,
        address seller,
        address paymentToken,
        uint256 amount,
        bytes32 specHash,
        bytes32 prestateAnchorHash,
        bytes32 backendId,
        bytes32 backendVersionHash,
        uint64 deliverWindow,
        uint256 requiredSellerBond,
        // EIP-3009 authorization signed by the buyer (`from`):
        uint256 validAfter,
        uint256 validBefore,
        bytes32 authNonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bytes32 dealId) {
        if (amount == 0) revert ZeroAmount();
        if (from == address(0) || seller == address(0) || seller == from) revert BadParty();
        if (deliverWindow == 0) revert ZeroWindow();

        dealId = computeDealId(
            salt, from, seller, paymentToken, amount, specHash, prestateAnchorHash, backendId, backendVersionHash
        );
        if (deals[dealId].state != DealState.None) revert DealExists();

        // The authorization the buyer signed must be the one that funds *this*
        // deal for *this* window. This is the term binding that makes relaying
        // safe (see {fundingNonce}).
        if (authNonce != fundingNonce(dealId, deliverWindow, requiredSellerBond)) revert BadNonce();

        uint64 deliverDeadline = uint64(block.timestamp) + deliverWindow;

        deals[dealId] = Deal({
            buyer: from,
            seller: seller,
            paymentToken: paymentToken,
            amount: amount,
            specHash: specHash,
            prestateAnchorHash: prestateAnchorHash,
            backendId: backendId,
            backendVersionHash: backendVersionHash,
            deliveryHash: bytes32(0),
            deliverDeadline: deliverDeadline,
            challengeDeadline: 0,
            resolveDeadline: 0,
            state: DealState.Held,
            settleDeadline: 0,
            verdictOutcome: 0,
            verdictResolver: address(0),
            verdictTraceHash: bytes32(0),
            requiredSellerBond: requiredSellerBond,
            sellerBondLocked: 0
        });

        // Pull funds last (state written first; token call is the only external
        // interaction). `to` is address(this), so a stray authorization cannot
        // be redirected, and the buyer's signature over `from`/`value`/`nonce`
        // is verified by the token — the facilitator holds no discretion.
        IUSDC3009(paymentToken).receiveWithAuthorization(
            from, address(this), amount, validAfter, validBefore, authNonce, v, r, s
        );

        emit Funded(
            dealId,
            from,
            seller,
            paymentToken,
            amount,
            specHash,
            prestateAnchorHash,
            backendId,
            backendVersionHash,
            deliverDeadline,
            requiredSellerBond
        );
    }

    /// @notice Seller records their delivery (execution plan + claim, committed
    ///         by hash off-chain). The verdict later replays the plan rather than
    ///         trusting the claim. Entering `Delivered`.
    function deliver(bytes32 dealId, bytes32 deliveryHash, uint64 challengeWindow) external {
        Deal storage d = deals[dealId];
        if (d.state != DealState.Held) revert BadState();
        if (msg.sender != d.seller) revert NotSeller();
        if (block.timestamp > d.deliverDeadline) revert DeadlinePassed();
        if (challengeWindow == 0) revert ZeroWindow();

        d.deliveryHash = deliveryHash;
        uint64 challengeDeadline = uint64(block.timestamp) + challengeWindow;
        d.challengeDeadline = challengeDeadline;
        d.state = DealState.Delivered;

        emit Delivered(dealId, deliveryHash, challengeDeadline);

        // Lock the seller's data-availability bond, if the buyer required one.
        // State is already `Delivered`, so a re-entrant token hook re-hits the
        // state guard above and reverts. The seller must have approved the escrow
        // for `requiredSellerBond` of the payment token beforehand.
        uint256 bond = d.requiredSellerBond;
        if (bond > 0) {
            d.sellerBondLocked = bond;
            emit SellerBondPosted(dealId, msg.sender, bond);
            IUSDC3009(d.paymentToken).transferFrom(msg.sender, address(this), bond);
        }
    }

    /// @notice Buyer challenges a delivery, opening the re-execution window.
    ///         Entering `Disputed`. Emits full terms so any observer can
    ///         reproduce the verdict independently.
    function challenge(bytes32 dealId, uint64 resolveWindow) external {
        Deal storage d = deals[dealId];
        if (d.state != DealState.Delivered) revert BadState();
        if (msg.sender != d.buyer) revert NotBuyer();
        if (block.timestamp > d.challengeDeadline) revert DeadlinePassed();
        if (resolveWindow == 0) revert ZeroWindow();

        uint64 resolveDeadline = uint64(block.timestamp) + resolveWindow;
        d.resolveDeadline = resolveDeadline;
        d.state = DealState.Disputed;

        emit Disputed(
            dealId,
            d.specHash,
            d.deliveryHash,
            d.prestateAnchorHash,
            d.backendId,
            d.backendVersionHash,
            resolveDeadline
        );
    }

    /// @notice A registered resolver posts the signed verdict commitment. The
    ///         committed fields MUST match the deal (no fresh anchor/backend),
    ///         the signer MUST be a registered resolver, and the backend/version
    ///         MUST be allow-listed. Releases on Reproduced, refunds on Failed.
    /// @dev The committed fields must match the deal exactly, the backend/version
    ///      must be allow-listed, and the signer must be a registered resolver.
    ///      Shared by `resolve`, `resolveOptimistic`, and `challengeVerdict`.
    /// @dev The committed fields must match the deal exactly (no fresh anchor /
    ///      backend). Shared by the settlement paths and `slashWithQuorum`.
    function _commitmentBindsDeal(Deal storage d, VerdictHash.VerdictCommitment calldata c)
        private
        view
    {
        if (
            c.specHash != d.specHash || c.deliveryHash != d.deliveryHash
                || c.prestateAnchorHash != d.prestateAnchorHash || c.backendId != d.backendId
                || c.backendVersionHash != d.backendVersionHash
        ) revert CommitmentMismatch();
    }

    function _recoverRegisteredSigner(
        Deal storage d,
        VerdictHash.VerdictCommitment calldata c,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private view returns (address signer) {
        _commitmentBindsDeal(d, c);
        if (!registry.backendAllowed(c.backendId, c.backendVersionHash)) revert DisallowedBackend();
        signer = VerdictHash.recover(VerdictHash.digest(DOMAIN_SEPARATOR, _toMemory(c)), v, r, s);
        if (signer == address(0)) revert BadSignature();
        if (!registry.isResolver(signer)) revert UnknownResolver();
    }

    function resolve(VerdictHash.VerdictCommitment calldata c, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 id = c.dealId;
        Deal storage d = deals[id];
        if (d.state != DealState.Disputed) revert BadState();

        address signer = _recoverRegisteredSigner(d, c, v, r, s);

        d.state = DealState.Resolved;

        Outcome outcome = Outcome(c.outcome);
        emit VerdictCommitted(c.dealId, outcome, c.prestateRoot, c.resultHash, c.traceHash, signer);
        // Pure ERC-8004-style projection: reputation for the seller-agent, earned
        // by a reproducible verdict rather than self-reported feedback. Does not
        // touch settlement below.
        emit ReputationEvidence(d.seller, outcome == Outcome.Reproduced, id, c.traceHash, c.backendId);

        if (outcome == Outcome.Reproduced) {
            _pay(d, id, d.seller, 0);
        } else {
            _pay(d, id, d.buyer, 1);
        }
    }

    // --- optimistic settlement (bonded resolver + challenge window) ---

    /// @notice Like `resolve`, but the signer must be bonded and settlement is
    ///         *deferred*: the verdict is recorded and a challenge window opens.
    ///         The reproducible verdict is public immediately (`VerdictCommitted`),
    ///         so anyone can re-derive it and, if it is wrong, a second registered
    ///         resolver can `challengeVerdict` before funds move.
    function resolveOptimistic(
        VerdictHash.VerdictCommitment calldata c,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint64 settleWindow
    ) external {
        bytes32 id = c.dealId;
        Deal storage d = deals[id];
        if (d.state != DealState.Disputed) revert BadState();
        if (settleWindow == 0) revert ZeroWindow();

        address signer = _recoverRegisteredSigner(d, c, v, r, s);
        if (!registry.isBonded(signer)) revert NotBonded();

        Outcome outcome = Outcome(c.outcome);
        d.state = DealState.Settling;
        d.settleDeadline = uint64(block.timestamp) + settleWindow;
        d.verdictOutcome = c.outcome;
        d.verdictResolver = signer;
        d.verdictTraceHash = c.traceHash;

        emit VerdictCommitted(c.dealId, outcome, c.prestateRoot, c.resultHash, c.traceHash, signer);
        emit ReputationEvidence(d.seller, outcome == Outcome.Reproduced, id, c.traceHash, c.backendId);
        emit SettlementOpened(id, signer, outcome, d.settleDeadline);
    }

    /// @notice After the window closes with no successful challenge, settle per the
    ///         recorded verdict. Permissionless — anyone can finalize.
    function finalizeSettlement(bytes32 id) external {
        Deal storage d = deals[id];
        if (d.state != DealState.Settling) revert BadState();
        if (block.timestamp <= d.settleDeadline) revert SettleWindowOpen();

        d.state = DealState.Resolved;
        if (Outcome(d.verdictOutcome) == Outcome.Reproduced) {
            _pay(d, id, d.seller, 0);
        } else {
            _pay(d, id, d.buyer, 1);
        }
    }

    /// @notice During the window, a *different* registered resolver presents a
    ///         conflicting verdict for the same deterministic deal. Because an
    ///         honest resolver re-derives the same `outcome`/`traceHash` from the
    ///         committed inputs, a conflict is a provable resolver-set fault. The
    ///         escrow cannot tell on-chain which signer is honest, so it fail-safes
    ///         to a **buyer refund** (matching the timeout philosophy) and emits
    ///         `Fault`; governance slashes the liar's bond off-chain using the
    ///         public verdict as evidence.
    function challengeVerdict(VerdictHash.VerdictCommitment calldata c, uint8 v, bytes32 r, bytes32 s)
        external
    {
        bytes32 id = c.dealId;
        Deal storage d = deals[id];
        if (d.state != DealState.Settling) revert BadState();
        if (block.timestamp > d.settleDeadline) revert SettleWindowClosed();

        address challenger = _recoverRegisteredSigner(d, c, v, r, s);
        if (challenger == d.verdictResolver) revert SameResolver();
        // A conflict is any disagreement on the deterministic verdict.
        if (c.traceHash == d.verdictTraceHash && c.outcome == d.verdictOutcome) {
            revert NotConflicting();
        }

        d.state = DealState.Resolved;
        emit Fault(id, d.verdictResolver, challenger, c.traceHash);
        _pay(d, id, d.buyer, 5);
    }

    /// @notice Permissionlessly slash a resolver whose signed verdict a **K-of-N
    ///         registered-resolver quorum contradicts**. Because the verdict is
    ///         deterministic from committed inputs, K honest resolvers sign the
    ///         same `truth`, so a resolver on the other side is provably wrong —
    ///         no governance, no window. Its whole bond is a **bounty** to the
    ///         submitter (sound under an honest-majority quorum). Independent of
    ///         the deal's settlement state.
    ///
    ///         This is the achievable "quorum" step toward trustless enforcement;
    ///         zero-trust single-signer adjudication still wants a fraud-proof VM
    ///         or a ZK proof of the re-execution.
    function slashWithQuorum(
        VerdictHash.VerdictCommitment calldata faulty,
        uint8 fv,
        bytes32 fr,
        bytes32 fs,
        VerdictHash.VerdictCommitment calldata truth,
        Sig[] calldata quorum
    ) external {
        bytes32 id = faulty.dealId;
        if (truth.dealId != id) revert CommitmentMismatch();
        Deal storage d = deals[id];
        _commitmentBindsDeal(d, faulty);
        _commitmentBindsDeal(d, truth);
        // `truth` must actually disagree with the faulty verdict.
        if (faulty.traceHash == truth.traceHash && faulty.outcome == truth.outcome) {
            revert NotConflicting();
        }

        address faultyResolver =
            VerdictHash.recover(VerdictHash.digest(DOMAIN_SEPARATOR, _toMemory(faulty)), fv, fr, fs);
        if (faultyResolver == address(0)) revert BadSignature();
        if (!registry.isResolver(faultyResolver)) revert UnknownResolver();
        if (quorumSlashed[id][faultyResolver]) revert AlreadySlashed();

        if (quorum.length < registry.quorumThreshold()) revert BelowQuorum();
        bytes32 truthDigest = VerdictHash.digest(DOMAIN_SEPARATOR, _toMemory(truth));
        address last = address(0);
        for (uint256 i = 0; i < quorum.length; i++) {
            address qs = VerdictHash.recover(truthDigest, quorum[i].v, quorum[i].r, quorum[i].s);
            if (qs == address(0) || !registry.isResolver(qs)) revert QuorumNotRegistered();
            // Strictly ascending => the quorum signers are distinct.
            if (qs <= last) revert QuorumUnordered();
            if (qs == faultyResolver) revert SameResolver();
            last = qs;
        }

        quorumSlashed[id][faultyResolver] = true;
        uint256 amount = registry.bond(faultyResolver);
        emit QuorumSlashed(id, faultyResolver, msg.sender, amount, truth.traceHash);
        registry.slashByQuorum(faultyResolver, msg.sender, amount);
    }

    // --- escape hatches so funds never lock forever ---

    /// @notice Buyer reclaims if the seller never delivered before the deadline.
    function reclaimUndelivered(bytes32 id) external {
        Deal storage d = deals[id];
        if (d.state != DealState.Held) revert BadState();
        if (msg.sender != d.buyer) revert NotBuyer();
        if (block.timestamp <= d.deliverDeadline) revert DeadlineNotReached();
        d.state = DealState.Resolved;
        _pay(d, id, d.buyer, 4);
    }

    /// @notice Seller claims if the buyer never challenged before the deadline.
    function claimUnchallenged(bytes32 id) external {
        Deal storage d = deals[id];
        if (d.state != DealState.Delivered) revert BadState();
        if (msg.sender != d.seller) revert NotSeller();
        if (block.timestamp <= d.challengeDeadline) revert DeadlineNotReached();
        d.state = DealState.Resolved;
        _pay(d, id, d.seller, 3);
    }

    /// @notice Anyone may refund the buyer if a dispute produced no verdict
    ///         before the resolve deadline (review C1). Seller-provided delivery
    ///         and replay evidence are the seller's burden, so timeout favors
    ///         the buyer; the buyer publishes spec/anchor bytes at funding.
    function timeoutRefund(bytes32 id) external {
        Deal storage d = deals[id];
        if (d.state != DealState.Disputed) revert BadState();
        if (block.timestamp <= d.resolveDeadline) revert DeadlineNotReached();
        d.state = DealState.Resolved;
        // A withholding seller cannot dodge the negative reputation signal by
        // forcing a timeout instead of a `Failed` verdict: emit evidence-withheld
        // (reproduced = false, zero trace) before refunding the buyer. Zero trace
        // distinguishes this from a reproduced `Failed`. Pure projection.
        emit ReputationEvidence(d.seller, false, id, bytes32(0), d.backendId);
        _pay(d, id, d.buyer, 2);
    }

    // --- helpers ---

    function getDeal(bytes32 id) external view returns (Deal memory) {
        return deals[id];
    }

    function _pay(Deal storage d, bytes32 id, address to, uint8 reason) internal {
        // State is already set to Resolved by the caller before this runs, so a
        // re-entrant token hook re-hits the state guard and reverts.
        uint256 amount = d.amount;
        emit Settled(id, to, amount, reason);

        // Settle the seller's data-availability bond, if one is locked. It is
        // forfeited to the buyer ONLY on a dispute timeout (reason 2 = seller
        // withheld replay evidence); on every other terminal path — release,
        // verdict refund, unchallenged release, conflict fault — the seller
        // provided evidence (or was not at fault) and gets the bond back. The
        // `reclaimUndelivered` path (reason 4) never locked a bond, so
        // `sellerBondLocked` is 0 there and nothing moves. Zeroed before transfer
        // so a re-entrant hook cannot double-release.
        uint256 bond = d.sellerBondLocked;
        address bondTo = reason == 2 ? d.buyer : d.seller;

        IUSDC3009(d.paymentToken).transfer(to, amount);
        if (bond > 0) {
            d.sellerBondLocked = 0;
            emit SellerBondSettled(id, bondTo, bond, reason == 2);
            IUSDC3009(d.paymentToken).transfer(bondTo, bond);
        }
    }

    function _toMemory(VerdictHash.VerdictCommitment calldata c)
        internal
        pure
        returns (VerdictHash.VerdictCommitment memory m)
    {
        m = VerdictHash.VerdictCommitment({
            dealId: c.dealId,
            specHash: c.specHash,
            deliveryHash: c.deliveryHash,
            prestateAnchorHash: c.prestateAnchorHash,
            prestateRoot: c.prestateRoot,
            backendId: c.backendId,
            backendVersionHash: c.backendVersionHash,
            outcome: c.outcome,
            resultHash: c.resultHash,
            traceHash: c.traceHash
        });
    }
}

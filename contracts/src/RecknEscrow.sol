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
///          at funding under the protocol's data-availability policy.
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
    }

    ResolverRegistry public immutable registry;
    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(bytes32 => Deal) public deals;

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
        uint64 deliverDeadline
    );
    event Delivered(bytes32 indexed dealId, bytes32 deliveryHash, uint64 challengeDeadline);
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
    //         3 = unchallenged release, 4 = undelivered reclaim

    /// @notice Reputation evidence about the seller-agent, projected from a
    ///         re-execution verdict (ERC-8004 style). Unlike self-reported
    ///         feedback, the evidence is a reproducible verdict: `traceHash`
    ///         (the canonical ReplayRecordV1 digest) can be re-derived by anyone.
    ///         Emission is a pure projection — it never infers quality and never
    ///         affects settlement.
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

    /// @notice Buyer funds a deal atomically with an EIP-3009 authorization and
    ///         binds it to the spec's canonical commitments. Entering `Held`.
    function fundWithAuthorization(
        bytes32 salt,
        address seller,
        address paymentToken,
        uint256 amount,
        bytes32 specHash,
        bytes32 prestateAnchorHash,
        bytes32 backendId,
        bytes32 backendVersionHash,
        uint64 deliverWindow,
        // EIP-3009 authorization (buyer = from):
        uint256 validAfter,
        uint256 validBefore,
        bytes32 authNonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bytes32 dealId) {
        if (amount == 0) revert ZeroAmount();
        if (seller == address(0) || seller == msg.sender) revert BadParty();
        if (deliverWindow == 0) revert ZeroWindow();

        dealId = keccak256(
            abi.encode(
                block.chainid,
                address(this),
                salt,
                msg.sender,
                seller,
                paymentToken,
                amount,
                specHash,
                prestateAnchorHash,
                backendId,
                backendVersionHash
            )
        );
        if (deals[dealId].state != DealState.None) revert DealExists();

        uint64 deliverDeadline = uint64(block.timestamp) + deliverWindow;

        deals[dealId] = Deal({
            buyer: msg.sender,
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
            state: DealState.Held
        });

        // Pull funds last (state written first; token call is the only external
        // interaction). `to` is address(this), so a stray authorization cannot
        // be redirected.
        IUSDC3009(paymentToken).receiveWithAuthorization(
            msg.sender, address(this), amount, validAfter, validBefore, authNonce, v, r, s
        );

        emit Funded(
            dealId,
            msg.sender,
            seller,
            paymentToken,
            amount,
            specHash,
            prestateAnchorHash,
            backendId,
            backendVersionHash,
            deliverDeadline
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
    function resolve(VerdictHash.VerdictCommitment calldata c, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 id = c.dealId;
        Deal storage d = deals[id];
        if (d.state != DealState.Disputed) revert BadState();

        // Committed fields must match the deal exactly.
        if (
            c.specHash != d.specHash || c.deliveryHash != d.deliveryHash
                || c.prestateAnchorHash != d.prestateAnchorHash || c.backendId != d.backendId
                || c.backendVersionHash != d.backendVersionHash
        ) revert CommitmentMismatch();

        if (!registry.backendAllowed(c.backendId, c.backendVersionHash)) revert DisallowedBackend();

        address signer = VerdictHash.recover(VerdictHash.digest(DOMAIN_SEPARATOR, _toMemory(c)), v, r, s);
        if (signer == address(0)) revert BadSignature();
        if (!registry.isResolver(signer)) revert UnknownResolver();

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
        IUSDC3009(d.paymentToken).transfer(to, amount);
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

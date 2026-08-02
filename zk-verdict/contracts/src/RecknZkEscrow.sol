// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RecknVerdictVerifier, VerdictPublicValues} from "./RecknVerdictVerifier.sol";

interface IERC20Min {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

/// @title RecknZkEscrow
/// @notice Escrow settled by a **ZK-proven re-execution verdict** — with **no
///         resolver**. This is where the re-execution proofs finally *move money*:
///         a deal commits, at funding, the `dealBinding` its verdict proof must
///         carry (a commitment the guest computes over the agreed prestate +
///         predicate + plan). `settleWithProof` verifies an SP1 proof via
///         `RecknVerdictVerifier` and, only if the proof's `dealBinding` matches the
///         deal's, releases to the seller (`Reproduced`) or refunds the buyer
///         (`Failed`). Settlement authority comes from a proof that verifies, not
///         from a signer on an allow-list — so it works identically on any chain.
///
///         The binding is what makes this sound: a proof from some other favorable
///         execution carries a different `dealBinding` and cannot settle this deal.
contract RecknZkEscrow {
    uint8 public constant REPRODUCED = 0;
    uint8 public constant FAILED = 1;

    RecknVerdictVerifier public immutable verifier;

    enum State {
        None,
        Funded,
        Settled
    }

    struct Deal {
        address buyer;
        address seller;
        address token;
        uint256 amount;
        bytes32 dealBinding;
        State state;
    }

    mapping(bytes32 => Deal) public deals;

    event Funded(
        bytes32 indexed dealId,
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount,
        bytes32 dealBinding
    );
    /// @notice A deal settled purely on a verified ZK verdict (reason: 0 = release to
    ///         seller on Reproduced, 1 = refund to buyer on Failed).
    event SettledByProof(bytes32 indexed dealId, address indexed to, uint8 outcome, bytes32 traceHash);

    error DealExists();
    error BadState();
    error ZeroBinding();
    error BindingMismatch();
    error BadOutcome();

    constructor(RecknVerdictVerifier _verifier) {
        verifier = _verifier;
    }

    /// @notice Fund a deal, committing the `dealBinding` its settlement proof must
    ///         reproduce. The buyer must have approved `amount` of `token`.
    function fund(bytes32 dealId, address seller, address token, uint256 amount, bytes32 dealBinding)
        external
    {
        if (deals[dealId].state != State.None) revert DealExists();
        if (dealBinding == bytes32(0)) revert ZeroBinding();
        deals[dealId] = Deal({
            buyer: msg.sender,
            seller: seller,
            token: token,
            amount: amount,
            dealBinding: dealBinding,
            state: State.Funded
        });
        emit Funded(dealId, msg.sender, seller, token, amount, dealBinding);
        // State written first; the token pull is the only external interaction.
        IERC20Min(token).transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Settle a funded deal on a ZK-verified verdict. Anyone may submit the
    ///         proof — it carries its own authority. Reverts if the proof does not
    ///         verify or is not bound to this deal.
    function settleWithProof(bytes32 dealId, bytes calldata publicValues, bytes calldata proofBytes)
        external
    {
        Deal storage d = deals[dealId];
        if (d.state != State.Funded) revert BadState();

        // Authority: the proof must verify (this reverts otherwise).
        VerdictPublicValues memory v = verifier.verifyVerdict(publicValues, proofBytes);

        // Binding: the proof must be about THIS deal (its committed prestate +
        // predicate + plan), not some other favorable execution.
        if (v.dealBinding != d.dealBinding) revert BindingMismatch();

        // Settle on the proven outcome. State set before transfer so a re-entrant
        // token hook re-hits the state guard and reverts.
        d.state = State.Settled;
        address to;
        if (v.outcome == REPRODUCED) {
            to = d.seller;
        } else if (v.outcome == FAILED) {
            to = d.buyer;
        } else {
            revert BadOutcome();
        }
        emit SettledByProof(dealId, to, v.outcome, v.traceHash);
        IERC20Min(d.token).transfer(to, d.amount);
    }
}

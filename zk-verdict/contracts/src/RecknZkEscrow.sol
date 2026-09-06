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
///         predicate + plan). `settleWithProof` verifies an SP1 proof through the
///         verifier the deal itself names and, only if the proof's `dealBinding`
///         matches the deal's, releases to the seller (`Reproduced`) or refunds the
///         buyer (`Failed`). Settlement authority comes from a proof that verifies,
///         not from a signer on an allow-list — so it works identically on any chain.
///
///         The binding is what makes this sound: a proof from some other favorable
///         execution carries a different `dealBinding` and cannot settle this deal.
///
///         **Cross-VM (009).** The adjudicating program is named by the FUNDER, per
///         deal, and pinned by its codehash — so one escrow settles an EVM proof and
///         a Solana proof without a resolver, a bridge or a light client. The funder
///         chooses the program; the proof, checked by that program, chooses the
///         payout. A funder who names a sham program has defrauded nobody but
///         themselves; a funder who names one that always returns `Failed` makes the
///         seller work for nothing, which is indistinguishable on-chain from an
///         honest `Failed` and is why a seller reads `verifier` before working.
contract RecknZkEscrow {
    uint8 public constant REPRODUCED = 0;
    uint8 public constant FAILED = 1;
    /// @notice How long a funded deal waits for a proof before the buyer may take
    ///         the money back. Fixed for the protocol, not chosen by a deployer or a
    ///         funder: a deadline someone picks is a parameter someone controls, and
    ///         the point of this contract is that nobody controls anything. It is
    ///         long enough that an honest seller can produce a Groth16 proof —
    ///         regenerating one fixture measures at 335 s — with room for a prover
    ///         outage, a chain halt, and a human weekend.
    uint256 public constant REFUND_AFTER = 30 days;

    /// @notice `extcodehash` of an account that exists with no code. An address
    ///         whose codehash is this, or zero, is not a program.
    bytes32 public constant EMPTY_CODEHASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

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
        address verifier;
        bytes32 verifierCodeHash;
        bytes32 dealBinding;
        uint64 fundedAt;
        State state;
    }

    mapping(bytes32 => Deal) public deals;

    event Funded(
        bytes32 indexed dealId,
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount,
        address verifier,
        bytes32 verifierCodeHash,
        bytes32 dealBinding
    );
    /// @notice A deal settled purely on a verified ZK verdict (reason: 0 = release to
    ///         seller on Reproduced, 1 = refund to buyer on Failed).
    event SettledByProof(bytes32 indexed dealId, address indexed to, uint8 outcome, bytes32 traceHash);
    /// @notice A funded deal returned to its buyer because no proof arrived in time.
    ///         Distinct from `SettledByProof` on purpose: this payout is the only one
    ///         in the contract that no proof authorised, and a reader of the log
    ///         should never have to infer which kind it was.
    event RefundedAfterDeadline(bytes32 indexed dealId, address indexed buyer, uint256 amount);

    error DealExists();
    error BadState();
    error ZeroBinding();
    error BindingMismatch();
    error BadOutcome();
    error NoVerifierCode();
    error VerifierMismatch();
    error TooEarly();

    /// @notice Fund a deal, naming the program whose proof may settle it.
    /// @dev The codehash is pinned at funding and re-checked at settlement, so the
    ///      address cannot become different code between the two.
    function fund(
        bytes32 dealId,
        address seller,
        address token,
        uint256 amount,
        address verifier,
        bytes32 verifierCodeHash,
        bytes32 dealBinding
    ) external {
        if (deals[dealId].state != State.None) revert DealExists();
        if (dealBinding == bytes32(0)) revert ZeroBinding();
        if (verifierCodeHash == bytes32(0) || verifierCodeHash == EMPTY_CODEHASH) revert NoVerifierCode();
        if (verifier.codehash != verifierCodeHash) revert VerifierMismatch();
        deals[dealId] = Deal({
            buyer: msg.sender,
            seller: seller,
            token: token,
            amount: amount,
            verifier: verifier,
            verifierCodeHash: verifierCodeHash,
            dealBinding: dealBinding,
            fundedAt: uint64(block.timestamp),
            state: State.Funded
        });
        emit Funded(dealId, msg.sender, seller, token, amount, verifier, verifierCodeHash, dealBinding);
        // State written first; the token pull is the only external interaction.
        IERC20Min(token).transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Settle a funded deal on a verified verdict. Permissionless: the proof
    ///         carries its own authority. There is no parameter with which a settler
    ///         could name an adjudicator — the deal named it at funding.
    function settleWithProof(bytes32 dealId, bytes calldata publicValues, bytes calldata proofBytes)
        external
    {
        Deal storage d = deals[dealId];
        if (d.state != State.Funded) revert BadState();
        if (d.verifier.codehash != d.verifierCodeHash) revert VerifierMismatch();

        // Authority: the proof must verify (this reverts otherwise). The dispatch is
        // `view`-typed, so it is a STATICCALL: the callee cannot write state, which
        // is what makes it safe to call funder-chosen code before the binding check.
        VerdictPublicValues memory v =
            RecknVerdictVerifier(d.verifier).verifyVerdict(publicValues, proofBytes);

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

    /// @notice Return a funded deal to its buyer once `REFUND_AFTER` has passed with
    ///         no proof. **Permissionless**: any address may call it, and calling it
    ///         gives the caller nothing — the money goes to the deal's buyer, which
    ///         `fund` fixed and nothing can change.
    /// @dev    This is the only payout in the contract that a proof did not
    ///         authorise, and it is why the escrow can be keyless without being a
    ///         place money goes to die: before it, a deal whose prover never showed
    ///         up — or whose recipient a stablecoin froze — stayed funded forever.
    ///         It is not an escape hatch for anyone in particular: it cannot be
    ///         called early, it cannot be called twice, it cannot be called after a
    ///         proof settled the deal, and it names no privileged address.
    function refundAfterDeadline(bytes32 dealId) external {
        Deal storage d = deals[dealId];
        if (d.state != State.Funded) revert BadState();
        if (block.timestamp < uint256(d.fundedAt) + REFUND_AFTER) revert TooEarly();

        // State first, then the transfer: a re-entrant token hook re-hits the guard.
        d.state = State.Settled;
        emit RefundedAfterDeadline(dealId, d.buyer, d.amount);
        IERC20Min(d.token).transfer(d.buyer, d.amount);
    }
}

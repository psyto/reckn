// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RecknZkEscrow} from "@zk/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "@zk/RecknVerdictVerifier.sol";

/// @notice The subset of the deployed ENSv2 Permissioned Resolver this adapter uses.
///         Taken from the DEPLOYED beta, whose ABI is not the main branch's — two
///         signatures in `013` §2.3 were wrong because they were read from `main`.
interface IPermissionedResolver {
    /// @param setter the CALLDATA of the write being authorised, not the name. Passing a
    ///        name reverts `UnsupportedResolverProfile`, because its first four bytes are
    ///        read as a selector.
    function grantSetterRoles(bytes calldata setter, address account) external;
    /// @dev Returns the KEY first, then the resource, then the role bitmap. Decoding it as
    ///      `(uint256, uint256)` yields `(0x60, resource)` — an ABI offset that looks exactly
    ///      like a plausible resource id, and revoking against it silently leaves the window
    ///      open. Read from the deployed contract, not from `main`.
    function decodeSetter(bytes calldata setter)
        external
        view
        returns (string memory key, uint256 resource, uint256 roleBitmap);
    function revokeRoles(uint256 resource, uint256 roleBitmap, address account) external;
    function setText(bytes calldata name, string calldata key, string calldata value) external;
}

/// @title SettlementRecord
/// @notice An agent cannot write its own history. The right to write one record is created
///         by a settlement and destroyed after the write.
///
/// **What this contract does not have.** No owner, no admin, no pause, no upgrade path, and
/// no way to choose an outcome. `open` and `close` are callable by anyone, exactly as
/// `settleWithProof` is. What is fixed is not *who calls* but *who may write*: the buyer
/// named at funding, and nobody else.
///
/// **Why the outcome is re-derived and never passed in.** `RecknZkEscrow.Deal` has no outcome
/// field and `State` is only `None | Funded | Settled`; the verdict exists solely in an event,
/// which contracts cannot read. Settlement is permissionless, so a third party may have
/// settled. Taking the outcome from the caller would let anyone write false history that looks
/// earned — worse than the problem this exists to solve. So the adapter re-verifies the proof
/// itself, through the verifier **the funder named**, pinned by codehash.
///
/// **Why the clock.** `refundAfterDeadline` writes the same terminal `Settled` state with no
/// proof at all, and the escrow cannot be changed (`AGENTS.md` §0). A refund is impossible
/// before `fundedAt + REFUND_AFTER`, so a record written strictly inside that window cannot be
/// standing on one. The cost is real and is stated rather than hidden: **a job must be recorded
/// within 30 days of funding or it is never recordable.**
///
/// **Three steps, not one, and that is load-bearing.** `open` grants; the buyer writes in its
/// own transaction; `close` revokes. Folding the write into `open` would mean the adapter
/// writes on the buyer's behalf — and then the agent calling `open` on its own honestly settled
/// deal would produce a record, which is exactly what `013` R-12 forbids.
contract SettlementRecord {
    RecknZkEscrow public immutable escrow;
    IPermissionedResolver public immutable resolver;

    /// @notice One window per deal, ever. Set before any external call.
    mapping(bytes32 => bool) public opened;
    /// @notice The party the window was opened for, kept so `close` needs no argument
    ///         the caller could get wrong.
    mapping(bytes32 => address) public writerOf;
    /// @notice The resource the window was opened on, and the exact role that was granted.
    ///         Both are taken from the resolver rather than assumed: a constant of our own
    ///         would be one more thing that can drift away from the deployment.
    mapping(bytes32 => uint256) public resourceOf;
    mapping(bytes32 => uint256) public roleOf;
    mapping(bytes32 => bool) public closed;

    event WindowOpened(bytes32 indexed dealId, address indexed writer, uint256 resource, uint8 outcome);
    event WindowClosed(bytes32 indexed dealId, address indexed writer, uint256 resource);

    error AlreadyOpened();
    error NotSettled();
    error RefundWindowPassed();
    error VerifierNotTheOneNamed();
    error BindingMismatch();
    error NotOpened();
    error AlreadyClosed();

    constructor(RecknZkEscrow _escrow, IPermissionedResolver _resolver) {
        escrow = _escrow;
        resolver = _resolver;
    }

    /// @notice The key a settled deal's record lives under. Deterministic, so a reader does
    ///         not have to be told where to look.
    function recordKey(bytes32 dealId) public pure returns (string memory) {
        return string.concat("reckn:job:", _hex(dealId));
    }

    /// @notice The value a truthful record carries. `Failed` is recorded, not omitted — a
    ///         surface that records only successes is a highlight reel (`013` R-7).
    function recordValue(uint8 outcome, uint64 settledAtBlock, address verifier)
        public
        pure
        returns (string memory)
    {
        return string.concat(
            outcome == 0 ? "reproduced" : "failed",
            " block=",
            _dec(settledAtBlock),
            " verifier=",
            _hex20(verifier)
        );
    }

    /// @notice The exact calldata the buyer is authorised to send, and nothing else. The
    ///         resolver grants against the write itself, so the grant is per record rather
    ///         than per name: a grant for this key does not authorise any other key.
    function setterFor(bytes calldata dnsName, bytes32 dealId) public pure returns (bytes memory) {
        return abi.encodeWithSelector(IPermissionedResolver.setText.selector, dnsName, recordKey(dealId), "");
    }

    /// @dev The escrow's public getter returns nine values, which is one stack frame too
    ///      many to destructure inline. Collecting them into memory here is the whole reason
    ///      this helper exists.
    struct DealView {
        address buyer;
        address verifier;
        bytes32 codeHash;
        bytes32 binding;
        uint64 fundedAt;
        RecknZkEscrow.State state;
    }

    function _deal(bytes32 dealId) private view returns (DealView memory d) {
        (d.buyer,,,, d.verifier, d.codeHash, d.binding, d.fundedAt, d.state) = escrow.deals(dealId);
    }

    /// @dev Everything that decides whether a window may open, kept in its own frame. Inlining
    ///      it into `open` is one local too many for the stack, and `via_ir` would change how
    ///      the whole contract is generated to buy a line of style.
    function _authorise(bytes32 dealId, bytes calldata publicValues, bytes calldata proofBytes)
        private
        view
        returns (address buyer, uint8 outcome)
    {
        DealView memory d = _deal(dealId);
        if (d.state != RecknZkEscrow.State.Settled) revert NotSettled();
        // forge-lint warns that a validator can nudge block.timestamp. The window this
        // guards is 30 days wide, so seconds of drift cannot move a record across it; what
        // it separates is a settlement from a timeout refund, and those are a month apart.
        if (block.timestamp >= uint256(d.fundedAt) + escrow.REFUND_AFTER()) revert RefundWindowPassed();

        address verifier = d.verifier;
        bytes32 observed;
        assembly {
            observed := extcodehash(verifier)
        }
        if (observed != d.codeHash) revert VerifierNotTheOneNamed();

        VerdictPublicValues memory v = RecknVerdictVerifier(verifier).verifyVerdict(publicValues, proofBytes);
        if (v.dealBinding != d.binding) revert BindingMismatch();
        return (d.buyer, v.outcome);
    }

    /// @dev The grant, in its own frame for the same stack reason as `_authorise`. The
    ///      resource AND the role bitmap both come back from the resolver; neither is a
    ///      constant of ours that could drift away from the deployment.
    function _grant(bytes32 dealId, bytes calldata dnsName, address buyer) private returns (uint256 resource) {
        bytes memory setter = setterFor(dnsName, dealId);
        uint256 roleBitmap;
        (, resource, roleBitmap) = resolver.decodeSetter(setter);
        resourceOf[dealId] = resource;
        roleOf[dealId] = roleBitmap;
        resolver.grantSetterRoles(setter, buyer);
    }

    /// @notice Open the one window this deal will ever have. Anyone may call.
    /// @dev The outcome is read out of the proof, never off the caller.
    function open(bytes32 dealId, bytes calldata dnsName, bytes calldata publicValues, bytes calldata proofBytes)
        external
        returns (address, uint8)
    {
        if (opened[dealId]) revert AlreadyOpened();
        opened[dealId] = true; // effects before interactions

        (address buyer, uint8 outcome) = _authorise(dealId, publicValues, proofBytes);
        writerOf[dealId] = buyer;
        emit WindowOpened(dealId, buyer, _grant(dealId, dnsName, buyer), outcome);
        return (buyer, outcome);
    }

    /// @notice Close it again. Anyone may call; the writer and the resource are read from
    ///         storage rather than taken as arguments, so a caller cannot close someone
    ///         else's window by naming it.
    function close(bytes32 dealId) external {
        if (!opened[dealId]) revert NotOpened();
        if (closed[dealId]) revert AlreadyClosed();
        closed[dealId] = true;

        address writer = writerOf[dealId];
        uint256 resource = resourceOf[dealId];
        resolver.revokeRoles(resource, roleOf[dealId], writer);

        emit WindowClosed(dealId, writer, resource);
    }

    // ---- formatting, kept private and boring -------------------------------------------

    function _hex(bytes32 v) private pure returns (string memory) {
        bytes memory s = new bytes(64);
        for (uint256 i; i < 32; ++i) {
            s[i * 2] = _nib(uint8(v[i]) >> 4);
            s[i * 2 + 1] = _nib(uint8(v[i]) & 0x0f);
        }
        return string(s);
    }

    function _hex20(address a) private pure returns (string memory) {
        bytes20 b = bytes20(a);
        bytes memory s = new bytes(42);
        s[0] = "0";
        s[1] = "x";
        for (uint256 i; i < 20; ++i) {
            s[2 + i * 2] = _nib(uint8(b[i]) >> 4);
            s[3 + i * 2] = _nib(uint8(b[i]) & 0x0f);
        }
        return string(s);
    }

    function _nib(uint8 n) private pure returns (bytes1) {
        return bytes1(n < 10 ? 48 + n : 87 + n);
    }

    function _dec(uint64 n) private pure returns (string memory) {
        if (n == 0) return "0";
        uint64 t = n;
        uint256 d;
        while (t != 0) {
            ++d;
            t /= 10;
        }
        bytes memory s = new bytes(d);
        while (n != 0) {
            s[--d] = bytes1(uint8(48 + (n % 10)));
            n /= 10;
        }
        return string(s);
    }
}

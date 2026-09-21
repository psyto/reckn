// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "@zk/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "@zk/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockUSDC} from "@zktest/mocks/MockUSDC.sol";

/// S5 — the seam spec 013 §3.4 rests on, and the ONLY thing in the demo never run.
///
/// ★ THIS IS NOT THE ADAPTER. The adapter is §4-2 = event work and must not exist before
///   2026-09-25. `OutcomeProbe` below does not touch ENS, grants nothing, and writes nothing.
///   It answers one question: **can a contract derive the verdict of an already-settled deal
///   without being told it?** If no, §3.4 collapses back to r1 B1.
///
/// DISPOSABLE. Not ported.

/// @dev Read-only. No state, no authority, no ENS.
contract OutcomeProbe {
    error NotSettled();
    error VerifierSwapped();
    error WrongDeal();
    error RefundWindowPassed();

    RecknZkEscrow public immutable escrow;

    constructor(RecknZkEscrow e) {
        escrow = e;
    }

    /// Mirrors the four `require`s of spec 013 §3.4, and returns what they establish.
    function outcomeOf(bytes32 dealId, bytes calldata publicValues, bytes calldata proofBytes)
        external
        view
        returns (uint8 outcome, address buyer)
    {
        (
            address buyer_,
            ,
            ,
            ,
            address verifier,
            bytes32 verifierCodeHash,
            bytes32 dealBinding,
            uint64 fundedAt,
            RecknZkEscrow.State st
        ) = escrow.deals(dealId);

        if (st != RecknZkEscrow.State.Settled) revert NotSettled();
        if (block.timestamp >= uint256(fundedAt) + escrow.REFUND_AFTER()) {
            revert RefundWindowPassed(); // r2 B2: a refund also writes Settled
        }
        if (verifier.codehash != verifierCodeHash) revert VerifierSwapped();

        VerdictPublicValues memory v =
            RecknVerdictVerifier(verifier).verifyVerdict(publicValues, proofBytes);
        if (v.dealBinding != dealBinding) revert WrongDeal();

        return (v.outcome, buyer_);
    }
}

contract S5_JoinSeam is Test {
    string constant DIR = "../../zk-verdict/contracts/";
    string constant PROOF_REPRODUCED = "src/fixtures/reexec-groth16-fixture.json";
    string constant PROOF_FAILED = "src/fixtures/reexec-falserelease-fixture.json";

    uint256 constant AMOUNT = 250_000000;
    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");

    MockUSDC usdc;

    struct Proof {
        bytes32 vkey;
        bytes publicValues;
        bytes proof;
        bytes32 binding;
        uint256 outcome;
    }

    function _proof(string memory path) internal view returns (Proof memory p) {
        string memory json = vm.readFile(string.concat(DIR, path));
        p.vkey = vm.parseJsonBytes32(json, ".vkey");
        p.publicValues = vm.parseJsonBytes(json, ".public_values");
        p.proof = vm.parseJsonBytes(json, ".proof");
        p.binding = vm.parseJsonBytes32(json, ".deal_binding");
        p.outcome = vm.parseJsonUint(json, ".outcome");
    }

    function _setup(Proof memory p)
        internal
        returns (RecknZkEscrow escrow, RecknVerdictVerifier verifier, bytes32 dealId)
    {
        usdc = new MockUSDC();
        usdc.mint(buyer, 1000_000000);
        verifier = new RecknVerdictVerifier(address(new SP1Verifier()), p.vkey);
        escrow = new RecknZkEscrow();
        dealId = keccak256(abi.encodePacked("join-seam", p.binding));
        vm.prank(buyer);
        usdc.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        escrow.fund(
            dealId,
            seller,
            address(usdc),
            AMOUNT,
            address(verifier),
            address(verifier).codehash,
            p.binding
        );
    }

    /// THE SEAM. A third party settles directly; the probe must still derive the truth.
    function test_probe_derives_the_outcome_of_a_deal_it_did_not_settle() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        (RecknZkEscrow escrow, , bytes32 dealId) = _setup(p);
        OutcomeProbe probe = new OutcomeProbe(escrow);

        // somebody else, not us, settles
        vm.prank(address(0xDEAD));
        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        (uint8 outcome, address b) = probe.outcomeOf(dealId, p.publicValues, p.proof);
        emit log_named_uint("outcome derived by a contract", outcome);
        emit log_named_address("recipient fixed at funding", b);
        assertEq(outcome, uint8(p.outcome), "the probe derived the wrong verdict");
        assertEq(b, buyer, "the write recipient is not the funder's buyer");
        emit log("SEAM OK: the verdict came from the proof, not from the caller");
    }

    /// A Failed deal must record as Failed — R-7's ground.
    function test_failed_is_derivable_too() public {
        Proof memory p = _proof(PROOF_FAILED);
        (RecknZkEscrow escrow, , bytes32 dealId) = _setup(p);
        OutcomeProbe probe = new OutcomeProbe(escrow);

        vm.prank(address(0xDEAD));
        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        (uint8 outcome,) = probe.outcomeOf(dealId, p.publicValues, p.proof);
        emit log_named_uint("failed-fixture outcome", outcome);
        assertEq(outcome, uint8(p.outcome), "Failed did not come back as Failed");
    }

    /// r2 B2, mechanically: a timeout refund writes the same Settled state.
    /// The probe must refuse it, and must NOT refuse the same proof inside the window.
    function test_timeout_refund_is_refused_and_the_control_arm_passes() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        (RecknZkEscrow escrow, , bytes32 dealId) = _setup(p);
        OutcomeProbe probe = new OutcomeProbe(escrow);

        // control arm first: inside the window, after a real settlement, it works
        vm.prank(address(0xDEAD));
        escrow.settleWithProof(dealId, p.publicValues, p.proof);
        probe.outcomeOf(dealId, p.publicValues, p.proof);
        emit log("control: inside the window, a settled deal IS derivable");

        // now a second deal that nobody proves, refunded on timeout
        usdc.mint(buyer, 1000_000000);
        bytes32 dealId2 = keccak256("timeout-deal");
        vm.prank(buyer);
        usdc.approve(address(escrow), AMOUNT);
        (,,,, address verifier, bytes32 ch,,,) = escrow.deals(dealId);
        vm.prank(buyer);
        escrow.fund(dealId2, seller, address(usdc), AMOUNT, verifier, ch, p.binding);

        vm.warp(block.timestamp + escrow.REFUND_AFTER() + 1);
        escrow.refundAfterDeadline(dealId2);

        (,,,,,,,, RecknZkEscrow.State st) = escrow.deals(dealId2);
        assertTrue(st == RecknZkEscrow.State.Settled, "a refund really does write Settled");
        emit log("a timeout refund wrote State.Settled - exactly r2 B2");

        vm.expectRevert(OutcomeProbe.RefundWindowPassed.selector);
        probe.outcomeOf(dealId2, p.publicValues, p.proof);
        emit log("the probe REFUSED to record a refunded deal");
    }
}

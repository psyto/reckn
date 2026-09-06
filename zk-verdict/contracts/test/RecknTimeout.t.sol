// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// The keyless escrow's one payout that no proof authorises — and the four things
/// that have to be true about it for the escrow to stay keyless.
///
/// Before this, a funded deal whose prover never showed up stayed funded forever.
/// `RecknArcUsdcSettlement`'s blacklist test demonstrates the same hole from the
/// other side: a payout that keeps reverting leaves USDC in the contract with no way
/// out. A refund path is what makes an escrow with no admin something other than a
/// place money goes to die.
///
/// The acceptance conditions are task 001's, verbatim from `AGENTS.md` §3: any
/// address may call it after the deadline; nobody may call it before; after
/// `settleWithProof` the refund path is dead; and in either order, the money comes
/// out exactly once.
contract RecknTimeoutTest is Test {
    string constant FIXTURE = "src/fixtures/reexec-groth16-fixture.json";

    address buyer = address(0xB0B);
    address seller = address(0x5E11E5);
    address stranger = address(0x57A);
    uint256 constant AMOUNT = 250_000000;

    MockUSDC usdc;
    RecknZkEscrow escrow;
    RecknVerdictVerifier verifier;
    bytes32 binding;
    bytes publicValues;
    bytes proofBytes;

    function setUp() public {
        usdc = new MockUSDC();
        usdc.mint(buyer, AMOUNT);

        string memory json = vm.readFile(FIXTURE);
        binding = vm.parseJsonBytes32(json, ".deal_binding");
        publicValues = vm.parseJsonBytes(json, ".public_values");
        proofBytes = vm.parseJsonBytes(json, ".proof");

        verifier = new RecknVerdictVerifier(address(new SP1Verifier()), vm.parseJsonBytes32(json, ".vkey"));
        escrow = new RecknZkEscrow();
    }

    function _fund(bytes32 dealId) internal {
        vm.prank(buyer);
        usdc.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        escrow.fund(
            dealId, seller, address(usdc), AMOUNT,
            address(verifier), address(verifier).codehash, binding
        );
    }

    function _state(bytes32 dealId) internal view returns (RecknZkEscrow.State) {
        (,,,,,,,, RecknZkEscrow.State st) = escrow.deals(dealId);
        return st;
    }

    /// 001(a) — after the deadline, ANY address may call it, and calling it pays the
    /// caller nothing. The money goes where `fund` said it goes.
    function test_TMO01_any_address_may_refund_after_the_deadline() public {
        bytes32 dealId = keccak256("tmo-refund");
        _fund(dealId);

        vm.warp(block.timestamp + escrow.REFUND_AFTER());
        vm.prank(stranger);
        escrow.refundAfterDeadline(dealId);

        assertEq(usdc.balanceOf(buyer), AMOUNT, "the buyer is made whole");
        assertEq(usdc.balanceOf(stranger), 0, "the caller gets nothing for calling");
        assertEq(usdc.balanceOf(seller), 0, "and the seller, who proved nothing, gets nothing");
        assertEq(usdc.balanceOf(address(escrow)), 0, "escrow drained");
        assertTrue(_state(dealId) == RecknZkEscrow.State.Settled, "one-way");
    }

    /// 001(b) — before the deadline nobody may call it. Not a stranger, not the
    /// seller, and not the buyer whose money it is: an early refund is a way to take
    /// the money back after the work was done but before the proof landed.
    function test_TMO02_nobody_may_refund_before_the_deadline() public {
        bytes32 dealId = keccak256("tmo-early");
        _fund(dealId);

        vm.warp(block.timestamp + escrow.REFUND_AFTER() - 1);
        address[3] memory callers = [stranger, seller, buyer];
        for (uint256 i = 0; i < callers.length; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(RecknZkEscrow.TooEarly.selector);
            escrow.refundAfterDeadline(dealId);
        }
        assertEq(usdc.balanceOf(address(escrow)), AMOUNT, "the money has not moved");
        assertTrue(_state(dealId) == RecknZkEscrow.State.Funded, "still funded");
    }

    /// 001(c) — a deal a proof already settled cannot then be refunded, however long
    /// anyone waits.
    function test_TMO03_a_settled_deal_cannot_be_refunded_afterwards() public {
        bytes32 dealId = keccak256("tmo-settled-then-refund");
        _fund(dealId);

        escrow.settleWithProof(dealId, publicValues, proofBytes);
        assertEq(usdc.balanceOf(seller), AMOUNT, "the proof paid the seller");

        vm.warp(block.timestamp + escrow.REFUND_AFTER() * 10);
        vm.expectRevert(RecknZkEscrow.BadState.selector);
        escrow.refundAfterDeadline(dealId);

        assertEq(usdc.balanceOf(seller), AMOUNT, "still paid exactly once");
        assertEq(usdc.balanceOf(buyer), 0, "and the buyer is not paid a second time");
    }

    /// 001(d) — the reverse order. A refunded deal cannot then be settled by a proof,
    /// even a real one that verifies and carries the right binding.
    function test_TMO04_a_refunded_deal_cannot_then_be_settled_by_a_proof() public {
        bytes32 dealId = keccak256("tmo-refund-then-settle");
        _fund(dealId);

        vm.warp(block.timestamp + escrow.REFUND_AFTER());
        escrow.refundAfterDeadline(dealId);
        assertEq(usdc.balanceOf(buyer), AMOUNT, "refunded");

        vm.expectRevert(RecknZkEscrow.BadState.selector);
        escrow.settleWithProof(dealId, publicValues, proofBytes);

        assertEq(usdc.balanceOf(seller), 0, "the seller cannot be paid out of an empty deal");
        assertEq(usdc.balanceOf(buyer), AMOUNT, "and the buyer is not paid twice");
    }

    /// The refund cannot be called twice either — the same guard, stated as its own
    /// test because "one-way" is the property, not "one call".
    function test_TMO05_the_refund_cannot_be_called_twice() public {
        bytes32 dealId = keccak256("tmo-twice");
        _fund(dealId);

        vm.warp(block.timestamp + escrow.REFUND_AFTER());
        escrow.refundAfterDeadline(dealId);

        vm.expectRevert(RecknZkEscrow.BadState.selector);
        escrow.refundAfterDeadline(dealId);
        assertEq(usdc.balanceOf(buyer), AMOUNT, "paid back exactly once");
    }

    /// The waiting period is a constant of the protocol: no deployer chose it, no
    /// funder chose it, and there is no function that changes it.
    function test_TMO06_the_waiting_period_is_not_configurable() public view {
        assertEq(escrow.REFUND_AFTER(), 30 days, "fixed at thirty days");
    }
}

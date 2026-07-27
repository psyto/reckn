// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {RecknEscrow} from "../src/RecknEscrow.sol";
import {ResolverRegistry} from "../src/ResolverRegistry.sol";
import {VerdictHash} from "../src/libraries/VerdictHash.sol";
import {MockUSDC3009} from "./mocks/MockUSDC3009.sol";

contract RecknEscrowTest is Test {
    RecknEscrow escrow;
    ResolverRegistry registry;
    MockUSDC3009 token;

    address owner = address(0xA11CE);
    address buyer = address(0xB0B);
    address seller = address(0x5E11E5);

    uint256 resolverPk = 0xBEEF;
    address resolver;

    bytes32 constant BACKEND_ID = keccak256("reckn/backend/evm");
    bytes32 constant BACKEND_VER = keccak256("reckn/backend/evm@v1");
    bytes32 constant SPEC_HASH = keccak256("spec");
    bytes32 constant ANCHOR_HASH = keccak256("anchor");
    bytes32 constant DELIVERY_HASH = keccak256("delivery");

    uint256 constant AMOUNT = 1_000e6;
    uint64 constant DELIVER_W = 1 days;
    uint64 constant CHALLENGE_W = 1 days;
    uint64 constant RESOLVE_W = 1 days;

    function setUp() public {
        resolver = vm.addr(resolverPk);
        registry = new ResolverRegistry(owner);
        escrow = new RecknEscrow(registry);
        token = new MockUSDC3009();

        vm.startPrank(owner);
        registry.setResolver(resolver, true);
        registry.setBackend(BACKEND_ID, BACKEND_VER, true);
        vm.stopPrank();

        token.mint(buyer, AMOUNT);
    }

    // --- helpers ---

    function _fund(bytes32 salt) internal returns (bytes32 id) {
        vm.prank(buyer);
        id = escrow.fundWithAuthorization(
            salt, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER, DELIVER_W,
            0, type(uint256).max, keccak256(abi.encode("authnonce", salt)), 0, bytes32(0), bytes32(0)
        );
    }

    function _commitment(bytes32 id, uint8 outcome) internal pure returns (VerdictHash.VerdictCommitment memory) {
        return VerdictHash.VerdictCommitment({
            dealId: id,
            specHash: SPEC_HASH,
            deliveryHash: DELIVERY_HASH,
            prestateAnchorHash: ANCHOR_HASH,
            prestateRoot: keccak256("root"),
            backendId: BACKEND_ID,
            backendVersionHash: BACKEND_VER,
            outcome: outcome,
            resultHash: keccak256("result"),
            traceHash: keccak256("trace")
        });
    }

    function _sign(VerdictHash.VerdictCommitment memory c, uint256 pk) internal view returns (uint8, bytes32, bytes32) {
        bytes32 digest = VerdictHash.digest(escrow.DOMAIN_SEPARATOR(), c);
        return vm.sign(pk, digest);
    }

    // --- lifecycle: happy paths ---

    function test_resolve_reproduced_pays_seller() public {
        bytes32 id = _fund("s1");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0); // Reproduced
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        escrow.resolve(c, v, r, s);

        assertEq(token.balanceOf(seller), AMOUNT, "seller paid");
        assertEq(token.balanceOf(buyer), 0, "buyer spent");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    function test_resolve_failed_refunds_buyer() public {
        bytes32 id = _fund("s2");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 1); // Failed
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        escrow.resolve(c, v, r, s);

        assertEq(token.balanceOf(buyer), AMOUNT, "buyer refunded");
        assertEq(token.balanceOf(seller), 0, "seller unpaid");
    }

    function test_claimUnchallenged_pays_seller_after_deadline() public {
        bytes32 id = _fund("s3");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);

        vm.warp(block.timestamp + CHALLENGE_W + 1);
        vm.prank(seller);
        escrow.claimUnchallenged(id);
        assertEq(token.balanceOf(seller), AMOUNT, "seller paid on silence");
    }

    function test_reclaimUndelivered_refunds_buyer_after_deadline() public {
        bytes32 id = _fund("s4");
        vm.warp(block.timestamp + DELIVER_W + 1);
        vm.prank(buyer);
        escrow.reclaimUndelivered(id);
        assertEq(token.balanceOf(buyer), AMOUNT, "buyer reclaimed no-show");
    }

    // --- review C1: dispute never locks forever ---

    function test_timeoutRefund_refunds_buyer_when_no_verdict() public {
        bytes32 id = _fund("s5");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        vm.warp(block.timestamp + RESOLVE_W + 1);
        escrow.timeoutRefund(id); // anyone can call
        assertEq(token.balanceOf(buyer), AMOUNT, "buyer refunded on timeout");
    }

    function test_timeoutRefund_reverts_before_deadline() public {
        bytes32 id = _fund("s6");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        vm.expectRevert(RecknEscrow.DeadlineNotReached.selector);
        escrow.timeoutRefund(id);
    }

    // --- settlement-authority guards ---

    function test_resolve_rejects_unknown_resolver() public {
        bytes32 id = _fund("s7");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0);
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, 0xBADBAD); // not registered
        vm.expectRevert(RecknEscrow.UnknownResolver.selector);
        escrow.resolve(c, v, r, s);
    }

    function test_resolve_rejects_commitment_mismatch() public {
        bytes32 id = _fund("s8");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0);
        c.prestateAnchorHash = keccak256("fresh-anchor"); // resolver tries a new anchor
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        vm.expectRevert(RecknEscrow.CommitmentMismatch.selector);
        escrow.resolve(c, v, r, s);
    }

    function test_resolve_rejects_disallowed_backend() public {
        vm.prank(owner);
        registry.setBackend(BACKEND_ID, BACKEND_VER, false); // revoke

        bytes32 id = _fund("s9");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0);
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        vm.expectRevert(RecknEscrow.DisallowedBackend.selector);
        escrow.resolve(c, v, r, s);
    }

    function test_resolve_rejects_second_resolution() public {
        bytes32 id = _fund("s10");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0);
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        escrow.resolve(c, v, r, s);

        vm.expectRevert(RecknEscrow.BadState.selector);
        escrow.resolve(c, v, r, s);
    }

    // --- state-machine guards ---

    function test_deliver_rejects_non_seller() public {
        bytes32 id = _fund("s11");
        vm.expectRevert(RecknEscrow.NotSeller.selector);
        vm.prank(buyer);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
    }

    function test_challenge_rejects_non_buyer() public {
        bytes32 id = _fund("s12");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.expectRevert(RecknEscrow.NotBuyer.selector);
        vm.prank(seller);
        escrow.challenge(id, RESOLVE_W);
    }

    function test_duplicate_fund_reverts() public {
        _fund("dup");
        token.mint(buyer, AMOUNT);
        vm.expectRevert(RecknEscrow.DealExists.selector);
        vm.prank(buyer);
        escrow.fundWithAuthorization(
            "dup", seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER, DELIVER_W,
            0, type(uint256).max, keccak256(abi.encode("authnonce", bytes32("dup2"))), 0, bytes32(0), bytes32(0)
        );
    }

    // --- review M2: windows must be nonzero ---

    function test_fund_rejects_zero_deliver_window() public {
        vm.expectRevert(RecknEscrow.ZeroWindow.selector);
        vm.prank(buyer);
        escrow.fundWithAuthorization(
            "zw", seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER, 0,
            0, type(uint256).max, keccak256("zw-auth"), 0, bytes32(0), bytes32(0)
        );
    }

    function test_deliver_rejects_zero_challenge_window() public {
        bytes32 id = _fund("zw2");
        vm.expectRevert(RecknEscrow.ZeroWindow.selector);
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, 0);
    }

    function test_challenge_rejects_zero_resolve_window() public {
        bytes32 id = _fund("zw3");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.expectRevert(RecknEscrow.ZeroWindow.selector);
        vm.prank(buyer);
        escrow.challenge(id, 0);
    }

    // --- end to end: the full flow settles on REAL reexec-evm output ---
    // resultHash / traceHash below are the actual engine outputs captured in
    // dashboard/moneyshot.json (cargo run --example moneyshot), so this proves the
    // deployed contract accepts and settles a verdict the real engine produced.

    event VerdictCommitted(
        bytes32 indexed dealId,
        RecknEscrow.Outcome outcome,
        bytes32 prestateRoot,
        bytes32 resultHash,
        bytes32 traceHash,
        address resolver
    );

    event ReputationEvidence(
        address indexed agent,
        bool reproduced,
        bytes32 indexed dealId,
        bytes32 verdictTraceHash,
        bytes32 backendId
    );

    function test_e2e_false_claim_refunds_buyer_on_real_engine_output() public {
        bytes32 id = _fund("e2e-false");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 1); // Failed
        c.resultHash = 0xf1846cc92f5d3a04701c28886a449fd5caf52b84f9017e6efa521f513b449a20;
        c.traceHash = 0x2bf9692fe585295592983bf9cec62592dd32e97f3e00bd888e8a765dc8f28fd8;
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);

        // The on-chain record commits the engine's real trace hash.
        vm.expectEmit(true, false, false, true, address(escrow));
        emit VerdictCommitted(id, RecknEscrow.Outcome.Failed, c.prestateRoot, c.resultHash, c.traceHash, resolver);
        escrow.resolve(c, v, r, s);

        assertEq(token.balanceOf(buyer), AMOUNT, "false claim -> buyer refunded");
        assertEq(token.balanceOf(seller), 0, "seller unpaid");
    }

    function test_e2e_honest_releases_seller_on_real_engine_output() public {
        bytes32 id = _fund("e2e-honest");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0); // Reproduced
        c.resultHash = 0x2c48daa905066618b1071532f08fd6714b8adde8c4e34db9f2638b94719a51f6;
        c.traceHash = 0x71ce9c5f338669b974dce7e7660f2f7a121c71ed961269d976ecb095e6c1dd25;
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);

        escrow.resolve(c, v, r, s);

        assertEq(token.balanceOf(seller), AMOUNT, "honest -> seller released");
        assertEq(token.balanceOf(buyer), 0, "buyer spent");
    }

    // --- ERC-8004-style reputation evidence (pure projection of the verdict) ---

    function test_reputation_evidence_emitted_on_failed() public {
        bytes32 id = _fund("rep-fail");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 1); // Failed
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);

        // agent = seller, reproduced = false, evidence = the verdict trace hash.
        vm.expectEmit(true, true, false, true, address(escrow));
        emit ReputationEvidence(seller, false, id, c.traceHash, BACKEND_ID);
        escrow.resolve(c, v, r, s);
    }

    function test_reputation_evidence_emitted_on_reproduced() public {
        bytes32 id = _fund("rep-ok");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        VerdictHash.VerdictCommitment memory c = _commitment(id, 0); // Reproduced
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit ReputationEvidence(seller, true, id, c.traceHash, BACKEND_ID);
        escrow.resolve(c, v, r, s);
    }

    // --- conservation: escrow never mints or strands value ---

    function testFuzz_conservation(uint8 pathSel) public {
        bytes32 id = _fund("fuzz");
        uint256 total = token.balanceOf(buyer) + token.balanceOf(seller) + token.balanceOf(address(escrow));

        uint8 path = pathSel % 3;
        if (path == 0) {
            vm.prank(seller);
            escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
            vm.prank(buyer);
            escrow.challenge(id, RESOLVE_W);
            VerdictHash.VerdictCommitment memory c = _commitment(id, uint8(pathSel % 2));
            (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
            escrow.resolve(c, v, r, s);
        } else if (path == 1) {
            vm.warp(block.timestamp + DELIVER_W + 1);
            vm.prank(buyer);
            escrow.reclaimUndelivered(id);
        } else {
            vm.prank(seller);
            escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
            vm.warp(block.timestamp + CHALLENGE_W + 1);
            vm.prank(seller);
            escrow.claimUnchallenged(id);
        }

        uint256 after_ = token.balanceOf(buyer) + token.balanceOf(seller) + token.balanceOf(address(escrow));
        assertEq(after_, total, "value conserved");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow holds nothing after settle");
    }
}

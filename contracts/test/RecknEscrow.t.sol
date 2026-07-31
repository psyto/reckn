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
    // The buyer signs an EIP-3009 authorization off-chain, so it needs a key.
    uint256 buyerPk = 0xB0B;
    address buyer;
    address seller = address(0x5E11E5);
    // A third party that relays the buyer's signed authorization on-chain. It
    // never signs anything and is not a deal party — it only submits.
    address facilitator = address(0xFAC117A705);

    uint256 resolverPk = 0xBEEF;
    address resolver;
    // A second registered, bonded resolver — the challenger in a conflict.
    uint256 resolver2Pk = 0xF00D;
    address resolver2;

    bytes32 constant BACKEND_ID = keccak256("reckn/backend/evm");
    bytes32 constant BACKEND_VER = keccak256("reckn/backend/evm@v1");
    bytes32 constant SPEC_HASH = keccak256("spec");
    bytes32 constant ANCHOR_HASH = keccak256("anchor");
    bytes32 constant DELIVERY_HASH = keccak256("delivery");

    uint256 constant AMOUNT = 1_000e6;
    uint64 constant DELIVER_W = 1 days;
    uint64 constant CHALLENGE_W = 1 days;
    uint64 constant RESOLVE_W = 1 days;
    uint64 constant SETTLE_W = 1 days;
    uint256 constant BOND = 1 ether;

    function setUp() public {
        buyer = vm.addr(buyerPk);
        resolver = vm.addr(resolverPk);
        resolver2 = vm.addr(resolver2Pk);
        registry = new ResolverRegistry(owner);
        escrow = new RecknEscrow(registry);
        token = new MockUSDC3009();

        vm.startPrank(owner);
        registry.setResolver(resolver, true);
        registry.setResolver(resolver2, true);
        registry.setBackend(BACKEND_ID, BACKEND_VER, true);
        registry.setMinBond(BOND);
        vm.stopPrank();

        // Bond both resolvers (inert for the instant resolve() path).
        vm.deal(resolver, BOND);
        vm.prank(resolver);
        registry.depositBond{value: BOND}();
        vm.deal(resolver2, BOND);
        vm.prank(resolver2);
        registry.depositBond{value: BOND}();

        token.mint(buyer, AMOUNT);
    }

    // Fund → deliver → challenge, leaving the deal Disputed and ready to resolve.
    function _toDisputed(bytes32 salt) internal returns (bytes32 id) {
        id = _fund(salt);
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);
    }

    // --- helpers ---

    /// @dev The EIP-712 digest the buyer signs for an EIP-3009 `receive`
    ///      authorization, computed exactly as {MockUSDC3009} verifies it. `to` is
    ///      the escrow, because the escrow is the payee that pulls the funds.
    function _authDigest(address from, uint256 value, uint256 validAfter, uint256 validBefore, bytes32 nonce)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                token.RECEIVE_WITH_AUTHORIZATION_TYPEHASH(),
                from,
                address(escrow),
                value,
                validAfter,
                validBefore,
                nonce
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    }

    /// @dev Fund the canonical deal for `salt`: the buyer signs the term-bound
    ///      authorization, then a facilitator (not the buyer) relays it — the
    ///      default path already exercises the x402 relay property.
    function _fund(bytes32 salt) internal returns (bytes32 id) {
        id = escrow.computeDealId(
            salt, buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 nonce = escrow.fundingNonce(id, DELIVER_W);
        bytes32 digest = _authDigest(buyer, AMOUNT, 0, type(uint256).max, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPk, digest);

        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            salt, buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER, DELIVER_W,
            0, type(uint256).max, nonce, v, r, s
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

    /// A seller who withholds delivery/replay evidence to force a timeout cannot
    /// dodge the negative reputation signal: the timeout emits evidence-withheld
    /// (reproduced = false, zero trace) distinguishable from a reproduced Failed.
    function test_timeoutRefund_emits_evidence_withheld() public {
        bytes32 id = _fund("s5b");
        vm.prank(seller);
        escrow.deliver(id, DELIVERY_HASH, CHALLENGE_W);
        vm.prank(buyer);
        escrow.challenge(id, RESOLVE_W);

        vm.warp(block.timestamp + RESOLVE_W + 1);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit ReputationEvidence(seller, false, id, bytes32(0), BACKEND_ID);
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
        // Same terms -> same dealId; the slot is occupied, so this reverts before
        // the token is ever touched. The signature args are irrelevant here.
        bytes32 id = escrow.computeDealId(
            "dup", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 dupNonce = escrow.fundingNonce(id, DELIVER_W);
        vm.expectRevert(RecknEscrow.DealExists.selector);
        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            "dup", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER, DELIVER_W,
            0, type(uint256).max, dupNonce, 0, bytes32(0), bytes32(0)
        );
    }

    // --- review M2: windows must be nonzero ---

    function test_fund_rejects_zero_deliver_window() public {
        vm.expectRevert(RecknEscrow.ZeroWindow.selector);
        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            "zw", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER, 0,
            0, type(uint256).max, keccak256("zw-auth"), 0, bytes32(0), bytes32(0)
        );
    }

    // --- x402 / EIP-3009: one buyer signature both pays and opens the escrow ---

    function test_fund_facilitator_relays_buyer_signature() public {
        assertEq(token.balanceOf(buyer), AMOUNT, "buyer starts funded");
        // Relayed by the facilitator inside _fund (msg.sender != buyer).
        bytes32 id = _fund("relay");

        RecknEscrow.Deal memory d = escrow.getDeal(id);
        assertEq(d.buyer, buyer, "deal bound to the signer, not the relayer");
        assertEq(uint8(d.state), uint8(RecknEscrow.DealState.Held), "held");
        assertEq(token.balanceOf(buyer), 0, "funds pulled from the buyer");
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "escrow holds the pot");
        assertEq(token.balanceOf(facilitator), 0, "relayer never touches funds");
    }

    /// A relayer that keeps the buyer's signed nonce but swaps a term (here the
    /// seller) recomputes a different dealId, so the bound nonce no longer matches.
    function test_fund_rejects_tampered_term_via_nonce() public {
        bytes32 id = escrow.computeDealId(
            "tamper", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 nonce = escrow.fundingNonce(id, DELIVER_W);
        bytes32 digest = _authDigest(buyer, AMOUNT, 0, type(uint256).max, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPk, digest);

        address otherSeller = address(0xBAD5E11E5);
        vm.expectRevert(RecknEscrow.BadNonce.selector);
        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            "tamper", buyer, otherSeller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER,
            DELIVER_W, 0, type(uint256).max, nonce, v, r, s
        );
    }

    /// A relayer that instead forges a matching nonce for the tampered terms gets
    /// past the escrow's nonce check, but the token rejects the buyer's signature
    /// because it was never signed over the new amount.
    function test_fund_rejects_tampered_amount_via_token_signature() public {
        // Buyer signs for AMOUNT against the honest deal.
        bytes32 id = escrow.computeDealId(
            "amt", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 nonce = escrow.fundingNonce(id, DELIVER_W);
        bytes32 digest = _authDigest(buyer, AMOUNT, 0, type(uint256).max, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPk, digest);

        // Relayer inflates the amount and recomputes a matching bound nonce.
        uint256 tampered = AMOUNT + 1;
        token.mint(buyer, 1);
        bytes32 id2 = escrow.computeDealId(
            "amt", buyer, seller, address(token), tampered, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 nonce2 = escrow.fundingNonce(id2, DELIVER_W);
        vm.expectRevert("3009: bad signature");
        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            "amt", buyer, seller, address(token), tampered, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER,
            DELIVER_W, 0, type(uint256).max, nonce2, v, r, s
        );
    }

    function test_fund_rejects_wrong_signer() public {
        bytes32 id = escrow.computeDealId(
            "wrong", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 nonce = escrow.fundingNonce(id, DELIVER_W);
        bytes32 digest = _authDigest(buyer, AMOUNT, 0, type(uint256).max, nonce);
        // Signed by the resolver, not the buyer.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(resolverPk, digest);

        vm.expectRevert("3009: bad signature");
        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            "wrong", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER,
            DELIVER_W, 0, type(uint256).max, nonce, v, r, s
        );
    }

    function test_fund_rejects_expired_authorization() public {
        vm.warp(1000);
        bytes32 id = escrow.computeDealId(
            "exp", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER
        );
        bytes32 nonce = escrow.fundingNonce(id, DELIVER_W);
        // Signed with a validBefore already in the past.
        bytes32 digest = _authDigest(buyer, AMOUNT, 0, 500, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPk, digest);

        vm.expectRevert("3009: auth expired");
        vm.prank(facilitator);
        escrow.fundWithAuthorization(
            "exp", buyer, seller, address(token), AMOUNT, SPEC_HASH, ANCHOR_HASH, BACKEND_ID, BACKEND_VER,
            DELIVER_W, 0, 500, nonce, v, r, s
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

    // --- optimistic settlement: bonded resolver + challenge window ---

    function test_optimistic_reproduced_finalizes_to_seller() public {
        bytes32 id = _toDisputed("o1");
        VerdictHash.VerdictCommitment memory c = _commitment(id, 0); // Reproduced
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        escrow.resolveOptimistic(c, v, r, s, SETTLE_W);

        // Not settled during the window.
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "held during window");
        assertEq(uint8(escrow.getDeal(id).state), uint8(RecknEscrow.DealState.Settling));

        vm.warp(block.timestamp + SETTLE_W + 1);
        escrow.finalizeSettlement(id);

        assertEq(token.balanceOf(seller), AMOUNT, "seller paid after window");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    function test_optimistic_failed_finalizes_to_buyer() public {
        bytes32 id = _toDisputed("o2");
        VerdictHash.VerdictCommitment memory c = _commitment(id, 1); // Failed
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        escrow.resolveOptimistic(c, v, r, s, SETTLE_W);

        vm.warp(block.timestamp + SETTLE_W + 1);
        escrow.finalizeSettlement(id);

        assertEq(token.balanceOf(buyer), AMOUNT, "buyer refunded after window");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    function test_finalize_reverts_before_window_closes() public {
        bytes32 id = _toDisputed("o3");
        VerdictHash.VerdictCommitment memory c = _commitment(id, 0);
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        escrow.resolveOptimistic(c, v, r, s, SETTLE_W);

        vm.expectRevert(RecknEscrow.SettleWindowOpen.selector);
        escrow.finalizeSettlement(id);
    }

    function test_resolveOptimistic_reverts_unbonded_resolver() public {
        // Resolver pulls its bond → no longer bonded.
        vm.prank(resolver);
        registry.withdrawBond(BOND);

        bytes32 id = _toDisputed("o4");
        VerdictHash.VerdictCommitment memory c = _commitment(id, 0);
        (uint8 v, bytes32 r, bytes32 s) = _sign(c, resolverPk);
        vm.expectRevert(RecknEscrow.NotBonded.selector);
        escrow.resolveOptimistic(c, v, r, s, SETTLE_W);
    }

    function test_challenge_conflict_refunds_buyer_and_emits_fault() public {
        bytes32 id = _toDisputed("o5");
        // Resolver 1 optimistically resolves Reproduced.
        VerdictHash.VerdictCommitment memory c1 = _commitment(id, 0);
        (uint8 v1, bytes32 r1, bytes32 s1) = _sign(c1, resolverPk);
        escrow.resolveOptimistic(c1, v1, r1, s1, SETTLE_W);

        // Resolver 2 presents a conflicting verdict (Failed) within the window.
        VerdictHash.VerdictCommitment memory c2 = _commitment(id, 1);
        (uint8 v2, bytes32 r2, bytes32 s2) = _sign(c2, resolver2Pk);

        vm.expectEmit(true, true, true, true);
        emit RecknEscrow.Fault(id, resolver, resolver2, c2.traceHash);
        escrow.challengeVerdict(c2, v2, r2, s2);

        assertEq(token.balanceOf(buyer), AMOUNT, "conflict fail-safes to buyer refund");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
        assertEq(uint8(escrow.getDeal(id).state), uint8(RecknEscrow.DealState.Resolved));
    }

    function test_challenge_reverts_when_not_conflicting() public {
        bytes32 id = _toDisputed("o6");
        VerdictHash.VerdictCommitment memory c1 = _commitment(id, 0);
        (uint8 v1, bytes32 r1, bytes32 s1) = _sign(c1, resolverPk);
        escrow.resolveOptimistic(c1, v1, r1, s1, SETTLE_W);

        // Resolver 2 signs the SAME verdict — honest agreement is not a challenge.
        VerdictHash.VerdictCommitment memory c2 = _commitment(id, 0);
        (uint8 v2, bytes32 r2, bytes32 s2) = _sign(c2, resolver2Pk);
        vm.expectRevert(RecknEscrow.NotConflicting.selector);
        escrow.challengeVerdict(c2, v2, r2, s2);
    }

    function test_challenge_reverts_same_resolver() public {
        bytes32 id = _toDisputed("o7");
        VerdictHash.VerdictCommitment memory c1 = _commitment(id, 0);
        (uint8 v1, bytes32 r1, bytes32 s1) = _sign(c1, resolverPk);
        escrow.resolveOptimistic(c1, v1, r1, s1, SETTLE_W);

        // The same resolver cannot "challenge" its own verdict.
        VerdictHash.VerdictCommitment memory c2 = _commitment(id, 1);
        (uint8 v2, bytes32 r2, bytes32 s2) = _sign(c2, resolverPk);
        vm.expectRevert(RecknEscrow.SameResolver.selector);
        escrow.challengeVerdict(c2, v2, r2, s2);
    }

    function test_challenge_reverts_after_window() public {
        bytes32 id = _toDisputed("o8");
        VerdictHash.VerdictCommitment memory c1 = _commitment(id, 0);
        (uint8 v1, bytes32 r1, bytes32 s1) = _sign(c1, resolverPk);
        escrow.resolveOptimistic(c1, v1, r1, s1, SETTLE_W);

        vm.warp(block.timestamp + SETTLE_W + 1);
        VerdictHash.VerdictCommitment memory c2 = _commitment(id, 1);
        (uint8 v2, bytes32 r2, bytes32 s2) = _sign(c2, resolver2Pk);
        vm.expectRevert(RecknEscrow.SettleWindowClosed.selector);
        escrow.challengeVerdict(c2, v2, r2, s2);
    }

    // --- registry bonds ---

    function test_registry_deposit_and_withdraw_bond() public {
        address r3 = address(0xD00D);
        vm.deal(r3, 3 ether);
        vm.startPrank(r3);
        registry.depositBond{value: 2 ether}();
        assertEq(registry.bond(r3), 2 ether);
        assertTrue(registry.isBonded(r3));
        registry.withdrawBond(2 ether);
        assertEq(registry.bond(r3), 0);
        assertFalse(registry.isBonded(r3));
        vm.stopPrank();
        assertEq(r3.balance, 3 ether, "bond returned in full");
    }

    function test_registry_withdraw_insufficient_reverts() public {
        vm.prank(resolver);
        vm.expectRevert(ResolverRegistry.InsufficientBond.selector);
        registry.withdrawBond(BOND + 1);
    }

    function test_registry_slash_transfers_bond_to_payee() public {
        assertEq(registry.bond(resolver), BOND);
        vm.prank(owner);
        registry.slash(resolver, buyer, BOND);
        assertEq(registry.bond(resolver), 0, "bond slashed");
        assertEq(buyer.balance, BOND, "harmed party compensated");
        assertFalse(registry.isBonded(resolver), "no longer bonded");
    }

    function test_registry_slash_only_owner() public {
        vm.prank(buyer);
        vm.expectRevert(ResolverRegistry.NotOwner.selector);
        registry.slash(resolver, buyer, BOND);
    }
}

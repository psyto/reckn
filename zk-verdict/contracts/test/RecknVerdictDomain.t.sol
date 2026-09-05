// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// AC-10 — the widened record survives the round trip on-chain, and the attack
/// refunds the buyer.
///
/// Both fixtures are REAL Groth16 proofs of in-guest re-executions, verified by
/// SP1's real verifier. The headline one credits 100 across the limb-0 boundary;
/// the false-release one is a DECREASE (pre = 2^64, post = 2^64 - 1) which the
/// pre-008 guest proved as the largest possible credit and released to the seller.
/// Test 3 is that exact cell, and it now pays the buyer.
///
/// Tier: `forge test` against SP1Verifier with committed proofs, on one machine.
/// Not a chain result, and nothing here may be described as one.
contract RecknVerdictDomainTest is Test {
    string constant FIXTURE = "src/fixtures/reexec-groth16-fixture.json";
    string constant FALSE_RELEASE = "src/fixtures/reexec-falserelease-fixture.json";
    string constant ALT_BINDING = "src/fixtures/alt-binding.json";

    uint256 constant TWO_64 = 2 ** 64;

    address buyer = address(0xB0B);
    address seller = address(0x5E11E5);
    uint256 constant AMOUNT = 1_000e6;

    MockERC20 token;

    function setUp() public {
        token = new MockERC20();
        token.mint(buyer, AMOUNT);
    }

    function _fund(RecknZkEscrow escrow, bytes32 dealId, bytes32 binding) internal {
        vm.prank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        escrow.fund(dealId, seller, address(token), AMOUNT, binding);
    }

    function _verifier(string memory json) internal returns (RecknVerdictVerifier) {
        bytes32 vkey = vm.parseJsonBytes32(json, ".vkey");
        SP1Verifier sp1 = new SP1Verifier();
        return new RecknVerdictVerifier(address(sp1), vkey);
    }

    /// 1. The value crosses limb 0 and arrives whole. Against the pre-008 `uint64`
    ///    struct this decode reverts on dirty high bits.
    function test_AC10_verifier_returns_untruncated_pre() public {
        require(vm.exists(FIXTURE), "missing reexec fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(FIXTURE);
        VerdictPublicValues memory got = _verifier(json).verifyVerdict(
            vm.parseJsonBytes(json, ".public_values"), vm.parseJsonBytes(json, ".proof")
        );
        assertEq(got.pre, TWO_64, "pre survives the limb-0 boundary");
        assertEq(got.post, TWO_64 + 100, "post survives the limb-0 boundary");
        assertEq(got.post - got.pre, 100, "credited delta");
    }

    /// 2. The same proof moves money: Reproduced above 2^64 pays the seller.
    function test_AC10_reproduced_settles_to_seller_at_pre_above_2_64() public {
        require(vm.exists(FIXTURE), "missing reexec fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(FIXTURE);
        assertEq(vm.parseJsonUint(json, ".outcome"), 0, "fixture is Reproduced");

        RecknZkEscrow escrow = new RecknZkEscrow(_verifier(json));
        bytes32 dealId = keccak256("deal-widened-reproduced");
        _fund(escrow, dealId, vm.parseJsonBytes32(json, ".deal_binding"));

        escrow.settleWithProof(
            dealId, vm.parseJsonBytes(json, ".public_values"), vm.parseJsonBytes(json, ".proof")
        );

        assertEq(token.balanceOf(seller), AMOUNT, "seller paid above 2^64");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    /// 3. THE CELL THAT USED TO PAY THE SELLER. pre = 2^64, post = 2^64 - 1: the
    ///    balance decreased. The pre-008 guest read limb 0 and saw a credit of
    ///    u64::MAX, proved `Reproduced`, and released to the seller. The same
    ///    execution now proves `Failed` and the escrow refunds the buyer.
    function test_AC10_false_release_vector_refunds_the_buyer() public {
        require(vm.exists(FALSE_RELEASE), "missing false-release fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(FALSE_RELEASE);
        assertEq(vm.parseJsonUint(json, ".outcome"), 1, "the decrease is proven Failed");

        VerdictPublicValues memory got = _verifier(json).verifyVerdict(
            vm.parseJsonBytes(json, ".public_values"), vm.parseJsonBytes(json, ".proof")
        );
        assertEq(got.pre, TWO_64, "pre is 2^64");
        assertEq(got.post, TWO_64 - 1, "post is one wei below it -- a decrease");

        RecknZkEscrow escrow = new RecknZkEscrow(_verifier(json));
        bytes32 dealId = keccak256("deal-false-release");
        _fund(escrow, dealId, vm.parseJsonBytes32(json, ".deal_binding"));

        escrow.settleWithProof(
            dealId, vm.parseJsonBytes(json, ".public_values"), vm.parseJsonBytes(json, ".proof")
        );

        assertEq(token.balanceOf(buyer), AMOUNT, "buyer refunded on the proven decrease");
        assertEq(token.balanceOf(seller), 0, "seller paid nothing");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    /// AC-7b.1 — the real proof settles the deal it is bound to.
    function test_AC07_real_proof_settles_the_deal_it_is_bound_to() public {
        require(vm.exists(FIXTURE), "missing reexec fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(FIXTURE);

        RecknZkEscrow escrow = new RecknZkEscrow(_verifier(json));
        bytes32 dealId = keccak256("deal-bound");
        _fund(escrow, dealId, vm.parseJsonBytes32(json, ".deal_binding"));

        escrow.settleWithProof(
            dealId, vm.parseJsonBytes(json, ".public_values"), vm.parseJsonBytes(json, ".proof")
        );
        assertEq(token.balanceOf(seller), AMOUNT, "seller paid on the deal's own proof");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    /// AC-7b.2 — a proof of ANOTHER convenient execution cannot settle this deal.
    /// `alt-binding.json` carries the binding of an execution that differs only in
    /// the block environment (the timestamp), which the pre-008 guest could not
    /// distinguish at all: it configured chain_id and nothing else.
    function test_AC07_proof_from_another_execution_reverts_BindingMismatch() public {
        require(vm.exists(FIXTURE), "missing reexec fixture -- a missing fixture is a hard failure");
        require(vm.exists(ALT_BINDING), "missing alt-binding fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(FIXTURE);
        bytes32 alt = vm.parseJsonBytes32(vm.readFile(ALT_BINDING), ".deal_binding");
        assertTrue(alt != vm.parseJsonBytes32(json, ".deal_binding"), "the two executions differ");

        RecknZkEscrow escrow = new RecknZkEscrow(_verifier(json));
        bytes32 dealId = keccak256("deal-other-execution");
        _fund(escrow, dealId, alt);

        vm.expectRevert(RecknZkEscrow.BindingMismatch.selector);
        escrow.settleWithProof(
            dealId, vm.parseJsonBytes(json, ".public_values"), vm.parseJsonBytes(json, ".proof")
        );
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "funds stay in escrow");
        assertEq(token.balanceOf(seller), 0, "seller paid nothing");
    }

    /// 4. A forged record with the widened field types is still not a proof.
    function test_AC10_tampered_public_values_are_rejected() public {
        require(vm.exists(FIXTURE), "missing reexec fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(FIXTURE);
        RecknVerdictVerifier v = _verifier(json);

        bytes memory forged = abi.encode(
            VerdictPublicValues({
                pre: TWO_64,
                post: type(uint256).max,
                minDelta: 0,
                maxDelta: type(uint256).max,
                outcome: 0,
                traceHash: bytes32(uint256(1)),
                dealBinding: vm.parseJsonBytes32(json, ".deal_binding")
            })
        );

        vm.expectRevert();
        v.verifyVerdict(forged, vm.parseJsonBytes(json, ".proof"));
    }
}

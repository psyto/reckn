// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// Reckn on Arc — a conditional USDC payment whose condition is a proof.
///
/// Arc is a payment rail, not an adjudicator: nothing here changes how a verdict is
/// reached. What it shows is that the money being released is **USDC**, in USDC's
/// own units, released by the **existing** keyless path — the same real Groth16
/// proofs, the same `dealBinding`, the same `settleWithProof` with no admin and no
/// resolver. `RecknZkEscrow` is unmodified: on Arc, USDC is the native gas token and
/// Circle exposes an ERC-20 interface over it at
/// `0x3600000000000000000000000000000000000000` (6 decimals on that face), so the
/// escrow holds it the way it holds any ERC-20, and the deal names it as its `token`.
///
/// **Tier (`AGENTS.md` §5).** These run under `forge` on one machine against a
/// USDC-shaped mock. They are NOT an Arc testnet result and nothing here may be
/// described as one. What they establish is that the settlement logic is correct in
/// USDC's units and under USDC's semantics — which is the part a deployment cannot
/// tell you afterwards.
contract RecknArcUsdcSettlementTest is Test {
    /// The real EVM re-execution proof: `Reproduced`.
    string constant PROOF_REPRODUCED = "src/fixtures/reexec-groth16-fixture.json";
    /// The real EVM re-execution proof of a DECREASE: `Failed`. Before task 008 this
    /// exact execution proved as the largest possible credit and paid the seller.
    string constant PROOF_FAILED = "src/fixtures/reexec-falserelease-fixture.json";
    /// A binding from an execution differing only in the block environment.
    string constant ALT_BINDING = "src/fixtures/alt-binding.json";
    /// The real SVM re-execution proof: a `bank_hash`-authenticated System transfer.
    string constant SVM_PROOF = "src/fixtures/svm-groth16-fixture.json";

    /// 250.00 USDC. Six decimals, not eighteen — the units the escrow will actually
    /// hold on Arc.
    uint256 constant AMOUNT = 250_000000;

    address buyer = address(0xB0B);
    address seller = address(0x5E11E5);

    MockUSDC usdc;
    SP1Verifier sp1;

    function setUp() public {
        usdc = new MockUSDC();
        usdc.mint(buyer, 1_000_000000); // 1,000.00 USDC
        sp1 = new SP1Verifier();
    }

    struct Proof {
        bytes32 vkey;
        bytes publicValues;
        bytes proof;
        bytes32 binding;
        uint256 outcome;
    }

    function _proof(string memory path) internal view returns (Proof memory p) {
        string memory json = vm.readFile(path);
        p.vkey = vm.parseJsonBytes32(json, ".vkey");
        p.publicValues = vm.parseJsonBytes(json, ".public_values");
        p.proof = vm.parseJsonBytes(json, ".proof");
        p.binding = vm.parseJsonBytes32(json, ".deal_binding");
        p.outcome = vm.parseJsonUint(json, ".outcome");
    }

    function _escrow(Proof memory p)
        internal
        returns (RecknZkEscrow escrow, RecknVerdictVerifier verifier)
    {
        verifier = new RecknVerdictVerifier(address(sp1), p.vkey);
        escrow = new RecknZkEscrow();
    }

    function _fund(
        RecknZkEscrow escrow,
        RecknVerdictVerifier verifier,
        bytes32 dealId,
        bytes32 binding,
        uint256 amount
    ) internal {
        vm.prank(buyer);
        usdc.approve(address(escrow), amount);
        vm.prank(buyer);
        escrow.fund(
            dealId, seller, address(usdc), amount,
            address(verifier), address(verifier).codehash, binding
        );
    }

    function _state(RecknZkEscrow escrow, bytes32 dealId) internal view returns (RecknZkEscrow.State) {
        (,,,,,,,, RecknZkEscrow.State st) = escrow.deals(dealId);
        return st;
    }

    /// The headline: a USDC payment released by a proof, with nobody able to release it.
    function test_ARC01_usdc_deal_settles_to_the_seller_on_a_real_proof() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        assertEq(p.outcome, 0, "the fixture is Reproduced");
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(p);

        bytes32 dealId = keccak256("arc-usdc-reproduced");
        _fund(escrow, verifier, dealId, p.binding, AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), AMOUNT, "escrow holds 250.00 USDC");
        assertEq(usdc.balanceOf(buyer), 750_000000, "buyer is down exactly 250.00");

        // Anyone may submit it: authority comes from the proof, not the caller.
        vm.prank(address(0xDEAD));
        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        assertEq(usdc.balanceOf(seller), AMOUNT, "seller paid 250.00 USDC on the proof");
        assertEq(usdc.balanceOf(address(escrow)), 0, "escrow drained");
        assertTrue(_state(escrow, dealId) == RecknZkEscrow.State.Settled, "settled");
    }

    /// The other half of a conditional payment: the condition failing must return the
    /// money. This uses the proof of a balance DECREASE — the cell that paid the
    /// seller before task 008.
    function test_ARC02_usdc_deal_refunds_the_buyer_on_a_proven_failure() public {
        Proof memory p = _proof(PROOF_FAILED);
        assertEq(p.outcome, 1, "the fixture is a proven Failed");
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(p);

        bytes32 dealId = keccak256("arc-usdc-failed");
        _fund(escrow, verifier, dealId, p.binding, AMOUNT);

        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        assertEq(usdc.balanceOf(buyer), 1_000_000000, "buyer made whole, to the cent");
        assertEq(usdc.balanceOf(seller), 0, "seller paid nothing");
        assertEq(usdc.balanceOf(address(escrow)), 0, "escrow drained");
    }

    /// A proof of some other favourable execution cannot take the USDC.
    function test_ARC03_a_proof_of_another_execution_cannot_take_the_usdc() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 alt = vm.parseJsonBytes32(vm.readFile(ALT_BINDING), ".deal_binding");
        assertTrue(alt != p.binding, "the two executions differ");
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(p);

        bytes32 dealId = keccak256("arc-usdc-other-execution");
        _fund(escrow, verifier, dealId, alt, AMOUNT);

        vm.expectRevert(RecknZkEscrow.BindingMismatch.selector);
        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        assertEq(usdc.balanceOf(address(escrow)), AMOUNT, "the USDC stays in escrow");
        assertEq(usdc.balanceOf(seller), 0, "seller paid nothing");
    }

    /// Six decimals move exactly. An escrow tested only against an 18-decimal token
    /// has never been tested against the units it will hold.
    function test_ARC04_six_decimal_amounts_move_exactly() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(p);

        uint256 odd = 1_234567; // 1.234567 USDC — every decimal place significant
        bytes32 dealId = keccak256("arc-usdc-exact");
        _fund(escrow, verifier, dealId, p.binding, odd);

        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        assertEq(usdc.balanceOf(seller), odd, "the seller receives 1.234567, not 1.23");
        assertEq(usdc.balanceOf(buyer), 1_000_000000 - odd, "and the buyer is down exactly that");
        assertEq(usdc.decimals(), 6, "USDC's ERC-20 face on Arc is six decimals");
    }

    /// USDC can freeze an address. This is not a bug in the escrow, and the honest
    /// consequence is demonstrated rather than described: the payout reverts, the
    /// deal stays Funded and the money stays where it is until either the freeze is
    /// lifted or `refundAfterDeadline` returns it to the buyer (thirty days,
    /// permissionless — `RecknTimeout.t.sol`). Before that existed, this state was
    /// permanent, which is why the test was written before the fix was.
    function test_ARC05_a_blacklisted_seller_makes_settlement_revert_and_the_money_stays() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(p);

        bytes32 dealId = keccak256("arc-usdc-blacklisted");
        _fund(escrow, verifier, dealId, p.binding, AMOUNT);

        usdc.setBlacklisted(seller, true);

        vm.expectRevert(abi.encodeWithSelector(MockUSDC.Blacklisted.selector, seller));
        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        assertTrue(_state(escrow, dealId) == RecknZkEscrow.State.Funded, "still funded");
        assertEq(usdc.balanceOf(address(escrow)), AMOUNT, "the USDC is still in escrow");

        // Unfreeze and the same proof settles: the proof did not expire, and nothing
        // about the verdict changed.
        usdc.setBlacklisted(seller, false);
        escrow.settleWithProof(dealId, p.publicValues, p.proof);
        assertEq(usdc.balanceOf(seller), AMOUNT, "paid once the freeze is lifted");
    }

    /// The sentence this whole repository exists to make true, in one transaction:
    /// **USDC escrowed on Arc, released by a proof about work performed on Solana.**
    ///
    /// Nothing here is a bridge and nothing is a light client. The deal names the
    /// Solana guest's verifier at funding; `settleWithProof` calls it, checks that
    /// the proof carries THIS deal's binding, and pays. The escrow does not know
    /// which virtual machine the work happened on, and that is the point — the
    /// adjudicator is a computation, so it does not belong to a chain.
    ///
    /// What it does NOT say (`docs/arc-usdc.md`, and unchanged by this test):
    /// "settled by a Solana proof" means "settled by a proof about a Solana-shaped
    /// state the deal named". The provenance of the committed `bank_hash` is not
    /// established here or anywhere else in this repository.
    function test_ARC07_usdc_on_arc_settled_by_a_proof_about_work_on_solana() public {
        Proof memory svm = _proof(SVM_PROOF);
        Proof memory evm = _proof(PROOF_REPRODUCED);
        assertEq(svm.outcome, 0, "the Solana fixture is Reproduced");
        assertTrue(svm.vkey != evm.vkey, "two guests, two vkeys, not the same proof twice");
        assertTrue(svm.binding != evm.binding, "and two executions, two bindings");

        // One escrow. The deal names the SOLANA guest's verifier; the token is USDC.
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(svm);
        bytes32 dealId = keccak256("arc-usdc-settled-by-solana");
        _fund(escrow, verifier, dealId, svm.binding, AMOUNT);
        assertEq(usdc.balanceOf(address(escrow)), AMOUNT, "250.00 USDC escrowed");

        escrow.settleWithProof(dealId, svm.publicValues, svm.proof);

        assertEq(usdc.balanceOf(seller), AMOUNT, "USDC released on a Solana proof");
        assertEq(usdc.balanceOf(address(escrow)), 0, "escrow drained");
        assertTrue(_state(escrow, dealId) == RecknZkEscrow.State.Settled, "settled");

        // And the EVM proof cannot take this deal's USDC: the barriers are per-deal,
        // not per-chain.
        bytes32 other = keccak256("arc-usdc-settled-by-solana-2");
        _fund(escrow, verifier, other, svm.binding, AMOUNT);
        vm.expectRevert();
        escrow.settleWithProof(other, evm.publicValues, evm.proof);
        assertEq(usdc.balanceOf(address(escrow)), AMOUNT, "the second deal keeps its USDC");
    }

    /// No USDC is created or destroyed by a settlement.
    function test_ARC06_no_usdc_is_created_or_destroyed_by_a_settlement() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        (RecknZkEscrow escrow, RecknVerdictVerifier verifier) = _escrow(p);

        uint256 supply0 = usdc.totalSupply();
        uint256 sum0 = usdc.balanceOf(buyer) + usdc.balanceOf(seller) + usdc.balanceOf(address(escrow));

        bytes32 dealId = keccak256("arc-usdc-conservation");
        _fund(escrow, verifier, dealId, p.binding, AMOUNT);
        escrow.settleWithProof(dealId, p.publicValues, p.proof);

        assertEq(usdc.totalSupply(), supply0, "supply unchanged");
        assertEq(
            usdc.balanceOf(buyer) + usdc.balanceOf(seller) + usdc.balanceOf(address(escrow)),
            sum0,
            "conserved across funding and settlement"
        );
    }
}

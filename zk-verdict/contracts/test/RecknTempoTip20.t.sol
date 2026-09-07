// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockTIP20} from "./mocks/MockTIP20.sol";

/// Task 011 — **a Tempo agent payment settles only when a Solana action can be reproducibly
/// proven.** The escrow holds a TIP-20 stablecoin; the release condition is a real Groth16
/// proof that a named Solana execution reproduced; the same machinery refunds the buyer when
/// it did not.
///
/// **These are the SAME fixtures the Arc tests use.** Nothing here regenerates a proof,
/// changes a guest, or touches `RecknZkEscrow` — 011 is additive, and the fact that the
/// escrow needs no change to settle a TIP-20 is the finding, not an accident. If a test in
/// this file ever requires editing `src/`, that is a finding to report (011 §Lane).
///
/// What is deliberately NOT claimed here: nothing crosses a bridge, and the proof does not
/// establish that the prestate came from Solana mainnet. It establishes that the declared
/// prestate, predicate and execution produced the committed result.
contract RecknTempoTip20Test is Test {
    string constant REPRO = "src/fixtures/svm-groth16-fixture.json";
    string constant FAILED = "src/fixtures/svm-failed-fixture.json";

    address constant BUYER = address(0xB0B);
    address constant SELLER = address(0x5E11E4);

    struct Fx {
        bytes32 vkey;
        bytes publicValues;
        bytes proof;
        bytes32 dealBinding;
        uint256 outcome;
    }

    function _load(string memory path) internal view returns (Fx memory f) {
        require(
            vm.exists(path),
            "missing svm fixture -- a missing fixture is a hard failure; regenerate with `cargo run --bin svm -- --fixture`"
        );
        string memory json = vm.readFile(path);
        f.vkey = vm.parseJsonBytes32(json, ".vkey");
        f.publicValues = vm.parseJsonBytes(json, ".public_values");
        f.proof = vm.parseJsonBytes(json, ".proof");
        f.dealBinding = vm.parseJsonBytes32(json, ".deal_binding");
        f.outcome = vm.parseJsonUint(json, ".outcome");
    }

    /// Deploys the real verifier chain for a fixture and a TIP-20 at the given decimals.
    function _rig(string memory path, uint8 decimals)
        internal
        returns (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok)
    {
        f = _load(path);
        SP1Verifier sp1 = new SP1Verifier();
        v = new RecknVerdictVerifier(address(sp1), f.vkey);
        escrow = new RecknZkEscrow();
        tok = new MockTIP20("Path USD", "pathUSD", decimals);
    }

    function _fund(
        RecknZkEscrow escrow,
        MockTIP20 tok,
        RecknVerdictVerifier v,
        bytes32 dealId,
        bytes32 binding,
        uint256 amount
    ) internal {
        tok.mint(BUYER, amount);
        vm.startPrank(BUYER);
        tok.approve(address(escrow), amount);
        escrow.fund(dealId, SELLER, address(tok), amount, address(v), address(v).codehash, binding);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- T-1, T-9 ----

    /// T-1 — a TIP-20-funded deal releases to the seller on the REPRODUCED proof.
    /// T-9 — at six decimals, which is the unit the token is most likely to use. The
    ///       decimals of the testnet TIP-20 are NOT established (011 §2.4), so the escrow is
    ///       exercised at both and neither is assumed.
    function test_TEMPO01_tip20_deal_releases_to_seller_on_a_reproduced_solana_proof() public {
        uint256 amount = 250_000000; // 250.00 at 6 decimals
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 6);
        assertEq(f.outcome, 0, "fixture must be REPRODUCED");

        bytes32 dealId = keccak256("tempo/t1");
        _fund(escrow, tok, v, dealId, f.dealBinding, amount);
        assertEq(tok.balanceOf(address(escrow)), amount, "escrow holds the TIP-20");
        assertEq(tok.balanceOf(SELLER), 0, "seller starts empty");

        escrow.settleWithProof(dealId, f.publicValues, f.proof);

        assertEq(tok.balanceOf(SELLER), amount, "seller was paid by a Solana proof");
        assertEq(tok.balanceOf(address(escrow)), 0, "escrow emptied exactly once");
        assertEq(tok.balanceOf(BUYER), 0, "buyer was not refunded");
    }

    /// T-9 — the same deal at eighteen decimals.
    function test_TEMPO09_the_escrow_settles_identically_at_18_decimals() public {
        uint256 amount = 250e18;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 18);

        bytes32 dealId = keccak256("tempo/t9");
        _fund(escrow, tok, v, dealId, f.dealBinding, amount);
        escrow.settleWithProof(dealId, f.publicValues, f.proof);

        assertEq(tok.decimals(), 18, "the mock really is at 18");
        assertEq(tok.balanceOf(SELLER), amount, "seller paid in full at 18 decimals");
    }

    // ---------------------------------------------------------------- T-2 ----

    /// T-2 — the refund direction, and it is a PROOF-driven refund, not the 30-day timeout.
    /// The distinction matters: `REFUND_AFTER` is 30 days and the CWF judging window is 28,
    /// so a deadline refund cannot be shown on a public chain inside the event (011 §7.1).
    /// This one is immediate, and it is the one the demo shows.
    function test_TEMPO02_tip20_deal_refunds_the_buyer_on_a_failed_solana_proof() public {
        uint256 amount = 100_000000;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(FAILED, 6);
        assertEq(f.outcome, 1, "fixture must be FAILED");

        bytes32 dealId = keccak256("tempo/t2");
        _fund(escrow, tok, v, dealId, f.dealBinding, amount);

        escrow.settleWithProof(dealId, f.publicValues, f.proof);

        assertEq(tok.balanceOf(BUYER), amount, "buyer got the money back on a failed replay");
        assertEq(tok.balanceOf(SELLER), 0, "seller was not paid");
        assertEq(tok.balanceOf(address(escrow)), 0, "escrow emptied exactly once");
    }

    // ---------------------------------------------------------------- T-3 ----

    /// T-3 — the money shot, in TIP-20. A REAL Groth16 proof, of a REAL execution, that
    /// verifies — and is simply not about this deal. It is refused and nothing moves.
    function test_TEMPO03_a_real_proof_of_another_execution_moves_no_tip20() public {
        uint256 amount = 250_000000;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 6);

        // Fund against a DIFFERENT binding than the proof commits to. Everything else about
        // the proof is genuine.
        bytes32 other = keccak256(abi.encodePacked(f.dealBinding, "not this deal"));
        assertTrue(other != f.dealBinding, "the two bindings must differ");

        bytes32 dealId = keccak256("tempo/t3");
        _fund(escrow, tok, v, dealId, other, amount);

        vm.expectRevert(RecknZkEscrow.BindingMismatch.selector);
        escrow.settleWithProof(dealId, f.publicValues, f.proof);

        assertEq(tok.balanceOf(address(escrow)), amount, "the money did not move");
        assertEq(tok.balanceOf(SELLER), 0, "the seller was not paid");
    }

    // ---------------------------------------------------------------- T-7 ----

    /// T-7 — a paused TIP-20 stops a payout that a valid proof authorised. The deal stays
    /// `Funded`. This is not a defect in the escrow; it is the trust boundary 011 §8
    /// discloses, demonstrated rather than described.
    function test_TEMPO07_a_paused_token_blocks_a_proof_authorised_release() public {
        uint256 amount = 250_000000;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 6);

        bytes32 dealId = keccak256("tempo/t7");
        _fund(escrow, tok, v, dealId, f.dealBinding, amount);

        tok.setPaused(true);
        vm.expectRevert(MockTIP20.TokenPaused.selector);
        escrow.settleWithProof(dealId, f.publicValues, f.proof);

        assertEq(tok.balanceOf(address(escrow)), amount, "the money is still held");
        assertEq(tok.balanceOf(SELLER), 0, "the seller was not paid");

        // And the sharper half: the timeout is closed too. Warp past REFUND_AFTER and the
        // permissionless refund ALSO reverts while the token is paused. On Arc the blacklist
        // froze one named address and the timeout still worked; on Tempo a pause reaches
        // both exits at once, and that is strictly worse.
        vm.warp(block.timestamp + escrow.REFUND_AFTER() + 1);
        vm.expectRevert(MockTIP20.TokenPaused.selector);
        escrow.refundAfterDeadline(dealId);

        // Unpause and the same call succeeds, so the money was never lost — only held by a
        // third party's decision.
        tok.setPaused(false);
        escrow.refundAfterDeadline(dealId);
        assertEq(tok.balanceOf(BUYER), amount, "the buyer got it back once the pause lifted");
    }

    // ---------------------------------------------------------------- T-8 ----

    /// T-8 — a TIP-403 policy refusing the SELLER blocks the release, the deal stays
    /// `Funded`, and the timeout is the only exit. Unlike the pause, a policy aimed at the
    /// seller leaves the buyer's refund path open — which is exactly the Arc blacklist shape
    /// and exactly what `refundAfterDeadline` was written for.
    function test_TEMPO08_a_transfer_policy_refusing_the_seller_leaves_the_refund_open() public {
        uint256 amount = 250_000000;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 6);

        bytes32 dealId = keccak256("tempo/t8");
        _fund(escrow, tok, v, dealId, f.dealBinding, amount);

        tok.setPolicyForbids(SELLER, true);
        vm.expectRevert(abi.encodeWithSelector(MockTIP20.PolicyForbids.selector, SELLER));
        escrow.settleWithProof(dealId, f.publicValues, f.proof);
        assertEq(tok.balanceOf(address(escrow)), amount, "still held");

        vm.warp(block.timestamp + escrow.REFUND_AFTER() + 1);
        // Permissionless: a stranger calls it, and earns nothing for doing so.
        vm.prank(address(0xDEAD));
        escrow.refundAfterDeadline(dealId);
        assertEq(tok.balanceOf(BUYER), amount, "the buyer's exit was open");
        assertEq(tok.balanceOf(address(0xDEAD)), 0, "the caller was paid nothing");
    }

    // ---------------------------------------------------------------- T-10 ----

    /// T-10 — the escrow does not read a memo and cannot be steered by one. A memo is data
    /// the issuer can also write; if settlement turned on it, that would be a lever handed
    /// to a third party. This test exists so "we do not use memos" is checked, not asserted.
    function test_TEMPO10_a_token_memo_changes_no_settlement_outcome() public {
        uint256 amount = 250_000000;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 6);

        bytes32 dealId = keccak256("tempo/t10");
        tok.mint(BUYER, amount);
        vm.startPrank(BUYER);
        tok.approve(address(escrow), amount);
        escrow.fund(dealId, SELLER, address(tok), amount, address(v), address(v).codehash, f.dealBinding);
        vm.stopPrank();

        // Someone writes a memo at the token, claiming whatever they like about the deal.
        tok.mint(address(0xCAFE), 1);
        vm.prank(address(0xCAFE));
        tok.transferWithMemo(BUYER, 1, keccak256("release to me"));

        escrow.settleWithProof(dealId, f.publicValues, f.proof);
        assertEq(tok.balanceOf(SELLER), amount, "the proof decided it, not the memo");
    }

    // ---------------------------------------------------------------- InvalidRecipient ----

    /// TIP-20 refuses a transfer whose recipient is another TIP-20. A deal whose seller is a
    /// TIP-20 address is therefore unsettleable — recorded here because it is a way to fund
    /// a deal that can never release, and the buyer should know the timeout is their exit.
    function test_TEMPO11_a_deal_whose_seller_is_a_tip20_can_only_ever_time_out() public {
        uint256 amount = 250_000000;
        (Fx memory f, RecknZkEscrow escrow, RecknVerdictVerifier v, MockTIP20 tok) = _rig(REPRO, 6);
        MockTIP20 otherToken = new MockTIP20("Other USD", "otherUSD", 6);
        tok.setIsTip20(address(otherToken), true);

        bytes32 dealId = keccak256("tempo/t11");
        tok.mint(BUYER, amount);
        vm.startPrank(BUYER);
        tok.approve(address(escrow), amount);
        escrow.fund(
            dealId, address(otherToken), address(tok), amount, address(v), address(v).codehash, f.dealBinding
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(MockTIP20.InvalidRecipient.selector, address(otherToken)));
        escrow.settleWithProof(dealId, f.publicValues, f.proof);

        vm.warp(block.timestamp + escrow.REFUND_AFTER() + 1);
        escrow.refundAfterDeadline(dealId);
        assertEq(tok.balanceOf(BUYER), amount, "the timeout is the only exit, and it works");
    }
}

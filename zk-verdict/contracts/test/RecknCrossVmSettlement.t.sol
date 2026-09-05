// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// A sham adjudicator: `view`, ignores its arguments, always reproduces. It exists to
/// prove the escrow dispatches to the deal's OWN verifier — and, read the other way,
/// it is the capability 009 hands the funder. A funder who names this has defrauded
/// nobody but themselves; the proof, checked by the program the funder chose, is what
/// chooses the payout.
contract AlwaysReproduces {
    bytes32 public immutable binding;

    constructor(bytes32 b) {
        binding = b;
    }

    function verifyVerdict(bytes calldata, bytes calldata)
        external
        view
        returns (VerdictPublicValues memory v)
    {
        v.outcome = 0;
        v.traceHash = bytes32(0);
        v.dealBinding = binding;
    }
}

/// A counter the state-writing verifier bumps, so "did it write?" is observable.
contract Sink {
    uint256 public n;

    function bump() external {
        n += 1;
    }
}

/// The same selector as a real verifier, but NOT `view`: it writes, then returns a
/// record that would settle. Called through the escrow's `view` type it is a
/// STATICCALL and must revert; called through a non-`view` type it must succeed.
contract WritingVerifier {
    Sink public immutable sink;
    bytes32 public immutable binding;

    constructor(Sink s, bytes32 b) {
        sink = s;
        binding = b;
    }

    function verifyVerdict(bytes calldata, bytes calldata)
        external
        returns (VerdictPublicValues memory v)
    {
        sink.bump();
        v.outcome = 0;
        v.traceHash = bytes32(0);
        v.dealBinding = binding;
    }
}

interface IWritingVerifier {
    function verifyVerdict(bytes calldata, bytes calldata)
        external
        returns (VerdictPublicValues memory);
}

/// The negative control for AC-4: the same contract, reached through a non-`view`
/// type. Without this, AC-4 test 1 is satisfied by any implementation that reverts
/// for any reason at all.
contract NonViewCaller {
    function call(IWritingVerifier v) external returns (VerdictPublicValues memory) {
        return v.verifyVerdict(hex"", hex"");
    }
}

/// A real contract (so `fund` accepts its codehash) that returns a `Failed` record
/// bound to the deal. It says nothing about Solana; it says the Failed branch of the
/// widened contract still refunds.
contract MockVerdictVerifier {
    bytes32 public immutable binding;
    uint8 public immutable outcome;

    constructor(bytes32 b, uint8 o) {
        binding = b;
        outcome = o;
    }

    function verifyVerdict(bytes calldata, bytes calldata)
        external
        view
        returns (VerdictPublicValues memory v)
    {
        v.outcome = outcome;
        v.traceHash = bytes32(0);
        v.dealBinding = binding;
    }
}

/// 009 — one escrow, two virtual machines. The adjudicating program is named by the
/// funder per deal and pinned by codehash; `settleWithProof` has no parameter with
/// which a settler could name one.
///
/// Tier: `forge test` against SP1's real verifier with committed Groth16 proofs, on
/// one machine. Not a chain result, and nothing here may be described as one.
contract RecknCrossVmSettlementTest is Test {
    string constant EVM_FIXTURE = "src/fixtures/reexec-groth16-fixture.json";
    string constant SVM_FIXTURE = "src/fixtures/svm-groth16-fixture.json";

    address buyer = address(0xB0B);
    address seller = address(0x5E11E5);
    uint256 constant AMOUNT = 1_000e6;

    MockERC20 token;
    SP1Verifier sp1;

    struct Fixture {
        bytes32 vkey;
        bytes publicValues;
        bytes proof;
        bytes32 binding;
        uint256 outcome;
    }

    function setUp() public {
        token = new MockERC20();
        token.mint(buyer, 10 * AMOUNT);
        sp1 = new SP1Verifier();
    }

    function _read(string memory path) internal view returns (Fixture memory f) {
        require(vm.exists(path), "missing fixture -- a missing fixture is a hard failure");
        string memory json = vm.readFile(path);
        f.vkey = vm.parseJsonBytes32(json, ".vkey");
        f.publicValues = vm.parseJsonBytes(json, ".public_values");
        f.proof = vm.parseJsonBytes(json, ".proof");
        f.binding = vm.parseJsonBytes32(json, ".deal_binding");
        f.outcome = vm.parseJsonUint(json, ".outcome");
    }

    function _fund(RecknZkEscrow escrow, bytes32 dealId, address verifier, bytes32 binding) internal {
        vm.prank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        escrow.fund(dealId, seller, address(token), AMOUNT, verifier, verifier.codehash, binding);
    }

    function _state(RecknZkEscrow escrow, bytes32 dealId) internal view returns (RecknZkEscrow.State) {
        (,,,,,,, RecknZkEscrow.State st) = escrow.deals(dealId);
        return st;
    }

    // ---------------------------------------------------------------- AC-1 -----

    function test_AC01_one_escrow_settles_an_evm_proof_and_an_svm_proof() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);

        assertTrue(e.vkey != s.vkey, "two guests, two vkeys");
        assertTrue(e.binding != s.binding, "two executions, two bindings");
        assertTrue(keccak256(e.publicValues) != keccak256(s.publicValues), "public values differ");
        assertTrue(keccak256(e.proof) != keccak256(s.proof), "proofs differ");
        assertEq(e.outcome, 0, "evm fixture is Reproduced");
        assertEq(s.outcome, 0, "svm fixture is Reproduced");

        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        RecknVerdictVerifier vS = new RecknVerdictVerifier(address(sp1), s.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();

        bytes32 dealE = keccak256("E");
        bytes32 dealS = keccak256("S");
        _fund(escrow, dealE, address(vE), e.binding);
        _fund(escrow, dealS, address(vS), s.binding);

        escrow.settleWithProof(dealE, e.publicValues, e.proof);
        escrow.settleWithProof(dealS, s.publicValues, s.proof);

        assertEq(token.balanceOf(seller), 2 * AMOUNT, "both settlements paid the seller");
        assertEq(token.balanceOf(address(escrow)), 0, "one escrow, drained");
        assertTrue(_state(escrow, dealE) == RecknZkEscrow.State.Settled, "E settled");
        assertTrue(_state(escrow, dealS) == RecknZkEscrow.State.Settled, "S settled");
    }

    function test_AC01_settling_the_svm_deal_leaves_every_other_deal_untouched() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);

        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        RecknVerdictVerifier vS = new RecknVerdictVerifier(address(sp1), s.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();

        bytes32 dealE = keccak256("E");
        bytes32 dealS = keccak256("S");
        bytes32 dealU = keccak256("U");
        bytes32 unrelated = keccak256("unrelated");
        _fund(escrow, dealE, address(vE), e.binding);
        _fund(escrow, dealS, address(vS), s.binding);
        _fund(escrow, dealU, address(vS), unrelated);

        escrow.settleWithProof(dealS, s.publicValues, s.proof);

        assertTrue(_state(escrow, dealE) == RecknZkEscrow.State.Funded, "E untouched");
        assertTrue(_state(escrow, dealU) == RecknZkEscrow.State.Funded, "U untouched");
        assertEq(token.balanceOf(address(escrow)), 2 * AMOUNT, "the other two deals still funded");
        assertEq(token.balanceOf(seller), AMOUNT, "exactly one settlement paid");

        (,,,, address uVerifier, bytes32 uCodeHash, bytes32 uBinding,) = escrow.deals(dealU);
        assertEq(uVerifier, address(vS), "U's verifier unchanged");
        assertEq(uCodeHash, address(vS).codehash, "U's codehash unchanged");
        assertEq(uBinding, unrelated, "U's binding unchanged");
    }

    // ---------------------------------------------------------------- AC-2 -----

    function test_AC02_an_evm_proof_cannot_settle_the_svm_deal() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);
        RecknVerdictVerifier vS = new RecknVerdictVerifier(address(sp1), s.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 dealS = keccak256("S");
        _fund(escrow, dealS, address(vS), s.binding);

        vm.expectRevert();
        escrow.settleWithProof(dealS, e.publicValues, e.proof);

        assertTrue(_state(escrow, dealS) == RecknZkEscrow.State.Funded, "still funded");
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "nothing moved");
    }

    function test_AC02_an_svm_proof_cannot_settle_the_evm_deal() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);
        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 dealE = keccak256("E");
        _fund(escrow, dealE, address(vE), e.binding);

        vm.expectRevert();
        escrow.settleWithProof(dealE, s.publicValues, s.proof);

        assertTrue(_state(escrow, dealE) == RecknZkEscrow.State.Funded, "still funded");
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "nothing moved");
    }

    /// The proof VERIFIES here — it is the deal's own verifier — and the binding is
    /// what stops it. That separates the two barriers instead of letting one mask
    /// the other.
    function test_AC02_a_verifying_proof_with_the_wrong_binding_reverts_on_the_binding() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);
        RecknVerdictVerifier vS = new RecknVerdictVerifier(address(sp1), s.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 dealId = keccak256("S-with-evm-binding");
        _fund(escrow, dealId, address(vS), e.binding);

        vm.expectRevert(RecknZkEscrow.BindingMismatch.selector);
        escrow.settleWithProof(dealId, s.publicValues, s.proof);
    }

    function test_AC02_the_two_fixtures_are_not_the_same_artifact() public view {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);
        assertTrue(e.vkey != s.vkey, "vkeys differ");
        assertTrue(e.vkey != bytes32(0) && s.vkey != bytes32(0), "neither vkey is zero");
        assertTrue(e.binding != s.binding, "bindings differ");
        assertTrue(e.binding != bytes32(0) && s.binding != bytes32(0), "neither binding is zero");
        assertTrue(keccak256(e.publicValues) != keccak256(s.publicValues), "public values differ");
        assertTrue(keccak256(e.proof) != keccak256(s.proof), "proofs differ");
        assertEq(e.outcome, 0, "evm outcome");
        assertEq(s.outcome, 0, "svm outcome");
    }

    // ---------------------------------------------------------------- AC-3 -----

    function test_AC03_settle_with_proof_has_no_adjudicator_parameter() public {
        RecknZkEscrow escrow = new RecknZkEscrow();
        assertEq(
            escrow.settleWithProof.selector,
            bytes4(keccak256("settleWithProof(bytes32,bytes,bytes)")),
            "no adjudicator parameter exists to pass"
        );
        assertEq(
            escrow.fund.selector,
            bytes4(keccak256("fund(bytes32,address,address,uint256,address,bytes32,bytes32)")),
            "the funder names it, here"
        );
    }

    function test_AC03_the_escrow_dispatches_to_the_deal_s_verifier_and_to_nothing_else() public {
        Fixture memory e = _read(EVM_FIXTURE);
        bytes32 binding = keccak256("chosen");
        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        AlwaysReproduces sham = new AlwaysReproduces(binding);
        RecknZkEscrow escrow = new RecknZkEscrow();

        bytes32 dealA = keccak256("A");
        bytes32 dealB = keccak256("B");
        _fund(escrow, dealA, address(vE), binding);
        _fund(escrow, dealB, address(sham), binding);

        // A reaches the real verifier: garbage is not a proof.
        vm.expectRevert();
        escrow.settleWithProof(dealA, hex"00", hex"00");
        assertTrue(_state(escrow, dealA) == RecknZkEscrow.State.Funded, "A untouched");

        // B reaches the sham the funder chose, and it settles.
        escrow.settleWithProof(dealB, hex"00", hex"00");
        assertEq(token.balanceOf(seller), AMOUNT, "B settled through the deal's own verifier");
    }

    // ---------------------------------------------------------------- AC-4 -----

    function test_AC04_the_adjudication_call_cannot_write_state() public {
        bytes32 binding = keccak256("write");
        Sink sink = new Sink();
        WritingVerifier w = new WritingVerifier(sink, binding);
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 dealId = keccak256("W");
        _fund(escrow, dealId, address(w), binding);

        vm.expectRevert();
        escrow.settleWithProof(dealId, hex"", hex"");

        assertEq(sink.n(), 0, "the STATICCALL wrote nothing");
        assertTrue(_state(escrow, dealId) == RecknZkEscrow.State.Funded, "still funded");
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "nothing moved");
    }

    function test_AC04_the_same_verifier_writes_when_it_is_not_called_through_a_view_type() public {
        bytes32 binding = keccak256("write");
        Sink sink = new Sink();
        WritingVerifier w = new WritingVerifier(sink, binding);
        NonViewCaller caller = new NonViewCaller();

        caller.call(IWritingVerifier(address(w)));

        assertEq(sink.n(), 1, "the same contract writes when the type permits it");
    }

    // ---------------------------------------------------------------- AC-5 -----

    function test_AC05_fund_rejects_an_address_with_no_code() public {
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 binding = keccak256("b");

        address untouched = address(0xDEAD00);
        vm.prank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        vm.expectRevert(RecknZkEscrow.NoVerifierCode.selector);
        escrow.fund(keccak256("n1"), seller, address(token), AMOUNT, untouched, untouched.codehash, binding);

        address eoa = address(0xE0A);
        vm.deal(eoa, 1 ether);
        vm.prank(buyer);
        vm.expectRevert(RecknZkEscrow.NoVerifierCode.selector);
        escrow.fund(keccak256("n2"), seller, address(token), AMOUNT, eoa, eoa.codehash, binding);

        assertEq(token.balanceOf(address(escrow)), 0, "nothing was pulled");
    }

    function test_AC05_fund_rejects_a_codehash_that_is_not_the_named_verifier_s() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);
        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        MockVerdictVerifier other = new MockVerdictVerifier(s.binding, 0);
        RecknZkEscrow escrow = new RecknZkEscrow();

        vm.prank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        vm.expectRevert(RecknZkEscrow.VerifierMismatch.selector);
        escrow.fund(
            keccak256("mismatch"), seller, address(token), AMOUNT,
            address(vE), address(other).codehash, e.binding
        );

        assertEq(token.balanceOf(address(escrow)), 0, "nothing was pulled");
        assertEq(token.balanceOf(buyer), 10 * AMOUNT, "the buyer still holds everything");
    }

    function test_AC05_fund_still_rejects_a_zero_binding() public {
        Fixture memory e = _read(EVM_FIXTURE);
        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();

        vm.prank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        vm.expectRevert(RecknZkEscrow.ZeroBinding.selector);
        escrow.fund(
            keccak256("zero"), seller, address(token), AMOUNT,
            address(vE), address(vE).codehash, bytes32(0)
        );
    }

    // ---------------------------------------------------------------- AC-6 -----

    function test_AC06_the_svm_deal_cannot_be_settled_twice() public {
        Fixture memory s = _read(SVM_FIXTURE);
        RecknVerdictVerifier vS = new RecknVerdictVerifier(address(sp1), s.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 dealS = keccak256("S");
        _fund(escrow, dealS, address(vS), s.binding);

        escrow.settleWithProof(dealS, s.publicValues, s.proof);

        vm.expectRevert(RecknZkEscrow.BadState.selector);
        escrow.settleWithProof(dealS, s.publicValues, s.proof);

        assertEq(token.balanceOf(seller), AMOUNT, "paid exactly once");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained once");
    }

    /// A mock, so this says nothing about Solana. It says the Failed branch of the
    /// widened contract still refunds the buyer.
    function test_AC06_a_failed_verdict_on_an_svm_shaped_deal_refunds_the_buyer() public {
        bytes32 binding = keccak256("failed-deal");
        MockVerdictVerifier failing = new MockVerdictVerifier(binding, 1);
        RecknZkEscrow escrow = new RecknZkEscrow();
        bytes32 dealId = keccak256("F");
        _fund(escrow, dealId, address(failing), binding);

        escrow.settleWithProof(dealId, hex"", hex"");

        assertEq(token.balanceOf(buyer), 10 * AMOUNT, "buyer made whole");
        assertEq(token.balanceOf(seller), 0, "seller paid nothing");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    function test_AC06_no_token_is_created_or_destroyed_across_both_settlements() public {
        Fixture memory e = _read(EVM_FIXTURE);
        Fixture memory s = _read(SVM_FIXTURE);
        RecknVerdictVerifier vE = new RecknVerdictVerifier(address(sp1), e.vkey);
        RecknVerdictVerifier vS = new RecknVerdictVerifier(address(sp1), s.vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();

        uint256 supply0 = token.totalSupply();
        uint256 sum0 = token.balanceOf(buyer) + token.balanceOf(seller) + token.balanceOf(address(escrow));

        bytes32 dealE = keccak256("E");
        bytes32 dealS = keccak256("S");
        _fund(escrow, dealE, address(vE), e.binding);
        _fund(escrow, dealS, address(vS), s.binding);
        assertEq(token.totalSupply(), supply0, "supply unchanged after funding");
        assertEq(
            token.balanceOf(buyer) + token.balanceOf(seller) + token.balanceOf(address(escrow)),
            sum0,
            "conserved after funding"
        );

        escrow.settleWithProof(dealE, e.publicValues, e.proof);
        assertEq(
            token.balanceOf(buyer) + token.balanceOf(seller) + token.balanceOf(address(escrow)),
            sum0,
            "conserved after the EVM settlement"
        );

        escrow.settleWithProof(dealS, s.publicValues, s.proof);
        assertEq(token.totalSupply(), supply0, "supply unchanged at the end");
        assertEq(
            token.balanceOf(buyer) + token.balanceOf(seller) + token.balanceOf(address(escrow)),
            sum0,
            "conserved after both settlements"
        );
    }
}

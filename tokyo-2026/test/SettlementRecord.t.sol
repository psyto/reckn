// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "@zk/RecknZkEscrow.sol";
import {RecknVerdictVerifier} from "@zk/RecknVerdictVerifier.sol";
import {MockUSDC} from "@zktest/mocks/MockUSDC.sol";
import {SettlementRecord, IPermissionedResolver} from "../src/SettlementRecord.sol";

interface IEAC {
    function grantRootRoles(uint256 roleBitmap, address account) external returns (bool);
    function hasRoles(uint256 resource, uint256 roleBitmap, address account) external view returns (bool);
}

interface IResolverRead {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory, address);
}

/// `013` §5 — the rows the 2026-09-26 09:00 fallback decision reads.
///
/// **Against the real deployment, not mocks.** Everything but the deal itself is what was put on
/// Sepolia tonight: the escrow, the verdict verifier, our parent registry, our resolver instance,
/// and `agent.reckn.eth`. A row that passes here passes against the addresses the submission
/// names, which is the only version of passing that counts.
contract SettlementRecordTest is Test {
    // deployed 2026-09-25, recorded in zk-verdict/contracts/sepolia.json
    RecknZkEscrow constant ESCROW = RecknZkEscrow(0x6d6a9deb67d785BC131a5d732617EABE751098C5);
    address constant VERIFIER = 0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608;
    address constant RESOLVER = 0x740e02cE9FB52629feF861CA02DF7091f416BBF8;
    address constant UNIVERSAL_RESOLVER = 0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3;
    address constant DEPLOYER = 0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321; // holds root today
    uint256 constant ALL_ROLES = 0x1111111111111111111111111111111111111111111111111111111111111111;
    /// EACUnauthorizedAccountRoles(uint256,uint256,address) -- read off a real revert. A bare
    /// `vm.expectRevert()` would also be satisfied by the call reverting for the wrong reason,
    /// which is how a row passes while proving nothing.
    bytes4 constant EAC_UNAUTHORIZED = 0x4b27a133;

    string constant DIR = "../zk-verdict/contracts/";
    string constant PROOF_REPRODUCED = "src/fixtures/reexec-groth16-fixture.json";
    string constant PROOF_FAILED = "src/fixtures/reexec-falserelease-fixture.json";

    uint256 constant AMOUNT = 250_000000;

    SettlementRecord rec;
    MockUSDC usdc;
    address buyer = makeAddr("buyer");
    address agent = makeAddr("agent-the-seller");

    struct Proof {
        bytes publicValues;
        bytes proof;
        bytes32 binding;
        uint256 outcome;
    }

    function setUp() public {
        rec = new SettlementRecord(ESCROW, IPermissionedResolver(RESOLVER), _dns());
        usdc = new MockUSDC();
        usdc.mint(buyer, 10_000_000000);
        // The adapter needs the resolver's admin role. Today the deployer still holds root and
        // can hand it over; that is the residue 013 §1.1 discloses, and renouncing is what
        // closes it. The grant itself is the same call the real setup makes.
        vm.prank(DEPLOYER);
        IEAC(RESOLVER).grantRootRoles(ALL_ROLES, address(rec));
    }

    function _dns() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), "agent", uint8(5), "reckn", uint8(3), "eth", uint8(0));
    }

    function _proof(string memory path) internal view returns (Proof memory p) {
        string memory json = vm.readFile(string.concat(DIR, path));
        p.publicValues = vm.parseJsonBytes(json, ".public_values");
        p.proof = vm.parseJsonBytes(json, ".proof");
        p.binding = vm.parseJsonBytes32(json, ".deal_binding");
        p.outcome = vm.parseJsonUint(json, ".outcome");
    }

    /// Fund a deal on the REAL escrow, naming the REAL verifier, exactly as a buyer would.
    function _fund(Proof memory p, string memory tag) internal returns (bytes32 dealId) {
        dealId = keccak256(abi.encodePacked(tag, p.binding, block.number));
        vm.startPrank(buyer);
        usdc.approve(address(ESCROW), AMOUNT);
        ESCROW.fund(dealId, agent, address(usdc), AMOUNT, VERIFIER, VERIFIER.codehash, p.binding);
        vm.stopPrank();
    }

    function _settleByAStranger(bytes32 dealId, Proof memory p) internal {
        vm.prank(address(0xDEAD));
        ESCROW.settleWithProof(dealId, p.publicValues, p.proof);
    }

    // ---------------------------------------------------------------- the join, §4-10

    /// §4-10 — one path from a real settlement to a record that resolves through ENS.
    function test_join_settlement_opens_the_window_and_the_buyer_writes() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 dealId = _fund(p, "join");
        _settleByAStranger(dealId, p);

        (address writer, uint8 outcome) = rec.open(dealId, p.publicValues, p.proof);
        assertEq(writer, buyer, "the window opened for somebody other than the funder's buyer");
        assertEq(outcome, uint8(p.outcome), "the outcome did not come from the proof");

        string memory key = rec.recordKey(dealId);
        string memory value = rec.recordValue(outcome, uint64(block.number), VERIFIER);
        vm.prank(buyer);
        IPermissionedResolver(RESOLVER).setText(_dns(), key, value);

        // R-1: assert the RESOLVED value, not the write receipt, and go through ENS.
        (bytes memory out,) = IResolverRead(UNIVERSAL_RESOLVER).resolve(
            _dns(), abi.encodeWithSelector(bytes4(0x59d1d43c), _namehash(), key)
        );
        assertEq(abi.decode(out, (string)), value, "ENS did not resolve the record that was written");
    }

    // ---------------------------------------------------------------- R-2

    /// R-2 — the central row. The agent writes its own record and is refused.
    function test_R2_the_agent_cannot_write_its_own_record() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 dealId = _fund(p, "r2");
        _settleByAStranger(dealId, p);
        rec.open(dealId, p.publicValues, p.proof);

        // recordKey() first: an external call evaluated as an argument becomes "the next
        // call", eats the prank and the expectRevert, and the row passes for nothing.
        string memory key = rec.recordKey(dealId);
        bytes memory name = _dns();
        vm.prank(agent);
        vm.expectPartialRevert(EAC_UNAUTHORIZED);
        IPermissionedResolver(RESOLVER).setText(name, key, "reproduced");
    }

    // ---------------------------------------------------------------- R-12

    /// R-12 (first half) — the author is fixed, not chosen. The agent calling `open` on its own
    /// honestly settled deal opens the window for the BUYER, and still cannot write.
    function test_R12_the_agent_calling_open_still_cannot_write() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 dealId = _fund(p, "r12a");
        _settleByAStranger(dealId, p);

        vm.prank(agent);
        (address writer,) = rec.open(dealId, p.publicValues, p.proof);
        assertEq(writer, buyer, "calling open chose the writer");

        string memory key = rec.recordKey(dealId);
        bytes memory name = _dns();
        vm.prank(agent);
        vm.expectPartialRevert(EAC_UNAUTHORIZED);
        IPermissionedResolver(RESOLVER).setText(name, key, "reproduced");
    }

    /// R-12 (second half) — no second window, for anybody, ever.
    function test_R12_no_second_window() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 dealId = _fund(p, "r12b");
        _settleByAStranger(dealId, p);
        rec.open(dealId, p.publicValues, p.proof);

        vm.expectRevert(SettlementRecord.AlreadyOpened.selector);
        rec.open(dealId, p.publicValues, p.proof);
    }

    // ---------------------------------------------------------------- R-10

    /// R-10 — the outcome is not a caller argument. A stranger cannot turn a Reproduced deal
    /// into a Failed record, because the only way to open a window is to hand over a proof, and
    /// the proof for this deal says Reproduced.
    function test_R10_an_attacker_cannot_record_a_false_outcome() public {
        Proof memory good = _proof(PROOF_REPRODUCED);
        Proof memory bad = _proof(PROOF_FAILED);
        bytes32 dealId = _fund(good, "r10");
        _settleByAStranger(dealId, good);

        // the other fixture is a real, verifying proof -- of a DIFFERENT deal
        vm.prank(address(0xBAD));
        vm.expectRevert(SettlementRecord.BindingMismatch.selector);
        rec.open(dealId, bad.publicValues, bad.proof);
    }

    // ---------------------------------------------------------------- R-7

    /// R-7 — a Failed verdict writes a Failed record. Omission is a failure of this criterion.
    function test_R7_failed_is_recorded_as_failed() public {
        Proof memory p = _proof(PROOF_FAILED);
        bytes32 dealId = _fund(p, "r7");
        _settleByAStranger(dealId, p);

        (, uint8 outcome) = rec.open(dealId, p.publicValues, p.proof);
        assertEq(outcome, 1, "a failed verdict did not come back as failed");
        string memory value = rec.recordValue(outcome, uint64(block.number), VERIFIER);
        assertEq(_slice(value, 6), "failed", "the record does not say failed");
    }

    // ---------------------------------------------------------------- R-13

    /// R-13 — a timeout refund is not a settlement. With the control arm, so the row cannot
    /// pass by being broken.
    function test_R13_a_refund_is_not_recordable_and_the_control_arm_passes() public {
        Proof memory p = _proof(PROOF_REPRODUCED);

        // control arm: inside the window, the same proof DOES open
        bytes32 ok = _fund(p, "r13-control");
        _settleByAStranger(ok, p);
        rec.open(ok, p.publicValues, p.proof);

        // the row: fund, let the clock pass, refund, then try the same valid proof
        bytes32 late = _fund(p, "r13-late");
        vm.warp(block.timestamp + ESCROW.REFUND_AFTER() + 1);
        ESCROW.refundAfterDeadline(late);

        vm.expectRevert(SettlementRecord.RefundWindowPassed.selector);
        rec.open(late, p.publicValues, p.proof);
    }

    // ---------------------------------------------------------------- R-4

    /// R-4 — the window closes. The same party writing a second time is refused.
    function test_R4_the_window_closes_after_the_write() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 dealId = _fund(p, "r4");
        _settleByAStranger(dealId, p);
        rec.open(dealId, p.publicValues, p.proof);

        string memory key = rec.recordKey(dealId);
        vm.prank(buyer);
        IPermissionedResolver(RESOLVER).setText(_dns(), key, "reproduced");

        // the writer closes their own window at once; a stranger would have to wait
        // WRITE_WINDOW, which is what stops `close` being a griefing weapon (Grief.t.sol).
        vm.prank(buyer);
        rec.close(dealId);

        vm.prank(buyer);
        vm.expectPartialRevert(EAC_UNAUTHORIZED);
        IPermissionedResolver(RESOLVER).setText(_dns(), key, "reproduced twice");
    }

    // ---------------------------------------------------------------- R-8

    /// R-8 — the deal, not the caller, is the authority. A deal the escrow never settled has
    /// no record to open.
    function test_R8_an_unsettled_deal_has_no_window() public {
        Proof memory p = _proof(PROOF_REPRODUCED);
        bytes32 dealId = _fund(p, "r8"); // funded, never settled
        vm.expectRevert(SettlementRecord.NotSettled.selector);
        rec.open(dealId, p.publicValues, p.proof);
    }

    // ---------------------------------------------------------------- helpers

    function _namehash() internal pure returns (bytes32) {
        bytes32 n = bytes32(0);
        n = keccak256(abi.encodePacked(n, keccak256("eth")));
        n = keccak256(abi.encodePacked(n, keccak256("reckn")));
        n = keccak256(abi.encodePacked(n, keccak256("agent")));
        return n;
    }

    function _slice(string memory s, uint256 n) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory o = new bytes(n);
        for (uint256 i; i < n; ++i) o[i] = b[i];
        return string(o);
    }
}

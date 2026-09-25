// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "@zk/RecknZkEscrow.sol";
import {MockUSDC} from "@zktest/mocks/MockUSDC.sol";
import {SettlementRecord, IPermissionedResolver} from "../src/SettlementRecord.sol";

interface IEAC2 {
    function grantRootRoles(uint256, address) external returns (bool);
}

/// @title The window has to still be there when the buyer arrives.
///
/// **Why this file exists separately.** The nine rows in SettlementRecord.t.sol are all of the
/// form *this must not happen*. Not one of them is of the form *this must still work*, and a
/// contract can satisfy every prohibition by doing nothing at all. That gap was not theoretical:
/// `close` was permissionless with no further condition, and this file's first row — then named
/// `test_a_stranger_can_close_the_window_before_the_buyer_writes` — PASSED, i.e. the attack
/// worked. `open` is permissionless and the proof is public in the settling transaction's
/// calldata, so anybody could open a deal's one window and close it in the same block. Because
/// `opened[dealId]` never resets, the record was then unwritable by anyone, forever.
///
/// The rows below are the same scenario with the guard in place, and they are kept adversarial:
/// L-1 is the attack failing, **L-2 is the buyer still getting through afterwards**, and L-3 is
/// the other direction — the right still ends even if the buyer never shows up.
contract GriefTest is Test {
    RecknZkEscrow constant ESCROW = RecknZkEscrow(0x6d6a9deb67d785BC131a5d732617EABE751098C5);
    address constant VERIFIER = 0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608;
    address constant RESOLVER = 0x740e02cE9FB52629feF861CA02DF7091f416BBF8;
    address constant DEPLOYER = 0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321;
    uint256 constant ALL = 0x1111111111111111111111111111111111111111111111111111111111111111;

    SettlementRecord rec;
    MockUSDC usdc;
    address buyer = makeAddr("buyer");
    address agent = makeAddr("agent");
    address attacker = makeAddr("attacker");
    bytes pub;
    bytes prf;
    bytes32 binding;

    function setUp() public {
        rec = new SettlementRecord(ESCROW, IPermissionedResolver(RESOLVER));
        usdc = new MockUSDC();
        usdc.mint(buyer, 10_000_000000);
        vm.prank(DEPLOYER);
        IEAC2(RESOLVER).grantRootRoles(ALL, address(rec));
        string memory j = vm.readFile("../zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json");
        pub = vm.parseJsonBytes(j, ".public_values");
        prf = vm.parseJsonBytes(j, ".proof");
        binding = vm.parseJsonBytes32(j, ".deal_binding");
    }

    function _dns() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), "agent", uint8(5), "reckn", uint8(3), "eth", uint8(0));
    }

    /// A settled deal whose window a stranger has already opened. The stranger is not being
    /// unusual: `open` is meant to be callable by anybody, and the proof is public.
    function _settledAndOpenedByAStranger(string memory tag) internal returns (bytes32 id) {
        id = keccak256(abi.encodePacked(tag, block.number));
        vm.startPrank(buyer);
        usdc.approve(address(ESCROW), 250_000000);
        ESCROW.fund(id, agent, address(usdc), 250_000000, VERIFIER, VERIFIER.codehash, binding);
        vm.stopPrank();
        vm.prank(address(0xDEAD));
        ESCROW.settleWithProof(id, pub, prf);
        vm.prank(attacker);
        rec.open(id, _dns(), pub, prf);
    }

    // ---------------------------------------------------------------- L-1

    /// L-1 — the attack, now refused. This is the exact call that used to succeed.
    function test_L1_a_stranger_cannot_close_the_window_before_the_writer_has_used_it() public {
        bytes32 id = _settledAndOpenedByAStranger("grief");
        vm.prank(attacker);
        vm.expectRevert(SettlementRecord.NotYoursToCloseYet.selector);
        rec.close(id);
    }

    // ---------------------------------------------------------------- L-2

    /// L-2 — **the row the nine were missing.** Refusing the attacker is worth nothing unless the
    /// buyer then gets through. A stranger opens, a stranger tries to close and fails, and the
    /// buyer writes the record anyway.
    function test_L2_the_buyer_still_writes_after_a_stranger_attacks() public {
        bytes32 id = _settledAndOpenedByAStranger("grief-liveness");
        vm.prank(attacker);
        vm.expectRevert(SettlementRecord.NotYoursToCloseYet.selector);
        rec.close(id);

        string memory key = rec.recordKey(id);
        bytes memory name = _dns();
        vm.prank(buyer);
        IPermissionedResolver(RESOLVER).setText(name, key, "reproduced");

        // and the buyer closes their own window at once -- no waiting for the grace period
        vm.prank(buyer);
        rec.close(id);
        assertTrue(rec.closed(id), "the writer could not close their own window");
    }

    // ---------------------------------------------------------------- L-3

    /// L-3 — the other direction. `013` §3.3 wants a right that ENDS. A buyer who never appears
    /// must not leave a role standing forever, so after `WRITE_WINDOW` anybody may clean up.
    /// The control arm is L-1: one second earlier, the same call from the same address reverts.
    function test_L3_anybody_may_close_once_the_write_window_has_passed() public {
        bytes32 id = _settledAndOpenedByAStranger("grief-cleanup");

        vm.warp(block.timestamp + rec.WRITE_WINDOW() - 1);
        vm.prank(attacker);
        vm.expectRevert(SettlementRecord.NotYoursToCloseYet.selector);
        rec.close(id);

        vm.warp(block.timestamp + 1);
        vm.prank(attacker);
        rec.close(id);
        assertTrue(rec.closed(id), "the window never closes if the writer never appears");

        // and the standing role really is gone
        string memory key = rec.recordKey(id);
        bytes memory name = _dns();
        vm.prank(buyer);
        vm.expectRevert();
        IPermissionedResolver(RESOLVER).setText(name, key, "too late");
    }
}

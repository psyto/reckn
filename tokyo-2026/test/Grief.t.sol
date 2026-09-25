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
        rec = new SettlementRecord(ESCROW, IPermissionedResolver(RESOLVER), _dns());
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
        rec.open(id, pub, prf);
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

    // ---------------------------------------------------------------- L-4, L-5

    /// L-4 — **the scope of the grant, measured rather than claimed.** The submission used to
    /// say writes were "granted per record, not per name". They are not: the deployed resolver
    /// derives the resource from the KEY alone, so the buyer's role works on every name the
    /// resolver serves. This row asserts the uncomfortable half out loud, so nobody has to
    /// rediscover it, and L-5 asserts the half that makes it survivable.
    function test_L4_the_grant_is_NOT_scoped_to_the_name() public {
        bytes32 id = _settledAndOpenedByAStranger("scope");
        string memory key = rec.recordKey(id);
        bytes memory foreign = abi.encodePacked(uint8(6), "victim", uint8(5), "reckn", uint8(3), "eth", uint8(0));
        vm.prank(buyer);
        // not expectRevert: this SUCCEEDS, and that is the finding
        IPermissionedResolver(RESOLVER).setText(foreign, key, "reproduced");
    }

    /// L-5 — and why L-4 cannot be used to forge somebody else's history. The key the buyer
    /// holds names THIS adapter's name, and the adapter's name is fixed at construction rather
    /// than taken from the caller. So the bytes land on the foreign name under a key that says
    /// whose record it is, and the canonical lookup for the foreign name finds nothing.
    function test_L5_a_foreign_name_lookup_does_not_find_the_planted_record() public {
        bytes32 id = _settledAndOpenedByAStranger("scope-2");
        bytes memory foreign = abi.encodePacked(uint8(6), "victim", uint8(5), "reckn", uint8(3), "eth", uint8(0));
        // the key into a local FIRST: an external call in argument position becomes "the next
        // call" and eats the prank. That is not hypothetical here -- it failed this way once.
        string memory ourKey = rec.recordKey(id);
        vm.prank(buyer);
        IPermissionedResolver(RESOLVER).setText(foreign, ourKey, "reproduced");

        // what a reader of victim.reckn.eth would actually ask for
        string memory theirKey = string.concat("reckn:job:victim.reckn.eth:", _hex(id));
        assertTrue(
            keccak256(bytes(ourKey)) != keccak256(bytes(theirKey)),
            "the planted key is the victim's own key -- the name is not in the key"
        );

        // and the buyer cannot reach the victim's own key, because no adapter granted it
        vm.prank(buyer);
        vm.expectPartialRevert(bytes4(0x4b27a133));
        IPermissionedResolver(RESOLVER).setText(foreign, theirKey, "reproduced");
    }

    function _hex(bytes32 v) internal pure returns (string memory) {
        bytes memory s = new bytes(64);
        for (uint256 i; i < 32; ++i) {
            uint8 b = uint8(v[i]);
            s[i * 2] = bytes1((b >> 4) < 10 ? 48 + (b >> 4) : 87 + (b >> 4));
            s[i * 2 + 1] = bytes1((b & 15) < 10 ? 48 + (b & 15) : 87 + (b & 15));
        }
        return string(s);
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
        vm.expectPartialRevert(bytes4(0x4b27a133));
        IPermissionedResolver(RESOLVER).setText(name, key, "too late");
    }
}

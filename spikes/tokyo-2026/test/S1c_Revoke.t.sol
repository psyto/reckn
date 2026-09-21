// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MiniProxy, AdapterStub, IEAC, IResolverDeployed} from "./S1_EacFromContract.t.sol";

/// S1c — can the window be CLOSED? Needs the resource id the grant landed on.
/// DISPOSABLE.
contract S1c_Revoke is Test {
    address constant IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    uint256 constant ROLE_SET_TEXT = 1 << 4;

    bytes n = hex"056167656e74076578616d706c650365746800";
    address client = address(0xBEEF);

    AdapterStub a;
    IResolverDeployed r;
    IEAC eac;

    function namehash() internal pure returns (bytes32 node) {
        node = bytes32(0);
        node = keccak256(abi.encodePacked(node, keccak256("eth")));
        node = keccak256(abi.encodePacked(node, keccak256("example")));
        node = keccak256(abi.encodePacked(node, keccak256("agent")));
    }

    function setUp() public {
        address inst = address(new MiniProxy(IMPL));
        r = IResolverDeployed(inst);
        eac = IEAC(inst);
        a = new AdapterStub(inst);
        IResolverDeployed.RoleAssignment[] memory admins =
            new IResolverDeployed.RoleAssignment[](1);
        admins[0] = IResolverDeployed.RoleAssignment(address(a), ALL_ROLES);
        r.initialize(admins, new bytes[](0));
    }

    function setter(string memory key) internal view returns (bytes memory) {
        return abi.encodeWithSelector(IResolverDeployed.setText.selector, n, key, "");
    }

    /// How is the resource derived? Probe every candidate against the one we can observe.
    function test_find_the_resource() public {
        a.openSetterWindow(setter("job:1"), client);

        // observed by making an unauthorized call and reading the error's resource field
        uint256 observed;
        vm.prank(address(0xDEAD));
        try r.setText(n, "job:1", "x") {}
        catch (bytes memory err) {
            assembly { observed := mload(add(err, 0x24)) }
        }
        emit log_named_uint("resource in EACUnauthorized (job:1)", observed);
        assertTrue(eac.hasRoles(observed, ROLE_SET_TEXT, client), "client role not on that resource");

        emit log_named_uint("getRecordId(namehash)", r.getRecordId(namehash()));
        emit log_named_uint("getRecordId(keccak(dnsname))", r.getRecordId(keccak256(n)));
        emit log_named_uint("getRecordCount", r.getRecordCount());
        emit log_named_uint("keccak(node,partHash(text-key))",
            uint256(keccak256(abi.encode(namehash(), keccak256(bytes("job:1"))))));
    }

    /// The window closes — the whole point of §3.3.
    function test_revoke_closes_the_window() public {
        a.openSetterWindow(setter("job:1"), client);

        uint256 res;
        vm.prank(address(0xDEAD));
        try r.setText(n, "job:1", "x") {} catch (bytes memory err) {
            assembly { res := mload(add(err, 0x24)) }
        }

        vm.prank(client);
        r.setText(n, "job:1", "Reproduced");
        emit log("client wrote inside the window");

        a.revoke(res, ROLE_SET_TEXT, client);
        emit log("adapter revoked");

        vm.prank(client);
        try r.setText(n, "job:1", "second write") {
            emit log("!! WINDOW DID NOT CLOSE");
            fail();
        } catch {
            emit log("window closed: second write REFUSED");
        }
    }

    /// The assignee cap, and whether revoke frees a slot.
    function test_cap_and_slot_reuse() public {
        a.openSetterWindow(setter("job:cap"), client);
        uint256 res;
        vm.prank(address(0xDEAD));
        try r.setText(n, "job:cap", "x") {} catch (bytes memory err) {
            assembly { res := mload(add(err, 0x24)) }
        }

        uint256 extra;
        for (uint256 i = 0; i < 25; i++) {
            try a.grant(res, ROLE_SET_TEXT, address(uint160(0x2000 + i))) { extra++; }
            catch { emit log_named_uint("grant reverted at extra #", i + 1); break; }
        }
        emit log_named_uint("extra assignees granted", extra);
        emit log_named_uint("assigneeCount", eac.getAssigneeCount(res, ROLE_SET_TEXT));

        a.revoke(res, ROLE_SET_TEXT, address(uint160(0x2000)));
        try a.grant(res, ROLE_SET_TEXT, address(0xCAFE)) { emit log("revoke frees a slot: YES"); }
        catch { emit log("revoke frees a slot: NO"); }
    }
}

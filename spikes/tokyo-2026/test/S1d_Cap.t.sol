// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MiniProxy, AdapterStub, IEAC, IResolverDeployed} from "./S1_EacFromContract.t.sol";

interface IDecode {
    function decodeSetter(bytes calldata setter) external view returns (uint256, uint256);
}

contract S1d_Cap is Test {
    address constant IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    uint256 constant ROLE_SET_TEXT = 1 << 4;
    bytes n = hex"056167656e74076578616d706c650365746800";

    AdapterStub a; IResolverDeployed r; IEAC eac;

    function setUp() public {
        address inst = address(new MiniProxy(IMPL));
        r = IResolverDeployed(inst); eac = IEAC(inst); a = new AdapterStub(inst);
        IResolverDeployed.RoleAssignment[] memory admins = new IResolverDeployed.RoleAssignment[](1);
        admins[0] = IResolverDeployed.RoleAssignment(address(a), ALL_ROLES);
        r.initialize(admins, new bytes[](0));
    }

    function setter(string memory k) internal view returns (bytes memory) {
        return abi.encodeWithSelector(IResolverDeployed.setText.selector, n, k, "");
    }

    function test_decodeSetter_gives_the_resource() public {
        (bool ok, bytes memory out) = address(r).staticcall(
            abi.encodeWithSelector(IDecode.decodeSetter.selector, setter("job:1"))
        );
        emit log_named_string("decodeSetter callable", ok ? "YES" : "NO");
        emit log_named_bytes("decodeSetter returns", out);
    }

    function test_why_does_grant_revert() public {
        a.openSetterWindow(setter("job:cap"), address(0xBEEF));
        uint256 res;
        vm.prank(address(0xDEAD));
        try r.setText(n, "job:cap", "x") {} catch (bytes memory e) {
            assembly { res := mload(add(e, 0x24)) }
        }
        emit log_named_uint("resource", res);
        emit log_named_uint("assigneeCount(res, ROLE_SET_TEXT)", eac.getAssigneeCount(res, ROLE_SET_TEXT));
        emit log_named_uint("roleCount(res)", eac.roleCount(res));
        emit log_named_uint("roles(res, BEEF)", eac.roles(res, address(0xBEEF)));
        emit log_named_uint("roles(res, adapter)", eac.roles(res, address(a)));

        vm.prank(address(a));
        try eac.grantRoles(res, ROLE_SET_TEXT, address(0x2001)) {
            emit log("second grant on same resource: OK");
        } catch (bytes memory e) {
            emit log_named_bytes("second grant revert", e);
        }
    }
}

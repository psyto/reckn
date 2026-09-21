// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MiniProxy, AdapterStub, IEAC, IResolverDeployed} from "./S1_EacFromContract.t.sol";

contract S1b_Diag is Test {
    address constant IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    bytes n = hex"056167656e74076578616d706c650365746800";

    function test_diag() public {
        address inst = address(new MiniProxy(IMPL));
        AdapterStub a = new AdapterStub(inst);
        IResolverDeployed r = IResolverDeployed(inst);
        IResolverDeployed.RoleAssignment[] memory admins =
            new IResolverDeployed.RoleAssignment[](1);
        admins[0] = IResolverDeployed.RoleAssignment(address(a), ALL_ROLES);
        r.initialize(admins, new bytes[](0));

        // the first arg is SETTER CALLDATA, not a name (UnsupportedResolverProfile proved it)
        bytes memory setter = abi.encodeWithSelector(
            IResolverDeployed.setText.selector, n, "job:1", ""
        );
        address client = address(0xBEEF);
        address agent = address(0xA9E7);
        try a.openSetterWindow(setter, client) {
            emit log("grantSetterRoles(setterCalldata, client): OK");
        } catch (bytes memory err) {
            emit log_named_bytes("grantSetterRoles revert", err);
        }

        vm.prank(client);
        try r.setText(n, "job:1", "Reproduced") {
            emit log("client setText after grant: OK");
        } catch (bytes memory err) {
            emit log_named_bytes("client setText revert", err);
        }

        vm.prank(agent);
        try r.setText(n, "job:1", "agent wrote this") {
            emit log("!! AGENT setText: OK  <-- claim would be dead");
        } catch (bytes memory err) {
            emit log_named_bytes("agent setText revert (expected EACUnauthorized)", err);
        }

        vm.prank(client);
        try r.setText(n, "other:key", "different record") {
            emit log("!! client wrote a DIFFERENT record  <-- granularity is per-name, not per-record");
        } catch (bytes memory err) {
            emit log_named_bytes("client on other record: refused", err);
        }

        try r.setText(n, "k", "v") {
            emit log("setText as test-contract OK (it holds no role)");
        } catch (bytes memory err) {
            emit log_named_bytes("setText revert", err);
        }

        emit log_named_uint("getRecordId(keccak(name))", r.getRecordId(keccak256(n)));
        emit log_named_uint("getRecordCount", r.getRecordCount());

        vm.prank(address(a));
        try r.setText(n, "k", "v") {
            emit log("setText as adapter (root admin): OK");
        } catch (bytes memory err) {
            emit log_named_bytes("setText as adapter revert", err);
        }
    }
}

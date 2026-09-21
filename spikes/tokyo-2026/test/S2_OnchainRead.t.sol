// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MiniProxy, AdapterStub, IEAC, IResolverDeployed} from "./S1_EacFromContract.t.sol";

/// S2 — can a CONTRACT (a v4 hook, in the real design) read the record on chain?
/// If resolution needs CCIP-Read, a hook cannot gate on it. DISPOSABLE.
contract S2_OnchainRead is Test {
    address constant IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;
    address constant UNIVERSAL_RESOLVER_V2 = 0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3;
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    bytes n = hex"056167656e74076578616d706c650365746800";
    address client = address(0xBEEF);

    AdapterStub a; IResolverDeployed r; IEAC eac;

    function namehash() internal pure returns (bytes32 node) {
        node = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        node = keccak256(abi.encodePacked(node, keccak256("example")));
        node = keccak256(abi.encodePacked(node, keccak256("agent")));
    }

    function setUp() public {
        address inst = address(new MiniProxy(IMPL));
        r = IResolverDeployed(inst); eac = IEAC(inst); a = new AdapterStub(inst);
        IResolverDeployed.RoleAssignment[] memory ad = new IResolverDeployed.RoleAssignment[](1);
        ad[0] = IResolverDeployed.RoleAssignment(address(a), ALL_ROLES);
        r.initialize(ad, new bytes[](0));

        bytes memory setter =
            abi.encodeWithSelector(IResolverDeployed.setText.selector, n, "reckn:jobs", "");
        a.openSetterWindow(setter, client);
        vm.prank(client);
        r.setText(n, "reckn:jobs", "1");
    }

    /// The hook's actual call: resolve(name, text(node,key)) straight at the resolver.
    function test_hook_can_read_the_record_onchain() public {
        bytes memory inner =
            abi.encodeWithSelector(bytes4(0x59d1d43c), namehash(), "reckn:jobs"); // text(bytes32,string)
        (bool ok, bytes memory out) = address(r).staticcall(
            abi.encodeWithSelector(IResolverDeployed.resolve.selector, n, inner)
        );
        emit log_named_string("resolve() at the resolver", ok ? "OK" : "REVERT");
        emit log_named_bytes("returned", out);
        if (ok) {
            bytes memory unwrapped = abi.decode(out, (bytes));
            emit log_named_string("text value", abi.decode(unwrapped, (string)));
        }
    }

    /// Through UniversalResolverV2 — this is where CCIP-Read (OffchainLookup) would appear.
    function test_universal_resolver_path() public {
        bytes memory inner = abi.encodeWithSelector(bytes4(0x59d1d43c), namehash(), "reckn:jobs");
        (bool ok, bytes memory out) = UNIVERSAL_RESOLVER_V2.staticcall(
            abi.encodeWithSelector(IResolverDeployed.resolve.selector, n, inner)
        );
        emit log_named_string("UniversalResolverV2.resolve", ok ? "OK" : "REVERT");
        if (!ok && out.length >= 4) {
            bytes4 sel; assembly { sel := mload(add(out, 0x20)) }
            emit log_named_bytes32("revert selector", bytes32(sel));
            // OffchainLookup(address,string[],bytes,bytes4,bytes) = 0x556f1830
        }
    }
}

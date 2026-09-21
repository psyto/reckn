// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

/// S1 — Can a CONTRACT hold the admin role on the ENSv2 Permissioned Resolver and open/close a
/// write window for someone else? Runs against the REAL Sepolia bytecode.
///
/// ★ The ABI below is the DEPLOYED one, recovered from the bytecode's selectors (openchain
///   lookup, 2026-09-21) — NOT the one in `ensdomains + contracts-v2 (main branch)`. They differ:
///     main:     initialize(address admin, uint256 roleBitmap, bytes[] setters)
///               setText(bytes32 node, string key, string value)
///     deployed: initialize((address,uint256)[] admins, bytes[] setters)
///               setText(bytes name, string key, string value)   // DNS-encoded name
///   Spec 013 was written against the main-branch shape. This is the finding.
///
/// ★ Three tests were REMOVED from this file after measurement: they called
///   `grantSetterRoles(name, account)`, which is the wrong argument shape (S1b showed the first
///   argument is the setter's calldata). `S1c` and `S1d` replaced them against the real API.
///   They are deleted rather than left red, so that nothing in this directory is a failure
///   whose reason has been forgotten.
///
/// DISPOSABLE. Not ported.

interface IEAC {
    function grantRoles(uint256 resource, uint256 roleBitmap, address account)
        external
        returns (bool);
    function revokeRoles(uint256 resource, uint256 roleBitmap, address account)
        external
        returns (bool);
    function grantRootRoles(uint256 roleBitmap, address account) external returns (bool);
    function revokeRootRoles(uint256 roleBitmap, address account) external returns (bool);
    function hasRoles(uint256 resource, uint256 roleBitmap, address account)
        external
        view
        returns (bool);
    function hasRootRoles(uint256 roleBitmap, address account) external view returns (bool);
    function roles(uint256 resource, address account) external view returns (uint256);
    function roleCount(uint256 resource) external view returns (uint256);
    function getAssigneeCount(uint256 resource, uint256 role) external view returns (uint256);
    function ROOT_RESOURCE() external view returns (uint256);
}

interface IResolverDeployed {
    struct RoleAssignment {
        address account;
        uint256 roleBitmap;
    }

    function initialize(RoleAssignment[] calldata admins, bytes[] calldata setters) external;
    function grantSetterRoles(bytes calldata name, address account) external;
    function setText(bytes calldata name, string calldata key, string calldata value) external;
    function getRecordId(bytes32 node) external view returns (uint256);
    function getRecordCount() external view returns (uint256);
    function linkToNode(bytes calldata name, bytes32 node) external;
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory);
}

/// @dev Minimal ERC-1967 proxy. An EIP-1167 clone does NOT work: the implementation is UUPS and
///      `onlyProxy` reads the ERC-1967 slot, which a clone leaves empty. The real path is the
///      `VerifiableFactory`; this stands in so the spike needs no factory permissions.
contract MiniProxy {
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address impl) {
        assembly {
            sstore(_IMPL_SLOT, impl)
        }
    }

    fallback() external payable {
        assembly {
            let impl := sload(_IMPL_SLOT)
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @dev Stands in for the record adapter of spec 013 §3.4: a CONTRACT holding the admin role,
///      opening a window for a fixed recipient. No discretion, no outcome parameter.
contract AdapterStub {
    IEAC public immutable eac;
    IResolverDeployed public immutable resolver;

    constructor(address r) {
        eac = IEAC(r);
        resolver = IResolverDeployed(r);
    }

    function openSetterWindow(bytes calldata name, address to) external {
        resolver.grantSetterRoles(name, to);
    }

    function grant(uint256 resource, uint256 role, address to) external {
        eac.grantRoles(resource, role, to);
    }

    function revoke(uint256 resource, uint256 role, address to) external {
        eac.revokeRoles(resource, role, to);
    }
}

contract S1_EacFromContract is Test {
    // Sepolia ENSv2 beta (docs.ens.domains/learn/deployments, read 2026-09-21)
    address constant PERMISSIONED_RESOLVER_IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;

    uint256 constant ROLE_SET_TEXT = 1 << 4;
    uint256 constant ROLE_SET_TEXT_ADMIN = ROLE_SET_TEXT << 128;
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;

    address agent = makeAddr("agent");
    address client = makeAddr("client");
    address other = makeAddr("other");

    // DNS-encoded "agent.example.eth"
    bytes name = hex"056167656e74076578616d706c650365746800";

    AdapterStub adapter;
    IResolverDeployed resolver;
    IEAC eac;

    function setUp() public {
        address inst = address(new MiniProxy(PERMISSIONED_RESOLVER_IMPL));
        resolver = IResolverDeployed(inst);
        eac = IEAC(inst);
        adapter = new AdapterStub(inst);

        IResolverDeployed.RoleAssignment[] memory admins =
            new IResolverDeployed.RoleAssignment[](1);
        admins[0] = IResolverDeployed.RoleAssignment(address(adapter), ALL_ROLES);
        bytes[] memory none = new bytes[](0);
        resolver.initialize(admins, none);
    }

    /// Q1 — a contract holds the admin role.
    function test_Q1_contract_holds_admin_role() public {
        uint256 rootRes = eac.ROOT_RESOURCE();
        emit log_named_uint("ROOT_RESOURCE", rootRes);
        emit log_named_uint("adapter roles @root", eac.roles(rootRes, address(adapter)));
        assertTrue(
            eac.hasRootRoles(ROLE_SET_TEXT_ADMIN, address(adapter)),
            "a contract cannot hold the admin role"
        );
    }


    /// r2 finding: can root roles be renounced, or is the deployer a permanent key?
    function test_can_root_be_renounced() public {
        vm.prank(address(adapter));
        try eac.revokeRootRoles(ALL_ROLES, address(adapter)) {
            emit log("root roles renounced: YES");
            emit log_named_uint(
                "adapter roles @root after", eac.roles(eac.ROOT_RESOURCE(), address(adapter))
            );
        } catch {
            emit log("root roles renounced: NO (the deployer stays a key)");
        }
    }
}

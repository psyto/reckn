// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PermissionedRegistry} from "@ens/src/registry/PermissionedRegistry.sol";
import {IRegistry} from "@ens/src/registry/interfaces/IRegistry.sol";
import {ILabelStore} from "@ens/src/utils/interfaces/ILabelStore.sol";
import {RegistryRolesLib} from "@ens/src/registry/libraries/RegistryRolesLib.sol";
import {EACBaseRolesLib} from "@ens/src/access-control/libraries/EACBaseRolesLib.sol";
import {MiniProxy, AdapterStub, IResolverDeployed} from "./S1_EacFromContract.t.sol";

/// S7 — the ENS prize requirements, not the mechanism:
///   "Project must be built on ENSv2 (Sepolia)"
///   "Your demo must be functional and not just include hard-coded values"
///   (Continuity) "target an existing project's testnet deployment"
///
/// Everything measured so far used a stand-in name that is not registered and a resolver reached
/// directly. **A judge will resolve through ENS.** This registers a real name on the real Sepolia
/// ETHRegistrar, hangs our own registry under it, and asks UniversalResolverV2 for the record.
///
/// DISPOSABLE. Not ported.

interface IETHRegistrar {
    function makeCommitment(
        string calldata label,
        address owner,
        bytes32 secret,
        IRegistry subregistry,
        address resolver,
        uint64 duration,
        bytes32 referrer
    ) external pure returns (bytes32);

    function commit(bytes32 commitment) external;

    function register(
        string calldata label,
        address owner,
        bytes32 secret,
        IRegistry subregistry,
        address resolver,
        uint64 duration,
        address paymentToken,
        bytes32 referrer
    ) external returns (uint256);

    function MIN_COMMITMENT_AGE() external view returns (uint64);
    function MIN_REGISTER_DURATION() external view returns (uint64);
    function isAvailable(string calldata label) external view returns (bool);
    function getRegisterPrice(string calldata label, uint64 duration, address paymentToken)
        external
        view
        returns (uint256, uint256);
}

interface IERC20Like {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IUniversalResolver {
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory, address);
}

contract MockLabelStore2 is ILabelStore {
    function setLabel(string calldata label) external {
        emit Label(keccak256(bytes(label)), label);
    }

    function getLabel(uint256) external pure returns (string memory) {
        return "";
    }
}

contract S7_RealNameResolution is Test {
    address constant ETH_REGISTRAR = 0xAbe76F6C8DFcEd81AA5A2bB8034202A7136b94ca;
    address constant UNIVERSAL_RESOLVER = 0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3;
    address constant MOCK_USDC = 0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e;
    address constant RESOLVER_IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;

    string constant PARENT = "recknspike7391";
    string constant SUB = "agent";
    string constant KEY = "reckn:jobs";

    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;

    address agent = makeAddr("agent");
    address client = makeAddr("client");

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    PermissionedRegistry ourRegistry;
    IResolverDeployed resolver;
    AdapterStub adapter;

    function test_register_hang_and_resolve_through_ENS() public {
        IETHRegistrar rar = IETHRegistrar(ETH_REGISTRAR);
        emit log_named_string("parent label available", rar.isAvailable(PARENT) ? "YES" : "NO");

        // our own subname registry + a Permissioned Resolver whose admin is a contract
        ourRegistry = new PermissionedRegistry(
            ILabelStore(address(new MockLabelStore2())), address(this), EACBaseRolesLib.ALL_ROLES
        );
        address inst = address(new MiniProxy(RESOLVER_IMPL));
        resolver = IResolverDeployed(inst);
        adapter = new AdapterStub(inst);
        IResolverDeployed.RoleAssignment[] memory ad = new IResolverDeployed.RoleAssignment[](1);
        ad[0] = IResolverDeployed.RoleAssignment(address(adapter), ALL_ROLES);
        resolver.initialize(ad, new bytes[](0));

        // --- register the parent on the REAL registrar
        uint64 duration = rar.MIN_REGISTER_DURATION();
        (uint256 base, uint256 premium) = rar.getRegisterPrice(PARENT, duration, MOCK_USDC);
        emit log_named_uint("register price (base)", base);
        emit log_named_uint("register price (premium)", premium);

        deal(MOCK_USDC, address(this), (base + premium) * 10 + 1e24);
        IERC20Like(MOCK_USDC).approve(ETH_REGISTRAR, type(uint256).max);

        bytes32 secret = keccak256("spike-secret");
        bytes32 commitment = rar.makeCommitment(
            PARENT, address(this), secret, IRegistry(address(ourRegistry)), inst, duration, bytes32(0)
        );
        rar.commit(commitment);
        vm.warp(block.timestamp + rar.MIN_COMMITMENT_AGE() + 1);

        rar.register(
            PARENT,
            address(this),
            secret,
            IRegistry(address(ourRegistry)),
            inst,
            duration,
            MOCK_USDC,
            bytes32(0)
        );
        emit log("parent registered on the real Sepolia ETHRegistrar");

        // --- the agent's subname, WITHOUT the power to repoint it (S4)
        ourRegistry.register(
            SUB,
            agent,
            IRegistry(address(0)),
            inst,
            RegistryRolesLib.ROLE_RENEW,
            uint64(block.timestamp + 300 days)
        );
        emit log("agent subname issued under our own registry");

        // --- a settlement-shaped window writes the record
        bytes memory dnsName = _dns();
        bytes memory setter =
            abi.encodeWithSelector(IResolverDeployed.setText.selector, dnsName, KEY, "");
        adapter.openSetterWindow(setter, client);
        vm.prank(client);
        resolver.setText(dnsName, KEY, "1");

        // --- THE QUESTION: does ENS itself resolve it?
        bytes memory inner = abi.encodeWithSelector(bytes4(0x59d1d43c), _namehash(), KEY);
        (bool ok, bytes memory out) = UNIVERSAL_RESOLVER.staticcall(
            abi.encodeWithSelector(IUniversalResolver.resolve.selector, dnsName, inner)
        );
        emit log_named_string("UniversalResolverV2.resolve", ok ? "OK" : "REVERT");
        if (!ok) {
            bytes4 sel;
            assembly { sel := mload(add(out, 0x20)) }
            emit log_named_bytes32("revert selector", bytes32(sel));
            fail();
        }
        (bytes memory answer, address usedResolver) = abi.decode(out, (bytes, address));
        emit log_named_address("resolver ENS chose", usedResolver);
        emit log_named_string("text via ENS", abi.decode(answer, (string)));
        assertEq(usedResolver, address(resolver), "ENS did not route to our resolver");
        assertEq(abi.decode(answer, (string)), "1", "ENS did not return the record");
        emit log("RESOLVED THROUGH ENS - not through a direct call to our own resolver");
    }

    function _dns() internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(bytes(SUB).length), SUB,
            uint8(bytes(PARENT).length), PARENT,
            uint8(3), "eth",
            uint8(0)
        );
    }

    function _namehash() internal pure returns (bytes32 n) {
        n = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        n = keccak256(abi.encodePacked(n, keccak256(bytes(PARENT))));
        n = keccak256(abi.encodePacked(n, keccak256(bytes(SUB))));
    }
}

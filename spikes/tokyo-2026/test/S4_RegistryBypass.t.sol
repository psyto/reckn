// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PermissionedRegistry} from "@ens/src/registry/PermissionedRegistry.sol";
import {IRegistry} from "@ens/src/registry/interfaces/IRegistry.sol";
import {ILabelStore} from "@ens/src/utils/interfaces/ILabelStore.sol";
import {RegistryRolesLib} from "@ens/src/registry/libraries/RegistryRolesLib.sol";
import {EACBaseRolesLib} from "@ens/src/access-control/libraries/EACBaseRolesLib.sol";

/// S4 — spec 013 §3.6 Q5, the last paper-only hole in the central claim.
///
/// r1 B2: "if the agent owns its subname token, ordinary token-owner powers can replace its
/// resolver, and the original resolver keeps correctly refusing while the agent writes whatever
/// it likes somewhere else."
///
/// The question is whether the ISSUER can withhold that power at registration.
/// DISPOSABLE. Not ported.
/// @dev Minimal stand-in: the real LabelStore drags in the v1 ens-contracts tree, and nothing
///      here depends on label storage.
contract MockLabelStore is ILabelStore {
    mapping(bytes32 => string) labels;

    function setLabel(string calldata label) external {
        labels[keccak256(bytes(label))] = label;
        emit Label(keccak256(bytes(label)), label);
    }

    function getLabel(uint256) external pure returns (string memory) {
        return "";
    }
}

contract S4_RegistryBypass is Test {
    PermissionedRegistry registry;

    address agent = makeAddr("agent");
    address evilResolver = makeAddr("evilResolver");
    address goodResolver = makeAddr("goodResolver");

    uint64 expiry;

    function setUp() public {
        ILabelStore labels = ILabelStore(address(new MockLabelStore()));
        // we are the root of OUR parent registry — §1.1 already discloses that
        registry = new PermissionedRegistry(labels, address(this), EACBaseRolesLib.ALL_ROLES);
        expiry = uint64(block.timestamp + 365 days);
    }

    /// The agent gets its name, but NOT the power to repoint it.
    function test_agent_cannot_repoint_its_own_record_surface() public {
        uint256 withheld = RegistryRolesLib.ROLE_RENEW; // deliberately not SET_RESOLVER/SET_SUBREGISTRY
        uint256 tokenId =
            registry.register("agent", agent, IRegistry(address(0)), goodResolver, withheld, expiry);

        assertEq(registry.ownerOf(tokenId), agent, "the agent does own the token");

        vm.prank(agent);
        try registry.setResolver(tokenId, evilResolver) {
            emit log("!! THE AGENT REPOINTED ITS OWN RESOLVER - r1 B2 stands, claim is dead");
            fail();
        } catch (bytes memory err) {
            bytes4 sel;
            assembly { sel := mload(add(err, 0x20)) }
            emit log_named_bytes32("setResolver refused with", bytes32(sel));
            emit log("the agent owns the name and still cannot repoint its record surface");
        }

        vm.prank(agent);
        try registry.setSubregistry(tokenId, IRegistry(address(0xdead))) {
            emit log("!! THE AGENT REPLACED ITS SUBREGISTRY");
            fail();
        } catch {
            emit log("setSubregistry also refused");
        }

        assertEq(registry.getResolver("agent"), goodResolver, "resolver moved anyway");
    }

    /// CONTROL ARM — the refusal above must be caused by the withheld role and nothing else.
    /// If this arm also refused, the test above would be green for the wrong reason.
    function test_control_same_call_succeeds_when_the_role_is_granted() public {
        uint256 granted = RegistryRolesLib.ROLE_SET_RESOLVER;
        uint256 tokenId = registry.register(
            "agent2", agent, IRegistry(address(0)), goodResolver, granted, expiry
        );

        vm.prank(agent);
        registry.setResolver(tokenId, evilResolver);
        assertEq(registry.getResolver("agent2"), evilResolver, "control arm did not move it");
        emit log("control: with ROLE_SET_RESOLVER granted, the same call SUCCEEDS");
    }

    /// And the issuer must not be able to smuggle the role in later without it being visible.
    function test_root_can_still_grant_it_later_so_renouncing_root_matters() public {
        uint256 tokenId = registry.register(
            "agent3", agent, IRegistry(address(0)), goodResolver, RegistryRolesLib.ROLE_RENEW, expiry
        );
        uint256 resource = registry.getResource(tokenId);

        registry.grantRoles(resource, RegistryRolesLib.ROLE_SET_RESOLVER, agent);
        vm.prank(agent);
        registry.setResolver(tokenId, evilResolver);
        emit log("root CAN hand the power over afterwards - which is why root must be renounced");
        assertEq(registry.getResolver("agent3"), evilResolver);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";

/// @title DeployArc
/// @notice Deploys the keyless settlement path to Arc: SP1's Groth16 verifier, the
///         generic verdict verifier bound to one guest's vkey, and the escrow.
///
///         Three properties of this script are deliberate.
///
///         **It deploys SP1's verifier itself.** Arc has no canonical SP1 verifier
///         gateway, and a gateway is an upgradeable indirection owned by somebody.
///         Deploying `SP1Verifier` directly means the address the escrow trusts is a
///         fixed, non-upgradeable Groth16 verifier — which is what lets the escrow
///         have no admin without smuggling one in behind it.
///
///         **It passes no token address.** USDC is named per deal at funding time,
///         not at deployment. On Arc that address is the native-USDC ERC-20 face at
///         `0x3600000000000000000000000000000000000000` — a constant of the chain,
///         not a parameter of this system.
///
///         **`RecknZkEscrow` takes no constructor argument at all**, so there is no
///         deployment-time choice to trust: two deployments of this source are the
///         same contract. That is the point being demonstrated, and a deploy script
///         that had to configure the escrow would be evidence against it.
///
///         Run (requires a funded key — held by the founder, never by an agent):
///           VKEY=0x... forge script script/DeployArc.s.sol:DeployArc \
///             --rpc-url https://rpc.testnet.arc.io --broadcast
contract DeployArc is Script {
    /// Arc testnet's native-USDC ERC-20 interface (Arc docs, read 2026-09-06).
    address constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;
    uint256 constant ARC_TESTNET_CHAIN_ID = 5042002;

    function run() external {
        bytes32 vkey = vm.envBytes32("VKEY");
        require(vkey != bytes32(0), "VKEY is required: the verifier is bound to one guest");

        if (block.chainid != ARC_TESTNET_CHAIN_ID) {
            console.log("note: chainid is not Arc testnet (5042002); deploying anyway to", block.chainid);
        }

        vm.startBroadcast();
        SP1Verifier sp1 = new SP1Verifier();
        RecknVerdictVerifier verifier = new RecknVerdictVerifier(address(sp1), vkey);
        RecknZkEscrow escrow = new RecknZkEscrow();
        vm.stopBroadcast();

        console.log("chain id          ", block.chainid);
        console.log("SP1Verifier       ", address(sp1));
        console.log("RecknVerdictVerifier", address(verifier));
        console.log("  vkey            ", vm.toString(vkey));
        console.log("  codehash        ", vm.toString(address(verifier).codehash));
        console.log("RecknZkEscrow     ", address(escrow));
        console.log("USDC (fund with)  ", ARC_TESTNET_USDC);
        console.log("");
        console.log("A buyer funds a deal with:");
        console.log("  fund(dealId, seller, USDC, amount, verifier, verifierCodehash, dealBinding)");
        console.log("The codehash above is what a seller reads before working.");
    }
}

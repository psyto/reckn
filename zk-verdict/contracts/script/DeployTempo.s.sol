// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";

/// @title DeployTempo
/// @notice Task 011. Deploys the same keyless settlement path to Tempo. `DeployArc.s.sol`
///         is not modified and not replaced; this is its sibling.
///
///         **The escrow source is identical.** `RecknZkEscrow` names no chain and no token
///         — `grep -n 'Arc\|USDC'` over `src/*.sol` returns nothing — so nothing about it
///         changes to hold a TIP-20. That is the finding 011 rests on, and a deploy script
///         that had to configure the escrow would be evidence against it.
///
///         **Three things differ from Arc, and only three.**
///
///         1. **The token is not a constant here.** On Arc the USDC ERC-20 face is a fixed
///            predeploy. On Tempo the TIP-20 to use is not yet established (011 §2.4), so it
///            is an env var and is printed, never hardcoded. Recording an unverified address
///            in source is how a wrong-but-plausible literal survives review.
///         2. **Tempo has no native gas token.** The fee for this very deployment is paid in
///            a USD-denominated TIP-20. Whether upstream Foundry can send such a transaction
///            or `tempoxyz/tempo-foundry` and its `--tempo.fee-token` flag are required is
///            OPEN (011 §2.4, §9.2) — this script does not pretend to settle it.
///         3. **`eth_getBalance` is meaningless on Tempo.** Measured 2026-09-08 it returns a
///            constant (~6.8e74), not a balance. Anything downstream that checks funding
///            must read `balanceOf` on the TIP-20.
///
///         SP1's Groth16 verifier is deployed directly rather than pointing at a gateway,
///         for the same reason as on Arc: a gateway is an upgradeable indirection owned by
///         somebody, and the escrow's claim is that nobody owns anything. The BN254
///         precompiles this verifier needs were measured present on Tempo testnet with
///         Ethereum semantics on 2026-09-08 (011 §2.2); that a real proof VERIFIES there,
///         and fits the fee model, is what this deployment exists to find out.
///
///         Run (requires a funded key — held by the founder, never by an agent):
///           VKEY=0x... TIP20=0x... forge script script/DeployTempo.s.sol:DeployTempo \
///             --rpc-url https://rpc.moderato.tempo.xyz --broadcast
contract DeployTempo is Script {
    /// Measured 2026-09-08: `eth_chainId` at https://rpc.moderato.tempo.xyz returns 0xa5bf.
    uint256 constant TEMPO_TESTNET_CHAIN_ID = 42431;

    function run() external {
        bytes32 vkey = vm.envBytes32("VKEY");
        require(vkey != bytes32(0), "VKEY is required: the verifier is bound to one guest");
        // Optional, and printed rather than trusted: the deal names the token at funding.
        address tip20 = vm.envOr("TIP20", address(0));

        if (block.chainid != TEMPO_TESTNET_CHAIN_ID) {
            console.log("note: chainid is not Tempo testnet (42431); deploying anyway to", block.chainid);
            console.log("      https://rpc.tempo.xyz answered 4217 on 2026-09-08 -- a DIFFERENT chain.");
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
        if (tip20 == address(0)) {
            console.log("TIP-20 (fund with)  NOT SUPPLIED -- pass TIP20=0x... once the faucet token is known");
        } else {
            console.log("TIP-20 (fund with)", tip20);
        }
        console.log("");
        console.log("A buyer funds a deal with:");
        console.log("  fund(dealId, seller, TIP20, amount, verifier, verifierCodehash, dealBinding)");
        console.log("The codehash above is what a seller reads before working.");
        console.log("Record the receipts in zk-verdict/contracts/tempo.json -- never from memory.");
    }
}

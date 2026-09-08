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
///         1. **The token has a measured default and stays overridable.** `PATHUSD` is the
///            token BOTH sampled receipts paid their fee in on 2026-09-08, and
///            name()/symbol()/decimals() read PathUSD / PathUSD / 6 from it. It is a
///            measurement of the chain's default, which is not a promise about the token our
///            deal will name — so `TIP20=0x...` overrides it. (An earlier draft of this
///            comment said the token "is not a constant here"; that was true before the
///            address was measured, and leaving it would have been the drift this repository
///            keeps catching.)
///         2. **Tempo has no native gas token, and the RECEIPT says what paid.** Every
///            receipt carries `feeToken` and `feePayer` — including for a plain type 0x2
///            transaction, measured 2026-09-08. So a standard EIP-1559 transaction both
///            works here and produces the evidence 011's T-4 asks for. `tempo-foundry` and
///            its `--tempo.fee-token` flag are needed only to CHOOSE a non-default fee
///            token, which requires Tempo's own type `0x76`. Paying a fee does not.
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
///           VKEY=0x... forge script script/DeployTempo.s.sol:DeployTempo \
///             --rpc-url https://rpc.moderato.tempo.xyz --broadcast
///         (add TIP20=0x... to name a token other than the measured default)
contract DeployTempo is Script {
    /// Measured 2026-09-08: `eth_chainId` at https://rpc.moderato.tempo.xyz returns 0xa5bf.
    uint256 constant TEMPO_TESTNET_CHAIN_ID = 42431;
    /// Tempo testnet's default fee token (measured 2026-09-08; see tempo.json).
    address constant PATHUSD = 0x20C0000000000000000000000000000000000000;

    function run() external {
        bytes32 vkey = vm.envBytes32("VKEY");
        require(vkey != bytes32(0), "VKEY is required: the verifier is bound to one guest");
        // The deal names the token at funding, so this is only for the operator's benefit.
        // PATHUSD is measured, not transcribed: on 2026-09-08 both a type 0x2 and a type 0x76
        // receipt reported `feeToken` = this address, and name()/symbol()/decimals() read
        // PathUSD / PathUSD / 6 from it. It stays overridable because the faucet token has
        // not been obtained and a measurement of the DEFAULT is not a promise about ours.
        address tip20 = vm.envOr("TIP20", PATHUSD);

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
        console.log("TIP-20 (fund with)", tip20);
        if (tip20 == PATHUSD) {
            console.log("  ^ PathUSD, 6 decimals -- the chain's DEFAULT fee token, measured 2026-09-08.");
            console.log("    Override with TIP20=0x... if the deal should name a different one.");
        }
        console.log("Fees: no native token exists. The receipt's feeToken/feePayer name what paid.");
        console.log("");
        console.log("A buyer funds a deal with:");
        console.log("  fund(dealId, seller, TIP20, amount, verifier, verifierCodehash, dealBinding)");
        console.log("The codehash above is what a seller reads before working.");
        console.log("Record the receipts in zk-verdict/contracts/tempo.json -- never from memory.");
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";

/// End-to-end against SP1's **real** Groth16 verifier (circuit v6.1.0, matching
/// the `sp1-sdk` that generated the proof). No mock: this deploys the canonical
/// `SP1Verifier` and feeds it a real proof produced by `cargo run --bin evm`.
/// If it verifies, the reckn verdict is authoritative on-chain with zero trusted
/// parties — exactly the trustless cross-chain settlement primitive.
///
/// Gated on the fixture's presence so `forge test` stays green for anyone who
/// hasn't run the (heavy, GPU-friendly) proof generation. Generate it with:
///   cd ../script && cargo run --release --bin evm -- --pre 42 --post 142 --min 100
contract RecknVerdictVerifierFixtureTest is Test {
    string constant FIXTURE = "src/fixtures/groth16-fixture.json";

    function test_real_groth16_proof_verifies_on_chain() public {
        require(vm.exists(FIXTURE), "missing groth16 fixture -- a missing fixture is a hard failure; regenerate with `cargo run --bin evm`");

        string memory json = vm.readFile(FIXTURE);
        bytes32 vkey = vm.parseJsonBytes32(json, ".vkey");
        bytes memory publicValues = vm.parseJsonBytes(json, ".public_values");
        bytes memory proof = vm.parseJsonBytes(json, ".proof");
        bytes32 expectedTraceHash = vm.parseJsonBytes32(json, ".trace_hash");
        uint256 expectedOutcome = vm.parseJsonUint(json, ".outcome");
        uint256 pre = vm.parseJsonUint(json, ".pre");
        uint256 post = vm.parseJsonUint(json, ".post");

        SP1Verifier sp1 = new SP1Verifier();
        RecknVerdictVerifier v = new RecknVerdictVerifier(address(sp1), vkey);

        // The real proof verifies against the real verifier, and the decoded
        // verdict matches what the guest committed.
        VerdictPublicValues memory got = v.verifyVerdict(publicValues, proof);
        assertEq(uint256(got.outcome), expectedOutcome, "on-chain outcome");
        assertEq(got.traceHash, expectedTraceHash, "on-chain trace hash");
        assertEq(uint256(got.post - got.pre), post - pre, "credited delta");
    }

    function test_tampered_public_values_are_rejected() public {
        require(vm.exists(FIXTURE), "missing fixture -- regenerate it; a missing fixture is a hard failure");

        string memory json = vm.readFile(FIXTURE);
        bytes32 vkey = vm.parseJsonBytes32(json, ".vkey");
        bytes memory proof = vm.parseJsonBytes(json, ".proof");

        SP1Verifier sp1 = new SP1Verifier();
        RecknVerdictVerifier v = new RecknVerdictVerifier(address(sp1), vkey);

        // Forge a "Reproduced" verdict the proof does not attest to: the real
        // verifier binds public values into the proof, so this must revert.
        bytes memory forged = abi.encode(
            VerdictPublicValues({
                pre: 0,
                post: 1_000_000,
                minDelta: 0,
                maxDelta: type(uint64).max,
                outcome: 0,
                traceHash: keccak256("forged"),
                dealBinding: bytes32(0)
            })
        );
        vm.expectRevert();
        v.verifyVerdict(forged, proof);
    }
}

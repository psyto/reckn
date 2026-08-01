// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";

/// The **full re-execution** proof, verified on-chain. This fixture is produced by
/// a guest that runs *real revm* inside the zkVM: it seeds the committed prestate,
/// executes the seller's CALL, and derives the post-state — so `post` is proven by
/// execution, not trusted. The very same generic `RecknVerdictVerifier` (only the
/// program vkey differs from the predicate proof) accepts it, because the guest
/// commits the identical `VerdictPublicValues`. That is the point: strengthening
/// the proof from "trusts post" to "executes to get post" changes nothing on-chain.
///
/// Gated on the fixture so `forge test` stays green without it. Generate with:
///   cd ../script && cargo run --release --bin reexec -- --fixture
contract RecknReexecVerdictTest is Test {
    string constant FIXTURE = "src/fixtures/reexec-groth16-fixture.json";

    function test_full_reexecution_proof_verifies_on_chain() public {
        if (!vm.exists(FIXTURE)) {
            emit log("no reexec fixture present -- skipping (run `cargo run --bin reexec -- --fixture`)");
            return;
        }

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

        // The proof of the in-guest EVM execution verifies, and the verdict it
        // attests (post derived by execution) matches.
        VerdictPublicValues memory got = v.verifyVerdict(publicValues, proof);
        assertEq(uint256(got.outcome), expectedOutcome, "reexec on-chain outcome");
        assertEq(got.traceHash, expectedTraceHash, "reexec on-chain trace hash");
        assertEq(uint256(got.post - got.pre), post - pre, "executed credited delta");
    }

    function test_reexec_tampered_public_values_are_rejected() public {
        if (!vm.exists(FIXTURE)) return;

        string memory json = vm.readFile(FIXTURE);
        bytes32 vkey = vm.parseJsonBytes32(json, ".vkey");
        bytes memory proof = vm.parseJsonBytes(json, ".proof");

        SP1Verifier sp1 = new SP1Verifier();
        RecknVerdictVerifier v = new RecknVerdictVerifier(address(sp1), vkey);

        bytes memory forged = abi.encode(
            VerdictPublicValues({
                pre: 0,
                post: 1_000_000,
                minDelta: 0,
                maxDelta: type(uint64).max,
                outcome: 0,
                traceHash: keccak256("forged")
            })
        );
        vm.expectRevert();
        v.verifyVerdict(forged, proof);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";

/// The **Solana (SVM) re-execution** proof, verified on-chain. This fixture is
/// produced by a guest that signature-verifies the real committed Solana
/// transaction and re-executes its System transfer to derive the post-lamports —
/// so `post` is proven by execution, not trusted. The **same** generic
/// `RecknVerdictVerifier` accepts it (only the program vkey differs from the EVM
/// proofs), because every reckn guest commits the identical `VerdictPublicValues`.
/// That is the cross-VM payoff: one on-chain verdict contract, one verdict record,
/// EVM and SVM proofs alike.
///
/// Gated on the fixture so `forge test` stays green without it. Generate with:
///   cd ../script && cargo run --release --bin svm -- --fixture
contract RecknSvmVerdictTest is Test {
    string constant FIXTURE = "src/fixtures/svm-groth16-fixture.json";

    function test_svm_reexecution_proof_verifies_on_chain() public {
        if (!vm.exists(FIXTURE)) {
            emit log("no svm fixture present -- skipping (run `cargo run --bin svm -- --fixture`)");
            return;
        }

        string memory json = vm.readFile(FIXTURE);
        bytes32 vkey = vm.parseJsonBytes32(json, ".vkey");
        bytes memory publicValues = vm.parseJsonBytes(json, ".public_values");
        bytes memory proof = vm.parseJsonBytes(json, ".proof");
        bytes32 expectedTraceHash = vm.parseJsonBytes32(json, ".trace_hash");
        uint256 expectedOutcome = vm.parseJsonUint(json, ".outcome");

        SP1Verifier sp1 = new SP1Verifier();
        RecknVerdictVerifier v = new RecknVerdictVerifier(address(sp1), vkey);

        VerdictPublicValues memory got = v.verifyVerdict(publicValues, proof);
        assertEq(uint256(got.outcome), expectedOutcome, "svm on-chain outcome");
        assertEq(got.traceHash, expectedTraceHash, "svm on-chain trace hash");
        // The credited lamports delta the transfer produced.
        assertGe(uint256(got.post - got.pre), 1, "svm credited a positive delta");
    }

    function test_svm_tampered_public_values_are_rejected() public {
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

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1VerifierGateway} from "@sp1-contracts/SP1VerifierGateway.sol";

/// Self-contained: the public values are constructed here (matching what the
/// zk-verdict guest commits), so no generated fixture is required. The valid-proof
/// path mocks the SP1 verifier to succeed (the wiring under test is "if the proof
/// verifies, the contract decodes and exposes the verdict"); the invalid-proof
/// path hits the real gateway, which reverts. A real Groth16 fixture verified
/// against SP1's real on-chain verifier is the heavier bonus (see the README).
contract RecknVerdictVerifierTest is Test {
    address verifier;
    RecknVerdictVerifier v;
    bytes32 constant VKEY = bytes32(uint256(0xbeef));

    function setUp() public {
        verifier = address(new SP1VerifierGateway(address(1)));
        v = new RecknVerdictVerifier(verifier, VKEY);
    }

    // A committed verdict: credited 100 lands in [100, MAX] -> Reproduced.
    function _reproducedVerdict() internal pure returns (bytes memory) {
        return abi.encode(
            VerdictPublicValues({
                pre: 42,
                post: 142,
                minDelta: 100,
                maxDelta: type(uint64).max,
                outcome: 0,
                traceHash: keccak256("trace")
            })
        );
    }

    function test_valid_proof_exposes_the_zk_attested_verdict() public {
        bytes memory publicValues = _reproducedVerdict();
        // A valid SP1 proof verifies; mock the verifier to accept.
        vm.mockCall(
            verifier,
            abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector),
            abi.encode(true)
        );
        VerdictPublicValues memory got = v.verifyVerdict(publicValues, hex"1234");
        assertEq(got.outcome, v.REPRODUCED(), "ZK-attested Reproduced");
        assertEq(got.traceHash, keccak256("trace"), "attested trace hash");
        assertEq(got.post - got.pre, 100, "credited delta");
    }

    function test_invalid_proof_reverts_so_no_unproven_verdict_settles() public {
        bytes memory publicValues = _reproducedVerdict();
        bytes memory fakeProof = new bytes(260);
        // No mock: the real gateway has no route for this proof and reverts —
        // an unproven verdict is never authoritative.
        vm.expectRevert();
        v.verifyVerdict(publicValues, fakeProof);
    }
}

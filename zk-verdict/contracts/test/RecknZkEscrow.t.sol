// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier, VerdictPublicValues} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {SP1VerifierGateway} from "@sp1-contracts/SP1VerifierGateway.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// The payoff: a ZK-proven re-execution verdict **moves money**, with no resolver.
/// The happy path settles a real Groth16 proof (the EVM re-execution fixture) on
/// SP1's real verifier; the rest use a mocked verifier to exercise the refund and
/// the binding/authority guards without re-proving.
contract RecknZkEscrowTest is Test {
    string constant REEXEC_FIXTURE = "src/fixtures/reexec-groth16-fixture.json";

    address buyer = address(0xB0B);
    address seller = address(0x5E11E5);
    uint256 constant AMOUNT = 1_000e6;

    MockERC20 token;

    function setUp() public {
        token = new MockERC20();
        token.mint(buyer, AMOUNT);
    }

    function _fund(RecknZkEscrow escrow, bytes32 dealId, bytes32 binding) internal {
        vm.prank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.prank(buyer);
        escrow.fund(dealId, seller, address(token), AMOUNT, binding);
    }

    /// End-to-end: a REAL Groth16 proof of the EVM re-execution (Reproduced) settles
    /// the escrow to the seller — authority from the proof, not a signature.
    function test_real_proof_settles_to_seller() public {
        if (!vm.exists(REEXEC_FIXTURE)) {
            emit log("no reexec fixture -- skipping (cd ../script && cargo run --bin reexec -- --fixture)");
            return;
        }
        string memory json = vm.readFile(REEXEC_FIXTURE);
        bytes32 vkey = vm.parseJsonBytes32(json, ".vkey");
        bytes memory publicValues = vm.parseJsonBytes(json, ".public_values");
        bytes memory proof = vm.parseJsonBytes(json, ".proof");
        bytes32 binding = vm.parseJsonBytes32(json, ".deal_binding");
        assertEq(vm.parseJsonUint(json, ".outcome"), 0, "fixture is Reproduced");

        SP1Verifier sp1 = new SP1Verifier();
        RecknVerdictVerifier verifier = new RecknVerdictVerifier(address(sp1), vkey);
        RecknZkEscrow escrow = new RecknZkEscrow(verifier);

        bytes32 dealId = keccak256("deal-real");
        _fund(escrow, dealId, binding);
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "escrow holds funds");

        // Anyone can submit the proof — it carries its own authority.
        escrow.settleWithProof(dealId, publicValues, proof);

        assertEq(token.balanceOf(seller), AMOUNT, "seller paid on ZK-proven Reproduced");
        assertEq(token.balanceOf(address(escrow)), 0, "escrow drained");
    }

    // --- mocked verifier: refund + guards ---

    function _mockEscrow() internal returns (RecknZkEscrow escrow, address verifierAddr) {
        verifierAddr = address(new SP1VerifierGateway(address(1)));
        RecknVerdictVerifier verifier = new RecknVerdictVerifier(verifierAddr, bytes32(uint256(0xbeef)));
        escrow = new RecknZkEscrow(verifier);
        // Accept any proof so we can exercise the escrow's own logic.
        vm.mockCall(
            verifierAddr,
            abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector),
            abi.encode(true)
        );
    }

    function _pv(uint8 outcome, bytes32 binding) internal pure returns (bytes memory) {
        return abi.encode(
            VerdictPublicValues({
                pre: 42,
                post: 42,
                minDelta: 100,
                maxDelta: type(uint64).max,
                outcome: outcome,
                traceHash: keccak256("t"),
                dealBinding: binding
            })
        );
    }

    function test_failed_verdict_refunds_buyer() public {
        (RecknZkEscrow escrow,) = _mockEscrow();
        bytes32 dealId = keccak256("deal-failed");
        bytes32 binding = keccak256("binding-A");
        _fund(escrow, dealId, binding);

        escrow.settleWithProof(dealId, _pv(escrow.FAILED(), binding), hex"1234");
        assertEq(token.balanceOf(buyer), AMOUNT, "buyer refunded on ZK-proven Failed");
        assertEq(token.balanceOf(seller), 0, "seller unpaid");
    }

    function test_settle_reverts_on_binding_mismatch() public {
        (RecknZkEscrow escrow,) = _mockEscrow();
        bytes32 dealId = keccak256("deal-mismatch");
        _fund(escrow, dealId, keccak256("binding-A"));

        // A verified proof, but about a DIFFERENT deal (binding-B) — must not settle.
        // Build the public values first so expectRevert targets the settle call only.
        bytes memory pv = _pv(escrow.REPRODUCED(), keccak256("binding-B"));
        vm.expectRevert(RecknZkEscrow.BindingMismatch.selector);
        escrow.settleWithProof(dealId, pv, hex"1234");
        assertEq(token.balanceOf(address(escrow)), AMOUNT, "funds stay put");
    }

    function test_settle_reverts_on_unverified_proof() public {
        // Real gateway (no mock): a fake proof cannot verify, so settlement reverts.
        SP1VerifierGateway gw = new SP1VerifierGateway(address(1));
        RecknVerdictVerifier verifier = new RecknVerdictVerifier(address(gw), bytes32(uint256(0xbeef)));
        RecknZkEscrow escrow = new RecknZkEscrow(verifier);
        bytes32 dealId = keccak256("deal-badproof");
        _fund(escrow, dealId, keccak256("binding-A"));

        vm.expectRevert();
        escrow.settleWithProof(dealId, _pv(0, keccak256("binding-A")), new bytes(260));
    }
}

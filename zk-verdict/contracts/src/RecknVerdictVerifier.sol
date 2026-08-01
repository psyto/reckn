// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";

/// @notice Public values committed by the zk-verdict guest. Must match the
///         `sol!` struct in `zk-verdict/lib/src/lib.rs` (field order + types).
struct VerdictPublicValues {
    uint64 pre;
    uint64 post;
    uint64 minDelta;
    uint64 maxDelta;
    uint8 outcome;
    bytes32 traceHash;
}

/// @title RecknVerdictVerifier
/// @notice Accepts a reckn verdict **proven in a zkVM** (SP1): it verifies the
///         proof on-chain against the program's verification key, then exposes the
///         committed verdict (`outcome`, `traceHash`). No trusted resolver — the
///         verdict is authoritative because the proof verifies, not because a
///         signer is on an allow-list.
///
///         Because this is only a proof check, it works identically on **any**
///         chain. That is what makes a ZK verdict the trustless cross-chain
///         settlement primitive: a paying chain A can verify a verdict about work
///         on chain B by checking this proof itself — no bridge, no B light
///         client, no trusted relayer. The verdict *is* the proof.
contract RecknVerdictVerifier {
    uint8 public constant REPRODUCED = 0;
    uint8 public constant FAILED = 1;

    /// @notice The SP1 verifier (a `SP1VerifierGateway`, or a versioned verifier).
    address public immutable verifier;
    /// @notice The verification key of the zk-verdict program.
    bytes32 public immutable verdictProgramVKey;

    constructor(address _verifier, bytes32 _verdictProgramVKey) {
        verifier = _verifier;
        verdictProgramVKey = _verdictProgramVKey;
    }

    /// @notice Verify a ZK proof of a reckn verdict and return the attested values.
    ///         Reverts if the proof does not verify, so an unproven verdict can
    ///         never be treated as authoritative.
    function verifyVerdict(bytes calldata publicValues, bytes calldata proofBytes)
        public
        view
        returns (VerdictPublicValues memory v)
    {
        ISP1Verifier(verifier).verifyProof(verdictProgramVKey, publicValues, proofBytes);
        v = abi.decode(publicValues, (VerdictPublicValues));
    }
}

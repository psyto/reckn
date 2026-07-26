// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

/// @title VerdictHash
/// @notice EIP-712 struct hashing + resolver signature recovery for a
///         VerdictCommitment. The resolver signs over EVERY field — never
///         `traceHash` alone (protocol rule). The escrow checks the recovered
///         signer is a registered resolver AND that the committed fields match
///         the deal, so a resolver cannot pick a fresh anchor or backend.
library VerdictHash {
    /// @dev Outcome mirrors the on-chain enum: Reproduced = 0, Failed = 1.
    ///      (Note: the off-chain ReexecVerdict TS enum uses 1/2; the codec layer
    ///      maps to this on-chain encoding — keep the mapping in packages/protocol.)
    struct VerdictCommitment {
        bytes32 dealId;
        bytes32 specHash;
        bytes32 deliveryHash;
        bytes32 prestateAnchorHash;
        bytes32 prestateRoot;
        bytes32 backendId;
        bytes32 backendVersionHash;
        uint8 outcome;
        bytes32 resultHash;
        bytes32 traceHash;
    }

    bytes32 internal constant VERDICT_TYPEHASH = keccak256(
        "VerdictCommitment(bytes32 dealId,bytes32 specHash,bytes32 deliveryHash,bytes32 prestateAnchorHash,bytes32 prestateRoot,bytes32 backendId,bytes32 backendVersionHash,uint8 outcome,bytes32 resultHash,bytes32 traceHash)"
    );

    function structHash(VerdictCommitment memory c) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                VERDICT_TYPEHASH,
                c.dealId,
                c.specHash,
                c.deliveryHash,
                c.prestateAnchorHash,
                c.prestateRoot,
                c.backendId,
                c.backendVersionHash,
                c.outcome,
                c.resultHash,
                c.traceHash
            )
        );
    }

    function digest(bytes32 domainSeparator, VerdictCommitment memory c) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash(c)));
    }

    /// @dev ECDSA recover with low-s malleability guard. Returns address(0) on
    ///      malformed input so callers MUST compare against an expected signer.
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }
        if (v != 27 && v != 28) return address(0);
        return ecrecover(hash, v, r, s);
    }
}

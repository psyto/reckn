// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VerdictHash} from "../src/libraries/VerdictHash.sol";

/// @notice Cross-language pin: the EIP-712 digest the escrow verifies in
///         resolve() must byte-match the digest the Rust keeper signs. Both
///         compute it for the SAME fixed inputs and assert the SAME golden value
///         (packages/protocol/golden/verdict-eip712-v1.json). If this test and
///         keeper/src/lib.rs::eip712_digest_matches_golden ever disagree, a
///         keeper signature would be rejected by resolve().
contract VerdictDigestTest is Test {
    // Same domain the keeper uses: chainId = 1, verifyingContract = 0x00..0abcd.
    uint256 constant CHAIN_ID = 1;
    address constant VERIFYING = address(0xCAFE);

    bytes32 constant GOLDEN = 0x1c8d7d89486545d7e3a23da1f5438c4f36c244c85646dcc1a0b5f3c5ef19846c;

    function _domainSeparator() internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Reckn"),
                keccak256("1"),
                CHAIN_ID,
                VERIFYING
            )
        );
    }

    function _fixedCommitment() internal pure returns (VerdictHash.VerdictCommitment memory) {
        return VerdictHash.VerdictCommitment({
            dealId: bytes32(_rep(0xd1)),
            specHash: bytes32(_rep(0x5c)),
            deliveryHash: bytes32(_rep(0xde)),
            prestateAnchorHash: bytes32(_rep(0xa0)),
            prestateRoot: bytes32(_rep(0x06)),
            backendId: bytes32(_rep(0xb0)),
            backendVersionHash: bytes32(_rep(0xb1)),
            outcome: 1, // Failed
            resultHash: bytes32(_rep(0x07)),
            traceHash: bytes32(_rep(0x2b))
        });
    }

    /// @dev A 32-byte word with every byte set to `b` (matches Rust B256::from([b;32])).
    function _rep(uint8 b) internal pure returns (uint256 w) {
        for (uint256 i = 0; i < 32; i++) {
            w = (w << 8) | b;
        }
    }

    function test_verdict_digest_matches_keeper_golden() public pure {
        bytes32 digest = VerdictHash.digest(_domainSeparator(), _fixedCommitment());
        assertEq(digest, GOLDEN, "contract digest must equal the keeper golden");
    }
}

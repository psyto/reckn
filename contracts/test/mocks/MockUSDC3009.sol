// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {IUSDC3009} from "../../src/interfaces/IUSDC3009.sol";

/// @dev Test double: `receiveWithAuthorization` moves balance from->to without
///      verifying the signature (real USDC verifies EIP-3009). Sufficient to
///      exercise the escrow's fund/settle accounting.
contract MockUSDC3009 is IUSDC3009 {
    mapping(address => uint256) public override balanceOf;
    mapping(bytes32 => bool) public usedNonce;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256, /*validAfter*/
        uint256, /*validBefore*/
        bytes32 nonce,
        uint8, /*v*/
        bytes32, /*r*/
        bytes32 /*s*/
    ) external override {
        require(to == msg.sender, "to != caller");
        require(!usedNonce[nonce], "nonce used");
        require(balanceOf[from] >= value, "insufficient");
        usedNonce[nonce] = true;
        balanceOf[from] -= value;
        balanceOf[to] += value;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "insufficient");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }
}

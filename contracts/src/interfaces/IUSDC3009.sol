// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

/// @title Minimal EIP-3009 + transfer surface used by Reckn escrow.
/// @notice Reckn pulls buyer funds with a signed EIP-3009 authorization at
///         funding time and pays out with a plain transfer at resolution. The
///         escrow never holds an allowance and never calls `latest`-style
///         mutable state; funding is atomic with the buyer's off-chain signature.
interface IUSDC3009 {
    /// @dev EIP-3009: move `value` from `from` to `to` given a signed auth.
    ///      `to` MUST be msg.sender (the escrow), preventing griefing pulls.
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transfer(address to, uint256 value) external returns (bool);

    /// @dev Standard ERC-20 pull. Reckn uses it only for the optional seller
    ///      data-availability bond: the seller approves the escrow, and `deliver`
    ///      pulls the committed bond into escrow. Buyer payment never uses this
    ///      path (it is EIP-3009, allowance-free).
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

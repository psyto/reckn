// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

/// @title ResolverRegistry
/// @notice Allow-list of (a) resolver settlement keys and (b) exact
///         (backendId, backendVersionHash) pairs a verdict may be produced by.
///         Per the protocol: backend id and *exact* version are part of the
///         deal/signature, so an engine upgrade cannot silently change a spec's
///         meaning. This registry is the on-chain half of that promise.
/// @dev Ownership is intentionally minimal (single owner) for the MVP. It is a
///      settlement-authority boundary, NOT a reproducibility claim — anyone can
///      re-derive a verdict from published inputs regardless of this list.
contract ResolverRegistry {
    address public owner;

    mapping(address => bool) public isResolver;
    // key = keccak256(abi.encode(backendId, backendVersionHash))
    mapping(bytes32 => bool) public isBackendAllowed;

    event OwnerTransferred(address indexed from, address indexed to);
    event ResolverSet(address indexed resolver, bool allowed);
    event BackendSet(bytes32 indexed backendId, bytes32 indexed backendVersionHash, bool allowed);

    error NotOwner();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        emit OwnerTransferred(address(0), owner_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnerTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setResolver(address resolver, bool allowed) external onlyOwner {
        if (resolver == address(0)) revert ZeroAddress();
        isResolver[resolver] = allowed;
        emit ResolverSet(resolver, allowed);
    }

    function setBackend(bytes32 backendId, bytes32 backendVersionHash, bool allowed) external onlyOwner {
        isBackendAllowed[backendKey(backendId, backendVersionHash)] = allowed;
        emit BackendSet(backendId, backendVersionHash, allowed);
    }

    function backendKey(bytes32 backendId, bytes32 backendVersionHash) public pure returns (bytes32) {
        return keccak256(abi.encode(backendId, backendVersionHash));
    }

    function backendAllowed(bytes32 backendId, bytes32 backendVersionHash) external view returns (bool) {
        return isBackendAllowed[backendKey(backendId, backendVersionHash)];
    }
}

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

    /// @notice A resolver's ETH bond — its skin in the game for optimistic
    ///         settlement. `RecknEscrow.resolveOptimistic` requires `isBonded`,
    ///         and governance can `slash` a bond to the harmed party when the
    ///         public, reproducible verdict proves a resolver signed a wrong one.
    mapping(address => uint256) public bond;
    uint256 public minBond;

    /// @notice A contract (the escrow) authorized to slash on a verified quorum
    ///         proof, so a resolver whose verdict a K-of-N quorum contradicts is
    ///         slashed automatically — not only by owner governance.
    address public quorumSlasher;
    /// @notice K: how many co-signing registered resolvers make a quorum.
    uint256 public quorumThreshold;

    event OwnerTransferred(address indexed from, address indexed to);
    event ResolverSet(address indexed resolver, bool allowed);
    event BackendSet(bytes32 indexed backendId, bytes32 indexed backendVersionHash, bool allowed);
    event MinBondSet(uint256 minBond);
    event BondDeposited(address indexed resolver, uint256 amount, uint256 total);
    event BondWithdrawn(address indexed resolver, uint256 amount, uint256 remaining);
    event Slashed(address indexed resolver, address indexed to, uint256 amount);
    event QuorumSlasherSet(address indexed slasher);
    event QuorumThresholdSet(uint256 threshold);

    error NotOwner();
    error ZeroAddress();
    error InsufficientBond();
    error TransferFailed();
    error NotQuorumSlasher();

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

    // --- resolver bonds (skin in the game for optimistic settlement) ---

    function setMinBond(uint256 newMinBond) external onlyOwner {
        minBond = newMinBond;
        emit MinBondSet(newMinBond);
    }

    /// @notice `resolveOptimistic` only accepts a signer whose bond clears the
    ///         current floor. Detached from the allow-list so a resolver can be
    ///         both approved and economically staked.
    function isBonded(address resolver) external view returns (bool) {
        return bond[resolver] >= minBond;
    }

    /// @notice Stake ETH against the caller's resolver identity. Anyone may bond
    ///         (settlement authority is still gated by `isResolver`).
    function depositBond() external payable {
        bond[msg.sender] += msg.value;
        emit BondDeposited(msg.sender, msg.value, bond[msg.sender]);
    }

    /// @notice Withdraw unslashed bond. There is no lock here; the optimistic
    ///         settlement window (in the escrow) is the period during which a
    ///         resolver's verdict is challengeable, and `slash` is governance's
    ///         tool for a proven fault — a resolver that withdraws forfeits its
    ///         standing to `resolveOptimistic`.
    function withdrawBond(uint256 amount) external {
        if (amount > bond[msg.sender]) revert InsufficientBond();
        bond[msg.sender] -= amount;
        emit BondWithdrawn(msg.sender, amount, bond[msg.sender]);
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Governance transfers a proven-faulty resolver's bond to the harmed
    ///         party. The proof is off-chain but public and reproducible: anyone
    ///         re-derives the correct verdict from committed inputs and sees which
    ///         resolver signed a conflicting one. Automatic, trustless slashing
    ///         (quorum / fraud proof) is a separate, larger effort.
    function slash(address resolver, address to, uint256 amount) external onlyOwner {
        _slash(resolver, to, amount);
    }

    // --- quorum-adjudicated automatic slashing ---

    function setQuorumSlasher(address slasher) external onlyOwner {
        quorumSlasher = slasher;
        emit QuorumSlasherSet(slasher);
    }

    function setQuorumThreshold(uint256 threshold) external onlyOwner {
        quorumThreshold = threshold;
        emit QuorumThresholdSet(threshold);
    }

    /// @notice Slash a bond on behalf of the `quorumSlasher` (the escrow), which
    ///         has verified that a K-of-N resolver quorum contradicts the faulty
    ///         resolver's verdict. Trustless under an honest-majority quorum — no
    ///         owner action required.
    function slashByQuorum(address resolver, address to, uint256 amount) external {
        if (msg.sender != quorumSlasher) revert NotQuorumSlasher();
        _slash(resolver, to, amount);
    }

    function _slash(address resolver, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (amount > bond[resolver]) revert InsufficientBond();
        bond[resolver] -= amount;
        emit Slashed(resolver, to, amount);
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}

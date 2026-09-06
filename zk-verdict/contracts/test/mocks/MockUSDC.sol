// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @title MockUSDC
/// @notice A USDC-shaped ERC-20 for the Arc settlement tests.
///
///         **What it stands in for.** On Arc, USDC is the NATIVE gas token (18
///         decimals) and Circle exposes an ERC-20 interface over that same balance
///         at the predeploy `0x3600000000000000000000000000000000000000`, whose
///         **ERC-20 face is 6 decimals** (Arc docs, "Contract addresses", read
///         2026-09-06). There is no wrapped USDC on Arc and none is needed: the
///         escrow holds the predeploy's ERC-20 face, so `RecknZkEscrow` requires no
///         change at all to settle in USDC on Arc.
///
///         This mock models that ERC-20 face. It is deliberately closer to Circle's
///         FiatTokenV2 than the generic MockERC20 is, in the three ways that can
///         change what the escrow does:
///
///         1. **six decimals.** 250 USDC is `250_000000`, not `250e18`. An escrow
///            tested only against an 18-decimal token has never been tested against
///            the units it will actually hold.
///         2. **`transfer` / `transferFrom` return `true` and REVERT on failure.**
///            They never return `false`. That matters because `RecknZkEscrow`
///            discards the boolean (a residual owned by task 003): with a token that
///            returns `false` instead of reverting, a payout could silently move
///            nothing. With USDC's actual semantics it cannot — and this mock is the
///            thing that makes that statement testable rather than asserted.
///         3. **a blacklist.** USDC can freeze an address, and a frozen recipient
///            makes the payout REVERT. That is not a bug in the escrow and this mock
///            exists so the consequence is demonstrated instead of described:
///            settlement reverts, the deal stays `Funded`, and — because the keyless
///            escrow has no timeout yet — the money stays where it is.
///
///         What it is not: not upgradeable, no EIP-3009, no permit, no fee logic.
///         Only the parts that can change a settlement outcome.
contract MockUSDC {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isBlacklisted;

    error Blacklisted(address account);
    error InsufficientBalance();
    error InsufficientAllowance();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// Test-only faucet. No access control, because this contract never leaves a test.
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    /// Test-only. Circle's is `blacklist(address)` behind an owner role; the role is
    /// irrelevant to what the escrow does when a recipient is frozen.
    function setBlacklisted(address account, bool frozen) external {
        isBlacklisted[account] = frozen;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (isBlacklisted[msg.sender]) revert Blacklisted(msg.sender);
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < value) revert InsufficientAllowance();
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - value;
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (isBlacklisted[from]) revert Blacklisted(from);
        if (isBlacklisted[to]) revert Blacklisted(to);
        if (balanceOf[from] < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }
}

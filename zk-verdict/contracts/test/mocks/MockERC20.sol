// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// Minimal ERC-20 for the ZK-escrow settlement tests.
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    /// Tracked so 009's AC-6 test 3 can assert that settlement creates and destroys
    /// nothing: only `mint` moves it, and no transfer path touches it.
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "insufficient");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "insufficient");
        uint256 a = allowance[from][msg.sender];
        require(a >= value, "allowance");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        return true;
    }
}

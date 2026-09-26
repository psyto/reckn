// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @notice A freely-mintable ERC-20, for the gated pool and nothing else.
/// @dev In `src/demo/` rather than `src/` on purpose: nothing here carries a claim. The pool
///      needs two tokens to trade and this is the smallest thing that is one. No owner, no
///      supply cap, no pretence of being money.
contract DemoToken {
    string public name;
    string public symbol = "DEMO";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name) {
        name = _name;
    }

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
        totalSupply += a;
        emit Transfer(address(0), to, a);
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        emit Transfer(msg.sender, to, a);
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        emit Transfer(f, t, a);
        return true;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        emit Approval(msg.sender, s, a);
        return true;
    }
}

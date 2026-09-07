// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @title MockTIP20
/// @notice A TIP-20-shaped token for the Tempo settlement tests (task 011).
///
///         **What it stands in for.** Tempo has **no native gas token**: transaction fees
///         are paid in a USD-denominated TIP-20 stablecoin. Measured 2026-09-08 against
///         `https://rpc.moderato.tempo.xyz` (chain 42431), `eth_getBalance` returns a
///         constant (~6.8e74) rather than a balance, which is the same statement from the
///         other side. So on Tempo the escrow's contents and the fee that pays for its
///         release are the SAME asset — the thing that makes 011 a Tempo slice rather than
///         the same Solidity on another RPC.
///
///         TIP-20 keeps ERC-20 `transfer` / `transferFrom` / `approve` semantics (Tempo
///         docs, TIP-20 spec, read 2026-09-08), so `RecknZkEscrow` needs no change to hold
///         one. This mock models only the parts that can change a settlement OUTCOME:
///
///         1. **decimals are a constructor argument.** The decimals of the testnet TIP-20
///            we will use are not established (011 §2.4), and an escrow tested only at 18
///            has never been tested in the units it will hold. The tests run 6 and 18.
///         2. **revert, never return `false`.** `RecknZkEscrow` discards the boolean, so a
///            token that returned `false` could make a payout silently move nothing. This
///            mock reverts, which is what makes that a demonstrated property.
///         3. **`pause()`.** A paused TIP-20 stops ALL token movement — including
///            `refundAfterDeadline`. That reaches further than Arc's USDC blacklist, which
///            only froze a named address, and it is the sharpest edge of 011: a state in
///            which a proof-authorised payout AND the timeout are both blocked by a third
///            party. Modelled so the consequence is shown, not described.
///         4. **a TIP-403-shaped policy.** Both sender and recipient must be authorised or
///            the call reverts with `PolicyForbids`.
///         5. **`InvalidRecipient`.** A TIP-20 refuses a transfer to another TIP-20.
///         6. **`transferWithMemo`.** Present only so a test can prove the escrow does NOT
///            read a memo and does not depend on one. A memo is data the issuer can also
///            write; letting settlement turn on it would hand someone a lever.
///
///         What it is not: no roles, no supply cap, no quote token, no fee precompile path.
///         None of them can change what `settleWithProof` does, and a mock that models
///         everything models nothing in particular.
contract MockTIP20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// TIP-403: an address is authorised unless explicitly forbidden. The real policy is a
    /// separate contract consulted on every movement; what matters to the escrow is only
    /// that a movement can be refused for a reason the escrow never sees.
    mapping(address => bool) public policyForbids;
    /// TIP-20 refuses a transfer whose recipient is another TIP-20.
    mapping(address => bool) public isTip20;
    bool public paused;

    error PolicyForbids(address account);
    error InvalidRecipient(address to);
    error TokenPaused();
    error InsufficientBalance();
    error InsufficientAllowance();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferWithMemo(address indexed from, address indexed to, uint256 value, bytes32 memo);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(bool paused);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        isTip20[address(this)] = true;
    }

    /// Test-only faucet. No access control, because this contract never leaves a test.
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    /// Test-only. The real one is behind `PAUSE_ROLE`; the role is not what is being tested,
    /// the CONSEQUENCE of a pause is.
    function setPaused(bool p) external {
        paused = p;
        emit Paused(p);
    }

    /// Test-only stand-in for a TIP-403 policy refusing an address.
    function setPolicyForbids(address account, bool forbidden) external {
        policyForbids[account] = forbidden;
    }

    /// Test-only. Marks an address as another TIP-20, so transfers to it are refused.
    function setIsTip20(address account, bool yes) external {
        isTip20[account] = yes;
    }

    function _guard(address from, address to) internal view {
        if (paused) revert TokenPaused();
        // Both ends are authorised, or the call reverts. TIP-20 spec: "Both checks must
        // return true, otherwise the call reverts with PolicyForbids."
        if (policyForbids[from]) revert PolicyForbids(from);
        if (policyForbids[to]) revert PolicyForbids(to);
        if (isTip20[to]) revert InvalidRecipient(to);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (paused) revert TokenPaused();
        if (policyForbids[msg.sender]) revert PolicyForbids(msg.sender);
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _move(msg.sender, to, value);
        return true;
    }

    /// The memo is emitted and otherwise inert. Nothing in this contract reads it back, and
    /// nothing in `RecknZkEscrow` can see it.
    function transferWithMemo(address to, uint256 value, bytes32 memo) external returns (bool) {
        _move(msg.sender, to, value);
        emit TransferWithMemo(msg.sender, to, value, memo);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a < value) revert InsufficientAllowance();
        if (a != type(uint256).max) allowance[from][msg.sender] = a - value;
        _move(from, to, value);
        return true;
    }

    function _move(address from, address to, uint256 value) internal {
        _guard(from, to);
        uint256 b = balanceOf[from];
        if (b < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = b - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {IUSDC3009} from "../../src/interfaces/IUSDC3009.sol";

/// @dev Test double that verifies a REAL EIP-3009 authorization the way USDC's
///      FiatTokenV2 does: the buyer (`from`) signs an off-chain
///      `ReceiveWithAuthorization` over EIP-712, and only the payee (`to`) may
///      submit it (`to == msg.sender`). This lets a third-party facilitator relay
///      a buyer's signed payment into the escrow without the buyer sending the
///      transaction, while the token — not the escrow — is what proves the buyer
///      authorized exactly this pull. Nonces are per-authorizer, matching the real
///      token's `_authorizationStates[authorizer][nonce]`.
contract MockUSDC3009 is IUSDC3009 {
    string public constant name = "USD Coin";
    string public constant version = "2";

    mapping(address => uint256) public override balanceOf;
    // authorizer => nonce => used
    mapping(address => mapping(bytes32 => bool)) public authorizationState;

    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

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
    ) external override {
        // EIP-3009 "receive" variant: only the payee may pull, so a signed
        // authorization cannot be redirected by whoever relays it.
        require(to == msg.sender, "3009: caller must be payee");
        require(block.timestamp > validAfter, "3009: auth not yet valid");
        require(block.timestamp < validBefore, "3009: auth expired");
        require(!authorizationState[from][nonce], "3009: nonce used");

        bytes32 structHash = keccak256(
            abi.encode(
                RECEIVE_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        // Low-s + valid-v guard, then the signer must be the authorizer.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "3009: bad s");
        require(v == 27 || v == 28, "3009: bad v");
        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == from, "3009: bad signature");

        require(balanceOf[from] >= value, "insufficient");
        authorizationState[from][nonce] = true;
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

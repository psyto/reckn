// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {DemoToken} from "./DemoToken.sol";

/// @notice The unlock dance, so a swap can be one transaction somebody sends.
/// @dev Demo scaffolding, not part of the claim: it holds the pool's tokens and settles what it
///      owes. `beforeAddLiquidity` is unflagged on the hook, so adding liquidity through here
///      never consults it — the gate is on trading.
contract PoolRouter is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager p) {
        pm = p;
    }

    function addLiquidity(PoolKey memory key, ModifyLiquidityParams memory p) external {
        pm.unlock(abi.encode(uint8(1), key, abi.encode(p)));
    }

    function swap(PoolKey memory key, SwapParams memory p) external {
        pm.unlock(abi.encode(uint8(2), key, abi.encode(p)));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(pm), "only the PoolManager");
        (uint8 action, PoolKey memory key, bytes memory inner) =
            abi.decode(data, (uint8, PoolKey, bytes));
        BalanceDelta delta;
        if (action == 1) {
            (delta,) = pm.modifyLiquidity(key, abi.decode(inner, (ModifyLiquidityParams)), "");
        } else {
            delta = pm.swap(key, abi.decode(inner, (SwapParams)), "");
        }
        _settle(key.currency0, delta.amount0());
        _settle(key.currency1, delta.amount1());
        return "";
    }

    function _settle(Currency c, int128 amount) internal {
        if (amount < 0) {
            pm.sync(c);
            DemoToken(Currency.unwrap(c)).transfer(address(pm), uint128(-amount));
            pm.settle();
        } else if (amount > 0) {
            pm.take(c, address(this), uint128(amount));
        }
    }
}

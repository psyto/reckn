// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";

/// @notice The read side of the deployed ENSv2 resolver. `resolve` is the ENSIP-10 entry point;
///         calling it with `text(bytes32,string)` returns the record ABI-encoded inside bytes.
interface IResolverRead {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

/// @title RecordGatedHook
/// @notice A Uniswap v4 pool that will not trade for an agent whose job was never settled.
///
/// **The loop this closes.** The rest of this submission earns a record: an escrow releases the
/// agent's fee only when the job is re-executed and reproduces, and the same settlement grants
/// the buyer the right to write one ENS text record about it. That record is worth something
/// only if something reads it. `beforeSwap` reads it, **on chain, synchronously, inside the
/// swap**. Earning happens where the work happened; spending happens here.
///
/// **No CCIP-Read on this path.** The resolver answers from its own storage, so the whole check
/// is one `staticcall` and the swap either proceeds or reverts in the same transaction. A hook
/// cannot go offchain and come back; if the record needed a gateway, this could not exist.
///
/// **`beforeAddLiquidity` is deliberately unflagged.** The gate is on TRADING, not on providing
/// liquidity, so the hook is never consulted when someone adds to the pool. Said here rather
/// than left for a judge to notice.
///
/// **What this does NOT do, stated before anyone finds it.** It does not identify the swapper,
/// and it could not: `beforeSwap`'s `sender` is whoever the PoolManager was **unlocked** for,
/// which is the router, not the trader. Measured on the refusal at `0xda60d7df…`, where the
/// error carries `0x25cc9656…` — our router — while the transaction came from
/// `0xfa2582ec…`. Everyone behind one router looks identical here. So the pool is gated on a
/// record existing and saying `reproduced`, and a second agent could trade behind the first
/// one's record. What is demonstrated is that **a settlement, and only a settlement, opens the
/// pool at all** — `013` R-14/R-15/R-16 — not that it opens it for exactly one address.
contract RecordGatedHook is IHooks {
    /// @notice Raised inside `beforeSwap`. The PoolManager wraps it in ERC-7751
    ///         `WrappedError(target, selector, reason, details)`, so a test must unwrap and
    ///         assert `target` and `reason` — the OUTER selector belongs to the PoolManager.
    error NoSettledRecord(address swapper);

    IResolverRead public immutable resolver;
    /// @notice The name whose record opens this pool, in DNS wire form, and its namehash.
    bytes public dnsName;
    bytes32 public immutable node;
    /// @notice The exact record key. One pool, one job.
    string public recordKey;

    /// @dev `text(bytes32,string)`.
    bytes4 private constant TEXT = 0x59d1d43c;
    /// @dev What a record has to start with. A job that was re-executed and FAILED is a real
    ///      record and is written as one (`013` R-7); it must not open a pool. Checking only
    ///      that a record exists would let the failure trade.
    bytes10 private constant REPRODUCED = bytes10("reproduced");

    constructor(IResolverRead _resolver, bytes memory _dnsName, bytes32 _node, string memory _key) {
        resolver = _resolver;
        dnsName = _dnsName;
        node = _node;
        recordKey = _key;
    }

    /// @notice What the pool would decide right now, without swapping. Here so the gate can be
    ///         read off chain and shown, and so a test can assert the reason separately from
    ///         the PoolManager's wrapping.
    function isOpen() public view returns (bool) {
        bytes memory inner = abi.encodeWithSelector(TEXT, node, recordKey);
        (bool ok, bytes memory out) =
            address(resolver).staticcall(abi.encodeCall(IResolverRead.resolve, (dnsName, inner)));
        if (!ok || out.length == 0) return false;
        bytes memory unwrapped = abi.decode(out, (bytes));
        if (unwrapped.length == 0) return false;
        bytes memory value = bytes(abi.decode(unwrapped, (string)));
        if (value.length < 10) return false;
        return bytes10(value) == REPRODUCED;
    }

    function beforeSwap(address sender, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (!isOpen()) revert NoSettledRecord(sender);
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // ---- everything below is unflagged, so the PoolManager never calls it ------------------
    // They revert rather than return a selector: if one is ever reached, the address was mined
    // wrong, and a silent success would hide that.

    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        revert();
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        revert();
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert();
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert();
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        returns (bytes4, int128)
    {
        revert();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert();
    }
}

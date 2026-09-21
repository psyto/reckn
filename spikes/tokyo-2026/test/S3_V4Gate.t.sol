// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {MiniProxy, AdapterStub, IEAC, IResolverDeployed} from "./S1_EacFromContract.t.sol";

/// S3 — does the record actually gate a Uniswap v4 pool?
///
/// Liquidity is deliberately NOT provided. `beforeSwap` runs before the swap body, so the
/// question "did the gate open" is answered by WHICH error comes back: ours, or the pool's.
/// This does not prove a full swap executes. Said here so no one later claims it did.
///
/// DISPOSABLE. Not ported.

/// @dev beforeSwap-only hook. Reverts unless the swapper's ENS record exists.
contract RecordGatedHook is IHooks {
    error NoSettledRecord(address swapper);

    IResolverDeployed public immutable resolver;
    bytes public dnsName;
    bytes32 public node;
    string public key;

    constructor(address r, bytes memory n, bytes32 nd, string memory k) {
        resolver = IResolverDeployed(r);
        dnsName = n;
        node = nd;
        key = k;
    }

    function beforeSwap(address sender, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bytes memory inner = abi.encodeWithSelector(bytes4(0x59d1d43c), node, key);
        (bool ok, bytes memory out) =
            address(resolver).staticcall(abi.encodeCall(IResolverDeployed.resolve, (dnsName, inner)));
        bool has;
        if (ok) {
            bytes memory unwrapped = abi.decode(out, (bytes));
            if (unwrapped.length > 0) {
                has = bytes(abi.decode(unwrapped, (string))).length > 0;
            }
        }
        if (!has) revert NoSettledRecord(sender);
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // Flags are off for everything below, so the PoolManager never calls them.
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        revert();
    }
    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        returns (bytes4)
    {
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
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure returns (bytes4) {
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

/// @dev The unlock dance: swaps must happen inside `unlock`.
contract SwapRouterStub is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager p) {
        pm = p;
    }

    function trySwap(PoolKey memory key, SwapParams memory params) external {
        pm.unlock(abi.encode(key, params));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        (PoolKey memory key, SwapParams memory params) = abi.decode(data, (PoolKey, SwapParams));
        pm.swap(key, params, "");
        return "";
    }
}

contract S3_V4Gate is Test {
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant RESOLVER_IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;

    uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;

    bytes dnsName = hex"056167656e74076578616d706c650365746800";
    string constant KEY = "reckn:jobs";
    address agent = address(0xA9E7);
    address client = address(0xBEEF);

    IPoolManager pm = IPoolManager(POOL_MANAGER);
    IResolverDeployed resolver;
    AdapterStub adapter;
    RecordGatedHook hook;
    SwapRouterStub router;
    PoolKey key_;

    function namehash() internal pure returns (bytes32 n) {
        n = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        n = keccak256(abi.encodePacked(n, keccak256("example")));
        n = keccak256(abi.encodePacked(n, keccak256("agent")));
    }

    function setUp() public {
        // 1. a Permissioned Resolver instance, adapter as its admin
        address inst = address(new MiniProxy(RESOLVER_IMPL));
        resolver = IResolverDeployed(inst);
        adapter = new AdapterStub(inst);
        IResolverDeployed.RoleAssignment[] memory ad = new IResolverDeployed.RoleAssignment[](1);
        ad[0] = IResolverDeployed.RoleAssignment(address(adapter), ALL_ROLES);
        resolver.initialize(ad, new bytes[](0));

        // 2. mine a hook address whose low bits are exactly BEFORE_SWAP_FLAG
        bytes memory args = abi.encode(inst, dnsName, namehash(), KEY);
        bytes memory initCode = abi.encodePacked(type(RecordGatedHook).creationCode, args);
        bytes32 initHash = keccak256(initCode);
        uint256 salt;
        for (salt = 0; salt < 500_000; salt++) {
            address predicted = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(bytes1(0xff), address(this), bytes32(salt), initHash)
                        )
                    )
                )
            );
            if (uint160(predicted) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG) break;
        }
        emit log_named_uint("hook salt found at", salt);
        hook = new RecordGatedHook{salt: bytes32(salt)}(inst, dnsName, namehash(), KEY);
        emit log_named_address("hook", address(hook));
        assertEq(uint160(address(hook)) & ALL_HOOK_MASK, BEFORE_SWAP_FLAG, "hook flags wrong");

        // 3. a pool on the REAL Sepolia PoolManager, with our hook
        key_ = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(0x1111111111111111111111111111111111111111)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        pm.initialize(key_, 79228162514264337593543950336); // 1:1
        emit log("pool initialized on the real Sepolia PoolManager");

        router = new SwapRouterStub(pm);
    }

    function _swap() internal {
        router.trySwap(
            key_,
            SwapParams({zeroForOne: true, amountSpecified: -1e6, sqrtPriceLimitX96: 4295128740})
        );
    }

    function test_gate_closed_then_open() public {
        // A — no record yet
        vm.prank(agent);
        try this.callSwap() {
            emit log("!! swap succeeded with no record - THE GATE IS NOT GATING");
            fail();
        } catch (bytes memory err) {
            bytes4 sel;
            assembly { sel := mload(add(err, 0x20)) }
            emit log_named_bytes32("outer selector (ERC-7751 WrappedError)", bytes32(sel));
            // WrappedError(address target, bytes4 selector, bytes reason, bytes details)
            (address target, bytes4 inner, bytes memory reason,) =
                abi.decode(_strip(err), (address, bytes4, bytes, bytes));
            emit log_named_address("  wrapped target", target);
            emit log_named_bytes32("  inner selector", bytes32(inner));
            emit log_named_bytes32(
                "  NoSettledRecord is", bytes32(RecordGatedHook.NoSettledRecord.selector)
            );
            assertEq(target, address(hook), "the revert did not come from our hook");
            bytes4 fromReason;
            assembly { fromReason := mload(add(reason, 0x20)) }
            assertEq(
                fromReason,
                RecordGatedHook.NoSettledRecord.selector,
                "the revert was NOT NoSettledRecord - the gate is not what refused"
            );
            emit log("CONFIRMED: the refusal is our hook's NoSettledRecord");
        }

        // B — the settlement writes the record
        bytes memory setter =
            abi.encodeWithSelector(IResolverDeployed.setText.selector, dnsName, KEY, "");
        adapter.openSetterWindow(setter, client);
        vm.prank(client);
        resolver.setText(dnsName, KEY, "1");
        emit log("record written by the client");

        // C — same swap again
        vm.prank(agent);
        try this.callSwap() {
            emit log("swap after record: SUCCEEDED");
        } catch (bytes memory err) {
            bytes4 sel;
            assembly { sel := mload(add(err, 0x20)) }
            emit log_named_bytes32("with-record swap revert selector", bytes32(sel));
            emit log("  if this differs from NoSettledRecord, the gate OPENED");
        }
    }

    function callSwap() external {
        _swap();
    }

    function _strip(bytes memory e) internal pure returns (bytes memory out) {
        out = new bytes(e.length - 4);
        for (uint256 i = 0; i < out.length; i++) out[i] = e[i + 4];
    }
}

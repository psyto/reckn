// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {RecordGatedHook} from "./S3_V4Gate.t.sol";
import {MiniProxy, AdapterStub, IResolverDeployed} from "./S1_EacFromContract.t.sol";

/// S6 — spec 013 Q6 / `R-15`: does a swap actually EXECUTE through the gate, moving tokens?
///
/// S3 measured only that `beforeSwap` stopped refusing, on an empty pool. That is not the same
/// claim and the spec says so. This provides liquidity and asserts balances.
///
/// DISPOSABLE. Not ported.

contract TestToken {
    string public name = "T";
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }
}

/// @dev Does the unlock dance for both liquidity and swaps, settling what it owes.
contract PoolRouter is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager p) {
        pm = p;
    }

    function addLiquidity(PoolKey memory key, ModifyLiquidityParams memory params) external {
        pm.unlock(abi.encode(uint8(1), key, abi.encode(params)));
    }

    function swap(PoolKey memory key, SwapParams memory params) external {
        pm.unlock(abi.encode(uint8(2), key, abi.encode(params)));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
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
            TestToken(Currency.unwrap(c)).transfer(address(pm), uint128(-amount));
            pm.settle();
        } else if (amount > 0) {
            pm.take(c, address(this), uint128(amount));
        }
    }
}

contract S6_FundedPool is Test {
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant RESOLVER_IMPL = 0x14F09Fd05d4585759e54844DC9B00147131Cf243;

    uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);
    uint256 constant ALL_ROLES =
        0x1111111111111111111111111111111111111111111111111111111111111111;

    bytes dnsName = hex"056167656e74076578616d706c650365746800";
    string constant KEY = "reckn:jobs";
    address client = address(0xBEEF);

    IPoolManager pm = IPoolManager(POOL_MANAGER);
    IResolverDeployed resolver;
    AdapterStub adapter;
    RecordGatedHook hook;
    PoolRouter router;
    PoolKey key_;
    TestToken t0;
    TestToken t1;

    function namehash() internal pure returns (bytes32 n) {
        n = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        n = keccak256(abi.encodePacked(n, keccak256("example")));
        n = keccak256(abi.encodePacked(n, keccak256("agent")));
    }

    function setUp() public {
        address inst = address(new MiniProxy(RESOLVER_IMPL));
        resolver = IResolverDeployed(inst);
        adapter = new AdapterStub(inst);
        IResolverDeployed.RoleAssignment[] memory ad = new IResolverDeployed.RoleAssignment[](1);
        ad[0] = IResolverDeployed.RoleAssignment(address(adapter), ALL_ROLES);
        resolver.initialize(ad, new bytes[](0));

        bytes memory initCode = abi.encodePacked(
            type(RecordGatedHook).creationCode, abi.encode(inst, dnsName, namehash(), KEY)
        );
        bytes32 initHash = keccak256(initCode);
        uint256 salt;
        for (salt = 0; salt < 500_000; salt++) {
            address p = address(
                uint160(
                    uint256(
                        keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(salt), initHash))
                    )
                )
            );
            if (uint160(p) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG) break;
        }
        hook = new RecordGatedHook{salt: bytes32(salt)}(inst, dnsName, namehash(), KEY);

        TestToken a = new TestToken();
        TestToken b = new TestToken();
        (t0, t1) = address(a) < address(b) ? (a, b) : (b, a);

        key_ = PoolKey({
            currency0: Currency.wrap(address(t0)),
            currency1: Currency.wrap(address(t1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        pm.initialize(key_, 79228162514264337593543950336);

        router = new PoolRouter(pm);
        t0.mint(address(router), 1_000_000 ether);
        t1.mint(address(router), 1_000_000 ether);

        // liquidity: beforeAddLiquidity is NOT flagged, so the hook is not consulted here
        router.addLiquidity(
            key_,
            ModifyLiquidityParams({
                tickLower: -600,
                tickUpper: 600,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            })
        );
        emit log("liquidity provided");
    }

    function _swap() internal {
        router.swap(
            key_,
            SwapParams({zeroForOne: true, amountSpecified: -1 ether, sqrtPriceLimitX96: 4295128740})
        );
    }

    function test_R15_the_gate_opens_and_tokens_actually_move() public {
        // A — refused, and refused by US
        try this.callSwap() {
            fail();
        } catch (bytes memory err) {
            (address target,, bytes memory reason,) =
                abi.decode(_strip(err), (address, bytes4, bytes, bytes));
            assertEq(target, address(hook), "not our hook that refused");
            bytes4 inner;
            assembly { inner := mload(add(reason, 0x20)) }
            assertEq(inner, RecordGatedHook.NoSettledRecord.selector, "not our error");
            emit log("A: refused by our hook's NoSettledRecord");
        }

        // B — the record is written
        bytes memory setter =
            abi.encodeWithSelector(IResolverDeployed.setText.selector, dnsName, KEY, "");
        adapter.openSetterWindow(setter, client);
        vm.prank(client);
        resolver.setText(dnsName, KEY, "1");

        // C — the same swap, and the balances must MOVE
        uint256 before0 = t0.balanceOf(address(router));
        uint256 before1 = t1.balanceOf(address(router));
        _swap();
        uint256 after0 = t0.balanceOf(address(router));
        uint256 after1 = t1.balanceOf(address(router));

        emit log_named_uint("token0 spent", before0 - after0);
        emit log_named_uint("token1 received", after1 - before1);
        assertLt(after0, before0, "token0 did not leave");
        assertGt(after1, before1, "token1 did not arrive");
        emit log("R-15: the swap EXECUTED through the gate and tokens moved");
    }

    /// R-16 — it is the record doing the gating, not something incidental about the caller.
    function test_R16_clearing_the_record_closes_the_pool_again() public {
        bytes memory setter =
            abi.encodeWithSelector(IResolverDeployed.setText.selector, dnsName, KEY, "");
        adapter.openSetterWindow(setter, client);
        vm.prank(client);
        resolver.setText(dnsName, KEY, "1");
        _swap();
        emit log("with the record: swap executes");

        vm.prank(client);
        resolver.setText(dnsName, KEY, "");
        try this.callSwap() {
            emit log("!! still open after the record was cleared");
            fail();
        } catch {
            emit log("R-16: record cleared -> the pool is closed to it again");
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

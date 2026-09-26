// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

import {RecknZkEscrow} from "@zk/RecknZkEscrow.sol";
import {MockUSDC} from "@zktest/mocks/MockUSDC.sol";
import {SettlementRecord, IPermissionedResolver} from "../src/SettlementRecord.sol";
import {RecordGatedHook, IResolverRead} from "../src/RecordGatedHook.sol";

interface IEAC3 {
    function grantRootRoles(uint256, address) external returns (bool);
}

contract TestToken {
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

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }
}

/// @dev The unlock dance. Liquidity and swaps both go through here; `beforeAddLiquidity` is
///      unflagged, so adding liquidity never consults the hook.
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

/// `013` §4-9 — the hook, on the real Sepolia PoolManager and the real deployed resolver.
///
/// **The whole loop runs inside this file.** A buyer funds a deal on the real escrow, a stranger
/// settles it on a real Groth16 proof, the real adapter opens the one window, and only then does
/// the pool trade. Nothing is stubbed on either side of the seam: the record the hook reads is
/// the record the settlement created.
///
/// **No root anywhere.** Earlier versions of this could have written the record by pranking the
/// account that still holds root on the resolver. That would have made the file stop working
/// the moment root is renounced tonight — a test that depends on the residue the project is
/// trying to remove. Every write below is the buyer using the role the settlement granted.
contract RecordGatedHookTest is Test {
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    RecknZkEscrow constant ESCROW = RecknZkEscrow(0x6d6a9deb67d785BC131a5d732617EABE751098C5);
    address constant VERIFIER = 0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608;
    address constant RESOLVER = 0x740e02cE9FB52629feF861CA02DF7091f416BBF8;
    address constant DEPLOYER = 0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321;
    uint256 constant ALL_ROLES = 0x1111111111111111111111111111111111111111111111111111111111111111;

    uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    string constant DIR = "../zk-verdict/contracts/";
    uint256 constant AMOUNT = 250_000000;

    IPoolManager pm = IPoolManager(POOL_MANAGER);
    SettlementRecord rec;
    RecordGatedHook hook;
    PoolRouter router;
    MockUSDC usdc;
    PoolKey poolKey;
    TestToken t0;
    TestToken t1;

    address buyer = makeAddr("buyer");
    address agent = makeAddr("agent-the-seller");
    bytes32 dealId;
    string key;
    uint8 outcome;

    function _dns() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), "agent", uint8(5), "reckn", uint8(3), "eth", uint8(0));
    }

    function _node() internal pure returns (bytes32 n) {
        n = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        n = keccak256(abi.encodePacked(n, keccak256("reckn")));
        n = keccak256(abi.encodePacked(n, keccak256("agent")));
    }

    function setUp() public {
        rec = new SettlementRecord(ESCROW, IPermissionedResolver(RESOLVER), _dns());
        usdc = new MockUSDC();
        usdc.mint(buyer, 10_000_000000);
        vm.prank(DEPLOYER);
        IEAC3(RESOLVER).grantRootRoles(ALL_ROLES, address(rec));

        // --- the settlement side: a real deal, a real proof, a stranger settling it ---------
        string memory json = vm.readFile(string.concat(DIR, "src/fixtures/reexec-groth16-fixture.json"));
        bytes memory pub = vm.parseJsonBytes(json, ".public_values");
        bytes memory prf = vm.parseJsonBytes(json, ".proof");
        bytes32 binding = vm.parseJsonBytes32(json, ".deal_binding");

        dealId = keccak256(abi.encodePacked("hook", binding, block.number));
        vm.startPrank(buyer);
        usdc.approve(address(ESCROW), AMOUNT);
        ESCROW.fund(dealId, agent, address(usdc), AMOUNT, VERIFIER, VERIFIER.codehash, binding);
        vm.stopPrank();
        vm.prank(address(0xDEAD));
        ESCROW.settleWithProof(dealId, pub, prf);
        (, outcome) = rec.open(dealId, pub, prf);
        key = rec.recordKey(dealId);

        // --- mine an address whose low 14 bits are EXACTLY beforeSwap ----------------------
        bytes memory initCode = abi.encodePacked(
            type(RecordGatedHook).creationCode,
            abi.encode(IResolverRead(RESOLVER), _dns(), _node(), key)
        );
        bytes32 initHash = keccak256(initCode);
        uint256 salt;
        for (salt = 0; salt < 500_000; ++salt) {
            address p = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(salt), initHash))))
            );
            if (uint160(p) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG) break;
        }
        hook = new RecordGatedHook{salt: bytes32(salt)}(IResolverRead(RESOLVER), _dns(), _node(), key);
        assertEq(uint160(address(hook)) & ALL_HOOK_MASK, BEFORE_SWAP_FLAG, "hook flags are wrong");

        // --- the pool ----------------------------------------------------------------------
        TestToken a = new TestToken();
        TestToken b = new TestToken();
        (t0, t1) = address(a) < address(b) ? (a, b) : (b, a);
        poolKey = PoolKey({
            currency0: Currency.wrap(address(t0)),
            currency1: Currency.wrap(address(t1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        pm.initialize(poolKey, SQRT_PRICE_1_1);

        router = new PoolRouter(pm);
        t0.mint(address(router), 1_000_000 ether);
        t1.mint(address(router), 1_000_000 ether);
        router.addLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: 100 ether, salt: bytes32(0)})
        );
    }

    // ------------------------------------------------------------------ helpers

    function _swap() internal {
        router.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -1 ether, sqrtPriceLimitX96: 4295128740})
        );
    }

    function callSwap() external {
        _swap();
    }

    /// @dev The buyer writing through the role the settlement granted. No root, ever.
    function _write(string memory value) internal {
        string memory k = key;
        bytes memory name = _dns();
        vm.prank(buyer);
        IPermissionedResolver(RESOLVER).setText(name, k, value);
    }

    function _goodValue() internal view returns (string memory) {
        return rec.recordValue(outcome, uint64(block.number), VERIFIER);
    }

    /// @dev Assert the swap was refused BY US. The PoolManager wraps the hook's revert in
    ///      ERC-7751 `WrappedError(address,bytes4,bytes,bytes)`; asserting the outer selector
    ///      would pass for any hook failing for any reason, which `013` §2.4 calls out by name.
    function _expectRefusedByOurHook() internal {
        try this.callSwap() {
            fail();
        } catch (bytes memory err) {
            bytes memory stripped = new bytes(err.length - 4);
            for (uint256 i = 4; i < err.length; ++i) stripped[i - 4] = err[i];
            (address target,, bytes memory reason,) =
                abi.decode(stripped, (address, bytes4, bytes, bytes));
            assertEq(target, address(hook), "something other than our hook refused the swap");
            bytes4 inner;
            assembly {
                inner := mload(add(reason, 0x20))
            }
            assertEq(inner, RecordGatedHook.NoSettledRecord.selector, "refused for the wrong reason");
        }
    }

    // ------------------------------------------------------------------ R-14

    /// R-14 — no record, no trade. The target and the reason are both asserted to be ours.
    function test_R14_a_swap_without_the_record_is_refused_by_our_hook() public {
        assertFalse(hook.isOpen(), "the pool is open before anything was written");
        _expectRefusedByOurHook();
    }

    // ------------------------------------------------------------------ R-15

    /// R-15 — the record is written by the settlement's own grant, and the SAME swap then
    /// executes on a funded pool. Balances have to move; a no-op on an empty pool is not this.
    function test_R15_with_the_record_the_swap_executes_and_tokens_move() public {
        _expectRefusedByOurHook();

        _write(_goodValue());
        assertTrue(hook.isOpen(), "the record was written and the pool is still shut");

        uint256 before0 = t0.balanceOf(address(router));
        uint256 before1 = t1.balanceOf(address(router));
        _swap();
        uint256 after0 = t0.balanceOf(address(router));
        uint256 after1 = t1.balanceOf(address(router));

        emit log_named_uint("token0 spent   ", before0 - after0);
        emit log_named_uint("token1 received", after1 - before1);
        assertLt(after0, before0, "token0 did not leave");
        assertGt(after1, before1, "token1 did not arrive");
    }

    // ------------------------------------------------------------------ R-16

    /// R-16 — it is the record doing the gating. Clearing it shuts the same pool to the same
    /// caller again, and it is refused for OUR reason, not merely refused.
    function test_R16_clearing_the_record_closes_the_pool_again() public {
        _write(_goodValue());
        _swap(); // control arm: it really was open

        _write("");
        assertFalse(hook.isOpen(), "the record was cleared and the pool is still open");
        _expectRefusedByOurHook();
    }

    // ------------------------------------------------------------------ R-7 on this surface

    /// A job that was re-executed and FAILED is a real record and is written as one. It must
    /// not open a pool. Checking only that a record EXISTS would let the failure trade, which
    /// is the highlight-reel failure `013` R-7 forbids one layer down.
    function test_a_failed_record_does_not_open_the_pool() public {
        _write(rec.recordValue(1, uint64(block.number), VERIFIER));
        assertEq(_first6(), "failed", "the fixture for this row is not a failed record");
        assertFalse(hook.isOpen(), "a failed job opened the pool");
        _expectRefusedByOurHook();
    }

    function _first6() internal view returns (string memory) {
        bytes memory b = bytes(rec.recordValue(1, uint64(block.number), VERIFIER));
        bytes memory o = new bytes(6);
        for (uint256 i; i < 6; ++i) o[i] = b[i];
        return string(o);
    }
}

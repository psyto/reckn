// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";

import {RecknZkEscrow} from "@zk/RecknZkEscrow.sol";
import {SettlementRecord, IPermissionedResolver} from "../src/SettlementRecord.sol";
import {RecordGatedHook, IResolverRead} from "../src/RecordGatedHook.sol";
import {DemoToken} from "../src/demo/DemoToken.sol";
import {PoolRouter} from "../src/demo/PoolRouter.sol";

interface IERC20Min {
    function approve(address, uint256) external returns (bool);
}

interface IMintable {
    function mint(address, uint256) external;
}

/// Put the gate on the real chain.
///
/// **Why a script and not a list of `cast send` lines.** Sixteen transactions is sixteen keystore
/// prompts, and the hook's constructor argument is a record key that does not exist until the
/// window is opened three transactions earlier. Grouped into two broadcasts, it is two prompts,
/// and the key is computed rather than pasted.
///
/// The deal is settled and its window opened, but **nothing is written**. That is the point: the
/// pool has to be seen refusing before it is seen passing, and a record that already exists
/// cannot be filmed arriving.
contract HookOnchain is Script {
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    RecknZkEscrow constant ESCROW = RecknZkEscrow(0x6d6a9deb67d785BC131a5d732617EABE751098C5);
    address constant VERIFIER = 0xe0dE264D76f0664C4e943fc02e3D9FB46CD27608;
    address constant RESOLVER = 0x740e02cE9FB52629feF861CA02DF7091f416BBF8;
    address constant ADAPTER = 0xA6966f9f5E72a1841b2d2A22Ec62a23D703202b8;
    address constant USDC = 0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e;
    address constant AGENT = 0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321;
    // NOTE: forge-std's Base.sol already declares CREATE2_FACTORY; it is the deterministic
    // deployer 0x4e59b448…, and foundry broadcasts `new X{salt:…}` through it. The mined
    // address must therefore be computed against THAT address and not against the sender.

    uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 constant AMOUNT = 250_000000;
    /// @dev Relative to this project root; `fs_permissions` in foundry.toml allows exactly this.
    /// @dev Relative to this project root; `fs_permissions` in foundry.toml allows exactly this.
    ///      Both are overridable so the SAME code can stand up a second, independent pool
    ///      without a copy of this file drifting away from the one that was measured.
    function out() internal view returns (string memory) {
        return vm.envOr("HOOK_OUT", string("./hook-onchain.json"));
    }

    function dealId() public view returns (bytes32) {
        return keccak256(bytes(vm.envOr("DEAL_TAG", string("reckn-tokyo-hook-1"))));
    }

    function _dns() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), "agent", uint8(5), "reckn", uint8(3), "eth", uint8(0));
    }

    function _node() internal pure returns (bytes32 n) {
        n = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        n = keccak256(abi.encodePacked(n, keccak256("reckn")));
        n = keccak256(abi.encodePacked(n, keccak256("agent")));
    }

    function _fixture() internal view returns (bytes memory pub, bytes memory prf, bytes32 binding) {
        string memory j = vm.readFile("../zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json");
        pub = vm.parseJsonBytes(j, ".public_values");
        prf = vm.parseJsonBytes(j, ".proof");
        binding = vm.parseJsonBytes32(j, ".deal_binding");
    }

    // ------------------------------------------------------------------ stage 1 [reckn-buyer]

    /// The buyer funds the deal that will earn the record. One prompt.
    function stage1() external {
        (,, bytes32 binding) = _fixture();
        vm.startBroadcast();
        // The buyer spent its last MockUSDC on the event-proof deal. Minting is open to anyone
        // on this mock, which is also why the playground pool can be traded by a stranger.
        IMintable(USDC).mint(msg.sender, AMOUNT);
        IERC20Min(USDC).approve(address(ESCROW), AMOUNT);
        ESCROW.fund(dealId(), AGENT, USDC, AMOUNT, VERIFIER, VERIFIER.codehash, binding);
        vm.stopBroadcast();
    }

    // ------------------------------------------------------------------ stage 2 [reckn-agent]

    /// Settle it, open the window, and stand up the pool the record will open. One prompt.
    /// **Nothing is written here** — the refusal has to be filmable.
    function stage2() external {
        (bytes memory pub, bytes memory prf,) = _fixture();
        SettlementRecord rec = SettlementRecord(ADAPTER);

        vm.startBroadcast();
        ESCROW.settleWithProof(dealId(), pub, prf);
        rec.open(dealId(), pub, prf);
        vm.stopBroadcast();

        string memory key = rec.recordKey(dealId());

        // mine against the CREATE2 factory, because that is who will deploy it
        bytes32 initHash = keccak256(
            abi.encodePacked(
                type(RecordGatedHook).creationCode,
                abi.encode(IResolverRead(RESOLVER), _dns(), _node(), key)
            )
        );
        uint256 salt;
        address predicted;
        for (salt = 0; salt < 2_000_000; ++salt) {
            predicted = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, bytes32(salt), initHash))))
            );
            if (uint160(predicted) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG) break;
        }
        require(uint160(predicted) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG, "no salt found");

        vm.startBroadcast();
        DemoToken a = new DemoToken("Reckn Demo A");
        DemoToken b = new DemoToken("Reckn Demo B");
        RecordGatedHook hook =
            new RecordGatedHook{salt: bytes32(salt)}(IResolverRead(RESOLVER), _dns(), _node(), key);
        PoolRouter router = new PoolRouter(IPoolManager(POOL_MANAGER));

        (DemoToken t0, DemoToken t1) = address(a) < address(b) ? (a, b) : (b, a);
        t0.mint(address(router), 1_000_000 ether);
        t1.mint(address(router), 1_000_000 ether);

        PoolKey memory key_ = PoolKey({
            currency0: Currency.wrap(address(t0)),
            currency1: Currency.wrap(address(t1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        IPoolManager(POOL_MANAGER).initialize(key_, SQRT_PRICE_1_1);
        router.addLiquidity(
            key_,
            ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: 100 ether, salt: bytes32(0)})
        );
        vm.stopBroadcast();

        // The address is READ back, not trusted from the prediction.
        require(address(hook) == predicted, "the hook did not land where it was mined");
        require(uint160(address(hook)) & ALL_HOOK_MASK == BEFORE_SWAP_FLAG, "hook flags are wrong");
        require(!hook.isOpen(), "the pool is open before anything was written");

        string memory o = "o";
        vm.serializeBytes32(o, "dealId", dealId());
        vm.serializeString(o, "recordKey", key);
        vm.serializeAddress(o, "hook", address(hook));
        vm.serializeAddress(o, "router", address(router));
        vm.serializeAddress(o, "token0", address(t0));
        vm.serializeAddress(o, "token1", address(t1));
        vm.serializeUint(o, "salt", salt);
        vm.writeJson(vm.serializeUint(o, "fee", 3000), out());
    }
}

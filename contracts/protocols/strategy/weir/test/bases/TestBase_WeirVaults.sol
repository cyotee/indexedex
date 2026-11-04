// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FixedPoint96} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WeirVaults} from "../../WeirVaults.sol";
import {WeirPoolRouter} from "../peripherals/WeirPoolRouter.sol";
import {WeirCallRouter} from "../peripherals/WeirCallRouter.sol";
import {WeirObserveHook} from "../peripherals/WeirObserveHook.sol";
import {WeirReturnDeltaHook} from "../peripherals/WeirReturnDeltaHook.sol";

abstract contract TestBase_WeirVaults is CraneTest {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 internal constant K = 2 ** 20;
    uint256 internal constant F0_SHARES = 1_047_576;
    uint256 internal constant F0_OUT = 1_047_575;

    IPoolManager internal poolManager;
    WeirVaults internal weir;
    address internal treasury;
    address internal owner;
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;
    SimpleMintableERC20 internal tokenC;
    WeirPoolRouter internal poolRouter;
    WeirCallRouter internal callRouter;

    function setUp() public virtual override {
        CraneTest.setUp();
        if (treasury == address(0)) {
            treasury = makeAddr("treasury");
            owner = makeAddr("owner");
            vm.label(treasury, "treasury");
            vm.label(owner, "owner");
        }
        if (address(poolManager) == address(0)) {
            poolManager = new PoolManager(address(this));
            vm.label(address(poolManager), "PoolManager");
        }
        if (address(weir) == address(0)) {
            weir = new WeirVaults(poolManager, treasury, owner);
            vm.label(address(weir), "WeirVaults");
        }
        if (address(tokenA) == address(0)) {
            tokenA = new SimpleMintableERC20("TokenA", "TKA");
            tokenB = new SimpleMintableERC20("TokenB", "TKB");
            tokenC = new SimpleMintableERC20("TokenC", "TKC");
            vm.label(address(tokenA), "tokenA");
            vm.label(address(tokenB), "tokenB");
            vm.label(address(tokenC), "tokenC");
        }
        if (address(poolRouter) == address(0)) {
            poolRouter = new WeirPoolRouter(poolManager);
            callRouter = new WeirCallRouter(poolManager);
            vm.label(address(poolRouter), "WeirPoolRouter");
            vm.label(address(callRouter), "WeirCallRouter");
        }
    }

    function snap() internal returns (uint256) {
        return vm.snapshotState();
    }

    function restore(uint256 id) internal {
        assertTrue(vm.revertToState(id));
    }

    function deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function sorted(address a, address b) internal pure returns (address c0, address c1) {
        (c0, c1) = a < b ? (a, b) : (b, a);
    }

    function ercKey(address a, address b, uint24 fee, int24 spacing, IHooks hooks) internal pure returns (PoolKey memory key) {
        (address c0, address c1) = sorted(a, b);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: fee,
            tickSpacing: spacing,
            hooks: hooks
        });
    }

    function f0Key() internal view returns (PoolKey memory) {
        return ercKey(address(tokenA), address(tokenB), 0, 1, IHooks(address(0)));
    }

    function initHookless(PoolKey memory key, uint160 sqrtP) internal returns (PoolId id) {
        poolManager.initialize(key, sqrtP);
        id = key.toId();
        (uint160 price,, uint24 protocolFee,) = poolManager.getSlot0(id);
        assertEq(price, sqrtP);
        assertEq(protocolFee, 0);
    }

    function f0Sqrt() internal pure returns (uint160) {
        return TickMath.getSqrtPriceAtTick(0);
    }

    function initF0() internal returns (PoolKey memory key, PoolId id) {
        uint160 price = f0Sqrt();
        assertEq(price, uint160(FixedPoint96.Q96));
        key = f0Key();
        id = initHookless(key, price);
    }

    function fund(address user, SimpleMintableERC20 token, uint256 amount, address spender) internal {
        token.mint(user, amount);
        vm.prank(user);
        token.approve(spender, type(uint256).max);
    }

    function mineHook(uint160 flags, bytes memory creationCode, bytes memory args)
        internal
        returns (address predicted, bytes32 salt)
    {
        (predicted, salt) = HookMiner.find(address(this), flags, creationCode, args);
    }

    function observeFlags() internal pure returns (uint160) {
        return Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
    }

    function returnDeltaFlags() internal pure returns (uint160) {
        return observeFlags() | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
    }
}

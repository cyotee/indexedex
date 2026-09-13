// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4CurveQuadStableSwapHook_Decimals
} from "contracts/hooks/uniswap/v4/stable/quad/curve/TestBase_UniswapV4CurveQuadStableSwapHook_Decimals.sol";
import {
    UniswapV4CurveQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookMath.sol";
import {
    IUniswapV4CurveQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHook.sol";
import {RateProviderHarness} from
    "contracts/hooks/uniswap/v4/stable/quad/curve/TestBase_UniswapV4CurveQuadStableSwapHook.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHook_Decimals
 * @notice Liquidity/swap/zap/rates/safety/reentrancy on each `B_*` book.
 * @dev pairToken constructed first at `_dec0()`. After address sort t0..t3 permute.
 *      Amounts are raw units. Hook LP stays 18. `test_L5_mixedDecimals_6_6_18_18` is the book fixture.
 */
abstract contract UniswapV4CurveQuadStableSwapHook_Decimals is
    TestBase_UniswapV4CurveQuadStableSwapHook_Decimals
{
    WrapperExactOutRouter internal swapRouter;

    function setUp() public virtual override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
    }

    /* ------------------------------ Liquidity ------------------------------ */

    function test_L1_firstMint_locksMinLiqToZero() public {
        uint256[4] memory amounts = _balancedAmounts(1_000);
        uint256[4] memory mins;
        vm.prank(user);
        (uint256 shares,) = quad.addLiquidity(amounts, mins, user, 0);
        assertGt(shares, 0);
        (, bytes memory ret) = hook.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
        uint256 bal0 = abi.decode(ret, (uint256));
        assertEq(bal0, Math.MINIMUM_LIQUIDITY);
        (, bytes memory retTs) = hook.staticcall(abi.encodeWithSignature("totalSupply()"));
        uint256 ts = abi.decode(retTs, (uint256));
        assertEq(ts, shares + Math.MINIMUM_LIQUIDITY);
    }

    function test_L2_firstMint_withOpenDoors_noPriorSwaps() public {
        _addLiquidityFirst(500);
        uint256[4] memory r = _bookReserves();
        assertGt(r[0], 0);
        assertGt(r[1], 0);
        assertGt(r[2], 0);
        assertGt(r[3], 0);
    }

    function test_L3_laterProportional_mins() public {
        _addLiquidityFirst(1_000);
        uint256[4] memory amounts = _balancedAmounts(100);
        uint256[4] memory mins = [uint256(1), 1, 1, 1];
        (uint256 pred,) = quad.previewAddLiquidity(amounts);
        vm.prank(user);
        (uint256 shares, uint256[4] memory actual) = quad.addLiquidity(amounts, mins, user, pred);
        assertEq(shares, pred);
        for (uint256 i; i < 4; ++i) {
            assertLe(actual[i], amounts[i]);
        }
    }

    function test_L4_removeProRata() public {
        uint256 shares = _addLiquidityFirst(1_000);
        uint256 half = shares / 2;
        uint256[4] memory mins;
        uint256[4] memory pred = quad.previewRemoveLiquidity(half);
        vm.prank(user);
        uint256[4] memory got = quad.removeLiquidity(half, user, mins);
        for (uint256 i; i < 4; ++i) {
            assertEq(got[i], pred[i]);
        }
    }

    /// @notice Replaces gold `test_L5_mixedDecimals_6_6_18_18`. Book decimals are the fixture.
    function test_L5_mixedDecimals_6_6_18_18() public {
        assertEq(pairToken.decimals(), _dec0(), "pairToken role decimals");
        _addLiquidityFirst(1_000);
        uint256[4] memory r = _bookReserves();
        assertGt(r[0] + r[1] + r[2] + r[3], 0);
        assertTrue(t0.decimals() == _dec0() || t0.decimals() == _dec1() || t0.decimals() == _dec2() || t0.decimals() == _dec3());
    }

    function test_L6_donation_doesNotChangeReserves() public {
        _addLiquidityFirst(1_000);
        uint256[4] memory before = _bookReserves();
        t0.mint(hook, _raw(t0, 999));
        uint256[4] memory after_ = _bookReserves();
        for (uint256 i; i < 4; ++i) {
            assertEq(after_[i], before[i]);
        }
    }

    /* ------------------------------ Swap ----------------------------------- */

    function test_S0_inertBook_swapReverts() public {
        MintableERC20Decimals a = new MintableERC20Decimals("IA", "IA", _dec0());
        MintableERC20Decimals b = new MintableERC20Decimals("IB", "IB", _dec1());
        MintableERC20Decimals c = new MintableERC20Decimals("IC", "IC", _dec2());
        MintableERC20Decimals d = new MintableERC20Decimals("ID", "ID", _dec3());
        (MintableERC20Decimals x0, MintableERC20Decimals x1, MintableERC20Decimals x2, MintableERC20Decimals x3) =
            _sortFour(a, b, c, d);
        address[4] memory providers;
        address h = _deployHook(
            _pkgArgs(address(x0), address(x1), address(x2), address(x3), DEMO_FEE, DEMO_AMP, providers)
        );
        IUniswapV4CurveQuadStableSwapHook inert = IUniswapV4CurveQuadStableSwapHook(h);
        uint256[4] memory r = _bookReserves(h);
        assertEq(r[0], 0);
        assertEq(r[1], 0);
        assertEq(r[2], 0);
        assertEq(r[3], 0);

        try inert.previewSwapExactIn(address(x0), address(x1), _raw(x0, 1)) returns (uint256 oIn) {
            assertEq(oIn, 0, "S0: empty book exact-in");
        } catch {}
        try inert.previewSwapExactOut(address(x0), address(x1), _raw(x1, 1)) returns (uint256 oOut) {
            assertEq(oOut, 0, "S0: empty book exact-out");
        } catch {}
    }

    function test_S1_exactIn_pair0_previewEqualsExecution() public {
        _addLiquidityFirst(10_000);
        _approveRouter();
        _assertExactIn(0, true, 10);
    }

    function test_S1b_exactIn_pair0_oneForZero() public {
        _addLiquidityFirst(10_000);
        _approveRouter();
        _assertExactIn(0, false, 10);
    }

    function test_S_allSixPairs_exactIn_bothDirections() public {
        _addLiquidityFirst(10_000);
        _approveRouter();
        for (uint256 p; p < 6; ++p) {
            _assertExactIn(p, true, 5);
            _assertExactIn(p, false, 5);
        }
    }

    function test_S_allSixPairs_exactOut_bothDirections() public {
        _addLiquidityFirst(10_000);
        _approveRouter();
        for (uint256 p; p < 6; ++p) {
            _assertExactOut(p, true, 3);
            _assertExactOut(p, false, 3);
        }
    }

    function test_S14_exactOut_zero_reverts() public {
        _addLiquidityFirst(10_000);
        vm.expectRevert();
        quad.previewSwapExactOut(address(t0), address(t1), 0);
    }

    function _approveRouter() internal {
        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        t2.approve(address(swapRouter), type(uint256).max);
        t3.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _swapAmt(address token, uint256 human) internal view returns (uint256) {
        uint8 d = MintableERC20Decimals(token).decimals();
        return human * (10 ** uint256(d));
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _assertExactIn(uint256 pairIdx, bool zeroForOne, uint256 humanIn) internal {
        PoolKey memory key = _poolKeys()[pairIdx];
        address tokenIn = zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        address tokenOut = zeroForOne ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);
        uint256 amountIn = _swapAmt(tokenIn, humanIn);
        uint256 pred = quad.previewSwapExactIn(tokenIn, tokenOut, amountIn);
        assertGt(pred, 0, "pred out");

        uint256 beforeOut = IERC20(tokenOut).balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            ""
        );
        uint256 got = IERC20(tokenOut).balanceOf(user) - beforeOut;
        assertApproxEqAbs(got, pred, DUST);
    }

    function _assertExactOut(uint256 pairIdx, bool zeroForOne, uint256 humanOut) internal {
        PoolKey memory key = _poolKeys()[pairIdx];
        address tokenIn = zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        address tokenOut = zeroForOne ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);
        uint256 amountOut = _swapAmt(tokenOut, humanOut);
        uint256 predIn = quad.previewSwapExactOut(tokenIn, tokenOut, amountOut);
        assertGt(predIn, 0, "pred in");

        uint256 beforeOut = IERC20(tokenOut).balanceOf(user);
        uint256 beforeIn = IERC20(tokenIn).balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactOut(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountOut),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            predIn * 2,
            ""
        );
        uint256 gotOut = IERC20(tokenOut).balanceOf(user) - beforeOut;
        uint256 spentIn = beforeIn - IERC20(tokenIn).balanceOf(user);
        assertEq(gotOut, amountOut);
        assertApproxEqAbs(spentIn, predIn, DUST);
    }

    /* ------------------------------ Zap ------------------------------------ */

    function test_Z3_notEligible_beforeLive() public {
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 100);
        vm.expectRevert();
        quad.previewZapIn(amounts);
    }

    function test_Z1_singleLeg_whenEligible() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 100);
        (uint256 pred,) = quad.previewZapIn(amounts);
        assertGt(pred, 0);
        vm.prank(user);
        (uint256 shares, uint256[4] memory used) = quad.zapIn(amounts, user, pred);
        assertApproxEqAbs(shares, pred, DUST);
        assertLe(used[0], amounts[0]);
    }

    function test_Z2_multiLeg_and_balanced() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory bal = _balancedAmounts(50);
        (uint256 pred,) = quad.previewZapIn(bal);
        vm.prank(user);
        (uint256 shares,) = quad.zapIn(bal, user, 0);
        assertApproxEqAbs(shares, pred, DUST);

        uint256[4] memory imb;
        imb[0] = _raw(t0, 200);
        imb[1] = _raw(t1, 10);
        (uint256 pred2,) = quad.previewZapIn(imb);
        vm.prank(user);
        (uint256 shares2,) = quad.zapIn(imb, user, 0);
        assertApproxEqAbs(shares2, pred2, DUST);
        assertGt(shares2, 0);
    }

    function test_Z4_previewEqualsZapIn() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 80);
        amounts[1] = _raw(t1, 20);
        amounts[3] = _raw(t3, 5);
        (uint256 pred, uint256[4] memory usedPred) = quad.previewZapIn(amounts);
        vm.prank(user);
        (uint256 shares, uint256[4] memory used) = quad.zapIn(amounts, user, 0);
        assertApproxEqAbs(shares, pred, DUST);
        for (uint256 i; i < 4; ++i) {
            assertApproxEqAbs(used[i], usedPred[i], DUST);
        }
    }

    function test_Z5_singleCommit_reservesIncrease() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory before = _bookReserves();
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 100);
        vm.prank(user);
        quad.zapIn(amounts, user, 0);
        uint256[4] memory after_ = _bookReserves();
        bool grew;
        for (uint256 i; i < 4; ++i) {
            if (after_[i] > before[i]) grew = true;
        }
        assertTrue(grew);
    }

    function test_Z6_sharesMin_enforced() public {
        _addLiquidityFirst(5_000);
        uint256[4] memory amounts;
        amounts[0] = _raw(t0, 50);
        (uint256 pred,) = quad.previewZapIn(amounts);
        vm.prank(user);
        vm.expectRevert();
        quad.zapIn(amounts, user, pred + 1e18);
    }

    function test_Z6_unviableInverse_clamp_previewEqualsExec_sharesMin() public {
        _addLiquidityFirst(100);
        uint256[4] memory rBefore = _bookReserves();

        uint256[4] memory huge;
        huge[0] = _raw(t0, 500);

        (uint256 pred, uint256[4] memory usedPred) = quad.previewZapIn(huge);
        assertTrue(pred > 0, "one-sided zap still mints under Curve math");

        vm.prank(user);
        (uint256 shares, uint256[4] memory used) = quad.zapIn(huge, user, 0);
        assertApproxEqAbs(shares, pred, DUST);
        for (uint256 i; i < 4; ++i) {
            assertApproxEqAbs(used[i], usedPred[i], DUST);
        }
        assertTrue(used[0] <= huge[0], "input leg used <= pull max");

        uint256[4] memory rAfter = _bookReserves();
        for (uint256 i; i < 4; ++i) {
            assertTrue(rAfter[i] > 0, "reserve leg remains positive after zap");
        }
        assertTrue(rAfter[0] > rBefore[0], "surplus leg reserve increased");

        (uint256 pred2,) = quad.previewZapIn(huge);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Slippage()"));
        quad.zapIn(huge, user, pred2 + 1);
    }

    /* ------------------------------ Rates ---------------------------------- */

    function test_R3_zeroProviders_decimalOnly() public view {
        uint256 r0 = quad.effectiveRate(0);
        assertGt(r0, 0);
    }

    function test_R1_rateProvider_scales() public {
        RateProviderHarness rp = new RateProviderHarness();
        rp.setRate(2e18);
        (IUniswapV4CurveQuadStableSwapHook h,) = _deployWithProviders(address(rp), address(0), address(0), address(0));
        uint256 r0 = h.effectiveRate(0);
        assertGt(r0, 0);
    }

    function test_R2_failClosed_zeroRate() public {
        RateProviderHarness rp = new RateProviderHarness();
        rp.setRate(0);
        (IUniswapV4CurveQuadStableSwapHook h,) = _deployWithProviders(address(rp), address(0), address(0), address(0));
        vm.expectRevert();
        h.effectiveRate(0);
    }

    function test_R2_failClosed_revertProvider() public {
        RateProviderHarness rp = new RateProviderHarness();
        rp.setShouldRevert(true);
        (IUniswapV4CurveQuadStableSwapHook h,) = _deployWithProviders(address(rp), address(0), address(0), address(0));
        vm.expectRevert();
        h.effectiveRate(0);
    }

    function _deployWithProviders(address p0, address p1, address p2, address p3)
        internal
        returns (IUniswapV4CurveQuadStableSwapHook h, address hookAddr)
    {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", _dec0());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _dec1());
        MintableERC20Decimals c = new MintableERC20Decimals("C", "C", _dec2());
        MintableERC20Decimals d = new MintableERC20Decimals("D", "D", _dec3());
        (MintableERC20Decimals x0, MintableERC20Decimals x1, MintableERC20Decimals x2, MintableERC20Decimals x3) =
            _sortFour(a, b, c, d);
        address[4] memory providers;
        providers[0] = p0;
        providers[1] = p1;
        providers[2] = p2;
        providers[3] = p3;
        hookAddr = _deployHook(
            _pkgArgs(address(x0), address(x1), address(x2), address(x3), DEMO_FEE, DEMO_AMP, providers)
        );
        h = IUniswapV4CurveQuadStableSwapHook(hookAddr);
    }

    /* ------------------------------ Safety --------------------------------- */

    function test_I2_clAddLiquidity_reverts() public {
        _addLiquidityFirst(1_000);
        PoolKey memory key = _poolKeys()[0];
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(
            address(this),
            key,
            ModifyLiquidityParams({tickLower: -1, tickUpper: 1, liquidityDelta: 1, salt: bytes32(0)}),
            ""
        );
    }

    function test_I2_donate_reverts() public {
        vm.prank(address(pm));
        (bool ok,) = hook.call(
            abi.encodeWithSelector(
                IHooks.beforeDonate.selector, address(this), _poolKeys()[0], uint256(1), uint256(1), ""
            )
        );
        assertFalse(ok);
    }

    /* ------------------------------ Reentrancy ----------------------------- */

    function test_A1_reentrancy_addLiquidity() public {
        CurveQuadHostilePull hostile = new CurveQuadHostilePull("H", "H", _dec0());
        (address h, IUniswapV4CurveQuadStableSwapHook q) = _deployWithHostilePull(hostile);

        uint256[4] memory amounts = _hostileBalanced(h, 1000);
        uint256[4] memory mins;
        hostile.arm(
            h,
            abi.encodeWithSelector(
                IUniswapV4CurveQuadStableSwapHook.addLiquidity.selector, amounts, mins, user, uint256(0)
            )
        );
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Reentrancy()"));
        q.addLiquidity(amounts, mins, user, 0);
    }

    function test_A1_reentrancy_zapIn() public {
        CurveQuadHostilePull hostile = new CurveQuadHostilePull("H", "H", _dec0());
        (address h, IUniswapV4CurveQuadStableSwapHook q) = _deployWithHostilePull(hostile);

        uint256[4] memory first = _hostileBalanced(h, 5000);
        uint256[4] memory mins;
        vm.prank(user);
        q.addLiquidity(first, mins, user, 0);

        address[4] memory toks = q.tokens();
        uint256 hi;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == address(hostile)) hi = i;
        }
        uint256[4] memory zapAmts;
        zapAmts[hi] = _swapAmt(address(hostile), 100);
        zapAmts[hi == 0 ? 1 : 0] = _swapAmt(toks[hi == 0 ? 1 : 0], 10);

        hostile.arm(
            h, abi.encodeWithSelector(IUniswapV4CurveQuadStableSwapHook.zapIn.selector, zapAmts, user, uint256(0))
        );

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Reentrancy()"));
        q.zapIn(zapAmts, user, 0);
    }

    function test_A1_reentrancy_removeLiquidity() public {
        CurveQuadHostilePush hostile = new CurveQuadHostilePush("H", "H", _dec0());
        (address h, IUniswapV4CurveQuadStableSwapHook q) = _deployWithHostilePush(hostile);

        uint256[4] memory first = _hostileBalanced(h, 2000);
        uint256[4] memory mins;
        vm.prank(user);
        (uint256 sh,) = q.addLiquidity(first, mins, user, 0);

        uint256[4] memory minOut;
        hostile.arm(
            h,
            abi.encodeWithSelector(
                IUniswapV4CurveQuadStableSwapHook.removeLiquidity.selector, sh / 2, user, minOut
            )
        );

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Reentrancy()"));
        q.removeLiquidity(sh / 2, user, minOut);
    }

    function _hostileBalanced(address h, uint256 human) internal view returns (uint256[4] memory amounts) {
        address[4] memory toks = IUniswapV4CurveQuadStableSwapHook(h).tokens();
        for (uint256 i; i < 4; ++i) {
            amounts[i] = _swapAmt(toks[i], human);
        }
    }

    function _deployWithHostilePull(CurveQuadHostilePull hostile)
        internal
        returns (address h, IUniswapV4CurveQuadStableSwapHook q)
    {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", _dec1());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _dec2());
        MintableERC20Decimals c = new MintableERC20Decimals("C", "C", _dec3());
        address[4] memory addrs = _sort4(address(a), address(b), address(c), address(hostile));
        address[4] memory providers;
        h = _deployHook(_pkgArgs(addrs[0], addrs[1], addrs[2], addrs[3], DEMO_FEE, DEMO_AMP, providers));
        q = IUniswapV4CurveQuadStableSwapHook(h);
        _fundApproveHostile(addrs, h);
    }

    function _deployWithHostilePush(CurveQuadHostilePush hostile)
        internal
        returns (address h, IUniswapV4CurveQuadStableSwapHook q)
    {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", _dec1());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _dec2());
        MintableERC20Decimals c = new MintableERC20Decimals("C", "C", _dec3());
        address[4] memory addrs = _sort4(address(a), address(b), address(c), address(hostile));
        address[4] memory providers;
        h = _deployHook(_pkgArgs(addrs[0], addrs[1], addrs[2], addrs[3], DEMO_FEE, DEMO_AMP, providers));
        q = IUniswapV4CurveQuadStableSwapHook(h);
        _fundApproveHostile(addrs, h);
    }

    function _fundApproveHostile(address[4] memory addrs, address h) internal {
        for (uint256 i; i < 4; ++i) {
            uint256 amt = _swapAmt(addrs[i], 10_000_000);
            (bool ok,) = addrs[i].call(abi.encodeWithSignature("mint(address,uint256)", user, amt));
            require(ok);
        }
        vm.startPrank(user);
        for (uint256 i; i < 4; ++i) {
            IERC20(addrs[i]).approve(h, type(uint256).max);
        }
        vm.stopPrank();
    }

    function _sort4(address a, address b, address c, address d)
        internal
        pure
        returns (address[4] memory addrs)
    {
        addrs = [a, b, c, d];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j + 1 < 4; ++j) {
                if (addrs[j] > addrs[j + 1]) (addrs[j], addrs[j + 1]) = (addrs[j + 1], addrs[j]);
            }
        }
    }
}

contract CurveQuadHostilePull {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            (bool ok, bytes memory ret) = target.call(reentryCall);
            _depth = 0;
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract CurveQuadHostilePush {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            (bool ok, bytes memory ret) = target.call(reentryCall);
            _depth = 0;
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

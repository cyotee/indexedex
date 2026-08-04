// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    TestBase_UniswapV4QuadStableSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/stable/quad/TestBase_UniswapV4QuadStableSwapHook.sol";
import {
    IUniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHook.sol";

/**
 * @title UniswapV4QuadStableSwapHook_Swap_Test
 * @notice All six pairs exact-in/out both directions; preview fidelity; inert SwapNotLive.
 */
contract UniswapV4QuadStableSwapHook_Swap_Test is TestBase_UniswapV4QuadStableSwapHook {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public override {
        TestBase_UniswapV4QuadStableSwapHook.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
        _addLiquidityFirst(10_000);
        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        t2.approve(address(swapRouter), type(uint256).max);
        t3.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _swapAmt(address token, uint256 human) internal view returns (uint256) {
        uint8 d = MintableDec(token).decimals();
        return human * (10 ** uint256(d));
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _pairKey(uint256 pairIdx) internal view returns (PoolKey memory) {
        return _poolKeys()[pairIdx];
    }

    /// @notice S0: doors may exist but reserves empty → SwapNotLive on preview (real path).
    function test_S0_inertBook_swapReverts() public {
        MintableDec a = new MintableDec("IA", "IA", 18);
        MintableDec b = new MintableDec("IB", "IB", 18);
        MintableDec c = new MintableDec("IC", "IC", 18);
        MintableDec d = new MintableDec("ID", "ID", 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        address[4] memory providers;
        (address h,) = factory.deploy(
            address(x0),
            address(x1),
            address(x2),
            address(x3),
            DEMO_FEE,
            DEMO_AMP,
            providers,
            "inert-book-ns"
        );
        IUniswapV4QuadStableSwapHook inert = IUniswapV4QuadStableSwapHook(h);
        uint256[4] memory r = inert.reserves();
        assertEq(r[0], 0);
        assertEq(r[1], 0);
        assertEq(r[2], 0);
        assertEq(r[3], 0);

        // Pair door exists; book inert → pair-leg gate fails
        vm.expectRevert(abi.encodeWithSignature("SwapNotLive()"));
        inert.previewSwapExactIn(address(x0), address(x1), 1e18);

        vm.expectRevert(abi.encodeWithSignature("SwapNotLive()"));
        inert.previewSwapExactOut(address(x0), address(x1), 1e18);
    }

    function test_S1_exactIn_pair0_previewEqualsExecution() public {
        _assertExactIn(0, true, 10);
    }

    function test_S1b_exactIn_pair0_oneForZero() public {
        _assertExactIn(0, false, 10);
    }

    /// @notice S1–S6: exact-in both directions on all six pairs; preview == exec.
    function test_S_allSixPairs_exactIn_bothDirections() public {
        for (uint256 p; p < 6; ++p) {
            _assertExactIn(p, true, 5);
            _assertExactIn(p, false, 5);
        }
    }

    /// @notice S7–S12: exact-out both directions on all six pairs; preview == exec.
    function test_S_allSixPairs_exactOut_bothDirections() public {
        for (uint256 p; p < 6; ++p) {
            _assertExactOut(p, true, 3);
            _assertExactOut(p, false, 3);
        }
    }

    function test_S14_exactOut_zero_reverts() public {
        vm.expectRevert();
        quad.previewSwapExactOut(address(t0), address(t1), 0);
    }

    function _assertExactIn(uint256 pairIdx, bool zeroForOne, uint256 humanIn) internal {
        PoolKey memory key = _pairKey(pairIdx);
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
        PoolKey memory key = _pairKey(pairIdx);
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
}

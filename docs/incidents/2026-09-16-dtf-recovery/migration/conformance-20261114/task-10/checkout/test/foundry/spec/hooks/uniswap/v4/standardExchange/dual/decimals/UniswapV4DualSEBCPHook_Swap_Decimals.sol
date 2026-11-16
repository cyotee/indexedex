// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TestBase_UniswapV4DualSEBCPHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook_Decimals.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

/**
 * @title UniswapV4DualSEBCPHook_Swap_Decimals
 * @notice Dual Swap money-paths on ERC-4626×ERC-4626 cells `D_U{left}_U{right}`.
 * @dev Left SE underlying `_leftDecimals()`, right `_rightDecimals()`. After PoolKey sort,
 *      exact-in amount is raw units of the **in** currency (`_humanFor`). Hook LP stays 18.
 */
abstract contract UniswapV4DualSEBCPHook_Swap_Decimals is TestBase_UniswapV4DualSEBCPHook_Decimals {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public virtual override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
        _depositBoth(_uA(500), _uB(500));
        _initPool();

        vm.startPrank(user);
        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function test_S1_exactIn_zeroForOne_previewEqualsExecution() public {
        uint256 amountIn = _humanFor(dual.currency0(), 5);
        uint256 pred = dual.previewSwapExactIn(true, amountIn);
        assertGt(pred, 0);

        address c1 = dual.currency1();
        uint256 beforeOut = IERC20(c1).balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _sqrtLimit(true)
            }),
            ""
        );
        uint256 got = IERC20(c1).balanceOf(user) - beforeOut;
        assertApproxEqAbs(got, pred, DUST);
    }

    function test_S1b_exactIn_oneForZero_previewEqualsExecution() public {
        uint256 amountIn = _humanFor(dual.currency1(), 5);
        uint256 pred = dual.previewSwapExactIn(false, amountIn);
        assertGt(pred, 0);

        address c0 = dual.currency0();
        uint256 beforeOut = IERC20(c0).balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _sqrtLimit(false)
            }),
            ""
        );
        uint256 got = IERC20(c0).balanceOf(user) - beforeOut;
        assertApproxEqAbs(got, pred, DUST);
    }
}

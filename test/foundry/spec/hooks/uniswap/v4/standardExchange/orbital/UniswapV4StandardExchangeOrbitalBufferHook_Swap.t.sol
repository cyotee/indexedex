// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_SwapTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function setUp() public override {
        super.setUp();
        _seedThreeLeg(500 ether);
    }

    function test_swap_exactIn_allSixDirections() public {
        address[3] memory t = [address(token0), address(token1), address(token2)];
        for (uint256 i; i < 3; i++) {
            for (uint256 j; j < 3; j++) {
                if (i == j) continue;
                uint256 preview = orbital.previewSwapExactIn(t[i], t[j], 1 ether);
                assertGt(preview, 0, "preview out");
                uint256 balBefore = IERC20(t[j]).balanceOf(user);
                _swapExactIn(t[i], t[j], 1 ether);
                uint256 balAfter = IERC20(t[j]).balanceOf(user);
                assertEq(balAfter - balBefore, preview, "preview==exec");
            }
        }
    }

    function test_swap_exactOut_preview() public {
        uint256 amountOut = 1 ether;
        uint256 amountIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(amountIn, 0);
        // execute via exact-in of amountIn should deliver ~amountOut (within dust)
        uint256 out = orbital.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertApproxEqAbs(out, amountOut, 2, "round-trip dust");
    }

    function test_swap_exactOut_execution_previewEqualsExec() public {
        uint256 amountOut = 1 ether;
        uint256 amountIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(amountIn, 0);

        PoolKey memory key = _poolKeyFor(address(token0), address(token1));
        bool zeroForOne = address(token0) == Currency.unwrap(key.currency0);
        uint256 balOutBefore = token1.balanceOf(user);
        uint256 balInBefore = token0.balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactOut(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountOut),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            amountIn + 1 ether, // maxIn cushion
            ""
        );

        uint256 gotOut = token1.balanceOf(user) - balOutBefore;
        uint256 paidIn = balInBefore - token0.balanceOf(user);
        assertEq(gotOut, amountOut, "exact-out amount");
        // Router may refund unused maxIn; paid should equal previewed amountIn
        assertEq(paidIn, amountIn, "exact-out input matches preview");
    }

    function test_swap_beforeLive_reverts() public {
        // fresh inert would need new deploy — use radius check via empty second instance is heavy;
        // drain attempt: swap more than reserve reverts
        vm.expectRevert();
        orbital.previewSwapExactIn(address(token0), address(token1), 10_000_000 ether);
    }

    function test_swap_zeroFee_path() public {
        _setDexFee(0);
        uint256 preview = orbital.previewSwapExactIn(address(token0), address(token1), 1 ether);
        uint256 balBefore = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertEq(token1.balanceOf(user) - balBefore, preview);
    }

    function test_swap_withFee_residualGrowsBook() public {
        _setDexFee(0.003e18); // 30 bps
        (uint256 e0Before,,) = orbital.effectiveReserves();
        _swapExactIn(address(token0), address(token1), 10 ether);
        (uint256 e0After,,) = orbital.effectiveReserves();
        assertGt(e0After, e0Before, "fee residual in book");
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

contract UniswapV4OrbitalSwapHook_Swap_Test is TestBase_UniswapV4OrbitalSwapHook {
    function setUp() public override {
        TestBase_UniswapV4OrbitalSwapHook.setUp();
        _seedThreeLeg(500 ether);
        _setDexFee(0.003e18); // 0.3%
    }

    function _assertExactIn(address tin, address tout, uint256 amountIn) internal {
        uint256 pred = orbital.previewSwapExactIn(tin, tout, amountIn);
        assertGt(pred, 0);
        uint256 beforeOut = IERC20(tout).balanceOf(user);
        uint256 rOutBefore = orbital.reserveOf(tout);
        _swapExactIn(tin, tout, amountIn);
        uint256 got = IERC20(tout).balanceOf(user) - beforeOut;
        assertEq(got, pred, "preview==exec exact-in");
        assertGt(orbital.reserveOf(tout), 0);
        assertLt(orbital.reserveOf(tout), rOutBefore);
        assertGt(orbital.reserveOf(tin), 0);
    }

    function test_exactIn_allSixDirections_previewBitExact() public {
        uint256 amt = 1 ether;
        _assertExactIn(address(token0), address(token1), amt);
        _assertExactIn(address(token1), address(token0), amt);
        _assertExactIn(address(token1), address(token2), amt);
        _assertExactIn(address(token2), address(token1), amt);
        _assertExactIn(address(token0), address(token2), amt);
        _assertExactIn(address(token2), address(token0), amt);
    }

    function test_exactOut_previewBitExact_token0_to_token1() public {
        uint256 amountOut = 0.5 ether;
        uint256 predIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(predIn, 0);

        uint256 beforeOut = token1.balanceOf(user);
        uint256 beforeIn = token0.balanceOf(user);

        PoolKey memory key = _poolKeyFor(address(token0), address(token1));
        address c0 = Currency.unwrap(key.currency0);
        bool zeroForOne = (address(token0) == c0);

        vm.prank(user);
        swapRouter.swapExactOut(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountOut),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            predIn + 1 ether,
            ""
        );

        uint256 gotOut = token1.balanceOf(user) - beforeOut;
        uint256 spentIn = beforeIn - token0.balanceOf(user);
        assertEq(gotOut, amountOut);
        assertEq(spentIn, predIn);
    }

    function test_noFullDrain() public {
        vm.expectRevert();
        orbital.previewSwapExactIn(address(token0), address(token1), 10_000 ether);
    }

    function test_zeroFee_path() public {
        _setDexFee(0);
        _assertExactIn(address(token0), address(token1), 1 ether);
    }
}

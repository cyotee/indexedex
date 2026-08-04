// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";

contract UniswapV4OrbitalSwapHook_Fees_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_tradingFee_residualStaysInReserve() public {
        _seedThreeLeg(200 ether);
        _setDexFee(0.01e18); // 1%
        uint256 r0Before = orbital.reserveOf(address(token0));
        uint256 amountIn = 10 ether;
        _swapExactIn(address(token0), address(token1), amountIn);
        assertEq(orbital.reserveOf(address(token0)), r0Before + amountIn);
    }

    function test_growthFee_mintsToFeeTo_afterSwaps() public {
        _seedThreeLeg(200 ether);
        _setUsageFee(0.05e18); // 5%
        // Snapshot kLast on next LP after fee on
        _addLiquidity(1 ether, 1 ether, 1 ether);

        // Grow k via swaps (does not update kLast)
        for (uint256 i; i < 5; i++) {
            _swapExactIn(address(token0), address(token1), 5 ether);
            _swapExactIn(address(token1), address(token0), 5 ether);
        }

        address ft = orbital.feeTo();
        uint256 feeBalBefore = IERC20(hook).balanceOf(ft);

        _addLiquidity(2 ether, 2 ether, 2 ether);
        uint256 feeBalAfter = IERC20(hook).balanceOf(ft);
        assertGt(feeBalAfter, feeBalBefore, "protocol growth LP must mint to feeTo");
        assertEq(
            uint8(orbital.kLastMode()),
            uint8(IUniswapV4OrbitalSwapHook.KLastMode.FullProduct)
        );
    }

    function test_feeOff_ownerFeeShareZero() public {
        _seedThreeLeg(100 ether);
        _setUsageFee(1); // 1 wei WAD → ownerFeeShare floors to 0
        address ft = orbital.feeTo();
        uint256 before = IERC20(hook).balanceOf(ft);
        // Grow then add — still no protocol mint when fee-off
        _swapExactIn(address(token0), address(token1), 5 ether);
        _addLiquidity(1 ether, 1 ether, 1 ether);
        assertEq(IERC20(hook).balanceOf(ft), before);
    }
}

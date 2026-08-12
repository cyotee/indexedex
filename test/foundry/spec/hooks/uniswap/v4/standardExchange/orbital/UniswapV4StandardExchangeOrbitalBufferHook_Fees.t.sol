// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_FeesTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_dualChannel_views() public {
        _seedThreeLeg(100 ether);
        _setDexFee(0.003e18);
        _setUsageFee(0.05e18);
        assertEq(orbital.dexSwapFee(), 0.003e18);
        assertEq(orbital.usageFee(), 0.05e18);
        assertEq(orbital.feeTo(), feeRecipient);
    }

    function test_protocolGrowth_onAdd_assertGt() public {
        // Mirror monomorph orbital Fees gold: seed → usage fee → snapshot kLast → round-trip swaps → mint
        _seedThreeLeg(200 ether);
        _setUsageFee(0.05e18); // 5%
        _setDexFee(0.01e18); // 1% trading residual grows k
        // Snapshot kLast on next LP after fee on
        _addLiquidity(1 ether, 1 ether, 1 ether);
        assertGt(orbital.kLast(), 0, "kLast set");

        // Grow k via round-trip swaps (does not update kLast)
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
            uint8(IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode.FullProduct)
        );
    }

    function test_swap_doesNotUpdateKLast() public {
        _seedThreeLeg(200 ether);
        _setUsageFee(0.05e18);
        _addLiquidity(50 ether, 50 ether, 50 ether); // set kLast
        uint256 kBefore = orbital.kLast();
        assertGt(kBefore, 0);
        _swapExactIn(address(token0), address(token1), 5 ether);
        assertEq(orbital.kLast(), kBefore, "swap must not update kLast");
    }
}

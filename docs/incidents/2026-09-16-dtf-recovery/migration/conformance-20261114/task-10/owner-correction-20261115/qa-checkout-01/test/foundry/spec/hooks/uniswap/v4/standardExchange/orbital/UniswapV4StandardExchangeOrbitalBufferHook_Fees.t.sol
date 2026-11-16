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

    function test_protocolMintFee_splitsOnlyBackedDeposit() public {
        _seedThreeLeg(200 ether);
        _setUsageFee(0.05e18);
        _setDexFee(0.01e18);
        uint256 supplyBeforeSwaps = IERC20(hook).totalSupply();
        uint256 feeBeforeSwaps = IERC20(hook).balanceOf(feeRecipient);
        for (uint256 i; i < 5; ++i) {
            _swapExactIn(address(token0), address(token1), 5 ether);
            _swapExactIn(address(token1), address(token0), 5 ether);
        }
        assertEq(IERC20(hook).totalSupply(), supplyBeforeSwaps, "swaps issue no LP");
        assertEq(IERC20(hook).balanceOf(feeRecipient), feeBeforeSwaps);
        (uint256 net,,,) = _addLiquidity(2 ether, 2 ether, 2 ether);
        uint256 gross = IERC20(hook).totalSupply() - supplyBeforeSwaps;
        uint256 fee = gross * 0.05e18 / 1e18;
        assertGt(gross, 0);
        assertEq(IERC20(hook).balanceOf(feeRecipient) - feeBeforeSwaps, fee);
        assertEq(net + fee, gross, "fee is split from gross, never on top");
        assertEq(orbital.kLast(), 0, "retired growth slot");
    }

    function test_swap_doesNotUpdateKLast() public {
        _seedThreeLeg(200 ether);
        _setUsageFee(0.05e18);
        _addLiquidity(50 ether, 50 ether, 50 ether); // set kLast
        uint256 kBefore = orbital.kLast();
        assertEq(kBefore, 0, "retired growth slot");
        _swapExactIn(address(token0), address(token1), 5 ether);
        assertEq(orbital.kLast(), kBefore, "swap must not update kLast");
    }
}

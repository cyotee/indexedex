// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/**
 * @notice H11 dual-channel: usageFee growth mint; dexSwapFee residual on swaps.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Fees is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    /// @notice Force rootK > kLast via SE donation, then join → feeTo LP strictly increases.
    function test_usageFee_growthMint_onJoin() public {
        _ensureFeeTo();
        _setUsageFee(0.05e18); // 5%

        uint256 first = _firstMintEqual(100 ether);
        assertGt(first, 0);
        assertGt(weighted.kLast(), 0, "kLast set when fee-on");

        address feeTo_ = address(weighted.feeTo());
        assertTrue(feeTo_ != address(0));
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);

        // Donation of SE shares increases inventory V without minting LP → rootK > kLast
        uint256 amountIn = 20 ether;
        token0.mint(user, amountIn);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), amountIn, IERC20(se0), 0, user, false, block.timestamp + 1 hours
        );
        require(seOut > 0, "se mint");
        IERC20(se0).transfer(hook, seOut);
        vm.stopPrank();
        assertGt(weighted.nativeReserve(0), 0);

        // Next join mints protocol growth from pre-intake k rise
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        vm.prank(user);
        weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);

        uint256 feeLpAfter = IERC20(hook).balanceOf(feeTo_);
        assertGt(feeLpAfter, feeLpBefore, "feeTo LP strictly increases after growth mint");
    }

    function test_dexSwapFee_affectsExactInOut() public {
        _firstMintEqual(200 ether);
        uint256 amountIn = 2 ether;
        // Oracle: 0 means "unset" (fallback). Use explicit non-zero tiers.
        _setDexFee(0.001e18); // 0.1% baseline
        uint256 outLowFee = weighted.previewSwapExactIn(address(token1), address(token0), amountIn);
        assertEq(weighted.dexSwapFee(), 0.001e18);

        _setDexFee(0.05e18); // 5%
        uint256 outHighFee = weighted.previewSwapExactIn(address(token1), address(token0), amountIn);
        assertEq(weighted.dexSwapFee(), 0.05e18);
        assertLt(outHighFee, outLowFee, "higher dex fee reduces out");
    }
}

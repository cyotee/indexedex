// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/**
 * @notice H11 dual-channel: usageFee backed mint split; dexSwapFee residual on swaps.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Fees is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    /// @notice Ambient donations mint no fee; a later join splits only its own backed gross.
    function test_usageFee_splitsOnlyBackedMint_onJoin() public {
        _ensureFeeTo();
        _setUsageFee(0.05e18);
        uint256 first = _firstMintEqual(100 ether);
        uint256 grossFirst = IERC20(hook).totalSupply() - 1000;
        address recipient = weighted.feeTo();
        assertEq(IERC20(hook).balanceOf(recipient), grossFirst * 0.05e18 / 1e18);
        assertEq(first + IERC20(hook).balanceOf(recipient), grossFirst);
        assertEq(weighted.kLast(), 0, "retired growth checkpoint remains reserved");
        uint256 feeBefore = IERC20(hook).balanceOf(recipient);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 bookBefore = weighted.seBalance(0);
        uint256 donated = _userAcquireSeShares(se0, token0, 20 ether);
        vm.prank(user);
        IERC20(se0).transfer(hook, donated);
        assertEq(weighted.seBalance(0), bookBefore, "ambient shares remain unbooked");
        assertEq(IERC20(hook).totalSupply(), supplyBefore);
        assertEq(IERC20(hook).balanceOf(recipient), feeBefore);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether; amounts[1] = 10 ether;
        vm.prank(user);
        (uint256 net,) = weighted.joinProportional(amounts, user, 1, block.timestamp);
        uint256 gross = IERC20(hook).totalSupply() - supplyBefore;
        assertEq(IERC20(hook).balanceOf(recipient) - feeBefore, gross * 0.05e18 / 1e18);
        assertEq(net + gross * 0.05e18 / 1e18, gross);
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

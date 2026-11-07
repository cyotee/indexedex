// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_MultiAssetLiq
 * @notice MultiAssetLiquidity selectors resolve 1:1 with hook liquidity (same diamond).
 */
contract UniswapV4StandardExchangeWeightedBufferHook_MultiAssetLiq is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_multiAssetLiquidity_1to1_selectors() public {
        _firstMintEqual(100 ether);
        IStandardExchangeMultiAssetLiquidity mal = IStandardExchangeMultiAssetLiquidity(hook);
        uint256 singleQuote = weighted.previewJoinSingleAssetExactIn(address(token1), 5 ether);
        assertGt(singleQuote, 0);
        assertEq(mal.previewJoinSingleAssetExactIn(address(token1), 5 ether), singleQuote);
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 singleMinted = mal.joinSingleAssetExactIn(address(token1), 5 ether, user, singleQuote, block.timestamp + 1 hours);
        assertEq(singleMinted, singleQuote);
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, singleMinted);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether; amounts[1] = 5 ether;
        (uint256 expected, uint256[] memory expectedUsed) = weighted.previewJoinProportional(amounts);
        (uint256 genericExpected, uint256[] memory genericUsed) = mal.previewJoinProportional(amounts);
        assertEq(genericExpected, expected); assertEq(genericUsed, expectedUsed);
        assertGt(expected, 0);
        vm.prank(user);
        (uint256 minted, uint256[] memory used) = mal.joinProportional(amounts, user, 1, block.timestamp + 1 hours);
        assertEq(minted, expected); assertEq(used, expectedUsed);
    }
}

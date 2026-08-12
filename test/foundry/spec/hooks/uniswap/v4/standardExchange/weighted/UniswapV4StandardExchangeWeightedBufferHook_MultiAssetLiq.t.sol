// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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

        uint256 amountIn = 5 ether;
        uint256 a = weighted.previewJoinSingleAssetExactIn(address(token1), amountIn);
        uint256 b = mal.previewJoinSingleAssetExactIn(address(token1), amountIn);
        assertEq(a, b, "preview join 1:1");

        vm.prank(user);
        uint256 s1 = mal.joinSingleAssetExactIn(
            address(token1), amountIn, user, 0, block.timestamp + 1 hours
        );
        assertEq(s1, a, "mal join uses same path");
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHook_MultiAssetLiq is TestBase {
    function test_multiAssetLiquidity_propJoin_facade() public {
        IStandardExchangeMultiAssetLiquidity mal = IStandardExchangeMultiAssetLiquidity(hook);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = mal.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertGt(shares, 0);
        // InvalidRoute on OMIT
        vm.expectRevert(IUniswapV4StandardExchangeCurveQuadStableBufferHook.InvalidRoute.selector);
        mal.previewJoinUnbalanced(amounts);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHook_MultiAssetLiq is TestBase {
    function test_multiAssetLiquidity_propJoin_facade() public {
        IStandardExchangeMultiAssetLiquidity mal = IStandardExchangeMultiAssetLiquidity(hook);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = mal.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertGt(shares, 0);
    }

    function test_multiAssetLiquidity_unbalancedAndExactOut_live() public {
        IStandardExchangeMultiAssetLiquidity mal = IStandardExchangeMultiAssetLiquidity(hook);
        _firstMintEqual(300 ether);

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 8 ether;
        amounts[1] = 25 ether;
        amounts[2] = 4 ether;
        amounts[3] = 12 ether;
        uint256 predU = mal.previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 sU = mal.joinUnbalanced(amounts, user, 0, block.timestamp + 1);
        assertEq(sU, predU);
        assertGt(sU, 0);

        uint256 amountOut = 2 ether;
        uint256 predBurn = mal.previewExitSingleAssetExactTokenOut(address(token1), amountOut);
        vm.prank(user);
        uint256 burned = mal.exitSingleAssetExactTokenOut(
            address(token1), amountOut, user, type(uint256).max, block.timestamp + 1
        );
        assertEq(burned, predBurn);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals
 * @notice n=8 smoke: deploy doors, first mint, one swap, one join. Books `B_P6_R18` / `B_P9_R18` only.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
{
    function test_n8_smoke_deployDoorsMintSwapJoin() public {
        MintableERC20Decimals[] memory toks;
        (, toks) = _deployNn(8);

        assertEq(weighted.numTokens(), 8);
        assertEq(weighted.pairDoorCount(), 28);
        _assertAllDoorsLive();

        uint256[] memory amounts = new uint256[](8);
        for (uint256 i; i < 8; ++i) {
            amounts[i] = _raw(toks[i], 50);
        }
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);

        uint256 swapIn = _raw(toks[1], 1);
        if (swapIn > 1) swapIn = swapIn / 2;
        _swapExactIn(address(toks[1]), address(toks[2]), swapIn);

        uint256[] memory moreIn = new uint256[](8);
        for (uint256 i; i < 8; ++i) {
            moreIn[i] = _raw(toks[i], 5);
        }
        vm.prank(user);
        (uint256 more,) = weighted.joinProportional(moreIn, user, 0, block.timestamp + 1 hours);
        assertGt(more, 0);
    }
}

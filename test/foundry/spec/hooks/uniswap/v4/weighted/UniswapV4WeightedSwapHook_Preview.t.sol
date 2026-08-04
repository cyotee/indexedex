// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

contract UniswapV4WeightedSwapHook_Preview_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_Q1_joinExitPreviewExact() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 5000);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 200);
        amounts[1] = _raw(t1, 200);
        (uint256 pShares, uint256[] memory pUsed) =
            IUniswapV4WeightedSwapHook(hook).previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 eShares, uint256[] memory eUsed) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(eShares, pShares);
        assertEq(eUsed[0], pUsed[0]);
        assertEq(eUsed[1], pUsed[1]);

        uint256[] memory pExit = IUniswapV4WeightedSwapHook(hook).previewExitProportional(eShares / 3);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        uint256[] memory eExit = IUniswapV4WeightedSwapHook(hook).exitProportional(
            eShares / 3, user, mins, block.timestamp + 1 hours
        );
        assertEq(eExit[0], pExit[0]);
        assertEq(eExit[1], pExit[1]);
    }

    function test_Q2_swapPreview() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 5000);
        uint256 ain = _raw(t0, 7);
        uint256 o1 = IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), ain);
        uint256 o2 = IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), ain);
        assertEq(o1, o2);
        uint256 i1 = IUniswapV4WeightedSwapHook(hook).previewSwapExactOut(address(t0), address(t1), o1);
        assertGt(i1, 0);
    }

    function test_Q3_unbalancedPreview() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 5000);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 30);
        amounts[1] = _raw(t1, 5);
        uint256 p = IUniswapV4WeightedSwapHook(hook).previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 e = IUniswapV4WeightedSwapHook(hook).joinUnbalanced(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(e, p);
    }
}

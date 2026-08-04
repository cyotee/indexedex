// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

contract UniswapV4WeightedSwapHook_Partial_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_P1_partialFirstMint_n3() public {
        (address hook, MintableDec t0, MintableDec t1, MintableDec t2) = _deployN3();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 1000);
        amounts[2] = 0; // partial
        vm.prank(user);
        (uint256 shares,) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(shares, 0);
        assertFalse(IUniswapV4WeightedSwapHook(hook).isFullBook());
        assertEq(
            uint8(IUniswapV4WeightedSwapHook(hook).kLastMode()),
            uint8(IUniswapV4WeightedSwapHook.KLastMode.PartialInterim)
        );
    }

    function test_P2_n2_rejectsPartialFirstMint() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = 0;
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_P3_seedCompletesToFull() public {
        (address hook, MintableDec t0, MintableDec t1, MintableDec t2) = _deployN3();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 1000);
        amounts[2] = 0;
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );

        // seed third leg
        uint256[] memory seed = new uint256[](3);
        seed[0] = 0;
        seed[1] = 0;
        seed[2] = _raw(t2, 1000);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            seed, user, 0, block.timestamp + 1 hours, ""
        );
        assertTrue(IUniswapV4WeightedSwapHook(hook).isFullBook());
        assertEq(
            uint8(IUniswapV4WeightedSwapHook(hook).kLastMode()),
            uint8(IUniswapV4WeightedSwapHook.KLastMode.FullProduct)
        );
    }

    function test_P4_unbalancedRestrictedWhilePartial() public {
        (address hook, MintableDec t0, MintableDec t1,) = _deployN3();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 1000);
        amounts[2] = 0;
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );

        uint256[] memory unb = new uint256[](3);
        unb[0] = _raw(t0, 10);
        unb[1] = _raw(t1, 5);
        unb[2] = 0;
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).joinUnbalanced(
            unb, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_P5_partialExitProportional() public {
        (address hook, MintableDec t0, MintableDec t1,) = _deployN3();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 1000);
        amounts[2] = 0;
        vm.prank(user);
        (uint256 shares,) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        uint256[] memory mins = new uint256[](3);
        vm.prank(user);
        uint256[] memory out = IUniswapV4WeightedSwapHook(hook).exitProportional(
            shares / 2, user, mins, block.timestamp + 1 hours
        );
        assertGt(out[0], 0);
        assertGt(out[1], 0);
        assertEq(out[2], 0);
    }
}

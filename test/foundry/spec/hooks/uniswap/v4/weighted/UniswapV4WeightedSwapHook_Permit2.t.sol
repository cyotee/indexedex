// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

contract UniswapV4WeightedSwapHook_Permit2_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_P2_1_emptyPermit2_transferFrom() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        // empty permit2Data uses transferFrom — already covered by joins
        uint256 shares = _joinFullN2(hook, t0, t1, 500);
        assertGt(shares, 0);
    }

    function test_P2_2_badModeReverts() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        // mode 99
        bytes memory bad = abi.encode(uint8(99));
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, bad
        );
    }

    function test_P2_3_allowanceModeWithoutPermit2SetupReverts() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        bytes memory allowMode = abi.encode(uint8(1));
        // No Permit2 allowances set → transferFrom on Permit2 should fail
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, allowMode
        );
    }
}

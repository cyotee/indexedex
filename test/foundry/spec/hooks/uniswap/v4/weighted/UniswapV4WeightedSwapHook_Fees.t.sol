// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

contract UniswapV4WeightedSwapHook_Fees_Test is TestBase_UniswapV4WeightedSwapHook {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
    }

    function test_G1_growthMintOnJoinAfterSwap() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 10_000);

        uint256 kBefore = IUniswapV4WeightedSwapHook(hook).kLast();
        assertGt(kBefore, 0);

        PoolKey memory key = _pairPoolKeys(hook)[0];
        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        uint256 amountIn = _raw(t0, 100);
        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne
                    ? TickMath.MIN_SQRT_PRICE + 1
                    : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );
        vm.stopPrank();

        assertEq(IUniswapV4WeightedSwapHook(hook).kLast(), kBefore);

        uint256 feeToBalBefore = IERC20(hook).balanceOf(feeRecipient);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(IERC20(hook).balanceOf(feeRecipient), feeToBalBefore);
    }

    function test_G2_rootKIsV_fullBook() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);
        uint256 k = IUniswapV4WeightedSwapHook(hook).kLast();
        assertGt(k, 1000);
        assertEq(
            uint8(IUniswapV4WeightedSwapHook(hook).kLastMode()),
            uint8(IUniswapV4WeightedSwapHook.KLastMode.FullProduct)
        );
    }

    function test_G3_feeOff_noProtocolMint() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vm.stopPrank();

        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);
        assertEq(IUniswapV4WeightedSwapHook(hook).kLast(), 0);
        assertEq(IERC20(hook).balanceOf(feeRecipient), 0);
    }

    function test_G4_growthOnExit() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256 shares = _joinFullN2(hook, t0, t1, 10_000);

        PoolKey memory key = _pairPoolKeys(hook)[0];
        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(_raw(t0, 50)),
                sqrtPriceLimitX96: zeroForOne
                    ? TickMath.MIN_SQRT_PRICE + 1
                    : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );
        vm.stopPrank();

        uint256 feeBefore = IERC20(hook).balanceOf(feeRecipient);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).exitProportional(
            shares / 10, user, mins, block.timestamp + 1 hours
        );
        assertGe(IERC20(hook).balanceOf(feeRecipient), feeBefore);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

contract UniswapV4WeightedSwapHook_Swap_Test is TestBase_UniswapV4WeightedSwapHook {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
    }

    function test_S1_previewExactInExactOut() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 10_000);

        uint256 amountIn = _raw(t0, 10);
        uint256 out = IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), amountIn);
        assertGt(out, 0);
        uint256 in2 = IUniswapV4WeightedSwapHook(hook).previewSwapExactOut(address(t0), address(t1), out);
        assertGe(in2, amountIn);
    }

    function test_S2_swapExactIn_viaRouter_updatesReserves() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 10_000);

        PoolKey memory key = factory.pairPoolKeys(hook)[0];
        uint256 amountIn = _raw(t0, 10);
        uint256 preview =
            IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), amountIn);

        uint256 r0Before = IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0));
        uint256 r1Before = IUniswapV4WeightedSwapHook(hook).reserveOf(address(t1));
        uint256 kBefore = IUniswapV4WeightedSwapHook(hook).kLast();

        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        SwapParams memory sp = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });

        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(key, sp, "");
        vm.stopPrank();

        assertEq(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0)), r0Before + amountIn);
        assertEq(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t1)), r1Before - preview);
        assertEq(IUniswapV4WeightedSwapHook(hook).kLast(), kBefore);
    }

    function test_S3_swapNotLive_partialLeg() public {
        (address hook, MintableDec t0, MintableDec t1, MintableDec t2) = _deployN3();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 1000);
        amounts[2] = 0;
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t2)), 0);
        uint256 amtIn = _raw(t0, 1);
        vm.expectRevert(abi.encodeWithSignature("SwapNotLive()"));
        IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t2), amtIn);
    }

    function test_S4_maxInRatio() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);
        uint256 huge = _raw(t0, 400);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), huge);
    }

    function test_S5_feeZero_stillWorks() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(0);
        vm.stopPrank();

        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);
        uint256 out = IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(
            address(t0), address(t1), _raw(t0, 10)
        );
        assertGt(out, 0);
    }

    function test_S6_multiDoor_n3() public {
        (address hook, MintableDec t0, MintableDec t1, MintableDec t2) = _deployN3();
        _joinFullN3(hook, t0, t1, t2, 5000);
        assertGt(
            IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), _raw(t0, 5)),
            0
        );
        assertGt(
            IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t1), address(t2), _raw(t1, 5)),
            0
        );
        assertGt(
            IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t2), _raw(t0, 5)),
            0
        );
    }
}

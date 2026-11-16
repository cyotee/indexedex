// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4WeightedSwapHook_Decimals
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";

/**
 * @title UniswapV4WeightedSwapHook_NLeg_Decimals
 * @notice n=3 and n=4 live join/swap on each `B_*` book. After address sort t0..tn permute;
 *      `_bookDec(0)` is pairToken at construction. Hook LP stays 18.
 */
abstract contract UniswapV4WeightedSwapHook_NLeg_Decimals is TestBase_UniswapV4WeightedSwapHook_Decimals {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public virtual override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
    }

    function test_P1_partialFirstMint_n3() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(toks[0], 1000);
        amounts[1] = _raw(toks[1], 1000);
        amounts[2] = 0;
        vm.prank(user);
        (uint256 shares,) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(shares, 0);
        assertFalse(IUniswapV4WeightedSwapHook(hook_).isFullBook());
        assertEq(
            uint8(IUniswapV4WeightedSwapHook(hook_).kLastMode()),
            uint8(IUniswapV4WeightedSwapHook.KLastMode.PartialInterim)
        );
    }

    function test_P3_seedCompletesToFull() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(toks[0], 1000);
        amounts[1] = _raw(toks[1], 1000);
        amounts[2] = 0;
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );

        uint256[] memory seed = new uint256[](3);
        seed[2] = _raw(toks[2], 1000);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            seed, user, 0, block.timestamp + 1 hours, ""
        );
        assertTrue(IUniswapV4WeightedSwapHook(hook_).isFullBook());
        assertEq(
            uint8(IUniswapV4WeightedSwapHook(hook_).kLastMode()),
            uint8(IUniswapV4WeightedSwapHook.KLastMode.FullProduct)
        );
    }

    function test_P4_unbalancedRestrictedWhilePartial() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(toks[0], 1000);
        amounts[1] = _raw(toks[1], 1000);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );

        uint256[] memory unb = new uint256[](3);
        unb[0] = _raw(toks[0], 10);
        unb[1] = _raw(toks[1], 5);
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).joinUnbalanced(
            unb, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_P5_partialExitProportional() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(toks[0], 1000);
        amounts[1] = _raw(toks[1], 1000);
        vm.prank(user);
        (uint256 shares,) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        uint256[] memory mins = new uint256[](3);
        vm.prank(user);
        uint256[] memory out = IUniswapV4WeightedSwapHook(hook_).exitProportional(
            shares / 2, user, mins, block.timestamp + 1 hours
        );
        assertGt(out[0], 0);
        assertGt(out[1], 0);
        assertEq(out[2], 0);
    }

    function test_S3_swapNotLive_partialLeg() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(toks[0], 1000);
        amounts[1] = _raw(toks[1], 1000);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[2])), 0);
        uint256 amtIn = _raw(toks[0], 1);
        vm.expectRevert(abi.encodeWithSignature("SwapNotLive()"));
        IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(address(toks[0]), address(toks[2]), amtIn);
    }

    function test_S6_multiDoor_n3() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        _joinFull(hook_, toks, 5000);
        assertGt(
            IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
                address(toks[0]), address(toks[1]), _raw(toks[0], 5)
            ),
            0
        );
        assertGt(
            IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
                address(toks[1]), address(toks[2]), _raw(toks[1], 5)
            ),
            0
        );
        assertGt(
            IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
                address(toks[0]), address(toks[2]), _raw(toks[0], 5)
            ),
            0
        );
    }

    function test_L1_firstMintFull_minOnAddress0_n3() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        uint256 shares = _joinFull(hook_, toks, 1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook_).balanceOf(address(0)), Math.MINIMUM_LIQUIDITY);
        assertTrue(IUniswapV4WeightedSwapHook(hook_).isFullBook());
        for (uint256 i; i < 3; ++i) {
            assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[i])), _raw(toks[i], 1000));
        }
    }

    function test_L2_propJoinExit_previewEqExec_n3() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(3);
        _joinFull(hook_, toks, 1000);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i; i < 3; ++i) amounts[i] = _raw(toks[i], 100);
        (uint256 prevShares, uint256[] memory prevUsed) =
            IUniswapV4WeightedSwapHook(hook_).previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prevShares);
        for (uint256 i; i < 3; ++i) assertEq(used[i], prevUsed[i]);
    }

    function test_L1_firstMintFull_minOnAddress0_n4() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(4);
        uint256 shares = _joinFull(hook_, toks, 1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook_).balanceOf(address(0)), Math.MINIMUM_LIQUIDITY);
        assertTrue(IUniswapV4WeightedSwapHook(hook_).isFullBook());
        for (uint256 i; i < 4; ++i) {
            assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[i])), _raw(toks[i], 1000));
        }
    }

    function test_L2_propJoinExit_previewEqExec_n4() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(4);
        _joinFull(hook_, toks, 1000);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = _raw(toks[i], 100);
        (uint256 prevShares, uint256[] memory prevUsed) =
            IUniswapV4WeightedSwapHook(hook_).previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prevShares);
        for (uint256 i; i < 4; ++i) assertEq(used[i], prevUsed[i]);

        uint256[] memory prevExit = IUniswapV4WeightedSwapHook(hook_).previewExitProportional(shares / 2);
        uint256[] memory mins = new uint256[](4);
        vm.prank(user);
        uint256[] memory exited = IUniswapV4WeightedSwapHook(hook_).exitProportional(
            shares / 2, user, mins, block.timestamp + 1 hours
        );
        for (uint256 i; i < 4; ++i) assertEq(exited[i], prevExit[i]);
    }

    function test_S1_previewExactInExactOut_n4() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(4);
        _joinFull(hook_, toks, 10_000);
        uint256 amountIn = _raw(toks[0], 10);
        uint256 out = IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
            address(toks[0]), address(toks[1]), amountIn
        );
        assertGt(out, 0);
        uint256 in2 = IUniswapV4WeightedSwapHook(hook_).previewSwapExactOut(
            address(toks[0]), address(toks[1]), out
        );
        assertGe(in2 + amountIn / 10_000 + 1, amountIn);
    }

    function test_S2_swapExactIn_viaRouter_updatesReserves_n4() public {
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(4);
        _joinFull(hook_, toks, 10_000);

        PoolKey memory key = _poolKeyForDec(address(toks[0]), address(toks[1]), hook_);
        uint256 amountIn = _raw(toks[0], 10);
        uint256 preview = IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
            address(toks[0]), address(toks[1]), amountIn
        );
        uint256 r0Before = IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[0]));
        uint256 r1Before = IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[1]));

        bool zeroForOne = address(toks[0]) == Currency.unwrap(key.currency0);
        vm.startPrank(user);
        toks[0].approve(address(swapRouter), type(uint256).max);
        toks[1].approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );
        vm.stopPrank();

        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[0])), r0Before + amountIn);
        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(toks[1])), r1Before - preview);
    }
}

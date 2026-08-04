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
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

/**
 * @title UniswapV4WeightedSwapHook_Base
 * @notice Fork DoD: factory deploy + join + swap + exit on Base (Alchemy alias).
 * @dev Run: forge test --match-path test/foundry/fork/base_main/hooks/uniswap/v4/weighted/** --fork-url base_mainnet_alchemy
 */
contract UniswapV4WeightedSwapHook_Base_Test is TestBase_UniswapV4WeightedSwapHook {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
    }

    function test_fork_lifecycle_joinSwapExit() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        uint256 shares = _joinFullN2(hook, t0, t1, 5_000);
        assertGt(shares, 0);

        PoolKey memory key = factory.pairPoolKeys(hook)[0];
        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        uint256 amountIn = _raw(t0, 25);
        uint256 preview =
            IUniswapV4WeightedSwapHook(hook).previewSwapExactIn(address(t0), address(t1), amountIn);

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

        assertEq(
            IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0)), _raw(t0, 5_000) + amountIn
        );
        assertEq(
            IUniswapV4WeightedSwapHook(hook).reserveOf(address(t1)), _raw(t1, 5_000) - preview
        );

        uint256[] memory mins = new uint256[](2);
        uint256 balBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook).exitProportional(
            balBefore / 4, user, mins, block.timestamp + 1 hours
        );
        assertLt(IERC20(hook).balanceOf(user), balBefore);
    }
}

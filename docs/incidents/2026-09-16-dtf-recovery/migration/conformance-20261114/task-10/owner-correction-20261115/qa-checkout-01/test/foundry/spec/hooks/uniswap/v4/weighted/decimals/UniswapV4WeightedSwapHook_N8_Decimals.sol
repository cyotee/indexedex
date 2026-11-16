// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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

/**
 * @title UniswapV4WeightedSwapHook_N8_Decimals
 * @notice n=8 smoke: deploy doors, first mint, one swap, one join. Books `B_P6_R18` / `B_P9_R18` only.
 */
abstract contract UniswapV4WeightedSwapHook_N8_Decimals is TestBase_UniswapV4WeightedSwapHook_Decimals {
    function test_n8_smoke_deployDoorsMintSwapJoin() public {
        WrapperExactOutRouter swapRouter = new WrapperExactOutRouter(pm);
        (address hook_, MintableERC20Decimals[] memory toks) = _deployNn(8);
        assertEq(IUniswapV4WeightedSwapHook(hook_).numTokens(), 8);

        uint256 shares = _joinFull(hook_, toks, 1_000);
        assertGt(shares, 0);
        assertTrue(IUniswapV4WeightedSwapHook(hook_).isFullBook());

        PoolKey memory key = _poolKeyForDec(address(toks[0]), address(toks[1]), hook_);
        uint256 amountIn = _raw(toks[0], 5);
        uint256 pred = IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
            address(toks[0]), address(toks[1]), amountIn
        );
        assertGt(pred, 0);
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

        uint256[] memory amounts = new uint256[](8);
        for (uint256 i; i < 8; ++i) amounts[i] = _raw(toks[i], 50);
        vm.prank(user);
        (uint256 more,) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(more, 0);
    }
}

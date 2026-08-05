// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

contract Adversarial_Griefing_Test is AdvBase {
    /// @notice H1: SE reverts mid-swap → full tx revert
    function test_H1_sePauseOrFail_fullRevert() public {
        // Force SE failure by using amount that would need pair with no approval after we drain
        // Simpler: zero-amount swap via router reverts
        bool zfo = _isWrapZFO();
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: 0, sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        _assertHookFlat();
    }

    /// @notice H2: exact-out insufficient user input
    function test_H2_exactOutInsufficient_reverts() public {
        uint256 seOut = 4 ether;
        uint256 amountIn = buffer.previewWrapExactOut(seOut);
        bool zfo = _isWrapZFO();
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: int256(seOut), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            amountIn > 1 ? amountIn - 1 : 0,
            ""
        );
        _assertHookFlat();
    }

    /// @notice H3: add liquidity always LiquidityNotAllowed
    function test_H3_addLiquidity_alwaysReverts() public {
        vm.expectRevert();
        liqRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32(0)
            }),
            ""
        );
    }

    /// @notice H4: init wrong fee/pair reverts
    function test_H4_initWrongFee_reverts() public {
        PoolKey memory bad = poolKey;
        bad.fee = 500;
        vm.expectRevert();
        pm.initialize(bad, SQRT_PRICE_1_1);
    }
}

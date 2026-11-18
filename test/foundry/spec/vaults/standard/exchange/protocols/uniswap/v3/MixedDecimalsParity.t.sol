// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SwapMath.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {StandardExchangeFrozenQuoteLib as FrozenQuote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV3FullSpreadStandardExchangeVaultMath as V3Math} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMath as V4Math} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol";

/// @notice Preserve actual V4 behavior for the mixed-decimal first-bond regression.
contract UniswapV3FullSpreadMixedDecimalsParityTest is Test {
    function test_unrepresentableSwapOutputMatchesV4WholeInputRefund() public pure {
        // Observed six-decimal input / eighteen-decimal output pool state.
        uint256 amount = 97_853_047;
        uint256 swapInput = amount * 49 / 100;
        uint160 price = uint160(uint256(1 << 96) * 1e6);
        uint128 activeLiquidity = 50_000_099_699_801_198_596;
        (uint160 priceAfter, uint256 spent, uint256 output, uint256 fee) =
            SwapMath.computeSwapStep(price, TickMath.MIN_SQRT_RATIO + 1, activeLiquidity, int256(swapInput), 3000);
        assertEq(spent + fee, swapInput);
        assertEq(output, 47_804_103_295_401_599_892);
        uint160 lower = TickMath.getSqrtRatioAtTick(-887220);
        uint160 upper = TickMath.getSqrtRatioAtTick(887220);

        (uint128 liquidity,, uint256 consumedOutput) = V3Math.proportional(
            priceAfter, lower, upper, amount - swapInput, output, type(uint128).max
        );
        assertEq(liquidity, 47_804_148_999_999);
        assertEq(output - consumedOutput, 999_998);
        (, uint256 nextOutput) = V3Math.amountsToPay(priceAfter, lower, upper, liquidity + 1);
        assertEq(nextOutput, output + 1, "another liquidity unit requires unavailable output");

        V3Math.Sized memory v3 = V3Math.sizeOneSided(
            amount, true, swapInput, output, priceAfter, lower, upper, type(uint128).max
        );
        V4Math.Sized memory v4 = V4Math.sizeOneSided(
            amount, true, swapInput, output, priceAfter, lower, upper
        );
        assertEq(v4.liquidity, 0, "V4 rejects an add that cannot consume its swap output");
        assertEq(v4.remainder, amount, "V4 refunds the complete original input");
        assertEq(v3.liquidity, v4.liquidity);
        assertEq(v3.remainder, v4.remainder);
        assertEq(v3.swapIn, 0);
        assertEq(v3.swapOut, 0);
    }

    function test_frozenModelPreservesV4MixedDecimalRefund() public pure {
        Frozen.SwapDepositV2 memory q;
        q.exchange = address(3);
        q.pool = address(4);
        q.token0 = address(1);
        q.token1 = address(2);
        q.request = Frozen.Request(q.token0, q.exchange, address(0), Frozen.Mode.OrdinaryDeposit);
        q.positionLiquidity = 99_699_801_198_596;
        q.supply = q.positionLiquidity;
        q.poolState.sqrtPriceX96 = uint160(uint256(1 << 96) * 1e6);
        q.poolState.tick = 276324;
        q.poolState.activeLiquidity = 50_000_099_699_801_198_596;
        q.poolState.tickSpacing = 60;
        q.poolState.feePips = 3000;
        q.poolState.maxLiquidityPerTick = 11_505_743_598_341_114_571_880_798_222_544_994;
        (q.poolState.firstWord, q.poolState.lastWord) = UniswapV3Quoter.snapshotWordBounds(60);
        q.poolState.bitmapWords = new UniswapV3Quoter.BitmapWord[](2);
        q.poolState.bitmapWords[0] = UniswapV3Quoter.BitmapWord(-58, uint256(1) << 61);
        q.poolState.bitmapWords[1] = UniswapV3Quoter.BitmapWord(57, uint256(1) << 195);
        q.poolState.initializedTicks = new UniswapV3Quoter.InitializedTick[](2);
        q.poolState.initializedTicks[0] = UniswapV3Quoter.InitializedTick(
            -887220, q.poolState.activeLiquidity, int128(q.poolState.activeLiquidity)
        );
        q.poolState.initializedTicks[1] = UniswapV3Quoter.InitializedTick(
            887220, q.poolState.activeLiquidity, -int128(q.poolState.activeLiquidity)
        );
        ExchangeInAmount.Result memory receipt = FrozenQuote.evaluate(
            Frozen.VersionedInputs(2, abi.encode(q)), 97_853_047
        );
        assertEq(receipt.amountOut, 0);
        assertEq(receipt.amountRefunded, 97_853_047);
    }
}

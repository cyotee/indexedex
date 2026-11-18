// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {StandardExchangeConstantProduct as Product} from
    "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV3FullSpreadStandardExchangeVaultMath as V3Math} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultMath.sol";
/// @notice Versioned state-only evaluation of manual ordinary-deposit operands.
/// @dev Structural validation does not authenticate an owner's supplied historical state.
library StandardExchangeFrozenQuoteLib {
    function requireSupported(Frozen.Inputs memory q) internal pure {
        if (
            q.model != Frozen.Model.UniswapV3PairDeposit
                || q.request.mode != Frozen.Mode.OrdinaryDeposit
                || q.request.tokenOut != q.exchange
                || (q.request.tokenIn != q.token0 && q.request.tokenIn != q.token1)
        ) revert Frozen.UnsupportedFrozenQuote(q.exchange, q.request.tokenIn, q.request.tokenOut, q.request.mode);
    }

    function evaluate(Frozen.Inputs memory q, uint256 amount) internal pure returns (ExchangeInAmount.Result memory r) {
        requireSupported(q);
        if (amount == 0) return r;
        uint256 added0 = q.request.tokenIn == q.token0 ? amount : 0;
        uint256 added1 = q.request.tokenIn == q.token1 ? amount : 0;
        r.amountOut = q.supply == 0
            ? Product._initialShares(added0, added1, q.minimumLiquidity)
            : Product._sharesForDeposit(added0, added1, q.supply, q.reserve0, q.reserve1);
    }

    /// @notice Version two contains a complete V3 swap book, not constant-product reserves.
    function requireSupported(Frozen.VersionedInputs memory encoded) internal pure {
        if (encoded.version == 1) {
            requireSupported(abi.decode(encoded.data, (Frozen.Inputs)));
            return;
        }
        if (encoded.version != 2) revert Frozen.UnsupportedFrozenVersion(encoded.version);
        Frozen.SwapDepositV2 memory q = abi.decode(encoded.data, (Frozen.SwapDepositV2));
        if (q.exchange == address(0) || q.pool == address(0) || q.token0 == address(0)
            || q.token0 >= q.token1 || q.exchange == q.token0 || q.exchange == q.token1
            || q.request.mode != Frozen.Mode.OrdinaryDeposit || q.request.tokenOut != q.exchange
            || q.request.holder != address(0)
            || (q.request.tokenIn != q.token0 && q.request.tokenIn != q.token1)) {
            revert Frozen.InvalidFrozenDeposit();
        }
        UniswapV3Quoter.validateSnapshot(q.poolState);
        int24 lower = TickMath.minUsableTick(q.poolState.tickSpacing);
        int24 upper = TickMath.maxUsableTick(q.poolState.tickSpacing);
        uint256 count = q.poolState.initializedTicks.length;
        uint128 lowerGross = count != 0 && q.poolState.initializedTicks[0].index == lower
            ? q.poolState.initializedTicks[0].liquidityGross : 0;
        uint128 upperGross = count != 0 && q.poolState.initializedTicks[count - 1].index == upper
            ? q.poolState.initializedTicks[count - 1].liquidityGross : 0;
        if (q.positionLiquidity > lowerGross || q.positionLiquidity > upperGross) {
            revert Frozen.InvalidFrozenDeposit();
        }
    }

    function evaluate(Frozen.VersionedInputs memory encoded, uint256 amount)
        internal
        pure
        returns (ExchangeInAmount.Result memory r)
    {
        requireSupported(encoded);
        if (encoded.version == 1) return evaluate(abi.decode(encoded.data, (Frozen.Inputs)), amount);
        Frozen.SwapDepositV2 memory q = abi.decode(encoded.data, (Frozen.SwapDepositV2));
        V3Math.Sized memory sized = _size(q, amount);
        r.amountRefunded = sized.remainder;
        (uint256 gross, bool failed) = V3Math.grossShares(sized.liquidity, q.supply, q.positionLiquidity);
        if (!failed) (, r.amountOut) = V3Math.netShares(gross, q.usageFeeWad, q.feeTo);
    }

    function _size(Frozen.SwapDepositV2 memory q, uint256 amount)
        private
        pure
        returns (V3Math.Sized memory sized)
    {
        sized.remainder = amount;
        if (amount == 0) return sized;
        UniswapV3Quoter.PoolSnapshot memory state = q.poolState;
        int24 lower = TickMath.minUsableTick(state.tickSpacing);
        int24 upper = TickMath.maxUsableTick(state.tickSpacing);
        uint160 sqrtA = TickMath.getSqrtRatioAtTick(lower);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(upper);
        uint256 count = state.initializedTicks.length;
        uint128 lowerGross = count != 0 && state.initializedTicks[0].index == lower
            ? state.initializedTicks[0].liquidityGross : 0;
        uint128 upperGross = count != 0 && state.initializedTicks[count - 1].index == upper
            ? state.initializedTicks[count - 1].liquidityGross : 0;
        uint128 capacity = state.maxLiquidityPerTick - (lowerGross > upperGross ? lowerGross : upperGross);
        if (capacity > uint128(type(int128).max)) capacity = uint128(type(int128).max);
        bool zeroForOne = q.request.tokenIn == q.token0;
        if (state.sqrtPriceX96 <= sqrtA || state.sqrtPriceX96 >= sqrtB) {
            return V3Math.singleTokenAdd(amount, zeroForOne, state.sqrtPriceX96, sqrtA, sqrtB, capacity);
        }
        if (state.activeLiquidity == 0 || capacity == 0) return sized;
        uint256 swapIn = FullMath.mulDiv(amount, 49, 100);
        uint160 limit = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        if (swapIn == 0 || swapIn > uint256(type(int256).max)
            || (zeroForOne ? state.sqrtPriceX96 <= limit : state.sqrtPriceX96 >= limit)) return sized;
        UniswapV3Quoter.SwapQuoteResult memory quote =
            UniswapV3Quoter.quoteExactInput(state, zeroForOne, swapIn, limit);
        if (!quote.fullyFilled || quote.amountIn != swapIn || quote.amountOut == 0) return sized;
        return V3Math.sizeOneSided(
            amount, zeroForOne, swapIn, quote.amountOut, quote.sqrtPriceAfterX96, sqrtA, sqrtB, capacity
        );
    }
}

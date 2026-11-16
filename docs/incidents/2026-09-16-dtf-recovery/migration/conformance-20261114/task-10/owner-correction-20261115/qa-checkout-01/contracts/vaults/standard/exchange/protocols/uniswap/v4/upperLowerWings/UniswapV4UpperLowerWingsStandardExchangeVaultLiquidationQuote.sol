// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TickBitmap} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickBitmap.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol";
import {ProtocolFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {BitMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote[]
/// @notice Whole-book value after removing all owned liquidity, selling only through remaining external liquidity.
/// @dev Native token units. No spot mark for unsold inventory. Reads the live hookless pool; does not execute swaps.
library UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote {
    using StateLibrary for IPoolManager;
    using ProtocolFeeLibrary for uint24;
    using ProtocolFeeLibrary for uint16;

    uint256 internal constant MAX_STEPS = 512;
    error InvalidQuoteState();
    error DuplicatePosition();
    error QuoteWorkExceeded(uint256 steps);
    error QuoteDeltaOverflow();

    struct Position {
        int24 lower;
        int24 upper;
        bytes32 salt;
    }

    struct Request {
        IPoolManager manager;
        PoolKey key;
        address owner;
        Position[3] positions;
        uint8 count;
        bool target0;
        uint256 local0;
        uint256 local1;
        uint256 stepLimit;
    }

    struct Result {
        uint256 value;
        uint256 sold;
        uint256 unsold;
        uint256 proceeds;
        bool marketLimited;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 steps;
        uint256 executionCostBound;
    }

    struct PoolState { uint160 price; int24 tick; uint128 externalLiquidity; }
    struct HeldPosition {
        int24 lower;
        int24 upper;
        uint128 liquidity;
        uint256 growth0;
        uint256 growth1;
    }
    struct SwapProjection { Result sale; PoolState pool; HeldPosition[3] positions; }

    struct Boundary {
        int24 tick;
        uint128 gross;
        int256 net;
    }

    struct Context {
        IPoolManager manager;
        PoolId id;
        int24 spacing;
        bool zeroForOne;
        uint24 fee;
        uint24 packedProtocolFee;
        uint24 lpFee;
        uint16 protocolFee;
        HeldPosition[3] held;
        bool accrue;
        bool costs;
        uint256 collected0;
        uint256 collected1;
        Boundary[12] boundaries;
        uint8 count;
    }

    struct Step {
        int24 tick;
        bool initialized;
        uint160 price;
        uint160 start;
        uint256 amountIn;
        uint256 amountOut;
        uint256 fee;
    }

    /// @notice Quotes collection and full removal of exactly the owned positions, then opposing-token sale.
    /// @dev Caller supplies local backing excluding pending deposits, external credits and liabilities.
    function quote(Request memory request_) internal view returns (Result memory result_) {
        return _quote(request_, false, 0, 0);
    }

    /// @notice Value a no-swap projected book against the same external pool after all owned liquidity is removed.
    /// @dev Totals include projected local inventory, removable principal and fees. This is valid only while
    /// price and external liquidity are unchanged; a projected swap requires a new pool-state overlay.
    function quoteInventory(Request memory request_, uint256 total0_, uint256 total1_) internal view returns (Result memory) {
        return _quote(request_, true, total0_, total1_);
    }

    function _quote(Request memory request_, bool projected_, uint256 total0_, uint256 total1_)
        private view returns (Result memory result_)
    {
        Context memory context;
        (context, result_) = _prepare(request_);
        if (!projected_) {
            total0_ = request_.local0 + context.collected0;
            total1_ = request_.local1 + context.collected1;
        }
        result_.value = request_.target0 ? total0_ : total1_;
        result_.unsold = request_.target0 ? total1_ : total0_;
        // A single PoolManager delta is signed int128. Reject unexecutable aggregate results explicitly.
        if (result_.unsold > uint256(uint128(type(int128).max))) revert QuoteDeltaOverflow();
        _sell(context, result_, request_.stepLimit);
        result_.value += result_.proceeds;
        result_.marketLimited = result_.unsold != 0;
    }

    function _prepare(Request memory request_) private view returns (Context memory context, Result memory result_) {
        if (request_.count > 3 || request_.stepLimit == 0 || request_.stepLimit > MAX_STEPS
            || address(request_.key.hooks) != address(0) || request_.key.tickSpacing <= 0) revert InvalidQuoteState();

        context.manager = request_.manager;
        context.id = request_.key.toId();
        context.spacing = request_.key.tickSpacing;
        context.zeroForOne = !request_.target0;
        
        (result_.sqrtPriceX96, result_.tick, context.packedProtocolFee, context.lpFee) = request_.manager.getSlot0(context.id);
        if (result_.sqrtPriceX96 < TickMath.MIN_SQRT_PRICE || result_.sqrtPriceX96 >= TickMath.MAX_SQRT_PRICE) {
            revert InvalidQuoteState();
        }
        _direction(context, context.zeroForOne);
        result_.liquidity = request_.manager.getLiquidity(context.id);
        _removeOwned(request_, context, result_);
    }

    function _direction(Context memory context_, bool zeroForOne_) private pure {
        context_.zeroForOne = zeroForOne_;
        context_.protocolFee = zeroForOne_ ? context_.packedProtocolFee.getZeroForOneFee() : context_.packedProtocolFee.getOneForZeroFee();
        context_.fee = context_.protocolFee.calculateSwapFee(context_.lpFee);
    }

    /// @notice The live pool with only this vault's positions removed, before any hypothetical sale.
    function startingPool(Request memory source_) public view returns (PoolState memory pool_) {
        (, Result memory start) = _prepare(source_);
        return PoolState(start.sqrtPriceX96, start.tick, start.liquidity);
    }

    /// @notice Value supplied inventory at a supplied projected pool price/tick/external-liquidity state.
    /// @dev Source positions define the live-storage baseline; projected owned positions never replace that baseline.
    function quoteInventoryAt(Request memory source_, PoolState memory pool_, uint256 total0_, uint256 total1_)
        public view returns (Result memory result_)
    {
        Context memory context;
        (context, result_) = _prepare(source_);
        _atPool(result_, pool_);
        result_.value = source_.target0 ? total0_ : total1_;
        result_.unsold = source_.target0 ? total1_ : total0_;
        if (result_.unsold > uint256(uint128(type(int128).max))) revert QuoteDeltaOverflow();
        _sell(context, result_, source_.stepLimit);
        result_.value += result_.proceeds;
        result_.marketLimited = result_.unsold != 0;
    }

    /// @notice Project an actual exact-input swap through external liquidity plus the supplied current owned positions.
    /// @dev Accumulates full Q128 growth while each owned range is active; rounding occurs at collection, not per step.
    function projectSwap(Request memory source_, PoolState memory pool_, HeldPosition[3] memory held_, bool zeroForOne_, uint256 amount_)
        public view returns (SwapProjection memory projection_)
    {
        if (amount_ > uint256(uint128(type(int128).max))) revert QuoteDeltaOverflow();
        Context memory context;
        (context, projection_.sale) = _prepare(source_);
        _direction(context, zeroForOne_);
        _atPool(projection_.sale, pool_);
        context.held = abi.decode(abi.encode(held_), (HeldPosition[3]));
        context.accrue = true;
        context.costs = true;
        for (uint256 i; i < 3; ++i) {
            HeldPosition memory position = held_[i];
            if (position.liquidity == 0) continue;
            _addBoundary(context, position.lower, position.liquidity, true);
            _addBoundary(context, position.upper, position.liquidity, false);
            if (pool_.tick >= position.lower && pool_.tick < position.upper) projection_.sale.liquidity += position.liquidity;
        }
        projection_.sale.unsold = amount_;
        _sell(context, projection_.sale, source_.stepLimit);
        projection_.sale.marketLimited = projection_.sale.unsold != 0;
        projection_.positions = context.held;
        uint128 externalLiquidity = projection_.sale.liquidity;
        for (uint256 i; i < 3; ++i) {
            HeldPosition memory position = held_[i];
            if (projection_.sale.tick >= position.lower && projection_.sale.tick < position.upper) externalLiquidity -= position.liquidity;
        }
        projection_.pool = PoolState(projection_.sale.sqrtPriceX96, projection_.sale.tick, externalLiquidity);
    }

    function _atPool(Result memory result_, PoolState memory pool_) private pure {
        if (pool_.price < TickMath.MIN_SQRT_PRICE || pool_.price >= TickMath.MAX_SQRT_PRICE) revert InvalidQuoteState();
        result_.sqrtPriceX96 = pool_.price;
        result_.tick = pool_.tick;
        result_.liquidity = pool_.externalLiquidity;
    }

    function _addBoundary(Context memory context_, int24 tick_, uint128 liquidity_, bool lower_) private view {
        uint256 index;
        while (index < context_.count && context_.boundaries[index].tick != tick_) ++index;
        if (index == context_.count) {
            (uint128 gross, int128 net) = context_.manager.getTickLiquidity(context_.id, tick_);
            context_.boundaries[index] = Boundary(tick_, gross, net);
            ++context_.count;
        }
        context_.boundaries[index].gross += liquidity_;
        context_.boundaries[index].net += lower_ ? int256(uint256(liquidity_)) : -int256(uint256(liquidity_));
    }

    function _accrue(Context memory context_, Result memory result_, Step memory step_) private pure {
        if (!context_.accrue || result_.liquidity == 0) return;
        uint256 lpFee = step_.fee;
        if (context_.protocolFee != 0) {
            uint256 protocolAmount = context_.fee == context_.protocolFee ? step_.fee
                : (step_.amountIn + step_.fee) * context_.protocolFee / 1_000_000;
            lpFee -= protocolAmount;
        }
        uint256 growth = FullMath.mulDiv(lpFee, uint256(1) << 128, result_.liquidity);
        for (uint256 i; i < 3; ++i) {
            HeldPosition memory position = context_.held[i];
            if (position.liquidity == 0 || result_.tick < position.lower || result_.tick >= position.upper) continue;
            unchecked {
                if (context_.zeroForOne) context_.held[i].growth0 += growth;
                else context_.held[i].growth1 += growth;
            }
        }
    }

    function _removeOwned(Request memory request_, Context memory context_, Result memory result_) private view {
        for (uint256 i; i < request_.count; ++i) {
            Position memory position = request_.positions[i];
            if (position.lower >= position.upper || position.lower % context_.spacing != 0
                || position.upper % context_.spacing != 0) revert InvalidQuoteState();
            for (uint256 j; j < i; ++j) {
                Position memory earlier = request_.positions[j];
                if (earlier.lower == position.lower && earlier.upper == position.upper && earlier.salt == position.salt) {
                    revert DuplicatePosition();
                }
            }
            (uint128 liquidity, uint256 last0, uint256 last1) = context_.manager.getPositionInfo(
                context_.id, request_.owner, position.lower, position.upper, position.salt
            );
            if (liquidity == 0) continue;
            (uint256 growth0, uint256 growth1) =
                context_.manager.getFeeGrowthInside(context_.id, position.lower, position.upper);
            Types.Principal memory principal =
                Inventory.principal(result_.sqrtPriceX96, position.lower, position.upper, liquidity, false);
            uint256 amount0 = principal.amount0 + Inventory.earnedFee(liquidity, growth0, last0);
            uint256 amount1 = principal.amount1 + Inventory.earnedFee(liquidity, growth1, last1);
            if (amount0 > uint256(uint128(type(int128).max)) || amount1 > uint256(uint128(type(int128).max))) {
                revert QuoteDeltaOverflow();
            }
            context_.collected0 += amount0;
            context_.collected1 += amount1;
            // The stored tick (not inverse sqrt price) determines active liquidity at directional boundaries.
            if (result_.tick >= position.lower && result_.tick < position.upper) result_.liquidity -= liquidity;
            _removeBoundary(context_, position.lower, liquidity, true);
            _removeBoundary(context_, position.upper, liquidity, false);
        }
    }

    function _removeBoundary(Context memory context_, int24 tick_, uint128 liquidity_, bool lower_) private view {
        uint256 index;
        while (index < context_.count && context_.boundaries[index].tick != tick_) ++index;
        if (index == context_.count) {
            (uint128 gross, int128 net) = context_.manager.getTickLiquidity(context_.id, tick_);
            context_.boundaries[index] = Boundary(tick_, gross, net);
            ++context_.count;
        }
        context_.boundaries[index].gross -= liquidity_;
        context_.boundaries[index].net += lower_ ? -int256(uint256(liquidity_)) : int256(uint256(liquidity_));
    }

    function _sell(Context memory context_, Result memory result_, uint256 limit_) private view {
        uint160 priceLimit = context_.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        // At an initialized extreme there may be no legal movement in this direction.
        if (context_.zeroForOne ? result_.sqrtPriceX96 <= priceLimit : result_.sqrtPriceX96 >= priceLimit) return;
        while (result_.unsold != 0 && result_.sqrtPriceX96 != priceLimit) {
            if (result_.steps == limit_) revert QuoteWorkExceeded(result_.steps);
            ++result_.steps;
            Step memory step;
            step.start = result_.sqrtPriceX96;
            (step.tick, step.initialized) = _next(context_, result_.tick);
            if (step.tick < TickMath.MIN_TICK) step.tick = TickMath.MIN_TICK;
            if (step.tick > TickMath.MAX_TICK) step.tick = TickMath.MAX_TICK;
            step.price = TickMath.getSqrtPriceAtTick(step.tick);
            (result_.sqrtPriceX96, step.amountIn, step.amountOut, step.fee) = SwapMath.computeSwapStep(
                step.start, SwapMath.getSqrtPriceTarget(context_.zeroForOne, step.price, priceLimit),
                result_.liquidity, -int256(result_.unsold), context_.fee
            );
            _accrue(context_, result_, step);
            uint256 spent = step.amountIn + step.fee;
            if (context_.costs && spent != 0) result_.executionCostBound += _stepCost(step, context_.zeroForOne);
            result_.sold += spent;
            result_.unsold -= spent;
            result_.proceeds += step.amountOut;
            if (result_.proceeds > uint256(uint128(type(int128).max))) revert QuoteDeltaOverflow();
            if (result_.sqrtPriceX96 == step.price) {
                if (step.initialized) {
                    int256 net = _net(context_, step.tick);
                    int256 nextLiquidity = int256(uint256(result_.liquidity)) + (context_.zeroForOne ? -net : net);
                    if (nextLiquidity < 0 || uint256(nextLiquidity) > type(uint128).max) revert InvalidQuoteState();
                    result_.liquidity = uint128(uint256(nextLiquidity));
                }
                result_.tick = context_.zeroForOne ? step.tick - 1 : step.tick;
            } else if (result_.sqrtPriceX96 != step.start) {
                result_.tick = TickMath.getTickAtSqrtPrice(result_.sqrtPriceX96);
            }
        }
    }

    /// @notice Conservative fee and arithmetic cost allowance for the exact swap through the current pool.
    /// @dev Does not debit value. Execution pays actual fees through PoolManager exactly once.
    function swapCost(Request memory request_, uint256 amount_) public view returns (uint256) {
        request_.count = 0;
        (Context memory context, Result memory result) = _prepare(request_);
        context.costs = true;
        if (amount_ > uint256(uint128(type(int128).max))) revert QuoteDeltaOverflow();
        result.unsold = amount_;
        _sell(context, result, request_.stepLimit);
        return result.executionCostBound;
    }
    /// @dev Each step rounds input up (<1 input unit) and output down (<1 output unit).
    /// Its starting price is the best marginal conversion price along that directional step.
    /// Two ceiling divisions retain a conservative bound without squaring a uint160.
    function _stepCost(Step memory step_, bool zeroForOne_) private pure returns (uint256) {
        uint256 numerator = zeroForOne_ ? uint256(step_.start) : uint256(1) << 96;
        uint256 denominator = zeroForOne_ ? uint256(1) << 96 : uint256(step_.start);
        uint256 converted = FullMath.mulDivRoundingUp(step_.fee + 1, numerator, denominator);
        return FullMath.mulDivRoundingUp(converted, numerator, denominator) + 1;
    }

    function _next(Context memory context_, int24 tick_) private view returns (int24 next_, bool initialized_) {
        int24 compressed = TickBitmap.compress(tick_, context_.spacing);
        if (!context_.zeroForOne) ++compressed;
        (int16 word, uint8 bit) = TickBitmap.position(compressed);
        uint256 bitmap = context_.manager.getTickBitmap(context_.id, word);
        for (uint256 i; i < context_.count; ++i) {
            Boundary memory boundary = context_.boundaries[i];
            (int16 removedWord, uint8 removedBit) = TickBitmap.position(boundary.tick / context_.spacing);
            if (word == removedWord) {
                if (boundary.gross == 0) bitmap &= ~(uint256(1) << removedBit);
                else bitmap |= uint256(1) << removedBit;
            }
        }
        if (context_.zeroForOne) {
            uint256 masked = bitmap & (type(uint256).max >> (255 - bit));
            initialized_ = masked != 0;
            next_ = (compressed - int24(uint24(initialized_ ? bit - BitMath.mostSignificantBit(masked) : bit)))
                * context_.spacing;
        } else {
            uint256 masked = bitmap & (type(uint256).max << bit);
            initialized_ = masked != 0;
            next_ = (compressed + int24(uint24(initialized_ ? BitMath.leastSignificantBit(masked) - bit : 255 - bit)))
                * context_.spacing;
        }
    }

    function _net(Context memory context_, int24 tick_) private view returns (int256 net_) {
        for (uint256 i; i < context_.count; ++i) {
            if (context_.boundaries[i].tick == tick_) return context_.boundaries[i].net;
        }
        (, int128 net) = context_.manager.getTickLiquidity(context_.id, tick_);
        return net;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote[]

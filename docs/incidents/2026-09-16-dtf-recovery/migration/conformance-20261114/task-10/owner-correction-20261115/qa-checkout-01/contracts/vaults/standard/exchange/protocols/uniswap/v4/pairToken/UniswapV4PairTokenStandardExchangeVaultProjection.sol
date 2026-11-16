// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TickBitmap} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickBitmap.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol";
import {ProtocolFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {BitMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol";
import {SafeCast} from "@crane/contracts/protocols/dexes/uniswap/libraries/SafeCast.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultProjection[]
/// @notice Exact, memory-only transitions for the family's hookless V4 position.
/// @dev Never changes the local custody ledger or supply. A returned failure invalidates
/// the ENTIRE candidate, including its mutable overlays. Start alternatives with fresh().
library UniswapV4PairTokenStandardExchangeVaultProjection {
    // tag::DirectCallNotAllowed-3921c703[]
    /// @custom:signature DirectCallNotAllowed()
    /// @custom:selector 0x3921c703
    error DirectCallNotAllowed();
    // end::DirectCallNotAllowed-3921c703[]
    using PoolIdLibrary for PoolKey;
    using ProtocolFeeLibrary for uint24;
    using ProtocolFeeLibrary for uint16;

    // Each loop reads at most one new word and crosses at most one new tick.
    // The two owned boundaries are the only additional keys modified by this family.
    uint256 private constant TICK_CACHE_CAPACITY = Types.QUOTE_MAX_INITIALIZED_TICK_CROSSINGS + 2;
    uint256 private constant Q128 = 1 << 128;
    uint256 private constant MAX_POSITIVE_DELTA = uint256(uint128(type(int128).max));

    struct SwapState {
        uint256 remaining;
        uint256 spent;
        uint256 received;
        uint16 protocolFee;
        uint24 swapFee;
        bool zeroForOne;
        uint160 limit;
        Types.Phase phase;
    }

    struct ModifyState {
        int128 delta;
        uint256 lowerIndex;
        uint256 upperIndex;
        bool flippedLower;
        bool flippedUpper;
        uint256 inside0;
        uint256 inside1;
        uint256 fee0;
        uint256 fee1;
        int256 principal0;
        int256 principal1;
    }

    /* -------------------------------------------------------------------------- */
    /*                          Loading and candidate copies                      */
    /* -------------------------------------------------------------------------- */

    // tag::load[]
    /// @notice Load a fresh candidate with canonical state and the two owned boundaries.
    function load(Types.Config memory config_, Types.Inventory memory inventory_, uint256 supply_, address owner_)
        internal
        view
        returns (Types.ProjectedState memory)
    {
        return fresh(loadSnapshot(config_, inventory_, supply_, owner_));
    }

    /// @notice Read canonical manager state for the zero-salt owner position.
    function loadSnapshot(Types.Config memory config_, Types.Inventory memory inventory_, uint256 supply_, address owner_)
        internal
        view
        returns (Types.Snapshot memory state)
    {
        state.config = config_;
        state.inventory = inventory_;
        state.supply = supply_;
        IPoolManager manager = config_.poolManager;
        PoolId id = config_.poolKey.toId();
        (state.pool.sqrtPriceX96, state.pool.tick, state.pool.protocolFee, state.pool.lpFee) =
            StateLibrary.getSlot0(manager, id);
        if (state.pool.sqrtPriceX96 == 0) revert Pool.PoolNotInitialized();
        state.pool.liquidity = StateLibrary.getLiquidity(manager, id);
        (state.pool.feeGrowthGlobal0X128, state.pool.feeGrowthGlobal1X128) =
            StateLibrary.getFeeGrowthGlobals(manager, id);
        bytes32 positionKey =
            Position.calculatePositionKey(owner_, config_.tickLower, config_.tickUpper, bytes32(0));
        (
            state.position.liquidity,
            state.position.feeGrowthInside0LastX128,
            state.position.feeGrowthInside1LastX128
        ) = StateLibrary.getPositionInfo(manager, id, positionKey);
    }
    // end::load[]

    // tag::fresh[]
    /// @notice Create an isolated candidate; snapshot and initial/current tick values never alias.
    function fresh(Types.Snapshot memory original_) internal view returns (Types.ProjectedState memory projected) {
        projected.state = abi.decode(abi.encode(original_), (Types.Snapshot));
        projected.ticks = new Types.TickState[](2);
        projected.words = new Types.BitmapWord[](2);
        _tick(projected, original_.config.tickLower);
        _tick(projected, original_.config.tickUpper);
        (int16 lowerWord,) = TickBitmap.position(original_.config.tickLower / original_.config.poolKey.tickSpacing);
        (int16 upperWord,) = TickBitmap.position(original_.config.tickUpper / original_.config.poolKey.tickSpacing);
        _word(projected, lowerWord);
        _word(projected, upperWord);
    }
    // end::fresh[]

    // tag::capture[]
    /// @notice Freeze one action checkpoint without retaining unused cache capacity.
    /// @dev Captures are for witness materialization, not further projection.
    /// @custom:signature capture(UniswapV4PairTokenStandardExchangeVaultTypes.ProjectedState)
    /// @custom:selector 0x9acbbb2d
    function capture(Types.ProjectedState memory projected_)
        public
        view
        returns (Types.ProjectedState memory checkpoint)
    {
        _requireDelegateCall();
        checkpoint.state = abi.decode(abi.encode(projected_.state), (Types.Snapshot));
        checkpoint.tickCount = projected_.tickCount;
        checkpoint.wordCount = projected_.wordCount;
        checkpoint.swapSteps = projected_.swapSteps;
        checkpoint.tickCrossings = projected_.tickCrossings;
        checkpoint.ticks = new Types.TickState[](checkpoint.tickCount);
        checkpoint.words = new Types.BitmapWord[](checkpoint.wordCount);
        for (uint256 i; i < checkpoint.tickCount; ++i) {
            checkpoint.ticks[i] = Types.TickState(
                projected_.ticks[i].tick, _copyTick(projected_.ticks[i].initial), _copyTick(projected_.ticks[i].current)
            );
        }
        for (uint256 i; i < checkpoint.wordCount; ++i) {
            checkpoint.words[i] = Types.BitmapWord(
                projected_.words[i].wordPos, projected_.words[i].initial, projected_.words[i].current
            );
        }
    }
    // end::capture[]

    /* -------------------------------------------------------------------------- */
    /*                         Canonical position transitions                     */
    /* -------------------------------------------------------------------------- */

    // tag::modify[]
    /// @notice Project an owned liquidity modification or nonempty-position poke.
    /// @dev Principal and fees are narrowed independently before their per-leg sum.
    function modify(Types.ProjectedState memory projected_, int256 liquidityDelta_, Types.Phase phase_)
        internal
        view
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued, Types.Failure memory failure)
    {
        ModifyState memory work;
        if (liquidityDelta_ < type(int128).min || liquidityDelta_ > type(int128).max) {
            return (callerDelta, feesAccrued, _castFailure(phase_, Types.FailureKind.LiquidityLimit));
        }
        work.delta = int128(liquidityDelta_);
        if (work.delta == 0 && projected_.state.position.liquidity == 0) {
            return (
                callerDelta,
                feesAccrued,
                _failure(phase_, Types.FailureKind.Economic, abi.encodeWithSelector(Position.CannotUpdateEmptyPosition.selector))
            );
        }
        int256 ownedAfter = int256(uint256(projected_.state.position.liquidity)) + liquidityDelta_;
        if (ownedAfter < 0 || ownedAfter > type(int128).max) {
            return (callerDelta, feesAccrued, _castFailure(phase_, Types.FailureKind.LiquidityLimit));
        }
        work.lowerIndex = _tick(projected_, projected_.state.config.tickLower);
        work.upperIndex = _tick(projected_, projected_.state.config.tickUpper);
        if (work.delta != 0) {
            failure = _tickCapacity(projected_, work.lowerIndex, work.delta, phase_);
            if (failure.kind != Types.FailureKind.None) return (callerDelta, feesAccrued, failure);
            failure = _tickCapacity(projected_, work.upperIndex, work.delta, phase_);
            if (failure.kind != Types.FailureKind.None) return (callerDelta, feesAccrued, failure);
            work.flippedLower = _updateTick(projected_, work.lowerIndex, work.delta, false);
            work.flippedUpper = _updateTick(projected_, work.upperIndex, work.delta, true);
            if (work.flippedLower) _flip(projected_, projected_.state.config.tickLower);
            if (work.flippedUpper) _flip(projected_, projected_.state.config.tickUpper);
        }
        (work.inside0, work.inside1) = _inside(projected_, work.lowerIndex, work.upperIndex);
        (work.fee0, work.fee1) = _fees(projected_.state.position, work.inside0, work.inside1);
        if (work.fee0 > MAX_POSITIVE_DELTA || work.fee1 > MAX_POSITIVE_DELTA) {
            // A fee-collection failure is not maintenance addition capacity.
            return (callerDelta, feesAccrued, _castFailure(phase_, Types.FailureKind.Economic));
        }
        projected_.state.position.liquidity = uint128(uint256(ownedAfter));
        projected_.state.position.feeGrowthInside0LastX128 = work.inside0;
        projected_.state.position.feeGrowthInside1LastX128 = work.inside1;
        if (work.delta < 0) {
            if (work.flippedLower) delete projected_.ticks[work.lowerIndex].current;
            if (work.flippedUpper) delete projected_.ticks[work.upperIndex].current;
        }
        (work.principal0, work.principal1) = _principalDelta(projected_.state, work.delta);
        if (!_fitsDelta(work.principal0) || !_fitsDelta(work.principal1)) {
            return (callerDelta, feesAccrued, _castFailure(phase_, Types.FailureKind.LiquidityLimit));
        }
        int256 net0 = work.principal0 + int256(work.fee0);
        int256 net1 = work.principal1 + int256(work.fee1);
        if (
            !_fitsDelta(net0) || !_fitsDelta(net1)
                || net0 == type(int128).min || net1 == type(int128).min
        ) {
            // A net debt is settled once as a positive int128 manager credit.
            // Its domain is narrower than the signed negative delta domain.
            return (callerDelta, feesAccrued, _castFailure(phase_, Types.FailureKind.Economic));
        }
        if (
            work.delta != 0 && projected_.state.pool.tick >= projected_.state.config.tickLower
                && projected_.state.pool.tick < projected_.state.config.tickUpper
        ) {
            int256 activeAfter = int256(uint256(projected_.state.pool.liquidity)) + work.delta;
            if (activeAfter < 0 || uint256(activeAfter) > type(uint128).max) {
                return (callerDelta, feesAccrued, _castFailure(phase_, Types.FailureKind.LiquidityLimit));
            }
            projected_.state.pool.liquidity = uint128(uint256(activeAfter));
        }
        callerDelta = toBalanceDelta(int128(net0), int128(net1));
        feesAccrued = toBalanceDelta(int128(int256(work.fee0)), int128(int256(work.fee1)));
    }
    // end::modify[]

    function _principalDelta(Types.Snapshot memory state_, int128 delta_)
        private
        pure
        returns (int256 principal0, int256 principal1)
    {
        if (delta_ == 0) return (0, 0);
        uint160 lower = TickMath.getSqrtPriceAtTick(state_.config.tickLower);
        uint160 upper = TickMath.getSqrtPriceAtTick(state_.config.tickUpper);
        if (state_.pool.tick < state_.config.tickLower) {
            principal0 = SqrtPriceMath.getAmount0Delta(lower, upper, delta_);
        } else if (state_.pool.tick < state_.config.tickUpper) {
            principal0 = SqrtPriceMath.getAmount0Delta(state_.pool.sqrtPriceX96, upper, delta_);
            principal1 = SqrtPriceMath.getAmount1Delta(lower, state_.pool.sqrtPriceX96, delta_);
        } else {
            principal1 = SqrtPriceMath.getAmount1Delta(lower, upper, delta_);
        }
    }

    function _tickCapacity(
        Types.ProjectedState memory projected_,
        uint256 index_,
        int128 delta_,
        Types.Phase phase_
    ) private pure returns (Types.Failure memory failure) {
        int256 grossAfter = int256(uint256(projected_.ticks[index_].current.liquidityGross)) + delta_;
        if (grossAfter < 0 || uint256(grossAfter) > type(uint128).max) {
            return _castFailure(phase_, Types.FailureKind.LiquidityLimit);
        }
        if (
            delta_ > 0
                && uint256(grossAfter) > Pool.tickSpacingToMaxLiquidityPerTick(projected_.state.config.poolKey.tickSpacing)
        ) {
            return _failure(
                phase_,
                Types.FailureKind.LiquidityLimit,
                abi.encodeWithSelector(Pool.TickLiquidityOverflow.selector, projected_.ticks[index_].tick)
            );
        }
    }

    function _updateTick(Types.ProjectedState memory projected_, uint256 index_, int128 delta_, bool upper_)
        private
        pure
        returns (bool flipped)
    {
        Pool.TickInfo memory info = projected_.ticks[index_].current;
        uint128 beforeGross = info.liquidityGross;
        info.liquidityGross = uint128(uint256(int256(uint256(beforeGross)) + delta_));
        flipped = (beforeGross == 0) != (info.liquidityGross == 0);
        if (beforeGross == 0 && projected_.ticks[index_].tick <= projected_.state.pool.tick) {
            info.feeGrowthOutside0X128 = projected_.state.pool.feeGrowthGlobal0X128;
            info.feeGrowthOutside1X128 = projected_.state.pool.feeGrowthGlobal1X128;
        }
        // Canonical per-tick capacity guarantees that liquidityNet remains signed.
        info.liquidityNet = upper_ ? info.liquidityNet - delta_ : info.liquidityNet + delta_;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Canonical exact-input swap                      */
    /* -------------------------------------------------------------------------- */

    // tag::swap[]
    /// @notice Project one swap, sharing the candidate's counter with all earlier swaps.
    /// @dev The amountSpecified magnitude may reach 2**255; only actual consumed/received
    /// deltas must fit int128. A large partially filled request is not rejected early.
    function swap(
        Types.ProjectedState memory projected_,
        bool zeroForOne_,
        uint256 amountIn_,
        uint160 sqrtPriceLimitX96_,
        Types.Phase phase_
    ) internal view returns (BalanceDelta delta, Types.Failure memory failure) {
        Types.ProjectedState memory result_;
        (result_, delta, failure) = UniswapV4PairTokenStandardExchangeVaultSwapProjection.projectSwap(
            projected_, zeroForOne_, amountIn_, sqrtPriceLimitX96_, phase_
        );
        // Preserve the caller's Snapshot/Inventory aliases: a swap only changes
        // pool state and the tick/word overlays, never local ownership categories.
        projected_.state.pool = result_.state.pool;
        projected_.ticks = result_.ticks;
        projected_.words = result_.words;
        projected_.tickCount = result_.tickCount;
        projected_.wordCount = result_.wordCount;
        projected_.swapSteps = result_.swapSteps;
        projected_.tickCrossings = result_.tickCrossings;
    }

    /// @notice Fixed linked swap projector; the wrapper adopts its explicit result.
    function projectSwapInternal(
        Types.ProjectedState memory projected_,
        bool zeroForOne_,
        uint256 amountIn_,
        uint160 sqrtPriceLimitX96_,
        Types.Phase phase_
    ) internal view returns (Types.ProjectedState memory, BalanceDelta, Types.Failure memory) {
        _requireDelegateCall();
        (BalanceDelta delta_, Types.Failure memory failure_) =
            _swap(projected_, zeroForOne_, amountIn_, sqrtPriceLimitX96_, phase_);
        return (projected_, delta_, failure_);
    }

    function _swap(
        Types.ProjectedState memory projected_,
        bool zeroForOne_,
        uint256 amountIn_,
        uint160 sqrtPriceLimitX96_,
        Types.Phase phase_
    ) private view returns (BalanceDelta delta, Types.Failure memory failure) {
        if (amountIn_ == 0) {
            return (
                delta,
                _failure(phase_, Types.FailureKind.Economic, abi.encodeWithSelector(IPoolManager.SwapAmountCannotBeZero.selector))
            );
        }
        if (amountIn_ > (uint256(1) << 255)) {
            return (delta, _castFailure(phase_, Types.FailureKind.DeltaLimit));
        }
        uint160 price = projected_.state.pool.sqrtPriceX96;
        if (zeroForOne_ ? sqrtPriceLimitX96_ >= price : sqrtPriceLimitX96_ <= price) {
            return (
                delta,
                _failure(
                    phase_, Types.FailureKind.PriceLimit,
                    abi.encodeWithSelector(Pool.PriceLimitAlreadyExceeded.selector, price, sqrtPriceLimitX96_)
                )
            );
        }
        if (zeroForOne_ ? sqrtPriceLimitX96_ <= TickMath.MIN_SQRT_PRICE : sqrtPriceLimitX96_ >= TickMath.MAX_SQRT_PRICE) {
            return (
                delta,
                _failure(
                    phase_, Types.FailureKind.PriceLimit,
                    abi.encodeWithSelector(Pool.PriceLimitOutOfBounds.selector, sqrtPriceLimitX96_)
                )
            );
        }
        SwapState memory work;
        work.remaining = amountIn_;
        work.zeroForOne = zeroForOne_;
        work.limit = sqrtPriceLimitX96_;
        work.phase = phase_;
        work.protocolFee = zeroForOne_
            ? projected_.state.pool.protocolFee.getZeroForOneFee()
            : projected_.state.pool.protocolFee.getOneForZeroFee();
        work.swapFee = work.protocolFee == 0
            ? projected_.state.pool.lpFee
            : work.protocolFee.calculateSwapFee(projected_.state.pool.lpFee);
        while (work.remaining != 0 && projected_.state.pool.sqrtPriceX96 != work.limit) {
            if (projected_.swapSteps == Types.QUOTE_MAX_SWAP_STEPS) {
                return (
                    delta,
                    _failure(
                        phase_, Types.FailureKind.WorkLimit,
                        abi.encodeWithSelector(
                            IVault.QuoteWorkExceeded.selector,
                            Types.QUOTE_MAX_SWAP_STEPS + 1,
                            Types.QUOTE_MAX_SWAP_STEPS
                        )
                    )
                );
            }
            ++projected_.swapSteps;
            failure = _swapStep(projected_, work);
            if (failure.kind != Types.FailureKind.None) return (delta, failure);
        }
        int128 spent = int128(-int256(work.spent));
        int128 received = int128(int256(work.received));
        delta = zeroForOne_ ? toBalanceDelta(spent, received) : toBalanceDelta(received, spent);
    }
    // end::swap[]

    function _swapStep(Types.ProjectedState memory projected_, SwapState memory work_)
        private
        view
        returns (Types.Failure memory failure)
    {
        Pool.StepComputations memory step;
        step.sqrtPriceStartX96 = projected_.state.pool.sqrtPriceX96;
        {
            bool admitted_;
            (step.tickNext, step.initialized, admitted_) = _nextTick(projected_, work_.zeroForOne);
            if (!admitted_) {
                return _failure(work_.phase, Types.FailureKind.WorkLimit, abi.encodeWithSelector(
                    IVault.QuoteBitmapWordsExceeded.selector,
                    projected_.wordCount + 1, Types.QUOTE_MAX_BITMAP_WORDS
                ));
            }
        }
        if (step.tickNext < TickMath.MIN_TICK) step.tickNext = TickMath.MIN_TICK;
        if (step.tickNext > TickMath.MAX_TICK) step.tickNext = TickMath.MAX_TICK;
        step.sqrtPriceNextX96 = TickMath.getSqrtPriceAtTick(step.tickNext);
        int256 remaining;
        unchecked {
            remaining = -int256(work_.remaining);
        }
        (projected_.state.pool.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) =
            SwapMath.computeSwapStep(
                step.sqrtPriceStartX96,
                SwapMath.getSqrtPriceTarget(work_.zeroForOne, step.sqrtPriceNextX96, work_.limit),
                projected_.state.pool.liquidity,
                remaining,
                work_.swapFee
            );
        uint256 paid = step.amountIn + step.feeAmount;
        // Exact one-shot settle casts the positive paid amount to int128.
        // Pool.swap can encode -2**127, but its corresponding settlement cannot.
        if (paid > MAX_POSITIVE_DELTA - work_.spent || step.amountOut > MAX_POSITIVE_DELTA - work_.received) {
            return _castFailure(work_.phase, Types.FailureKind.DeltaLimit);
        }
        work_.remaining -= paid;
        work_.spent += paid;
        work_.received += step.amountOut;
        if (work_.protocolFee != 0) {
            uint256 protocolAmount = work_.swapFee == work_.protocolFee
                ? step.feeAmount
                : paid * work_.protocolFee / ProtocolFeeLibrary.PIPS_DENOMINATOR;
            step.feeAmount -= protocolAmount;
        }
        if (projected_.state.pool.liquidity != 0) {
            unchecked {
                uint256 growth = step.feeAmount * Q128 / projected_.state.pool.liquidity;
                if (work_.zeroForOne) projected_.state.pool.feeGrowthGlobal0X128 += growth;
                else projected_.state.pool.feeGrowthGlobal1X128 += growth;
            }
        }
        if (projected_.state.pool.sqrtPriceX96 == step.sqrtPriceNextX96) {
            if (step.initialized) {
                if (projected_.tickCrossings == Types.QUOTE_MAX_INITIALIZED_TICK_CROSSINGS) {
                    return _failure(work_.phase, Types.FailureKind.WorkLimit, abi.encodeWithSelector(
                        IVault.QuoteTickCrossingsExceeded.selector,
                        projected_.tickCrossings + 1, Types.QUOTE_MAX_INITIALIZED_TICK_CROSSINGS
                    ));
                }
                ++projected_.tickCrossings;
                uint256 index = _tick(projected_, step.tickNext);
                Pool.TickInfo memory info = projected_.ticks[index].current;
                unchecked {
                    info.feeGrowthOutside0X128 =
                        projected_.state.pool.feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
                    info.feeGrowthOutside1X128 =
                        projected_.state.pool.feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
                }
                int128 net = work_.zeroForOne ? -info.liquidityNet : info.liquidityNet;
                projected_.state.pool.liquidity = LiquidityMath.addDelta(projected_.state.pool.liquidity, net);
            }
            projected_.state.pool.tick = work_.zeroForOne ? step.tickNext - 1 : step.tickNext;
        } else if (projected_.state.pool.sqrtPriceX96 != step.sqrtPriceStartX96) {
            projected_.state.pool.tick = TickMath.getTickAtSqrtPrice(projected_.state.pool.sqrtPriceX96);
        }
    }

    function _nextTick(Types.ProjectedState memory projected_, bool lte_)
        private
        view
        returns (int24 next, bool initialized, bool admitted)
    {
        int24 spacing = projected_.state.config.poolKey.tickSpacing;
        int24 compressed = TickBitmap.compress(projected_.state.pool.tick, spacing);
        if (!lte_) ++compressed;
        (int16 wordPos, uint8 bitPos) = TickBitmap.position(compressed);
        if (projected_.wordCount == Types.QUOTE_MAX_BITMAP_WORDS) {
            bool cached_;
            for (uint256 i_; i_ < projected_.wordCount; ++i_) {
                if (projected_.words[i_].wordPos == wordPos) {
                    cached_ = true;
                    break;
                }
            }
            if (!cached_) return (0, false, false);
        }
        uint256 wordIndex = _word(projected_, wordPos);
        uint256 bits = projected_.words[wordIndex].current;
        unchecked {
            if (lte_) {
                uint256 masked = bits & (type(uint256).max >> (255 - bitPos));
                initialized = masked != 0;
                next = initialized
                    ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * spacing
                    : (compressed - int24(uint24(bitPos))) * spacing;
            } else {
                uint256 masked = bits & ~((uint256(1) << bitPos) - 1);
                initialized = masked != 0;
                next = initialized
                    ? (compressed + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * spacing
                    : (compressed + int24(uint24(255 - bitPos))) * spacing;
            }
        }
        admitted = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                      Fee-inclusive accounting observation                 */
    /* -------------------------------------------------------------------------- */

    // tag::positionAmounts[]
    /// @notice Clamped removable principal, booked idle and current uncollected fees.
    /// @dev Excludes all caller, exit, refund and wrapped reservations.
    function positionAmounts(Types.ProjectedState memory projected_)
        internal
        view
        returns (Types.Amounts memory amounts)
    {
        uint160 lower = TickMath.getSqrtPriceAtTick(projected_.state.config.tickLower);
        uint160 upper = TickMath.getSqrtPriceAtTick(projected_.state.config.tickUpper);
        uint160 price = projected_.state.pool.sqrtPriceX96;
        if (price < lower) price = lower;
        if (price > upper) price = upper;
        amounts.amount0 = SqrtPriceMath.getAmount0Delta(price, upper, projected_.state.position.liquidity, false);
        amounts.amount1 = SqrtPriceMath.getAmount1Delta(lower, price, projected_.state.position.liquidity, false);
        (uint256 inside0, uint256 inside1) = _inside(
            projected_, _tick(projected_, projected_.state.config.tickLower), _tick(projected_, projected_.state.config.tickUpper)
        );
        (uint256 fee0, uint256 fee1) = _fees(projected_.state.position, inside0, inside1);
        amounts.amount0 += projected_.state.inventory.booked.amount0 + fee0;
        amounts.amount1 += projected_.state.inventory.booked.amount1 + fee1;
    }
    // end::positionAmounts[]

    function _inside(Types.ProjectedState memory projected_, uint256 lower_, uint256 upper_)
        private
        pure
        returns (uint256 inside0, uint256 inside1)
    {
        Pool.TickInfo memory lower = projected_.ticks[lower_].current;
        Pool.TickInfo memory upper = projected_.ticks[upper_].current;
        unchecked {
            if (projected_.state.pool.tick < projected_.state.config.tickLower) {
                return (
                    lower.feeGrowthOutside0X128 - upper.feeGrowthOutside0X128,
                    lower.feeGrowthOutside1X128 - upper.feeGrowthOutside1X128
                );
            }
            if (projected_.state.pool.tick >= projected_.state.config.tickUpper) {
                return (
                    upper.feeGrowthOutside0X128 - lower.feeGrowthOutside0X128,
                    upper.feeGrowthOutside1X128 - lower.feeGrowthOutside1X128
                );
            }
            return (
                projected_.state.pool.feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128 - upper.feeGrowthOutside0X128,
                projected_.state.pool.feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128 - upper.feeGrowthOutside1X128
            );
        }
    }

    function _fees(Position.State memory position_, uint256 inside0_, uint256 inside1_)
        private
        pure
        returns (uint256 fee0, uint256 fee1)
    {
        unchecked {
            fee0 = FullMath.mulDiv(inside0_ - position_.feeGrowthInside0LastX128, position_.liquidity, Q128);
            fee1 = FullMath.mulDiv(inside1_ - position_.feeGrowthInside1LastX128, position_.liquidity, Q128);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                       Full-plan read-set witnesses                         */
    /* -------------------------------------------------------------------------- */

    // tag::readKeys[]
    /// @notice Ordered unique keys; every checkpoint must use this complete-plan order.
    function readKeys(Types.ProjectedState memory projected_)
        internal
        pure
        returns (int24[] memory ticks, int16[] memory words)
    {
        ticks = new int24[](projected_.tickCount);
        words = new int16[](projected_.wordCount);
        for (uint256 i; i < ticks.length; ++i) ticks[i] = projected_.ticks[i].tick;
        for (uint256 i; i < words.length; ++i) words[i] = projected_.words[i].wordPos;
    }
    // end::readKeys[]

    // tag::witness[]
    /// @notice Materialize this state against its own complete read set.
    /// @custom:signature witness(UniswapV4PairTokenStandardExchangeVaultTypes.ProjectedState)
    /// @custom:selector 0x28f43d6f
    function witness(Types.ProjectedState memory projected_) public view returns (Types.Witness memory) {
        _requireDelegateCall();
        return witness(projected_, projected_);
    }

    // tag::witness-13c62e10[]
    /// @notice Materialize a captured phase against the final candidate's complete keys.
    /// @dev Keys not yet seen at the phase use their immutable initial values. Every
    /// write goes through the cache, so an unseen key cannot have been changed by us.
    /// This avoids replaying swaps or charging a second set of planning iterations.
    /// @custom:signature witness(UniswapV4PairTokenStandardExchangeVaultTypes.ProjectedState,UniswapV4PairTokenStandardExchangeVaultTypes.ProjectedState)
    /// @custom:selector 0x13c62e10
    function witness(Types.ProjectedState memory phase_, Types.ProjectedState memory complete_)
        public
        view
        returns (Types.Witness memory result)
    {
        _requireDelegateCall();
        result.stateHash = _stateHash(phase_.state);
        for (uint256 i; i < complete_.tickCount; ++i) {
            Pool.TickInfo memory info = complete_.ticks[i].initial;
            // A capture is an immutable prefix of this candidate's append-only
            // cache. Later discoveries cannot reorder an earlier checkpoint.
            if (i < phase_.tickCount) info = phase_.ticks[i].current;
            result.ticksHash = keccak256(abi.encode(result.ticksHash, complete_.ticks[i].tick, info));
        }
        for (uint256 i; i < complete_.wordCount; ++i) {
            uint256 value = complete_.words[i].initial;
            if (i < phase_.wordCount) value = phase_.words[i].current;
            result.wordsHash = keccak256(abi.encode(result.wordsHash, complete_.words[i].wordPos, value));
        }
    }
    // end::witness-13c62e10[]
    // end::witness[]

    // tag::check[]
    /// @notice Validate fresh canonical manager/config assumptions against a phase witness.
    /// @dev Inventory and supply are intentionally excluded. Execution separately checks
    /// its expected book/supply at ledger checkpoints; burns, reservations and pulls
    /// between manager actions must not invalidate the canonical-state witness.
    /// @custom:signature check(UniswapV4PairTokenStandardExchangeVaultTypes.Snapshot,address,int24[],int16[],UniswapV4PairTokenStandardExchangeVaultTypes.Witness)
    /// @custom:selector 0xcf5cbc23
    function check(
        Types.Snapshot memory liveLocal_,
        address owner_,
        int24[] memory ticks_,
        int16[] memory words_,
        Types.Witness memory expected_
    ) public view returns (bool) {
        _requireDelegateCall();
        Types.Snapshot memory live =
            loadSnapshot(liveLocal_.config, liveLocal_.inventory, liveLocal_.supply, owner_);
        if (_stateHash(live) != expected_.stateHash) return false;
        Types.Witness memory actual;
        for (uint256 i; i < ticks_.length; ++i) {
            Pool.TickInfo memory info = _readTick(live.config, ticks_[i]);
            actual.ticksHash = keccak256(abi.encode(actual.ticksHash, ticks_[i], info));
        }
        for (uint256 i; i < words_.length; ++i) {
            uint256 value = StateLibrary.getTickBitmap(live.config.poolManager, live.config.poolKey.toId(), words_[i]);
            actual.wordsHash = keccak256(abi.encode(actual.wordsHash, words_[i], value));
        }
        return actual.ticksHash == expected_.ticksHash && actual.wordsHash == expected_.wordsHash;
    }
    // end::check[]

    function _stateHash(Types.Snapshot memory state_) private pure returns (bytes32) {
        return keccak256(abi.encode(state_.config, state_.pool, state_.position));
    }

    function _requireDelegateCall() private view {
        bytes32 executingHash_;
        assembly ("memory-safe") {
            let scratch_ := mload(0x40)
            codecopy(scratch_, 0, codesize())
            executingHash_ := keccak256(scratch_, codesize())
        }
        if (address(this).codehash == executingHash_) revert DirectCallNotAllowed();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Lazy overlays                                */
    /* -------------------------------------------------------------------------- */

    function _tick(Types.ProjectedState memory projected_, int24 tick_) private view returns (uint256 index) {
        for (; index < projected_.tickCount; ++index) {
            if (projected_.ticks[index].tick == tick_) return index;
        }
        Pool.TickInfo memory info = _readTick(projected_.state.config, tick_);
        if (index == projected_.ticks.length) {
            uint256 capacity = index * 2;
            if (capacity > TICK_CACHE_CAPACITY) capacity = TICK_CACHE_CAPACITY;
            Types.TickState[] memory expanded = new Types.TickState[](capacity);
            for (uint256 i; i < index; ++i) expanded[i] = projected_.ticks[i];
            projected_.ticks = expanded;
        }
        projected_.ticks[index] = Types.TickState(tick_, _copyTick(info), info);
        ++projected_.tickCount;
    }

    function _word(Types.ProjectedState memory projected_, int16 word_) private view returns (uint256 index) {
        for (; index < projected_.wordCount; ++index) {
            if (projected_.words[index].wordPos == word_) return index;
        }
        uint256 value = StateLibrary.getTickBitmap(
            projected_.state.config.poolManager, projected_.state.config.poolKey.toId(), word_
        );
        if (index == projected_.words.length) {
            uint256 capacity = index * 2;
            if (capacity > Types.QUOTE_MAX_BITMAP_WORDS) capacity = Types.QUOTE_MAX_BITMAP_WORDS;
            Types.BitmapWord[] memory expanded = new Types.BitmapWord[](capacity);
            for (uint256 i; i < index; ++i) expanded[i] = projected_.words[i];
            projected_.words = expanded;
        }
        projected_.words[index] = Types.BitmapWord(word_, value, value);
        ++projected_.wordCount;
    }

    function _flip(Types.ProjectedState memory projected_, int24 tick_) private view {
        int24 spacing = projected_.state.config.poolKey.tickSpacing;
        if (tick_ % spacing != 0) revert TickBitmap.TickMisaligned(tick_, spacing);
        (int16 wordPos, uint8 bitPos) = TickBitmap.position(tick_ / spacing);
        uint256 wordIndex = _word(projected_, wordPos);
        projected_.words[wordIndex].current ^= uint256(1) << bitPos;
    }

    function _readTick(Types.Config memory config_, int24 tick_) private view returns (Pool.TickInfo memory info) {
        (info.liquidityGross, info.liquidityNet, info.feeGrowthOutside0X128, info.feeGrowthOutside1X128) =
            StateLibrary.getTickInfo(config_.poolManager, config_.poolKey.toId(), tick_);
    }

    function _copyTick(Pool.TickInfo memory info_) private pure returns (Pool.TickInfo memory) {
        return Pool.TickInfo(
            info_.liquidityGross, info_.liquidityNet, info_.feeGrowthOutside0X128, info_.feeGrowthOutside1X128
        );
    }

    function _fitsDelta(int256 value_) private pure returns (bool) {
        return value_ >= type(int128).min && value_ <= type(int128).max;
    }

    function _castFailure(Types.Phase phase_, Types.FailureKind kind_) private pure returns (Types.Failure memory) {
        return _failure(phase_, kind_, abi.encodeWithSelector(SafeCast.SafeCastOverflow.selector));
    }

    function _failure(Types.Phase phase_, Types.FailureKind kind_, bytes memory data_)
        private
        pure
        returns (Types.Failure memory)
    {
        return Types.Failure(phase_, kind_, data_);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultProjection[]

/// @notice Fixed linked boundary for the canonical swap loop.
/// @dev The internal kernel remains beside the other canonical transitions.
library UniswapV4PairTokenStandardExchangeVaultSwapProjection {
    // tag::projectSwap-dd1a6086[]
    /// @custom:signature projectSwap(UniswapV4PairTokenStandardExchangeVaultTypes.ProjectedState,bool,uint256,uint160,UniswapV4PairTokenStandardExchangeVaultTypes.Phase)
    /// @custom:selector 0xdd1a6086
    function projectSwap(
        Types.ProjectedState memory projected_,
        bool zeroForOne_,
        uint256 amountIn_,
        uint160 sqrtPriceLimitX96_,
        Types.Phase phase_
    ) public view returns (Types.ProjectedState memory, BalanceDelta, Types.Failure memory) {
        return UniswapV4PairTokenStandardExchangeVaultProjection.projectSwapInternal(
            projected_, zeroForOne_, amountIn_, sqrtPriceLimitX96_, phase_
        );
    }
    // end::projectSwap-dd1a6086[]
}

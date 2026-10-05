// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickBitmap} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickBitmap.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol";
import {ProtocolFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol";
import {BitMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityMath.sol";
import {StandardExchangeConstantProduct as ConstantProduct} from "../../../../StandardExchangeConstantProduct.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "../UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "../UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath as Analytic} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition[]
/// @notice Bounded segment walk and one exact-input certification. Not production dispatch.
library UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint32 internal constant MAX_STEPS = 64;
    uint32 internal constant MAX_PLACEMENT = 3;
    uint256 internal constant FEE = 1_000_000;
    uint16 internal constant IMPACT_BPS = 50;

    enum Failure {
        None,
        Degenerate,
        NegativeDiscriminant,
        OutOfDomain,
        Unrepresentable,
        ZeroLiquidity,
        EmptyBook,
        WorkLimit,
        Rejected
    }

    struct TickOverlay {
        int24 tick;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    struct ProjectedPoolOverlay {
        bool useOverlay;
        uint128 activeLiquidity;
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 lpFee;
        uint24 protocolFees;
        TickOverlay[] ticks;
    }

    struct Work {
        uint32 discoveryCoreSteps;
        uint32 bitmapWordReads;
        uint32 certificationCoreSteps;
        uint32 placementEvaluations;
    }

    struct Walk {
        Types.Snapshot state;
        Quotes.Params params;
        ProjectedPoolOverlay overlay;
        uint256 credit;
        uint256 prefixIn;
        uint256 incumbentIn;
        uint256 incumbentOut;
        uint256 callerRemaining;
        uint256 callerOut;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 poolLiquidity;
        uint128 ownedLiquidity;
        uint24 lpFee;
        uint16 protocolFee;
        uint24 swapFee;
        int24 spacing;
        uint256 overlayIndex;
        Failure pending;
    }

    /// @notice One certified composition plan. Does not call production `_composition`.
    function _plan(
        Types.Snapshot memory state_,
        Quotes.Params memory params_,
        uint256 credit_,
        ProjectedPoolOverlay memory overlay_
    ) public view returns (Types.Plan memory plan_, Work memory work_, Failure failure_) {
        if (!state_.idle || state_.book.supply == 0 || credit_ == 0) return (plan_, work_, Failure.EmptyBook);
        if (address(params_.key.hooks) != address(0) || credit_ > uint256(uint128(type(int128).max))) {
            return (plan_, work_, Failure.Rejected);
        }
        Walk memory walk;
        walk.state = abi.decode(abi.encode(state_), (Types.Snapshot));
        Inventory._collect(walk.state.book);
        walk.params = params_;
        walk.overlay = overlay_;
        walk.credit = credit_;
        walk.callerRemaining = credit_;
        walk.spacing = params_.key.tickSpacing;
        failure_ = _loadFees(walk);
        if (failure_ != Failure.None) return (plan_, work_, failure_);
        _bindLiquidity(walk);
        while (walk.callerRemaining != 0) {
            if (!_noteDiscovery(work_)) return (plan_, work_, Failure.WorkLimit);
            (uint160 target, int24 boundary, bool initialized, bool capped) = _boundary(walk, work_);
            if (capped) return (plan_, work_, Failure.WorkLimit);
            if (walk.poolLiquidity == 0) {
                if (!_advanceZero(walk, target, boundary, initialized)) return (plan_, work_, Failure.ZeroLiquidity);
                continue;
            }
            (bool reached, uint256 gross, uint256 output) = _segmentCapacity(walk, target);
            Analytic.Candidate memory candidate = _segmentCandidate(walk);
            if (candidate.failure == Analytic.Failure.Unrepresentable) return (plan_, work_, Failure.Unrepresentable);
            if (candidate.failure == Analytic.Failure.None && candidate.swapIn > 0 && candidate.swapIn <= gross) {
                return _certify(walk, work_, walk.prefixIn + candidate.swapIn);
            }
            if (!reached) return (plan_, work_, _map(candidate.failure));
            if (!_commit(walk, gross, output, boundary, initialized)) return (plan_, work_, walk.pending);
        }
        return (plan_, work_, walk.pending == Failure.None ? Failure.OutOfDomain : walk.pending);
    }

    function _loadFees(Walk memory walk_) private view returns (Failure) {
        if (walk_.overlay.useOverlay) {
            walk_.sqrtPriceX96 = walk_.overlay.sqrtPriceX96;
            walk_.tick = walk_.overlay.tick;
            walk_.lpFee = walk_.overlay.lpFee;
            walk_.protocolFee = walk_.params.zeroForOne
                ? ProtocolFeeLibrary.getZeroForOneFee(walk_.overlay.protocolFees)
                : ProtocolFeeLibrary.getOneForZeroFee(walk_.overlay.protocolFees);
        } else {
            walk_.sqrtPriceX96 = walk_.state.position.sqrtPriceX96;
            walk_.tick = walk_.state.position.tick;
            (,, uint24 protocolFees, uint24 lpFee) = walk_.params.manager.getSlot0(walk_.params.key.toId());
            walk_.lpFee = lpFee;
            walk_.protocolFee = walk_.params.zeroForOne
                ? ProtocolFeeLibrary.getZeroForOneFee(protocolFees)
                : ProtocolFeeLibrary.getOneForZeroFee(protocolFees);
        }
        walk_.swapFee = ProtocolFeeLibrary.calculateSwapFee(walk_.protocolFee, walk_.lpFee);
        if (walk_.sqrtPriceX96 == 0 || walk_.swapFee >= FEE) return Failure.Degenerate;
        uint256 input = walk_.params.zeroForOne ? 0 : 1;
        walk_.incumbentIn = walk_.state.book.free[input] + walk_.state.book.deployed[input];
        walk_.incumbentOut = walk_.state.book.free[1 - input] + walk_.state.book.deployed[1 - input];
        if (walk_.incumbentIn == 0 || walk_.incumbentOut == 0) return Failure.Degenerate;
        return Failure.None;
    }

    function _bindLiquidity(Walk memory walk_) private pure {
        walk_.poolLiquidity = walk_.overlay.useOverlay ? walk_.overlay.activeLiquidity : walk_.state.position.activeLiquidity;
        walk_.ownedLiquidity = _owned(walk_);
    }

    function _owned(Walk memory walk_) private pure returns (uint128) {
        Types.PositionState memory position = walk_.state.position;
        if (walk_.tick >= position.lower && walk_.tick < position.upper) return position.liquidity;
        return 0;
    }

    function _segmentCandidate(Walk memory walk_) private pure returns (Analytic.Candidate memory) {
        return Analytic._candidate(Analytic.SegmentInput({
            sqrtPriceX96: walk_.sqrtPriceX96,
            poolLiquidity: walk_.poolLiquidity,
            ownedLiquidity: walk_.ownedLiquidity,
            lpFeePips: walk_.lpFee,
            protocolFeePips: walk_.protocolFee,
            incumbentIn: walk_.incumbentIn,
            incumbentOut: walk_.incumbentOut,
            callerInRemaining: walk_.callerRemaining,
            callerOutAccumulated: walk_.callerOut,
            zeroForOne: walk_.params.zeroForOne
        }));
    }

    function _segmentCapacity(Walk memory walk_, uint160 target_)
        private pure returns (bool reached_, uint256 gross_, uint256 output_)
    {
        int256 remaining = -int256(walk_.callerRemaining);
        (uint160 next, uint256 amountIn, uint256 amountOut, uint256 feeAmount) = SwapMath.computeSwapStep(
            walk_.sqrtPriceX96, target_, walk_.poolLiquidity, remaining, walk_.swapFee
        );
        reached_ = next == target_;
        gross_ = amountIn + feeAmount;
        output_ = amountOut;
        if (!reached_) gross_ = walk_.callerRemaining;
    }

    function _boundary(Walk memory walk_, Work memory work_)
        private view returns (uint160 target_, int24 boundary_, bool initialized_, bool capped_)
    {
        if (walk_.overlay.useOverlay) return _overlayBoundary(walk_, work_);
        (boundary_, initialized_, capped_) = _liveBoundary(walk_, work_);
        if (capped_) return (0, 0, false, true);
        boundary_ = _closerOwn(walk_, boundary_);
        if (boundary_ < TickMath.MIN_TICK) boundary_ = TickMath.MIN_TICK;
        if (boundary_ > TickMath.MAX_TICK) boundary_ = TickMath.MAX_TICK;
        target_ = SwapMath.getSqrtPriceTarget(walk_.params.zeroForOne, TickMath.getSqrtPriceAtTick(boundary_), _limit(walk_.params.zeroForOne));
    }

    function _overlayBoundary(Walk memory walk_, Work memory work_)
        private pure returns (uint160 target_, int24 boundary_, bool initialized_, bool capped_)
    {
        if (!_noteBitmap(work_)) return (0, 0, false, true);
        int24 own = _closerOwn(walk_, walk_.params.zeroForOne ? TickMath.MIN_TICK : TickMath.MAX_TICK);
        boundary_ = own;
        uint256 count = walk_.overlay.ticks.length;
        if (walk_.overlayIndex < count) {
            int24 tick = walk_.overlay.ticks[walk_.params.zeroForOne ? count - 1 - walk_.overlayIndex : walk_.overlayIndex].tick;
            if (_between(walk_, tick) && _closer(walk_, tick, boundary_)) boundary_ = tick;
        }
        initialized_ = true;
        target_ = SwapMath.getSqrtPriceTarget(walk_.params.zeroForOne, TickMath.getSqrtPriceAtTick(boundary_), _limit(walk_.params.zeroForOne));
    }

    function _liveBoundary(Walk memory walk_, Work memory work_)
        private view returns (int24 next_, bool initialized_, bool capped_)
    {
        if (!_noteBitmap(work_)) return (0, false, true);
        int24 compressed = TickBitmap.compress(walk_.tick, walk_.spacing);
        uint256 word;
        if (walk_.params.zeroForOne) {
            (int16 wordPos, uint8 bitPos) = TickBitmap.position(compressed);
            word = walk_.params.manager.getTickBitmap(walk_.params.key.toId(), wordPos);
            uint256 mask = type(uint256).max >> (uint256(type(uint8).max) - bitPos);
            uint256 masked = word & mask;
            initialized_ = masked != 0;
            next_ = initialized_
                ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * walk_.spacing
                : (compressed - int24(uint24(bitPos))) * walk_.spacing;
        } else {
            (int16 wordPos, uint8 bitPos) = TickBitmap.position(++compressed);
            word = walk_.params.manager.getTickBitmap(walk_.params.key.toId(), wordPos);
            uint256 mask = ~((uint256(1) << bitPos) - 1);
            uint256 masked = word & mask;
            initialized_ = masked != 0;
            next_ = initialized_
                ? (compressed + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * walk_.spacing
                : (compressed + int24(uint24(type(uint8).max - bitPos))) * walk_.spacing;
        }
    }

    function _closerOwn(Walk memory walk_, int24 bitmapNext_) private pure returns (int24) {
        int24 next = bitmapNext_;
        int24 lower = walk_.state.position.lower;
        int24 upper = walk_.state.position.upper;
        if (_between(walk_, lower) && _closer(walk_, lower, next)) next = lower;
        if (_between(walk_, upper) && _closer(walk_, upper, next)) next = upper;
        return next;
    }

    function _between(Walk memory walk_, int24 tick_) private pure returns (bool) {
        return walk_.params.zeroForOne ? tick_ < walk_.tick : tick_ > walk_.tick;
    }

    function _closer(Walk memory walk_, int24 candidate_, int24 current_) private pure returns (bool) {
        if (walk_.params.zeroForOne) return candidate_ > current_;
        return candidate_ < current_;
    }

    function _advanceZero(Walk memory walk_, uint160 target_, int24 boundary_, bool initialized_) private view returns (bool) {
        if (target_ == walk_.sqrtPriceX96 && boundary_ == walk_.tick) return false;
        _cross(walk_, boundary_, initialized_);
        walk_.sqrtPriceX96 = target_;
        return walk_.sqrtPriceX96 != 0;
    }

    function _commit(Walk memory walk_, uint256 gross_, uint256 output_, int24 boundary_, bool initialized_)
        private view returns (bool)
    {
        if (gross_ > walk_.callerRemaining || walk_.poolLiquidity == 0) {
            _cross(walk_, boundary_, initialized_);
            return true;
        }
        uint256 alphaIn = walk_.poolLiquidity == 0 ? 0
            : Math.mulDiv(uint256(walk_.ownedLiquidity) * (FEE - walk_.protocolFee), gross_, uint256(walk_.poolLiquidity) * FEE);
        uint256 rhoOut = walk_.poolLiquidity == 0 ? 0
            : Math.mulDiv(walk_.ownedLiquidity, output_, walk_.poolLiquidity);
        if (rhoOut > walk_.incumbentOut) {
            walk_.pending = Failure.OutOfDomain;
            return false;
        }
        walk_.incumbentIn += alphaIn;
        walk_.incumbentOut -= rhoOut;
        walk_.callerRemaining -= gross_;
        walk_.callerOut += output_;
        walk_.prefixIn += gross_;
        _cross(walk_, boundary_, initialized_);
        return true;
    }

    function _cross(Walk memory walk_, int24 boundary_, bool initialized_) private view {
        int128 net;
        if (walk_.overlay.useOverlay) net = _overlayNet(walk_, boundary_);
        else if (initialized_ && !_isOwnOnly(walk_, boundary_)) {
            (, net,,) = walk_.params.manager.getTickInfo(walk_.params.key.toId(), boundary_);
        }
        if (walk_.params.zeroForOne) net = -net;
        if (net != 0 && walk_.poolLiquidity != 0) {
            walk_.poolLiquidity = LiquidityMath.addDelta(walk_.poolLiquidity, net);
        }
        walk_.tick = walk_.params.zeroForOne ? boundary_ - 1 : boundary_;
        walk_.sqrtPriceX96 = TickMath.getSqrtPriceAtTick(boundary_);
        if (walk_.params.zeroForOne) walk_.sqrtPriceX96 = TickMath.getSqrtPriceAtTick(walk_.tick);
        walk_.ownedLiquidity = _owned(walk_);
        if (walk_.overlay.useOverlay) ++walk_.overlayIndex;
    }

    function _overlayNet(Walk memory walk_, int24 boundary_) private pure returns (int128) {
        for (uint256 i; i < walk_.overlay.ticks.length; ++i) {
            if (walk_.overlay.ticks[i].tick == boundary_) return walk_.overlay.ticks[i].liquidityNet;
        }
        return 0;
    }

    function _isOwnOnly(Walk memory walk_, int24 boundary_) private pure returns (bool) {
        return boundary_ == walk_.state.position.lower || boundary_ == walk_.state.position.upper;
    }

    function _certify(Walk memory walk_, Work memory work_, uint256 swapIn_)
        private view returns (Types.Plan memory plan_, Work memory, Failure)
    {
        plan_.workflow = Types.Workflow.Composition;
        Types.Snapshot memory original = walk_.state;
        Quotes.Params memory params = walk_.params;
        params.position = original.position;
        params.amount = swapIn_;
        bool filled;
        if (walk_.overlay.useOverlay) (plan_.swap, filled) = _overlayQuote(walk_, swapIn_, work_);
        else (plan_.swap, filled) = Quotes._tryForward(params);
        if (!walk_.overlay.useOverlay) work_.certificationCoreSteps = plan_.swap.steps;
        if (work_.certificationCoreSteps > MAX_STEPS) return (plan_, work_, Failure.WorkLimit);
        if (!filled) return (plan_, work_, plan_.swap.steps >= MAX_STEPS ? Failure.WorkLimit : Failure.Rejected);
        _afterSwap(original, plan_.swap);
        uint256 input = params.zeroForOne ? 0 : 1;
        plan_.contribution[input] = walk_.credit - plan_.swap.amountIn;
        plan_.contribution[1 - input] = plan_.swap.amountOut;
        uint256[2] memory backing = Inventory._totals(original.book);
        if (!Protection._priceWithin(walk_.state.position.sqrtPriceX96, original.position.sqrtPriceX96, IMPACT_BPS)) {
            return (plan_, work_, Failure.Rejected);
        }
        for (uint256 i; i < 2; ++i) original.book.free[i] += plan_.contribution[i];
        work_.placementEvaluations = _placementCount(original);
        if (work_.placementEvaluations > MAX_PLACEMENT) return (plan_, work_, Failure.WorkLimit);
        plan_.placement = Inventory._safePlacement(original);
        for (uint256 i; i < 2; ++i) {
            uint256 loss = plan_.placement.roundingLoss[i];
            if (plan_.placement.liquidityDelta > 0) {
                if (loss > plan_.contribution[i]) return (plan_, work_, Failure.Rejected);
                plan_.contribution[i] -= loss;
            } else {
                if (loss > backing[i]) return (plan_, work_, Failure.Rejected);
                backing[i] -= loss;
            }
        }
        if ((backing[0] != 0 && plan_.contribution[0] == 0) || (backing[1] != 0 && plan_.contribution[1] == 0)) {
            return (plan_, work_, Failure.Rejected);
        }
        if ((backing[0] == 0 && plan_.contribution[0] != 0) || (backing[1] == 0 && plan_.contribution[1] != 0)) {
            return (plan_, work_, Failure.Rejected);
        }
        plan_.shares = ConstantProduct._sharesForDeposit(
            plan_.contribution[0], plan_.contribution[1], walk_.state.book.supply, backing[0], backing[1]
        );
        for (uint256 i; i < 2; ++i) {
            if (!Protection._aligned(plan_.shares, backing[i], walk_.state.book.supply, plan_.contribution[i])) {
                return (plan_, work_, Failure.Rejected);
            }
        }
        plan_.valid = plan_.shares != 0;
        plan_.refinements = 0;
        plan_.evaluations = 1 + work_.placementEvaluations;
        if (!plan_.valid) return (plan_, work_, Failure.Rejected);
        plan_.placement.afterState.book.supply += plan_.shares;
        return (plan_, work_, Failure.None);
    }

    function _overlayQuote(Walk memory walk_, uint256 swapIn_, Work memory work_)
        private pure returns (Types.Swap memory swap_, bool filled_)
    {
        QuoteCursor memory cursor = QuoteCursor({
            remaining: swapIn_,
            price: walk_.state.position.sqrtPriceX96,
            tick: walk_.state.position.tick,
            liquidity: walk_.overlay.activeLiquidity
        });
        swap_.zeroForOne = walk_.params.zeroForOne;
        while (cursor.remaining != 0 && cursor.price != _limit(swap_.zeroForOne)) {
            if (!_overlayStep(walk_, swap_, cursor, work_)) return (swap_, false);
        }
        filled_ = cursor.remaining == 0;
        swap_.sqrtPriceAfterX96 = cursor.price;
        swap_.tickAfter = cursor.tick;
        swap_.liquidityAfter = cursor.liquidity;
        swap_.steps = work_.certificationCoreSteps;
    }

    struct QuoteCursor {
        uint256 remaining;
        uint160 price;
        int24 tick;
        uint128 liquidity;
    }

    function _overlayStep(Walk memory walk_, Types.Swap memory swap_, QuoteCursor memory cursor_, Work memory work_)
        private pure returns (bool)
    {
        if (work_.certificationCoreSteps >= MAX_STEPS) return false;
        ++work_.certificationCoreSteps;
        int24 boundary = _overlayNext(walk_, swap_.zeroForOne, cursor_.tick);
        StepInput memory stepInput = StepInput({
            price: cursor_.price,
            target: SwapMath.getSqrtPriceTarget(swap_.zeroForOne, TickMath.getSqrtPriceAtTick(boundary), _limit(swap_.zeroForOne)),
            liquidity: cursor_.liquidity,
            remaining: cursor_.remaining,
            fee: walk_.swapFee
        });
        (uint160 next, uint256 gross, uint256 amountOut, uint256 amountIn, uint256 feeAmount) = _step(stepInput);
        if (gross > cursor_.remaining) return false;
        cursor_.remaining -= gross;
        swap_.amountIn += gross;
        swap_.amountOut += amountOut;
        swap_.feeAmount += feeAmount;
        _creditGrowth(walk_, swap_, cursor_.tick, cursor_.liquidity, amountIn, feeAmount);
        cursor_.price = next;
        if (next == stepInput.target) {
            cursor_.tick = swap_.zeroForOne ? boundary - 1 : boundary;
            int128 net = _overlayNet(walk_, boundary);
            if (swap_.zeroForOne) net = -net;
            if (net != 0) cursor_.liquidity = LiquidityMath.addDelta(cursor_.liquidity, net);
        } else {
            cursor_.tick = TickMath.getTickAtSqrtPrice(cursor_.price);
        }
        return true;
    }

    function _overlayNext(Walk memory walk_, bool zeroForOne_, int24 tick_) private pure returns (int24 boundary_) {
        boundary_ = zeroForOne_ ? TickMath.MIN_TICK : TickMath.MAX_TICK;
        for (uint256 i; i < walk_.overlay.ticks.length; ++i) {
            int24 tickAt = walk_.overlay.ticks[i].tick;
            if (zeroForOne_ ? tickAt < tick_ && tickAt > boundary_ : tickAt > tick_ && tickAt < boundary_) boundary_ = tickAt;
        }
    }

    struct StepInput {
        uint160 price;
        uint160 target;
        uint128 liquidity;
        uint256 remaining;
        uint24 fee;
    }

    function _step(StepInput memory input_)
        private pure returns (uint160 next_, uint256 gross_, uint256 amountOut_, uint256 amountIn_, uint256 feeAmount_)
    {
        (next_, amountIn_, amountOut_, feeAmount_) = SwapMath.computeSwapStep(
            input_.price, input_.target, input_.liquidity, -int256(input_.remaining), input_.fee
        );
        gross_ = amountIn_ + feeAmount_;
    }

    function _creditGrowth(
        Walk memory walk_, Types.Swap memory swap_, int24 tick_, uint128 liquidity_, uint256 amountIn_, uint256 feeAmount_
    ) private pure {
        Types.PositionState memory position = walk_.state.position;
        if (liquidity_ == 0 || tick_ < position.lower || tick_ >= position.upper) return;
        uint256 lpFee = feeAmount_;
        if (walk_.protocolFee != 0) {
            lpFee -= walk_.swapFee == walk_.protocolFee ? lpFee : Math.mulDiv(amountIn_ + feeAmount_, walk_.protocolFee, FEE);
        }
        swap_.feeGrowthInsideX128 += Math.mulDiv(lpFee, uint256(1) << 128, liquidity_);
    }

    function _placementCount(Types.Snapshot memory state_) private pure returns (uint32 count_) {
        count_ = 1;
        (bool representable, uint128 target) = Inventory._tryTargetLiquidity(state_);
        if (representable) count_ += target > state_.position.liquidity ? 2 : 1;
    }

    function _noteDiscovery(Work memory work_) private pure returns (bool) {
        ++work_.discoveryCoreSteps;
        return work_.discoveryCoreSteps <= MAX_STEPS;
    }

    function _noteBitmap(Work memory work_) private pure returns (bool) {
        ++work_.bitmapWordReads;
        return work_.bitmapWordReads <= MAX_STEPS;
    }

    function _limit(bool zeroForOne_) private pure returns (uint160) {
        return zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    /// @dev Same fee-growth booking as `TransitionPlanner._afterSwap`. Kept here so production dispatch does not link a library cycle.
    function _afterSwap(Types.Snapshot memory state_, Types.Swap memory swap_) private pure {
        state_.position.sqrtPriceX96 = swap_.sqrtPriceAfterX96;
        state_.position.tick = swap_.tickAfter;
        state_.position.activeLiquidity = swap_.liquidityAfter;
        state_.book.deployed = Inventory._amounts(state_.position, state_.position.liquidity, false);
        uint256 input = swap_.zeroForOne ? 0 : 1;
        state_.book.earned[input] += Math.mulDiv(swap_.feeGrowthInsideX128, state_.position.liquidity, uint256(1) << 128);
        Inventory._collect(state_.book);
    }

    function _map(Analytic.Failure failure_) private pure returns (Failure) {
        if (failure_ == Analytic.Failure.Degenerate) return Failure.Degenerate;
        if (failure_ == Analytic.Failure.NegativeDiscriminant) return Failure.NegativeDiscriminant;
        if (failure_ == Analytic.Failure.Unrepresentable) return Failure.Unrepresentable;
        if (failure_ == Analytic.Failure.ZeroLiquidity) return Failure.ZeroLiquidity;
        if (failure_ == Analytic.Failure.EmptyBook) return Failure.EmptyBook;
        return Failure.OutOfDomain;
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition[]

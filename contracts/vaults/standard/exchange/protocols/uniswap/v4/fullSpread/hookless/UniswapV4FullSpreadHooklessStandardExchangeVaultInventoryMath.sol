// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {StandardExchangeConstantProduct as ConstantProduct} from "../../../StandardExchangeConstantProduct.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath[]
/// @notice Pure custody exclusions, finite-range metrics and signed placement accounting.
library UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath {
    error AccountingMismatch();

    function _depositShares(uint256 amount0_, uint256 amount1_, uint256 supply_, uint256 backing0_, uint256 backing1_, uint256 minimum_)
        public pure returns (uint256)
    {
        if (supply_ == 0) return ConstantProduct._initialShares(amount0_, amount1_, minimum_);
        return ConstantProduct._sharesForDeposit(amount0_, amount1_, supply_, backing0_, backing1_);
    }

    function _blockedInputForShares(uint256 backingIn_, uint256 backingOther_, uint256 shares_, uint256 supply_)
        public pure returns (uint256)
    {
        return ConstantProduct._amountInForShares(backingIn_, backingOther_, shares_, supply_);
    }

    function _matches(Types.Snapshot memory actual_, Types.Snapshot memory expected_) public pure returns (bool) {
        for (uint256 i; i < 2; ++i) {
            if (actual_.book.free[i] != expected_.book.free[i]
                || actual_.book.deployed[i] != expected_.book.deployed[i]
                || actual_.book.earned[i] != expected_.book.earned[i]) return false;
        }
        return actual_.book.supply == expected_.book.supply
            && actual_.position.sqrtPriceX96 == expected_.position.sqrtPriceX96
            && actual_.position.tick == expected_.position.tick
            && actual_.position.liquidity == expected_.position.liquidity
            && actual_.position.activeLiquidity == expected_.position.activeLiquidity
            && actual_.position.lowerLiquidityGross == expected_.position.lowerLiquidityGross
            && actual_.position.upperLiquidityGross == expected_.position.upperLiquidityGross;
    }

    function _free(uint256 balance_, uint256 credit_, uint256 payout_, uint256 refund_)
        internal pure returns (uint256)
    {
        return balance_ - credit_ - payout_ - refund_;
    }

    function _target(uint256 total_, uint256 sleeveWad_) internal pure returns (uint256) {
        return Math.mulDiv(total_, sleeveWad_, 1e18 + sleeveWad_);
    }

    function _deadband(uint256 target_, uint256 absoluteFloor_) internal pure returns (uint256) {
        return Math.max(absoluteFloor_, target_ / 20);
    }

    function _totals(Types.Book memory book_) internal pure returns (uint256[2] memory totals_) {
        for (uint256 i; i < 2; ++i) totals_[i] = book_.free[i] + book_.deployed[i] + book_.earned[i];
    }

    function _collect(Types.Book memory book_) internal pure {
        for (uint256 i; i < 2; ++i) {
            if (book_.earned[i] > uint256(uint128(type(int128).max))) revert AccountingMismatch();
            book_.free[i] += book_.earned[i];
            book_.earned[i] = 0;
        }
    }

    function _amounts(Types.PositionState memory position_, uint128 liquidity_, bool roundUp_)
        public pure returns (uint256[2] memory amounts_)
    {
        if (position_.lowerX96 >= position_.upperX96) revert AccountingMismatch();
        if (position_.sqrtPriceX96 <= position_.lowerX96) {
            amounts_[0] = SqrtPriceMath.getAmount0Delta(position_.lowerX96, position_.upperX96, liquidity_, roundUp_);
        } else if (position_.sqrtPriceX96 >= position_.upperX96) {
            amounts_[1] = SqrtPriceMath.getAmount1Delta(position_.lowerX96, position_.upperX96, liquidity_, roundUp_);
        } else {
            amounts_[0] = SqrtPriceMath.getAmount0Delta(position_.sqrtPriceX96, position_.upperX96, liquidity_, roundUp_);
            amounts_[1] = SqrtPriceMath.getAmount1Delta(position_.lowerX96, position_.sqrtPriceX96, liquidity_, roundUp_);
        }
    }

    function _composition(Types.Snapshot memory state_) internal pure returns (Types.Ratio memory ratio_) {
        (ratio_,) = _compositionWithSign(state_);
    }

    function _compositionWithSign(Types.Snapshot memory state_) private pure returns (Types.Ratio memory ratio_, int256 sign_) {
        uint256 total0 = state_.book.free[0] + state_.book.deployed[0];
        uint256 total1 = state_.book.free[1] + state_.book.deployed[1];
        ratio_.denominator = Protection._from(1);
        if (total0 == 0 && total1 == 0) return (ratio_, 0);
        Types.PositionState memory p = state_.position;
        if (p.sqrtPriceX96 <= p.lowerX96) {
            ratio_.numerator = Protection._from(total1 == 0 ? 0 : 1);
            return (ratio_, total1 == 0 ? int256(0) : int256(-1));
        }
        if (p.sqrtPriceX96 >= p.upperX96) {
            ratio_.numerator = Protection._from(total0 == 0 ? 0 : 1);
            return (ratio_, total0 == 0 ? int256(0) : int256(1));
        }
        Types.Uint2048 memory x = Protection._scale(
            Protection._product(total0, p.sqrtPriceX96 - p.lowerX96, p.sqrtPriceX96), p.upperX96
        );
        Types.Uint2048 memory y = Protection._product(total1, p.upperX96 - p.sqrtPriceX96, uint256(1) << 192);
        sign_ = Protection._compare(x, y);
        bool xLarger = sign_ >= 0;
        ratio_.numerator = xLarger ? Protection._subtract(x, y) : Protection._subtract(y, x);
        ratio_.denominator = xLarger ? x : y;
    }

    function _compositionSign(Types.Snapshot memory state_) public pure returns (int256) {
        (, int256 sign) = _compositionWithSign(state_);
        return sign;
    }

    function _progress(Types.Snapshot memory state_) public pure returns (Types.Progress memory progress_) {
        (progress_,) = _progressWithSign(state_);
    }

    function _progressWithSign(Types.Snapshot memory state_) private pure returns (Types.Progress memory progress_, int256 sign_) {
        Types.Ratio memory rho;
        (rho, sign_) = _compositionWithSign(state_);
        progress_.compositionExcess = _excess(rho);
        progress_.sleeveExcess = _sleeveExcess(state_);
    }

    function _compositionExcess(Types.Snapshot memory state_) private pure returns (Types.Ratio memory excess_) {
        return _excess(_composition(state_));
    }

    function _excess(Types.Ratio memory rho) private pure returns (Types.Ratio memory excess_) {
        Types.Uint2048 memory scaled = Protection._scale(rho.numerator, 10_000);
        if (Protection._compare(scaled, rho.denominator) > 0) {
            excess_.numerator = Protection._subtract(scaled, rho.denominator);
        }
        excess_.denominator = Protection._scale(rho.denominator, 10_000);
    }

    function _sleeveExcess(Types.Snapshot memory state_) private pure returns (Types.Ratio memory excess_) {
        excess_.denominator = Protection._from(1);
        for (uint256 i; i < 2; ++i) {
            uint256 total = state_.book.free[i] + state_.book.deployed[i];
            uint256 target = _target(total, state_.sleeveWad);
            uint256 free = state_.book.free[i];
            uint256 deviation = free > target ? free - target : target - free;
            uint256 band = _deadband(target, state_.absoluteFloor[i]);
            Types.Ratio memory sigma;
            sigma.numerator = Protection._from(deviation > band ? deviation - band : 0);
            sigma.denominator = Protection._from(Math.max(total, 1));
            if (Protection._ratioCompare(sigma, excess_) > 0) excess_ = sigma;
        }
    }

    function _passes(Types.Snapshot memory state_) public pure returns (bool) {
        Types.Ratio memory rho = _composition(state_);
        if (Protection._compare(Protection._scale(rho.numerator, 10_000), rho.denominator) > 0) return false;
        for (uint256 i; i < 2; ++i) {
            uint256 target = _target(state_.book.free[i] + state_.book.deployed[i], state_.sleeveWad);
            uint256 free = state_.book.free[i];
            uint256 deviation = free > target ? free - target : target - free;
            if (deviation > _deadband(target, state_.absoluteFloor[i])) return false;
        }
        return true;
    }

    function _compareProgress(Types.Snapshot memory a_, Types.Snapshot memory b_) public pure returns (int256) {
        int256 comparison = Protection._ratioCompare(_compositionExcess(a_), _compositionExcess(b_));
        return comparison != 0 ? comparison : Protection._ratioCompare(_sleeveExcess(a_), _sleeveExcess(b_));
    }

    /// @dev A separate pure call frame releases trial-placement scratch memory
    /// before the family planner evaluates the next swap. Candidate order and
    /// ties are identical to the original inlined stencil.
    function _safePlacement(Types.Snapshot memory state_) public pure returns (Types.Placement memory best_) {
        (best_,,) = _safePlacementWithProgress(state_);
    }

    function _safePlacementWithProgress(Types.Snapshot memory state_)
        public pure returns (Types.Placement memory best_, Types.Progress memory bestProgress, int256 bestSign_)
    {
        best_ = _place(state_, state_.position.liquidity, false);
        (bestProgress, bestSign_) = _progressWithSign(best_.afterState);
        best_.certified = _progressPasses(bestProgress);
        (bool representable, uint128 target) = _tryTargetLiquidity(state_);
        if (!representable) return (best_, bestProgress, bestSign_);
        uint256 candidates = target > state_.position.liquidity ? 2 : 1;
        for (uint256 i; i < candidates; ++i) {
            Types.Placement memory candidate = _place(state_, target - uint128(i), false);
            if (!candidate.funded) continue;
            (Types.Progress memory candidateProgress, int256 candidateSign) = _progressWithSign(candidate.afterState);
            candidate.certified = _progressPasses(candidateProgress);
            int256 comparison = _compareMetrics(candidateProgress, bestProgress);
            int256 candidateDelta = candidate.liquidityDelta;
            int256 bestDelta = best_.liquidityDelta;
            if (comparison < 0 || (comparison == 0
                && (candidateDelta < 0 ? -candidateDelta : candidateDelta) < (bestDelta < 0 ? -bestDelta : bestDelta))) {
                best_ = candidate;
                bestProgress = candidateProgress;
                bestSign_ = candidateSign;
            }
        }
    }

    function _compareMetrics(Types.Progress memory a_, Types.Progress memory b_) internal pure returns (int256) {
        int256 comparison = Protection._ratioCompare(a_.compositionExcess, b_.compositionExcess);
        return comparison != 0 ? comparison : Protection._ratioCompare(a_.sleeveExcess, b_.sleeveExcess);
    }

    function _progressPasses(Types.Progress memory progress_) private pure returns (bool) {
        Types.Uint2048 memory zero;
        return Protection._compare(progress_.compositionExcess.numerator, zero) == 0
            && Protection._compare(progress_.sleeveExcess.numerator, zero) == 0;
    }

    function _tryTargetLiquidity(Types.Snapshot memory state_) internal pure returns (bool representable_, uint128 liquidity_) {
        uint256[2] memory budget;
        for (uint256 i; i < 2; ++i) {
            uint256 total = state_.book.free[i] + state_.book.deployed[i];
            budget[i] = total - _target(total, state_.sleeveWad);
        }
        Types.PositionState memory p = state_.position;
        if (p.lowerX96 == 0 || p.lowerX96 >= p.upperX96) revert AccountingMismatch();
        if (p.sqrtPriceX96 <= p.lowerX96) return _liquidity0(p.lowerX96, p.upperX96, budget[0]);
        if (p.sqrtPriceX96 >= p.upperX96) return _boundedLiquidity(budget[1], uint256(1) << 96, p.upperX96 - p.lowerX96);
        (bool fits0, uint128 liquidity0) = _liquidity0(p.sqrtPriceX96, p.upperX96, budget[0]);
        (bool fits1, uint128 liquidity1) = _boundedLiquidity(budget[1], uint256(1) << 96, p.sqrtPriceX96 - p.lowerX96);
        if (!fits0 && !fits1) return (false, 0);
        return (true, liquidity0 < liquidity1 ? liquidity0 : liquidity1);
    }

    function _liquidity0(uint160 lower_, uint160 upper_, uint256 budget_) private pure returns (bool, uint128) {
        uint256 intermediate = Math.mulDiv(lower_, upper_, uint256(1) << 96);
        return _boundedLiquidity(budget_, intermediate, upper_ - lower_);
    }

    function _boundedLiquidity(uint256 budget_, uint256 coefficient_, uint256 denominator_) private pure returns (bool, uint128) {
        // Preserve LiquidityAmounts' intermediate rounding, but classify a target
        // outside uint128 as an unsupported certificate rather than aborting R8.
        if (Protection._compare(Protection._product(budget_, coefficient_, 1),
            Protection._product(uint256(type(uint128).max) + 1, denominator_, 1)) >= 0) {
            return (false, type(uint128).max);
        }
        return (true, uint128(Math.mulDiv(budget_, coefficient_, denominator_)));
    }

    function _placement(Types.Snapshot memory state_, uint128 finalLiquidity_)
        public pure returns (Types.Placement memory result_)
    {
        return _place(state_, finalLiquidity_, true);
    }

    function _place(Types.Snapshot memory state_, uint128 finalLiquidity_, bool certify_)
        private pure returns (Types.Placement memory result_)
    {
        result_.afterState = abi.decode(abi.encode(state_), (Types.Snapshot));
        Types.PositionState memory position = result_.afterState.position;
        bool adding = finalLiquidity_ > position.liquidity;
        uint128 change = adding ? finalLiquidity_ - position.liquidity : position.liquidity - finalLiquidity_;
        if (change > uint128(type(int128).max)) return result_;
        if (position.lowerLiquidityGross > position.maxLiquidityPerTick
            || position.upperLiquidityGross > position.maxLiquidityPerTick) revert AccountingMismatch();
        if (adding && (change > position.maxLiquidityPerTick - position.lowerLiquidityGross
            || change > position.maxLiquidityPerTick - position.upperLiquidityGross)) return result_;
        result_.liquidityDelta = adding ? int128(change) : -int128(change);
        uint256[2] memory settlement = _amounts(position, change, adding);
        uint256[2] memory deployedAfter = _amounts(position, finalLiquidity_, false);
        for (uint256 i; i < 2; ++i) {
            if (settlement[i] > uint256(uint128(type(int128).max))) return result_;
            if (adding && settlement[i] > state_.book.free[i]) return result_;
            if (adding) {
                result_.debt[i] = settlement[i];
                result_.afterState.book.free[i] -= settlement[i];
            } else {
                result_.proceeds[i] = settlement[i];
                result_.afterState.book.free[i] += settlement[i];
            }
            uint256 beforeTotal = state_.book.free[i] + state_.book.deployed[i];
            uint256 afterTotal = result_.afterState.book.free[i] + deployedAfter[i];
            if (afterTotal > beforeTotal) revert AccountingMismatch();
            result_.roundingLoss[i] = beforeTotal - afterTotal;
            result_.afterState.book.deployed[i] = deployedAfter[i];
        }
        position.liquidity = finalLiquidity_;
        position.liquidityChange += result_.liquidityDelta;
        position.lowerLiquidityGross = adding ? position.lowerLiquidityGross + change : position.lowerLiquidityGross - change;
        position.upperLiquidityGross = adding ? position.upperLiquidityGross + change : position.upperLiquidityGross - change;
        if (position.tick >= position.lower && position.tick < position.upper) {
            position.activeLiquidity = adding ? position.activeLiquidity + change : position.activeLiquidity - change;
        }
        result_.funded = true;
        if (certify_) result_.certified = _passes(result_.afterState);
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath[]

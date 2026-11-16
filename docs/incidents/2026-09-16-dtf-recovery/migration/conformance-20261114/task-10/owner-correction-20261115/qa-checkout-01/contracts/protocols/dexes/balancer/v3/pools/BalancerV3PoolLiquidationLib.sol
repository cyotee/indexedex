// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {PoolData, Rounding} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {PoolConfigLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolConfigLib.sol";
import {ScalingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {LogExpMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/LogExpMath.sol";
import {IWeightedPool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
import {IBalancerV3PoolLiquidityQuote as Quote} from "./IBalancerV3PoolLiquidityQuote.sol";
import {BalancerV3WeightedBufferPoolQuoteLib as WeightedQuote} from "./weighted/BalancerV3WeightedBufferPoolQuoteLib.sol";

/// @notice Shared native single-token liquidation route for BPT Standard Exchanges.
/// @dev At most nine native steps. Exact-input amounts beyond the bounded route
/// use one native valuation step: execution still asks the real Vault to
/// perform it and propagates its rejection atomically. Fees and virtual books are
/// projected after every step. The rate provider needs no knowledge of this route.
library BalancerV3PoolLiquidationLib {
    using FixedPoint for uint256;

    uint256 internal constant MAX_STEPS = 9;
    error InvalidLiquidationQuote();

    struct PoolQuoteState {
        address pool;
        uint256 index;
        uint256 swapFee;
        uint256 supply;
        uint256 holderShares;
        uint256[] balancesRaw;
        uint256[] scalingFactors;
        uint256[] rates;
        uint256 aggregateSwapFee;
        bytes poolState;
        bytes weightedState;
        uint256 minimumRatio;
    }

    struct Step {
        uint256 bpt;
        uint256 assets;
        bool exactOut;
    }

    struct LiquidationProgress {
        uint256 remaining;
        uint256 count;
        uint256 bpt;
        uint256 assets;
        bool valuationOnly;
    }

    function snapshot(IVault vault_, address pool_, uint256 index_)
        external view returns (PoolQuoteState memory q_)
    {
        PoolData memory d_ = vault_.getPoolData(pool_);
        q_.pool = pool_;
        q_.index = index_;
        q_.supply = IERC20(pool_).totalSupply();
        q_.balancesRaw = d_.balancesRaw;
        q_.scalingFactors = d_.decimalScalingFactors;
        q_.rates = d_.tokenRates;
        q_.swapFee = PoolConfigLib.getStaticSwapFeePercentage(d_.poolConfigBits);
        q_.aggregateSwapFee = PoolConfigLib.isPoolInRecoveryMode(d_.poolConfigBits)
            ? 0 : PoolConfigLib.getAggregateSwapFeePercentage(d_.poolConfigBits);
        q_.minimumRatio = IBasePool(pool_).getMinimumInvariantRatio();
        (bool ok_, bytes memory data_) = pool_.staticcall(
            abi.encodeCall(IERC165.supportsInterface, (type(Quote).interfaceId))
        );
        if (ok_ && data_.length == 32 && abi.decode(data_, (bool))) {
            q_.poolState = Quote(pool_).quotePoolState(q_.scalingFactors, q_.rates);
            if (q_.poolState.length == 0) revert InvalidLiquidationQuote();
        } else {
            q_.weightedState = WeightedQuote.snapshot(pool_, q_.scalingFactors, q_.rates);
            // Old stable buffer deployments cannot project their mutable virtual book.
            (bool stable_, bytes memory amp_) = pool_.staticcall(abi.encodeWithSignature("getAmplificationParameter()"));
            (bool buffered_, bytes memory buf_) = pool_.staticcall(abi.encodeWithSignature("virtualBuffer()"));
            if (stable_ && amp_.length == 96 && buffered_ && buf_.length == 32) revert InvalidLiquidationQuote();
        }
    }

    function liveBalances(PoolQuoteState memory q_) internal pure returns (uint256[] memory live_) {
        live_ = new uint256[](q_.balancesRaw.length);
        for (uint256 i_; i_ < live_.length; ++i_) {
            live_[i_] = ScalingHelpers.toScaled18ApplyRateRoundDown(q_.balancesRaw[i_], q_.scalingFactors[i_], q_.rates[i_]);
        }
    }

    function _quoteStep(PoolQuoteState memory q_, uint256 amount_, bool exactOut_)
        private view returns (Step memory step_, uint256[] memory fees_)
    {
        return _quoteStepWith(q_, amount_, exactOut_, _quoteMath);
    }

    function _quoteStepWith(
        PoolQuoteState memory q_, uint256 amount_, bool exactOut_,
        function(PoolQuoteState memory, Quote.LiquidityQuoteParams memory) internal view returns (uint256, uint256[] memory) math_
    ) private view returns (Step memory step_, uint256[] memory fees_)
    {
        Quote.LiquidityQuoteParams memory p_;
        p_.balancesLiveScaled18 = liveBalances(q_);
        p_.index = q_.index;
        p_.supply = q_.supply;
        p_.swapFee = q_.swapFee;
        p_.exactOut = exactOut_;
        p_.amountScaled18 = exactOut_
            ? ScalingHelpers.toScaled18ApplyRateRoundUp(amount_, q_.scalingFactors[q_.index], q_.rates[q_.index])
            : amount_;
        (uint256 calculated_, uint256[] memory quotedFees_) = math_(q_, p_);
        fees_ = quotedFees_;
        step_.exactOut = exactOut_;
        step_.bpt = exactOut_ ? calculated_ : amount_;
        step_.assets = exactOut_ ? amount_ : ScalingHelpers.toRawUndoRateRoundDown(
            calculated_, q_.scalingFactors[q_.index], q_.rates[q_.index]
        );
    }

    function _quoteMath(PoolQuoteState memory q_, Quote.LiquidityQuoteParams memory p_)
        private view returns (uint256 calculated_, uint256[] memory fees_)
    {
        if (q_.poolState.length != 0) {
            (calculated_, fees_) = Quote(q_.pool).quotePoolLiquidity(q_.poolState, p_);
        } else if (q_.weightedState.length != 0) {
            (calculated_, fees_) = WeightedQuote.quote(q_.weightedState, p_);
        } else if (p_.exactOut) {
            (calculated_, fees_) = _plainExactOut(q_, p_);
        } else {
            (calculated_, fees_) = _plainExactIn(q_, p_);
        }
    }

    /// @dev BasePoolMath removal formula with the execution-only ratio check omitted.
    /// At total-supply redemption both remaining balance and taxable amount are zero.
    function _plainExactIn(PoolQuoteState memory q_, Quote.LiquidityQuoteParams memory p_)
        private view returns (uint256 out_, uint256[] memory fees_)
    {
        return _plainExactInWith(q_, p_, _plainBalance);
    }

    function _plainExactInWith(
        PoolQuoteState memory q_, Quote.LiquidityQuoteParams memory p_,
        function(PoolQuoteState memory, uint256[] memory, uint256) internal view returns (uint256) balance_
    ) internal view returns (uint256 out_, uint256[] memory fees_)
    {
        uint256 remaining_ = q_.supply - p_.amountScaled18;
        fees_ = new uint256[](p_.balancesLiveScaled18.length);
        if (remaining_ == 0) return (p_.balancesLiveScaled18[q_.index], fees_);
        uint256 next_ = balance_(q_, p_.balancesLiveScaled18, remaining_.divUp(q_.supply));
        uint256 taxable_ = remaining_.mulDivUp(p_.balancesLiveScaled18[q_.index], q_.supply) - next_;
        fees_[q_.index] = taxable_.mulUp(q_.swapFee);
        out_ = p_.balancesLiveScaled18[q_.index] - next_ - fees_[q_.index];
    }

    function _plainBalance(PoolQuoteState memory q_, uint256[] memory live_, uint256 ratio_)
        private view returns (uint256)
    {
        try IBasePool(q_.pool).computeBalance(live_, q_.index, ratio_) returns (uint256 balance_) {
            return balance_;
        } catch (bytes memory reason_) {
            // Only the weighted power-domain error receives a mathematical
            // continuation. All other pool errors retain their original payload.
            if (reason_.length != 4 || bytes4(reason_) != LogExpMath.ProductOutOfBounds.selector) {
                assembly ("memory-safe") { revert(add(reason_, 32), mload(reason_)) }
            }
            uint256[] memory weights_ = IWeightedPool(q_.pool).getNormalizedWeights();
            return WeightedQuote.balanceAfterRemoval(live_[q_.index], weights_[q_.index], ratio_);
        }
    }

    function _plainExactOut(PoolQuoteState memory q_, Quote.LiquidityQuoteParams memory p_)
        private view returns (uint256 bpt_, uint256[] memory fees_)
    {
        return _plainExactOutWith(q_, p_, _plainInvariant);
    }

    function _plainInvariant(PoolQuoteState memory q_, uint256[] memory balances_, Rounding rounding_)
        private view returns (uint256)
    {
        return IBasePool(q_.pool).computeInvariant(balances_, rounding_);
    }

    function _plainExactOutWith(
        PoolQuoteState memory q_, Quote.LiquidityQuoteParams memory p_,
        function(PoolQuoteState memory, uint256[] memory, Rounding) internal view returns (uint256) invariant_
    ) internal view returns (uint256 bpt_, uint256[] memory fees_)
    {
        uint256[] memory next_ = new uint256[](p_.balancesLiveScaled18.length);
        for (uint256 i_; i_ < next_.length; ++i_) next_[i_] = p_.balancesLiveScaled18[i_] - 1;
        next_[q_.index] -= p_.amountScaled18;
        uint256 current_ = invariant_(q_, p_.balancesLiveScaled18, Rounding.ROUND_UP);
        uint256 ratio_ = invariant_(q_, next_, Rounding.ROUND_UP).divUp(current_);
        uint256 taxable_ = ratio_.mulUp(p_.balancesLiveScaled18[q_.index]) - next_[q_.index];
        fees_ = new uint256[](next_.length);
        fees_[q_.index] = taxable_.divUp(q_.swapFee.complement()) - taxable_;
        next_[q_.index] -= fees_[q_.index];
        bpt_ = q_.supply.mulDivUp(current_ - invariant_(q_, next_, Rounding.ROUND_DOWN), current_);
    }

    function afterLiquidity(PoolQuoteState memory q_, uint256[] memory fees_, bool joining_, uint256 bpt_)
        external view returns (PoolQuoteState memory)
    {
        _afterLiquidity(q_, fees_, joining_, bpt_);
        return q_;
    }

    function _afterLiquidity(PoolQuoteState memory q_, uint256[] memory fees_, bool joining_, uint256 bpt_)
        private view
    {
        _applyFees(q_, fees_);
        if (q_.poolState.length != 0) {
            q_.poolState = Quote(q_.pool).quotePoolStateAfterLiquidity(q_.poolState, joining_, bpt_, q_.supply);
        }
        if (q_.weightedState.length != 0) {
            q_.weightedState = WeightedQuote.afterLiquidity(q_.weightedState, joining_, bpt_, q_.supply);
        }
    }

    function _applyFees(PoolQuoteState memory q_, uint256[] memory fees_) internal pure {
        if (fees_.length != q_.balancesRaw.length) revert InvalidLiquidationQuote();
        for (uint256 i_; i_ < fees_.length; ++i_) {
            uint256 rawFee_ = ScalingHelpers.toRawUndoRateRoundDown(fees_[i_], q_.scalingFactors[i_], q_.rates[i_]);
            q_.balancesRaw[i_] -= rawFee_ * q_.aggregateSwapFee / 1e18;
        }
    }

    /// @notice Quote the deterministic native withdrawal sequence and its final pool state.
    /// @dev Does not mutate caller memory (external library call). The final step may be
    /// valuation-only; no partial success is allowed if the real Vault rejects that step.
    function liquidate(PoolQuoteState memory q_, uint256 amount_, bool exactOut_)
        external view returns (PoolQuoteState memory, uint256 bpt_, uint256 assets_, Step[] memory steps_)
    {
        return _liquidate(q_, amount_, exactOut_, _quoteMath, _afterLiquidity);
    }

    /// @dev Native callers supply internal math and book updates; remote consumers retain the external adapters above.
    function _liquidate(
        PoolQuoteState memory q_, uint256 amount_, bool exactOut_,
        function(PoolQuoteState memory, Quote.LiquidityQuoteParams memory) internal view returns (uint256, uint256[] memory) math_,
        function(PoolQuoteState memory, uint256[] memory, bool, uint256) internal view after_
    ) internal view returns (PoolQuoteState memory, uint256, uint256, Step[] memory steps_)
    {
        steps_ = new Step[](MAX_STEPS);
        if (amount_ == 0) {
            assembly ("memory-safe") { mstore(steps_, 0) }
            return (q_, 0, 0, steps_);
        }
        if (q_.supply == 0 || (!exactOut_ && amount_ > q_.supply)) revert InvalidLiquidationQuote();
        LiquidationProgress memory progress_;
        if (!exactOut_) {
            uint256 residual_ = q_.supply;
            for (uint256 i_; i_ < MAX_STEPS; ++i_) {
                residual_ -= residual_.mulDown(q_.minimumRatio.complement());
            }
            progress_.valuationOnly = amount_ > q_.supply - residual_;
        }
        progress_.remaining = amount_;
        while (progress_.remaining != 0) {
            uint256 cap_ = q_.supply.mulDown(q_.minimumRatio.complement());
            Step memory step_;
            uint256[] memory fees_;
            if (exactOut_) {
                // A large exact-output formula may leave a negative post-fee
                // balance even though a sequence of native steps can pay it.
                // Compare against a valid capacity step before inverting it.
                if (cap_ != 0 && progress_.count + 1 < MAX_STEPS) {
                    (step_, fees_) = _quoteStepWith(q_, cap_, false, math_);
                }
                if (step_.assets == 0 || step_.assets > progress_.remaining) {
                    (step_, fees_) = _quoteStepWith(q_, progress_.remaining, true, math_);
                }
            } else {
                uint256 chunk_ = progress_.remaining;
                if (!progress_.valuationOnly && chunk_ > cap_ && cap_ != 0 && progress_.count + 1 < MAX_STEPS) chunk_ = cap_;
                (step_, fees_) = _quoteStepWith(q_, chunk_, false, math_);
            }
            if (step_.bpt == 0 || (exactOut_ && (step_.assets == 0 || step_.assets > progress_.remaining))) {
                revert InvalidLiquidationQuote();
            }
            steps_[progress_.count++] = step_;
            q_.balancesRaw[q_.index] -= step_.assets;
            after_(q_, fees_, false, step_.bpt);
            q_.supply -= step_.bpt;
            progress_.bpt += step_.bpt;
            progress_.assets += step_.assets;
            progress_.remaining -= exactOut_ ? step_.assets : step_.bpt;
        }
        uint256 count_ = progress_.count;
        assembly ("memory-safe") { mstore(steps_, count_) }
        return (q_, progress_.bpt, progress_.assets, steps_);
    }
}

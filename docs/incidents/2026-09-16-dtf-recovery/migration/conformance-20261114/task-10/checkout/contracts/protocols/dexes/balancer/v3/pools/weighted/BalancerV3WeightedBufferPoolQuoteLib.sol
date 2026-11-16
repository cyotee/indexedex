// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {LogExpMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/LogExpMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {IBalancerV3PoolLiquidityQuote as Quote} from "../IBalancerV3PoolLiquidityQuote.sol";
import {IStandardExchangeBufferPool} from "../constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {ICommonBufferMultiVaultWeightedPool} from "./commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";
import {IMultiPairStandardExchangeBufferPool} from "./multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Single} from "../constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {MixedLegWeightedBufferPoolRepo as Mixed} from "./mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";
import {CommonBufferMultiVaultWeightedPoolRepo as Common} from "./commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolRepo.sol";

/// @notice Sequential quote book for the four native weighted buffer-pool families.
/// @dev Reads existing pool views; adds no pool selectors or storage. Withdrawals scale
/// virtual reserves and signed share offsets exactly as the production after-remove hooks.
library BalancerV3WeightedBufferPoolQuoteLib {
    using FixedPoint for uint256;

    error InvalidWeightedQuote();

    struct State {
        uint256[] weights;
        uint256[] bufferIndices;
        uint256[] buffers;
        uint256[] shareIndices;
        int256[] offsets;
        uint256[] scaling;
        uint256[] rates;
        uint256 maxRatio;
    }

    function _hasView(address pool_, bytes4 selector_) private view returns (bool) {
        (bool ok_, bytes memory result_) = pool_.staticcall(abi.encodeWithSelector(selector_));
        return ok_ && result_.length == 32;
    }

    function snapshot(address pool_, uint256[] memory scaling_, uint256[] memory rates_)
        external view returns (bytes memory)
    {
        // These packages expose the views but do not register the whole family
        // interface in ERC165. Identify their existing, distinct view surfaces.
        bool single_ = _hasView(pool_, IStandardExchangeBufferPool.ttaIndex.selector);
        bool common_ = !single_ && _hasView(pool_, ICommonBufferMultiVaultWeightedPool.vaultCount.selector);
        bool pairs_ = !single_ && !common_ && _hasView(pool_, IMultiPairStandardExchangeBufferPool.pairCount.selector);
        if (!single_ && !common_ && !pairs_) return "";
        State memory q_;
        q_.scaling = scaling_;
        q_.rates = rates_;
        q_.maxRatio = IBasePool(pool_).getMaximumInvariantRatio();
        q_.weights = new uint256[](rates_.length);
        uint256 count_ = single_ ? 1 : common_
            ? ICommonBufferMultiVaultWeightedPool(pool_).vaultCount()
            : IMultiPairStandardExchangeBufferPool(pool_).pairCount();
        uint256 buffers_ = common_ ? 1 : count_;
        q_.bufferIndices = new uint256[](buffers_);
        q_.buffers = new uint256[](buffers_);
        q_.shareIndices = new uint256[](count_);
        q_.offsets = new int256[](count_);
        if (single_) {
            IStandardExchangeBufferPool p_ = IStandardExchangeBufferPool(pool_);
            q_.bufferIndices[0] = p_.ttaIndex();
            q_.buffers[0] = p_.virtualTTA();
            q_.shareIndices[0] = p_.sharesIndex();
            q_.offsets[0] = p_.hookSharesDelta();
            uint256 ratio_ = Math.mulDiv(rates_[p_.sharesIndex()], 1e18, p_.baselineRate());
            uint256 shareWeight_ = Math.mulDiv(ratio_, 1e18, ratio_ + 1e18);
            q_.weights[p_.sharesIndex()] = shareWeight_;
            q_.weights[p_.ttaIndex()] = 1e18 - shareWeight_;
            if (shareWeight_ < 1e16 || 1e18 - shareWeight_ < 1e16) {
                revert IStandardExchangeBufferPool.EffectiveWeightOutOfBounds(1e18 - shareWeight_, shareWeight_);
            }
        } else {
            // These views have the same ABI in all three fixed-weight families.
            IMultiPairStandardExchangeBufferPool p_ = IMultiPairStandardExchangeBufferPool(pool_);
            for (uint256 i_; i_ < rates_.length; ++i_) q_.weights[i_] = p_.weight(i_);
            for (uint256 i_; i_ < count_; ++i_) {
                q_.shareIndices[i_] = p_.shareIndex(i_);
                q_.offsets[i_] = p_.hookShareDelta(i_);
            }
            if (common_) {
                q_.bufferIndices[0] = ICommonBufferMultiVaultWeightedPool(pool_).bufferIndex();
                q_.buffers[0] = ICommonBufferMultiVaultWeightedPool(pool_).virtualBuffer();
            } else {
                for (uint256 i_; i_ < count_; ++i_) {
                    q_.bufferIndices[i_] = p_.bufferIndex(i_);
                    q_.buffers[i_] = p_.virtualBuffer(i_);
                }
            }
        }
        return abi.encode(q_);
    }

    function afterLiquidity(bytes memory state_, bool joining_, uint256 bpt_, uint256 supply_)
        external pure returns (bytes memory)
    {
        return _afterLiquidity(state_, joining_, bpt_, supply_);
    }

    function _afterLiquidity(bytes memory state_, bool joining_, uint256 bpt_, uint256 supply_)
        internal pure returns (bytes memory)
    {
        State memory q_ = abi.decode(state_, (State));
        if (!joining_ && supply_ != 0) {
            for (uint256 i_; i_ < q_.buffers.length; ++i_) q_.buffers[i_] -= bpt_ * q_.buffers[i_] / supply_;
            for (uint256 i_; i_ < q_.offsets.length; ++i_) {
                q_.offsets[i_] -= int256(bpt_) * q_.offsets[i_] / int256(supply_);
            }
        }
        return abi.encode(q_);
    }

    function _balances(State memory q_, uint256[] memory live_) internal pure returns (uint256[] memory b_) {
        if (live_.length != q_.rates.length) revert InvalidWeightedQuote();
        b_ = new uint256[](live_.length);
        for (uint256 i_; i_ < live_.length; ++i_) b_[i_] = live_[i_];
        for (uint256 i_; i_ < q_.buffers.length; ++i_) b_[q_.bufferIndices[i_]] = q_.buffers[i_];
        for (uint256 i_; i_ < q_.offsets.length; ++i_) {
            uint256 idx_ = q_.shareIndices[i_];
            int256 h_ = q_.offsets[i_];
            uint256 delta_ = Math.mulDiv(uint256(h_ <= 0 ? -h_ : h_), q_.scaling[idx_] * q_.rates[idx_], 1e18);
            if (h_ <= 0) b_[idx_] = live_[idx_] + delta_;
            else b_[idx_] = delta_ >= live_[idx_] ? 0 : live_[idx_] - delta_;
        }
    }

    function _invariant(State memory q_, uint256[] memory live_, bool up_) internal pure returns (uint256) {
        uint256[] memory b_ = _balances(q_, live_);
        return up_ ? WeightedMath.computeInvariantUp(q_.weights, b_) : WeightedMath.computeInvariantDown(q_.weights, b_);
    }

    function hostInvariant(bytes memory state_, uint256[] memory live_, bool up_) external view returns (uint256) {
        State memory q_ = abi.decode(state_, (State));
        _hostWeights(q_);
        uint256[] memory b_ = new uint256[](live_.length);
        for (uint256 i_; i_ < live_.length; ++i_) b_[i_] = _hostBalanceAt(q_, live_, i_);
        return up_ ? WeightedMath.computeInvariantUp(q_.weights, b_) : WeightedMath.computeInvariantDown(q_.weights, b_);
    }

    function balance(bytes memory state_, uint256[] memory live_, uint256 index_, uint256 ratio_)
        external view returns (uint256)
    {
        State memory q_ = abi.decode(state_, (State));
        _hostWeights(q_);
        return WeightedMath.computeBalanceOutGivenInvariant(_hostBalanceAt(q_, live_, index_), q_.weights[index_], ratio_);
    }

    function _hostWeights(State memory q_) private view {
        if (address(Single._ttaToken()) == address(0)) return;
        uint256 shares_ = Single._sharesIndex();
        if (q_.rates[shares_] == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        uint256 ratio_ = Math.mulDiv(q_.rates[shares_], 1e18, Single._baselineRate());
        uint256 weight_ = Math.mulDiv(ratio_, 1e18, ratio_ + 1e18);
        if (weight_ < 1e16 || 1e18 - weight_ < 1e16) {
            revert IStandardExchangeBufferPool.EffectiveWeightOutOfBounds(1e18 - weight_, weight_);
        }
        q_.weights[shares_] = weight_;
        q_.weights[Single._ttaIndex()] = 1e18 - weight_;
    }

    /// @dev Join callbacks retain the host helpers' zero-rate guards, checked multiplication
    /// grouping, and unchecked signed-offset behavior. Liquidation retains its existing quote book.
    function _hostBalanceAt(State memory q_, uint256[] memory live_, uint256 index_) private view returns (uint256) {
        bool single_ = address(Single._ttaToken()) != address(0);
        if (single_ && q_.rates[q_.shareIndices[0]] == 0) revert IStandardExchangeBufferPool.RateProviderZero();
        for (uint256 i_; i_ < q_.bufferIndices.length; ++i_) {
            if (index_ == q_.bufferIndices[i_]) return q_.buffers[i_];
        }
        for (uint256 i_; i_ < q_.shareIndices.length; ++i_) {
            if (index_ != q_.shareIndices[i_]) continue;
            int256 h_ = q_.offsets[i_];
            if (h_ == 0) return live_[index_];
            if (q_.rates[index_] == 0) revert IStandardExchangeBufferPool.RateProviderZero();
            bool mixed_ = Mixed._tokenCount() != 0;
            uint256 raw_;
            if (mixed_ || Common._vaultCount() != 0) {
                unchecked { raw_ = uint256(h_ <= 0 ? -h_ : h_); }
            } else {
                raw_ = uint256(h_ <= 0 ? -h_ : h_);
            }
            uint256 delta_ = mixed_
                ? Math.mulDiv(raw_ * q_.scaling[index_], q_.rates[index_], 1e18)
                : Math.mulDiv(raw_, q_.scaling[index_] * q_.rates[index_], 1e18);
            if (h_ <= 0) {
                unchecked { return live_[index_] + delta_; }
            }
            return delta_ >= live_[index_] ? 0 : live_[index_] - delta_;
        }
        return live_[index_];
    }

    /// @notice Extend weighted removal valuation beyond LogExpMath's lower exponent bound.
    /// @dev Native executable ratios retain the exact pinned WeightedMath result.
    /// For very small ratios, x^(n+f) = x^n * (x^(f/2))^2. Integer powers use
    /// rounded-up multiplication; f/2 rounds down because 0 < x < 1. The remaining
    /// fractional power has ln(x)*(f/2) >= -21, safely inside LogExpMath's domain.
    /// Every operation rounds the remaining balance up, hence the quoted payout down.
    function balanceAfterRemoval(uint256 balance_, uint256 weight_, uint256 ratio_)
        external pure returns (uint256)
    {
        return _balanceAfterRemoval(balance_, weight_, ratio_);
    }

    function _balanceAfterRemoval(uint256 balance_, uint256 weight_, uint256 ratio_)
        private pure returns (uint256)
    {
        if (weight_ < 1e16 || weight_ > 1e18 || ratio_ > 1e18) revert InvalidWeightedQuote();
        if (ratio_ == 0) return 0;
        uint256 exponent_ = uint256(1e18).divDown(weight_);
        // Keep the existing optimized integer powers, and leave a full exponent
        // unit of margin around LogExpMath's -41 bound for logarithm rounding.
        if (exponent_ == 1e18 || exponent_ == 2e18 || exponent_ == 4e18
            || LogExpMath.ln(int256(ratio_)) * int256(exponent_) / 1e18 >= -40e18) {
            return WeightedMath.computeBalanceOutGivenInvariant(balance_, weight_, ratio_);
        }
        uint256 power_ = 1e18;
        uint256 base_ = ratio_;
        uint256 integer_ = exponent_ / 1e18;
        while (integer_ != 0) {
            if ((integer_ & 1) != 0) power_ = power_.mulUp(base_);
            integer_ >>= 1;
            if (integer_ != 0) base_ = base_.mulUp(base_);
        }
        uint256 halfFraction_ = (exponent_ % 1e18) / 2;
        if (halfFraction_ != 0) {
            uint256 fractional_ = ratio_.powUp(halfFraction_);
            power_ = power_.mulUp(fractional_.mulUp(fractional_));
        }
        return balance_.mulUp(power_);
    }

    function quote(bytes memory state_, Quote.LiquidityQuoteParams memory p_)
        external pure returns (uint256 result_, uint256[] memory fees_)
    {
        return _quote(state_, p_);
    }

    function _quote(bytes memory state_, Quote.LiquidityQuoteParams memory p_)
        internal pure returns (uint256 result_, uint256[] memory fees_)
    {
        State memory q_ = abi.decode(state_, (State));
        for (uint256 i_; i_ < q_.bufferIndices.length; ++i_) {
            if (p_.index == q_.bufferIndices[i_]) revert InvalidWeightedQuote();
        }
        if (p_.joining) return _add(q_, p_);
        if (p_.exactOut) return _removeOut(q_, p_);
        uint256 remaining_ = p_.supply - p_.amountScaled18;
        fees_ = new uint256[](p_.balancesLiveScaled18.length);
        if (remaining_ == 0) return (p_.balancesLiveScaled18[p_.index], fees_);
        uint256 next_ = _balanceAfterRemoval(
            _balances(q_, p_.balancesLiveScaled18)[p_.index], q_.weights[p_.index], remaining_.divUp(p_.supply)
        );
        uint256 taxable_ = remaining_.mulDivUp(p_.balancesLiveScaled18[p_.index], p_.supply) - next_;
        fees_[p_.index] = taxable_.mulUp(p_.swapFee);
        result_ = p_.balancesLiveScaled18[p_.index] - next_ - fees_[p_.index];
    }

    function _add(State memory q_, Quote.LiquidityQuoteParams memory p_)
        private pure returns (uint256 result_, uint256[] memory fees_)
    {
        // Current SE transitions support physical exact-in additions only.
        if (p_.exactOut) revert InvalidWeightedQuote();
        uint256[] memory next_ = new uint256[](p_.balancesLiveScaled18.length);
        fees_ = new uint256[](next_.length);
        for (uint256 i_; i_ < next_.length; ++i_) {
            next_[i_] = p_.balancesLiveScaled18[i_] + (i_ == p_.index ? p_.amountScaled18 : 0) - 1;
        }
        uint256 current_ = _invariant(q_, p_.balancesLiveScaled18, true);
        uint256 ratio_ = _invariant(q_, next_, false).divDown(current_);
        if (ratio_ > q_.maxRatio) revert BasePoolMath.InvariantRatioAboveMax(ratio_, q_.maxRatio);
        for (uint256 i_; i_ < next_.length; ++i_) {
            uint256 proportional_ = ratio_.mulDown(p_.balancesLiveScaled18[i_]);
            if (next_[i_] > proportional_) {
                fees_[i_] = (next_[i_] - proportional_).mulUp(p_.swapFee);
                next_[i_] -= fees_[i_];
            }
        }
        result_ = p_.supply * (_invariant(q_, next_, false) - current_) / current_;
    }

    function _removeOut(State memory q_, Quote.LiquidityQuoteParams memory p_)
        private pure returns (uint256 result_, uint256[] memory fees_)
    {
        uint256[] memory next_ = new uint256[](p_.balancesLiveScaled18.length);
        for (uint256 i_; i_ < next_.length; ++i_) next_[i_] = p_.balancesLiveScaled18[i_] - 1;
        next_[p_.index] -= p_.amountScaled18;
        uint256 current_ = _invariant(q_, p_.balancesLiveScaled18, true);
        uint256 ratio_ = _invariant(q_, next_, true).divUp(current_);
        uint256 taxable_ = ratio_.mulUp(p_.balancesLiveScaled18[p_.index]) - next_[p_.index];
        fees_ = new uint256[](next_.length);
        fees_[p_.index] = taxable_.divUp(p_.swapFee.complement()) - taxable_;
        next_[p_.index] -= fees_[p_.index];
        result_ = p_.supply.mulDivUp(current_ - _invariant(q_, next_, false), current_);
    }
}

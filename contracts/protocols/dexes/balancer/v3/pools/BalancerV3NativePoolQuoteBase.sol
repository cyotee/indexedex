// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {PoolData, Rounding, TokenType} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {PoolDataLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolDataLib.sol";
import {PoolConfigLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolConfigLib.sol";
import {BalancerV3PoolRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3PoolRepo.sol";
import {BalancerV3ConstantProductPoolTarget} from "@crane/contracts/protocols/dexes/balancer/v3/pool-constProd/BalancerV3ConstantProductPoolTarget.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BalancerV3PoolLiquidationLib as Liquidation} from "./BalancerV3PoolLiquidationLib.sol";
import {IBalancerV3PoolLiquidityQuote as Quote} from "./IBalancerV3PoolLiquidityQuote.sol";
import {BalancerV3StableBufferPoolQuoteTarget, BalancerV3StableBufferPoolQuoteLib as StableQuote} from "./stable/BalancerV3StableBufferPoolQuoteTarget.sol";
import {BalancerV3WeightedBufferPoolQuoteLib as WeightedQuote} from "./weighted/BalancerV3WeightedBufferPoolQuoteLib.sol";
import {StandardExchangeBufferPoolRepo as Single} from "./constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {IStandardExchangeBufferPool} from "./constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {CommonBufferMultiVaultWeightedPoolRepo as CommonWeighted} from "./weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolRepo.sol";
import {MultiPairStandardExchangeBufferPoolRepo as Pairs} from "./weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolRepo.sol";
import {MixedLegWeightedBufferPoolRepo as MixedWeighted} from "./weighted/mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";
import {CommonBufferMultiVaultStablePoolRepo as CommonStable} from "./stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolRepo.sol";
import {MixedBufferMultiVaultStablePoolRepo as MixedStable} from "./stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolRepo.sol";

/// @dev Native pool quotes read the host's existing family storage, never its selector surface.
/// No storage is introduced. Constant-product math is inherited verbatim; buffer math
/// and projected virtual-book updates reuse the same implementations as remote quotes.
library BalancerV3NativePoolQuoteLib {
    function joinData(IVault vault_) external view returns (PoolData memory d_) {
        d_ = vault_.getPoolData(address(this));
        (,,uint256[] memory raw_,uint256[] memory lastLive_) = vault_.getPoolTokenInfo(address(this));
        uint256 fee_ = PoolConfigLib.getAggregateYieldFeePercentage(d_.poolConfigBits);
        bool yield_ = fee_ != 0 && !PoolConfigLib.isPoolInRecoveryMode(d_.poolConfigBits);
        for (uint256 i_; i_ < raw_.length; ++i_) {
            PoolDataLib.updateRawAndLiveBalance(d_, i_, raw_[i_], Rounding.ROUND_UP);
            if (yield_ && d_.tokenInfo[i_].paysYieldFees && d_.tokenInfo[i_].tokenType == TokenType.WITH_RATE) {
                uint256 due_ = PoolDataLib._computeYieldFeesDue(d_, lastLive_[i_], i_, fee_);
                if (due_ != 0) PoolDataLib.updateRawAndLiveBalance(d_, i_, raw_[i_] - due_, Rounding.ROUND_UP);
            }
        }
    }

    function isVirtualBuffer(address token_) external view returns (bool) {
        if (address(Single._ttaToken()) != address(0)) return token_ == address(Single._ttaToken());
        if (address(CommonWeighted._bufferToken()) != address(0)) return token_ == address(CommonWeighted._bufferToken());
        if (address(CommonStable._bufferToken()) != address(0)) return token_ == address(CommonStable._bufferToken());
        if (address(MixedStable._bufferToken()) != address(0)) return token_ == address(MixedStable._bufferToken());
        for (uint256 i_; i_ < Pairs._pairCount(); ++i_) {
            if (token_ == address(Pairs._bufferToken(i_))) return true;
        }
        for (uint256 i_; i_ < MixedWeighted._pairCount(); ++i_) {
            if (token_ == address(MixedWeighted._bufferToken(i_))) return true;
        }
        return false;
    }

    function _stableBufferQuoteState() private view returns (BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q_) {
        bool common_ = address(CommonStable._bufferToken()) != address(0);
        if (common_) (q_.amp,) = CommonStable._getAmplificationParameter();
        else (q_.amp,) = MixedStable._getAmplificationParameter();
        q_.bufferIndex = common_ ? CommonStable._bufferIndex() : MixedStable._bufferIndex();
        q_.virtualBuffer = common_ ? CommonStable._virtualBuffer() : MixedStable._virtualBuffer();
        uint256 n_ = common_ ? CommonStable._vaultCount() : MixedStable._vaultCount();
        q_.shareIndices = new uint256[](n_);
        q_.hookShareDeltas = new int256[](n_);
        for (uint256 i_; i_ < n_; ++i_) {
            q_.shareIndices[i_] = common_ ? CommonStable._shareIndex(i_) : MixedStable._shareIndex(i_);
            q_.hookShareDeltas[i_] = common_ ? CommonStable._hookShareDelta(i_) : MixedStable._hookShareDelta(i_);
        }
    }

    function snapshot(IVault vault_, uint256 index_, bool joining_) external view returns (Liquidation.PoolQuoteState memory q_) {
        PoolData memory d_ = vault_.getPoolData(address(this));
        q_.pool = address(this);
        q_.index = index_;
        // BPT lives in the Vault's multi-token ledger, not ERC20Repo in the pool.
        q_.supply = vault_.totalSupply(address(this));
        q_.balancesRaw = d_.balancesRaw;
        q_.scalingFactors = d_.decimalScalingFactors;
        q_.rates = d_.tokenRates;
        q_.swapFee = PoolConfigLib.getStaticSwapFeePercentage(d_.poolConfigBits);
        q_.aggregateSwapFee = PoolConfigLib.isPoolInRecoveryMode(d_.poolConfigBits)
            ? 0 : PoolConfigLib.getAggregateSwapFeePercentage(d_.poolConfigBits);
        q_.minimumRatio = BalancerV3PoolRepo._minimumInvariantRatio();
        if (address(CommonStable._bufferToken()) != address(0) || address(MixedStable._bufferToken()) != address(0)) {
            BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory s_ = _stableBufferQuoteState();
            s_.pool = address(this);
            s_.scalingFactors = q_.scalingFactors;
            s_.rates = q_.rates;
            s_.minInvariantRatio = q_.minimumRatio;
            s_.maxInvariantRatio = BalancerV3PoolRepo._maximumInvariantRatio();
            q_.poolState = abi.encode(s_);
        } else {
            q_.weightedState = _nativeWeightedState(q_.scalingFactors, q_.rates, joining_);
        }
    }

    function _nativeWeightedState(uint256[] memory scaling_, uint256[] memory rates_, bool joining_) private view returns (bytes memory) {
        bool single_ = address(Single._ttaToken()) != address(0);
        bool common_ = address(CommonWeighted._bufferToken()) != address(0);
        bool pairs_ = Pairs._pairCount() != 0;
        uint256 count_ = single_ ? 1 : common_ ? CommonWeighted._vaultCount()
            : pairs_ ? Pairs._pairCount() : MixedWeighted._pairCount();
        if (count_ == 0 && MixedWeighted._tokenCount() == 0) return "";
        WeightedQuote.State memory q_;
        q_.scaling = scaling_;
        q_.rates = rates_;
        q_.maxRatio = BalancerV3PoolRepo._maximumInvariantRatio();
        q_.bufferIndices = new uint256[](common_ ? 1 : count_);
        q_.buffers = new uint256[](q_.bufferIndices.length);
        q_.shareIndices = new uint256[](count_);
        q_.offsets = new int256[](count_);
        if (single_) {
            q_.bufferIndices[0] = Single._ttaIndex();
            q_.buffers[0] = Single._virtualTTA();
            q_.shareIndices[0] = Single._sharesIndex();
            q_.offsets[0] = Single._hookSharesDelta();
            q_.weights = new uint256[](rates_.length);
            // Join callbacks calculate effective weights at the same point as host math,
            // after the caller's balance arithmetic and invariant-ratio checks.
            if (joining_) return abi.encode(q_);
            uint256 ratio_ = Math.mulDiv(rates_[Single._sharesIndex()], 1e18, Single._baselineRate());
            uint256 shareWeight_ = Math.mulDiv(ratio_, 1e18, ratio_ + 1e18);
            q_.weights[Single._sharesIndex()] = shareWeight_;
            q_.weights[Single._ttaIndex()] = 1e18 - shareWeight_;
            if (shareWeight_ < 1e16 || 1e18 - shareWeight_ < 1e16) {
                revert IStandardExchangeBufferPool.EffectiveWeightOutOfBounds(1e18 - shareWeight_, shareWeight_);
            }
        } else {
            q_.weights = common_ ? CommonWeighted._weightsMemory() : pairs_ ? Pairs._weightsMemory() : MixedWeighted._weightsMemory();
            for (uint256 i_; i_ < count_; ++i_) {
                q_.shareIndices[i_] = common_ ? CommonWeighted._shareIndex(i_) : pairs_ ? Pairs._shareIndex(i_) : MixedWeighted._shareIndex(i_);
                q_.offsets[i_] = common_ ? CommonWeighted._hookShareDelta(i_) : pairs_ ? Pairs._hookShareDelta(i_) : MixedWeighted._hookShareDelta(i_);
            }
            if (common_) {
                q_.bufferIndices[0] = CommonWeighted._bufferIndex();
                q_.buffers[0] = CommonWeighted._virtualBuffer();
            } else {
                for (uint256 i_; i_ < count_; ++i_) {
                    q_.bufferIndices[i_] = pairs_ ? Pairs._bufferIndex(i_) : MixedWeighted._bufferIndex(i_);
                    q_.buffers[i_] = pairs_ ? Pairs._virtualBuffer(i_) : MixedWeighted._virtualBuffer(i_);
                }
            }
        }
        return abi.encode(q_);
    }
}

abstract contract BalancerV3NativePoolQuoteBase is BalancerV3ConstantProductPoolTarget {
    function _isVirtualBuffer(address token_) internal view returns (bool) {
        return BalancerV3NativePoolQuoteLib.isVirtualBuffer(token_);
    }

    function _nativeSnapshot(IVault vault_, uint256 index_, bool joining_) internal view returns (Liquidation.PoolQuoteState memory) {
        return BalancerV3NativePoolQuoteLib.snapshot(vault_, index_, joining_);
    }

    function _nativeInvariant(Liquidation.PoolQuoteState memory q_, uint256[] memory live_, Rounding rounding_)
        internal view returns (uint256)
    {
        if (q_.poolState.length != 0) return StableQuote.hostInvariant(q_.poolState, live_, rounding_ == Rounding.ROUND_UP);
        if (q_.weightedState.length != 0) {
            return WeightedQuote.hostInvariant(q_.weightedState, live_, rounding_ == Rounding.ROUND_UP);
        }
        return BalancerV3ConstantProductPoolTarget.computeInvariant(live_, rounding_);
    }

    function _nativeBalance(Liquidation.PoolQuoteState memory q_, uint256[] memory live_, uint256 ratio_)
        internal view returns (uint256)
    {
        if (q_.poolState.length != 0) return StableQuote.balance(q_.poolState, live_, q_.index, ratio_);
        if (q_.weightedState.length != 0) {
            return WeightedQuote.balance(q_.weightedState, live_, q_.index, ratio_);
        }
        return BalancerV3ConstantProductPoolTarget.computeBalance(live_, q_.index, ratio_);
    }

    function _nativeQuoteMath(Liquidation.PoolQuoteState memory q_, Quote.LiquidityQuoteParams memory p_)
        internal view returns (uint256, uint256[] memory)
    {
        if (q_.poolState.length != 0) return StableQuote.quote(q_.poolState, p_);
        if (q_.weightedState.length != 0) return WeightedQuote.quote(q_.weightedState, p_);
        if (p_.exactOut) return Liquidation._plainExactOutWith(q_, p_, _nativeInvariant);
        return Liquidation._plainExactInWith(q_, p_, _nativeBalance);
    }

    function _nativeAfterLiquidity(Liquidation.PoolQuoteState memory q_, uint256[] memory fees_, bool joining_, uint256 bpt_)
        internal view
    {
        Liquidation._applyFees(q_, fees_);
        if (q_.poolState.length != 0) q_.poolState = StableQuote.afterLiquidity(q_.poolState, joining_, bpt_, q_.supply);
        if (q_.weightedState.length != 0) q_.weightedState = WeightedQuote.afterLiquidity(q_.weightedState, joining_, bpt_, q_.supply);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IBalancerV3PoolLiquidityQuote} from "contracts/protocols/dexes/balancer/v3/pools/IBalancerV3PoolLiquidityQuote.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/// @notice Read-only CommonBuffer/MixedBuffer stable liquidity math with an explicit virtual book.
/// @dev BasePoolMath's fee/rounding order is retained, but its IBasePool callbacks cannot carry
/// a projected book. The callbacks below use the same StableMath and derived-depth formulas
/// as the two production pool targets. No live state is changed by these selectors.
abstract contract BalancerV3StableBufferPoolQuoteTarget is IBalancerV3PoolLiquidityQuote {
    using FixedPoint for uint256;

    struct StableBufferQuoteState {
        address pool;
        uint256 amp;
        uint256 bufferIndex;
        uint256 virtualBuffer;
        uint256[] shareIndices;
        int256[] hookShareDeltas;
        uint256[] scalingFactors;
        uint256[] rates;
        uint256 minInvariantRatio;
        uint256 maxInvariantRatio;
    }

    function _stableBufferQuoteState() internal view virtual returns (StableBufferQuoteState memory);

    function quotePoolState(uint256[] calldata scalingFactors, uint256[] calldata rates)
        external view returns (bytes memory)
    {
        return _quotePoolState(scalingFactors, rates);
    }

    function _quotePoolState(uint256[] memory scalingFactors, uint256[] memory rates)
        internal view returns (bytes memory)
    {
        StableBufferQuoteState memory q = _stableBufferQuoteState();
        q.pool = address(this);
        q.scalingFactors = scalingFactors;
        q.rates = rates;
        q.minInvariantRatio = IBasePool(address(this)).getMinimumInvariantRatio();
        q.maxInvariantRatio = IBasePool(address(this)).getMaximumInvariantRatio();
        return abi.encode(q);
    }

    function _decodePoolState(bytes memory state) internal view returns (StableBufferQuoteState memory q) {
        q = abi.decode(state, (StableBufferQuoteState));
        if (q.pool != address(this) || q.scalingFactors.length != q.rates.length
            || q.shareIndices.length != q.hookShareDeltas.length || q.bufferIndex >= q.rates.length) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
    }

    function quotePoolStateAfterLiquidity(bytes calldata state, bool joining, uint256 bptAmount, uint256 supplyBefore)
        external view returns (bytes memory)
    {
        return _quotePoolStateAfterLiquidity(state, joining, bptAmount, supplyBefore);
    }

    function _quotePoolStateAfterLiquidity(bytes memory state, bool joining, uint256 bptAmount, uint256 supplyBefore)
        internal view returns (bytes memory)
    {
        return BalancerV3StableBufferPoolQuoteLib.afterLiquidity(state, joining, bptAmount, supplyBefore);
    }

    function quotePoolLiquidity(bytes calldata state, LiquidityQuoteParams calldata p)
        external view returns (uint256 result, uint256[] memory fees)
    {
        return _quotePoolLiquidity(state, p);
    }

    function _quotePoolLiquidity(bytes memory state, LiquidityQuoteParams memory p)
        internal view returns (uint256 result, uint256[] memory fees)
    {
        return BalancerV3StableBufferPoolQuoteLib.quote(state, p);
    }
}

/// @dev Linked pure math shared by the native SE and the pool's explicit-state quote selectors.
library BalancerV3StableBufferPoolQuoteLib {
    using FixedPoint for uint256;

    error RateProviderZero();

    function hostInvariant(bytes memory state, uint256[] memory live, bool up) external pure returns (uint256 result) {
        BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q =
            abi.decode(state, (BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState));
        result = StableMath.computeInvariant(q.amp, _hostBalances(q, live));
        if (up && result > 0) ++result;
    }

    function balance(bytes memory state, uint256[] memory live, uint256 index, uint256 ratio) external pure returns (uint256) {
        BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q =
            abi.decode(state, (BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState));
        uint256[] memory balances = _hostBalances(q, live);
        uint256 current = StableMath.computeInvariant(q.amp, balances);
        if (current > 0) ++current;
        return StableMath.computeBalance(q.amp, balances, current.mulUp(ratio), index);
    }

    function _hostBalances(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, uint256[] memory live)
        private pure returns (uint256[] memory balances)
    {
        balances = new uint256[](live.length);
        for (uint256 i; i < live.length; ++i) balances[i] = live[i];
        balances[q.bufferIndex] = q.virtualBuffer;
        for (uint256 i; i < q.shareIndices.length; ++i) {
            uint256 idx = q.shareIndices[i];
            int256 h = q.hookShareDeltas[i];
            if (h == 0) continue;
            if (q.rates[idx] == 0) revert RateProviderZero();
            uint256 raw;
            unchecked { raw = uint256(h <= 0 ? -h : h); }
            uint256 delta = Math.mulDiv(raw, q.scalingFactors[idx] * q.rates[idx], 1e18);
            if (h <= 0) {
                unchecked { balances[idx] = live[idx] + delta; }
            } else balances[idx] = delta >= live[idx] ? 0 : live[idx] - delta;
        }
    }

    function _decodePoolState(bytes memory state) private view returns (BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q) {
        q = abi.decode(state, (BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState));
        if (q.pool != address(this) || q.scalingFactors.length != q.rates.length
            || q.shareIndices.length != q.hookShareDeltas.length || q.bufferIndex >= q.rates.length) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
    }

    function afterLiquidity(bytes memory state, bool joining, uint256 bptAmount, uint256 supplyBefore)
        external view returns (bytes memory)
    {
        BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q = _decodePoolState(state);
        if (!joining && supplyBefore != 0) {
            uint256 sub = (bptAmount * q.virtualBuffer) / supplyBefore;
            q.virtualBuffer = sub >= q.virtualBuffer ? 0 : q.virtualBuffer - sub;
            for (uint256 i; i < q.hookShareDeltas.length; ++i) {
                int256 h = q.hookShareDeltas[i];
                q.hookShareDeltas[i] = h - (int256(bptAmount) * h) / int256(supplyBefore);
            }
        }
        return abi.encode(q);
    }

    function _mathBalances(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, uint256[] memory live)
        private pure returns (uint256[] memory balances)
    {
        if (live.length != q.rates.length) revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        balances = new uint256[](live.length);
        for (uint256 i; i < live.length; ++i) balances[i] = live[i];
        balances[q.bufferIndex] = q.virtualBuffer;
        for (uint256 i; i < q.shareIndices.length; ++i) {
            uint256 idx = q.shareIndices[i];
            int256 h = q.hookShareDeltas[i];
            uint256 delta = Math.mulDiv(uint256(h <= 0 ? -h : h), q.scalingFactors[idx] * q.rates[idx], 1e18);
            if (h <= 0) {
                unchecked { balances[idx] = live[idx] + delta; }
            } else {
                balances[idx] = delta >= live[idx] ? 0 : live[idx] - delta;
            }
        }
    }

    function _invariant(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, uint256[] memory live, bool up)
        private pure returns (uint256 result)
    {
        result = StableMath.computeInvariant(q.amp, _mathBalances(q, live));
        if (up && result > 0) ++result;
    }

    function _balance(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, uint256[] memory live, uint256 index, uint256 ratio)
        private pure returns (uint256)
    {
        uint256[] memory balances = _mathBalances(q, live);
        uint256 current = StableMath.computeInvariant(q.amp, balances);
        if (current > 0) ++current;
        return StableMath.computeBalance(q.amp, balances, current.mulUp(ratio), index);
    }

    function _checkRatio(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, uint256 ratio, bool joining) private pure {
        if (joining && ratio > q.maxInvariantRatio) revert BasePoolMath.InvariantRatioAboveMax(ratio, q.maxInvariantRatio);
        if (!joining && ratio < q.minInvariantRatio) revert BasePoolMath.InvariantRatioBelowMin(ratio, q.minInvariantRatio);
    }

    function quote(bytes memory state, IBalancerV3PoolLiquidityQuote.LiquidityQuoteParams memory p)
        external view returns (uint256 result, uint256[] memory fees)
    {
        BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q = _decodePoolState(state);
        if (p.index == q.bufferIndex || p.index >= q.rates.length || (p.joining && p.exactOut)) {
            revert IStandardExchangeTransitionQuote.InvalidQuoteState();
        }
        if (p.joining) return _quoteAdd(q, p);
        if (p.exactOut) return _quoteRemoveExactOut(q, p);
        uint256 newSupply = p.supply - p.amountScaled18; // exact-in amount is BPT
        fees = new uint256[](p.balancesLiveScaled18.length);
        // Full-reserve valuation is defined even when execution capacity is smaller.
        // At zero remaining supply the selected balance and taxable amount become zero.
        if (newSupply == 0) return (p.balancesLiveScaled18[p.index], fees);
        uint256 ratio = newSupply.divUp(p.supply);
        uint256 newBalance = _balance(q, p.balancesLiveScaled18, p.index, ratio);
        uint256 taxable = newSupply.mulDivUp(p.balancesLiveScaled18[p.index], p.supply) - newBalance;
        fees[p.index] = taxable.mulUp(p.swapFee);
        result = p.balancesLiveScaled18[p.index] - newBalance - fees[p.index];
    }

    function _quoteAdd(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, IBalancerV3PoolLiquidityQuote.LiquidityQuoteParams memory p)
        private pure returns (uint256 result, uint256[] memory fees)
    {
        uint256[] memory next = new uint256[](p.balancesLiveScaled18.length);
        fees = new uint256[](next.length);
        for (uint256 i; i < next.length; ++i) {
            next[i] = p.balancesLiveScaled18[i] + (i == p.index ? p.amountScaled18 : 0) - 1;
        }
        uint256 currentInvariant = _invariant(q, p.balancesLiveScaled18, true);
        uint256 ratio = _invariant(q, next, false).divDown(currentInvariant);
        _checkRatio(q, ratio, true);
        for (uint256 i; i < next.length; ++i) {
            uint256 proportional = ratio.mulDown(p.balancesLiveScaled18[i]);
            if (next[i] > proportional) {
                fees[i] = (next[i] - proportional).mulUp(p.swapFee);
                next[i] -= fees[i];
            }
        }
        result = (p.supply * (_invariant(q, next, false) - currentInvariant)) / currentInvariant;
    }

    function _quoteRemoveExactOut(BalancerV3StableBufferPoolQuoteTarget.StableBufferQuoteState memory q, IBalancerV3PoolLiquidityQuote.LiquidityQuoteParams memory p)
        private pure returns (uint256 result, uint256[] memory fees)
    {
        uint256[] memory next = new uint256[](p.balancesLiveScaled18.length);
        for (uint256 i; i < next.length; ++i) next[i] = p.balancesLiveScaled18[i] - 1;
        next[p.index] -= p.amountScaled18;
        uint256 currentInvariant = _invariant(q, p.balancesLiveScaled18, true);
        uint256 ratio = _invariant(q, next, true).divUp(currentInvariant);
        uint256 taxable = ratio.mulUp(p.balancesLiveScaled18[p.index]) - next[p.index];
        fees = new uint256[](next.length);
        fees[p.index] = taxable.divUp(p.swapFee.complement()) - taxable;
        next[p.index] -= fees[p.index];
        result = p.supply.mulDivUp(currentInvariant - _invariant(q, next, false), currentInvariant);
    }
}

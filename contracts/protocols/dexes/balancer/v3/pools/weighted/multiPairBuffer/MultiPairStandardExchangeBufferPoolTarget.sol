// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";
import {MultiPairStandardExchangeBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolCommon.sol";
import {MultiPairStandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolRepo.sol";

/**
 * @title MultiPairStandardExchangeBufferPoolTarget
 * @notice Fixed-weight WeightedMath over virtual buffers + derived share depths.
 */
contract MultiPairStandardExchangeBufferPoolTarget is MultiPairStandardExchangeBufferPoolCommon, IBalancerV3Pool {
    function computeInvariant(uint256[] memory balancesLiveScaled18, Rounding rounding)
        public
        view
        virtual
        override
        returns (uint256 invariant)
    {
        uint256[] memory weights = Repo._weightsMemory();
        uint256[] memory balances = _mathBalances(balancesLiveScaled18);
        invariant = rounding == Rounding.ROUND_DOWN
            ? WeightedMath.computeInvariantDown(weights, balances)
            : WeightedMath.computeInvariantUp(weights, balances);
    }

    function computeBalance(uint256[] memory balancesLiveScaled18, uint256 tokenInIndex, uint256 invariantRatio)
        public
        view
        virtual
        override
        returns (uint256 newBalance)
    {
        uint256 currentBalance = _mathBalanceAt(tokenInIndex, balancesLiveScaled18);
        uint256 w = Repo._weight(tokenInIndex);
        newBalance = WeightedMath.computeBalanceOutGivenInvariant(currentBalance, w, invariantRatio);
    }

    function onSwap(PoolSwapParams calldata params)
        public
        view
        virtual
        override
        returns (uint256 amountCalculatedScaled18)
    {
        uint256 balIn = _mathBalanceAt(params.indexIn, params.balancesScaled18);
        uint256 balOut = _mathBalanceAt(params.indexOut, params.balancesScaled18);
        if (balIn == 0) {
            (uint256 pIn,) = Repo._resolveTokenIndex(params.indexIn);
            revert IMultiPairStandardExchangeBufferPool.PoolBufferSideExhausted(pIn);
        }
        if (balOut == 0) {
            (uint256 pOut,) = Repo._resolveTokenIndex(params.indexOut);
            revert IMultiPairStandardExchangeBufferPool.PoolShareSideExhausted(pOut);
        }

        uint256 wIn = Repo._weight(params.indexIn);
        uint256 wOut = Repo._weight(params.indexOut);

        if (params.kind == SwapKind.EXACT_IN) {
            amountCalculatedScaled18 =
                WeightedMath.computeOutGivenExactIn(balIn, wIn, balOut, wOut, params.amountGivenScaled18);
        } else {
            amountCalculatedScaled18 =
                WeightedMath.computeInGivenExactOut(balIn, wIn, balOut, wOut, params.amountGivenScaled18);
        }
    }
}

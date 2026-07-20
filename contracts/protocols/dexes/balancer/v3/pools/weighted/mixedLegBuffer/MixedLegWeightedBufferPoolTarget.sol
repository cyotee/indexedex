// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {MixedLegWeightedBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolCommon.sol";
import {MixedLegWeightedBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";

contract MixedLegWeightedBufferPoolTarget is MixedLegWeightedBufferPoolCommon, IBalancerV3Pool {
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
        newBalance =
            WeightedMath.computeBalanceOutGivenInvariant(currentBalance, Repo._weight(tokenInIndex), invariantRatio);
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
            (IMixedLegWeightedBufferPool.TokenKind k, uint256 leg) = Repo._resolveTokenIndex(params.indexIn);
            if (k == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                revert IMixedLegWeightedBufferPool.PoolBufferSideExhausted(leg);
            }
            if (k == IMixedLegWeightedBufferPool.TokenKind.Share) {
                revert IMixedLegWeightedBufferPool.PoolShareSideExhausted(leg);
            }
            revert IMixedLegWeightedBufferPool.PoolUnpairedSideExhausted(leg);
        }
        if (balOut == 0) {
            (IMixedLegWeightedBufferPool.TokenKind k, uint256 leg) = Repo._resolveTokenIndex(params.indexOut);
            if (k == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                revert IMixedLegWeightedBufferPool.PoolBufferSideExhausted(leg);
            }
            if (k == IMixedLegWeightedBufferPool.TokenKind.Share) {
                revert IMixedLegWeightedBufferPool.PoolShareSideExhausted(leg);
            }
            revert IMixedLegWeightedBufferPool.PoolUnpairedSideExhausted(leg);
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

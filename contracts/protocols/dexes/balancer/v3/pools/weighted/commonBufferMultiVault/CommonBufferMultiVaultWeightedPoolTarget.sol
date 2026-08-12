// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

import {ICommonBufferMultiVaultWeightedPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";
import {CommonBufferMultiVaultWeightedPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolCommon.sol";
import {CommonBufferMultiVaultWeightedPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolRepo.sol";

contract CommonBufferMultiVaultWeightedPoolTarget is CommonBufferMultiVaultWeightedPoolCommon, IBalancerV3Pool {
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
            (ICommonBufferMultiVaultWeightedPool.TokenKind k, uint256 leg) = Repo._resolveTokenIndex(params.indexIn);
            if (k == ICommonBufferMultiVaultWeightedPool.TokenKind.Buffer) {
                revert ICommonBufferMultiVaultWeightedPool.PoolBufferSideExhausted();
            }
            if (k == ICommonBufferMultiVaultWeightedPool.TokenKind.Share) {
                revert ICommonBufferMultiVaultWeightedPool.PoolShareSideExhausted(leg);
            }
            revert ICommonBufferMultiVaultWeightedPool.PoolUnpairedSideExhausted(leg);
        }
        if (balOut == 0) {
            (ICommonBufferMultiVaultWeightedPool.TokenKind k, uint256 leg) = Repo._resolveTokenIndex(params.indexOut);
            if (k == ICommonBufferMultiVaultWeightedPool.TokenKind.Buffer) {
                revert ICommonBufferMultiVaultWeightedPool.PoolBufferSideExhausted();
            }
            if (k == ICommonBufferMultiVaultWeightedPool.TokenKind.Share) {
                revert ICommonBufferMultiVaultWeightedPool.PoolShareSideExhausted(leg);
            }
            revert ICommonBufferMultiVaultWeightedPool.PoolUnpairedSideExhausted(leg);
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

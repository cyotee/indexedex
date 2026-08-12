// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    PoolSwapParams,
    SwapKind,
    Rounding
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    MixedBufferMultiVaultStablePoolCommon
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolCommon.sol";
import {
    MixedBufferMultiVaultStablePoolRepo as Repo
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolRepo.sol";

/**
 * @title MixedBufferMultiVaultStablePoolTarget
 * @notice StableMath onSwap / invariant / computeBalance over math balances + package amp.
 */
contract MixedBufferMultiVaultStablePoolTarget is MixedBufferMultiVaultStablePoolCommon, IBalancerV3Pool {
    using FixedPoint for uint256;

    function computeInvariant(uint256[] memory balancesLiveScaled18, Rounding rounding)
        public
        view
        virtual
        override
        returns (uint256 invariant)
    {
        (uint256 currentAmp,) = Repo._getAmplificationParameter();
        uint256[] memory balances = _mathBalances(balancesLiveScaled18);
        invariant = StableMath.computeInvariant(currentAmp, balances);
        if (invariant > 0 && rounding == Rounding.ROUND_UP) {
            invariant = invariant + 1;
        }
    }

    function computeBalance(uint256[] memory balancesLiveScaled18, uint256 tokenInIndex, uint256 invariantRatio)
        public
        view
        virtual
        override
        returns (uint256 newBalance)
    {
        (uint256 currentAmp,) = Repo._getAmplificationParameter();
        uint256[] memory balances = _mathBalances(balancesLiveScaled18);
        uint256 invariant = StableMath.computeInvariant(currentAmp, balances);
        if (invariant > 0) {
            invariant = invariant + 1;
        }
        newBalance = StableMath.computeBalance(currentAmp, balances, invariant.mulUp(invariantRatio), tokenInIndex);
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
            (IMixedBufferMultiVaultStablePool.TokenKind k, uint256 leg) = Repo._resolveTokenIndex(params.indexIn);
            if (k == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
                revert IMixedBufferMultiVaultStablePool.PoolBufferSideExhausted();
            }
            if (k == IMixedBufferMultiVaultStablePool.TokenKind.Unpaired) {
                revert IMixedBufferMultiVaultStablePool.PoolUnpairedSideExhausted(leg);
            }
            revert IMixedBufferMultiVaultStablePool.PoolShareSideExhausted(leg);
        }
        if (balOut == 0) {
            (IMixedBufferMultiVaultStablePool.TokenKind k, uint256 leg) = Repo._resolveTokenIndex(params.indexOut);
            if (k == IMixedBufferMultiVaultStablePool.TokenKind.Buffer) {
                revert IMixedBufferMultiVaultStablePool.PoolBufferSideExhausted();
            }
            if (k == IMixedBufferMultiVaultStablePool.TokenKind.Unpaired) {
                revert IMixedBufferMultiVaultStablePool.PoolUnpairedSideExhausted(leg);
            }
            revert IMixedBufferMultiVaultStablePool.PoolShareSideExhausted(leg);
        }

        (uint256 currentAmp,) = Repo._getAmplificationParameter();
        uint256[] memory balances = _mathBalances(params.balancesScaled18);
        uint256 invariant = StableMath.computeInvariant(currentAmp, balances);

        if (params.kind == SwapKind.EXACT_IN) {
            amountCalculatedScaled18 = StableMath.computeOutGivenExactIn(
                currentAmp, balances, params.indexIn, params.indexOut, params.amountGivenScaled18, invariant
            );
        } else {
            amountCalculatedScaled18 = StableMath.computeInGivenExactOut(
                currentAmp, balances, params.indexIn, params.indexOut, params.amountGivenScaled18, invariant
            );
        }
    }
}

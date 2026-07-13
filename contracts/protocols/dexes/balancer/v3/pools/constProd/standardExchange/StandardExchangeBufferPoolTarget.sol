// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";

/**
 * @title StandardExchangeBufferPoolTarget
 * @notice Rate-tracking weighted AMM pool target where x = virtualTTA (virtual, from storage)
 *         and y is derived from the Vault-supplied live shares balance minus the hook's
 *         accumulated delta. Effective weights carry currentRate/baselineRate so the pool's
 *         marginal price tracks the Vault-configured rate provider (NAV) directly:
 *         TTA per raw share = (wShares/wTta) * virtualTTA / parShares.
 *         At currentRate == baselineRate the weights are 50/50 — exactly the previous
 *         constant-product behavior.
 * @dev Implements IBalancerV3Pool (computeInvariant, computeBalance, onSwap).
 */
contract StandardExchangeBufferPoolTarget is StandardExchangeBufferPoolCommon, IBalancerV3Pool {

    /**
     * @notice Pool invariant: x^wTta * y^wShares with rate-scaled effective weights.
     * @param balancesLiveScaled18 Token balances after decimal scaling and rates (from Vault).
     * @param rounding Rounding direction.
     */
    function computeInvariant(uint256[] memory balancesLiveScaled18, Rounding rounding)
        public view virtual override returns (uint256 invariant)
    {
        uint256 ttaIdx = StandardExchangeBufferPoolRepo._ttaIndex();
        uint256 sharesIdx = StandardExchangeBufferPoolRepo._sharesIndex();
        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();

        uint256[] memory weights = new uint256[](2);
        uint256[] memory balances = new uint256[](2);
        weights[ttaIdx] = wTta;
        weights[sharesIdx] = wShares;
        balances[ttaIdx] = StandardExchangeBufferPoolRepo._virtualTTA();
        balances[sharesIdx] = _derivedY(balancesLiveScaled18);

        invariant = rounding == Rounding.ROUND_DOWN
            ? WeightedMath.computeInvariantDown(weights, balances)
            : WeightedMath.computeInvariantUp(weights, balances);
    }

    /**
     * @notice New balance of a token after an operation, given an invariant ratio.
     */
    function computeBalance(uint256[] memory balancesLiveScaled18, uint256 tokenInIndex, uint256 invariantRatio)
        public view virtual override returns (uint256 newBalance)
    {
        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();
        bool isTta = (tokenInIndex == StandardExchangeBufferPoolRepo._ttaIndex());
        uint256 currentBalance = isTta
            ? StandardExchangeBufferPoolRepo._virtualTTA()
            : _derivedY(balancesLiveScaled18);
        newBalance = WeightedMath.computeBalanceOutGivenInvariant(
            currentBalance, isTta ? wTta : wShares, invariantRatio
        );
    }

    /**
     * @notice Execute a swap using weighted math over x = virtualTTA and y = derivedY,
     *         with rate-scaled effective weights.
     */
    function onSwap(PoolSwapParams calldata params)
        public view virtual override returns (uint256 amountCalculatedScaled18)
    {
        uint256 x = StandardExchangeBufferPoolRepo._virtualTTA();
        uint256 y = _derivedY(params.balancesScaled18);
        if (y == 0) revert IStandardExchangeBufferPool.PoolSharesSideExhausted();
        if (x == 0) revert IStandardExchangeBufferPool.PoolTTASideExhausted();

        bool ttaIn = (params.indexIn == StandardExchangeBufferPoolRepo._ttaIndex());
        (uint256 wTta, uint256 wShares) = _currentEffectiveWeights();

        if (ttaIn) {
            amountCalculatedScaled18 = params.kind == SwapKind.EXACT_IN
                ? WeightedMath.computeOutGivenExactIn(x, wTta, y, wShares, params.amountGivenScaled18)
                : WeightedMath.computeInGivenExactOut(x, wTta, y, wShares, params.amountGivenScaled18);
        } else {
            amountCalculatedScaled18 = params.kind == SwapKind.EXACT_IN
                ? WeightedMath.computeOutGivenExactIn(y, wShares, x, wTta, params.amountGivenScaled18)
                : WeightedMath.computeInGivenExactOut(y, wShares, x, wTta, params.amountGivenScaled18);
        }
    }
}

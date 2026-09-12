// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool_Comparative_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative_Decimals.sol";
import {TestBase_StandardExchangeBufferPool_Comparative} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol";

import {
    Behavior_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol";

/**
 * @title StandardExchangeBufferPool_Comparative_Spec
 * @notice A/B tests: the Standard Exchange Buffer Pool vs a real BV3 constant-product pool of the
 *         same (TTA, shares) tokens sharing the same rate provider.
 */
abstract contract StandardExchangeBufferPool_Comparative_Spec_Decimals is TestBase_StandardExchangeBufferPool_Comparative_Decimals, Behavior_StandardExchangeBufferPool_Comparative {
    function _base()
        internal
        view
        override
        returns (TestBase_StandardExchangeBufferPool_Comparative)
    {
        return TestBase_StandardExchangeBufferPool_Comparative(address(this));
    }

    function _cmp()
        internal
        view
        returns (TestBase_StandardExchangeBufferPool_Comparative_Decimals)
    {
        return TestBase_StandardExchangeBufferPool_Comparative_Decimals(address(this));
    }

    /// @notice Both pools expose the same effective reserves immediately after matched init.
    function test_compare_init_liveBalancesMatch() public view {
        (uint256 bufTTA, uint256 bufShares) = _cmp().bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = _cmp().referenceReserves();
        assertApproxEqAbs(refTTA, bufTTA, 1e3, "init TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, 1e3, "init shares reserve mismatch");
    }

    /// @dev Native TTA swap size: 10 human units, capped at 1% of Vault live TTA so
    ///      18-dec TTA cannot exceed WeightedMath MaxInRatio on a shallow book.
    function _cmpSwapTtaRaw() internal view returns (uint256 dx) {
        dx = _from18(address(tta), 10e18);
        // WeightedMath MaxInRatio is 30% of virtualTTA (scaled18), not Vault live raw.
        uint256 vtRaw = _from18(address(tta), IStandardExchangeBufferPool(bufferPool).virtualTTA());
        uint256 cap = vtRaw / 10;
        if (cap == 0) cap = vtRaw > 1 ? vtRaw / 2 : 1;
        if (dx > cap) dx = cap;
        if (dx == 0) dx = 1;
    }

    /// @notice TTA->shares EXACT_IN output matches between both pools at the initial rate.
    function test_compare_swap_TTAtoShares_atInitialRate() public {
        behavior_compare_swap_TTAtoShares_exactIn(_cmpSwapTtaRaw());
    }

    /// @notice shares->TTA EXACT_IN output matches between both pools at the initial rate.
    function test_compare_swap_sharesToTTA_atInitialRate() public {
        behavior_compare_swap_sharesToTTA_exactIn(10e18);
    }

    /// @notice After trading the underlying V2 pool, TTA->shares output still matches.
    function test_compare_swap_TTAtoShares_afterRateChange() public {
        (uint256 before_, uint256 after_) = _cmp().tradeUnderlyingV2(_from18(address(tta), 50_000e18));
        assertTrue(after_ != before_, "rate did not move");
        behavior_compare_swap_TTAtoShares_exactIn(_cmpSwapTtaRaw());
    }

    /// @notice After trading the underlying V2 pool, shares->TTA output still matches.
    function test_compare_swap_sharesToTTA_afterRateChange() public {
        (uint256 before_, uint256 after_) = _cmp().tradeUnderlyingV2(_from18(address(tta), 50_000e18));
        assertTrue(after_ != before_, "rate did not move");
        behavior_compare_swap_sharesToTTA_exactIn(10e18);
    }

    /// @notice After the underlying V2 trade, both pools report the same effective reserves
    ///         (hence the same marginal/spot price) without any swap between them.
    function test_compare_spotPrice_afterRateChange() public {
        (uint256 before_, uint256 after_) = _cmp().tradeUnderlyingV2(_from18(address(tta), 50_000e18));
        assertTrue(after_ != before_, "rate did not move");

        (uint256 bufTTA, uint256 bufShares) = _cmp().bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = _cmp().referenceReserves();

        assertApproxEqAbs(refTTA, bufTTA, 1e3, "post-trade TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, 1e3, "post-trade shares reserve mismatch");

        uint256 bufSpot = (bufTTA * 1e18) / bufShares;
        uint256 refSpot = (refTTA * 1e18) / refShares;
        assertApproxEqRel(refSpot, bufSpot, 1e16, "post-trade spot price mismatch");
    }
}

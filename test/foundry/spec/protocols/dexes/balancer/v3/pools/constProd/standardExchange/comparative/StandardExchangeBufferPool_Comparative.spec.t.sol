// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol";
import {
    Behavior_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/behaviors/Behavior_StandardExchangeBufferPool_Comparative.sol";

/**
 * @title StandardExchangeBufferPool_Comparative_Spec
 * @notice A/B tests: the Standard Exchange Buffer Pool vs a real BV3 constant-product pool of the
 *         same (TTA, shares) tokens sharing the same rate provider.
 */
contract StandardExchangeBufferPool_Comparative_Spec is
    TestBase_StandardExchangeBufferPool_Comparative,
    Behavior_StandardExchangeBufferPool_Comparative
{
    function _base()
        internal
        view
        override
        returns (TestBase_StandardExchangeBufferPool_Comparative)
    {
        return TestBase_StandardExchangeBufferPool_Comparative(address(this));
    }

    /// @notice Both pools expose the same effective reserves immediately after matched init.
    function test_compare_init_liveBalancesMatch() public view {
        (uint256 bufTTA, uint256 bufShares) = bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = referenceReserves();
        assertApproxEqAbs(refTTA, bufTTA, ABS_TOL, "init TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, ABS_TOL, "init shares reserve mismatch");
    }

    /// @notice TTA->shares EXACT_IN output matches between both pools at the initial rate.
    function test_compare_swap_TTAtoShares_atInitialRate() public {
        behavior_compare_swap_TTAtoShares_exactIn(10e18);
    }

    /// @notice shares->TTA EXACT_IN output matches between both pools at the initial rate.
    function test_compare_swap_sharesToTTA_atInitialRate() public {
        behavior_compare_swap_sharesToTTA_exactIn(10e18);
    }
}

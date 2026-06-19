// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_StandardExchangeBufferPool_Comparative
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/comparative/bases/TestBase_StandardExchangeBufferPool_Comparative.sol";

/**
 * @title StandardExchangeBufferPool_Comparative_Spec
 * @notice A/B tests: the Standard Exchange Buffer Pool vs a real BV3 constant-product pool of the
 *         same (TTA, shares) tokens sharing the same rate provider.
 */
contract StandardExchangeBufferPool_Comparative_Spec is
    TestBase_StandardExchangeBufferPool_Comparative
{
    /// @notice Both pools expose the same effective reserves immediately after matched init.
    function test_compare_init_liveBalancesMatch() public view {
        (uint256 bufTTA, uint256 bufShares) = bufferEffectiveReserves();
        (uint256 refTTA, uint256 refShares) = referenceReserves();
        assertApproxEqAbs(refTTA, bufTTA, ABS_TOL, "init TTA reserve mismatch");
        assertApproxEqAbs(refShares, bufShares, ABS_TOL, "init shares reserve mismatch");
    }
}

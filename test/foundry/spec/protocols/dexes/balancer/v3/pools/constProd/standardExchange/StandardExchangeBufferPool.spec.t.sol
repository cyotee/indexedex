// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {Behavior_StandardExchangeBufferPool_Registration} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Registration.sol";

/**
 * @title StandardExchangeBufferPoolSpec
 * @notice Spec runner that drives all Standard Exchange Buffer Pool behavior libraries.
 *         Additional behavior contracts (Tasks 17-21) will be inherited here as they are
 *         implemented, keeping all assertions in one Foundry test contract.
 *
 * @dev Inherits TestBase_StandardExchangeBufferPool (full integration fixture) and
 *      each Behavior_* contract.  Each test_ function calls the corresponding
 *      behavior_ function so that the behavior library is also reusable from fork tests
 *      (Task 26) without re-writing assertions.
 */
contract StandardExchangeBufferPoolSpec is
    TestBase_StandardExchangeBufferPool,
    Behavior_StandardExchangeBufferPool_Registration
{
    /* ---------------------------------------------------------------------- */
    /*                       Behavior Hook Implementation                      */
    /* ---------------------------------------------------------------------- */

    function _base() internal view override returns (TestBase_StandardExchangeBufferPool) {
        return TestBase_StandardExchangeBufferPool(address(this));
    }

    /* ---------------------------------------------------------------------- */
    /*                         Registration Tests                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Tokens stored on the pool match tta / shares with correct sorted indices.
    function test_registration_tokensWired() public view {
        behavior_poolIsRegisteredWithExpectedTokens();
    }

    /// @notice The Balancer V3 Vault recorded hooksContract == pool address (self-hook Diamond).
    function test_registration_hookAtPoolAddress() public view {
        behavior_hooksContractEqualsPool();
    }

    /// @notice The pool appears as registered in the Balancer V3 Vault.
    function test_registration_poolRegisteredWithVault() public view {
        behavior_poolIsRegisteredWithVault();
    }

    /// @notice virtualTTA is seeded and hookSharesDelta is zero after initialization.
    function test_registration_initialStorage() public view {
        behavior_initialVirtualTTAAndHookSharesDelta();
    }
}

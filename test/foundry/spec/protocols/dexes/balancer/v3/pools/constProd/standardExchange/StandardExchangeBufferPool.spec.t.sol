// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {Behavior_StandardExchangeBufferPool_Registration} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Registration.sol";
import {Behavior_StandardExchangeBufferPool_Initialization} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Initialization.sol";
import {Behavior_StandardExchangeBufferPool_Swap_TTAtoShares} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Swap_TTAtoShares.sol";
import {Behavior_StandardExchangeBufferPool_Swap_SharesToTTA} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Swap_SharesToTTA.sol";
import {Behavior_StandardExchangeBufferPool_LP_AddProportional} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_LP_AddProportional.sol";
import {Behavior_StandardExchangeBufferPool_LP_RemoveProportional} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_LP_RemoveProportional.sol";

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
    Behavior_StandardExchangeBufferPool_Registration,
    Behavior_StandardExchangeBufferPool_Initialization,
    Behavior_StandardExchangeBufferPool_Swap_TTAtoShares,
    Behavior_StandardExchangeBufferPool_Swap_SharesToTTA,
    Behavior_StandardExchangeBufferPool_LP_AddProportional,
    Behavior_StandardExchangeBufferPool_LP_RemoveProportional
{
    /* ---------------------------------------------------------------------- */
    /*                       Behavior Hook Implementation                      */
    /* ---------------------------------------------------------------------- */

    function _base() internal view override(
        Behavior_StandardExchangeBufferPool_Registration,
        Behavior_StandardExchangeBufferPool_Initialization,
        Behavior_StandardExchangeBufferPool_Swap_TTAtoShares,
        Behavior_StandardExchangeBufferPool_Swap_SharesToTTA,
        Behavior_StandardExchangeBufferPool_LP_AddProportional,
        Behavior_StandardExchangeBufferPool_LP_RemoveProportional
    ) returns (TestBase_StandardExchangeBufferPool) {
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

    /* ---------------------------------------------------------------------- */
    /*                         Initialization Tests                            */
    /* ---------------------------------------------------------------------- */

    /// @notice virtualTTA equals the seeded shares amount times the rate, scaled to 18 decimals.
    function test_init_virtualTTAMatchesSeed() public view {
        behavior_init_virtualTTAMatchesSeed();
    }

    /// @notice hookSharesDelta is exactly zero immediately after initialization.
    function test_init_hookSharesDeltaZero() public view {
        behavior_init_hookSharesDeltaZero();
    }

    /// @notice BPT total supply is positive after initialization.
    function test_init_bptSupplyPositive() public view {
        behavior_init_bptSupplyPositive();
    }

    /// @notice Alice holds the entire BPT supply after initialization.
    function test_init_aliceHoldsBPT() public view {
        behavior_init_aliceHoldsBPT();
    }

    /// @notice Vault raw TTA balance for the pool is positive after initialization.
    function test_init_poolActualTTAPositive() public view {
        behavior_init_poolActualTTAPositive();
    }

    /// @notice Vault raw shares balance for the pool is positive after initialization.
    function test_init_poolActualSharesPositive() public view {
        behavior_init_poolActualSharesPositive();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Swap TTA→Shares Tests                           */
    /* ---------------------------------------------------------------------- */

    /// @notice End-to-end TTA→shares EXACT_IN swap asserts spec section 6.2 post-state.
    function test_swap_TTAtoShares_basic() public {
        behavior_swap_TTAtoShares_endToEnd(10e18);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Swap Shares→TTA Tests                             */
    /* ---------------------------------------------------------------------- */

    /// @notice End-to-end shares→TTA EXACT_IN swap asserts spec section 6.3 post-state.
    function test_swap_sharesToTTA_basic() public {
        behavior_swap_sharesToTTA_endToEnd(10e18);
    }

    /* ---------------------------------------------------------------------- */
    /*                    LP Add Proportional Tests                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Proportional add (shares-only) mints BPT and scales virtualTTA + hookSharesDelta.
    /// @dev Uses a small bptOut (1% of alice's BPT) to stay within her shares balance.
    function test_lpAdd_sharesOnly_basic() public {
        // alice holds (totalSupply - 1e6) BPT after init; use 1% of her balance.
        uint256 aliceBpt = IERC20(this.bufferPool()).balanceOf(this.getAlice());
        uint256 bptOut = aliceBpt / 100;
        if (bptOut == 0) bptOut = 1e15; // floor at 1e15 if balance is too small
        behavior_lpAdd_proportional_sharesOnlyContribution(bptOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                    LP Remove Proportional Tests                         */
    /* ---------------------------------------------------------------------- */

    /// @notice Proportional remove burns BPT and scales virtualTTA + hookSharesDelta down.
    /// @dev Uses 10% of alice's BPT so the pool retains enough liquidity after removal.
    function test_lpRemove_basic() public {
        uint256 aliceBpt = IERC20(this.bufferPool()).balanceOf(this.getAlice());
        uint256 bptIn = aliceBpt / 10;
        if (bptIn == 0) bptIn = 1e15;
        behavior_lpRemove_proportional(bptIn);
    }
}

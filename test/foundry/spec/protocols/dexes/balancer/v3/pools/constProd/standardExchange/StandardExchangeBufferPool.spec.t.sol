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
import {Behavior_StandardExchangeBufferPool_LP_AddUnbalanced} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_LP_AddUnbalanced.sol";
import {Behavior_StandardExchangeBufferPool_Clamping} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Clamping.sol";
import {Behavior_StandardExchangeBufferPool_Errors} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Errors.sol";
import {Behavior_StandardExchangeBufferPool_Adversarial} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/behaviors/Behavior_StandardExchangeBufferPool_Adversarial.sol";

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
    Behavior_StandardExchangeBufferPool_LP_RemoveProportional,
    Behavior_StandardExchangeBufferPool_LP_AddUnbalanced,
    Behavior_StandardExchangeBufferPool_Clamping,
    Behavior_StandardExchangeBufferPool_Errors,
    Behavior_StandardExchangeBufferPool_Adversarial
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
        Behavior_StandardExchangeBufferPool_LP_RemoveProportional,
        Behavior_StandardExchangeBufferPool_LP_AddUnbalanced,
        Behavior_StandardExchangeBufferPool_Clamping,
        Behavior_StandardExchangeBufferPool_Errors,
        Behavior_StandardExchangeBufferPool_Adversarial
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
    /*                    LP Add Unbalanced Tests (Change 1)                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Unbalanced add (shares only) mints BPT without changing virtualTTA.
    /// @dev Shares-only unbalanced adds increase derived_y (the pool's BPT-visible invariant side)
    ///      and produce positive bptAmountOut. virtualTTA stays unchanged because no TTA was added.
    function test_lpAdd_unbalanced_sharesOnly_basic() public {
        behavior_lpAdd_unbalanced_sharesOnly(10e18);
    }

    /// @notice Unbalanced add (both tokens, unequal amounts) mints BPT and grows virtualTTA by ttaIn.
    /// @dev The shares contribution drives invariant growth (and BPT mint); the TTA contribution
    ///      grows virtualTTA by the exact amount added (amountsInScaled18[ttaIdx]).
    function test_lpAdd_unbalanced_bothTokens_basic() public {
        // Contribute a small TTA and a different shares amount - deliberately unequal.
        behavior_lpAdd_unbalanced_bothTokensUnequal(5e18, 10e18);
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

    /* ---------------------------------------------------------------------- */
    /*                         Clamping Tests                                  */
    /* ---------------------------------------------------------------------- */

    /// @notice TTA→shares swap reverts when hookSharesDelta is set to exhaust the shares side.
    function test_clamping_sharesExhausted() public {
        behavior_clamping_revertsWhenSharesSideExhausted();
    }

    /// @notice Shares→TTA swap reverts when virtualTTA is forced to zero.
    function test_clamping_ttaExhausted() public {
        behavior_clamping_revertsWhenTTASideExhausted();
    }

    /* ---------------------------------------------------------------------- */
    /*                          Error Path Tests                               */
    /* ---------------------------------------------------------------------- */

    /// @notice Direct onAddLiquidityCustom call with a non-hook router argument reverts.
    function test_errors_customAddFromNonHook() public {
        behavior_errors_customAddFromNonHookReverts();
    }

    /// @notice Direct onRemoveLiquidityCustom call with a non-hook router argument reverts.
    function test_errors_customRemoveFromNonHook() public {
        behavior_errors_customRemoveFromNonHookReverts();
    }

    /* ---------------------------------------------------------------------- */
    /*                       Adversarial Tests (§ 8.5)                         */
    /* ---------------------------------------------------------------------- */

    /// @notice A rate provider returning 0 causes the swap to revert without corrupting state.
    function test_adversarial_rateProviderZero() public {
        behavior_adversarial_rateProviderZero();
    }

    /// @notice A donation via router.donate() does not shift virtualTTA, hookSharesDelta, or BPT supply.
    function test_adversarial_donationGriefing() public {
        behavior_adversarial_donationGriefing();
    }
}

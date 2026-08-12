// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HooksConfig} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Registration
 * @notice Reusable behavior contract containing one assertion function per registration invariant.
 *         Each function is callable from any spec contract that inherits this contract and implements
 *         _base() to return the deployed test fixture.
 *
 * @dev Designed for Task 16 of the Standard Exchange Buffer Pool plan.
 *      Subsequent behavior libraries (Tasks 17-21) plug into the same spec runner.
 */
abstract contract Behavior_StandardExchangeBufferPool_Registration is Test {
    /* ---------------------------------------------------------------------- */
    /*                         Abstract Hook                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice Implementors return the live test fixture so behavior functions
    ///         can access all public state (bv3Vault, bufferPool, tta, shares, …).
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool);

    /* ---------------------------------------------------------------------- */
    /*                         Behavior Assertions                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Assert that the pool stores the correct token addresses and indices,
     *         along with the expected SE vault and rate provider references.
     *
     * Tokens are sorted by address (ascending) per Balancer convention.
     * The DFPkg computes ttaIdx / sharesIdx as:
     *   address(tta) < address(shares) => ttaIdx = 0, sharesIdx = 1
     *   otherwise                       => ttaIdx = 1, sharesIdx = 0
     */
    function behavior_poolIsRegisteredWithExpectedTokens() public view {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        (uint256 expectedTtaIdx, uint256 expectedSharesIdx) =
            address(tb.tta()) < address(tb.shares()) ? (uint256(0), uint256(1)) : (uint256(1), uint256(0));

        assertEq(p.ttaIndex(),    expectedTtaIdx,            "ttaIndex must match sorted order");
        assertEq(p.sharesIndex(), expectedSharesIdx,         "sharesIndex must match sorted order");
        assertEq(address(p.ttaToken()),            address(tb.tta()),           "ttaToken must match TTA");
        assertEq(address(p.shareToken()),          address(tb.shares()),        "shareToken must match SE vault shares");
        assertEq(address(p.standardExchangeVault()), address(tb.seVault()),     "standardExchangeVault must match seVault");
        assertEq(address(p.rateProvider()),        address(tb.seRateProvider()), "rateProvider must match seRateProvider");
    }

    /**
     * @notice Assert that the Balancer V3 Vault recorded hooksContract == pool address.
     *
     * The DFPkg calls _registerPoolWithBalV3Vault with poolHooksContract = proxy (the Diamond),
     * so the Vault's HooksConfig.hooksContract must equal bufferPool.
     */
    function behavior_hooksContractEqualsPool() public view {
        TestBase_StandardExchangeBufferPool tb = _base();
        HooksConfig memory hc = tb.bv3Vault().getHooksConfig(tb.bufferPool());
        assertEq(hc.hooksContract, tb.bufferPool(), "hooksContract must equal pool (self-hook Diamond)");
    }

    /**
     * @notice Assert that the pool is registered with the Balancer V3 Vault.
     *
     * Uses the canonical IVaultExtension.isPoolRegistered() query.
     */
    function behavior_poolIsRegisteredWithVault() public view {
        TestBase_StandardExchangeBufferPool tb = _base();
        assertTrue(
            tb.bv3Vault().isPoolRegistered(tb.bufferPool()),
            "pool must be registered with the BV3 Vault"
        );
    }

    /**
     * @notice Assert that virtualTTA is seeded to a positive value after initialization
     *         and that hookSharesDelta is zero immediately after init.
     *
     * At init: virtualTTA = shares_amount * rate / 1e18.
     * With a fresh SE Vault backed by balanced Aerodrome liquidity, rate >= 1e18,
     * so virtualTTA > 0 whenever shares_amount > 0.
     */
    function behavior_initialVirtualTTAAndHookSharesDelta() public view {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        assertGt(p.virtualTTA(),    0, "virtualTTA must be seeded > 0 after initialization");
        assertEq(p.hookSharesDelta(), 0, "hookSharesDelta must be 0 immediately after initialization");
    }
}

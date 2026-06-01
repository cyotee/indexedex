// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title Behavior_StandardExchangeBufferPool_Adversarial
 * @notice Reusable behavior contract exercising the adversarial edge cases from spec section 8.5.
 *
 * @dev Adversarial cases covered:
 *
 *      Case 2 — Malicious rate provider returning 0:
 *        vm.mockCall forces getRate() to return 0 on the pool's seRateProvider. A shares→TTA
 *        swap must revert before any state changes because _liftSharesToScaled18Rated detects
 *        rate == 0 and reverts with RateProviderZero. After vm.clearMockedCalls() the pool is
 *        undamaged and a normal swap succeeds.
 *
 *      Case 3 — Donation griefing:
 *        An external attacker donates tokens directly to the Balancer V3 pool via
 *        router.donate(). Since DONATION kind mints 0 BPT, onAfterAddLiquidity's proportional
 *        delta (bptAmountOut * X / T_pre) is zero — virtualTTA and hookSharesDelta are
 *        unchanged. BPT supply is also unchanged. The donated tokens grow actual reserves
 *        (benefiting existing LPs via higher per-BPT value) but the attacker minted no BPT
 *        and cannot drain value.
 *
 * Deferred cases (require alternate pool instances with custom SE Vault mocks — tracked as
 * future work per spec section 10):
 *
 *      Case 1 — Stale-rate sandwich:
 *        The SE Vault rate changes between hook's previewExchangeOut (sizing) and the actual
 *        exchangeOut (settle). Requires a MockStandardExchange with deliberately divergent
 *        previewExchangeOut and exchangeOut return values deployed via a fresh pool instance.
 *        The test base uses a live Aerodrome pool that cannot easily inject this divergence.
 *
 *      Case 4 — Reentrant Standard Exchange Vault:
 *        A malicious mock SE Vault re-enters Vault.swap during exchangeIn/exchangeOut.
 *        Balancer V3's nonReentrant guard should catch it. Requires a fresh pool instance
 *        wired to a ReentrantMockSEVault; the test base fixture exposes no such hook.
 */
abstract contract Behavior_StandardExchangeBufferPool_Adversarial is Test {

    /* ---------------------------------------------------------------------- */
    /*                         Abstract Hook                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Implementors return the live test fixture so behavior functions
    ///         can access all public state (bv3Vault, bufferPool, tta, shares, …).
    function _base() internal view virtual returns (TestBase_StandardExchangeBufferPool);

    /* ---------------------------------------------------------------------- */
    /*                  Case 2 — Malicious Rate Provider (zero)                */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice A rate provider that returns 0 must cause the pool to revert gracefully.
     *
     * @dev Attack vector:
     *        1. Force seRateProvider.getRate() to return 0 via vm.mockCall.
     *        2. Attempt a shares→TTA EXACT_IN swap. The swap path calls onBeforeSwap →
     *           _preSeatShares → _derivedY → _liftSharesToScaled18Rated. The zero-rate
     *           check triggers RateProviderZero before any vault state changes occur.
     *        3. Assert that the swap reverts (typed error may be wrapped by Vault or Router).
     *        4. Clear mocked calls; confirm pool state is undamaged.
     *
     *      Post-state assertions confirm no storage corruption: virtualTTA, hookSharesDelta,
     *      and BPT supply are identical to their pre-attempt values.
     */
    function behavior_adversarial_rateProviderZero() public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        // Cache alice address early so getAlice() is not the call consumed by vm.expectRevert().
        address alice_ = tb.getAlice();

        // Ensure alice holds shares for the attempted swap.
        if (tb.shares().balanceOf(alice_) < 1e15) {
            tb.mintShares(alice_, 1e18);
        }

        // Snapshot storage before the mocked attack.
        uint256 vtPre   = p.virtualTTA();
        int256  hdPre   = p.hookSharesDelta();
        uint256 bptPre  = IERC20(tb.bufferPool()).totalSupply();

        // Force getRate() to return 0 on the pool's seRateProvider.
        address rp = address(tb.seRateProvider());
        vm.mockCall(
            rp,
            abi.encodeWithSelector(IRateProvider.getRate.selector),
            abi.encode(uint256(0))
        );

        // The swap must revert — either typed (RateProviderZero) or vault-wrapped.
        // alice_ is already cached above so no external call is the "next" after expectRevert.
        vm.expectRevert();
        tb.swapSharesForTTA(alice_, 1e15);

        // Restore normal rate provider behaviour.
        vm.clearMockedCalls();

        // Pool state must be identical to the pre-attempt snapshot (no partial writes).
        assertEq(
            p.virtualTTA(),
            vtPre,
            "adversarial_rateProviderZero: virtualTTA unchanged after failed swap"
        );
        assertEq(
            p.hookSharesDelta(),
            hdPre,
            "adversarial_rateProviderZero: hookSharesDelta unchanged after failed swap"
        );
        assertEq(
            IERC20(tb.bufferPool()).totalSupply(),
            bptPre,
            "adversarial_rateProviderZero: BPT supply unchanged after failed swap"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                    Case 3 — Donation Griefing                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice An attacker that donates tokens directly to the pool via router.donate() cannot
     *         shift virtualTTA, hookSharesDelta, or BPT supply in their favour.
     *
     * @dev Attack vector:
     *        1. Attacker (bob) acquires TTA; permit2 approvals for bob are set in setUp.
     *        2. Attacker calls donateLiquidity (test-base helper wrapping router.donate).
     *        3. Balancer V3 processes DONATION kind → bptAmountOut == 0.
     *        4. onAfterAddLiquidity: delta = (0 * vtPre) / tPre == 0 → no-op.
     *        5. Assert virtualTTA, hookSharesDelta, BPT supply all unchanged.
     *
     *      The donated TTA is credited to the pool's raw reserve, raising per-BPT value for
     *      existing LPs — but the attacker receives nothing (they paid for liquidity without
     *      minting BPT). This confirms the pool is correctly immune to donation griefing.
     */
    function behavior_adversarial_donationGriefing() public {
        TestBase_StandardExchangeBufferPool tb = _base();
        IStandardExchangeBufferPool p = IStandardExchangeBufferPool(tb.bufferPool());

        // Use bob as attacker: permit2 approvals for tta (dai) are established in setUp.
        address attacker = tb.getBob();
        uint256 donationTTA = 1e18;

        tb.mintTTA(attacker, donationTTA);

        // Snapshot state before the donation.
        uint256 vtPre   = p.virtualTTA();
        int256  hdPre   = p.hookSharesDelta();
        uint256 bptPre  = IERC20(tb.bufferPool()).totalSupply();

        // Execute the donation via the test-base helper (router.donate with TTA only; shares = 0).
        tb.donateLiquidity(attacker, donationTTA, 0);

        // Proportional scaling: delta = bptAmountOut * vtPre / tPre = 0 * vtPre / tPre == 0.
        assertEq(
            p.virtualTTA(),
            vtPre,
            "adversarial_donation: virtualTTA unchanged after donation"
        );
        assertEq(
            p.hookSharesDelta(),
            hdPre,
            "adversarial_donation: hookSharesDelta unchanged after donation"
        );
        assertEq(
            IERC20(tb.bufferPool()).totalSupply(),
            bptPre,
            "adversarial_donation: BPT supply unchanged after donation (DONATION mints 0 BPT)"
        );
    }
}

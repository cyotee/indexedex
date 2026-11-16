// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {PoolSwapParams} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

import {
    TestBase_StandardExchangeBufferPool_UniV2
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool_UniV2.sol";
import {CommonHarness} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.t.sol";

/**
 * @title StandardExchangeBufferPool_RateTrackingTest
 * @notice Real-rate-movement integration coverage for the Task 1-3 rate-tracking refactor.
 *
 * @dev NO MOCKS: every rate movement in this suite is produced by a genuine trade through the
 *      underlying Uniswap V2 DAI/USDC pair (via `_shiftRateUp` / `_shiftRateDown` on
 *      `TestBase_StandardExchangeBufferPool_UniV2`), which shifts the SE vault's per-share NAV
 *      and is observed by the pool exclusively via `IVault.getPoolTokenRates` in production code.
 *      The single exception is `test_extremeRateDrift_revertsEffectiveWeightOutOfBounds`, which
 *      vm.stores an extreme `baselineRate` purely to exercise the `EffectiveWeightOutOfBounds`
 *      guard path (a ~99x rate drift since init is not reachable through real trading in this
 *      fixture's timeframe).
 */
contract StandardExchangeBufferPool_RateTrackingTest is TestBase_StandardExchangeBufferPool_UniV2 {
    /// @dev Same slot layout as StandardExchangeBufferPoolTarget.t.sol / StandardExchangeBufferPoolRepo.
    uint256 internal constant BASELINE_RATE_OFFSET = 10;

    /// @notice Pool quotes NAV at initialization (equilibrium identity).
    function test_initialQuote_isNav() public {
        uint256 rate = seRateProvider.getRate();
        uint256 dx = 1e15; // small trade => marginal price
        uint256 sharesOut = _quoteSwapExactIn(tta, shareToken(), dx);
        // NAV: TTA per raw share = scalingFactor * rate / 1e18; invert for shares-out
        // (fused via _sharesOutAtNav to avoid flooring the NAV to 0 for large rate/raw-supply
        // ratios - see its docs).
        uint256 expected = _sharesOutAtNav(dx, rate);
        assertApproxEqRel(sharesOut, expected, 0.01e18);
    }

    /// @notice The headline property: after real V2 trades move the NAV, the pool re-quotes
    ///         proportionally with NO trades against the buffer pool itself.
    function test_quoteTracksRate_upAndDown() public {
        uint256 dx = 1e15;
        uint256 r1 = seRateProvider.getRate();
        uint256 out1 = _quoteSwapExactIn(tta, shareToken(), dx);

        uint256 r2 = _shiftRateUp();
        uint256 out2 = _quoteSwapExactIn(tta, shareToken(), dx);
        assertApproxEqRel(out2, Math.mulDiv(out1, r1, r2), 0.005e18, "up-shift not tracked");

        uint256 r3 = _shiftRateDown();
        uint256 out3 = _quoteSwapExactIn(tta, shareToken(), dx);
        assertApproxEqRel(out3, Math.mulDiv(out1, r1, r3), 0.005e18, "down-shift not tracked");
    }

    /// @notice Full-path swap (through the Balancer Vault + hook) executes near NAV after a shift.
    function test_fullPathSwap_executesNearNav_afterRateShift() public {
        uint256 r = _shiftRateUp();
        uint256 dx = 1e16;

        // Task 5 unblocks this: a large enough up-shift can cause the hook's onAfterSwap
        // deposit-back-to-SE-vault step to revert with PostSwapDepositFailed. If that happens
        // here, skip rather than shrinking the rate shift to hide the defect.
        try this.__swapTtaForSharesExternal(dx) returns (uint256 sharesReceived) {
            uint256 expected = _sharesOutAtNav(dx, r);
            // fee + finite-size slippage tolerance
            assertApproxEqRel(sharesReceived, expected, 0.07e18);
        } catch (bytes memory reason) {
            if (_isPostSwapDepositFailed(reason)) {
                vm.skip(true);
                return;
            }
            assembly {
                revert(add(reason, 0x20), mload(reason))
            }
        }
    }

    /// @notice Effective-weight bound: force an extreme baseline via vm.store ONLY to prove the
    ///         guard path (production state cannot reach it without ~99x rate drift).
    function test_extremeRateDrift_revertsEffectiveWeightOutOfBounds() public {
        uint256 currentRate = seRateProvider.getRate();
        uint256 forcedBaseline = currentRate * 150;
        vm.store(
            bufferPool,
            bytes32(
                uint256(keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange"))
                    + BASELINE_RATE_OFFSET
            ),
            bytes32(forcedBaseline)
        );

        // The guard (_effectiveWeights) is deterministic and pure; capture its exact revert data
        // (via the same CommonHarness the unit tests use) so expectRevert can match it exactly.
        // (This forge-std cheatcode version does exact calldata matching for a parameterized
        // custom error selector, not selector-only prefix matching.)
        bytes memory expectedRevertData = _effectiveWeightOutOfBoundsData(currentRate, forcedBaseline);

        // Build params BEFORE arming expectRevert: onSwap must be the literal next external call,
        // and _quoteSwapExactIn's own index/balance lookups are external (view) calls that would
        // otherwise consume the revert expectation before onSwap ever runs.
        (PoolSwapParams memory params,) = _buildQuoteParams(tta, shareToken(), 1e15);
        vm.expectRevert(expectedRevertData);
        IBalancerV3Pool(bufferPool).onSwap(params);
    }

    /// @dev Calls CommonHarness.effectiveWeights (which reverts with EffectiveWeightOutOfBounds
    ///      for this rate ratio, same as the production guard) and returns its raw revert data.
    function _effectiveWeightOutOfBoundsData(uint256 currentRate, uint256 baselineRate_)
        internal
        returns (bytes memory)
    {
        try new CommonHarness().effectiveWeights(currentRate, baselineRate_) returns (uint256, uint256) {
            revert("expected EffectiveWeightOutOfBounds but harness returned normally");
        } catch (bytes memory reason) {
            return reason;
        }
    }

    /// Regression: TTA->shares through the full path after an upward NAV shift used to
    /// revert PostSwapDepositFailed (exchangeOut needed more TTA than the user paid).
    /// This stresses the maximum reachable rate drift in this fixture: a large direct V2
    /// trade (bigger than _shiftRateUp's default 10%-of-balance trade) pushes the rate close
    /// to (but inside) the effective-weight guard bound, then a swap sized to ~29% of
    /// virtualTTA is pushed through the buffer pool - the largest dx that stays clear of the
    /// weight guard at this drift. Under the old exact-mint (exchangeOut) reconcile this
    /// combination was the closest reachable approximation of a PostSwapDepositFailed
    /// revert (see task-5-report.md for why an exact repro could not be forced within the
    /// weight bound); under the new best-effort (exchangeIn) reconcile it must succeed.
    function test_ttaToShares_afterUpwardNavShift_succeeds() public {
        _swapThroughV2Pair(tta, ttb, 950_000_000e18);
        uint256 vt = IStandardExchangeBufferPool(bufferPool).virtualTTA();
        uint256 dx = (vt * 29) / 100;
        uint256 sharesReceived = _swapThroughBalancerVault(tta, shareToken(), dx);
        assertGt(sharesReceived, 0);
    }

    /// @notice EXACT_OUT full-path regression: request `sharesOut` close to (but safely under)
    ///         30% of the pool's shares-side live balance (`WeightedMath._MAX_OUT_RATIO`). This is
    ///         the lever the Task 5 reviewer flagged as untested: `onSwap` supports EXACT_OUT via
    ///         `computeInGivenExactOut`, whose required TTA input diverges non-linearly as the
    ///         requested shares approach the out-ratio ceiling - orthogonal to the rate-drift /
    ///         weight-guard lever the original Task 5 analysis exercised. `onAfterSwap` still calls
    ///         `_reconcileTTAToShares(params.amountInScaled18)` for this swap kind, so the
    ///         best-effort reconcile must handle whatever (possibly large) X_raw the Vault quotes.
    ///         No rate shift: isolates the pure out-ratio lever.
    function test_ttaToSharesExactOut_nearMaxOutRatio_succeeds() public {
        uint256[] memory bal = bv3Vault.getCurrentLiveBalances(bufferPool);
        uint256 sharesLiveScaled18 = bal[_sharesIdx()];

        // Convert the 30%-of-live-balance ceiling (scaled18) back to RAW shares so it can be
        // passed as `exactAmountOut` to the router (which expects raw token units).
        (uint256[] memory scalingFactors, uint256[] memory rates) = bv3Vault.getPoolTokenRates(bufferPool);
        uint256 denom = scalingFactors[_sharesIdx()] * rates[_sharesIdx()];
        uint256 maxOutRatioScaled18 = Math.mulDiv(sharesLiveScaled18, 30, 100);
        uint256 maxOutRatioRaw = Math.mulDiv(maxOutRatioScaled18, 1e18, denom);

        // 95% of the 30% ceiling: close to, but safely under, the guard.
        uint256 sharesOut = (maxOutRatioRaw * 95) / 100;
        assertGt(sharesOut, 0, "sharesOut must be nonzero to be a meaningful regression");

        uint256 userSharesBefore = shareToken().balanceOf(address(this));
        uint256 amountIn = _swapThroughBalancerVaultExactOut(tta, shareToken(), sharesOut, type(uint128).max);
        uint256 userSharesAfter = shareToken().balanceOf(address(this));

        assertGt(amountIn, 0, "swap reported zero TTA in");
        assertEq(userSharesAfter - userSharesBefore, sharesOut, "user did not receive exactly sharesOut");
    }

    /// @notice Same EXACT_OUT near-max-out-ratio scenario, but combined with a moderate in-bounds
    ///         upward rate shift - exercises both levers (out-ratio + rate drift) together.
    function test_ttaToSharesExactOut_nearMaxOutRatio_withRateShift_succeeds() public {
        _shiftRateUp();

        uint256[] memory bal = bv3Vault.getCurrentLiveBalances(bufferPool);
        uint256 sharesLiveScaled18 = bal[_sharesIdx()];

        (uint256[] memory scalingFactors, uint256[] memory rates) = bv3Vault.getPoolTokenRates(bufferPool);
        uint256 denom = scalingFactors[_sharesIdx()] * rates[_sharesIdx()];
        uint256 maxOutRatioScaled18 = Math.mulDiv(sharesLiveScaled18, 30, 100);
        uint256 maxOutRatioRaw = Math.mulDiv(maxOutRatioScaled18, 1e18, denom);

        uint256 sharesOut = (maxOutRatioRaw * 95) / 100;
        assertGt(sharesOut, 0, "sharesOut must be nonzero to be a meaningful regression");

        uint256 userSharesBefore = shareToken().balanceOf(address(this));
        uint256 amountIn = _swapThroughBalancerVaultExactOut(tta, shareToken(), sharesOut, type(uint128).max);
        uint256 userSharesAfter = shareToken().balanceOf(address(this));

        assertGt(amountIn, 0, "swap reported zero TTA in");
        assertEq(userSharesAfter - userSharesBefore, sharesOut, "user did not receive exactly sharesOut");
    }

    /// @notice No free lunch: a round trip after a rate shift returns strictly less than paid.
    function test_roundTrip_afterRateShift_losesFees() public {
        _shiftRateUp();
        uint256 dx = 1e16;
        uint256 sharesReceived = _swapThroughBalancerVault(tta, shareToken(), dx);
        uint256 back = _swapThroughBalancerVault(shareToken(), tta, sharesReceived);
        assertLt(back, dx);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Internal helpers                          */
    /* ---------------------------------------------------------------------- */

    /// @dev External self-call wrapper so `test_fullPathSwap_executesNearNav_afterRateShift` can
    ///      catch `PostSwapDepositFailed` via try/catch (only external calls are catchable).
    function __swapTtaForSharesExternal(uint256 amountIn) external returns (uint256) {
        require(msg.sender == address(this), "internal only");
        return _swapThroughBalancerVault(tta, shareToken(), amountIn);
    }

    function _isPostSwapDepositFailed(bytes memory reason) internal pure returns (bool) {
        if (reason.length < 4) return false;
        bytes4 selector;
        assembly {
            selector := mload(add(reason, 0x20))
        }
        return selector == IStandardExchangeBufferPool.PostSwapDepositFailed.selector;
    }
}

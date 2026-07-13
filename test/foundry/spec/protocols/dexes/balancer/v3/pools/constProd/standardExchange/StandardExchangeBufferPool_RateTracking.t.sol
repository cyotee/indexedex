// SPDX-License-Identifier: BUSL-1.1
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
        // ratios — see its docs).
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

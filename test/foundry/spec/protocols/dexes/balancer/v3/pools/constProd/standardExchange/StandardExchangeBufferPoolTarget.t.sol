// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {CommonHarness} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.t.sol";

/**
 * @title StandardExchangeBufferPoolTargetTest
 * @notice Unit tests for StandardExchangeBufferPoolTarget (onSwap, computeInvariant, computeBalance)
 *         exercised against the real deployed pool from TestBase_StandardExchangeBufferPool.
 *
 * @dev WHY THIS INHERITS THE FULL INTEGRATION BASE (no StaticRateProvider / vm.mockCall):
 *
 *      The previous version of this test used a local StaticRateProvider and vm.mockCall to stub
 *      IERC20.decimals().  Those mocks encoded the developer's belief about the rate provider's
 *      behaviour rather than testing against real code.  Every production bug found during Tasks
 *      19/20 sailed past those mocks.
 *
 *      By inheriting TestBase_StandardExchangeBufferPool we get:
 *        - A real Balancer V3 VaultMock (Crane)
 *        - A real Aerodrome DAI/USDC SE vault
 *        - A real ERC4626-based rate provider (seRateProvider)
 *        - A fully-registered and initialized buffer pool diamond (bufferPool)
 *
 *      onSwap is a public view function; any address can call it directly with crafted
 *      PoolSwapParams.  Tests that need to force specific virtualTTA / hookSharesDelta values
 *      use vm.store (the same technique Behavior_Clamping uses) rather than a custom setter.
 *
 *      Slot layout for StandardExchangeBufferPoolRepo.Storage (base = POOL_REPO_SLOT):
 *        offset 0  ttaToken
 *        offset 1  shareToken
 *        offset 2  standardExchangeVault
 *        offset 3  rateProvider
 *        offset 4  ttaIndex
 *        offset 5  sharesIndex
 *        offset 6  expectedFactory
 *        offset 7  virtualTTA         ← VIRTUAL_TTA_OFFSET
 *        offset 8  hookSharesDelta    ← HOOK_SHARES_DELTA_OFFSET
 *        offset 9  pendingPreSeatS
 *        offset 10 baselineRate       ← BASELINE_RATE_OFFSET
 */
contract StandardExchangeBufferPoolTargetTest is TestBase_StandardExchangeBufferPool {

    /* ---------------------------------------------------------------------- */
    /*                              Storage offsets                             */
    /* ---------------------------------------------------------------------- */

    bytes32 internal constant POOL_REPO_SLOT =
        keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange");

    uint256 internal constant VIRTUAL_TTA_OFFSET      = 7;
    uint256 internal constant HOOK_SHARES_DELTA_OFFSET = 8;
    uint256 internal constant BASELINE_RATE_OFFSET     = 10;

    /* ---------------------------------------------------------------------- */
    /*                              Helpers                                     */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Force virtualTTA to `v` in the pool's diamond storage via vm.store.
     *      Uses the same slot layout as Behavior_Clamping.
     */
    function _setVirtualTTA(uint256 v) internal {
        vm.store(bufferPool, bytes32(uint256(POOL_REPO_SLOT) + VIRTUAL_TTA_OFFSET), bytes32(v));
    }

    /**
     * @dev Force hookSharesDelta to `v` in the pool's diamond storage via vm.store.
     *      The value is stored as uint256 (int256 is bitwise-identical in EVM slots).
     */
    function _setHookSharesDelta(int256 v) internal {
        vm.store(bufferPool, bytes32(uint256(POOL_REPO_SLOT) + HOOK_SHARES_DELTA_OFFSET), bytes32(uint256(v)));
    }

    /**
     * @dev Force baselineRate to `v` in the pool's diamond storage via vm.store.
     */
    function _setBaselineRate(uint256 v) internal {
        vm.store(bufferPool, bytes32(uint256(POOL_REPO_SLOT) + BASELINE_RATE_OFFSET), bytes32(v));
    }

    /**
     * @dev Read virtualTTA from the live pool.
     */
    function _virtualTTA() internal view returns (uint256) {
        return IStandardExchangeBufferPool(bufferPool).virtualTTA();
    }

    /**
     * @dev Read the Vault's current live (scaled18 + rated) balances for the pool — the same
     *      array onSwap/computeInvariant receive from the Vault.
     */
    function _liveBalances() internal view returns (uint256[] memory) {
        return bv3Vault.getCurrentLiveBalances(bufferPool);
    }

    /**
     * @dev Convenience wrapper around _buildSwapParams using the live balances, matching the
     *      brief's `_swapParams(kind, amount, idxIn, idxOut)` shape.
     */
    function _swapParams(SwapKind kind, uint256 amount, uint256 idxIn, uint256 idxOut)
        internal view returns (PoolSwapParams memory)
    {
        return _buildSwapParams(kind, idxIn, idxOut, amount, _liveBalances());
    }

    /**
     * @dev Build a PoolSwapParams with the given fields.  router and userData are not used
     *      by onSwap so we pass zero / empty.
     */
    function _buildSwapParams(
        SwapKind kind,
        uint256 idxIn,
        uint256 idxOut,
        uint256 amount,
        uint256[] memory bal
    ) internal pure returns (PoolSwapParams memory) {
        return PoolSwapParams({
            kind: kind,
            amountGivenScaled18: amount,
            balancesScaled18: bal,
            indexIn: idxIn,
            indexOut: idxOut,
            router: address(0),
            userData: ""
        });
    }

    /**
     * @dev Convenience: build balancesScaled18 consistent with "virtualTTA = 100e18, y = 100e18"
     *      regardless of token order.  The pool's actual indices are used so the test is
     *      order-independent.
     */
    function _bal100() internal view returns (uint256[] memory bal) {
        bal = new uint256[](2);
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();
        // TTA side is virtual — we pass 0 in the balances array (onSwap reads virtualTTA from storage).
        bal[sharesIdx] = 100e18;
    }

    /* ---------------------------------------------------------------------- */
    /*                         onSwap Tests                                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice EXACT_IN TTA→shares: CP formula dy = y*dx/(x+dx) with x=y=100e18, dx=10e18.
     *         Expected out: 100 * 10 / (100 + 10) ≈ 9.0909e18.
     */
    function test_onSwap_TTAin_EXACT_IN_basicCP() public {
        // Force virtualTTA to a known value.
        _setVirtualTTA(100e18);
        _setHookSharesDelta(0);

        uint256 ttaIdx    = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256[] memory bal = new uint256[](2);
        bal[sharesIdx] = 100e18;

        uint256 out = IBalancerV3Pool(bufferPool).onSwap(
            _buildSwapParams(SwapKind.EXACT_IN, ttaIdx, sharesIdx, 10e18, bal)
        );
        // 100 * 10 / (100 + 10) = 9.0909...e18
        assertApproxEqAbs(out, 9.090909090909090909e18, 1e9);
    }

    /**
     * @notice EXACT_IN shares→TTA: same formula (x=y=100e18, dx=10e18) → ≈ 9.0909e18 TTA.
     */
    function test_onSwap_SharesIn_EXACT_IN_basicCP() public {
        _setVirtualTTA(100e18);
        _setHookSharesDelta(0);

        uint256 ttaIdx    = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256[] memory bal = new uint256[](2);
        bal[sharesIdx] = 100e18;

        uint256 out = IBalancerV3Pool(bufferPool).onSwap(
            _buildSwapParams(SwapKind.EXACT_IN, sharesIdx, ttaIdx, 10e18, bal)
        );
        assertApproxEqAbs(out, 9.090909090909090909e18, 1e9);
    }

    /**
     * @notice A positive hookSharesDelta reduces the effective shares depth (derivedY = y - delta).
     *
     *         hookSharesDelta is stored in RAW share units. _liftSharesToScaled18Rated converts it
     *         to scaled18 using the rate provider before subtracting from balancesScaled18.
     *         To produce derivedY = 80e18 from balancesScaled18 = 100e18, we need:
     *           liftToScaled18(hookDeltaRaw) = 20e18
     *           hookDeltaRaw = 20e18 * 1e18 / rate
     *         This is rate-agnostic: regardless of what getRate() returns, derivedY = 80e18.
     */
    function test_onSwap_hookSharesDeltaShiftsDerivedY() public {
        _setVirtualTTA(100e18);

        // Compute the raw hookSharesDelta that corresponds to 20e18 scaled18 units at the
        // current rate, so that liftToScaled18(hookDeltaRaw) = 20e18 regardless of rate.
        uint256 rate = IStandardExchangeBufferPool(bufferPool).rateProvider().getRate();
        uint256 hookDeltaRaw = rate > 0 ? (20e18 * 1e18) / rate : 20e18;
        _setHookSharesDelta(int256(hookDeltaRaw));

        uint256 ttaIdx    = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256[] memory bal = new uint256[](2);
        bal[sharesIdx] = 100e18;

        uint256 out = IBalancerV3Pool(bufferPool).onSwap(
            _buildSwapParams(SwapKind.EXACT_IN, ttaIdx, sharesIdx, 10e18, bal)
        );
        // derivedY = 100e18 - 20e18 = 80e18, x = 100e18 → dy = 80*10/110 = 7.2727...
        assertApproxEqAbs(out, 7.272727272727272727e18, 1e9);
    }

    /**
     * @notice When hookSharesDelta exceeds actual shares balance, derivedY clamps to 0 and the pool
     *         reverts with PoolSharesSideExhausted on a TTA→shares swap.
     */
    function test_onSwap_revertsWhenSharesSideExhausted() public {
        _setVirtualTTA(100e18);
        // hookSharesDelta > actual shares balance → derivedY clamps to 0.
        _setHookSharesDelta(int256(120e18));

        uint256 ttaIdx    = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256[] memory bal = new uint256[](2);
        bal[sharesIdx] = 100e18;

        vm.expectRevert(IStandardExchangeBufferPool.PoolSharesSideExhausted.selector);
        IBalancerV3Pool(bufferPool).onSwap(
            _buildSwapParams(SwapKind.EXACT_IN, ttaIdx, sharesIdx, 10e18, bal)
        );
    }

    /**
     * @notice When virtualTTA is forced to 0, the pool reverts with PoolTTASideExhausted on a
     *         shares→TTA swap.
     */
    function test_onSwap_revertsWhenTTASideExhausted() public {
        _setVirtualTTA(0);
        _setHookSharesDelta(0);

        uint256 ttaIdx    = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256[] memory bal = new uint256[](2);
        bal[sharesIdx] = 100e18;

        vm.expectRevert(IStandardExchangeBufferPool.PoolTTASideExhausted.selector);
        IBalancerV3Pool(bufferPool).onSwap(
            _buildSwapParams(SwapKind.EXACT_IN, sharesIdx, ttaIdx, 10e18, bal)
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       computeInvariant Tests                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice computeInvariant = sqrt(virtualTTA * derivedY).
     *         With virtualTTA = 100e18 and derivedY = 100e18 → invariant ≈ 100e18.
     */
    function test_computeInvariant_sqrtOfXY() public {
        _setVirtualTTA(100e18);
        _setHookSharesDelta(0);

        uint256[] memory bal = new uint256[](2);
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();
        bal[sharesIdx] = 100e18;

        uint256 inv = IBalancerV3Pool(bufferPool).computeInvariant(bal, Rounding.ROUND_DOWN);
        // sqrt(100e18 * 100e18) = 100e18
        assertApproxEqAbs(inv, 100e18, 1e9);
    }

    /* ---------------------------------------------------------------------- */
    /*                 Rate-Tracking Weighted Math Tests (Task 3)               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice At rate == baselineRate weights are 50/50 and the quote must equal the CP
     *         formula to within rounding (<= 2 wei).
     */
    function test_onSwap_matchesCP_atBaseline() public {
        uint256 ttaIdx = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256 x = _virtualTTA();
        uint256[] memory bals = _liveBalances();
        uint256 y = bals[sharesIdx];
        uint256 dx = x / 100;
        uint256 cpOut = y * dx / (x + dx);
        uint256 got = IBalancerV3Pool(bufferPool).onSwap(_swapParams(SwapKind.EXACT_IN, dx, ttaIdx, sharesIdx));
        // FixedPoint.powUp/powDown special-case exponent 1e18 (the 50/50 case) to identity,
        // bypassing LogExpMath entirely. The small divergence comes from 18-decimal fixed-point
        // rounding of `base = balanceIn.divUp(balanceIn + amountIn)` and complement rounding
        // inside WeightedMath vs the reference's exact integer division. Use a tight relative
        // tolerance instead of an absolute "<=2 wei" bound to handle larger swap sizes.
        assertApproxEqRel(got, cpOut, 1e9, "50/50 weighted != CP");
    }

    /**
     * @notice Force baselineRate = currentRate / 1.2, i.e. the rate has "risen" 20% since
     *         init. The quoted shares-out for a small TTA amount must fall by ~1.2x versus
     *         the baseline quote. Under the old CP math the two quotes are identical.
     */
    function test_onSwap_quoteScalesInverselyWithRateRatio() public {
        uint256 ttaIdx = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256 dx = 1e15;
        uint256 out1 = IBalancerV3Pool(bufferPool).onSwap(_swapParams(SwapKind.EXACT_IN, dx, ttaIdx, sharesIdx));
        uint256 currentRate = seRateProvider.getRate();
        _setBaselineRate(Math.mulDiv(currentRate, 1e18, 1.2e18));
        uint256 out2 = IBalancerV3Pool(bufferPool).onSwap(_swapParams(SwapKind.EXACT_IN, dx, ttaIdx, sharesIdx));
        // price-per-share ∝ rate/baseline ⇒ shares-out ∝ baseline/rate
        // (0.5% tolerance for finite trade size)
        assertApproxEqRel(out2, Math.mulDiv(out1, 1e18, 1.2e18), 0.005e18, "quote did not track rate ratio");
    }

    /**
     * @notice Invariant equals WeightedMath.computeInvariantDown over [virtualTTA, derivedY]
     *         with the effective weights for the forced rate ratio.
     */
    function test_computeInvariant_usesEffectiveWeights() public {
        uint256 ttaIdx = IStandardExchangeBufferPool(bufferPool).ttaIndex();
        uint256 sharesIdx = IStandardExchangeBufferPool(bufferPool).sharesIndex();

        uint256 currentRate = seRateProvider.getRate();
        _setBaselineRate(Math.mulDiv(currentRate, 1e18, 1.2e18));
        (uint256 wTta, uint256 wShares) = new CommonHarness().effectiveWeights(1.2e18, 1e18);

        uint256[] memory bals = _liveBalances();
        uint256[] memory weights = new uint256[](2);
        uint256[] memory balances = new uint256[](2);
        weights[ttaIdx] = wTta;
        weights[sharesIdx] = wShares;
        balances[ttaIdx] = _virtualTTA();
        balances[sharesIdx] = bals[sharesIdx]; // hookSharesDelta is 0 here, so derivedY == live
        uint256 expected = WeightedMath.computeInvariantDown(weights, balances);

        uint256 got = IBalancerV3Pool(bufferPool).computeInvariant(bals, Rounding.ROUND_DOWN);
        assertApproxEqRel(got, expected, 1e6);
    }
}

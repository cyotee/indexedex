// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {FullSpreadMaintenanceReferenceMath as Ref} from "contracts/test/utils/FullSpreadMaintenanceReferenceMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";

/// @notice Independent real-core terminal observations; family adapters supply only the SUT plan/actions.
/// @dev The actor owns salt zero. Salt one is the independently funded external LP.
// tag::TestBase_FullSpreadMaintenanceObservation[]
abstract contract TestBase_FullSpreadMaintenanceObservation is Test {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;

    struct Observation {
        uint160 price;
        int24 tick;
        uint128 liquidity;
        uint128 active;
        uint256[2] free;
        uint256[2] principal;
        uint256[2] fees;
    }
    struct Outcome {
        Observation baseline;
        Observation actual;
        Types.Plan plan;
    }

    function _observedManager() internal view virtual returns (IPoolManager);
    function _observedKey() internal view virtual returns (PoolKey memory);
    function _observedTicks() internal view virtual returns (int24, int24);
    function _observedModify(int256 delta, bytes32 salt) internal virtual returns (BalanceDelta, BalanceDelta);
    function _observedSwap(bool direction, uint256 amount) internal virtual returns (BalanceDelta);
    function _observedPlan(Types.Snapshot memory state) internal view virtual returns (Types.Plan memory);
    function _observedFeeMark() internal view virtual returns (bytes memory) { return bytes(""); }
    function _observedCheckFees(bytes memory, Types.Swap memory, BalanceDelta) internal view virtual {}
    function _observedHasLpFee() internal pure virtual returns (bool) { return true; }

    function _observe() internal returns (Observation memory o) {
        IPoolManager pm = _observedManager();
        PoolKey memory k = _observedKey();
        (int24 lo, int24 hi) = _observedTicks();
        o.free = [IERC20(Currency.unwrap(k.currency0)).balanceOf(address(this)),
            IERC20(Currency.unwrap(k.currency1)).balanceOf(address(this))];
        (o.price, o.tick,,) = StateLibrary.getSlot0(pm, k.toId());
        o.active = StateLibrary.getLiquidity(pm, k.toId());
        (o.liquidity,,) = StateLibrary.getPositionInfo(pm, k.toId(), address(this), lo, hi, bytes32(0));
        if (o.liquidity == 0) return o;
        uint256 checkpoint = vm.snapshotState();
        (BalanceDelta total, BalanceDelta fees) = _observedModify(-int256(uint256(o.liquidity)), bytes32(0));
        int256 p0 = int256(total.amount0()) - int256(fees.amount0());
        int256 p1 = int256(total.amount1()) - int256(fees.amount1());
        assertGe(p0, 0); assertGe(p1, 0);
        assertGe(int256(fees.amount0()), 0); assertGe(int256(fees.amount1()), 0);
        o.principal = [uint256(p0), uint256(p1)];
        o.fees = [uint256(int256(fees.amount0())), uint256(int256(fees.amount1()))];
        assertTrue(vm.revertToStateAndDelete(checkpoint));
    }

    function _metric(Observation memory o) internal view returns (Ref.Metric memory) {
        (int24 lo, int24 hi) = _observedTicks();
        return Ref.metric(o.free, o.principal, o.price, TickMath.getSqrtPriceAtTick(lo),
            TickMath.getSqrtPriceAtTick(hi), 0.2e18, [uint256(1e12), uint256(1e12)]);
    }

    function _plannerInput(Observation memory o) internal view returns (Types.Snapshot memory s) {
        PoolKey memory k = _observedKey();
        IPoolManager pm = _observedManager();
        (int24 lo, int24 hi) = _observedTicks();
        s.idle = true; s.sleeveWad = 0.2e18;
        s.absoluteFloor = [uint256(1e12), uint256(1e12)];
        s.book.free = o.free; s.book.deployed = o.principal; s.book.earned = o.fees;
        s.book.supply = 1_000e18; // Maintenance never changes supply; not a pricing reference.
        s.position.sqrtPriceX96 = o.price; s.position.tick = o.tick;
        s.position.lower = lo; s.position.upper = hi;
        s.position.lowerX96 = TickMath.getSqrtPriceAtTick(lo);
        s.position.upperX96 = TickMath.getSqrtPriceAtTick(hi);
        s.position.liquidity = o.liquidity; s.position.activeLiquidity = o.active;
        (s.position.lowerLiquidityGross,) = StateLibrary.getTickLiquidity(pm, k.toId(), lo);
        (s.position.upperLiquidityGross,) = StateLibrary.getTickLiquidity(pm, k.toId(), hi);
        s.position.maxLiquidityPerTick = Pool.tickSpacingToMaxLiquidityPerTick(k.tickSpacing);
    }

    function _collectObserved() internal {
        (int24 lo, int24 hi) = _observedTicks();
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(_observedManager(), _observedKey().toId(), address(this), lo, hi, bytes32(0));
        if (liquidity != 0) _observedModify(0, bytes32(0));
    }

    /// @dev Every candidate really settles from the same collected state. No production projection/comparator.
    function _placementBaseline() internal returns (Observation memory best) {
        _collectObserved();
        Observation memory start = _observe();
        best = start;
        (int24 lo, int24 hi) = _observedTicks();
        uint256 total0 = start.free[0] + start.principal[0];
        uint256 total1 = start.free[1] + start.principal[1];
        uint128 target = LiquidityAmounts.getLiquidityForAmounts(start.price,
            TickMath.getSqrtPriceAtTick(lo), TickMath.getSqrtPriceAtTick(hi),
            total0 - total0 * 0.2e18 / 1.2e18, total1 - total1 * 0.2e18 / 1.2e18);
        uint128[2] memory candidates = [target, target > start.liquidity ? target - 1 : target];
        for (uint256 i; i < (target > start.liquidity ? 2 : 1); ++i) {
            if (!_candidateFunded(start, candidates[i])) continue;
            uint256 checkpoint = vm.snapshotState();
            int256 delta = int256(uint256(candidates[i])) - int256(uint256(start.liquidity));
            if (delta != 0) _observedModify(delta, bytes32(0));
            Observation memory candidate = _observe();
            int256 comparison = Ref.compareMetric(_metric(candidate), _metric(best));
            if (comparison < 0 || (comparison == 0 && _distance(candidate.liquidity, start.liquidity)
                < _distance(best.liquidity, start.liquidity))) best = candidate;
            assertTrue(vm.revertToStateAndDelete(checkpoint));
        }
    }

    function _candidateFunded(Observation memory start, uint128 target) private view returns (bool) {
        uint256 change = _distance(start.liquidity, target);
        if (change > uint128(type(int128).max)) return false;
        if (target <= start.liquidity) return true;
        (int24 lo, int24 hi) = _observedTicks();
        IPoolManager pm = _observedManager();
        PoolKey memory k = _observedKey();
        (uint128 gross0,) = StateLibrary.getTickLiquidity(pm, k.toId(), lo);
        (uint128 gross1,) = StateLibrary.getTickLiquidity(pm, k.toId(), hi);
        uint256 capacity = Pool.tickSpacingToMaxLiquidityPerTick(k.tickSpacing);
        if (uint256(gross0) + change > capacity || uint256(gross1) + change > capacity) return false;
        return _additionCovered(start, uint128(change), lo, hi);
    }

    function _additionCovered(Observation memory start, uint128 change, int24 lo, int24 hi) private pure returns (bool) {
        uint160 a = TickMath.getSqrtPriceAtTick(lo);
        uint160 b = TickMath.getSqrtPriceAtTick(hi);
        uint256 debt0 = start.price >= b ? 0 : SqrtPriceMath.getAmount0Delta(start.price > a ? start.price : a, b, change, true);
        uint256 debt1 = start.price <= a ? 0 : SqrtPriceMath.getAmount1Delta(a, start.price < b ? start.price : b, change, true);
        return debt0 <= start.free[0] && debt1 <= start.free[1];
    }

    function _distance(uint128 a, uint128 b) private pure returns (uint256) { return a > b ? a - b : b - a; }

    function _runObserved() internal returns (Outcome memory result) {
        Observation memory start = _observe();
        uint256 root = vm.snapshotState();
        result.baseline = _placementBaseline();
        assertTrue(vm.revertToStateAndDelete(root));
        result.plan = _observedPlan(_plannerInput(start));
        assertTrue(result.plan.valid);
        _collectObserved();
        if (result.plan.fundingRemoval.liquidityDelta != 0)
            _observedModify(result.plan.fundingRemoval.liquidityDelta, bytes32(0));
        Observation memory beforeSwap = _observe();
        if (result.plan.fundingRemoval.liquidityDelta < 0) assertLt(beforeSwap.active, start.active);
        if (result.plan.swap.amountIn != 0) {
            uint256 input = result.plan.swap.zeroForOne ? 0 : 1;
            assertLe(result.plan.swap.amountIn, beforeSwap.free[input], "actual sleeve/removal funds swap");
            bytes memory feeMark = _observedFeeMark();
            BalanceDelta delta = _observedSwap(result.plan.swap.zeroForOne, result.plan.swap.amountIn);
            int128 spent = input == 0 ? delta.amount0() : delta.amount1();
            int128 received = input == 0 ? delta.amount1() : delta.amount0();
            assertEq(uint256(-int256(spent)), result.plan.swap.amountIn);
            assertEq(uint256(int256(received)), result.plan.swap.amountOut);
            _observedCheckFees(feeMark, result.plan.swap, delta);
        }
        _collectObserved();
        if (result.plan.placement.liquidityDelta != 0)
            _observedModify(result.plan.placement.liquidityDelta, bytes32(0));
        result.actual = _observe();
        assertEq(result.actual.fees[0], 0); assertEq(result.actual.fees[1], 0);
        assertTrue(Ref.priceWithin(start.price, result.actual.price, 25), "observed terminal price impact");
        assertEq(result.actual.free[0], result.plan.placement.afterState.book.free[0]);
        assertEq(result.actual.free[1], result.plan.placement.afterState.book.free[1]);
        assertEq(result.actual.principal[0], result.plan.placement.afterState.book.deployed[0]);
        assertEq(result.actual.principal[1], result.plan.placement.afterState.book.deployed[1]);
        assertEq(result.actual.liquidity, result.plan.placement.afterState.position.liquidity);
        assertEq(result.actual.price, result.plan.placement.afterState.position.sqrtPriceX96);
        assertEq(result.actual.tick, result.plan.placement.afterState.position.tick);
        assertEq(result.actual.active, result.plan.placement.afterState.position.activeLiquidity);
        assertEq(result.plan.placement.afterState.book.supply, 1_000e18, "maintenance preserves supplied share supply");
        int256 progress = Ref.compareMetric(_metric(result.actual), _metric(result.baseline));
        if (result.plan.swap.amountIn != 0) assertLt(progress, 0, "net terminal improvement versus placement only");
        else assertEq(progress, 0, "no trade equals independent placement baseline");
    }

    /// @dev Transfer surplus to a treasury; never allow initial mint inventory to subsidize execution.
    function _setObservedFree(uint256[2] memory wanted) internal {
        PoolKey memory k = _observedKey();
        IERC20[2] memory tokens = [IERC20(Currency.unwrap(k.currency0)), IERC20(Currency.unwrap(k.currency1))];
        for (uint256 i; i < 2; ++i) {
            uint256 held = tokens[i].balanceOf(address(this));
            assertGe(held, wanted[i], "fixture funding must precede trimming");
            if (held != wanted[i]) assertTrue(tokens[i].transfer(address(0xBEEF1234), held - wanted[i]));
        }
    }

    function _prepareObserved(uint256 direction, uint256 donation) internal {
        Observation memory o = _observe();
        uint256[2] memory free = [o.principal[0] / 5, o.principal[1] / 5];
        free[direction] += donation;
        _setObservedFree(free);
    }

    /// @notice Real-core net progress in each direction; no production metric determines the expected result.
    function test_observedMaintenance_usefulBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            _prepareObserved(direction, 10e18);
            Outcome memory result = _runObserved();
            assertGt(result.plan.swap.amountIn, 0, "useful repair witness");
            assertEq(result.plan.swap.zeroForOne, direction == 0);
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    /// @notice Large imbalance must exercise useful partial repair, not merely a feasible complete repair.
    function test_observedMaintenance_partialBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            _prepareObserved(direction, 1_000_000e18);
            Outcome memory result = _runObserved();
            assertGt(result.plan.swap.amountIn, 0, "partial repair must trade");
            assertFalse(Ref.passes(_metric(result.actual)), "fixed partial-progress witness");
            Outcome memory next = _runObserved();
            assertGt(next.plan.swap.amountIn, 0, "immediate second useful step");
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    /// @notice Fixed high-owned-liquidity seed must select a real funding removal in both directions.
    function test_observedMaintenance_fundingRemovalBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            // Frozen real-core witness: owned L=1M, external L=100k, local excess=1k.
            // Both H/P and both directions select full own-position release before the swap.
            _observedModify(-int256(uint256(900_000e18)), bytes32(uint256(1)));
            _observedModify(int256(uint256(999_000e18)), bytes32(0));
            _prepareObserved(direction, 1_000e18);
            Outcome memory result = _runObserved();
            assertEq(int256(result.plan.fundingRemoval.liquidityDelta), -int256(uint256(1_000_000e18)),
                "fixed full funding-removal witness");
            assertGt(result.plan.swap.amountIn, 0);
            assertEq(result.plan.swap.zeroForOne, direction == 0);
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    /// @notice Within-band books never trade; balanced excess is placed without a trade.
    function test_observedMaintenance_noTradeAndPlacementPreference() public {
        uint256 root = vm.snapshotState();
        _prepareObserved(0, 0);
        assertTrue(Ref.passes(_metric(_observe())), "fixture already inside both bands");
        Outcome memory unchanged = _runObserved();
        assertEq(unchanged.plan.swap.amountIn, 0);
        assertTrue(vm.revertToStateAndDelete(root));
        Observation memory o = _observe();
        // Extra inventory follows the actual full-range position proportions at tick 120.
        _setObservedFree([o.principal[0] / 4, o.principal[1] / 4]);
        Outcome memory placed = _runObserved();
        assertTrue(Ref.passes(_metric(placed.baseline)), "placement-only sufficient");
        assertEq(placed.plan.swap.amountIn, 0);
        assertGt(int256(placed.plan.placement.liquidityDelta), 0, "actual placement witness");
        assertEq(keccak256(abi.encode(placed.actual)), keccak256(abi.encode(placed.baseline)));
    }

    /// @notice Existing fees are collected once, using real core fee accrual before the root snapshot.
    function test_observedMaintenance_priorFeesBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            _observedSwap(direction == 0, 1e18);
            Observation memory accrued = _observe();
            if (_observedHasLpFee()) assertGt(accrued.fees[direction], 0, "real prior own LP fees");
            else { assertEq(accrued.fees[0], 0); assertEq(accrued.fees[1], 0); }
            _prepareObserved(direction, 10e18);
            Outcome memory result = _runObserved();
            assertGt(result.plan.swap.amountIn, 0);
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    /// @notice Adjacent attainable real-token books straddle 1 bp while the sleeve remains inside its band.
    /// @dev Test-side binary search constructs the fixture only; it never supplies an execution quote.
    function test_observedMaintenance_realThresholdNeighborsBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            Observation memory original = _observe();
            uint256[2] memory total = [original.principal[0] + original.principal[0] / 5,
                original.principal[1] + original.principal[1] / 5];
            uint256 inside = _lastPassingTotal(total, direction, original.price);
            uint256 root = vm.snapshotState();
            total[direction] = inside;
            _setObservedFree([total[0] - original.principal[0], total[1] - original.principal[1]]);
            assertTrue(Ref.passes(_metric(_observe())), "natural inclusive threshold neighbor");
            Outcome memory passing = _runObserved();
            assertEq(passing.plan.swap.amountIn, 0, "inside both bands never trades");
            assertTrue(vm.revertToStateAndDelete(root));

            root = vm.snapshotState();
            total[direction] = inside + 1;
            _setObservedFree([total[0] - original.principal[0], total[1] - original.principal[1]]);
            Ref.Metric memory outside = _metric(_observe());
            assertGt(outside.composition.numerator.length, 0, "one raw unit outside composition bound");
            assertEq(outside.sleeve.numerator.length, 0, "not a sleeve-deadband test");
            _runObserved(); // A truthful placement-only/deferred result is allowed by product law.
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    function _lastPassingTotal(uint256[2] memory total, uint256 direction, uint160 price)
        private view returns (uint256 low)
    {
        (int24 lo, int24 hi) = _observedTicks();
        uint160 a = TickMath.getSqrtPriceAtTick(lo);
        uint160 b = TickMath.getSqrtPriceAtTick(hi);
        assertEq(Ref.composition(total, price, a, b).numerator.length, 0, "balanced search endpoint");
        low = total[direction];
        uint256 high = low * 2;
        total[direction] = high;
        assertGt(Ref.composition(total, price, a, b).numerator.length, 0, "outside search endpoint");
        for (uint256 i; i < 256 && high - low > 1; ++i) {
            uint256 mid = low + (high - low) / 2;
            total[direction] = mid;
            if (Ref.composition(total, price, a, b).numerator.length == 0) low = mid;
            else high = mid;
        }
        assertEq(high - low, 1, "actual adjacent integer endpoints");
    }

    /// @notice Independent wide reference self-controls: carries, cross products, exact inclusive threshold.
    function test_observedMaintenance_referenceArithmeticControls() public pure {
        Ref.Big memory maximum = Ref.number(type(uint256).max);
        Ref.Big memory square = Ref.multiply(maximum, maximum);
        assertEq(square.length, 16);
        assertEq(square.digit[0], 1);
        for (uint256 i = 1; i < 8; ++i) assertEq(square.digit[i], 0);
        assertEq(square.digit[8], type(uint32).max - 1);
        for (uint256 i = 9; i < 16; ++i) assertEq(square.digit[i], type(uint32).max);
        Ref.Big memory power = Ref.multiply(Ref.number(uint256(1) << 255), Ref.number(2));
        assertEq(Ref.compare(Ref.subtract(power, Ref.number(1)), maximum), 0);
        assertEq(Ref.compareFraction(Ref.fraction(2, 3), Ref.fraction(4, 6)), 0);
        assertLt(Ref.compareFraction(Ref.fraction(2, 3), Ref.fraction(3, 4)), 0);
        uint160 q = uint160(1) << 96;
        assertEq(Ref.composition([uint256(9_999), uint256(10_000)], q, q / 2, q * 2).numerator.length, 0);
        assertGt(Ref.composition([uint256(9_999), uint256(10_001)], q, q / 2, q * 2).numerator.length, 0);
    }
}
// end::TestBase_FullSpreadMaintenanceObservation[]

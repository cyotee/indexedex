// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {FullSpreadMaintenanceReferenceMath as Ref} from "contracts/test/utils/FullSpreadMaintenanceReferenceMath.sol";

interface IRegistryMaintenanceSubject {
    function rebalanceLiquidReserve() external;
    function targetLiquidReservePercentage() external view returns (uint256);
}

/// @notice Public proxy confirmation using only actual custody, core state and independent terminal comparisons.
/// @dev The no-trade counterfactual is predictive core signed-delta arithmetic here. Actual replay is covered
/// separately by TestBase_FullSpreadMaintenanceObservation; no proxy impersonation/test-only selector is used.
// tag::TestBase_FullSpreadRegistryMaintenanceObservation[]
abstract contract TestBase_FullSpreadRegistryMaintenanceObservation is Test {
    using PoolIdLibrary for PoolKey;

    struct Book {
        uint160 q;
        uint128 liquidity;
        uint256[2] free;
        uint256[2] principal;
        uint256[2] earned;
        uint256 sleeve;
    }
    struct Result { Book beforeBook; Book baseline; Book afterBook; uint256 swaps; }

    function _registrySubject() internal view virtual returns (address);
    function _registryManager() internal view virtual returns (IPoolManager);
    function _registryKey() internal view virtual returns (PoolKey memory);
    function _registryPermit2() internal view virtual returns (address);
    function _registryExtraAllowances() internal view virtual {}

    function _registryTokens() internal view returns (IERC20[2] memory tokens) {
        PoolKey memory key = _registryKey();
        // These bounded confirmation fixtures use ERC20/WETH pool faces, not native currency.
        tokens = [IERC20(Currency.unwrap(key.currency0)), IERC20(Currency.unwrap(key.currency1))];
        assertTrue(address(tokens[0]) != address(0) && address(tokens[1]) != address(0));
    }

    function _registryBounds() internal view returns (int24 lo, int24 hi) {
        int24 spacing = _registryKey().tickSpacing;
        return (TickMath.minUsableTick(spacing), TickMath.maxUsableTick(spacing));
    }

    function _registryPrincipal(uint160 q, uint128 liquidity, bool roundUp)
        internal view returns (uint256[2] memory amounts)
    {
        (int24 lo, int24 hi) = _registryBounds();
        uint160 a = TickMath.getSqrtPriceAtTick(lo);
        uint160 b = TickMath.getSqrtPriceAtTick(hi);
        if (q < b) amounts[0] = SqrtPriceMath.getAmount0Delta(q > a ? q : a, b, liquidity, roundUp);
        if (q > a) amounts[1] = SqrtPriceMath.getAmount1Delta(a, q < b ? q : b, liquidity, roundUp);
    }

    function _registryObserve() internal view returns (Book memory book) {
        PoolKey memory key = _registryKey();
        IPoolManager manager = _registryManager();
        IERC20[2] memory tokens = _registryTokens();
        address subject = _registrySubject();
        book.free = [tokens[0].balanceOf(subject), tokens[1].balanceOf(subject)];
        (book.q,,,) = StateLibrary.getSlot0(manager, key.toId());
        (int24 lo, int24 hi) = _registryBounds();
        uint256 last0; uint256 last1;
        (book.liquidity, last0, last1) = StateLibrary.getPositionInfo(manager, key.toId(), subject, lo, hi, bytes32(0));
        book.principal = _registryPrincipal(book.q, book.liquidity, false);
        if (book.liquidity != 0) {
            (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(manager, key.toId(), lo, hi);
            unchecked { growth0 -= last0; growth1 -= last1; }
            book.earned = [FullMath.mulDiv(growth0, book.liquidity, uint256(1) << 128),
                FullMath.mulDiv(growth1, book.liquidity, uint256(1) << 128)];
        }
        book.sleeve = IRegistryMaintenanceSubject(subject).targetLiquidReservePercentage();
    }

    function _registryMetric(Book memory book) internal view returns (Ref.Metric memory) {
        (int24 lo, int24 hi) = _registryBounds();
        return Ref.metric(book.free, book.principal, book.q, TickMath.getSqrtPriceAtTick(lo),
            TickMath.getSqrtPriceAtTick(hi), book.sleeve, [uint256(1e12), uint256(1e12)]);
    }

    function _registryPlacementBaseline(Book memory beforeBook) internal view returns (Book memory best) {
        Book memory collected = abi.decode(abi.encode(beforeBook), (Book));
        for (uint256 i; i < 2; ++i) { collected.free[i] += collected.earned[i]; collected.earned[i] = 0; }
        best = collected;
        uint128 target = _registryTarget(collected);
        for (uint256 i; i < (target > collected.liquidity ? 2 : 1); ++i) {
            (bool funded, Book memory candidate) = _registryPlacement(collected, target - uint128(i));
            if (!funded) continue;
            int256 comparison = Ref.compareMetric(_registryMetric(candidate), _registryMetric(best));
            if (comparison < 0 || (comparison == 0 && _registryDistance(candidate.liquidity, collected.liquidity)
                < _registryDistance(best.liquidity, collected.liquidity))) best = candidate;
        }
    }

    function _registryTarget(Book memory book) private view returns (uint128) {
        (int24 lo, int24 hi) = _registryBounds();
        uint256[2] memory budget;
        for (uint256 i; i < 2; ++i) {
            uint256 total = book.free[i] + book.principal[i];
            budget[i] = total - FullMath.mulDiv(total, book.sleeve, 1e18 + book.sleeve);
        }
        return LiquidityAmounts.getLiquidityForAmounts(book.q, TickMath.getSqrtPriceAtTick(lo),
            TickMath.getSqrtPriceAtTick(hi), budget[0], budget[1]);
    }

    function _registryPlacement(Book memory book, uint128 target) private view returns (bool, Book memory candidate) {
        candidate = abi.decode(abi.encode(book), (Book));
        uint256 change = _registryDistance(target, book.liquidity);
        if (change > uint128(type(int128).max)) return (false, candidate);
        bool adding = target > book.liquidity;
        if (adding && !_registryCapacity(uint128(change))) return (false, candidate);
        uint256[2] memory settlement = _registryPrincipal(book.q, uint128(change), adding);
        for (uint256 i; i < 2; ++i) {
            if (adding) {
                if (settlement[i] > candidate.free[i]) return (false, candidate);
                candidate.free[i] -= settlement[i];
            } else candidate.free[i] += settlement[i];
        }
        candidate.liquidity = target;
        candidate.principal = _registryPrincipal(book.q, target, false);
        return (true, candidate);
    }

    function _registryCapacity(uint128 increase) private view returns (bool) {
        (int24 lo, int24 hi) = _registryBounds();
        PoolKey memory key = _registryKey();
        (uint128 g0,) = StateLibrary.getTickLiquidity(_registryManager(), key.toId(), lo);
        (uint128 g1,) = StateLibrary.getTickLiquidity(_registryManager(), key.toId(), hi);
        uint256 cap = Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing);
        return uint256(g0) + increase <= cap && uint256(g1) + increase <= cap;
    }

    function _registryDistance(uint128 a, uint128 b) private pure returns (uint256) { return a > b ? a - b : b - a; }

    function _registryAssertCustody() internal view {
        address subject = _registrySubject();
        IERC20[2] memory tokens = _registryTokens();
        for (uint256 i; i < 2; ++i) {
            assertEq(IBasicVault(subject).reserveOfToken(address(tokens[i])), tokens[i].balanceOf(subject));
            assertEq(tokens[i].allowance(address(this), subject), 0, "public repair has no caller funding approval");
            assertEq(tokens[i].allowance(subject, address(this)), 0);
            assertEq(tokens[i].allowance(subject, address(_registryManager())), 0);
            assertEq(tokens[i].allowance(subject, _registryPermit2()), type(uint256).max, "preserve configured Permit2 approval");
        }
        assertEq(IBasicVault(subject).reserveOfToken(subject), IERC20(subject).balanceOf(subject));
        assertEq(subject.balance, 0);
        _registryExtraAllowances();
    }

    function _registryRun() internal returns (Result memory result) {
        address subject = _registrySubject();
        IERC20[2] memory tokens = _registryTokens();
        uint256[2] memory caller = [tokens[0].balanceOf(address(this)), tokens[1].balanceOf(address(this))];
        uint256 supply = IERC20(subject).totalSupply();
        uint256 shares = IERC20(subject).balanceOf(address(this));
        result.beforeBook = _registryObserve();
        result.baseline = _registryPlacementBaseline(result.beforeBook);
        vm.recordLogs();
        IRegistryMaintenanceSubject(subject).rebalanceLiquidReserve();
        result.swaps = _registryCountSwaps(vm.getRecordedLogs());
        result.afterBook = _registryObserve();
        assertLe(result.swaps, 1, "at most one actual holder swap");
        assertEq(result.afterBook.earned[0], 0); assertEq(result.afterBook.earned[1], 0);
        assertEq(IERC20(subject).totalSupply(), supply); assertEq(IERC20(subject).balanceOf(address(this)), shares);
        assertEq(tokens[0].balanceOf(address(this)), caller[0]); assertEq(tokens[1].balanceOf(address(this)), caller[1]);
        assertTrue(Ref.priceWithin(result.beforeBook.q, result.afterBook.q, 25));
        int256 progress = Ref.compareMetric(_registryMetric(result.afterBook), _registryMetric(result.baseline));
        if (result.swaps != 0) assertLt(progress, 0, "public net terminal progress versus independent predictive placement");
        else {
            assertEq(progress, 0);
            assertEq(keccak256(abi.encode(result.afterBook)), keccak256(abi.encode(result.baseline)), "actual no-trade placement book");
        }
        _registryAssertCustody();
    }

    function _registryCountSwaps(Vm.Log[] memory logs) private view returns (uint256 count) {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(_registryManager()) && logs[i].topics.length > 1
                && logs[i].topics[0] == IPoolManager.Swap.selector && logs[i].topics[1] == PoolId.unwrap(_registryKey().toId())) ++count;
        }
    }

    function _registryDonate(uint256 direction, uint256 amount) internal {
        IERC20 token = _registryTokens()[direction];
        assertGe(token.balanceOf(address(this)), amount, "real fixture donation funding");
        assertTrue(token.transfer(_registrySubject(), amount));
    }

    /// @notice Public repair improves independently measured terminal book in each direction.
    function test_registryMaintenance_usefulBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            Book memory book = _registryObserve();
            _registryDonate(direction, (book.free[direction] + book.principal[direction]) / 100);
            Result memory result = _registryRun();
            assertEq(result.swaps, 1, "real useful swap witness");
            if (direction == 0) assertLt(result.afterBook.q, result.beforeBook.q);
            else assertGt(result.afterBook.q, result.beforeBook.q);
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    /// @notice Public repair makes useful partial progress and permits another useful step immediately.
    function test_registryMaintenance_partialBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            Book memory book = _registryObserve();
            uint128 active = StateLibrary.getLiquidity(_registryManager(), _registryKey().toId());
            uint256[2] memory poolAmounts = _registryPrincipal(book.q, active, false);
            _registryDonate(direction, poolAmounts[direction] / 10);
            Result memory first = _registryRun();
            assertEq(first.swaps, 1);
            assertFalse(Ref.passes(_registryMetric(first.afterBook)), "partial progress remains outside bands");
            Result memory second = _registryRun();
            assertEq(second.swaps, 1, "immediate second useful step");
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }

    /// @notice No trades, supply changes or caller rewards when independently measured bands already pass.
    function test_registryMaintenance_withinBandsNoTrade() public {
        assertTrue(Ref.passes(_registryMetric(_registryObserve())), "real initial book inside both bands");
        for (uint256 i; i < 3; ++i) {
            Result memory result = _registryRun();
            assertEq(result.swaps, 0);
            assertEq(result.afterBook.q, result.beforeBook.q);
            assertTrue(Ref.passes(_registryMetric(result.afterBook)));
        }
    }
}
// end::TestBase_FullSpreadRegistryMaintenanceObservation[]

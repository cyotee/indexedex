// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValueTest as PoolFixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValue.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultHarvest as Harvest} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultHarvestTest[]
/// @notice Compare the shared planner's projected cash and position book with real manager operations.
contract UniswapV4UpperLowerWingsStandardExchangeVaultHarvestTest is PoolFixture {
    using StateLibrary for IPoolManager;
    function testFuzz_placementParityBothTargets(uint64 amount0_, uint64 amount1_, bool target0_) public {
        Harvest.Portfolio memory book = _empty(target0_);
        book.local0 = bound(amount0_, 1, 1e18);
        book.local1 = bound(amount1_, 1, 1e18);
        token0.mint(address(portfolio), book.local0);
        token1.mint(address(portfolio), book.local1);
        Harvest.Plan memory plan = Harvest.placement(book);
        _executeAndCheck(plan);
        assertGe(target0_ ? plan.portfolio.local0 : plan.portfolio.local1, 1);
    }
    function test_harvestConvertedWingAndReopenParity() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 snapshot = vm.snapshotState();
            Harvest.Portfolio memory book = _empty(direction == 0);
            book.local0 = direction == 0 ? 1e12 : 0; book.local1 = direction == 0 ? 0 : 1e12;
            token0.mint(address(portfolio), book.local0);
            token1.mint(address(portfolio), book.local1);
            Harvest.Plan memory initial = Harvest.placement(book);
            _executeAndCheck(initial);
            trader.swapTo(key, direction == 1, 1e15, TickMath.getSqrtPriceAtTick(direction == 0 ? int24(120) : int24(-120)));
            book = _refresh(initial.portfolio);
            Harvest.Plan memory harvested = Harvest.harvest(book);
            assertGt(harvested.count, 0);
            assertEq(uint256(harvested.operations[0].slot), direction == 0 ? 1 : 2);
            assertLt(harvested.operations[0].quantity, 0);
            _executeAndCheck(harvested);
            Harvest.Plan memory repeated = Harvest.harvest(harvested.portfolio);
            assertEq(repeated.count, 0, "no repeated harvest without new conversion");
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function test_feesAloneDoNotTriggerWingHarvest() public pure {
        Harvest.Portfolio memory book;
        book.price = uint160(1) << 96; book.spacing = 60; book.supply = 1; book.target0 = true;
        book.positions[1] = Harvest.Position(60, 887220, 1e9, 123, 456, 0, 0);
        Harvest.Plan memory plan = Harvest.harvest(book);
        assertEq(plan.count, 0);
        assertEq(plan.portfolio.positions[1].fee1, 456);
    }
    function test_oneUnitDepositRetainsFloorWithEmptyCore() public pure {
        Harvest.Portfolio memory book;
        book.price = uint160(1) << 96; book.spacing = 60; book.supply = 1; book.target0 = true; book.local0 = 1;
        Harvest.Plan memory plan = Harvest.placement(book);
        assertEq(plan.count, 0); assertEq(plan.portfolio.local0, 1);
    }
    function _empty(bool target0_) internal view returns (Harvest.Portfolio memory book_) {
        book_.price = uint160(1) << 96; book_.spacing = 60; book_.supply = 1e12;
        book_.sleevePercentage = 0.2e18; book_.target0 = target0_;
        Harvest.loadCapacities(book_, manager, key.toId());
    }
    function _refresh(Harvest.Portfolio memory book_) internal view returns (Harvest.Portfolio memory) {
        (book_.price, book_.tick,,) = manager.getSlot0(key.toId());
        for (uint256 i; i < 3; ++i) {
            Harvest.Position memory position = book_.positions[i];
            if (position.liquidity == 0) continue;
            (uint128 liquidity, uint256 last0, uint256 last1) = manager.getPositionInfo(
                key.toId(), address(portfolio), position.lower, position.upper, bytes32(i));
            (uint256 growth0, uint256 growth1) = manager.getFeeGrowthInside(key.toId(), position.lower, position.upper);
            book_.positions[i].fee0 = Inventory.earnedFee(liquidity, growth0, last0);
            book_.positions[i].fee1 = Inventory.earnedFee(liquidity, growth1, last1);
        }
        Harvest.loadCapacities(book_, manager, key.toId());
        return book_;
    }
    function _executeAndCheck(Harvest.Plan memory plan_) internal {
        for (uint256 i; i < plan_.operations.length; ++i) {
            Common.Operation memory operation = plan_.operations[i];
            assertEq(uint256(operation.kind), uint256(Common.Kind.Modify), "no balancing swap");
            portfolio.modify(key, operation.lower, operation.upper, operation.quantity, bytes32(uint256(operation.slot)));
        }
        assertEq(token0.balanceOf(address(portfolio)), plan_.portfolio.local0, "cash0");
        assertEq(token1.balanceOf(address(portfolio)), plan_.portfolio.local1, "cash1");
        for (uint256 i; i < 3; ++i) {
            Harvest.Position memory position = plan_.portfolio.positions[i];
            if (position.liquidity == 0) continue;
            (uint128 liquidity,,) = manager.getPositionInfo(key.toId(), address(portfolio), position.lower, position.upper, bytes32(i));
            assertEq(liquidity, position.liquidity, "position liquidity");
        }
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultHarvestTest[]

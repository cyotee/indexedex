// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultGeometry as Geometry} from "./UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultHarvest[]
/// @notice Shared arithmetic for execution and previews: close converted wings, pair local inventory, place residuals.
/// @dev Ordinary harvest never swaps. The plan contains exact manager mutations and a projected portfolio.
library UniswapV4UpperLowerWingsStandardExchangeVaultHarvest {
    using StateLibrary for IPoolManager;
    struct Position { int24 lower; int24 upper; uint128 liquidity; uint256 fee0; uint256 fee1; uint256 growth0; uint256 growth1; }
    struct Capacity { int24 tick; uint128 gross; }
    struct Portfolio {
        uint160 price;
        int24 tick;
        int24 spacing;
        bool target0;
        uint256 supply;
        uint256 local0;
        uint256 local1;
        uint256 sleevePercentage;
        Position[3] positions;
        Capacity[6] capacities;
        uint8 capacityCount;
        uint128 maxLiquidityPerTick;
    }
    struct Plan { Portfolio portfolio; Common.Operation[] operations; uint256 count; }
    error InvalidPlacement();

    function snapshot() public view returns (Portfolio memory book_) {
        Repo.Storage storage state = Repo._layout();
        (book_.price, book_.tick,,) = state.manager.getSlot0(state.key.toId());
        book_.spacing = state.key.tickSpacing;
        book_.target0 = state.target0;
        book_.supply = ERC20Repo._totalSupply();
        book_.local0 = state.local0;
        book_.local1 = state.local1;
        book_.sleevePercentage = state.oracle.liquidReservePercentageOfVault(address(this));
        for (uint256 i; i < 3; ++i) {
            Repo.Position storage position = state.positions[i];
            if (position.liquidity == 0) continue;
            (uint128 liquidity, uint256 last0, uint256 last1) = state.manager.getPositionInfo(
                state.key.toId(), address(this), position.lower, position.upper, Repo.salt(i));
            (uint256 growth0, uint256 growth1) = state.manager.getFeeGrowthInside(state.key.toId(), position.lower, position.upper);
            book_.positions[i] = Position(position.lower, position.upper, liquidity,
                Inventory.earnedFee(liquidity, growth0, last0), Inventory.earnedFee(liquidity, growth1, last1), 0, 0);
            unchecked {
                book_.positions[i].growth0 = growth0 - last0;
                book_.positions[i].growth1 = growth1 - last1;
            }
        }
        loadCapacities(book_, state.manager, state.key.toId());
    }
    /// @notice Cache all current and prospective boundaries; subsequent projected mutations update their gross liquidity.
    function loadCapacities(Portfolio memory book_, IPoolManager manager_, PoolId pool_) internal view {
        book_.capacityCount = 0;
        book_.maxLiquidityPerTick = Pool.tickSpacingToMaxLiquidityPerTick(book_.spacing);
        Types.Geometry memory geometry = Geometry.ranges(book_.price, book_.spacing);
        _loadRange(book_, manager_, pool_, geometry.core);
        _loadRange(book_, manager_, pool_, geometry.upper);
        _loadRange(book_, manager_, pool_, geometry.lower);
        for (uint256 i; i < 3; ++i) {
            Position memory position = book_.positions[i];
            if (position.liquidity != 0) _loadRange(book_, manager_, pool_, Types.Range(position.lower, position.upper, true));
        }
    }
    function _loadRange(Portfolio memory book_, IPoolManager manager_, PoolId pool_, Types.Range memory range_) private view {
        if (!range_.available) return;
        _loadTick(book_, manager_, pool_, range_.lower);
        _loadTick(book_, manager_, pool_, range_.upper);
    }
    function _loadTick(Portfolio memory book_, IPoolManager manager_, PoolId pool_, int24 tick_) private view {
        for (uint256 i; i < book_.capacityCount; ++i) if (book_.capacities[i].tick == tick_) return;
        (uint128 gross,) = manager_.getTickLiquidity(pool_, tick_);
        book_.capacities[book_.capacityCount++] = Capacity(tick_, gross);
    }
    function _capacityIndex(Portfolio memory book_, int24 tick_) private pure returns (uint256) {
        for (uint256 i; i < book_.capacityCount; ++i) if (book_.capacities[i].tick == tick_) return i;
        revert InvalidPlacement();
    }
    function _capacityRoom(Portfolio memory book_, Types.Range memory range_) private pure returns (uint128) {
        uint128 lower = book_.maxLiquidityPerTick - book_.capacities[_capacityIndex(book_, range_.lower)].gross;
        uint128 upper = book_.maxLiquidityPerTick - book_.capacities[_capacityIndex(book_, range_.upper)].gross;
        return lower < upper ? lower : upper;
    }
    function _changeCapacity(Portfolio memory book_, int24 lower_, int24 upper_, uint128 liquidity_, bool add_) private pure {
        uint256 lower = _capacityIndex(book_, lower_);
        uint256 upper = _capacityIndex(book_, upper_);
        if (add_) {
            book_.capacities[lower].gross += liquidity_;
            book_.capacities[upper].gross += liquidity_;
        } else {
            book_.capacities[lower].gross -= liquidity_;
            book_.capacities[upper].gross -= liquidity_;
        }
    }
    function totalInventory(Portfolio memory book_) public pure returns (uint256 amount0_, uint256 amount1_) {
        amount0_ = book_.local0; amount1_ = book_.local1;
        for (uint256 i; i < 3; ++i) {
            Position memory position = book_.positions[i];
            if (position.liquidity == 0) continue;
            Types.Principal memory principal = Inventory.principal(book_.price, position.lower, position.upper, position.liquidity, false);
            amount0_ += principal.amount0 + position.fee0;
            amount1_ += principal.amount1 + position.fee1;
        }
    }
    function harvest(Portfolio memory book_) public pure returns (Plan memory plan_) {
        plan_.portfolio = book_;
        plan_.operations = new Common.Operation[](8);
        for (uint256 i = 1; i < 3; ++i) {
            Position memory position = book_.positions[i];
            if (position.liquidity == 0) continue;
            Types.Principal memory principal = Inventory.principal(book_.price, position.lower, position.upper, position.liquidity, false);
            if (Inventory.harvestEligible(Types.Slot(i), principal)) close(plan_, uint8(i));
        }
        if (plan_.count != 0) place(plan_);
        _trim(plan_);
    }
    function placement(Portfolio memory book_) public pure returns (Plan memory plan_) {
        plan_.portfolio = book_;
        plan_.operations = new Common.Operation[](8);
        place(plan_);
        _trim(plan_);
    }
    function close(Plan memory plan_, uint8 slot_) internal pure {
        Position memory position = plan_.portfolio.positions[slot_];
        if (position.liquidity == 0) return;
        Types.Principal memory principal = Inventory.principal(plan_.portfolio.price, position.lower, position.upper, position.liquidity, false);
        plan_.portfolio.local0 += principal.amount0 + position.fee0;
        plan_.portfolio.local1 += principal.amount1 + position.fee1;
        plan_.operations[plan_.count++] = Common.Operation(Common.Kind.Modify, slot_, position.lower, position.upper,
            -int256(uint256(position.liquidity)), false, 0);
        _changeCapacity(plan_.portfolio, position.lower, position.upper, position.liquidity, false);
        delete plan_.portfolio.positions[slot_];
    }
    function place(Plan memory plan_) internal pure {
        Portfolio memory book = plan_.portfolio;
        if (book.sleevePercentage > 1e18) revert InvalidPlacement();
        Types.Geometry memory geometry = Geometry.ranges(book.price, book.spacing);
        uint256 floor = liquidFloor(book);
        _add(plan_, 0, geometry.core, floor);
        // Existing unconverted wings retain their ranges until closed; never orphan old position fees.
        _add(plan_, 1, geometry.upper, floor);
        _add(plan_, 2, geometry.lower, floor);
    }
    function liquidFloor(Portfolio memory book_) internal pure returns (uint256 floor_) {
        uint256 target = book_.target0 ? book_.local0 : book_.local1;
        for (uint256 i; i < 3; ++i) {
            Position memory position = book_.positions[i];
            if (position.liquidity == 0) continue;
            Types.Principal memory principal = Inventory.principal(book_.price, position.lower, position.upper, position.liquidity, false);
            target += book_.target0 ? principal.amount0 : principal.amount1;
        }
        floor_ = FullMath.mulDiv(target, book_.sleevePercentage, 1e18 + book_.sleevePercentage);
        if (book_.supply != 0 && floor_ == 0) floor_ = 1;
    }
    function _add(Plan memory plan_, uint8 slot_, Types.Range memory range_, uint256 floor_) private pure {
        Portfolio memory book = plan_.portfolio;
        Position memory position = book.positions[slot_];
        if (position.liquidity != 0) {
            range_ = Types.Range(position.lower, position.upper, true);
            if (slot_ != 0 && Inventory.harvestEligible(Types.Slot(slot_),
                Inventory.principal(book.price, position.lower, position.upper, position.liquidity, false))) return;
        }
        if (!range_.available) return;
        uint256 available0 = book.local0;
        uint256 available1 = book.local1;
        if (book.target0) available0 = available0 > floor_ ? available0 - floor_ : 0;
        else available1 = available1 > floor_ ? available1 - floor_ : 0;
        if (available0 == 0 && available1 == 0) return;
        uint128 liquidity = _affordableLiquidity(book, range_, available0, available1);
        if (liquidity == 0) return;
        if (uint256(position.liquidity) + liquidity > uint256(uint128(type(int128).max))) revert InvalidPlacement();
        Types.Principal memory cost = Inventory.principal(book.price, range_.lower, range_.upper, liquidity, true);
        if (cost.amount0 > available0 || cost.amount1 > available1) revert InvalidPlacement();
        book.local0 = book.local0 - cost.amount0 + position.fee0;
        book.local1 = book.local1 - cost.amount1 + position.fee1;
        book.positions[slot_] = Position(range_.lower, range_.upper, position.liquidity + liquidity, 0, 0, 0, 0);
        _changeCapacity(book, range_.lower, range_.upper, liquidity, true);
        plan_.operations[plan_.count++] = Common.Operation(Common.Kind.Modify, slot_, range_.lower, range_.upper,
            int256(uint256(liquidity)), false, 0);
    }
    function _affordableLiquidity(Portfolio memory book_, Types.Range memory range_, uint256 available0_, uint256 available1_)
        private pure returns (uint128 liquidity_)
    {
        uint128 room = _capacityRoom(book_, range_);
        if (room == 0) return 0;
        Types.Principal memory maximum = Inventory.principal(book_.price, range_.lower, range_.upper, room, true);
        uint256 signedMaximum = uint256(uint128(type(int128).max));
        if (available0_ > signedMaximum) available0_ = signedMaximum;
        if (available1_ > signedMaximum) available1_ = signedMaximum;
        uint160 lower = TickMath.getSqrtPriceAtTick(range_.lower);
        uint160 upper = TickMath.getSqrtPriceAtTick(range_.upper);
        if (book_.price <= lower) return _liquidity0(lower, upper, available0_, maximum.amount0, room);
        if (book_.price >= upper) return _liquidity1(lower, upper, available1_, maximum.amount1, room);
        uint128 liquidity0 = _liquidity0(book_.price, upper, available0_, maximum.amount0, room);
        uint128 liquidity1 = _liquidity1(lower, book_.price, available1_, maximum.amount1, room);
        return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    }
    function _liquidity0(uint160 lower_, uint160 upper_, uint256 available_, uint256 maximum_, uint128 room_)
        private pure returns (uint128)
    {
        return available_ >= maximum_ ? room_ : LiquidityAmounts.getLiquidityForAmount0(lower_, upper_, available_);
    }
    function _liquidity1(uint160 lower_, uint160 upper_, uint256 available_, uint256 maximum_, uint128 room_)
        private pure returns (uint128)
    {
        return available_ >= maximum_ ? room_ : LiquidityAmounts.getLiquidityForAmount1(lower_, upper_, available_);
    }

    function _trim(Plan memory plan_) private pure {
        Common.Operation[] memory operations = plan_.operations;
        uint256 count = plan_.count;
        assembly ("memory-safe") { mstore(operations, count) }
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultHarvest[]

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuoteTest as QuoteFixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultProjectionPoolTest[]
/// @notice Independent actual swaps verify carried pool state, overlaid positions and full fee growth across successive projections.
contract UniswapV4UpperLowerWingsStandardExchangeVaultProjectionPoolTest is QuoteFixture {
    using StateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;
    function testFuzz_successiveProjectedSwapsPreservePoolAndOwnedFeeGrowth(uint32 firstSeed_, uint32 secondSeed_, bool zeroForOne_) public {
        Quote.Request memory source = _request(true);
        _add(source, -887220, 887220, 1e8, bytes32(uint256(1)));
        _add(source, 60, 887220, 2e8, bytes32(uint256(2)));
        _add(source, -887220, -60, 3e8, bytes32(uint256(3)));
        externalLp.modify(key, -887220, 887220, 4e8, bytes32(0));
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, uint24(1000 | (500 << 12)));
        Quote.HeldPosition[3] memory held = _held(source);
        uint256 firstAmount = bound(firstSeed_, 1, 1e9);
        uint256 secondAmount = bound(secondSeed_, 1, 1e9);
        Quote.SwapProjection memory first = Quote.projectSwap(source, Quote.startingPool(source), held, zeroForOne_, firstAmount);
        Quote.SwapProjection memory second = Quote.projectSwap(source, first.pool, first.positions, !zeroForOne_, secondAmount);
        _executeSwapAndCheck(first, zeroForOne_, firstAmount);
        _executeSwapAndCheck(second, !zeroForOne_, secondAmount);
        for (uint256 i; i < 3; ++i) {
            Quote.Position memory position = source.positions[i];
            (, uint256 last0, uint256 last1) = manager.getPositionInfo(key.toId(), address(portfolio), position.lower, position.upper, position.salt);
            (uint256 growth0, uint256 growth1) = manager.getFeeGrowthInside(key.toId(), position.lower, position.upper);
            unchecked { assertEq(second.positions[i].growth0, growth0 - last0); assertEq(second.positions[i].growth1, growth1 - last1); }
        }
    }
    function test_projectionReplacesOwnedRangeAndSetsNewBitmapBits() public {
        Quote.Request memory source = _request(true);
        _add(source, -887220, 887220, 1e8, bytes32(uint256(1)));
        _add(source, 60, 887220, 2e8, bytes32(uint256(2)));
        externalLp.modify(key, -887220, 887220, 4e8, bytes32(0));
        Quote.HeldPosition[3] memory held = _held(source);
        held[1] = Quote.HeldPosition(120, 240, 2e8, 0, 0);
        Quote.SwapProjection memory projected = Quote.projectSwap(source, Quote.startingPool(source), held, false, 1e8);
        portfolio.modify(key, 60, 887220, -int256(2e8), bytes32(uint256(2)));
        token0.mint(address(portfolio), 1e20); token1.mint(address(portfolio), 1e20);
        portfolio.modify(key, 120, 240, 2e8, bytes32(uint256(2)));
        _executeSwapAndCheck(projected, false, 1e8);
        (, uint256 last0, uint256 last1) = manager.getPositionInfo(key.toId(), address(portfolio), 120, 240, bytes32(uint256(2)));
        (uint256 growth0, uint256 growth1) = manager.getFeeGrowthInside(key.toId(), 120, 240);
        unchecked { assertEq(projected.positions[1].growth0, growth0 - last0); assertEq(projected.positions[1].growth1, growth1 - last1); }
    }
    function _held(Quote.Request memory source_) private view returns (Quote.HeldPosition[3] memory held_) {
        for (uint256 i; i < source_.count; ++i) {
            Quote.Position memory position = source_.positions[i];
            (uint128 liquidity, uint256 last0, uint256 last1) = manager.getPositionInfo(key.toId(), address(portfolio), position.lower, position.upper, position.salt);
            (uint256 growth0, uint256 growth1) = manager.getFeeGrowthInside(key.toId(), position.lower, position.upper);
            unchecked { held_[i] = Quote.HeldPosition(position.lower, position.upper, liquidity, growth0 - last0, growth1 - last1); }
        }
    }
    function _executeSwapAndCheck(Quote.SwapProjection memory projected_, bool zeroForOne_, uint256 amount_) private {
        BalanceDelta actual = trader.swap(key, zeroForOne_, amount_);
        assertEq(projected_.sale.sold, uint256(-int256(zeroForOne_ ? actual.amount0() : actual.amount1())));
        assertEq(projected_.sale.proceeds, uint256(uint128(zeroForOne_ ? actual.amount1() : actual.amount0())));
        (uint160 price, int24 tick,,) = manager.getSlot0(key.toId());
        assertEq(projected_.sale.sqrtPriceX96, price); assertEq(projected_.sale.tick, tick);
        assertEq(projected_.sale.liquidity, manager.getLiquidity(key.toId()));
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultProjectionPoolTest[]

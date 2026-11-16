// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValueTest as PoolFixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValue.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuoteTest[]
/// @notice Byte-for-byte native amount and final pool-state parity against actual removal and PoolManager swap.
contract UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuoteTest is PoolFixture {
    using StateLibrary for IPoolManager;

    function quote(Quote.Request memory request_) external view returns (Quote.Result memory) {
        return Quote.quote(request_);
    }

    function testFuzz_liquidationParityThreeOverlappingSlots(bool target0_, uint64 amount_, uint32 liquidity_) public {
        uint128 liquidity = uint128(bound(liquidity_, 1000, 1e9));
        Quote.Request memory request = _request(target0_);
        _add(request, -887220, 887220, liquidity, bytes32(uint256(1)));
        _add(request, 60, 887220, liquidity * 2, bytes32(uint256(2)));
        _add(request, -887220, -60, liquidity * 3, bytes32(uint256(3)));
        externalLp.modify(key, -887220, 887220, int256(uint256(liquidity * 4)), bytes32(0));
        // Generate real uncollected fees and mixed principal before the quote.
        trader.swap(key, target0_, bound(amount_, 1, uint256(liquidity)));
        _assertParity(request);
    }

    function test_liquidationParityAllOwnNoExternalEitherTarget() public {
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot = vm.snapshotState();
            Quote.Request memory request = _request(i == 0);
            _add(request, -887220, 887220, 1e9, bytes32(0));
            Quote.Result memory result = _assertParity(request);
            assertEq(result.sold, 0);
            assertEq(result.proceeds, 0);
            assertGt(result.unsold, 0);
            assertTrue(result.marketLimited);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    function test_liquidationTraversesEmptyGapToExternalDepth() public {
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot = vm.snapshotState();
            Quote.Request memory request = _request(i == 0);
            if (request.target0) {
                token1.mint(address(portfolio), 10000);
                externalLp.modify(key, 30720, 31020, 1e8, bytes32(0));
            } else {
                token0.mint(address(portfolio), 10000);
                externalLp.modify(key, -31020, -30720, 1e8, bytes32(0));
            }
            assertEq(manager.getLiquidity(key.toId()), 0);
            Quote.Result memory result = _assertParity(request);
            assertGt(result.proceeds, 0);
            assertEq(result.unsold, 0);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    function test_liquidationPartialFillRetainsUnsoldEitherTarget() public {
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot = vm.snapshotState();
            Quote.Request memory request = _request(i == 0);
            token0.mint(address(portfolio), 1e15);
            token1.mint(address(portfolio), 1e15);
            externalLp.modify(key, -60, 60, 1000000, bytes32(0));
            Quote.Result memory result = _assertParity(request);
            assertGt(result.proceeds, 0);
            assertGt(result.sold, 0);
            assertGt(result.unsold, 0);
            assertTrue(result.marketLimited);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    function test_liquidationSharedBoundaryWithZeroOriginalNet() public {
        Quote.Request memory request = _request(true);
        _add(request, -120, 60, 1e8, bytes32(0));
        externalLp.modify(key, 60, 180, 1e8, bytes32(0));
        (, int128 originalNet) = manager.getTickLiquidity(key.toId(), 60);
        assertEq(originalNet, 0);
        Quote.Result memory result = _assertParity(request);
        assertGt(result.proceeds, 0);
    }

    function test_liquidationExactDirectionalBoundaryTick() public {
        Quote.Request memory request = _request(false);
        _add(request, -60, 60, 1e8, bytes32(0));
        externalLp.modify(key, -120, 60, 1e8, bytes32(0));
        trader.swapTo(key, true, 1e20, TickMath.getSqrtPriceAtTick(-60));
        (, int24 tick,,) = manager.getSlot0(key.toId());
        assertEq(tick, -61);
        _assertParity(request);
    }

    function test_liquidationProtocolFeesBothDirections() public {
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, uint24(1000 | (500 << 12)));
        Quote.Request memory request = _request(true);
        _add(request, -887220, 887220, 1e8, bytes32(0));
        externalLp.modify(key, -887220, 887220, 1e9, bytes32(0));
        uint256 snapshot = vm.snapshotState();
        _assertParity(request);
        assertTrue(vm.revertToState(snapshot));
        request.target0 = false;
        _assertParity(request);
    }

    function test_liquidationWorkExhaustionIsNotMarketLimited() public {
        Quote.Request memory request = _request(true);
        request.local1 = 1e9;
        request.stepLimit = 1;
        vm.expectRevert(abi.encodeWithSelector(Quote.QuoteWorkExceeded.selector, 1));
        this.quote(request);
    }

    function test_liquidationDuplicatePositionRejected() public {
        Quote.Request memory request = _request(true);
        _add(request, -60, 60, 1000000, bytes32(0));
        request.positions[1] = request.positions[0];
        request.count = 2;
        vm.expectRevert(Quote.DuplicatePosition.selector);
        this.quote(request);
    }

    function test_liquidationUnexecutableInputRejected() public {
        Quote.Request memory request = _request(true);
        request.local1 = uint256(uint128(type(int128).max)) + 1;
        vm.expectRevert(Quote.QuoteDeltaOverflow.selector);
        this.quote(request);
    }

    function test_feeExtremesMatchActualProtocolSale() public {
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot = vm.snapshotState();
            key.fee = i == 0 ? uint24(0) : uint24(1000000);
            manager.initialize(key, uint160(1) << 96);
            externalLp.modify(key, -887220, 887220, 1e9, bytes32(0));
            token1.mint(address(portfolio), 10000);
            Quote.Result memory result = _assertParity(_request(true));
            assertEq(result.unsold, 0);
            if (i == 0) assertGt(result.proceeds, 0);
            else assertEq(result.proceeds, 0);
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function test_gasProbeThreeSlotsAndEmptyWordTraversal() public {
        Quote.Request memory request = _request(true);
        _add(request, -887220, 887220, 1000000, bytes32(uint256(1)));
        _add(request, 60, 887220, 1000000, bytes32(uint256(2)));
        _add(request, -887220, -60, 1000000, bytes32(uint256(3)));
        uint256 gasBefore = gasleft();
        Quote.Result memory result = Quote.quote(request);
        emit log_named_uint("three-slot full quote gas (fixture state)", gasBefore - gasleft());
        emit log_named_uint("bitmap/swap steps", result.steps);
        gasBefore = gasleft();
        Quote.quote(request);
        emit log_named_uint("repeated warm quote gas", gasBefore - gasleft());
        assertGt(result.steps, 0);
    }

    function test_repeatedQuotesDoNotMutateInputSnapshot() public {
        Quote.Request memory request = _request(true);
        _add(request, -60, 60, 1000000, bytes32(0));
        request.local0 = 123;
        request.local1 = 456;
        bytes memory beforeState = abi.encode(request);
        Quote.Result memory first = Quote.quote(request);
        Quote.Result memory second = Quote.quote(request);
        assertEq(abi.encode(request), beforeState);
        assertEq(abi.encode(first), abi.encode(second));
    }

    function test_liquidationNoOpposingDoesNotScanTicks() public {
        Quote.Request memory request = _request(true);
        request.local0 = 100;
        request.stepLimit = 1;
        Quote.Result memory result = Quote.quote(request);
        assertEq(result.value, 100);
        assertEq(result.steps, 0);
        assertFalse(result.marketLimited);
    }

    function _request(bool target0_) internal view returns (Quote.Request memory request_) {
        request_.manager = manager;
        request_.key = key;
        request_.owner = address(portfolio);
        request_.target0 = target0_;
        request_.stepLimit = 512;
    }

    function _add(Quote.Request memory request_, int24 lower_, int24 upper_, uint128 liquidity_, bytes32 salt_) internal {
        token0.mint(address(portfolio), 1e20);
        token1.mint(address(portfolio), 1e20);
        portfolio.modify(key, lower_, upper_, int256(uint256(liquidity_)), salt_);
        // Remove test funding remainder, keeping this independent of the quoted principal calculation.
        uint256 balance0 = token0.balanceOf(address(portfolio));
        uint256 balance1 = token1.balanceOf(address(portfolio));
        vm.startPrank(address(portfolio));
        token0.transfer(address(this), balance0);
        token1.transfer(address(this), balance1);
        vm.stopPrank();
        request_.positions[request_.count++] = Quote.Position(lower_, upper_, salt_);
    }

    function _assertParity(Quote.Request memory request_) internal returns (Quote.Result memory result_) {
        request_.local0 = token0.balanceOf(address(portfolio));
        request_.local1 = token1.balanceOf(address(portfolio));
        result_ = Quote.quote(request_);
        for (uint256 i; i < request_.count; ++i) {
            Quote.Position memory position = request_.positions[i];
            (uint128 liquidity,,) = manager.getPositionInfo(
                key.toId(), address(portfolio), position.lower, position.upper, position.salt
            );
            portfolio.modify(key, position.lower, position.upper, -int256(uint256(liquidity)), position.salt);
        }
        uint256 opposingBefore = request_.target0 ? token1.balanceOf(address(portfolio)) : token0.balanceOf(address(portfolio));
        uint256 targetBefore = request_.target0 ? token0.balanceOf(address(portfolio)) : token1.balanceOf(address(portfolio));
        if (opposingBefore != 0) portfolio.swap(key, !request_.target0, opposingBefore);
        uint256 opposingAfter = request_.target0 ? token1.balanceOf(address(portfolio)) : token0.balanceOf(address(portfolio));
        uint256 targetAfter = request_.target0 ? token0.balanceOf(address(portfolio)) : token1.balanceOf(address(portfolio));
        assertEq(result_.sold, opposingBefore - opposingAfter, "sold");
        assertEq(result_.unsold, opposingAfter, "unsold");
        assertEq(result_.proceeds, targetAfter - targetBefore, "proceeds");
        assertEq(result_.value, targetAfter, "value");
        (uint160 price, int24 tick,,) = manager.getSlot0(key.toId());
        assertEq(result_.sqrtPriceX96, price, "final price");
        assertEq(result_.tick, tick, "final tick");
        assertEq(result_.liquidity, manager.getLiquidity(key.toId()), "final liquidity");
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuoteTest[]

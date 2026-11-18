// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IStandardExchangeStateQuote as Quote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";

/// @notice Sequential views are checked against real pool receipts and vault books.
contract UniswapV3FullSpreadStateQuoteTest is TestBase_UniswapV3FullSpreadAccounting {
    struct Operation {
        IERC20 tokenIn;
        uint256 amount;
        IERC20 tokenOut;
        address payer;
    }

    function testFuzz_redemptionThenDepositPreservesFeesAndSupply(uint16 fraction_, bool target0_) public {
        _seedVault(SEED);
        _poolFees(1e16, 2e16);
        _bundleIn(bob, 1e8, 2e8);
        _poolFees(1e15, 3e15);
        _setUsageFee(7e16);
        IERC20 target_ = target0_ ? IERC20(address(token0)) : IERC20(address(token1));
        uint256 shares_ = vault.balanceOf(alice) * bound(fraction_, 1, 9999) / 10000;
        Quote quote_ = Quote(address(vault));
        (, uint256 paid_,) = quote_.quoteExchangeIn(
            quote_.quoteExchangeState(), IERC20(address(vault)), shares_, target_
        );
        Operation[] memory operations_ = new Operation[](2);
        operations_[0] = Operation(IERC20(address(vault)), shares_, target_, alice);
        operations_[1] = Operation(target_, paid_ / 2, IERC20(address(vault)), bob);
        _assertSequence(operations_);
    }

    function test_oppositeSwapsRetainFeeGrowthFractionsUntilPositionTouch() public {
        _seedVault(5e17);
        vm.prank(IUniswapV3Factory(pool.factory()).owner());
        pool.setFeeProtocol(4, 5);
        _poolFees(7, 11);
        Operation[] memory operations_ = new Operation[](9);
        for (uint256 i_; i_ < 8; ++i_) {
            bool zeroForOne_ = i_ % 2 == 0;
            operations_[i_] = Operation(
                zeroForOne_ ? IERC20(address(token0)) : IERC20(address(token1)),
                10_003 + i_ * 113,
                zeroForOne_ ? IERC20(address(token1)) : IERC20(address(token0)),
                bob
            );
        }
        operations_[8] = Operation(
            IERC20(address(vault)), vault.balanceOf(alice) / 7, IERC20(address(token0)), alice
        );
        _assertSequence(operations_);
    }

    function test_genesisMintThenRedemptionIncludesLockedAndFeeShares() public {
        _setUsageFee(7e16);
        Quote quote_ = Quote(address(vault));
        (, uint256 shares_,) = quote_.quoteExchangeIn(
            quote_.quoteExchangeState(), IERC20(address(token0)), 1e10, IERC20(address(vault))
        );
        Operation[] memory operations_ = new Operation[](2);
        operations_[0] = Operation(IERC20(address(token0)), 1e10, IERC20(address(vault)), bob);
        operations_[1] = Operation(IERC20(address(vault)), shares_ / 2, IERC20(address(token1)), bob);
        _assertSequence(operations_);
        assertEq(vault.balanceOf(address(0)), 1000, "genesis floor remains issued");
    }

    function test_unrepresentableDepositRefundDoesNotAdvanceState() public {
        _seedVault(SEED);
        _swapTo(TickMath.getSqrtRatioAtTick(lower) - 1);
        Quote quote_ = Quote(address(vault));
        bytes memory before_ = quote_.quoteExchangeState();
        (bytes memory next_, uint256 out_, uint256 refund_) =
            quote_.quoteExchangeIn(before_, IERC20(address(token1)), 1e10, IERC20(address(vault)));
        assertEq(out_, 0);
        assertEq(refund_, 1e10);
        assertEq(next_, before_, "discard the unexecuted candidate");
        vm.prank(bob);
        (uint256 paid_, uint256 returned_) = vault.exchangeIn(
            IERC20(address(token1)), 1e10, IERC20(address(vault)), 0, bob, false, block.timestamp
        );
        assertEq(paid_, 0);
        assertEq(returned_, refund_);
        _assertState(next_);
    }

    function test_unavailableFullBookExitDoesNotAdvanceState() public {
        _freshMarket(false);
        _seedVault(SEED);
        Quote quote_ = Quote(address(vault));
        bytes memory before_ = quote_.quoteExchangeState();
        (bytes memory next_, uint256 out_, uint256 refund_) =
            quote_.quoteExchangeIn(before_, IERC20(address(vault)), vault.totalSupply(), IERC20(address(token0)));
        assertEq(out_, 0, "there is no external liquidity for the unwanted token");
        assertEq(refund_, 0);
        assertEq(next_, before_);
    }

    function test_zeroAmountAndUnsupportedRoutePreserveState() public {
        _seedVault(SEED);
        _poolFees(1e16, 2e16);
        Quote quote_ = Quote(address(vault));
        bytes memory before_ = quote_.quoteExchangeState();
        (bytes memory next_, uint256 out_, uint256 refund_) =
            quote_.quoteExchangeIn(before_, IERC20(address(vault)), 0, IERC20(address(token0)));
        assertEq(next_, before_, "zero redemption cannot collect hypothetical fees");
        assertEq(out_, 0);
        assertEq(refund_, 0);
        (next_, out_, refund_) = quote_.quoteExchangeIn(before_, IERC20(bob), 1e10, IERC20(address(vault)));
        assertEq(next_, before_);
        assertEq(out_, 0);
        assertEq(refund_, 0);
    }

    function test_foreignDomainVersionAndMalformedLengthAreRejected() public {
        Quote quote_ = Quote(address(vault));
        Planner.State memory state_ = abi.decode(quote_.quoteExchangeState(), (Planner.State));
        state_.vault = bob;
        vm.expectRevert(Quote.InvalidQuoteState.selector);
        quote_.quoteExchangeSupply(abi.encode(state_));
        state_.vault = address(vault);
        state_.pool = bob;
        vm.expectRevert(Quote.InvalidQuoteState.selector);
        quote_.quoteExchangeSupply(abi.encode(state_));
        state_.pool = address(pool);
        state_.version = 2;
        vm.expectRevert(Quote.InvalidQuoteState.selector);
        quote_.quoteExchangeIn(abi.encode(state_), IERC20(address(token0)), 1e10, IERC20(address(vault)));
        state_.version = 1;
        ++state_.chainId;
        vm.expectRevert(Quote.InvalidQuoteState.selector);
        quote_.quoteExchangeSupply(abi.encode(state_));
        state_.chainId = block.chainid;
        vm.expectRevert(Quote.InvalidQuoteState.selector);
        quote_.quoteExchangeSupply(bytes.concat(abi.encode(state_), bytes32(0)));
    }

    function _assertSequence(Operation[] memory operations_) private {
        Quote quote_ = Quote(address(vault));
        bytes memory state_ = quote_.quoteExchangeState();
        bytes[] memory states_ = new bytes[](operations_.length);
        uint256[] memory outputs_ = new uint256[](operations_.length);
        uint256[] memory refunds_ = new uint256[](operations_.length);
        // Every transition is projected before any execution changes the live baseline.
        for (uint256 i_; i_ < operations_.length; ++i_) {
            Operation memory operation_ = operations_[i_];
            (state_, outputs_[i_], refunds_[i_]) =
                quote_.quoteExchangeIn(state_, operation_.tokenIn, operation_.amount, operation_.tokenOut);
            assertGt(outputs_[i_], 0, "positive executable sequence");
            states_[i_] = state_;
        }
        for (uint256 i_; i_ < operations_.length; ++i_) {
            Operation memory operation_ = operations_[i_];
            uint256 balance_ = operation_.tokenOut.balanceOf(operation_.payer);
            vm.prank(operation_.payer);
            (uint256 paid_, uint256 refunded_) = vault.exchangeIn(
                operation_.tokenIn, operation_.amount, operation_.tokenOut,
                outputs_[i_], operation_.payer, false, block.timestamp
            );
            assertEq(paid_, outputs_[i_], "projected payout");
            assertEq(refunded_, refunds_[i_], "projected caller refund");
            assertEq(operation_.tokenOut.balanceOf(operation_.payer) - balance_, paid_, "actual receipt");
            _assertState(states_[i_]);
            _assertSettled();
        }
    }

    function _assertState(bytes memory encoded_) private view {
        Planner.State memory expected_ = abi.decode(encoded_, (Planner.State));
        Planner.State memory actual_ =
            abi.decode(Quote(address(vault)).quoteExchangeState(), (Planner.State));
        assertEq(expected_.supply, vault.totalSupply(), "issued shares");
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(expected_.booked0, booked0_, "booked token zero");
        assertEq(expected_.booked1, booked1_, "booked token one");
        assertEq(expected_.position.liquidity, _positionLiquidity(), "remaining position");
        (uint160 price_, int24 tick_,,,,,) = pool.slot0();
        assertEq(expected_.position.sqrtPriceX96, price_, "pool price");
        assertEq(expected_.position.tick, tick_, "pool tick");
        assertEq(expected_.position.activeLiquidity, pool.liquidity(), "active pool liquidity");
        assertEq(expected_.position.fee0, actual_.position.fee0, "unpaid token zero fees");
        assertEq(expected_.position.fee1, actual_.position.fee1, "unpaid token one fees");
        assertEq(expected_.position.lowerGross, actual_.position.lowerGross, "lower endpoint capacity");
        assertEq(expected_.position.upperGross, actual_.position.upperGross, "upper endpoint capacity");
    }
}

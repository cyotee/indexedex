// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Liquidity} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";

/// @notice Pure component oracles and tuple plumbing against the production libraries.
/// @dev The test contract supplies only the external SE quote dependency, never a replacement SUT.
contract UniswapV4HookComponentAccountingTest is Test {
    address internal constant FEE_TO = address(0xFEE);
    address internal constant PAIR = address(0xBEEF);
    bool internal contextEnabled;

    /// @notice T=7, C=[11,5,13], available=[5,2,8] accepts [4,2,4] for two LP.
    function test_component_workedBasket() public pure {
        uint256[] memory book_ = _three(11, 5, 13);
        uint256[] memory available_ = _three(5, 2, 8);
        uint256[] memory expected_ = _three(4, 2, 4);
        uint256[] memory refunds_ = _three(1, 0, 4);
        assertEq(Liquidity.componentMintLimit(5, 11, 7), 3);
        assertEq(Liquidity.componentMintLimit(2, 5, 7), 2);
        assertEq(Liquidity.componentMintLimit(8, 13, 7), 4);
        uint256 minted_ = Liquidity.maxComponentMint(available_, book_, 7);
        assertEq(minted_, 2);
        for (uint256 i; i < 3; ++i) {
            uint256 accepted_ = Liquidity.componentContribution(minted_, book_[i], 7);
            assertEq(accepted_, expected_[i]);
            assertEq(available_[i] - accepted_, refunds_[i]);
            assertGe(accepted_ * 7, minted_ * book_[i]);
            assertGe((book_[i] + accepted_) * 7, book_[i] * (7 + minted_));
        }
        assertEq(Liquidity.componentAllocation(2, 11, 7), 3);
        assertEq(Liquidity.componentAllocation(2, 5, 7), 1);
        assertEq(Liquidity.componentAllocation(2, 13, 7), 3);
    }

    /// @notice Zero components do not constrain live inventory; an empty book cannot mint.
    function test_component_zeroAndAllLocalBooks() public pure {
        assertEq(Liquidity.componentContribution(17, 0, 7), 0);
        assertEq(Liquidity.componentAllocation(3, 0, 7), 0);
        assertEq(Liquidity.componentMintLimit(0, 0, 7), type(uint256).max);
        assertEq(Liquidity.maxComponentMint(_three(0, 3, 0), _three(0, 5, 0), 7), 4);
        assertEq(Liquidity.maxComponentMint(_three(99, 99, 99), _three(0, 0, 0), 7), 0);
        assertEq(Liquidity.maxComponentMint(new uint256[](0), new uint256[](0), 7), 0);
        assertEq(Liquidity.maxComponentMint(_three(99, 0, 99), _three(11, 5, 13), 7), 0);
        assertEq(Liquidity.componentContribution(0, 11, 7), 0);
    }

    /// @notice Live-supply arithmetic never silently enters the separate genesis branch.
    function test_component_invalidSupplyAndDimensions() public {
        vm.expectRevert(Liquidity.InvalidComponentSupply.selector);
        this.contribution(1, 0, 0);
        vm.expectRevert(Liquidity.InvalidComponentSupply.selector);
        this.limit(1, 0, 0);
        vm.expectRevert(Liquidity.InvalidComponentSupply.selector);
        this.allocation(0, 0, 0);
        vm.expectRevert(Liquidity.InvalidComponentSupply.selector);
        this.allocation(8, 5, 7);
        vm.expectRevert(Liquidity.InvalidComponentSupply.selector);
        this.basket(_three(1, 2, 3), _three(0, 0, 0), 0);
        vm.expectRevert(Liquidity.ComponentLengthMismatch.selector);
        this.basket(new uint256[](0), _three(1, 2, 3), 7);
    }

    /// @notice Products wider than 256 bits work; unrepresentable results fail.
    function test_component_fullWidthAndOverflow() public {
        assertEq(Liquidity.componentContribution(1 << 200, 1 << 100, 1 << 150), 1 << 150);
        assertEq(Liquidity.componentAllocation(1 << 100, 1 << 200, 1 << 150), 1 << 150);
        assertEq(Liquidity.componentMintLimit(1 << 200, 1 << 150, 1 << 100), 1 << 150);
        assertEq(Liquidity.componentContribution(type(uint256).max, 1, type(uint256).max), 1);
        assertEq(Liquidity.componentAllocation(1, type(uint256).max, type(uint256).max), 1);
        vm.expectRevert(FixedPointMathLib.FullMulDivFailed.selector);
        this.contribution(type(uint256).max, 2, 1);
        vm.expectRevert(FixedPointMathLib.FullMulDivFailed.selector);
        this.limit(type(uint256).max, 1, 2);
        // The floor quotient fits exactly at max, but its nonzero remainder makes ceil overflow.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        this.contribution(type(uint256).max - 1, type(uint256).max - 1, type(uint256).max - 2);
    }

    /// @notice A base-2^128 decomposition is an independent full-width oracle, with no mulDiv.
    function testFuzz_component_fullWidthOracle(uint256 amount_, uint128 multiplier_) public pure {
        uint256 multiplier = uint256(multiplier_) + 1;
        uint256 lowProduct_ = uint256(uint128(amount_)) * multiplier;
        uint256 floor_ = (amount_ >> 128) * multiplier + (lowProduct_ >> 128);
        uint256 ceil_ = floor_ + (uint128(lowProduct_) == 0 ? 0 : 1);
        assertEq(Liquidity.componentContribution(amount_, multiplier, 1 << 128), ceil_);
        assertEq(Liquidity.componentAllocation(multiplier, amount_, 1 << 128), floor_);
        assertEq(Liquidity.componentMintLimit(amount_, 1 << 128, multiplier), floor_);
    }

    /// @notice Direct bounded products prove ceil backing, maximal mint, and refund conservation.
    function testFuzz_component_basketProperties(
        uint64 supplySeed_, uint64[3] memory bookSeed_, uint64[3] memory availableSeed_
    ) public pure {
        uint256 supply_ = uint256(supplySeed_) + 1;
        uint256[] memory book_ = new uint256[](3);
        uint256[] memory available_ = new uint256[](3);
        uint256 expected_ = type(uint256).max;
        for (uint256 i; i < 3; ++i) {
            book_[i] = uint256(bookSeed_[i]) + 1;
            available_[i] = availableSeed_[i];
            uint256 limit_ = available_[i] * supply_ / book_[i];
            if (limit_ < expected_) expected_ = limit_;
        }
        uint256 minted_ = Liquidity.maxComponentMint(available_, book_, supply_);
        assertEq(minted_, expected_);
        bool limiting_;
        for (uint256 i; i < 3; ++i) {
            uint256 product_ = minted_ * book_[i];
            uint256 accepted_ = Liquidity.componentContribution(minted_, book_[i], supply_);
            assertEq(accepted_, product_ / supply_ + (product_ % supply_ == 0 ? 0 : 1));
            assertLe(accepted_, available_[i]);
            assertGe(accepted_ * supply_, product_);
            assertGe((book_[i] + accepted_) * supply_, book_[i] * (supply_ + minted_));
            assertEq(accepted_ + (available_[i] - accepted_), available_[i]);
            if (available_[i] * supply_ < (minted_ + 1) * book_[i]) limiting_ = true;
        }
        assertTrue(limiting_);
    }

    /// @notice Sequential burns cannot increase aggregate entitlement through rounding.
    function testFuzz_component_splitBurn(uint64 book_, uint64 supplySeed_, uint64 firstSeed_, uint64 secondSeed_)
        public pure
    {
        uint256 supply_ = uint256(supplySeed_) + 2;
        uint256 first_ = uint256(firstSeed_) % supply_;
        uint256 second_ = uint256(secondSeed_) % (supply_ - first_ + 1);
        uint256 firstOut_ = Liquidity.componentAllocation(first_, book_, supply_);
        uint256 secondOut_ = Liquidity.componentAllocation(second_, uint256(book_) - firstOut_, supply_ - first_);
        uint256 together_ = (first_ + second_) * uint256(book_) / supply_;
        assertEq(firstOut_, first_ * uint256(book_) / supply_);
        assertEq(secondOut_, second_ * (uint256(book_) - firstOut_) / (supply_ - first_));
        assertLe(firstOut_ + secondOut_, together_);
    }

    /// @notice A 2% fee splits gross=100 into 98+2; exact net=100 minimally requires 102.
    function test_fee_workedExamplesAndGenesisFloor() public pure {
        (uint256 net_, uint256 fee_) = Liquidity.splitMintFee(100, 2e16, FEE_TO, true);
        assertEq(net_, 98);
        assertEq(fee_, 2);
        assertEq(net_ + fee_, 100);
        assertEq(Liquidity.grossForNet(100, 2e16, FEE_TO, true), 102);
        (net_, fee_) = Liquidity.splitMintFee(102, 2e16, FEE_TO, true);
        assertEq(net_, 100);
        assertEq(fee_, 2);
        assertEq(Liquidity.componentContribution(102, 500, 1000), 51);
        uint256 gross_ = Liquidity.genesisGross(1100, 1000);
        (net_, fee_) = Liquidity.splitMintFee(gross_, 2e16, FEE_TO, true);
        assertEq(net_, 98);
        assertEq(1000 + net_ + fee_, 1100);
        assertEq(Liquidity.componentAllocation(fee_, 5500, 1100), 10);
    }

    /// @notice Inactive/zero-recipient fees bypass configuration; active 100% cannot deliver net.
    function test_fee_activationAndLimits() public {
        (uint256 net_, uint256 fee_) = Liquidity.splitMintFee(100, type(uint256).max, FEE_TO, false);
        assertEq(net_, 100); assertEq(fee_, 0);
        (net_, fee_) = Liquidity.splitMintFee(100, type(uint256).max, address(0), true);
        assertEq(net_, 100); assertEq(fee_, 0);
        assertEq(Liquidity.grossForNet(100, type(uint256).max, FEE_TO, false), 100);
        assertEq(Liquidity.grossForNet(100, type(uint256).max, address(0), true), 100);
        (net_, fee_) = Liquidity.splitMintFee(100, 1e18, FEE_TO, true);
        assertEq(net_, 0); assertEq(fee_, 100);
        assertEq(Liquidity.grossForNet(0, 1e18, FEE_TO, true), 0);
        assertEq(Liquidity.grossForNet(type(uint256).max, 0, FEE_TO, true), type(uint256).max);
        vm.expectRevert(Liquidity.InvalidMintFee.selector);
        this.split(1, 1e18 + 1);
        vm.expectRevert(Liquidity.InvalidMintFee.selector);
        this.gross(1, 1e18 + 1);
        vm.expectRevert(Liquidity.ExactNetLiquidityUnavailable.selector);
        this.gross(1, 1e18);
        vm.expectRevert(Liquidity.ExactNetLiquidityUnavailable.selector);
        this.gross(type(uint256).max, 1);
        vm.expectRevert(Liquidity.ZeroLiquidityAmount.selector);
        this.genesis(1000, 1000);
        vm.expectRevert(Liquidity.ZeroLiquidityAmount.selector);
        this.genesis(999, 1000);
    }

    /// @notice Independent bounded multiplication checks conservation and inverse minimality.
    function testFuzz_fee_splitAndExactNet(uint128 grossSeed_, uint128 netSeed_, uint64 feeSeed_) public pure {
        uint256 feeWad_ = uint256(feeSeed_) % 1e18;
        (uint256 net_, uint256 fee_) = Liquidity.splitMintFee(grossSeed_, feeWad_, FEE_TO, true);
        assertEq(fee_, uint256(grossSeed_) * feeWad_ / 1e18);
        assertEq(net_ + fee_, grossSeed_);
        uint256 requested_ = uint256(netSeed_) + 1;
        uint256 expectedGross_ = (requested_ - 1) * 1e18 / (1e18 - feeWad_) + 1;
        uint256 gross_ = Liquidity.grossForNet(requested_, feeWad_, FEE_TO, true);
        assertEq(gross_, expectedGross_);
        assertEq(gross_ - gross_ * feeWad_ / 1e18, requested_);
        assertLt(gross_ - 1 - (gross_ - 1) * feeWad_ / 1e18, requested_);
    }

    /// @notice Full-width fees preserve every LP unit, including a fee one unit below 100%.
    function test_fee_fullWidthBoundary() public pure {
        uint256 maximum_ = type(uint256).max;
        (uint256 net_, uint256 fee_) = Liquidity.splitMintFee(maximum_, 1e18 - 1, FEE_TO, true);
        uint256 expectedNet_ = maximum_ / 1e18 + (maximum_ % 1e18 == 0 ? 0 : 1);
        assertEq(net_, expectedNet_);
        assertEq(fee_, maximum_ - expectedNet_);
        uint256 gross_ = Liquidity.grossForNet(net_, 1e18 - 1, FEE_TO, true);
        assertEq(gross_, (net_ - 1) * 1e18 + 1);
        (uint256 received_,) = Liquidity.splitMintFee(gross_, 1e18 - 1, FEE_TO, true);
        assertEq(received_, net_);
    }

    /// @notice 101 incoming shares spend 5; ambient custody and receipt value are not LP inputs.
    function test_bootstrap_actualReceiptAndRounding() public pure {
        (uint256 spend_, uint256 retained_) = Liquidity.bootstrapSplit(101);
        assertEq(spend_, 5); assertEq(retained_, 96);
        uint256 local_;
        (retained_, local_) = Liquidity.bootstrapReceipt(
            101, ExchangeInAmount.Result(7, 0), 1101, 1096, 2000, 2007
        );
        assertEq(retained_, 96); assertEq(local_, 7);
        (spend_, retained_) = Liquidity.bootstrapSplit(20);
        assertEq(spend_, 1); assertEq(retained_, 19);
        (spend_, retained_) = Liquidity.bootstrapSplit(type(uint256).max);
        assertEq(spend_, type(uint256).max / 20);
        assertEq(spend_ + retained_, type(uint256).max);
    }

    /// @notice Bootstrap rejects zero spends, empty receipts, partial refunds, and false tuples.
    function test_bootstrap_incompleteOrShortReceiptReverts() public {
        vm.expectRevert(Liquidity.ZeroLiquidityAmount.selector);
        this.bootstrap(19, ExchangeInAmount.Result(1, 0), 19, 19, 0, 1);
        vm.expectRevert(Liquidity.InvalidBootstrapReceipt.selector);
        this.bootstrap(100, ExchangeInAmount.Result(0, 0), 100, 95, 0, 0);
        vm.expectRevert(Liquidity.InvalidBootstrapReceipt.selector);
        this.bootstrap(100, ExchangeInAmount.Result(7, 1), 100, 96, 0, 7);
        vm.expectRevert(Liquidity.InvalidBootstrapReceipt.selector);
        this.bootstrap(100, ExchangeInAmount.Result(7, 0), 99, 94, 0, 7);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.bootstrap(100, ExchangeInAmount.Result(7, 0), 100, 96, 0, 7);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.bootstrap(100, ExchangeInAmount.Result(7, 0), 100, 95, 1000, 1006);
    }

    /// @notice Returned input is counted once, independently of output units or ambient balances.
    function test_receipt_creditAndTupleConservation() public pure {
        ExchangeInAmount.Result memory result_ = ExchangeInAmount.fromConsumedInput(60, 45, 9);
        assertEq(result_.amountOut, 9);
        assertEq(result_.amountRefunded, 15);
        assertEq(ExchangeInAmount.localCredit(100, 60, result_.amountRefunded), 55);
        assertEq(ExchangeInAmount.requireReceipt(60, result_, 1000, 955, 2000, 2009), 45);
        assertEq(ExchangeInAmount.localCredit(type(uint256).max, type(uint256).max, type(uint256).max), type(uint256).max);
    }

    /// @notice Invalid funding, refunds, consumption, and output deltas cannot create credit.
    function test_receipt_invalidAmountsRevert() public {
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.credit(100, 101, 0);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.credit(100, 60, 61);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.transitionResult(60, 61, 9);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.receipt(60, ExchangeInAmount.Result(9, 15), 59, 14, 0, 9);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.receipt(60, ExchangeInAmount.Result(9, 15), 1000, 940, 0, 9);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.receipt(60, ExchangeInAmount.Result(9, 15), 1000, 955, 10, 9);
        vm.expectRevert(ExchangeInAmount.InvalidExchangeReceipt.selector);
        this.receipt(60, ExchangeInAmount.Result(9, 15), 1000, 1001, 0, 9);
    }

    /// @notice Same-unit conservation remains exact for the entire uint256 input range.
    function testFuzz_receipt_localConservation(uint256 supplied_, uint256 forwardSeed_, uint256 refundSeed_)
        public pure
    {
        uint256 forwarded_ = forwardSeed_ > supplied_ ? supplied_ : forwardSeed_;
        uint256 refunded_ = refundSeed_ > forwarded_ ? forwarded_ : refundSeed_;
        uint256 consumed_ = forwarded_ - refunded_;
        uint256 local_ = ExchangeInAmount.localCredit(supplied_, forwarded_, refunded_);
        assertEq(local_, supplied_ - forwarded_ + refunded_);
        assertEq(local_ + consumed_, supplied_);
    }

    /// @notice Legacy one-word helpers stay compatible while new callers retain the refund.
    function test_result_executionAndPreviewPreserveRefund() public {
        IStandardExchangeIn exchange_ = IStandardExchangeIn(address(this));
        ExchangeInAmount.Result memory preview_ = ExchangeInAmount.previewResult(exchange_, IERC20(PAIR), 100, IERC20(address(this)));
        ExchangeInAmount.Result memory actual_ = ExchangeInAmount.exchangeResult(
            exchange_, IERC20(PAIR), 100, IERC20(address(this)), 0, address(this), false, type(uint256).max
        );
        assertEq(preview_.amountOut, 50); assertEq(preview_.amountRefunded, 25);
        assertEq(actual_.amountOut, 50); assertEq(actual_.amountRefunded, 25);
        assertEq(ExchangeInAmount.previewOut(exchange_, IERC20(PAIR), 100, IERC20(address(this))), 50);
        assertEq(ExchangeInAmount.exchangeOut(
            exchange_, IERC20(PAIR), 100, IERC20(address(this)), 0, address(this), false, type(uint256).max
        ), 50);
    }

    /// @notice Optional-context fallback does not erase ordinary two-word previews.
    function test_result_contextFallbackPreservesRefund() public view {
        (ExchangeInAmount.Result memory deposit_, bytes memory next_) =
            ContextQuote.depositResult(address(this), PAIR, address(this), 100, address(0));
        assertEq(deposit_.amountOut, 50); assertEq(deposit_.amountRefunded, 25); assertEq(next_.length, 0);
        (ExchangeInAmount.Result memory redeem_,) =
            ContextQuote.redeemResult(address(this), PAIR, address(this), 100, address(0));
        assertEq(redeem_.amountOut, 50); assertEq(redeem_.amountRefunded, 25);
        ExchangeInAmount.Result memory received_ = ContextQuote.redeemReceivedResult(address(this), PAIR, 100, address(0));
        assertEq(received_.amountOut, 50); assertEq(received_.amountRefunded, 25);
        (deposit_, next_) = ContextQuote.depositResult(PAIR, PAIR, address(this), 100, address(0));
        assertEq(deposit_.amountOut, 100); assertEq(deposit_.amountRefunded, 0); assertEq(next_.length, 0);
    }

    /// @notice Projected exact-input consumption maps back to refunds without changing next state.
    function test_result_projectedConsumptionPreservesRefund() public {
        contextEnabled = true;
        (ExchangeInAmount.Result memory deposit_, bytes memory next_) =
            ContextQuote.depositResult(address(this), PAIR, address(this), 100, address(1));
        assertEq(deposit_.amountOut, 50); assertEq(deposit_.amountRefunded, 25);
        assertEq(abi.decode(next_, (uint256)), 7);
        (ExchangeInAmount.Result memory redeem_,) =
            ContextQuote.redeemResult(address(this), PAIR, address(this), 100, address(1));
        assertEq(redeem_.amountOut, 50); assertEq(redeem_.amountRefunded, 25);
        ExchangeInAmount.Result memory received_ = ContextQuote.redeemReceivedResult(address(this), PAIR, 100, address(1));
        assertEq(received_.amountOut, 50); assertEq(received_.amountRefunded, 25);
        (uint256 legacy_, bytes memory legacyNext_) = ContextQuote.deposit(address(this), PAIR, address(this), 100, address(1));
        assertEq(legacy_, 50); assertEq(legacyNext_, next_);
        (legacy_, legacyNext_) = ContextQuote.redeem(address(this), PAIR, address(this), 100, address(1));
        assertEq(legacy_, 50); assertEq(legacyNext_, next_);
        assertEq(ContextQuote.redeemReceived(address(this), PAIR, 100, address(1)), 50);
    }

    function test_result_unchangedContextKeepsOrdinaryInverseQuotes() public {
        assertEq(ContextQuote.inputForShares(address(this), PAIR, 10, address(1)), 13);
        assertEq(ContextQuote.withdraw(address(this), PAIR, address(this), 10, address(1)), 13);
        contextEnabled = true;
        // The dependency supports snapshots but the projection leaves them unchanged.
        // Its ordinary inverse remains valid without advertising a quantity interface.
        assertEq(ContextQuote.inputForShares(address(this), PAIR, 10, address(1)), 13);
        assertEq(ContextQuote.withdraw(address(this), PAIR, address(this), 10, address(1)), 13);
    }

    // External boundaries expose the real internal arithmetic for exact revert assertions.
    function contribution(uint256 g_, uint256 b_, uint256 t_) external pure returns (uint256) { return Liquidity.componentContribution(g_, b_, t_); }
    function limit(uint256 a_, uint256 b_, uint256 t_) external pure returns (uint256) { return Liquidity.componentMintLimit(a_, b_, t_); }
    function allocation(uint256 b_, uint256 c_, uint256 t_) external pure returns (uint256) { return Liquidity.componentAllocation(b_, c_, t_); }
    function basket(uint256[] memory a_, uint256[] memory b_, uint256 t_) external pure returns (uint256) { return Liquidity.maxComponentMint(a_, b_, t_); }
    function split(uint256 g_, uint256 f_) external pure returns (uint256, uint256) { return Liquidity.splitMintFee(g_, f_, FEE_TO, true); }
    function gross(uint256 n_, uint256 f_) external pure returns (uint256) { return Liquidity.grossForNet(n_, f_, FEE_TO, true); }
    function genesis(uint256 seed_, uint256 floor_) external pure returns (uint256) { return Liquidity.genesisGross(seed_, floor_); }
    function credit(uint256 g_, uint256 d_, uint256 f_) external pure returns (uint256) { return ExchangeInAmount.localCredit(g_, d_, f_); }
    function transitionResult(uint256 supplied_, uint256 consumed_, uint256 out_) external pure returns (ExchangeInAmount.Result memory) { return ExchangeInAmount.fromConsumedInput(supplied_, consumed_, out_); }
    function receipt(uint256 supplied_, ExchangeInAmount.Result memory result_, uint256 ib_, uint256 ia_, uint256 ob_, uint256 oa_)
        external pure returns (uint256) { return ExchangeInAmount.requireReceipt(supplied_, result_, ib_, ia_, ob_, oa_); }
    function bootstrap(uint256 supplied_, ExchangeInAmount.Result memory result_, uint256 sb_, uint256 sa_, uint256 pb_, uint256 pa_)
        external pure returns (uint256, uint256) { return Liquidity.bootstrapReceipt(supplied_, result_, sb_, sa_, pb_, pa_); }

    // Controlled non-SUT dependency: quote/return plumbing only, not token execution evidence.
    function previewExchangeIn(IERC20, uint256 amount_, IERC20) external pure returns (uint256, uint256) {
        return (amount_ / 2, amount_ / 4);
    }
    function previewExchangeOut(IERC20, IERC20, uint256 amount_) external pure returns (uint256) {
        return amount_ + 3;
    }
    function exchangeIn(IERC20, uint256 amount_, IERC20, uint256, address, bool, uint256) external pure returns (uint256, uint256) {
        return (amount_ / 2, amount_ / 4);
    }
    function supportsInterface(bytes4 id_) external view returns (bool) {
        return contextEnabled && (
            id_ == type(Transition).interfaceId || id_ == type(IStandardExchangeUnlockContextQuote).interfaceId
        );
    }
    function quoteState(address, address) external pure returns (bytes memory, uint256) { return (abi.encode(uint256(7)), 0); }
    function quoteStateWithUnavailableUnlock(bytes calldata state_, address) external pure returns (bytes memory) { return state_; }
    function quoteTransition(bytes calldata state_, Transition.Operation operation_, uint256 amount_)
        external pure returns (bytes memory, uint256, uint256, uint256)
    {
        if (operation_ == Transition.Operation.ReceiveShares) return (state_, amount_, amount_, 0);
        return (state_, amount_ - amount_ / 4, amount_ / 2, 0);
    }

    function _three(uint256 a_, uint256 b_, uint256 c_) private pure returns (uint256[] memory values_) {
        values_ = new uint256[](3);
        values_[0] = a_; values_[1] = b_; values_[2] = c_;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultTypes.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {FullSpreadV4ExternalLp} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";

/// @notice Successive quotes are computed before any execution, then checked against
/// actual receipts, custody, booked balances, position checkpoints and PoolManager state.
contract UniswapV4FullSpreadStandardExchangeVault_StateQuote_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    IStandardExchangeStateQuote internal quote;

    struct Operation {
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        bytes next;
        uint256 out;
        uint256 refund;
    }

    function setUp() public override {
        super.setUp();
        quote = IStandardExchangeStateQuote(address(vault));
        _fund(address(this), 10_000_000 ether, 10_000_000 ether);
        _approve(address(vault));
    }

    function test_stateQuoteSequentialRedemptionsCarryBookedAndAccruedFees() public {
        _external(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 1_000_000 ether);
        _bundle(100_000 ether);
        _trade(address(token0), address(token1), 123 ether);
        _trade(address(token1), address(token0), 217 ether);
        _bundle(1 ether);
        _trade(address(token0), address(token1), 113 ether);
        _trade(address(token1), address(token0), 211 ether);
        bytes memory initial_ = quote.quoteExchangeState();
        Types.QuoteState memory captured_ = abi.decode(initial_, (Types.QuoteState));
        assertGt(captured_.booked[0], 0);
        assertGt(captured_.booked[1], 0);
        uint256 shares_ = vault.balanceOf(address(this)) / 7;
        Operation[] memory steps_ = new Operation[](4);
        steps_[0] = _project(initial_, address(vault), shares_, address(token0));
        steps_[1] = _project(steps_[0].next, address(vault), shares_, address(token1));
        steps_[2] = _project(steps_[1].next, address(token1), 41 ether, address(vault));
        steps_[3] = _project(steps_[2].next, address(vault), steps_[2].out, address(token0));
        for (uint256 i_; i_ < steps_.length; ++i_) {
            assertGt(steps_[i_].out, 0);
            _execute(steps_[i_]);
        }
    }

    function test_stateQuoteOppositeSwapsCrossTicksWithPerStepProtocolFees() public {
        _external(-60, 60, 500_000 ether);
        _external(-600, 600, 300_000 ether);
        _bundle(100_000 ether);
        pool.setProtocolFeeController(address(this));
        pool.setProtocolFee(key, uint24(700 | (900 << 12)));
        bytes memory state_ = quote.quoteExchangeState();
        Operation[] memory steps_ = new Operation[](10);
        for (uint256 i_; i_ < 8; ++i_) {
            bool forward_ = i_ % 2 == 0;
            steps_[i_] = _project(
                state_, forward_ ? address(token0) : address(token1),
                uint256(i_ == 0 ? 12_000 : 24_000) * 1 ether + i_,
                forward_ ? address(token1) : address(token0)
            );
            state_ = steps_[i_].next;
            Types.QuoteState memory projected_ = abi.decode(state_, (Types.QuoteState));
            assertTrue(forward_ ? projected_.tick < -60 : projected_.tick > 60, "cross the external LP boundary");
        }
        steps_[8] = _project(state_, address(token0), 37 ether, address(vault));
        steps_[9] = _project(steps_[8].next, address(vault), vault.balanceOf(address(this)) / 9, address(token1));
        for (uint256 i_; i_ < steps_.length; ++i_) _execute(steps_[i_]);
        assertGt(pool.protocolFeesAccrued(key.currency0), 0);
        assertGt(pool.protocolFeesAccrued(key.currency1), 0);
    }

    function test_stateQuoteGenesisAndSuccessiveMintsBothSides() public {
        _external(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 1_000_000 ether);
        for (uint256 side_; side_ < 2; ++side_) {
            uint256 snapshot_ = vm.snapshotState();
            address first_ = side_ == 0 ? address(token0) : address(token1);
            address other_ = side_ == 0 ? address(token1) : address(token0);
            bytes memory initial_ = quote.quoteExchangeState();
            assertEq(quote.quoteExchangeSupply(initial_), 0);
            Operation memory firstMint_ = _project(initial_, first_, 100 ether, address(vault));
            Operation memory secondMint_ = _project(firstMint_.next, other_, 71 ether, address(vault));
            Operation memory exit_ = _project(secondMint_.next, address(vault), firstMint_.out, other_);
            assertGt(firstMint_.out, 0);
            assertGt(secondMint_.out, 0);
            _execute(firstMint_);
            assertEq(vault.balanceOf(address(0)), 1_000);
            _execute(secondMint_);
            _execute(exit_);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_stateQuoteFullBookValuationUsesIndependentCopy() public {
        _external(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 1_000_000 ether);
        _bundle(100_000 ether);
        Operation memory mint_ = _project(quote.quoteExchangeState(), address(token0), 100 ether, address(vault));
        bytes32 preserved_ = keccak256(mint_.next);
        for (uint256 side_; side_ < 2; ++side_) {
            Operation memory valuation_ = _project(
                mint_.next, address(vault), quote.quoteExchangeSupply(mint_.next),
                side_ == 0 ? address(token0) : address(token1)
            );
            assertGt(valuation_.out, 0);
            assertEq(quote.quoteExchangeSupply(valuation_.next), 0);
            assertEq(keccak256(mint_.next), preserved_);
        }
        Operation memory actualExit_ = _project(mint_.next, address(vault), mint_.out, address(token1));
        _execute(mint_);
        _execute(actualExit_);
    }

    function test_stateQuoteRejectedDepositDiscardsCandidateSwapEffects() public {
        _bundle(100_000 ether);
        _fund(address(this), 10 ** 60, 10 ** 60);
        bytes memory state_ = quote.quoteExchangeState();
        for (uint256 side_; side_ < 2; ++side_) {
            address input_ = side_ == 0 ? address(token0) : address(token1);
            Operation memory tiny_ = _project(state_, input_, 1, address(vault));
            Operation memory partial_ = _project(state_, input_, 10 ** 60, address(vault));
            assertEq(tiny_.out, 0);
            assertEq(tiny_.refund, 1);
            assertEq(tiny_.next, state_);
            assertEq(partial_.out, 0);
            assertEq(partial_.refund, 10 ** 60);
            assertEq(partial_.next, state_);
            _execute(tiny_);
            _execute(partial_);
        }
        Operation memory accepted_ = _project(state_, address(token0), 10 ether, address(vault));
        assertGt(accepted_.out, 0);
        _execute(accepted_);
    }

    function test_stateQuotePartialPassThroughCarriesExecutedPrice() public {
        _bundle(10_000);
        _fund(address(this), 10 ** 30, 10 ** 30);
        for (uint256 side_; side_ < 2; ++side_) {
            uint256 snapshot_ = vm.snapshotState();
            address input_ = side_ == 0 ? address(token0) : address(token1);
            address output_ = side_ == 0 ? address(token1) : address(token0);
            Operation memory partial_ = _project(quote.quoteExchangeState(), input_, 10 ** 30, output_);
            assertGt(partial_.out, 0);
            assertGt(partial_.refund, 0);
            Operation memory reverse_ = _project(partial_.next, output_, 1_000, input_);
            _execute(partial_);
            _execute(reverse_);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_stateQuoteUnavailableAndUnsupportedLeaveStateUnchanged() public {
        bytes memory empty_ = quote.quoteExchangeState();
        Operation memory genesis_ = _project(empty_, address(token0), 1, address(vault));
        assertEq(genesis_.out, 0);
        assertEq(genesis_.refund, 0);
        assertEq(genesis_.next, empty_);
        _bundle(100_000 ether);
        bytes memory state_ = quote.quoteExchangeState();
        Operation memory unsupported_ = _project(state_, address(0xBEEF), 1 ether, address(vault));
        assertEq(unsupported_.out, 0);
        assertEq(unsupported_.refund, 0);
        assertEq(unsupported_.next, state_);
        Operation memory impossible_ = _project(state_, address(vault), quote.quoteExchangeSupply(state_), address(token0));
        assertEq(impossible_.out, 0, "no external liquidity can buy the entire unwanted side");
        assertEq(impossible_.refund, 0);
        assertEq(impossible_.next, state_);
        _assertState(state_);
    }

    function test_stateQuoteRejectsForeignDomainVersionAndMalformedLength() public {
        bytes memory state_ = quote.quoteExchangeState();
        Types.QuoteState memory changed_ = abi.decode(state_, (Types.QuoteState));
        changed_.version = 2;
        _invalid(abi.encode(changed_));
        changed_ = abi.decode(state_, (Types.QuoteState));
        changed_.domain = bytes32(uint256(changed_.domain) ^ 1);
        _invalid(abi.encode(changed_));
        _invalid("");
        _invalid(bytes.concat(state_, hex"00"));
        PoolKey memory otherKey_ = key;
        otherKey_.fee = 500;
        pool.initialize(otherKey_, uint160(1) << 96);
        IStandardExchangeStateQuote other_ = IStandardExchangeStateQuote(package.deployVault(IPackage.PkgArgs(otherKey_)));
        _invalid(other_.quoteExchangeState());
        vm.chainId(block.chainid + 1);
        _invalid(state_);
    }

    function _project(bytes memory state_, address input_, uint256 amount_, address output_)
        internal view returns (Operation memory operation_)
    {
        operation_.tokenIn = input_;
        operation_.amountIn = amount_;
        operation_.tokenOut = output_;
        (operation_.next, operation_.out, operation_.refund) =
            quote.quoteExchangeIn(state_, IERC20(input_), amount_, IERC20(output_));
    }

    function _execute(Operation memory operation_) internal {
        uint256 beforeIn_ = IERC20(operation_.tokenIn).balanceOf(address(this));
        address recipient_ = address(0xCAFE);
        // Keep minted shares in the caller's ledger for later projected redemptions.
        if (operation_.tokenOut == address(vault)) recipient_ = address(this);
        uint256 beforeOut_ = IERC20(operation_.tokenOut).balanceOf(recipient_);
        (uint256 out_, uint256 refund_) = vault.exchangeIn(
            operation_.tokenIn, operation_.amountIn, operation_.tokenOut,
            operation_.out, recipient_, false, block.timestamp
        );
        assertEq(out_, operation_.out, "evolving quote receipt");
        assertEq(refund_, operation_.refund, "evolving quote refund");
        assertEq(IERC20(operation_.tokenOut).balanceOf(recipient_) - beforeOut_, out_);
        assertEq(beforeIn_ - IERC20(operation_.tokenIn).balanceOf(address(this)), operation_.amountIn - refund_);
        _assertState(operation_.next);
    }

    function _assertState(bytes memory expected_) internal view {
        Types.QuoteState memory projected_ = abi.decode(expected_, (Types.QuoteState));
        assertEq(quote.quoteExchangeSupply(expected_), vault.totalSupply(), "issued supply");
        assertEq(projected_.positionLiquidity, vault.positionLiquidity(), "own position");
        assertEq(projected_.booked[0], uint256(vm.load(address(vault), Repo.STORAGE_SLOT)), "booked zero");
        assertEq(projected_.booked[1], uint256(vm.load(address(vault), bytes32(uint256(Repo.STORAGE_SLOT) + 1))), "booked one");
        (uint160 price_, int24 tick_,, ) = StateLibrary.getSlot0(pool, key.toId());
        assertEq(projected_.sqrtPriceX96, price_, "pool price");
        assertEq(projected_.tick, tick_, "pool tick");
        assertEq(projected_.poolLiquidity, StateLibrary.getLiquidity(pool, key.toId()), "active liquidity");
        // Includes global growth, both boundary outside-growth counters, and the
        // position's fee checkpoints. Each is independently re-read from PoolManager.
        assertEq(expected_, quote.quoteExchangeState(), "complete hypothetical state");
    }

    function _invalid(bytes memory state_) internal {
        vm.expectRevert(IStandardExchangeStateQuote.InvalidQuoteState.selector);
        quote.quoteExchangeSupply(state_);
        vm.expectRevert(IStandardExchangeStateQuote.InvalidQuoteState.selector);
        quote.quoteExchangeIn(state_, IERC20(address(token0)), 1 ether, IERC20(address(vault)));
    }

    function _bundle(uint256 amount_) internal {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = amount_;
        amounts_[1] = amount_;
        vault.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function _trade(address input_, address output_, uint256 amount_) internal {
        vault.exchangeIn(input_, amount_, output_, 0, address(this), false, block.timestamp);
    }

    function _external(int24 lower_, int24 upper_, uint128 liquidity_) internal {
        FullSpreadV4ExternalLp lp_ = new FullSpreadV4ExternalLp(pool);
        _fund(address(lp_), 2_000_000 ether, 2_000_000 ether);
        lp_.add(key, lower_, upper_, liquidity_);
    }
}

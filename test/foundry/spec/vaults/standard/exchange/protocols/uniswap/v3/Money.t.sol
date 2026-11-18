// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV3MintCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeBundleIn} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";

/// @notice Real proxy funding, fixed-swap minting, withdrawal and callback boundary coverage.
/// @dev Direct real pool swaps under reverted snapshots independently price the expected
/// outcomes. No quoter/planner implementation is used as the expected-value oracle.
contract UniswapV3FullSpreadMoneyTest is TestBase_UniswapV3FullSpreadAccounting {
    struct EntryExpectation {
        uint256 swapIn;
        uint256 swapOut;
        uint128 liquidity;
        uint256 used0;
        uint256 used1;
        uint256 shares;
        uint256 refund;
        uint256 fee0;
        uint256 fee1;
    }

    /// @notice First and later deposits use exactly one 49% swap and consume all its output in the mint.
    function testFuzz_entryMatchesIndependentPoolAndMintMath(bool zeroForOne_, bool established_) public {
        if (established_) _seedVault(SEED);
        uint256 amount_ = 10_000_000_101;
        EntryExpectation memory expected_ = _entryExpectation(amount_, zeroForOne_);
        IERC20 input_ = IERC20(zeroForOne_ ? address(token0) : address(token1));
        uint256 beforeInput_ = input_.balanceOf(bob);
        uint256 beforeSupply_ = vault.totalSupply();
        (uint256 preview_, uint256 previewRefund_) = vault.previewExchangeIn(input_, amount_, IERC20(address(vault)));
        vm.recordLogs();

        vm.prank(bob);
        (uint256 shares_, uint256 refund_) = vault.exchangeIn(
            input_, amount_, IERC20(address(vault)), expected_.shares, recipient, false, block.timestamp
        );

        PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
        assertEq(shares_, expected_.shares);
        assertEq(preview_, expected_.shares);
        assertEq(refund_, expected_.refund);
        assertEq(previewRefund_, expected_.refund);
        assertEq(vault.balanceOf(recipient), expected_.shares);
        assertEq(beforeInput_ - input_.balanceOf(bob), amount_ - expected_.refund);
        assertEq(trace_.swaps, 1);
        assertEq(uint256(zeroForOne_ ? trace_.delta0 : trace_.delta1), amount_ * 49 / 100);
        assertEq(uint256(-(zeroForOne_ ? trace_.delta1 : trace_.delta0)), expected_.swapOut);
        assertEq(trace_.mints, 1);
        assertEq(trace_.mintedLiquidity, expected_.liquidity);
        assertEq(trace_.mint0, expected_.used0);
        assertEq(trace_.mint1, expected_.used1);
        assertEq(zeroForOne_ ? trace_.mint1 : trace_.mint0, expected_.swapOut);
        assertEq(vault.totalSupply() - beforeSupply_, expected_.liquidity);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, expected_.fee0);
        assertEq(booked1_, expected_.fee1);
        _assertSettled();
    }

    /// @notice Zero split, zero swap output and incomplete huge swaps never partially execute a mint.
    function testFuzz_unformableEntryRefundsExistingSupplyButFailsGenesis(bool established_, uint8 reason_) public {
        if (established_) _seedVault(SEED);
        uint256 amount_ = reason_ % 3 == 0 ? 1 : reason_ % 3 == 1 ? 3 : 1e40;
        uint256 before_ = token0.balanceOf(bob);
        uint256 supply_ = vault.totalSupply();
        uint128 liquidity_ = _positionLiquidity();
        (uint256 preview_,) = vault.previewExchangeIn(IERC20(address(token0)), amount_, IERC20(address(vault)));
        assertEq(preview_, 0);
        if (!established_) {
            vm.expectRevert(IVault.MinLiquidityNotMet.selector);
            vm.prank(bob);
            vault.exchangeIn(IERC20(address(token0)), amount_, IERC20(address(vault)), 0, bob, false, block.timestamp);
        } else {
            vm.recordLogs();
            vm.prank(bob);
            (uint256 shares_, uint256 refund_) = vault.exchangeIn(
                IERC20(address(token0)), amount_, IERC20(address(vault)), 0, bob, false, block.timestamp
            );
            assertEq(shares_, 0);
            assertEq(refund_, amount_);
            PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
            assertEq(trace_.swaps, 0);
            assertEq(trace_.mints, 0);
        }
        assertEq(token0.balanceOf(bob), before_);
        assertEq(vault.totalSupply(), supply_);
        assertEq(_positionLiquidity(), liquidity_);
        _assertSettled();
    }

    /// @notice A fully fillable swap is still rejected when its output cannot all become liquidity.
    function testFuzz_fullySpentSwapWhoseOutputCannotBeConsumedNeverExecutes(bool established_, bool zeroForOne_) public {
        if (established_) _seedVault(SEED);
        uint256 amount_ = 1e18;
        IERC20 input_ = IERC20(zeroForOne_ ? address(token0) : address(token1));
        uint256 snapshot_ = vm.snapshotState();
        uint256 directBalance_ = input_.balanceOf(address(this));
        uint256 output_ = _externalSwapExactIn(pool, zeroForOne_, amount_ * 49 / 100);
        assertEq(input_.balanceOf(address(this)), directBalance_, "the independent swap spends its full funded input");
        (uint160 price_,,,,,,) = pool.slot0();
        uint128 candidate_ = _expectedLiquidity(
            price_, zeroForOne_ ? amount_ * 51 / 100 : output_,
            zeroForOne_ ? output_ : amount_ * 51 / 100
        );
        (uint256 used0_, uint256 used1_) = _amounts(price_, candidate_, true);
        assertLt(zeroForOne_ ? used1_ : used0_, output_, "mint cannot consume all received output");
        assertTrue(vm.revertToState(snapshot_));
        uint256 before_ = input_.balanceOf(bob);
        (uint256 quoted_,) = vault.previewExchangeIn(input_, amount_, IERC20(address(vault)));
        assertEq(quoted_, 0);
        vm.recordLogs();
        if (!established_) vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        vm.prank(bob);
        (uint256 minted_, uint256 refunded_) = vault.exchangeIn(
            input_, amount_, IERC20(address(vault)), 0, bob, false, block.timestamp
        );
        if (established_) {
            assertEq(minted_, 0);
            assertEq(refunded_, amount_);
        }
        PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mints, 0);
        assertEq(input_.balanceOf(bob), before_);
        _assertSettled();
    }

    /// @notice A positive minimum rejects the zero-share refund outcome and rolls back its pull.
    function test_refundOnlyEntryRejectsPositiveMinimum() public {
        _seedVault(SEED);
        uint256 before_ = token0.balanceOf(bob);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        vm.prank(bob);
        vault.exchangeIn(IERC20(address(token0)), 3, IERC20(address(vault)), 1, bob, false, block.timestamp);
        assertEq(token0.balanceOf(bob), before_);
        assertEq(vault.totalSupply(), SEED);
        _assertSettled();
    }

    /// @notice Expired calls fail before funding or any pool interaction.
    function test_deadlineFailureLeavesFundingAndPoolUntouched() public {
        vm.warp(100);
        uint256 before_ = token0.balanceOf(bob);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 99, 100));
        vm.prank(bob);
        vault.exchangeIn(
            IERC20(address(token0)), 1e9, IERC20(address(vault)), 0, bob, false, 99
        );
        assertEq(token0.balanceOf(bob), before_);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(pool.liquidity(), EXTERNAL_LIQUIDITY);
        _assertSettled();
    }

    /// @notice EOA staging does not bypass the public contract-only pretransfer guard.
    function test_eoaPretransferIsRejectedWithoutConsumingStagedTokens() public {
        vm.prank(bob);
        token0.transfer(address(vault), 10000);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vm.prank(bob);
        vault.exchangeIn(IERC20(address(token0)), 10000, IERC20(address(vault)), 0, bob, true, block.timestamp);
        assertEq(token0.balanceOf(address(vault)), 10000);
        assertEq(vault.totalSupply(), 0);
    }

    /// @notice Oversized declared credit never pulls a shortfall: empty supply fails, live supply refunds credit only.
    function testFuzz_oversizedPretransferUsesGenesisPrecedence(bool established_, bool positiveMinimum_) public {
        if (established_) _seedVault(SEED);
        token0.transfer(address(vault), 7);
        uint256 before_ = token0.balanceOf(address(this));
        uint256 minimum_ = positiveMinimum_ ? 1 : 0;
        if (!established_) vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        else if (positiveMinimum_) {
            vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        }
        (uint256 shares_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(token0)), 8, IERC20(address(vault)), minimum_, recipient, true, block.timestamp
        );
        if (established_ && !positiveMinimum_) {
            assertEq(shares_, 0);
            assertEq(refund_, 7);
            assertEq(token0.balanceOf(address(this)), before_ + 7);
            assertEq(token0.balanceOf(address(vault)), 0);
        } else {
            assertEq(token0.balanceOf(address(this)), before_);
            assertEq(token0.balanceOf(address(vault)), 7);
        }
        assertEq(vault.totalSupply(), established_ ? SEED : 0);
        _assertSettled();
    }

    /// @notice A funded pretransfer spends its declared maximum only and leaves both unrelated credit and booked custody.
    function test_pretransferBudgetExcludesBookAndUndeclaredCredit() public {
        _seedVault(SEED);
        (uint256 oldFees0_,) = _poolFees(1e18, 0);
        _bundleIn(bob, SEED, SEED);
        uint256 amount_ = 10_000_000_101;
        EntryExpectation memory expected_ = _entryExpectation(amount_, true);
        token0.transfer(address(vault), amount_ + 11);
        uint256 before_ = token0.balanceOf(address(this));

        (uint256 shares_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(token0)), amount_, IERC20(address(vault)), expected_.shares, recipient, true, block.timestamp
        );

        assertEq(shares_, expected_.shares);
        assertEq(refund_, expected_.refund);
        assertEq(token0.balanceOf(address(this)), before_ + expected_.refund);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, oldFees0_ + expected_.fee0);
        assertEq(booked1_, expected_.fee1);
        assertEq(token0.balanceOf(address(vault)) - booked0_, 11);
        assertEq(token1.balanceOf(address(vault)) - booked1_, 0);
        _assertSettled();
    }

    /// @notice An over-maximum cannot refund other holders' booked funds.
    function test_oversizedPretransferRefundsOnlyUnbookedBalance() public {
        _seedVault(SEED);
        (uint256 fees0_,) = _poolFees(1e20, 0);
        _bundleIn(bob, SEED, SEED);
        token0.transfer(address(vault), 7);
        uint256 before_ = token0.balanceOf(address(this));

        (uint256 shares_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(token0)), fees0_ + 8, IERC20(address(vault)), 0, recipient, true, block.timestamp
        );

        assertEq(shares_, 0);
        assertEq(refund_, 7);
        assertEq(token0.balanceOf(address(this)), before_ + 7);
        assertEq(token0.balanceOf(address(vault)), fees0_);
        (uint256 booked0_,) = _booked();
        assertEq(booked0_, fees0_);
        assertEq(vault.totalSupply(), 2 * SEED);
        _assertSettled();
    }

    /// @notice Either bundle maximum exceeding credit fails atomically before processing the other leg.
    function test_bundleOverMaximumProcessesNeitherLeg() public {
        token0.transfer(address(vault), 10);
        token1.transfer(address(vault), 3);
        vm.expectRevert(bytes(""));
        IStandardExchangeBundleIn(address(vault)).exchangeBundleInForSingleOut(
            _amountArray(10, 4), address(vault), 0, recipient, true, block.timestamp
        );
        assertEq(token0.balanceOf(address(vault)), 10);
        assertEq(token1.balanceOf(address(vault)), 3);
        assertEq(vault.totalSupply(), 0);
        assertEq(_positionLiquidity(), 0);
        _assertSettled();
    }

    /// @notice A partially spent pass-through matches a real pool swap and refunds the remaining input without mint fees.
    function testFuzz_partialPassThroughMatchesRealPoolReceipt(bool zeroForOne_) public {
        _seedVault(SEED);
        _setUsageFee(1e18);
        uint256 amount_ = 1e40;
        uint256 snapshot_ = vm.snapshotState();
        (int256 delta0_, int256 delta1_) = pool.swap(
            address(this), zeroForOne_, int256(amount_),
            zeroForOne_ ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(address(this))
        );
        uint256 spent_ = uint256(zeroForOne_ ? delta0_ : delta1_);
        uint256 expected_ = uint256(-(zeroForOne_ ? delta1_ : delta0_));
        assertLt(spent_, amount_);
        assertTrue(vm.revertToState(snapshot_));
        IERC20 input_ = IERC20(zeroForOne_ ? address(token0) : address(token1));
        IERC20 output_ = IERC20(zeroForOne_ ? address(token1) : address(token0));
        (uint256 preview_, uint256 previewRefund_) = vault.previewExchangeIn(input_, amount_, output_);
        uint256 beforeInput_ = input_.balanceOf(bob);
        uint256 beforeOutput_ = output_.balanceOf(recipient);

        vm.prank(bob);
        (uint256 received_, uint256 refund_) =
            vault.exchangeIn(input_, amount_, output_, expected_, recipient, false, block.timestamp);

        assertEq(received_, expected_);
        assertEq(preview_, expected_);
        assertEq(refund_, amount_ - spent_);
        assertEq(previewRefund_, amount_ - spent_);
        assertEq(beforeInput_ - input_.balanceOf(bob), spent_);
        assertEq(output_.balanceOf(recipient) - beforeOutput_, expected_);
        assertEq(vault.totalSupply(), SEED);
        assertEq(vault.balanceOf(address(indexedexManager.feeTo())), 0);
        _assertSettled();
    }

    /// @notice The exit quote prices its entire opposing principal/fee claim against liquidity after the burn.
    function testFuzz_exitReceiptMatchesIndependentPostBurnSwap(bool want0_) public {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e18, 2e18);
        uint256 shares_ = SEED / 4;
        uint256 claim0_ = fee0_ * shares_ / SEED;
        uint256 claim1_ = fee1_ * shares_ / SEED;
        uint256 wanted_ = shares_ - 1 + (want0_ ? claim0_ : claim1_);
        uint256 opposing_ = shares_ - 1 + (want0_ ? claim1_ : claim0_);
        uint256 snapshot_ = vm.snapshotState();
        // The public bundle route performs the real removal, but its return is NOT the expectation.
        _bundleOut(alice, shares_, recipient, false);
        (int256 delta0_, int256 delta1_) = pool.swap(
            address(this), !want0_, int256(opposing_),
            want0_ ? TickMath.MAX_SQRT_RATIO - 1 : TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(address(this))
        );
        assertEq(uint256(want0_ ? delta1_ : delta0_), opposing_);
        uint256 expected_ = wanted_ + uint256(-(want0_ ? delta0_ : delta1_));
        assertTrue(vm.revertToState(snapshot_));
        IERC20 output_ = IERC20(want0_ ? address(token0) : address(token1));
        (uint256 preview_,) = vault.previewExchangeIn(IERC20(address(vault)), shares_, output_);
        uint256 before_ = output_.balanceOf(recipient);

        vm.prank(alice);
        (uint256 received_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(vault)), shares_, output_, expected_, recipient, false, block.timestamp
        );

        assertEq(preview_, expected_);
        assertEq(received_, expected_);
        assertEq(output_.balanceOf(recipient) - before_, expected_);
        assertEq(refund_, 0);
        assertEq(_positionLiquidity(), SEED - shares_);
        assertEq(vault.balanceOf(alice), SEED - 1000 - shares_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fee0_ - claim0_);
        assertEq(booked1_, fee1_ - claim1_);
        _assertSettled();
    }

    /// @notice An opposing claim exceeding post-burn pool capacity previews zero and cannot burn shares or custody.
    function testFuzz_incompleteOpposingExitRollsBackEverything(bool want0_) public {
        _freshMarket(false);
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(want0_ ? 0 : 1e30, want0_ ? 1e30 : 0);
        _bundleIn(bob, 1001, 1001);
        uint256 shares_ = SEED - 1000;
        IERC20 output_ = IERC20(want0_ ? address(token0) : address(token1));
        uint256 before_ = output_.balanceOf(recipient);
        (uint256 preview_,) = vault.previewExchangeIn(IERC20(address(vault)), shares_, output_);
        assertEq(preview_, 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 0, 0));

        vm.prank(alice);
        vault.exchangeIn(IERC20(address(vault)), shares_, output_, 0, recipient, false, block.timestamp);

        assertEq(vault.balanceOf(alice), shares_);
        assertEq(vault.totalSupply(), SEED + 1001);
        assertEq(_positionLiquidity(), SEED + 1001);
        assertEq(output_.balanceOf(recipient), before_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fee0_);
        assertEq(booked1_, fee1_);
        assertEq(token0.balanceOf(address(vault)), fee0_);
        assertEq(token1.balanceOf(address(vault)), fee1_);
        (uint160 price_,,,,,,) = pool.slot0();
        assertEq(price_, Q96);
        _assertSettled();
    }

    /// @notice pretransferred share exits still burn the contract caller's shares, leaving parked shares intact.
    function test_pretransferredBundleExitBurnsCallerSharesOnly() public {
        _seedVault(SEED);
        vm.startPrank(alice);
        vault.transfer(address(this), 1e6);
        vault.transfer(address(vault), 7e6);
        vm.stopPrank();

        uint256[] memory amounts_ = _bundleOut(address(this), 1e6, recipient, true);

        assertEq(amounts_[0], 1e6 - 1);
        assertEq(amounts_[1], 1e6 - 1);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(vault)), 7e6);
        assertEq(vault.totalSupply(), SEED - 1e6);
        _assertSettled();
    }

    /// @notice Shares merely delivered to the vault never fund a caller-owned single-token exit.
    function test_parkedSharesAreNotSingleExitCredit() public {
        _seedVault(SEED);
        vm.prank(alice);
        vault.transfer(address(vault), 1234);
        vm.expectRevert(abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 1234
        ));
        vault.exchangeIn(
            IERC20(address(vault)), 1234, IERC20(address(token0)), 0, recipient, true, block.timestamp
        );
        assertEq(vault.balanceOf(address(vault)), 1234);
        assertEq(vault.totalSupply(), SEED);
    }

    /// @notice Exact boundaries and outside prices accept the wanted token without swapping, even at zero active liquidity.
    function testFuzz_boundaryWantedTokenAddsWithoutSwap(bool low_, bool outside_) public {
        _seedVault(SEED);
        uint160 boundary_ = TickMath.getSqrtRatioAtTick(low_ ? lower : upper);
        uint160 price_ = outside_ ? (low_ ? boundary_ - 1 : boundary_ + 1) : boundary_;
        _swapTo(price_);
        assertEq(pool.liquidity(), 0);
        uint256 amount_ = 1e25;
        uint128 expectedLiquidity_ = _expectedLiquidity(price_, low_ ? amount_ : 0, low_ ? 0 : amount_);
        (uint256 used0_, uint256 used1_) = _amounts(price_, expectedLiquidity_, true);
        IERC20 input_ = IERC20(low_ ? address(token0) : address(token1));
        (uint256 preview_,) = vault.previewExchangeIn(input_, amount_, IERC20(address(vault)));
        vm.recordLogs();

        vm.prank(bob);
        (uint256 shares_, uint256 refund_) = vault.exchangeIn(
            input_, amount_, IERC20(address(vault)), 1, bob, false, block.timestamp
        );

        PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
        assertGt(expectedLiquidity_, 0);
        assertEq(shares_, expectedLiquidity_);
        assertEq(preview_, expectedLiquidity_);
        assertEq(refund_, amount_ - (low_ ? used0_ : used1_));
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mints, 1);
        assertEq(_positionLiquidity(), SEED + expectedLiquidity_);
        _assertSettled();
    }

    /// @notice The unwanted boundary token is fully refunded without a pool action.
    function testFuzz_boundaryUnwantedTokenRefundsWholeInput(bool low_) public {
        _seedVault(SEED);
        _swapTo(TickMath.getSqrtRatioAtTick(low_ ? lower : upper));
        IERC20 input_ = IERC20(low_ ? address(token1) : address(token0));
        uint256 before_ = input_.balanceOf(bob);
        vm.recordLogs();

        vm.prank(bob);
        (uint256 shares_, uint256 refund_) =
            vault.exchangeIn(input_, 1e9, IERC20(address(vault)), 0, bob, false, block.timestamp);

        PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
        assertEq(shares_, 0);
        assertEq(refund_, 1e9);
        assertEq(input_.balanceOf(bob), before_);
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mints, 0);
        assertEq(_positionLiquidity(), SEED);
        _assertSettled();
    }

    /// @notice An initialized interior pool with zero active liquidity cannot bootstrap a one-sided swap.
    function test_zeroActiveInteriorOneSidedGenesisFails() public {
        _freshMarket(false);
        assertEq(pool.liquidity(), 0);
        (uint256 preview_,) = vault.previewExchangeIn(IERC20(address(token0)), 1e9, IERC20(address(vault)));
        assertEq(preview_, 0);
        uint256 before_ = token0.balanceOf(bob);
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        vm.prank(bob);
        vault.exchangeIn(IERC20(address(token0)), 1e9, IERC20(address(vault)), 0, bob, false, block.timestamp);
        assertEq(token0.balanceOf(bob), before_);
        assertEq(vault.totalSupply(), 0);
        assertEq(_positionLiquidity(), 0);
    }

    /// @notice A both-token genesis can supply liquidity without needing an entry swap.
    function test_zeroActiveInteriorBundleGenesisBootstrapsPool() public {
        _freshMarket(false);
        vm.recordLogs();
        uint256 shares_ = _seedVault(SEED);
        assertEq(shares_, SEED - 1000);
        assertEq(pool.liquidity(), SEED);
        assertEq(_poolTrace(vm.getRecordedLogs()).swaps, 0);
        _assertSettled();
    }

    /// @notice Both foreign callbacks reject; even the pool identity has no spending authority outside an operation.
    function test_callbacksRequireBoundPoolAndAnOpenBudget() public {
        _seedVault(SEED);
        vm.expectRevert(Common.UniswapV3Exchange_CallbackNotAuthorized.selector);
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(1, 1, "");
        vm.expectRevert(Common.UniswapV3Exchange_CallbackNotAuthorized.selector);
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(1, -1, "");
        vm.expectRevert(IVault.SettlementMismatch.selector);
        vm.prank(address(pool));
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(1, 0, "");
        vm.expectRevert(IVault.SettlementMismatch.selector);
        vm.prank(address(pool));
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(0, 1, "");
        assertEq(vault.totalSupply(), SEED);
        _assertSettled();
    }

    /// @notice The fixed entry swap remains fully spent across adjacent initialized dust ticks.
    function testFuzz_dustTickEntryMatchesIndependentPoolReceipt(bool zeroForOne_) public {
        _seedVault(SEED);
        _adjacentDustTicks();
        uint256 amount_ = 5e16;
        EntryExpectation memory expected_ = _entryExpectation(amount_, zeroForOne_);
        IERC20 input_ = IERC20(zeroForOne_ ? address(token0) : address(token1));
        (uint256 quoted_, uint256 quotedRefund_) = vault.previewExchangeIn(input_, amount_, IERC20(address(vault)));
        vm.recordLogs();
        vm.prank(bob);
        (uint256 minted_, uint256 refunded_) = vault.exchangeIn(
            input_, amount_, IERC20(address(vault)), expected_.shares, bob, false, block.timestamp
        );
        PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
        assertEq(trace_.swaps, 1);
        assertEq(uint256(zeroForOne_ ? trace_.delta0 : trace_.delta1), amount_ * 49 / 100);
        assertEq(uint256(-(zeroForOne_ ? trace_.delta1 : trace_.delta0)), expected_.swapOut);
        assertEq(zeroForOne_ ? trace_.mint1 : trace_.mint0, expected_.swapOut);
        assertEq(minted_, expected_.shares);
        assertEq(quoted_, expected_.shares);
        assertEq(refunded_, expected_.refund);
        assertEq(quotedRefund_, expected_.refund);
        (, int24 tick_,,,,,) = pool.slot0();
        assertGt(zeroForOne_ ? -tick_ : tick_, 300, "cross several adjacent initialized ticks");
        _assertSettled();
    }

    /// @notice Opposing exit quotes include both the burn and every crossed initialized dust tick.
    function testFuzz_dustTickExitQuotesAfterRemoval(bool want0_) public {
        _seedVault(1e17);
        _adjacentDustTicks();
        uint256 shares_ = 8e16;
        uint256 principal_ = shares_ - 1;
        uint256 snapshot_ = vm.snapshotState();
        _bundleOut(alice, shares_, recipient, false);
        (int256 delta0_, int256 delta1_) = pool.swap(
            address(this), !want0_, int256(principal_),
            want0_ ? TickMath.MAX_SQRT_RATIO - 1 : TickMath.MIN_SQRT_RATIO + 1, abi.encode(address(this))
        );
        assertEq(uint256(want0_ ? delta1_ : delta0_), principal_, "entire opposing principal is spent");
        uint256 expected_ = principal_ + uint256(-(want0_ ? delta0_ : delta1_));
        assertTrue(vm.revertToState(snapshot_));
        IERC20 output_ = IERC20(want0_ ? address(token0) : address(token1));
        (uint256 quoted_,) = vault.previewExchangeIn(IERC20(address(vault)), shares_, output_);
        uint256 before_ = output_.balanceOf(recipient);
        vm.prank(alice);
        (uint256 paid_,) = vault.exchangeIn(
            IERC20(address(vault)), shares_, output_, expected_, recipient, false, block.timestamp
        );
        assertEq(quoted_, expected_);
        assertEq(paid_, expected_);
        assertEq(output_.balanceOf(recipient) - before_, expected_);
        (, int24 tick_,,,,,) = pool.slot0();
        assertGt(want0_ ? tick_ : -tick_, 1_000);
        _assertSettled();
    }

    function _adjacentDustTicks() private {
        for (int24 i_ = 1; i_ <= 20; ++i_) {
            pool.mint(address(this), -i_ * 60, (-i_ + 1) * 60, 1e6, abi.encode(address(this)));
            pool.mint(address(this), (i_ - 1) * 60, i_ * 60, 1e6, abi.encode(address(this)));
        }
    }

    function _entryExpectation(uint256 amount_, bool zeroForOne_)
        private
        returns (EntryExpectation memory expected_)
    {
        uint256 supply_ = vault.totalSupply();
        (uint128 own_, uint256 last0_, uint256 last1_, uint128 owed0_, uint128 owed1_) =
            pool.positions(_positionKey());
        uint256 snapshot_ = vm.snapshotState();
        expected_.swapIn = amount_ * 49 / 100;
        expected_.swapOut = _externalSwapExactIn(pool, zeroForOne_, expected_.swapIn);
        (uint160 price_,,,,,,) = pool.slot0();
        expected_.liquidity = _expectedLiquidity(
            price_, zeroForOne_ ? amount_ - expected_.swapIn : expected_.swapOut,
            zeroForOne_ ? expected_.swapOut : amount_ - expected_.swapIn
        );
        (expected_.used0, expected_.used1) = _amounts(price_, expected_.liquidity, true);
        assertEq(zeroForOne_ ? expected_.used1 : expected_.used0, expected_.swapOut, "fixture consumes output");
        expected_.refund = amount_ - expected_.swapIn - (zeroForOne_ ? expected_.used0 : expected_.used1);
        expected_.shares = supply_ == 0
            ? uint256(expected_.liquidity) - 1000
            : FullMath.mulDiv(expected_.liquidity, supply_, own_);
        // These cases stay strictly inside never-crossed full-range endpoints.
        expected_.fee0 = owed0_ + FullMath.mulDiv(pool.feeGrowthGlobal0X128() - last0_, own_, uint256(1) << 128);
        expected_.fee1 = owed1_ + FullMath.mulDiv(pool.feeGrowthGlobal1X128() - last1_, own_, uint256(1) << 128);
        assertTrue(vm.revertToState(snapshot_));
    }
}

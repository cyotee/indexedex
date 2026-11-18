// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";

/// @notice Accounting contracts exercised on a manager-registry deployed diamond.
/// @dev Expectations come from funded liquidity, integer formulas and real pool fees,
/// never the planner or the preview under test. Legacy sleeve suites do not own these rules.
contract UniswapV3FullSpreadAccountingTest is TestBase_UniswapV3FullSpreadAccounting {
    /// @notice Direct custody cannot inflate the fixed zero-address genesis floor or reserves.
    function test_genesisUsesRawLiquidityAndIgnoresStrayCustody() public {
        token0.transfer(address(vault), 17 ether);
        token1.transfer(address(vault), 29 ether);
        assertEq(vault.reserveOfToken(address(token0)), 0);
        assertEq(vault.reserveOfToken(address(token1)), 0);

        uint256 shares_ = _seedVault(SEED);

        assertEq(shares_, SEED - 1000);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.balanceOf(address(0xdead)), 0);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        assertEq(vault.reserveOfToken(address(token0)), SEED - 1);
        assertEq(vault.reserveOfToken(address(token1)), SEED - 1);
        assertEq(token0.balanceOf(address(vault)), 17 ether);
        assertEq(token1.balanceOf(address(vault)), 29 ether);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_ + booked1_, 0);
        _assertSettled();
    }

    /// @notice Exactly 1,000 supported liquidity is a failed genesis, not a refund success.
    function test_genesisAtFloorRevertsAllFunding() public {
        uint256 before0_ = token0.balanceOf(alice);
        uint256 before1_ = token1.balanceOf(alice);
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        _bundleIn(alice, 1000, 1000);
        assertEq(token0.balanceOf(alice), before0_);
        assertEq(token1.balanceOf(alice), before1_);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(address(0)), 0);
        assertEq(_positionLiquidity(), 0);
        _assertSettled();
    }

    /// @notice First/later fees come out of gross, clamp at 30%, and never alter the oracle.
    function testFuzz_usageFeeIsDeductedAndClamped(uint256 fee_, bool established_) public {
        fee_ = bound(fee_, 0, 1e18);
        if (established_) _seedVault(SEED);
        _setUsageFee(fee_);
        address feeTo_ = address(indexedexManager.feeTo());
        uint256 gross_ = established_ ? SEED : SEED - 1000;
        uint256 expectedFee_ = gross_ * (fee_ > 3e17 ? 3e17 : fee_) / 1e18;
        uint256 beforeSupply_ = vault.totalSupply();
        (uint256 preview_,) = IStandardExchangeBundleIn(address(vault))
            .previewExchangeBundleInForSingleOut(_amountArray(SEED, SEED), address(vault));

        (uint256 shares_,) = _bundleIn(bob, SEED, SEED);

        assertEq(preview_, gross_ - expectedFee_);
        assertEq(shares_, gross_ - expectedFee_);
        assertEq(vault.balanceOf(bob), gross_ - expectedFee_);
        assertEq(vault.balanceOf(feeTo_), expectedFee_);
        assertEq(vault.totalSupply() - beforeSupply_, SEED);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(indexedexManager.usageFeeOfVault(address(vault)), fee_);
        _assertSettled();
    }

    /// @notice feeTo zero skips the fee without routing it to the permanent zero-address floor.
    function test_zeroFeeRecipientReceivesNoFeeMint() public {
        _setUsageFee(1e18);
        _setFeeRecipient(address(0));

        uint256 shares_ = _seedVault(SEED);

        assertEq(shares_, SEED - 1000);
        assertEq(vault.balanceOf(alice), SEED - 1000);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.totalSupply(), SEED);
        _assertSettled();
    }

    /// @notice The bundle minimum binds net shares after fees, not the pre-fee gross.
    function test_bundleMinimumUsesNetSharesAndRevertsFunding() public {
        _setUsageFee(3e17);
        uint256 gross_ = SEED - 1000;
        uint256 net_ = gross_ - gross_ * 3e17 / 1e18;
        uint256 before0_ = token0.balanceOf(bob);
        uint256 before1_ = token1.balanceOf(bob);
        vm.expectRevert(abi.encodeWithSelector(
            IStandardExchangeBundleIn.MinAmountNotMetAt.selector, 0, net_ + 1, net_
        ));
        vm.prank(bob);
        IStandardExchangeBundleIn(address(vault)).exchangeBundleInForSingleOut(
            _amountArray(SEED, SEED), address(vault), net_ + 1, recipient, false, block.timestamp
        );
        assertEq(token0.balanceOf(bob), before0_);
        assertEq(token1.balanceOf(bob), before1_);
        assertEq(vault.totalSupply(), 0);
        assertEq(_positionLiquidity(), 0);
        _assertSettled();
    }

    /// @notice A later mint prices only added liquidity against pre-add liquidity/supply.
    function test_laterMintUsesLiquidityRatioAfterUnpricedPoolDonation() public {
        _seedVault(SEED);
        // A real third party may mint directly to the vault's position without minting shares.
        pool.mint(address(vault), lower, upper, SEED, abi.encode(address(this)));
        uint256 expectedGross_ = uint256(SEED) * SEED / (2 * uint256(SEED));

        (uint256 shares_,) = _bundleIn(bob, SEED, SEED);

        assertEq(shares_, expectedGross_);
        assertEq(vault.totalSupply(), SEED + expectedGross_);
        assertEq(_positionLiquidity(), 3 * SEED);
        assertEq(vault.balanceOf(address(0)), 1000);
        _assertSettled();
    }

    /// @notice Both-token deposits maximize proportional liquidity and refund each excess without swapping.
    function test_bundleMintRefundsOnlyUnusedInputsWithoutSwap() public {
        _seedVault(SEED);
        uint256 before0_ = token0.balanceOf(bob);
        uint256 before1_ = token1.balanceOf(bob);
        (uint256 preview_, uint256[] memory previewRefunds_) = IStandardExchangeBundleIn(address(vault))
            .previewExchangeBundleInForSingleOut(_amountArray(7e9, 3e9), address(vault));
        vm.recordLogs();

        (uint256 shares_, uint256[] memory refunds_) = _bundleIn(bob, 7e9, 3e9);

        PoolTrace memory trace_ = _poolTrace(vm.getRecordedLogs());
        assertEq(shares_, 3e9);
        assertEq(preview_, 3e9);
        assertEq(refunds_[0], 4e9);
        assertEq(refunds_[1], 0);
        assertEq(previewRefunds_[0], 4e9);
        assertEq(previewRefunds_[1], 0);
        assertEq(before0_ - token0.balanceOf(bob), 3e9);
        assertEq(before1_ - token1.balanceOf(bob), 3e9);
        assertEq(trace_.swaps, 0);
        assertEq(trace_.mintedLiquidity, 3e9);
        assertEq(_positionLiquidity(), SEED + 3e9);
        _assertSettled();
    }

    /// @notice Stored owed plus unpoked growth is collected once and excluded from depositor credit.
    function test_incumbentStoredAndGrowthFeesBecomeBookedBeforeMint() public {
        _seedVault(SEED);
        (uint256 first0_, uint256 first1_) = _poolFees(1e18, 2e18);
        pool.mint(address(vault), lower, upper, 1, abi.encode(address(this)));
        (,,, uint128 stored0_, uint128 stored1_) = pool.positions(_positionKey());
        assertEq(stored0_, first0_);
        assertEq(stored1_, first1_);
        (uint256 second0_, uint256 second1_) = _poolFees(3e18, 4e18);
        uint256 fees0_ = first0_ + second0_;
        uint256 fees1_ = first1_ + second1_;
        assertEq(vault.reserveOfToken(address(token0)), SEED + fees0_);
        assertEq(vault.reserveOfToken(address(token1)), SEED + fees1_);
        uint256 expectedShares_ = uint256(SEED) * SEED / (SEED + 1);

        (uint256 shares_,) = _bundleIn(bob, SEED, SEED);

        assertEq(shares_, expectedShares_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fees0_);
        assertEq(booked1_, fees1_);
        assertEq(token0.balanceOf(address(vault)), fees0_);
        assertEq(token1.balanceOf(address(vault)), fees1_);
        assertEq(vault.reserveOfToken(address(token0)), 2 * SEED);
        assertEq(vault.reserveOfToken(address(token1)), 2 * SEED);
        (,,, stored0_, stored1_) = pool.positions(_positionKey());
        assertEq(stored0_, 0);
        assertEq(stored1_, 0);
        _assertSettled();
    }

    /// @notice A later mint dilutes booked claims using the enlarged supply, including the floor.
    function test_laterMintDilutesBookedClaimAndExitLeavesExactRemainder() public {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e20, 2e20);
        _bundleIn(bob, SEED, SEED);
        uint256 shares_ = 1e9;
        uint256 claim0_ = fee0_ * shares_ / (2 * SEED);
        uint256 claim1_ = fee1_ * shares_ / (2 * SEED);
        assertLt(claim0_, fee0_ * shares_ / SEED);
        assertLt(claim1_, fee1_ * shares_ / SEED);
        uint256 before0_ = token0.balanceOf(recipient);
        uint256 before1_ = token1.balanceOf(recipient);
        vm.recordLogs();

        uint256[] memory amounts_ = _bundleOut(alice, shares_, recipient, false);

        assertEq(amounts_[0], shares_ - 1 + claim0_);
        assertEq(amounts_[1], shares_ - 1 + claim1_);
        assertEq(token0.balanceOf(recipient) - before0_, amounts_[0]);
        assertEq(token1.balanceOf(recipient) - before1_, amounts_[1]);
        assertEq(_poolTrace(vm.getRecordedLogs()).swaps, 0);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fee0_ - claim0_);
        assertEq(booked1_, fee1_ - claim1_);
        assertEq(vault.totalSupply(), 2 * SEED - shares_);
        assertEq(vault.balanceOf(address(0)), 1000);
        _assertSettled();
    }

    /// @notice Unpaid fees are split at the pre-burn read, then only the remaining booked claim is payable.
    function test_bundleExitPaysFeesOnceAcrossSuccessiveBurns() public {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e20, 3e20);
        uint256 shares_ = SEED / 4;
        uint256 claim0_ = fee0_ * shares_ / SEED;
        uint256 claim1_ = fee1_ * shares_ / SEED;
        (uint256[] memory preview_,) = IStandardExchangeBundleOut(address(vault))
            .previewExchangeBundleOut(address(vault), shares_, _tokensOut());
        uint256[] memory first_ = _bundleOut(alice, shares_, recipient, false);
        assertEq(first_[0], shares_ - 1 + claim0_);
        assertEq(first_[1], shares_ - 1 + claim1_);
        assertEq(preview_[0], first_[0]);
        assertEq(preview_[1], first_[1]);
        uint256 next0_ = (fee0_ - claim0_) * shares_ / (SEED - shares_);
        uint256 next1_ = (fee1_ - claim1_) * shares_ / (SEED - shares_);

        uint256[] memory second_ = _bundleOut(alice, shares_, recipient, false);

        assertEq(second_[0], shares_ - 1 + next0_);
        assertEq(second_[1], shares_ - 1 + next1_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fee0_ - claim0_ - next0_);
        assertEq(booked1_, fee1_ - claim1_ - next1_);
        _assertSettled();
    }

    /// @notice Each output minimum is checked before a bundle exit can burn caller shares.
    function testFuzz_bundleExitChecksEachTokenMinimum(bool second_) public {
        _seedVault(SEED);
        uint256 shares_ = 1e9;
        uint256[] memory minima_ = _amountArray(shares_ - 1, shares_ - 1);
        minima_[second_ ? 1 : 0] = shares_;
        vm.expectRevert(abi.encodeWithSelector(
            IStandardExchangeBundleIn.MinAmountNotMetAt.selector, second_ ? 1 : 0, shares_, shares_ - 1
        ));
        vm.prank(alice);
        IStandardExchangeBundleOut(address(vault)).exchangeBundleOut(
            address(vault), shares_, _tokensOut(), minima_, recipient, false, block.timestamp
        );
        assertEq(vault.balanceOf(alice), SEED - 1000);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        _assertSettled();
    }

    /// @notice The smallest positive burn pays its nonzero booked claim, even when principal rounds to zero.
    /// @dev Organic S<=L makes a positive zero-liquidity burn unreachable. Here Lburn=1,
    /// but both rounded-down token principals are zero: this is the reachable dust case.
    function test_oneShareExitPaysBookedClaimWithZeroTokenPrincipal() public {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e24, 2e24);
        _bundleIn(bob, SEED, SEED);
        uint256 expected0_ = fee0_ / (2 * SEED);
        uint256 expected1_ = fee1_ / (2 * SEED);
        assertGt(expected0_, 0);
        assertGt(expected1_, 0);
        assertLe(vault.totalSupply(), _positionLiquidity(), "organic supply never exceeds deployed liquidity");
        assertGe(FullMath.mulDiv(_positionLiquidity(), 1, vault.totalSupply()), 1);

        uint256[] memory amounts_ = _bundleOut(alice, 1, recipient, false);

        assertEq(amounts_[0], expected0_);
        assertEq(amounts_[1], expected1_);
        assertEq(_positionLiquidity(), 2 * SEED - 1);
        assertEq(vault.totalSupply(), 2 * SEED - 1);
        _assertSettled();
    }

    /// @notice S<=L survives deposits, share donations, fee compounding and exits.
    /// @dev Thus a positive burn cannot remove zero liquidity; an interior full-range
    /// book with positive supply cannot have zero active pool liquidity either.
    function testFuzz_organicSupplyBoundMakesPositiveZeroLiquidityBurnUnreachable(uint256 shares_) public {
        _seedVault(SEED);
        _bundleIn(bob, SEED, SEED);
        address feeTo_ = address(indexedexManager.feeTo());
        vm.prank(alice);
        vault.transfer(feeTo_, 1000);
        vm.prank(feeTo_);
        IVault(address(vault)).donate(address(vault), 1000, false);
        assertLe(vault.totalSupply(), _positionLiquidity());
        _poolFees(SEED, SEED);
        vm.prank(feeTo_);
        IVault(address(vault)).compound();
        assertLe(vault.totalSupply(), _positionLiquidity());
        _bundleIn(bob, SEED, SEED);
        uint256 supply_ = vault.totalSupply();
        uint128 liquidity_ = _positionLiquidity();
        assertLe(supply_, liquidity_);
        assertGe(pool.liquidity(), liquidity_);
        shares_ = bound(shares_, 1, vault.balanceOf(bob));
        uint256 removal_ = FullMath.mulDiv(liquidity_, shares_, supply_);
        assertGe(removal_, 1);

        _bundleOut(bob, shares_, recipient, false);

        assertEq(_positionLiquidity(), uint256(liquidity_) - removal_);
        assertEq(vault.totalSupply(), supply_ - shares_);
        assertLe(vault.totalSupply(), _positionLiquidity());
        _assertSettled();
    }

    /// @notice Share tokens parked on the vault are custody, never reserves or additional caller burn credit.
    function test_shareTransferCreatesNeitherReservesNorLiquidity() public {
        _seedVault(SEED);
        uint256 before0_ = vault.reserveOfToken(address(token0));
        uint256 before1_ = vault.reserveOfToken(address(token1));

        vm.prank(alice);
        vault.transfer(address(vault), 1234);

        assertEq(vault.reserveOfToken(address(token0)), before0_);
        assertEq(vault.reserveOfToken(address(token1)), before1_);
        assertEq(vault.reserveOfToken(address(vault)), 0);
        assertEq(_positionLiquidity(), SEED);
        assertEq(vault.totalSupply(), SEED);
    }
}

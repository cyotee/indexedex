// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeSYExecutionAssertions} from "contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";
import {UniswapV3PoolLockProbe} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/helpers/UniswapV3PoolLockProbe.sol";

/// @notice Full-range lifecycle security retained on the bundle and exchangeIn APIs after SY retirement.
contract V3FullRangeNativeSYTest is TestBase_UniswapV3FullSpreadAccounting, NativeSYExecutionAssertions {
    /// @notice Share receipt preserves deployed inventory and the executable both-token claim.
    function test_receivedSharesDoNotRebalanceOrChangePoolInventory() public {
        _seedVault(SEED);
        (uint256[] memory before_,) = IStandardExchangeBundleOut(address(vault))
            .previewExchangeBundleOut(address(vault), 1e8, _tokensOut());
        uint256 pool0_ = token0.balanceOf(address(pool));
        uint256 pool1_ = token1.balanceOf(address(pool));
        uint256 reserve0_ = vault.reserveOfToken(address(token0));
        uint256 reserve1_ = vault.reserveOfToken(address(token1));

        vm.prank(alice);
        vault.transfer(bob, 1e8);

        (uint256[] memory after_,) = IStandardExchangeBundleOut(address(vault))
            .previewExchangeBundleOut(address(vault), 1e8, _tokensOut());
        assertEq(after_, before_);
        assertEq(vault.balanceOf(bob), 1e8);
        assertEq(vault.balanceOf(alice), SEED - 1000 - 1e8);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        assertEq(token0.balanceOf(address(pool)), pool0_);
        assertEq(token1.balanceOf(address(pool)), pool1_);
        assertEq(vault.reserveOfToken(address(token0)), reserve0_);
        assertEq(vault.reserveOfToken(address(token1)), reserve1_);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
    }

    /// @notice All live facets, including the bundle queries, fit the deployed runtime limit.
    function test_installedQueryFacetsFitRuntimeLimit() public view {
        address[] memory facets_ = IDiamondLoupe(address(vault)).facetAddresses();
        assertGt(facets_.length, 0);
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertGt(facets_[i_].code.length, 0);
            assertLe(facets_[i_].code.length, 24_576, "installed facet runtime exceeds EIP-170");
        }
    }

    /// @notice The proportional genesis bundle rejects the floor and records it only at address zero.
    function test_bundleActivationUsesRawLiquidityAndFloor1000() public {
        uint256 before0_ = token0.balanceOf(alice);
        uint256 before1_ = token1.balanceOf(alice);
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        _bundleIn(alice, 1000, 1000);
        assertEq(token0.balanceOf(alice), before0_);
        assertEq(token1.balanceOf(alice), before1_);
        assertEq(vault.totalSupply(), 0);
        assertEq(_positionLiquidity(), 0);
        (uint256 quote_, uint256[] memory refunds_) = IStandardExchangeBundleIn(address(vault))
            .previewExchangeBundleInForSingleOut(_amountArray(SEED, SEED), address(vault));
        assertEq(quote_, SEED - 1000);
        assertEq(refunds_, _amountArray(0, 0));
        assertEq(_seedVault(SEED), quote_);
        assertEq(_positionLiquidity(), SEED);
        assertEq(vault.totalSupply(), SEED);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.balanceOf(address(0xdead)), 0);
    }

    /// @notice ABI-valid SY and quoteAssets calls fail as missing selectors, not malformed inputs.
    function test_retiredSYAndQuoteAssetsCallsFailExactly() public {
        _seedVault(SEED);
        assertFalse(IERC165(address(vault)).supportsInterface(type(IStandardizedYield).interfaceId));
        assertFalse(IERC165(address(vault)).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId));
        bytes[] memory calls_ = new bytes[](7);
        calls_[0] = abi.encodeCall(IStandardizedYield.deposit, (recipient, address(token0), 1e8, 0));
        calls_[1] = abi.encodeCall(IStandardizedYield.redeem, (recipient, 1e8, address(token0), 0, false));
        calls_[2] = abi.encodeCall(IStandardizedYield.redeem, (recipient, 1e8, address(token0), 0, true));
        calls_[3] = abi.encodeCall(IStandardizedYield.exchangeRate, ());
        calls_[4] = abi.encodeCall(IStandardizedYield.assetInfo, ());
        calls_[5] = abi.encodeCall(IStandardizedYield.previewDeposit, (address(token0), 1e8));
        calls_[6] = abi.encodeCall(IStandardExchangeTransitionQuote.quoteAssets, (bytes(""), 1e8));
        for (uint256 i_; i_ < calls_.length; ++i_) {
            bytes4 selector_ = bytes4(calls_[i_]);
            assertEq(IDiamondLoupe(address(vault)).facetAddress(selector_), address(0));
            (bool success_, bytes memory reason_) = address(vault).call(calls_[i_]);
            assertFalse(success_);
            assertEq(reason_, abi.encodeWithSelector(Proxy.NoTargetFor.selector, selector_));
        }
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        assertEq(vault.balanceOf(alice), SEED - 1000);
    }

    /// @notice A later single-token mint can be redeemed by its holder as a proportional bundle.
    function test_singleTokenEntryAndCallerHeldBundleRedemption() public noSelfCalls(address(vault)) {
        _seedVault(SEED);
        (uint256 quote_, uint256 refund_) =
            vault.previewExchangeIn(IERC20(address(token0)), 1e8, IERC20(address(vault)));
        assertGt(quote_, 0);
        uint256 beforeInput_ = token0.balanceOf(bob);
        vm.prank(bob);
        (uint256 minted_, uint256 refunded_) = vault.exchangeIn(
            IERC20(address(token0)), 1e8, IERC20(address(vault)), quote_, bob, false, block.timestamp
        );
        assertEq(minted_, quote_);
        assertEq(refunded_, refund_);
        assertEq(token0.balanceOf(bob), beforeInput_ - 1e8 + refund_);
        (uint256[] memory expected_,) = IStandardExchangeBundleOut(address(vault))
            .previewExchangeBundleOut(address(vault), quote_, _tokensOut());
        assertGt(expected_[0], 0);
        assertGt(expected_[1], 0);
        uint256 before0_ = token0.balanceOf(recipient);
        uint256 before1_ = token1.balanceOf(recipient);
        uint256 supply_ = vault.totalSupply();
        assertEq(vault.allowance(bob, address(vault)), 0);

        uint256[] memory actual_ = _bundleOut(bob, quote_, recipient, false);

        assertEq(actual_, expected_);
        assertEq(token0.balanceOf(recipient), before0_ + expected_[0]);
        assertEq(token1.balanceOf(recipient), before1_ + expected_[1]);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), supply_ - quote_);
        _assertSettled();
    }

    /// @notice Neither funding flag can claim parked shares; a funded caller burns only its own shares.
    function test_parkedSharesRemainAfterCallerHeldBundleBurn() public noSelfCalls(address(vault)) {
        _seedVault(SEED);
        vm.prank(alice);
        vault.transfer(address(vault), 5e8);
        for (uint256 i_; i_ < 2; ++i_) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 2e8));
            _bundleOut(address(this), 2e8, recipient, i_ == 1);
        }
        assertEq(vault.balanceOf(address(vault)), 5e8);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        vm.prank(alice);
        vault.transfer(address(this), 2e8);
        (uint256[] memory expected_,) = IStandardExchangeBundleOut(address(vault))
            .previewExchangeBundleOut(address(vault), 2e8, _tokensOut());
        uint256 before0_ = token0.balanceOf(recipient);
        uint256 before1_ = token1.balanceOf(recipient);

        uint256[] memory actual_ = _bundleOut(address(this), 2e8, recipient, true);

        assertEq(actual_, expected_);
        assertEq(token0.balanceOf(recipient), before0_ + expected_[0]);
        assertEq(token1.balanceOf(recipient), before1_ + expected_[1]);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(vault)), 5e8);
        assertEq(vault.totalSupply(), SEED - 2e8);
        assertEq(_positionLiquidity(), SEED - 2e8);
        _assertSettled();
    }

    /// @notice Accrued fees are booked, not share credit, and asymmetric bundle refunds match preview.
    function test_accruedFeeBundleDepositMatchesItsPreview() public noSelfCalls(address(vault)) {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e18, 2e18);
        assertGt(fee0_, 0);
        assertGt(fee1_, 0);
        (uint256 quote_, uint256[] memory previewRefunds_) = IStandardExchangeBundleIn(address(vault))
            .previewExchangeBundleInForSingleOut(_amountArray(7e8, 3e8), address(vault));
        uint256 before0_ = token0.balanceOf(bob);
        uint256 before1_ = token1.balanceOf(bob);

        (uint256 minted_, uint256[] memory refunds_) = _bundleIn(bob, 7e8, 3e8);

        assertEq(quote_, 3e8);
        assertEq(minted_, quote_);
        assertEq(refunds_, previewRefunds_);
        assertEq(refunds_, _amountArray(4e8, 0));
        assertEq(token0.balanceOf(bob), before0_ - 3e8);
        assertEq(token1.balanceOf(bob), before1_ - 3e8);
        assertEq(vault.balanceOf(bob), quote_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, fee0_);
        assertEq(booked1_, fee1_);
        assertEq(token0.balanceOf(address(vault)), fee0_);
        assertEq(token1.balanceOf(address(vault)), fee1_);
        _assertSettled();
    }

    /// @notice Bundle entry and each token's exit minimum roll back both token and share ledgers.
    function test_bundleSlippageRollbackPreservesBothLedgers() public {
        _seedVault(SEED);
        uint256 before0_ = token0.balanceOf(alice);
        uint256 before1_ = token1.balanceOf(alice);
        (uint256 quote_,) = IStandardExchangeBundleIn(address(vault))
            .previewExchangeBundleInForSingleOut(_amountArray(3e8, 3e8), address(vault));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeBundleIn.MinAmountNotMetAt.selector, 0, quote_ + 1, quote_));
        vm.prank(alice);
        IStandardExchangeBundleIn(address(vault)).exchangeBundleInForSingleOut(
            _amountArray(3e8, 3e8), address(vault), quote_ + 1, alice, false, block.timestamp
        );
        (uint256[] memory output_,) = IStandardExchangeBundleOut(address(vault))
            .previewExchangeBundleOut(address(vault), 1e8, _tokensOut());
        for (uint256 i_; i_ < 2; ++i_) {
            uint256[] memory minima_ = _amountArray(0, 0);
            minima_[i_] = output_[i_] + 1;
            vm.expectRevert(abi.encodeWithSelector(
                IStandardExchangeBundleIn.MinAmountNotMetAt.selector, i_, minima_[i_], output_[i_]
            ));
            vm.prank(alice);
            IStandardExchangeBundleOut(address(vault)).exchangeBundleOut(
                address(vault), 1e8, _tokensOut(), minima_, alice, false, block.timestamp
            );
        }
        assertEq(token0.balanceOf(alice), before0_);
        assertEq(token1.balanceOf(alice), before1_);
        assertEq(vault.balanceOf(alice), SEED - 1000);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        _assertSettled();
    }

    /// @notice Both bundle executions reject a real pool lock while their previews remain available.
    function test_lockedPoolRejectsBundleExecutionWithoutLocalFallback() public noSelfCalls(address(vault)) {
        _seedVault(SEED);
        UniswapV3PoolLockProbe probe_ = new UniswapV3PoolLockProbe(pool, address(vault));
        _fundAccount(address(probe_));
        vm.prank(alice);
        vault.transfer(address(probe_), 1e8);
        bytes[] memory calls_ = new bytes[](4);
        calls_[0] = abi.encodeCall(IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut, (_amountArray(1e8, 1e8), address(vault)));
        calls_[1] = abi.encodeCall(IStandardExchangeBundleOut.previewExchangeBundleOut, (address(vault), 1e6, _tokensOut()));
        calls_[2] = abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut, (_amountArray(1e8, 1e8), address(vault), 0, recipient, false, block.timestamp));
        calls_[3] = abi.encodeCall(IStandardExchangeBundleOut.exchangeBundleOut, (address(vault), 1e6, _tokensOut(), _amountArray(0, 0), recipient, false, block.timestamp));

        (bool[] memory success_, bytes[] memory result_) = probe_.run(calls_);

        assertTrue(probe_.observedLocked());
        assertTrue(success_[0]);
        assertTrue(success_[1]);
        (uint256 shares_, uint256[] memory refunds_) = abi.decode(result_[0], (uint256, uint256[]));
        (uint256[] memory amounts_, uint256 refund_) = abi.decode(result_[1], (uint256[], uint256));
        assertGt(shares_, 0);
        assertEq(refunds_.length, 2);
        assertGt(amounts_[0], 0);
        assertGt(amounts_[1], 0);
        assertEq(refund_, 0);
        for (uint256 i_ = 2; i_ < 4; ++i_) {
            assertFalse(success_[i_]);
            assertEq(result_[i_], abi.encodeWithSelector(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector));
        }
        assertEq(vault.totalSupply(), SEED);
        assertEq(vault.balanceOf(address(probe_)), 1e8);
        assertEq(_positionLiquidity(), SEED);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
        _assertSettled();
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {NativeSYExecutionAssertions} from "contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeBundleIn} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";
import {UniswapV3PoolLockProbe} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/helpers/UniswapV3PoolLockProbe.sol";

/// @notice Former native-SY security cases exercised through the current V3 Standard Exchange surface.
contract UniswapV3FullSpreadStandardExchangeVault_NativeSYTest is TestBase_UniswapV3FullSpreadAccounting, NativeSYExecutionAssertions {
    /// @notice Receiving shares changes ownership without changing either pool or vault backing.
    function test_receivedSharesDoNotRebalanceOrChangePoolInventory() public {
        _seedVault(SEED);
        uint256 reserve0_ = vault.reserveOfToken(address(token0));
        uint256 reserve1_ = vault.reserveOfToken(address(token1));
        uint256 pool0_ = token0.balanceOf(address(pool));
        uint256 pool1_ = token1.balanceOf(address(pool));
        uint256 custody0_ = token0.balanceOf(address(vault));
        uint256 custody1_ = token1.balanceOf(address(vault));
        (uint256 quote_, uint256 refund_) =
            vault.previewExchangeIn(IERC20(address(vault)), 1000, IERC20(address(token0)));

        vm.prank(alice);
        vault.transfer(bob, 1000);

        assertEq(vault.balanceOf(bob), 1000);
        assertEq(vault.balanceOf(alice), SEED - 2000);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        assertEq(vault.reserveOfToken(address(token0)), reserve0_);
        assertEq(vault.reserveOfToken(address(token1)), reserve1_);
        assertEq(token0.balanceOf(address(pool)), pool0_);
        assertEq(token1.balanceOf(address(pool)), pool1_);
        assertEq(token0.balanceOf(address(vault)), custody0_);
        assertEq(token1.balanceOf(address(vault)), custody1_);
        (uint256 afterQuote_, uint256 afterRefund_) =
            vault.previewExchangeIn(IERC20(address(vault)), 1000, IERC20(address(token0)));
        assertEq(afterQuote_, quote_);
        assertEq(afterRefund_, refund_);
    }

    /// @notice Every installed facet, including query facets, obeys EIP-170.
    function test_installedQueryFacetsFitRuntimeLimit() public view {
        address[] memory facets_ = IDiamondLoupe(address(vault)).facetAddresses();
        assertGt(facets_.length, 0);
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertGt(facets_[i_].code.length, 0);
            assertLe(facets_[i_].code.length, 24_576, "installed facet runtime exceeds EIP-170");
        }
    }

    /// @notice Genesis rejects liquidity at the floor, then issues raw liquidity less 1,000.
    function test_bundleActivationUsesZeroAddressLiquidityFloor() public {
        uint256 before0_ = token0.balanceOf(alice);
        uint256 before1_ = token1.balanceOf(alice);
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        _bundleIn(alice, 1000, 1000);
        assertEq(token0.balanceOf(alice), before0_);
        assertEq(token1.balanceOf(alice), before1_);
        assertEq(vault.totalSupply(), 0);
        assertEq(_positionLiquidity(), 0);
        (uint256 preview_,) = IStandardExchangeBundleIn(address(vault))
            .previewExchangeBundleInForSingleOut(_amountArray(SEED, SEED), address(vault));
        assertEq(preview_, SEED - 1000);
        assertEq(_seedVault(SEED), SEED - 1000);
        assertEq(_positionLiquidity(), SEED);
        assertEq(vault.totalSupply(), SEED);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.balanceOf(address(0xdead)), 0);
    }

    /// @notice SY and quoteAssets are absent from discovery and fail with the exact proxy error.
    function test_retiredSYAndQuoteAssetsSurfaceIsAbsent() public {
        _seedVault(SEED);
        assertEq(IERC20Metadata(address(vault)).decimals(), 18);
        assertFalse(IERC165(address(vault)).supportsInterface(type(IStandardizedYield).interfaceId));
        assertFalse(IERC165(address(vault)).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId));
        bytes4[] memory extra_ = new bytes4[](1);
        extra_[0] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        bytes4[] memory selectors_ = NativeStandardYieldSelectors._append(extra_);
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertEq(IDiamondLoupe(address(vault)).facetAddress(selectors_[i_]), address(0));
            (bool success_, bytes memory reason_) = address(vault).call(abi.encodePacked(selectors_[i_]));
            assertFalse(success_);
            assertEq(reason_, abi.encodeWithSelector(Proxy.NoTargetFor.selector, selectors_[i_]));
        }
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
    }

    /// @notice A later one-token deposit refunds input and its caller-held exit needs no share allowance.
    function test_singleTokenRoutesBurnCallerHeldShares() public noSelfCalls(address(vault)) {
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
        (uint256 output_,) =
            vault.previewExchangeIn(IERC20(address(vault)), quote_, IERC20(address(token0)));
        assertGt(output_, 0);
        uint256 beforeOutput_ = token0.balanceOf(recipient);
        uint256 supply_ = vault.totalSupply();
        assertEq(vault.allowance(bob, address(vault)), 0);
        vm.prank(bob);
        (uint256 paid_, uint256 exitRefund_) = vault.exchangeIn(
            IERC20(address(vault)), quote_, IERC20(address(token0)), output_, recipient, false, block.timestamp
        );
        assertEq(paid_, output_);
        assertEq(exitRefund_, 0);
        assertEq(token0.balanceOf(recipient), beforeOutput_ + output_);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), supply_ - quote_);
    }

    /// @notice Public previews remain two-word internal calculations without proxy self-calls.
    function test_exchangePreviewUsesInternalQuote() public noSelfCalls(address(vault)) {
        _seedVault(SEED);
        vm.expectCall(address(vault), abi.encodeWithSelector(IERC20.totalSupply.selector), uint64(0));
        vm.expectCall(address(vault), abi.encodeWithSelector(IERC20.balanceOf.selector), uint64(0));
        vm.expectCall(address(vault), abi.encodeWithSelector(IDiamondLoupe.facetAddress.selector), uint64(0));
        (uint256 mint_,) = vault.previewExchangeIn(IERC20(address(token0)), 1e8, IERC20(address(vault)));
        (uint256 exit_,) = vault.previewExchangeIn(IERC20(address(vault)), 1e8, IERC20(address(token1)));
        assertGt(mint_, 0);
        assertGt(exit_, 0);
    }

    /// @notice A caller with no shares cannot claim shares parked on the vault, with either funding flag.
    function test_parkedSharesCannotBecomeCallerBurnCredit() public {
        _seedVault(SEED);
        vm.prank(alice);
        vault.transfer(address(vault), 5e8);
        uint256 before0_ = token0.balanceOf(address(this));
        for (uint256 i_; i_ < 2; ++i_) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 2e8));
            vault.exchangeIn(
                IERC20(address(vault)), 2e8, IERC20(address(token0)), 0, address(this), i_ == 1, block.timestamp
            );
        }
        assertEq(vault.balanceOf(address(vault)), 5e8);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        assertEq(token0.balanceOf(address(this)), before0_);
    }

    /// @notice Accrued pool fees do not break either word of the one-token deposit preview.
    function test_accruedFeeDepositMatchesItsPreview() public {
        _seedVault(SEED);
        (uint256 fee0_, uint256 fee1_) = _poolFees(1e18, 2e18);
        assertGt(fee0_, 0);
        assertGt(fee1_, 0);
        (uint256 quote_, uint256 refund_) =
            vault.previewExchangeIn(IERC20(address(token1)), 1e8, IERC20(address(vault)));
        assertGt(quote_, 0);
        uint256 before_ = token1.balanceOf(bob);
        vm.prank(bob);
        (uint256 minted_, uint256 refunded_) = vault.exchangeIn(
            IERC20(address(token1)), 1e8, IERC20(address(vault)), quote_, bob, false, block.timestamp
        );
        assertEq(minted_, quote_);
        assertEq(refunded_, refund_);
        assertEq(vault.balanceOf(bob), quote_);
        assertEq(token1.balanceOf(bob), before_ - 1e8 + refund_);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertGe(booked0_, fee0_);
        assertGe(booked1_, fee1_);
        _assertSettled();
    }

    /// @notice A failed deposit or exit minimum rolls back funding, pool state, shares and custody.
    function test_exchangeSlippageRollbackPreservesBothLedgers() public {
        _seedVault(SEED);
        uint256 before0_ = token0.balanceOf(alice);
        uint256 before1_ = token1.balanceOf(alice);
        (uint160 price_, int24 tick_,,,,,) = pool.slot0();
        (uint256 quote_,) = vault.previewExchangeIn(IERC20(address(token0)), 1e8, IERC20(address(vault)));
        assertGt(quote_, 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quote_ + 1, quote_));
        vm.prank(alice);
        vault.exchangeIn(
            IERC20(address(token0)), 1e8, IERC20(address(vault)), quote_ + 1, alice, false, block.timestamp
        );
        (uint256 out_,) = vault.previewExchangeIn(IERC20(address(vault)), 1e8, IERC20(address(token0)));
        assertGt(out_, 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, out_ + 1, out_));
        vm.prank(alice);
        vault.exchangeIn(
            IERC20(address(vault)), 1e8, IERC20(address(token0)), out_ + 1, alice, false, block.timestamp
        );
        assertEq(token0.balanceOf(alice), before0_);
        assertEq(token1.balanceOf(alice), before1_);
        assertEq(vault.balanceOf(alice), SEED - 1000);
        assertEq(vault.totalSupply(), SEED);
        assertEq(_positionLiquidity(), SEED);
        (uint160 afterPrice_, int24 afterTick_,,,,,) = pool.slot0();
        assertEq(afterPrice_, price_);
        assertEq(afterTick_, tick_);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        _assertSettled();
        vm.prank(alice);
        (uint256 paid_,) = vault.exchangeIn(
            IERC20(address(vault)), 1e8, IERC20(address(token0)), out_, alice, false, block.timestamp
        );
        assertEq(paid_, out_);
        assertEq(token0.balanceOf(alice), before0_ + out_);
        assertEq(vault.totalSupply(), SEED - 1e8);
    }

    /// @notice Locked previews remain readable while deposit and exit execution reject pool interaction.
    function test_lockedPoolRejectsExecutionWithoutLocalFallback() public {
        _seedVault(SEED);
        UniswapV3PoolLockProbe probe_ = new UniswapV3PoolLockProbe(pool, address(vault));
        _fundAccount(address(probe_));
        vm.prank(alice);
        vault.transfer(address(probe_), 1e8);
        bytes[] memory calls_ = new bytes[](4);
        calls_[0] = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(token0)), 1e8, IERC20(address(vault))));
        calls_[1] = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(vault)), 1e6, IERC20(address(token1))));
        calls_[2] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(token0)), 1e8, IERC20(address(vault)), 0, recipient, false, block.timestamp));
        calls_[3] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(vault)), 1e6, IERC20(address(token1)), 0, recipient, false, block.timestamp));

        (bool[] memory success_, bytes[] memory result_) = probe_.run(calls_);

        assertTrue(probe_.observedLocked());
        for (uint256 i_; i_ < 2; ++i_) {
            assertTrue(success_[i_]);
            assertEq(result_[i_].length, 64);
            (uint256 amount_,) = abi.decode(result_[i_], (uint256, uint256));
            assertGt(amount_, 0);
            assertFalse(success_[i_ + 2]);
            assertEq(result_[i_ + 2], abi.encodeWithSelector(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector));
        }
        assertEq(vault.totalSupply(), SEED);
        assertEq(vault.balanceOf(address(probe_)), 1e8);
        assertEq(_positionLiquidity(), SEED);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
        _assertSettled();
    }
}

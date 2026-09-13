// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {MintableERC20Decimals as StubDecimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_main/LaunchState.sol";
import {Phase_05_Stage_01_SeRateProviderPkg as ProviderPackage} from "scripts/foundry/anvil_robinhood_main/Phase_05_Stage_01_SeRateProviderPkg.sol";
import {Phase_07_Stage_03_FeeAccrualRateProviders as Providers} from "scripts/foundry/anvil_robinhood_main/Phase_07_Stage_03_FeeAccrualRateProviders.sol";
import {Phase_06_Stage_10_RebasingAwareERC4626Pkg as WrapperPackage} from "scripts/foundry/anvil_robinhood_main/Phase_06_Stage_10_RebasingAwareERC4626Pkg.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as WeightedPkg} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as ScaleMath} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";

/**
 * @notice H15 dual-scale FIX + live SE book donations dilute.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Scale is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    LaunchState internal custodyComponents;

    function _custodyArgs(uint8 offset_) internal returns (WeightedPkg.PkgArgs memory args_, IERC4626 custody_) {
        custodyComponents.create3Factory = create3Factory;
        custodyComponents.diamondPackageFactory = diamondPackageFactory;
        custodyComponents.indexedexManager = indexedexManager;
        custodyComponents.erc20Facet = erc20Facet;
        vm.prank(create3Factory.owner());
        create3Factory.setOperator(owner, true);
        vm.startPrank(owner);
        WrapperPackage.execute(custodyComponents);
        vm.stopPrank();
        custody_ = IRebasingAwareERC4626DFPkg(custodyComponents.rebasingAwareErc4626Pkg).deployVault(
            IERC20Metadata(address(token0)), offset_, bytes32(uint256(offset_))
        );
        args_ = _defaultPkgArgs();
        args_.standardExchanges[0] = address(custody_);
        args_.seDecimals[0] = IERC20Metadata(address(custody_)).decimals();
        ProviderPackage.execute(custodyComponents);
        args_.rateProviders[0] = Providers.execute(
            diamondPackageFactory, custodyComponents.rateProviderPkg, address(custody_), address(token0)
        );
    }

    function _activateCustody(uint8 offset_) internal returns (IERC4626 custody_) {
        WeightedPkg.PkgArgs memory args_;
        (args_, custody_) = _custodyArgs(offset_);
        _deployHookWithArgs(args_);
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _firstMintEqual(100 ether);
        assertEq(weighted.ratedScale(0), 1e18, "18-decimal asset scale");
        assertEq(weighted.invScale(0), 10 ** uint256(18 - offset_), "actual wrapper share scale");
        assertEq(weighted.nativeReserve(0), custody_.balanceOf(hook), "inventory is actual shares");
        assertEq(weighted.seClaim(0), custody_.previewRedeem(custody_.balanceOf(hook)), "claim is asset units");
        assertApproxEqAbs(weighted.ratedBalance(0), weighted.seClaim(0), 1, "provider uses whole share units");
    }

    function test_custody28_joinSwapAndExit() public {
        IERC4626 custody_ = _activateCustody(10);
        uint256 beforeShares_ = custody_.balanceOf(hook);
        _swapExactIn(address(token1), address(token0), 1 ether);
        assertLt(custody_.balanceOf(hook), beforeShares_, "swap redeems custody shares");
        _swapExactOut(address(token0), address(token1), 1 ether);
        assertEq(weighted.nativeReserve(0), custody_.balanceOf(hook));
        uint256 lp_ = IERC20(hook).balanceOf(user) / 10;
        uint256[] memory preview_ = weighted.previewExitProportional(lp_);
        uint256 before0_ = token0.balanceOf(user);
        uint256 before1_ = token1.balanceOf(user);
        vm.prank(user);
        weighted.exitProportional(lp_, user, new uint256[](2), block.timestamp + 1 hours);
        assertEq(token0.balanceOf(user) - before0_, preview_[0]);
        assertEq(token1.balanceOf(user) - before1_, preview_[1]);
    }

    function test_weightedFacets_fitProductionRuntimeLimit() public view {
        address[] memory facets_ = IDiamondLoupe(hook).facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertLe(facets_[i_].code.length, 24576, "facet exceeds EIP-170");
        }
    }

    function test_custody36_supportedUpperBoundary() public {
        _activateCustody(18);
        assertEq(weighted.invScale(0), 1);
        _swapExactIn(address(token1), address(token0), 1 ether);
    }

    function test_custody28_withoutProviderUsesLiveClaim() public {
        (WeightedPkg.PkgArgs memory args_, IERC4626 custody_) = _custodyArgs(10);
        args_.rateProviders[0] = address(0);
        _deployHookWithArgs(args_);
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _firstMintEqual(100 ether);
        assertEq(weighted.ratedBalance(0), custody_.previewRedeem(custody_.balanceOf(hook)));
        _swapExactIn(address(token1), address(token0), 1 ether);
        _swapExactOut(address(token0), address(token1), 1 ether);
    }

    function testFuzz_custody28_sequencePreservesInventoryAccounting(uint256 seed_) public {
        IERC4626 custody_ = _activateCustody(10);
        for (uint256 step_; step_ < 8; ++step_) {
            seed_ = uint256(keccak256(abi.encode(seed_, step_)));
            uint256 amount_ = bound(seed_, 1e12, 1e17);
            if (seed_ % 3 == 0) {
                uint256 shares_ = custody_.balanceOf(hook);
                uint256 supply_ = IERC20(hook).totalSupply();
                token0.mint(address(custody_), amount_);
                assertEq(custody_.balanceOf(hook), shares_, "yield cannot invent inventory");
                assertEq(IERC20(hook).totalSupply(), supply_, "yield cannot mint LP");
            } else if (seed_ % 3 == 1) {
                _swapExactIn(address(token0), address(token1), amount_);
            } else {
                _swapExactIn(address(token1), address(token0), amount_);
            }
            assertEq(weighted.nativeReserve(0), custody_.balanceOf(hook));
            assertEq(weighted.seClaim(0), custody_.previewRedeem(custody_.balanceOf(hook)));
            assertApproxEqRel(weighted.ratedBalance(0), weighted.seClaim(0), 1e12);
            assertEq(token0.allowance(hook, address(custody_)), 0);
            assertGt(weighted.nativeReserve(0), 0);
            assertGt(weighted.nativeReserve(1), 0);
        }
    }

    function test_custody28_underlyingDonationChangesClaimWithoutInventingShares() public {
        IERC4626 custody_ = _activateCustody(10);
        uint256 book_ = weighted.nativeReserve(0);
        uint256 claim_ = weighted.seClaim(0);
        token0.mint(address(custody_), 10 ether);
        assertEq(weighted.nativeReserve(0), book_);
        assertGt(weighted.seClaim(0), claim_);
        assertEq(weighted.seClaim(0), custody_.previewRedeem(book_));
    }

    function test_custody_rejectsForgedShareDecimals() public {
        (WeightedPkg.PkgArgs memory args_,) = _custodyArgs(10);
        args_.seDecimals[0] = 18;
        vm.expectRevert(WeightedPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args_));
    }

    function test_custody_rejectsForgedAssetDecimals() public {
        (WeightedPkg.PkgArgs memory args_,) = _custodyArgs(10);
        args_.tokenDecimals[0] = 6;
        vm.expectRevert(WeightedPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args_));
    }

    function test_custody_rejectsUnsupportedShareDecimals() public {
        (WeightedPkg.PkgArgs memory args_,) = _custodyArgs(10);
        args_.seDecimals[0] = 37;
        vm.expectRevert(WeightedPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args_));
    }

    function testFuzz_custodyScale_roundingBounds(uint8 decimals_, uint128 amount_) public pure {
        decimals_ = uint8(bound(decimals_, 19, 36));
        uint256 scale_ = ScaleMath.baseScaleFromDecimals(decimals_);
        uint256 down_ = ScaleMath.scaleTo(amount_, scale_);
        uint256 up_ = ScaleMath.scaleToUp(amount_, scale_);
        assertLe(ScaleMath.descale(down_, scale_), amount_);
        assertGe(ScaleMath.descaleUp(up_, scale_), amount_);
        assertLe(up_ - down_, 1);
        assertEq(ScaleMath.scaleTo(10 ** uint256(decimals_), scale_), 1e18, "one whole share normalized");
    }

    function testFuzz_rateScale_matchesRationalUnits(uint8 shareDecimals_, uint8 assetDecimals_, uint128 shares_, uint64 rate_) public pure {
        shareDecimals_ = uint8(bound(shareDecimals_, 6, 36));
        assetDecimals_ = uint8(bound(assetDecimals_, 6, 18));
        uint256 expected_ = (uint256(shares_) * rate_ * 10 ** uint256(assetDecimals_))
            / (1e18 * 10 ** uint256(shareDecimals_));
        assertEq(ScaleMath.ratedPairUnits(shares_, rate_, ScaleMath.baseScaleFromDecimals(shareDecimals_), ScaleMath.baseScaleFromDecimals(assetDecimals_)), expected_);
    }

    function test_dualScale_invVsRated() public view {
        uint256 inv0 = weighted.invScale(0);
        uint256 rated0 = weighted.ratedScale(0);
        assertGt(inv0, 0);
        assertGt(rated0, 0);
        assertEq(weighted.invScale(1), weighted.ratedScale(1));
    }

    /// @notice FIX-mixed: real 6-decimal raw leg + 18-decimal SE leg; scales differ; first mint works.
    function test_FIX_mixedDecimals_6and18() public {
        StubDecimals t6 = new StubDecimals("Six", "SIX", 6);
        SimpleMintableERC20 t18 = new SimpleMintableERC20("Eighteen", "E18");
        SimpleYieldERC4626 vault6 = new SimpleYieldERC4626(t6);
        address se6 = _deployERC4626SE(address(vault6));

        address a6 = address(t6);
        address a18 = address(t18);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;

        uint8 i6;
        uint8 i18;
        if (a6 < a18) {
            toks[0] = a6;
            toks[1] = a18;
            ses[0] = se6;
            ses[1] = address(0);
            i6 = 0;
            i18 = 1;
        } else {
            toks[0] = a18;
            toks[1] = a6;
            ses[0] = address(0);
            ses[1] = se6;
            i18 = 0;
            i6 = 1;
        }

        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));

        t6.mint(user, 1_000_000e6);
        t18.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t6.approve(hook, type(uint256).max);
        t18.approve(hook, type(uint256).max);
        vm.stopPrank();

        // ratedScale = 10^(36 - pairDecimals). 6-dec is SE-buffered; self-leg is 18.
        uint8 se6Dec = IERC20Metadata(se6).decimals();
        assertEq(weighted.ratedScale(i6), 10 ** uint256(36 - 6), "ratedScale 6dec");
        assertEq(weighted.ratedScale(i18), 10 ** uint256(36 - 18), "ratedScale 18dec");
        assertEq(weighted.invScale(i6), 10 ** uint256(36 - se6Dec), "SE inv share scale");
        assertEq(weighted.invScale(i18), weighted.ratedScale(i18), "self-leg inv==rated");
        assertTrue(weighted.ratedScale(i6) != weighted.ratedScale(i18), "cross-leg scales differ");

        uint256[] memory amounts = new uint256[](2);
        amounts[i6] = 100_000e6;
        amounts[i18] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0, "first mint mixed decimals");
        assertTrue(weighted.isFullBook());
        assertGt(weighted.nativeReserve(i6), 0);
        assertGt(weighted.nativeReserve(i18), 0);
    }

    function test_liveSeBook_donationDilutes() public {
        _firstMintEqual(50 ether);
        uint256 bookBefore = weighted.nativeReserve(0);
        uint256 seBalBefore = weighted.seBalance(0);
        assertEq(bookBefore, seBalBefore);
        assertGt(bookBefore, 0);

        uint256 amountIn = 10 ether;
        token0.mint(user, amountIn);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), amountIn, IERC20(se0), 0, user, false, block.timestamp + 1 hours
        );
        assertGt(seOut, 0, "minted SE shares");
        IERC20(se0).transfer(hook, seOut);
        vm.stopPrank();

        uint256 bookAfter = weighted.nativeReserve(0);
        assertEq(bookAfter, weighted.seBalance(0), "book == live SE bal");
        assertEq(bookAfter, seBalBefore + seOut, "donation increased live book");
        assertGt(bookAfter, bookBefore, "dilution: book rose without LP mint");

        uint256 bookMid = weighted.nativeReserve(0);
        token0.mint(hook, 5);
        assertEq(weighted.nativeReserve(0), bookMid, "face dust not book");
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "still SE shares");
    }

    function test_reserveOfToken_matchesNativeBook() public {
        _firstMintEqual(25 ether);
        assertEq(_reserveOf(address(token0)), weighted.nativeReserve(0));
        assertEq(_reserveOf(address(token1)), weighted.nativeReserve(1));
        assertEq(_reserveOf(address(token0)), weighted.seBalance(0));
        assertEq(token1.balanceOf(hook), weighted.nativeReserve(1));
    }
}

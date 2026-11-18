// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4DetfFirstBondShares as Basket} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";

/// @notice Three six-decimal pairs are funded with real V3 bundle-acquired shares.
contract UniswapV4DetfFirstBondSharesTest is TestBase_UniswapV4Detf_Quad_Univ3Se_Decimals {
    uint256[] internal amounts;
    address[] internal shareTokens;
    uint256 internal anchor;
    uint256 internal anchorValue;

    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 6; }

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            detf, BondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK, 0, 0)
        );
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(detf, 5e16);
        vm.stopPrank();
        address[] memory pairs_ = detfInfo.acceptedBondTokens();
        anchorValue = type(uint256).max;
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            address vault_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(pairs_[i_]);
            uint256 shares_ = SeLib.acquirePositionShares(vault_, pairs_[i_], 100e6, detfUser);
            shareTokens.push(vault_);
            amounts.push(shares_);
            (uint256 value_,) = IStandardExchangeIn(vault_).previewExchangeIn(
                IERC20(vault_), shares_, IERC20(pairs_[i_])
            );
            assertGt(value_, 0, "real shares have an executable pair valuation");
            if (value_ < anchorValue) {
                anchorValue = value_;
                anchor = i_;
            }
            vm.prank(detfUser);
            IERC20(vault_).approve(detf, shares_);
        }
    }

    function _open() internal returns (uint256 id_, uint256 lp_) {
        vm.prank(detfUser);
        return Basket(detf).bondFirstShares(
            amounts, anchor, DEFAULT_MIN_LOCK, detfUser, 1, 1, block.timestamp + 1
        );
    }

    function test_realShareBasketPreservesAnchorPricingAndFundsPrincipal() public {
        uint256 g_ = anchorValue * 1e9 / 1e6;
        uint256 principal_ = g_ * 95 / 100;
        uint256 rewards_ = 2 * (g_ * 5 / 100);
        (uint256 purchased_, uint256 quotedPrincipal_, uint256 quotedRewards_, uint256 quotedG_, uint256 quotedLp_) =
            Basket(detf).previewFirstBondShares(amounts, anchor, DEFAULT_MIN_LOCK);
        assertEq(purchased_, g_, "zero bonus keeps the anchor purchase linear");
        assertEq(quotedG_, g_, "other funded legs do not multiply liquidity DETF");
        assertEq(quotedPrincipal_, principal_);
        assertEq(quotedRewards_, rewards_);
        uint256[] memory before_ = new uint256[](amounts.length);
        for (uint256 i_; i_ < amounts.length; ++i_) before_[i_] = IERC20(shareTokens[i_]).balanceOf(detfUser);
        (uint256 id_, uint256 lp_) = _open();
        assertGt(lp_, 0);
        assertEq(lp_, quotedLp_, "complete hook quote executes");
        assertTrue(detfInfo.isReserveLive());
        assertTrue(IUniswapV4SeBufferHook(reserveHook).isLive());
        assertEq(IDetfBondNFT(detfInfo.bondNftVault()).positionOf(id_).principal, principal_);
        assertEq(IERC20(detf).totalSupply(), g_ + principal_ + rewards_);
        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()), principal_ + rewards_);
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lp_);
        for (uint256 i_; i_ < amounts.length; ++i_) {
            assertEq(IERC20(shareTokens[i_]).balanceOf(detfUser), before_[i_] - amounts[i_]);
            assertEq(IERC20(shareTokens[i_]).balanceOf(detf), 0, "every declared share entered the hook");
            assertEq(IERC20(shareTokens[i_]).allowance(detf, reserveHook), 0);
        }
        assertTrue(IERC165(detf).supportsInterface(type(Basket).interfaceId));
    }

    function test_existingParentSharesCannotReplaceFreshCallerFunding() public {
        uint256 last_ = amounts.length - 1;
        vm.startPrank(detfUser);
        IERC20(shareTokens[last_]).transfer(detf, amounts[last_]);
        IERC20(shareTokens[last_]).approve(detf, 0);
        vm.stopPrank();
        uint256 firstBefore_ = IERC20(shareTokens[0]).balanceOf(detfUser);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        _open();
        assertFalse(detfInfo.isReserveLive());
        assertEq(IERC20(detf).totalSupply(), 0);
        assertEq(IERC20(shareTokens[0]).balanceOf(detfUser), firstBefore_, "earlier pulls roll back");
        assertEq(IERC20(shareTokens[last_]).balanceOf(detf), amounts[last_], "old custody is preserved");
    }

    function test_preexistingShareCustodyRemainsOutsideBasket() public {
        vm.prank(detfUser);
        IERC20(shareTokens[0]).transfer(detf, 1);
        --amounts[0];
        // Choose the smallest live valuation after changing the declared basket.
        address[] memory pairs_ = detfInfo.acceptedBondTokens();
        anchorValue = type(uint256).max;
        for (uint256 i_; i_ < amounts.length; ++i_) {
            (uint256 value_,) = IStandardExchangeIn(shareTokens[i_]).previewExchangeIn(
                IERC20(shareTokens[i_]), amounts[i_], IERC20(pairs_[i_])
            );
            if (value_ < anchorValue) { anchorValue = value_; anchor = i_; }
        }
        _open();
        assertEq(IERC20(shareTokens[0]).balanceOf(detf), 1, "undeclared custody is not spent");
    }

    function test_lateMinimumFailureRollsBackAllFundingAndIssuance() public {
        uint256 firstBefore_ = IERC20(shareTokens[0]).balanceOf(detfUser);
        (, uint256 principal_,,, uint256 lp_) =
            Basket(detf).previewFirstBondShares(amounts, anchor, DEFAULT_MIN_LOCK);
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(
            Basket.FirstBondMinimumNotMet.selector, principal_, 0, lp_, type(uint256).max
        ));
        Basket(detf).bondFirstShares(
            amounts, anchor, DEFAULT_MIN_LOCK, detfUser, 0, type(uint256).max, block.timestamp + 1
        );
        assertEq(IERC20(shareTokens[0]).balanceOf(detfUser), firstBefore_);
        assertEq(IERC20(detf).totalSupply(), 0);
        assertEq(IERC20(reserveHook).totalSupply(), 0);
        assertFalse(detfInfo.isReserveLive());
    }

    function test_underfundedOtherLegCannotBorrowAnchorCredit() public {
        uint256 other_ = (anchor + 1) % amounts.length;
        amounts[other_] /= 2;
        address[] memory pairs_ = detfInfo.acceptedBondTokens();
        (uint256 value_,) = IStandardExchangeIn(shareTokens[other_]).previewExchangeIn(
            IERC20(shareTokens[other_]), amounts[other_], IERC20(pairs_[other_])
        );
        assertLt(value_, anchorValue);
        vm.expectRevert(abi.encodeWithSelector(
            Basket.InsufficientFirstBondBacking.selector, pairs_[other_], value_, anchorValue
        ));
        _open();
        assertEq(IERC20(detf).totalSupply(), 0);
        assertFalse(detfInfo.isReserveLive());
    }

    function test_missingLegAndInvalidAnchorRejectBeforeFunding() public {
        uint256[] memory short_ = new uint256[](amounts.length - 1);
        vm.prank(detfUser);
        vm.expectRevert(Basket.InvalidShareBasket.selector);
        Basket(detf).bondFirstShares(short_, 0, DEFAULT_MIN_LOCK, detfUser, 0, 0, block.timestamp + 1);
        vm.prank(detfUser);
        vm.expectRevert(Basket.InvalidShareBasket.selector);
        Basket(detf).bondFirstShares(amounts, amounts.length, DEFAULT_MIN_LOCK, detfUser, 0, 0, block.timestamp + 1);
        assertEq(IERC20(detf).totalSupply(), 0);
    }

    function test_shareBasketCannotBeUsedAfterFirstBond() public {
        _open();
        vm.expectRevert(Repo.AlreadyLive.selector);
        _open();
    }
}

/// @notice Ordinary permissionless bootstrap selectors are absent from Migration.
contract MigrationRejectsOrdinaryShareBasketTest is TestBase_UniswapV4DetfMigration {
    function test_ordinaryShareBasketIsNeitherInstalledNorAdvertised() public view {
        assertEq(IDiamondLoupe(detf).facetAddress(Basket.bondFirstShares.selector), address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Basket.previewFirstBondShares.selector), address(0));
        assertFalse(IERC165(detf).supportsInterface(type(Basket).interfaceId));
    }
}

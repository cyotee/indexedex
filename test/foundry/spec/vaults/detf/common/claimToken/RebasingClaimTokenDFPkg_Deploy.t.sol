// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {DETFSYTarget} from "contracts/vaults/detf/common/sy/DETFSYTarget.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

/// @notice Production factory and funded child integration; no mocked DETF/NFT accounting.
contract RebasingClaimTokenDFPkg_Deploy_Test is TestBase_UniswapV4Detf, DETFFundedStakingArtifacts {
    function test_existingERC4626SEExposesNativeSYMetadata() public view {
        IStandardizedYield native_ = IStandardizedYield(se);
        assertEq(IERC20Metadata(se).decimals(), 18, "existing SE unit stays unchanged");
        assertEq(native_.yieldToken(), address(pairProtocolVault));
        (IStandardizedYield.AssetType kind_, address asset_, uint8 decimals_) = native_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, address(pairToken));
        assertEq(decimals_, 18);
        assertTrue(native_.isValidTokenIn(address(pairToken)));
        assertTrue(native_.isValidTokenOut(address(pairProtocolVault)));
        assertEq(native_.getRewardTokens().length, 0);
    }

    function test_nativeSYUsesStandardRoutesAndPreservesUnredeemedInternalShares() public {
        IStandardizedYield native_ = IStandardizedYield(se);
        uint256 preview_ = native_.previewDeposit(address(pairToken), 100 ether);
        vm.startPrank(detfUser);
        uint256 shares_ = native_.deposit(detfUser, address(pairToken), 100 ether, preview_);
        assertEq(shares_, preview_);
        assertEq(IERC20(se).balanceOf(detfUser), shares_);
        uint256 internal_ = shares_ * 3 / 4;
        IERC20(se).transfer(se, internal_);
        uint256 redeem_ = shares_ / 4;
        uint256 expected_ = native_.previewRedeem(address(pairToken), redeem_);
        uint256 paid_ = native_.redeem(detfUser, redeem_, address(pairToken), expected_, true);
        vm.stopPrank();
        assertEq(paid_, expected_);
        assertEq(IERC20(se).balanceOf(se), internal_ - redeem_, "only requested internal SY is consumed");
    }

    function test_nativeSYRateUsesProportionalAccountingAssets() public {
        IStandardizedYield native_ = IStandardizedYield(se);
        vm.startPrank(detfUser);
        uint256 shares_ = native_.deposit(detfUser, address(pairToken), 100 ether, 0);
        uint256 before_ = native_.exchangeRate();
        pairToken.approve(address(pairProtocolVault), 10 ether);
        pairProtocolVault.simulateYield(10 ether);
        vm.stopPrank();
        uint256 held_ = pairProtocolVault.balanceOf(se);
        uint256 expected_ = pairProtocolVault.convertToAssets(held_) * 1e18 / IERC20(se).totalSupply();
        assertEq(native_.exchangeRate(), expected_);
        assertGt(expected_, before_);
        assertEq(IERC20(se).balanceOf(detfUser), shares_, "existing static SE balances do not rebase");
    }

    function test_nativeSYSlippageRollsBackStandardDeposit() public {
        IStandardizedYield native_ = IStandardizedYield(se);
        uint256 quoted_ = native_.previewDeposit(address(pairToken), 100 ether);
        uint256 before_ = pairToken.balanceOf(detfUser);
        vm.prank(detfUser);
        vm.expectRevert();
        native_.deposit(detfUser, address(pairToken), 100 ether, quoted_ + 1);
        assertEq(pairToken.balanceOf(detfUser), before_);
        assertEq(IERC20(se).balanceOf(detfUser), 0);
    }

    function test_bondMetadataFacetIsAssembledAndDeployable() public {
        (uint256 id_,) = _firstBond(1_000 ether);
        address nft_ = address(_bondVault());
        address renderer_ = IDiamondLoupe(nft_).facetAddress(IERC721Metadata.tokenURI.selector);
        address custody_ = IDiamondLoupe(nft_).facetAddress(IDetfBondNFT.claimBond.selector);
        assertTrue(renderer_ != custody_, "rendering has independent code-size headroom");
        assertGt(renderer_.code.length, 0);
        assertLe(renderer_.code.length, 24_576);
        assertLe(custody_.code.length, 24_576);
        string memory uri_ = IERC721Metadata(nft_).tokenURI(id_);
        assertTrue(bytes(uri_).length > 100, "proxy renders its actual funded position");
        assertTrue(bytes(IERC721Metadata(nft_).tokenURI(1)).length > 100, "standing role metadata");
        vm.expectRevert();
        IERC721Metadata(nft_).tokenURI(id_ + 1);
    }

    function _staking() private view returns (IStakedDETF) {
        return IStakedDETF(detfInfo.rebasingClaimToken());
    }

    function _bondVault() private view returns (IDetfBondNFT) {
        return IDetfBondNFT(address(detfInfo.bondNftVault()));
    }

    function test_deployedNativeUnitsAndEmptyFundedLedger() public view {
        IStakedDETF token_ = _staking();
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(token_.decimals(), 9);
        assertEq(token_.detf(), detf);
        assertEq(token_.totalSupply(), 0);
        assertEq(token_.stakingState().accountedBacking, 0);
        assertEq(token_.stakingState().gonsPerUnit, StakingMath.INITIAL_GONS_PER_UNIT);
    }

    function test_deployTokenDefaultMetadataAndDeterminism() public {
        address first_ = rebasingClaimTokenPkg.deployToken(
            IDetf(detf), IDETFNFTVault(address(_bondVault())),
            IVaultFeeOracleQuery(address(indexedexManager)), "", ""
        );
        address second_ = rebasingClaimTokenPkg.deployToken(
            IDetf(detf), IDETFNFTVault(address(_bondVault())),
            IVaultFeeOracleQuery(address(indexedexManager)), "", ""
        );
        assertEq(first_, second_);
        assertEq(IERC20Metadata(first_).name(), "Staked DETF");
        assertEq(IERC20Metadata(first_).symbol(), "sDETF");
    }

    function test_customMetadataPreserved() public {
        address token_ = rebasingClaimTokenPkg.deployToken(
            IDetf(detf), IDETFNFTVault(address(_bondVault())),
            IVaultFeeOracleQuery(address(indexedexManager)), "Staked basket", "sBASKET"
        );
        assertEq(IERC20Metadata(token_).name(), "Staked basket");
        assertEq(IERC20Metadata(token_).symbol(), "sBASKET");
    }

    function test_stakingPackageRejectsNonNineDecimalBacking() public {
        IDETFNFTVault nft_ = IDETFNFTVault(address(_bondVault()));
        vm.expectRevert();
        rebasingClaimTokenPkg.deployToken(
            IDetf(address(pairToken)), nft_,
            IVaultFeeOracleQuery(address(indexedexManager)), "Invalid backing", "sINVALID"
        );
    }

    function test_legacyUnfundedMintSelectorAbsent() public view {
        bytes4 retired_ = bytes4(keccak256("mintFromNFTSale(uint256,uint256,address)"));
        assertEq(IDiamondLoupe(address(_staking())).facetAddress(retired_), address(0));
    }

    function test_onlyDetfCanFundRewards() public {
        IStakedDETF staking_ = _staking();
        vm.expectRevert(abi.encodeWithSelector(StakedDETFTarget.Unauthorized.selector, address(this)));
        staking_.fundRewards(1e9);
    }

    function test_firstBondFundsPrincipalInAdditionToLiquidity() public {
        (uint256 id_, uint256 lp_) = _firstBond(1_000 ether);
        IDetfBondNFT bond_ = _bondVault();
        StakingMath.BondPosition memory position_ = bond_.positionOf(id_);
        uint256 p_ = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        assertEq(position_.principal, (1_000e9 * (1e18 - p_)) / 1e18);
        assertEq(position_.claimedPrincipal, 0);
        assertEq(position_.startTimestamp, block.timestamp);
        assertEq(position_.vestingDuration, DEFAULT_MIN_LOCK);
        assertGt(lp_, 0);
        assertEq(IERC20(detf).balanceOf(detfUser), 0, "bond principal is staked in escrow");
        assertGe(_staking().balanceOf(address(bond_)), position_.principal);
        assertEq(IERC20(detf).balanceOf(address(_staking())), _staking().stakingState().accountedBacking);
        assertGe(IERC20(reserveHook).balanceOf(address(bond_)), lp_);
    }

    function test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond() public {
        (uint256 id_,) = _firstBond(1_000 ether);
        IDetfBondNFT bond_ = _bondVault();
        uint256 principal_ = bond_.positionOf(id_).principal;
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(detfUser);
        (uint256 paidPrincipal_, uint256 reward_) = bond_.claimBond(id_, detfUser);
        assertEq(paidPrincipal_, principal_ / 2);
        assertEq(_staking().balanceOf(detfUser), paidPrincipal_ + reward_);
        assertEq(bond_.positionOf(id_).claimedPrincipal, paidPrincipal_);
        IStakedDETF staking_ = _staking();
        vm.prank(detfUser);
        staking_.exchangeIn(
            IERC20(address(staking_)), paidPrincipal_ + reward_, IERC20(detf),
            paidPrincipal_ + reward_, detfUser, false, block.timestamp
        );
        assertEq(IERC20(detf).balanceOf(detfUser), paidPrincipal_ + reward_);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(detfUser);
        (uint256 remaining_,) = bond_.claimBond(id_, detfUser);
        assertEq(remaining_, principal_ - paidPrincipal_);
        assertEq(bond_.ownerOf(id_), address(0));
    }

    function _sy(bool staked_) private view returns (IStandardizedYield) {
        IDETFStandardizedYield discovery_ = IDETFStandardizedYield(detf);
        return IStandardizedYield(staked_ ? discovery_.stakingSY() : discovery_.rawSY());
    }

    function _liquidBondPrincipal() private returns (uint256 amount_) {
        (uint256 id_,) = _firstBond(1_000 ether);
        IDetfBondNFT bond_ = _bondVault();
        IStakedDETF staking_ = _staking();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        vm.startPrank(detfUser);
        (uint256 principal_, uint256 reward_) = bond_.claimBond(id_, detfUser);
        amount_ = principal_ + reward_;
        staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(detf), amount_, detfUser, false, block.timestamp);
        vm.stopPrank();
    }

    function test_syAddressesMetadataAndDirectionalDiscovery() public view {
        IStandardizedYield raw_ = _sy(false);
        IStandardizedYield staked_ = _sy(true);
        address staking_ = address(_staking());
        assertTrue(address(raw_) != address(staked_));
        assertTrue(address(raw_) != detf && address(staked_) != staking_);
        assertEq(raw_.decimals(), 9);
        assertEq(staked_.decimals(), 9);
        assertEq(raw_.yieldToken(), detf);
        assertEq(staked_.yieldToken(), staking_);
        assertEq(raw_.exchangeRate(), 1e18);
        (IStandardizedYield.AssetType kind_, address asset_, uint8 decimals_) = staked_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, detf);
        assertEq(decimals_, 9);
        assertTrue(staked_.isValidTokenIn(staking_) && staked_.isValidTokenOut(staking_));
        assertFalse(raw_.isValidTokenIn(staking_) || raw_.isValidTokenOut(staking_));
        assertEq(raw_.getRewardTokens().length, 0);
        assertEq(staked_.getRewardTokens().length, 0);
        address[] memory inputs_ = staked_.getTokensIn();
        for (uint256 i; i < inputs_.length; ++i) {
            assertTrue(staked_.isValidTokenIn(inputs_[i]));
            for (uint256 j; j < i; ++j) assertTrue(inputs_[i] != inputs_[j]);
        }
    }

    function test_rawSYWrapsAndRedeemsExactDETFWithoutStaking() public {
        uint256 amount_ = _liquidBondPrincipal();
        IStandardizedYield sy_ = _sy(false);
        IStakedDETF staking_ = _staking();
        uint256 stakingSupply_ = staking_.totalSupply();
        assertEq(sy_.previewDeposit(detf, amount_), amount_);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(sy_), amount_);
        assertEq(sy_.deposit(detfUser, detf, amount_, amount_), amount_);
        assertEq(sy_.balanceOf(detfUser), amount_);
        assertEq(staking_.totalSupply(), stakingSupply_);
        assertEq(sy_.redeem(detfUser, amount_, detf, amount_, false), amount_);
        vm.stopPrank();
        assertEq(IERC20(detf).balanceOf(detfUser), amount_);
        assertEq(sy_.totalSupply(), 0);
    }

    function test_stakingSYDepositAndRedemptionMatchPreviews() public {
        uint256 amount_ = _liquidBondPrincipal();
        IStandardizedYield sy_ = _sy(true);
        IStakedDETF staking_ = _staking();
        uint256 expected_ = sy_.previewDeposit(detf, amount_);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(sy_), amount_);
        uint256 shares_ = sy_.deposit(detfUser, detf, amount_, expected_);
        assertEq(shares_, expected_);
        assertGe(staking_.balanceOf(address(sy_)), sy_.previewRedeem(detf, shares_));
        uint256 payout_ = sy_.previewRedeem(detf, shares_);
        assertEq(sy_.redeem(detfUser, shares_, detf, payout_, false), payout_);
        vm.stopPrank();
        assertEq(IERC20(detf).balanceOf(detfUser), payout_);
        assertLe(payout_, amount_, "conversion cannot invent backing");
    }

    function test_stakingSYOwnsStaticBalancesAcrossNewBondRewards() public {
        uint256 amount_ = _liquidBondPrincipal();
        IStandardizedYield sy_ = _sy(true);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(sy_), amount_);
        uint256 shares_ = sy_.deposit(detfUser, detf, amount_, 1);
        vm.stopPrank();
        uint256 rate_ = sy_.exchangeRate();
        uint256 balance_ = sy_.balanceOf(detfUser);
        _firstBond(100 ether);
        assertEq(sy_.balanceOf(detfUser), balance_);
        assertEq(sy_.totalSupply(), shares_);
        assertGt(sy_.exchangeRate(), rate_, "new bond rewards fund the existing static shares");
    }

    function test_syInternalBalanceRedemptionConsumesOnlyTransferredSY() public {
        uint256 amount_ = _liquidBondPrincipal();
        IStandardizedYield sy_ = _sy(false);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(sy_), amount_);
        sy_.deposit(detfUser, detf, amount_, amount_);
        sy_.transfer(address(sy_), amount_ / 2);
        vm.stopPrank();
        assertEq(sy_.redeem(address(this), amount_ / 2, detf, amount_ / 2, true), amount_ / 2);
        assertEq(sy_.balanceOf(detfUser), amount_ - amount_ / 2);
        assertEq(IERC20(detf).balanceOf(address(this)), amount_ / 2);
        vm.expectRevert();
        sy_.redeem(address(this), 1, detf, 0, true);
    }

    function test_syDepositSlippageRollsBackInputAndBacking() public {
        uint256 amount_ = _liquidBondPrincipal();
        IStandardizedYield sy_ = _sy(true);
        uint256 expected_ = sy_.previewDeposit(detf, amount_);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(sy_), amount_);
        vm.expectRevert(abi.encodeWithSelector(DETFSYTarget.MinimumOutputNotMet.selector, expected_ + 1, expected_));
        sy_.deposit(detfUser, detf, amount_, expected_ + 1);
        vm.stopPrank();
        assertEq(IERC20(detf).balanceOf(detfUser), amount_);
        assertEq(sy_.totalSupply(), 0);
    }

    function test_priceGatedMintUsesSupplyNeutralReserveSwap() public {
        _firstBond(1_000 ether);
        assertFalse(detfInfo.isMintingAllowed(IERC20(address(pairToken))));
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = _staking().stakingState().accountedBacking;
        uint256 quote_ = detfExchangeIn.previewExchangeIn(IERC20(address(pairToken)), 10 ether, IERC20(detf));
        assertGt(quote_, 0);
        vm.prank(detfUser);
        uint256 out_ = detfExchangeIn.exchangeIn(
            IERC20(address(pairToken)), 10 ether, IERC20(detf), quote_, detfUser, false, block.timestamp
        );
        assertEq(out_, quote_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(_staking().stakingState().accountedBacking, backing_, "swap has no issuance seigniorage");
    }

    function test_priceGatedBurnUsesSupplyNeutralReserveSwap() public {
        IUniswapV4Detf.PkgArgs memory args_ = _defaultDetfArgs();
        args_.mintThreshold = 2e18;
        args_.burnThreshold = 0.1e18;
        args_.name = "Wide deadband basket";
        detf = _deployHookThenDetf(args_);
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        vm.prank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        uint256 amount_ = _liquidBondPrincipal() / 100;
        assertFalse(detfInfo.isBurningAllowed(IERC20(address(pairToken))));
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 backing_ = _staking().stakingState().accountedBacking;
        uint256 quote_ = detfExchangeIn.previewExchangeIn(IERC20(detf), amount_, IERC20(address(pairToken)));
        assertGt(quote_, 0);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, amount_);
        uint256 out_ = detfExchangeIn.exchangeIn(
            IERC20(detf), amount_, IERC20(address(pairToken)), quote_, detfUser, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(out_, quote_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(_staking().stakingState().accountedBacking, backing_);
    }

    function test_standingRecipientsReceiveNewExpansionAfterAllStakeUnstakes() public {
        _liquidBondPrincipal();
        IStakedDETF staking_ = _staking();
        address beneficiary_ = _bondVault().ownerOf(1);
        assertEq(beneficiary_, _bondVault().ownerOf(2), "fixture uses creator fallback");
        uint256 feeBalance_ = staking_.balanceOf(beneficiary_);
        assertGt(feeBalance_, 0);
        vm.prank(beneficiary_);
        staking_.exchangeIn(
            IERC20(address(staking_)), feeBalance_, IERC20(detf), feeBalance_, beneficiary_, false, block.timestamp
        );
        assertEq(staking_.totalSupply(), 0);
        uint256 index_ = staking_.stakingState().gonsPerUnit;
        uint256 backing_ = staking_.stakingState().accountedBacking;
        // Actual underlying yield raises reserve value without adding any staking principal.
        vm.startPrank(detfUser);
        pairToken.approve(address(pairProtocolVault), 100_000 ether);
        pairProtocolVault.simulateYield(100_000 ether);
        vm.stopPrank();
        vm.warp(block.timestamp + 8 hours);
        uint256 expected_ = detfInfo.pendingExpansionDetf();
        assertGt(expected_, 0);
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), expected_);
        assertGt(staking_.balanceOf(beneficiary_), 0);
        assertEq(staking_.stakingState().gonsPerUnit, index_, "zero ordinary stake has no rebase allocation");
        assertEq(staking_.stakingState().accountedBacking, backing_ + expected_);
    }
}

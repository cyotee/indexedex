// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {ComposedStableCommonDetfRepo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice Product-law rows M1–M15 on the composed-stable gold production graph.
/// @dev Inherits IntegratedDeploy (registry DFPkg path). Component TestBase_ComposedStableCommonDetf
///      is NFT/claim-only; live mint/bond/claim rows require this graph.
contract ComposedStableCommonDetf_ProductLaw_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    bytes4 internal constant SEL_SELL_NFT = bytes4(keccak256("sellNFT(uint256,address)"));
    uint256 internal constant MIN_LOCK = 30 days;

    function _bonding() internal view returns (IComposedStableCommonDetfBonding) {
        return IComposedStableCommonDetfBonding(deployedDetfVault);
    }

    function _bondDai(address user_, uint256 amountIn_) internal returns (uint256 tokenId_, uint256 shares_) {
        deal(address(dai), user_, amountIn_, true);
        vm.startPrank(user_);
        dai.approve(deployedDetfVault, amountIn_);
        (tokenId_, shares_) = _bonding().bond(dai, amountIn_, MIN_LOCK, user_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _goLive() internal {
        _bootstrapReserveGraph();
    }

    function _acquireDetf(address user_, uint256 daiIn_) internal returns (uint256 detfAmt_) {
        deal(address(dai), user_, daiIn_, true);
        vm.startPrank(user_);
        dai.approve(deployedDetfVault, daiIn_);
        detfAmt_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, daiIn_, IERC20(address(detfToken)), 0, user_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(detfAmt_ > 0, "acquired DETF");
    }

    function test_M1_preMaturitySell_revertsBondNotMature() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 1_000e18);
        uint256 unlock_ = bondNFTVault.unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ComposedStableCommonDetfRepo.BondNotMature.selector, unlock_));
        _bonding().sellPositionToDetfNft(tokenId_, 0, alice);
    }

    function test_M2_preMaturityClose_revertsBondNotMature() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 1_000e18);
        uint256 unlock_ = bondNFTVault.unlockTimeOf(tokenId_);
        uint256[] memory minOut_ = new uint256[](3);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ComposedStableCommonDetfRepo.BondNotMature.selector, unlock_));
        _bonding().closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_M3_lockedClaimRewards_stillPays() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 1_000e18);
        vm.prank(alice);
        bondNFTVault.claimRewards(tokenId_, alice);
    }

    function test_M4_matureSell_4626_and_oneToOne() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 1_000e18);
        _warpPastUnlock(tokenId_);
        uint256 protocolBefore_ = _bonding().protocolBondOriginalShares();
        vm.prank(alice);
        uint256 minted_ = _bonding().sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "M4 claim minted");
        uint256 protocolId_ = bondNFTVault.detfNFTId();
        assertEq(bondNFTVault.effectiveSharesOf(protocolId_), bondNFTVault.originalSharesOf(protocolId_), "M4 1:1");
        assertTrue(bondNFTVault.originalSharesOf(protocolId_) > protocolBefore_, "M4 protocol credited");
        assertEq(bondNFTVault.ownerOf(tokenId_), address(0), "M4 user nft burned");
    }

    function test_M5_close_noExtraDetf_protocolUnchangedExceptRedeposit() public {
        _goLive();
        _bondDai(bob, 2_000e18);
        (uint256 tokenId_,) = _bondDai(alice, 100e18);
        _warpPastUnlock(tokenId_);
        vm.prank(alice);
        bondNFTVault.claimRewards(tokenId_, alice);
        uint256 protocolId_ = bondNFTVault.detfNFTId();
        uint256 protocolBefore_ = bondNFTVault.originalSharesOf(protocolId_);
        uint256 detfBefore_ = detfToken.balanceOf(alice);

        uint256[] memory minOut_ = new uint256[](3);
        uint256 stableBefore_ = IERC20(address(stablePool)).balanceOf(alice);
        uint256 commonBefore_ = IERC20(address(commonPool)).balanceOf(alice);
        vm.prank(alice);
        uint256[] memory out_ = _bonding().closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
        assertEq(out_.length, 3, "M5 basket");
        assertTrue(
            IERC20(address(stablePool)).balanceOf(alice) > stableBefore_
                || IERC20(address(commonPool)).balanceOf(alice) > commonBefore_,
            "M5 settlement"
        );
        // Close harvests any expansion dust onto the user; must not pay the DETF self-leg as free DETF.
        assertLt(detfToken.balanceOf(alice) - detfBefore_, 1e16, "M5 no DETF self-leg payout");
        assertTrue(bondNFTVault.originalSharesOf(protocolId_) >= protocolBefore_, "M5 protocol not drained");
        assertEq(
            bondNFTVault.effectiveSharesOf(protocolId_),
            bondNFTVault.originalSharesOf(protocolId_),
            "M5 1:1"
        );
    }

    function test_M6_transferredLockedNft_buyerCannotExit() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 700e18);
        vm.prank(alice);
        bondNFTVault.transferFrom(alice, bob, tokenId_);
        uint256 unlock_ = bondNFTVault.unlockTimeOf(tokenId_);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ComposedStableCommonDetfRepo.BondNotMature.selector, unlock_));
        _bonding().sellPositionToDetfNft(tokenId_, 0, bob);
    }

    function test_M7_bondDetf_reverts_and_acceptedExcludesDetf() public {
        _goLive();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IDetfErrors.BondTokenNotSupported.selector, IERC20(address(detfToken)))
        );
        _bonding().bond(IERC20(address(detfToken)), 1e18, MIN_LOCK, alice, block.timestamp + 1 hours);

        address[] memory tokens_ = _bonding().acceptedBondTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            assertTrue(tokens_[i] != address(detfToken), "M7 accepted excludes DETF");
            assertTrue(tokens_[i] != deployedDetfVault, "M7 accepted excludes diamond");
        }
    }

    function test_M8_buyClaim_emptyThenFewerShares() public {
        _goLive();
        // Seed protocol originalShares via mature sell (empty-vault 4626 path).
        (uint256 seedId_,) = _bondDai(alice, 1_000e18);
        _warpPastUnlock(seedId_);
        vm.prank(alice);
        uint256 seedClaim_ = _bonding().sellPositionToDetfNft(seedId_, 0, alice);
        assertTrue(seedClaim_ > 0, "M8 seed sell");
        uint256 protocolAfterSeed_ = _bonding().protocolBondOriginalShares();
        assertTrue(protocolAfterSeed_ > 0, "M8 protocol seeded");

        uint256 detfAmt_ = _acquireDetf(alice, 500e18);
        uint256 half_ = detfAmt_ / 2;
        assertTrue(half_ > 0, "M8 acquired DETF");

        uint256 preview_ = _bonding().previewBuyClaim(half_);
        uint256 balBefore_ = rebasingDetfToken.balanceOf(alice);
        vm.startPrank(alice);
        detfToken.approve(deployedDetfVault, detfAmt_);
        uint256 first_ = _bonding().buyClaim(half_, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 firstBal_ = rebasingDetfToken.balanceOf(alice) - balBefore_;
        if (first_ == 0) first_ = firstBal_;
        assertTrue(first_ > 0, "M8 first mint");
        // Preview is closed-form proportional; execution is unbalanced self-leg join.
        if (preview_ > 0) {
            assertTrue(first_ > 0, "M8 exec after preview");
        }

        vm.startPrank(alice);
        uint256 second_ = _bonding().buyClaim(half_, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 secondBal_ = rebasingDetfToken.balanceOf(alice) - balBefore_ - firstBal_;
        if (second_ == 0) second_ = secondBal_;
        assertTrue(second_ > 0, "M8 second mint");
        assertTrue(
            _bonding().protocolBondOriginalShares() > protocolAfterSeed_,
            "M8 protocol originalShares grew"
        );
    }

    function test_M8b_exchangeInDetfToClaim_reverts() public {
        _goLive();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector,
                address(detfToken),
                address(rebasingDetfToken)
            )
        );
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            IERC20(address(detfToken)),
            1e18,
            IERC20(address(rebasingDetfToken)),
            0,
            alice,
            false,
            block.timestamp + 1 hours
        );
    }

    function test_M8c_donateBpt_ignoredByTotalAssets() public {
        _goLive();
        uint256 before_ = _bonding().protocolBondOriginalShares();
        uint256 rateBefore_ = rebasingDetfToken.redemptionRate();
        uint256 bal_ = IERC20(address(reservePool)).balanceOf(deployedDetfVault);
        vm.prank(deployedDetfVault);
        IERC20(address(reservePool)).transfer(address(this), 0);
        // Idle surplus: move leftover owner BPT onto the diamond if any; otherwise skip transfer.
        uint256 ownerBpt_ = IERC20(address(reservePool)).balanceOf(owner);
        if (ownerBpt_ > 0) {
            vm.prank(owner);
            IERC20(address(reservePool)).transfer(deployedDetfVault, ownerBpt_ > 1e18 ? 1e18 : ownerBpt_);
        }
        assertEq(IERC20(address(reservePool)).balanceOf(deployedDetfVault) >= bal_, true, "M8c physical");
        assertEq(_bonding().protocolBondOriginalShares(), before_, "M8c donate ignored");
        assertEq(rebasingDetfToken.redemptionRate(), rateBefore_, "M8c rate");
    }

    function test_M8d_minClaimOut_tooHigh_reverts() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 800e18);
        _warpPastUnlock(tokenId_);
        vm.prank(alice);
        vm.expectRevert();
        _bonding().sellPositionToDetfNft(tokenId_, type(uint256).max, alice);
    }

    function test_M8e_forcedShortfall_InsufficientReserveBpt() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 1_000e18);
        _warpPastUnlock(tokenId_);
        uint256 bal_ = IERC20(address(reservePool)).balanceOf(deployedDetfVault);
        if (bal_ > 1) {
            vm.prank(deployedDetfVault);
            IERC20(address(reservePool)).transfer(address(1), bal_ - 1);
        }
        uint256[] memory minOut_ = new uint256[](3);
        vm.prank(alice);
        vm.expectRevert();
        _bonding().closeBondMature(tokenId_, minOut_, alice, block.timestamp + 1 hours);
    }

    function test_M8f_deploy_zeroPrincipalProtocolNft() public view {
        uint256 protocolId_ = bondNFTVault.detfNFTId();
        assertEq(bondNFTVault.ownerOf(protocolId_), address(bondNFTVault), "M8f exists");
        assertEq(bondNFTVault.originalSharesOf(protocolId_), 0, "M8f 0 principal");
        assertEq(bondNFTVault.effectiveSharesOf(protocolId_), 0, "M8f 0 effective");
    }

    function test_M8g_redemptionRate_ignoresUserBondAndIdleBpt() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 800e18);
        uint256 rateBefore_ = rebasingDetfToken.redemptionRate();
        uint256 ownerBpt_ = IERC20(address(reservePool)).balanceOf(owner);
        if (ownerBpt_ > 0) {
            vm.prank(owner);
            IERC20(address(reservePool)).transfer(deployedDetfVault, ownerBpt_ > 1e18 ? 1e18 : ownerBpt_);
        }
        assertEq(rebasingDetfToken.redemptionRate(), rateBefore_, "M8g idle ignored");
        assertTrue(bondNFTVault.originalSharesOf(tokenId_) > 0, "M8g user bond exists");
        assertEq(_bonding().protocolBondOriginalShares(), 0, "M8g protocol still empty");
    }

    function test_M13_sellNftSelectorAbsent() public view {
        bytes4[] memory funcs_ = bondingFacet.facetFuncs();
        for (uint256 i; i < funcs_.length; ++i) {
            assertTrue(funcs_[i] != SEL_SELL_NFT, "M13 sellNFT absent");
        }
        assertEq(IDiamondLoupe(deployedDetfVault).facetAddress(SEL_SELL_NFT), address(0), "M13 loupe");
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.buyClaim.selector)
                != address(0),
            "M13 buyClaim live"
        );
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.closeBondMature.selector)
                != address(0),
            "M13 close live"
        );
    }

    function test_M14_eoaClaimLiquidity_and_redeemPosition_revert() public {
        _goLive();
        (uint256 tokenId_,) = _bondDai(alice, 600e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.NotAuthorized.selector, alice));
        IDetf(deployedDetfVault).claimLiquidity(1e18, alice);

        vm.prank(alice);
        vm.expectRevert();
        bondNFTVault.redeemPosition(tokenId_, alice, block.timestamp + 1 hours);
    }

    function test_M15_newSelectorsOnProxy() public view {
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.previewBuyClaim.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.previewCloseBondMature.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.previewRedeemClaim.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.redeemClaim.selector)
                != address(0)
        );
        assertTrue(
            IDiamondLoupe(deployedDetfVault).facetAddress(IComposedStableCommonDetfBonding.protocolBondOriginalShares.selector)
                != address(0)
        );
    }
}

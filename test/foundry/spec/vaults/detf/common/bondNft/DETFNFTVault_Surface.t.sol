// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";
/// @notice Catalog J1-J3 against the real funded NFT proxy and factory cuts.
contract DETFNFTVault_Surface_Test is TestBase_UniswapV4Detf, DETFFundedStakingArtifacts {
    function _nft() private view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }
    function _stake() private view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }

    function _controls() private pure returns (bytes4[] memory c_) {
        c_ = new bytes4[](20);
        c_[0] = IDetfBondNFT.detf.selector; c_[1] = IDetfBondNFT.lpToken.selector;
        c_[2] = IDetfBondNFT.initializeReservedBondNfts.selector; c_[3] = IDetfBondNFT.reservedBondNftsWired.selector;
        c_[4] = IDetfBondNFT.createFundedPosition.selector; c_[5] = IDetfBondNFT.positionOf.selector;
        c_[6] = IDetfBondNFT.previewClaim.selector; c_[7] = IDetfBondNFT.claimPrincipal.selector;
        c_[8] = IDetfBondNFT.claimRewards.selector; c_[9] = IDetfBondNFT.claimBond.selector;
        c_[10] = IDetfBondNFT.transferHeldToken.selector; c_[11] = IStandardVault.vaultFeeTypeIds.selector;
        c_[12] = IStandardVault.contentsId.selector; c_[13] = IStandardVault.vaultTypes.selector;
        c_[14] = IStandardVault.vaultConfig.selector;
        c_[15] = bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)"));
        c_[16] = bytes4(keccak256("donate(address,address,uint256,uint256,bool,uint256)"));
        c_[17] = IDetfNftReserveDonation.donateWithPermit2Allowance.selector;
        c_[18] = IDetfNftReserveDonation.donateWithPermit2Signature.selector; c_[19] = IDetfNftReserveDonation.previewDonate.selector;
    }

    function test_J1_J2_fundedControlsMatchFacetCutsAndAssembledProxy() public view {
        address proxy_ = address(_nft()); IDiamondLoupe loupe_ = IDiamondLoupe(proxy_);
        address facet_ = loupe_.facetAddress(IDetfBondNFT.createFundedPosition.selector);
        bytes4[] memory exports_ = IFacet(facet_).facetFuncs(); bytes4[] memory controls_ = _controls();
        assertEq(exports_.length, controls_.length);
        for (uint256 i_; i_ < controls_.length; ++i_) {
            bool found_;
            for (uint256 j_; j_ < exports_.length; ++j_) if (exports_[j_] == controls_[i_]) found_ = true;
            assertTrue(found_); assertEq(loupe_.facetAddress(controls_[i_]), facet_);
        }
        IDiamond.FacetCut[] memory cuts_ = bondNftVaultPkg.facetCuts();
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            assertLe(cuts_[i_].facetAddress.code.length, 24_576);
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                bytes4 sel_ = cuts_[i_].functionSelectors[j_];
                address final_ = cuts_[i_].facetAddress;
                for (uint256 k_ = i_ + 1; k_ < cuts_.length; ++k_)
                    for (uint256 x_; x_ < cuts_[k_].functionSelectors.length; ++x_)
                        if (cuts_[k_].functionSelectors[x_] == sel_) final_ = cuts_[k_].facetAddress;
                assertEq(loupe_.facetAddress(sel_), final_);
            }
        }
        assertEq(loupe_.facetAddress(IERC721.transferFrom.selector), facet_);
        assertEq(loupe_.facetAddress(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), facet_);
        assertEq(loupe_.facetAddress(bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))), facet_);
        assertTrue(loupe_.facetAddress(IERC721Metadata.tokenURI.selector) != address(0));
    }

    function test_J2_retiredLpAndEffectiveShareSelectorsCannotBeCalled() public {
        string[17] memory signatures_ = [
            "initializeDETFNFT()", "createPosition(uint256,uint256,address)", "createPositionWithEffectiveBase(uint256,uint256,uint256,address)",
            "redeemPosition(uint256,address,uint256)", "sellPositionToDetfNft(uint256)", "originalSharesOf(uint256)",
            "effectiveSharesOf(uint256)", "totalShares()", "totalOriginalShares()", "rewardPerShares()",
            "convertToAssets(uint256)", "convertToShares(uint256)", "rewardToken()", "compoundProtocolRewards()",
            "addEffectiveSharesOnly(uint256,uint256)", "addToDETFNFT(uint256,uint256)", "pendingRewards(uint256)"
        ];
        address proxy_ = address(_nft());
        for (uint256 i_; i_ < signatures_.length; ++i_) {
            bytes4 sel_ = bytes4(keccak256(bytes(signatures_[i_])));
            assertEq(IDiamondLoupe(proxy_).facetAddress(sel_), address(0));
            (bool ok_,) = proxy_.call(abi.encodePacked(sel_)); assertFalse(ok_);
        }
    }

    function test_J3_guardedTransferOverloadsKeepPositionAndRejectCustodyDestinations() public {
        (uint256 id_,) = _firstBond(1_000 ether); IDetfBondNFT n_ = _nft();
        address next_ = makeAddr("safe bond recipient"); bytes32 terms_ = keccak256(abi.encode(n_.positionOf(id_)));
        vm.prank(detfUser); vm.expectRevert(); n_.transferFrom(detfUser, detf, id_);
        vm.prank(detfUser); n_.safeTransferFrom(detfUser, next_, id_);
        vm.prank(next_); n_.safeTransferFrom(next_, detfUser, id_, hex"1234");
        assertEq(n_.ownerOf(id_), detfUser); assertEq(keccak256(abi.encode(n_.positionOf(id_))), terms_);
    }
}

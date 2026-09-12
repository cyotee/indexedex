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
/// @notice Registered funded-NFT lifecycle, authorization and standing-role regressions.
contract DETFNFTVaultDFPkg_Deploy_Test is TestBase_UniswapV4Detf, DETFFundedStakingArtifacts {
    function _nft() private view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }
    function _stake() private view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }

    function test_reservedRolesHaveNoPurchasedPrincipalAndCreatorFallbackPersists() public {
        IDetfBondNFT n_ = _nft();
        assertTrue(n_.reservedBondNftsWired()); assertEq(n_.ownerOf(0), address(n_));
        assertEq(n_.ownerOf(1), n_.ownerOf(2)); assertTrue(n_.ownerOf(1) != address(0));
        assertEq(n_.detf(), detf); assertEq(address(n_.lpToken()), reserveHook);
        for (uint256 i_; i_ < 3; ++i_) {
            assertEq(n_.positionOf(i_).principal, 0); assertEq(n_.previewClaim(i_).principalDue, 0);
        }
        (uint256 id_,) = _firstBond(1_000 ether); assertEq(id_, 3);
        assertEq(n_.ownerOf(id_), detfUser);
    }

    function test_reservedInitializationAndPositionFundingAreDetfOnly() public {
        IDetfBondNFT n_ = _nft();
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, address(this)));
        n_.initializeReservedBondNfts(address(this), address(this));
        vm.prank(detf); vm.expectRevert(DETFFundedBondTarget.AlreadyInitialized.selector);
        n_.initializeReservedBondNfts(address(this), address(this));
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, address(this)));
        n_.createFundedPosition(1e9, DEFAULT_MIN_LOCK, address(this));
        assertEq(n_.ownerOf(0), address(n_)); assertEq(_stake().totalSupply(), 0);
    }

    function test_positionPrincipalIsFundedOnceAndNotDerivedFromProtocolLp() public {
        (uint256 id_,) = _firstBond(1_000 ether); IDetfBondNFT n_ = _nft(); IStakedDETF stake_ = _stake();
        Math.BondPosition memory p_ = n_.positionOf(id_);
        assertGt(p_.principal, 0); assertEq(p_.claimedPrincipal, 0); assertEq(p_.startTimestamp, block.timestamp);
        assertEq(p_.vestingDuration, DEFAULT_MIN_LOCK); assertEq(p_.stakingGons, stake_.gonsOf(address(n_)));
        assertGe(stake_.balanceOf(address(n_)), p_.principal);
        assertEq(IERC20(detf).balanceOf(address(stake_)), stake_.stakingState().accountedBacking);
        uint256 lp_ = n_.lpToken().balanceOf(address(n_));
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        vm.prank(detfUser); uint256 paid_ = n_.claimPrincipal(id_, address(0));
        assertEq(paid_, p_.principal / 2); assertEq(n_.positionOf(id_).claimedPrincipal, paid_);
        assertEq(stake_.balanceOf(detfUser), paid_); assertEq(n_.lpToken().balanceOf(address(n_)), lp_);
    }

    function test_ownerOperatorAndTransferPreserveRemainingVesting() public {
        (uint256 id_,) = _firstBond(1_000 ether); IDetfBondNFT n_ = _nft();
        Math.BondPosition memory p_ = n_.positionOf(id_); address next_ = makeAddr("bond next owner");
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, address(this)));
        n_.claimPrincipal(id_, next_);
        vm.prank(detfUser); n_.approve(address(this), id_);
        uint256 paid_ = n_.claimPrincipal(id_, detfUser); assertEq(paid_, p_.principal / 2);
        vm.prank(detfUser); n_.transferFrom(detfUser, next_, id_);
        assertEq(n_.getApproved(id_), address(0));
        Math.BondPosition memory after_ = n_.positionOf(id_);
        assertEq(after_.startTimestamp, p_.startTimestamp); assertEq(after_.vestingDuration, p_.vestingDuration);
        assertEq(after_.principal, p_.principal); assertEq(after_.claimedPrincipal, paid_);
        vm.prank(detfUser); vm.expectRevert(); n_.claimBond(id_, detfUser);
        vm.warp(p_.startTimestamp + p_.vestingDuration);
        vm.prank(next_); (uint256 rest_, uint256 reward_) = n_.claimBond(id_, address(0));
        assertEq(rest_, p_.principal - paid_); assertEq(_stake().balanceOf(next_), rest_ + reward_);
        assertEq(n_.ownerOf(id_), address(0)); vm.expectRevert(); n_.previewClaim(id_);
    }

    function test_rewardOnlyClaimIsImmediateAndDoesNotUnlockPrincipal() public {
        (uint256 id_,) = _firstBond(1_000 ether); IDetfBondNFT n_ = _nft();
        Math.BondPosition memory p_ = n_.positionOf(id_); uint256 due_ = n_.previewClaim(id_).rewardsDue;
        assertGt(due_, 0); assertEq(n_.previewClaim(id_).principalDue, 0);
        vm.prank(detfUser); assertEq(n_.claimRewards(id_, detfUser), due_);
        Math.BondPosition memory after_ = n_.positionOf(id_);
        assertEq(after_.principal, p_.principal); assertEq(after_.claimedPrincipal, 0);
        assertEq(after_.stakingGons, p_.stakingGons - due_ * _stake().stakingState().gonsPerUnit);
        vm.prank(detfUser); assertEq(n_.claimRewards(id_, detfUser), 0);
        assertEq(_stake().balanceOf(detfUser), due_);
    }

    function test_reservedRolesCannotClaimPurchasedEscrow() public {
        _firstBond(1_000 ether); IDetfBondNFT n_ = _nft(); uint256 gons_ = _stake().gonsOf(address(n_));
        for (uint256 i_; i_ < 3; ++i_) {
            address role_ = n_.ownerOf(i_);
            vm.prank(role_); vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.ReservedBond.selector, i_));
            n_.claimBond(i_, role_);
        }
        assertEq(_stake().gonsOf(address(n_)), gons_);
    }

    function test_reserveCustodyCannotMovePurchasedRawOrStakingAssets() public {
        _firstBond(1_000 ether); IDetfBondNFT n_ = _nft(); IERC20 lp_ = n_.lpToken();
        uint256 held_ = lp_.balanceOf(address(n_));
        vm.expectRevert(abi.encodeWithSelector(DETFFundedBondTarget.NotAuthorized.selector, address(this)));
        n_.transferHeldToken(lp_, address(this), 1);
        vm.prank(detf); vm.expectRevert(DETFFundedBondTarget.ProtectedStakingAsset.selector);
        n_.transferHeldToken(IERC20(detf), address(this), 1);
        IERC20 stake_ = IERC20(address(_stake()));
        vm.prank(detf); vm.expectRevert(DETFFundedBondTarget.ProtectedStakingAsset.selector);
        n_.transferHeldToken(stake_, address(this), 1);
        assertEq(lp_.balanceOf(address(n_)), held_);
    }

    function test_feeRoleTransferSettlesOldBoundaryThenPaysNewOwnerOnLaterMint() public {
        _firstBond(1_000 ether); IDetfBondNFT n_ = _nft(); IStakedDETF stake_ = _stake();
        address old_ = n_.ownerOf(1); address next_ = makeAddr("new fee role owner");
        uint256 oldBefore_ = stake_.balanceOf(old_);
        vm.startPrank(detfUser); pairToken.approve(address(pairProtocolVault), 100_000 ether);
        pairProtocolVault.simulateYield(100_000 ether); vm.stopPrank();
        vm.warp(block.timestamp + 25 hours); uint256 pending_ = detfInfo.pendingExpansionDetf(); assertGt(pending_, 0);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(old_); n_.transferFrom(old_, next_, 1);
        assertEq(IERC20(detf).totalSupply(), supply_ + pending_); assertGt(stake_.balanceOf(old_), oldBefore_);
        assertEq(stake_.balanceOf(next_), 0); assertEq(n_.ownerOf(1), next_);
        _firstBond(100 ether); assertGt(stake_.balanceOf(next_), 0);
    }

    function test_packageArgumentProcessingRequiresRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(IDETFNFTVaultDFPkg.NotCalledByRegistry.selector, address(this)));
        bondNftVaultPkg.processArgs("");
    }
}

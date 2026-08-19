// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/**
 * @title ComposedStableCommonDetf_Alignment_FeeCreatorClaim
 * @notice D28 FC1–FC12 on the production Composed stable Open-mode proxy.
 */
contract ComposedStableCommonDetf_Alignment_FeeCreatorClaim is ComposedStableCommonDetf_IntegratedDeploy_Test {
    uint256 internal constant MIN_LOCK = 30 days;

    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function _composedMintThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return bondNFTVault;
    }

    function _bonding() internal view returns (IComposedStableCommonDetfBonding) {
        return IComposedStableCommonDetfBonding(deployedDetfVault);
    }

    function _bootstrapAndBond(address bonder_, uint256 daiIn_) internal returns (uint256 tokenId_) {
        _bootstrapReserveGraph();
        deal(address(dai), bonder_, daiIn_, true);
        vm.startPrank(bonder_);
        dai.approve(deployedDetfVault, daiIn_);
        (tokenId_,) = _bonding().bond(dai, daiIn_, MIN_LOCK, bonder_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_FC1_composed_feeToAndCreatorCanClaim() public {
        _bootstrapAndBond(alice, 1_000e18);
        IDETFNFTVault nft_ = _nft();
        assertTrue(nft_.reservedBondNftsWired(), "reserved wired");
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), _feeTo(), "id1 feeTo");
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), _feeTo(), "id2 D21");

        uint256 reserveDetfBefore_ = detfToken.balanceOf(address(reservePool));
        uint256 potBefore_ = _potBalance();
        _liveMint(alice, 50e18);
        uint256 potAfter_ = _potBalance();
        assertTrue(potAfter_ > potBefore_, "live mint pot");
        assertEq(detfToken.balanceOf(address(reservePool)), reserveDetfBefore_, "D11 no DETF into reserve");

        uint256 c1_ = _claim(DETF_FEE_TO_BOND_NFT_ID, _feeTo());
        uint256 c2_ = _claim(DETF_CREATOR_BOND_NFT_ID, _feeTo());
        assertTrue(c1_ > 0, "FC1 id1 claimed");
        assertTrue(c2_ > 0, "FC1 id2 claimed");
    }

    function test_FC2_composed_claimEqualsPendingAndBalance() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        IDETFNFTVault nft_ = _nft();
        uint256 pending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 balBefore_ = detfToken.balanceOf(_feeTo());
        uint256 claimed_ = _claim(DETF_FEE_TO_BOND_NFT_ID, _feeTo());
        assertEq(claimed_, pending_, "FC2 claim==pending");
        assertEq(detfToken.balanceOf(_feeTo()) - balBefore_, claimed_, "FC2 balance delta");
    }

    function test_FC3_composed_dueAmountsFloor() public {
        _bootstrapAndBond(alice, 1_000e18);
        IDETFNFTVault nft_ = _nft();
        uint256 F_ = nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 C_ = nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 T_ = nft_.totalShares();
        _liveMint(alice, 50e18);
        uint256 p1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 p2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 acc_ = p1_ + p2_ + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        assertTrue(acc_ > 0, "new pot");
        uint256 due1_ = (acc_ * F_) / T_;
        uint256 due2_ = (acc_ * C_) / T_;
        assertLe(p1_ > due1_ ? p1_ - due1_ : due1_ - p1_, 1, "FC3 id1 floor");
        assertLe(p2_ > due2_ ? p2_ - due2_ : due2_ - p2_, 1, "FC3 id2 floor");
    }

    function test_FC4_composed_newSharesDoNotClaimOldPot() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        IDETFNFTVault nft_ = _nft();
        uint256 pending1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 pending2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 freeDetf_ = detfToken.balanceOf(alice) / 20;
        if (freeDetf_ == 0) freeDetf_ = detfToken.balanceOf(alice);
        vm.startPrank(alice);
        detfToken.approve(deployedDetfVault, freeDetf_);
        _bonding().buyClaim(freeDetf_, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 after1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 after2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        assertLe(after1_ > pending1_ ? after1_ - pending1_ : pending1_ - after1_, 1e13, "FC4 id1");
        assertLe(after2_ > pending2_ ? after2_ - pending2_ : pending2_ - after2_, 1e13, "FC4 id2");
    }

    function test_FC5_composed_newPotAtNewWeights() public {
        _bootstrapAndBond(alice, 1_000e18);
        IDETFNFTVault nft_ = _nft();
        uint256 pendingBefore_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 accBefore_ = pendingBefore_
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        _liveMint(alice, 50e18);
        uint256 fromNew_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID) - pendingBefore_;
        uint256 accAfter_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 delta_ = accAfter_ > accBefore_ ? accAfter_ - accBefore_ : 0;
        uint256 dueNew_ = (delta_ * nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID)) / nft_.totalShares();
        assertLe(fromNew_ > dueNew_ ? fromNew_ - dueNew_ : dueNew_ - fromNew_, 1, "FC5 id1 new pot");
    }

    function test_FC6_composed_secondClaimZero() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        uint256 first_ = _claim(DETF_FEE_TO_BOND_NFT_ID, _feeTo());
        assertTrue(first_ > 0, "first claim");
        uint256 second_ = _claim(DETF_FEE_TO_BOND_NFT_ID, _feeTo());
        assertEq(second_, 0, "FC6 second claim 0");
    }

    function test_FC7_composed_nonOwnerCannotClaim() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        IDETFNFTVault nft_ = _nft();
        vm.prank(alice);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, alice);
    }

    function test_FC8_composed_ids1and2CannotSellOrClose() public {
        _bootstrapAndBond(alice, 1_000e18);
        assertTrue(_nft().reservedBondNftsWired(), "wired");
        address feeTo_ = _feeTo();
        uint256 deadline_ = block.timestamp + 1 hours;
        uint256[] memory minOut_ = new uint256[](3);
        vm.prank(feeTo_);
        vm.expectRevert();
        _bonding().closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(feeTo_);
        vm.expectRevert();
        _bonding().closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(feeTo_);
        vm.expectRevert();
        _bonding().sellPositionToDetfNft(DETF_FEE_TO_BOND_NFT_ID, 0, feeTo_);
    }

    function test_FC9_composed_d2NoOriginalShares() public {
        _bootstrapAndBond(alice, 1_000e18);
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 original");
        assertTrue(nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID) > 0, "FC9 id1 effective");
        assertTrue(nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID) > 0, "FC9 id2 effective");
    }

    function test_FC10_composed_feeToChangeDoesNotMoveId1() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        address original_ = _feeTo();
        address newFeeTo_ = makeAddr("newFeeTo");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(newFeeTo_));
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), original_, "FC10 owner stays");
        uint256 claimed_ = _claim(DETF_FEE_TO_BOND_NFT_ID, original_);
        assertTrue(claimed_ > 0, "original still claims");
        vm.prank(newFeeTo_);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, newFeeTo_);
    }

    function test_FC11_composed_creatorZeroFeeToOwnsBoth() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), _feeTo());
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), _feeTo());
        uint256 due1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 due2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 c1_ = _claim(DETF_FEE_TO_BOND_NFT_ID, _feeTo());
        uint256 c2_ = _claim(DETF_CREATOR_BOND_NFT_ID, _feeTo());
        assertEq(c1_, due1_, "FC11 id1");
        assertEq(c2_, due2_, "FC11 id2");
        assertTrue(c1_ + c2_ < detfToken.totalSupply(), "not whole supply");
    }

    function test_FC12_composed_conservationTwoWaves() public {
        _bootstrapAndBond(alice, 1_000e18);
        _liveMint(alice, 50e18);
        deal(address(dai), bob, 200e18, true);
        vm.startPrank(bob);
        dai.approve(deployedDetfVault, 200e18);
        _bonding().bond(dai, 200e18, MIN_LOCK, bob, block.timestamp + 1 hours);
        vm.stopPrank();
        _liveMint(bob, 25e18);
        IDETFNFTVault nft_ = _nft();
        uint256 claimed_ = _claim(DETF_FEE_TO_BOND_NFT_ID, _feeTo())
            + _claim(DETF_CREATOR_BOND_NFT_ID, _feeTo())
            + _claim(DETF_FIRST_USER_BOND_NFT_ID, alice);
        uint256 leftover_ = nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID);
        try this.claimProtocolForFc12() returns (uint256 p0_) {
            claimed_ += p0_;
        } catch {}
        leftover_ = nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID);
        assertLe(claimed_ + leftover_, detfToken.totalSupply(), "FC12 not over mint");
        assertLe(leftover_, detfToken.balanceOf(address(nft_)) + 4, "FC12 leftover backed");
    }

    function claimProtocolForFc12() external returns (uint256) {
        return _nft().claimRewards(DETF_PROTOCOL_BOND_NFT_ID, address(this));
    }
}

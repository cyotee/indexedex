// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/**
 * @title UniswapV4SingleStandardExchangeDETF_Alignment_FeeCreatorClaim
 * @notice D28 FC1–FC12 on the production Uni V4 Single SE CP proxy. Open mode. Small mints.
 */
contract UniswapV4SingleStandardExchangeDETF_Alignment_FeeCreatorClaim is
    TestBase_UniswapV4SingleStandardExchangeDETF
{
    address internal alice;
    address internal bob;

    function setUp() public override {
        super.setUp();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _openArgs();
        args_.name = "FC UniV4 CP DETF";
        args_.symbol = "fcUv4Cp";
        detf = _deployDetfWired(args_);
        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function test_FC1_univ4Cp_feeToAndCreatorCanClaim() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        IDETFNFTVault nft_ = _nft();
        assertTrue(nft_.reservedBondNftsWired(), "reserved wired");
        address feeTo_ = _feeTo();
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_, "id1 feeTo");
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), feeTo_, "id2 D21");

        uint256 potBefore_ = _potBalance();
        _liveMint(alice, 2 ether);
        uint256 potAfter_ = _potBalance();
        assertTrue(potAfter_ > potBefore_, "live mint pot");

        uint256 c1_ = _claim(DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        uint256 c2_ = _claim(DETF_CREATOR_BOND_NFT_ID, feeTo_);
        assertTrue(c1_ > 0, "FC1 id1 claimed");
        assertTrue(c2_ > 0, "FC1 id2 claimed");
    }

    function test_FC2_univ4Cp_claimEqualsPendingAndBalance() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeTo();
        uint256 pending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 balBefore_ = IERC20(detf).balanceOf(feeTo_);
        uint256 claimed_ = _claim(DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertEq(claimed_, pending_, "FC2 claim==pending");
        assertEq(IERC20(detf).balanceOf(feeTo_) - balBefore_, claimed_, "FC2 balance delta");
    }

    function test_FC3_univ4Cp_dueAmountsFloor() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 F_ = nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 C_ = nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 T_ = nft_.totalShares();
        _liveMint(alice, 2 ether);
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

    function test_FC4_univ4Cp_newSharesDoNotClaimOldPot() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pending1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 pending2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 freeDetf_ = IERC20(detf).balanceOf(alice) / 20;
        if (freeDetf_ == 0) freeDetf_ = IERC20(detf).balanceOf(alice);
        vm.startPrank(alice);
        IERC20(detf).approve(detf, freeDetf_);
        detfInfo.buyClaim(freeDetf_, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 after1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 after2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        assertLe(after1_ > pending1_ ? after1_ - pending1_ : pending1_ - after1_, 1e13, "FC4 id1");
        assertLe(after2_ > pending2_ ? after2_ - pending2_ : pending2_ - after2_, 1e13, "FC4 id2");
    }

    function test_FC5_univ4Cp_newPotAtNewWeights() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pendingBefore_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 accBefore_ = pendingBefore_
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        _liveMint(alice, 2 ether);
        uint256 fromNew_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID) - pendingBefore_;
        uint256 accAfter_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 delta_ = accAfter_ > accBefore_ ? accAfter_ - accBefore_ : 0;
        uint256 dueNew_ = (delta_ * nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID)) / nft_.totalShares();
        assertLe(fromNew_ > dueNew_ ? fromNew_ - dueNew_ : dueNew_ - fromNew_, 1, "FC5 id1 new pot");
    }

    function test_FC6_univ4Cp_secondClaimZero() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
        address feeTo_ = _feeTo();
        uint256 first_ = _claim(DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertTrue(first_ > 0, "first claim");
        uint256 second_ = _claim(DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertEq(second_, 0, "FC6 second claim 0");
    }

    function test_FC7_univ4Cp_nonOwnerCannotClaim() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        vm.prank(alice);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, alice);
    }

    function test_FC8_univ4Cp_ids1and2CannotSellOrClose() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        assertTrue(_nft().reservedBondNftsWired(), "wired");
        address feeTo_ = _feeTo();
        uint256 deadline_ = block.timestamp + 1 hours;
        uint256[] memory minOut_ = new uint256[](2);
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.sellPositionToDetfNft(DETF_FEE_TO_BOND_NFT_ID, feeTo_);
    }

    function test_FC9_univ4Cp_d2NoOriginalShares() public {
        _bootstrapViaFirstBond(alice, 15 ether);
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 original");
        assertTrue(nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID) > 0, "FC9 id1 effective");
        assertTrue(nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID) > 0, "FC9 id2 effective");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "FC9 no LP");
    }

    function test_FC10_univ4Cp_feeToChangeDoesNotMoveId1() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
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

    function test_FC11_univ4Cp_creatorZeroFeeToOwnsBoth() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeTo();
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_);
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), feeTo_);
        uint256 due1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 due2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 c1_ = _claim(DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        uint256 c2_ = _claim(DETF_CREATOR_BOND_NFT_ID, feeTo_);
        assertEq(c1_, due1_, "FC11 id1");
        assertEq(c2_, due2_, "FC11 id2");
        assertTrue(c1_ + c2_ < IERC20(detf).totalSupply(), "not whole supply");
    }

    function test_FC12_univ4Cp_conservationTwoWaves() public {
        _bootstrapViaFirstBond(alice, 20 ether);
        _liveMint(alice, 2 ether);
        _bootstrapViaFirstBond(bob, 4 ether);
        _liveMint(bob, 1 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeTo();
        uint256 claimed_ = _claim(DETF_FEE_TO_BOND_NFT_ID, feeTo_)
            + _claim(DETF_CREATOR_BOND_NFT_ID, feeTo_)
            + _claim(DETF_FIRST_USER_BOND_NFT_ID, alice);
        try this.claimProtocolForFc12() returns (uint256 p0_) {
            claimed_ += p0_;
        } catch {}
        uint256 leftover_ = nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID);
        assertLe(claimed_ + leftover_, IERC20(detf).totalSupply(), "FC12 not over mint");
        assertLe(leftover_, IERC20(detf).balanceOf(address(nft_)) + 4, "FC12 leftover backed");
    }

    function claimProtocolForFc12() external returns (uint256) {
        return _nft().claimRewards(DETF_PROTOCOL_BOND_NFT_ID, address(this));
    }

    function _liveMint(address who_, uint256 pairAmt_) internal {
        pairToken.mint(who_, pairAmt_);
        vm.startPrank(who_);
        pairToken.approve(detf, pairAmt_);
        IStandardExchangeIn(detf).exchangeIn(
            IERC20(address(pairToken)), pairAmt_, IERC20(detf), 0, who_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}

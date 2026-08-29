// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4Detf_PonsV2Se_Stage11Helpers} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se_Stage11Helpers.sol";

/// @notice H_CP_P2 Stage 11 Policy. Full §7.0 Policy IDs. FC names use fixture id H_CP_P2.
/// @dev No TestBase_UniswapV4Detf inherit (R-5 field clash).
contract UniswapV4Detf_PonsV2Se_Policy is UniswapV4Detf_PonsV2Se_Stage11Helpers {
    function setUp() public override {
        super.setUp();
        _bindStage11Actors();
    }

    function test_T7_8_policy_isMintingAllowed_token() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy), "Policy");
        assertTrue(info.isReserveLive(), "live");
        IUniswapV4Detf.IoRoute[] memory routes_ = info.mintRoutes();
        assertGt(routes_.length, 0, "mintRoutes");
        bool any_;
        uint256 syn_ = info.syntheticPrice();
        bool expectedGate_ = syn_ > info.mintThreshold();
        for (uint256 i; i < routes_.length; ++i) {
            bool tok_ = info.isMintingAllowed(routes_[i].token);
            assertEq(tok_, expectedGate_, "H8 token gate");
            if (tok_) any_ = true;
        }
        assertEq(info.isMintingAllowed(), any_, "no-arg iff some mintRoutes token");
    }

    function test_policy_mint_blocked_in_deadband_then_allowed_after_push() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = IERC20(launchToken);
        assertTrue(info.isMintingAllowed(), "launch-rich mint can pass");
        uint256 opened_ = _mintOn(d, LIVE_MINT_AMT);
        assertGt(opened_, 0, "mint while allowed");
        for (uint256 i; i < 24 && info.isMintingAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertFalse(info.isMintingAllowed(), "skewed into mint-blocked");
        uint256 synBlocked_ = info.syntheticPrice();
        uint256 mintTh_ = info.mintThreshold();
        vm.startPrank(detfUser);
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4DetfRepo.MintingNotAllowed.selector, synBlocked_, mintTh_)
        );
        info.mint(tok_, 1 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        for (uint256 j; j < 24 && !info.isMintingAllowed(); ++j) {
            _pushSyntheticUp(d);
        }
        assertTrue(info.isMintingAllowed(), "mint allowed after push");
        uint256 userOut_ = _mintOn(d, LIVE_MINT_AMT);
        assertGt(userOut_, 0);
    }

    function test_policy_burn_allowed_when_synthetic_below_burnThreshold() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = IERC20(launchToken);
        if (info.isMintingAllowed()) _mintOn(d, LIVE_MINT_AMT);
        for (uint256 i; i < 40 && !info.isBurningAllowed(); ++i) {
            _skewSyntheticDownAmt(d, 400 ether);
        }
        assertTrue(info.isBurningAllowed(), "burn allowed");
        _ensureFreeDetf(d, LIVE_MINT_AMT);
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        require(bal_ > 0, "need free DETF to burn");
        uint256 burnAmt_ = bal_ / 10;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        info.compoundProtocolRewards();
        uint256 out_ = _burnOn(d, burnAmt_, tok_);
        assertGt(out_, 0, "burn succeeds below burnThreshold");
    }

    function test_D31_1_policyMint_realizesThenGates() public {
        address d = _deployD31LaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * POLICY_EXPANSION_CATCHUP);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 nftBefore_ = IERC20(d).balanceOf(info.bondNftVault());
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        if (!info.isMintingAllowed()) {
            vm.startPrank(detfUser);
            vm.expectRevert();
            info.mint(IERC20(launchToken), LIVE_MINT_AMT, 0, detfUser, false, _deadline());
            vm.stopPrank();
            assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-1 fail: supply");
            assertEq(info.pendingExpansionDetf(), pending_, "D31-1 fail: pending stuck");
            return;
        }
        _mintOn(d, LIVE_MINT_AMT);
        if (pending_ > 0) {
            assertGe(IERC20(d).balanceOf(info.bondNftVault()), nftBefore_ + pending_ - 1, "D31-1 realized");
        }
    }

    function test_D31_2_realizeWouldCloseMint_revertsUnchanged() public {
        address d = _deployD31LaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = IERC20(launchToken);
        for (uint256 i; i < 30; ++i) {
            vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * POLICY_EXPANSION_CATCHUP);
            if (!info.isMintingAllowed()) {
                uint256 supplyBefore_ = IERC20(d).totalSupply();
                uint256 pendingBefore_ = info.pendingExpansionDetf();
                vm.startPrank(detfUser);
                vm.expectRevert();
                info.mint(tok_, 5 ether, 0, detfUser, false, _deadline());
                vm.stopPrank();
                assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-2 supply");
                assertEq(info.pendingExpansionDetf(), pendingBefore_, "D31-2 pending");
                return;
            }
            _skewSyntheticDown(d);
        }
        for (uint256 j; j < 20 && info.isMintingAllowed(); ++j) {
            uint256 dump_ = IERC20(d).balanceOf(detfUser);
            if (dump_ < 20 ether) {
                deal(d, detfUser, dump_ + 80 ether, true);
                dump_ = IERC20(d).balanceOf(detfUser);
            }
            if (dump_ == 0) break;
            _donateDetfSelf(d, dump_);
        }
        assertFalse(info.isMintingAllowed(), "D31-2 need mint closed");
        uint256 supply2_ = IERC20(d).totalSupply();
        uint256 pending2_ = info.pendingExpansionDetf();
        vm.startPrank(detfUser);
        vm.expectRevert();
        info.mint(tok_, 5 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        assertEq(IERC20(d).totalSupply(), supply2_, "D31-2 supply fallback");
        assertEq(info.pendingExpansionDetf(), pending2_, "D31-2 pending fallback");
    }

    function test_D31_3_policyBurn_realizesThenGates() public {
        address d = _deployD31LaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = IERC20(launchToken);
        if (info.isMintingAllowed()) _mintOn(d, LIVE_MINT_AMT);
        for (uint256 i; i < 40 && !info.isBurningAllowed(); ++i) {
            _skewSyntheticDownAmt(d, 400 ether);
        }
        assertTrue(info.isBurningAllowed(), "D31-3 burn allowed");
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 2);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        _ensureFreeDetf(d, LIVE_MINT_AMT);
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        require(bal_ > 0, "D31-3 need DETF");
        uint256 burnAmt_ = bal_ / 10;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        if (!info.isBurningAllowed()) {
            vm.startPrank(detfUser);
            IERC20(d).approve(d, type(uint256).max);
            vm.expectRevert();
            info.burn(burnAmt_, tok_, 0, detfUser, _deadline());
            vm.stopPrank();
            assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-3 fail supply");
            assertEq(info.pendingExpansionDetf(), pending_, "D31-3 fail pending");
            return;
        }
        _burnOn(d, burnAmt_, tok_);
    }

    function test_D22_claimUngated() public {
        address d = _deployPolicyLaunchRichLive();
        uint256 claimBal_ = _sellAndClaimOn(d, detfUser, 40 ether, 20 ether);
        IUniswapV4Detf info = IUniswapV4Detf(d);
        for (uint256 i; i < 40 && info.isMintingAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertFalse(info.isMintingAllowed(), "Policy deadband");
        uint256 redeem_ = claimBal_ / 4;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 detfBefore_ = IERC20(d).balanceOf(detfUser);
        uint256 pairBefore_ = IERC20(launchToken).balanceOf(detfUser);
        uint256 out_ = _redeemOn(d, detfUser, redeem_);
        assertGt(out_, 0, "D22 redeem in deadband");
        assertEq(IERC20(d).balanceOf(detfUser) - detfBefore_, out_);
        assertEq(IERC20(launchToken).balanceOf(detfUser), pairBefore_, "D22 no pair");
    }

    function test_D15_9_ungatedVsPolicy() public {
        address d = _deployPolicyLaunchRichLive();
        uint256 claimBal_ = _sellAndClaimOn(d, detfUser, 40 ether, 20 ether);
        IUniswapV4Detf info = IUniswapV4Detf(d);
        for (uint256 i; i < 40 && info.isMintingAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        uint256 redeem_ = claimBal_ / 4;
        if (redeem_ == 0) redeem_ = claimBal_;
        uint256 out_ = _redeemOn(d, detfUser, redeem_);
        assertGt(out_, 0, "D15-9");
    }

    function test_D15_1_previewEqualsExecute() public {
        address d = _deployPolicyLaunchRichLive();
        uint256 claimBal_ = _sellAndClaimOn(d, detfUser, 40 ether, 20 ether);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = 1;
        uint256 preview_ = _claimTokOf(d).previewRedeem(redeem_);
        uint256 out_ = _redeemOn(d, detfUser, redeem_);
        assertEq(out_, preview_, "D15-1 preview==exec");
    }

    function test_D15_8_nonDetfPayoutForbidden() public {
        address d = _deployPolicyLaunchRichLive();
        uint256 claimBal_ = _sellAndClaimOn(d, detfUser, 40 ether, 20 ether);
        uint256 redeem_ = claimBal_ / 3;
        if (redeem_ == 0) redeem_ = claimBal_;
        _assertRedeemPaysDetfOnly(d, detfUser, redeem_);
    }

    function test_D15_redeem_paysDetf_only() public {
        address d = _deployPolicyLaunchRichLive();
        uint256 claimBal_ = _sellAndClaimOn(d, detfUser, 40 ether, 20 ether);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = claimBal_;
        _assertRedeemPaysDetfOnly(d, detfUser, redeem_);
    }

    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        IUniswapV4Detf.PkgArgs memory args = _policyArgs();
        args = _withTag(args, string.concat("t1", _nextTag()));
        address d = _deployInstance(args);
        IUniswapV4Detf info = IUniswapV4Detf(d);
        uint256[] memory creation_ = info.creationPairPerDetfWad();
        uint256[] memory opening_ = info.openingPairPerDetfWad();
        assertTrue(_openingEq(opening_, creation_), "stored opening == creation");
        assertFalse(info.isReserveLive(), "inert");
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(info.isReserveLive(), "live");
        uint256 g_ = _expectedJoinDetf(FIRST_BOND_AMT, DEFAULT_CREATION_PAIR_PER_DETF);
        assertApproxEqAbs(_detfReserveInHook(d), g_, 1000, "first-bond G at peg");
    }

    function test_T2_openingUsesG_creationViewUnchanged() public {
        IUniswapV4Detf.PkgArgs memory args = _withOpening(_policyArgs(), LAUNCH_RICH_START);
        args = _withTag(args, string.concat("t2", _nextTag()));
        address d = _deployInstance(args);
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation view");
        assertTrue(_openingAll(info.openingPairPerDetfWad(), LAUNCH_RICH_START), "stored opening");
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = _expectedJoinDetf(FIRST_BOND_AMT, LAUNCH_RICH_START);
        uint256 gCreation_ = _expectedJoinDetf(FIRST_BOND_AMT, DEFAULT_CREATION_PAIR_PER_DETF);
        uint256 raw_ = _detfReserveInHook(d);
        assertApproxEqAbs(raw_, gOpening_, 1000, "first-bond G uses opening");
        assertTrue(raw_ != gCreation_, "G is not creation-rate join");
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation unchanged");
    }

    function test_T5_creationZero_revertsInvalidCreationRate() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.creationPairPerDetfWad = new uint256[](1);
        args.creationPairPerDetfWad[0] = 0;
        args.symbol = "badP2";
        vm.startPrank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function test_FC1_univ4Detf_H_CP_P2_feeToAndCreatorCanClaim() public { _assertFC1(); }
    function test_FC2_univ4Detf_H_CP_P2_claimEqualsPendingAndBalance() public { _assertFC2(); }
    function test_FC3_univ4Detf_H_CP_P2_dueAmountsFloor() public { _assertFC3(); }
    function test_FC4_univ4Detf_H_CP_P2_newSharesDoNotClaimOldPot() public { _assertFC4(); }
    function test_FC5_univ4Detf_H_CP_P2_newPotAtNewWeights() public { _assertFC5(); }
    function test_FC6_univ4Detf_H_CP_P2_secondClaimZero() public { _assertFC6(); }
    function test_FC7_univ4Detf_H_CP_P2_nonOwnerCannotClaim() public { _assertFC7(); }
    function test_FC8_univ4Detf_H_CP_P2_ids1and2CannotSellOrClose() public { _assertFC8(); }
    function test_FC9_univ4Detf_H_CP_P2_d2NoOriginalShares() public { _assertFC9(); }
    function test_FC10_univ4Detf_H_CP_P2_feeToChangeDoesNotMoveId1() public { _assertFC10(); }
    function test_FC11_univ4Detf_H_CP_P2_creatorZeroFeeToOwnsBoth() public { _assertFC11(); }
    function test_FC12_univ4Detf_H_CP_P2_conservationTwoWaves() public { _assertFC12(); }

    function _assertFC1() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        assertTrue(nft_.reservedBondNftsWired(), "reserved wired");
        address feeTo_ = _feeToOf(detf);
        _liveMintOn(detf, alice, 2 ether);
        uint256 p1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 p2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 c1_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        uint256 c2_ = _nftClaim(detf, DETF_CREATOR_BOND_NFT_ID, feeTo_);
        assertGt(c1_, 0, "FC1 id1 claimed");
        assertGt(c2_, 0, "FC1 id2 claimed");
        assertEq(c1_, p1_, "FC1 id1 == pending");
        assertEq(c2_, p2_, "FC1 id2 == pending");
    }

    function _assertFC2() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        address feeTo_ = _feeToOf(detf);
        uint256 pending_ = _nft().pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 balBefore_ = IERC20(detf).balanceOf(feeTo_);
        uint256 claimed_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertEq(claimed_, pending_, "FC2 claim==pending");
        assertEq(IERC20(detf).balanceOf(feeTo_) - balBefore_, claimed_, "FC2 balance delta");
    }

    function _assertFC3() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 F_ = nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 C_ = nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 T_ = nft_.totalShares();
        _liveMintOn(detf, alice, 2 ether);
        uint256 p1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 p2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 acc_ = p1_ + p2_ + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        assertGt(acc_, 0, "new pot");
        uint256 due1_ = (acc_ * F_) / T_;
        uint256 due2_ = (acc_ * C_) / T_;
        assertLe(p1_ > due1_ ? p1_ - due1_ : due1_ - p1_, 1, "FC3 id1 floor");
        assertLe(p2_ > due2_ ? p2_ - due2_ : due2_ - p2_, 1, "FC3 id2 floor");
    }

    function _assertFC4() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pending1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 pending2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        _bondOn(detf, bob, 20 ether);
        uint256 after1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 after2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        assertLe(pending1_ > after1_ ? pending1_ - after1_ : 0, 1e13, "FC4 id1 old pot");
        assertLe(pending2_ > after2_ ? pending2_ - after2_ : 0, 1e13, "FC4 id2 old pot");
    }

    function _assertFC5() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pendingBefore_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 accBefore_ = pendingBefore_ + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID) + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        _liveMintOn(detf, alice, 2 ether);
        uint256 fromNew_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID) - pendingBefore_;
        uint256 accAfter_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID) + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 delta_ = accAfter_ > accBefore_ ? accAfter_ - accBefore_ : 0;
        uint256 dueNew_ = (delta_ * nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID)) / nft_.totalShares();
        assertLe(fromNew_ > dueNew_ ? fromNew_ - dueNew_ : dueNew_ - fromNew_, 1, "FC5 id1 new pot");
    }

    function _assertFC6() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        address feeTo_ = _feeToOf(detf);
        uint256 first_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertGt(first_, 0, "first claim");
        uint256 second_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertEq(second_, 0, "FC6 second claim 0");
    }

    function _assertFC7() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        vm.prank(alice);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, alice);
    }

    function _assertFC8() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeToOf(detf);
        uint256[] memory minOut_ = _minOutOf(detf);
        uint256 deadline_ = _deadline();
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(detf);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_FEE_TO_BOND_NFT_ID));
        nft_.sellPositionToDetfNft(DETF_FEE_TO_BOND_NFT_ID, feeTo_, feeTo_);
        vm.prank(detf);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_CREATOR_BOND_NFT_ID));
        nft_.sellPositionToDetfNft(DETF_CREATOR_BOND_NFT_ID, feeTo_, feeTo_);
    }

    function _assertFC9() internal {
        _bootAlice(15 ether);
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 original");
        assertGt(nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 effective");
        assertGt(nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 effective");
    }

    function _assertFC10() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        address original_ = _feeToOf(detf);
        address newFeeTo_ = makeAddr("newFeeTo");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(newFeeTo_));
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), original_, "FC10 owner stays");
        uint256 claimed_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, original_);
        assertGt(claimed_, 0, "original still claims");
        vm.prank(newFeeTo_);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, newFeeTo_);
    }

    function _assertFC11() internal {
        _fcActors();
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = address(0);
        address instance_ = _deployTagged(args_, string.concat("fc11", _nextTag()));
        _bondOn(instance_, alice, 20 ether);
        _liveMintOn(instance_, alice, 2 ether);
        IDETFNFTVault nft_ = _nftOf(instance_);
        address feeTo_ = _feeToOf(instance_);
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_);
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), feeTo_);
        uint256 due1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 due2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 c1_ = _nftClaim(instance_, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        uint256 c2_ = _nftClaim(instance_, DETF_CREATOR_BOND_NFT_ID, feeTo_);
        assertEq(c1_, due1_, "FC11 id1");
        assertEq(c2_, due2_, "FC11 id2");
        assertGt(c1_, 0, "FC11 id1 claimed");
        assertGt(c2_, 0, "FC11 id2 claimed");
    }

    function _assertFC12() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        _bondOn(detf, bob, 4 ether);
        _liveMintOn(detf, bob, 1 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeToOf(detf);
        address firstOwner_ = nft_.ownerOf(DETF_FIRST_USER_BOND_NFT_ID);
        uint256 claimed_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_)
            + _nftClaim(detf, DETF_CREATOR_BOND_NFT_ID, feeTo_)
            + _nftClaim(detf, DETF_FIRST_USER_BOND_NFT_ID, firstOwner_);
        uint256 leftover_ = nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID);
        assertLe(claimed_ + leftover_, IERC20(detf).totalSupply(), "FC12 not over mint");
    }
}

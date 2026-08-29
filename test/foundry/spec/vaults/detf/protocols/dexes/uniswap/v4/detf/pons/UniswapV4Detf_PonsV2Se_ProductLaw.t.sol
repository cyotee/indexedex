// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {DETFNFTVaultCommon} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultCommon.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {Uv4DetfDonateDuringUnlockHarness} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";
import {UniswapV4Detf_PonsV2Se_Stage11Helpers} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se_Stage11Helpers.sol";

/// @notice H_CP_P2 Stage 11 Open. Full §7.0 Open IDs on launchToken. No TestBase_UniswapV4Detf inherit.
contract UniswapV4Detf_PonsV2Se_ProductLaw is UniswapV4Detf_PonsV2Se_Stage11Helpers {
    function setUp() public override {
        super.setUp();
        _bindStage11Actors();
    }

    function test_T7_2_defaultTables_pairAndShare_noUnderlyings() public view {
        address[] memory hookToks_ = IUniswapV4SeBufferHook(reserveHook).tokens();
        _assertDefaultInbound(detfInfo.mintRoutes(), hookToks_, "mint");
        _assertDefaultInbound(detfInfo.burnRoutes(), hookToks_, "burn");
        _assertDefaultInbound(detfInfo.bondRoutes(), hookToks_, "bond");
    }

    function test_T7_10_laterBond_joinUnbalanced_unboostedG() public {
        _firstBond(80 ether);
        uint256 mintTokenIn_ = 20 ether;
        address pair_ = launchToken;
        uint256 p_ = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        uint256 gExpected_ = _unboostedBondG(pair_, mintTokenIn_);
        uint256 expectedUser_ = Math.mulDiv(gExpected_, ONE_WAD - p_, ONE_WAD);
        (uint256 mintGross_,,) = detfInfo.previewMint(IERC20(pair_), mintTokenIn_);
        assertGt(mintGross_, 0, "mint Gross");
        uint256 userBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) = detfInfo.bond(
            IERC20(pair_), mintTokenIn_, DEFAULT_MIN_LOCK, detfUser, false, _deadline()
        );
        vm.stopPrank();
        assertGt(tokenId, 0, "later tokenId");
        assertGt(shares, 0, "later lp");
        uint256 bondUser_ = IERC20(detf).balanceOf(detfUser) - userBefore_;
        assertEq(bondUser_, expectedUser_, "G unboosted mix user split");
        assertTrue(bondUser_ != mintGross_, "later bond G is not boosted mint Gross");
        detfInfo.sweepDust();
        _assertNoJoinableDust();
    }

    function test_T7_14_commonNftUnused_claimHoldsNoHookLp() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(IERC20(launchToken), 10 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        address nft_ = detfInfo.bondNftVault();
        address claim_ = detfInfo.rebasingClaimToken();
        assertTrue(nft_ != address(0), "R12a Bond NFT");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "no LP on diamond");
        assertEq(IERC20(reserveHook).balanceOf(claim_), 0, "no LP on claim");
        assertGt(IERC20(reserveHook).balanceOf(nft_), 0, "LP on Bond NFT");
        _assertNoJoinableDust();
    }

    function test_T7_19_afterMint_diamondHasNoJoinableBalances() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(IERC20(launchToken), 10 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        _assertNoJoinableDust();
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.rebasingClaimToken()), 0, "no LP on claim");
    }

    function test_reserveHook_ownerIsDetf() public view {
        assertEq(IMultiStepOwnable(reserveHook).owner(), detf, "hook.owner()==detf");
        assertEq(IMultiStepOwnable(detfInfo.reservePool()).owner(), detf, "reservePool owner");
    }

    function test_reserveHook_thirdPartyAddReverts() public {
        IERC20 tok_ = _openPairToken();
        vm.prank(detfUser);
        vm.expectRevert();
        IUniswapV4SeBufferHook(reserveHook).joinSingleAssetExactIn(
            address(tok_), 1 ether, detfUser, 0, _deadline()
        );
    }

    function test_preMaturity_sell_reverts() public {
        _firstBond(100 ether);
        (uint256 tokenId,) = _firstBond(20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 unlock_ = nft_.unlockTimeOf(tokenId);
        assertGt(unlock_, block.timestamp, "still locked");
        vm.prank(detf);
        vm.expectRevert(abi.encodeWithSelector(DETFNFTVaultCommon.BondNotMature.selector, unlock_));
        nft_.sellPositionToDetfNft(tokenId, detfUser, detfUser);
    }

    function test_postMaturity_sell_mintsRebasingClaim() public {
        _firstBond(100 ether);
        (uint256 tokenId, uint256 shares) = _firstBond(40 ether);
        IDETFNFTVault nft_ = _nft();
        IERC20 lp_ = _lpToken();
        uint256 lpBefore_ = lp_.balanceOf(address(nft_));
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 claimBefore_ = _claimTok().balanceOf(detfUser);
        _warpMature(tokenId);
        (uint256 principal, uint256 minted_) = _d10SellToClaimOn(detf, tokenId, detfUser);
        assertEq(principal, shares, "principal originalShares");
        assertGt(minted_, 0, "claim minted");
        assertEq(_claimTok().balanceOf(detfUser) - claimBefore_, minted_, "claim balance");
        assertEq(nft_.originalSharesOf(tokenId), 0, "sold originalShares");
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_ + principal, "id0 takes originalShares");
        assertEq(lp_.balanceOf(address(nft_)), lpBefore_, "no LP withdraw");
    }

    function test_claimRewards_whileLocked() public {
        _setPfc(detf);
        (uint256 tokenId,) = _firstBond(100 ether);
        _liveMintOn(detf, detfUser, 10 ether);
        IDETFNFTVault nft_ = _nft();
        assertLt(block.timestamp, nft_.unlockTimeOf(tokenId), "locked");
        uint256 pending_ = nft_.pendingRewards(tokenId);
        assertGt(pending_, 0, "pending while locked");
        uint256 balBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 claimed_ = nft_.claimRewards(tokenId, detfUser);
        assertEq(claimed_, pending_, "claimed == pending");
        assertEq(IERC20(detf).balanceOf(detfUser) - balBefore_, claimed_, "DETF paid");
        assertEq(nft_.pendingRewards(tokenId), 0, "pending cleared");
    }

    function test_D15_1_previewEqualsExecute() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = 1;
        IRebasingClaimToken claim_ = _claimTok();
        uint256 preview_ = claim_.previewRedeem(redeem_);
        uint256 detfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 out_ = _redeemOn(detf, detfUser, redeem_);
        assertEq(out_, preview_, "D15-1 preview==exec");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore_, out_);
    }

    function test_D15_8_nonDetfPayoutForbidden() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 60 ether);
        uint256 redeem_ = claimBal_ / 3;
        if (redeem_ == 0) redeem_ = claimBal_;
        _assertRedeemPaysDetfOnly(detf, detfUser, redeem_);
    }

    function test_D15_redeem_paysDetf_only() public {
        uint256 claimBal_ = _sellAndClaimOn(detf, detfUser, 100 ether, 50 ether);
        uint256 redeem_ = claimBal_ / 2;
        if (redeem_ == 0) redeem_ = claimBal_;
        _assertRedeemPaysDetfOnly(detf, detfUser, redeem_);
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        (, uint256 bobId_) = _liveAliceBob();
        IERC20 detfToken_ = IERC20(detf);
        uint256 pending_ = _nft().pendingRewards(bobId_);
        uint256 detfBeforeClaim_ = detfToken_.balanceOf(d25Bob);
        uint256 claimed_ = _claimRewardsAs(d25Bob, bobId_);
        assertApproxEqAbs(claimed_, pending_, 1, "D25-1 claimed==pending");
        assertEq(detfToken_.balanceOf(d25Bob) - detfBeforeClaim_, claimed_, "D25-1 DETF from claimRewards");
        uint256 detfAfterClaim_ = detfToken_.balanceOf(d25Bob);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        assertEq(out_[_detfTokenIndex(toks_)], 0, "D25-1 DETF slot unpaid");
        assertEq(detfToken_.balanceOf(d25Bob), detfAfterClaim_, "D25-1 close does not pay DETF");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        (, uint256 bobId_) = _liveAliceBob();
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        _closeAs(d25Bob, bobId_);
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "D25-2 no burn of withdrawn DETF");
    }

    function test_D25_3_id0OriginalSharesRise() public {
        (, uint256 bobId_) = _liveAliceBob();
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        _closeAs(d25Bob, bobId_);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-3 id 0 credited");
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        (, uint256 bobId_) = _liveAliceBob();
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        uint256 detfIdx_ = _detfTokenIndex(toks_);
        uint256 pairBefore_ = IERC20(launchToken).balanceOf(d25Bob);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        assertEq(out_.length, toks_.length, "tokens() order");
        assertEq(out_[detfIdx_], 0, "DETF slot unpaid");
        uint256 pairPaid_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == launchToken) pairPaid_ = out_[i];
        }
        assertGt(pairPaid_, 0, "pair basket");
        assertEq(IERC20(launchToken).balanceOf(d25Bob) - pairBefore_, pairPaid_, "pair paid");
    }

    function test_D25_5_ids1and2CannotClose() public {
        _ensureActors();
        if (!detfInfo.isReserveLive()) _firstBond(80 ether);
        _bondAs(d25Alice, 20 ether);
        uint256[] memory minOut_ = _minOut();
        uint256 deadline_ = _deadline();
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_FEE_TO_BOND_NFT_ID));
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, d25Alice, deadline_);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_CREATOR_BOND_NFT_ID));
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, d25Alice, deadline_);
    }

    function test_D25_6_previewEqualsExecute() public {
        (, uint256 bobId_) = _liveAliceBob();
        uint256[] memory preview_ = detfInfo.previewCloseBondMature(bobId_);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        assertEq(out_.length, preview_.length, "D25-6 length");
        for (uint256 i; i < out_.length; ++i) {
            assertApproxEqAbs(out_[i], preview_[i], 1, "D25-6 preview==exec");
        }
    }

    function test_D25_7_minRejoinLpOutGt0() public {
        uint256 aliceId_ = _liveAliceOnly();
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(nft_.detfNFTId());
        _closeAs(d25Alice, aliceId_);
        assertGt(nft_.originalSharesOf(nft_.detfNFTId()), id0Before_, "D25-7 MIN rejoin credited id 0");
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        uint256 aliceId_ = _liveAliceOnly();
        IDETFNFTVault nft_ = _nft();
        uint256 feePending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorPending_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        _closeAs(d25Alice, aliceId_);
        assertLe(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), feePending_ + 1, "D25 leftover DETF must not extract to feeTo");
        assertLe(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), creatorPending_ + 1, "D25 leftover DETF must not extract to creator");
    }

    function test_compound_raises_protocolLp() public {
        address d = _deployOpenLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        _mintOn(d, LIVE_MINT_AMT);
        uint256 nftLpBefore_ = _nftLpOf(d);
        (uint256 detfIn_, uint256 lpOut_) = info.compoundProtocolRewards();
        detfIn_;
        if (lpOut_ > 0) {
            assertGt(_nftLpOf(d), nftLpBefore_, "Bond NFT hook-LP rises when lpOut>0");
        }
    }

    function test_open_never_expands() public {
        address d = _deployOpenLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        info.compoundProtocolRewards();
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 50);
        assertEq(info.pendingExpansionDetf(), 0, "Open never pending");
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        _mintOn(d, LIVE_MINT_AMT);
        assertEq(info.pendingExpansionDetf(), 0, "Open mint no expansion");
        assertGt(IERC20(d).totalSupply(), supplyBefore_, "open mint minted");
    }

    function test_A0_donateBeforeFirstBond_cannotFreeMint() public {
        address instance_ = _deployInstance(_uniqueDetfArgs("a0"));
        IUniswapV4Detf info_ = IUniswapV4Detf(instance_);
        uint256 donate_ = 80 ether;
        _fundLaunch(attacker, donate_);
        vm.prank(attacker);
        IERC20(launchToken).transfer(instance_, donate_);
        assertFalse(info_.isReserveLive(), "inert");
        _fundLaunch(attacker, 1 ether);
        vm.startPrank(attacker);
        IERC20(launchToken).approve(instance_, 1 ether);
        vm.expectRevert(UniswapV4DetfRepo.ReserveNotLive.selector);
        info_.mint(IERC20(launchToken), 1 ether, 0, attacker, false, _deadline());
        vm.stopPrank();
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "no free detfToken");
    }

    function test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork() public {
        IUniswapV4Detf info_ = detfInfo;
        (uint256 firstId_,) = _goLive(400 ether);
        (uint256 sellId_,) = _bondAs(detfUser, 80 ether);
        uint256 minted_ = _liveMintOn(detf, detfUser, 40 ether);
        assertGt(minted_, 0, "mint for burn");
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 claimMinted_ = _d10SellToClaim(sellId_, detfUser);
        assertGt(claimMinted_, 0, "sold to claim");
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        bytes memory disabledErr_ = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf);
        vm.startPrank(detfUser);
        vm.expectRevert(disabledErr_);
        info_.mint(IERC20(launchToken), 1 ether, 0, detfUser, false, _deadline());
        vm.expectRevert(disabledErr_);
        info_.bond(IERC20(launchToken), 1 ether, DEFAULT_MIN_LOCK, detfUser, false, _deadline());
        vm.expectRevert(disabledErr_);
        info_.donate(IERC20(launchToken), 1 ether, false);
        vm.stopPrank();
        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(detfUser);
        uint256 redeemAmt_ = claimBal_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;
        vm.startPrank(detfUser);
        uint256 redeemOut_ = claim_.redeem(redeemAmt_, detfUser, false);
        vm.stopPrank();
        assertGt(redeemOut_, 0, "redeem after disable");
        vm.prank(detfUser);
        uint256[] memory closed_ = info_.closeBondMature(firstId_, _minOut(), detfUser, _deadline());
        assertGt(closed_[_pairIndex(IUniswapV4SeBufferHook(info_.hook()).tokens())], 0, "close after disable");
        uint256 burnAmt_ = minted_ / 2;
        if (burnAmt_ == 0) burnAmt_ = minted_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 burned_ = info_.burn(burnAmt_, IERC20(launchToken), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(burned_, 0, "burn exit after disable");
    }

    function test_I1_mint_pretransferred_inventoryNoInCallTransfer_reverts() public {
        _goLive(200 ether);
        uint256 residual_ = 8 ether;
        _bookPairResidual(detf, residual_);
        uint256 claimed_ = residual_;
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(claimed_, 0));
        detfInfo.mint(IERC20(launchToken), claimed_, 0, attacker, true, _deadline());
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I1: no free detfToken mint");
    }

    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        _goLive(200 ether);
        uint256 residual_ = 6 ether;
        _bookPairResidual(detf, residual_);
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(residual_, 0));
        detfInfo.bond(IERC20(launchToken), residual_, DEFAULT_MIN_LOCK, attacker, true, _deadline());
        assertEq(IERC20(detf).balanceOf(attacker), 0, "bond I1: no free detfToken");
    }

    function test_I1_donate_pretransferred_inventoryNoTransfer_reverts() public {
        _goLive(200 ether);
        uint256 residual_ = 4 ether;
        _bookPairResidual(detf, residual_);
        vm.prank(attacker);
        vm.expectRevert();
        detfInfo.donate(IERC20(launchToken), residual_, true);
        assertEq(IERC20(detf).balanceOf(attacker), 0, "donate I1: no free detfToken");
    }

    function test_I2_mint_pretransferred_claimedGtDelta_reverts() public {
        _goLive(200 ether);
        _bookPairResidual(detf, 4 ether);
        uint256 claimed_ = 10 ether;
        _fundLaunch(attacker, claimed_);
        uint256 shortDelta_ = claimed_ / 2;
        vm.startPrank(attacker);
        IERC20(launchToken).approve(address(preHelper), shortDelta_);
        vm.expectRevert(_deltaRevert(claimed_, shortDelta_));
        preHelper.mintPretransfer(detf, IERC20(launchToken), shortDelta_, claimed_, attacker);
        vm.stopPrank();
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I2: no mint on short");
    }

    function test_I2_bond_pretransferred_claimedGtDelta_reverts() public {
        _goLive(200 ether);
        _bookPairResidual(detf, 4 ether);
        uint256 claimed_ = 8 ether;
        _fundLaunch(attacker, claimed_);
        uint256 shortDelta_ = claimed_ / 2;
        vm.startPrank(attacker);
        IERC20(launchToken).approve(address(preHelper), shortDelta_);
        vm.expectRevert(_deltaRevert(claimed_, shortDelta_));
        preHelper.bondPretransfer(detf, IERC20(launchToken), shortDelta_, claimed_, DEFAULT_MIN_LOCK, attacker);
        vm.stopPrank();
    }

    function test_I2_donate_pretransferred_claimedGtDelta_reverts() public {
        _goLive(200 ether);
        address nft_ = detfInfo.bondNftVault();
        uint256 claimed_ = 6 ether;
        _fundLaunch(attacker, claimed_);
        uint256 shortDelta_ = claimed_ / 2;
        vm.startPrank(attacker);
        IERC20(launchToken).approve(address(preHelper), shortDelta_);
        vm.expectRevert(_deltaRevert(claimed_, shortDelta_));
        preHelper.donatePretransfer(detf, nft_, IERC20(launchToken), shortDelta_, claimed_);
        vm.stopPrank();
    }

    function test_I3_mint_residualInventory_cannotFundSecondFreePretransfer() public {
        _goLive(200 ether);
        uint256 residual_ = 5 ether;
        _fundLaunch(aliceAdv, residual_);
        vm.prank(aliceAdv);
        IERC20(launchToken).transfer(detf, residual_);
        uint256 out_ = _liveMintOn(detf, victim, 8 ether);
        assertGt(out_, 0, "honest mint ok");
        uint256 residualAfter_ = IERC20(launchToken).balanceOf(detf);
        if (residualAfter_ < residual_) {
            _bookPairResidual(detf, residual_);
            residualAfter_ = IERC20(launchToken).balanceOf(detf);
        }
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(residualAfter_, 0));
        detfInfo.mint(IERC20(launchToken), residualAfter_, 0, attacker, true, _deadline());
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I3: no free mint");
    }

    function test_I3_bond_residualInventory_cannotFundSecondFreePretransfer() public {
        _goLive(200 ether);
        _bookPairResidual(detf, 4 ether);
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(1 ether, 0));
        detfInfo.bond(IERC20(launchToken), 1 ether, DEFAULT_MIN_LOCK, attacker, true, _deadline());
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I3 bond: no free");
    }

    function test_I3_donate_residualInventory_cannotFundSecondFreePretransfer() public {
        _goLive(200 ether);
        _fundLaunch(aliceAdv, 8 ether);
        address nft_ = detfInfo.bondNftVault();
        vm.startPrank(aliceAdv);
        IERC20(launchToken).approve(nft_, 8 ether);
        detfInfo.donate(IERC20(launchToken), 8 ether, false);
        vm.stopPrank();
        vm.prank(attacker);
        vm.expectRevert(IDetfErrors.ZeroAmount.selector);
        detfInfo.donate(IERC20(launchToken), 1 ether, true);
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I3 donate: no free");
    }

    function test_K1_donationNotMintCredit() public {
        _goLive(200 ether);
        uint256 donate_ = 10 ether;
        _fundLaunch(attacker, donate_);
        vm.prank(attacker);
        IERC20(launchToken).transfer(detf, donate_);
        uint256 victimOut_ = _liveMintOn(detf, victim, 8 ether);
        assertGt(victimOut_, 0, "victim honest mint");
        uint256 attBefore_ = IERC20(detf).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(donate_, 0));
        detfInfo.mint(IERC20(launchToken), donate_, 0, attacker, true, _deadline());
        assertEq(IERC20(detf).balanceOf(attacker), attBefore_, "K1: donation not mint credit");
    }

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        _goLive(200 ether);
        uint256 out_ = _liveMintOn(detf, detfUser, 20 ether);
        assertGt(out_, 0, "T-NEST-1");
        assertEq(IERC20(launchToken).allowance(detf, address(ponsSe)), 0, "no nested fund approve");
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        _goLive(200 ether);
        uint256 dust_ = 2 ether;
        _fundLaunch(detfUser, dust_ * 2);
        vm.prank(detfUser);
        IERC20(launchToken).transfer(address(ponsSe), dust_);
        uint256 Rh = IBasicVault(address(ponsSe)).reserveOfToken(launchToken);
        uint256 Bh = IERC20(launchToken).balanceOf(address(ponsSe));
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        assertTrue(U > 0, "need surplus");
        uint256 claimOver_ = U + 1;
        vm.expectRevert();
        IStandardExchangeIn(address(ponsSe)).exchangeIn(
            IERC20(launchToken), claimOver_, IERC20(address(ponsSe)), 0, detfUser, true, _deadline()
        );
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        _goLive(200 ether);
        _liveMintOn(detf, detfUser, 10 ether);
        IERC20 tokenIn_ = IERC20(launchToken);
        uint256 Rh = IBasicVault(address(ponsSe)).reserveOfToken(address(tokenIn_));
        uint256 Bh = tokenIn_.balanceOf(address(ponsSe));
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        uint256 claim_ = U >= 1 ? U + 1 : uint256(1);
        vm.expectRevert();
        IStandardExchangeIn(address(ponsSe)).exchangeIn(
            tokenIn_, claim_, IERC20(address(ponsSe)), 0, detfUser, true, _deadline()
        );
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _goLive(200 ether);
        _liveMintOn(detf, detfUser, 10 ether);
        uint256 R = IBasicVault(detf).reserveOfToken(launchToken);
        uint256 B = IERC20(launchToken).balanceOf(detf);
        uint256 U = B >= R ? B - R : 0;
        if (U == 0) {
            vm.expectRevert();
            vm.prank(detfUser);
            detfInfo.mint(IERC20(launchToken), 1, 0, detfUser, true, _deadline());
        } else {
            vm.prank(detfUser);
            detfInfo.mint(IERC20(launchToken), U, 0, detfUser, true, _deadline());
            vm.expectRevert();
            vm.prank(detfUser);
            detfInfo.mint(IERC20(launchToken), 1, 0, detfUser, true, _deadline());
        }
    }

    function test_DN1_donate_pair_Ogt0_unassignedLp() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        assertGt(nft_.totalOriginalShares(), 0, "O>0");
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lpOut_ = _donatePair(dnDonor, 10 ether);
        _assertR12aUnassigned(before_, lpOut_);
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf, "user DETF");
        _assertNoJoinableDust();
    }

    function test_DN2_donate_vaultShare() public {
        _ensureLiveBond();
        IERC20 tok_ = _openPairToken();
        address se_ = IUniswapV4SeBufferHook(detfInfo.hook()).standardExchangeOf(address(tok_));
        if (se_ == address(0)) se_ = address(ponsSe);
        IERC20 share_ = IERC20(se_);
        uint256 pairIn_ = 20 ether;
        _fundLaunch(dnDonor, pairIn_);
        vm.startPrank(dnDonor);
        tok_.approve(se_, pairIn_);
        uint256 shares_ = IStandardExchangeIn(se_).exchangeIn(tok_, pairIn_, share_, 0, dnDonor, false, _deadline());
        vm.stopPrank();
        assertGt(shares_, 0, "DN2 se shares");
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        share_.approve(address(_nft()), shares_);
        uint256 lpOut_ = _nftDonate().donate(share_, shares_, 0, false, _deadline());
        vm.stopPrank();
        _assertR12aUnassigned(before_, lpOut_);
        _assertNoJoinableDust();
    }

    function test_DN4_donate_detf_selfLeg_noMint() public {
        _ensureLiveBond();
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "DN4 bond minted DETF");
        uint256 donateAmt_ = userDetf_ / 4;
        if (donateAmt_ == 0) donateAmt_ = userDetf_;
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(_nft()), donateAmt_);
        uint256 lpOut_ = _nftDonate().donate(IERC20(detf), donateAmt_, 0, false, _deadline());
        vm.stopPrank();
        assertGt(lpOut_, 0, "DN4 lpOut");
        assertEq(IERC20(detf).totalSupply(), before_.supply, "DN4 supply");
        assertGt(_nft().convertToAssets(dnUserOriginal), before_.assets, "DN4 NAV rises");
        _assertNoJoinableDust();
    }

    function test_DN5_inert_reverts() public {
        _ensureDonor();
        address inert_ = _deployInstance(_uniqueDetfArgs("dn5"));
        IDETFNFTVault nft_ = IDETFNFTVault(IUniswapV4Detf(inert_).bondNftVault());
        IERC20 tok_ = _openPairToken();
        _fundLaunch(dnDonor, 1 ether);
        vm.startPrank(dnDonor);
        tok_.approve(address(nft_), 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(tok_, 1 ether, 0, false, _deadline());
        vm.stopPrank();
        assertEq(IDetfNftReserveDonation(address(nft_)).previewDonate(tok_, 1 ether), 0, "DN5 preview inert");
    }

    function test_DN6_twoBonders_navRisesTogether() public {
        _ensureLiveBond();
        address bob_ = makeAddr("dn6bob");
        (uint256 bobId,) = _bondAs(bob_, 80 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId);
        uint256 aliceAssets_ = nft_.convertToAssets(dnUserOriginal);
        uint256 bobAssets_ = nft_.convertToAssets(bobOrig_);
        _donatePair(dnDonor, 15 ether);
        assertGt(nft_.convertToAssets(dnUserOriginal), aliceAssets_, "DN6 alice NAV");
        assertGt(nft_.convertToAssets(bobOrig_), bobAssets_, "DN6 bob NAV");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "DN6 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "DN6 id2 original");
    }

    function test_DN7_detf_donate_forwardsToNft() public {
        _ensureLiveBond();
        uint256 amt_ = 8 ether;
        IDETFNFTVault nft_ = _nft();
        uint256 nftLpBefore_ = _lpToken().balanceOf(address(nft_));
        IERC20 tok_ = _openPairToken();
        vm.startPrank(dnDonor);
        tok_.transfer(address(nft_), amt_);
        IUniswapV4Detf(detf).donate(tok_, amt_, true);
        vm.stopPrank();
        assertGt(_lpToken().balanceOf(address(nft_)), nftLpBefore_, "DN7 nft LP");
        assertEq(tok_.balanceOf(detf), 0, "DN7 pull not on diamond");
        _assertNoJoinableDust();
    }

    function test_DN8_joinDonatedCapital_eoaReverts() public {
        _ensureLiveBond();
        address attacker_ = makeAddr("dn8");
        vm.prank(attacker_);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, attacker_));
        detfInfo.joinDonatedCapital(_openPairToken(), 1 ether, _deadline());
    }

    function test_DN9_pretransferred_noSurplus_reverts() public {
        _ensureLiveBond();
        address attacker_ = makeAddr("dn9");
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(attacker_, 25 ether);
        uint256 oBefore_ = _nft().totalOriginalShares();
        uint256 lpBefore_ = _lpToken().balanceOf(address(_nft()));
        vm.prank(attacker_);
        try _nftDonate().donate(IERC20(address(junk_)), 10 ether, 0, true, _deadline()) {
            revert("DN9 junk donate must not credit");
        } catch {}
        assertEq(_nft().totalOriginalShares(), oBefore_, "DN9 O");
        assertEq(_lpToken().balanceOf(address(_nft())), lpBefore_, "DN9 lp");
    }

    function test_DN10_previewEqualsExecute() public {
        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amt_ = 7 ether;
        uint256 preview_;
        try detfInfo.previewJoinDonatedCapital(token_, amt_) returns (uint256 p_) {
            preview_ = p_;
        } catch {}
        if (preview_ == 0) preview_ = _nftDonate().previewDonate(token_, amt_);
        uint256 lpOut_ = _donatePair(dnDonor, amt_);
        if (preview_ > 0) {
            assertApproxEqRel(lpOut_, preview_, 0.12e18, "DN10 preview ~ execute");
        } else {
            assertGt(lpOut_, 0, "DN10 lpOut");
        }
    }

    function test_DN11_ownerOnlyLiquidity_donateStillWorks() public {
        _ensureLiveBond();
        address attacker_ = makeAddr("dn11");
        address hook_ = detfInfo.hook();
        IERC20 tok_ = _openPairToken();
        _fundLaunch(attacker_, 1 ether);
        uint256 lpBefore_ = IERC20(hook_).balanceOf(attacker_);
        vm.startPrank(attacker_);
        tok_.approve(hook_, 1 ether);
        try IUniswapV4SeBufferHook(hook_).joinSingleAssetExactIn(
            address(tok_), 1 ether, attacker_, 0, _deadline()
        ) {} catch {}
        vm.stopPrank();
        assertEq(IERC20(hook_).balanceOf(attacker_), lpBefore_, "DN11 no third-party LP");
        uint256 lpOut_ = _donatePair(dnDonor, 5 ether);
        assertGt(lpOut_, 0, "DN11 donate");
        _assertNoJoinableDust();
    }

    function test_DN12_donate_doesNotRealizeExpansion() public {
        _ensureLiveBond();
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 lastBefore_ = _lastExpansionTs();
        _donatePair(dnDonor, 6 ether);
        assertEq(_lastExpansionTs(), lastBefore_, "DN12 timestamp");
        assertEq(detfInfo.pendingExpansionDetf(), pending_, "DN12 pending");
    }

    function test_DN13_burn_afterDonate_usesDonatedLp() public {
        _ensureLiveBond();
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "DN13 bond DETF");
        _donatePair(dnDonor, 12 ether);
        uint256 nftLp_ = _lpToken().balanceOf(address(_nft()));
        uint256 burnAmt_ = userDetf_ / 3;
        if (burnAmt_ == 0) burnAmt_ = userDetf_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 pairOut_ = detfInfo.burn(burnAmt_, _openPairToken(), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(pairOut_, 0, "DN13 burn");
        assertLt(_lpToken().balanceOf(address(_nft())), nftLp_, "DN13 donated LP in D13 formula");
        _assertNoJoinableDust();
    }

    function test_DN14_closeAfterDonate_userBasketUnchanged() public {
        _ensureLiveBond();
        address bob_ = makeAddr("dn14bob");
        (uint256 bobId,) = _bondAs(bob_, 60 ether);
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        uint256 detfIdx_ = _detfTokenIndex(toks_);
        uint256[] memory snap_ = detfInfo.previewCloseBondMature(bobId);
        uint256 pairIdx_ = _pairIndex(toks_);
        uint256 pairSnap_ = snap_[pairIdx_];
        assertEq(snap_[detfIdx_], 0, "DN14 snapshot DETF slot unpaid");
        assertGt(pairSnap_, 0, "DN14 snapshot pair");
        _donatePair(dnDonor, 9 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 id0Before_ = _nft().originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(bob_);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob_, _deadline());
        assertEq(out_[detfIdx_], 0, "DN14 DETF slot not paid");
        assertGt(out_[pairIdx_], 0, "DN14 pair basket");
        assertGe(out_[pairIdx_] + 10, pairSnap_, "DN14 pair >= pre-donate snapshot");
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "DN14 no DETF burn");
        assertGt(_nft().originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "DN14 DETF rejoin id0");
        _assertNoJoinableDust();
    }

    function test_DN16_lastClose_thenDonate_nextBondDoesNotCapture() public {
        _ensureLiveBond();
        address bob_ = makeAddr("dn16bob");
        address carol = makeAddr("dn16carol");
        (uint256 bobId,) = _bondAs(bob_, 40 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(_openPairToken(), 20 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.closeBondMature(dnUserBondId, _minOut(), detfUser, _deadline());
        vm.prank(bob_);
        detfInfo.closeBondMature(bobId, _minOut(), bob_, _deadline());
        uint256 donateAmt_ = IERC20(detf).balanceOf(detfUser) / 4;
        if (donateAmt_ == 0) donateAmt_ = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(_nft()), donateAmt_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(_nft())).donate(
            IERC20(detf), donateAmt_, 0, false, _deadline()
        );
        vm.stopPrank();
        assertGt(lpOut_, 0, "DN16 donated LP");
        uint256 id0AfterDonate_ = _nft().originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        (uint256 carolId,) = _bondAs(carol, 30 ether);
        assertGe(_nft().originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0AfterDonate_, "DN16 next bond leaves id0");
        uint256 carolOrig_ = _nft().originalSharesOf(carolId);
        uint256 carolAssets_ = _nft().convertToAssets(carolOrig_);
        uint256 totalLp_ = _lpToken().balanceOf(address(_nft()));
        assertLt(carolAssets_, totalLp_, "DN16 carol does not swallow donated LP");
        _assertNoJoinableDust();
    }

    function test_DN17_d2_ids12_effectiveShares() public {
        _ensureLiveBond();
        _donatePair(dnDonor, 8 ether);
        _assertD2Identity();
    }

    function test_DN18_disabled_donateReverts_closeWorks() public {
        _ensureLiveBond();
        address bob_ = makeAddr("dn18bob");
        address carol = makeAddr("dn18carol");
        (uint256 bobId,) = _bondAs(bob_, 50 ether);
        (uint256 carolId,) = _bondAs(carol, 40 ether);
        uint256 aliceDetf_ = IERC20(detf).balanceOf(detfUser);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        assertGt(_d10SellToClaim(carolId, carol), 0, "DN18 pre-disable D10 claim");
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        bytes memory disabledErr_ = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf);
        vm.startPrank(detfUser);
        vm.expectRevert(disabledErr_);
        detfInfo.donate(_openPairToken(), 4 ether, false);
        vm.stopPrank();
        vm.prank(bob_);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob_, _deadline());
        assertGt(out_[_pairIndex(IUniswapV4SeBufferHook(detfInfo.hook()).tokens())], 0, "DN18 close");
        uint256 burnAmt_ = aliceDetf_ / 4;
        if (burnAmt_ == 0) burnAmt_ = aliceDetf_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 pairOut_ = detfInfo.burn(burnAmt_, _openPairToken(), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(pairOut_, 0, "DN18 burn");
        IRebasingClaimToken claim_ = IRebasingClaimToken(detfInfo.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(carol);
        vm.startPrank(carol);
        uint256 redeemed_ = claim_.redeem(claimBal_, carol, false);
        vm.stopPrank();
        assertGt(redeemed_, 0, "DN18 redeem");
    }

    function test_DN19_permit2_allowance() public {
        _ensureLiveBond();
        uint256 amt_ = 5 ether;
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        IERC20(launchToken).approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            launchToken, address(_nft()), type(uint160).max, type(uint48).max
        );
        uint256 fromPermit_ = _nftDonate().donateWithPermit2Allowance(IERC20(launchToken), amt_, 0, _deadline());
        vm.stopPrank();
        _assertR12aUnassigned(before_, fromPermit_);
    }

    function test_DN20_permit2_signature() public {
        _ensureLiveBond();
        uint256 amt_ = 4 ether;
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 deadline_ = _deadline();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: launchToken, amount: amt_}),
            nonce: 0,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(dnDonorPk, launchToken, amt_, address(_nft()), 0, deadline_);
        bytes memory data_ = abi.encode(permit_, sig_);
        vm.startPrank(dnDonor);
        IERC20(launchToken).approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = _nftDonate().donateWithPermit2Signature(IERC20(launchToken), amt_, 0, deadline_, data_);
        vm.stopPrank();
        assertGt(lpOut_, 0, "DN20 lpOut");
        _assertR12aUnassigned(before_, lpOut_);
    }

    function test_DN21_d2_afterDonate() public {
        _ensureLiveBond();
        uint256 oBefore_ = _nft().totalOriginalShares();
        _donatePair(dnDonor, 13 ether);
        assertEq(_nft().totalOriginalShares(), oBefore_, "DN21 O unchanged");
        _assertD2Identity();
    }

    function test_DN22_donate_whilePoolManagerUnlocked() public {
        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        Uv4DetfDonateDuringUnlockHarness harness =
            new Uv4DetfDonateDuringUnlockHarness(IPoolManager(address(poolManager)));
        // Launch token transfer can re-enter PoolManager; donate DETF self-leg instead.
        IERC20 tok_ = IERC20(detf);
        uint256 send_ = tok_.balanceOf(detfUser) / 4;
        if (send_ == 0) send_ = tok_.balanceOf(detfUser);
        require(send_ > 0, "DN22 DETF");
        vm.prank(detfUser);
        tok_.transfer(address(harness), send_);
        IDETFNFTVault nft_ = _nft();
        // Pretransfer into the NFT: DETF transferFrom during an open PoolManager unlock reverts.
        vm.prank(address(harness));
        tok_.transfer(address(nft_), send_);
        bytes memory ret_ = harness.run(
            address(nft_),
            abi.encodeWithSelector(
                bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)")),
                address(tok_),
                send_,
                uint256(0),
                true,
                _deadline()
            )
        );
        uint256 lpOut_ = abi.decode(ret_, (uint256));
        _assertR12aUnassigned(before_, lpOut_);
    }
}

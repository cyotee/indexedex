// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_SingleStandardExchangeDETF_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";
import {FundedPrimaryRouteAssertions} from "contracts/test/bases/FundedPrimaryRouteAssertions.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    ILegacySingleStandardExchangeDETFBonding as ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ILegacySingleStandardExchangeDETFInfo as ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @notice D29 donate DN1–DN13 / DN15–DN21 on production Balancer Single SE DETF proxy.
/// @dev DN11 N/A (Balancer public join stays, L5).
abstract contract SingleStandardExchangeDETF_ReserveDonation_Decimals is
    TestBase_SingleStandardExchangeDETF_Decimals,
    FundedBondLifecycleAssertions,
    FundedPrimaryRouteAssertions
{
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal donor;
    uint256 internal donorPk;
    uint256 internal userBondId;
    uint256 internal userPrincipal;
    uint256 internal donationUnit;

    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetf("dn sse", "dnsse");
        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        donorPk = 0xA11CE;
        donor = vm.addr(donorPk);
        {
            address p2_ = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
            vm.etch(p2_, address(permit2).code);
            permit2 = IPermit2(p2_);
        }
        (userBondId,) = _bootstrapViaFirstBond(alice, 1_200e18);
        userPrincipal = _nft().positionOf(userBondId).principal;
        donationUnit = _fundSeShares(donor, 10_000e18) / 10_000;
        vm.prank(donor);
        seShare.approve(address(_nft()), type(uint256).max);
    }

    function _nft() internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(detfInfo.bondNftVault());
    }

    function _dl() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](2);
    }

    function _poolBalance(IERC20 token_) internal view returns (uint256) {
        address pool_ = detfInfo.reservePool();
        (IERC20[] memory tokens_,, uint256[] memory bals_,) = IVault(address(vault)).getPoolTokenInfo(pool_);
        for (uint256 i; i < tokens_.length; ++i) {
            if (address(tokens_[i]) == address(token_)) return bals_[i];
        }
        return 0;
    }

    /// @dev Unbalanced join cannot exceed Balancer 300% invariant ratio. 25% of the
    ///      live leg is a conservative cap (same fraction as D25-7 DETF rejoin).
    function _capToPool(IERC20 token_, uint256 want_) internal view returns (uint256) {
        uint256 rem_ = _poolBalance(token_);
        uint256 cap_ = rem_ / 4;
        if (cap_ == 0) cap_ = rem_ > 0 ? rem_ : 1;
        return want_ < cap_ ? want_ : cap_;
    }

    function _donateMintToken(address from_, uint256 amount_) internal returns (uint256 lpOut_) {
        IDetfBondNFT nft_ = _nft();
        vm.startPrank(from_);
        seShare.approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(seShare, amount_, 0, false, _dl());
        vm.stopPrank();
    }

    function test_N1_donate_payment_buildsProtocolLp() public {
        IDetfBondNFT nft_ = _nft();
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 lpBefore_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(alice);
        uint256 userAssetsBefore_ = nft_.positionOf(userBondId).principal;
        uint256 lpOut_ = _donateMintToken(donor, 10 * donationUnit);
        assertGt(lpOut_, 0, "N1 lpOut");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), lpBefore_, "N1 nftLp");
        assertGt(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N1 protocol LP");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N1 no mint");
        assertEq(IERC20(detf).balanceOf(alice), userDetfBefore_, "N1 user DETF");
        assertEq(nft_.positionOf(userBondId).principal, userPrincipal, "N1 purchased principal");
        assertEq(nft_.positionOf(userBondId).principal, userAssetsBefore_, "N1 purchased principal unchanged");
    }

    function test_N2_donate_vaultShare_buildsProtocolLp() public {
        uint256 shares_ = _fundSeShares(donor, 20e18);
        assertGt(shares_, 0, "funded shares");
        IDetfBondNFT nft_ = _nft();
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.startPrank(donor);
        seShare.approve(address(nft_), shares_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(seShare, shares_, 0, false, _dl());
        vm.stopPrank();
        assertGt(lpOut_, 0, "N2 lpOut");
        assertGt(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N2 protocol LP");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N2 no mint");
    }

    function test_N3_donate_lpToken_thisCallInboundOnly() public {
        IDetfBondNFT nft_ = _nft();
        IERC20 lp_ = nft_.lpToken();
        uint256 shares_ = _fundSeShares(donor, 40e18);
        _externalReserveJoin(
            PrimaryContext(detf, _fundedBondStaking(detf), nft_, IVault(address(vault)), seShare, 0, donor),
            address(router),
            address(router.getPermit2()),
            donor,
            shares_
        );
        uint256 payment_ = lp_.balanceOf(donor);
        assertGt(payment_, 0, "donor acquired LP through public reserve join");
        uint256 before_ = lp_.balanceOf(address(nft_));
        vm.startPrank(donor);
        lp_.approve(address(nft_), payment_);
        uint256 received_ = IDetfNftReserveDonation(address(nft_)).donate(lp_, payment_, 0, false, _dl());
        vm.stopPrank();
        assertEq(received_, payment_, "only fresh LP credited");
        assertEq(lp_.balanceOf(address(nft_)), before_ + payment_);
        assertEq(lp_.balanceOf(donor), 0);
    }

    function test_N4_donate_detf_selfLeg_noMint() public {
        uint256 userDetf_ = _fundDonationDetf(alice);
        assertGt(userDetf_, 0, "N4 bond DETF");
        uint256 donateAmt_ = _capToPool(IERC20(detf), userDetf_ / 4);
        if (donateAmt_ == 0) donateAmt_ = userDetf_;
        IDetfBondNFT nft_ = _nft();
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 claimBefore_ = IERC20(detfInfo.rebasingClaimToken()).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(alice);
        vm.startPrank(alice);
        IERC20(detf).approve(address(nft_), donateAmt_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(IERC20(detf), donateAmt_, 0, false, _dl());
        vm.stopPrank();
        assertGt(lpOut_, 0, "N4 lpOut");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N4 supply");
        assertEq(IERC20(detf).balanceOf(alice), userDetfBefore_ - donateAmt_, "N4 donor DETF down");
        assertGt(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N4 protocol LP");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).totalSupply(), claimBefore_, "N4 no claim");
    }

    function test_N5_inert_reverts() public {
        address inert_ = _deployOpenModeDetf("dn5 inert", "dn5i");
        IDetfBondNFT nft_ = IDetfBondNFT(ISingleStandardExchangeDETFInfo(inert_).bondNftVault());
        rateAsset.mint(donor, 1e18);
        vm.startPrank(donor);
        IERC20(address(rateAsset)).approve(address(nft_), 1e18);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(IERC20(address(rateAsset)), 1e18, 0, false, _dl());
        vm.stopPrank();
        assertEq(
            IDetfNftReserveDonation(address(nft_)).previewDonate(IERC20(address(rateAsset)), 1e18), 0, "N5 preview"
        );
    }

    function test_N6_twoBonders_principalUnchanged() public {
        uint256 bobId_ = _bootstrapDetf(detf, bob, 200e18);
        IDetfBondNFT nft_ = _nft();
        uint256 bobOrig_ = nft_.positionOf(bobId_).principal;
        uint256 aliceAssets_ = nft_.positionOf(userBondId).principal;
        uint256 bobAssets_ = nft_.positionOf(bobId_).principal;
        _donateMintToken(donor, 15 * donationUnit);
        assertEq(nft_.positionOf(userBondId).principal, aliceAssets_, "N6 alice NAV");
        assertEq(nft_.positionOf(bobId_).principal, bobAssets_, "N6 bob NAV");
        assertEq(nft_.positionOf(DETF_FEE_TO_BOND_NFT_ID).principal, 0, "N6 id1");
        assertEq(nft_.positionOf(DETF_CREATOR_BOND_NFT_ID).principal, 0, "N6 id2");
    }

    function test_N7_idetf_forwarder_donorIsCollector() public {
        address collector = makeAddr("collector");
        uint256 amt_ = 8 * donationUnit;
        uint256 shares_ = _fundSeShares(collector, 80e18);
        IDetfBondNFT nft_ = _nft();
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        vm.prank(collector);
        seShare.transfer(address(nft_), shares_);
        vm.expectEmit(true, true, false, false, address(nft_));
        emit IDetfNftReserveDonation.ReserveDonated(collector, address(seShare), shares_, 0);
        vm.prank(collector);
        IDetf(detf).donate(seShare, shares_, true);
        assertGt(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N7 protocol LP");
    }

    function test_N8_joinDonatedCapital_eoaReverts() public {
        address attacker = makeAddr("dn8");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(SingleStandardExchangeDETFRepo.NotAuthorized.selector, attacker));
        detfBonding.joinDonatedCapital(IERC20(address(rateAsset)), 1e18, _dl());
    }

    function test_N9_pretransferred_noSurplus_reverts() public {
        IDetfBondNFT nft_ = _nft();
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(nft_));
        address attacker = makeAddr("dn9");
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(attacker, 25e18);
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        IERC20 lpToken_ = nft_.lpToken();
        uint256 deadline_ = _dl();
        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(IERC20(address(junk_)), 10e18, 0, true, deadline_);
        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(lpToken_, 1e18, 0, true, deadline_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N9 protocol LP");
    }

    function test_N10_previewEqualsExecute() public {
        uint256 amt_ = 7 * donationUnit;
        uint256 preview_ = IDetfNftReserveDonation(address(_nft())).previewDonate(seShare, amt_);
        uint256 lpOut_ = _donateMintToken(donor, amt_);
        assertGt(preview_, 0, "N10 preview");
        assertGt(lpOut_, 0, "N10 execute");
        // Balancer unbalanced join is not closed-form; linear preview vs execute can be wide.
    }

    /// @notice DN11 N/A: Balancer public join stays (L5). Donate still succeeds.
    function test_N11_publicJoin_nA_donateStillWorks() public {
        assertGt(_donateMintToken(donor, 5 * donationUnit), 0, "N11 donate");
    }

    function test_N12_donate_doesNotRealizeExpansion() public {
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 lastBefore_ = detfInfo.lastExpansionTimestamp();
        _donateMintToken(donor, 6 * donationUnit);
        assertEq(detfInfo.lastExpansionTimestamp(), lastBefore_, "N12 timestamp");
    }

    function test_N13_burn_afterDonate_usesDonatedLp() public {
        uint256 userDetf_ = _fundDonationDetf(alice);
        assertGt(userDetf_, 0, "N13 bond DETF");
        _donateMintToken(donor, 12 * donationUnit);
        IDetfBondNFT nft_ = _nft();
        uint256 nftLp_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        bool primary_ = detfInfo.isBurningAllowed();
        // Keep the exit above one native SE-share unit in low-decimal fixtures.
        uint256 burnAmt_ = userDetf_;
        uint256 sharesBefore_ = seShare.balanceOf(alice);
        vm.startPrank(alice);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 pairOut_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), burnAmt_, seShare, 1, alice, false, _dl());
        vm.stopPrank();
        assertGt(pairOut_, 0, "N13 burn");
        assertEq(seShare.balanceOf(alice), sharesBefore_ + pairOut_, "funded payout credited");
        assertEq(IERC20(detf).balanceOf(alice), 0, "funded DETF consumed");
        if (primary_) assertLt(nft_.lpToken().balanceOf(address(nft_)), nftLp_, "primary burn uses protocol LP");
        else assertEq(nft_.lpToken().balanceOf(address(nft_)), nftLp_, "fallback swaps existing reserve balances");
    }

    function test_N15_donation_preservesPurchasedPrincipal() public {
        IDetfBondNFT nft_ = _nft();
        uint256 assetsBefore_ = nft_.positionOf(userBondId).principal;
        _donateMintToken(donor, 11 * donationUnit);
        assertEq(nft_.positionOf(userBondId).principal, assetsBefore_, "N15 N10");
    }

    function test_N16_lastClaim_thenDonate_nextBondHasOnlyFundedPrincipal() public {
        uint256 bobId_ = _bootstrapDetf(detf, bob, 200e18);
        _assertBondMaturePreviewEqualsPayment(detf, userBondId, alice);
        _assertBondMaturePreviewEqualsPayment(detf, bobId_, bob);
        IDetfBondNFT nft_ = _nft();
        uint256 before_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 donated_ = _donateMintToken(donor, 10 * donationUnit);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), before_ + donated_);
        address carol_ = makeAddr("dn16carol");
        uint256 payment_ = _capToPool(seShare, _fundSeShares(carol_, 30e18));
        (uint256 principal_,,) = detfBonding.previewBond(seShare, payment_, DEFAULT_MIN_LOCK);
        vm.startPrank(carol_);
        seShare.approve(detf, payment_);
        (uint256 id_,) = detfBonding.bond(seShare, payment_, DEFAULT_MIN_LOCK, carol_, false, _dl());
        vm.stopPrank();
        assertEq(nft_.positionOf(id_).principal, principal_, "only quoted purchase is owed");
        assertGe(nft_.lpToken().balanceOf(address(nft_)), before_ + donated_, "gift remains protocol-owned");
        _assertBondPrincipalIsFunded(detf, id_, carol_);
    }

    function test_N17_fundedStandingRecipientWeights() public {
        _assertD2();
    }

    function test_N18_disabled_donateReverts_fundedClaimWorks() public {
        uint256 bobId_ = _bootstrapDetf(detf, bob, 200e18);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        address donationTarget_ = address(_nft());
        vm.prank(donor);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf));
        IDetfNftReserveDonation(donationTarget_).donate(seShare, 4 * donationUnit, 0, false, _dl());
        _assertBondMaturePreviewEqualsPayment(detf, bobId_, bob);
        _assertFundedUnstake(detf, bob, _fundedBondStaking(detf).balanceOf(bob));
    }

    function test_N19_permit2_allowance() public {
        IDetfBondNFT nft_ = _nft();
        uint256 amt_ = 5 * donationUnit;
        uint256 preview_ = IDetfNftReserveDonation(address(nft_)).previewDonate(seShare, amt_);
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        vm.startPrank(donor);
        seShare.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2))
            .approve(address(seShare), address(nft_), type(uint160).max, type(uint48).max);
        uint256 fromPermit_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Allowance(seShare, amt_, 0, _dl());
        vm.stopPrank();
        assertGt(fromPermit_, 0, "N19 execute");
        assertGt(preview_, 0, "N19 preview");
        assertGt(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N19 protocol LP");
    }

    function test_N20_permit2_signature() public {
        IDetfBondNFT nft_ = _nft();
        uint256 amt_ = 4 * donationUnit;
        uint256 deadline_ = _dl();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(seShare), amount: amt_}),
            nonce: 0,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(donorPk, address(seShare), amt_, address(nft_), 0, deadline_);
        uint256 lpBeforeDonation_ = nft_.lpToken().balanceOf(address(nft_));
        vm.startPrank(donor);
        seShare.approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_))
            .donateWithPermit2Signature(seShare, amt_, 0, deadline_, abi.encode(permit_, sig_));
        vm.stopPrank();
        assertGt(lpOut_, 0, "N20 lpOut");
        assertGt(nft_.lpToken().balanceOf(address(nft_)), lpBeforeDonation_, "N20 protocol LP");
    }

    function test_N21_fundedWeightsAfterDonation() public {
        _donateMintToken(donor, 13 * donationUnit);
        _assertD2();
    }

    function _assertD2() internal view {
        (, uint256 fee_, uint256 creator_) =
            IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(detf);
        IStakedDETF staking_ = _fundedBondStaking(detf);
        IStakedDETF.StakingState memory state_ = staking_.stakingState();
        uint256 implied_ = Math.mulDiv(state_.totalGons, 1e18, 1e18 - fee_ - creator_);
        assertEq(state_.feeWeight, Math.mulDiv(implied_, fee_, 1e18), "standing fee weight");
        assertEq(state_.creatorWeight, Math.mulDiv(implied_, creator_, 1e18), "standing creator weight");
        assertGe(IERC20(detf).balanceOf(address(staking_)), staking_.totalSupply(), "all staking is funded");
        assertEq(_nft().positionOf(DETF_FEE_TO_BOND_NFT_ID).principal, 0);
        assertEq(_nft().positionOf(DETF_CREATOR_BOND_NFT_ID).principal, 0);
    }

    function _fundDonationDetf(address user_) internal returns (uint256 amount_) {
        uint256 shares_ = _fundSeShares(user_, 20e18);
        vm.startPrank(user_);
        seShare.approve(detf, shares_);
        amount_ = IStandardExchangeIn(detf).exchangeIn(seShare, shares_, IERC20(detf), 0, user_, false, _dl());
        vm.stopPrank();
        assertGt(amount_, 0, "donor bought funded DETF");
    }

    function _signPermit2(
        uint256 pk_,
        address token_,
        uint256 amount_,
        address spender_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (bytes memory sig_) {
        bytes32 tokenHash_ = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token_, amount_));
        bytes32 structHash_ =
            keccak256(abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenHash_, spender_, nonce_, deadline_));
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash_));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(pk_, digest_);
        sig_ = abi.encodePacked(r_, s_, v_);
    }
}

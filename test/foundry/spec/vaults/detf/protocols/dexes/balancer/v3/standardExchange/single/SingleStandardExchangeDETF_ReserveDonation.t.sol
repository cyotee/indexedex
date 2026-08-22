// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @notice D29 donate DN1–DN13 / DN15–DN21 on production Balancer Single SE DETF proxy.
/// @dev DN11 N/A (Balancer public join stays, L5).
contract SingleStandardExchangeDETF_ReserveDonation is TestBase_SingleStandardExchangeDETF {
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal donor;
    uint256 internal donorPk;
    uint256 internal userBondId;
    uint256 internal userOriginal;

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
        userOriginal = _nft().originalSharesOf(userBondId);
        _fundSeShares(donor, 10_000e18);
        vm.prank(donor);
        seShare.approve(address(_nft()), type(uint256).max);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function _dl() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](2);
    }

    function _poolBalance(IERC20 token_) internal view returns (uint256) {
        address pool_ = detfInfo.reservePool();
        (IERC20[] memory tokens_,, uint256[] memory bals_,) =
            IVault(address(vault)).getPoolTokenInfo(pool_);
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
        IDETFNFTVault nft_ = _nft();
        vm.startPrank(from_);
        seShare.approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(seShare, amount_, 0, false, _dl());
        vm.stopPrank();
    }

    function test_N1_donate_pairToken_credits_id0() public {
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpBefore_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(alice);
        uint256 userAssetsBefore_ = nft_.convertToAssets(userOriginal);
        uint256 lpOut_ = _donateMintToken(donor, 10e18);
        assertGt(lpOut_, 0, "N1 lpOut");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), lpBefore_, "N1 nftLp");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N1 id0");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N1 no mint");
        assertEq(IERC20(detf).balanceOf(alice), userDetfBefore_, "N1 user DETF");
        assertEq(nft_.originalSharesOf(userBondId), userOriginal, "N1 user original");
        assertEq(nft_.convertToAssets(userOriginal), userAssetsBefore_, "N1 NAV");
    }

    function test_N2_donate_vaultShare_credits_id0() public {
        uint256 shares_ = _fundSeShares(donor, 20e18);
        if (shares_ == 0) return;
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.startPrank(donor);
        seShare.approve(address(nft_), shares_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(seShare, shares_, 0, false, _dl());
        vm.stopPrank();
        assertGt(lpOut_, 0, "N2 lpOut");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N2 id0");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N2 no mint");
    }

    function test_N3_donate_lpToken_thisCallInboundOnly() public {
        IDETFNFTVault nft_ = _nft();
        IERC20 lp_ = nft_.lpToken();
        uint256 booked_ = lp_.balanceOf(address(nft_));
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 shares_ = _fundSeShares(donor, 40e18);
        vm.startPrank(donor);
        seShare.approve(detf, shares_);
        IStandardExchangeIn(detf).exchangeIn(seShare, shares_, IERC20(detf), 0, donor, false, _dl());
        vm.stopPrank();
        uint256 mintedLp_ = lp_.balanceOf(detf);
        assertGt(mintedLp_, 0, "N3 donor LP");
        vm.prank(detf);
        lp_.transfer(donor, mintedLp_);
        vm.startPrank(donor);
        lp_.approve(address(nft_), mintedLp_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(lp_, mintedLp_, 0, false, _dl());
        vm.stopPrank();
        assertEq(lpOut_, mintedLp_, "N3 inbound delta");
        assertEq(lp_.balanceOf(address(nft_)), booked_ + mintedLp_, "N3 no double credit");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N3 id0");
    }

    function test_N4_donate_detf_selfLeg_noMint() public {
        uint256 userDetf_ = IERC20(detf).balanceOf(alice);
        assertGt(userDetf_, 0, "N4 bond DETF");
        uint256 donateAmt_ = userDetf_ / 4;
        if (donateAmt_ == 0) donateAmt_ = userDetf_;
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
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
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N4 id0");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).totalSupply(), claimBefore_, "N4 no claim");
    }

    function test_N5_inert_reverts() public {
        address inert_ = _deployOpenModeDetf("dn5 inert", "dn5i");
        IDETFNFTVault nft_ = _bondNftVault(inert_);
        dai.mint(donor, 1e18);
        vm.startPrank(donor);
        IERC20(address(dai)).approve(address(nft_), 1e18);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(IERC20(address(dai)), 1e18, 0, false, _dl());
        vm.stopPrank();
        assertEq(
            IDetfNftReserveDonation(address(nft_)).previewDonate(IERC20(address(dai)), 1e18),
            0,
            "N5 preview"
        );
    }

    function test_N6_twoBonders_navUnchanged() public {
        uint256 bobId_ = _bootstrapDetf(detf, bob, 200e18);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId_);
        uint256 aliceAssets_ = nft_.convertToAssets(userOriginal);
        uint256 bobAssets_ = nft_.convertToAssets(bobOrig_);
        _donateMintToken(donor, 15e18);
        assertEq(nft_.convertToAssets(userOriginal), aliceAssets_, "N6 alice NAV");
        assertEq(nft_.convertToAssets(bobOrig_), bobAssets_, "N6 bob NAV");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "N6 id1");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID)), 0, "N6 id2");
    }

    function test_N7_idetf_forwarder_donorIsCollector() public {
        address collector = makeAddr("collector");
        uint256 amt_ = 8e18;
        uint256 shares_ = _fundSeShares(collector, 80e18);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(collector);
        seShare.transfer(address(nft_), shares_);
        vm.expectEmit(true, true, false, false, address(nft_));
        emit IDetfNftReserveDonation.ReserveDonated(collector, address(seShare), shares_, 0);
        vm.prank(collector);
        IDetf(detf).donate(seShare, shares_, true);
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N7 id0");
    }

    function test_N8_joinDonatedCapital_eoaReverts() public {
        address attacker = makeAddr("dn8");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(SingleStandardExchangeDETFRepo.NotAuthorized.selector, attacker)
        );
        detfBonding.joinDonatedCapital(IERC20(address(dai)), 1e18, _dl());
    }

    function test_N9_pretransferred_noSurplus_reverts() public {
        IDETFNFTVault nft_ = _nft();
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(nft_));
        address attacker = makeAddr("dn9");
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(attacker, 25e18);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        IERC20 lpToken_ = nft_.lpToken();
        uint256 deadline_ = _dl();
        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(IERC20(address(junk_)), 10e18, 0, true, deadline_);
        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(lpToken_, 1e18, 0, true, deadline_);
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N9 id0");
    }

    function test_N10_previewEqualsExecute() public {
        uint256 amt_ = 7e18;
        uint256 preview_ = IDetfNftReserveDonation(address(_nft())).previewDonate(seShare, amt_);
        uint256 lpOut_ = _donateMintToken(donor, amt_);
        assertGt(preview_, 0, "N10 preview");
        assertGt(lpOut_, 0, "N10 execute");
        // Balancer unbalanced join is not closed-form; linear preview vs execute can be wide.
    }

    /// @notice DN11 N/A: Balancer public join stays (L5). Donate still succeeds.
    function test_N11_publicJoin_nA_donateStillWorks() public {
        assertGt(_donateMintToken(donor, 5e18), 0, "N11 donate");
    }

    function test_N12_donate_doesNotRealizeExpansion() public {
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 lastBefore_ = detfInfo.lastExpansionTimestamp();
        _donateMintToken(donor, 6e18);
        assertEq(detfInfo.lastExpansionTimestamp(), lastBefore_, "N12 timestamp");
    }

    function test_N13_burn_afterDonate_usesDonatedLp() public {
        uint256 userDetf_ = IERC20(detf).balanceOf(alice);
        assertGt(userDetf_, 0, "N13 bond DETF");
        _donateMintToken(donor, 12e18);
        IDETFNFTVault nft_ = _nft();
        uint256 nftLp_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 burnAmt_ = userDetf_ / 3;
        if (burnAmt_ == 0) burnAmt_ = userDetf_;
        vm.startPrank(alice);
        IERC20(detf).approve(detf, type(uint256).max);
        uint256 pairOut_ = IStandardExchangeIn(detf).exchangeIn(
            IERC20(detf), burnAmt_, seShare, 0, alice, false, _dl()
        );
        vm.stopPrank();
        assertGt(pairOut_, 0, "N13 burn");
        assertLt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), nftLp_, "N13 donated LP used");
    }

    function test_N15_n10_userConvertUnchanged() public {
        IDETFNFTVault nft_ = _nft();
        uint256 assetsBefore_ = nft_.convertToAssets(userOriginal);
        _donateMintToken(donor, 11e18);
        assertEq(nft_.convertToAssets(userOriginal), assetsBefore_, "N15 N10");
    }

    function test_N16_lastClose_thenDonate_nextBondDoesNotCapture() public {
        detf = _deployOpenModeDetf("dn16 sse", "d16s");
        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
        uint256 aliceId_ = _bootstrapDetf(detf, alice, 80e18);
        uint256 bobId_ = _bootstrapDetf(detf, bob, 30e18);
        _fundSeShares(donor, 10_000e18);
        vm.prank(donor);
        seShare.approve(address(_nft()), type(uint256).max);
        _warpPastUnlock(detf, aliceId_);
        _warpPastUnlock(detf, bobId_);
        vm.prank(alice);
        detfBonding.closeBondMature(aliceId_, _minOut(), alice, _dl());
        vm.prank(bob);
        detfBonding.closeBondMature(bobId_, _minOut(), bob, _dl());
        IDETFNFTVault nft_ = _nft();
        // After last-exit the remaining book is MIN-scale; unbalanced donate/next-bond
        // must stay under Balancer InvariantRatioAboveMax (300%).
        uint256 donateAmt_ = _capToPool(seShare, 1e18);
        _donateMintToken(donor, donateAmt_);
        uint256 id0AfterDonate_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        assertGt(id0AfterDonate_, 0, "N16 gift on id0");
        address carol = makeAddr("dn16carol");
        uint256 funded_ = _fundSeShares(carol, 30e18);
        uint256 carolAmt_ = _capToPool(seShare, funded_);
        vm.startPrank(carol);
        seShare.approve(detf, carolAmt_);
        (uint256 carolId_,) = ISingleStandardExchangeDETFBonding(detf).bond(
            seShare, carolAmt_, DEFAULT_MIN_LOCK, carol, false, _dl()
        );
        vm.stopPrank();
        assertGe(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0AfterDonate_, "N16 id0 kept");
        assertLt(
            nft_.convertToAssets(nft_.originalSharesOf(carolId_)),
            IERC20(nft_.lpToken()).balanceOf(address(nft_)),
            "N16 no swallow"
        );
    }

    function test_N17_d2_ids12_effectiveShares() public {
        _assertD2();
    }

    function test_N18_disabled_donateReverts_closeWorks() public {
        uint256 bobId_ = _bootstrapDetf(detf, bob, 200e18);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(_nft()));
        uint256 deadline_ = _dl();
        vm.prank(donor);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf));
        nftDonate_.donate(seShare, 4e18, 0, false, deadline_);
        _warpPastUnlock(detf, bobId_);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(bobId_, _minOut(), bob, _dl());
        assertGt(out_[0] + out_[1], 0, "N18 close");
    }

    function test_N19_permit2_allowance() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 5e18;
        uint256 preview_ = IDetfNftReserveDonation(address(nft_)).previewDonate(seShare, amt_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        seShare.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(seShare), address(nft_), type(uint160).max, type(uint48).max
        );
        uint256 fromPermit_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Allowance(
            seShare, amt_, 0, _dl()
        );
        vm.stopPrank();
        assertGt(fromPermit_, 0, "N19 execute");
        assertGt(preview_, 0, "N19 preview");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N19 id0");
    }

    function test_N20_permit2_signature() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 4e18;
        uint256 deadline_ = _dl();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(seShare), amount: amt_}),
            nonce: 0,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(donorPk, address(seShare), amt_, address(nft_), 0, deadline_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        seShare.approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Signature(
            seShare, amt_, 0, deadline_, abi.encode(permit_, sig_)
        );
        vm.stopPrank();
        assertGt(lpOut_, 0, "N20 lpOut");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N20 id0");
    }

    function test_N21_d2_afterDonate() public {
        _donateMintToken(donor, 13e18);
        _assertD2();
    }

    function _assertD2() internal view {
        IDETFNFTVault nft_ = _nft();
        (, uint256 f_, uint256 c_) =
            IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(detf);
        uint256 feeEff_ = nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorEff_ = nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 others_ = nft_.totalShares() - feeEff_ - creatorEff_;
        uint256 implied_ = others_ * 1e18 / (1e18 - f_ - c_);
        assertApproxEqAbs(feeEff_, implied_ * f_ / 1e18, 1, "D2 id1");
        assertApproxEqAbs(creatorEff_, implied_ * c_ / 1e18, 1, "D2 id2");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "id2 original");
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

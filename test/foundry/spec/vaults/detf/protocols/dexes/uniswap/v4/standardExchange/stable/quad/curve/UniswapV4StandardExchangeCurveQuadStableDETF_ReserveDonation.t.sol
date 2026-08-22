// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
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
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol";

/// @notice D29 donate DN1–DN13 / DN15–DN21 on production Uni V4 Curve Quad DETF proxy.
contract UniswapV4StandardExchangeCurveQuadStableDETF_ReserveDonation is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
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
        detf = _deployDetfWired(_openArgsUnique("dn"));
        _bindDetfPointers();
        _setBondTermsFor(detf);
        donorPk = 0xA11CE;
        donor = vm.addr(donorPk);
        (userBondId,) = _firstBondDefault(50 ether);
        userOriginal = _nft().originalSharesOf(userBondId);
        SimpleMintableERC20(pair0).mint(donor, 10_000 ether);
        vm.prank(donor);
        IERC20(pair0).approve(address(_nft()), type(uint256).max);
        vm.prank(donor);
        IERC20(pair0).approve(detf, type(uint256).max);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function _minOut() internal view returns (uint256[] memory m) {
        m = new uint256[](detfInfo.n());
    }

    function _donateMintToken(address from_, uint256 amount_) internal returns (uint256 lpOut_) {
        IDETFNFTVault nft_ = _nft();
        vm.startPrank(from_);
        IERC20(pair0).approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(IERC20(pair0), amount_, 0, false, _dl());
        vm.stopPrank();
    }

    function test_N1_donate_pairToken_credits_id0() public {
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpBefore_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 userAssetsBefore_ = nft_.convertToAssets(userOriginal);
        uint256 lpOut_ = _donateMintToken(donor, 10 ether);
        assertGt(lpOut_, 0, "N1 lpOut");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), lpBefore_, "N1 nftLp");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N1 id0");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N1 no mint");
        assertEq(IERC20(detf).balanceOf(detfUser), userDetfBefore_, "N1 user DETF");
        assertEq(nft_.originalSharesOf(userBondId), userOriginal, "N1 user original");
        assertEq(nft_.convertToAssets(userOriginal), userAssetsBefore_, "N1 NAV");
    }

    function test_N2_donate_vaultShare_credits_id0() public {
        address shareAddr_ = detfInfo.vaultShare(0);
        if (shareAddr_ == address(0)) shareAddr_ = detfInfo.standardExchange(0);
        if (shareAddr_ == address(0)) return;
        IERC20 share_ = IERC20(shareAddr_);
        uint256 pairIn_ = 20 ether;
        SimpleMintableERC20(pair0).mint(donor, pairIn_);
        vm.startPrank(donor);
        IERC20(pair0).approve(shareAddr_, pairIn_);
        uint256 shares_ = IStandardExchangeIn(shareAddr_).exchangeIn(
            IERC20(pair0), pairIn_, share_, 0, donor, false, _dl()
        );
        vm.stopPrank();
        if (shares_ == 0) return;
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.startPrank(donor);
        share_.approve(address(nft_), shares_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(share_, shares_, 0, false, _dl());
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
        address hook_ = detfInfo.reserveHook();
        SimpleMintableERC20(pair0).mint(detf, 40 ether);
        vm.startPrank(detf);
        IERC20(pair0).approve(hook_, 40 ether);
        uint256 mintedLp_ = IHook(hook_).depositSingle(pair0, 40 ether, donor, 0, _dl());
        vm.stopPrank();
        assertGt(mintedLp_, 0, "N3 donor LP");
        vm.startPrank(donor);
        lp_.approve(address(nft_), mintedLp_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(lp_, mintedLp_, 0, false, _dl());
        vm.stopPrank();
        assertEq(lpOut_, mintedLp_, "N3 inbound");
        assertEq(lp_.balanceOf(address(nft_)), booked_ + mintedLp_, "N3 no double");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N3 id0");
    }

    function test_N4_donate_detf_selfLeg_noMint() public {
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "N4 bond DETF");
        uint256 donateAmt_ = userDetf_ / 4;
        if (donateAmt_ == 0) donateAmt_ = userDetf_;
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 claimBefore_ = IERC20(detfInfo.rebasingClaimToken()).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(nft_), donateAmt_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(IERC20(detf), donateAmt_, 0, false, _dl());
        vm.stopPrank();
        assertGt(lpOut_, 0, "N4 lpOut");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N4 supply");
        assertEq(IERC20(detf).balanceOf(detfUser), userDetfBefore_ - donateAmt_, "N4 DETF down");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N4 id0");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).totalSupply(), claimBefore_, "N4 no claim");
    }

    function test_N5_inert_reverts() public {
        address inert_ = _deployDetfWired(_openArgsUnique("dn5"));
        IDETFNFTVault nft_ = _bondNftVault(inert_);
        address p0_ = IUniswapV4StandardExchangeCurveQuadStableDETF(inert_).pairToken(0);
        SimpleMintableERC20(p0_).mint(donor, 1 ether);
        vm.startPrank(donor);
        IERC20(p0_).approve(address(nft_), 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(IERC20(p0_), 1 ether, 0, false, _dl());
        vm.stopPrank();
    }

    function test_N6_twoBonders_navUnchanged() public {
        (uint256 bobId_,) = _laterBond(makeAddr("dn6bob"), 5 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId_);
        uint256 aliceAssets_ = nft_.convertToAssets(userOriginal);
        uint256 bobAssets_ = nft_.convertToAssets(bobOrig_);
        _donateMintToken(donor, 8 ether);
        assertEq(nft_.convertToAssets(userOriginal), aliceAssets_, "N6 alice");
        assertEq(nft_.convertToAssets(bobOrig_), bobAssets_, "N6 bob");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0);
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0);
    }

    function test_N7_idetf_forwarder_donorIsCollector() public {
        address collector = makeAddr("collector");
        uint256 amt_ = 8 ether;
        SimpleMintableERC20(pair0).mint(collector, amt_);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(collector);
        IERC20(pair0).transfer(address(nft_), amt_);
        vm.expectEmit(true, true, false, false, address(nft_));
        emit IDetfNftReserveDonation.ReserveDonated(collector, pair0, amt_, 0);
        vm.prank(collector);
        IDetf(detf).donate(IERC20(pair0), amt_, true);
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N7 id0");
    }

    function test_N8_joinDonatedCapital_eoaReverts() public {
        address attacker = makeAddr("dn8");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV4StandardExchangeCurveQuadStableDETFRepo.NotAuthorized.selector, attacker
            )
        );
        detfInfo.joinDonatedCapital(IERC20(pair0), 1 ether, _dl());
    }

    function test_N9_pretransferred_noSurplus_reverts() public {
        IDETFNFTVault nft_ = _nft();
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(nft_));
        address attacker = makeAddr("dn9");
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(attacker, 25 ether);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        IERC20 lpToken_ = nft_.lpToken();
        uint256 deadline_ = _dl();
        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(IERC20(address(junk_)), 10 ether, 0, true, deadline_);
        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(lpToken_, 1 ether, 0, true, deadline_);
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_);
    }

    function test_N10_previewEqualsExecute() public {
        uint256 amt_ = 7 ether;
        uint256 preview_ = IDetfNftReserveDonation(address(_nft())).previewDonate(IERC20(pair0), amt_);
        uint256 lpOut_ = _donateMintToken(donor, amt_);
        assertApproxEqRel(lpOut_, preview_, 0.02e18, "N10");
    }

    function test_N11_ownerOnlyLiquidity_donateStillWorks() public {
        address attacker = makeAddr("dn11");
        address hook_ = detfInfo.reserveHook();
        SimpleMintableERC20(pair0).mint(attacker, 5 ether);
        vm.startPrank(attacker);
        IERC20(pair0).approve(hook_, 5 ether);
        vm.expectRevert();
        IHook(hook_).depositSingle(pair0, 5 ether, attacker, 0, _dl());
        vm.stopPrank();
        assertGt(_donateMintToken(donor, 5 ether), 0, "N11");
    }

    function test_N12_donate_doesNotRealizeExpansion() public {
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 lastBefore_ = detfInfo.lastExpansionTimestamp();
        _donateMintToken(donor, 6 ether);
        assertEq(detfInfo.lastExpansionTimestamp(), lastBefore_, "N12 timestamp");
        assertEq(detfInfo.pendingExpansionDetf(), pending_, "N12 pending");
    }

    function test_N13_burn_afterDonate_usesDonatedLp() public {
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "N13");
        _donateMintToken(donor, 8 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 nftLp_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 burnAmt_ = userDetf_ / 3;
        if (burnAmt_ == 0) burnAmt_ = userDetf_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, type(uint256).max);
        uint256 pairOut_ = IStandardExchangeIn(detf).exchangeIn(
            IERC20(detf), burnAmt_, IERC20(pair0), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
        assertGt(pairOut_, 0, "N13 burn");
        assertLt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), nftLp_, "N13 donated LP");
    }

    function test_N15_n10_userConvertUnchanged() public {
        IDETFNFTVault nft_ = _nft();
        uint256 assetsBefore_ = nft_.convertToAssets(userOriginal);
        _donateMintToken(donor, 8 ether);
        assertEq(nft_.convertToAssets(userOriginal), assetsBefore_, "N15");
    }

    function test_N16_lastClose_thenDonate_nextBondDoesNotCapture() public {
        (uint256 bobId_,) = _laterBond(makeAddr("dn16bob"), 5 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.closeBondMature(userBondId, _minOut(), detfUser, _dl());
        vm.prank(makeAddr("dn16bob"));
        detfInfo.closeBondMature(bobId_, _minOut(), makeAddr("dn16bob"), _dl());
        IDETFNFTVault nft_ = _nft();
        _donateMintToken(donor, 10 ether);
        uint256 id0AfterDonate_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        assertGt(id0AfterDonate_, 0, "N16 gift");
        (uint256 carolId_,) = _laterBond(makeAddr("dn16carol"), 5 ether);
        assertGe(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0AfterDonate_, "N16 id0");
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
        (uint256 bobId_,) = _laterBond(makeAddr("dn18bob"), 5 ether);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(_nft()));
        uint256 deadline_ = _dl();
        vm.prank(donor);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf));
        nftDonate_.donate(IERC20(pair0), 4 ether, 0, false, deadline_);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(makeAddr("dn18bob"));
        uint256[] memory out_ = detfInfo.closeBondMature(bobId_, _minOut(), makeAddr("dn18bob"), _dl());
        uint256 slot_ = detfInfo.detfBindingIndex() == 0 ? 1 : 0;
        assertGt(out_[slot_], 0, "N18 close");
    }

    function test_N19_permit2_allowance() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 5 ether;
        uint256 preview_ = IDetfNftReserveDonation(address(nft_)).previewDonate(IERC20(pair0), amt_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        IERC20(pair0).approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            pair0, address(nft_), type(uint160).max, type(uint48).max
        );
        uint256 fromPermit_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Allowance(
            IERC20(pair0), amt_, 0, _dl()
        );
        vm.stopPrank();
        assertApproxEqRel(fromPermit_, preview_, 0.02e18, "N19");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N19 id0");
    }

    function test_N20_permit2_signature() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 4 ether;
        uint256 deadline_ = _dl();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: pair0, amount: amt_}),
            nonce: 0,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(donorPk, pair0, amt_, address(nft_), 0, deadline_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        IERC20(pair0).approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Signature(
            IERC20(pair0), amt_, 0, deadline_, abi.encode(permit_, sig_)
        );
        vm.stopPrank();
        assertGt(lpOut_, 0, "N20");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N20 id0");
    }

    function test_N21_d2_afterDonate() public {
        _donateMintToken(donor, 8 ether);
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
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0);
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0);
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

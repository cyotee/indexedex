// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @notice D29 donate DN1–DN13 / DN15–DN21 on production Mixed-buffer DETF proxy.
/// @dev DN11 N/A (Balancer public join stays, L5). First mint token is buffer (rateAsset).
contract MixedBufferMultiVaultStableDetf_ReserveDonation is TestBase_MixedBufferMultiVaultStableDetf {
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal donor;
    uint256 internal donorPk;
    uint256 internal userBondId;
    uint256 internal userOriginal;
    IERC20 internal buffer;
    IERC20 internal share0;

    function setUp() public override {
        super.setUp();
        detf = _deployOpenNamed("dn mb", "dnmb");
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        buffer = IERC20(detfInfo.bufferToken());
        share0 = IERC20(detfInfo.vaultShares()[0]);
        (userBondId,,) = _bootstrapDefault(detf, alice);
        userOriginal = _nft().originalSharesOf(userBondId);
        donorPk = 0xA11CE;
        donor = vm.addr(donorPk);
        {
            address p2_ = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
            vm.etch(p2_, address(permit2).code);
            permit2 = IPermit2(p2_);
        }
        _fundBuffer(donor, 10_000e18);
        vm.prank(donor);
        buffer.approve(address(_nft()), type(uint256).max);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function _dl() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _minOut() internal view returns (uint256[] memory m) {
        m = new uint256[](_reserveTokenCount(detf));
    }

    function _deployOpenNamed(string memory name_, string memory symbol_) internal returns (address detf_) {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args_ =
            _buildPkgArgs(1, 0, 0, ThresholdMode.Open);
        args_.name = name_;
        args_.symbol = symbol_;
        detf_ = _deployWithArgs(args_);
    }

    function _laterBond(address who_, uint256 amt_) internal returns (uint256 tokenId_) {
        _fundBuffer(who_, amt_);
        vm.startPrank(who_);
        buffer.approve(detf, amt_);
        (tokenId_,) = detfBonding.bond(buffer, amt_, DEFAULT_MIN_LOCK, who_, false, _dl());
        vm.stopPrank();
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

    function _capToPool(IERC20 token_, uint256 want_) internal view returns (uint256) {
        uint256 rem_ = _poolBalance(token_);
        uint256 cap_ = rem_ / 4;
        if (cap_ == 0) cap_ = rem_ > 0 ? rem_ : 1;
        return want_ < cap_ ? want_ : cap_;
    }

    function _donateMintToken(address from_, uint256 amount_) internal returns (uint256 lpOut_) {
        IDETFNFTVault nft_ = _nft();
        vm.startPrank(from_);
        buffer.approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(buffer, amount_, 0, false, _dl());
        vm.stopPrank();
    }

    function _publicJoinShare(address joiner_, uint256 shares_) internal returns (uint256 bptOut_) {
        address pool_ = detfInfo.reservePool();
        IVault bal_ = IVault(address(vault));
        uint256 n_ = bal_.getCurrentLiveBalances(pool_).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        (IERC20[] memory tokens_,,,) = bal_.getPoolTokenInfo(pool_);
        uint256 idx_;
        for (uint256 i; i < n_; ++i) {
            if (address(tokens_[i]) == address(share0)) {
                idx_ = i;
                break;
            }
        }
        amountsIn_[idx_] = shares_;
        vm.startPrank(joiner_);
        share0.transfer(address(bal_), shares_);
        bptOut_ = IBalancerV3StandardExchangeRouterProxy(address(seRouter)).prepayAddLiquidityUnbalanced(
            pool_, amountsIn_, 0, ""
        );
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
        uint256 shares_ = _fundVaultShares(0, donor, 20e18);
        if (shares_ == 0) return;
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.startPrank(donor);
        share0.approve(address(nft_), shares_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(share0, shares_, 0, false, _dl());
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
        uint256 shares_ = _fundVaultShares(0, donor, 40e18);
        vm.startPrank(donor);
        share0.approve(detf, shares_);
        IStandardExchangeIn(detf).exchangeIn(share0, shares_, IERC20(detf), 0, donor, false, _dl());
        vm.stopPrank();
        uint256 mintedLp_ = lp_.balanceOf(detf);
        assertGt(mintedLp_, 0, "N3 donor LP");
        vm.prank(detf);
        lp_.transfer(donor, mintedLp_);
        vm.startPrank(donor);
        lp_.approve(address(nft_), mintedLp_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(lp_, mintedLp_, 0, false, _dl());
        vm.stopPrank();
        assertEq(lpOut_, mintedLp_, "N3 inbound");
        assertEq(lp_.balanceOf(address(nft_)), booked_ + mintedLp_, "N3 no double");
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
        assertEq(IERC20(detf).balanceOf(alice), userDetfBefore_ - donateAmt_, "N4 DETF down");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N4 id0");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).totalSupply(), claimBefore_, "N4 no claim");
    }

    function test_N5_inert_reverts() public {
        address inert_ = _deployOpenNamed("dn5 mb", "dn5b");
        IDETFNFTVault nft_ = _bondNftVault(inert_);
        IERC20 buf_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(inert_).bufferToken());
        _fundBuffer(donor, 1e18);
        vm.startPrank(donor);
        buf_.approve(address(nft_), 1e18);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(buf_, 1e18, 0, false, _dl());
        vm.stopPrank();
    }

    function test_N6_twoBonders_navUnchanged() public {
        uint256 bobId_ = _laterBond(bob, 100e18);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId_);
        uint256 aliceAssets_ = nft_.convertToAssets(userOriginal);
        uint256 bobAssets_ = nft_.convertToAssets(bobOrig_);
        _donateMintToken(donor, 8e18);
        assertEq(nft_.convertToAssets(userOriginal), aliceAssets_, "N6 alice");
        assertEq(nft_.convertToAssets(bobOrig_), bobAssets_, "N6 bob");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0);
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0);
    }

    function test_N7_idetf_forwarder_donorIsCollector() public {
        address collector = makeAddr("collector");
        uint256 amt_ = 8e18;
        _fundBuffer(collector, amt_);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(collector);
        buffer.transfer(address(nft_), amt_);
        vm.expectEmit(true, true, false, false, address(nft_));
        emit IDetfNftReserveDonation.ReserveDonated(collector, address(buffer), amt_, 0);
        vm.prank(collector);
        IDetf(detf).donate(buffer, amt_, true);
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N7 id0");
    }

    function test_N8_joinDonatedCapital_eoaReverts() public {
        address attacker = makeAddr("dn8");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.NotAuthorized.selector, attacker)
        );
        detfBonding.joinDonatedCapital(buffer, 1e18, _dl());
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
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_);
    }

    function test_N10_previewEqualsExecute() public {
        uint256 amt_ = 7e18;
        uint256 preview_ = IDetfNftReserveDonation(address(_nft())).previewDonate(buffer, amt_);
        uint256 lpOut_ = _donateMintToken(donor, amt_);
        assertGt(preview_, 0, "N10 preview");
        assertGt(lpOut_, 0, "N10 execute");
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
        assertGt(userDetf_, 0, "N13");
        _donateMintToken(donor, 8e18);
        IDETFNFTVault nft_ = _nft();
        uint256 nftLp_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 burnAmt_ = userDetf_ / 3;
        if (burnAmt_ == 0) burnAmt_ = userDetf_;
        vm.startPrank(alice);
        IERC20(detf).approve(detf, type(uint256).max);
        uint256 pairOut_ = IStandardExchangeIn(detf).exchangeIn(
            IERC20(detf), burnAmt_, buffer, 0, alice, false, _dl()
        );
        vm.stopPrank();
        assertGt(pairOut_, 0, "N13 burn");
        assertLt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), nftLp_, "N13 donated LP");
    }

    function test_N15_n10_userConvertUnchanged() public {
        IDETFNFTVault nft_ = _nft();
        uint256 assetsBefore_ = nft_.convertToAssets(userOriginal);
        _donateMintToken(donor, 8e18);
        assertEq(nft_.convertToAssets(userOriginal), assetsBefore_, "N15");
    }

    function test_N16_lastClose_thenDonate_nextBondDoesNotCapture() public {
        uint256 bobId_ = _laterBond(bob, 100e18);
        _warpPastUnlock(detf, userBondId);
        _warpPastUnlock(detf, bobId_);
        vm.prank(alice);
        detfBonding.closeBondMature(userBondId, _minOut(), alice, _dl());
        vm.prank(bob);
        detfBonding.closeBondMature(bobId_, _minOut(), bob, _dl());
        IDETFNFTVault nft_ = _nft();
        uint256 donateAmt_ = _capToPool(buffer, 1e18);
        uint256 shareCap_ = _capToPool(share0, 1e18);
        if (shareCap_ < donateAmt_) donateAmt_ = shareCap_;
        _donateMintToken(donor, donateAmt_);
        uint256 id0AfterDonate_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        assertGt(id0AfterDonate_, 0, "N16 gift");
        address carol = makeAddr("dn16carol");
        uint256 carolAmt_ = _capToPool(buffer, 80e18);
        uint256 carolShareCap_ = _capToPool(share0, 80e18);
        if (carolShareCap_ < carolAmt_) carolAmt_ = carolShareCap_;
        uint256 carolId_ = _laterBond(carol, carolAmt_);
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
        uint256 bobId_ = _laterBond(bob, 100e18);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(_nft()));
        uint256 deadline_ = _dl();
        vm.prank(donor);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf));
        nftDonate_.donate(buffer, 4e18, 0, false, deadline_);
        _warpPastUnlock(detf, bobId_);
        vm.prank(bob);
        uint256[] memory out_ = detfBonding.closeBondMature(bobId_, _minOut(), bob, _dl());
        uint256 sum_;
        for (uint256 i; i < out_.length; ++i) sum_ += out_[i];
        assertGt(sum_, 0, "N18 close");
    }

    function test_N19_permit2_allowance() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 5e18;
        uint256 preview_ = IDetfNftReserveDonation(address(nft_)).previewDonate(buffer, amt_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        buffer.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(buffer), address(nft_), type(uint160).max, type(uint48).max
        );
        uint256 fromPermit_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Allowance(
            buffer, amt_, 0, _dl()
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
            permitted: ISignatureTransfer.TokenPermissions({token: address(buffer), amount: amt_}),
            nonce: 0,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(donorPk, address(buffer), amt_, address(nft_), 0, deadline_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        buffer.approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Signature(
            buffer, amt_, 0, deadline_, abi.encode(permit_, sig_)
        );
        vm.stopPrank();
        assertGt(lpOut_, 0, "N20");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N20 id0");
    }

    function test_N21_d2_afterDonate() public {
        _donateMintToken(donor, 8e18);
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

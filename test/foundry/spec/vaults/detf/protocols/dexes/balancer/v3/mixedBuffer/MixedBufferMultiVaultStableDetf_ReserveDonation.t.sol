// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {FundedPrimaryRouteAssertions} from "contracts/test/bases/FundedPrimaryRouteAssertions.sol";
import {TestBase_MixedBufferMultiVaultStableDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {IMixedBufferMultiVaultStableDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";
import {MixedBufferMultiVaultStableDetfRepo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @notice D29 donations add protocol LP without changing funded staking or bond liabilities.
contract MixedBufferMultiVaultStableDetf_ReserveDonation is TestBase_MixedBufferMultiVaultStableDetf, FundedPrimaryRouteAssertions {
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    address internal donor;
    uint256 internal donorPk;
    uint256 internal userBondId;
    IERC20 internal buffer;
    IERC20 internal share0;
    IPermit2 internal donationPermit2;

    function setUp() public virtual override {
        super.setUp();
        detf = _deployNamed("donation funded", "dnfunded");
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        buffer = IERC20(detfInfo.bufferToken());
        share0 = IERC20(detfInfo.vaultShares()[0]);
        (userBondId,,) = _bootstrapDefault(detf, alice);
        donorPk = 0xA11CE;
        donor = vm.addr(donorPk);
        donationPermit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        vm.etch(address(donationPermit2), address(permit2).code);
        _fundBuffer(donor, _fixtureAmount(10_000e18));
        vm.prank(donor);
        buffer.approve(address(_nft()), type(uint256).max);
    }

    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }
    function _stake() internal view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }
    function _donation() internal view returns (IDetfNftReserveDonation) { return IDetfNftReserveDonation(address(_nft())); }
    function _dl() internal view returns (uint256) { return block.timestamp + 1 hours; }
    function _lpHeld() internal view returns (uint256) { return _nft().lpToken().balanceOf(address(_nft())); }
    function _fundedState() internal view returns (bytes memory) {
        IStakedDETF stake_ = _stake();
        return abi.encode(IERC20(detf).totalSupply(), stake_.stakingState(),
            stake_.gonsOf(address(_nft())), stake_.gonsOf(_nft().ownerOf(1)), stake_.gonsOf(_nft().ownerOf(2)),
            _nft().positionOf(userBondId), detfInfo.lastExpansionTimestamp());
    }
    function _deployNamed(string memory name_, string memory symbol_) internal returns (address) {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(1, 100e18, 10e18);
        args_.name = name_; args_.symbol = symbol_;
        return _deployWithArgs(args_);
    }
    function _laterBond(address who_, uint256 amt_) internal returns (uint256 id_) {
        _fundBuffer(who_, amt_);
        vm.startPrank(who_); buffer.approve(detf, amt_);
        (id_,) = detfBonding.bond(buffer, amt_, DEFAULT_MIN_LOCK, who_, false, _dl());
        vm.stopPrank();
    }
    function _donateMintToken(address from_, uint256 amount_) internal returns (uint256 out_) {
        vm.startPrank(from_); buffer.approve(address(_nft()), amount_);
        out_ = _donation().donate(buffer, amount_, 0, false, _dl()); vm.stopPrank();
    }
    function _assertDonation(IERC20 token_, uint256 amount_) internal returns (uint256 out_) {
        bytes memory before_ = _fundedState();
        uint256 lpBefore_ = _lpHeld();
        uint256 donorBefore_ = token_.balanceOf(donor);
        uint256 quote_ = _donation().previewDonate(token_, amount_);
        assertGt(quote_, 0, "real donation quote");
        vm.startPrank(donor); token_.approve(address(_nft()), amount_);
        out_ = _donation().donate(token_, amount_, quote_, false, _dl()); vm.stopPrank();
        assertEq(out_, quote_, "exact donation preview/payout");
        assertEq(_lpHeld(), lpBefore_ + out_, "entire inbound LP is protocol custody");
        assertEq(token_.balanceOf(donor), donorBefore_ - amount_, "only actual payment spent");
        assertEq(_fundedState(), before_, "donation neither issues DETF nor rebases/settles/funds bonds");
    }
    function _publicJoinShare(uint256 shares_) internal returns (uint256) {
        uint256 before_ = _nft().lpToken().balanceOf(donor);
        _externalReserveJoin(PrimaryContext(detf, _stake(), _nft(), IVault(address(vault)), share0, shares_, donor),
            address(router), address(permit2), donor, shares_);
        return _nft().lpToken().balanceOf(donor) - before_;
    }
    function _assertRolePositions() internal view {
        assertEq(_nft().positionOf(1).principal, 0);
        assertEq(_nft().positionOf(2).principal, 0);
        assertGt(_stake().stakingState().feeWeight, 0);
        assertGt(_stake().stakingState().creatorWeight, 0);
    }
    function _claimMature(uint256 id_, address who_) internal returns (uint256 paid_) {
        Math.BondPosition memory p_ = _nft().positionOf(id_);
        uint256 end_ = p_.startTimestamp + p_.vestingDuration;
        if (block.timestamp < end_) vm.warp(end_);
        uint256 before_ = _stake().balanceOf(who_);
        uint256 lpBefore_ = _lpHeld();
        IDetfBondNFT nft_ = _nft();
        vm.prank(who_); (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, who_);
        paid_ = principal_ + rewards_;
        assertGt(paid_, 0);
        assertEq(_stake().balanceOf(who_) - before_, paid_);
        assertEq(_lpHeld(), lpBefore_, "claim does not unwind protocol LP");
        assertEq(_nft().ownerOf(id_), address(0));
    }

    function test_N1_donate_pairToken_addsProtocolLp() public virtual { _assertDonation(buffer, _fixtureAmount(10e18)); }
    function test_N2_donate_vaultShare_addsProtocolLp() public virtual { _assertDonation(share0, _fundVaultShares(0, donor, 20e18)); }
    function test_N3_donate_lpToken_thisCallInboundOnly() public virtual {
        uint256 externalLp_ = _publicJoinShare(_fundVaultShares(0, donor, 40e18));
        IERC20 lp_ = _nft().lpToken();
        uint256 prior_ = externalLp_ / 3;
        address nft_ = address(_nft());
        vm.prank(donor); lp_.transfer(nft_, prior_);
        assertEq(_assertDonation(lp_, externalLp_ - prior_), externalLp_ - prior_, "preexisting LP is not counted twice");
    }
    function test_N4_donate_detf_selfLeg_noMint() public virtual {
        uint256 raw_ = _mintDetfFromBuffer(detf, donor, _fixtureAmount(10e18));
        assertGt(raw_, 0); _assertDonation(IERC20(detf), raw_ / 4);
    }
    function test_N5_inert_reverts() public virtual {
        address inert_ = _deployNamed("inert donation", "indn");
        address nft_ = IMixedBufferMultiVaultStableDetfInfo(inert_).bondNftVault();
        vm.startPrank(donor); buffer.approve(nft_, _fixtureAmount(1e18));
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(nft_).donate(buffer, _fixtureAmount(1e18), 0, false, _dl()); vm.stopPrank();
    }
    function test_N6_twoBonders_fundedClaimsUnchanged() public virtual {
        uint256 bobId_ = _laterBond(bob, _fixtureAmount(100e18));
        bytes memory before_ = abi.encode(_nft().positionOf(bobId_), _nft().previewClaim(bobId_));
        _assertDonation(buffer, _fixtureAmount(8e18));
        assertEq(abi.encode(_nft().positionOf(bobId_), _nft().previewClaim(bobId_)), before_);
        _assertRolePositions();
    }
    function test_N7_idetf_forwarder_donorIsCollector() public virtual {
        address collector_ = makeAddr("collector"); uint256 amt_ = _fixtureAmount(8e18);
        _fundBuffer(collector_, amt_);
        uint256 before_ = _lpHeld(); bytes memory funded_ = _fundedState();
        address nft_ = address(_nft());
        vm.prank(collector_); buffer.transfer(nft_, amt_);
        vm.expectEmit(true, true, false, false, address(_nft()));
        emit IDetfNftReserveDonation.ReserveDonated(collector_, address(buffer), amt_, 0);
        vm.prank(collector_); IDetf(detf).donate(buffer, amt_, true);
        assertGt(_lpHeld(), before_); assertEq(_fundedState(), funded_);
    }
    function test_N8_joinDonatedCapital_eoaReverts() public virtual {
        address attacker_ = makeAddr("dn8"); uint256 deadline_ = _dl();
        vm.prank(attacker_);
        vm.expectRevert(abi.encodeWithSelector(MixedBufferMultiVaultStableDetfRepo.NotAuthorized.selector, attacker_));
        detfBonding.joinDonatedCapital(buffer, _fixtureAmount(1e18), deadline_);
    }
    function test_N9_pretransferred_noSurplus_reverts() public virtual {
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        IERC20 lp_ = _nft().lpToken(); IDetfNftReserveDonation route_ = _donation(); uint256 deadline_ = _dl();
        uint256 before_ = _lpHeld(); bytes memory funded_ = _fundedState();
        vm.prank(donor); vm.expectRevert(); route_.donate(IERC20(address(junk_)), 10e18, 0, true, deadline_);
        vm.prank(donor); vm.expectRevert(); route_.donate(lp_, 1e18, 0, true, deadline_);
        assertEq(_lpHeld(), before_); assertEq(_fundedState(), funded_);
    }
    function test_N10_previewAndMinimumMatchExecute() public virtual {
        uint256 quote_ = _donation().previewDonate(buffer, _fixtureAmount(7e18));
        bytes memory before_ = _fundedState(); uint256 lpBefore_ = _lpHeld();
        IDetfNftReserveDonation route_ = _donation(); uint256 deadline_ = _dl();
        vm.prank(donor); vm.expectRevert(); route_.donate(buffer, _fixtureAmount(7e18), quote_ + 1, false, deadline_);
        assertEq(_lpHeld(), lpBefore_); assertEq(_fundedState(), before_);
        _assertDonation(buffer, _fixtureAmount(7e18));
    }
    function test_N11_publicJoinPreservesDonations() public virtual {
        _publicJoinShare(_fundVaultShares(0, donor, 10e18)); _assertDonation(buffer, _fixtureAmount(5e18));
    }
    function test_N12_donate_doesNotRealizeExpansion() public virtual {
        vm.warp(block.timestamp + 8 hours * 24); _assertDonation(buffer, _fixtureAmount(6e18));
    }
    function test_N13_burn_afterDonate_usesDonatedLp() public virtual {
        uint256 raw_ = _mintDetfFromBuffer(detf, donor, _fixtureAmount(10e18));
        _assertDonation(buffer, _fixtureAmount(8e18));
        assertTrue(detfInfo.isBurningAllowed());
        uint256 before_ = _lpHeld(); uint256 supply_ = IERC20(detf).totalSupply();
        assertGt(_burnDetfToBuffer(detf, donor, raw_ / 3), 0);
        assertLt(_lpHeld(), before_); assertEq(IERC20(detf).totalSupply(), supply_ - raw_ / 3);
    }
    function test_N15_donate_preservesClaimPreview() public virtual {
        bytes memory before_ = abi.encode(_nft().previewClaim(userBondId));
        _assertDonation(buffer, _fixtureAmount(8e18)); assertEq(abi.encode(_nft().previewClaim(userBondId)), before_);
    }
    function test_N16_finalClaims_thenDonate_nextBondOnlyReceivesPurchasedPrincipal() public virtual {
        uint256 bobId_ = _laterBond(bob, _fixtureAmount(100e18));
        _claimMature(userBondId, alice); _claimMature(bobId_, bob);
        uint256 before_ = _lpHeld(); assertGt(_donateMintToken(donor, _fixtureAmount(1e18)), 0);
        uint256 donated_ = _lpHeld(); assertGt(donated_, before_);
        (uint256 principal_,,) = detfBonding.previewBond(buffer, _fixtureAmount(80e18), DEFAULT_MIN_LOCK);
        uint256 carolId_ = _laterBond(makeAddr("carol donation"), _fixtureAmount(80e18));
        assertEq(_nft().positionOf(carolId_).principal, principal_);
        assertGt(_lpHeld(), donated_, "new bond adds LP; it cannot extract old protocol liquidity");
    }
    function test_N17_reservedRolesHaveStandingWeightsAndNoPrincipal() public virtual { _assertRolePositions(); }
    function test_N18_disabled_donateReverts_claimWorks() public virtual {
        uint256 bobId_ = _laterBond(bob, _fixtureAmount(100e18));
        vm.prank(owner); IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        IDetfNftReserveDonation route_ = _donation(); uint256 deadline_ = _dl();
        vm.prank(donor); vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf));
        route_.donate(buffer, _fixtureAmount(4e18), 0, false, deadline_);
        _claimMature(bobId_, bob);
    }
    function test_N19_permit2_allowance() public virtual {
        uint256 amt_ = _fixtureAmount(5e18); uint256 before_ = _lpHeld(); bytes memory funded_ = _fundedState();
        uint256 quote_ = _donation().previewDonate(buffer, amt_);
        vm.startPrank(donor); buffer.approve(address(donationPermit2), type(uint256).max);
        IAllowanceTransfer(address(donationPermit2)).approve(address(buffer), address(_nft()), uint160(amt_), type(uint48).max);
        uint256 out_ = _donation().donateWithPermit2Allowance(buffer, amt_, quote_, _dl()); vm.stopPrank();
        assertEq(out_, quote_); assertEq(_lpHeld(), before_ + out_); assertEq(_fundedState(), funded_);
    }
    function test_N20_permit2_signature() public virtual {
        uint256 amt_ = _fixtureAmount(4e18); uint256 deadline_ = _dl(); uint256 before_ = _lpHeld(); bytes memory funded_ = _fundedState();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(buffer), amount: amt_}), nonce: 0, deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(donorPk, address(buffer), amt_, address(_nft()), 0, deadline_);
        uint256 quote_ = _donation().previewDonate(buffer, amt_);
        vm.startPrank(donor); buffer.approve(address(donationPermit2), type(uint256).max);
        uint256 out_ = _donation().donateWithPermit2Signature(buffer, amt_, quote_, deadline_, abi.encode(permit_, sig_));
        vm.stopPrank(); assertEq(out_, quote_); assertEq(_lpHeld(), before_ + out_); assertEq(_fundedState(), funded_);
    }
    function test_N21_donateDoesNotTopUpStandingWeights() public virtual { _assertDonation(buffer, _fixtureAmount(8e18)); _assertRolePositions(); }

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
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", donationPermit2.DOMAIN_SEPARATOR(), structHash_));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(pk_, digest_);
        sig_ = abi.encodePacked(r_, s_, v_);
    }
}

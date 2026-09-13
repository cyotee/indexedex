// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

interface IFundedBondQuote {
    function acceptedBondTokens() external view returns (address[] memory);
    function previewBond(IERC20 token, uint256 amount, uint256 duration) external view returns (uint256, uint256, uint256);
}

interface IFundedBondWithPrepay {
    function bond(IERC20 token, uint256 amount, uint256 duration, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256, uint256);
}

interface IFundedBondWithoutPrepay {
    function bond(IERC20 token, uint256 amount, uint256 duration, address recipient, uint256 deadline)
        external returns (uint256, uint256);
}

/// @notice Final funded claims share the same custody rules across reserve families.
abstract contract FundedBondCloseAssertions is Test {
    address private constant CLAIM_RECIPIENT = address(0xCA11C105E);

    function _assertFinalFundedClaim(
        address detf_, IDetfBondNFT nft_, IStakedDETF staking_,
        uint256 id_, address buyer_, IERC20[] memory payments_
    ) internal {
        _assertFundedBondSurface(detf_, staking_);
        uint256 snapshot_ = vm.snapshotState();
        _assertFinalFundedClaimPath(detf_, nft_, staking_, id_, buyer_, payments_);
        assertTrue(vm.revertToState(snapshot_));

        // Reproduce the former reserve-LP shortfall scenario using actual custody transfers.
        // Funded principal and its held-DETF redemption must remain independent of that LP.
        IERC20 lp_ = nft_.lpToken();
        uint256 held_ = lp_.balanceOf(address(nft_));
        vm.prank(detf_); nft_.transferHeldToken(lp_, address(0x1A055), held_);
        held_ = lp_.balanceOf(detf_);
        if (held_ != 0) { vm.prank(detf_); assertTrue(lp_.transfer(address(0x1A055), held_)); }
        assertEq(lp_.balanceOf(address(nft_)) + lp_.balanceOf(detf_), 0);
        _assertFinalFundedClaimPath(detf_, nft_, staking_, id_, buyer_, payments_);
    }

    function _assertFundedBondSurface(address detf_, IStakedDETF staking_) private {
        string[10] memory retired_ = [
            "sellNFT(uint256,address)", "sellPositionToDetfNft(uint256,uint256,address)",
            "buyClaim(uint256,uint256,address,bool,uint256)", "previewBuyClaim(uint256)",
            "redeemClaim(uint256,address,uint256,address,uint256)", "previewRedeemClaim(uint256,address)",
            "claimLiquidity(uint256,address)", "protocolBondOriginalShares()",
            "closeBondMature(uint256,uint256[],address,uint256)", "previewCloseBondMature(uint256)"
        ];
        for (uint256 i_; i_ < retired_.length; ++i_) {
            assertEq(IDiamondLoupe(detf_).facetAddress(bytes4(keccak256(bytes(retired_[i_])))), address(0));
        }
        assertTrue(IDiamondLoupe(detf_).facetAddress(IStandardExchangeIn.exchangeIn.selector) != address(0));
        address[] memory payments_ = IFundedBondQuote(detf_).acceptedBondTokens();
        for (uint256 i_; i_ < payments_.length; ++i_) {
            assertTrue(payments_[i_] != detf_ && payments_[i_] != address(staking_));
        }
        vm.expectRevert(); IFundedBondQuote(detf_).previewBond(IERC20(detf_), 1, 30 days);
        vm.expectRevert(); IFundedBondQuote(detf_).previewBond(IERC20(address(staking_)), 1, 30 days);
        assertEq(IStandardExchangeIn(detf_).previewExchangeIn(IERC20(detf_), 1, IERC20(address(staking_))), 1);
    }

    function _assertFinalFundedClaimPath(
        address detf_, IDetfBondNFT nft_, IStakedDETF staking_,
        uint256 id_, address buyer_, IERC20[] memory payments_
    ) private {
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration);
        Math.BondClaim memory quote_ = nft_.previewClaim(id_);
        assertEq(quote_.principalDue, position_.principal - position_.claimedPrincipal);
        assertGt(quote_.principalDue, 0, "final claim has fully funded principal");
        bytes32 before_ = _closeCustodyState(detf_, nft_, staking_, payments_);
        uint256 receipts_ = staking_.balanceOf(CLAIM_RECIPIENT);
        vm.prank(buyer_);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, CLAIM_RECIPIENT);
        assertEq(principal_, quote_.principalDue, "principal preview equals paid sDETF");
        assertEq(rewards_, quote_.rewardsDue, "reward preview equals paid sDETF");
        assertEq(staking_.balanceOf(CLAIM_RECIPIENT) - receipts_, principal_ + rewards_);
        assertEq(_closeCustodyState(detf_, nft_, staking_, payments_), before_,
            "claim does not burn, withdraw reserve assets, or award standing recipients");
        assertEq(nft_.ownerOf(id_), address(0), "paid NFT has no owner");
        vm.expectRevert(); nft_.positionOf(id_);
        vm.expectRevert(); nft_.previewClaim(id_);
        vm.expectRevert(); vm.prank(buyer_); nft_.claimBond(id_, CLAIM_RECIPIENT);
        _assertClaimedStakeUnstakes(detf_, nft_, staking_, principal_ + rewards_, payments_[0]);
        _assertHostStakeRoundTrip(detf_, staking_, (principal_ + rewards_) / 2);
    }

    function _assertHostStakeRoundTrip(address detf_, IStakedDETF staking_, uint256 amount_) private {
        IERC20 raw_ = IERC20(detf_);
        IERC20 receipt_ = IERC20(address(staking_));
        uint256 backing_ = staking_.stakingState().accountedBacking;
        uint256 balance_ = raw_.balanceOf(CLAIM_RECIPIENT);
        uint256 supply_ = raw_.totalSupply();
        vm.startPrank(CLAIM_RECIPIENT);
        raw_.approve(detf_, amount_);
        _assertNotBondPayment(detf_, raw_, amount_);
        vm.expectRevert();
        IStandardExchangeIn(detf_).exchangeIn(raw_, amount_, IERC20(address(0xBAD)), 0,
            CLAIM_RECIPIENT, false, block.timestamp);
        assertEq(raw_.balanceOf(CLAIM_RECIPIENT), balance_, "unsupported destination cannot spend funded input");
        assertEq(staking_.stakingState().accountedBacking, backing_);
        assertEq(IStandardExchangeIn(detf_).exchangeIn(
            raw_, amount_, receipt_, amount_, CLAIM_RECIPIENT, false, block.timestamp
        ), amount_);
        assertEq(staking_.balanceOf(CLAIM_RECIPIENT), amount_);
        assertEq(staking_.stakingState().accountedBacking, backing_ + amount_);
        receipt_.approve(detf_, amount_);
        _assertNotBondPayment(detf_, receipt_, amount_);
        // The input is actually held and approved: rejection must be route validation.
        vm.expectRevert();
        IStandardExchangeIn(detf_).exchangeIn(receipt_, amount_, IERC20(address(0xBAD)), 0,
            CLAIM_RECIPIENT, false, block.timestamp);
        assertEq(staking_.balanceOf(CLAIM_RECIPIENT), amount_);
        assertEq(staking_.stakingState().accountedBacking, backing_ + amount_);
        assertEq(raw_.balanceOf(CLAIM_RECIPIENT), balance_ - amount_);
        assertEq(IStandardExchangeIn(detf_).exchangeIn(
            receipt_, amount_, raw_, amount_, CLAIM_RECIPIENT, false, block.timestamp
        ), amount_);
        vm.stopPrank();
        assertEq(staking_.gonsOf(CLAIM_RECIPIENT), 0);
        assertEq(raw_.balanceOf(CLAIM_RECIPIENT), balance_);
        assertEq(raw_.totalSupply(), supply_);
        assertEq(staking_.stakingState().accountedBacking, backing_);
        assertEq(raw_.balanceOf(address(staking_)), backing_);
    }

    /// @dev Called with the actual payment balance and allowance, so an empty wallet cannot mask acceptance.
    function _assertNotBondPayment(address detf_, IERC20 token_, uint256 amount_) private {
        assertGe(token_.balanceOf(CLAIM_RECIPIENT), amount_);
        if (IDiamondLoupe(detf_).facetAddress(IFundedBondWithPrepay.bond.selector) != address(0)) {
            vm.expectRevert();
            IFundedBondWithPrepay(detf_).bond(token_, amount_, 30 days, CLAIM_RECIPIENT, false, block.timestamp);
        } else {
            assertTrue(IDiamondLoupe(detf_).facetAddress(IFundedBondWithoutPrepay.bond.selector) != address(0));
            vm.expectRevert();
            IFundedBondWithoutPrepay(detf_).bond(token_, amount_, 30 days, CLAIM_RECIPIENT, block.timestamp);
        }
    }

    function _assertClaimedStakeUnstakes(
        address detf_, IDetfBondNFT nft_, IStakedDETF staking_, uint256 amount_, IERC20 payment_
    ) private {
        uint256 supply_ = IERC20(detf_).totalSupply();
        uint256 backing_ = staking_.stakingState().accountedBacking;
        uint256 raw_ = IERC20(detf_).balanceOf(CLAIM_RECIPIENT);
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 paymentBefore_ = payment_.balanceOf(CLAIM_RECIPIENT);
        IERC20 stakeToken_ = IERC20(address(staking_));
        assertEq(staking_.previewExchangeIn(stakeToken_, amount_, IERC20(detf_)), amount_);
        vm.expectRevert();
        staking_.previewExchangeIn(stakeToken_, amount_, payment_);
        vm.expectRevert(); vm.prank(CLAIM_RECIPIENT);
        staking_.exchangeIn(stakeToken_, amount_, IERC20(detf_), amount_ + 1,
            CLAIM_RECIPIENT, false, block.timestamp);
        assertEq(staking_.balanceOf(CLAIM_RECIPIENT), amount_, "failed minimum preserves principal");
        vm.prank(CLAIM_RECIPIENT);
        assertEq(staking_.exchangeIn(stakeToken_, amount_, IERC20(detf_), amount_,
            CLAIM_RECIPIENT, false, block.timestamp), amount_);
        assertEq(IERC20(detf_).balanceOf(CLAIM_RECIPIENT), raw_ + amount_);
        assertEq(staking_.gonsOf(CLAIM_RECIPIENT), 0, "full principal exit retires only this account");
        // A supported route with no remaining receipt cannot drain someone else's backing.
        vm.expectRevert(); vm.prank(CLAIM_RECIPIENT);
        staking_.exchangeIn(stakeToken_, 1, IERC20(detf_), 1, CLAIM_RECIPIENT, false, block.timestamp);
        assertEq(IERC20(detf_).balanceOf(CLAIM_RECIPIENT), raw_ + amount_);
        assertEq(staking_.gonsOf(CLAIM_RECIPIENT), 0);
        assertEq(staking_.stakingState().accountedBacking, backing_ - amount_);
        assertEq(IERC20(detf_).totalSupply(), supply_, "unstaking is a backing transfer");
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_, "unstaking never withdraws reserve LP");
        assertEq(payment_.balanceOf(CLAIM_RECIPIENT), paymentBefore_);
    }

    function _closeCustodyState(
        address detf_, IDetfBondNFT nft_, IStakedDETF staking_, IERC20[] memory payments_
    ) private view returns (bytes32) {
        uint256[] memory balances_ = new uint256[](payments_.length);
        for (uint256 i_; i_ < payments_.length; ++i_) balances_[i_] = payments_[i_].balanceOf(CLAIM_RECIPIENT);
        IERC20 lp_ = nft_.lpToken();
        return keccak256(abi.encode(
            IERC20(detf_).totalSupply(), IERC20(detf_).balanceOf(CLAIM_RECIPIENT),
            IERC20(detf_).balanceOf(address(staking_)), staking_.stakingState().accountedBacking,
            lp_.balanceOf(detf_), lp_.balanceOf(address(nft_)),
            staking_.balanceOf(nft_.ownerOf(1)), staking_.balanceOf(nft_.ownerOf(2)), balances_
        ));
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

/// @notice Shared funded-reward assertions for actual family purchase routes.
abstract contract FundedRewardAssertions is Test {
    struct FundingExpectation {
        IStakedDETF.StakingState state;
        address feeOwner;
        address creatorOwner;
        uint256 feeGons;
        uint256 creatorGons;
        uint256 escrowGons;
        uint256 principalGons;
    }

    function _exitStandingReceiptsAndChangeOracle(
        address detf_, IStakedDETF staking_, IDetfBondNFT nft_, address manager_, address managerOwner_
    ) internal {
        assertTrue(nft_.reservedBondNftsWired());
        address fee_ = nft_.ownerOf(1); address creator_ = nft_.ownerOf(2);
        assertEq(nft_.positionOf(1).principal, 0);
        assertEq(nft_.positionOf(2).principal, 0);
        assertEq(nft_.previewClaim(1).rewardsDue, 0, "standing role has no escrow reward claim");
        assertEq(nft_.previewClaim(2).principalDue, 0);
        IStakedDETF.StakingState memory before_ = staking_.stakingState();
        assertGt(before_.feeWeight, 0); assertGt(before_.creatorWeight, 0);
        uint256 escrow_ = staking_.gonsOf(address(nft_));
        uint256 lp_ = nft_.lpToken().balanceOf(address(nft_));
        uint256 supply_ = IERC20(detf_).totalSupply();
        _exitStandingAccount(detf_, staking_, fee_);
        if (creator_ != fee_) _exitStandingAccount(detf_, staking_, creator_);
        assertEq(staking_.stakingState().feeWeight, before_.feeWeight, "exit preserves fee rights");
        assertEq(staking_.stakingState().creatorWeight, before_.creatorWeight, "exit preserves creator rights");
        assertEq(staking_.gonsOf(address(nft_)), escrow_, "standing exit cannot consume bond escrow");
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lp_);
        assertEq(IERC20(detf_).totalSupply(), supply_);
        address replacement_ = address(0xFEEC011EC7);
        vm.prank(managerOwner_);
        IVaultFeeOracleManager(manager_).setFeeTo(IFeeCollectorProxy(replacement_));
        assertEq(nft_.ownerOf(1), fee_, "oracle feeTo change does not transfer existing role NFT");
        assertEq(nft_.ownerOf(2), creator_);
        assertEq(staking_.balanceOf(replacement_), 0);
    }

    function _exitStandingAccount(address detf_, IStakedDETF staking_, address recipient_) private {
        uint256 amount_ = staking_.balanceOf(recipient_);
        assertGt(amount_, 0, "purchase delivered immediately redeemable sDETF");
        uint256 backingBefore_ = IERC20(detf_).balanceOf(recipient_);
        vm.expectRevert();
        staking_.transferFrom(recipient_, address(0xBAD), amount_);
        vm.prank(recipient_);
        uint256 paid_ = staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(detf_), amount_,
            recipient_, false, block.timestamp);
        assertEq(paid_, amount_);
        assertEq(IERC20(detf_).balanceOf(recipient_) - backingBefore_, amount_);
        assertEq(staking_.balanceOf(recipient_), 0);
        assertEq(staking_.gonsOf(recipient_), 0);
        vm.expectRevert(); vm.prank(recipient_);
        staking_.exchangeIn(IERC20(address(staking_)), 1, IERC20(detf_), 1, recipient_, false, block.timestamp);
    }

    /// @dev Independent integer reference for principal funding followed by one immediate pot.
    ///      Test inputs are bounded real purchases; none of these products approach uint256.
    function _expectedBondFunding(
        address detf_, IStakedDETF staking_, IDetfBondNFT nft_, address oracle_, uint256 principal_, uint256 pot_
    ) internal view returns (FundingExpectation memory e_) {
        e_.state = staking_.stakingState();
        e_.feeOwner = nft_.ownerOf(1); e_.creatorOwner = nft_.ownerOf(2);
        e_.feeGons = staking_.gonsOf(e_.feeOwner); e_.creatorGons = staking_.gonsOf(e_.creatorOwner);
        e_.principalGons = principal_ * e_.state.gonsPerUnit;
        e_.escrowGons = staking_.gonsOf(address(nft_)) + e_.principalGons;
        e_.state.totalGons += e_.principalGons;
        e_.state.accountedBacking += principal_ + pot_;
        (, uint256 fee_, uint256 creator_) = IVaultFeeOracleQuery(oracle_).seigniorageSplitOfVault(detf_);
        _expectedWeightTopUp(e_.state, fee_, creator_);
        uint256 reward_ = pot_ + e_.state.allocationDust;
        uint256 rps_ = reward_ * 1e54 / (e_.state.totalGons + e_.state.feeWeight + e_.state.creatorWeight);
        uint256 ordinary_ = e_.state.totalGons * rps_ / 1e54;
        uint256 f_ = e_.state.feeWeight * rps_ / 1e54;
        uint256 c_ = e_.state.creatorWeight * rps_ / 1e54;
        e_.state.allocationDust = reward_ - ordinary_ - f_ - c_;
        uint256 target_ = e_.state.totalGons / e_.state.gonsPerUnit + ordinary_ + e_.state.stakingDust;
        e_.state.gonsPerUnit = (e_.state.totalGons + target_ - 1) / target_;
        e_.state.stakingDust = target_ - e_.state.totalGons / e_.state.gonsPerUnit;
        uint256 feeGons_ = f_ * e_.state.gonsPerUnit;
        uint256 creatorGons_ = c_ * e_.state.gonsPerUnit;
        e_.state.totalGons += feeGons_ + creatorGons_;
        e_.feeGons += feeGons_; e_.creatorGons += creatorGons_;
        if (e_.feeOwner == e_.creatorOwner) {
            e_.feeGons += creatorGons_; e_.creatorGons += feeGons_;
        }
        _expectedWeightTopUp(e_.state, fee_, creator_);
    }

    function _expectedWeightTopUp(IStakedDETF.StakingState memory s_, uint256 fee_, uint256 creator_) private pure {
        uint256 total_ = s_.totalGons * 1e18 / (1e18 - fee_ - creator_);
        uint256 feeTarget_ = total_ * fee_ / 1e18;
        uint256 creatorTarget_ = total_ * creator_ / 1e18;
        if (feeTarget_ > s_.feeWeight) s_.feeWeight = feeTarget_;
        if (creatorTarget_ > s_.creatorWeight) s_.creatorWeight = creatorTarget_;
    }

    function _assertBondFunding(
        address detf_, IStakedDETF staking_, IDetfBondNFT nft_, uint256 id_, FundingExpectation memory e_
    ) internal view {
        assertEq(abi.encode(staking_.stakingState()), abi.encode(e_.state), "independent funding/allocation/rebase floors");
        assertEq(nft_.positionOf(id_).stakingGons, e_.principalGons, "new bond participates in its immediate pot");
        assertEq(staking_.gonsOf(address(nft_)), e_.escrowGons);
        assertEq(staking_.gonsOf(e_.feeOwner), e_.feeGons, "fee receipts issued after the ordinary rebase");
        assertEq(staking_.gonsOf(e_.creatorOwner), e_.creatorGons);
        assertGt(staking_.balanceOf(e_.feeOwner), 0, "fee rights pay again after full unstaking");
        assertGt(staking_.balanceOf(e_.creatorOwner), 0, "creator rights pay again after full unstaking");
        assertEq(nft_.ownerOf(1), e_.feeOwner); assertEq(nft_.ownerOf(2), e_.creatorOwner);
        assertEq(IERC20(detf_).balanceOf(address(staking_)), e_.state.accountedBacking);
        assertEq(e_.state.accountedBacking, staking_.totalSupply() + e_.state.allocationDust + e_.state.stakingDust);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

interface IFundedBalancerEpochState {
    function epochAnchor() external view returns (uint256);
    function lastExpansionTimestamp() external view returns (uint256);
    function expansionClosureRatePerSecond() external view returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
    function synchronizeRewards() external returns (uint256);
    function reservePool() external view returns (address);
    function isMintingAllowed() external view returns (bool);
}

/// @notice One assertion corpus, exercised by all four real Balancer reserve hosts.
abstract contract FundedBalancerEpochAssertions is Test {
    struct EpochContext { address detf; IStakedDETF staking; IDetfBondNFT nft; uint256 price; uint256 anchor; }
    struct EpochSnapshot {
        uint256 supply;
        uint256 backing;
        uint256 actualBacking;
        uint256 escrowGons;
        uint256 index;
        uint256 ownedLp;
    }

    function _assertFundedEpochConfiguration(address detf_) internal view {
        assertEq(IFundedBalancerEpochState(detf_).expansionClosureRatePerSecond(), uint256(1e17) / 365 days);
        assertEq(IFundedBalancerEpochState(detf_).epochAnchor(), 0);
        bytes4[6] memory removed_ = [
            bytes4(keccak256("thresholdMode()")),
            bytes4(keccak256("expansionCatchUpMaxSeconds()")),
            bytes4(keccak256("expansionCatchUpCapBps()")),
            bytes4(keccak256("setExpansionClosureRatePerSecond(uint256)")),
            bytes4(keccak256("compoundProtocolRewards()")),
            bytes4(keccak256("compoundProtocolRewardsAtomic()"))
        ];
        for (uint256 i_; i_ < removed_.length; ++i_) assertEq(IDiamondLoupe(detf_).facetAddress(removed_[i_]), address(0));
    }

    function _donateEpochCapital(IDetfBondNFT nft_, IERC20 token_, uint256 amount_, address donor_) internal {
        IDetfNftReserveDonation gift_ = IDetfNftReserveDonation(address(nft_));
        uint256 quote_ = gift_.previewDonate(token_, amount_);
        vm.startPrank(donor_);
        token_.approve(address(nft_), amount_);
        assertEq(gift_.donate(token_, amount_, quote_, false, block.timestamp), quote_);
        vm.stopPrank();
    }

    function _assertFundedBalancerEpochs(address detf_, IStakedDETF stake_, IDetfBondNFT nft_, uint256 price_) internal {
        IFundedBalancerEpochState epoch_ = IFundedBalancerEpochState(detf_);
        assertTrue(epoch_.isMintingAllowed(), "real funded reserve is above the mint gate");
        assertGt(price_, 1e18);
        uint256 anchor_ = epoch_.epochAnchor();
        uint256[3] memory elapsed_ = [uint256(8 hours - 1), uint256(25 hours), uint256(7 days + 1 hours)];
        for (uint256 i_; i_ < elapsed_.length; ++i_) {
            uint256 snap_ = vm.snapshotState();
            vm.warp(anchor_ + elapsed_[i_]);
            _assertOneFundedEpoch(EpochContext(detf_, stake_, nft_, price_, anchor_), elapsed_[i_]);
            assertTrue(vm.revertToState(snap_));
        }
    }

    function _assertOneFundedEpoch(EpochContext memory c_, uint256 elapsed_) private {
        IFundedBalancerEpochState epoch_ = IFundedBalancerEpochState(c_.detf);
        IERC20 raw_ = IERC20(c_.detf); IERC20 lp_ = IERC20(epoch_.reservePool());
        EpochSnapshot memory s_;
        s_.supply = raw_.totalSupply(); s_.backing = c_.staking.stakingState().accountedBacking;
        s_.actualBacking = raw_.balanceOf(address(c_.staking));
        s_.escrowGons = c_.staking.gonsOf(address(c_.nft)); s_.index = c_.staking.stakingState().gonsPerUnit;
        s_.ownedLp = lp_.balanceOf(c_.detf) + lp_.balanceOf(address(c_.nft));
        uint256 completed_ = elapsed_ / 8 hours * 8 hours;
        // Independent integer reference: preserve the family's two floors before elapsed time.
        uint256 expected_ = (s_.supply * (c_.price - 1e18) / c_.price) * epoch_.expansionClosureRatePerSecond() / 1e18 * completed_;
        if (expected_ <= 1) expected_ = 0;
        assertEq(epoch_.pendingExpansionDetf(), expected_);
        if (elapsed_ > 7 days) assertGt(expected_, s_.supply * 50 / 10_000, "former supply brake cannot bind");
        if (expected_ != 0) {
            uint256 snapshot_ = vm.snapshotState();
            _assertEpochOnUnstake(c_, s_, expected_);
            assertTrue(vm.revertToState(snapshot_));
        }
        vm.recordLogs(); assertEq(epoch_.synchronizeRewards(), expected_);
        _assertSingleExpansionMint(vm.getRecordedLogs(), c_.detf, expected_);
        assertEq(raw_.totalSupply(), s_.supply + expected_);
        assertEq(c_.staking.stakingState().accountedBacking, s_.backing + expected_);
        assertEq(raw_.balanceOf(address(c_.staking)), s_.actualBacking + expected_);
        assertEq(c_.staking.gonsOf(address(c_.nft)), s_.escrowGons, "ordinary stake rebases without receiving new gons");
        if (expected_ != 0) assertLt(c_.staking.stakingState().gonsPerUnit, s_.index);
        else assertEq(c_.staking.stakingState().gonsPerUnit, s_.index);
        assertEq(lp_.balanceOf(c_.detf) + lp_.balanceOf(address(c_.nft)), s_.ownedLp);
        assertEq(epoch_.lastExpansionTimestamp(), c_.anchor + completed_);
        assertEq(epoch_.pendingExpansionDetf(), 0); assertEq(epoch_.synchronizeRewards(), 0);
        if (expected_ != 0) _assertBothBondRewards(c_, s_.index);
    }

    function _assertEpochOnUnstake(EpochContext memory c_, EpochSnapshot memory s_, uint256 expected_) private {
        address recipient_ = c_.nft.ownerOf(1);
        assertGt(c_.staking.balanceOf(recipient_), 0);
        uint256 rawBefore_ = IERC20(c_.detf).balanceOf(recipient_);
        vm.recordLogs(); vm.prank(recipient_);
        assertEq(c_.staking.exchangeIn(IERC20(address(c_.staking)), 1, IERC20(c_.detf), 1,
            recipient_, false, block.timestamp), 1);
        _assertSingleExpansionMint(vm.getRecordedLogs(), c_.detf, expected_);
        assertEq(IERC20(c_.detf).totalSupply(), s_.supply + expected_);
        assertEq(c_.staking.stakingState().accountedBacking, s_.backing + expected_ - 1);
        assertEq(IERC20(c_.detf).balanceOf(address(c_.staking)), s_.actualBacking + expected_ - 1);
        assertEq(IERC20(c_.detf).balanceOf(recipient_), rawBefore_ + 1);
        assertLt(c_.staking.stakingState().gonsPerUnit, s_.index, "due funded rebase precedes unstaking");
        IERC20 lp_ = c_.nft.lpToken();
        assertEq(lp_.balanceOf(c_.detf) + lp_.balanceOf(address(c_.nft)), s_.ownedLp);
        assertEq(IFundedBalancerEpochState(c_.detf).pendingExpansionDetf(), 0);
    }

    function _assertBothBondRewards(EpochContext memory c_, uint256 oldIndex_) private {
        uint256 index_ = c_.staking.stakingState().gonsPerUnit;
        for (uint256 id_ = 3; id_ <= 4; ++id_) {
            Math.BondPosition memory position_ = c_.nft.positionOf(id_);
            assertLt(block.timestamp, position_.startTimestamp + position_.vestingDuration, "claim while vesting");
            uint256 remaining_ = position_.principal - position_.claimedPrincipal;
            uint256 expected_ = position_.stakingGons / index_ - remaining_;
            uint256 prior_ = position_.stakingGons / oldIndex_ - remaining_;
            assertGt(expected_, prior_, "each real bond earns its own proportional funded growth");
            assertEq(c_.nft.previewClaim(id_).rewardsDue, expected_);
            address recipient_ = address(uint160(0xC1A100 + id_));
            address buyer_ = c_.nft.ownerOf(id_);
            vm.prank(buyer_); assertEq(c_.nft.claimRewards(id_, recipient_), expected_);
            assertEq(c_.staking.balanceOf(recipient_), expected_);
            assertEq(IERC20(c_.detf).balanceOf(recipient_), 0, "bond rewards pay only sDETF");
            Math.BondPosition memory after_ = c_.nft.positionOf(id_);
            assertEq(after_.principal, position_.principal);
            assertEq(after_.claimedPrincipal, position_.claimedPrincipal);
            assertEq(after_.stakingGons, position_.stakingGons - expected_ * index_);
            assertEq(c_.nft.previewClaim(id_).rewardsDue, 0);
            vm.prank(buyer_); assertEq(c_.nft.claimRewards(id_, recipient_), 0);
        }
    }

    function _assertSingleExpansionMint(Vm.Log[] memory logs_, address detf_, uint256 expected_) private pure {
        uint256 count_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != detf_ || logs_[i_].topics.length != 3
                || logs_[i_].topics[0] != keccak256("Transfer(address,address,uint256)") || logs_[i_].topics[1] != bytes32(0)) continue;
            ++count_; assertEq(abi.decode(logs_[i_].data, (uint256)), expected_);
        }
        assertEq(count_, expected_ == 0 ? 0 : 1, "one aggregate raw DETF mint, including seigniorage");
    }
}

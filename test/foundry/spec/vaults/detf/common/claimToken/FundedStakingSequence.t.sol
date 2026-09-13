// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Funded accounting sequences against the actual DETF, staking and NFT proxies.
/// @dev Actors obtain DETF only through paid bonds. No direct storage writes or mocked issuance.
contract FundedStakingSequenceTest is TestBase_UniswapV4Detf {
    IStakedDETF private staking_;
    IDetfBondNFT private bonds_;
    address[3] private actors_;
    uint256 private unsolicited_;

    function setUp() public override {
        super.setUp();
        staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        bonds_ = IDetfBondNFT(detfInfo.bondNftVault());
        actors_ = [detfUser, makeAddr("funded actor 1"), makeAddr("funded actor 2")];
        (uint256 id_,) = _firstBond(1_000 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        vm.startPrank(detfUser);
        (uint256 principal_, uint256 reward_) = bonds_.claimBond(id_, detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), principal_ + reward_, IERC20(detf), 0, detfUser, false, block.timestamp);
        uint256 each_ = IERC20(detf).balanceOf(detfUser) / 3;
        IERC20(detf).transfer(actors_[1], each_);
        IERC20(detf).transfer(actors_[2], each_);
        vm.stopPrank();
        for (uint256 i_; i_ < actors_.length; ++i_) {
            vm.prank(actors_[i_]);
            IERC20(detf).approve(address(staking_), type(uint256).max);
        }
    }

    function _assertFundedLedger() private view {
        IStakedDETF.StakingState memory state_ = staking_.stakingState();
        uint256 liability_ = staking_.totalSupply();
        assertEq(liability_, state_.totalGons / state_.gonsPerUnit);
        assertEq(state_.accountedBacking, liability_ + state_.allocationDust + state_.stakingDust);
        assertEq(IERC20(detf).balanceOf(address(staking_)), state_.accountedBacking + unsolicited_);
        uint256 gons_ = staking_.gonsOf(address(bonds_));
        address fee_ = bonds_.ownerOf(1);
        address creator_ = bonds_.ownerOf(2);
        gons_ += staking_.gonsOf(fee_);
        if (creator_ != fee_) gons_ += staking_.gonsOf(creator_);
        for (uint256 i_; i_ < actors_.length; ++i_) {
            assertTrue(actors_[i_] != fee_ && actors_[i_] != creator_);
            gons_ += staking_.gonsOf(actors_[i_]);
        }
        assertEq(gons_, state_.totalGons, "all gons have an actual owner");
    }

    function testFuzz_paidRewardsAndStakeChangesKeepEveryUnitFunded(uint256 seed_) public {
        uint256 previousK_ = staking_.stakingState().gonsPerUnit;
        for (uint256 step_; step_ < 24; ++step_) {
            seed_ = uint256(keccak256(abi.encode(seed_, step_)));
            uint256 op_ = seed_ % 5;
            address actor_ = actors_[(seed_ >> 8) % actors_.length];
            if (op_ == 0) _stakeSome(actor_, seed_ >> 16);
            else if (op_ == 1) _unstakeSome(actor_, seed_ >> 16);
            else if (op_ == 2) _transferSome(actor_, seed_ >> 16);
            else if (op_ == 3) _purchaseReward();
            else _donateUnsolicited(actor_, seed_ >> 16);
            uint256 k_ = staking_.stakingState().gonsPerUnit;
            assertLe(k_, previousK_, "funded rebase never lowers balances");
            assertGt(k_, 0);
            previousK_ = k_;
            _assertFundedLedger();
        }
    }

    function _stakeSome(address actor_, uint256 seed_) private {
        uint256 balance_ = IERC20(detf).balanceOf(actor_);
        if (balance_ == 0) return;
        uint256 amount_ = 1 + seed_ % balance_;
        uint256 before_ = staking_.balanceOf(actor_);
        vm.prank(actor_);
        staking_.exchangeOut(IERC20(detf), balance_, IERC20(address(staking_)), amount_, actor_, false, block.timestamp);
        assertEq(staking_.balanceOf(actor_), before_ + amount_);
        assertEq(IERC20(detf).balanceOf(actor_), balance_ - amount_);
    }

    function _unstakeSome(address actor_, uint256 seed_) private {
        uint256 balance_ = staking_.balanceOf(actor_);
        if (balance_ == 0) return;
        uint256 amount_ = seed_ % 3 == 0 ? balance_ : 1 + seed_ % balance_;
        uint256 raw_ = IERC20(detf).balanceOf(actor_);
        uint256 lp_ = IERC20(reserveHook).balanceOf(address(bonds_));
        vm.prank(actor_);
        staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(detf), amount_, actor_, false, block.timestamp);
        assertEq(staking_.balanceOf(actor_), balance_ - amount_);
        assertEq(IERC20(detf).balanceOf(actor_), raw_ + amount_);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds_)), lp_);
        if (amount_ == balance_) assertEq(staking_.gonsOf(actor_), 0, "full unstake retires own fraction");
    }

    function _transferSome(address from_, uint256 seed_) private {
        uint256 balance_ = staking_.balanceOf(from_);
        if (balance_ == 0) return;
        address to_ = actors_[seed_ % actors_.length];
        uint256 amount_ = 1 + seed_ % balance_;
        uint256 before_ = staking_.balanceOf(to_);
        uint256 supply_ = staking_.totalSupply();
        vm.prank(from_);
        staking_.transfer(to_, amount_);
        assertEq(staking_.totalSupply(), supply_);
        if (to_ != from_) {
            assertEq(staking_.balanceOf(from_), balance_ - amount_);
            assertEq(staking_.balanceOf(to_), before_ + amount_);
        } else assertEq(staking_.balanceOf(from_), balance_);
    }

    function _purchaseReward() private {
        uint256[3] memory before_;
        for (uint256 i_; i_ < actors_.length; ++i_) before_[i_] = staking_.balanceOf(actors_[i_]);
        _firstBond(1 ether);
        for (uint256 i_; i_ < actors_.length; ++i_) assertGe(staking_.balanceOf(actors_[i_]), before_[i_]);
    }

    function _donateUnsolicited(address actor_, uint256 seed_) private {
        uint256 balance_ = IERC20(detf).balanceOf(actor_);
        if (balance_ == 0) return;
        uint256 amount_ = 1 + seed_ % balance_;
        IStakedDETF.StakingState memory before_ = staking_.stakingState();
        vm.prank(actor_);
        IERC20(detf).transfer(address(staking_), amount_);
        unsolicited_ += amount_;
        assertEq(abi.encode(staking_.stakingState()), abi.encode(before_), "idle backing is not reward or public mint credit");
    }

    function test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction() public {
        (uint256 a_,) = _firstBond(17 ether);
        (uint256 b_,) = _firstBond(23 ether);
        Math.BondPosition memory bBefore_ = bonds_.positionOf(b_);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(detfUser);
        bonds_.claimBond(a_, detfUser);
        assertEq(bonds_.positionOf(b_).stakingGons, bBefore_.stakingGons);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK / 2);
        vm.prank(detfUser);
        bonds_.claimBond(a_, detfUser);
        assertEq(bonds_.ownerOf(a_), address(0));
        assertEq(bonds_.positionOf(b_).stakingGons, bBefore_.stakingGons);
        vm.prank(detfUser);
        bonds_.claimBond(b_, detfUser);
        assertEq(bonds_.ownerOf(b_), address(0));
        assertEq(staking_.gonsOf(address(bonds_)), 0);
        _assertFundedLedger();
    }
}

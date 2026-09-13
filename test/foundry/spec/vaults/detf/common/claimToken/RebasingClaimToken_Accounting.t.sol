// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Funded replacements for the old spot/LP-valued claim accounting regressions.
/// @dev Transactions use registered DETF/staking/NFT proxies; no storage overrides or SUT mocks.
contract RebasingClaimToken_Accounting is TestBase_UniswapV4Detf {
    function _staking() private view returns (IStakedDETF) {
        return IStakedDETF(detfInfo.rebasingClaimToken());
    }

    function _walletStake() private returns (IStakedDETF staking_) {
        (uint256 id_,) = _firstBond(1_000 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        IDetfBondNFT bonds_ = IDetfBondNFT(detfInfo.bondNftVault());
        vm.prank(detfUser);
        bonds_.claimBond(id_, detfUser);
        staking_ = _staking();
        assertGt(staking_.balanceOf(detfUser), 0);
    }

    function _assertZeroTransfers(IStakedDETF staking_) private {
        address receiver_ = makeAddr("zero-transfer receiver");
        address spender_ = makeAddr("zero-transfer spender");
        IStakedDETF.StakingState memory before_ = staking_.stakingState();
        uint256 gons_ = staking_.gonsOf(detfUser);
        vm.expectEmit(true, true, false, true, address(staking_));
        emit IERC20Events.Transfer(detfUser, receiver_, 0);
        vm.prank(detfUser);
        assertTrue(staking_.transfer(receiver_, 0));
        vm.expectEmit(true, true, false, true, address(staking_));
        emit IERC20Events.Transfer(detfUser, receiver_, 0);
        vm.prank(spender_);
        assertTrue(staking_.transferFrom(detfUser, receiver_, 0));
        assertEq(staking_.gonsOf(detfUser), gons_);
        assertEq(staking_.gonsOf(receiver_), 0);
        assertEq(staking_.allowance(detfUser, spender_), 0);
        assertEq(abi.encode(staking_.stakingState()), abi.encode(before_));
    }

    function test_zeroTransfersEmitWithoutAllowanceBeforeAndAfterFunding() public {
        _assertZeroTransfers(_staking());
        _assertZeroTransfers(_walletStake());
    }

    function test_sameBlockFundedRewardsUpdateGonsButUnsolicitedBackingDoesNot() public {
        IStakedDETF staking_ = _walletStake();
        vm.startPrank(detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), 1, IERC20(detf), 1, detfUser, false, block.timestamp);
        IStakedDETF.StakingState memory before_ = staking_.stakingState();
        uint256 balance_ = staking_.balanceOf(detfUser);
        uint256 gons_ = staking_.gonsOf(detfUser);
        IERC20(detf).transfer(address(staking_), 1);
        vm.stopPrank();
        assertEq(staking_.balanceOf(detfUser), balance_);
        assertEq(abi.encode(staking_.stakingState()), abi.encode(before_));
        assertEq(IERC20(detf).balanceOf(address(staking_)), before_.accountedBacking + 1);
        uint256 block_ = block.number;
        _firstBond(40 ether);
        assertEq(block.number, block_);
        assertLt(staking_.stakingState().gonsPerUnit, before_.gonsPerUnit);
        assertGt(staking_.balanceOf(detfUser), balance_);
        assertEq(staking_.gonsOf(detfUser), gons_, "existing holder earns through K, not new ownership issuance");
        assertEq(IERC20(detf).balanceOf(address(staking_)), staking_.stakingState().accountedBacking + 1);
    }

    function test_reserveTradingCannotReduceFundedPrincipalAndFullExitRetiresOnlyOwnFraction() public {
        IStakedDETF staking_ = _walletStake();
        uint256 k_ = staking_.stakingState().gonsPerUnit;
        uint256 balance_ = staking_.balanceOf(detfUser);
        uint256 ownLp_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        uint256 lpSupply_ = IERC20(reserveHook).totalSupply();
        vm.startPrank(detfUser);
        pairToken.approve(reserveHook, 50 ether);
        IStandardExchangeIn(reserveHook).exchangeIn(pairToken, 50 ether, IERC20(detf), 1, detfUser, false, block.timestamp);
        vm.stopPrank();
        assertEq(staking_.stakingState().gonsPerUnit, k_);
        assertEq(staking_.balanceOf(detfUser), balance_);
        uint256 before_ = IERC20(detf).balanceOf(detfUser);
        uint256 otherGons_ = staking_.stakingState().totalGons - staking_.gonsOf(detfUser);
        address recipient_ = makeAddr("overdraw recipient");
        vm.startPrank(detfUser);
        vm.expectRevert();
        staking_.transfer(recipient_, balance_ + 1);
        vm.expectRevert(StakedDETFTarget.ZeroAmount.selector);
        staking_.exchangeIn(IERC20(address(staking_)), 0, IERC20(detf), 0, detfUser, false, block.timestamp);
        assertEq(staking_.balanceOf(detfUser), balance_);
        assertEq(staking_.exchangeIn(IERC20(address(staking_)), balance_, IERC20(detf), balance_, detfUser, false, block.timestamp), balance_);
        vm.stopPrank();
        assertEq(IERC20(detf).balanceOf(detfUser), before_ + balance_);
        assertEq(staking_.gonsOf(detfUser), 0, "full native exit retires that holder's own remainder");
        assertEq(staking_.stakingState().totalGons, otherGons_);
        assertEq(staking_.stakingState().gonsPerUnit, k_, "full exit never resets the index");
        assertEq(staking_.gonsOf(recipient_), 0);
        assertEq(IERC20(reserveHook).totalSupply(), lpSupply_);
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), ownLp_);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(staking_), 1);
        assertEq(staking_.exchangeIn(IERC20(detf), 1, IERC20(address(staking_)), 1, detfUser, false, block.timestamp), 1);
        assertEq(staking_.exchangeOut(IERC20(address(staking_)), 1, IERC20(detf), 1, detfUser, false, block.timestamp), 1);
        vm.stopPrank();
        assertEq(staking_.gonsOf(detfUser), 0);
        assertEq(staking_.stakingState().gonsPerUnit, k_);
    }
}

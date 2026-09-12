// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

interface IFundedPrimaryGate {
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
}

/// @notice Real reserve joins and raw issuance, distinct from the supply-neutral swap branch.
abstract contract FundedPrimaryRouteAssertions is Test {
    struct PrimaryContext {
        address detf;
        IStakedDETF staking;
        IDetfBondNFT nft;
        IVault vault;
        IERC20 payment;
        uint256 amount;
        address payer;
    }
    struct PrimarySnapshot {
        uint256 supply;
        uint256 backing;
        uint256 lp;
        uint256 poolDetf;
        uint256 payment;
        uint256 userDetf;
        uint256 escrowGons;
        uint256 feeGons;
        uint256 creatorGons;
        uint256 index;
    }

    function _primarySnapshot(PrimaryContext memory c_) private view returns (PrimarySnapshot memory s_) {
        s_.supply = IERC20(c_.detf).totalSupply();
        s_.backing = c_.staking.stakingState().accountedBacking;
        IERC20 lp_ = c_.nft.lpToken();
        s_.lp = lp_.balanceOf(c_.detf) + lp_.balanceOf(address(c_.nft));
        (IERC20[] memory tokens_,, uint256[] memory balances_,) = c_.vault.getPoolTokenInfo(address(lp_));
        for (uint256 i_; i_ < tokens_.length; ++i_) if (address(tokens_[i_]) == c_.detf) s_.poolDetf = balances_[i_];
        s_.payment = c_.payment.balanceOf(c_.payer);
        s_.userDetf = IERC20(c_.detf).balanceOf(c_.payer);
        s_.escrowGons = c_.staking.gonsOf(address(c_.nft));
        s_.feeGons = c_.staking.gonsOf(c_.nft.ownerOf(1));
        s_.creatorGons = c_.staking.gonsOf(c_.nft.ownerOf(2));
        s_.index = c_.staking.stakingState().gonsPerUnit;
    }

    function _assertPrimaryMint(PrimaryContext memory c_) internal {
        assertTrue(IFundedPrimaryGate(c_.detf).isMintingAllowed(), "actual reserve capital opens primary mint");
        IStandardExchangeIn exchange_ = IStandardExchangeIn(c_.detf);
        uint256 quote_ = exchange_.previewExchangeIn(c_.payment, c_.amount, IERC20(c_.detf));
        assertGt(quote_, 0);
        PrimarySnapshot memory before_ = _primarySnapshot(c_);
        vm.startPrank(c_.payer); c_.payment.approve(c_.detf, c_.amount);
        vm.expectRevert();
        exchange_.exchangeIn(c_.payment, c_.amount, IERC20(c_.detf), quote_ + 1, c_.payer, false, block.timestamp);
        vm.stopPrank();
        assertEq(abi.encode(_primarySnapshot(c_)), abi.encode(before_), "failed mint minimum rolls back every custody change");
        vm.prank(c_.payer);
        assertEq(exchange_.exchangeIn(c_.payment, c_.amount, IERC20(c_.detf), quote_, c_.payer, false, block.timestamp), quote_);
        PrimarySnapshot memory after_ = _primarySnapshot(c_);
        assertEq(after_.payment, before_.payment - c_.amount);
        assertEq(after_.userDetf, before_.userDetf + quote_);
        assertGt(after_.supply, before_.supply + quote_, "primary issuance includes a separately funded reward pot");
        assertEq(after_.backing - before_.backing, after_.supply - before_.supply - quote_);
        assertEq(IERC20(c_.detf).balanceOf(address(c_.staking)), after_.backing);
        assertGt(after_.lp, before_.lp, "actual payment joins protocol-owned liquidity");
        assertEq(after_.poolDetf, before_.poolDetf, "ordinary mint does not add a second DETF liquidity leg");
        assertEq(after_.escrowGons, before_.escrowGons, "existing bond escrow rebases without issuing principal");
        assertLt(after_.index, before_.index);
        assertGt(after_.feeGons, before_.feeGons);
        assertGt(after_.creatorGons, before_.creatorGons);
    }

    function _claimedBurnPrincipal(address detf_, IStakedDETF staking_, IDetfBondNFT nft_, uint256 id_, address buyer_)
        internal returns (uint256 amount_)
    {
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration / 2);
        vm.prank(buyer_); amount_ = nft_.claimPrincipal(id_, buyer_);
        assertGt(amount_, 0);
        vm.prank(buyer_);
        assertEq(staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(detf_), amount_,
            buyer_, false, block.timestamp), amount_);
    }

    function _externalReserveJoin(PrimaryContext memory c_, address router_, address permit2_, address outsider_, uint256 payment_) internal {
        IERC20 lp_ = c_.nft.lpToken();
        (IERC20[] memory tokens_,,,) = c_.vault.getPoolTokenInfo(address(lp_));
        uint256[] memory amounts_ = new uint256[](tokens_.length);
        for (uint256 i_; i_ < tokens_.length; ++i_) if (address(tokens_[i_]) == address(c_.payment)) amounts_[i_] = payment_;
        uint256 lpBefore_ = lp_.balanceOf(outsider_);
        vm.startPrank(outsider_);
        c_.payment.approve(permit2_, payment_);
        IPermit2(permit2_).approve(address(c_.payment), router_, uint160(payment_), type(uint48).max);
        uint256 received_ = IRouter(router_).addLiquidityUnbalanced(
            address(lp_), amounts_, 0, false, ""
        );
        vm.stopPrank();
        assertGt(received_, 0);
        assertEq(lp_.balanceOf(outsider_), lpBefore_ + received_, "outsider acquired actual reserve LP");
    }

    function _assertOwnedLpBurn(PrimaryContext memory c_, address router_, address permit2_, address outsider_, uint256 externalPayment_) internal {
        _externalReserveJoin(c_, router_, permit2_, outsider_, externalPayment_);
        assertTrue(IFundedPrimaryGate(c_.detf).isBurningAllowed());
        PrimarySnapshot memory before_ = _primarySnapshot(c_);
        IERC20 lp_ = c_.nft.lpToken();
        uint256 externalLp_ = lp_.balanceOf(outsider_);
        assertGt(externalLp_, 0);
        assertGt(lp_.totalSupply(), before_.lp, "total reserve LP includes external property");
        uint256 expectedLp_ = c_.amount * before_.lp / before_.supply;
        assertGt(expectedLp_, 0);
        uint256 quote_ = IStandardExchangeIn(c_.detf).previewExchangeIn(IERC20(c_.detf), c_.amount, c_.payment);
        assertGt(quote_, 0);
        uint256 paid_ = _executePrimaryBurn(c_, quote_);
        _assertReserveLpBurn(vm.getRecordedLogs(), address(lp_), expectedLp_);
        assertEq(paid_, quote_);
        assertEq(c_.payment.balanceOf(c_.payer), before_.payment + paid_);
        assertEq(IERC20(c_.detf).totalSupply(), before_.supply - c_.amount);
        assertEq(IERC20(c_.detf).balanceOf(c_.payer), before_.userDetf - c_.amount);
        assertEq(lp_.balanceOf(outsider_), externalLp_, "primary redemption cannot spend external LP");
        assertEq(c_.staking.stakingState().accountedBacking, before_.backing);
        assertEq(c_.staking.gonsOf(address(c_.nft)), before_.escrowGons);
    }

    function _executePrimaryBurn(PrimaryContext memory c_, uint256 quote_) private returns (uint256 paid_) {
        vm.startPrank(c_.payer); IERC20(c_.detf).approve(c_.detf, c_.amount);
        vm.recordLogs();
        paid_ = IStandardExchangeIn(c_.detf).exchangeIn(
            IERC20(c_.detf), c_.amount, c_.payment, quote_, c_.payer, false, block.timestamp
        );
        vm.stopPrank();
    }

    function _assertReserveLpBurn(Vm.Log[] memory logs_, address lp_, uint256 expected_) private pure {
        uint256 burned_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == lp_ && logs_[i_].topics.length == 3
                && logs_[i_].topics[0] == keccak256("Transfer(address,address,uint256)")
                && logs_[i_].topics[2] == bytes32(0)) burned_ += abi.decode(logs_[i_].data, (uint256));
        }
        assertEq(burned_, expected_, "LP exit uses actual protocol ownership over complete outstanding DETF supply");
    }
}

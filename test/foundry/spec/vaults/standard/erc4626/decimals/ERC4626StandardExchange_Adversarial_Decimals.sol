// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_ERC4626StandardExchange_Decimals} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange_Decimals.sol";

/**
 * @title ERC4626StandardExchange_Adversarial_Decimals
 * @notice I1–I3 only (J and FoT N/A). Combo recorded by the concrete suite name.
 */
abstract contract ERC4626StandardExchange_Adversarial_Decimals is
    TestBase_ERC4626StandardExchange_Decimals
{
    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function test_I1_pretransferred_noTransfer_bookedReserve_reverts() public {
        _seedLiquidity(_u(50));
        uint256 claimed_ = _u(1);
        uint256 invBefore_ = IERC20(address(protocolVault)).balanceOf(se);
        assertGe(invBefore_, claimed_, "booked protocolVault inventory");
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 attackerSeBefore_ = IERC20(se).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)), claimed_, IERC20(se), 0, attacker, true, _deadline()
        );
        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1: no free SE mint");
        assertEq(IERC20(se).balanceOf(attacker), attackerSeBefore_, "I1: attacker SE unchanged");
        assertEq(IERC20(address(protocolVault)).balanceOf(se), invBefore_, "I1: inventory unmoved");
    }

    function test_I1_wrapUnderlying_pretransferred_noTransfer_bookedReserve_reverts() public {
        _seedLiquidity(_u(50));
        uint256 claimed_ = _u(1);
        assertEq(underlying.balanceOf(se), 0, "wrap deposits leftover cash");
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        seIn.exchangeIn(IERC20(address(underlying)), claimed_, IERC20(se), 0, attacker, true, _deadline());
        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1 wrap: no free mint");
        assertEq(underlying.balanceOf(se), 0, "I1 wrap: no underlying pulled");
    }

    function test_I1_exchangeOut_pretransferred_noTransfer_bookedReserve_reverts() public {
        _seedLiquidity(_u(50));
        uint256 seDesired_ = _u(1);
        uint256 maxIn_ = _u(10);
        uint256 claimedIn_ =
            seOut.previewExchangeOut(IERC20(address(protocolVault)), IERC20(se), seDesired_);
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 invBefore_ = IERC20(address(protocolVault)).balanceOf(se);
        assertGe(invBefore_, claimedIn_, "booked inventory");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimedIn_, uint256(0))
        );
        seOut.exchangeOut(
            IERC20(address(protocolVault)), maxIn_, IERC20(se), seDesired_, attacker, true, _deadline()
        );
        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1 out: no free mint");
        assertEq(IERC20(address(protocolVault)).balanceOf(se), invBefore_, "I1 out: inventory unmoved");
    }

    function test_I2_pretransferred_claimedGtU_revertsExactArgs() public {
        _seedLiquidity(_u(50));
        uint256 booked_ = IERC20(address(protocolVault)).balanceOf(se);
        uint256 short_ = _u(1);
        uint256 claimed_ = _u(5);
        vm.startPrank(user);
        protocolVault.deposit(_u(20), user);
        protocolVault.transfer(se, short_);
        vm.stopPrank();
        uint256 U_ = IERC20(address(protocolVault)).balanceOf(se) - booked_;
        assertEq(U_, short_, "unbooked surplus == short transfer");
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, short_)
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)), claimed_, IERC20(se), 0, attacker, true, _deadline()
        );
        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I2: no short-credit mint");
    }

    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        uint256 residualSeed_ = _u(10);
        uint256 pull_ = _u(5);
        vm.startPrank(user);
        protocolVault.deposit(residualSeed_ + pull_, user);
        protocolVault.transfer(se, residualSeed_);
        protocolVault.approve(se, pull_);
        uint256 minted_ = seIn.exchangeIn(
            IERC20(address(protocolVault)), pull_, IERC20(se), 0, user, false, _deadline()
        );
        vm.stopPrank();
        assertGt(minted_, 0, "honest first pull");
        uint256 residual_ = IERC20(address(protocolVault)).balanceOf(se);
        assertGe(residual_, residualSeed_, "residual inventory remains");
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 claim_ = residualSeed_;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)), claim_, IERC20(se), 0, attacker, true, _deadline()
        );
        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I3: no second free mint");
        assertEq(IERC20(address(protocolVault)).balanceOf(se), residual_, "I3: inventory unmoved");
    }
}

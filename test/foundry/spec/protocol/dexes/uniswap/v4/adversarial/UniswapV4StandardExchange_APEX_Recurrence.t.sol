// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {Adversarial_UniswapV4SE_SecurePull} from "./Adversarial_UniswapV4SE_SecurePull.t.sol";

contract UniswapV4StandardExchange_APEX_Recurrence is Adversarial_UniswapV4SE_SecurePull {
    function test_RECURRENCE_legacyV4_prepaidSharesRejectEOA() public {
        uint256 shares = _mintSeShares(victim, 100 ether) / 10;
        vm.prank(victim);
        IERC20(address(vault)).transfer(address(vault), shares);
        uint256 snapshot = vm.snapshotState();
        uint256 paid = vault.exchangeIn(
            IERC20(address(vault)), shares, IERC20(_token0()), 0, address(this), true, _deadline()
        );
        assertGt(paid, 0, "funded contract control");
        assertTrue(vm.revertToState(snapshot));
        assertEq(attacker.code.length, 0);
        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(IERC20(address(vault)), shares, IERC20(_token0()), 0, attacker, true, _deadline());
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), shares);
    }
}

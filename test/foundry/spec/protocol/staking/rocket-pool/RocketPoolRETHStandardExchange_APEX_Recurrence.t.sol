// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {RocketPoolRETHStandardExchange_APEX_R14_Test} from "./RocketPoolRETHStandardExchange_APEX_R14.t.sol";

/// @notice Recurrence verification of D39's separately minimum-qualified source allocations.
contract RocketPoolRETHStandardExchange_APEX_Recurrence is RocketPoolRETHStandardExchange_APEX_R14_Test {
    /// @notice A later credit that lifts sleeve excess to the minimum deposits the whole excess.
    function test_RECURRENCE_B02_combinedExcessDepositsOnce_exactIn() public {
        _zeroUsageFees();
        _setTarget(0);
        hermeticSettings.setMinimumDeposit(1 ether);
        _wethToSe(0.6 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 0.6 ether, "first credit stays in the sleeve");
        assertEq(hermeticReth.balanceOf(seVault), 0, "below-minimum excess is not deposited");
        uint256 holderShares = IERC20(seVault).balanceOf(address(this));
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 0.6 ether, IERC20(seVault));
        uint256 minted = _wethToSe(0.6 ether, address(0xCA11));
        assertEq(minted, preview, "caller receives its quoted shares");
        assertEq(IERC20(seVault).balanceOf(address(this)), holderShares, "old shares unchanged");
        assertEq(rocketPoolSe.liquidReserveEth(), 0, "combined excess is deposited");
        assertGt(hermeticReth.balanceOf(seVault), 0, "combined excess became rETH");
    }

    /// @notice Exact-output issuance uses the same combined sleeve excess.
    function test_RECURRENCE_B02_combinedExcessDepositsOnce_exactOut() public {
        _zeroUsageFees();
        _setTarget(0);
        hermeticSettings.setMinimumDeposit(1 ether);
        _wethToSe(0.6 ether, address(this));
        uint256 requested = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 0.6 ether, IERC20(seVault));
        uint256 used = _wethToSeExactOut(requested, address(0xCA11));
        assertLt(used, 1 ether, "caller allocation remains individually below minimum");
        assertGe(used + 0.6 ether, 1 ether, "aggregate crosses minimum");
        assertEq(rocketPoolSe.liquidReserveEth(), 0, "combined excess is deposited");
        assertGt(hermeticReth.balanceOf(seVault), 0, "combined excess became rETH");
    }
}

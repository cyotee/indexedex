// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";

/// @notice R14.4 exact sleeve boundaries on the real EtherFi SE and existing hermetic protocol port.
contract EtherFiWeETHStandardExchange_APEX_Recurrence is TestBase_EtherFiWeETHStandardExchange {
    function _policy(uint256 target) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(target);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(seVault, target);
        vm.stopPrank();
    }

    function _deposit(uint256 assets, bool exactOut) internal returns (uint256 minted, uint256 used) {
        IERC20 input = IERC20(address(hermeticWeth));
        minted = seIn.previewExchangeIn(input, assets, IERC20(seVault));
        used = exactOut ? seOut.previewExchangeOut(input, IERC20(seVault), minted) : assets;
        _dealWeth(address(this), used);
        hermeticWeth.approve(seVault, used);
        uint256 beforeShares = IERC20(seVault).balanceOf(address(this));
        if (exactOut) {
            assertEq(seOut.exchangeOut(input, used, IERC20(seVault), minted, address(this), false, block.timestamp), used);
        } else {
            assertEq(seIn.exchangeIn(input, used, IERC20(seVault), minted, address(this), false, block.timestamp), minted);
        }
        assertEq(IERC20(seVault).balanceOf(address(this)) - beforeShares, minted, "preview and issuance");
    }

    function _locked(bool exactOut) internal {
        _policy(0.2e18);
        (uint256 first,) = _deposit(400 ether, false);
        assertEq(etherFiSe.liquidReserveEth(), 80 ether);
        assertEq(etherFiSe.lockedReserveEth(), 320 ether);
        uint256 entitlement = seIn.previewExchangeIn(IERC20(seVault), first, IERC20(address(hermeticWeth)));
        (, uint256 used) = _deposit(50 ether, exactOut);
        uint256 total = 400 ether + used;
        assertEq(etherFiSe.totalReserveEth(), total, "fee-free value preserved");
        assertEq(etherFiSe.liquidReserveEth(), total / 5, "exact 20 percent sleeve");
        assertEq(etherFiSe.lockedReserveEth(), total - total / 5, "remainder invested");
        assertEq(seIn.previewExchangeIn(IERC20(seVault), first, IERC20(address(hermeticWeth))), entitlement, "old-holder entitlement unchanged");
    }

    /// @notice Locked 80/320 state plus a funded caller preserves exact sleeve allocation.
    function test_RECURRENCE_B04_lockedSleeve_exactIn() public { _locked(false); }
    /// @notice The same locked arithmetic holds for exact-output share issuance.
    function test_RECURRENCE_B04_lockedSleeve_exactOut() public { _locked(true); }

    function _extreme(uint256 target, bool exactOut) internal {
        _policy(target);
        (, uint256 used) = _deposit(100 ether, exactOut);
        assertEq(etherFiSe.liquidReserveEth(), target == 0 ? 0 : used, "extreme liquid allocation");
        assertEq(etherFiSe.lockedReserveEth(), target == 0 ? used : 0, "extreme invested allocation");
        assertEq(etherFiSe.totalReserveEth(), used, "whole caller input backs shares");
    }

    /// @notice A zero sleeve invests the full exact-input principal.
    function test_RECURRENCE_B04_targetZero_exactIn() public { _extreme(0, false); }
    /// @notice A zero sleeve invests the full exact-output principal.
    function test_RECURRENCE_B04_targetZero_exactOut() public { _extreme(0, true); }
    /// @notice A full sleeve retains the full exact-input principal.
    function test_RECURRENCE_B04_targetFull_exactIn() public { _extreme(1e18, false); }
    /// @notice A full sleeve retains the full exact-output principal.
    function test_RECURRENCE_B04_targetFull_exactOut() public { _extreme(1e18, true); }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice F1–F2 (F3 EX-MARKER). Combo ID is the concrete suite name.
abstract contract MorphoBlueStandardExchange_Fees_Decimals is
    TestBase_MorphoBlueStandardExchange_Decimals
{
    function test_F1_usageFeeZero_noFeeToShares() public {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBefore = IERC20(se).balanceOf(feeTo_);
        uint256 shares = _wrapExactIn(user, _u(100));
        assertEq(IERC20(se).balanceOf(user), shares, "F1 user full shares");
        assertEq(IERC20(se).balanceOf(feeTo_), feeBefore, "F1 no fee shares");
        assertEq(IERC20(se).totalSupply(), shares + feeBefore, "F1 supply == user shares");
    }

    function test_F2_nonzeroUsageFee_feeSharesToFeeTo_userFullShares() public {
        uint256 feePct = 0.01e18;
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, feePct);
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 amount = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), amount, IERC20(se));
        uint256 shares = _wrapExactIn(user, amount);
        assertEq(shares, preview, "F2 user shares == sharesForDeposit");
        assertEq(IERC20(se).balanceOf(user), shares, "F2 user full shares");
        uint256 feeShares = (shares * feePct) / 1e18;
        assertEq(IERC20(se).balanceOf(feeTo_), feeShares, "F2 feeTo shares");
        assertEq(IERC20(se).totalSupply(), shares + feeShares, "F2 supply inflated");
    }
}

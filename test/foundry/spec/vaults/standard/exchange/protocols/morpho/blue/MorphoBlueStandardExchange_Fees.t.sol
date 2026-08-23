// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/**
 * @title MorphoBlueStandardExchange_Fees
 * @notice F1–F3: usage fee 0, non-zero inflation to feeTo, marker id is LENDING type key.
 */
contract MorphoBlueStandardExchange_Fees is TestBase_MorphoBlueStandardExchange {
    function test_F1_usageFeeZero_noFeeToShares() public {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBefore = IERC20(se).balanceOf(feeTo_);
        uint256 shares = _wrapExactIn(user, 100 ether);
        assertEq(IERC20(se).balanceOf(user), shares, "F1 user full shares");
        assertEq(IERC20(se).balanceOf(feeTo_), feeBefore, "F1 no fee shares");
        assertEq(IERC20(se).totalSupply(), shares + feeBefore, "F1 supply == user shares");
    }

    function test_F2_nonzeroUsageFee_feeSharesToFeeTo_userFullShares() public {
        uint256 feePct = 0.01e18;
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, feePct);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), 100 ether, IERC20(se));
        uint256 shares = _wrapExactIn(user, 100 ether);
        assertEq(shares, preview, "F2 user shares == sharesForDeposit");
        assertEq(IERC20(se).balanceOf(user), shares, "F2 user full shares");
        uint256 feeShares = (shares * feePct) / 1e18;
        assertEq(IERC20(se).balanceOf(feeTo_), feeShares, "F2 feeTo shares");
        assertEq(IERC20(se).totalSupply(), shares + feeShares, "F2 supply inflated");
    }

    function test_F3_markerInterfaceId_isLendingTypeKey() public view {
        bytes32 ids = morphoBlueStandardExchangeDFPkg.vaultFeeTypeIds();
        bytes4 lendingId = VaultTypeUtils._decodeVaultFeeType(ids, VaultFeeType.LENDING);
        assertEq(lendingId, type(IMorphoBlueStandardExchange).interfaceId, "F3 LENDING key");
    }
}

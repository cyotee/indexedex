// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

/// @notice Inlined receipt-plus-local backing math for ERC-4626 SE and Aave Stata.
/// @dev Not a CREATE3-linked library. Receipt units use the bound receipt's accounting
///      conversion (`convertToShares` / `convertToAssets`), never a capacity-limited preview.
library ReceiptBackedERC4626AccountingLib {
    /// @notice Canonical holder backing. Stata mode adds booked expected-hold extras once, then converts.
    /// @dev Generic mode contributes zero extra even when the receipt is a Stata token. Absent
    ///      expected-hold membership contributes zero. Do not read an unsolicited live extra balance.
    /// @param receipt Bound protocol vault or stata token.
    /// @param holder Account whose receipt balance is counted.
    /// @param includeExpectedHoldExtra When true, add booked expected-hold tokens other than receipt and underlying.
    function backingReceiptUnits(IERC4626 receipt, address holder, bool includeExpectedHoldExtra)
        internal
        view
        returns (uint256)
    {
        uint256 heldReceipts = IERC20(address(receipt)).balanceOf(holder);
        address underlying = receipt.asset();
        uint256 booked = MultiAssetBasicVaultRepo._reserveOfToken(underlying);
        if (includeExpectedHoldExtra) {
            booked += _bookedExpectedHoldExtra(address(receipt), underlying);
        }
        return receiptUnits(receipt, heldReceipts, booked);
    }

    function _bookedExpectedHoldExtra(address receipt, address underlying) private view returns (uint256 sum) {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            if (token == receipt || token == underlying) continue;
            sum += MultiAssetBasicVaultRepo._reserveOfToken(token);
        }
    }

    /// @notice Receipt-denominated backing: held receipts plus receipt-equivalent booked cash.
    /// @param receipt Bound protocol vault or stata token.
    /// @param heldReceipts Receipt tokens held by the wrapper.
    /// @param bookedUnderlying Booked local underlying plus any Stata expected-hold extra.
    function receiptUnits(IERC4626 receipt, uint256 heldReceipts, uint256 bookedUnderlying)
        internal
        view
        returns (uint256)
    {
        if (bookedUnderlying == 0) return heldReceipts;
        return heldReceipts + receipt.convertToShares(bookedUnderlying);
    }

    function sharesFromReceiptUnits(uint256 receiptDelta, uint256 backingBefore, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        if (supply == 0 || backingBefore == 0) return receiptDelta;
        return (receiptDelta * supply) / backingBefore;
    }

    function receiptUnitsFromShares(uint256 shares, uint256 backing, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        if (supply == 0) return 0;
        return (shares * backing) / supply;
    }

    function sharesForWithdraw(uint256 receiptUnitsOut, uint256 backing, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        if (supply == 0 || backing == 0) return receiptUnitsOut;
        return (receiptUnitsOut * supply + backing - 1) / backing;
    }

    function receiptUnitsForMint(uint256 shares, uint256 backing, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        if (supply == 0 || backing == 0) return shares;
        return (shares * backing + supply - 1) / supply;
    }
}

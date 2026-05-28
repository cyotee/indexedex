// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {BaseDualSelfCommonDETFRepo} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol";

/**
 * @title BaseDualSelfCommonDETFRichirRedeemTarget
 * @notice Implementation of restricted RICHIR→RICH redemption route management.
 * @dev Functions to add/remove addresses from the allowed list for local RICHIR redemption.
 */
abstract contract BaseDualSelfCommonDETFRichirRedeemTarget is OperableModifiers {
    using AddressSetRepo for AddressSet;
    /// @notice Add an address to the allowed list for RICHIR→RICH redemption
    /// @param addr Address to add
    function addAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        layoutStruct.allowedRichirRedeemAddresses._add(addr);
    }

    /// @notice Remove an address from the allowed list for RICHIR→RICH redemption
    /// @param addr Address to remove
    function removeAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        layoutStruct.allowedRichirRedeemAddresses._remove(addr);
    }

    /// @notice Check if an address is allowed to use the RICHIR→RICH route
    /// @param addr Address to check
    /// @return bool True if allowed
    function isAllowedRichirRedeemAddress(address addr) external view returns (bool) {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        return layoutStruct.allowedRichirRedeemAddresses._contains(addr);
    }
}

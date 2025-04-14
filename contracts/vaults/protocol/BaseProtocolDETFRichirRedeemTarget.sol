// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";

/**
 * @title BaseProtocolDETFRichirRedeemTarget
 * @notice Implementation of restricted RICHIR→RICH redemption route management.
 * @dev Functions to add/remove addresses from the allowed list for local RICHIR redemption.
 */
abstract contract BaseProtocolDETFRichirRedeemTarget is OperableModifiers {
    using AddressSetRepo for AddressSet;
    /// @notice Add an address to the allowed list for RICHIR→RICH redemption
    /// @param addr Address to add
    function addAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        layout.allowedRichirRedeemAddresses._add(addr);
    }

    /// @notice Remove an address from the allowed list for RICHIR→RICH redemption
    /// @param addr Address to remove
    function removeAllowedRichirRedeemAddress(address addr) external onlyOwnerOrOperator {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        layout.allowedRichirRedeemAddresses._remove(addr);
    }

    /// @notice Check if an address is allowed to use the RICHIR→RICH route
    /// @param addr Address to check
    /// @return bool True if allowed
    function isAllowedRichirRedeemAddress(address addr) external view returns (bool) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        return layout.allowedRichirRedeemAddresses._contains(addr);
    }
}

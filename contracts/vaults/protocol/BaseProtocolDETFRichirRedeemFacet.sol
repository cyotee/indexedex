// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBaseProtocolDETFRichirRedeem} from "contracts/interfaces/IBaseProtocolDETFRichirRedeem.sol";
import {BaseProtocolDETFRichirRedeemTarget} from "contracts/vaults/protocol/BaseProtocolDETFRichirRedeemTarget.sol";

/**
 * @title BaseProtocolDETFRichirRedeemFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for restricted RICHIR→RICH redemption route management.
 * @dev Extends BaseProtocolDETFRichirRedeemTarget and implements IFacet.
 */
contract BaseProtocolDETFRichirRedeemFacet is BaseProtocolDETFRichirRedeemTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(BaseProtocolDETFRichirRedeemFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBaseProtocolDETFRichirRedeem).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](3);
        funcs_[0] = IBaseProtocolDETFRichirRedeem.addAllowedRichirRedeemAddress.selector;
        funcs_[1] = IBaseProtocolDETFRichirRedeem.removeAllowedRichirRedeemAddress.selector;
        funcs_[2] = IBaseProtocolDETFRichirRedeem.isAllowedRichirRedeemAddress.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(BaseProtocolDETFRichirRedeemFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBaseProtocolDETFRichirRedeem).interfaceId;
        functions = new bytes4[](3);
        functions[0] = IBaseProtocolDETFRichirRedeem.addAllowedRichirRedeemAddress.selector;
        functions[1] = IBaseProtocolDETFRichirRedeem.removeAllowedRichirRedeemAddress.selector;
        functions[2] = IBaseProtocolDETFRichirRedeem.isAllowedRichirRedeemAddress.selector;
    }
}

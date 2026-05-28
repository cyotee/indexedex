// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBaseDualSelfCommonDETFRichirRedeem} from "contracts/interfaces/IBaseDualSelfCommonDETFRichirRedeem.sol";
import {BaseDualSelfCommonDETFRichirRedeemTarget} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRichirRedeemTarget.sol";

/**
 * @title BaseDualSelfCommonDETFRichirRedeemFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for restricted RICHIR→RICH redemption route management.
 * @dev Extends BaseDualSelfCommonDETFRichirRedeemTarget and implements IFacet.
 */
contract BaseDualSelfCommonDETFRichirRedeemFacet is BaseDualSelfCommonDETFRichirRedeemTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(BaseDualSelfCommonDETFRichirRedeemFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBaseDualSelfCommonDETFRichirRedeem).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](3);
        funcs_[0] = IBaseDualSelfCommonDETFRichirRedeem.addAllowedRichirRedeemAddress.selector;
        funcs_[1] = IBaseDualSelfCommonDETFRichirRedeem.removeAllowedRichirRedeemAddress.selector;
        funcs_[2] = IBaseDualSelfCommonDETFRichirRedeem.isAllowedRichirRedeemAddress.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(BaseDualSelfCommonDETFRichirRedeemFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBaseDualSelfCommonDETFRichirRedeem).interfaceId;
        functions = new bytes4[](3);
        functions[0] = IBaseDualSelfCommonDETFRichirRedeem.addAllowedRichirRedeemAddress.selector;
        functions[1] = IBaseDualSelfCommonDETFRichirRedeem.removeAllowedRichirRedeemAddress.selector;
        functions[2] = IBaseDualSelfCommonDETFRichirRedeem.isAllowedRichirRedeemAddress.selector;
    }
}

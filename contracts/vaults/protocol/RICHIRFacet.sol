// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {RICHIRTarget} from "contracts/vaults/protocol/RICHIRTarget.sol";

/**
 * @title RICHIRFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for RICHIR rebasing token operations.
 * @dev Extends RICHIRTarget and implements IFacet.
 */
contract RICHIRFacet is RICHIRTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory) {
        return type(RICHIRFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IRICHIR).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](21);
        // ERC20 functions
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        // ERC20Metadata functions
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        // IRICHIR functions
        funcs_[9] = IRICHIR.sharesOf.selector;
        funcs_[10] = IRICHIR.totalShares.selector;
        funcs_[11] = IRICHIR.redemptionRate.selector;
        funcs_[12] = IRICHIR.protocolDETF.selector;
        funcs_[13] = IRICHIR.protocolNFTId.selector;
        funcs_[14] = IRICHIR.wethToken.selector;
        funcs_[15] = IRICHIR.convertToShares.selector;
        funcs_[16] = IRICHIR.convertToRichir.selector;
        funcs_[17] = IRICHIR.previewRedeem.selector;
        funcs_[18] = IRICHIR.mintFromNFTSale.selector;
        funcs_[19] = IRICHIR.redeem.selector;
        funcs_[20] = IRICHIR.burnShares.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = type(RICHIRFacet).name;

        interfaces = new bytes4[](3);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IRICHIR).interfaceId;

        functions = new bytes4[](21);
        functions[0] = IERC20.totalSupply.selector;
        functions[1] = IERC20.balanceOf.selector;
        functions[2] = IERC20.transfer.selector;
        functions[3] = IERC20.allowance.selector;
        functions[4] = IERC20.approve.selector;
        functions[5] = IERC20.transferFrom.selector;
        functions[6] = IERC20Metadata.name.selector;
        functions[7] = IERC20Metadata.symbol.selector;
        functions[8] = IERC20Metadata.decimals.selector;
        functions[9] = IRICHIR.sharesOf.selector;
        functions[10] = IRICHIR.totalShares.selector;
        functions[11] = IRICHIR.redemptionRate.selector;
        functions[12] = IRICHIR.protocolDETF.selector;
        functions[13] = IRICHIR.protocolNFTId.selector;
        functions[14] = IRICHIR.wethToken.selector;
        functions[15] = IRICHIR.convertToShares.selector;
        functions[16] = IRICHIR.convertToRichir.selector;
        functions[17] = IRICHIR.previewRedeem.selector;
        functions[18] = IRICHIR.mintFromNFTSale.selector;
        functions[19] = IRICHIR.redeem.selector;
        functions[20] = IRICHIR.burnShares.selector;
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IBaseDualSelfCommonDETFBonding} from "contracts/vaults/protocol/BaseDualSelfCommonDETFBondingTarget.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {BaseDualSelfCommonDETFBondingQueryTarget} from "contracts/vaults/protocol/BaseDualSelfCommonDETFBondingQueryTarget.sol";

/**
 * @title BaseDualSelfCommonDETFBondingQueryFacet
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond facet for Protocol DETF bonding query/view operations.
 * @dev Split from BaseDualSelfCommonDETFBondingFacet to meet EIP-170 contract size limit.
 *      Contains all view/getter functions.
 */
contract BaseDualSelfCommonDETFBondingQueryFacet is BaseDualSelfCommonDETFBondingQueryTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                              IFacet                                    */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory name) {
        return type(BaseDualSelfCommonDETFBondingQueryFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IBaseDualSelfCommonDETFBonding).interfaceId;
        interfaces_[1] = type(IProtocolDETF).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](20);
        // IProtocolDETFBonding view functions
        funcs_[0] = IBaseDualSelfCommonDETFBonding.syntheticPrice.selector;
        funcs_[1] = IBaseDualSelfCommonDETFBonding.isMintingAllowed.selector;
        funcs_[2] = IBaseDualSelfCommonDETFBonding.isBurningAllowed.selector;

        // IProtocolDETF view functions
        funcs_[3] = IProtocolDETF.chirWethVault.selector;
        funcs_[4] = IProtocolDETF.richChirVault.selector;
        funcs_[5] = IProtocolDETF.reservePool.selector;
        funcs_[6] = IProtocolDETF.protocolNFTVault.selector;
        funcs_[7] = IProtocolDETF.richToken.selector;
        funcs_[8] = IProtocolDETF.richirToken.selector;
        funcs_[9] = IProtocolDETF.chirToken.selector;
        funcs_[10] = IProtocolDETF.protocolNFTId.selector;
        funcs_[11] = IProtocolDETF.mintThreshold.selector;
        funcs_[12] = IProtocolDETF.burnThreshold.selector;
        funcs_[13] = IProtocolDETF.wethToken.selector;
        funcs_[14] = IProtocolDETF.previewClaimLiquidity.selector;
        funcs_[15] = IProtocolDETF.previewBridgeRichir.selector;
        funcs_[16] = IDETF.bondNftVault.selector;
        funcs_[17] = IDETF.rebasingDetfToken.selector;
        funcs_[18] = IDETF.previewRebasingDetfTokenReserveBpt.selector;
        funcs_[19] = IDETF.previewRebasingDetfTokenEthValue.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(BaseDualSelfCommonDETFBondingQueryFacet).name;
        interfaces = new bytes4[](2);
        interfaces[0] = type(IBaseDualSelfCommonDETFBonding).interfaceId;
        interfaces[1] = type(IProtocolDETF).interfaceId;
        functions = new bytes4[](20);
        functions[0] = IBaseDualSelfCommonDETFBonding.syntheticPrice.selector;
        functions[1] = IBaseDualSelfCommonDETFBonding.isMintingAllowed.selector;
        functions[2] = IBaseDualSelfCommonDETFBonding.isBurningAllowed.selector;
        functions[3] = IProtocolDETF.chirWethVault.selector;
        functions[4] = IProtocolDETF.richChirVault.selector;
        functions[5] = IProtocolDETF.reservePool.selector;
        functions[6] = IProtocolDETF.protocolNFTVault.selector;
        functions[7] = IProtocolDETF.richToken.selector;
        functions[8] = IProtocolDETF.richirToken.selector;
        functions[9] = IProtocolDETF.chirToken.selector;
        functions[10] = IProtocolDETF.protocolNFTId.selector;
        functions[11] = IProtocolDETF.mintThreshold.selector;
        functions[12] = IProtocolDETF.burnThreshold.selector;
        functions[13] = IProtocolDETF.wethToken.selector;
        functions[14] = IProtocolDETF.previewClaimLiquidity.selector;
        functions[15] = IProtocolDETF.previewBridgeRichir.selector;
        functions[16] = IDETF.bondNftVault.selector;
        functions[17] = IDETF.rebasingDetfToken.selector;
        functions[18] = IDETF.previewRebasingDetfTokenReserveBpt.selector;
        functions[19] = IDETF.previewRebasingDetfTokenEthValue.selector;
    }
}

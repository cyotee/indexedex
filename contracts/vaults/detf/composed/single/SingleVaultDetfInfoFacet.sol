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
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {SingleVaultDetfInfoTarget} from "contracts/vaults/detf/composed/single/SingleVaultDetfInfoTarget.sol";

contract SingleVaultDetfInfoFacet is SingleVaultDetfInfoTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(SingleVaultDetfInfoFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IProtocolDETF).interfaceId;
        interfaces_[1] = type(ISingleVaultDetf).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](17);
        funcs_[0] = IProtocolDETF.chirToken.selector;
        funcs_[1] = IProtocolDETF.richToken.selector;
        funcs_[2] = IProtocolDETF.richirToken.selector;
        funcs_[3] = IProtocolDETF.wethToken.selector;
        funcs_[4] = IProtocolDETF.protocolNFTVault.selector;
        funcs_[5] = IProtocolDETF.chirWethVault.selector;
        funcs_[6] = IProtocolDETF.richChirVault.selector;
        funcs_[7] = IProtocolDETF.reservePool.selector;
        funcs_[8] = IProtocolDETF.protocolNFTId.selector;
        funcs_[9] = IProtocolDETF.syntheticPrice.selector;
        funcs_[10] = IProtocolDETF.mintThreshold.selector;
        funcs_[11] = IProtocolDETF.burnThreshold.selector;
        funcs_[12] = IProtocolDETF.isMintingAllowed.selector;
        funcs_[13] = IProtocolDETF.isBurningAllowed.selector;
        funcs_[14] = ISingleVaultDetf.wethRichVault.selector;
        funcs_[15] = ISingleVaultDetf.vaultRateProvider.selector;
        funcs_[16] = ISingleVaultDetf.reservePoolIndexes.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(SingleVaultDetfInfoFacet).name;
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IProtocolDETF).interfaceId;
        interfaces_[1] = type(ISingleVaultDetf).interfaceId;
        functions_ = new bytes4[](17);
        functions_[0] = IProtocolDETF.chirToken.selector;
        functions_[1] = IProtocolDETF.richToken.selector;
        functions_[2] = IProtocolDETF.richirToken.selector;
        functions_[3] = IProtocolDETF.wethToken.selector;
        functions_[4] = IProtocolDETF.protocolNFTVault.selector;
        functions_[5] = IProtocolDETF.chirWethVault.selector;
        functions_[6] = IProtocolDETF.richChirVault.selector;
        functions_[7] = IProtocolDETF.reservePool.selector;
        functions_[8] = IProtocolDETF.protocolNFTId.selector;
        functions_[9] = IProtocolDETF.syntheticPrice.selector;
        functions_[10] = IProtocolDETF.mintThreshold.selector;
        functions_[11] = IProtocolDETF.burnThreshold.selector;
        functions_[12] = IProtocolDETF.isMintingAllowed.selector;
        functions_[13] = IProtocolDETF.isBurningAllowed.selector;
        functions_[14] = ISingleVaultDetf.wethRichVault.selector;
        functions_[15] = ISingleVaultDetf.vaultRateProvider.selector;
        functions_[16] = ISingleVaultDetf.reservePoolIndexes.selector;
    }
}
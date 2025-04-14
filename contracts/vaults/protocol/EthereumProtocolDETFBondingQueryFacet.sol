// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {
    IBaseProtocolDETFBonding
} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {
    EthereumProtocolDETFBondingQueryTarget
} from "contracts/vaults/protocol/EthereumProtocolDETFBondingQueryTarget.sol";

contract EthereumProtocolDETFBondingQueryFacet is EthereumProtocolDETFBondingQueryTarget, IFacet {
    function facetName() external pure returns (string memory name) {
        return type(EthereumProtocolDETFBondingQueryFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IBaseProtocolDETFBonding).interfaceId;
        interfaces_[1] = type(IProtocolDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](16);
        funcs_[0] = IBaseProtocolDETFBonding.syntheticPrice.selector;
        funcs_[1] = IBaseProtocolDETFBonding.isMintingAllowed.selector;
        funcs_[2] = IBaseProtocolDETFBonding.isBurningAllowed.selector;
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
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(EthereumProtocolDETFBondingQueryFacet).name;
        interfaces = new bytes4[](2);
        interfaces[0] = type(IBaseProtocolDETFBonding).interfaceId;
        interfaces[1] = type(IProtocolDETF).interfaceId;
        functions = new bytes4[](16);
        functions[0] = IBaseProtocolDETFBonding.syntheticPrice.selector;
        functions[1] = IBaseProtocolDETFBonding.isMintingAllowed.selector;
        functions[2] = IBaseProtocolDETFBonding.isBurningAllowed.selector;
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
    }
}
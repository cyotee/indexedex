// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    ISingleVaultDetfBonding,
    SingleVaultDetfBondingTarget
} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";

contract SingleVaultDetfBondingFacet is SingleVaultDetfBondingTarget, IFacet {
    function facetName() external pure returns (string memory name_) {
        return type(SingleVaultDetfBondingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(ISingleVaultDetfBonding).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](11);
        funcs_[0] = ISingleVaultDetfBonding.acceptedBondTokens.selector;
        funcs_[1] = ISingleVaultDetfBonding.isAcceptedBondToken.selector;
        funcs_[2] = ISingleVaultDetfBonding.setRichirToken.selector;
        funcs_[3] = ISingleVaultDetfBonding.bond.selector;
        funcs_[4] = ISingleVaultDetfBonding.bondWithPosition.selector;
        funcs_[5] = ISingleVaultDetfBonding.captureSeigniorage.selector;
        funcs_[6] = ISingleVaultDetfBonding.sellNFT.selector;
        funcs_[7] = ISingleVaultDetfBonding.donate.selector;
        funcs_[8] = IProtocolDETF.claimLiquidity.selector;
        funcs_[9] = IProtocolDETF.bridgeRichir.selector;
        funcs_[10] = IProtocolDETF.receiveBridgedRich.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(SingleVaultDetfBondingFacet).name;
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(ISingleVaultDetfBonding).interfaceId;
        functions_ = new bytes4[](11);
        functions_[0] = ISingleVaultDetfBonding.acceptedBondTokens.selector;
        functions_[1] = ISingleVaultDetfBonding.isAcceptedBondToken.selector;
        functions_[2] = ISingleVaultDetfBonding.setRichirToken.selector;
        functions_[3] = ISingleVaultDetfBonding.bond.selector;
        functions_[4] = ISingleVaultDetfBonding.bondWithPosition.selector;
        functions_[5] = ISingleVaultDetfBonding.captureSeigniorage.selector;
        functions_[6] = ISingleVaultDetfBonding.sellNFT.selector;
        functions_[7] = ISingleVaultDetfBonding.donate.selector;
        functions_[8] = IProtocolDETF.claimLiquidity.selector;
        functions_[9] = IProtocolDETF.bridgeRichir.selector;
        functions_[10] = IProtocolDETF.receiveBridgedRich.selector;
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IBaseProtocolDETFBonding,
    BaseProtocolDETFBondingTarget
} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {EthereumProtocolDETFBondingTarget} from "contracts/vaults/protocol/EthereumProtocolDETFBondingTarget.sol";

contract EthereumProtocolDETFBondingFacet is EthereumProtocolDETFBondingTarget, IFacet {
    function facetName() external pure returns (string memory name) {
        return type(EthereumProtocolDETFBondingFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBaseProtocolDETFBonding).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](7);
        funcs_[0] = IBaseProtocolDETFBonding.acceptedBondTokens.selector;
        funcs_[1] = IBaseProtocolDETFBonding.isAcceptedBondToken.selector;
        funcs_[2] = IBaseProtocolDETFBonding.bond.selector;
        funcs_[3] = IBaseProtocolDETFBonding.captureSeigniorage.selector;
        funcs_[4] = IBaseProtocolDETFBonding.sellNFT.selector;
        funcs_[5] = IBaseProtocolDETFBonding.donate.selector;
        funcs_[6] = IProtocolDETF.claimLiquidity.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(EthereumProtocolDETFBondingFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBaseProtocolDETFBonding).interfaceId;
        functions = new bytes4[](7);
        functions[0] = IBaseProtocolDETFBonding.acceptedBondTokens.selector;
        functions[1] = IBaseProtocolDETFBonding.isAcceptedBondToken.selector;
        functions[2] = IBaseProtocolDETFBonding.bond.selector;
        functions[3] = IBaseProtocolDETFBonding.captureSeigniorage.selector;
        functions[4] = IBaseProtocolDETFBonding.sellNFT.selector;
        functions[5] = IBaseProtocolDETFBonding.donate.selector;
        functions[6] = IProtocolDETF.claimLiquidity.selector;
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {EthereumProtocolDETFBridgeTarget} from "contracts/vaults/protocol/EthereumProtocolDETFBridgeTarget.sol";

contract EthereumProtocolDETFBridgeFacet is EthereumProtocolDETFBridgeTarget, IFacet {
    function facetName() external pure returns (string memory name) {
        return type(EthereumProtocolDETFBridgeFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IProtocolDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IProtocolDETF.bridgeRichir.selector;
        funcs_[1] = IProtocolDETF.receiveBridgedRich.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(EthereumProtocolDETFBridgeFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IProtocolDETF).interfaceId;
        functions = new bytes4[](2);
        functions[0] = IProtocolDETF.bridgeRichir.selector;
        functions[1] = IProtocolDETF.receiveBridgedRich.selector;
    }
}
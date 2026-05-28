// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {EthereumDualSelfCommonDETFExchangeInTarget} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFExchangeInTarget.sol";

contract EthereumDualSelfCommonDETFExchangeInFacet is EthereumDualSelfCommonDETFExchangeInTarget, IFacet {
    function facetName() external pure returns (string memory name) {
        return type(EthereumDualSelfCommonDETFExchangeInFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = type(EthereumDualSelfCommonDETFExchangeInFacet).name;
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        functions = new bytes4[](1);
        functions[0] = IStandardExchangeIn.exchangeIn.selector;
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    EthereumProtocolDETFExchangeInQueryTarget
} from "contracts/vaults/protocol/EthereumProtocolDETFExchangeInQueryTarget.sol";

contract EthereumProtocolDETFExchangeInQueryFacet is EthereumProtocolDETFExchangeInQueryTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(EthereumProtocolDETFExchangeInQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
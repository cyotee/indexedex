// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ERC4626StandardExchangeOutTarget} from
    "contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol";

contract ERC4626StandardExchangeOutFacet is ERC4626StandardExchangeOutTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(ERC4626StandardExchangeOutFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeOut.exchangeOut.selector;
        return funcs;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}

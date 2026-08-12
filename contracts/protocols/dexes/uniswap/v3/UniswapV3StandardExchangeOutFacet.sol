// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutTarget.sol";

/**
 * @title UniswapV3StandardExchangeOutFacet
 * @notice Facet for exchange-out routes.
 */
contract UniswapV3StandardExchangeOutFacet is UniswapV3StandardExchangeOutTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangeOutFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata()
        external
        pure
        override
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}

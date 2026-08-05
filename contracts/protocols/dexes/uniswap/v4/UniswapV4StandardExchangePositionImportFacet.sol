// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IUniswapV4StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {
    UniswapV4StandardExchangePositionImportTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportTarget.sol";

contract UniswapV4StandardExchangePositionImportFacet is UniswapV4StandardExchangePositionImportTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4StandardExchangePositionImportFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangePositionImport).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IUniswapV4StandardExchangePositionImport.importPosition.selector;
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

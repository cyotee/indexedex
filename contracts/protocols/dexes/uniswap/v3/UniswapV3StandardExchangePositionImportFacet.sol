// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3StandardExchangePositionImport,
    UniswapV3StandardExchangePositionImportTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";

/**
 * @title UniswapV3StandardExchangePositionImportFacet
 * @notice Facet for first-deposit NPM → direct-pool center conversion.
 */
contract UniswapV3StandardExchangePositionImportFacet is UniswapV3StandardExchangePositionImportTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangePositionImportFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV3StandardExchangePositionImport).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IUniswapV3StandardExchangePositionImport.previewImportPosition.selector;
        funcs[1] = IUniswapV3StandardExchangePositionImport.importPosition.selector;
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

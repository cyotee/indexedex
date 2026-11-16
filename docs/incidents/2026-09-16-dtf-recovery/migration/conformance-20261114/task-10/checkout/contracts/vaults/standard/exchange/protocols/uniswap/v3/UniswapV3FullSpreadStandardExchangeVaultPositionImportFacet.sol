// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultPositionImport,
    UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";

/**
 * @title UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet
 * @notice Facet for first-deposit NPM → direct-pool center conversion.
 */
contract UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet is UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV3FullSpreadStandardExchangeVaultPositionImport).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IUniswapV3FullSpreadStandardExchangeVaultPositionImport.previewImportPosition.selector;
        funcs[1] = IUniswapV3FullSpreadStandardExchangeVaultPositionImport.importPosition.selector;
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

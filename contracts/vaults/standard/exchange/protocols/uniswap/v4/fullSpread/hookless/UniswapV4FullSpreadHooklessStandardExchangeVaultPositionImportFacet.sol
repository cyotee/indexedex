// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportTarget.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet is UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport.importPosition.selector;
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

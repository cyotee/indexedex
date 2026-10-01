// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IUniswapV4FullSpreadPonsFamilyHookPositionImport
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInTarget.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookPositionImportTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookPositionImportTarget.sol";

contract UniswapV4FullSpreadPonsFamilyHookPositionImportFacet is UniswapV4FullSpreadPonsFamilyHookPositionImportTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4FullSpreadPonsFamilyHookPositionImportFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4FullSpreadPonsFamilyHookPositionImport).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IUniswapV4FullSpreadPonsFamilyHookPositionImport.importPosition.selector;
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

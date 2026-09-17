// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol";

contract UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet is UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOutMulti).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeOutMulti.exchangeOutOneToMany.selector;
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

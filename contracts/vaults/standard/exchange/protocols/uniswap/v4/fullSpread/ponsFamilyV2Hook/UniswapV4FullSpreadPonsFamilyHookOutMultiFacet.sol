// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookOutMultiTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol";

contract UniswapV4FullSpreadPonsFamilyHookOutMultiFacet is UniswapV4FullSpreadPonsFamilyHookOutMultiTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV4FullSpreadPonsFamilyHookOutMultiFacet).name;
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

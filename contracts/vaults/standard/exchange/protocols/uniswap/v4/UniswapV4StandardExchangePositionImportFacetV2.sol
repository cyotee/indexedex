// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IUniswapV4StandardExchangePositionImportV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInTargetV2.sol";
import {
    UniswapV4StandardExchangePositionImportTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangePositionImportTargetV2.sol";

contract UniswapV4StandardExchangePositionImportFacetV2 is UniswapV4StandardExchangePositionImportTargetV2, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4StandardExchangePositionImportFacetV2).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangePositionImportV2).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IUniswapV4StandardExchangePositionImportV2.importPosition.selector;
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

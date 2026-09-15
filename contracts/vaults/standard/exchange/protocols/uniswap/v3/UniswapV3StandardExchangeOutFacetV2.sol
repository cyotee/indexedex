// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutExecuteTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeOutExecuteTargetV2.sol";

/**
 * @title UniswapV3StandardExchangeOutFacetV2
 * @notice Execute-only exchangeOut. Preview lives on OutQueryFacet.
 */
contract UniswapV3StandardExchangeOutFacetV2 is UniswapV3StandardExchangeOutExecuteTargetV2, IFacet {
    constructor(address executionDelegate) UniswapV3StandardExchangeOutExecuteTargetV2(executionDelegate) {}

    function facetName() public pure returns (string memory name) {
        return type(UniswapV3StandardExchangeOutFacetV2).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeOut.exchangeOut.selector;
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

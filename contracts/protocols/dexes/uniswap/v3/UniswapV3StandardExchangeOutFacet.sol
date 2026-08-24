// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutExecuteTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutExecuteTarget.sol";

/**
 * @title UniswapV3StandardExchangeOutFacet
 * @notice Execute-only exchangeOut. Preview lives on OutQueryFacet.
 */
contract UniswapV3StandardExchangeOutFacet is UniswapV3StandardExchangeOutExecuteTarget, IFacet {
    constructor(address executionDelegate) UniswapV3StandardExchangeOutExecuteTarget(executionDelegate) {}

    function facetName() public pure returns (string memory name) {
        return type(UniswapV3StandardExchangeOutFacet).name;
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

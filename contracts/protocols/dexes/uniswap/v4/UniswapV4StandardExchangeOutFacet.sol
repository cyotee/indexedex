// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOutExecuteTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecuteTarget.sol";

/// @notice Execute-only exchangeOut (Option 1b + 2b delegate). Preview is on OutQueryFacet.
contract UniswapV4StandardExchangeOutFacet is UniswapV4StandardExchangeOutExecuteTarget, IFacet {
    constructor(address executionDelegate) UniswapV4StandardExchangeOutExecuteTarget(executionDelegate) {}

    function facetName() public pure returns (string memory name) {
        return type(UniswapV4StandardExchangeOutFacet).name;
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

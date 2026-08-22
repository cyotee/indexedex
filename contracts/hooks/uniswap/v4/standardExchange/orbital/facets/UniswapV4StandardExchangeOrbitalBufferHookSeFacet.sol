// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookSeFacet
 * @notice IStandardExchangeIn / Out surface (same sphere book as V4 doors).
 */
contract UniswapV4StandardExchangeOrbitalBufferHookSeFacet is
    UniswapV4StandardExchangeOrbitalBufferHookSeTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookSeFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[3] = IStandardExchangeOut.exchangeOut.selector;
        funcs[4] = IUniswapV4StandardExchangeOrbitalBufferHook.ownerSwapExactIn.selector;
        funcs[5] = IUniswapV4StandardExchangeOrbitalBufferHook.ownerSwapExactOut.selector;
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

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

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
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeOut).interfaceId;
        interfaces[2] = type(IStandardizedYield).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs[1] = IStandardizedYield.deposit.selector;
        funcs[2] = IStandardizedYield.redeem.selector;
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

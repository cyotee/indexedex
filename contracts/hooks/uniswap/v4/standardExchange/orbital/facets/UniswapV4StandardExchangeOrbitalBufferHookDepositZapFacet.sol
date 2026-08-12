// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDepositZapTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositZapTarget.sol";

contract UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet is
    UniswapV4StandardExchangeOrbitalBufferHookDepositZapTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IUniswapV4StandardExchangeOrbitalBufferHook.depositSingle.selector;
        funcs[1] = IUniswapV4StandardExchangeOrbitalBufferHook.previewDepositSingle.selector;
        funcs[2] = IUniswapV4StandardExchangeOrbitalBufferHook.previewZapSplit.selector;
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

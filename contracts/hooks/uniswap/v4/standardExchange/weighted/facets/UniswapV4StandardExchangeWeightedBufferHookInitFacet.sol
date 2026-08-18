// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookInit
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookInit.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookInitTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookInitTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookInitFacet
 * @notice Source-only IFacet mixin inherited by the DFPkg (S47). Never CREATE3-deployed.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookInitFacet is
    UniswapV4StandardExchangeWeightedBufferHookInitTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeWeightedBufferHookInitFacet).name;
    }

    function facetInterfaces() public pure virtual returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeWeightedBufferHookInit).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IHooks.beforeInitialize.selector;
        funcs[1] = IUniswapV4HookStagedPairInit.deployPair.selector;
        funcs[2] = IUniswapV4HookStagedPairInit.finalizeInitialization.selector;
        funcs[3] = IUniswapV4HookStagedPairInit.isPairPoolLive.selector;
        funcs[4] = IUniswapV4HookStagedPairInit.pairPoolKey.selector;
        funcs[5] = IUniswapV4HookStagedPairInit.isInitializationFinalized.selector;
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

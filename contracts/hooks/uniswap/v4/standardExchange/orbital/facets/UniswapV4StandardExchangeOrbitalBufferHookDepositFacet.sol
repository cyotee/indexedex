// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookDepositFacet
 * @notice addLiquidity + depositSingle (zap-in) + previews.
 */
contract UniswapV4StandardExchangeOrbitalBufferHookDepositFacet is
    UniswapV4StandardExchangeOrbitalBufferHookTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookDepositFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeOrbitalBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector;
        funcs[1] = IUniswapV4StandardExchangeOrbitalBufferHook.depositSingle.selector;
        funcs[2] = IUniswapV4StandardExchangeOrbitalBufferHook.previewAddLiquidity.selector;
        funcs[3] = IUniswapV4StandardExchangeOrbitalBufferHook.previewDepositSingle.selector;
        funcs[4] = IUniswapV4StandardExchangeOrbitalBufferHook.previewZapSplit.selector;
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

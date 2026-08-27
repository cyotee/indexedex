// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositTarget.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookDepositFacet
 * @notice addLiquidity + depositSingle (zap-in) + previews.
 */
contract UniswapV4StandardExchangeOrbitalBufferHookDepositFacet is
    UniswapV4StandardExchangeOrbitalBufferHookDepositTarget,
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
        funcs = new bytes4[](15);
        funcs[0] = IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector;
        funcs[1] = IUniswapV4StandardExchangeOrbitalBufferHook.depositSingle.selector;
        funcs[2] = IUniswapV4StandardExchangeOrbitalBufferHook.previewAddLiquidity.selector;
        funcs[3] = IUniswapV4StandardExchangeOrbitalBufferHook.previewDepositSingle.selector;
        funcs[4] = IUniswapV4StandardExchangeOrbitalBufferHook.previewZapSplit.selector;
        funcs[5] = IUniswapV4StandardExchangeOrbitalBufferHook.depositFlexible.selector;
        funcs[6] = IUniswapV4StandardExchangeOrbitalBufferHook.previewDepositFlexible.selector;
        funcs[7] = IUniswapV4SeBufferHook.joinProportional.selector;
        funcs[8] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[9] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
        funcs[10] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[11] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        funcs[12] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[13] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        funcs[14] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
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

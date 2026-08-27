// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet
 * @notice removeLiquidity + preview (no zap-out).
 */
contract UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet is
    UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IUniswapV4StandardExchangeOrbitalBufferHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IUniswapV4StandardExchangeOrbitalBufferHook.removeLiquidity.selector;
        funcs[1] = IUniswapV4StandardExchangeOrbitalBufferHook.previewRemoveLiquidity.selector;
        funcs[2] = IUniswapV4StandardExchangeOrbitalBufferHook.withdrawFlexible.selector;
        funcs[3] = IUniswapV4StandardExchangeOrbitalBufferHook.previewWithdrawFlexible.selector;
        funcs[4] = IUniswapV4SeBufferHook.exitProportional.selector;
        funcs[5] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        funcs[6] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[7] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[8] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[9] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[10] = IDetfReserveQuote.previewBurnToToken.selector;
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

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

contract UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet is
    UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](13);
        funcs[0] = IHook.withdraw.selector;
        funcs[1] = IHook.withdrawSingle.selector;
        funcs[2] = IHook.previewWithdraw.selector;
        funcs[3] = IHook.previewWithdrawSingle.selector;
        funcs[4] = IHook.withdrawSeShares.selector;
        funcs[5] = IHook.previewWithdrawSeShares.selector;
        funcs[6] = IUniswapV4SeBufferHook.exitProportional.selector;
        funcs[7] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        funcs[8] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[9] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[10] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[11] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[12] = IDetfReserveQuote.previewBurnToToken.selector;
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

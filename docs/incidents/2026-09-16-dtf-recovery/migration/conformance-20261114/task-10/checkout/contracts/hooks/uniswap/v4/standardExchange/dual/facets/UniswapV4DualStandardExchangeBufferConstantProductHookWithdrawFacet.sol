// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

contract UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet is
    UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](12);
        funcs[0] = IHook.withdraw.selector;
        funcs[1] = IHook.previewWithdraw.selector;
        funcs[2] = IHook.withdrawFlexible.selector;
        funcs[3] = IHook.previewWithdrawFlexible.selector;
        funcs[4] = IUniswapV4SeBufferHook.exitProportional.selector;
        funcs[5] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        funcs[6] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[7] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[8] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[9] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[10] = IDetfReserveQuote.previewBurnToToken.selector;
        funcs[11] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs = NativeStandardYieldSelectors._appendQuery(funcs);
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

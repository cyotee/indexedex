// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHookFacet
 * @notice Product facet: IHooks + bindings + previews + pool helpers (no vault selectors).
 */
contract UniswapV4SingleStandardExchangeBufferHookFacet is
    UniswapV4SingleStandardExchangeBufferHookTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferHookFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IHook).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](24);
        // IHooks (10)
        funcs[0] = IHooks.beforeInitialize.selector;
        funcs[1] = IHooks.afterInitialize.selector;
        funcs[2] = IHooks.beforeAddLiquidity.selector;
        funcs[3] = IHooks.afterAddLiquidity.selector;
        funcs[4] = IHooks.beforeRemoveLiquidity.selector;
        funcs[5] = IHooks.afterRemoveLiquidity.selector;
        funcs[6] = IHooks.beforeSwap.selector;
        funcs[7] = IHooks.afterSwap.selector;
        funcs[8] = IHooks.beforeDonate.selector;
        funcs[9] = IHooks.afterDonate.selector;
        // Bindings + helpers
        funcs[10] = IHook.poolManager.selector;
        funcs[11] = IHook.standardExchange.selector;
        funcs[12] = IHook.pairToken.selector;
        funcs[13] = IHook.wrapper.selector;
        funcs[14] = IHook.currency0.selector;
        funcs[15] = IHook.currency1.selector;
        funcs[16] = IHook.poolFee.selector;
        funcs[17] = IHook.tickSpacingHint.selector;
        funcs[18] = IHook.sqrtPriceX96Hint.selector;
        // Previews
        funcs[19] = IHook.previewWrap.selector;
        funcs[20] = IHook.previewWrapExactOut.selector;
        funcs[21] = IHook.previewUnwrap.selector;
        funcs[22] = IHook.previewUnwrapExactOut.selector;
        funcs[23] = IHook.getHookPermissions.selector;
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

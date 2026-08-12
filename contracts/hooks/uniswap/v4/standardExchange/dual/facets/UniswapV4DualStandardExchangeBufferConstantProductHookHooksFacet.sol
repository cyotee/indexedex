// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/// @notice IHooks + product binding/claim/fee views + swap previews (size-split facet).
contract UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet is
    UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IHooks).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        bytes4[] memory a = _a();
        bytes4[] memory b = _b();
        funcs = new bytes4[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            funcs[i] = a[i];
        }
        for (uint256 j; j < b.length; ++j) {
            funcs[a.length + j] = b[j];
        }
    }

    function _a() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](20);
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
        funcs[10] = IHook.poolManager.selector;
        funcs[11] = IHook.feeOracle.selector;
        funcs[12] = IHook.permit2.selector;
        funcs[13] = IHook.standardExchange0.selector;
        funcs[14] = IHook.standardExchange1.selector;
        funcs[15] = IHook.token0.selector;
        funcs[16] = IHook.token1.selector;
        funcs[17] = IHook.currency0.selector;
        funcs[18] = IHook.currency1.selector;
        funcs[19] = IHook.claimSupply0.selector;
    }

    function _b() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IHook.claimSupply1.selector;
        funcs[1] = IHook.claimSupplyCurrency0.selector;
        funcs[2] = IHook.claimSupplyCurrency1.selector;
        funcs[3] = IHook.tradingFeePercent.selector;
        funcs[4] = IHook.tradingFeeDenominator.selector;
        funcs[5] = IHook.dexSwapFee.selector;
        funcs[6] = IHook.feeTo.selector;
        funcs[7] = IHook.kLast.selector;
        funcs[8] = IHook.previewSwapExactIn.selector;
        funcs[9] = IHook.previewSwapExactOut.selector;
        funcs[10] = this.getHookPermissions.selector;
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

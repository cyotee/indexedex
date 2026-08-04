// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @notice Hooks + SE In/Out + product views (size-split facet).
contract UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet is
    UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IStandardExchangeIn).interfaceId;
        interfaces[2] = type(IStandardExchangeOut).interfaceId;
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
        funcs[13] = IHook.standardExchange.selector;
        funcs[14] = IHook.pairToken.selector;
        funcs[15] = IHook.rawToken.selector;
        funcs[16] = IHook.currency0.selector;
        funcs[17] = IHook.currency1.selector;
        funcs[18] = IHook.rawReserve.selector;
        funcs[19] = IHook.seClaimSupply.selector;
    }

    function _b() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](15);
        funcs[0] = IHook.reserveCurrency0.selector;
        funcs[1] = IHook.reserveCurrency1.selector;
        funcs[2] = IHook.isLive.selector;
        funcs[3] = IHook.isZapEligible.selector;
        funcs[4] = IHook.tradingFeePercent.selector;
        funcs[5] = IHook.tradingFeeDenominator.selector;
        funcs[6] = IHook.dexSwapFeeAndFeeTo.selector;
        funcs[7] = IHook.kLast.selector;
        funcs[8] = IHook.previewSwapExactIn.selector;
        funcs[9] = IHook.previewSwapExactOut.selector;
        funcs[10] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[11] = IStandardExchangeIn.exchangeIn.selector;
        funcs[12] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[13] = IStandardExchangeOut.exchangeOut.selector;
        funcs[14] = this.getHookPermissions.selector;
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

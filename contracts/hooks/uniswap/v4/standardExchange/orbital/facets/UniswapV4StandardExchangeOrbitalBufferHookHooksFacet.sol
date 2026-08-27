// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookHooksFacet
 * @notice IHooks callbacks + product binding views + swap previews.
 */
contract UniswapV4StandardExchangeOrbitalBufferHookHooksFacet is
    UniswapV4StandardExchangeOrbitalBufferHookHooksTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookHooksFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](4);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4StandardExchangeOrbitalBufferHook).interfaceId;
        interfaces[2] = type(IUniswapV4SeBufferHook).interfaceId;
        interfaces[3] = type(IDetfReserveQuote).interfaceId;
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
        funcs[10] = IUniswapV4StandardExchangeOrbitalBufferHook.poolManager.selector;
        funcs[11] = IUniswapV4StandardExchangeOrbitalBufferHook.feeOracle.selector;
        funcs[12] = IUniswapV4StandardExchangeOrbitalBufferHook.token0.selector;
        funcs[13] = IUniswapV4StandardExchangeOrbitalBufferHook.token1.selector;
        funcs[14] = IUniswapV4StandardExchangeOrbitalBufferHook.token2.selector;
        funcs[15] = IUniswapV4StandardExchangeOrbitalBufferHook.standardExchange.selector;
        funcs[16] = IUniswapV4StandardExchangeOrbitalBufferHook.rateProvider.selector;
        funcs[17] = IUniswapV4StandardExchangeOrbitalBufferHook.isBuffered.selector;
        funcs[18] = IUniswapV4StandardExchangeOrbitalBufferHook.radius.selector;
        funcs[19] = IUniswapV4StandardExchangeOrbitalBufferHook.lSquared.selector;
    }

    function _b() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](25);
        funcs[0] = IUniswapV4StandardExchangeOrbitalBufferHook.rawReserve.selector;
        funcs[1] = IUniswapV4StandardExchangeOrbitalBufferHook.seBalance.selector;
        funcs[2] = IUniswapV4StandardExchangeOrbitalBufferHook.seClaim.selector;
        funcs[3] = IUniswapV4StandardExchangeOrbitalBufferHook.effectiveReserve.selector;
        funcs[4] = IUniswapV4StandardExchangeOrbitalBufferHook.effectiveReserves.selector;
        funcs[5] = IUniswapV4StandardExchangeOrbitalBufferHook.dexSwapFee.selector;
        funcs[6] = IUniswapV4StandardExchangeOrbitalBufferHook.usageFee.selector;
        funcs[7] = IUniswapV4StandardExchangeOrbitalBufferHook.feeTo.selector;
        funcs[8] = IUniswapV4StandardExchangeOrbitalBufferHook.kLast.selector;
        funcs[9] = IUniswapV4StandardExchangeOrbitalBufferHook.kLastMode.selector;
        funcs[10] = IUniswapV4StandardExchangeOrbitalBufferHook.permit2.selector;
        funcs[11] = IUniswapV4StandardExchangeOrbitalBufferHook.pairPoolTickSpacing.selector;
        funcs[12] = IUniswapV4StandardExchangeOrbitalBufferHook.pairPoolSqrtPriceX96.selector;
        funcs[13] = IUniswapV4StandardExchangeOrbitalBufferHook.isZapEligible.selector;
        funcs[14] = IUniswapV4SeBufferHook.previewSwapExactIn.selector;
        funcs[15] = IUniswapV4SeBufferHook.previewSwapExactOut.selector;
        funcs[16] = this.getHookPermissions.selector;
        funcs[17] = IUniswapV4SeBufferHook.tokens.selector;
        funcs[18] = IUniswapV4SeBufferHook.standardExchangeOf.selector;
        funcs[19] = IUniswapV4SeBufferHook.syntheticNumeraires.selector;
        funcs[20] = IUniswapV4SeBufferHook.requiredFirstBondTokens.selector;
        funcs[21] = IUniswapV4SeBufferHook.firstJoinMustBeFullBook.selector;
        funcs[22] = IUniswapV4SeBufferHook.isLive.selector;
        funcs[23] = IUniswapV4SeBufferHook.tradingFeeWad.selector;
        funcs[24] = IDetfReserveQuote.previewSynthetic.selector;
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

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeOrbitalBufferHookOwnerSwapTarget} from "../UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol";

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
    UniswapV4StandardExchangeOrbitalBufferHookOwnerSwapTarget,
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
        funcs = new bytes4[](50);
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
        funcs[16] = bytes4(keccak256("rateProvider(uint8)"));
        funcs[17] = IUniswapV4StandardExchangeOrbitalBufferHook.isBuffered.selector;
        funcs[18] = IUniswapV4StandardExchangeOrbitalBufferHook.lSquared.selector;
        funcs[19] = this.previewSwapAfterExchange.selector;
        funcs[20] = IUniswapV4StandardExchangeOrbitalBufferHook.rawReserve.selector;
        funcs[21] = IUniswapV4StandardExchangeOrbitalBufferHook.seBalance.selector;
        funcs[22] = IUniswapV4StandardExchangeOrbitalBufferHook.seClaim.selector;
        funcs[23] = IUniswapV4StandardExchangeOrbitalBufferHook.effectiveReserve.selector;
        funcs[24] = IUniswapV4StandardExchangeOrbitalBufferHook.effectiveReserves.selector;
        funcs[25] = IUniswapV4StandardExchangeOrbitalBufferHook.dexSwapFee.selector;
        funcs[26] = IUniswapV4StandardExchangeOrbitalBufferHook.usageFee.selector;
        funcs[27] = IUniswapV4StandardExchangeOrbitalBufferHook.feeTo.selector;
        funcs[28] = IUniswapV4StandardExchangeOrbitalBufferHook.kLast.selector;
        funcs[29] = IUniswapV4StandardExchangeOrbitalBufferHook.kLastMode.selector;
        funcs[30] = IUniswapV4StandardExchangeOrbitalBufferHook.permit2.selector;
        funcs[31] = IUniswapV4StandardExchangeOrbitalBufferHook.pairPoolTickSpacing.selector;
        funcs[32] = IUniswapV4StandardExchangeOrbitalBufferHook.pairPoolSqrtPriceX96.selector;
        funcs[33] = IUniswapV4StandardExchangeOrbitalBufferHook.isZapEligible.selector;
        funcs[34] = IUniswapV4SeBufferHook.previewSwapExactIn.selector;
        funcs[35] = IUniswapV4SeBufferHook.previewSwapExactOut.selector;
        funcs[36] = this.getHookPermissions.selector;
        funcs[37] = IUniswapV4SeBufferHook.tokens.selector;
        funcs[38] = IUniswapV4SeBufferHook.standardExchangeOf.selector;
        funcs[39] = IUniswapV4SeBufferHook.syntheticNumeraires.selector;
        funcs[40] = IUniswapV4SeBufferHook.requiredFirstBondTokens.selector;
        funcs[41] = IUniswapV4SeBufferHook.firstJoinMustBeFullBook.selector;
        funcs[42] = IUniswapV4SeBufferHook.isLive.selector;
        funcs[43] = IUniswapV4SeBufferHook.tradingFeeWad.selector;
        funcs[44] = IDetfReserveQuote.previewSynthetic.selector;
        funcs[45] = this.ownerOnlyLiquidity.selector;
        funcs[46] = IUniswapV4StandardExchangeOrbitalBufferHook.rateProviders.selector;
        funcs[47] = bytes4(keccak256("rateProvider(address)"));
        funcs[48] = IUniswapV4SeBufferHook.ownerSwapExactIn.selector;
        funcs[49] = IUniswapV4SeBufferHook.ownerSwapExactOut.selector;
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

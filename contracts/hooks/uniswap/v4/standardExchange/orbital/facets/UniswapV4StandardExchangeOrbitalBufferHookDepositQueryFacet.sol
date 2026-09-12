// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookClaimQuote} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet
 * @notice addLiquidity + depositSingle (zap-in) + previews.
 */
contract UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet is
    UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IUniswapV4StandardExchangeOrbitalBufferHook.previewAddLiquidity.selector;
        funcs[1] = IUniswapV4StandardExchangeOrbitalBufferHook.previewDepositSingle.selector;
        funcs[2] = IUniswapV4StandardExchangeOrbitalBufferHook.previewZapSplit.selector;
        funcs[3] = IUniswapV4StandardExchangeOrbitalBufferHook.previewDepositFlexible.selector;
        funcs[4] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[5] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[6] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[7] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4StandardExchangeOrbitalBufferHook.radius.selector;
        funcs[9] = this.previewJoinAfterDeposit.selector;
        funcs[10] = this.previewBondAfterDeposit.selector;
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

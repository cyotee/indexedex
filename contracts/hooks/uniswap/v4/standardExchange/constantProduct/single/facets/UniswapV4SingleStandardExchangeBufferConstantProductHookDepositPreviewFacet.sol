// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookClaimQuote} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet
/// @notice Diamond metadata and selector routing for CP deposit preview operations.
contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget,
    IFacet
{
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](10);
        funcs[0] = IHook.previewDeposit.selector;
        funcs[1] = IHook.previewDepositSingle.selector;
        funcs[2] = IHook.previewZapSplit.selector;
        funcs[3] = IHook.previewDepositWithSeShares.selector;
        funcs[4] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[5] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[6] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[7] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
        funcs[8] = IUniswapV4SeBufferHookClaimQuote.previewClaimAfterJoin.selector;
        funcs[9] = this.previewJoinAfterDeposit.selector;
    }

    /// @inheritdoc IFacet
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

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet
/// @notice Diamond metadata and selector routing for CP single-asset deposit operations.
contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget,
    IFacet
{
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IHook.depositSingle.selector;
        funcs[1] = IHook.depositSingleWithPermit2Signature.selector;
        funcs[2] = IHook.depositSingleWithPermit2Allowance.selector;
        funcs[3] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        funcs[4] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        funcs[5] = this.previewSwapAfterExchange.selector;
        funcs[6] = this.previewBondAfterDeposit.selector;
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

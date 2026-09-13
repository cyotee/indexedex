// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet
/// @notice Diamond metadata and selector routing for CP proportional deposit operations.
contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget,
    IFacet
{
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IHook.deposit.selector;
        funcs[1] = IHook.depositWithPermit2Signature.selector;
        funcs[2] = IHook.depositWithPermit2Allowance.selector;
        funcs[3] = IHook.depositWithSeShares.selector;
        funcs[4] = IUniswapV4SeBufferHook.joinProportional.selector;
        funcs[5] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
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

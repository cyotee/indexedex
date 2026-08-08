// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](11);
        funcs[0] = IHook.deposit.selector;
        funcs[1] = IHook.depositSingle.selector;
        funcs[2] = IHook.depositWithPermit2Signature.selector;
        funcs[3] = IHook.depositWithPermit2Allowance.selector;
        funcs[4] = IHook.depositSingleWithPermit2Signature.selector;
        funcs[5] = IHook.depositSingleWithPermit2Allowance.selector;
        funcs[6] = IHook.previewDeposit.selector;
        funcs[7] = IHook.previewDepositSingle.selector;
        funcs[8] = IHook.previewZapSplit.selector;
        funcs[9] = IHook.depositWithSeShares.selector;
        funcs[10] = IHook.previewDepositWithSeShares.selector;
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

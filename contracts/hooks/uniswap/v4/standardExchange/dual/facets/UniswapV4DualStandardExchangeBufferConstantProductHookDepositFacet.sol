// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

contract UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet is
    UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](19);
        funcs[0] = IHook.deposit.selector;
        funcs[1] = IHook.depositSingle.selector;
        funcs[2] = IHook.depositWithPermit2Signature.selector;
        funcs[3] = IHook.depositWithPermit2Allowance.selector;
        funcs[4] = IHook.depositSingleWithPermit2Signature.selector;
        funcs[5] = IHook.depositSingleWithPermit2Allowance.selector;
        funcs[6] = IHook.previewDeposit.selector;
        funcs[7] = IHook.previewDepositSingle.selector;
        funcs[8] = IHook.previewZapSplit.selector;
        funcs[9] = IHook.depositFlexible.selector;
        funcs[10] = IHook.previewDepositFlexible.selector;
        funcs[11] = IUniswapV4SeBufferHook.joinProportional.selector;
        funcs[12] = IUniswapV4SeBufferHook.previewJoinProportional.selector;
        funcs[13] = IUniswapV4SeBufferHook.joinUnbalanced.selector;
        funcs[14] = IUniswapV4SeBufferHook.previewJoinUnbalanced.selector;
        funcs[15] = IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector;
        funcs[16] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactIn.selector;
        funcs[17] = IUniswapV4SeBufferHook.joinSingleAssetExactOut.selector;
        funcs[18] = IUniswapV4SeBufferHook.previewJoinSingleAssetExactOut.selector;
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

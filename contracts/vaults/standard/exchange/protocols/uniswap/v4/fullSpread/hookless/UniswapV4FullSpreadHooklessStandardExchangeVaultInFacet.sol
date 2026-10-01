// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBinding} from "./interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultComponentBindings.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet is UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget, IFacet {
    constructor(address executionDelegate) UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget(executionDelegate) {}

    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4FullSpreadHooklessStandardExchangeVaultInFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[1] = type(IUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBinding).interfaceId;
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[2] = IUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBinding.UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.selector;
        funcs[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs[1] = IUnlockCallback.unlockCallback.selector;
    }

    function facetMetadata()
        external
        pure
        override
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}

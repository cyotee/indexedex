// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInDelegateExecutionBase} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";
import {UniswapV4FullSpreadHooklessStandardYieldExecutionTarget} from "./UniswapV4FullSpreadHooklessStandardYieldExecutionTarget.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiTarget.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet is UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiTarget, UniswapV4FullSpreadHooklessStandardYieldExecutionTarget, IFacet {
    constructor(address executionDelegate) UniswapV4FullSpreadHooklessStandardExchangeVaultInDelegateExecutionBase(executionDelegate) {}
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4FullSpreadHooklessStandardExchangeVaultInMultiFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeInMulti).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeInMulti.exchangeInManyToOne.selector;
        funcs = NativeStandardYieldSelectors._appendExecution(funcs);
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

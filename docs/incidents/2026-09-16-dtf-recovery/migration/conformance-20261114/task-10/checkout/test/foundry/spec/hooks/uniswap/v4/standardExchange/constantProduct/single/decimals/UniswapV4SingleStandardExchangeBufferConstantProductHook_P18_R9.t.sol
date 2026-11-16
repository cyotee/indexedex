// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

/// @notice Combo `P18_R9` is illegal under HDEC-7: CP raw/self-leg decimals must be 18.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_P18_R9 is TestBase {
    function test_HDEC7_rawTokenDecimals9_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.rawTokenDecimals = 9;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }
}

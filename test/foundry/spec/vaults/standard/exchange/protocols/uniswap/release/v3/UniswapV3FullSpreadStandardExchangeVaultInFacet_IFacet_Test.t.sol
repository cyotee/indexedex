// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {TransferredTestInput, IStandardExchangeOut, IStandardizedYield} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/TransferredTestInput.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultInFacet
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInFacet.sol";
import {
    TestBase_UniswapV3FullSpreadStandardExchangeVault
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultInFacet_IFacet_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault, TestBase_IFacet {
    function setUp() public override(TestBase_UniswapV3FullSpreadStandardExchangeVault, TestBase_IFacet) {
        TestBase_UniswapV3FullSpreadStandardExchangeVault.setUp();
        TestBase_IFacet.setUp();
    }
    function facetTestInstance() public view override returns (IFacet) { return uniswapV3StandardExchangeInFacet; }
    function controlFacetName() public pure override returns (string memory) { return type(UniswapV3FullSpreadStandardExchangeVaultInFacet).name; }
    function controlFacetInterfaces() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](3);
        values[0] = type(IStandardExchangeIn).interfaceId;
        values[1] = type(IUniswapV3MintCallback).interfaceId;
        values[2] = type(IUniswapV3SwapCallback).interfaceId;
    }
    function controlFacetFuncs() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](3);
        values[0] = IStandardExchangeIn.exchangeIn.selector;
        values[1] = IUniswapV3MintCallback.uniswapV3MintCallback.selector;
        values[2] = IUniswapV3SwapCallback.uniswapV3SwapCallback.selector;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {PreparedTestInput, IStandardExchangePretransfer, IStandardExchangeOut, IStandardizedYield} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/PreparedTestInput.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    UniswapV3StandardExchangeInFacetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeInFacetV2.sol";
import {
    TestBase_UniswapV3StandardExchangeV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchangeV2.sol";

contract UniswapV3StandardExchangeInFacet_IFacet_TestV2 is TestBase_UniswapV3StandardExchangeV2, TestBase_IFacet {
    function setUp() public override(TestBase_UniswapV3StandardExchangeV2, TestBase_IFacet) {
        TestBase_UniswapV3StandardExchangeV2.setUp();
        TestBase_IFacet.setUp();
    }
    function facetTestInstance() public view override returns (IFacet) { return uniswapV3StandardExchangeInFacet; }
    function controlFacetName() public pure override returns (string memory) { return type(UniswapV3StandardExchangeInFacetV2).name; }
    function controlFacetInterfaces() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](4);
        values[0] = type(IStandardExchangeIn).interfaceId;
        values[1] = type(IUniswapV3MintCallback).interfaceId;
        values[2] = type(IUniswapV3SwapCallback).interfaceId;
        values[3] = type(IStandardExchangePretransfer).interfaceId;
    }
    function controlFacetFuncs() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](4);
        values[0] = IStandardExchangeIn.exchangeIn.selector;
        values[1] = IUniswapV3MintCallback.uniswapV3MintCallback.selector;
        values[2] = IUniswapV3SwapCallback.uniswapV3SwapCallback.selector;
        values[3] = IStandardExchangePretransfer.preparePretransfer.selector;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutFacetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeOutFacetV2.sol";
import {
    TestBase_UniswapV3StandardExchangeV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchangeV2.sol";

contract UniswapV3StandardExchangeOutFacet_IFacet_TestV2 is TestBase_UniswapV3StandardExchangeV2, TestBase_IFacet {
    function setUp() public override(TestBase_UniswapV3StandardExchangeV2, TestBase_IFacet) {
        TestBase_UniswapV3StandardExchangeV2.setUp();
        TestBase_IFacet.setUp();
    }
    function facetTestInstance() public view override returns (IFacet) { return uniswapV3StandardExchangeOutFacet; }
    function controlFacetName() public pure override returns (string memory) { return type(UniswapV3StandardExchangeOutFacetV2).name; }
    function controlFacetInterfaces() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](1);
        values[0] = type(IStandardExchangeOut).interfaceId;
    }
    function controlFacetFuncs() public pure override returns (bytes4[] memory values) {
        values = new bytes4[](1);
        values[0] = IStandardExchangeOut.exchangeOut.selector;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {PreparedTestInput, IStandardExchangePretransfer, IStandardExchangeOut, IStandardizedYield} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/PreparedTestInput.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeInFacetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInFacetV2.sol";
import {
    UniswapV4_Component_FactoryServiceV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4_Component_FactoryServiceV2.sol";

contract UniswapV4StandardExchangeInFacet_IFacet_TestV2 is CraneTest, TestBase_IFacet {
    using UniswapV4_Component_FactoryServiceV2 for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV4StandardExchangeInFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeInFacetV2).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](2);
        controlInterfaces[1] = type(IStandardExchangePretransfer).interfaceId;
        controlInterfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](3);
        controlFuncs[2] = IStandardExchangePretransfer.preparePretransfer.selector;
        controlFuncs[0] = IStandardExchangeIn.exchangeIn.selector;
        controlFuncs[1] = IUnlockCallback.unlockCallback.selector;
    }
}

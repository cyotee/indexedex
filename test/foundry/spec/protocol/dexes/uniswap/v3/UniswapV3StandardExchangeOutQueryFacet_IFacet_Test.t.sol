// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutQueryFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutQueryFacet.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";

contract UniswapV3StandardExchangeOutQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployUniswapV3StandardExchangeOutQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV3StandardExchangeOutQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](2);
        controlInterfaces[0] = type(IStandardExchangeOut).interfaceId;
        controlInterfaces[1] = type(IStandardizedYield).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](17);
        controlFuncs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        controlFuncs[1] = IStandardizedYield.deposit.selector;
        controlFuncs[2] = IStandardizedYield.redeem.selector;
        controlFuncs[3] = IStandardizedYield.exchangeRate.selector;
        controlFuncs[4] = IStandardizedYield.yieldToken.selector;
        controlFuncs[5] = IStandardizedYield.assetInfo.selector;
        controlFuncs[6] = IStandardizedYield.getTokensIn.selector;
        controlFuncs[7] = IStandardizedYield.getTokensOut.selector;
        controlFuncs[8] = IStandardizedYield.isValidTokenIn.selector;
        controlFuncs[9] = IStandardizedYield.isValidTokenOut.selector;
        controlFuncs[10] = IStandardizedYield.previewDeposit.selector;
        controlFuncs[11] = IStandardizedYield.previewRedeem.selector;
        controlFuncs[12] = IStandardizedYield.getRewardTokens.selector;
        controlFuncs[13] = IStandardizedYield.accruedRewards.selector;
        controlFuncs[14] = IStandardizedYield.rewardIndexesCurrent.selector;
        controlFuncs[15] = IStandardizedYield.rewardIndexesStored.selector;
        controlFuncs[16] = IStandardizedYield.claimRewards.selector;
    }
}

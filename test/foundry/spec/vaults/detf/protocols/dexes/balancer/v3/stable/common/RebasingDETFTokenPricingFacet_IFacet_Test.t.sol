// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {TestBase_IFacet} from '@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol';
import {CraneTest} from '@crane/contracts/test/CraneTest.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {ComposedStableCommonDetf_Facet_FactoryService} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol';
import {RebasingDETFTokenPricingFacet} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenPricingFacet.sol';

contract RebasingDETFTokenPricingFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using ComposedStableCommonDetf_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployRebasingDetfTokenPricingFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(RebasingDETFTokenPricingFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IDETF).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](10);
        controlFuncs[0] = IDETF.bondNftVault.selector;
        controlFuncs[1] = IDETF.detfNFTId.selector;
        controlFuncs[2] = IDETF.rebasingDetfToken.selector;
        controlFuncs[3] = IDETF.reservePool.selector;
        controlFuncs[4] = IDETF.previewRebasingDetfTokenReserveBpt.selector;
        controlFuncs[5] = IDETF.previewRebasingDetfTokenEthValue.selector;
        controlFuncs[6] = IDETF.previewStablePoolBptEthValue.selector;
        controlFuncs[7] = IDETF.previewCommonPoolBptEthValue.selector;
        controlFuncs[8] = IDETF.syntheticDetfEthPrice.selector;
        controlFuncs[9] = IDETF.previewReservePoolDecomposition.selector;
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {SingleVaultDetfExchangeInFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInFacet.sol";
import {SingleVaultDetf_Facet_FactoryService} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";

contract SingleVaultDetfExchangeInFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deploySingleVaultDetfExchangeInFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(SingleVaultDetfExchangeInFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](2);
        controlInterfaces[0] = type(IStandardExchangeIn).interfaceId;
        controlInterfaces[1] = type(IProtocolDETF).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](2);
        controlFuncs[0] = IStandardExchangeIn.exchangeIn.selector;
        controlFuncs[1] = IProtocolDETF.mintWithRateAsset.selector;
    }
}
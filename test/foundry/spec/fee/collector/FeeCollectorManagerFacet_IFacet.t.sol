// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {FeeCollectorManagerFacet} from "contracts/fee/collector/FeeCollectorManagerFacet.sol";

/**
 * @title FeeCollectorManagerFacet_IFacet_Test
 * @notice Validates FeeCollectorManagerFacet exposes correct interfaces and selectors
 */
contract FeeCollectorManagerFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using FeeCollectorFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployFeeCollectorManagerFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(FeeCollectorManagerFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IFeeCollectorManager).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](3);
        controlFuncs[0] = IFeeCollectorManager.syncReserve.selector;
        controlFuncs[1] = IFeeCollectorManager.syncReserves.selector;
        controlFuncs[2] = IFeeCollectorManager.pullFee.selector;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IFeeCollectorSingleTokenPush} from "contracts/interfaces/IFeeCollectorSingleTokenPush.sol";
import {FeeCollectorSingleTokenPushFacet} from "contracts/fee/collector/FeeCollectorSingleTokenPushFacet.sol";
import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";

/**
 * @title FeeCollectorSingleTokenPushFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for fee collector single-token push.
 */
contract FeeCollectorSingleTokenPushFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using FeeCollectorFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployFeeCollectorSingleTokenPushFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(FeeCollectorSingleTokenPushFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IFeeCollectorSingleTokenPush).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](1);
        controlFuncs[0] = IFeeCollectorSingleTokenPush.pushSingleTokenFee.selector;
    }
}

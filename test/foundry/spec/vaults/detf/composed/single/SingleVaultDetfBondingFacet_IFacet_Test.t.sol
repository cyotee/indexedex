// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {ISingleVaultDetfBonding} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";
import {SingleVaultDetfBondingFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingFacet.sol";
import {SingleVaultDetf_Facet_FactoryService} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";

contract SingleVaultDetfBondingFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deploySingleVaultDetfBondingFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(SingleVaultDetfBondingFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(ISingleVaultDetfBonding).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](11);
        controlFuncs[0] = ISingleVaultDetfBonding.acceptedBondTokens.selector;
        controlFuncs[1] = ISingleVaultDetfBonding.isAcceptedBondToken.selector;
        controlFuncs[2] = ISingleVaultDetfBonding.setRebasingClaimToken.selector;
        controlFuncs[3] = ISingleVaultDetfBonding.bond.selector;
        controlFuncs[4] = ISingleVaultDetfBonding.bondWithPosition.selector;
        controlFuncs[5] = ISingleVaultDetfBonding.captureSeigniorage.selector;
        controlFuncs[6] = ISingleVaultDetfBonding.sellNFT.selector;
        controlFuncs[7] = ISingleVaultDetfBonding.donate.selector;
        controlFuncs[8] = IProtocolDETF.claimLiquidity.selector;
        controlFuncs[9] = IProtocolDETF.bridgeRebasingClaim.selector;
        controlFuncs[10] = IProtocolDETF.receiveBridgedPair.selector;
    }
}
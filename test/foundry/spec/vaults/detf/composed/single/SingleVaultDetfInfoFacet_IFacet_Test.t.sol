// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {SingleVaultDetfInfoFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfInfoFacet.sol";
import {SingleVaultDetf_Facet_FactoryService} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";

contract SingleVaultDetfInfoFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deploySingleVaultDetfInfoFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(SingleVaultDetfInfoFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](2);
        controlInterfaces[0] = type(IDetf).interfaceId;
        controlInterfaces[1] = type(ISingleVaultDetf).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](16);
        controlFuncs[0] = IDetf.detfToken.selector;
        controlFuncs[1] = IDetf.pairToken.selector;
        controlFuncs[2] = IDetf.rebasingClaimToken.selector;
        controlFuncs[3] = IDetf.rateAsset.selector;
        controlFuncs[4] = IDetf.detfNFTVault.selector;
        controlFuncs[5] = IDetf.underlyingVault.selector;
        controlFuncs[6] = IDetf.reservePool.selector;
        controlFuncs[7] = IDetf.detfNFTId.selector;
        controlFuncs[8] = IDetf.syntheticPrice.selector;
        controlFuncs[9] = IDetf.mintThreshold.selector;
        controlFuncs[10] = IDetf.burnThreshold.selector;
        controlFuncs[11] = IDetf.thresholdMode.selector;
        controlFuncs[12] = IDetf.isMintingAllowed.selector;
        controlFuncs[13] = IDetf.isBurningAllowed.selector;
        controlFuncs[14] = ISingleVaultDetf.vaultRateProvider.selector;
        controlFuncs[15] = ISingleVaultDetf.reservePoolIndexes.selector;
    }
}

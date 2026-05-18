// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {SingleVaultDetfExchangeInQueryFacet} from "contracts/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryFacet.sol";
import {SingleVaultDetf_Facet_FactoryService} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";

contract SingleVaultDetfExchangeInQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deploySingleVaultDetfExchangeInQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(SingleVaultDetfExchangeInQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](4);
        controlInterfaces[0] = type(IStandardExchangeIn).interfaceId;
        controlInterfaces[1] = type(IStandardExchangeOut).interfaceId;
        controlInterfaces[2] = type(IProtocolDETF).interfaceId;
        controlInterfaces[3] = type(ISingleVaultDetf).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](21);
        controlFuncs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        controlFuncs[1] = IStandardExchangeOut.previewExchangeOut.selector;
        controlFuncs[2] = IProtocolDETF.chirToken.selector;
        controlFuncs[3] = IProtocolDETF.richToken.selector;
        controlFuncs[4] = IProtocolDETF.richirToken.selector;
        controlFuncs[5] = IProtocolDETF.wethToken.selector;
        controlFuncs[6] = IProtocolDETF.protocolNFTVault.selector;
        controlFuncs[7] = IProtocolDETF.chirWethVault.selector;
        controlFuncs[8] = IProtocolDETF.richChirVault.selector;
        controlFuncs[9] = IProtocolDETF.reservePool.selector;
        controlFuncs[10] = IProtocolDETF.protocolNFTId.selector;
        controlFuncs[11] = IProtocolDETF.syntheticPrice.selector;
        controlFuncs[12] = IProtocolDETF.mintThreshold.selector;
        controlFuncs[13] = IProtocolDETF.burnThreshold.selector;
        controlFuncs[14] = IProtocolDETF.isMintingAllowed.selector;
        controlFuncs[15] = IProtocolDETF.isBurningAllowed.selector;
        controlFuncs[16] = ISingleVaultDetf.wethRichVault.selector;
        controlFuncs[17] = ISingleVaultDetf.vaultRateProvider.selector;
        controlFuncs[18] = ISingleVaultDetf.reservePoolIndexes.selector;
        controlFuncs[19] = IProtocolDETF.previewClaimLiquidity.selector;
        controlFuncs[20] = IProtocolDETF.previewBridgeRichir.selector;
    }
}
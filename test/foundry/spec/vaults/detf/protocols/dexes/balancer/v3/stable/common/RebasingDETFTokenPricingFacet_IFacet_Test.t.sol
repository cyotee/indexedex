// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    ComposedStableCommonDetf_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol";
import {
    RebasingDETFTokenPricingFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenPricingFacet.sol";

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
        controlInterfaces[0] = type(IComposedStableCommonDetfInfo).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](25);
        controlFuncs[0] = IComposedStableCommonDetfInfo.reservePool.selector;
        controlFuncs[1] = IComposedStableCommonDetfInfo.bondNftVault.selector;
        controlFuncs[2] = IComposedStableCommonDetfInfo.rebasingClaimToken.selector;
        controlFuncs[3] = IComposedStableCommonDetfInfo.syntheticDetfEthPrice.selector;
        controlFuncs[4] = IComposedStableCommonDetfInfo.previewStablePoolBptEthValue.selector;
        controlFuncs[5] = IComposedStableCommonDetfInfo.previewCommonPoolBptEthValue.selector;
        controlFuncs[6] = IComposedStableCommonDetfInfo.previewReservePoolDecomposition.selector;
        controlFuncs[7] = IComposedStableCommonDetfInfo.mintThreshold.selector;
        controlFuncs[8] = IComposedStableCommonDetfInfo.burnThreshold.selector;
        controlFuncs[9] = IComposedStableCommonDetfInfo.isMintingAllowed.selector;
        controlFuncs[10] = IComposedStableCommonDetfInfo.isBurningAllowed.selector;
        controlFuncs[11] = IComposedStableCommonDetfInfo.isReserveLive.selector;
        controlFuncs[12] = IComposedStableCommonDetfInfo.epochAnchor.selector;
        controlFuncs[13] = IComposedStableCommonDetfInfo.lastExpansionTimestamp.selector;
        controlFuncs[14] = IComposedStableCommonDetfInfo.expansionClosureRatePerSecond.selector;
        controlFuncs[15] = IComposedStableCommonDetfInfo.pendingExpansionDetf.selector;
        controlFuncs[16] = IDETFStandardizedYield.rawSY.selector;
        controlFuncs[17] = IDETFStandardizedYield.stakingSY.selector;
        controlFuncs[18] = IComposedStableCommonDetfInfo.tokensIn.selector;
        controlFuncs[19] = IComposedStableCommonDetfInfo.tokensOut.selector;
        controlFuncs[20] = IDETFFundedRewards.synchronizeRewards.selector;
        controlFuncs[21] = IDETFStakingPreview.previewStakingGonsPerUnit.selector;
        controlFuncs[22] = IStandardExchangeIn.previewExchangeIn.selector;
        controlFuncs[23] = bytes4(keccak256("previewJoinDonatedCapital(address,uint256)"));
        controlFuncs[24] = IComposedStableCommonDetfInfo.openingConfiguration.selector;
    }
}

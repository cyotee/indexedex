// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@crane/contracts/interfaces/IERC20Metadata.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {TestBase_IFacet} from '@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol';
import {CraneTest} from '@crane/contracts/test/CraneTest.sol';

import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {
    RebasingDETFToken_Facet_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFToken_Facet_FactoryService.sol';
import {RebasingDETFTokenFacet} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenFacet.sol';

contract RebasingDETFTokenFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using RebasingDETFToken_Facet_FactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployRebasingDETFTokenFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(RebasingDETFTokenFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](5);
        controlInterfaces[0] = type(IERC20).interfaceId;
        controlInterfaces[1] = type(IERC20Metadata).interfaceId;
        controlInterfaces[2] = type(IRebasingClaimToken).interfaceId;
        controlInterfaces[3] = type(IStandardExchangeIn).interfaceId;
        controlInterfaces[4] = type(IStandardExchangeOut).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](26);
        controlFuncs[0] = IERC20.totalSupply.selector;
        controlFuncs[1] = IERC20.balanceOf.selector;
        controlFuncs[2] = IERC20.transfer.selector;
        controlFuncs[3] = IERC20.allowance.selector;
        controlFuncs[4] = IERC20.approve.selector;
        controlFuncs[5] = IERC20.transferFrom.selector;
        controlFuncs[6] = IERC20Metadata.name.selector;
        controlFuncs[7] = IERC20Metadata.symbol.selector;
        controlFuncs[8] = IERC20Metadata.decimals.selector;
        controlFuncs[9] = IRebasingClaimToken.sharesOf.selector;
        controlFuncs[10] = IRebasingClaimToken.totalShares.selector;
        controlFuncs[11] = IRebasingClaimToken.redemptionRate.selector;
        controlFuncs[12] = IRebasingClaimToken.detf.selector;
        controlFuncs[13] = IRebasingClaimToken.setDetf.selector;
        controlFuncs[14] = IRebasingClaimToken.detfNFTId.selector;
        controlFuncs[15] = IRebasingClaimToken.rateAsset.selector;
        controlFuncs[16] = IRebasingClaimToken.convertToShares.selector;
        controlFuncs[17] = IRebasingClaimToken.convertToClaim.selector;
        controlFuncs[18] = IRebasingClaimToken.previewRedeem.selector;
        controlFuncs[19] = IRebasingClaimToken.mintFromNFTSale.selector;
        controlFuncs[20] = IRebasingClaimToken.redeem.selector;
        controlFuncs[21] = IRebasingClaimToken.burnShares.selector;
        controlFuncs[22] = IStandardExchangeIn.previewExchangeIn.selector;
        controlFuncs[23] = IStandardExchangeIn.exchangeIn.selector;
        controlFuncs[24] = IStandardExchangeOut.previewExchangeOut.selector;
        controlFuncs[25] = IStandardExchangeOut.exchangeOut.selector;
    }
}
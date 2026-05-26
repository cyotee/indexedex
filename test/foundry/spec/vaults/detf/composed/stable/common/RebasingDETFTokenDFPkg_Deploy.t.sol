// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@crane/contracts/interfaces/IERC20Metadata.sol';
import {IERC20Permit} from '@crane/contracts/interfaces/IERC20Permit.sol';
import {IERC5267} from '@crane/contracts/interfaces/IERC5267.sol';
import {IMultiStepOwnable} from '@crane/contracts/interfaces/IMultiStepOwnable.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IProtocolNFTVault} from 'contracts/interfaces/IProtocolNFTVault.sol';
import {IRICHIR} from 'contracts/interfaces/IRICHIR.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {TestBase_VaultComponents} from 'contracts/vaults/TestBase_VaultComponents.sol';
import {
    ComposedStableCommonDetf_Component_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol';
import {
    IRebasingDETFTokenDFPkg
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenDFPkg.sol';
import {
    RebasingDETFToken_Facet_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFToken_Facet_FactoryService.sol';
import {
    RebasingDETFToken_Pkg_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFToken_Pkg_FactoryService.sol';

contract RebasingDETFTokenDFPkg_Deploy_Test is TestBase_VaultComponents {
    using RebasingDETFToken_Facet_FactoryService for ICreate3FactoryProxy;
    using RebasingDETFToken_Pkg_FactoryService for ICreate3FactoryProxy;

    IFacet internal rebasingDetfTokenFacet;
    IRebasingDETFTokenDFPkg internal pkg;

    function setUp() public override {
        super.setUp();

        rebasingDetfTokenFacet = create3Factory.deployRebasingDETFTokenFacet();

        pkg = create3Factory.deployRebasingDETFTokenDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildRebasingDetfTokenPkgInit(
                ComposedStableCommonDetf_Component_FactoryService.RebasingDetfTokenFacets({
                    erc20Facet: erc20Facet,
                    erc5267Facet: erc5267Facet,
                    erc2612Facet: erc2612Facet,
                    multiStepOwnableFacet: multiStepOwnableFacet,
                    rebasingDetfTokenFacet: rebasingDetfTokenFacet
                }),
                diamondPackageFactory
            )
        );
    }

    function test_deployToken_success() public {
        IERC20 weth = IERC20(makeAddr('weth'));

        address tokenAddr = pkg.deployToken(IDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), weth, 7, owner);

        assertGt(tokenAddr.code.length, 0, 'rebasing token proxy not deployed');
        assertEq(IRICHIR(tokenAddr).protocolDETF(), address(0xBEEF), 'detf mismatch');
        assertEq(IRICHIR(tokenAddr).protocolNFTId(), 7, 'protocol nft id mismatch');
    }

    function test_deployToken_returnsExisting_onDuplicateSalt() public {
        IERC20 weth = IERC20(makeAddr('weth'));

        address tokenAddr1 = pkg.deployToken(IDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), weth, 7, owner);
        address tokenAddr2 = pkg.deployToken(IDETF(address(0xBEEF)), IProtocolNFTVault(address(0xCAFE)), weth, 7, owner);

        assertEq(tokenAddr2, tokenAddr1, 'expected existing deployment');
        assertGt(tokenAddr2.code.length, 0, 'rebasing token proxy missing');
    }

    function test_packageMetadata_includesStandardExchangeInterfaces() public view {
        bytes4[] memory interfaces = pkg.facetInterfaces();

        assertEq(interfaces.length, 8, 'unexpected interface count');
        assertEq(interfaces[0], type(IERC20).interfaceId, 'missing IERC20');
        assertEq(interfaces[1], type(IERC20Metadata).interfaceId, 'missing IERC20Metadata');
        assertEq(interfaces[2], type(IERC20Permit).interfaceId, 'missing IERC20Permit');
        assertEq(interfaces[3], type(IERC5267).interfaceId, 'missing IERC5267');
        assertEq(interfaces[4], type(IMultiStepOwnable).interfaceId, 'missing IMultiStepOwnable');
        assertEq(interfaces[5], type(IRICHIR).interfaceId, 'missing IRICHIR');
        assertEq(interfaces[6], type(IStandardExchangeIn).interfaceId, 'missing IStandardExchangeIn');
        assertEq(interfaces[7], type(IStandardExchangeOut).interfaceId, 'missing IStandardExchangeOut');
    }
}
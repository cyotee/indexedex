// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {IStablePool} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {IWeightedPool} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardVaultPkg} from 'contracts/interfaces/IStandardVaultPkg.sol';
import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {IVaultRegistryVaultQuery} from 'contracts/interfaces/IVaultRegistryVaultQuery.sol';
import {TestBase_VaultComponents} from 'contracts/vaults/TestBase_VaultComponents.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';
import {
    ComposedStableCommonDetf_Component_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol';
import {
    IComposedStableCommonDetfDFPkg
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfDFPkg.sol';
import {
    ComposedStableCommonDetf_Facet_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol';
import {
    ComposedStableCommonDetf_Pkg_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Pkg_FactoryService.sol';
import {ThresholdMode} from 'contracts/vaults/detf/common/core/DETFThresholdPolicy.sol';
import {
    IComposedStableCommonDetfInfo
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol';

contract ComposedStableCommonDetfDFPkg_Deploy_Test is TestBase_VaultComponents {
    using ComposedStableCommonDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using ComposedStableCommonDetf_Pkg_FactoryService for IVaultRegistryDeployment;

    IFacet internal exchangeInFacet;
    IFacet internal bondingFacet;
    IFacet internal exchangeOutQueryFacet;
    IFacet internal pricingFacet;
    IComposedStableCommonDetfDFPkg internal pkg;

    function setUp() public override {
        super.setUp();

        bondingFacet = create3Factory.deployComposedStableCommonDetfBondingFacet();
        exchangeInFacet = create3Factory.deployComposedStableCommonDetfExchangeInFacet();
        exchangeOutQueryFacet = create3Factory.deployComposedStableCommonDetfExchangeOutQueryFacet();
        pricingFacet = create3Factory.deployRebasingDetfTokenPricingFacet();

        ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfFacets memory facets =
            ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfFacets({
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                bondingFacet: bondingFacet,
                exchangeInFacet: exchangeInFacet,
                exchangeOutQueryFacet: exchangeOutQueryFacet,
                pricingFacet: pricingFacet
            });

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildPkgInit(
                facets,
                ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfInfra({
                    vaultRegistryDeployment: indexedexManager
                })
            )
        );
        vm.stopPrank();
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces_, address[] memory facets_) = pkg.packageMetadata();

        assertEq(name_, 'ComposedStableCommonDetfDFPkg', 'package name');
        assertEq(interfaces_.length, 7, 'interface count');
        assertEq(facets_.length, 6, 'facet count');
        assertEq(facets_[0], address(multiAssetBasicVaultFacet), 'basic vault facet');
        assertEq(facets_[1], address(multiAssetStandardVaultFacet), 'standard vault facet');
        assertEq(facets_[2], address(bondingFacet), 'bonding facet');
        assertEq(facets_[3], address(exchangeInFacet), 'exchange-in facet');
        assertEq(facets_[4], address(exchangeOutQueryFacet), 'exchange-out query facet');
        assertEq(facets_[5], address(pricingFacet), 'pricing facet');
        assertEq(interfaces_[6], type(IComposedStableCommonDetfInfo).interfaceId, 'threshold info interface');
    }

    function _buildPkgArgs(IWeightedPool reservePool_) internal returns (IComposedStableCommonDetfDFPkg.PkgArgs memory) {
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes = new ComposedStableCommonDetfRepo.RouteConfig[](0);

        return ComposedStableCommonDetf_Component_FactoryService.buildPkgArgs(
            ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfPricingConfig({
                reservePool: reservePool_,
                bondNftVault: IDETFNFTVault(makeAddr('bondNftVault')),
                rebasingDetfToken: IRebasingClaimToken(makeAddr('rebasingDetfToken')),
                detfToken: IERC20(makeAddr('detfToken')),
                stablePoolBpt: IERC20(makeAddr('stablePoolBpt')),
                commonPoolBpt: IERC20(makeAddr('commonPoolBpt')),
                rateAsset: IERC20(makeAddr('rateAsset')),
                stablePoolExitPricer: IStandardExchangeIn(makeAddr('stablePricer')),
                commonPoolExitPricer: IStandardExchangeIn(makeAddr('commonPricer')),
                permit2: IPermit2(makeAddr('permit2')),
                balancerV3Router: IBalancerV3StandardExchangeRouterProxy(makeAddr('balancerV3Router')),
                stablePool: IStablePool(makeAddr('stablePool')),
                commonPool: IStablePool(makeAddr('commonPool')),
                reservePoolEntryRouter: IStandardExchangeIn(makeAddr('reservePoolEntryRouter')),
                detfIndex: 0,
                stablePoolBptIndex: 1,
                commonPoolBptIndex: 2,
                mintThreshold: 0,
                burnThreshold: 0,
                routes: routes,
                thresholdMode: ThresholdMode.Policy,
                expansionClosureRatePerSecond: 0,
                expansionCatchUpMaxSeconds: 0,
                expansionCatchUpCapBps: 0,
                creator: address(0)
            })
        );
    }

    function test_deployVault_initializesReservePoolReference() public {
        IWeightedPool reservePool = IWeightedPool(makeAddr('reservePool'));
        IComposedStableCommonDetfDFPkg.PkgArgs memory pkgArgs = _buildPkgArgs(reservePool);

        vm.startPrank(owner);
        address vault = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(pkgArgs)
        );
        vm.stopPrank();

        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(vault), 'vault registered');
        assertTrue(IComposedStableCommonDetfBonding(vault).isAcceptedBondToken(IERC20(makeAddr('detfToken'))) == false, 'bonding facet deployed');
        assertEq(IDETF(vault).bondNftVault(), address(pkgArgs.bondNftVault), 'bond nft vault initialized');
        assertEq(IDETF(vault).detfNFTId(), 0, 'protocol nft id defaults to zero without initialized bond nft');
        assertEq(IDETF(vault).reservePool(), address(reservePool), 'reserve pool initialized');
        assertEq(IDETF(vault).rebasingDetfToken(), address(pkgArgs.rebasingDetfToken), 'rebasing token initialized');
    }
}
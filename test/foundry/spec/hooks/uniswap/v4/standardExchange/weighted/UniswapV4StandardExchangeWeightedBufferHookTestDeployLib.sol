// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";

/// @dev External lib to keep concrete test contracts under via_ir stack limits.
library UniswapV4StandardExchangeWeightedBufferHookTestDeployLib {
    function deployFactoryAndPackage(
        ICreate3FactoryProxy create3Factory,
        address owner,
        address indexedexManager,
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet multiAssetBasicVaultFacet,
        IFacet multiAssetStandardVaultFacet
    )
        external
        returns (
            IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
            IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg
        )
    {
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );
        // caller must prank owner for setHookDiamondPackageFactory + deployPackage
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(indexedexManager),
            owner,
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(indexedexManager),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(indexedexManager),
                liquidityFacet: PkgFactory.deployLiquidityFacet(create3Factory),
                seFacet: PkgFactory.deploySeFacet(create3Factory),
                hooksFacet: PkgFactory.deployHooksFacet(create3Factory),
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            keccak256(abi.encode(type(IUniswapV4StandardExchangeWeightedBufferHookPackage).name, "v1"))
        );
    }

    function deployHookInstance(
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args
    ) external returns (address hook) {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
    }
}

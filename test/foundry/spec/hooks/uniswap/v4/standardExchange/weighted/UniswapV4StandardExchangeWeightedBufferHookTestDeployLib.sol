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
    /// @dev Packed vault-component facets for package deploy (stack-safe under legacy codegen).
    struct VaultFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

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
        VaultFacets memory vf;
        vf.erc20Facet = erc20Facet;
        vf.erc5267Facet = erc5267Facet;
        vf.erc2612Facet = erc2612Facet;
        vf.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        vf.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        return _deployFactoryAndPackage(create3Factory, owner, indexedexManager, vf);
    }

    function _deployFactoryAndPackage(
        ICreate3FactoryProxy create3Factory,
        address owner,
        address indexedexManager,
        VaultFacets memory vf
    )
        private
        returns (
            IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
            IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg
        )
    {
        hookFactory = _deployHookFactory(create3Factory);
        hookPkg = _deployPackage(create3Factory, owner, indexedexManager, vf);
    }

    function _deployHookFactory(ICreate3FactoryProxy create3Factory)
        private
        returns (IUniswapV4HookDiamondPackageCallBackFactory hookFactory)
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
    }

    function _deployPackage(
        ICreate3FactoryProxy create3Factory,
        address owner,
        address indexedexManager,
        VaultFacets memory vf
    ) private returns (IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg) {
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgInit memory init =
            _buildPkgInit(create3Factory, indexedexManager, vf);
        // caller must prank owner for setHookDiamondPackageFactory + deployPackage
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(indexedexManager),
            owner,
            init,
            keccak256(abi.encode(type(IUniswapV4StandardExchangeWeightedBufferHookPackage).name, "v1"))
        );
    }

    function _buildPkgInit(
        ICreate3FactoryProxy create3Factory,
        address indexedexManager,
        VaultFacets memory vf
    )
        private
        returns (IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgInit memory init)
    {
        init.vaultRegistryDeployment = IVaultRegistryDeployment(indexedexManager);
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(indexedexManager);
        init.liquidityFacet = PkgFactory.deployLiquidityFacet(create3Factory);
        init.seFacet = PkgFactory.deploySeFacet(create3Factory);
        init.hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        init.erc20Facet = vf.erc20Facet;
        init.erc5267Facet = vf.erc5267Facet;
        init.erc2612Facet = vf.erc2612Facet;
        init.multiAssetBasicVaultFacet = vf.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = vf.multiAssetStandardVaultFacet;
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

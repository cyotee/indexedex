// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

// Balancer V3 facets from Crane

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

/**
 * @title BalancerV3ConstantProductPool_FactoryService
 * @notice Factory service for deploying Balancer V3 Constant Product Pool components via CREATE3.
 * @dev Provides deterministic deployment of facets and packages.
 *      NOTE: Some facets (DefaultPoolInfo, SwapFeeBounds, UnbalancedLiquidityBounds) must be deployed
 *      externally as they are not currently in the active Crane contracts directory.
 */
library BalancerV3ConstantProductPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBalancerV3VaultAwareFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3VaultAwareFacet.sol:BalancerV3VaultAwareFacet"), abi.encode("BalancerV3VaultAwareFacet")._hash()
        );
        vm.label(address(instance), "BalancerV3VaultAwareFacet");
    }

    function deployBalancerV3PoolTokenFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BetterBalancerV3PoolTokenFacet.sol:BalancerV3PoolTokenFacet"), abi.encode("BalancerV3PoolTokenFacet")._hash()
        );
        vm.label(address(instance), "BalancerV3PoolTokenFacet");
    }

    function deployBalancerV3AuthenticationFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3AuthenticationFacet.sol:BalancerV3AuthenticationFacet"),
            abi.encode("BalancerV3AuthenticationFacet")._hash()
        );
        vm.label(address(instance), "BalancerV3AuthenticationFacet");
    }

    function deployBalancerV3ConstantProductPoolFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3ConstantProductPoolFacet.sol:BalancerV3ConstantProductPoolFacet"),
            abi.encode("BalancerV3ConstantProductPoolFacet")._hash()
        );
        vm.label(address(instance), "BalancerV3ConstantProductPoolFacet");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Package Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBalancerV3ConstantProductPoolStandardVaultPkg(
        IVaultRegistryDeployment vaultRegistry,
        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit
    ) internal returns (IBalancerV3ConstantProductPoolStandardVaultPkg instance) {
        instance = IBalancerV3ConstantProductPoolStandardVaultPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("BalancerV3ConstantProductPoolStandardVaultPkg.sol:BalancerV3ConstantProductPoolStandardVaultPkg"),
                    abi.encode(pkgInit),
                    abi.encode("BalancerV3ConstantProductPoolStandardVaultPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "BalancerV3ConstantProductPoolStandardVaultPkg");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    function buildBalancerV3ConstantProductPoolPkgInit(
        IFacet basicVaultFacet,
        IFacet standardVaultFacet,
        IFacet balancerV3VaultAwareFacet,
        IFacet betterBalancerV3PoolTokenFacet,
        IFacet defaultPoolInfoFacet,
        IFacet standardSwapFeePercentageBoundsFacet,
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet,
        IFacet balancerV3AuthenticationFacet,
        IFacet balancerV3ConstProdPoolFacet,
        IVaultRegistryDeployment vaultRegistry,
        IVaultFeeOracleQuery vaultFeeOracle,
        IVault balancerV3Vault,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal pure returns (IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit) {
        pkgInit = IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit({
            basicVaultFacet: basicVaultFacet,
            standardVaultFacet: standardVaultFacet,
            balancerV3VaultAwareFacet: balancerV3VaultAwareFacet,
            betterBalancerV3PoolTokenFacet: betterBalancerV3PoolTokenFacet,
            defaultPoolInfoFacet: defaultPoolInfoFacet,
            standardSwapFeePercentageBoundsFacet: standardSwapFeePercentageBoundsFacet,
            unbalancedLiquidityInvariantRatioBoundsFacet: unbalancedLiquidityInvariantRatioBoundsFacet,
            balancerV3AuthenticationFacet: balancerV3AuthenticationFacet,
            balancerV3ConstProdPoolFacet: balancerV3ConstProdPoolFacet,
            vaultRegistry: vaultRegistry,
            vaultFeeOracle: vaultFeeOracle,
            balancerV3Vault: balancerV3Vault,
            diamondFactory: diamondFactory
        });
    }
}

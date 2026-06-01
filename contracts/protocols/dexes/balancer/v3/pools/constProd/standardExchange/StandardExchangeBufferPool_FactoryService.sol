// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    StandardExchangeBufferPoolFacet
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolFacet.sol";
import {
    StandardExchangeBufferPoolLiquidityFacet
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityFacet.sol";
import {
    StandardExchangeHookFacet
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeHookFacet.sol";
import {
    StandardExchangeBufferPoolStandardVaultPkg,
    IStandardExchangeBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol";

/**
 * @title StandardExchangeBufferPool_FactoryService
 * @notice Factory service for deploying Standard Exchange Buffer Pool components via CREATE3.
 * @dev Provides deterministic deployment of facets and packages.
 */
library StandardExchangeBufferPool_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBufferPoolFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(StandardExchangeBufferPoolFacet).creationCode,
            abi.encode(type(StandardExchangeBufferPoolFacet).name)._hash()
        );
        vm.label(address(instance), type(StandardExchangeBufferPoolFacet).name);
    }

    function deployPoolLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(StandardExchangeBufferPoolLiquidityFacet).creationCode,
            abi.encode(type(StandardExchangeBufferPoolLiquidityFacet).name)._hash()
        );
        vm.label(address(instance), type(StandardExchangeBufferPoolLiquidityFacet).name);
    }

    function deployHookFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(StandardExchangeHookFacet).creationCode,
            abi.encode(type(StandardExchangeHookFacet).name)._hash()
        );
        vm.label(address(instance), type(StandardExchangeHookFacet).name);
    }

    /* ---------------------------------------------------------------------- */
    /*                            Package Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBufferPoolPkg(
        IVaultRegistryDeployment vaultRegistry,
        IStandardExchangeBufferPoolPkg.PkgInit memory pkgInit
    ) internal returns (IStandardExchangeBufferPoolPkg instance) {
        instance = IStandardExchangeBufferPoolPkg(
            address(
                vaultRegistry.deployPkg(
                    type(StandardExchangeBufferPoolStandardVaultPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(StandardExchangeBufferPoolStandardVaultPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(StandardExchangeBufferPoolStandardVaultPkg).name);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    function buildBufferPoolPkgInit(
        IFacet basicVaultFacet,
        IFacet standardVaultFacet,
        IFacet balancerV3VaultAwareFacet,
        IFacet betterBalancerV3PoolTokenFacet,
        IFacet defaultPoolInfoFacet,
        IFacet standardSwapFeePercentageBoundsFacet,
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet,
        IFacet balancerV3AuthenticationFacet,
        IFacet bufferPoolFacet,
        IFacet poolLiquidityFacet,
        IFacet hookFacet,
        IVaultRegistryDeployment vaultRegistry,
        IVaultFeeOracleQuery vaultFeeOracle,
        IVault balancerV3Vault,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal pure returns (IStandardExchangeBufferPoolPkg.PkgInit memory pkgInit) {
        pkgInit = IStandardExchangeBufferPoolPkg.PkgInit({
            basicVaultFacet: basicVaultFacet,
            standardVaultFacet: standardVaultFacet,
            balancerV3VaultAwareFacet: balancerV3VaultAwareFacet,
            betterBalancerV3PoolTokenFacet: betterBalancerV3PoolTokenFacet,
            defaultPoolInfoFacet: defaultPoolInfoFacet,
            standardSwapFeePercentageBoundsFacet: standardSwapFeePercentageBoundsFacet,
            unbalancedLiquidityInvariantRatioBoundsFacet: unbalancedLiquidityInvariantRatioBoundsFacet,
            balancerV3AuthenticationFacet: balancerV3AuthenticationFacet,
            bufferPoolFacet: bufferPoolFacet,
            poolLiquidityFacet: poolLiquidityFacet,
            hookFacet: hookFacet,
            vaultRegistry: vaultRegistry,
            vaultFeeOracle: vaultFeeOracle,
            balancerV3Vault: balancerV3Vault,
            diamondFactory: diamondFactory
        });
    }
}

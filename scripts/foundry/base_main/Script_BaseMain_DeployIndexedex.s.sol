// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WALLET_0_KEY} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";

import {IRouter as IAerodromeRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory as IAerodromePoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";

import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {Aerodrome_Component_FactoryService} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

import {BalancerV3StandardExchangeRouter_FactoryService} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";
import {IBalancerV3StandardExchangeRouterDFPkg} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

/**
 * Deploys the IndexedEx core + Aerodrome + BalancerV3 router stack to Base mainnet.
 *
 * Requirements (env vars):
 * - PRIVATE_KEY: deployer EOA private key
 * - CRANE_CREATE3_FACTORY: deployed Create3Factory on Base
 * - CRANE_DIAMOND_FACTORY: deployed DiamondPackageCallBackFactory on Base
 * - OWNER (optional): owner address for FeeCollector + IndexedexManager (defaults to deployer)
 *
 * Notes:
 * - This script intentionally does NOT deploy the Crane factories themselves (no `new`).
 * - Aerodrome/Balancer protocol addresses are pulled from Crane `BASE_MAIN` constants.
 */
contract Script_BaseMain_DeployIndexedex is Script {
    using BetterEfficientHashLib for bytes;

    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for IDiamondPackageCallBackFactory;
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;
    using IndexedexManagerFactoryService for IDiamondPackageCallBackFactory;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for IDiamondPackageCallBackFactory;

    uint256 private privateKey;
    address private deployer;
    address private owner;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    IPermit2 private permit2;
    IVault private balancerV3Vault;
    IWETH private weth;
    IAerodromeRouter private aerodromeRouter;
    IAerodromePoolFactory private aerodromePoolFactory;

    function run() external {
        _loadConfig();
        _validateConfig();

        vm.startBroadcast(privateKey);

        (IFacet diamondCutFacet, IFacet multiStepOwnableFacet) = _deployCoreFacets();
        IFeeCollectorProxy feeCollector = _deployFeeCollector(diamondCutFacet, multiStepOwnableFacet);
        IIndexedexManagerProxy indexedexManager = _deployIndexedexManager(
            diamondCutFacet,
            multiStepOwnableFacet,
            feeCollector
        );
        _configureOperators(indexedexManager);

        IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg = _deployAerodromePkg(indexedexManager);
        (IBalancerV3StandardExchangeRouterDFPkg seRouterDFPkg, IBalancerV3StandardExchangeRouterProxy seRouter) =
            _deployBalancerRouter();

        vm.stopBroadcast();

        console2.log("Base mainnet deploy complete");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("Create3Factory:", address(create3Factory));
        console2.log("DiamondPackageFactory:", address(diamondPackageFactory));

        console2.log("FeeCollector:", address(feeCollector));
        console2.log("IndexedexManager:", address(indexedexManager));

        console2.log("AerodromeStandardExchangeDFPkg:", address(aerodromeStandardExchangeDFPkg));
        console2.log("BalancerV3StandardExchangeRouterDFPkg:", address(seRouterDFPkg));
        console2.log("BalancerV3StandardExchangeRouter:", address(seRouter));
    }

    function _loadConfig() internal {
        // Default to Crane DEV0 key for convenience in local runs.
        // On Base mainnet, you should set PRIVATE_KEY explicitly.
        try vm.envUint("PRIVATE_KEY") returns (uint256 envKey) {
            privateKey = envKey;
        } catch {
            privateKey = WALLET_0_KEY;
        }
        deployer = vm.addr(privateKey);

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner;
        } catch {
            owner = deployer;
        }

        create3Factory = ICreate3FactoryProxy(vm.envAddress("CRANE_CREATE3_FACTORY"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(vm.envAddress("CRANE_DIAMOND_FACTORY"));

        permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

        // Protocol bindings (Base mainnet)
        balancerV3Vault = IVault(BASE_MAIN.BALANCER_V3_VAULT);
        weth = IWETH(BASE_MAIN.WETH9);
        aerodromeRouter = IAerodromeRouter(BASE_MAIN.AERODROME_ROUTER);
        aerodromePoolFactory = IAerodromePoolFactory(BASE_MAIN.AERODROME_POOL_FACTORY);
    }

    function _validateConfig() internal view {
        require(block.chainid == BASE_MAIN.CHAIN_ID, "Not Base mainnet (chainid 8453)");
        require(address(create3Factory).code.length > 0, "CRANE_CREATE3_FACTORY has no code");
        require(address(diamondPackageFactory).code.length > 0, "CRANE_DIAMOND_FACTORY has no code");
        require(address(permit2).code.length > 0, "Permit2 has no code");
        require(address(balancerV3Vault).code.length > 0, "Balancer V3 Vault has no code");
        require(address(weth).code.length > 0, "WETH has no code");
        require(address(aerodromeRouter).code.length > 0, "Aerodrome Router has no code");
        require(address(aerodromePoolFactory).code.length > 0, "Aerodrome Pool Factory has no code");
    }

    function _deployCoreFacets() internal returns (IFacet diamondCutFacet, IFacet multiStepOwnableFacet) {
        multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();
        diamondCutFacet = create3Factory.deployDiamondCutFacet();
    }

    function _deployFeeCollector(IFacet diamondCutFacet, IFacet multiStepOwnableFacet)
        internal
        returns (IFeeCollectorProxy feeCollector)
    {
        IFacet feeCollectorManagerFacet = create3Factory.deployFeeCollectorManagerFacet();
        IFacet feeCollectorSingleTokenPushFacet = create3Factory.deployFeeCollectorSingleTokenPushFacet();

        IFeeCollectorDFPkg feeCollectorDFPkg = create3Factory.deployFeeCollectorDFPkg(
            diamondCutFacet,
            multiStepOwnableFacet,
            feeCollectorSingleTokenPushFacet,
            feeCollectorManagerFacet
        );

        feeCollector = diamondPackageFactory.deployFeeCollector(feeCollectorDFPkg, owner);
    }

    function _deployIndexedexManager(IFacet diamondCutFacet, IFacet multiStepOwnableFacet, IFeeCollectorProxy feeCollector)
        internal
        returns (IIndexedexManagerProxy indexedexManager)
    {
        IFacet vaultFeeOracleQueryFacet = create3Factory.deployVaultFeeOracleQueryFacet();
        IFacet vaultFeeOracleManagerFacet = create3Factory.deployVaultFeeOracleManagerFacet();
        IFacet operableFacet = create3Factory.deployOperableFacet();

        IFacet vaultRegistryDeploymentFacet = create3Factory.deployVaultRegistryDeploymentFacet();
        IFacet vaultRegistryVaultManagerFacet = create3Factory.deployVaultRegistryVaultManagerFacet();
        IFacet vaultRegistryVaultPackageManagerFacet = create3Factory.deployVaultRegistryVaultPackageManagerFacet();
        IFacet vaultRegistryVaultPackageQueryFacet = create3Factory.deployVaultRegistryVaultPackageQueryFacet();
        IFacet vaultRegistryVaultQueryFacet = create3Factory.deployVaultRegistryVaultQueryFacet();

        IIndexedexManagerDFPkg indexedexManagerDFPkg = create3Factory.deployIndexedexManagerDFPkg(
            diamondCutFacet,
            multiStepOwnableFacet,
            vaultFeeOracleQueryFacet,
            vaultFeeOracleManagerFacet,
            operableFacet,
            vaultRegistryDeploymentFacet,
            vaultRegistryVaultManagerFacet,
            vaultRegistryVaultPackageManagerFacet,
            vaultRegistryVaultPackageQueryFacet,
            vaultRegistryVaultQueryFacet
        );

        indexedexManager = diamondPackageFactory.deployIndexedexManager(
            create3Factory,
            indexedexManagerDFPkg,
            owner,
            feeCollector
        );
    }

    function _configureOperators(IIndexedexManagerProxy indexedexManager) internal {
        // Allow manager to deploy packages (used by Aerodrome_Component_FactoryService)
        IOperable(address(create3Factory)).setOperator(address(indexedexManager), true);
    }

    function _deployAerodromePkg(IIndexedexManagerProxy indexedexManager)
        internal
        returns (IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg)
    {
        // Use the Aerodrome factory service to avoid stack-too-deep.
        aerodromeStandardExchangeDFPkg = Aerodrome_Component_FactoryService.deployAerodromeStandardExchangeDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            create3Factory.deployERC20Facet(),
            create3Factory.deployERC2612Facet(),
            create3Factory.deployERCC5267Facet(),
            create3Factory.deployERC4626Facet(),
            create3Factory.deployERC4626BasedBasicVaultFacet(),
            create3Factory.deployERC4626StandardVaultFacet(),
            create3Factory.deployAerodromeStandardExchangeInFacet(),
            create3Factory.deployAerodromeStandardExchangeOutFacet(),
            indexedexManager,
            indexedexManager,
            permit2,
            aerodromeRouter,
            aerodromePoolFactory
        );
    }

    function _deployBalancerRouter()
        internal
        returns (IBalancerV3StandardExchangeRouterDFPkg seRouterDFPkg, IBalancerV3StandardExchangeRouterProxy seRouter)
    {
        // IFacet senderGuardFacet = _deploySenderGuardFacet(create3Factory);

        // IFacet exactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        // IFacet exactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        // IFacet exactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        // IFacet exactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        // IFacet batchExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        // IFacet batchExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        // IFacet prepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        // IFacet prepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();

        // seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
        //     senderGuardFacet,
        //     exactInQueryFacet,
        //     exactOutQueryFacet,
        //     exactInSwapFacet,
        //     exactOutSwapFacet,
        //     prepayFacet,
        //     prepayHooksFacet,
        //     batchExactInFacet,
        //     batchExactOutFacet,
        //     balancerV3Vault,
        //     permit2,
        //     weth
        // );

        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        {
            pkgInit.senderGuardFacet = _deploySenderGuardFacet(create3Factory);
            pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
            pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
            pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
            pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
            pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
            pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
            pkgInit.balancerV3StandardExchangeRouterPrepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
            pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
            pkgInit.balancerV3StandardExchangeRouterPermit2WitnessFacet = create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
            pkgInit.balancerV3Vault = balancerV3Vault;
            pkgInit.permit2 = permit2;
            pkgInit.weth = weth;
        }

        balRouterPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
            pkgInit
        );

        seRouter = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(seRouterDFPkg);
    }

    function _deploySenderGuardFacet(ICreate3FactoryProxy create3Factory_) internal returns (IFacet facet) {
        facet = create3Factory_.deployFacet(
            type(SenderGuardFacet).creationCode,
            abi.encode(type(SenderGuardFacet).name)._hash()
        );
    }
}

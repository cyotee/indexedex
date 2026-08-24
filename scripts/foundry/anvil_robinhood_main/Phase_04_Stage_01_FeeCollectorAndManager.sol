// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";

import {FeeCollectorFactoryService} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";

/// @title Phase_04_Stage_01_FeeCollectorAndManager
/// @notice FeeCollector and Manager facets, then packages, then diamonds. Hook factory + fee defaults + CREATE3 setOperator.
library Phase_04_Stage_01_FeeCollectorAndManager {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for ICreate3FactoryProxy;
    using FeeCollectorFactoryService for IDiamondPackageCallBackFactory;
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;
    using IndexedexManagerFactoryService for IDiamondPackageCallBackFactory;

    function execute(LaunchState storage s, address owner_) internal {
        _deployFeeCollector(s, owner_);
        _deployIndexedexManager(s, owner_);
        IOperable(address(s.create3Factory)).setOperator(address(s.indexedexManager), true);
        IVaultRegistryDeployment(address(s.indexedexManager)).setHookDiamondPackageFactory(address(s.hookFactory));
        _configureFeeOracle(s);
    }

    function _configureFeeOracle(LaunchState storage s) private {
        IVaultFeeOracleManager feeMgr = IVaultFeeOracleManager(address(s.indexedexManager));
        feeMgr.setDefaultUsageFee(FixtureEconomics.USAGE_FEE);
        feeMgr.setDefaultDexSwapFee(FixtureEconomics.DEX_SWAP_FEE);
        feeMgr.setDefaultSeigniorageIncentivePercentage(FixtureEconomics.SEIGNIORAGE);
        feeMgr.setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, FixtureEconomics.V4_LIQUID_RESERVE
        );
        feeMgr.setDefaultBondTerms(
            BondTerms({
                minLockDuration: FixtureEconomics.MIN_LOCK,
                maxLockDuration: FixtureEconomics.MAX_LOCK,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        );
    }

    function _deployFeeCollector(LaunchState storage s, address owner_) private {
        IFacet feeCollectorManagerFacet = s.create3Factory.deployFeeCollectorManagerFacet();
        IFacet feeCollectorSingleTokenPushFacet = s.create3Factory.deployFeeCollectorSingleTokenPushFacet();

        IFeeCollectorDFPkg feeCollectorDFPkg = s.create3Factory.deployFeeCollectorDFPkg(
            s.diamondCutFacet, s.multiStepOwnableFacet, feeCollectorSingleTokenPushFacet, feeCollectorManagerFacet
        );

        s.feeCollector = s.diamondPackageFactory.deployFeeCollector(feeCollectorDFPkg, owner_);
    }

    function _deployIndexedexManager(LaunchState storage s, address owner_) private {
        IIndexedexManagerDFPkg.PkgInit memory pkgInit;
        pkgInit.diamondCutFacet = s.diamondCutFacet;
        pkgInit.multiStepOwnableFacet = s.multiStepOwnableFacet;
        pkgInit.vaultFeeQueryFacet = s.create3Factory.deployVaultFeeOracleQueryFacet();
        pkgInit.vaultFeeManagerFacet = s.create3Factory.deployVaultFeeOracleManagerFacet();
        pkgInit.operableFacet = s.create3Factory.deployOperableFacet();
        pkgInit.vaultRegistryDeploymentFacet = s.create3Factory.deployVaultRegistryDeploymentFacet();
        pkgInit.vaultRegistryVaultManagerFacet = s.create3Factory.deployVaultRegistryVaultManagerFacet();
        pkgInit.vaultRegistryVaultPackageManagerFacet = s.create3Factory.deployVaultRegistryVaultPackageManagerFacet();
        pkgInit.vaultRegistryVaultPackageQueryFacet = s.create3Factory.deployVaultRegistryVaultPackageQueryFacet();
        pkgInit.vaultRegistryVaultQueryFacet = s.create3Factory.deployVaultRegistryVaultQueryFacet();
        pkgInit.vaultRegistryDisableQueryFacet = s.create3Factory.deployVaultRegistryDisableQueryFacet();
        pkgInit.vaultRegistryDisableManagerFacet = s.create3Factory.deployVaultRegistryDisableManagerFacet();

        IIndexedexManagerDFPkg indexedexManagerDFPkg = s.create3Factory.deployIndexedexManagerDFPkg(pkgInit);

        s.indexedexManager = s.diamondPackageFactory.deployIndexedexManager(
            s.create3Factory, indexedexManagerDFPkg, owner_, s.feeCollector
        );
    }
}

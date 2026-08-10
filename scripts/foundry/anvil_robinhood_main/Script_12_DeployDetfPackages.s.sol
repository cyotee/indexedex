// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Component_FactoryService as CpDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService as OrbDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETF_Component_FactoryService as WgtDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/// @title Script_12_DeployDetfPackages
/// @notice CP / Orbital / Weighted Uni V4 SE DETF DFPkgs via manager registry.
contract Script_12_DeployDetfPackages is DeploymentBase {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using CpDetfFS for ICreate3FactoryProxy;
    using CpDetfFS for IVaultRegistryDeployment;
    using OrbDetfFS for ICreate3FactoryProxy;
    using OrbDetfFS for IVaultRegistryDeployment;
    using WgtDetfFS for ICreate3FactoryProxy;
    using WgtDetfFS for IVaultRegistryDeployment;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant HOOK_PKGS_FILE = "10_hook_packages.json";
    string internal constant CHILDREN_FILE = "11_detf_children.json";
    string internal constant ARTIFACT_FILE = "12_detf_packages.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    address private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;

    address private cpDetfPkg;
    address private orbitalDetfPkg;
    address private weightedDetfPkg;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 12: DETF Packages");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        address cpHookPkg = _readAddress(HOOK_PKGS_FILE, "cpHookPkg");
        address orbHookPkg = _readAddress(HOOK_PKGS_FILE, "orbitalHookPkg");
        address wgtHookPkg = _readAddress(HOOK_PKGS_FILE, "weightedHookPkg");
        address bondNftVaultPkg = _readAddress(CHILDREN_FILE, "bondNftVaultPkg");
        address rebasingClaimTokenPkg = _readAddress(CHILDREN_FILE, "rebasingClaimTokenPkg");

        IVaultRegistryDeployment reg = IVaultRegistryDeployment(indexedexManager);
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());

        vm.startBroadcast();

        IFacet multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();

        // CP DETF
        {
            IFacet exchangeInFacet = CpDetfFS.deployExchangeInFacet(create3Factory);
            cpDetfPkg = address(
                CpDetfFS.deployPkg(
                    reg,
                    IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit({
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
                        exchangeInFacet: exchangeInFacet,
                        feeOracle: IVaultFeeOracleQuery(indexedexManager),
                        vaultRegistryDeployment: reg,
                        poolManager: pm,
                        hookPkg: IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(cpHookPkg),
                        bondNftVaultPkg: IDetfSelfNftInventoryDFPkg(bondNftVaultPkg),
                        rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(rebasingClaimTokenPkg),
                        diamondFactory: diamondPackageFactory
                    })
                )
            );
        }

        // Orbital DETF
        {
            IFacet exchangeInFacet = OrbDetfFS.deployExchangeInFacet(create3Factory);
            IFacet infoFacet = OrbDetfFS.deployInfoFacet(create3Factory);
            orbitalDetfPkg = address(
                OrbDetfFS.deployPkg(
                    reg,
                    IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit({
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
                        exchangeInFacet: exchangeInFacet,
                        infoFacet: infoFacet,
                        feeOracle: IVaultFeeOracleQuery(indexedexManager),
                        vaultRegistryDeployment: reg,
                        poolManager: pm,
                        hookPkg: IUniswapV4StandardExchangeOrbitalBufferHookPackage(orbHookPkg),
                        bondNftVaultPkg: IDetfSelfNftInventoryDFPkg(bondNftVaultPkg),
                        rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(rebasingClaimTokenPkg),
                        diamondFactory: diamondPackageFactory
                    })
                )
            );
        }

        // Weighted DETF
        {
            IFacet exchangeInFacet = WgtDetfFS.deployExchangeInFacet(create3Factory);
            IFacet infoFacet = WgtDetfFS.deployInfoFacet(create3Factory);
            weightedDetfPkg = address(
                WgtDetfFS.deployPkg(
                    reg,
                    IUniswapV4StandardExchangeWeightedDETDFPkg.PkgInit({
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
                        exchangeInFacet: exchangeInFacet,
                        infoFacet: infoFacet,
                        feeOracle: IVaultFeeOracleQuery(indexedexManager),
                        vaultRegistryDeployment: reg,
                        poolManager: pm,
                        hookPkg: IUniswapV4StandardExchangeWeightedBufferHookPackage(wgtHookPkg),
                        bondNftVaultPkg: IDetfSelfNftInventoryDFPkg(bondNftVaultPkg),
                        rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(rebasingClaimTokenPkg),
                        diamondFactory: diamondPackageFactory
                    })
                )
            );
        }

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory =
            IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
        indexedexManager = _readAddress(CORE_FILE, "indexedexManager");
        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
    }

    function _loadExisting() internal returns (bool) {
        (address a, bool okA) = _readAddressSafe(ARTIFACT_FILE, "cpDetfPkg");
        (address b, bool okB) = _readAddressSafe(ARTIFACT_FILE, "orbitalDetfPkg");
        (address c, bool okC) = _readAddressSafe(ARTIFACT_FILE, "weightedDetfPkg");
        if (!(okA && okB && okC)) return false;
        if (a.code.length == 0 || b.code.length == 0 || c.code.length == 0) return false;
        cpDetfPkg = a;
        orbitalDetfPkg = b;
        weightedDetfPkg = c;
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("detfPkgs", "cpDetfPkg", cpDetfPkg);
        json = vm.serializeAddress("detfPkgs", "orbitalDetfPkg", orbitalDetfPkg);
        json = vm.serializeAddress("detfPkgs", "weightedDetfPkg", weightedDetfPkg);
        json = vm.serializeUint("detfPkgs", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("cpDetfPkg:", cpDetfPkg);
        _logAddress("orbitalDetfPkg:", orbitalDetfPkg);
        _logAddress("weightedDetfPkg:", weightedDetfPkg);
        _logComplete("Stage 12");
    }
}

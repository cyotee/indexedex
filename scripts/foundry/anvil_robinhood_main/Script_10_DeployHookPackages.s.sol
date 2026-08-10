// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as ICpPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg as CpDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpFS
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IOrbPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDFPkg as OrbDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbFS
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWgtPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookDFPkg as WgtDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WgtFS
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeBufferHookPackage as ISinglePkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookDFPkg as SingleDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as SingleFS
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";

/// @title Script_10_DeployHookPackages
/// @notice Deploy CP / Orbital / Weighted / Single SE Buffer hook DFPkgs via manager registry.
contract Script_10_DeployHookPackages is DeploymentBase {
    using BetterEfficientHashLib for bytes;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant ARTIFACT_FILE = "10_hook_packages.json";

    ICreate3FactoryProxy private create3Factory;
    address private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    address private cpHookPkg;
    address private orbitalHookPkg;
    address private weightedHookPkg;
    address private singleSeBufferHookPkg;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _loadPrior();
        _logHeader("Stage 10: Hook Packages");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        IVaultRegistryDeployment reg = IVaultRegistryDeployment(indexedexManager);
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(indexedexManager);

        vm.startBroadcast();

        // --- CP Buffer Constant Product ---
        // Note: FactoryService.deployPackage uses vm.prank — illegal under broadcast.
        // Call registry.deployPkg directly as the broadcast sender (owner).
        {
            IFacet seFacet = CpFS.deploySeFacet(create3Factory);
            IFacet depositFacet = CpFS.deployDepositFacet(create3Factory);
            IFacet withdrawFacet = CpFS.deployWithdrawFacet(create3Factory);
            cpHookPkg = reg.deployPkg(
                type(CpDFPkg).creationCode,
                abi.encode(
                    ICpPkg.PkgInit({
                        vaultRegistryDeployment: reg,
                        vaultFeeOracleQuery: feeOracle,
                        seFacet: seFacet,
                        depositFacet: depositFacet,
                        withdrawFacet: withdrawFacet,
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
                    })
                ),
                abi.encode(type(ICpPkg).name, "AnvilRobinhood")._hash()
            );
        }

        // --- Orbital ---
        {
            IFacet depositFacet = OrbFS.deployDepositFacet(create3Factory);
            IFacet withdrawFacet = OrbFS.deployWithdrawFacet(create3Factory);
            IFacet seFacet = OrbFS.deploySeFacet(create3Factory);
            IFacet hooksFacet = OrbFS.deployHooksFacet(create3Factory);
            orbitalHookPkg = reg.deployPkg(
                type(OrbDFPkg).creationCode,
                abi.encode(
                    IOrbPkg.PkgInit({
                        vaultRegistryDeployment: reg,
                        vaultFeeOracleQuery: feeOracle,
                        depositFacet: depositFacet,
                        withdrawFacet: withdrawFacet,
                        seFacet: seFacet,
                        hooksFacet: hooksFacet,
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
                    })
                ),
                abi.encode(type(IOrbPkg).name, "AnvilRobinhood")._hash()
            );
        }

        // --- Weighted ---
        {
            IFacet liquidityFacet = WgtFS.deployLiquidityFacet(create3Factory);
            IFacet seFacet = WgtFS.deploySeFacet(create3Factory);
            IFacet hooksFacet = WgtFS.deployHooksFacet(create3Factory);
            weightedHookPkg = reg.deployPkg(
                type(WgtDFPkg).creationCode,
                abi.encode(
                    IWgtPkg.PkgInit({
                        vaultRegistryDeployment: reg,
                        vaultFeeOracleQuery: feeOracle,
                        liquidityFacet: liquidityFacet,
                        seFacet: seFacet,
                        hooksFacet: hooksFacet,
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
                    })
                ),
                abi.encode(type(IWgtPkg).name, "AnvilRobinhood")._hash()
            );
        }

        // --- Single SE Buffer ---
        {
            IFacet productFacet = SingleFS.deployProductFacet(create3Factory);
            singleSeBufferHookPkg = reg.deployPkg(
                type(SingleDFPkg).creationCode,
                abi.encode(
                    ISinglePkg.PkgInit({
                        vaultRegistryDeployment: reg,
                        productFacet: productFacet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
                    })
                ),
                abi.encode(type(ISinglePkg).name, "AnvilRobinhood")._hash()
            );
        }

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        indexedexManager = _readAddress(CORE_FILE, "indexedexManager");
        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        multiAssetBasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetBasicVaultFacet"));
        multiAssetStandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetStandardVaultFacet"));
    }

    function _loadExisting() internal returns (bool) {
        (address a, bool okA) = _readAddressSafe(ARTIFACT_FILE, "cpHookPkg");
        (address b, bool okB) = _readAddressSafe(ARTIFACT_FILE, "weightedHookPkg");
        (address c, bool okC) = _readAddressSafe(ARTIFACT_FILE, "orbitalHookPkg");
        (address d, bool okD) = _readAddressSafe(ARTIFACT_FILE, "singleSeBufferHookPkg");
        if (!(okA && okB && okC && okD)) return false;
        if (a.code.length == 0 || b.code.length == 0 || c.code.length == 0 || d.code.length == 0) return false;
        cpHookPkg = a;
        weightedHookPkg = b;
        orbitalHookPkg = c;
        singleSeBufferHookPkg = d;
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("hookPkgs", "cpHookPkg", cpHookPkg);
        json = vm.serializeAddress("hookPkgs", "orbitalHookPkg", orbitalHookPkg);
        json = vm.serializeAddress("hookPkgs", "weightedHookPkg", weightedHookPkg);
        json = vm.serializeAddress("hookPkgs", "singleSeBufferHookPkg", singleSeBufferHookPkg);
        json = vm.serializeUint("hookPkgs", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("cpHookPkg:", cpHookPkg);
        _logAddress("orbitalHookPkg:", orbitalHookPkg);
        _logAddress("weightedHookPkg:", weightedHookPkg);
        _logAddress("singleSeBufferHookPkg:", singleSeBufferHookPkg);
        _logComplete("Stage 10");
    }
}

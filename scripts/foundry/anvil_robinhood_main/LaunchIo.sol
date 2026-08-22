// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";

import {DeploymentBase} from "./DeploymentBase.sol";

/// @title LaunchIo
/// @notice JSON hydrate helpers for architecture groups 01–03.
abstract contract LaunchIo is DeploymentBase {
    string internal constant FILE_PREFLIGHT = "00_preflight.json";
    string internal constant FILE_FACTORIES = "01_factories.json";
    string internal constant FILE_PLATFORM = "02_platform.json";
    string internal constant FILE_UNIV4_PKGS = "03_univ4_packages.json";

    function _loadFactories(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "create3Factory");
        if (!ok || !_hasCode(a)) return false;
        s.create3Factory = ICreate3FactoryProxy(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "diamondPackageFactory");
        if (!ok || !_hasCode(a)) return false;
        s.diamondPackageFactory = IDiamondPackageCallBackFactory(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "hookFactory");
        if (!ok || !_hasCode(a)) return false;
        s.hookFactory = IUniswapV4HookDiamondPackageCallBackFactory(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "hookFlagsFacet");
        if (ok) s.hookFlagsFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "erc20Facet");
        if (!ok || !_hasCode(a)) return false;
        s.erc20Facet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "erc2612Facet");
        if (ok) s.erc2612Facet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "erc5267Facet");
        if (ok) s.erc5267Facet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "erc4626Facet");
        if (ok) s.erc4626Facet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "erc4626BasicVaultFacet");
        if (ok) s.erc4626BasicVaultFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "erc4626StandardVaultFacet");
        if (ok) s.erc4626StandardVaultFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "multiAssetBasicVaultFacet");
        if (!ok || !_hasCode(a)) return false;
        s.multiAssetBasicVaultFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "multiAssetStandardVaultFacet");
        if (!ok || !_hasCode(a)) return false;
        s.multiAssetStandardVaultFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "multiStepOwnableFacet");
        if (!ok || !_hasCode(a)) return false;
        s.multiStepOwnableFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "operableFacet");
        if (ok) s.operableFacet = IFacet(a);
        (a, ok) = _readAddressSafe(FILE_FACTORIES, "diamondCutFacet");
        if (!ok || !_hasCode(a)) return false;
        s.diamondCutFacet = IFacet(a);
        return true;
    }

    function _loadPlatform(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_PLATFORM, "indexedexManager");
        if (!ok || !_hasCode(a)) return false;
        s.indexedexManager = IIndexedexManagerProxy(a);
        (a, ok) = _readAddressSafe(FILE_PLATFORM, "feeCollector");
        if (!ok || !_hasCode(a)) return false;
        s.feeCollector = IFeeCollectorProxy(a);
        (a, ok) = _readAddressSafe(FILE_PLATFORM, "rateProviderPkg");
        if (!ok || !_hasCode(a)) return false;
        s.rateProviderPkg = IStandardExchangeRateProviderDFPkg(a);
        return true;
    }

    function _loadUniV4Packages(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "uniV4SePkg");
        if (!ok || !_hasCode(a)) return false;
        s.uniV4SePkg = IUniswapV4StandardExchangeDFPkg(a);
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "cpHookPkg");
        if (!ok || !_hasCode(a)) return false;
        s.cpHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "bondNftVaultPkg");
        if (ok) s.bondNftVaultPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "rebasingClaimTokenPkg");
        if (ok) s.rebasingClaimTokenPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "cpDetfPkg");
        if (!ok || !_hasCode(a)) return false;
        s.cpDetfPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "curveQuadHookPkg");
        if (!ok || !_hasCode(a)) return false;
        s.curveQuadHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "curveQuadDetfPkg");
        if (!ok || !_hasCode(a)) return false;
        s.curveQuadDetfPkg = a;
        return true;
    }

    function _exportFactories(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g01", "create3Factory", address(s.create3Factory));
        json = vm.serializeAddress("g01", "diamondPackageFactory", address(s.diamondPackageFactory));
        json = vm.serializeAddress("g01", "hookFactory", address(s.hookFactory));
        json = vm.serializeAddress("g01", "hookFlagsFacet", address(s.hookFlagsFacet));
        json = vm.serializeAddress("g01", "erc20Facet", address(s.erc20Facet));
        json = vm.serializeAddress("g01", "erc2612Facet", address(s.erc2612Facet));
        json = vm.serializeAddress("g01", "erc5267Facet", address(s.erc5267Facet));
        json = vm.serializeAddress("g01", "erc4626Facet", address(s.erc4626Facet));
        json = vm.serializeAddress("g01", "erc4626BasicVaultFacet", address(s.erc4626BasicVaultFacet));
        json = vm.serializeAddress("g01", "erc4626StandardVaultFacet", address(s.erc4626StandardVaultFacet));
        json = vm.serializeAddress("g01", "multiAssetBasicVaultFacet", address(s.multiAssetBasicVaultFacet));
        json = vm.serializeAddress("g01", "multiAssetStandardVaultFacet", address(s.multiAssetStandardVaultFacet));
        json = vm.serializeAddress("g01", "multiStepOwnableFacet", address(s.multiStepOwnableFacet));
        json = vm.serializeAddress("g01", "operableFacet", address(s.operableFacet));
        json = vm.serializeAddress("g01", "diamondCutFacet", address(s.diamondCutFacet));
        json = vm.serializeAddress("g01", "owner", owner);
        json = vm.serializeAddress("g01", "deployer", deployer);
        json = vm.serializeUint("g01", "chainId", block.chainid);
        json = vm.serializeString("g01", "networkProfile", _networkProfile());
        _writeJson(json, FILE_FACTORIES);
    }

    function _exportPlatform(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g02", "feeCollector", address(s.feeCollector));
        json = vm.serializeAddress("g02", "indexedexManager", address(s.indexedexManager));
        json = vm.serializeAddress("g02", "vaultRegistry", address(s.indexedexManager));
        json = vm.serializeAddress("g02", "vaultFeeOracle", address(s.indexedexManager));
        json = vm.serializeAddress("g02", "rateProviderPkg", address(s.rateProviderPkg));
        json = vm.serializeAddress("g02", "hookFactory", address(s.hookFactory));
        json = vm.serializeAddress("g02", "owner", owner);
        json = vm.serializeUint("g02", "chainId", block.chainid);
        _writeJson(json, FILE_PLATFORM);
    }

    function _exportUniV4Packages(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g03", "cpHookPkg", s.cpHookPkg);
        json = vm.serializeAddress("g03", "uniV4SePkg", address(s.uniV4SePkg));
        json = vm.serializeAddress("g03", "bondNftVaultPkg", s.bondNftVaultPkg);
        json = vm.serializeAddress("g03", "rebasingClaimTokenPkg", s.rebasingClaimTokenPkg);
        json = vm.serializeAddress("g03", "cpDetfPkg", s.cpDetfPkg);
        json = vm.serializeAddress("g03", "curveQuadHookPkg", s.curveQuadHookPkg);
        json = vm.serializeAddress("g03", "curveQuadDetfPkg", s.curveQuadDetfPkg);
        json = vm.serializeAddress("g03", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("g03", "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        json = vm.serializeAddress("g03", "permit2", RobinhoodCanonicalLib.permit2());
        json = vm.serializeUint("g03", "chainId", block.chainid);
        _writeJson(json, FILE_UNIV4_PKGS);
    }
}

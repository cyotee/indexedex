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
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";

import {DeploymentBase} from "./DeploymentBase.sol";

/// @title LaunchIo
/// @notice Per-Stage JSON hydrate/export for 4663 architecture catalog.
abstract contract LaunchIo is DeploymentBase {
    string internal constant FILE_00_01 = "phase00_stage01_anvil_env.json";
    string internal constant FILE_01_01 = "phase01_stage01_permit2.json";
    string internal constant FILE_01_02 = "phase01_stage02_weth.json";
    string internal constant FILE_01_03 = "phase01_stage03_uniswap_v4.json";
    string internal constant FILE_02_01 = "phase02_stage01_create3_factory.json";
    string internal constant FILE_02_02 = "phase02_stage02_diamond_package_factory.json";
    string internal constant FILE_02_03 = "phase02_stage03_hook_factory.json";
    string internal constant FILE_03_01 = "phase03_stage01_common_facets.json";
    string internal constant FILE_04_01 = "phase04_stage01_fee_collector_and_manager.json";
    string internal constant FILE_05_01 = "phase05_stage01_se_rate_provider_pkg.json";
    string internal constant FILE_05_02 = "phase05_stage02_uniswap_v4_twap_oracle.json";
    string internal constant FILE_05_03 = "phase05_stage03_uniswap_v4_standard_exchange_pkg.json";
    string internal constant FILE_05_05 = "phase05_stage05_morpho_blue_standard_exchange_pkg.json";
    string internal constant FILE_06_01 = "phase06_stage01_bond_nft_pkg.json";
    string internal constant FILE_06_02 = "phase06_stage02_rebasing_claim_pkg.json";
    string internal constant FILE_06_03 = "phase06_stage03_cp_buffer_hook_pkg.json";
    string internal constant FILE_06_04 = "phase06_stage04_weighted_buffer_hook_pkg.json";
    string internal constant FILE_06_06 = "phase06_stage06_curve_quad_buffer_hook_pkg.json";
    string internal constant FILE_06_07 = "phase06_stage07_cp_detf_pkg.json";
    string internal constant FILE_06_08 = "phase06_stage08_weighted_detf_pkg.json";
    string internal constant FILE_06_10 = "phase06_stage10_curve_quad_detf_pkg.json";
    string internal constant FILE_09_01 = "phase09_stage01_export_frontend.json";

    function _loadAddr(string memory file, string memory key) internal view returns (address) {
        (address a, bool ok) = _readAddressSafe(file, key);
        return (ok && _hasCode(a)) ? a : address(0);
    }

    function _requireCreate3(LaunchState storage s) internal {
        address a = _loadAddr(FILE_02_01, "create3Factory");
        require(_hasCode(a), "run Phase 02 Stage 01 first");
        s.create3Factory = ICreate3FactoryProxy(a);
    }

    function _requireDiamondFactory(LaunchState storage s) internal {
        _requireCreate3(s);
        address a = _loadAddr(FILE_02_02, "diamondPackageFactory");
        require(_hasCode(a), "run Phase 02 Stage 02 first");
        s.diamondPackageFactory = IDiamondPackageCallBackFactory(a);
    }

    function _requireHookFactory(LaunchState storage s) internal {
        address a = _loadAddr(FILE_02_03, "hookFactory");
        require(_hasCode(a), "run Phase 02 Stage 03 first");
        s.hookFactory = IUniswapV4HookDiamondPackageCallBackFactory(a);
        address flags = _loadAddr(FILE_02_03, "hookFlagsFacet");
        if (_hasCode(flags)) s.hookFlagsFacet = IFacet(flags);
    }

    function _requireCommonFacets(LaunchState storage s) internal {
        address a;
        a = _loadAddr(FILE_03_01, "erc20Facet");
        require(_hasCode(a), "run Phase 03 Stage 01 first (erc20Facet)");
        s.erc20Facet = IFacet(a);
        a = _loadAddr(FILE_03_01, "erc2612Facet");
        if (_hasCode(a)) s.erc2612Facet = IFacet(a);
        a = _loadAddr(FILE_03_01, "erc5267Facet");
        if (_hasCode(a)) s.erc5267Facet = IFacet(a);
        a = _loadAddr(FILE_03_01, "erc4626Facet");
        if (_hasCode(a)) s.erc4626Facet = IFacet(a);
        a = _loadAddr(FILE_03_01, "erc4626BasicVaultFacet");
        if (_hasCode(a)) s.erc4626BasicVaultFacet = IFacet(a);
        a = _loadAddr(FILE_03_01, "erc4626StandardVaultFacet");
        if (_hasCode(a)) s.erc4626StandardVaultFacet = IFacet(a);
        a = _loadAddr(FILE_03_01, "multiAssetBasicVaultFacet");
        require(_hasCode(a), "run Phase 03 Stage 01 first (multiAssetBasicVaultFacet)");
        s.multiAssetBasicVaultFacet = IFacet(a);
        a = _loadAddr(FILE_03_01, "multiAssetStandardVaultFacet");
        require(_hasCode(a), "run Phase 03 Stage 01 first (multiAssetStandardVaultFacet)");
        s.multiAssetStandardVaultFacet = IFacet(a);
        a = _loadAddr(FILE_03_01, "multiStepOwnableFacet");
        require(_hasCode(a), "run Phase 03 Stage 01 first (multiStepOwnableFacet)");
        s.multiStepOwnableFacet = IFacet(a);
        a = _loadAddr(FILE_03_01, "operableFacet");
        if (_hasCode(a)) s.operableFacet = IFacet(a);
        a = _loadAddr(FILE_03_01, "diamondCutFacet");
        require(_hasCode(a), "run Phase 03 Stage 01 first (diamondCutFacet)");
        s.diamondCutFacet = IFacet(a);
    }

    function _requireManager(LaunchState storage s) internal {
        address mgr = _loadAddr(FILE_04_01, "indexedexManager");
        require(_hasCode(mgr), "run Phase 04 Stage 01 first");
        s.indexedexManager = IIndexedexManagerProxy(mgr);
        address fee = _loadAddr(FILE_04_01, "feeCollector");
        require(_hasCode(fee), "run Phase 04 Stage 01 first (feeCollector)");
        s.feeCollector = IFeeCollectorProxy(fee);
    }

    function _requireRateProviderPkg(LaunchState storage s) internal {
        address a = _loadAddr(FILE_05_01, "rateProviderPkg");
        require(_hasCode(a), "run Phase 05 Stage 01 first");
        s.rateProviderPkg = IStandardExchangeRateProviderDFPkg(a);
    }

    function _requireTwapOracle(LaunchState storage s) internal {
        address facet = _loadAddr(FILE_05_02, "twapOracleFacet");
        if (_hasCode(facet)) s.twapOracleFacet = IFacet(facet);
        address pkg = _loadAddr(FILE_05_02, "twapOraclePkg");
        require(_hasCode(pkg), "run Phase 05 Stage 02 first (twapOraclePkg)");
        s.twapOraclePkg = IUniswapV4MultiPoolTwapOracleDFPkg(pkg);
        address oracle = _loadAddr(FILE_05_02, "twapOracle");
        require(_hasCode(oracle), "run Phase 05 Stage 02 first (twapOracle)");
        s.twapOracle = IUniswapV4MultiPoolTwapOracle(oracle);
        s.twapAdapterFactory = _loadAddr(FILE_05_02, "twapAdapterFactory");
        require(_hasCode(s.twapAdapterFactory), "run Phase 05 Stage 02 first (twapAdapterFactory)");
        require(
            s.twapOracle.poolManager() == RobinhoodCanonicalLib.poolManager(),
            "Phase 05-02: twapOracle.poolManager mismatch"
        );
    }

    function _requireUniV4SePkg(LaunchState storage s) internal {
        address a = _loadAddr(FILE_05_03, "uniV4SePkg");
        require(_hasCode(a), "run Phase 05 Stage 03 first");
        s.uniV4SePkg = IUniswapV4StandardExchangeDFPkg(a);
    }

    function _requireMorphoBlueSePkg(LaunchState storage s) internal {
        address a = _loadAddr(FILE_05_05, "morphoBlueSePkg");
        require(_hasCode(a), "run Phase 05 Stage 05 first");
        s.morphoBlueSePkg = a;
    }

    function _exportCreate3(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0201", "create3Factory", address(s.create3Factory));
        json = vm.serializeAddress("p0201", "owner", owner);
        json = vm.serializeAddress("p0201", "deployer", deployer);
        json = vm.serializeUint("p0201", "chainId", block.chainid);
        json = vm.serializeString("p0201", "networkProfile", _networkProfile());
        _writeJson(json, FILE_02_01);
    }

    function _exportDiamondFactory(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0202", "diamondPackageFactory", address(s.diamondPackageFactory));
        json = vm.serializeAddress("p0202", "create3Factory", address(s.create3Factory));
        json = vm.serializeUint("p0202", "chainId", block.chainid);
        _writeJson(json, FILE_02_02);
    }

    function _exportHookFactory(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0203", "hookFactory", address(s.hookFactory));
        json = vm.serializeAddress("p0203", "hookFlagsFacet", address(s.hookFlagsFacet));
        json = vm.serializeUint("p0203", "chainId", block.chainid);
        _writeJson(json, FILE_02_03);
    }

    function _exportCommonFacets(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0301", "erc20Facet", address(s.erc20Facet));
        json = vm.serializeAddress("p0301", "erc2612Facet", address(s.erc2612Facet));
        json = vm.serializeAddress("p0301", "erc5267Facet", address(s.erc5267Facet));
        json = vm.serializeAddress("p0301", "erc4626Facet", address(s.erc4626Facet));
        json = vm.serializeAddress("p0301", "erc4626BasicVaultFacet", address(s.erc4626BasicVaultFacet));
        json = vm.serializeAddress("p0301", "erc4626StandardVaultFacet", address(s.erc4626StandardVaultFacet));
        json = vm.serializeAddress("p0301", "multiAssetBasicVaultFacet", address(s.multiAssetBasicVaultFacet));
        json = vm.serializeAddress("p0301", "multiAssetStandardVaultFacet", address(s.multiAssetStandardVaultFacet));
        json = vm.serializeAddress("p0301", "multiStepOwnableFacet", address(s.multiStepOwnableFacet));
        json = vm.serializeAddress("p0301", "operableFacet", address(s.operableFacet));
        json = vm.serializeAddress("p0301", "diamondCutFacet", address(s.diamondCutFacet));
        json = vm.serializeUint("p0301", "chainId", block.chainid);
        _writeJson(json, FILE_03_01);
    }

    function _exportFeeCollectorAndManager(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0401", "feeCollector", address(s.feeCollector));
        json = vm.serializeAddress("p0401", "indexedexManager", address(s.indexedexManager));
        json = vm.serializeAddress("p0401", "vaultRegistry", address(s.indexedexManager));
        json = vm.serializeAddress("p0401", "vaultFeeOracle", address(s.indexedexManager));
        json = vm.serializeAddress("p0401", "hookFactory", address(s.hookFactory));
        json = vm.serializeAddress("p0401", "owner", owner);
        json = vm.serializeUint("p0401", "chainId", block.chainid);
        _writeJson(json, FILE_04_01);
    }

    function _exportPkg(string memory obj, string memory file, string memory key, address pkg) internal {
        string memory json;
        json = vm.serializeAddress(obj, key, pkg);
        json = vm.serializeUint(obj, "chainId", block.chainid);
        _writeJson(json, file);
    }

    function _exportTwapOracle(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0502", "twapOracleFacet", address(s.twapOracleFacet));
        json = vm.serializeAddress("p0502", "twapOraclePkg", address(s.twapOraclePkg));
        json = vm.serializeAddress("p0502", "twapOracle", address(s.twapOracle));
        json = vm.serializeAddress("p0502", "twapAdapterFactory", s.twapAdapterFactory);
        json = vm.serializeAddress("p0502", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeUint("p0502", "chainId", block.chainid);
        _writeJson(json, FILE_05_02);
    }

    function _exportArchitecture(LaunchState storage s) internal {
        _exportCreate3(s);
        _exportDiamondFactory(s);
        _exportHookFactory(s);
        _exportCommonFacets(s);
        _exportFeeCollectorAndManager(s);
        _exportPkg("p0501", FILE_05_01, "rateProviderPkg", address(s.rateProviderPkg));
        _exportTwapOracle(s);
        _exportPkg("p0503", FILE_05_03, "uniV4SePkg", address(s.uniV4SePkg));
        _exportPkg("p0505", FILE_05_05, "morphoBlueSePkg", s.morphoBlueSePkg);
        _exportPkg("p0601", FILE_06_01, "bondNftVaultPkg", s.bondNftVaultPkg);
        _exportPkg("p0602", FILE_06_02, "rebasingClaimTokenPkg", s.rebasingClaimTokenPkg);
        _exportPkg("p0603", FILE_06_03, "cpHookPkg", s.cpHookPkg);
        _exportPkg("p0604", FILE_06_04, "weightedHookPkg", s.weightedHookPkg);
        _exportPkg("p0606", FILE_06_06, "curveQuadHookPkg", s.curveQuadHookPkg);
        _exportPkg("p0607", FILE_06_07, "cpDetfPkg", s.cpDetfPkg);
        _exportPkg("p0608", FILE_06_08, "weightedDetfPkg", s.weightedDetfPkg);
        _exportPkg("p0610", FILE_06_10, "curveQuadDetfPkg", s.curveQuadDetfPkg);
    }

    function _loadPhasePriorForExport(LaunchState storage s) internal {
        _requireDiamondFactory(s);
        _requireHookFactory(s);
        _requireManager(s);
        _requireRateProviderPkg(s);
        _requireTwapOracle(s);
        _requireUniV4SePkg(s);
        _requireMorphoBlueSePkg(s);
        s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
        require(_hasCode(s.bondNftVaultPkg), "run Phase 06 Stage 01 first");
        s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
        require(_hasCode(s.rebasingClaimTokenPkg), "run Phase 06 Stage 02 first");
        s.cpHookPkg = _loadAddr(FILE_06_03, "cpHookPkg");
        require(_hasCode(s.cpHookPkg), "run Phase 06 Stage 03 first");
        s.weightedHookPkg = _loadAddr(FILE_06_04, "weightedHookPkg");
        require(_hasCode(s.weightedHookPkg), "run Phase 06 Stage 04 first");
        s.curveQuadHookPkg = _loadAddr(FILE_06_06, "curveQuadHookPkg");
        require(_hasCode(s.curveQuadHookPkg), "run Phase 06 Stage 06 first");
        s.cpDetfPkg = _loadAddr(FILE_06_07, "cpDetfPkg");
        require(_hasCode(s.cpDetfPkg), "run Phase 06 Stage 07 first");
        s.weightedDetfPkg = _loadAddr(FILE_06_08, "weightedDetfPkg");
        require(_hasCode(s.weightedDetfPkg), "run Phase 06 Stage 08 first");
        s.curveQuadDetfPkg = _loadAddr(FILE_06_10, "curveQuadDetfPkg");
        require(_hasCode(s.curveQuadDetfPkg), "run Phase 06 Stage 10 first");
    }
}

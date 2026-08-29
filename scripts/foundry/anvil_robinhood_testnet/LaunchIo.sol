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
/// @notice JSON hydrate helpers used by group scripts.
abstract contract LaunchIo is DeploymentBase {
    string internal constant FILE_PREFLIGHT = "00_preflight.json";
    string internal constant FILE_FACTORIES = "01_factories.json";
    string internal constant FILE_PLATFORM = "02_platform.json";
    string internal constant FILE_UNIV4_PKGS = "03_univ4_packages.json";
    string internal constant FILE_MORPHO = "03c_morpho_blue_se.json";
    string internal constant FILE_UNIV3 = "03d_univ3_se.json";
    string internal constant FILE_TOKENS = "04_tokens.json";
    string internal constant FILE_SEVEN_TOKENS = "04b_seven_test_tokens.json";
    string internal constant FILE_LEAF_POOLS = "05_leaf_pools_ses.json";
    string internal constant FILE_LEAF_DETFS = "06_leaf_detfs.json";
    string internal constant FILE_EXPORT = "09_export.json";

    string internal constant FILE_00_01 = "phase00_stage01_anvil_env.json";
    string internal constant FILE_01_01 = "phase01_stage01_permit2.json";
    string internal constant FILE_01_02 = "phase01_stage02_weth.json";
    string internal constant FILE_01_03 = "phase01_stage03_uniswap_v4.json";
    string internal constant FILE_01_04 = "phase01_stage04_uniswap_v3.json";
    string internal constant FILE_01_05 = "phase01_stage05_morpho_blue.json";
    string internal constant FILE_02_01 = "phase02_stage01_create3_factory.json";
    string internal constant FILE_02_02 = "phase02_stage02_diamond_package_factory.json";
    string internal constant FILE_02_03 = "phase02_stage03_hook_factory.json";
    string internal constant FILE_03_01 = "phase03_stage01_common_facets.json";
    string internal constant FILE_04_01 = "phase04_stage01_fee_collector_and_manager.json";
    string internal constant FILE_04_02 = "phase04_stage02_erc20_minter_facade.json";
    string internal constant FILE_05_01 = "phase05_stage01_se_rate_provider_pkg.json";
    string internal constant FILE_05_02 = "phase05_stage02_uniswap_v4_twap_oracle.json";
    string internal constant FILE_05_03 = "phase05_stage03_uniswap_v4_standard_exchange_pkg.json";
    string internal constant FILE_05_04 = "phase05_stage04_uniswap_v3_standard_exchange_pkg.json";
    string internal constant FILE_05_05 = "phase05_stage05_morpho_blue_standard_exchange_pkg.json";
    string internal constant FILE_06_01 = "phase06_stage01_bond_nft_pkg.json";
    string internal constant FILE_06_02 = "phase06_stage02_rebasing_claim_pkg.json";
    string internal constant FILE_06_03 = "phase06_stage03_cp_buffer_hook_pkg.json";
    string internal constant FILE_06_04 = "phase06_stage04_weighted_buffer_hook_pkg.json";
    string internal constant FILE_06_05 = "phase06_stage05_orbital_buffer_hook_pkg.json";
    string internal constant FILE_06_06 = "phase06_stage06_curve_quad_buffer_hook_pkg.json";
    string internal constant FILE_06_07 = "phase06_stage07_uniswap_v4_detf_pkg.json";
    string internal constant FILE_07_01 = "phase07_stage01_core_test_tokens.json";
    string internal constant FILE_07_02 = "phase07_stage02_mag7_test_tokens.json";
    string internal constant FILE_07_03 = "phase07_stage03_uni_v4_se_dtf_weth.json";
    string internal constant FILE_07_04 = "phase07_stage04_uni_v4_se_usd.json";
    string internal constant FILE_08_01 = "phase08_stage01_fee_detf.json";
    string internal constant FILE_08_02 = "phase08_stage02_ttdol_q.json";
    string internal constant FILE_09_01 = "phase09_stage01_export_frontend.json";

    function _bindCreator(LaunchState storage s) internal {
        s.creator = deployer;
        require(s.creator != address(0), "PkgArgs.creator requires a deployer");
    }

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
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "uniV4DetfPkg");
        if (!ok || !_hasCode(a)) return false;
        s.uniV4DetfPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "curveQuadHookPkg");
        if (!ok || !_hasCode(a)) return false;
        s.curveQuadHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "orbitalHookPkg");
        if (ok && _hasCode(a)) s.orbitalHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "weightedHookPkg");
        if (ok && _hasCode(a)) s.weightedHookPkg = a;
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
        _keepOptionalUniV4Pkg(s);
        string memory json;
        json = vm.serializeAddress("g03", "cpHookPkg", s.cpHookPkg);
        json = vm.serializeAddress("g03", "uniV4SePkg", address(s.uniV4SePkg));
        json = vm.serializeAddress("g03", "bondNftVaultPkg", s.bondNftVaultPkg);
        json = vm.serializeAddress("g03", "rebasingClaimTokenPkg", s.rebasingClaimTokenPkg);
        json = vm.serializeAddress("g03", "uniV4DetfPkg", s.uniV4DetfPkg);
        json = vm.serializeAddress("g03", "curveQuadHookPkg", s.curveQuadHookPkg);
        json = vm.serializeAddress("g03", "orbitalHookPkg", s.orbitalHookPkg);
        json = vm.serializeAddress("g03", "weightedHookPkg", s.weightedHookPkg);
        json = vm.serializeAddress("g03", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeUint("g03", "chainId", block.chainid);
        _writeJson(json, FILE_UNIV4_PKGS);
    }

    function _keepOptionalUniV4Pkg(LaunchState storage s) private {
        address a;
        bool ok;
        if (s.orbitalHookPkg == address(0) || s.orbitalHookPkg.code.length == 0) {
            (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "orbitalHookPkg");
            if (ok && _hasCode(a)) s.orbitalHookPkg = a;
        }
        if (s.weightedHookPkg == address(0) || s.weightedHookPkg.code.length == 0) {
            (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "weightedHookPkg");
            if (ok && _hasCode(a)) s.weightedHookPkg = a;
        }
        if (s.uniV4DetfPkg == address(0) || s.uniV4DetfPkg.code.length == 0) {
            (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "uniV4DetfPkg");
            if (ok && _hasCode(a)) s.uniV4DetfPkg = a;
        }
    }

    function _loadMorphoBlue(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_MORPHO, "morphoBlueSePkg");
        if (!ok || !_hasCode(a)) return false;
        s.morphoBlueSePkg = a;
        (a, ok) = _readAddressSafe(FILE_MORPHO, "morpho");
        if (ok && _hasCode(a)) s.morpho = a;
        (a, ok) = _readAddressSafe(FILE_MORPHO, "morphoIrm");
        if (ok && _hasCode(a)) s.morphoIrm = a;
        (a, ok) = _readAddressSafe(FILE_MORPHO, "morphoOracle");
        if (ok && _hasCode(a)) s.morphoOracle = a;
        try vm.readFile(_artifactPath(FILE_MORPHO)) returns (string memory raw) {
            try vm.parseJsonBool(raw, ".morphoLocal") returns (bool local_) {
                s.morphoLocal = local_;
            } catch {}
        } catch {}
        if (
            !s.morphoLocal && _hasCode(s.morpho)
                && (RobinhoodCanonicalLib.morpho().code.length == 0 || s.morpho != RobinhoodCanonicalLib.morpho())
        ) {
            s.morphoLocal = true;
        }
        return true;
    }

    function _exportMorphoBlue(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g03c", "morpho", s.morpho);
        json = vm.serializeAddress("g03c", "morphoBlue", s.morpho);
        json = vm.serializeAddress("g03c", "morphoIrm", s.morphoIrm);
        json = vm.serializeAddress("g03c", "morphoOracle", s.morphoOracle);
        json = vm.serializeAddress("g03c", "morphoBlueSePkg", s.morphoBlueSePkg);
        json = vm.serializeBool("g03c", "morphoLocal", s.morphoLocal);
        json = vm.serializeUint("g03c", "chainId", block.chainid);
        _writeJson(json, FILE_MORPHO);
    }

    function _loadUniV3(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_UNIV3, "uniV3SePkg");
        if (!ok || !_hasCode(a)) return false;
        s.uniV3SePkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV3, "v3Factory");
        if (ok && _hasCode(a)) s.v3Factory = a;
        try vm.readFile(_artifactPath(FILE_UNIV3)) returns (string memory raw) {
            try vm.parseJsonBool(raw, ".v3Local") returns (bool local_) {
                s.v3Local = local_;
            } catch {}
        } catch {}
        if (
            !s.v3Local && _hasCode(s.v3Factory)
                && (RobinhoodCanonicalLib.v3Factory() == address(0)
                    || RobinhoodCanonicalLib.v3Factory().code.length == 0
                    || s.v3Factory != RobinhoodCanonicalLib.v3Factory())
        ) {
            s.v3Local = true;
        }
        return true;
    }

    function _exportUniV3(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g03d", "v3Factory", s.v3Factory);
        json = vm.serializeAddress("g03d", "uniswapV3Factory", s.v3Factory);
        json = vm.serializeAddress("g03d", "uniV3SePkg", s.uniV3SePkg);
        json = vm.serializeBool("g03d", "v3Local", s.v3Local);
        json = vm.serializeUint("g03d", "chainId", block.chainid);
        _writeJson(json, FILE_UNIV3);
    }

    function _loadTokens(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_TOKENS, "erc20MinterFacade");
        if (!ok || !_hasCode(a)) return false;
        s.erc20MinterFacade = a;
        (a, ok) = _readAddressSafe(FILE_TOKENS, "TTUSDG");
        if (!ok || !_hasCode(a)) return false;
        s.ttUSDG = a;
        (a, ok) = _readAddressSafe(FILE_TOKENS, "TTUSDE");
        if (!ok || !_hasCode(a)) return false;
        s.ttUSDE = a;
        (a, ok) = _readAddressSafe(FILE_TOKENS, "TTWETH");
        if (ok && _hasCode(a)) s.ttWETH = a;
        (a, ok) = _readAddressAliased(FILE_TOKENS, "DTF", "TTRICH");
        if (ok && _hasCode(a)) s.ttRICH = a;
        (a, ok) = _readAddressSafe(FILE_TOKENS, "tokenPkg");
        if (ok) s.tokenPkg = a;
        return true;
    }

    function _exportTokens(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g04", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeAddress("g04", "tokenPkg", s.tokenPkg);
        json = vm.serializeAddress("g04", "TTUSDG", s.ttUSDG);
        json = vm.serializeAddress("g04", "TTUSDE", s.ttUSDE);
        json = vm.serializeAddress("g04", "TTWETH", s.ttWETH);
        json = vm.serializeAddress("g04", "DTF", s.ttRICH);
        json = vm.serializeAddress("g04", "TTRICH", s.ttRICH);
        json = vm.serializeAddress("g04", "owner", owner);
        json = vm.serializeAddress("g04", "uiWallet", uiWallet);
        json = vm.serializeUint("g04", "chainId", block.chainid);
        _writeJson(json, FILE_TOKENS);
    }

    function _loadSevenTokens()
        internal
        view
        returns (
            address ttNVDA,
            address ttMSFT,
            address ttAAPL,
            address ttGOOGL,
            address ttAMZN,
            address ttMETA,
            address ttTSLA
        )
    {
        bool ok;
        (ttNVDA, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTNVDA");
        if (!(ok && _hasCode(ttNVDA))) ttNVDA = address(0);
        (ttMSFT, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTMSFT");
        if (!(ok && _hasCode(ttMSFT))) ttMSFT = address(0);
        (ttAAPL, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTAAPL");
        if (!(ok && _hasCode(ttAAPL))) ttAAPL = address(0);
        (ttGOOGL, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTGOOGL");
        if (!(ok && _hasCode(ttGOOGL))) ttGOOGL = address(0);
        (ttAMZN, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTAMZN");
        if (!(ok && _hasCode(ttAMZN))) ttAMZN = address(0);
        (ttMETA, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTMETA");
        if (!(ok && _hasCode(ttMETA))) ttMETA = address(0);
        (ttTSLA, ok) = _readAddressSafe(FILE_SEVEN_TOKENS, "TTTSLA");
        if (!(ok && _hasCode(ttTSLA))) ttTSLA = address(0);
    }

    function _exportSevenTokens(
        LaunchState storage s,
        address ttNVDA,
        address ttMSFT,
        address ttAAPL,
        address ttGOOGL,
        address ttAMZN,
        address ttMETA,
        address ttTSLA
    ) internal {
        string memory json;
        json = vm.serializeAddress("g04b", "TTNVDA", ttNVDA);
        json = vm.serializeAddress("g04b", "TTMSFT", ttMSFT);
        json = vm.serializeAddress("g04b", "TTAAPL", ttAAPL);
        json = vm.serializeAddress("g04b", "TTGOOGL", ttGOOGL);
        json = vm.serializeAddress("g04b", "TTAMZN", ttAMZN);
        json = vm.serializeAddress("g04b", "TTMETA", ttMETA);
        json = vm.serializeAddress("g04b", "TTTSLA", ttTSLA);
        json = vm.serializeAddress("g04b", "TTWETH", s.ttWETH);
        json = vm.serializeAddress("g04b", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeAddress("g04b", "tokenPkg", s.tokenPkg);
        json = vm.serializeAddress("g04b", "owner", owner);
        json = vm.serializeUint("g04b", "chainId", block.chainid);
        json = vm.serializeUint("g04b", "mintAmount", uint256(1_000_000 ether));
        _writeJson(json, FILE_SEVEN_TOKENS);
    }

    function _loadLeafPools(LaunchState storage s) internal returns (bool) {
        address a;
        bool ok;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "seUsdeWeth");
        if (!ok || !_hasCode(a)) return false;
        s.seUsdeWeth = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "seUsdgWeth");
        if (!ok || !_hasCode(a)) return false;
        s.seUsdgWeth = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "seUsdgUsde");
        if (!ok || !_hasCode(a)) return false;
        s.seUsdgUsde = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "rpUsdeWeth");
        if (ok) s.rpUsdeWeth = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "rpUsdgWeth");
        if (ok) s.rpUsdgWeth = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "rpUsdgUsde");
        if (ok) s.rpUsdgUsde = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "seRichWeth");
        if (ok && _hasCode(a)) s.seRichWeth = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "rpRichWeth");
        if (ok) s.rpRichWeth = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_POOLS, "v4Seeder");
        if (ok) s.v4Seeder = a;
        return true;
    }

    function _exportLeafPools(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g05", "seUsdeWeth", s.seUsdeWeth);
        json = vm.serializeAddress("g05", "seUsdgWeth", s.seUsdgWeth);
        json = vm.serializeAddress("g05", "seUsdgUsde", s.seUsdgUsde);
        json = vm.serializeAddress("g05", "rpUsdeWeth", s.rpUsdeWeth);
        json = vm.serializeAddress("g05", "rpUsdgWeth", s.rpUsdgWeth);
        json = vm.serializeAddress("g05", "rpUsdgUsde", s.rpUsdgUsde);
        json = vm.serializeAddress("g05", "seRichWeth", s.seRichWeth);
        json = vm.serializeAddress("g05", "rpRichWeth", s.rpRichWeth);
        json = vm.serializeAddress("g05", "v4Seeder", s.v4Seeder);
        json = vm.serializeUint("g05", "chainId", block.chainid);
        _writeJson(json, FILE_LEAF_POOLS);
    }

    function _loadLeafDetfsPartial(LaunchState storage s) internal {
        address a;
        bool ok;
        (a, ok) = _readAddressAny(FILE_LEAF_DETFS, "DTF-DETF", "UP", "TTCHIR");
        if (ok && _hasCode(a)) s.dtfDetf = a;
        (a, ok) = _readAddressAny(FILE_LEAF_DETFS, "DTF-CLAIM", "UPPER", "TTRICHIR");
        if (ok && _hasCode(a)) s.dtfClaim = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_DETFS, "TTDOL-Q");
        if (ok && _hasCode(a)) s.ttDolQ = a;
    }

    function _loadLeafDetfs(LaunchState storage s) internal returns (bool) {
        _loadLeafDetfsPartial(s);
        return _hasCode(s.dtfDetf) && _hasCode(s.ttDolQ);
    }

    function _exportLeafDetfs(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g06", "DTF-DETF", s.dtfDetf);
        json = vm.serializeAddress("g06", "DTF-CLAIM", s.dtfClaim);
        json = vm.serializeAddress("g06", "TTDOL-Q", s.ttDolQ);
        json = vm.serializeUint("g06", "chainId", block.chainid);
        _writeJson(json, FILE_LEAF_DETFS);
    }

    function _requireDtfArchitecture(LaunchState storage s) internal view {
        require(_hasCode(s.ttRICH), "DTF required (run Script_04)");
        require(_hasCode(s.ttWETH), "TTWETH required (run Script_04)");
        require(_hasCode(s.seRichWeth), "DTF/TTWETH SE required (run Script_05)");
    }

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

    function _requireFacade(LaunchState storage s) internal {
        address a = _loadAddr(FILE_04_02, "erc20MinterFacade");
        require(_hasCode(a), "run Phase 04 Stage 02 first");
        s.erc20MinterFacade = a;
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

    function _requireCoreTokens(LaunchState storage s) internal {
        s.ttUSDG = _loadAddr(FILE_07_01, "TTUSDG");
        s.ttUSDE = _loadAddr(FILE_07_01, "TTUSDE");
        s.ttWETH = _loadAddr(FILE_07_01, "TTWETH");
        s.ttRICH = _loadAddr(FILE_07_01, "DTF");
        s.tokenPkg = _loadAddr(FILE_07_01, "tokenPkg");
        require(_hasCode(s.ttRICH), "run Phase 07 Stage 01 first (DTF)");
        require(_hasCode(s.ttWETH), "run Phase 07 Stage 01 first (TTWETH)");
        require(_hasCode(s.ttUSDG), "run Phase 07 Stage 01 first (TTUSDG)");
        require(_hasCode(s.ttUSDE), "run Phase 07 Stage 01 first (TTUSDE)");
    }

    function _hydrateMag7(LaunchState storage s) internal {
        s.ttNVDA = _loadAddr(FILE_07_02, "TTNVDA");
        s.ttMSFT = _loadAddr(FILE_07_02, "TTMSFT");
        s.ttAAPL = _loadAddr(FILE_07_02, "TTAAPL");
        s.ttGOOGL = _loadAddr(FILE_07_02, "TTGOOGL");
        s.ttAMZN = _loadAddr(FILE_07_02, "TTAMZN");
        s.ttMETA = _loadAddr(FILE_07_02, "TTMETA");
        s.ttTSLA = _loadAddr(FILE_07_02, "TTTSLA");
    }

    function _requireDtfWethSe(LaunchState storage s) internal {
        s.seRichWeth = _loadAddr(FILE_07_03, "seRichWeth");
        s.rpRichWeth = _loadAddr(FILE_07_03, "rpRichWeth");
        s.v4Seeder = _loadAddr(FILE_07_03, "v4Seeder");
        require(_hasCode(s.seRichWeth), "run Phase 07 Stage 03 first");
    }

    function _requireUsdSes(LaunchState storage s) internal {
        s.seUsdeWeth = _loadAddr(FILE_07_04, "seUsdeWeth");
        s.seUsdgWeth = _loadAddr(FILE_07_04, "seUsdgWeth");
        s.seUsdgUsde = _loadAddr(FILE_07_04, "seUsdgUsde");
        s.rpUsdeWeth = _loadAddr(FILE_07_04, "rpUsdeWeth");
        s.rpUsdgWeth = _loadAddr(FILE_07_04, "rpUsdgWeth");
        s.rpUsdgUsde = _loadAddr(FILE_07_04, "rpUsdgUsde");
        address seeder = _loadAddr(FILE_07_04, "v4Seeder");
        if (_hasCode(seeder)) s.v4Seeder = seeder;
        require(_hasCode(s.seUsdeWeth) && _hasCode(s.seUsdgWeth) && _hasCode(s.seUsdgUsde), "run Phase 07 Stage 04 first");
    }

    function _hydrateMorphoHost(LaunchState storage s) internal {
        s.morpho = _loadAddr(FILE_01_05, "morpho");
        s.morphoIrm = _loadAddr(FILE_01_05, "morphoIrm");
        s.morphoOracle = _loadAddr(FILE_01_05, "morphoOracle");
        try vm.readFile(_artifactPath(FILE_01_05)) returns (string memory raw) {
            try vm.parseJsonBool(raw, ".morphoLocal") returns (bool local_) {
                s.morphoLocal = local_;
            } catch {}
        } catch {}
    }

    function _hydrateV3Factory(LaunchState storage s) internal {
        s.v3Factory = _loadAddr(FILE_01_04, "v3Factory");
        try vm.readFile(_artifactPath(FILE_01_04)) returns (string memory raw) {
            try vm.parseJsonBool(raw, ".v3Local") returns (bool local_) {
                s.v3Local = local_;
            } catch {}
        } catch {}
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

    function _exportFacade(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0402", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeUint("p0402", "chainId", block.chainid);
        _writeJson(json, FILE_04_02);
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

    function _exportCoreTokens(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0701", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeAddress("p0701", "tokenPkg", s.tokenPkg);
        json = vm.serializeAddress("p0701", "TTUSDG", s.ttUSDG);
        json = vm.serializeAddress("p0701", "TTUSDE", s.ttUSDE);
        json = vm.serializeAddress("p0701", "TTWETH", s.ttWETH);
        json = vm.serializeAddress("p0701", "DTF", s.ttRICH);
        json = vm.serializeAddress("p0701", "owner", owner);
        json = vm.serializeAddress("p0701", "uiWallet", uiWallet);
        json = vm.serializeUint("p0701", "chainId", block.chainid);
        _writeJson(json, FILE_07_01);
    }

    function _exportMag7(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0702", "TTNVDA", s.ttNVDA);
        json = vm.serializeAddress("p0702", "TTMSFT", s.ttMSFT);
        json = vm.serializeAddress("p0702", "TTAAPL", s.ttAAPL);
        json = vm.serializeAddress("p0702", "TTGOOGL", s.ttGOOGL);
        json = vm.serializeAddress("p0702", "TTAMZN", s.ttAMZN);
        json = vm.serializeAddress("p0702", "TTMETA", s.ttMETA);
        json = vm.serializeAddress("p0702", "TTTSLA", s.ttTSLA);
        json = vm.serializeAddress("p0702", "TTWETH", s.ttWETH);
        json = vm.serializeAddress("p0702", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeAddress("p0702", "tokenPkg", s.tokenPkg);
        json = vm.serializeAddress("p0702", "owner", owner);
        json = vm.serializeUint("p0702", "chainId", block.chainid);
        json = vm.serializeUint("p0702", "mintAmount", uint256(1_000_000 ether));
        _writeJson(json, FILE_07_02);
    }

    function _exportDtfWethSe(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0703", "seRichWeth", s.seRichWeth);
        json = vm.serializeAddress("p0703", "rpRichWeth", s.rpRichWeth);
        json = vm.serializeAddress("p0703", "v4Seeder", s.v4Seeder);
        json = vm.serializeUint("p0703", "chainId", block.chainid);
        _writeJson(json, FILE_07_03);
    }

    function _exportUsdSes(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0704", "seUsdeWeth", s.seUsdeWeth);
        json = vm.serializeAddress("p0704", "seUsdgWeth", s.seUsdgWeth);
        json = vm.serializeAddress("p0704", "seUsdgUsde", s.seUsdgUsde);
        json = vm.serializeAddress("p0704", "rpUsdeWeth", s.rpUsdeWeth);
        json = vm.serializeAddress("p0704", "rpUsdgWeth", s.rpUsdgWeth);
        json = vm.serializeAddress("p0704", "rpUsdgUsde", s.rpUsdgUsde);
        json = vm.serializeAddress("p0704", "v4Seeder", s.v4Seeder);
        json = vm.serializeUint("p0704", "chainId", block.chainid);
        _writeJson(json, FILE_07_04);
    }

    function _exportFeeDetf(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0801", "DTF-DETF", s.dtfDetf);
        json = vm.serializeAddress("p0801", "DTF-CLAIM", s.dtfClaim);
        json = vm.serializeUint("p0801", "chainId", block.chainid);
        _writeJson(json, FILE_08_01);
    }

    function _exportTtDolQ(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("p0802", "TTDOL-Q", s.ttDolQ);
        json = vm.serializeUint("p0802", "chainId", block.chainid);
        _writeJson(json, FILE_08_02);
    }

    function _loadPhasePriorForExport(LaunchState storage s) internal {
        _requireDiamondFactory(s);
        _requireHookFactory(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _requireFacade(s);
        _requireRateProviderPkg(s);
        _requireTwapOracle(s);
        _requireUniV4SePkg(s);
        s.uniV3SePkg = _loadAddr(FILE_05_04, "uniV3SePkg");
        s.morphoBlueSePkg = _loadAddr(FILE_05_05, "morphoBlueSePkg");
        _hydrateMorphoHost(s);
        _hydrateV3Factory(s);
        s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
        s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
        s.cpHookPkg = _loadAddr(FILE_06_03, "cpHookPkg");
        s.weightedHookPkg = _loadAddr(FILE_06_04, "weightedHookPkg");
        s.orbitalHookPkg = _loadAddr(FILE_06_05, "orbitalHookPkg");
        s.curveQuadHookPkg = _loadAddr(FILE_06_06, "curveQuadHookPkg");
        s.uniV4DetfPkg = _loadAddr(FILE_06_07, "uniV4DetfPkg");
        _requireCoreTokens(s);
        _hydrateMag7(s);
        _requireDtfWethSe(s);
        _requireUsdSes(s);
        s.dtfDetf = _loadAddr(FILE_08_01, "DTF-DETF");
        s.dtfClaim = _loadAddr(FILE_08_01, "DTF-CLAIM");
        s.ttDolQ = _loadAddr(FILE_08_02, "TTDOL-Q");
        require(_hasCode(s.dtfDetf), "run Phase 08 Stage 01 first");
        require(_hasCode(s.ttDolQ), "run Phase 08 Stage 02 first");
    }
}

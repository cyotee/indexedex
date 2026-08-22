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
/// @notice JSON hydrate helpers used by group scripts.
abstract contract LaunchIo is DeploymentBase {
    string internal constant FILE_PREFLIGHT = "00_preflight.json";
    string internal constant FILE_FACTORIES = "01_factories.json";
    string internal constant FILE_PLATFORM = "02_platform.json";
    string internal constant FILE_UNIV4_PKGS = "03_univ4_packages.json";
    string internal constant FILE_TOKENS = "04_tokens.json";
    string internal constant FILE_SEVEN_TOKENS = "04b_seven_test_tokens.json";
    string internal constant FILE_LEAF_POOLS = "05_leaf_pools_ses.json";
    string internal constant FILE_LEAF_DETFS = "06_leaf_detfs.json";
    string internal constant FILE_EXPORT = "09_export.json";

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
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "cpDetfPkg");
        if (!ok || !_hasCode(a)) return false;
        s.cpDetfPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "curveQuadHookPkg");
        if (!ok || !_hasCode(a)) return false;
        s.curveQuadHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "curveQuadDetfPkg");
        if (!ok || !_hasCode(a)) return false;
        s.curveQuadDetfPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "orbitalHookPkg");
        if (ok && _hasCode(a)) s.orbitalHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "orbitalDetfPkg");
        if (ok && _hasCode(a)) s.orbitalDetfPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "weightedHookPkg");
        if (ok && _hasCode(a)) s.weightedHookPkg = a;
        (a, ok) = _readAddressSafe(FILE_UNIV4_PKGS, "weightedDetfPkg");
        if (ok && _hasCode(a)) s.weightedDetfPkg = a;
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
        json = vm.serializeAddress("g03", "orbitalHookPkg", s.orbitalHookPkg);
        json = vm.serializeAddress("g03", "orbitalDetfPkg", s.orbitalDetfPkg);
        json = vm.serializeAddress("g03", "weightedHookPkg", s.weightedHookPkg);
        json = vm.serializeAddress("g03", "weightedDetfPkg", s.weightedDetfPkg);
        json = vm.serializeAddress("g03", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeUint("g03", "chainId", block.chainid);
        _writeJson(json, FILE_UNIV4_PKGS);
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
        (a, ok) = _readAddressSafe(FILE_TOKENS, "TTRICH");
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
        (a, ok) = _readAddressSafe(FILE_LEAF_DETFS, "TTCHIR");
        if (ok && _hasCode(a)) s.ttChir = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_DETFS, "TTRICHIR");
        if (ok && _hasCode(a)) s.ttRichir = a;
        (a, ok) = _readAddressSafe(FILE_LEAF_DETFS, "TTDOL-Q");
        if (ok && _hasCode(a)) s.ttDolQ = a;
    }

    function _loadLeafDetfs(LaunchState storage s) internal returns (bool) {
        _loadLeafDetfsPartial(s);
        return _hasCode(s.ttChir) && _hasCode(s.ttDolQ);
    }

    function _exportLeafDetfs(LaunchState storage s) internal {
        string memory json;
        json = vm.serializeAddress("g06", "TTCHIR", s.ttChir);
        json = vm.serializeAddress("g06", "TTRICHIR", s.ttRichir);
        json = vm.serializeAddress("g06", "TTDOL-Q", s.ttDolQ);
        json = vm.serializeUint("g06", "chainId", block.chainid);
        _writeJson(json, FILE_LEAF_DETFS);
    }

    function _requireChirArchitecture(LaunchState storage s) internal view {
        require(_hasCode(s.ttRICH), "TTRICH required (run Script_04)");
        require(_hasCode(s.ttWETH), "TTWETH required (run Script_04)");
        require(_hasCode(s.seRichWeth), "TTRICH/TTWETH SE required (run Script_05)");
    }
}

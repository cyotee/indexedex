// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";

import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWgtHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WgtFS
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

import {
    IUniswapV4SingleStandardExchangeBufferHookPackage as ISinglePkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as SingleFS
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeDETDFPkg,
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg,
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @title Script_13_DeployInertDemos
/// @notice Weighted n=8 buffer, single SE buffers, CP/Orbital/Weighted gentle + launch-rich inert DETFs.
/// @dev NEVER calls bond / first-bond.
contract Script_13_DeployInertDemos is DeploymentBase {
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant HOOK_FACTORY_FILE = "03_hook_factory.json";
    string internal constant TOKENS_FILE = "04_test_tokens.json";
    string internal constant V3_SE_FILE = "07_univ3_se.json";
    string internal constant V4_SE_FILE = "08_univ4_se.json";
    string internal constant RP_FILE = "09_rate_providers.json";
    string internal constant HOOK_PKGS_FILE = "10_hook_packages.json";
    string internal constant DETF_PKGS_FILE = "12_detf_packages.json";
    string internal constant ARTIFACT_FILE = "13_inert_demos.json";

    address private indexedexManager;
    IUniswapV4HookDiamondPackageCallBackFactory private hookFactory;
    address[8] private tt;
    address private uniV3Se;
    address private uniV4Se;
    address private rpV3;
    address private rpV4;

    address private weightedBufferN8;
    address private singleSeBuffer_v3;
    address private singleSeBuffer_v4;
    address private cpDetfGentle;
    address private cpDetfLaunchRich;
    address private orbitalDetfGentle;
    address private orbitalDetfLaunchRich;
    address private weightedDetfGentle;
    address private weightedDetfLaunchRich;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 13: Inert demos (no bond)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployWeightedBufferN8();
        _deploySingleSeBuffers();
        _deployCpDetfs();
        _deployOrbitalDetfs();
        _deployWeightedDetfs();
        vm.stopBroadcast();

        _assertInert(cpDetfGentle);
        _assertInert(cpDetfLaunchRich);
        _assertInert(orbitalDetfGentle);
        _assertInert(orbitalDetfLaunchRich);
        _assertInert(weightedDetfGentle);
        _assertInert(weightedDetfLaunchRich);

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        indexedexManager = _readAddress(CORE_FILE, "indexedexManager");
        hookFactory = IUniswapV4HookDiamondPackageCallBackFactory(_readAddress(HOOK_FACTORY_FILE, "hookFactory"));
        for (uint8 i; i < 8; ++i) {
            tt[i] = _readAddress(TOKENS_FILE, FixtureGraph.tokenSymbol(i));
        }
        uniV3Se = _readAddress(V3_SE_FILE, "uniV3Se_tt0_tt1");
        uniV4Se = _readAddress(V4_SE_FILE, "uniV4Se_tt4_tt5");
        rpV3 = _readAddress(RP_FILE, "rp_v3Se_tt0_tt1");
        rpV4 = _readAddress(RP_FILE, "rp_v4Se_tt4_tt5");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address w, bool okW) = _readAddressSafe(ARTIFACT_FILE, "weightedBufferN8");
        (address c, bool okC) = _readAddressSafe(ARTIFACT_FILE, "cpDetfGentle");
        (address o, bool okO) = _readAddressSafe(ARTIFACT_FILE, "orbitalDetfGentle");
        (address d, bool okD) = _readAddressSafe(ARTIFACT_FILE, "weightedDetfGentle");
        if (!(okW && okC && okO && okD)) return false;
        if (w.code.length == 0 || c.code.length == 0 || o.code.length == 0 || d.code.length == 0) return false;
        weightedBufferN8 = w;
        cpDetfGentle = c;
        orbitalDetfGentle = o;
        weightedDetfGentle = d;
        (singleSeBuffer_v3,) = _readAddressSafe(ARTIFACT_FILE, "singleSeBuffer_v3");
        (singleSeBuffer_v4,) = _readAddressSafe(ARTIFACT_FILE, "singleSeBuffer_v4");
        (cpDetfLaunchRich,) = _readAddressSafe(ARTIFACT_FILE, "cpDetfLaunchRich");
        (orbitalDetfLaunchRich,) = _readAddressSafe(ARTIFACT_FILE, "orbitalDetfLaunchRich");
        (weightedDetfLaunchRich,) = _readAddressSafe(ARTIFACT_FILE, "weightedDetfLaunchRich");
        return true;
    }

    function _deployWeightedBufferN8() internal {
        // FORCE re-runs: reuse on-chain hook (same CREATE3 salt) — re-join / re-init reverts.
        (address existing,) = _readAddressSafe(ARTIFACT_FILE, "weightedBufferN8");
        if (existing != address(0) && existing.code.length > 0) {
            weightedBufferN8 = existing;
            vm.label(weightedBufferN8, "weightedBufferN8");
            return;
        }

        IWgtHookPkg pkg = IWgtHookPkg(_readAddress(HOOK_PKGS_FILE, "weightedHookPkg"));

        address[] memory tokens = new address[](8);
        uint256[] memory weights = new uint256[](8);
        address[] memory ses = new address[](8);
        address[] memory rps = new address[](8);

        for (uint256 i; i < 8; ++i) {
            tokens[i] = tt[i];
            weights[i] = FixtureGraph.EQUAL_WEIGHT_N8;
        }

        // Package requires strictly ascending token addresses (TokensNotAscending).
        for (uint256 i; i < 8; ++i) {
            for (uint256 j = i + 1; j < 8; ++j) {
                if (tokens[j] < tokens[i]) {
                    (tokens[i], tokens[j]) = (tokens[j], tokens[i]);
                }
            }
        }

        // Map SE/RP after sort: TT0 → V3 SE + RP; TT4 → V4 SE + RP.
        for (uint256 i; i < 8; ++i) {
            if (tokens[i] == tt[0]) {
                ses[i] = uniV3Se;
                rps[i] = rpV3;
            } else if (tokens[i] == tt[4]) {
                ses[i] = uniV4Se;
                rps[i] = rpV4;
            }
        }

        IWgtHookPkg.PkgArgs memory args = IWgtHookPkg.PkgArgs({
            poolManager: RobinhoodCanonicalLib.poolManager(),
            feeOracle: indexedexManager,
            n: 8,
            tokens: tokens,
            weights: weights,
            standardExchanges: ses,
            rateProviders: rps
        });

        uint256 mineNonce = WgtFS.findMineNonce(hookFactory, pkg, args);
        weightedBufferN8 = WgtFS.deployHook(pkg, args, mineNonce);
        vm.label(weightedBufferN8, "weightedBufferN8");

        // Seed doors: proportional join with small equal amounts
        IUniswapV4StandardExchangeWeightedBufferHook w =
            IUniswapV4StandardExchangeWeightedBufferHook(weightedBufferN8);
        uint256 n = w.numTokens();
        require(n == 8, "weighted buffer n != 8");

        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = 1_000e18;
            address tok = w.token(i);
            IERC20(tok).approve(weightedBufferN8, type(uint256).max);
            if (w.standardExchange(i) != address(0)) {
                IERC20(tok).approve(w.standardExchange(i), type(uint256).max);
            }
        }
        // Doors are initialized by the product on first join; do not pre-init (PoolAlreadyInitialized
        // during forge broadcast simulation is noisy and can abort multicall estimation).
        w.joinProportional(amounts, deployer, 0, block.timestamp + 1 days);
    }

    function _deploySingleSeBuffers() internal {
        ISinglePkg pkg = ISinglePkg(_readAddress(HOOK_PKGS_FILE, "singleSeBufferHookPkg"));
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());

        {
            (address existing,) = _readAddressSafe(ARTIFACT_FILE, "singleSeBuffer_v3");
            if (existing != address(0) && existing.code.length > 0) {
                singleSeBuffer_v3 = existing;
                vm.label(singleSeBuffer_v3, "singleSeBuffer_v3");
            } else {
                ISinglePkg.PkgArgs memory args = ISinglePkg.PkgArgs({
                    poolManager: address(pm),
                    standardExchange: uniV3Se,
                    pairToken: tt[0]
                });
                uint256 mineNonce = SingleFS.findMineNonce(hookFactory, pkg, args);
                singleSeBuffer_v3 = SingleFS.deployHook(pkg, args, mineNonce);
                vm.label(singleSeBuffer_v3, "singleSeBuffer_v3");
                _initSingleSePool(singleSeBuffer_v3, uniV3Se, tt[0], pm);
            }
        }
        {
            (address existing,) = _readAddressSafe(ARTIFACT_FILE, "singleSeBuffer_v4");
            if (existing != address(0) && existing.code.length > 0) {
                singleSeBuffer_v4 = existing;
                vm.label(singleSeBuffer_v4, "singleSeBuffer_v4");
            } else {
                ISinglePkg.PkgArgs memory args = ISinglePkg.PkgArgs({
                    poolManager: address(pm),
                    standardExchange: uniV4Se,
                    pairToken: tt[4]
                });
                uint256 mineNonce = SingleFS.findMineNonce(hookFactory, pkg, args);
                singleSeBuffer_v4 = SingleFS.deployHook(pkg, args, mineNonce);
                vm.label(singleSeBuffer_v4, "singleSeBuffer_v4");
                _initSingleSePool(singleSeBuffer_v4, uniV4Se, tt[4], pm);
            }
        }
    }

    function _initSingleSePool(address hook, address se, address pairToken, IPoolManager pm) internal {
        (address c0, address c1) =
            pairToken < se ? (pairToken, se) : (se, pairToken);
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        try pm.initialize(key, FixtureGraph.SQRT_PRICE_1_1) {} catch {}
    }

    function _deployCpDetfs() internal {
        IUniswapV4SingleStandardExchangeDETDFPkg pkg =
            IUniswapV4SingleStandardExchangeDETDFPkg(_readAddress(DETF_PKGS_FILE, "cpDetfPkg"));

        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory gentle = IUniswapV4SingleStandardExchangeDETDFPkg
            .PkgArgs({
            name: "Gentle UniV4 ConstProd DETF",
            symbol: "gConstProdDETF",
            standardExchangeVault: IStandardExchangeProxy(uniV3Se),
            standardExchangeVaultShare: IERC20(address(0)),
            pairToken: IERC20(tt[0]),
            creationPairPerDetfWad: FixtureGraph.DEFAULT_CREATION_PAIR_PER_DETF,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
        cpDetfGentle = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(gentle)
        );
        vm.label(cpDetfGentle, "cpDetfGentle");

        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory rich = gentle;
        rich.name = "LaunchRich UniV4 ConstProd DETF";
        rich.symbol = "lrConstProdDETF";
        rich.standardExchangeVault = IStandardExchangeProxy(uniV4Se);
        rich.pairToken = IERC20(tt[4]);
        rich.expansionClosureRatePerYearWad = FixtureGraph.LAUNCH_RICH_R;
        cpDetfLaunchRich = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(rich)
        );
        vm.label(cpDetfLaunchRich, "cpDetfLaunchRich");
    }

    function _deployOrbitalDetfs() internal {
        IUniswapV4StandardExchangeOrbitalDETDFPkg pkg =
            IUniswapV4StandardExchangeOrbitalDETDFPkg(_readAddress(DETF_PKGS_FILE, "orbitalDetfPkg"));

        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory gentle = IUniswapV4StandardExchangeOrbitalDETDFPkg
            .PkgArgs({
            name: "Gentle UniV4 Orb DETF",
            symbol: "gOrbDETF",
            pairToken0: IERC20(tt[0]),
            pairToken1: IERC20(tt[4]),
            standardExchange0: IStandardExchangeProxy(uniV3Se),
            standardExchange1: IStandardExchangeProxy(uniV4Se),
            vaultShare0: IERC20(address(0)),
            vaultShare1: IERC20(address(0)),
            rateProvider0: rpV3,
            rateProvider1: rpV4,
            rateAsset: IERC20(address(0)),
            detfBindingIndex: 2,
            creationPair0PerDetfWad: FixtureGraph.DEFAULT_CREATION_PAIR_PER_DETF,
            creationPair1PerDetfWad: FixtureGraph.DEFAULT_CREATION_PAIR_PER_DETF,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
        orbitalDetfGentle = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(gentle)
        );
        vm.label(orbitalDetfGentle, "orbitalDetfGentle");

        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory rich = gentle;
        rich.name = "LaunchRich UniV4 Orb DETF";
        rich.symbol = "lrOrbDETF";
        rich.expansionClosureRatePerYearWad = FixtureGraph.LAUNCH_RICH_R;
        orbitalDetfLaunchRich = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(rich)
        );
        vm.label(orbitalDetfLaunchRich, "orbitalDetfLaunchRich");
    }

    function _deployWeightedDetfs() internal {
        IUniswapV4StandardExchangeWeightedDETDFPkg pkg =
            IUniswapV4StandardExchangeWeightedDETDFPkg(_readAddress(DETF_PKGS_FILE, "weightedDetfPkg"));

        // n=8 = DETF self + 7 externals TT0..TT6
        IERC20[] memory pairs = new IERC20[](7);
        IStandardExchangeProxy[] memory ses = new IStandardExchangeProxy[](7);
        IERC20[] memory shares = new IERC20[](7);
        address[] memory rps = new address[](7);
        uint256[] memory pairW = new uint256[](7);
        uint256[] memory rates = new uint256[](7);

        for (uint256 i; i < 7; ++i) {
            pairs[i] = IERC20(tt[i]);
            pairW[i] = FixtureGraph.EQUAL_WEIGHT_N8; // 0.125 each external; detfWeight 0.125
            rates[i] = FixtureGraph.DEFAULT_CREATION_PAIR_PER_DETF;
        }
        // V3 SE on TT0, V4 SE on TT4
        ses[0] = IStandardExchangeProxy(uniV3Se);
        rps[0] = rpV3;
        ses[4] = IStandardExchangeProxy(uniV4Se);
        rps[4] = rpV4;

        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory gentle = IUniswapV4StandardExchangeWeightedDETDFPkg
            .PkgArgs({
            name: "Gentle UniV4 Wgt DETF n8",
            symbol: "gWgtDETF",
            pairTokens: pairs,
            standardExchanges: ses,
            vaultShares: shares,
            rateProviders: rps,
            detfWeight: FixtureGraph.EQUAL_WEIGHT_N8,
            pairWeights: pairW,
            creationPairPerDetfWad: rates,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
        weightedDetfGentle = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(gentle)
        );
        vm.label(weightedDetfGentle, "weightedDetfGentle");

        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory rich = gentle;
        rich.name = "LaunchRich UniV4 Wgt DETF n8";
        rich.symbol = "lrWgtDETF";
        rich.expansionClosureRatePerYearWad = FixtureGraph.LAUNCH_RICH_R;
        weightedDetfLaunchRich = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(address(pkg)), abi.encode(rich)
        );
        vm.label(weightedDetfLaunchRich, "weightedDetfLaunchRich");
    }

    function _assertInert(address detf) internal view {
        require(detf.code.length > 0, "detf no code");
        // isReserveLive if exposed
        try IUniswapV4SingleStandardExchangeDETF(detf).isReserveLive() returns (bool live) {
            require(!live, "detf unexpectedly live");
        } catch {}
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("demos", "weightedBufferN8", weightedBufferN8);
        json = vm.serializeAddress("demos", "singleSeBuffer_v3", singleSeBuffer_v3);
        json = vm.serializeAddress("demos", "singleSeBuffer_v4", singleSeBuffer_v4);
        json = vm.serializeAddress("demos", "cpDetfGentle", cpDetfGentle);
        json = vm.serializeAddress("demos", "cpDetfLaunchRich", cpDetfLaunchRich);
        json = vm.serializeAddress("demos", "orbitalDetfGentle", orbitalDetfGentle);
        json = vm.serializeAddress("demos", "orbitalDetfLaunchRich", orbitalDetfLaunchRich);
        json = vm.serializeAddress("demos", "weightedDetfGentle", weightedDetfGentle);
        json = vm.serializeAddress("demos", "weightedDetfLaunchRich", weightedDetfLaunchRich);
        json = vm.serializeUint("demos", "weightedBufferN", 8);
        json = vm.serializeUint("demos", "weightedDetfN", 8);
        json = vm.serializeUint("demos", "chainId", block.chainid);
        json = vm.serializeString(
            "demos",
            "notes",
            "Inert only; no bond. Weighted n=8: V3 SE on TT0, V4 SE on TT4. ConstProd: V3 gentle / V4 launch-rich."
        );
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("weightedBufferN8:", weightedBufferN8);
        _logAddress("cpDetfGentle:", cpDetfGentle);
        _logAddress("weightedDetfGentle:", weightedDetfGentle);
        _logComplete("Stage 13");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {PoolSeedLib} from "./PoolSeedLib.sol";
import {RichnessLib} from "./RichnessLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    UniswapV4DetfHookPremineLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol";
import {UniswapV4DetfScriptWireLib} from "scripts/foundry/UniswapV4DetfScriptWireLib.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title Stage_07_NestDETFs
/// @notice IdxQ/USDG SE + TTBETA-O + TTIDX-WRAP. TTM7-W / TTNEST-W / TTM7-WRAP omitted (weighted demo dropped).
/// @dev Premine helpers are view. Call them *before* `startBroadcast`.
library Stage_07_NestDETFs {
    function deployPoolsAndSes(LaunchState storage s) internal {
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());
        PoolKey memory keyQ = PoolSeedLib.buildKey(s.ttIdxQ, s.ttUSDG);
        PoolSeedLib.initEmpty(pm, keyQ);
        s.seIdxUsdg = s.uniV4SePkg.deployVault(keyQ, FixtureEconomics.SE_WIDTH_MULTIPLIER);
        s.rpIdxUsdg = address(s.rateProviderPkg.deployRateProvider(IStandardExchange(s.seIdxUsdg), IERC20(s.ttIdxQ)));
    }

    function ensureBondCapital(LaunchState storage s, address bonder) internal {
        uint256 need = FixtureEconomics.NEST_FIRST_BOND;
        RichnessLib.ensureBalance(s.ttNvdaSmhO, s.ttNVDA, need, bonder);
        RichnessLib.ensureBalance(s.ttIdxQ, s.ttSPY, need, bonder);
    }

    function premineBetaO(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineOrbital(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4StandardExchangeOrbitalDETDFPkg(s.orbitalDetfPkg),
            IUniswapV4StandardExchangeOrbitalBufferHookPackage(s.orbitalHookPkg),
            _betaOArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function premineIdxWrap(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineCp(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg),
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(s.cpHookPkg),
            _idxWrapArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployBetaO(LaunchState storage s, address bonder, uint256 nonce) internal {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _betaOArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.orbitalDetfPkg), abi.encode(args, uint256(0))
        );
        s.ttBetaO = IUniswapV4StandardExchangeOrbitalDETDFPkg(s.orbitalDetfPkg).deployVault(args, nonce);
        require(s.ttBetaO == predicted, "detf != predicted");
        UniswapV4DetfScriptWireLib._wireOrbital(s.ttBetaO);
        RichnessLib.firstBondOrbital(
            s.ttBetaO,
            IERC20(s.ttNvdaSmhO),
            FixtureEconomics.NEST_FIRST_BOND,
            IERC20(s.ttIdxQ),
            FixtureEconomics.NEST_FIRST_BOND,
            bonder
        );
        address[] memory pairs = new address[](2);
        pairs[0] = s.ttNvdaSmhO;
        pairs[1] = s.ttIdxQ;
        _refillInnersForEnrich(s, s.ttBetaO, pairs, bonder);
        RichnessLib.enrichMulti(s.ttBetaO, pairs, bonder);
    }

    function deployIdxWrap(LaunchState storage s, address bonder, uint256 nonce) internal {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _idxWrapArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.cpDetfPkg), abi.encode(args, uint256(0))
        );
        s.ttIdxWrap = IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg).deployVault(args, nonce);
        require(s.ttIdxWrap == predicted, "detf != predicted");
        UniswapV4DetfScriptWireLib._wireCp(s.ttIdxWrap);
        RichnessLib.firstBondCp(s.ttIdxWrap, IERC20(s.ttIdxQ), FixtureEconomics.NEST_FIRST_BOND, bonder);
        address[] memory pairs = new address[](1);
        pairs[0] = s.ttIdxQ;
        _refillInnersForEnrich(s, s.ttIdxWrap, pairs, bonder);
        RichnessLib.enrichCp(s.ttIdxWrap, s.ttIdxQ, bonder);
    }

    function _betaOArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args.name = "Test DETF Beta Nest";
        args.symbol = "TTBETA-O";
        args.pairToken0 = IERC20(s.ttNvdaSmhO);
        args.pairToken1 = IERC20(s.ttIdxQ);
        args.standardExchange0 = IStandardExchangeProxy(address(0));
        args.standardExchange1 = IStandardExchangeProxy(s.seIdxUsdg);
        args.vaultShare0 = IERC20(address(0));
        args.vaultShare1 = IERC20(address(0));
        args.rateProvider0 = address(0);
        args.rateProvider1 = s.rpIdxUsdg;
        args.rateAsset = IERC20(s.ttIdxQ);
        args.detfBindingIndex = FixtureEconomics.ORBITAL_DETF_BINDING;
        args.creationPair0PerDetfWad = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.creationPair1PerDetfWad = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
    }

    function _idxWrapArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args.name = "Test DETF Index Wrap";
        args.symbol = "TTIDX-WRAP";
        args.standardExchangeVault = IStandardExchangeProxy(s.seIdxUsdg);
        args.standardExchangeVaultShare = IERC20(address(0));
        args.pairToken = IERC20(s.ttIdxQ);
        args.creationPairPerDetfWad = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
    }

    function _refillInnersForEnrich(
        LaunchState storage s,
        address nest,
        address[] memory inners,
        address bonder
    ) private {
        for (uint256 i; i < inners.length; ++i) {
            uint256 need = RichnessLib.previewPairNeed(nest, inners[i]);
            if (need == 0) continue;
            address capital = _leafCapital(s, inners[i]);
            RichnessLib.ensureBalance(inners[i], capital, need, bonder);
        }
    }

    function _leafCapital(LaunchState storage s, address inner) private view returns (address) {
        if (inner == s.ttNvdaS || inner == s.ttNvdaSmhO) return s.ttNVDA;
        if (inner == s.ttIdxQ) return s.ttSPY;
        revert("07: unknown inner detfToken");
    }
}

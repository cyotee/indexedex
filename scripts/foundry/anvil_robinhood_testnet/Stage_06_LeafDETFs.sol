// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {RichnessLib} from "./RichnessLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
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
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

/// @title Stage_06_LeafDETFs
/// @notice Four leaf DETFs + first-bond + D47. TTM7-W omitted from this demo.
library Stage_06_LeafDETFs {
    function enrichAll(LaunchState storage s, address bonder) internal {
        enrichNvdaS(s, bonder);
        enrichNvdaSmhO(s, bonder);
        enrichIdxQ(s, bonder);
        enrichDolQ(s, bonder);
    }

    function premineNvdaS(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineCp(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg),
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(s.cpHookPkg),
            _nvdaSArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployNvdaS(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 TTNVDA-S deploy+bond+D47");
        _deployNvdaS(s, bonder, nonce);
        enrichNvdaS(s, bonder);
    }

    function enrichNvdaS(LaunchState storage s, address bonder) internal {
        RichnessLib.enrichCp(s.ttNvdaS, s.ttNVDA, bonder);
    }

    function premineNvdaSmhO(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineOrbital(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4StandardExchangeOrbitalDETDFPkg(s.orbitalDetfPkg),
            IUniswapV4StandardExchangeOrbitalBufferHookPackage(s.orbitalHookPkg),
            _nvdaSmhOArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployNvdaSmhO(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 TTNVDA-SMH-O deploy+bond+D47");
        _deployNvdaSmhO(s, bonder, nonce);
        enrichNvdaSmhO(s, bonder);
    }

    function enrichNvdaSmhO(LaunchState storage s, address bonder) internal {
        address[] memory pairs = new address[](2);
        pairs[0] = s.ttNVDA;
        pairs[1] = s.ttSMH;
        RichnessLib.enrichMulti(s.ttNvdaSmhO, pairs, bonder);
    }

    function premineIdxQ(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineQuad(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4StandardExchangeCurveQuadStableDETDFPkg(s.curveQuadDetfPkg),
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(s.curveQuadHookPkg),
            _idxQArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployIdxQ(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 TTIDX-Q deploy+bond+D47");
        _deployIdxQ(s, bonder, nonce);
        enrichIdxQ(s, bonder);
    }

    function enrichIdxQ(LaunchState storage s, address bonder) internal {
        address[] memory pairs = new address[](3);
        pairs[0] = s.ttSPY;
        pairs[1] = s.ttVTI;
        pairs[2] = s.ttQQQ;
        RichnessLib.enrichMulti(s.ttIdxQ, pairs, bonder);
    }

    function premineDolQ(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineQuad(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4StandardExchangeCurveQuadStableDETDFPkg(s.curveQuadDetfPkg),
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(s.curveQuadHookPkg),
            _dolQArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployDolQ(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 TTDOL-Q deploy+bond+D47");
        _deployDolQ(s, bonder, nonce);
        enrichDolQ(s, bonder);
    }

    function enrichDolQ(LaunchState storage s, address bonder) internal {
        address[] memory pairs = new address[](3);
        pairs[0] = s.ttUSDE;
        pairs[1] = s.ttUSDG;
        pairs[2] = RobinhoodCanonicalLib.weth();
        RichnessLib.enrichMulti(s.ttDolQ, pairs, bonder);
    }

    function _nvdaSArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args.name = "Test DETF NVDA Single";
        args.symbol = "TTNVDA-S";
        args.standardExchangeVault = IStandardExchangeProxy(s.seNvdaUsdg);
        args.standardExchangeVaultShare = IERC20(address(0));
        args.pairToken = IERC20(s.ttNVDA);
        args.creationPairPerDetfWad = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
    }

    function _deployNvdaS(LaunchState storage s, address bonder, uint256 nonce) private {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _nvdaSArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.cpDetfPkg), abi.encode(args, uint256(0))
        );
        s.ttNvdaS = IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg).deployVault(args, nonce);
        require(s.ttNvdaS == predicted, "detf != predicted");
        UniswapV4DetfScriptWireLib._wireCp(s.ttNvdaS);
        RichnessLib.firstBondCp(s.ttNvdaS, IERC20(s.ttNVDA), FixtureEconomics.LEAF_FIRST_BOND, bonder);
    }

    function _nvdaSmhOArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args.name = "Test DETF NVDA SMH Orbital";
        args.symbol = "TTNVDA-SMH-O";
        args.pairToken0 = IERC20(s.ttNVDA);
        args.pairToken1 = IERC20(s.ttSMH);
        args.standardExchange0 = IStandardExchangeProxy(s.seNvdaUsdg);
        args.standardExchange1 = IStandardExchangeProxy(address(0));
        args.vaultShare0 = IERC20(address(0));
        args.vaultShare1 = IERC20(address(0));
        args.rateProvider0 = s.rpNvdaUsdg;
        args.rateProvider1 = address(0);
        args.rateAsset = IERC20(s.ttNVDA);
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

    function _deployNvdaSmhO(LaunchState storage s, address bonder, uint256 nonce) private {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _nvdaSmhOArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.orbitalDetfPkg), abi.encode(args, uint256(0))
        );
        console2.log("06b calling orbital deployVault (premined nonce)", nonce);
        s.ttNvdaSmhO = IUniswapV4StandardExchangeOrbitalDETDFPkg(s.orbitalDetfPkg).deployVault(args, nonce);
        require(s.ttNvdaSmhO == predicted, "detf != predicted");
        console2.log("06b deployVault done", s.ttNvdaSmhO);
        UniswapV4DetfScriptWireLib._wireOrbital(s.ttNvdaSmhO);
        RichnessLib.firstBondOrbital(
            s.ttNvdaSmhO,
            IERC20(s.ttNVDA),
            FixtureEconomics.LEAF_FIRST_BOND,
            IERC20(s.ttSMH),
            FixtureEconomics.LEAF_FIRST_BOND,
            bonder
        );
    }

    function _idxQArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _quadBase("Test DETF Index Quad", "TTIDX-Q");
        args.pairTokens = new IERC20[](3);
        args.pairTokens[0] = IERC20(s.ttSPY);
        args.pairTokens[1] = IERC20(s.ttVTI);
        args.pairTokens[2] = IERC20(s.ttQQQ);
        args.standardExchanges = new IStandardExchangeProxy[](3);
        args.standardExchanges[0] = IStandardExchangeProxy(s.seSpyUsdg);
        args.vaultShares = new IERC20[](3);
        args.rateProviders = new address[](3);
        args.rateProviders[0] = s.rpSpyUsdg;
        args.creationPairPerDetfWad = _threeCreation();
    }

    function _deployIdxQ(LaunchState storage s, address bonder, uint256 nonce) private {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _idxQArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.curveQuadDetfPkg), abi.encode(args, uint256(0))
        );
        console2.log("06c calling quad deployVault (premined nonce)", nonce);
        s.ttIdxQ = IUniswapV4StandardExchangeCurveQuadStableDETDFPkg(s.curveQuadDetfPkg).deployVault(args, nonce);
        require(s.ttIdxQ == predicted, "detf != predicted");
        console2.log("06c deployVault done", s.ttIdxQ);
        UniswapV4DetfScriptWireLib._wireQuad(s.ttIdxQ);
        IERC20[] memory ins = new IERC20[](3);
        uint256[] memory amts = new uint256[](3);
        ins[0] = IERC20(s.ttSPY);
        ins[1] = IERC20(s.ttVTI);
        ins[2] = IERC20(s.ttQQQ);
        amts[0] = FixtureEconomics.LEAF_FIRST_BOND;
        amts[1] = FixtureEconomics.LEAF_FIRST_BOND;
        amts[2] = FixtureEconomics.LEAF_FIRST_BOND;
        RichnessLib.firstBondMulti(s.ttIdxQ, ins, amts, s.ttSPY, bonder);
    }

    function _dolQArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        address weth = RobinhoodCanonicalLib.weth();
        args = _quadBase("Test DETF Dollar Quad", "TTDOL-Q");
        args.pairTokens = new IERC20[](3);
        args.pairTokens[0] = IERC20(s.ttUSDE);
        args.pairTokens[1] = IERC20(s.ttUSDG);
        args.pairTokens[2] = IERC20(weth);
        args.standardExchanges = new IStandardExchangeProxy[](3);
        // SE[i] must contain pairTokens[i] (`PairTokenNotInSeTokens`).
        args.standardExchanges[0] = IStandardExchangeProxy(s.seUsdeWeth);
        args.standardExchanges[1] = IStandardExchangeProxy(s.seUsdgUsde);
        args.standardExchanges[2] = IStandardExchangeProxy(s.seUsdgWeth);
        args.vaultShares = new IERC20[](3);
        args.rateProviders = new address[](3);
        args.rateProviders[0] = s.rpUsdeWeth;
        args.rateProviders[1] = s.rpUsdgUsde;
        args.rateProviders[2] = s.rpUsdgWeth;
        args.creationPairPerDetfWad = _threeCreation();
    }

    function _deployDolQ(LaunchState storage s, address bonder, uint256 nonce) private {
        address weth = RobinhoodCanonicalLib.weth();
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _dolQArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.curveQuadDetfPkg), abi.encode(args, uint256(0))
        );
        console2.log("06e calling quad deployVault (premined nonce)", nonce);
        s.ttDolQ = IUniswapV4StandardExchangeCurveQuadStableDETDFPkg(s.curveQuadDetfPkg).deployVault(args, nonce);
        require(s.ttDolQ == predicted, "detf != predicted");
        console2.log("06e deployVault done", s.ttDolQ);
        UniswapV4DetfScriptWireLib._wireQuad(s.ttDolQ);
        IERC20[] memory ins = new IERC20[](3);
        uint256[] memory amts = new uint256[](3);
        ins[0] = IERC20(s.ttUSDE);
        ins[1] = IERC20(s.ttUSDG);
        ins[2] = IERC20(weth);
        amts[0] = FixtureEconomics.TTDOL_FIRST_BOND;
        amts[1] = FixtureEconomics.TTDOL_FIRST_BOND;
        amts[2] = FixtureEconomics.TTDOL_FIRST_BOND;
        RichnessLib.firstBondMulti(s.ttDolQ, ins, amts, s.ttUSDG, bonder);
    }

    function _quadBase(string memory name_, string memory symbol_)
        private
        pure
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args.name = name_;
        args.symbol = symbol_;
        args.baseAmp = FixtureEconomics.BASE_AMP;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
    }

    function _threeCreation() private pure returns (uint256[] memory rates) {
        rates = new uint256[](3);
        rates[0] = FixtureEconomics.CREATION_PAIR_PER_DETF;
        rates[1] = FixtureEconomics.CREATION_PAIR_PER_DETF;
        rates[2] = FixtureEconomics.CREATION_PAIR_PER_DETF;
    }
}

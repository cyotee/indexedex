// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {RichnessLib} from "./RichnessLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
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
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

/// @title Stage_06_LeafDETFs
/// @notice Required `DTF-DETF` then USD quad `TTDOL-Q` + first-bond as EOA (opening is launch-rich).
library Stage_06_LeafDETFs {
    function enrichAll(LaunchState storage s, address bonder) internal {
        enrichDtfDetf(s, bonder);
        enrichDolQ(s, bonder);
    }

    function premineDtfDetf(LaunchState storage s) internal view returns (address predicted, uint256 nonce) {
        return UniswapV4DetfHookPremineLib.premineCp(
            s.diamondPackageFactory,
            s.hookFactory,
            IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg),
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(s.cpHookPkg),
            _dtfDetfArgs(s),
            RobinhoodCanonicalLib.poolManager(),
            address(s.indexedexManager)
        );
    }

    function deployDtfDetf(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 DTF-DETF deploy+first-bond as EOA");
        _deployDtfDetf(s, bonder, nonce);
        enrichDtfDetf(s, bonder);
    }

    function enrichDtfDetf(LaunchState storage s, address /* bonder */) internal {
        // First bond as the EOA is the live / launch-rich gate. Opening WAD is the lever.
        // Do not impersonate the diamond or hook depositSingle as the diamond.
        _captureDtfClaim(s);
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
        console2.log("06 TTDOL-Q deploy+first-bond as EOA");
        _deployDolQ(s, bonder, nonce);
        enrichDolQ(s, bonder);
    }

    function enrichDolQ(LaunchState storage s, address /* bonder */) internal {
        // First bond as the EOA is the live / launch-rich gate. Opening WAD is the lever.
        // Do not impersonate the diamond or hook depositSingle as the diamond.
        s;
    }

    function _dtfDetfArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args.name = "Test DETF DTF-DETF";
        args.symbol = "DTF-DETF";
        args.claimName = "Test Claim DTF-CLAIM";
        args.claimSymbol = "DTF-CLAIM";
        args.bondName = "Test Bond DTF-DETF";
        args.bondSymbol = "DTF-DETF-BOND";
        args.standardExchangeVault = IStandardExchangeProxy(s.seRichWeth);
        args.standardExchangeVaultShare = IERC20(address(0));
        args.pairToken = IERC20(s.ttWETH);
        args.creationPairPerDetfWad = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.openingPairPerDetfWad = FixtureEconomics.OPENING_PAIR_PER_DETF;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
        require(s.creator != address(0), "DTF-DETF creator is the deployer");
        args.creator = s.creator;
    }

    function _deployDtfDetf(LaunchState storage s, address bonder, uint256 nonce) private {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _dtfDetfArgs(s);
        address predicted = s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.cpDetfPkg), abi.encode(args, uint256(0))
        );
        s.dtfDetf = IUniswapV4SingleStandardExchangeDETDFPkg(s.cpDetfPkg).deployVault(args, nonce);
        require(s.dtfDetf == predicted, "detf != predicted");
        UniswapV4DetfScriptWireLib._wireCp(s.dtfDetf);
        RichnessLib.firstBondCp(
            s.dtfDetf, IERC20(s.ttWETH), FixtureEconomics.DTF_DETF_FIRST_BOND, bonder
        );
        _captureDtfClaim(s);
    }

    function _captureDtfClaim(LaunchState storage s) private {
        if (s.dtfDetf == address(0) || s.dtfDetf.code.length == 0) return;
        s.dtfClaim = address(IDetf(s.dtfDetf).rebasingClaimToken());
    }

    function _dolQArgs(LaunchState storage s)
        private
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        address ttweth = s.ttWETH;
        args.name = "Double Dollar DETF";
        args.symbol = "$$DETF";
        args.claimName = "Infinite Double Dollar";
        args.claimSymbol = "I$$DETF";
        args.bondName = "Double Dollar Bond NFT";
        args.bondSymbol = "$$BondNFT";
        args.baseAmp = FixtureEconomics.BASE_AMP;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
        args.pairTokens = new IERC20[](3);
        args.pairTokens[0] = IERC20(s.ttUSDE);
        args.pairTokens[1] = IERC20(s.ttUSDG);
        args.pairTokens[2] = IERC20(ttweth);
        args.standardExchanges = new IStandardExchangeProxy[](3);
        args.standardExchanges[0] = IStandardExchangeProxy(s.seUsdeWeth);
        args.standardExchanges[1] = IStandardExchangeProxy(s.seUsdgUsde);
        args.standardExchanges[2] = IStandardExchangeProxy(s.seUsdgWeth);
        args.vaultShares = new IERC20[](3);
        args.rateProviders = new address[](3);
        args.rateProviders[0] = s.rpUsdeWeth;
        args.rateProviders[1] = s.rpUsdgUsde;
        args.rateProviders[2] = s.rpUsdgWeth;
        args.creationPairPerDetfWad = new uint256[](3);
        args.creationPairPerDetfWad[0] = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.creationPairPerDetfWad[1] = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.creationPairPerDetfWad[2] = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.openingPairPerDetfWad = new uint256[](3);
        args.openingPairPerDetfWad[0] = FixtureEconomics.OPENING_PAIR_PER_DETF;
        args.openingPairPerDetfWad[1] = FixtureEconomics.OPENING_PAIR_PER_DETF;
        args.openingPairPerDetfWad[2] = FixtureEconomics.OPENING_PAIR_PER_DETF;
        require(s.creator != address(0), "$$DETF creator is the deployer");
        args.creator = s.creator;
    }

    function _deployDolQ(LaunchState storage s, address bonder, uint256 nonce) private {
        address ttweth = s.ttWETH;
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
        ins[2] = IERC20(ttweth);
        amts[0] = FixtureEconomics.TTDOL_FIRST_BOND;
        amts[1] = FixtureEconomics.TTDOL_FIRST_BOND;
        amts[2] = FixtureEconomics.TTDOL_FIRST_BOND;
        RichnessLib.firstBondMulti(s.ttDolQ, ins, amts, s.ttUSDG, bonder);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {RichnessLib} from "./RichnessLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @title ProtocolDetfInstanceLib
/// @notice Required `DTF-DETF` then USD quad `TTDOL-Q` + first-bond as EOA (opening is launch-rich).
library ProtocolDetfInstanceLib {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function enrichAll(LaunchState storage s, address bonder) internal {
        enrichDtfDetf(s, bonder);
        enrichDolQ(s, bonder);
    }

    function premineDtfDetf(LaunchState storage s) internal returns (address predicted, uint256 nonce) {
        IUniswapV4Detf.PkgArgs memory args = _dtfDetfArgs(s);
        predicted = _predictDetf(s, args);
        nonce = _cpMineNonce(s, predicted);
    }

    function deployDtfDetf(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 DTF-DETF deploy+first-bond as EOA");
        _deployDtfDetf(s, bonder, nonce);
        enrichDtfDetf(s, bonder);
    }

    function enrichDtfDetf(LaunchState storage s, address /* bonder */) internal {
        _captureDtfClaim(s);
    }

    function premineDolQ(LaunchState storage s) internal returns (address predicted, uint256 nonce) {
        IUniswapV4Detf.PkgArgs memory args = _dolQArgs(s);
        predicted = _predictDetf(s, args);
        nonce = _quadMineNonce(s, predicted);
    }

    function deployDolQ(LaunchState storage s, address bonder, uint256 nonce) internal {
        console2.log("06 TTDOL-Q deploy+first-bond as EOA");
        _deployDolQ(s, bonder, nonce);
        enrichDolQ(s, bonder);
    }

    function enrichDolQ(LaunchState storage s, address /* bonder */) internal {
        s;
    }

    function _predictDetf(LaunchState storage s, IUniswapV4Detf.PkgArgs memory args)
        private
        view
        returns (address)
    {
        IUniswapV4Detf.PkgArgs memory saltArgs_ = args;
        saltArgs_.hook = address(0);
        return s.diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(s.uniV4DetfPkg), abi.encode(saltArgs_)
        );
    }

    function _dtfDetfArgs(LaunchState storage s) private view returns (IUniswapV4Detf.PkgArgs memory args) {
        args.name = "Test DETF DTF-DETF";
        args.symbol = "DTF-DETF";
        args.claimName = "Test Claim DTF-CLAIM";
        args.claimSymbol = "DTF-CLAIM";
        args.bondName = "Test Bond DTF-DETF";
        args.bondSymbol = "DTF-DETF-BOND";
        args.creationPairPerDetfWad = new uint256[](1);
        args.creationPairPerDetfWad[0] = FixtureEconomics.CREATION_PAIR_PER_DETF;
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = FixtureEconomics.OPENING_PAIR_PER_DETF;
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
        require(s.creator != address(0), "DTF-DETF creator is the deployer");
        args.creator = s.creator;
    }

    function _cpMineNonce(LaunchState storage s, address predicted) private returns (uint256) {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: RobinhoodCanonicalLib.poolManager(),
                feeOracle: address(s.indexedexManager),
                standardExchange: s.seRichWeth,
                pairToken: s.ttWETH,
                rawToken: predicted,
                ownerOnlyLiquidity: true,
                owner: predicted
            });
        return CpHookFactory.findMineNonce(
            s.hookFactory,
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(s.cpHookPkg),
            hArgs
        );
    }

    function _deployDtfDetf(LaunchState storage s, address bonder, uint256 nonce) private {
        IUniswapV4Detf.PkgArgs memory args = _dtfDetfArgs(s);
        address predicted = _predictDetf(s, args);
        vm.etch(predicted, s.ttWETH.code);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: RobinhoodCanonicalLib.poolManager(),
                feeOracle: address(s.indexedexManager),
                standardExchange: s.seRichWeth,
                pairToken: s.ttWETH,
                rawToken: predicted,
                ownerOnlyLiquidity: true,
                owner: predicted
            });
        address hook_ = CpHookFactory.deployHook(
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(s.cpHookPkg), hArgs, nonce
        );
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(predicted, s.ttWETH);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted, "");
        args.hook = hook_;
        s.dtfDetf = IUniswapV4DetfDFPkg(s.uniV4DetfPkg).deployVault(args);
        require(s.dtfDetf == predicted, "detf != predicted");
        RichnessLib.firstBondCp(
            s.dtfDetf, IERC20(s.ttWETH), FixtureEconomics.DTF_DETF_FIRST_BOND, bonder
        );
        _captureDtfClaim(s);
    }

    function _captureDtfClaim(LaunchState storage s) private {
        if (s.dtfDetf == address(0) || s.dtfDetf.code.length == 0) return;
        s.dtfClaim = address(IDetf(s.dtfDetf).rebasingClaimToken());
    }

    function _dolQArgs(LaunchState storage s) private view returns (IUniswapV4Detf.PkgArgs memory args) {
        args.name = "Double Dollar DETF";
        args.symbol = "$$DETF";
        args.claimName = "Infinite Double Dollar";
        args.claimSymbol = "I$$DETF";
        args.bondName = "Double Dollar Bond NFT";
        args.bondSymbol = "$$BondNFT";
        args.creationPairPerDetfWad = new uint256[](3);
        args.openingPairPerDetfWad = new uint256[](3);
        for (uint256 i; i < 3; ++i) {
            args.creationPairPerDetfWad[i] = FixtureEconomics.CREATION_PAIR_PER_DETF;
            args.openingPairPerDetfWad[i] = FixtureEconomics.OPENING_PAIR_PER_DETF;
        }
        args.mintThreshold = FixtureEconomics.MINT_THRESHOLD;
        args.burnThreshold = FixtureEconomics.BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = FixtureEconomics.EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = FixtureEconomics.EXPANSION_R;
        args.expansionMaxCatchUpEpochs = FixtureEconomics.EXPANSION_CATCHUP;
        require(s.creator != address(0), "$$DETF creator is the deployer");
        args.creator = s.creator;
    }

    function _quadHArgs(LaunchState storage s, address predicted)
        private
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory hArgs)
    {
        address[4] memory toks;
        toks[0] = predicted;
        toks[1] = s.ttUSDE;
        toks[2] = s.ttUSDG;
        toks[3] = s.ttWETH;
        _sort4(toks);
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == predicted) {
                ses[i] = address(0);
            } else if (toks[i] == s.ttUSDE) {
                ses[i] = s.seUsdeWeth;
                rps[i] = s.rpUsdeWeth;
            } else if (toks[i] == s.ttUSDG) {
                ses[i] = s.seUsdgUsde;
                rps[i] = s.rpUsdgUsde;
            } else {
                ses[i] = s.seUsdgWeth;
                rps[i] = s.rpUsdgWeth;
            }
        }
        hArgs = IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
            poolManager: RobinhoodCanonicalLib.poolManager(),
            feeOracle: address(s.indexedexManager),
            tokens: toks,
            standardExchanges: ses,
            rateProviders: rps,
            baseAmp: FixtureEconomics.BASE_AMP,
            ownerOnlyLiquidity: true,
            owner: predicted
        });
    }

    function _quadMineNonce(LaunchState storage s, address predicted) private returns (uint256) {
        return QuadFactory.findMineNonce(
            s.hookFactory,
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(s.curveQuadHookPkg),
            _quadHArgs(s, predicted)
        );
    }

    function _deployDolQ(LaunchState storage s, address bonder, uint256 nonce) private {
        address ttweth = s.ttWETH;
        IUniswapV4Detf.PkgArgs memory args = _dolQArgs(s);
        address predicted = _predictDetf(s, args);
        vm.etch(predicted, ttweth.code);
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory hArgs = _quadHArgs(s, predicted);
        address hook_ = QuadFactory.deployHook(
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(s.curveQuadHookPkg), hArgs, nonce
        );
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        address[4] memory toks = hArgs.tokens;
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        init.deployPair(toks[2], toks[3]);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted, "");
        args.hook = hook_;
        console2.log("06e calling quad deployVault (premined nonce)", nonce);
        s.ttDolQ = IUniswapV4DetfDFPkg(s.uniV4DetfPkg).deployVault(args);
        require(s.ttDolQ == predicted, "detf != predicted");
        console2.log("06e deployVault done", s.ttDolQ);
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

    function _sort4(address[4] memory a) private pure {
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (a[i] > a[j]) (a[i], a[j]) = (a[j], a[i]);
            }
        }
    }
}

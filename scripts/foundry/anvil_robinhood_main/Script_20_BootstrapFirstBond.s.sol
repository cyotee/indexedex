// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/external/IWETH9.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @title Script_20_BootstrapFirstBond
/// @notice (1) Minimal WETH first bond → live. (2) Capital-efficient launch-rich seed to target S.
/// @dev S = (fdPair / supply) / creationRate. Free DETF legs dilute S after first bond; pair-only
///      `depositSingle` into protocol LP holder raises fdPair without minting free DETF.
///      Absolute WETH for a given target S scales with first-bond size — keep bond small so a
///      ~1–2 WETH launch budget still reaches S≈10 (see FixtureEconomics).
contract Script_20_BootstrapFirstBond is DeploymentBase {
    uint256 private constant ONE_WAD = 1e18;

    string internal constant CHIR_FILE = "18_chir_instance.json";
    string internal constant ARTIFACT_FILE = "20_first_bond.json";

    address private chir;
    address private weth;
    uint256 private pairIn;
    uint256 private detfOut;
    uint256 private bondTokenId;
    bool private isReserveLive;
    uint256 private lockDuration;
    uint256 private syntheticAfterBond;
    uint256 private syntheticAfterSeed;
    uint256 private seedPairIn;
    uint256 private targetSyntheticWad;
    uint256 private launchBudgetWad;
    bool private didFirstBondThisRun;

    // Seed-loop scratch (storage avoids stack-too-deep in seed path).
    address private seedHook;
    address private seedLpTo;
    uint256 private seedMax;
    uint256 private seedTarget;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        targetSyntheticWad = FixtureEconomics.launchRichTargetSyntheticWad();
        launchBudgetWad = FixtureEconomics.launchBudgetWeth();
        _logHeader("Stage 20: First bond + capital-efficient launch-rich seed");
        _logUint("launchBudgetWeth:", launchBudgetWad);
        _logUint("firstBondWeth:", FixtureEconomics.firstBondWeth());
        _logUint("targetSyntheticWad:", targetSyntheticWad);

        IUniswapV4SingleStandardExchangeDETF detf = IUniswapV4SingleStandardExchangeDETF(chir);
        require(detf.pairToken() == weth, "CHIR pairToken != WETH");

        if (!detf.isReserveLive()) {
            _firstBond(detf);
            didFirstBondThisRun = true;
        } else {
            isReserveLive = true;
            _logString("note:", "CHIR already live - skipping first bond");
            (pairIn,) = _readUintSafe(ARTIFACT_FILE, "pairIn");
            (detfOut,) = _readUintSafe(ARTIFACT_FILE, "detfOut");
            (bondTokenId,) = _readUintSafe(ARTIFACT_FILE, "bondTokenId");
        }

        syntheticAfterBond = detf.syntheticPrice();
        _logUint("syntheticAfterBond:", syntheticAfterBond);
        _logUint("mintThreshold:", detf.mintThreshold());
        _logUint("totalSupplyAfterBond:", IERC20(chir).totalSupply());

        seedPairIn = _seedLaunchRich(detf);
        syntheticAfterSeed = detf.syntheticPrice();

        require(detf.isReserveLive(), "isReserveLive still false");
        require(
            syntheticAfterSeed > detf.mintThreshold(),
            "launch-rich seed failed: synthetic still <= mintThreshold"
        );

        _logUint("totalWethBondPlusSeed:", pairIn + seedPairIn);
        if (didFirstBondThisRun && pairIn + seedPairIn > launchBudgetWad) {
            _logString("warn:", "spent above LAUNCH_BUDGET_WETH");
        }
        if (syntheticAfterSeed < targetSyntheticWad) {
            _logString("warn:", "synthetic below target - increase budget or smaller first bond");
        }

        _exportJsonMeasured(detfOut);
        _logResults();
        _logUint("seedPairIn:", seedPairIn);
        _logUint("syntheticAfterSeed:", syntheticAfterSeed);
        _logUint("isMintingAllowed:", detf.isMintingAllowed() ? 1 : 0);
    }

    function _firstBond(IUniswapV4SingleStandardExchangeDETF detf) internal {
        pairIn = FixtureEconomics.firstBondWeth();
        if (pairIn > launchBudgetWad) {
            pairIn = launchBudgetWad / 10;
            if (pairIn == 0) pairIn = launchBudgetWad;
        }
        lockDuration = FixtureEconomics.DEFAULT_MIN_LOCK;

        uint256 chirBefore = IERC20(chir).balanceOf(deployer);

        vm.startBroadcast();
        _ensureWeth(pairIn);
        IERC20(weth).approve(chir, type(uint256).max);
        (bondTokenId, detfOut) = detf.bond(
            IERC20(weth),
            pairIn,
            lockDuration,
            deployer,
            false,
            block.timestamp + 1 hours
        );
        vm.stopBroadcast();

        isReserveLive = detf.isReserveLive();
        require(isReserveLive, "isReserveLive still false after first bond");

        uint256 freeDetf = IERC20(chir).balanceOf(deployer) - chirBefore;
        if (detfOut == 0) detfOut = freeDetf;
        _logUint("freeDetfReceived:", freeDetf);
        _logUint("bondTokenId:", bondTokenId);
    }

    function _maxSeedWeth() internal view returns (uint256 maxSeed_) {
        maxSeed_ = FixtureEconomics.launchRichSeedMaxWeth();
        if (didFirstBondThisRun) {
            if (launchBudgetWad <= pairIn) return 0;
            uint256 rem_ = launchBudgetWad - pairIn;
            if (rem_ < maxSeed_) maxSeed_ = rem_;
            return maxSeed_;
        }
        // Already-live re-seed: clamp to budget or hard max.
        if (launchBudgetWad > 0 && launchBudgetWad < maxSeed_) {
            maxSeed_ = launchBudgetWad;
        }
    }

    /// @dev fd = S * supply * C / 1e36  (from S = fd * 1e36 / (supply * C)).
    function _estimateFdPairWad(IUniswapV4SingleStandardExchangeDETF detf) internal view returns (uint256) {
        uint256 s_ = detf.syntheticPrice();
        uint256 supply_ = IERC20(chir).totalSupply();
        uint256 c_ = detf.creationPairPerDetfWad();
        if (s_ == 0 || supply_ == 0 || c_ == 0) return 0;
        return Math.mulDiv(s_, Math.mulDiv(supply_, c_, ONE_WAD), ONE_WAD);
    }

    function _estimateSeedNeed(IUniswapV4SingleStandardExchangeDETF detf, uint256 target_)
        internal
        view
        returns (uint256 needEst_)
    {
        uint256 supply_ = IERC20(chir).totalSupply();
        uint256 c_ = detf.creationPairPerDetfWad();
        uint256 fd0_ = _estimateFdPairWad(detf);
        uint256 fdTarget_ = Math.mulDiv(target_, Math.mulDiv(supply_, c_, ONE_WAD), ONE_WAD);
        if (fdTarget_ <= fd0_) return 0;
        needEst_ = fdTarget_ - fd0_;
        // +10% buffer for depositSingle / AMM non-linearity.
        needEst_ = needEst_ + needEst_ / 10;
    }

    function _seedLaunchRich(IUniswapV4SingleStandardExchangeDETF detf) internal returns (uint256 totalSeeded_) {
        seedTarget = targetSyntheticWad;
        if (seedTarget <= detf.mintThreshold()) {
            seedTarget = detf.mintThreshold() + 0.5e18;
        }
        if (detf.syntheticPrice() > seedTarget) {
            _logString("seed:", "already above target synthetic - skip");
            return 0;
        }

        seedHook = detf.reserveHook();
        require(seedHook != address(0) && seedHook.code.length > 0, "missing reserveHook");
        seedLpTo = chir;
        try detf.rebasingClaimToken() returns (address claim_) {
            if (claim_ != address(0)) seedLpTo = claim_;
        } catch {}

        seedMax = _maxSeedWeth();
        _logUint("maxSeedWeth:", seedMax);
        if (seedMax == 0) {
            _logString("seed:", "zero seed budget");
            return 0;
        }

        uint256 needEst_ = _estimateSeedNeed(detf, seedTarget);
        if (needEst_ > seedMax) needEst_ = seedMax;
        _logUint("fdPairEstAfterBond:", _estimateFdPairWad(detf));
        _logUint("seedEstimateWeth:", needEst_);

        vm.startBroadcast();
        if (needEst_ > 0) {
            totalSeeded_ = _depositPairSeed(needEst_);
        }
        totalSeeded_ = _fineSeedLoop(detf, totalSeeded_);
        vm.stopBroadcast();

        _logUint("syntheticAfterSeedLoop:", detf.syntheticPrice());
    }

    function _fineSeedLoop(IUniswapV4SingleStandardExchangeDETF detf, uint256 totalSeeded_)
        internal
        returns (uint256)
    {
        uint256 step_ = FixtureEconomics.launchRichSeedStepWeth();
        if (step_ == 0) step_ = 0.01 ether;

        for (uint256 i; i < 64; ++i) {
            if (detf.syntheticPrice() > seedTarget) break;
            if (totalSeeded_ >= seedMax) break;
            uint256 room_ = seedMax - totalSeeded_;
            uint256 chunk_ = step_ > room_ ? room_ : step_;
            if (chunk_ == 0) break;

            uint256 used_ = _depositPairSeed(chunk_);
            if (used_ == 0) {
                used_ = _depositPairSeed(chunk_ / 2);
                if (used_ == 0) break;
            }
            totalSeeded_ += used_;
        }
        return totalSeeded_;
    }

    function _depositPairSeed(uint256 amount_) internal returns (uint256 used_) {
        if (amount_ == 0) return 0;
        _ensureWeth(amount_);
        IERC20(weth).approve(seedHook, amount_);
        try IBufferHook(seedHook).depositSingle(weth, amount_, seedLpTo, 0, block.timestamp + 1 hours) returns (
            uint256
        ) {
            return amount_;
        } catch {
            return 0;
        }
    }

    function _ensureWeth(uint256 amount_) internal {
        uint256 bal = IERC20(weth).balanceOf(deployer);
        if (bal < amount_) {
            IWETH9(weth).deposit{value: amount_ - bal}();
        }
    }

    function _loadPrior() internal {
        chir = _readAddress(CHIR_FILE, "chir");
        weth = RobinhoodCanonicalLib.weth();
        require(chir != address(0) && chir.code.length > 0, "missing chir");
    }

    function _exportJsonMeasured(uint256 freeDetf) internal {
        string memory json;
        json = vm.serializeAddress("bond", "chir", chir);
        json = vm.serializeAddress("bond", "pairToken", weth);
        json = vm.serializeUint("bond", "pairIn", pairIn);
        json = vm.serializeUint("bond", "detfOut", detfOut);
        json = vm.serializeUint("bond", "freeDetfReceived", freeDetf);
        json = vm.serializeUint("bond", "bondTokenId", bondTokenId);
        json = vm.serializeUint("bond", "lockDuration", lockDuration);
        json = vm.serializeBool("bond", "isReserveLive", isReserveLive);
        json = vm.serializeUint("bond", "creationPairPerDetfWad", FixtureEconomics.creationPairPerDetfWad());
        json = vm.serializeUint("bond", "syntheticAfterBond", syntheticAfterBond);
        json = vm.serializeUint("bond", "syntheticAfterSeed", syntheticAfterSeed);
        json = vm.serializeUint("bond", "seedPairIn", seedPairIn);
        json = vm.serializeUint("bond", "targetSyntheticWad", targetSyntheticWad);
        json = vm.serializeUint("bond", "launchBudgetWeth", launchBudgetWad);
        json = vm.serializeUint("bond", "totalWethBondPlusSeed", pairIn + seedPairIn);
        json = vm.serializeUint("bond", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("CHIR:", chir);
        _logUint("pairIn:", pairIn);
        _logUint("detfOut:", detfOut);
        _logComplete("Stage 20");
    }
}

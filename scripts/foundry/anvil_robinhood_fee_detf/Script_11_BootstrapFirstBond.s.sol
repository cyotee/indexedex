// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/external/IWETH9.sol";

import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @title Script_11_BootstrapFirstBond
/// @notice Minimal WETH first bond -> isReserveLive for CHIR.
contract Script_11_BootstrapFirstBond is DeploymentBase {
    string internal constant CHIR_FILE = "09_chir_instance.json";
    string internal constant ARTIFACT_FILE = "11_first_bond.json";

    address private chir;
    address private weth;
    uint256 private pairIn;
    uint256 private detfOut;
    uint256 private bondTokenId;
    bool private isReserveLive;
    uint256 private lockDuration;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 11: First bond (WETH -> CHIR live)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        IUniswapV4SingleStandardExchangeDETF detf = IUniswapV4SingleStandardExchangeDETF(chir);
        require(detf.pairToken() == weth, "CHIR pairToken != WETH");

        pairIn = FixtureEconomics.firstBondWeth();
        lockDuration = FixtureEconomics.DEFAULT_MIN_LOCK;

        uint256 chirBefore = IERC20(chir).balanceOf(deployer);

        vm.startBroadcast();
        // Ensure WETH balance for bond.
        uint256 bal = IERC20(weth).balanceOf(deployer);
        if (bal < pairIn) {
            IWETH9(weth).deposit{value: pairIn - bal}();
        }
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

        // Persist measured economics
        _exportJsonMeasured(freeDetf);
        _logResults();
        _logUint("freeDetfReceived:", freeDetf);
        _logUint("bondTokenId:", bondTokenId);
    }

    function _loadPrior() internal {
        chir = _readAddress(CHIR_FILE, "chir");
        weth = RobinhoodCanonicalLib.weth();
        require(chir != address(0) && chir.code.length > 0, "missing chir");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        if (!IUniswapV4SingleStandardExchangeDETF(chir).isReserveLive()) return false;
        try vm.readFile(_artifactPath(ARTIFACT_FILE)) returns (string memory) {
            (pairIn,) = _readUintSafe(ARTIFACT_FILE, "pairIn");
            (detfOut,) = _readUintSafe(ARTIFACT_FILE, "detfOut");
            (bondTokenId,) = _readUintSafe(ARTIFACT_FILE, "bondTokenId");
            isReserveLive = true;
            return true;
        } catch {
            return false;
        }
    }

    function _exportJson() internal {
        _exportJsonMeasured(detfOut);
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
        json = vm.serializeUint("bond", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("CHIR:", chir);
        _logUint("pairIn:", pairIn);
        _logUint("detfOut:", detfOut);
        _logComplete("Stage 11");
    }
}

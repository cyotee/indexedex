// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_07_NestDETFs} from "./Stage_07_NestDETFs.sol";

/// @title Script_07_NestDETFs
/// @notice Group 07: TTBETA-O + TTIDX-WRAP (no TTM7-W / TTNEST-W / TTM7-WRAP).
contract Script_07_NestDETFs is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        _requireLocalhostIfBroadcast();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01 first");
        require(_loadPlatform(s), "run Script_02 first");
        require(_loadUniV4Packages(s), "run Script_03 first");
        require(_loadTokens(s), "run Script_04 first");
        require(_loadLeafPools(s), "run Script_05 first");
        require(_loadLeafDetfs(s), "run Script_06 first");
        _logHeader("Group 07: Nest DETFs");

        if (_artifactValid(FILE_NEST_DETFS, "TTBETA-O") && _artifactValid(FILE_NEST_DETFS, "TTIDX-WRAP")) {
            require(_loadNestDetfs(s), "07_nest_detfs.json incomplete");
            _exportNestDetfs(s);
            _logComplete("Group 07 (cached)");
            return;
        }

        vm.startBroadcast();
        Stage_07_NestDETFs.deployPoolsAndSes(s);
        Stage_07_NestDETFs.ensureBondCapital(s, owner);
        vm.stopBroadcast();

        console2.log("07 premine nest hook nonces (off-chain, not a broadcast tx)");
        (, uint256 nBetaO) = Stage_07_NestDETFs.premineBetaO(s);
        (, uint256 nIdxWrap) = Stage_07_NestDETFs.premineIdxWrap(s);
        console2.log("07 premined TTBETA-O nonce", nBetaO);
        console2.log("07 premined TTIDX-WRAP nonce", nIdxWrap);

        vm.startBroadcast();
        Stage_07_NestDETFs.deployBetaO(s, owner, nBetaO);
        Stage_07_NestDETFs.deployIdxWrap(s, owner, nIdxWrap);
        vm.stopBroadcast();

        _exportNestDetfs(s);
        _logAddress("TTBETA-O:", s.ttBetaO);
        _logAddress("TTIDX-WRAP:", s.ttIdxWrap);
        _logComplete("Group 07");
    }
}

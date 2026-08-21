// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";

/// @title Script_06_LeafDETFs
/// @notice Group 06: required TTCHIR then USD quad TTDOL-Q.
contract Script_06_LeafDETFs is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01 first");
        require(_loadPlatform(s), "run Script_02 first");
        require(_loadUniV4Packages(s), "run Script_03 first");
        require(_loadTokens(s), "run Script_04 first");
        require(_loadLeafPools(s), "run Script_05 first");
        _requireChirArchitecture(s);
        _loadLeafDetfsPartial(s);
        _logHeader("Group 06: TTCHIR + TTDOL-Q");

        _runChir();
        _runDolQ();

        _exportLeafDetfs(s);
        _logAddress("TTCHIR:", s.ttChir);
        _logAddress("TTRICHIR:", s.ttRichir);
        _logAddress("TTDOL-Q:", s.ttDolQ);
        _logComplete("Group 06");
    }

    function _runChir() internal {
        uint256 nonce;
        if (!_hasCode(s.ttChir)) {
            console2.log("06 premine TTCHIR CP hook nonce (off-chain)");
            (, nonce) = Stage_06_LeafDETFs.premineChir(s);
        }
        _broadcast();
        if (_hasCode(s.ttChir)) {
            Stage_06_LeafDETFs.enrichChir(s, owner);
        } else {
            Stage_06_LeafDETFs.deployChir(s, owner, nonce);
        }
        vm.stopBroadcast();
    }

    function _runDolQ() internal {
        uint256 nonce;
        if (!_hasCode(s.ttDolQ)) {
            console2.log("06 premine quad hook nonce (off-chain)");
            (, nonce) = Stage_06_LeafDETFs.premineDolQ(s);
        }
        _broadcast();
        if (_hasCode(s.ttDolQ)) {
            Stage_06_LeafDETFs.enrichDolQ(s, owner);
        } else {
            Stage_06_LeafDETFs.deployDolQ(s, owner, nonce);
        }
        vm.stopBroadcast();
    }
}

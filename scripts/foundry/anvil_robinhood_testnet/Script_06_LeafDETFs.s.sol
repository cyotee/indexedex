// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";

/// @title Script_06_LeafDETFs
/// @notice Group 06: four leaf DETFs (TTM7-W omitted). Premine each hook nonce before startBroadcast.
contract Script_06_LeafDETFs is LaunchIo {
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
        _loadLeafDetfsPartial(s);
        _logHeader("Group 06: Leaf DETFs");

        _runNvdaS();
        _runNvdaSmhO();
        _runIdxQ();
        _runDolQ();

        _exportLeafDetfs(s);
        _logAddress("TTNVDA-S:", s.ttNvdaS);
        _logAddress("TTDOL-Q:", s.ttDolQ);
        _logComplete("Group 06");
    }

    function _runNvdaS() internal {
        uint256 nonce;
        if (!_hasCode(s.ttNvdaS)) {
            console2.log("06 premine CP hook nonce (off-chain)");
            (, nonce) = Stage_06_LeafDETFs.premineNvdaS(s);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttNvdaS)) {
            Stage_06_LeafDETFs.enrichNvdaS(s, owner);
        } else {
            Stage_06_LeafDETFs.deployNvdaS(s, owner, nonce);
        }
        vm.stopBroadcast();
    }

    function _runNvdaSmhO() internal {
        uint256 nonce;
        if (!_hasCode(s.ttNvdaSmhO)) {
            console2.log("06 premine orbital hook nonce (off-chain)");
            (, nonce) = Stage_06_LeafDETFs.premineNvdaSmhO(s);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttNvdaSmhO)) {
            Stage_06_LeafDETFs.enrichNvdaSmhO(s, owner);
        } else {
            Stage_06_LeafDETFs.deployNvdaSmhO(s, owner, nonce);
        }
        vm.stopBroadcast();
    }

    function _runIdxQ() internal {
        uint256 nonce;
        if (!_hasCode(s.ttIdxQ)) {
            console2.log("06 premine quad hook nonce (off-chain)");
            (, nonce) = Stage_06_LeafDETFs.premineIdxQ(s);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttIdxQ)) {
            Stage_06_LeafDETFs.enrichIdxQ(s, owner);
        } else {
            Stage_06_LeafDETFs.deployIdxQ(s, owner, nonce);
        }
        vm.stopBroadcast();
    }

    function _runDolQ() internal {
        uint256 nonce;
        if (!_hasCode(s.ttDolQ)) {
            console2.log("06 premine quad hook nonce (off-chain)");
            (, nonce) = Stage_06_LeafDETFs.premineDolQ(s);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttDolQ)) {
            Stage_06_LeafDETFs.enrichDolQ(s, owner);
        } else {
            Stage_06_LeafDETFs.deployDolQ(s, owner, nonce);
        }
        vm.stopBroadcast();
    }
}

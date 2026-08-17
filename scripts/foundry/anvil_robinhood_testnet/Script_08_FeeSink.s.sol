// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_08_FeeSink} from "./Stage_08_FeeSink.sol";

/// @title Script_08_FeeSink
/// @notice Group 08: TTRICH + TTRICH-S + first-bond + D47. No fee push.
contract Script_08_FeeSink is LaunchIo {
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
        _loadLeafPools(s);
        _logHeader("Group 08: Fee-sink");

        if (_artifactValid(FILE_FEE_SINK, "TTRICH-S") && _artifactValid(FILE_FEE_SINK, "TTRICH")) {
            require(_loadFeeSink(s), "08_fee_sink.json incomplete");
            _exportFeeSink(s);
            _logComplete("Group 08 (cached)");
            return;
        }

        vm.startBroadcast();
        Stage_08_FeeSink.deployTtrichInfra(s, owner, uiWallet);
        vm.stopBroadcast();

        console2.log("08 premine TTRICH-S hook nonce (off-chain, not a broadcast tx)");
        (, uint256 nRichS) = Stage_08_FeeSink.premineRichS(s);
        console2.log("08 premined TTRICH-S nonce", nRichS);

        vm.startBroadcast();
        Stage_08_FeeSink.deployRichS(s, owner, nRichS);
        vm.stopBroadcast();

        _exportFeeSink(s);
        _logAddress("TTRICH:", s.ttRICH);
        _logAddress("TTRICH-S:", s.ttRichS);
        _logComplete("Group 08");
    }
}

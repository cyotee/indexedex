// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_05_LeafPoolsAndSEs} from "./Stage_05_LeafPoolsAndSEs.sol";

/// @title Script_05_LeafPoolsAndSEs
/// @notice Group 05: five seeded Uni V4 pools + SEs + RPs.
contract Script_05_LeafPoolsAndSEs is LaunchIo {
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
        _logHeader("Group 05: Leaf pools + SEs");

        if (_artifactValid(FILE_LEAF_POOLS, "seNvdaUsdg") && _artifactValid(FILE_LEAF_POOLS, "seSpyUsdg")) {
            require(_loadLeafPools(s), "05_leaf_pools_ses.json incomplete");
            _exportLeafPools(s);
            _logComplete("Group 05 (cached)");
            return;
        }

        vm.startBroadcast();
        Stage_05_LeafPoolsAndSEs.execute(s, owner);
        vm.stopBroadcast();

        _exportLeafPools(s);
        _logAddress("seNvdaUsdg:", s.seNvdaUsdg);
        _logComplete("Group 05");
    }
}

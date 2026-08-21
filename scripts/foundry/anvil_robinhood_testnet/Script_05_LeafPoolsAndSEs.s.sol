// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_05_LeafPoolsAndSEs} from "./Stage_05_LeafPoolsAndSEs.sol";

/// @title Script_05_LeafPoolsAndSEs
/// @notice Group 05: required `TTRICH`/`TTWETH` SE plus the three SEs that feed `TTDOL-Q`.
contract Script_05_LeafPoolsAndSEs is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01 first");
        require(_loadPlatform(s), "run Script_02 first");
        require(_loadUniV4Packages(s), "run Script_03 first");
        require(_loadTokens(s), "run Script_04 first");
        require(_hasCode(s.ttRICH), "run Script_04 for TTRICH");
        require(_hasCode(s.ttWETH), "run Script_04 for TTWETH");
        _logHeader("Group 05: Leaf pools + SEs");

        if (_artifactValid(FILE_LEAF_POOLS, "seUsdeWeth") && _artifactValid(FILE_LEAF_POOLS, "seRichWeth")) {
            require(_loadLeafPools(s), "05_leaf_pools_ses.json incomplete");
            if (!_hasCode(s.seRichWeth)) {
                _broadcast();
                Stage_05_LeafPoolsAndSEs.deployTtrichWeth(s, owner);
                vm.stopBroadcast();
            }
            _exportLeafPools(s);
            _logAddress("seRichWeth:", s.seRichWeth);
            _logComplete("Group 05 (cached)");
            return;
        }

        _broadcast();
        Stage_05_LeafPoolsAndSEs.execute(s, owner);
        vm.stopBroadcast();

        _exportLeafPools(s);
        _logAddress("seUsdeWeth:", s.seUsdeWeth);
        _logAddress("seRichWeth:", s.seRichWeth);
        _logComplete("Group 05");
    }
}

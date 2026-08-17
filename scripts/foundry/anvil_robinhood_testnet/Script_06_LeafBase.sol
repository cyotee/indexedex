// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

/// @title Script_06_LeafBase
/// @notice Shared load/export for one-leaf group 06 scripts.
abstract contract Script_06_LeafBase is LaunchIo {
    LaunchState internal s;

    function _prepLeaves() internal {
        console2.log("06 prep start");
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
    }

    function _done(string memory name, address detf) internal {
        _exportLeafDetfs(s);
        _logAddress(name, detf);
        _logComplete(name);
    }
}

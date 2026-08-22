// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_02_Platform} from "./Stage_02_Platform.sol";

/// @title Script_02_Platform
/// @notice Group 02: FeeCollector, IndexedexManager (registry + fee oracle), SE rate provider pkg.
contract Script_02_Platform is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01_Factories first");
        _logHeader("Group 02: IndexedEx platform");

        if (_artifactValid(FILE_PLATFORM, "indexedexManager") && _artifactValid(FILE_PLATFORM, "rateProviderPkg")) {
            require(_loadPlatform(s), "02_platform.json incomplete");
            _exportPlatform(s);
            _logAddress("IndexedexManager:", address(s.indexedexManager));
            _logComplete("Group 02 (cached)");
            return;
        }

        _broadcast();
        Stage_02_Platform.execute(s, owner);
        vm.stopBroadcast();

        _exportPlatform(s);
        _logAddress("FeeCollector:", address(s.feeCollector));
        _logAddress("IndexedexManager:", address(s.indexedexManager));
        _logAddress("RateProviderPkg:", address(s.rateProviderPkg));
        _logComplete("Group 02");
    }
}

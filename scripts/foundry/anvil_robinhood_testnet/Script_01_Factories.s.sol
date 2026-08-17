// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_01_Factories} from "./Stage_01_Factories.sol";

/// @title Script_01_Factories
/// @notice Group 01: CREATE3, diamond factory, hook factory, shared facets.
contract Script_01_Factories is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        _requireLocalhostIfBroadcast();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _logHeader("Group 01: Factories");

        if (_artifactValid(FILE_FACTORIES, "create3Factory") && _artifactValid(FILE_FACTORIES, "hookFactory")) {
            require(_loadFactories(s), "01_factories.json incomplete");
            _exportFactories(s);
            _logAddress("Create3Factory:", address(s.create3Factory));
            _logAddress("HookFactory:", address(s.hookFactory));
            _logComplete("Group 01 (cached)");
            return;
        }

        vm.startBroadcast();
        Stage_01_Factories.execute(s, owner);
        vm.stopBroadcast();

        _exportFactories(s);
        _logAddress("Create3Factory:", address(s.create3Factory));
        _logAddress("DiamondPackageFactory:", address(s.diamondPackageFactory));
        _logAddress("HookFactory:", address(s.hookFactory));
        _logComplete("Group 01");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_03b_OrbitalWeightedPackages} from "./Stage_03b_OrbitalWeightedPackages.sol";

/// @title Script_03b_OrbitalWeightedPackages
/// @notice Group 03b: Orbital + Weighted hook DFPkgs and DETF DFPkgs (no instances).
/// @dev Part of `all` / `foundation`. Requires groups 01–03.
contract Script_03b_OrbitalWeightedPackages is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01_Factories first");
        require(_loadPlatform(s), "run Script_02_Platform first");
        require(_loadUniV4Packages(s), "run Script_03_UniV4Packages first");
        _logHeader("Group 03b: Orbital + Weighted packages");

        if (_artifactValid(FILE_UNIV4_PKGS, "orbitalDetfPkg") && _artifactValid(FILE_UNIV4_PKGS, "weightedDetfPkg")) {
            _exportUniV4Packages(s);
            _logAddress("orbitalDetfPkg:", s.orbitalDetfPkg);
            _logAddress("weightedDetfPkg:", s.weightedDetfPkg);
            _logComplete("Group 03b (cached)");
            return;
        }

        _broadcast();
        Stage_03b_OrbitalWeightedPackages.execute(s);
        vm.stopBroadcast();

        _exportUniV4Packages(s);
        _logAddress("orbitalHookPkg:", s.orbitalHookPkg);
        _logAddress("orbitalDetfPkg:", s.orbitalDetfPkg);
        _logAddress("weightedHookPkg:", s.weightedHookPkg);
        _logAddress("weightedDetfPkg:", s.weightedDetfPkg);
        _logComplete("Group 03b");
    }
}

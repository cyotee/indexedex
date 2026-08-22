// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_03_UniV4Packages} from "./Stage_03_UniV4Packages.sol";

/// @title Script_03_UniV4Packages
/// @notice Group 03: Uni V4 SE + CP Protocol DETF + Curve Quad Stable packages. No instances.
contract Script_03_UniV4Packages is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01_Factories first");
        require(_loadPlatform(s), "run Script_02_Platform first");
        _logHeader("Group 03: Uni V4 packages");

        if (
            _artifactValid(FILE_UNIV4_PKGS, "uniV4SePkg") && _artifactValid(FILE_UNIV4_PKGS, "cpDetfPkg")
                && _artifactValid(FILE_UNIV4_PKGS, "curveQuadDetfPkg")
        ) {
            require(_loadUniV4Packages(s), "03_univ4_packages.json incomplete");
            _exportUniV4Packages(s);
            _logAddress("uniV4SePkg:", address(s.uniV4SePkg));
            _logComplete("Group 03 (cached)");
            return;
        }

        _broadcast();
        Stage_03_UniV4Packages.execute(s);
        vm.stopBroadcast();

        _exportUniV4Packages(s);
        _logAddress("cpHookPkg:", s.cpHookPkg);
        _logAddress("uniV4SePkg:", address(s.uniV4SePkg));
        _logAddress("cpDetfPkg:", s.cpDetfPkg);
        _logAddress("curveQuadHookPkg:", s.curveQuadHookPkg);
        _logAddress("curveQuadDetfPkg:", s.curveQuadDetfPkg);
        _logComplete("Group 03");
    }
}

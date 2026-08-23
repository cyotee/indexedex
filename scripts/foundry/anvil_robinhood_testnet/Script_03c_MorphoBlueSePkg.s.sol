// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Stage_03c_MorphoBlueSePkg} from "./Stage_03c_MorphoBlueSePkg.sol";

/// @title Script_03c_MorphoBlueSePkg
/// @notice Group 03c: Morpho Blue SE DFPkg. Rehearsal Morpho if the 46630 pin has no code.
contract Script_03c_MorphoBlueSePkg is LaunchIo {
    LaunchState internal s;

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01_Factories first");
        require(_loadPlatform(s), "run Script_02_Platform first");
        _logHeader("Group 03c: Morpho Blue SE package");

        if (_artifactValid(FILE_MORPHO, "morphoBlueSePkg") && _artifactValid(FILE_MORPHO, "morpho")) {
            require(_loadMorphoBlue(s), "03c_morpho_blue_se.json incomplete");
            _exportMorphoBlue(s);
            _logAddress("morpho:", s.morpho);
            _logAddress("morphoBlueSePkg:", s.morphoBlueSePkg);
            _logComplete("Group 03c (cached)");
            return;
        }

        _broadcast();
        Stage_03c_MorphoBlueSePkg.execute(s, owner);
        vm.stopBroadcast();

        _exportMorphoBlue(s);
        _logAddress("morpho:", s.morpho);
        _logAddress("morphoIrm:", s.morphoIrm);
        _logAddress("morphoOracle:", s.morphoOracle);
        _logAddress("morphoBlueSePkg:", s.morphoBlueSePkg);
        _logComplete("Group 03c");
    }
}

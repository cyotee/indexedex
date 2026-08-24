// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {
    Phase_05_Stage_05_MorphoBlueStandardExchangePkg as MorphoSePkgLib
} from "./Phase_05_Stage_05_MorphoBlueStandardExchangePkg.sol";

/// @title Phase_05_Stage_05_MorphoBlueStandardExchangePkg
/// @notice Skip key: `morphoBlueSePkg`.
contract Phase_05_Stage_05_MorphoBlueStandardExchangePkg is LaunchStageBase {
    function run() external {
        _start("Phase 05 Stage 05: Morpho Blue SE pkg");
        if (_shouldSkipStage(FILE_05_05, _skipKeys("morphoBlueSePkg"))) {
            s.morphoBlueSePkg = _loadAddr(FILE_05_05, "morphoBlueSePkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            _hydrateMorphoHost(s);
            _broadcast();
            MorphoSePkgLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0505", FILE_05_05, "morphoBlueSePkg", s.morphoBlueSePkg);
        _logAddress("morphoBlueSePkg:", s.morphoBlueSePkg);
        _logComplete("Phase 05 Stage 05");
    }
}

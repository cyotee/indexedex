// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_05_OrbitalBufferHookPkg as OrbitalHookLib} from "./Phase_06_Stage_05_OrbitalBufferHookPkg.sol";

/// @title Phase_06_Stage_05_OrbitalBufferHookPkg
/// @notice Skip key: `orbitalHookPkg`.
contract Phase_06_Stage_05_OrbitalBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 05: Orbital buffer hook pkg");
        if (_shouldSkipStage(FILE_06_05, _skipKeys("orbitalHookPkg"))) {
            s.orbitalHookPkg = _loadAddr(FILE_06_05, "orbitalHookPkg");
        } else {
            _requireCreate3(s);
            _requireCommonFacets(s);
            _requireManager(s);
            _broadcast();
            OrbitalHookLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0605", FILE_06_05, "orbitalHookPkg", s.orbitalHookPkg);
        _logAddress("orbitalHookPkg:", s.orbitalHookPkg);
        _logComplete("Phase 06 Stage 05");
    }
}

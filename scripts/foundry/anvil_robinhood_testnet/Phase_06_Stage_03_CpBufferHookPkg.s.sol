// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_03_CpBufferHookPkg as CpHookLib} from "./Phase_06_Stage_03_CpBufferHookPkg.sol";

/// @title Phase_06_Stage_03_CpBufferHookPkg
/// @notice Skip key: `cpHookPkg`.
contract Phase_06_Stage_03_CpBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 03: CP buffer hook pkg");
        if (_shouldSkipStage(FILE_06_03, _skipKeys("cpHookPkg"))) {
            s.cpHookPkg = _loadAddr(FILE_06_03, "cpHookPkg");
        } else {
            _requireCreate3(s);
            _requireCommonFacets(s);
            _requireManager(s);
            _broadcast();
            CpHookLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0603", FILE_06_03, "cpHookPkg", s.cpHookPkg);
        _logAddress("cpHookPkg:", s.cpHookPkg);
        _logComplete("Phase 06 Stage 03");
    }
}

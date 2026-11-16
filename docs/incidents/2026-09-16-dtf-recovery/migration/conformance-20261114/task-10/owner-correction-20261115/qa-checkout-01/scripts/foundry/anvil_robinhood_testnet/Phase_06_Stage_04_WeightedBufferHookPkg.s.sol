// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_04_WeightedBufferHookPkg as WeightedHookLib} from "./Phase_06_Stage_04_WeightedBufferHookPkg.sol";

/// @title Phase_06_Stage_04_WeightedBufferHookPkg
/// @notice Skip key: `weightedHookPkg`.
contract Phase_06_Stage_04_WeightedBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 04: Weighted buffer hook pkg");
        if (_shouldSkipStage(FILE_06_04, _skipKeys("weightedHookPkg"))) {
            s.weightedHookPkg = _loadAddr(FILE_06_04, "weightedHookPkg");
        } else {
            _requireCreate3(s);
            _requireCommonFacets(s);
            _requireManager(s);
            _broadcast();
            WeightedHookLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0604", FILE_06_04, "weightedHookPkg", s.weightedHookPkg);
        _logAddress("weightedHookPkg:", s.weightedHookPkg);
        _logComplete("Phase 06 Stage 04");
    }
}

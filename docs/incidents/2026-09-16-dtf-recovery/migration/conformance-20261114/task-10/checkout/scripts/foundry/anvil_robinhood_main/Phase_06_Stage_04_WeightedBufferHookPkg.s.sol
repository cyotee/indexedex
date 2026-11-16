// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_04_WeightedBufferHookPkg as WeightedHookLib} from "./Phase_06_Stage_04_WeightedBufferHookPkg.sol";

/// @title Phase_06_Stage_04_WeightedBufferHookPkg
/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.
contract Phase_06_Stage_04_WeightedBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 04: Weighted buffer hook pkg");
        // Address records alone cannot establish release freshness.
        _requireCreate3(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        WeightedHookLib.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0604", FILE_06_04, "weightedHookPkg", s.weightedHookPkg);
        _logAddress("weightedHookPkg:", s.weightedHookPkg);
        _logComplete("Phase 06 Stage 04");
    }
}

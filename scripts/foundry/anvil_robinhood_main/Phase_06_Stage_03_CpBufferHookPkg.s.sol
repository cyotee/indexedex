// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_03_CpBufferHookPkg as CpHookLib} from "./Phase_06_Stage_03_CpBufferHookPkg.sol";

/// @title Phase_06_Stage_03_CpBufferHookPkg
/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.
contract Phase_06_Stage_03_CpBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 03: CP buffer hook pkg");
        // Address records alone cannot establish release freshness.
        _requireCreate3(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        CpHookLib.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0603", FILE_06_03, "cpHookPkg", s.cpHookPkg);
        _logAddress("cpHookPkg:", s.cpHookPkg);
        _logComplete("Phase 06 Stage 03");
    }
}

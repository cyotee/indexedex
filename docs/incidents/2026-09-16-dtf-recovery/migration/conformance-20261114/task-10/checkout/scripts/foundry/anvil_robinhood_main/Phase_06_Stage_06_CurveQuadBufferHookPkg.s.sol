// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_06_CurveQuadBufferHookPkg as QuadHookLib} from "./Phase_06_Stage_06_CurveQuadBufferHookPkg.sol";

/// @title Phase_06_Stage_06_CurveQuadBufferHookPkg
/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.
contract Phase_06_Stage_06_CurveQuadBufferHookPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 06: Curve Quad buffer hook pkg");
        // Address records alone cannot establish release freshness.
        _requireCreate3(s);
        _requireCommonFacets(s);
        _requireManager(s);
        _broadcast();
        QuadHookLib.execute(s);
        vm.stopBroadcast();
        _exportPkg("p0606", FILE_06_06, "curveQuadHookPkg", s.curveQuadHookPkg);
        _logAddress("curveQuadHookPkg:", s.curveQuadHookPkg);
        _logComplete("Phase 06 Stage 06");
    }
}

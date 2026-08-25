// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_06_Stage_10_CurveQuadDetfPkg as QuadDetfLib} from "./Phase_06_Stage_10_CurveQuadDetfPkg.sol";

/// @title Phase_06_Stage_10_CurveQuadDetfPkg
/// @notice Skip key: `curveQuadDetfPkg`.
contract Phase_06_Stage_10_CurveQuadDetfPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 10: Curve Quad DETF pkg");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_06_10, _skipKeys("curveQuadDetfPkg"))) {
            s.curveQuadDetfPkg = _loadAddr(FILE_06_10, "curveQuadDetfPkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            s.curveQuadHookPkg = _loadAddr(FILE_06_06, "curveQuadHookPkg");
            s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
            s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
            _broadcast();
            QuadDetfLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0610", FILE_06_10, "curveQuadDetfPkg", s.curveQuadDetfPkg);
        _logAddress("curveQuadDetfPkg:", s.curveQuadDetfPkg);
        _logComplete("Phase 06 Stage 10");
    }
}

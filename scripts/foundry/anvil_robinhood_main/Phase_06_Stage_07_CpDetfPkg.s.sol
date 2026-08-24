// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_06_Stage_07_CpDetfPkg as CpDetfLib} from "./Phase_06_Stage_07_CpDetfPkg.sol";

/// @title Phase_06_Stage_07_CpDetfPkg
/// @notice Skip key: `cpDetfPkg`.
contract Phase_06_Stage_07_CpDetfPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 07: CP DETF pkg");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_06_07, _skipKeys("cpDetfPkg"))) {
            s.cpDetfPkg = _loadAddr(FILE_06_07, "cpDetfPkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            s.cpHookPkg = _loadAddr(FILE_06_03, "cpHookPkg");
            s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
            s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
            _broadcast();
            CpDetfLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0607", FILE_06_07, "cpDetfPkg", s.cpDetfPkg);
        _logAddress("cpDetfPkg:", s.cpDetfPkg);
        _logComplete("Phase 06 Stage 07");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_06_Stage_09_OrbitalDetfPkg as OrbitalDetfLib} from "./Phase_06_Stage_09_OrbitalDetfPkg.sol";

/// @title Phase_06_Stage_09_OrbitalDetfPkg
/// @notice Skip key: `orbitalDetfPkg`.
contract Phase_06_Stage_09_OrbitalDetfPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 09: Orbital DETF pkg");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_06_09, _skipKeys("orbitalDetfPkg"))) {
            s.orbitalDetfPkg = _loadAddr(FILE_06_09, "orbitalDetfPkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            s.orbitalHookPkg = _loadAddr(FILE_06_05, "orbitalHookPkg");
            s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
            s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
            _broadcast();
            OrbitalDetfLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0609", FILE_06_09, "orbitalDetfPkg", s.orbitalDetfPkg);
        _logAddress("orbitalDetfPkg:", s.orbitalDetfPkg);
        _logComplete("Phase 06 Stage 09");
    }
}

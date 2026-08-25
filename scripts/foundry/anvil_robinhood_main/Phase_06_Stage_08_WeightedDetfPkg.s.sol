// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {Phase_06_Stage_08_WeightedDetfPkg as WeightedDetfLib} from "./Phase_06_Stage_08_WeightedDetfPkg.sol";

/// @title Phase_06_Stage_08_WeightedDetfPkg
/// @notice Skip key: `weightedDetfPkg`.
contract Phase_06_Stage_08_WeightedDetfPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 08: Weighted DETF pkg");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_06_08, _skipKeys("weightedDetfPkg"))) {
            s.weightedDetfPkg = _loadAddr(FILE_06_08, "weightedDetfPkg");
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _requireManager(s);
            s.weightedHookPkg = _loadAddr(FILE_06_04, "weightedHookPkg");
            s.bondNftVaultPkg = _loadAddr(FILE_06_01, "bondNftVaultPkg");
            s.rebasingClaimTokenPkg = _loadAddr(FILE_06_02, "rebasingClaimTokenPkg");
            _broadcast();
            WeightedDetfLib.execute(s);
            vm.stopBroadcast();
        }
        _exportPkg("p0608", FILE_06_08, "weightedDetfPkg", s.weightedDetfPkg);
        _logAddress("weightedDetfPkg:", s.weightedDetfPkg);
        _logComplete("Phase 06 Stage 08");
    }
}

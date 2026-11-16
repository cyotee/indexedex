// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_02_Stage_02_DiamondPackageFactory as DiamondFactoryLib} from "./Phase_02_Stage_02_DiamondPackageFactory.sol";

/// @title Phase_02_Stage_02_DiamondPackageFactory
/// @notice Skip key: `diamondPackageFactory`.
contract Phase_02_Stage_02_DiamondPackageFactory is LaunchStageBase {
    function run() external {
        _start("Phase 02 Stage 02: Diamond package factory");
        if (_shouldSkipStage(FILE_02_02, _skipKeys("diamondPackageFactory"))) {
            _requireDiamondFactory(s);
        } else {
            _requireCreate3(s);
            _broadcast();
            DiamondFactoryLib.execute(s);
            vm.stopBroadcast();
        }
        _exportDiamondFactory(s);
        _logAddress("diamondPackageFactory:", address(s.diamondPackageFactory));
        _logComplete("Phase 02 Stage 02");
    }
}

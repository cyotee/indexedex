// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_02_Stage_03_HookFactory as HookFactoryLib} from "./Phase_02_Stage_03_HookFactory.sol";

/// @title Phase_02_Stage_03_HookFactory
/// @notice Skip key: `hookFactory`.
contract Phase_02_Stage_03_HookFactory is LaunchStageBase {
    function run() external {
        _start("Phase 02 Stage 03: Hook factory");
        if (_shouldSkipStage(FILE_02_03, _skipKeys("hookFactory"))) {
            _requireHookFactory(s);
        } else {
            _requireCreate3(s);
            _broadcast();
            HookFactoryLib.execute(s);
            vm.stopBroadcast();
        }
        _exportHookFactory(s);
        _logAddress("hookFactory:", address(s.hookFactory));
        _logComplete("Phase 02 Stage 03");
    }
}

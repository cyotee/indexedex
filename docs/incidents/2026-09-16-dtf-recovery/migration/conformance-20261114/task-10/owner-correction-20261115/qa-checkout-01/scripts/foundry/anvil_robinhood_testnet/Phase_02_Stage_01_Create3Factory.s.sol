// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_02_Stage_01_Create3Factory as Create3Lib} from "./Phase_02_Stage_01_Create3Factory.sol";

/// @title Phase_02_Stage_01_Create3Factory
/// @notice Skip key: `create3Factory`.
contract Phase_02_Stage_01_Create3Factory is LaunchStageBase {
    function run() external {
        _start("Phase 02 Stage 01: CREATE3 factory");
        if (_shouldSkipStage(FILE_02_01, _skipKeys("create3Factory"))) {
            _requireCreate3(s);
        } else {
            _broadcast();
            Create3Lib.execute(s, owner);
            vm.stopBroadcast();
        }
        _exportCreate3(s);
        _logAddress("create3Factory:", address(s.create3Factory));
        _logComplete("Phase 02 Stage 01");
    }
}

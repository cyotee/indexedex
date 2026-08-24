// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_01_Stage_01_Permit2 as Permit2Lib} from "./Phase_01_Stage_01_Permit2.sol";

/// @title Phase_01_Stage_01_Permit2
/// @notice Skip key: `permit2`.
contract Phase_01_Stage_01_Permit2 is LaunchStageBase {
    function run() external {
        _start("Phase 01 Stage 01: Permit2 pin");
        address permit2;
        if (_shouldSkipStage(FILE_01_01, "permit2")) {
            permit2 = _loadAddr(FILE_01_01, "permit2");
        } else {
            permit2 = Permit2Lib.execute();
        }
        string memory json;
        json = vm.serializeAddress("p0101", "permit2", permit2);
        json = vm.serializeUint("p0101", "chainId", block.chainid);
        _writeJson(json, FILE_01_01);
        _logAddress("permit2:", permit2);
        _logComplete("Phase 01 Stage 01");
    }
}

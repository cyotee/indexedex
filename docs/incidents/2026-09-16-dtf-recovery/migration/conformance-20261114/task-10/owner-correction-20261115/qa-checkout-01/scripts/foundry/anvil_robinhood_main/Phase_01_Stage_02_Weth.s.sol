// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_01_Stage_02_Weth as WethLib} from "./Phase_01_Stage_02_Weth.sol";

/// @title Phase_01_Stage_02_Weth
/// @notice Skip key: `weth`.
contract Phase_01_Stage_02_Weth is LaunchStageBase {
    function run() external {
        _start("Phase 01 Stage 02: WETH pin");
        address weth;
        if (_shouldSkipStage(FILE_01_02, _skipKeys("weth"))) {
            weth = _loadAddr(FILE_01_02, "weth");
        } else {
            weth = WethLib.execute();
        }
        string memory json;
        json = vm.serializeAddress("p0102", "weth", weth);
        json = vm.serializeUint("p0102", "chainId", block.chainid);
        _writeJson(json, FILE_01_02);
        _logAddress("weth:", weth);
        _logComplete("Phase 01 Stage 02");
    }
}

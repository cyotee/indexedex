// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_01_Stage_05_MorphoBlue as MorphoLib} from "./Phase_01_Stage_05_MorphoBlue.sol";

/// @title Phase_01_Stage_05_MorphoBlue
/// @notice Skip key: `morpho`. Writes live `morpho`, `morphoIrm`, `morphoOracle`.
contract Phase_01_Stage_05_MorphoBlue is LaunchStageBase {
    function run() external {
        _start("Phase 01 Stage 05: Morpho Blue");
        if (_shouldSkipStage(FILE_01_05, _skipKeys("morpho"))) {
            _hydrateMorphoHost(s);
        } else {
            _broadcast();
            MorphoLib.execute(s, owner);
            vm.stopBroadcast();
        }
        string memory json;
        json = vm.serializeAddress("p0105", "morpho", s.morpho);
        json = vm.serializeAddress("p0105", "morphoIrm", s.morphoIrm);
        json = vm.serializeAddress("p0105", "morphoOracle", s.morphoOracle);
        json = vm.serializeBool("p0105", "morphoLocal", s.morphoLocal);
        json = vm.serializeUint("p0105", "chainId", block.chainid);
        _writeJson(json, FILE_01_05);
        _logAddress("morpho:", s.morpho);
        _logComplete("Phase 01 Stage 05");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_07_Stage_02_Mag7TestTokens as Mag7Lib} from "./Phase_07_Stage_02_Mag7TestTokens.sol";

/// @title Phase_07_Stage_02_Mag7TestTokens
/// @notice Skip keys: `TTNVDA`, `TTMSFT`, `TTAAPL` (catalog). Deploys Mag7 TTNVDA…TTTSLA.
contract Phase_07_Stage_02_Mag7TestTokens is LaunchStageBase {
    function run() external {
        _start("Phase 07 Stage 02: Mag7 test tokens");
        if (_shouldSkipStage(FILE_07_02, _skipKeys("TTNVDA", "TTMSFT", "TTAAPL"))) {
            _hydrateMag7(s);
        } else {
            _requireCoreTokens(s);
            _requireFacade(s);
            _hydrateMag7(s);
            _broadcast();
            Mag7Lib.execute(s, deployer);
            vm.stopBroadcast();
        }
        _exportMag7(s);
        _logAddress("TTNVDA:", s.ttNVDA);
        _logComplete("Phase 07 Stage 02");
    }
}
